#!/usr/bin/env python3
"""tools/net_smoke.py process-tree kill and timeout path tests (IS-011 AC2). Standard library only.

Run: python3 tools/test_net_smoke.py   (on Windows `python` or `py -3`; tools/ci_local.sh `tools` step)
No Godot needed: small Python scripts that open a child + grandchild process and then hang stand in for Godot.
On POSIX a separate session + killpg (SIGTERM -> SIGKILL); on Windows a separate process group + CTRL_BREAK -> root
TerminateProcess, descendants filtered by creation time via taskkill /F /PID (pid reuse: DescendantsFromTableTest).
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

# `hang.py <flags>`: one generation per flag (e.g. "101" = root, child, grandchild). Each generation starts the next,
# waits for its READY line, prints `INSIDERS_READY` and `READY <own pid> <descendant pids>`, then hangs.
# Flag 1: that process ignores graceful signals (SIGTERM/SIGINT/SIGBREAK); dies only the forced way (SIGKILL /
# TerminateProcess). Flag 0: default behaviour (dies from the graceful signal).
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
    # A zombie (dead, not yet reaped) process also answers os.kill; on Linux its state is read.
    try:
        with open(f"/proc/{pid}/stat", encoding="ascii") as f:
            return f.read().rsplit(")", 1)[1].split()[0] != "Z"
    except (OSError, IndexError):
        return True


def wait_dead(pids: list[int], timeout: float = DEAD_WAIT_SEC) -> list[int]:
    """Returns the pids that did not die within the timeout."""
    deadline = time.monotonic() + timeout
    alive = list(pids)
    while alive and time.monotonic() < deadline:
        alive = [p for p in alive if pid_alive(p)]
        if alive:
            time.sleep(0.05)
    return alive


def force_kill(pids: list[int]) -> None:
    """The process must not stay hung even if the test fails."""
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
        """flags: per-generation signal-ignore flag (see HANG_SCRIPT). self.pids = pids from the root down."""
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
        # Root + child ignoring the graceful signal: forced path (POSIX SIGKILL, Windows TerminateProcess/taskkill /F).
        self.assert_tree_killed(self.start_tree("11"))

    def test_dead_intermediate_grandchild_killed(self) -> None:
        """Root and grandchild ignore the signal, the middle child dies from it (on Windows the grandchild's parent chain breaks).

            On Windows the grandchild is found only thanks to the tree collected BEFORE the signal (`known`): in the second scan
            the root has no child and the grandchild's parent is dead. To tell this apart, on Windows the same tree is also killed
            with `known` dropped and the grandchild is shown to survive this time (the test itself cleans up afterwards).
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
        net_smoke.kill_process_tree(popen, grace=0.5)  # does not throw
        self.assertEqual(popen.returncode, 0)


class DescendantsFromTableTest(unittest.TestCase):
    """Tree filtering with a fake process table (the pure core of the Windows path; runs on every platform).

    Windows does not re-parent children of a dead parent and pids are reused: unrelated processes whose parent pid
    collides with our root (or a descendant) but that were created BEFORE it must not enter the tree.
    """

    # pid: creation time (None = dead/inaccessible)
    TIMES = {
        100: 1000,  # root (Popen)
        200: 1100,  # the root's real child
        300: 1200,  # real grandchild
        400: 500,  # unrelated: an old parent's pid was 100 (like a desktop session), created before the root
        401: 600,  # child of 400 (unrelated subtree)
        402: 1300,  # child of 400 created AFTER the root: 400 is not in the tree so it still does not enter
        500: 1050,  # unrelated: a dead old process whose parent had pid 200; created before 200 (1100)
        650: 1150,  # dead intermediate node (collected earlier, known); its time can no longer be read
        700: 1250,  # real child of 650 (parent chain broken)
        701: 900,  # unrelated process whose parent looks like 650 but was created before the root
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
        # IS-013 AC5: the recorded intermediate node 650 (1150) died and its pid was later given to an unrelated process (1400);
        # that process's child 702 (1500) must not enter the tree even though it was created after both the root and the recorded time.
        table = [(100, 1), (650, 9), (702, 650)]
        times = {100: 1000, 650: 1400, 702: 1500}
        tree = net_smoke.descendants_from_table(100, table, times.get, known={650: 1150})
        self.assertNotIn(702, tree)
        self.assertEqual(tree, {650: 1150})  # the record stays; the kill step does not touch it because the time does not match
        # If the same pid is still the same process (time = record) its children are searched.
        times[650] = 1150
        self.assertIn(702, net_smoke.descendants_from_table(100, table, times.get, known={650: 1150}))

    def test_process_born_before_root_never_enters(self) -> None:
        # The root's time is an absolute lower bound: a process created after the (dead, recorded) parent's time but before the root
        # does not enter either.
        table = [(800, 100), (801, 800), (802, 800)]
        times = {100: 1000, 801: 950, 802: 1200}
        tree = net_smoke.descendants_from_table(100, table, times.get, known={800: 900})
        self.assertNotIn(801, tree)
        self.assertIn(802, tree)


class ExpandBotLoopTest(unittest.TestCase):
    """Expansion of the "loop" section in a bot file (IS-013 endurance run)."""

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
        out = net_smoke.expand_bot_loop(self.RAW, 9.9)  # laps [2,5), [5,8); [8,11) is partial: not added
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
            {"loop": {"from": 0.0, "period": 1.0}, "steps": [{"t": 1.5, "move": [0, 0]}]},  # outside the lap
            {"loop": {"from": 0.0, "period": 1.0}},
        ]
        for raw in bad:
            with self.assertRaises(ValueError, msg=repr(raw)):
                net_smoke.expand_bot_loop(raw, 10.0)

    @staticmethod
    def apply_frames(steps: list[dict], until: float) -> dict[float, int]:
        """entities/player/bot_timeline.gd arithmetic: each physics frame clock += 1/60 (float64) and a step with
            t <= clock is applied in that frame; t + dur (the end of a hold) works by the same rule.
            Returns: time mark -> frame it is applied in."""
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
        """In each expanded lap, how many frames pass from the lap's first step to each mark (step and t + dur)."""
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
        # Review finding (t2): the old soak_c2 lap used times on a frame boundary like 18.3 (t*60 an integer);
        # the legs became 16/17 frames from lap to lap. The simulation must catch this.
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
        # In every lap file in the repo: lap times are away from frame boundaries, period*60 is an integer and in a 1-hour
        # expansion every lap's leg frame counts are the same (the final position does not drift in a long run).
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
    """IS-013 expectation additions: $rtt bound, samples_players, mem_stable; log warning check."""

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
        # Warm-up is clamped to a quarter of the last sample time; a large first value during warm-up does not count.
        warm = [[0, 10.0], [2, 50.0], [4, 50.0], [6, 50.0], [8, 50.0], [10, 50.0], [12, 50.0], [14, 50.0]]
        self.assertTrue(self.results({"host": {"mem_mb": warm}}, exp)[0][0])
        self.assertFalse(self.results({"host": {"mem_mb": [[0, 1.0], [40, 1.0]]}}, exp)[0][0], "az örnek")
        self.assertFalse(self.results({"host": {}}, exp)[0][0], "mem_mb yok")
        # min_mb: fails only if the ~1 MB wrapper alone is measured.
        floor = {"mem_stable": {**exp["mem_stable"], "min_mb": 20}}
        self.assertTrue(self.results({"host": {"mem_mb": flat}}, floor)[0][0])
        wrapper = [[t, 1.25] for t in range(0, 40, 2)]
        self.assertFalse(self.results({"host": {"mem_mb": wrapper}}, floor)[0][0])
        # Coverage: fails if the last sample is before quit_after - 2 x every (sampling stopped early).
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

    def test_scenario_args(self) -> None:
        """IS-082: per-process "args" are validated and appended after the harness's own args."""
        ok = {"clients": 1, "args": {"host": ["--vision-mode=directional"], "c1": []}}
        self.assertEqual(net_smoke.args_problem(ok), "")
        self.assertEqual(net_smoke.process_args(ok, "host"), ["--vision-mode=directional"])
        self.assertEqual(net_smoke.process_args(ok, "c1"), [])
        self.assertEqual(net_smoke.process_args({}, "c2"), [], "anahtar yoksa boş")
        for bad in (
            {"args": ["--x"]},
            {"clients": 1, "args": {"c2": ["--x"]}},
            {"args": {"host": "--x"}},
            {"args": {"host": [1]}},
            {"args": {"host": ["x=1"]}},
            {"args": {"c1": ["--port=1"]}},
            {"args": {"host": ["--quit-after"]}},
        ):
            self.assertNotEqual(net_smoke.args_problem(bad), "", str(bad))
        tmp = tempfile.mkdtemp(prefix="test_net_smoke_")
        path = os.path.join(tmp, "s.json")
        try:
            with open(path, "w", encoding="utf-8") as f:
                json.dump({"level": "res://x.tscn", "args": {"c3": ["--x"]}, "expect": [{"eq": ["host.x", 1]}]}, f)
            sc, problem = net_smoke.load_scenario(path)
            self.assertIsNone(sc)
            self.assertIn("c3", problem)
        finally:
            os.remove(path)
            os.rmdir(tmp)

    def test_repo_scenarios_load(self) -> None:
        """Every tests/net/*.json scenario passes load_scenario (keys incl. "args")."""
        net_dir = os.path.join(net_smoke.ROOT, "tests", "net")
        for f in sorted(os.listdir(net_dir)):
            if f.endswith(".json"):
                sc, problem = net_smoke.load_scenario(os.path.join(net_dir, f))
                self.assertIsNotNone(sc, f"{f}: {problem}")

    def test_repo_soak_scenario_loads(self) -> None:
        sc, problem = net_smoke.load_scenario(os.path.join(net_smoke.ROOT, "tests", "net", "soak", "store_a.json"))
        self.assertIsNotNone(sc, problem)


# `alloc_tree.py`: the root stays small, the child allocates the memory (ALLOC_MB, written pages) - like the Godot console
# exe (~1 MB) and the real exe child that holds the memory on Windows. When the child prints READY the root prints `READY <root> <child>`.
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
            # Includes what the whole child allocated; measuring only the root (the old bug) stays below this bound.
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


class LogExcerptTest(unittest.TestCase):
    """IS-090: on FAIL short mode prints only the log's error lines (at most 20) or its last lines."""

    def test_picks_error_lines_and_at_lines(self) -> None:
        lines = ["Godot Engine v4", "bilgi", "ERROR: kırık", "   at: f (a.gd:3)", "bilgi 2",
                 "SCRIPT ERROR: x", "WARNING: y"]
        self.assertEqual(net_smoke.log_excerpt(lines),
                         ["ERROR: kırık", "   at: f (a.gd:3)", "SCRIPT ERROR: x", "WARNING: y"])

    def test_caps_at_limit(self) -> None:
        out = net_smoke.log_excerpt([f"ERROR: {i}" for i in range(30)])
        self.assertEqual(len(out), 21)
        self.assertEqual(out[0], "ERROR: 0")
        self.assertEqual(out[-1], "(+10 hata satırı daha)")

    def test_tail_when_no_errors(self) -> None:
        out = net_smoke.log_excerpt([str(i) for i in range(50)])
        self.assertEqual(out[1:], [str(i) for i in range(40, 50)])
        self.assertEqual(net_smoke.log_excerpt([]), ["(boş)"])


class LeaveTimingTest(unittest.TestCase):
    """IS-095: default --quit-after rule and dump spread (timing race) check."""

    def test_every_client_dumps_after_host_staggered_within_linger(self) -> None:
        duration = 40.0
        # (name, seconds from host start to client start): simultaneous starters and a late joiner (start_delay).
        for starts in ([("c1", 1.8), ("c2", 1.8)], [("c1", 1.7), ("c2", 30.2)], [("c1", 0.4)]):
            moments = {n: e + net_smoke.default_quit_after(n, duration, e) for n, e in starts}
            for i, (name, _) in enumerate(starts):
                # Every client, c1 included, dumps after the host's dump moment (duration).
                self.assertAlmostEqual(moments[name] - duration, net_smoke.LEAVE_STAGGER * (i + 1))
            ordered = [moments[n] for n, _ in starts]
            for a, b in zip(ordered, ordered[1:]):
                self.assertGreaterEqual(b - a, net_smoke.LEAVE_STAGGER - 1e-9)  # so they do not drop in the same host frame
            # The game has at most 3 people (host + 2 clients): that spread stays well below the wait margin.
            self.assertLess(max(ordered) - duration, net_smoke.LINGER_SEC - 0.3)

    def test_quit_after_floor(self) -> None:
        self.assertEqual(net_smoke.default_quit_after("c1", 5.0, 20.0), 1.0)

    def test_timing_race(self) -> None:
        linger = net_smoke.LINGER_SEC
        self.assertEqual(net_smoke.timing_race({}), "")
        self.assertEqual(net_smoke.timing_race({"host": 100.0}), "")
        self.assertEqual(net_smoke.timing_race({"host": 100.0, "c1": 100.3, "c2": 100.6}), "")
        self.assertEqual(net_smoke.timing_race({"host": 100.0 + linger - 0.01, "c1": 100.0}), "")
        late_host = net_smoke.timing_race({"host": 101.6, "c1": 100.3, "c2": 100.6})
        self.assertIn("zamanlama yarışı", late_host)
        self.assertIn("host dökümü c1 dökümünden 1.30 sn sonra", late_host)
        self.assertIn("c2 dökümü host", net_smoke.timing_race({"host": 100.0, "c1": 100.3, "c2": 100.0 + linger}))


# `fake_godot.py`: stands in for Godot; takes net_smoke's user arguments (--host/--join, --dump, --quit-after),
# prints INSIDERS_READY, after --quit-after s writes a {"peer_id", "x": 1} dump and exits with 0. The host delays its dump by
# FAKE_HOST_LATE s in the first FAKE_LATE_RUNS launches, counted via the FAKE_STATE counter file in the environment (a host whose
# clock lags under load).
FAKE_GODOT_SCRIPT = r"""
import json, os, sys, time
args = dict((a.split("=", 1) + [""])[:2] for a in sys.argv[1:])
host = "--host" in args
delay = float(args["--quit-after"])
if host:
    path = os.environ["FAKE_STATE"]
    n = int(open(path).read()) if os.path.exists(path) else 0
    open(path, "w").write(str(n + 1))
    if n < int(os.environ["FAKE_LATE_RUNS"]):
        delay += float(os.environ["FAKE_HOST_LATE"])
print("INSIDERS_READY", flush=True)
time.sleep(delay)
with open(args["--dump"], "w", encoding="utf-8") as f:
    json.dump({"peer_id": 1 if host else 2, "x": 1}, f)
"""


class RaceRetryTest(unittest.TestCase):
    """IS-095: a run whose shared dump moments spread more than LINGER_SEC is not evaluated and is re-run; if the race
    persists it FAILs (expectations are not loosened)."""

    def run_fake(self, late_runs: int, retries: int) -> tuple[int, str, int]:
        tmp = tempfile.mkdtemp(prefix="test_net_smoke_")
        script = os.path.join(tmp, "fake_godot.py")
        with open(script, "w", encoding="utf-8") as f:
            f.write(FAKE_GODOT_SCRIPT)
        scenario = os.path.join(tmp, "race.json")
        with open(scenario, "w", encoding="utf-8") as f:
            json.dump({"level": "res://x.tscn", "clients": 1, "duration": 1.0, "expect": [{"eq": ["*.x", 1]}]}, f)
        state = os.path.join(tmp, "state.txt")

        class FakeProc(net_smoke.Proc):
            def start(self) -> None:
                self.cmd = [sys.executable, script] + self.cmd[self.cmd.index("--") + 1 :]
                super().start()

        out: list[str] = []
        env = {"FAKE_STATE": state, "FAKE_LATE_RUNS": str(late_runs), "FAKE_HOST_LATE": "1.6"}
        try:
            with (
                mock.patch.dict(os.environ, env),
                mock.patch.object(net_smoke, "Proc", FakeProc),
                mock.patch.object(net_smoke, "RACE_RETRIES", retries),
                mock.patch.object(net_smoke, "find_godot", lambda: "godot-yerine-sahte-betik"),
                mock.patch("builtins.print", lambda *a, **_k: out.append(" ".join(str(x) for x in a))),
            ):
                code = net_smoke.run(scenario, 0.0, 0.0, 0.0, False, False, False)
            with open(state, encoding="utf-8") as f:
                starts = int(f.read())
            return code, "\n".join(out), starts
        finally:
            for name in os.listdir(tmp):
                os.remove(os.path.join(tmp, name))
            os.rmdir(tmp)

    def test_race_rerun_then_pass(self) -> None:
        code, text, starts = self.run_fake(late_runs=1, retries=2)
        self.assertEqual(code, 0, text)
        self.assertEqual(starts, 2, "yarışlı ilk koşudan sonra bir kez yeniden koşulmalı")
        self.assertIn("UYARI race.json (0 ms): zamanlama yarışı: host dökümü c1 dökümünden", text)
        self.assertIn("PASS race.json (0 ms): 2/2 beklenti", text)

    def test_persistent_race_fails(self) -> None:
        code, text, starts = self.run_fake(late_runs=99, retries=1)
        self.assertEqual(code, 1, text)
        self.assertEqual(starts, 2)
        self.assertIn("FAIL race.json (0 ms)", text)
        self.assertIn("  FAIL zamanlama yarışı: host dökümü c1 dökümünden", text)

    def test_no_race_single_run(self) -> None:
        code, text, starts = self.run_fake(late_runs=0, retries=2)
        self.assertEqual((code, starts), (0, 1), text)
        self.assertNotIn("zamanlama", text)


class TimeoutPathTest(unittest.TestCase):
    """net_smoke.run(): when the scenario's hard upper limit expires hung process trees are killed and FAIL is reported."""

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
            """Starts a root + child tree that ignores the graceful signal, in place of Godot."""

            def start(self) -> None:
                self.cmd = [sys.executable, script, "11"]
                created.append(self)
                super().start()

        def record_pids() -> None:
            # READY lines are written to proc.lines by the reader thread; collected here.
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
            # IS-090 short mode: without -v there is no passed-assertion line ("ok"), a summary + hint instead of the full log.
            self.assertNotIn("  ok  ", text)
            self.assertIn("--keep -v", text)
            # timeout 3 s + kill margin (each process: 2 x grace + taskkill); well before the hung process's 60 s sleep.
            self.assertLess(elapsed, 3.0 + 2 * (2 * net_smoke.KILL_GRACE_SEC + 3.0))
        finally:
            record_pids()
            force_kill(pids)
            for name in os.listdir(tmp):
                os.remove(os.path.join(tmp, name))
            os.rmdir(tmp)


if __name__ == "__main__":
    unittest.main(verbosity=2)
