#!/usr/bin/env python3
"""UDP gecikme proxy'si (mimari.md S6, US-001 AC6). Yalnız Python standart kütüphanesi.

Host'un önüne konur; istemciler proxy'ye bağlanır. Her istemci adresi (ip, port) için ayrı bir yukarı akış
soketi açılır (istemci adresi <-> yukarı akış soketi eşlemesi), böylece host her istemciyi ayrı peer görür.
Her paket, yön başına `delay_ms` (+ [-jitter_ms, +jitter_ms] düzgün dağılımlı sapma, en az 0) sonra iletilir;
`loss` olasılığıyla düşürülür. RTT = 2 x delay_ms. Varsayılan olarak jitter akış (istemci + yön) içindeki
sırayı korur (gecikme değişimi gibi; gerçek yollarda sıra bozulması seyrektir); `reorder=True` /
`--reorder` her paketin gecikmesini bağımsız seçer ve sırayı bozabilir.

Komut satırı:
    python3 tools/latency_proxy.py --target 127.0.0.1:7777 [--listen 127.0.0.1:0] \
        [--delay-ms 75] [--jitter-ms 0] [--loss 0.0] [--reorder] [--seed N]
Bağlanınca stdout'a tek satır `LATENCY_PROXY_READY port=<dinlenen port>` basar; SIGINT/SIGTERM ile kapanır
(Windows'ta SIGTERM gönderilemez: CTRL_BREAK_EVENT -> SIGBREAK ile de zarif kapanır).

Windows: select() zaman aşımı varsayılan zamanlayıcı adımına (~15,6 ms) yuvarlanır ve paketler geç çıkar;
proxy çalışırken süreç zamanlayıcı çözünürlüğü 1 ms'ye çekilir (winmm timeBeginPeriod/timeEndPeriod). Windows 11
güç kısıtlaması (EcoQoS) arka plandaki/penceresiz süreçlerin bu isteğini zaman zaman yok sayar (paketler yine
~11 ms geç çıkar, IS-012); bu yüzden proxy çalışırken süreç güç kısıtlamasından da çıkarılır
(SetProcessInformation/ProcessPowerThrottling), son proxy durunca sistem varsayılanına döner.

Modül olarak (net_smoke.py, testler):
    proxy = LatencyProxy(target=("127.0.0.1", 7777), delay_ms=75)
    port = proxy.start()      # arka plan iş parçacığı
    ...
    proxy.stop()
"""

from __future__ import annotations

import argparse
import ctypes
import heapq
import random
import selectors
import signal
import socket
import sys
import threading
import time
from dataclasses import dataclass, field

MAX_DATAGRAM = 65535
IDLE_TIMEOUT_SEC = 60.0


def _timer_period(begin: bool) -> bool:
    """Windows'ta zamanlayıcı çözünürlüğünü 1 ms'ye çeker (begin) ya da isteği geri alır; başka yerde no-op.
    Çağrılar Windows'ta sayılır: her başarılı begin için bir end gerekir. Başarılıysa True."""
    if sys.platform != "win32":
        return False
    try:
        winmm = ctypes.WinDLL("winmm")
        fn = winmm.timeBeginPeriod if begin else winmm.timeEndPeriod
        return fn(1) == 0  # TIMERR_NOERROR
    except (OSError, AttributeError):
        return False


# PROCESS_INFORMATION_CLASS.ProcessPowerThrottling ve PROCESS_POWER_THROTTLING_* bayrakları (processthreadsapi.h).
_PROCESS_POWER_THROTTLING = 4
_THROTTLE_EXECUTION_SPEED = 0x1
_THROTTLE_IGNORE_TIMER_RESOLUTION = 0x4
_unthrottle_lock = threading.Lock()
_unthrottle_users = 0


class _PowerThrottlingState(ctypes.Structure):
    _fields_ = [("Version", ctypes.c_ulong), ("ControlMask", ctypes.c_ulong), ("StateMask", ctypes.c_ulong)]


def _set_power_throttling_opt_out(opt_out: bool) -> bool:
    """Windows: opt_out=True süreci EcoQoS'tan ve 'zamanlayıcı çözünürlüğü isteğini yok say' kısıtından açıkça
    çıkarır; False kararı sisteme geri bırakır. Desteklenmeyen sürümde/başka platformda no-op. Başarılıysa True."""
    if sys.platform != "win32":
        return False
    try:
        k32 = ctypes.WinDLL("kernel32")
        k32.GetCurrentProcess.restype = ctypes.c_void_p
        k32.SetProcessInformation.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_ulong]
        mask = (_THROTTLE_EXECUTION_SPEED | _THROTTLE_IGNORE_TIMER_RESOLUTION) if opt_out else 0
        state = _PowerThrottlingState(1, mask, 0)  # StateMask 0 = denetlenen bayraklar kapalı
        return bool(
            k32.SetProcessInformation(
                k32.GetCurrentProcess(), _PROCESS_POWER_THROTTLING, ctypes.byref(state), ctypes.sizeof(state)
            )
        )
    except (OSError, AttributeError):
        return False


def _hold_unthrottled(hold: bool) -> None:
    """Güç kısıtlamasından çıkışı süreç genelinde sayar: ilk tutan açar, son bırakan sisteme geri verir."""
    global _unthrottle_users
    with _unthrottle_lock:
        if hold:
            _unthrottle_users += 1
            if _unthrottle_users == 1:
                _set_power_throttling_opt_out(True)
        elif _unthrottle_users > 0:
            _unthrottle_users -= 1
            if _unthrottle_users == 0:
                _set_power_throttling_opt_out(False)


def parse_addr(text: str) -> tuple[str, int]:
    """'host:port' ya da '[v6]:port' -> (host, port)."""
    host, sep, port = text.rpartition(":")
    if not sep or not port.isdigit():
        raise ValueError(f"adres host:port biçiminde olmalı: {text!r}")
    return host.strip("[]") or "127.0.0.1", int(port)


@dataclass
class _Client:
    addr: tuple
    upstream: socket.socket
    last_seen: float = field(default_factory=time.monotonic)


class LatencyProxy:
    """Çok istemcili UDP röle; gecikme/jitter/kayıp yön başına uygulanır."""

    def __init__(
        self,
        target: tuple[str, int],
        listen: tuple[str, int] = ("127.0.0.1", 0),
        delay_ms: float = 0.0,
        jitter_ms: float = 0.0,
        loss: float = 0.0,
        seed: int | None = None,
        reorder: bool = False,
    ) -> None:
        if delay_ms < 0 or jitter_ms < 0 or not 0.0 <= loss <= 1.0:
            raise ValueError("delay_ms/jitter_ms >= 0 ve 0 <= loss <= 1 olmalı")
        self.target = target
        self.listen = listen
        self.delay = delay_ms / 1000.0
        self.jitter = jitter_ms / 1000.0
        self.loss = loss
        self.reorder = reorder
        self.rng = random.Random(seed)
        self._last_due: dict[tuple, float] = {}
        self.stats = {"up": 0, "down": 0, "dropped": 0, "clients": 0}
        self._target_info = socket.getaddrinfo(target[0], target[1], type=socket.SOCK_DGRAM)[0]
        self._sel: selectors.BaseSelector | None = None
        self._listener: socket.socket | None = None
        self._clients: dict[tuple, _Client] = {}
        self._queue: list[tuple[float, int, socket.socket, bytes, tuple | None]] = []
        self._seq = 0
        self._thread: threading.Thread | None = None
        self._stop = threading.Event()
        self._wake_r: socket.socket | None = None
        self._wake_w: socket.socket | None = None
        self._hires_timer = False
        self._unthrottled = False
        self.port = 0

    # --- yaşam döngüsü ---

    def start(self) -> int:
        """Dinlemeye başlar, arka plan iş parçacığını açar ve dinlenen portu döner."""
        info = socket.getaddrinfo(self.listen[0], self.listen[1], type=socket.SOCK_DGRAM)[0]
        self._listener = socket.socket(info[0], socket.SOCK_DGRAM)
        self._listener.bind(info[4])
        self._listener.setblocking(False)
        self.port = self._listener.getsockname()[1]
        self._wake_r, self._wake_w = socket.socketpair()
        self._wake_r.setblocking(False)
        self._sel = selectors.DefaultSelector()
        self._sel.register(self._listener, selectors.EVENT_READ, "listen")
        self._sel.register(self._wake_r, selectors.EVENT_READ, "wake")
        if sys.platform == "win32":
            _hold_unthrottled(True)
            self._unthrottled = True
        self._hires_timer = _timer_period(True)
        self._thread = threading.Thread(target=self._run, name="latency-proxy", daemon=True)
        self._thread.start()
        return self.port

    def stop(self) -> None:
        self._stop.set()
        if self._wake_w is not None:
            try:
                self._wake_w.send(b"x")
            except OSError:
                pass
        if self._thread is not None:
            self._thread.join(timeout=2.0)
        for sock in [c.upstream for c in self._clients.values()] + [self._listener, self._wake_r, self._wake_w]:
            if sock is not None:
                try:
                    sock.close()
                except OSError:
                    pass
        self._clients.clear()
        self._last_due.clear()
        if self._sel is not None:
            self._sel.close()
        if self._hires_timer:
            self._hires_timer = False
            _timer_period(False)
        if self._unthrottled:
            self._unthrottled = False
            _hold_unthrottled(False)

    def __enter__(self) -> "LatencyProxy":
        self.start()
        return self

    def __exit__(self, *_exc: object) -> None:
        self.stop()

    # --- döngü ---

    def _run(self) -> None:
        assert self._sel is not None
        last_sweep = time.monotonic()
        while not self._stop.is_set():
            now = time.monotonic()
            timeout = 0.5 if not self._queue else max(0.0, min(0.5, self._queue[0][0] - now))
            for key, _mask in self._sel.select(timeout):
                if key.data == "listen":
                    self._drain_listener()
                elif key.data == "wake":
                    try:
                        self._wake_r.recv(64)
                    except OSError:
                        pass
                else:
                    self._drain_upstream(key.data)
            now = time.monotonic()
            while self._queue and self._queue[0][0] <= now:
                _t, _seq, sock, data, addr = heapq.heappop(self._queue)
                try:
                    if addr is None:
                        sock.send(data)
                    else:
                        sock.sendto(data, addr)
                except OSError:
                    pass  # karşı taraf henüz/artık yok: UDP gibi sessizce düşer
            if now - last_sweep > 5.0:
                last_sweep = now
                self._sweep_idle(now)

    def _drain_listener(self) -> None:
        assert self._listener is not None
        while True:
            try:
                data, addr = self._listener.recvfrom(MAX_DATAGRAM)
            except (BlockingIOError, InterruptedError):
                return
            except OSError:
                continue
            client = self._clients.get(addr)
            if client is None:
                client = self._open_client(addr)
                if client is None:
                    continue
            client.last_seen = time.monotonic()
            self.stats["up"] += 1
            self._schedule(client.upstream, data, None)

    def _drain_upstream(self, addr: tuple) -> None:
        client = self._clients.get(addr)
        if client is None:
            return
        while True:
            try:
                data = client.upstream.recv(MAX_DATAGRAM)
            except (BlockingIOError, InterruptedError):
                return
            except OSError:
                return  # ör. ICMP port kapalı; sonraki pakette yeniden denenir
            client.last_seen = time.monotonic()
            self.stats["down"] += 1
            assert self._listener is not None
            self._schedule(self._listener, data, addr)

    def _open_client(self, addr: tuple) -> _Client | None:
        family, _type, _proto, _canon, sockaddr = self._target_info
        up = socket.socket(family, socket.SOCK_DGRAM)
        try:
            up.connect(sockaddr)
        except OSError:
            up.close()
            return None
        up.setblocking(False)
        client = _Client(addr=addr, upstream=up)
        self._clients[addr] = client
        assert self._sel is not None
        self._sel.register(up, selectors.EVENT_READ, addr)
        self.stats["clients"] += 1
        return client

    def _sweep_idle(self, now: float) -> None:
        for addr, client in list(self._clients.items()):
            if now - client.last_seen > IDLE_TIMEOUT_SEC:
                assert self._sel is not None
                self._sel.unregister(client.upstream)
                self._last_due.pop((id(client.upstream), None), None)
                self._last_due.pop((id(self._listener), addr), None)
                client.upstream.close()
                del self._clients[addr]
        # Geçmişte kalan son teslim zamanı sırayı artık kısıtlamaz; akış kaydı silinebilir.
        for flow, due in list(self._last_due.items()):
            if due < now:
                del self._last_due[flow]

    def _schedule(self, sock: socket.socket, data: bytes, addr: tuple | None) -> None:
        if self.loss > 0.0 and self.rng.random() < self.loss:
            self.stats["dropped"] += 1
            return
        delay = self.delay
        if self.jitter > 0.0:
            delay = max(0.0, delay + self.rng.uniform(-self.jitter, self.jitter))
        due = time.monotonic() + delay
        if not self.reorder:
            flow = (id(sock), addr)
            due = max(due, self._last_due.get(flow, 0.0))
            self._last_due[flow] = due
        self._seq += 1
        heapq.heappush(self._queue, (due, self._seq, sock, data, addr))


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="UDP gecikme proxy'si (yön başına gecikme, jitter, kayıp)")
    ap.add_argument("--target", required=True, help="host adresi, ör. 127.0.0.1:7777")
    ap.add_argument("--listen", default="127.0.0.1:0", help="dinlenecek adres (port 0 = boş port)")
    ap.add_argument("--delay-ms", type=float, default=0.0, help="yön başına gecikme (RTT/2)")
    ap.add_argument("--jitter-ms", type=float, default=0.0, help="yön başına ± düzgün sapma")
    ap.add_argument("--loss", type=float, default=0.0, help="paket kaybı olasılığı (0..1)")
    ap.add_argument("--reorder", action="store_true", help="jitter paket sırasını bozabilsin")
    ap.add_argument("--seed", type=int, default=None)
    args = ap.parse_args(argv)
    proxy = LatencyProxy(
        target=parse_addr(args.target),
        listen=parse_addr(args.listen),
        delay_ms=args.delay_ms,
        jitter_ms=args.jitter_ms,
        loss=args.loss,
        seed=args.seed,
        reorder=args.reorder,
    )
    done = threading.Event()
    signal.signal(signal.SIGTERM, lambda *_: done.set())
    signal.signal(signal.SIGINT, lambda *_: done.set())
    if hasattr(signal, "SIGBREAK"):  # Windows: CTRL_BREAK_EVENT (SIGTERM'in karşılığı)
        signal.signal(signal.SIGBREAK, lambda *_: done.set())
    port = proxy.start()
    print(f"LATENCY_PROXY_READY port={port}", flush=True)
    try:
        while not done.wait(0.5):
            pass
    finally:
        proxy.stop()
    return 0


if __name__ == "__main__":
    sys.exit(main())
