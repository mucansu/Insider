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
import os
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

    def test_process_born_before_root_never_enters(self) -> None:
        # Kökün zamanı mutlak alt sınırdır: ebeveyn (ölmüş, kayıtlı) zamanından sonra ama kökten önce oluşmuş
        # süreç de girmez.
        table = [(800, 100), (801, 800), (802, 800)]
        times = {100: 1000, 801: 950, 802: 1200}
        tree = net_smoke.descendants_from_table(100, table, times.get, known={800: 900})
        self.assertNotIn(801, tree)
        self.assertIn(802, tree)


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
