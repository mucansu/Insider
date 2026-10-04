#!/usr/bin/env python3
"""tools/perf_run.py pure helper tests (IS-067). Standard library only; no Godot or display needed.

Run: python tools/test_perf_run.py   (on Windows `python` or `py -3`)
Coverage: seconds validation, Godot arguments (S6 --perf), dump summary table (windowed/headless/no dump),
host validation, environment line, skipping on a display-less machine, the .bat to export.sh link.
"""

from __future__ import annotations

import argparse
import io
import os
import sys
import unittest
from contextlib import redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import perf_run as pr  # noqa: E402


def summary(avg: float, **extra: float) -> dict:
    s = {"count": 4, "min": avg, "avg": avg, "p50": avg, "p95": avg, "p99": avg, "max": avg}
    s.update(extra)
    return s


def render(headless: bool) -> dict:
    r = {
        "headless": headless, "valid": not headless, "note": "", "window_s": 10.0, "measured_s": 9.98,
        "interval_s": 0.25, "frames": 600, "frame_ms": summary(16.6, p99=33.4), "fps": {"avg": 60.2, "min": 20.0,
        "p1_low": 29.9}, "adapter": "GPU X", "vendor": "V", "renderer": "gl_compatibility", "driver": "opengl3",
        "api_version": "3.3", "window": [1280, 720], "refresh_hz": 60.0, "vsync": 1, "max_fps": 0,
    }
    for key in ("process_ms", "physics_ms", "process_max_1s_ms", "physics_max_1s_ms", "process_total_ms", "draw_calls", "objects", "primitives", "render_cpu_ms",
                "render_gpu_ms", "frame_setup_ms"):
        r[key] = summary(0.0 if headless and key in pr.RENDER_ONLY else 2.0)
    r["draw_calls"] = summary(0.0 if headless else 226.0)
    return r


class ParseTest(unittest.TestCase):
    def test_seconds(self) -> None:
        self.assertEqual(pr.parse_seconds("10"), 10.0)
        self.assertEqual(pr.parse_seconds("2.5"), 2.5)
        for bad in ("0", "0.5", "601", "abc", ""):
            with self.assertRaises(ValueError, msg=bad):
                pr.parse_seconds(bad)

    def test_render_only_matches_core(self) -> None:
        with open(os.path.join(pr.ROOT, "core", "perf_report.gd"), encoding="utf-8") as f:
            text = f.read()
        block = text.split("const RENDER_ONLY_KEYS", 1)[1].split("= [", 1)[1].split("]", 1)[0]
        for key in pr.RENDER_ONLY:
            self.assertIn(f'"{key}"', block)
        self.assertEqual(block.count('"'), 2 * len(pr.RENDER_ONLY))


class ArgsTest(unittest.TestCase):
    def test_host_args(self) -> None:
        a = pr.peer_args("host", 7001, "res://levels/store_a.tscn", 10.0, "/d/host.json", "res://b.json", (1280, 720))
        self.assertEqual(a[:4], ["--name=host", "--perf", "--perf-seconds=10", "--dump=/d/host.json"])
        self.assertIn("--host", a)
        self.assertIn("--port=7001", a)
        self.assertIn("--level=res://levels/store_a.tscn", a)
        self.assertIn(f"--quit-after={pr.JOIN_SLACK_SEC + 10:g}", a)
        self.assertIn("--bot=res://b.json", a)
        self.assertIn("--window-size=1280x720", a)

    def test_client_args_backstop_after_host(self) -> None:
        a = pr.peer_args("c1", 7001, "res://x.tscn", 5.0, "/d/c1.json", None, None)
        self.assertIn("--join=127.0.0.1", a)
        self.assertNotIn("--host", a)
        self.assertFalse(any(x.startswith(("--level", "--bot", "--window-size")) for x in a))
        qa = float(next(x for x in a if x.startswith("--quit-after=")).split("=")[1])
        self.assertGreater(qa, pr.host_quit_after(5.0), "istemci host kaybıyla çıkar; süre yalnız yedek")


class TableTest(unittest.TestCase):
    def test_rows_windowed_headless_missing(self) -> None:
        dumps = {
            "host": {"peers": [1, 2], "render": render(False)},
            "c1": {"peers": [1, 2], "render": render(True)},
            "c2": None,
        }
        rows = pr.summary_rows(dumps)
        self.assertEqual([r[0] for r in rows], ["host", "c1", "c2"])
        header_len = 3 + len(pr.COLUMNS)
        self.assertTrue(all(len(r) == header_len for r in rows))
        titles = [c[0] for c in pr.COLUMNS]
        host, c1, c2 = rows
        self.assertEqual(host[1], "pencere")
        self.assertEqual(host[2], "2")
        self.assertEqual(host[3 + titles.index("draw")], "226")
        self.assertEqual(host[3 + titles.index("fps %1")], "30")
        self.assertEqual(host[3 + titles.index("kare p99")], "33.40")
        self.assertEqual(c1[1], "headless")
        self.assertEqual(c1[3 + titles.index("draw")], "-", "headless'ta renderer kolonu boş")
        self.assertEqual(c1[3 + titles.index("rgpu")], "-")
        self.assertEqual(c1[3 + titles.index("process")], "2.00", "process headless'ta da ölçülür")
        self.assertEqual(c1[3 + titles.index("motor 1sn max")], "2.00")
        self.assertEqual(c2[1], "döküm yok")
        table = pr.format_table(rows)
        lines = table.splitlines()
        self.assertEqual(len(lines), 5)
        self.assertTrue(lines[0].startswith("peer"))
        self.assertEqual(len({len(line.rstrip()) for line in lines[:2]}), 1, "başlık ve çizgi aynı genişlikte")

    def test_fmt_and_dig(self) -> None:
        self.assertEqual(pr.fmt(None, "{:.2f}"), "-")
        self.assertEqual(pr.fmt(True, "{:.2f}"), "-")
        self.assertEqual(pr.fmt(3, "{:.1f}"), "3.0")
        self.assertEqual(pr.dig({"a": {"b": 2}}, "a.b"), 2)
        self.assertIsNone(pr.dig({"a": 1}, "a.b"))
        self.assertIsNone(pr.dig(None, "a"))

    def test_host_problems(self) -> None:
        self.assertEqual(pr.host_problems({"render": render(False)}), [])
        self.assertTrue(pr.host_problems(None))
        self.assertTrue(pr.host_problems({"peers": [1]}))
        probs = pr.host_problems({"render": render(True)})
        self.assertEqual(len(probs), 2)

    def test_describe_machine(self) -> None:
        line = pr.describe_machine(render(False))
        for part in ("GPU X", "gl_compatibility/opengl3", "1280x720", "vsync açık", "9.98/10.0 sn", "600 kare"):
            self.assertIn(part, line)


class RunTest(unittest.TestCase):
    def test_skips_without_display(self) -> None:
        args = argparse.Namespace(seconds="10")
        buf = io.StringIO()
        with mock.patch.object(pr, "display_skip_reason", return_value="CI ortamı"), redirect_stdout(buf):
            self.assertEqual(pr.run(args), 0)
        self.assertIn("atlandı", buf.getvalue())

    def test_bad_seconds_is_usage_error(self) -> None:
        with mock.patch.object(pr, "display_skip_reason", return_value=""), \
                redirect_stdout(io.StringIO()), mock.patch("sys.stderr", io.StringIO()):
            with self.assertRaises(SystemExit) as ctx:
                pr.main(["--seconds", "0"])
        self.assertEqual(ctx.exception.code, 2)


class BatTest(unittest.TestCase):
    def test_bat_ascii_and_args(self) -> None:
        path = os.path.join(pr.ROOT, "tools", "perf_dump.bat")
        with open(path, "rb") as f:
            raw = f.read()
        raw.decode("ascii")  # independent of the cmd code page
        text = raw.decode("ascii")
        for part in ("--host", "--perf", "--perf-seconds=", "--quit-after=", "--dump=", "start \"\" /wait"):
            self.assertIn(part, text)
        code = [ln.strip().lower() for ln in text.splitlines() if not ln.strip().lower().startswith("rem")]
        self.assertFalse([ln for ln in code if "goto" in ln or ln.startswith(":")],
                         "LF satır sonunda etiket/goto güvenilmez")

    def test_export_copies_bat(self) -> None:
        with open(os.path.join(pr.ROOT, "tools", "export.sh"), encoding="utf-8") as f:
            self.assertIn("tools/perf_dump.bat", f.read())


if __name__ == "__main__":
    unittest.main(verbosity=2)
