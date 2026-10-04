#!/usr/bin/env python3
"""tools/heist_stats.py tests (IS-015b). Standard library only; no Godot needed (fake dumps, run_one mocked).

Run: python tools/test_heist_stats.py   (on Windows `python` or `py -3`)
Coverage: seed/player/strategy parsing, --cell, the matrix (per-peer tokens, duplicates, ids), Godot arguments (suffixes passed
untouched, client/host, heist-end stagger), one run row from fake dumps (ok / no result / timeout / mismatch / log lines / session
seed), the summary (outcome %, mean, p90, stuck, trouble), outputs (summary.md + runs.csv), port allocator, slot pool, the run
loop with a mocked run_one, exit codes, the ci_local tools step.
"""

from __future__ import annotations

import csv
import io
import os
import sys
import tempfile
import threading
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import heist_stats as hs  # noqa: E402


def dump(outcome: str | None = "clean", payout: int = 100, duration: float = 30.0, max_alert: int = 1,
         brain: dict | None = None, **extra) -> dict:
    d: dict = {"peer_id": 1, "exit_reason": "heist_end", "heist": {"active": False, "max_alert": max_alert, "result": {}}}
    if outcome is not None:
        d["heist"]["result"] = {
            "outcome": outcome, "payout": payout, "loot_total": payout, "duration_s": duration, "max_alert": max_alert,
            "heat": 0, "players": {"1": {"caught": False, "escaped": True}}, "strategy": {"class": "zaman"},
        }
    d["brain"] = brain if brain is not None else {"stuck_s": 0.5, "unsticks": 1, "failures": 0, "wait_timeouts": 0,
                                                  "retreats": 0}
    d.update(extra)
    return d


def spec(cell: str = "rush", players: int = 1, seed: int = 1) -> hs.RunSpec:
    peers = tuple(cell.split("/")) if "/" in cell else (cell,) * players
    return hs.RunSpec(f"{cell}_{players}p_s{seed}", cell, peers, seed)


def row(cell: str = "rush", players: int = 1, seed: int = 1, **kw) -> dict:
    names = hs.proc_names(players)
    dumps = kw.pop("dumps", None) or {n: dump(**kw) for n in names}
    return hs.record_from(spec(cell, players, seed), dumps, {n: 0 for n in names}, [], {}, 0.0, 12.0)


class ParseTest(unittest.TestCase):
    def test_seeds(self) -> None:
        self.assertEqual(hs.parse_seeds("1-5"), [1, 2, 3, 4, 5])
        self.assertEqual(hs.parse_seeds("3, 1,5-6,3"), [1, 3, 5, 6])
        self.assertEqual(len(hs.parse_seeds("1-50")), 50)
        for bad in ("5-1", "", "a", "1-", "1-2-3"):
            with self.assertRaises(ValueError, msg=bad):
                hs.parse_seeds(bad)

    def test_players(self) -> None:
        self.assertEqual(hs.parse_players("1,2,3"), [1, 2, 3])
        self.assertEqual(hs.parse_players("2,2"), [2])
        for bad in ("0", "5", "x", ""):
            with self.assertRaises(ValueError, msg=bad):
                hs.parse_players(bad)

    def test_strategy_tokens_are_free_strings(self) -> None:
        self.assertEqual(hs.parse_strategy("window+bag"), ("window+bag",))
        self.assertEqual(hs.parse_strategy("rush+omni"), ("rush+omni",))  # IS-058b suffix passes untouched
        self.assertEqual(hs.parse_strategy("future_brain"), ("future_brain",))
        self.assertEqual(hs.parse_strategy("rush/team/send+bag"), ("rush", "team", "send+bag"))
        for bad in ("", "a b", "rush/", "a/b/c/d/e", "x;y"):
            with self.assertRaises(ValueError, msg=bad):
                hs.parse_strategy(bad)

    def test_cell(self) -> None:
        cells, seeds = hs.parse_cell("team:2,3:1-10", [1])
        self.assertEqual(cells, [("team", ("team", "team")), ("team", ("team", "team", "team"))])
        self.assertEqual(seeds, list(range(1, 11)))
        cells, seeds = hs.parse_cell("rush/send", [7])
        self.assertEqual(cells, [("rush/send", ("rush", "send"))])
        self.assertEqual(seeds, [7])
        cells, _ = hs.parse_cell("buy", [1])
        self.assertEqual(cells, [("buy", ("buy",))])
        for bad in (":2", "a:1:2:3", "rush:9"):
            with self.assertRaises(ValueError, msg=bad):
                hs.parse_cell(bad, [1])

    def test_parse_args_defaults_and_matrix(self) -> None:
        args, specs = hs.parse_args(["--seeds", "1-3", "--cell", "team:2,3:1-2"])
        self.assertEqual(args.jobs, hs.default_jobs())
        self.assertGreaterEqual(args.jobs, 1)
        self.assertEqual(args.run_timeout, hs.DEFAULT_QUIT_AFTER + hs.HARD_MARGIN_SEC)
        self.assertEqual(len(specs), 5 * 3 + 2 * 2)
        self.assertEqual({s.cell for s in specs}, {"rush", "window", "send", "distract", "buy", "team"})
        self.assertEqual(sorted(s.players for s in specs if s.cell == "team"), [2, 2, 3, 3])
        self.assertIn("--cell team:2,3:1-2", args.argv_text)

    def test_parse_args_only_cells_and_errors(self) -> None:
        _, specs = hs.parse_args(["--strategies", "", "--cell", "rush:1:4"])
        self.assertEqual([s.run_id for s in specs], ["rush_1p_s4"])
        for bad in (["--strategies", ""], ["--jobs", "0"], ["--quit-after", "0"], ["--latency-ms", "-1"]):
            with self.assertRaises(ValueError, msg=bad):
                hs.parse_args(bad)

    def test_main_bad_args_exit_2(self) -> None:
        err = io.StringIO()
        with redirect_stderr(err):
            self.assertEqual(hs.main(["--seeds", "9-1"]), 2)
        self.assertIn("tohum", err.getvalue())


class MatrixTest(unittest.TestCase):
    def test_grid_and_dedup(self) -> None:
        cells = hs.cells_for([("rush",), ("team",), ("rush", "send")], [1, 3])
        self.assertEqual(cells, [("rush", ("rush",)), ("rush", ("rush",) * 3), ("team", ("team",)), ("team", ("team",) * 3),
                                 ("rush/send", ("rush", "send"))])
        specs = hs.build_matrix([(cells, [1, 2]), ([("rush", ("rush",))], [2, 3])])
        self.assertEqual(len(specs), 5 * 2 + 1)  # rush 1p s2 is a duplicate
        ids = [s.run_id for s in specs]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertIn("rush-send_2p_s1", ids)
        self.assertEqual(specs[0].players, 1)

    def test_run_id_is_file_name_safe(self) -> None:
        specs = hs.build_matrix([([("window+bag", ("window+bag",))], [3])])
        self.assertEqual(specs[0].run_id, "windowpbag_1p_s3")
        self.assertEqual(specs[0].peers, ("window+bag",))


class PeerArgsTest(unittest.TestCase):
    def test_host(self) -> None:
        a = hs.peer_args("host", "window+bag", 7, 5000, "res://levels/store_a.tscn", "/t/h.json", 240.0)
        self.assertEqual(a[:4], ["--name=host", "--host", "--port=5000", "--level=res://levels/store_a.tscn"])
        for s in ("--brain=window+bag", "--seed=7", "--dump=/t/h.json", "--quit-after=240", "--quit-on-heist-end=2.5"):
            self.assertIn(s, a)
        self.assertFalse(any(x.startswith("--player-scene") or x.startswith("--bot") for x in a))

    def test_client_and_extras(self) -> None:
        a = hs.peer_args("c2", "team", 3, 6000, "res://x.tscn", "c2.json", 100.0, "res://p.tscn", ["--brain-loop=60"])
        self.assertIn("--join=127.0.0.1", a)
        self.assertIn("--port=6000", a)
        self.assertNotIn("--level=res://x.tscn", a)
        self.assertIn("--player-scene=res://p.tscn", a)
        self.assertEqual(a[-1], "--brain-loop=60")
        self.assertIn("--quit-after=105", a)  # clients outlive the host: they leave on heist end / host loss

    def test_heist_end_stagger(self) -> None:
        # clients leave first, never in the same host frame; the host last (net_smoke LEAVE_STAGGER note)
        lingers = [hs.HEIST_END_LINGER[n] for n in hs.proc_names(4)]
        self.assertEqual(lingers[0], max(lingers))
        self.assertEqual(len(set(lingers)), len(lingers))
        self.assertGreaterEqual(min(abs(a - b) for i, a in enumerate(lingers) for b in lingers[i + 1:]), 0.3)


class RecordTest(unittest.TestCase):
    def test_ok_row(self) -> None:
        r = row(outcome="shouted", payout=128, duration=39.9, max_alert=2)
        self.assertEqual(r["status"], "ok")
        self.assertEqual(r["outcome"], "shouted")
        self.assertEqual((r["payout"], r["duration_s"], r["max_alert"]), (128.0, 39.9, 2.0))
        self.assertTrue(r["outcome_same"])
        self.assertEqual((r["escaped"], r["caught"], r["strategy_class"]), (1, 0, "zaman"))
        self.assertEqual(r["exit_reasons"], "host=heist_end")
        self.assertEqual(r["problem"], "")
        self.assertEqual(set(r), set(hs.RUN_FIELDS))

    def test_team_sums_and_max(self) -> None:
        b = [{"stuck_s": 0.2, "unsticks": 1, "failures": 2, "wait_timeouts": 1, "retreats": 0},
             {"stuck_s": 4.0, "unsticks": 3, "failures": 0, "wait_timeouts": 0, "retreats": 1}]
        dumps = {"host": dump(brain=b[0]), "c1": dump(brain=b[1])}
        r = hs.record_from(spec("team", 2), dumps, {"host": 0, "c1": 0}, [], {}, 150.0, 3.0)
        self.assertEqual((r["stuck_s"], r["unsticks"], r["failures"], r["wait_timeouts"], r["retreats"]), (4.0, 4, 2, 1, 1))
        self.assertEqual(r["latency_ms"], 150.0)

    def test_no_result(self) -> None:
        r = row(outcome=None)
        self.assertEqual((r["outcome"], r["status"]), (hs.NO_RESULT, "no_result"))
        self.assertIsNone(r["payout"])
        self.assertEqual(r["max_alert"], 1.0)  # still from heist.max_alert

    def test_timeout_and_missing_dump(self) -> None:
        names = ["host", "c1"]
        r = hs.record_from(spec("team", 2), {"host": dump(), "c1": None}, {"host": 0, "c1": 1}, ["c1"], {}, 0.0, 9.0)
        self.assertEqual(r["status"], "timeout")
        self.assertIn("c1 zaman aşımında öldürüldü", r["problem"])
        r = hs.record_from(spec("team", 2), {n: dump() for n in names}, {"host": 0, "c1": 1}, [], {}, 0.0, 9.0)
        self.assertEqual(r["status"], "error")
        self.assertIn("c1 çıkış kodu 1", r["problem"])
        r = hs.record_from(spec("team", 2), {"host": dump(), "c1": None}, {"host": 0, "c1": 0}, [], {}, 0.0, 9.0, ["x"])
        self.assertEqual(r["status"], "error")
        self.assertIn("c1 döküm yazmadı", r["problem"])

    def test_mismatch_and_logs(self) -> None:
        dumps = {"host": dump(outcome="clean"), "c1": dump(outcome="hot")}
        logs = {"host": ["ok", "ERROR: boom", "   at: x"], "c1": ["WARNING: w", "SCRIPT ERROR: e", "USER WARNING: u"]}
        r = hs.record_from(spec("team", 2), dumps, {"host": 0, "c1": 0}, [], logs, 0.0, 1.0)
        self.assertFalse(r["outcome_same"])
        self.assertEqual((r["error_lines"], r["warning_lines"]), (2, 2))

    def test_session_seed_when_present(self) -> None:
        self.assertEqual(row()["session_seed"], "")
        r = hs.record_from(spec(), {"host": dump(session_seed=42)}, {"host": 0}, [], {}, 0.0, 1.0)
        self.assertEqual(r["session_seed"], 42)

    def test_garbage_dump_does_not_raise(self) -> None:
        r = hs.record_from(spec(), {"host": {"heist": "x", "brain": [1]}}, {"host": 0}, [], {}, 0.0, 1.0)
        self.assertEqual(r["outcome"], hs.NO_RESULT)
        self.assertIsNone(r["stuck_s"])


class SummaryTest(unittest.TestCase):
    def test_percentile_mean(self) -> None:
        self.assertIsNone(hs.percentile([], 90))
        self.assertEqual(hs.percentile([5.0], 90), 5.0)
        self.assertEqual(hs.percentile([float(i) for i in range(1, 11)], 90), 9.0)
        self.assertEqual(hs.percentile([float(i) for i in range(1, 21)], 90), 18.0)
        self.assertEqual(hs.mean([1.0, 2.0, 6.0]), 3.0)
        self.assertIsNone(hs.mean([]))

    def test_groups_and_columns(self) -> None:
        rows = [row(seed=1, outcome="clean", payout=100, duration=10.0, max_alert=0),
                row(seed=2, outcome="clean", payout=200, duration=20.0, max_alert=1),
                row(seed=3, outcome="aborted", payout=0, duration=30.0, max_alert=2),
                row(seed=4, outcome=None),
                row("team", 3, 1, outcome="weird", brain={"stuck_s": 5.0, "failures": 2})]
        header, table = hs.summarize(rows)
        self.assertEqual(header[:3], ["strateji", "oyuncu", "n"])
        cols = [h[2:] for h in header if h.startswith("% ")]
        self.assertEqual(cols, hs.KNOWN_OUTCOMES + ["weird", hs.NO_RESULT])
        rush = dict(zip(header, table[0]))
        self.assertEqual((rush["strateji"], rush["oyuncu"], rush["n"]), ("rush", "1", "4"))
        self.assertEqual((rush["% clean"], rush["% aborted"], rush["% none"], rush["% hot"]), ("50", "25", "25", "0"))
        self.assertEqual(rush["ort. ödeme"], "100")  # (100 + 200 + 0) / 3; the no-result run has no payout
        self.assertEqual((rush["ort. süre"], rush["p90 süre"]), ("20.0", "30.0"))
        self.assertEqual(rush["ort. max_alert"], "1.00")
        self.assertEqual((rush["takılma"], rush["sorun"]), ("0", "0"))
        team = dict(zip(header, table[1]))
        self.assertEqual((team["strateji"], team["oyuncu"], team["% weird"]), ("team", "3", "100"))
        self.assertEqual((team["takılma"], team["başarısız"]), ("1", "6"))  # 3 peers x 2 failures

    def test_trouble_and_error_runs(self) -> None:
        bad = hs.record_from(spec(), {"host": dump()}, {"host": 0}, ["host"], {"host": ["ERROR: x", "WARNING: y"]}, 0.0, 1.0)
        header, table = hs.summarize([bad, row(seed=2)])
        r = dict(zip(header, table[0]))
        self.assertEqual((r["hatalı koşu"], r["sorun"]), ("1 (2)", "1"))

    def test_outputs(self) -> None:
        rows = [row(seed=s) for s in (1, 2)] + [row("team", 2, 1)]
        with tempfile.TemporaryDirectory() as d:
            text = hs.write_outputs(d, rows, {"started": "20261003-120000", "komut": "python tools/heist_stats.py"})
            with open(os.path.join(d, "summary.md"), encoding="utf-8") as f:
                md = f.read()
            with open(os.path.join(d, "runs.csv"), encoding="utf-8", newline="") as f:
                csv_rows = list(csv.DictReader(f))
        self.assertIn("# Soygun istatistiği — 20261003-120000", md)
        self.assertIn("| strateji | oyuncu | n |", md)
        self.assertIn("| rush | 1 | 2 |", md)
        self.assertIn("| team | 2 | 1 |", md)
        self.assertIn("- komut: python tools/heist_stats.py", md)
        self.assertEqual(len(csv_rows), 3)
        self.assertEqual(list(csv_rows[0]), hs.RUN_FIELDS)
        self.assertEqual(csv_rows[2]["players"], "2")
        self.assertIn("strateji", text.splitlines()[0])
        self.assertEqual(len(text.splitlines()), 3)


class PoolTest(unittest.TestCase):
    def test_ports_unique(self) -> None:
        seq = iter([5000, 5000, 5001, 5000, 5002])
        alloc = hs.PortAllocator(probe=lambda: next(seq))
        self.assertEqual([alloc.take(), alloc.take(), alloc.take()], [5000, 5001, 5002])
        stuck = hs.PortAllocator(probe=lambda: 7000)
        stuck.take()
        with self.assertRaises(RuntimeError):
            stuck.take()

    def test_slot_pool_weights(self) -> None:
        pool = hs.SlotPool(4)
        self.assertEqual(pool.acquire(3), 3)
        got: list[int] = []
        t = threading.Thread(target=lambda: got.append(pool.acquire(2)))
        t.start()
        t.join(0.3)
        self.assertTrue(t.is_alive())  # 1 free slot < 2
        pool.release(3)
        t.join(2.0)
        self.assertEqual(got, [2])
        self.assertEqual(hs.SlotPool(2).acquire(3), 2)  # capped at capacity: a 3-player run still runs on 2 slots
        cancel = threading.Event()
        cancel.set()
        full = hs.SlotPool(1)
        full.acquire(1)
        with self.assertRaises(InterruptedError):
            full.acquire(1, cancel)


class RunLoopTest(unittest.TestCase):
    def _run(self, argv: list[str], status: str = "ok") -> tuple[int, str, str]:
        def fake_run_one(s: hs.RunSpec, ctx: hs.Context) -> dict:
            names = hs.proc_names(s.players)
            r = hs.record_from(s, {n: dump(outcome="clean" if s.seed % 2 else "aborted") for n in names},
                               {n: 0 for n in names}, [], {}, ctx.latency_ms, 1.0)
            if status != "ok":
                r["status"] = status
            return r

        with tempfile.TemporaryDirectory() as d:
            out = io.StringIO()
            with mock.patch.object(hs, "run_one", fake_run_one), mock.patch.object(hs, "find_godot", lambda: "godot"), \
                    redirect_stdout(out):
                code = hs.main(argv + ["--out", d, "--jobs", "3"])
            self.assertTrue(os.path.isfile(os.path.join(d, ".gdignore")))
            produced = [n for n in os.listdir(d) if n != ".gdignore"]
            self.assertEqual(len(produced), 1)
            with open(os.path.join(d, produced[0], "summary.md"), encoding="utf-8") as f:
                md = f.read()
            self.assertTrue(os.path.isdir(os.path.join(d, produced[0], "runs")))
        return code, out.getvalue(), md

    def test_run_writes_summary(self) -> None:
        code, out, md = self._run(["--strategies", "rush,buy", "--seeds", "1-4", "--cell", "team:2,3:1-2"])
        self.assertEqual(code, 0)
        self.assertIn("12 koşu", out.splitlines()[0])  # 2 x 4 + team 2,3 x 2
        self.assertIn("| rush | 1 | 4 | 50 |", md)
        self.assertIn("| team | 3 | 2 | 50 |", md)
        self.assertIn("- gecikme: 0 ms RTT", md)

    def test_harness_problem_exit_1(self) -> None:
        code, out, _ = self._run(["--strategies", "rush", "--seeds", "1"], status="timeout")
        self.assertEqual(code, 1)
        self.assertIn("düzenek sorunu", out)

    def test_dry_run_starts_nothing(self) -> None:
        out = io.StringIO()
        with mock.patch.object(hs, "run_one", side_effect=AssertionError("started")), redirect_stdout(out):
            self.assertEqual(hs.main(["--strategies", "rush", "--seeds", "1", "--cell", "team:3:1", "--dry-run"]), 0)
        text = out.getvalue()
        self.assertIn("--brain=rush", text)
        self.assertIn("c2: --name=c2 --join=127.0.0.1", text)
        self.assertIn("2 koşu, 4 Godot süreci", text)


class FakePopen:
    def __init__(self, code: int | None) -> None:
        self.code = code

    def poll(self) -> int | None:
        return self.code

    def wait(self, timeout: float | None = None) -> int | None:
        if self.code is None:
            raise hs.subprocess.TimeoutExpired("godot", timeout or 0)
        return self.code


class FakeProc(hs.Proc):
    """Stands in for a Godot process: writes its dump at start; `hang` names never become ready nor exit."""
    started: list[list[str]] = []
    hang: set[str] = set()

    def start(self) -> None:
        FakeProc.started.append(self.cmd)
        if self.name in FakeProc.hang:
            self.popen = FakePopen(None)  # type: ignore[assignment]
            return
        self.popen = FakePopen(0)  # type: ignore[assignment]
        self.lines = ["INSIDERS_READY x"]
        self.ready.set()
        with open(self.dump_path, "w", encoding="utf-8") as f:
            hs.json.dump(dump(outcome="clean"), f)

    def kill(self) -> None:
        if self.popen is not None and self.popen.poll() is None:
            self.killed = True

    def finish(self) -> None:
        self.exit_code = self.popen.poll() if self.popen is not None else None


class RunOneTest(unittest.TestCase):
    def setUp(self) -> None:
        FakeProc.started = []
        FakeProc.hang = set()
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        ports = iter(range(41000, 41100))
        self.ctx = hs.Context(godot="godot", level="res://l.tscn", quit_after=60.0, run_timeout=0.5, latency_ms=0.0,
                              player_scene=None, extra=[], runs_dir=self.tmp.name,
                              ports=hs.PortAllocator(probe=lambda: next(ports)))
        patches = [mock.patch.object(hs, "Proc", FakeProc), mock.patch.object(hs, "JOIN_GAP_SEC", 0.0),
                   mock.patch.object(hs, "HOST_READY_TIMEOUT", 0.3), mock.patch.object(hs, "CLIENT_READY_TIMEOUT", 0.3)]
        for p in patches:
            p.start()
            self.addCleanup(p.stop)

    def test_team_run_order_and_args(self) -> None:
        r = hs.run_one(hs.RunSpec("team_3p_s4", "team", ("team",) * 3, 4), self.ctx)
        self.assertEqual((r["status"], r["outcome"], r["players"]), ("ok", "clean", 3))
        names = [next(a for a in c if a.startswith("--name=")) for c in FakeProc.started]
        self.assertEqual(names, ["--name=host", "--name=c1", "--name=c2"])  # join order = team role
        host, c1 = FakeProc.started[0], FakeProc.started[1]
        self.assertIn("--log-file", host)
        self.assertTrue(host[host.index("--log-file") + 1].endswith(os.path.join("team_3p_s4", "host.log")))
        self.assertIn("--port=41000", host)
        self.assertIn("--port=41000", c1)  # no latency: clients join the host port directly
        self.assertIn("--brain=team", c1)
        self.assertTrue(os.path.exists(os.path.join(self.tmp.name, "team_3p_s4", "c2.json")))

    def test_hung_client_is_killed(self) -> None:
        FakeProc.hang = {"c1"}
        r = hs.run_one(hs.RunSpec("team_2p_s1", "team", ("team", "team"), 1), self.ctx)
        self.assertEqual(r["status"], "timeout")
        self.assertIn("c1 0.3 sn içinde bağlanmadı", r["problem"])
        self.assertIn("c1 zaman aşımında öldürüldü", r["problem"])

    def test_latency_proxy_only_with_clients(self) -> None:
        self.ctx.latency_ms = 150.0
        with mock.patch.object(hs, "LatencyProxy") as proxy:
            proxy.return_value.start.return_value = 42000
            hs.run_one(hs.RunSpec("rush_1p_s1", "rush", ("rush",), 1), self.ctx)
            proxy.assert_not_called()
            hs.run_one(hs.RunSpec("team_2p_s1", "team", ("team", "team"), 1), self.ctx)
            proxy.assert_called_once()
            self.assertEqual(proxy.call_args.kwargs["delay_ms"], 75.0)
            proxy.return_value.stop.assert_called_once()
        self.assertIn("--port=42000", FakeProc.started[-1])  # the client joins through the proxy


class CiStepTest(unittest.TestCase):
    def test_ci_local_runs_this_file(self) -> None:
        with open(os.path.join(hs.ROOT, "tools", "ci_local.sh"), encoding="utf-8") as f:
            self.assertIn("py_test tools/test_heist_stats.py", f.read())


if __name__ == "__main__":
    unittest.main()
