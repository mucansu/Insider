#!/usr/bin/env python3
"""tools/latency_proxy.py birim testleri (US-001 AC6). Yalnız standart kütüphane.

Koşu: python3 tools/test_latency_proxy.py   (ya da python3 -m unittest tools/test_latency_proxy.py)
Windows'ta `python3` yoksa `python` ya da `py -3`; tools/ci_local.sh `tools` adımı yorumlayıcıyı kendisi bulur.
Ölçülen gidiş-dönüş gecikmesi beklenenin ±15 ms içinde olmalı.
"""

from __future__ import annotations

import ctypes
import os
import signal
import socket
import statistics
import subprocess
import sys
import threading
import time
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import latency_proxy  # noqa: E402
from latency_proxy import LatencyProxy, parse_addr  # noqa: E402

TOLERANCE_MS = 15.0
# Windows'ta SIGTERM gönderilemez (terminate = TerminateProcess, çıkış 1): proxy kendi süreç grubunda başlatılır
# ve CTRL_BREAK_EVENT ile (SIGBREAK) zarif kapatılır. POSIX'te SIGTERM.
WINDOWS = os.name == "nt"


class EchoServer:
    """Gelen her paketi göndereni + yükü ile geri yollar; görülen kaynak adresleri tutar."""

    def __init__(self) -> None:
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("127.0.0.1", 0))
        self.sock.settimeout(0.2)
        self.port = self.sock.getsockname()[1]
        self.sources: set[tuple] = set()
        self._stop = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._thread.start()

    def _run(self) -> None:
        while not self._stop.is_set():
            try:
                data, addr = self.sock.recvfrom(65535)
            except socket.timeout:
                continue
            except OSError:
                return
            self.sources.add(addr)
            self.sock.sendto(data, addr)

    def close(self) -> None:
        self._stop.set()
        self._thread.join(timeout=1.0)
        self.sock.close()


def client_socket(timeout: float = 1.0) -> socket.socket:
    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.bind(("127.0.0.1", 0))
    s.settimeout(timeout)
    return s


def measure_rtts(sock: socket.socket, port: int, count: int, tag: bytes = b"p") -> list[float]:
    """Sıralı ping-pong; her paket için ms cinsinden RTT (yanıt gelmeyen atlanır)."""
    out: list[float] = []
    for i in range(count):
        payload = tag + b":" + str(i).encode()
        t0 = time.monotonic()
        sock.sendto(payload, ("127.0.0.1", port))
        try:
            while True:
                data, _ = sock.recvfrom(65535)
                if data == payload:
                    out.append((time.monotonic() - t0) * 1000.0)
                    break
        except socket.timeout:
            continue
    return out


class LatencyProxyTest(unittest.TestCase):
    def setUp(self) -> None:
        self.echo = EchoServer()

    def tearDown(self) -> None:
        self.echo.close()

    def test_parse_addr(self) -> None:
        self.assertEqual(parse_addr("127.0.0.1:7777"), ("127.0.0.1", 7777))
        self.assertEqual(parse_addr("[::1]:9"), ("::1", 9))
        self.assertEqual(parse_addr(":5"), ("127.0.0.1", 5))
        with self.assertRaises(ValueError):
            parse_addr("127.0.0.1")

    def test_rejects_bad_parameters(self) -> None:
        with self.assertRaises(ValueError):
            LatencyProxy(target=("127.0.0.1", 1), loss=1.5)
        with self.assertRaises(ValueError):
            LatencyProxy(target=("127.0.0.1", 1), delay_ms=-1)

    def test_zero_delay_passthrough(self) -> None:
        with LatencyProxy(target=("127.0.0.1", self.echo.port)) as proxy:
            with client_socket() as s:
                rtts = measure_rtts(s, proxy.port, 10)
        self.assertEqual(len(rtts), 10)
        self.assertLess(statistics.mean(rtts), TOLERANCE_MS)

    def test_delay_per_direction(self) -> None:
        # yön başına 50 ms -> RTT 100 ms (±15)
        with LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=50) as proxy:
            with client_socket() as s:
                rtts = measure_rtts(s, proxy.port, 15)
        self.assertEqual(len(rtts), 15)
        self.assertAlmostEqual(statistics.mean(rtts), 100.0, delta=TOLERANCE_MS)
        self.assertGreaterEqual(min(rtts), 100.0 - 2.0, "gecikme yön başına uygulanmalı (RTT >= 2 x delay)")

    def test_rtt_150_like_net_smoke(self) -> None:
        # net_smoke.py --latency-ms 150 -> yön başına 75 ms
        with LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=75) as proxy:
            with client_socket() as s:
                rtts = measure_rtts(s, proxy.port, 8)
        self.assertEqual(len(rtts), 8)
        self.assertAlmostEqual(statistics.mean(rtts), 150.0, delta=TOLERANCE_MS)

    def test_multiple_clients_get_own_replies(self) -> None:
        with LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=20) as proxy:
            with client_socket() as a, client_socket() as b:
                ra = measure_rtts(a, proxy.port, 5, b"a")
                rb = measure_rtts(b, proxy.port, 5, b"b")
                # Aynı anda gönderim: her istemci yalnız kendi yanıtını alır.
                a.sendto(b"a:x", ("127.0.0.1", proxy.port))
                b.sendto(b"b:x", ("127.0.0.1", proxy.port))
                self.assertEqual(a.recvfrom(65535)[0], b"a:x")
                self.assertEqual(b.recvfrom(65535)[0], b"b:x")
            self.assertEqual(proxy.stats["clients"], 2)
        self.assertEqual((len(ra), len(rb)), (5, 5))
        self.assertAlmostEqual(statistics.mean(ra + rb), 40.0, delta=TOLERANCE_MS)
        self.assertEqual(len(self.echo.sources), 2, "her istemci için ayrı yukarı akış soketi")

    def test_jitter_bounds(self) -> None:
        with LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=40, jitter_ms=15, seed=7) as proxy:
            with client_socket() as s:
                rtts = measure_rtts(s, proxy.port, 25)
        self.assertEqual(len(rtts), 25)
        self.assertGreaterEqual(min(rtts), 2 * (40 - 15) - 2.0)
        self.assertLessEqual(max(rtts), 2 * (40 + 15) + TOLERANCE_MS)
        self.assertGreater(statistics.pstdev(rtts), 2.0, "jitter sapma üretmeli")
        self.assertAlmostEqual(statistics.mean(rtts), 80.0, delta=TOLERANCE_MS)

    def _burst_order(self, reorder: bool) -> list[int]:
        with LatencyProxy(
            target=("127.0.0.1", self.echo.port), delay_ms=20, jitter_ms=15, seed=11, reorder=reorder
        ) as proxy:
            with client_socket(timeout=0.5) as s:
                for i in range(60):
                    s.sendto(str(i).encode(), ("127.0.0.1", proxy.port))
                got: list[int] = []
                try:
                    while len(got) < 60:
                        got.append(int(s.recvfrom(65535)[0]))
                except socket.timeout:
                    pass
        return got

    def test_jitter_keeps_order_by_default(self) -> None:
        got = self._burst_order(reorder=False)
        self.assertEqual(got, list(range(60)), "varsayılan jitter akış içi sırayı korur")

    def test_jitter_reorder_option(self) -> None:
        got = self._burst_order(reorder=True)
        self.assertEqual(sorted(got), list(range(60)))
        self.assertNotEqual(got, list(range(60)), "--reorder sırayı bozabilmeli")

    def test_idle_sweep_releases_flow_state(self) -> None:
        proxy = LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=5, jitter_ms=3, seed=1)
        proxy.start()
        try:
            with client_socket() as s:
                self.assertEqual(len(measure_rtts(s, proxy.port, 3)), 3)
            self.assertGreater(len(proxy._last_due), 0)
            # İş parçacığını durdurup süpürmeyi elle, boşta kalma süresi geçmiş gibi koştur.
            proxy._stop.set()
            assert proxy._wake_w is not None and proxy._thread is not None
            proxy._wake_w.send(b"x")
            proxy._thread.join(timeout=2.0)
            proxy._sweep_idle(time.monotonic() + 1000.0)
            self.assertEqual(proxy._clients, {})
            self.assertEqual(proxy._last_due, {}, "akış sıra kaydı istemciyle birlikte silinmeli")
        finally:
            proxy.stop()

    @unittest.skipUnless(WINDOWS, "Windows güç kısıtlaması (EcoQoS)")
    def test_windows_power_throttling_opt_out(self) -> None:
        # IS-012: kısıtlanan süreçte timeBeginPeriod(1) yok sayılır ve paketler ~11 ms geç çıkar. Proxy çalışırken
        # süreç kısıtlamadan çıkmış olmalı (iç içe proxy'lerde sayılır); son proxy durunca sisteme geri verilir.
        def control_mask() -> int:
            k32 = ctypes.WinDLL("kernel32")
            k32.GetCurrentProcess.restype = ctypes.c_void_p
            k32.GetProcessInformation.argtypes = [ctypes.c_void_p, ctypes.c_int, ctypes.c_void_p, ctypes.c_ulong]
            st = latency_proxy._PowerThrottlingState(1, 0, 0)
            ok = k32.GetProcessInformation(
                k32.GetCurrentProcess(), latency_proxy._PROCESS_POWER_THROTTLING, ctypes.byref(st), ctypes.sizeof(st)
            )
            if not ok:
                self.skipTest("GetProcessInformation(ProcessPowerThrottling) desteklenmiyor")
            self.assertEqual(st.StateMask, 0, "denetlenen kısıtlar kapalı olmalı")
            return st.ControlMask

        ignore_timer = latency_proxy._THROTTLE_IGNORE_TIMER_RESOLUTION
        self.assertEqual(control_mask() & ignore_timer, 0)
        with LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=1):
            self.assertTrue(control_mask() & ignore_timer)
            with LatencyProxy(target=("127.0.0.1", self.echo.port), delay_ms=1):
                self.assertTrue(control_mask() & ignore_timer)
            self.assertTrue(control_mask() & ignore_timer, "iç proxy durunca dış proxy hâlâ kısıtsız")
        self.assertEqual(control_mask(), 0, "son proxy durunca karar sisteme geri verilir")

    def test_full_loss_drops_everything(self) -> None:
        with LatencyProxy(target=("127.0.0.1", self.echo.port), loss=1.0) as proxy:
            with client_socket(timeout=0.15) as s:
                rtts = measure_rtts(s, proxy.port, 5)
            self.assertEqual(rtts, [])
            self.assertEqual(proxy.stats["dropped"], 5)

    def test_partial_loss_rate(self) -> None:
        # Her yönde %20 kayıp -> gidiş-dönüş başarı ~0.64.
        with LatencyProxy(target=("127.0.0.1", self.echo.port), loss=0.2, seed=3) as proxy:
            with client_socket(timeout=0.05) as s:
                rtts = measure_rtts(s, proxy.port, 200)
        self.assertTrue(0.5 <= len(rtts) / 200 <= 0.78, f"başarı oranı {len(rtts) / 200}")

    def test_command_line(self) -> None:
        script = os.path.join(os.path.dirname(os.path.abspath(__file__)), "latency_proxy.py")
        proc = subprocess.Popen(
            [sys.executable, script, "--target", f"127.0.0.1:{self.echo.port}", "--delay-ms", "30"],
            stdout=subprocess.PIPE,
            text=True,
            creationflags=subprocess.CREATE_NEW_PROCESS_GROUP if WINDOWS else 0,
        )
        try:
            assert proc.stdout is not None
            line = proc.stdout.readline().strip()
            self.assertTrue(line.startswith("LATENCY_PROXY_READY port="), line)
            port = int(line.split("=", 1)[1])
            with client_socket() as s:
                rtts = measure_rtts(s, port, 5)
            self.assertEqual(len(rtts), 5)
            self.assertAlmostEqual(statistics.mean(rtts), 60.0, delta=TOLERANCE_MS)
        finally:
            if WINDOWS:
                proc.send_signal(signal.CTRL_BREAK_EVENT)
            else:
                proc.terminate()
            self.assertEqual(proc.wait(timeout=5), 0)
            if proc.stdout is not None:
                proc.stdout.close()


if __name__ == "__main__":
    unittest.main(verbosity=2)
