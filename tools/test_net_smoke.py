#!/usr/bin/env python3
"""tools/net_smoke.py süreç ağacı öldürme ve zaman aşımı yolu testleri (IS-011 AC2). Yalnız standart kütüphane.

Koşu: python3 tools/test_net_smoke.py   (Windows'ta `python` ya da `py -3`; tools/ci_local.sh `tools` adımı)
Godot gerekmez: Godot yerine çocuk + torun süreç açan, sonra asılı kalan küçük Python betikleri kullanılır.
POSIX'te ayrı oturum + killpg (SIGTERM → SIGKILL); Windows'ta ayrı süreç grubu + CTRL_BREAK → kök
TerminateProcess, oluşturma zamanıyla süzülmüş torunlar taskkill /F /PID (pid yeniden kullanımı: DescendantsFromTableTest).
"""

from __future__ import annotations

import ctypes
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import net_smoke  # noqa: E402

WINDOWS = os.name == "nt"
DEAD_WAIT_SEC = 10.0

# `hang.py <bayraklar>`: bayrak başına bir kuşak (ör. "101" = kök, çocuk, torun). Her kuşak bir sonrakini açar,
# onun READY satırını bekler, `INSIDERS_READY` ve `READY <kendi pid> <alt kuşak pid'leri>` basar, asılı kalır.
# Bayrak 1: o süreç zarif sinyalleri (SIGTERM/SIGINT/SIGBREAK) yok sayar; yalnız zorla yoldan (SIGKILL /
# TerminateProcess) ölür. Bayrak 0: varsayılan davranış (zarif sinyalle ölür).
HANG_SCRIPT = r"""
import os, signal, subprocess, sys, time
flags = sys.argv[1]
if flags[0] == "1":
    for n in ("SIGTERM", "SIGINT", "SIGBREAK"):
        if hasattr(signal, n):
            signal.signal(getattr(signal, n), signal.SIG_IGN)
below = []
if len(flags) > 1:
    child = subprocess.Popen([sys.executable, __file__, flags[1:]], stdout=subprocess.PIPE, text=True)
    line = ""
    while not line.startswith("READY"):
        line = child.stdout.readline()
        if not line:
            sys.exit(3)
    below = line.split()[1:]
print("INSIDERS_READY", flush=True)
print("READY", os.getpid(), *below, flush=True)
time.sleep(60.0)
"""


def pid_alive(pid: int) -> bool:
    if WINDOWS:
        kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
        kernel32.OpenProcess.restype = ctypes.c_void_p
        kernel32.OpenProcess.argtypes = [ctypes.c_uint32, ctypes.c_int, ctypes.c_uint32]
        kernel32.GetExitCodeProcess.argtypes = [ctypes.c_void_p, ctypes.POINTER(ctypes.c_uint32)]
        kernel32.CloseHandle.argtypes = [ctypes.c_void_p]
        handle = kernel32.OpenProcess(0x1000, False, pid)  # PROCESS_QUERY_LIMITED_INFORMATION
        if not handle:
            return False
        try:
            code = ctypes.c_uint32()
            if not kernel32.GetExitCodeProcess(handle, ctypes.byref(code)):
                return False
            return code.value == 259  # STILL_ACTIVE
        finally:
            kernel32.CloseHandle(handle)
    try:
        os.kill(pid, 0)
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    # Zombi (ölmüş, henüz toplanmamış) süreç de os.kill'e cevap verir; Linux'ta durumu okunur.
    try:
        with open(f"/proc/{pid}/stat", encoding="ascii") as f:
            return f.read().rsplit(")", 1)[1].split()[0] != "Z"
    except (OSError, IndexError):
        return True


def wait_dead(pids: list[int], timeout: float = DEAD_WAIT_SEC) -> list[int]:
    """timeout içinde ölmeyen pid'leri döner."""
    deadline = time.monotonic() + timeout
    alive = list(pids)
    while alive and time.monotonic() < deadline:
        alive = [p for p in alive if pid_alive(p)]
        if alive:
            time.sleep(0.05)
    return alive


def force_kill(pids: list[int]) -> None:
    """Test başarısız olsa da süreç asılı kalmasın."""
    for pid in pids:
        if not pid_alive(pid):
            continue
        if WINDOWS:
            subprocess.run(["taskkill", "/T", "/F", "/PID", str(pid)], capture_output=True, check=False)
        else:
            try:
                os.kill(pid, 9)
            except OSError:
                pass


class KillProcessTreeTest(unittest.TestCase):
    def setUp(self) -> None:
        self.tmp = tempfile.mkdtemp(prefix="test_net_smoke_")
        self.script = os.path.join(self.tmp, "hang.py")
        with open(self.script, "w", encoding="utf-8") as f:
            f.write(HANG_SCRIPT)
        self.pids: list[int] = []

    def tearDown(self) -> None:
        force_kill(self.pids)
        for name in os.listdir(self.tmp):
            os.remove(os.path.join(self.tmp, name))
        os.rmdir(self.tmp)

    def start_tree(self, flags: str) -> subprocess.Popen:
        """flags: kuşak başına sinyal yok sayma bayrağı (bkz. HANG_SCRIPT). self.pids = kökten aşağı pid'ler."""
        popen = subprocess.Popen(
            [sys.executable, self.script, flags],
            stdout=subprocess.PIPE,
            stdin=subprocess.DEVNULL,
            text=True,
            **net_smoke.popen_group_kwargs(),
        )
        assert popen.stdout is not None
        self.addCleanup(popen.stdout.close)
        line = ""
        while not line.startswith("READY"):
            line = popen.stdout.readline()
            if not line:
                force_kill([popen.pid])
                self.fail("asılı süreç ağacı hazır olmadı")
        self.pids = [int(p) for p in line.split()[1:]]
        self.assertEqual(len(self.pids), len(flags))
        self.assertEqual(self.pids[0], popen.pid)
        self.assertTrue(all(pid_alive(p) for p in self.pids), "ağaç başlangıçta canlı olmalı")
        return popen

    def assert_tree_killed(self, popen: subprocess.Popen, max_sec: float = 8.0) -> None:
        t0 = time.monotonic()
        net_smoke.kill_process_tree(popen, grace=0.5)
        self.assertEqual(wait_dead(self.pids), [], "süreç ağacında canlı süreç kaldı")
        self.assertIsNotNone(popen.poll())
        self.assertLess(time.monotonic() - t0, max_sec)

    def test_graceful_signal_kills_tree(self) -> None:
        self.assert_tree_killed(self.start_tree("00"))

    def test_forced_kill_when_signals_ignored(self) -> None:
        # Zarif sinyali yok sayan kök + çocuk: zorla yol (POSIX SIGKILL, Windows TerminateProcess/taskkill /F).
        self.assert_tree_killed(self.start_tree("11"))

    def test_dead_intermediate_grandchild_killed(self) -> None:
        """Kök ve torun sinyali yok sayar, aradaki çocuk sinyalle ölür (Windows'ta torunun ebeveyn zinciri kopar).

        Windows'ta torun yalnız sinyalden ÖNCE toplanan ağaç (`known`) sayesinde bulunur: ikinci taramada
        kökün çocuğu yoktur, torunun ebeveyni ölüdür. Bunu ayırt etmek için Windows'ta aynı ağaç bir de
        `known` atılarak öldürülür ve torunun bu kez sağ kaldığı gösterilir (sonra testin kendisi temizler).
        """
        self.assert_tree_killed(self.start_tree("101"))
        if not WINDOWS:
            return
        real = net_smoke._windows_descendants
        with mock.patch.object(net_smoke, "_windows_descendants", lambda pid, known=None: real(pid)):
            popen = self.start_tree("101")
            net_smoke.kill_process_tree(popen, grace=0.5)
        root, middle, grandchild = self.pids
        self.assertEqual(wait_dead([root, middle]), [])
        self.assertTrue(pid_alive(grandchild), "önceden toplama olmadan torun ölmemeliydi (test ayırt etmiyor)")
        force_kill([grandchild])
        self.assertEqual(wait_dead([grandchild]), [])

    def test_already_exited_process_is_noop(self) -> None:
        popen = subprocess.Popen([sys.executable, "-c", "pass"], **net_smoke.popen_group_kwargs())
        popen.wait(timeout=10)
        net_smoke.kill_process_tree(popen, grace=0.5)  # istisna fırlatmaz
        self.assertEqual(popen.returncode, 0)


class DescendantsFromTableTest(unittest.TestCase):
    """Sahte süreç tablosuyla ağaç süzme (Windows yolunun saf çekirdeği; her platformda koşar).

    Windows ölü ebeveyni yeniden bağlamaz ve pid'ler yeniden kullanılır: ebeveyn pid'i kökümüzle (ya da bir
    torunla) çakışan, ama ondan ÖNCE oluşmuş ilgisiz süreçler ağaca girmemeli.
    """

    # pid: oluşturma zamanı (None = ölmüş/erişilemez)
    TIMES = {
        100: 1000,  # kök (Popen)
        200: 1100,  # kökün gerçek çocuğu
        300: 1200,  # gerçek torun
        400: 500,  # ilgisiz: eski bir ebeveynin pid'i 100 idi (masaüstü oturumu gibi), kökten önce oluşmuş
        401: 600,  # 400'ün çocuğu (ilgisiz alt ağaç)
        402: 1300,  # 400'ün kökten SONRA oluşmuş çocuğu: 400 ağaçta olmadığından yine girmez
        500: 1050,  # ilgisiz: ebeveyni 200 pid'li ölmüş eski süreç; 200'den (1100) önce oluşmuş
        650: 1150,  # ölmüş ara düğüm (önceden toplandı, known); artık zamanı alınamıyor
        700: 1250,  # 650'nin gerçek çocuğu (ebeveyn zinciri kopuk)
        701: 900,  # ebeveyni 650 görünen ama kökten önce oluşmuş ilgisiz süreç
    }
    TABLE = [(100, 1), (200, 100), (300, 200), (400, 100), (401, 400), (402, 400), (500, 200), (700, 650), (701, 650)]

    def ctime(self, pid: int) -> int | None:
        return None if pid == 650 else self.TIMES.get(pid)

    def test_pid_reuse_excludes_older_unrelated_processes(self) -> None:
        tree = net_smoke.descendants_from_table(100, self.TABLE, self.ctime)
        self.assertEqual(tree, {200: 1100, 300: 1200})

    def test_known_dead_intermediate_keeps_real_children_only(self) -> None:
        tree = net_smoke.descendants_from_table(100, self.TABLE, self.ctime, known={650: 1150})
        self.assertEqual(sorted(tree), [200, 300, 650, 700])
        self.assertNotIn(701, tree)

    def test_unknown_root_time_gives_empty_tree(self) -> None:
        self.assertEqual(net_smoke.descendants_from_table(999, [(1, 999)], lambda p: None if p == 999 else 5), {})
        self.assertEqual(net_smoke.descendants_from_table(100, self.TABLE, lambda p: None if p == 100 else 2000), {})

    def test_known_reused_pid_children_not_searched(self) -> None:
        # IS-013 AC5: kayıtlı ara düğüm 650 (1150) ölmüş, pid'i sonradan ilgisiz bir sürece (1400) verilmiş;
        # o sürecin çocuğu 702 (1500) hem kökten hem kayıtlı zamandan sonra oluşmuş olsa da ağaca girmemeli.
        table = [(100, 1), (650, 9), (702, 650)]
        times = {100: 1000, 650: 1400, 702: 1500}
        tree = net_smoke.descendants_from_table(100, table, times.get, known={650: 1150})
        self.assertNotIn(702, tree)
        self.assertEqual(tree, {650: 1150})  # kayıt kalır; öldürme adımı zamanı eşleşmediği için dokunmaz
        # Aynı pid hâlâ aynı süreçse (zaman = kayıt) çocukları aranır.
        times[650] = 1150
        self.assertIn(702, net_smoke.descendants_from_table(100, table, times.get, known={650: 1150}))

    def test_process_born_before_root_never_enters(self) -> None:
        # Kökün zamanı mutlak alt sınırdır: ebeveyn (ölmüş, kayıtlı) zamanından sonra ama kökten önce oluşmuş
        # süreç de girmez.
        table = [(800, 100), (801, 800), (802, 800)]
        times = {100: 1000, 801: 950, 802: 1200}
        tree = net_smoke.descendants_from_table(100, table, times.get, known={800: 900})
        self.assertNotIn(801, tree)
        self.assertIn(802, tree)


class ExpandBotLoopTest(unittest.TestCase):
    """Bot dosyasındaki "loop" bölümünün açılması (IS-013 dayanıklılık koşusu)."""

    RAW = {
        "_doc": "x",
        "loop": {"from": 2.0, "period": 3.0},
        "steps": [
            {"t": 0.5, "move": [1, 0]},
            {"t": 2.0, "move": [0, 1]},
            {"t": 3.5, "hold": "sprint", "dur": 1.0},
            {"t": 4.5, "press": "interact"},
        ],
    }

    def test_without_loop_unchanged(self) -> None:
        raw = {"steps": [{"t": 1.0, "move": [1, 0]}]}
        self.assertIs(net_smoke.expand_bot_loop(raw, 100.0), raw)

    def test_prelude_once_and_only_complete_turns(self) -> None:
        out = net_smoke.expand_bot_loop(self.RAW, 9.9)  # turlar [2,5), [5,8); [8,11) yarım: eklenmez
        times = [s["t"] for s in out["steps"]]
        self.assertEqual(times, [0.5, 2.0, 3.5, 4.5, 5.0, 6.5, 7.5])
        self.assertEqual(out["steps"][5], {"t": 6.5, "hold": "sprint", "dur": 1.0})
        self.assertNotIn("loop", out)
        self.assertEqual(self.RAW["steps"][1]["t"], 2.0, "girdi değişmemeli")
        self.assertEqual([s["t"] for s in net_smoke.expand_bot_loop(self.RAW, 11.0)["steps"]][-1], 10.5)
        self.assertEqual(len(net_smoke.expand_bot_loop(self.RAW, 4.0)["steps"]), 1, "tam tur yoksa yalnız giriş")

    def test_bad_loop_rejected(self) -> None:
        bad = [
            {"loop": {"from": 0.0}, "steps": []},
            {"loop": {"from": 0.0, "period": 0.0}, "steps": []},
            {"loop": {"from": 0.0, "period": 1.0, "x": 1}, "steps": []},
            {"loop": {"from": 0.0, "period": 1.0}, "steps": [{"t": 1.5, "move": [0, 0]}]},  # turun dışında
            {"loop": {"from": 0.0, "period": 1.0}},
        ]
        for raw in bad:
            with self.assertRaises(ValueError, msg=repr(raw)):
                net_smoke.expand_bot_loop(raw, 10.0)

    @staticmethod
    def apply_frames(steps: list[dict], until: float) -> dict[float, int]:
        """entities/player/bot_timeline.gd aritmetiği: her fizik karesinde saat += 1/60 (float64) ve
        t <= saat olan adım o karede uygulanır; t + dur (basılı tutmanın bitişi) de aynı kuralla işler.
        Dönüş: zaman işareti -> uygulandığı kare."""
        marks = sorted({float(s["t"]) for s in steps} | {float(s["t"]) + float(s["dur"]) for s in steps if "dur" in s})
        out: dict[float, int] = {}
        clock, frame, i = 0.0, 0, 0
        while i < len(marks) and clock < until + 1.0:
            frame += 1
            clock += 1.0 / 60.0
            while i < len(marks) and marks[i] <= clock:
                out[marks[i]] = frame
                i += 1
        return out

    def turn_frame_patterns(self, raw: dict, until: float) -> set[tuple[int, ...]]:
        """Açılmış her turda, turun ilk adımından her işarete (adım ve t + dur) kaç kare geçtiği."""
        start, period = float(raw["loop"]["from"]), float(raw["loop"]["period"])
        body = [s for s in raw["steps"] if float(s["t"]) >= start]
        marks = sorted({float(s["t"]) for s in body} | {float(s["t"]) + float(s["dur"]) for s in body if "dur" in s})
        frames = self.apply_frames(net_smoke.expand_bot_loop(raw, until)["steps"], until)
        turns = int((until - start) // period)
        return {
            tuple(frames[round(m + k * period, 4)] - frames[round(marks[0] + k * period, 4)] for m in marks)
            for k in range(turns)
        }

    def test_boundary_times_change_leg_frames_between_turns(self) -> None:
        # İnceleme bulgusu (t2): eski soak_c2 turu 18.3 gibi kare sınırındaki (t·60 tam sayı) zamanlar
        # kullanıyordu; bacaklar turdan tura 16/17 kare oluyordu. Simülasyon bunu yakalamalı.
        old = {
            "loop": {"from": 12.8, "period": 8.0},
            "steps": [
                {"t": 12.8, "press": "interact"}, {"t": 13.4, "move": [0, 1]}, {"t": 15.2, "move": [0, 0]},
                {"t": 16.2, "move": [0, -1]}, {"t": 18.0, "move": [0, 0]}, {"t": 18.3, "move": [0, 1]},
                {"t": 18.58, "move": [0, 0]}, {"t": 19.0, "press": "interact"},
            ],
        }
        self.assertGreater(len(self.turn_frame_patterns(old, 600.0)), 1)

    def test_repo_loop_bots_keep_leg_frames_constant(self) -> None:
        # Depodaki her tur dosyasında: tur zamanları kare sınırından uzak, period·60 tam sayı ve 1 saatlik
        # açılımda her turun bacak kare sayıları aynı (uzun koşuda son konum kaymaz).
        bots_dir = os.path.join(net_smoke.ROOT, "tests", "net", "bots")
        checked = 0
        for name in sorted(os.listdir(bots_dir)):
            with open(os.path.join(bots_dir, name), encoding="utf-8") as f:
                raw = json.load(f)
            if "loop" not in raw:
                continue
            checked += 1
            period = float(raw["loop"]["period"])
            self.assertAlmostEqual(period * 60, round(period * 60), places=6, msg=name)
            for s in raw["steps"]:
                if float(s["t"]) < float(raw["loop"]["from"]):
                    continue
                for m in [float(s["t"])] + ([float(s["t"]) + float(s["dur"])] if "dur" in s else []):
                    frac = m * 60 - math.floor(m * 60)
                    self.assertTrue(0.1 < frac < 0.9, f"{name}: {m} kare sınırında (t·60 = {m * 60:.4f})")
            self.assertEqual(len(self.turn_frame_patterns(raw, 3600.0)), 1, name)
        self.assertGreaterEqual(checked, 3)

    def test_repo_soak_bots_are_valid_loops(self) -> None:
        for name in ("soak_host", "soak_c1", "soak_c2"):
            with open(os.path.join(net_smoke.ROOT, "tests", "net", "bots", name + ".json"), encoding="utf-8") as f:
                raw = json.load(f)
            out = net_smoke.expand_bot_loop(raw, 600.0)
            self.assertGreater(len(out["steps"]), len(raw["steps"]), name)
            times = [s["t"] for s in out["steps"]]
            self.assertEqual(times, sorted(times), name)


class EvaluatorExtrasTest(unittest.TestCase):
    """IS-013 beklenti eklemeleri: $rtt sınırı, samples_players, mem_stable; log uyarı denetimi."""

    @staticmethod
    def results(dumps: dict, exp: dict, rtt: float = 0.0) -> list[tuple[bool, str]]:
        return net_smoke.Evaluator(dumps, rtt_ms=rtt).check(exp)

    def test_rtt_bound(self) -> None:
        dumps = {"host": {"d": 300.0}}
        exp = {"between": ["host.d", 0, "$rtt+200"]}
        self.assertTrue(self.results(dumps, exp, rtt=150.0)[0][0])
        self.assertFalse(self.results(dumps, exp, rtt=0.0)[0][0])
        self.assertTrue(self.results(dumps, {"between": ["host.d", "$rtt", "$rtt + 1"]}, rtt=300.0)[0][0])
        self.assertTrue(self.results(dumps, {"between": ["host.d", 0, "$rtt-10"]}, rtt=310.0)[0][0])
        bad = self.results(dumps, {"between": ["host.d", 0, "$ping+1"]})
        self.assertFalse(bad[0][0])
        self.assertIn("değerlendirilemedi", bad[0][1])

    @staticmethod
    def samples(sizes: list[int]) -> list[dict]:
        return [{"slot": i, "players": {str(p): [0, 0] for p in range(n)}} for i, n in enumerate(sizes)]

    def test_samples_players(self) -> None:
        exp = {"samples_players": {"count": 3, "min_slots": 3}}
        ok = {"host": {"samples": self.samples([1, 2, 3, 3, 3])}, "c1": {"samples": self.samples([3, 3, 3])}}
        self.assertTrue(all(r[0] for r in self.results(ok, exp)))
        dropped = {"host": {"samples": self.samples([3, 3, 2, 3])}}
        self.assertFalse(self.results(dropped, exp)[0][0])
        never = {"host": {"samples": self.samples([1, 2, 2])}}
        self.assertFalse(self.results(never, exp)[0][0])
        short_run = {"host": {"samples": self.samples([1, 3, 3])}}
        self.assertFalse(self.results(short_run, exp)[0][0])
        self.assertFalse(self.results({"host": {}}, exp)[0][0])

    def test_mem_stable(self) -> None:
        exp = {"mem_stable": {"warmup_sec": 10, "window": 3, "max_growth_mb": 5}}
        flat = [[t, 50.0 + (0.5 if t % 2 else 0.0)] for t in range(0, 40, 2)]
        self.assertTrue(self.results({"host": {"mem_mb": flat}}, exp)[0][0])
        leak = [[t, 50.0 + t] for t in range(0, 40, 2)]
        res = self.results({"host": {"mem_mb": leak}}, exp)
        self.assertFalse(res[0][0])
        self.assertIn("artış", res[0][1])
        # Isınma son örnek zamanının dörtte birine kısılır; ısınmadaki büyük ilk değer sayılmaz.
        warm = [[0, 10.0], [2, 50.0], [4, 50.0], [6, 50.0], [8, 50.0], [10, 50.0], [12, 50.0], [14, 50.0]]
        self.assertTrue(self.results({"host": {"mem_mb": warm}}, exp)[0][0])
        self.assertFalse(self.results({"host": {"mem_mb": [[0, 1.0], [40, 1.0]]}}, exp)[0][0], "az örnek")
        self.assertFalse(self.results({"host": {}}, exp)[0][0], "mem_mb yok")
        # min_mb: yalnız ~1 MB'lık sarmalayıcı ölçülüyorsa düşer.
        floor = {"mem_stable": {**exp["mem_stable"], "min_mb": 20}}
        self.assertTrue(self.results({"host": {"mem_mb": flat}}, floor)[0][0])
        wrapper = [[t, 1.25] for t in range(0, 40, 2)]
        self.assertFalse(self.results({"host": {"mem_mb": wrapper}}, floor)[0][0])
        # Kapsam: son örnek quit_after - 2 x every'den önceyse (örnekleme erken durdu) düşer.
        meta_ok = {"every": 2, "quit_after": 40}
        self.assertTrue(self.results({"host": {"mem_mb": flat, "mem_meta": meta_ok}}, exp)[0][0])
        early = {"host": {"mem_mb": flat, "mem_meta": {"every": 2, "quit_after": 60}}}
        res = self.results(early, exp)
        self.assertFalse(res[0][0])
        self.assertIn("erken", res[0][1])

    def test_empty_procs_fail(self) -> None:
        dumps = {"host": {"samples": self.samples([3, 3]), "mem_mb": [[t, 50.0] for t in range(0, 40, 2)]}}
        for exp in (
            {"samples_players": {"count": 3, "procs": []}},
            {"mem_stable": {"max_growth_mb": 5, "window": 3, "procs": []}},
        ):
            res = self.results(dumps, exp)
            self.assertEqual(len(res), 1, exp)
            self.assertFalse(res[0][0], exp)

    def test_log_failures_warnings(self) -> None:
        lines = ["ok", "WARNING: a", "SCRIPT ERROR: b", "  USER WARNING: c izinli", "ERROR: d izinli"]
        allow = [re.compile("izinli")]
        self.assertEqual(net_smoke.log_failures("host", lines, allow, False), ["host log hatası: SCRIPT ERROR: b"])
        self.assertEqual(
            net_smoke.log_failures("host", lines, allow, True),
            ["host log uyarısı: WARNING: a", "host log hatası: SCRIPT ERROR: b"],
        )

    def test_new_scenario_keys_accepted(self) -> None:
        tmp = tempfile.mkdtemp(prefix="test_net_smoke_")
        path = os.path.join(tmp, "s.json")
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump({"level": "res://x.tscn", "deny_warnings": True, "mem_sample_sec": 3,
                           "expect": [{"eq": ["host.x", 1]}]}, f)
            sc, problem = net_smoke.load_scenario(path)
            self.assertIsNotNone(sc, problem)
        finally:
            os.remove(path)
            os.rmdir(tmp)

    def test_repo_soak_scenario_loads(self) -> None:
        sc, problem = net_smoke.load_scenario(os.path.join(net_smoke.ROOT, "tests", "net", "soak", "store_a.json"))
        self.assertIsNotNone(sc, problem)


# `alloc_tree.py`: kök küçük kalır, belleği (ALLOC_MB, yazılmış sayfalar) çocuk ayırır — Windows'ta Godot console
# exe'si (~1 MB) ile belleği tutan asıl exe çocuğunun ilişkisi. Çocuk READY basınca kök `READY <kök> <çocuk>` basar.
ALLOC_MB = 48
ALLOC_SCRIPT = r"""
import os, subprocess, sys, time
if len(sys.argv) > 1:
    block = bytearray(b"\x01") * (int(sys.argv[1]) * 1024 * 1024)
    print("READY", os.getpid(), flush=True)
    time.sleep(60.0)
    sys.exit(0)
child = subprocess.Popen([sys.executable, __file__, "%d"], stdout=subprocess.PIPE, text=True)
line = child.stdout.readline()
print("READY", os.getpid(), *line.split()[1:], flush=True)
time.sleep(60.0)
"""


class ProcessMemoryTest(unittest.TestCase):
    def test_tree_sums_child_memory_dead_has_none(self) -> None:
        tmp = tempfile.mkdtemp(prefix="test_net_smoke_")
        script = os.path.join(tmp, "alloc_tree.py")
        with open(script, "w", encoding="utf-8") as f:
            f.write(ALLOC_SCRIPT % ALLOC_MB)
        popen = subprocess.Popen(
            [sys.executable, script], stdout=subprocess.PIPE, text=True, **net_smoke.popen_group_kwargs()
        )
        pids: list[int] = []
        try:
            assert popen.stdout is not None
            line = popen.stdout.readline()
            self.assertTrue(line.startswith("READY"), line)
            pids = [int(p) for p in line.split()[1:]]
            self.assertEqual(len(pids), 2, line)
            tree_mb = net_smoke.process_tree_memory_mb(popen)
            self.assertIsNotNone(tree_mb)
            # Toplam çocuğun ayırdığını içerir; yalnız kökü ölçmek (eski hata) bu sınırın altında kalır.
            self.assertGreaterEqual(tree_mb, ALLOC_MB)
            root_only = (net_smoke._windows_private_bytes if WINDOWS else net_smoke._linux_private_bytes)(popen.pid)
            self.assertIsNotNone(root_only)
            self.assertLess(root_only / (1024.0 * 1024.0), ALLOC_MB / 2, "kök küçük olmalı (test kurgusu)")
        finally:
            net_smoke.kill_process_tree(popen, grace=0.5)
            force_kill(pids)
            if popen.stdout is not None:
                popen.stdout.close()
        self.assertIsNone(net_smoke.process_tree_memory_mb(popen))
        self.assertEqual(wait_dead(pids), [])
        os.remove(script)
        os.rmdir(tmp)


class TimeoutPathTest(unittest.TestCase):
    """net_smoke.run(): senaryonun sert üst süresi dolunca asılı süreç ağaçları öldürülür ve FAIL raporlanır."""

    def test_hard_timeout_kills_hung_processes(self) -> None:
        tmp = tempfile.mkdtemp(prefix="test_net_smoke_")
        script = os.path.join(tmp, "hang.py")
        with open(script, "w", encoding="utf-8") as f:
            f.write(HANG_SCRIPT)
        scenario = os.path.join(tmp, "hang.json")
        with open(scenario, "w", encoding="utf-8") as f:
            json.dump({"level": "res://x.tscn", "clients": 1, "timeout": 3, "expect": [{"eq": ["host.x", 1]}]}, f)

        pids: list[int] = []
        created: list[net_smoke.Proc] = []

        class HangProc(net_smoke.Proc):
            """Godot yerine zarif sinyali yok sayan kök + çocuk ağacı başlatır."""

            def start(self) -> None:
                self.cmd = [sys.executable, script, "11"]
                created.append(self)
                super().start()

        def record_pids() -> None:
            # READY satırları okuyucu iş parçacığınca proc.lines'a yazılır; burada toplanır.
            for proc in created:
                for line in list(proc.lines):
                    if line.startswith("READY "):
                        pids.extend(int(p) for p in line.split()[1:] if int(p) not in pids)

        out: list[str] = []
        t0 = time.monotonic()
        try:
            with (
                mock.patch.object(net_smoke, "Proc", HangProc),
                mock.patch.object(net_smoke, "find_godot", lambda: "godot-yerine-asili-betik"),
                mock.patch("builtins.print", lambda *a, **_k: out.append(" ".join(str(x) for x in a))),
            ):
                code = net_smoke.run(scenario, 0.0, 0.0, 0.0, False, False, False)
            elapsed = time.monotonic() - t0
            record_pids()
            self.assertEqual(code, 1)
            self.assertEqual(len(created), 2, "host + 1 istemci başlatılmalı")
            self.assertEqual(len(pids), 4, f"her süreç kök + çocuk bildirmeli: {pids}")
            self.assertEqual(wait_dead(pids), [], "zaman aşımından sonra canlı süreç kaldı")
            text = "\n".join(out)
            self.assertIn("host zaman aşımında öldürüldü", text)
            self.assertIn("c1 zaman aşımında öldürüldü", text)
            self.assertTrue(all(p.killed for p in created))
            # timeout 3 sn + öldürme payı (her süreç: 2 x grace + taskkill); asılı sürecin 60 sn uykusundan çok önce.
            self.assertLess(elapsed, 3.0 + 2 * (2 * net_smoke.KILL_GRACE_SEC + 3.0))
        finally:
            record_pids()
            force_kill(pids)
            for name in os.listdir(tmp):
                os.remove(os.path.join(tmp, name))
            os.rmdir(tmp)


if __name__ == "__main__":
    unittest.main(verbosity=2)
