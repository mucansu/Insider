#!/usr/bin/env python3
"""Çok süreçli ağ duman testi (mimari.md S6, §5; US-001). Yalnız Python standart kütüphanesi.

Kullanım:
    python3 tools/net_smoke.py tests/net/<senaryo>.json [--latency-ms 150] [--jitter-ms J] [--loss P]
                               [--reorder] [--keep] [--verbose] [--duration SN]
--duration senaryonun duration'ını ezer (tools/soak.sh). GDD §12 "sert ağ": --latency-ms 150 --jitter-ms 30
--loss 0.01 (IS-013 AC2; ci_local'ın varsayılan adımında değil, ayrı komut).
Godot: GODOT ortam değişkeni, yoksa tools/get_godot.sh. Çıkış kodu 0 = tüm beklentiler geçti.

Akış: boş UDP portları bulunur → host `--headless` başlatılır ve stdout'ta `INSIDERS_READY` beklenir →
(--latency-ms > 0 ise araya tools/latency_proxy.py konur: yön başına RTT/2 gecikme) → istemciler
`start_delay` sonra başlatılır → her süreç `--quit-after` ile döker ve kapanır; sert zaman aşımında bütün
süreç grupları öldürülür (asılı süreç kalmaz; SIGTERM'de de) → dökümler okunur, beklentiler değerlendirilir.
Süreç ağacı öldürme (kill_process_tree): POSIX'te ayrı oturum + killpg SIGTERM, sonra SIGKILL. Windows'ta
start_new_session işlemez: ayrı süreç grubu (CREATE_NEW_PROCESS_GROUP) + CTRL_BREAK_EVENT, sonra kök
Popen tutamağıyla, torunlar `taskkill /F /PID` ile (Godot console exe'si asıl exe'yi çocuk olarak başlatır).
Torunlar oluşturma zamanıyla süzülür: pid yeniden kullanımında ilgisiz süreç ağaca girmez (`/T` kullanılmaz).
Başarısızlıkta her sürecin log'u basılır. Log'da `ERROR:` / `SCRIPT ERROR:` satırı da başarısızlıktır
(`allow_log` hariç). --latency-ms > 0 iken gecikmenin uygulandığı ayrıca doğrulanır: proxy her istemciyi
eşlemiş olmalı ve her istemci için ölçülen ping (kendi dökümünde ping_ms.1 ya da host'unkinde ping_ms.<id>)
>= 0,8 x gecikme olmalı.

Senaryo (JSON; "_doc" serbest açıklamadır):
    level         res:// seviye (host'a --level)                        [zorunlu]
    player_scene  res:// oyuncu sahnesi (herkese --player-scene)       [res://tests/fixtures/dummy_player.tscn]
    clients       istemci sayısı (adları c1..cN)                       [2]
    duration      host başlangıcından ortak döküm anına saniye         [8]
    start_delay   {"c2": 2.0}: istemcinin host hazır olduktan sonra kaç sn sonra başlatılacağı   [0]
    quit_after    {"c2": 4}: sürece özel --quit-after (o sürecin başlangıcına göre); verilmeyenler host
                  başlangıcı + duration anında döker (cN, LEAVE_STAGGER x (N-1) sn sonra: istemciler aynı host
                  karesinde kopmasın; bkz. LEAVE_STAGGER notu)
    bots          {"host": "res://tests/net/bots/x.json", "c1": ...} (--bot). Bot dosyasında
                  "loop": {"from": F, "period": P} varsa net_smoke t >= F adımlarını P aralıkla, yalnız tam
                  turlar ve son tur bot saatinde quit_after - BOT_LOOP_END_MARGIN'de bitecek şekilde açar ve
                  açılmış kopyayı (geçici dizin, mutlak yol) verir (expand_bot_loop; dayanıklılık koşusu;
                  tur zamanları kare sınırına düşmemeli, bkz. expand_bot_loop)
    names         {"c1": "ad"} (--name)                                [süreç adı]
    exit_codes    {"c1": 0} beklenen çıkış kodları                     [hepsi 0]
    allow_log     ["regex", ...] izin verilen ERROR (/WARNING) satırları [yok]
    deny_warnings true ise log'daki WARNING satırı da başarısızlık   [false]
    mem_sample_sec  > 0 ise her sürecin ağacının özel belleği (Windows PrivateUsage, kök + torunlar; Linux
                  RssAnon, kök + torunlar) bu aralıkla örneklenir ve dökümüne "mem_mb": [[süreç başlangıcından
                  sn, MB], ...] ve "mem_meta": {"every", "quit_after"} olarak eklenir (mem_stable için)  [0]
    timeout       sert üst süre (sn)                                    [hesaplanır]
    expect        beklenti listesi (aşağıda)                           [zorunlu, boş olamaz]
Bilinmeyen anahtar içeren senaryo reddedilir (FAIL).

Yol ifadesi: "<süreç>.<anahtar>.<anahtar>..." — süreç host | c1..cN | * (her süreç için ayrı ayrı);
anahtarlar sözlük anahtarı ya da liste indisi; "$host", "$c1"... o sürecin peer_id'si ile değiştirilir
(peer kimlikleri rastgeledir). Dökümlere net_smoke "exit_code" (ve mem_sample_sec ile "mem_mb") ekler. Döküm alanları: main.gd ve
Game.collect_dump() (peer_id, is_host, peers, players{name,slot,pos}, team_cash, level, player_nodes,
events, host_lost, ping_ms, exit_reason, samples).
Beklentiler:
    {"eq": [yol, değer]}            {"ne": [yol, değer]}
    {"same": [yol, yol]}            iki yol eşit
    {"all_equal": "alt.yol"}        dökümü olan bütün süreçlerde aynı (S6)
    {"near": [yol, yol|değer, tol]} sayı ya da [x, y] farkı <= tol (S6)
    {"len": [yol, n]}               liste/sözlük uzunluğu
    {"has": [yol, öğe]}             sözlükte anahtar / listede öğe ("$c1" kullanılabilir)
    {"lacks": [yol, öğe]}           yukarıdakinin tersi
    {"between": [yol, alt, üst]}    alt <= değer <= üst; sınır sayı ya da "$rtt", "$rtt+200", "$rtt-10":
                                    koşunun nominal RTT'si (--latency-ms) ± ms (ör. çıkış kriteri 3)
    {"samples_players": {"count": 3, "min_slots": 100}}
        Her süreçte örneklerdeki oyuncu sayısı ilk kez count'a ulaştıktan sonra hep count; o andan sonra en az
        min_slots dilim (oyuncu sayısı kararlı).
    {"mem_stable": {"warmup_sec": 60, "window": 5, "max_growth_mb": 24, "min_mb": 20}}
        "mem_mb" (mem_sample_sec): ısınma (= min(warmup_sec, son örnek zamanı / 4)) sonrası ilk window örneğin
        medyanından son window örneğin medyanına artış <= max_growth_mb; en az 2 x window örnek gerekir;
        isteğe bağlı min_mb: ısınma sonrası her örnek >= min_mb; son örnek >= quit_after - 2 x mem_sample_sec
        (dökümdeki "mem_meta"). Boş "procs" listesi FAIL'dir (samples_players için de).
    {"samples_near": {"max_px": 32, "min_moving": 5, "move_px": 1.0}}
        Duvar saatine hizalı aynı örnek diliminde (samples[].slot) her oyuncunun süreçler arası en büyük
        konum farkı < max_px; oyuncunun önceki ortak dilime göre move_px'ten fazla yer değiştirdiği
        en az min_moving karşılaştırma bulunmalı (hareket sırasında ölçüldüğünün kanıtı). Geçersiz konum ya da
        bir sürecin örneklerinde hiç görünmeyen oyuncu da başarısızlıktır.
        Eşik: fikstür oyuncuyla (tests/fixtures/dummy_player.tscn) max_px 40 — fikstürde ara değerleme yok ve
        istemciler arası konum host üzerinden iki bacak gider (150 ms'de 35 px görüldü; IS-010 t1). Gerçek oyuncu
        sahnesiyle (US-004) max_px 32.
Değerlendirilemeyen beklenti (bozuk argüman, eksik alan) istisna fırlatmaz, FAIL sayılır.
"""

from __future__ import annotations

import argparse
import ctypes
import json
import math
import os
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import threading
import time
from dataclasses import dataclass, field
from typing import Any, Callable, Iterable

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, os.path.join(ROOT, "tools"))

from latency_proxy import LatencyProxy  # noqa: E402

READY_MARKER = "INSIDERS_READY"
DEFAULT_PLAYER_SCENE = "res://tests/fixtures/dummy_player.tscn"
HOST_READY_TIMEOUT = 20.0
LINGER_SEC = 1.0  # main.gd QUIT_LINGER_SEC
# İki istemci aynı host poll'unda koparsa Godot 4.7 SceneMultiplayer._del_peer (server relay) diğer kopuk
# peer'a DEL_PEER yollamaya çalışıp "Unable to send packet on channel 0, max channels: 0" basar (motor içi,
# zararsız). Testlerde istemcilerin çıkışı bu kadar aralıkla kaydırılır; döküm anları yine bekleme payı içinde.
LEAVE_STAGGER = 0.3
# Tur ("loop") içeren bot dosyasında son tam tur, bot saatinde sürecin quit_after'ından bu kadar önce biter
# (expand_bot_loop). Bot saati süreç başlangıcından SONRA (yerel oyuncu doğunca: açılış + bağlanma, ~1-2 sn)
# başladığından gerçek pay bu değer eksi doğma gecikmesidir.
BOT_LOOP_END_MARGIN = 4.0
SCENARIO_KEYS = {
    "_doc", "level", "player_scene", "clients", "duration", "start_delay", "quit_after", "bots", "names",
    "exit_codes", "allow_log", "timeout", "expect", "deny_warnings", "mem_sample_sec",
}
# --latency-ms > 0 iken gecikmenin gerçekten uygulandığının kanıtı: ölçülen ping >= bu oran x gecikme.
LATENCY_PROOF_RATIO = 0.8
ERROR_LINE = re.compile(r"^\s*(SCRIPT |USER )?ERROR:")
WARNING_LINE = re.compile(r"^\s*(SCRIPT |USER )?WARNING:")
ANSI = re.compile(r"\x1b\[[0-9;]*m")
MISSING = object()
WINDOWS = os.name == "nt"
KILL_GRACE_SEC = 2.0


def popen_group_kwargs() -> dict[str, Any]:
    """Süreci kendi grubunda başlatan Popen argümanları (zaman aşımında bütün çocuklarıyla öldürülebilsin)."""
    if WINDOWS:
        return {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP}
    return {"start_new_session": True}


def descendants_from_table(
    root_pid: int,
    table: Iterable[tuple[int, int]],
    ctime: Callable[[int], int | None],
    known: dict[int, int] | None = None,
) -> dict[int, int]:
    """Süreç tablosundan (pid, ebeveyn pid) root_pid'in torunlarını {pid: oluşturma zamanı} olarak döner.

    Windows ölü ebeveyni yeniden bağlamaz ve pid'ler yeniden kullanılır: bir sürecin th32ParentProcessID'si
    çoktan ölmüş ilgisiz bir sürecin pid'i olabilir. Bu yüzden (psutil yöntemi) çocuk yalnız oluşturma zamanı
    ebeveyninkinden ÖNCE DEĞİLSE ağaca girer; ebeveynin zamanı alınamazsa (ölmüş) kökün zamanı alt sınırdır ve
    kökten önce oluşmuş hiçbir süreç ağaca girmez. Kökün zamanı alınamazsa ağaç boştur.
    known: önceki taramada doğrulanmış torunlar {pid: zaman}; aradaki düğüm sonradan ölse de onun çocukları
    kayıtlı zamanla aranır (ör. CTRL_BREAK ile ölen ara süreç, sinyali yok sayan torunu). Kayıtlı düğümün pid'i
    şimdi başka bir sürece aitse (şimdiki oluşturma zamanı kayıttan farklı; IS-013 AC5) çocukları aranmaz:
    onlar yeni (ilgisiz) sürecin çocuklarıdır. Düğümün kendisi sonuçta kalır; öldürme adımı zaten yalnız
    zamanı kayıtla eşleşen pid'leri öldürür.
    ctime(pid): canlı (ya da tutamağı açık) sürecin oluşturma zamanı, yoksa None.
    """
    floor = ctime(root_pid)
    if floor is None:
        return {}
    known = dict(known or {})
    children: dict[int, list[int]] = {}
    for pid, ppid in table:
        if pid != ppid:
            children.setdefault(ppid, []).append(pid)
    out: dict[int, int] = {}
    todo = [root_pid] + [p for p in known if p != root_pid]
    seen = set(todo)
    while todo:
        node = todo.pop()
        if node != root_pid and node in known:
            now_t = ctime(node)
            if now_t is not None and now_t != known[node]:
                continue  # pid yeniden kullanılmış: kayıtlı ara düğüm artık başka süreç
        node_t = floor if node == root_pid else known.get(node, out.get(node))
        if node_t is None:
            node_t = floor
        for pid in children.get(node, []):
            if pid in seen:
                continue
            t = ctime(pid)
            if t is None or t < node_t or t < floor:
                continue  # ölmüş, erişilemiyor ya da pid'i yeniden kullanılmış ilgisiz (daha eski) süreç
            seen.add(pid)
            out[pid] = t
            todo.append(pid)
    for pid, t in known.items():
        out.setdefault(pid, t)
    out.pop(root_pid, None)
    return out


def _win_kernel32() -> Any:
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.restype = ctypes.c_void_p
    kernel32.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
    kernel32.GetProcessTimes.argtypes = [ctypes.c_void_p] + [ctypes.POINTER(ctypes.c_uint64)] * 4
    kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
    kernel32.CreateToolhelp32Snapshot.restype = ctypes.c_void_p
    kernel32.CreateToolhelp32Snapshot.argtypes = [ctypes.c_uint32, ctypes.c_uint32]
    return kernel32


def _windows_ctime(pid: int) -> int | None:
    """Sürecin oluşturma zamanı (FILETIME, 100 ns). Süreç yoksa ya da açılamıyorsa None. Ölmüş ama tutamağı
    açık süreç (ör. bekletilmemiş Popen) hâlâ açılır: pid'i de o sürece kilitlidir, yeniden kullanılamaz."""
    kernel32 = _win_kernel32()
    handle = kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
    if not handle:
        return None
    try:
        times = [ctypes.c_uint64() for _ in range(4)]
        if not kernel32.GetProcessTimes(handle, *[ctypes.byref(t) for t in times]):
            return None
        return times[0].value
    finally:
        kernel32.CloseHandle(handle)


def _windows_process_table() -> list[tuple[int, int]]:
    """Toolhelp32 anlık görüntüsü: [(pid, ebeveyn pid)]."""

    class ProcessEntry32W(ctypes.Structure):
        _fields_ = [
            ("dwSize", ctypes.c_uint32),
            ("cntUsage", ctypes.c_uint32),
            ("th32ProcessID", ctypes.c_uint32),
            ("th32DefaultHeapID", ctypes.c_size_t),
            ("th32ModuleID", ctypes.c_uint32),
            ("cntThreads", ctypes.c_uint32),
            ("th32ParentProcessID", ctypes.c_uint32),
            ("pcPriClassBase", ctypes.c_long),
            ("dwFlags", ctypes.c_uint32),
            ("szExeFile", ctypes.c_wchar * 260),
        ]

    kernel32 = _win_kernel32()
    kernel32.Process32FirstW.argtypes = [ctypes.c_void_p, ctypes.POINTER(ProcessEntry32W)]
    kernel32.Process32NextW.argtypes = [ctypes.c_void_p, ctypes.POINTER(ProcessEntry32W)]
    snap = kernel32.CreateToolhelp32Snapshot(0x2, 0)  # TH32CS_SNAPPROCESS
    if snap in (None, ctypes.c_void_p(-1).value):
        return []
    table: list[tuple[int, int]] = []
    try:
        entry = ProcessEntry32W()
        entry.dwSize = ctypes.sizeof(ProcessEntry32W)
        ok = kernel32.Process32FirstW(snap, ctypes.byref(entry))
        while ok:
            table.append((entry.th32ProcessID, entry.th32ParentProcessID))
            ok = kernel32.Process32NextW(snap, ctypes.byref(entry))
    finally:
        kernel32.CloseHandle(snap)
    return table


def _windows_descendants(root_pid: int, known: dict[int, int] | None = None) -> dict[int, int]:
    return descendants_from_table(root_pid, _windows_process_table(), _windows_ctime, known)


def _windows_private_bytes(pid: int) -> int | None:
    """Sürecin özel (paylaşılmayan) belleği, bayt (PROCESS_MEMORY_COUNTERS_EX.PrivateUsage); okunamazsa None."""

    class Counters(ctypes.Structure):
        _fields_ = [("cb", ctypes.c_uint32), ("PageFaultCount", ctypes.c_uint32)] + [
            (n, ctypes.c_size_t)
            for n in (
                "PeakWorkingSetSize", "WorkingSetSize", "QuotaPeakPagedPoolUsage", "QuotaPagedPoolUsage",
                "QuotaPeakNonPagedPoolUsage", "QuotaNonPagedPoolUsage", "PagefileUsage", "PeakPagefileUsage",
                "PrivateUsage",
            )
        ]

    kernel32 = _win_kernel32()
    kernel32.K32GetProcessMemoryInfo.argtypes = [ctypes.c_void_p, ctypes.POINTER(Counters), ctypes.c_uint32]
    handle = kernel32.OpenProcess(0x1000 | 0x0010, False, pid)  # QUERY_LIMITED_INFORMATION | VM_READ
    if not handle:
        return None
    try:
        c = Counters()
        c.cb = ctypes.sizeof(Counters)
        if not kernel32.K32GetProcessMemoryInfo(handle, ctypes.byref(c), c.cb):
            return None
        return int(c.PrivateUsage)
    finally:
        kernel32.CloseHandle(handle)


def _linux_private_bytes(pid: int) -> int | None:
    """/proc/<pid>/status RssAnon (anonim yerleşik bellek; özel belleğe en yakın ölçü), bayt."""
    try:
        with open(f"/proc/{pid}/status", encoding="ascii", errors="replace") as f:
            for line in f:
                if line.startswith("RssAnon:"):
                    return int(line.split()[1]) * 1024
    except (OSError, ValueError, IndexError):
        return None
    return None


def _linux_descendants(root_pid: int) -> list[int]:
    """/proc/<pid>/stat ebeveyn alanından root_pid'in canlı torunları (Linux). Linux ölü ebeveynin çocuğunu
    init'e bağladığından pid yeniden kullanımı ağaca ilgisiz süreç sokmaz (yalnız anlık görüntü)."""
    children: dict[int, list[int]] = {}
    try:
        names = os.listdir("/proc")
    except OSError:
        return []
    for name in names:
        if not name.isdigit():
            continue
        try:
            with open(f"/proc/{name}/stat", encoding="ascii", errors="replace") as f:
                ppid = int(f.read().rsplit(")", 1)[1].split()[1])
        except (OSError, ValueError, IndexError):
            continue
        children.setdefault(ppid, []).append(int(name))
    out: list[int] = []
    todo = [root_pid]
    while todo:
        for pid in children.get(todo.pop(), []):
            if pid not in out:
                out.append(pid)
                todo.append(pid)
    return out


def process_tree_memory_mb(popen: subprocess.Popen) -> float | None:
    """Süreç ağacının özel belleği (MB): kök + torunların toplamı. Windows'ta Godot console exe'si (~1 MB)
    asıl (belleği tutan) exe'yi çocuk olarak başlatır; torunlar oluşturma zamanıyla doğrulanır. Linux'ta
    /proc ile. Diğer platformlarda ölçülmez. Kök ölmüşse ya da hiçbir değer okunamazsa None."""
    if popen.poll() is not None:
        return None
    if WINDOWS:
        pids = [popen.pid] + list(_windows_descendants(popen.pid))
        values = [_windows_private_bytes(p) for p in pids]
    else:
        values = [_linux_private_bytes(p) for p in [popen.pid] + _linux_descendants(popen.pid)]
    known = [v for v in values if v is not None]
    return sum(known) / (1024.0 * 1024.0) if known else None


def kill_process_tree(popen: subprocess.Popen, grace: float = KILL_GRACE_SEC) -> None:
    """popen_group_kwargs() ile başlatılmış süreci ve çocuklarını öldürür: önce zarif sinyal, grace sn sonra zorla."""
    if WINDOWS:
        # Torunlar sinyalden önce de toplanır: ara süreç CTRL_BREAK ile ölüp torunu yaşarsa ebeveyn zinciri kopar.
        # `taskkill /T` kullanılmaz (kendi ağaç taraması pid yeniden kullanımına karşı zaman denetimi yapmaz);
        # yalnız oluşturma zamanıyla doğrulanmış açık pid'ler öldürülür. Kök, Popen tutamağıyla öldürülür.
        tree = _windows_descendants(popen.pid)
        try:
            popen.send_signal(signal.CTRL_BREAK_EVENT)  # süreç grubuna; konsol paylaşılmıyorsa OSError
            popen.wait(timeout=grace)
        except (OSError, subprocess.TimeoutExpired):
            pass
        tree = _windows_descendants(popen.pid, known=tree)
        if popen.poll() is None:
            try:
                popen.kill()  # TerminateProcess(kendi tutamağımız)
            except OSError:
                pass
        victims = [pid for pid, t in tree.items() if _windows_ctime(pid) == t]  # hâlâ aynı süreç mi
        if victims:
            args = ["taskkill", "/F"]
            for pid in victims:
                args += ["/PID", str(pid)]
            subprocess.run(args, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
        try:
            popen.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            pass
        return
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(popen.pid, sig)
        except (ProcessLookupError, PermissionError):
            return
        try:
            popen.wait(timeout=grace)
            return
        except subprocess.TimeoutExpired:
            continue


@dataclass
class Proc:
    name: str
    cmd: list[str]
    dump_path: str
    quit_after: float
    popen: subprocess.Popen | None = None
    lines: list[str] = field(default_factory=list)
    ready: threading.Event = field(default_factory=threading.Event)
    reader: threading.Thread | None = None
    started_at: float = 0.0
    exit_code: int | None = None
    killed: bool = False
    # Bellek örnekleri [(süreç başlangıcından sn, MB)] (senaryoda mem_sample_sec verildiyse).
    mem: list[tuple[float, float]] = field(default_factory=list)

    def start(self) -> None:
        self.started_at = time.monotonic()
        self.popen = subprocess.Popen(
            self.cmd,
            cwd=ROOT,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            stdin=subprocess.DEVNULL,
            text=True,
            errors="replace",
            **popen_group_kwargs(),  # süreç grubu: zaman aşımında bütün çocuklarıyla öldürülür
        )
        self.reader = threading.Thread(target=self._read, daemon=True)
        self.reader.start()

    def _read(self) -> None:
        assert self.popen is not None and self.popen.stdout is not None
        for raw in self.popen.stdout:
            line = ANSI.sub("", raw.rstrip("\n"))
            self.lines.append(line)
            if line.startswith(READY_MARKER):
                self.ready.set()

    def kill(self) -> None:
        if self.popen is None or self.popen.poll() is not None:
            return
        self.killed = True
        kill_process_tree(self.popen)

    def finish(self) -> None:
        if self.popen is None:
            return
        self.exit_code = self.popen.poll()
        if self.reader is not None:
            self.reader.join(timeout=2.0)
        if self.popen.stdout is not None:
            self.popen.stdout.close()


def free_udp_port() -> int:
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.bind(("", 0))
        return s.getsockname()[1]


def res_to_path(res: str) -> str:
    """res://a/b.json → <ROOT>/a/b.json; diğer yollar olduğu gibi."""
    return os.path.join(ROOT, *res[len("res://"):].split("/")) if res.startswith("res://") else res


def expand_bot_loop(raw: dict, until: float) -> dict:
    """Bot dosyasının "loop" bölümünü açar (IS-013, dayanıklılık koşusu). Biçim (S6 bot dosyasına ek; Godot
    "loop"u yok sayar, dosya tek başına bir tur oynar):
        {"loop": {"from": F, "period": P}, "steps": [...]}
    t < F adımları bir kez (giriş), t >= F adımları [F, F + P) aralığında bir tur sayılır ve yalnız TAM turlar
    eklenir: F + (k + 1)·P <= until olan k = 0, 1, ... (yarım tur yok: döküm anında bot turun sonundaki
    bilinen durumdadır, ör. her turda iki kez çevrilen kapı başlangıç durumunda). "loop" yoksa dosya olduğu
    gibi döner. Bozuk biçim ValueError.
    Kare sınırı: bot saati her fizik karesinde 1/60 sn ilerler ve adım `t <= saat` olan ilk karede uygulanır.
    Tur adımlarının (ve t + dur) zamanları kare sınırına (t·60 tam sayı) düşmemeli, period·60 tam sayı
    olmalı: aksi halde kayan nokta birikimi yüzünden bir bacak turdan tura ±1 kare değişir ve uzun koşuda
    son konum kayar (test_net_smoke ExpandBotLoopTest bunu depodaki tur dosyaları için denetler).
    """
    loop = raw.get("loop")
    if loop is None:
        return raw
    if not isinstance(loop, dict) or set(loop) != {"from", "period"}:
        raise ValueError('"loop" {"from": sn, "period": sn} olmalı')
    start, period = float(loop["from"]), float(loop["period"])
    if period <= 0 or start < 0:
        raise ValueError("loop.period > 0 ve loop.from >= 0 olmalı")
    steps = raw.get("steps")
    if not isinstance(steps, list):
        raise ValueError('"steps" liste olmalı')
    prelude = [s for s in steps if float(s["t"]) < start]
    body = [s for s in steps if float(s["t"]) >= start]
    late = [s for s in body if float(s["t"]) >= start + period]
    if late:
        raise ValueError(f"tur adımı [from, from + period) dışında: {late[0]!r}")
    out = [dict(s) for s in prelude]
    k = 0
    while body and start + (k + 1) * period <= until + 1e-9:
        out.extend({**s, "t": round(float(s["t"]) + k * period, 4)} for s in body)
        k += 1
    return {"steps": out}


def find_godot() -> str:
    env = os.environ.get("GODOT")
    if env:
        return env
    # shutil.which: Windows'ta CreateProcess "bash"ı PATH'ten önce System32'de (WSL) arar; Git Bash'inki seçilsin.
    bash = shutil.which("bash") or "bash"
    out = subprocess.run([bash, os.path.join(ROOT, "tools", "get_godot.sh")], capture_output=True, text=True, check=True)
    return out.stdout.strip().splitlines()[-1]


# --- beklenti değerlendirme ---


RTT_BOUND = re.compile(r"^\$rtt\s*(?:([+-])\s*(\d+(?:\.\d+)?))?$")


class Evaluator:
    def __init__(self, dumps: dict[str, dict | None], rtt_ms: float = 0.0) -> None:
        self.dumps = dumps
        self.procs = list(dumps.keys())
        self.rtt_ms = rtt_ms

    def bound(self, v: Any) -> float:
        """Sayı ya da "$rtt", "$rtt+200", "$rtt-10": koşunun nominal RTT'si (--latency-ms) ± ms."""
        if isinstance(v, (int, float)) and not isinstance(v, bool):
            return float(v)
        m = RTT_BOUND.match(v.strip()) if isinstance(v, str) else None
        if m is None:
            raise ValueError(f"sınır sayı ya da $rtt[+-ms] olmalı: {v!r}")
        extra = float(m.group(2) or 0.0)
        return self.rtt_ms + (extra if m.group(1) != "-" else -extra)

    def _peer_id(self, proc: str) -> Any:
        d = self.dumps.get(proc)
        return d.get("peer_id", MISSING) if isinstance(d, dict) else MISSING

    def subst(self, text: str) -> str:
        def repl(m: re.Match) -> str:
            pid = self._peer_id(m.group(1))
            return str(pid) if pid is not MISSING else m.group(0)

        return re.sub(r"\$([A-Za-z0-9_]+)", repl, text)

    def resolve(self, path: str) -> Any:
        parts = self.subst(path).split(".")
        cur: Any = self.dumps.get(parts[0], MISSING)
        if cur is None:
            return MISSING
        for part in parts[1:]:
            if isinstance(cur, dict) and part in cur:
                cur = cur[part]
            elif isinstance(cur, list) and re.fullmatch(r"-?\d+", part) and -len(cur) <= int(part) < len(cur):
                cur = cur[int(part)]
            else:
                return MISSING
        return cur

    def expand(self, path: str) -> list[str]:
        if path.startswith("*."):
            return [p + path[1:] for p in self.procs]
        return [path]

    @staticmethod
    def same(a: Any, b: Any) -> bool:
        if isinstance(a, bool) or isinstance(b, bool):
            return a is b or (isinstance(a, bool) and isinstance(b, bool) and a == b)
        if isinstance(a, (int, float)) and isinstance(b, (int, float)):
            return math.isclose(float(a), float(b), rel_tol=0.0, abs_tol=1e-9)
        return a == b

    @staticmethod
    def distance(a: Any, b: Any) -> float | None:
        if isinstance(a, (int, float)) and isinstance(b, (int, float)) and not isinstance(a, bool):
            return abs(float(a) - float(b))
        if isinstance(a, list) and isinstance(b, list) and len(a) == len(b) and a:
            if all(isinstance(x, (int, float)) for x in a + b):
                return math.sqrt(sum((float(x) - float(y)) ** 2 for x, y in zip(a, b)))
        return None

    def check(self, exp: dict) -> list[tuple[bool, str]]:
        if not isinstance(exp, dict) or len(exp) != 1:
            return [(False, f"geçersiz beklenti: {exp!r}")]
        op, arg = next(iter(exp.items()))
        fn = getattr(self, "op_" + op, None)
        if fn is None:
            return [(False, f"bilinmeyen beklenti: {op}")]
        try:
            return fn(arg)
        except Exception as e:  # noqa: BLE001 — bozuk beklenti/döküm testi çökertmesin, FAIL olsun
            return [(False, f"{op}: değerlendirilemedi {short(arg)} ({type(e).__name__}: {e})")]

    def _single(self, arg: list, label: str, test) -> list[tuple[bool, str]]:
        if not isinstance(arg, list) or not isinstance(arg[0], str):
            raise TypeError("[yol, ...] listesi bekleniyordu")
        out = []
        for path in self.expand(arg[0]):
            v = self.resolve(path)
            if v is MISSING:
                out.append((False, f"{label}: {path} yok"))
                continue
            ok, detail = test(v)
            out.append((ok, f"{label}: {path} = {short(v)} {detail}"))
        return out

    def op_eq(self, arg: list) -> list[tuple[bool, str]]:
        want = arg[1]
        return self._single(arg, "eq", lambda v: (self.same(v, want), f"(beklenen {short(want)})"))

    def op_ne(self, arg: list) -> list[tuple[bool, str]]:
        bad = arg[1]
        return self._single(arg, "ne", lambda v: (not self.same(v, bad), f"(olmamalı {short(bad)})"))

    def op_len(self, arg: list) -> list[tuple[bool, str]]:
        n = int(arg[1])
        return self._single(
            arg, "len", lambda v: (isinstance(v, (list, dict)) and len(v) == n, f"(uzunluk beklenen {n})")
        )

    def op_between(self, arg: list) -> list[tuple[bool, str]]:
        lo, hi = self.bound(arg[1]), self.bound(arg[2])
        return self._single(
            arg,
            "between",
            lambda v: (isinstance(v, (int, float)) and lo <= float(v) <= hi, f"(beklenen [{lo}, {hi}])"),
        )

    def _contains(self, container: Any, item: Any) -> bool:
        if isinstance(container, dict):
            return str(item) in container
        if isinstance(container, list):
            return any(str(x) == str(item) for x in container)
        return False

    def op_has(self, arg: list) -> list[tuple[bool, str]]:
        item = self.subst(arg[1]) if isinstance(arg[1], str) else arg[1]
        return self._single(arg, "has", lambda v: (self._contains(v, item), f"(içermeli {item})"))

    def op_lacks(self, arg: list) -> list[tuple[bool, str]]:
        item = self.subst(arg[1]) if isinstance(arg[1], str) else arg[1]
        if isinstance(item, str) and "$" in item:
            return [(False, f"lacks: {arg[1]} çözülemedi (süreç dökümü yok)")]
        return self._single(arg, "lacks", lambda v: (not self._contains(v, item), f"(içermemeli {item})"))

    def op_same(self, arg: list) -> list[tuple[bool, str]]:
        a, b = self.resolve(arg[0]), self.resolve(arg[1])
        if a is MISSING or b is MISSING:
            return [(False, f"same: {arg[0]} ya da {arg[1]} yok")]
        return [(self.same(a, b), f"same: {arg[0]} = {short(a)}, {arg[1]} = {short(b)}")]

    def op_all_equal(self, arg: str) -> list[tuple[bool, str]]:
        values = {p: self.resolve(f"{p}.{arg}") for p in self.procs}
        missing = [p for p, v in values.items() if v is MISSING]
        if missing:
            return [(False, f"all_equal: {arg} şu süreçlerde yok: {', '.join(missing)}")]
        first = next(iter(values.values()))
        ok = all(self.same(v, first) for v in values.values())
        return [(ok, f"all_equal: {arg} = " + ", ".join(f"{p}:{short(v)}" for p, v in values.items()))]

    def op_near(self, arg: list) -> list[tuple[bool, str]]:
        tol = float(arg[2])
        out = []
        for path in self.expand(arg[0]):
            a = self.resolve(path)
            other = arg[1]
            b = self.resolve(other) if isinstance(other, str) else other
            if a is MISSING or b is MISSING:
                out.append((False, f"near: {path} ya da {other} yok"))
                continue
            d = self.distance(a, b)
            ok = d is not None and d <= tol
            dtext = "?" if d is None else f"{d:.2f}"
            out.append((ok, f"near: {path} = {short(a)}, {other} = {short(b)}, fark {dtext} (<= {tol})"))
        return out

    def op_samples_near(self, arg: dict) -> list[tuple[bool, str]]:
        max_px = float(arg.get("max_px", 32))
        min_moving = int(arg.get("min_moving", 1))
        move_px = float(arg.get("move_px", 1.0))
        by_proc: dict[str, dict[int, dict]] = {}
        for p in arg.get("procs", self.procs):
            samples = self.resolve(f"{p}.samples")
            if samples is MISSING or not isinstance(samples, list):
                return [(False, f"samples_near: {p}.samples yok")]
            by_proc[p] = {int(s["slot"]): s.get("players", {}) for s in samples if isinstance(s, dict)}
        problems: list[str] = []
        seen = {p: {pid for slot in v.values() for pid in slot} for p, v in by_proc.items()}
        everyone = set().union(*seen.values()) if seen else set()
        for p, ids_seen in seen.items():
            for pid in sorted(everyone - ids_seen):
                problems.append(f"{p} örneklerinde peer {pid} hiç yok")
        common = sorted(set.intersection(*(set(v) for v in by_proc.values()))) if by_proc else []
        worst = (0.0, None, None)
        compared = moving = 0
        prev: dict[str, list] = {}
        for slot in common:
            views = [by_proc[p][slot] for p in by_proc]
            ids = set.intersection(*(set(v) for v in views))
            for pid in ids:
                positions = [v[pid] for v in views]
                dists = [self.distance(a, b) for a in positions for b in positions]
                if any(x is None for x in dists):
                    problems.append(f"dilim {slot} peer {pid}: geçersiz konum {short(positions)}")
                    continue
                d = max(x for x in dists if x is not None)
                compared += 1
                if d > worst[0]:
                    worst = (d, slot, pid)
                ref = positions[0]
                if pid in prev and (self.distance(prev[pid], ref) or 0.0) > move_px:
                    moving += 1
                prev[pid] = ref
        ok = not problems and compared > 0 and worst[0] < max_px and moving >= min_moving
        text = (
            f"samples_near: {len(common)} ortak dilim, {compared} karşılaştırma, {moving} hareketli; "
            f"en büyük fark {worst[0]:.2f} px (dilim {worst[1]}, peer {worst[2]}) < {max_px}, "
            f"hareketli >= {min_moving}"
        )
        if problems:
            text += "; " + "; ".join(problems[:5])
        return [(ok, text)]

    def op_samples_players(self, arg: dict) -> list[tuple[bool, str]]:
        """Oyuncu sayısı kararlı: her süreçte örneklerde oyuncu sayısı ilk kez `count`'a ulaştıktan sonra
        hep `count` kalır ve bu durumda en az `min_slots` örnek dilimi vardır."""
        count = int(arg["count"])
        min_slots = int(arg.get("min_slots", 1))
        procs = arg.get("procs", self.procs)
        if not procs:
            return [(False, "samples_players: süreç listesi boş")]
        out = []
        for p in procs:
            samples = self.resolve(f"{p}.samples")
            if not isinstance(samples, list):
                out.append((False, f"samples_players: {p}.samples yok"))
                continue
            sizes = [len(s.get("players", {})) for s in samples if isinstance(s, dict)]
            first = next((i for i, n in enumerate(sizes) if n == count), None)
            if first is None:
                out.append((False, f"samples_players: {p} hiç {count} oyuncuya ulaşmadı ({len(sizes)} dilim)"))
                continue
            after = sizes[first:]
            bad = [n for n in after if n != count]
            ok = not bad and len(after) >= min_slots
            out.append((ok, (
                f"samples_players: {p} {count} oyuncu {len(after)} dilim (>= {min_slots}), sapma {len(bad)}"
                + (f" (ör. {bad[0]} oyuncu)" if bad else "")
            )))
        return out

    def op_mem_stable(self, arg: dict) -> list[tuple[bool, str]]:
        """Bellek kararlı (mem_sample_sec ile örneklenen "mem_mb"): ısınma sonrası ilk `window` örneğin medyanı
        ile son `window` örneğin medyanı arasındaki artış <= max_growth_mb. Isınma = min(warmup_sec, son
        örnek zamanının dörtte biri) (kısa koşuda da değerlendirilsin); en az 2 x window örnek gerekir.
        min_mb (isteğe bağlı): ısınma sonrası her örnek >= min_mb (gerçek Godot sürecinin ölçüldüğünün kanıtı;
        Windows'ta yalnız console sarmalayıcısı ~1 MB). Kapsam: "mem_meta" varsa son örnek >= quit_after -
        2 x every olmalı (örnekleme koşu sonuna kadar sürdü)."""
        warmup = float(arg.get("warmup_sec", 60.0))
        window = int(arg.get("window", 5))
        max_growth = float(arg["max_growth_mb"])
        min_mb = float(arg.get("min_mb", 0.0))
        procs = arg.get("procs", self.procs)
        if not procs:
            return [(False, "mem_stable: süreç listesi boş")]
        out = []
        for p in procs:
            mem = self.resolve(f"{p}.mem_mb")
            if not isinstance(mem, list) or not mem:
                out.append((False, f"mem_stable: {p}.mem_mb yok (senaryoda mem_sample_sec?)"))
                continue
            last_t = float(mem[-1][0])
            meta = self.resolve(f"{p}.mem_meta")
            if isinstance(meta, dict):
                need = float(meta["quit_after"]) - 2.0 * float(meta["every"])
                if last_t < need:
                    out.append((False, f"mem_stable: {p} örnekleme erken bitti ({last_t:.0f} sn < {need:.0f})"))
                    continue
            w = min(warmup, last_t / 4.0)
            values = [float(mb) for t, mb in mem if float(t) >= w]
            if len(values) < 2 * window:
                out.append((False, f"mem_stable: {p} ısınma ({w:.0f} sn) sonrası {len(values)} örnek < {2 * window}"))
                continue
            first = sorted(values[:window])[window // 2]
            last = sorted(values[-window:])[window // 2]
            growth = last - first
            low = min(values)
            ok = growth <= max_growth and low >= min_mb
            out.append((ok, (
                f"mem_stable: {p} {first:.1f} → {last:.1f} MB (artış {growth:+.1f} <= {max_growth:g}; "
                f"en az {low:.1f} >= {min_mb:g}; en çok {max(values):.1f}; {len(values)} örnek "
                f"{last_t:.0f} sn'ye kadar, ısınma {w:.0f} sn)"
            )))
        return out


def short(v: Any, limit: int = 120) -> str:
    text = json.dumps(v, ensure_ascii=False, sort_keys=True) if v is not MISSING else "<yok>"
    return text if len(text) <= limit else text[: limit - 3] + "..."


# --- koşu ---


def load_scenario(path: str) -> tuple[dict | None, str]:
    """Senaryoyu okur ve doğrular; (senaryo, "") ya da (None, hata) döner."""
    try:
        with open(path, encoding="utf-8") as f:
            sc = json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        return None, f"senaryo okunamadı: {e}"
    if not isinstance(sc, dict):
        return None, "senaryo bir JSON nesnesi olmalı"
    unknown = sorted(set(sc) - SCENARIO_KEYS)
    if unknown:
        return None, f"bilinmeyen senaryo anahtarları: {', '.join(unknown)}"
    if not isinstance(sc.get("level"), str) or not sc["level"]:
        return None, "'level' zorunlu"
    if not isinstance(sc.get("expect"), list) or not sc["expect"]:
        return None, "'expect' boş olmayan bir liste olmalı"
    return sc, ""


def latency_proof(
    latency_ms: float, proxy: LatencyProxy, procs: dict[str, Proc], dumps: dict[str, dict | None]
) -> list[tuple[bool, str]]:
    """Gecikme gerçekten uygulandı mı: her istemci proxy'den geçti ve ölçülen ping >= oran x gecikme."""
    clients = [n for n in procs if n != "host"]
    out = [
        (
            proxy.stats["clients"] == len(clients),
            f"gecikme: proxy {proxy.stats['clients']} istemci eşledi (beklenen {len(clients)})",
        )
    ]
    floor = LATENCY_PROOF_RATIO * latency_ms
    host_pings = (dumps.get("host") or {}).get("ping_ms", {})
    for name in clients:
        d = dumps.get(name) or {}
        values = []
        if isinstance(d.get("ping_ms"), dict) and "1" in d["ping_ms"]:
            values.append(("kendi", d["ping_ms"]["1"]))
        pid = str(d.get("peer_id", ""))
        if isinstance(host_pings, dict) and pid in host_pings:
            values.append(("host", host_pings[pid]))
        ok = bool(values) and all(isinstance(v, (int, float)) and v >= floor for _, v in values)
        shown = ", ".join(f"{k} {v}" for k, v in values) or "ping yok"
        out.append((ok, f"gecikme: {name} ping ({shown}) >= {floor:g} ms"))
    return out


def log_failures(name: str, lines: list[str], allow: list[re.Pattern], deny_warnings: bool) -> list[str]:
    """Sürecin log'undaki başarısızlık satırları: ERROR (deny_warnings ise WARNING de), allow_log hariç."""
    out = []
    for line in lines:
        bad = ERROR_LINE.match(line) or (deny_warnings and WARNING_LINE.match(line))
        if bad and not any(r.search(line) for r in allow):
            out.append(f"{name} log {'hatası' if ERROR_LINE.match(line) else 'uyarısı'}: {line.strip()}")
    return out


def run(
    scenario_path: str,
    latency_ms: float,
    jitter_ms: float,
    loss: float,
    reorder: bool,
    keep: bool,
    verbose: bool,
    duration: float | None = None,
) -> int:
    sc, problem = load_scenario(scenario_path)
    if sc is None:
        print(f"FAIL {os.path.basename(scenario_path)}: {problem}")
        return 1
    if duration is not None:
        sc["duration"] = duration
    tmp = tempfile.mkdtemp(prefix="net_smoke_")
    try:
        return _run(sc, scenario_path, tmp, latency_ms, jitter_ms, loss, reorder, verbose)
    finally:
        if keep:
            print(f"  geçici dizin: {tmp}")
        else:
            shutil.rmtree(tmp, ignore_errors=True)


def _run(
    sc: dict,
    scenario_path: str,
    tmp: str,
    latency_ms: float,
    jitter_ms: float,
    loss: float,
    reorder: bool,
    verbose: bool,
) -> int:
    t_begin = time.monotonic()
    clients = int(sc.get("clients", 2))
    duration = float(sc.get("duration", 8))
    names = [f"c{i}" for i in range(1, clients + 1)]
    all_names = ["host"] + names
    start_delay = {k: float(v) for k, v in sc.get("start_delay", {}).items()}
    quit_override = {k: float(v) for k, v in sc.get("quit_after", {}).items()}
    bots = sc.get("bots", {})
    display = sc.get("names", {})
    exit_codes = {n: 0 for n in all_names}
    exit_codes.update({k: int(v) for k, v in sc.get("exit_codes", {}).items()})
    allow = [re.compile(p) for p in sc.get("allow_log", [])]
    level = sc["level"]
    player_scene = sc.get("player_scene", DEFAULT_PLAYER_SCENE)
    godot = find_godot()
    label = f"{os.path.basename(scenario_path)} ({latency_ms:g} ms"
    if latency_ms > 0 and (jitter_ms > 0 or loss > 0 or reorder):
        label += f", jitter {jitter_ms:g} ms, kayıp {loss:g}" + (", sıra bozuk" if reorder else "")
    label += ")"

    for name, path in bots.items():  # tur ("loop") biçimi süreçler başlamadan doğrulanır
        try:
            with open(res_to_path(path), encoding="utf-8") as f:
                expand_bot_loop(json.load(f), 1.0)
        except (OSError, ValueError, KeyError, TypeError) as e:
            print(f"FAIL {label}: {name} bot dosyası {path}: {e}")
            return 1

    host_port = free_udp_port()
    proxy: LatencyProxy | None = None
    join_port = host_port

    def bot_arg(name: str, quit_after: float) -> str:
        """Bot yolu; dosyada "loop" varsa açılmış kopyası geçici dizine yazılır: tam turlar, son tur bot
        saatinde quit_after - BOT_LOOP_END_MARGIN'de biter. Bot saati doğunca başladığından doğma gecikmesi
        dökümden önceki gerçek payı AZALTIR (pay = BOT_LOOP_END_MARGIN - doğma gecikmesi)."""
        path = bots[name]
        with open(res_to_path(path), encoding="utf-8") as f:
            raw = json.load(f)
        if "loop" not in raw:
            return path
        out = os.path.join(tmp, f"{name}.bot.json").replace("\\", "/")
        with open(out, "w", encoding="utf-8") as f:
            json.dump(expand_bot_loop(raw, quit_after - BOT_LOOP_END_MARGIN), f)
        return out

    def make(name: str, quit_after: float) -> Proc:
        user = [f"--name={display.get(name, name)}", f"--player-scene={player_scene}"]
        if name == "host":
            user += ["--host", f"--port={host_port}", f"--level={level}"]
        else:
            user += ["--join=127.0.0.1", f"--port={join_port}"]
        if name in bots:
            user.append(f"--bot={bot_arg(name, quit_after)}")
        dump = os.path.join(tmp, f"{name}.json")
        user += [f"--dump={dump}", f"--quit-after={quit_after:.2f}"]
        cmd = [godot, "--headless", "--path", ROOT, "--log-file", os.path.join(tmp, f"{name}.godot.log"), "--"]
        return Proc(name=name, cmd=cmd + user, dump_path=dump, quit_after=quit_after)

    procs: dict[str, Proc] = {}
    failures: list[str] = []
    mem_every = float(sc.get("mem_sample_sec", 0.0))
    mem_stop = threading.Event()

    def sample_memory() -> None:
        while not mem_stop.wait(mem_every):
            for proc in list(procs.values()):
                if proc.popen is None:
                    continue
                try:
                    mb = process_tree_memory_mb(proc.popen)
                except (OSError, ValueError, AttributeError):  # tek okuma hatası örneklemeyi durdurmasın
                    mb = None
                if mb is not None:
                    proc.mem.append((round(time.monotonic() - proc.started_at, 2), round(mb, 2)))

    sampler = threading.Thread(target=sample_memory, daemon=True) if mem_every > 0 else None
    try:
        if sampler is not None:
            sampler.start()
        if latency_ms > 0:
            proxy = LatencyProxy(
                target=("127.0.0.1", host_port),
                delay_ms=latency_ms / 2.0,
                jitter_ms=jitter_ms,
                loss=loss,
                reorder=reorder,
            )
            join_port = proxy.start()
        host = make("host", quit_override.get("host", duration))
        procs["host"] = host
        host.start()
        t0 = host.started_at
        while not host.ready.wait(0.05):
            if host.popen is not None and host.popen.poll() is not None:
                break
            if time.monotonic() - t0 > HOST_READY_TIMEOUT:
                break
        if not host.ready.is_set():
            failures.append(f"host {HOST_READY_TIMEOUT:g} sn içinde hazır olmadı")
        else:
            t_ready = time.monotonic()
            pending = sorted(names, key=lambda n: start_delay.get(n, 0.0))
            for name in pending:
                wait = t_ready + start_delay.get(name, 0.0) - time.monotonic()
                if wait > 0:
                    time.sleep(wait)
                elapsed = time.monotonic() - t0
                stagger = LEAVE_STAGGER * (int(name[1:]) - 1)
                qa = quit_override.get(name, max(1.0, duration - elapsed + stagger))
                proc = make(name, qa)
                procs[name] = proc
                proc.start()
        # Sert üst süre: en geç bitmesi gereken süreç + bekleme payı.
        ends = [p.started_at + p.quit_after for p in procs.values()]
        deadline = (t0 + float(sc["timeout"])) if "timeout" in sc else max(ends) + LINGER_SEC + 10.0
        for proc in procs.values():
            assert proc.popen is not None
            try:
                proc.popen.wait(timeout=max(0.1, deadline - time.monotonic()))
            except subprocess.TimeoutExpired:
                pass
    finally:
        mem_stop.set()
        if sampler is not None:
            sampler.join(timeout=5.0)
        for proc in procs.values():
            proc.kill()
            proc.finish()
        if proxy is not None:
            proxy.stop()

    deny_warnings = bool(sc.get("deny_warnings", False))
    for proc in procs.values():
        if proc.killed:
            failures.append(f"{proc.name} zaman aşımında öldürüldü")
        elif proc.exit_code != exit_codes.get(proc.name, 0):
            failures.append(f"{proc.name} çıkış kodu {proc.exit_code} (beklenen {exit_codes.get(proc.name, 0)})")
        failures.extend(log_failures(proc.name, proc.lines, allow, deny_warnings))
    for n in all_names:
        if n not in procs:
            failures.append(f"{n} başlatılmadı")

    dumps: dict[str, dict | None] = {}
    for name in all_names:
        proc = procs.get(name)
        d: dict | None = None
        if proc is not None and os.path.exists(proc.dump_path):
            try:
                with open(proc.dump_path, encoding="utf-8") as f:
                    d = json.load(f)
                d["exit_code"] = proc.exit_code
                if mem_every > 0:
                    d["mem_mb"] = [list(m) for m in proc.mem]
                    d["mem_meta"] = {"every": mem_every, "quit_after": proc.quit_after}
            except (OSError, json.JSONDecodeError, TypeError) as e:
                failures.append(f"{name} dökümü okunamadı: {e}")
                d = None
        elif proc is not None:
            failures.append(f"{name} döküm yazmadı")
        dumps[name] = d

    results: list[tuple[bool, str]] = []
    ev = Evaluator(dumps, rtt_ms=latency_ms)
    for exp in sc["expect"]:
        results.extend(ev.check(exp))
    if proxy is not None:
        results.extend(latency_proof(latency_ms, proxy, procs, dumps))
    failed = [r for r in results if not r[0]]

    ok = not failures and not failed
    elapsed = time.monotonic() - t_begin
    print(f"{'PASS' if ok else 'FAIL'} {label}: {len(results) - len(failed)}/{len(results)} beklenti, {elapsed:.1f} sn")
    if verbose or not ok:
        for passed, text in results:
            if verbose or not passed:
                print(f"  {'ok  ' if passed else 'FAIL'} {text}")
        for text in failures:
            print(f"  FAIL {text}")
    if verbose and proxy is not None:
        print(f"  proxy: {proxy.stats}")
    if verbose:
        for name in all_names:
            d = dumps.get(name) or {}
            print(f"  {name}: peer_id={d.get('peer_id')} ping_ms={d.get('ping_ms')} exit={d.get('exit_code')}")
    if not ok:
        for proc in procs.values():
            print(f"----- {proc.name} log ({' '.join(proc.cmd[-8:])}) -----")
            print("\n".join(proc.lines) if proc.lines else "(boş)")
    return 0 if ok else 1


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description="Çok süreçli Godot ağ duman testi (S6)")
    ap.add_argument("scenario")
    ap.add_argument("--latency-ms", type=float, default=0.0, help="RTT; >0 ise araya latency_proxy konur")
    ap.add_argument("--jitter-ms", type=float, default=0.0, help="yön başına ± jitter (yalnız --latency-ms ile)")
    ap.add_argument("--loss", type=float, default=0.0, help="yön başına kayıp olasılığı (yalnız --latency-ms ile)")
    ap.add_argument("--reorder", action="store_true", help="jitter paket sırasını bozabilsin (latency_proxy)")
    ap.add_argument("--keep", action="store_true", help="dökümleri/log'ları içeren geçici dizini silme")
    ap.add_argument("-v", "--verbose", action="store_true")
    ap.add_argument("--duration", type=float, default=None, help="senaryonun duration'ını ez (tools/soak.sh)")
    args = ap.parse_args(argv)
    # SIGTERM (ör. CI iptali) SystemExit'e çevrilir: finally blokları çalışır, Godot süreçleri öldürülür.
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    if hasattr(signal, "SIGBREAK"):  # Windows: CTRL_BREAK_EVENT (SIGTERM'in karşılığı)
        signal.signal(signal.SIGBREAK, lambda *_: sys.exit(143))
    return run(
        args.scenario, args.latency_ms, args.jitter_ms, args.loss, args.reorder, args.keep, args.verbose, args.duration
    )


if __name__ == "__main__":
    sys.exit(main())
