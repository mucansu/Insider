#!/usr/bin/env python3
"""tools/screenshot.py pure helper tests (IS-022 AC4). Standard library only; no Godot or display needed.

Run: python tools/test_screenshot.py   (on Windows `python` or `py -3`)
Coverage: moment parsing/timing (conversion to process clock, --quit-after), peer selection, skipping with no display,
GUI exe resolution, plan from a scenario, PNG reading (all filter kinds) and empty/black/size validation.
"""

from __future__ import annotations

import io
import json
import os
import random
import struct
import sys
import tempfile
import unittest
import zlib
from contextlib import redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import screenshot as ss  # noqa: E402


def _paeth(a: int, b: int, c: int) -> int:
    p = a + b - c
    pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
    return a if (pa <= pb and pa <= pc) else (b if pb <= pc else c)


def encode_png(rows: list[bytes], width: int, channels: int, filters: list[int] | None = None) -> bytes:
    """Test PNG: 8-bit, with the given filter per row (cycling 0..4 if none)."""
    color_type = {1: 0, 3: 2, 4: 6}[channels]
    raw = bytearray()
    prev = bytes(width * channels)
    for y, row in enumerate(rows):
        f = filters[y] if filters else y % 5
        out = bytearray()
        for i, x in enumerate(row):
            a = row[i - channels] if i >= channels else 0
            b = prev[i]
            c = prev[i - channels] if i >= channels else 0
            pred = (0, a, b, (a + b) >> 1, _paeth(a, b, c))[f]
            out.append((x - pred) & 0xFF)
        raw.append(f)
        raw += out
        prev = row

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, len(rows), 8, color_type, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b"")


class TempDirCase(unittest.TestCase):
    def setUp(self) -> None:
        self._tmp = tempfile.TemporaryDirectory(prefix="test_screenshot_")
        self.dir = self._tmp.name

    def tearDown(self) -> None:
        self._tmp.cleanup()

    def write(self, name: str, data: bytes) -> str:
        path = os.path.join(self.dir, name)
        with open(path, "wb") as f:
            f.write(data)
        return path


class MomentTest(unittest.TestCase):
    def test_parse_moments_sorted_unique(self) -> None:
        self.assertEqual(ss.parse_moments("6,2.5,6"), [2.5, 6.0])
        self.assertEqual(ss.parse_moments(" 0 , 1.004,1.001"), [0.0, 1.0])  # 0.01 s resolution

    def test_parse_moments_rejects_bad(self) -> None:
        for bad in ("", "1,,2", "1,2,", "x", "1,-1", "nan", "inf", "1e400"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                ss.parse_moments(bad)

    def test_moment_label(self) -> None:
        self.assertEqual(ss.moment_label(6.0), "6")
        self.assertEqual(ss.moment_label(2.5), "2.5")
        self.assertEqual(ss.moment_label(0.125), "0.12")

    def test_local_moments_shift_and_skip(self) -> None:
        self.assertEqual(ss.local_moments([3.0, 5.5, 8.0], 0.0), [(3.0, 3.0), (5.5, 5.5), (8.0, 8.0)])
        self.assertEqual(ss.local_moments([3.0, 5.5, 8.0], 1.237), [(3.0, 1.76), (5.5, 4.26), (8.0, 6.76)])
        # A moment before the process starts (or closer than MIN_LOCAL_SEC) is skipped.
        self.assertEqual(ss.local_moments([1.0, 3.0], 0.95), [(3.0, 2.05)])
        self.assertEqual(ss.local_moments([1.0], 2.0), [])

    def test_local_moments_preserve_order(self) -> None:
        # Godot's file order (shot_NN) is the ascending order of local moments; the conversion must keep the order.
        moments = ss.parse_moments("9,1,4.5,7")
        local = [loc for _, loc in ss.local_moments(moments, 0.4)]
        self.assertEqual(local, sorted(local))

    def test_clock_offset(self) -> None:
        # Same kind: startup times cancel out, the offset = the Popen difference.
        self.assertAlmostEqual(ss.clock_offset(1.8, 1.3, "window", "window"), 1.8)
        # Host headless (0.45 s), client windowed (estimate 1.5): the clock starts later.
        self.assertAlmostEqual(ss.clock_offset(1.0, 0.45, "window", "headless"), 1.0 - 0.45 + ss.STARTUP_ESTIMATE["window"])
        # Host windowed, client headless: earlier.
        self.assertAlmostEqual(ss.clock_offset(2.0, 1.6, "headless", "window"), 2.0 - 1.6 + ss.STARTUP_ESTIMATE["headless"])

    def test_quit_after_matches_net_smoke(self) -> None:
        self.assertEqual(ss.quit_after_for("host", 9.0, 0.0, 0), 9.0, "istemci yoksa bekleme yok")
        self.assertAlmostEqual(ss.quit_after_for("host", 9.0, 0.0, 2), 9.0 + 2 * ss.LEAVE_GAP + ss.LINGER_SEC)
        self.assertAlmostEqual(ss.quit_after_for("c1", 9.0, 0.5, 2), 8.5)
        self.assertAlmostEqual(ss.quit_after_for("c2", 9.0, 1.5, 2), 9.0 - 1.5 + ss.LEAVE_GAP)
        self.assertEqual(ss.quit_after_for("c1", 2.0, 5.0, 2), 1.0, "alt sınır 1 sn")

    def test_clients_leave_one_by_one_before_host(self) -> None:
        # On the host clock: client exits (dump + LINGER_SEC then leave) at least LEAVE_GAP apart, the host last.
        offsets = {"c1": 1.3, "c2": 2.4, "c3": 2.9}
        leave = {n: off + ss.quit_after_for(n, 10.0, off, 3) + ss.LINGER_SEC for n, off in offsets.items()}
        leave["host"] = ss.quit_after_for("host", 10.0, 0.0, 3) + ss.LINGER_SEC
        order = sorted(leave, key=leave.get)
        self.assertEqual(order, ["c1", "c2", "c3", "host"])
        for a, b in zip(order, order[1:]):
            self.assertGreaterEqual(leave[b] - leave[a], ss.LEAVE_GAP - 1e-9)

    def test_every_local_moment_before_quit(self) -> None:
        # All of every process's moments must be before its own --quit-after (so main.gd screenshot_plan does not drop them).
        moments = [3.0, 5.5, 8.0]
        duration = moments[-1] + ss.TAIL_SEC
        for host_kind, host_startup in (("window", 1.6), ("headless", 0.45)):
            for name, launched, kind in (("c1", 0.6, "window"), ("c2", 1.7, "headless"), ("c2", 2.5, "window")):
                offset = ss.clock_offset(launched, host_startup, kind, host_kind)
                qa = ss.quit_after_for(name, duration, offset, 2)
                for _, local in ss.local_moments(moments, offset):
                    self.assertLess(local, qa, f"{name} {local} >= {qa}")
        for _, local in ss.local_moments(moments, 0.0):
            self.assertLess(local, ss.quit_after_for("host", duration, 0.0, 0))


class ArgParseTest(unittest.TestCase):
    def test_window_size(self) -> None:
        self.assertEqual(ss.parse_window_size("1280x720"), (1280, 720))
        self.assertEqual(ss.parse_window_size("800X600"), (800, 600))
        for bad in ("1280", "x720", "10x10", "1280x720x1", "ax720"):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                ss.parse_window_size(bad)

    def test_parse_kv(self) -> None:
        self.assertEqual(ss.parse_kv(["host=a.json", " c1 = b "], "--bot"), {"host": "a.json", "c1": "b"})
        for bad in (["host"], ["=x"], ["host="]):
            with self.subTest(bad=bad), self.assertRaises(ValueError):
                ss.parse_kv(bad, "--bot")

    def test_parse_peers(self) -> None:
        self.assertEqual(ss.parse_peers("all", 2), ["host", "c1", "c2"])
        self.assertEqual(ss.parse_peers("c2, host,c2", 2), ["c2", "host"])
        self.assertEqual(ss.parse_peers("ALL", 0), ["host"])
        with self.assertRaises(ValueError):
            ss.parse_peers("c3", 2)
        with self.assertRaises(ValueError):
            ss.parse_peers("host,", 2)


class EnvironmentTest(TempDirCase):
    def test_skip_in_ci(self) -> None:
        self.assertIn("CI", ss.display_skip_reason({"CI": "true", "DISPLAY": ":0"}, "linux", lambda: True))
        self.assertEqual(ss.display_skip_reason({"CI": "false", "DISPLAY": ":0"}, "linux", lambda: True), "")

    def test_skip_without_display(self) -> None:
        self.assertNotEqual(ss.display_skip_reason({}, "linux", lambda: True), "")
        self.assertEqual(ss.display_skip_reason({"WAYLAND_DISPLAY": "wayland-0"}, "linux", lambda: True), "")
        self.assertNotEqual(ss.display_skip_reason({}, "win32", lambda: False), "")
        self.assertEqual(ss.display_skip_reason({}, "win32", lambda: True), "")
        self.assertEqual(ss.display_skip_reason({}, "darwin", lambda: False), "")

    def test_main_skips_and_returns_zero(self) -> None:
        out = io.StringIO()
        with mock.patch.object(ss, "display_skip_reason", return_value="ekran yok"), redirect_stdout(out):
            code = ss.main(["--at", "1"])
        self.assertEqual(code, 0)
        self.assertIn("atlandı", out.getvalue())

    def test_main_rejects_bad_arguments(self) -> None:
        with mock.patch.object(ss, "display_skip_reason", return_value=""), redirect_stdout(io.StringIO()):
            self.assertEqual(ss.main(["--at", "1,x"]), 2)
            self.assertEqual(ss.main(["--at", "1", "--peers", "c5"]), 2)
            self.assertEqual(ss.main(["--at", "1", "--bot", "c4=x.json", "--clients", "1"]), 2)

    def test_resolve_gui_godot(self) -> None:
        console = self.write("Godot_v4_console.exe", b"")
        gui = self.write("Godot_v4.exe", b"")
        self.assertEqual(ss.resolve_gui_godot("X.exe", {"GODOT": console}), "X.exe")
        self.assertEqual(ss.resolve_gui_godot(None, {"GODOT_GUI": "G.exe", "GODOT": console}), "G.exe")
        self.assertEqual(ss.resolve_gui_godot(None, {"GODOT": console}), gui)
        os.remove(gui)
        self.assertEqual(ss.resolve_gui_godot(None, {"GODOT": console}), console, "kardeş yoksa console exe")
        self.assertEqual(ss.resolve_gui_godot(None, {"GODOT": "/opt/godot"}), "/opt/godot")


class PlanTest(TempDirCase):
    def _args(self, *argv: str):
        ap_args = ["--at", "3,5.5,8", *argv]
        captured = {}

        def fake_run(plan, gui, verbose):
            captured["plan"] = plan
            return 0

        with mock.patch.object(ss, "display_skip_reason", return_value=""), mock.patch.object(ss, "run", fake_run), \
                mock.patch.object(ss, "resolve_gui_godot", return_value="gui"):
            self.assertEqual(ss.main(ap_args), 0)
        return captured["plan"]

    def test_defaults(self) -> None:
        plan = self._args()
        self.assertEqual(plan.name, "store_a")
        self.assertEqual(plan.level, ss.DEFAULT_LEVEL)
        self.assertEqual(plan.player_scene, ss.DEFAULT_PLAYER_SCENE)
        self.assertEqual(plan.clients, 2)
        self.assertEqual(plan.peers, ["host", "c1", "c2"])
        self.assertEqual(plan.window, (1280, 720))
        self.assertEqual(plan.moments, [3.0, 5.5, 8.0])
        self.assertTrue(plan.out_dir.endswith(os.path.join("build", "screens", "store_a")))

    def test_scenario_and_overrides(self) -> None:
        sc = {
            "_doc": "x", "level": "res://levels/test_arena.tscn", "player_scene": "res://p.tscn", "clients": 2,
            "start_delay": {"c2": 1.0}, "bots": {"host": "res://h.json", "c1": "res://c1.json"},
            "names": {"c1": "Ayşe"}, "args": {"host": ["--vision-mode=directional"]}, "expect": [{"eq": ["x", 1]}],
        }
        path = os.path.join(self.dir, "walk_demo.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(sc, f)
        plan = self._args("--scenario", path, "--bot", "c1=res://other.json", "--peers", "c1", "--out", self.dir)
        self.assertEqual(plan.name, "walk_demo")
        self.assertEqual(plan.level, "res://levels/test_arena.tscn")
        self.assertEqual(plan.player_scene, "res://p.tscn")
        self.assertEqual(plan.bots, {"host": "res://h.json", "c1": "res://other.json"})
        self.assertEqual(plan.start_delay, {"c2": 1.0})
        self.assertEqual(plan.display_names, {"c1": "Ayşe"})
        self.assertEqual(plan.extra_args, {"host": ["--vision-mode=directional"], "c1": [], "c2": []})
        self.assertEqual(plan.peers, ["c1"])
        self.assertEqual(plan.out_dir, os.path.join(self.dir, "walk_demo"))

    def test_name_must_be_safe(self) -> None:
        with mock.patch.object(ss, "display_skip_reason", return_value=""), redirect_stdout(io.StringIO()):
            self.assertEqual(ss.main(["--at", "1", "--name", "../x"]), 2)

    def test_prepare_out_clears_old_pngs(self) -> None:
        out = os.path.join(self.dir, "shots")
        os.makedirs(os.path.join(out, ".raw", "host"))
        self.write(os.path.join("shots", "host_1.png"), b"x")
        self.write(os.path.join("shots", "host_1.png.import"), b"x")
        self.write(os.path.join("shots", "notes.txt"), b"x")
        raw = ss._prepare_out(out)
        self.assertEqual(sorted(os.listdir(out)), ["notes.txt"])
        self.assertTrue(os.path.exists(os.path.join(self.dir, ".gdignore")), "çıktı kökü içe aktarılmaz")
        self.assertEqual(raw, os.path.join(out, ".raw"))


class CollectTest(TempDirCase):
    def _noise_png(self, path: str, width: int = 80, height: int = 48) -> None:
        rnd = random.Random(7)
        rows = [bytes(rnd.randrange(256) for _ in range(width * 3)) for _ in range(height)]
        with open(path, "wb") as f:
            f.write(encode_png(rows, width, 3))

    def test_parse_markers(self) -> None:
        lines = [
            "Godot Engine v4.7.2",
            "INSIDERS_SCREENSHOT skipped at=0.4 reason=level_not_loaded",
            "INSIDERS_SCREENSHOT ok at=2.95 file=C:/x/shot_01.png",
            "  INSIDERS_SCREENSHOT failed at=5 reason=empty_image",
            "INSIDERS_SCREENSHOT ok at=abc",
        ]
        self.assertEqual(
            ss.parse_markers(lines),
            {0.4: ("skipped", "level_not_loaded"), 2.95: ("ok", ""), 5.0: ("failed", "empty_image")},
        )

    def test_collect_valid_skipped_invalid_missing(self) -> None:
        raw = os.path.join(self.dir, ".raw")
        out = os.path.join(self.dir, "out")
        os.makedirs(os.path.join(raw, "c1"))
        os.makedirs(out)
        # c1: moment 1.6 before the level loads (skipped), 4 valid, 6 black, 8 no file.
        self._noise_png(os.path.join(raw, "c1", "shot_01.png"))
        with open(os.path.join(raw, "c1", "shot_02.png"), "wb") as f:
            f.write(encode_png([bytes(80 * 3)] * 48, 80, 3))
        expected = {"c1": [(1.6, 0.4), (4.0, 2.8), (6.0, 4.8), (8.0, 6.8)]}
        lines = {"c1": [
            "INSIDERS_SCREENSHOT skipped at=0.4 reason=level_not_loaded",
            "INSIDERS_SCREENSHOT ok at=2.8 file=x", "INSIDERS_SCREENSHOT ok at=4.8 file=y",
        ]}
        written, skipped, failures = ss.collect_shots(expected, lines, raw, out, (80, 48), 8.0)
        self.assertEqual(written, [os.path.join(out, "c1_4.png")])
        self.assertEqual(len(skipped), 1)
        self.assertIn("c1 1.6 sn", skipped[0])
        self.assertIn("seviye", skipped[0])
        self.assertEqual(len(failures), 2)
        self.assertIn("c1_6_INVALID.png", failures[0])
        self.assertIn("dosya yok", failures[1])
        self.assertEqual(sorted(os.listdir(out)), ["c1_4.png", "c1_6_INVALID.png"], "geçersiz sonuç adıyla kalmaz")

    def test_collect_all_skipped_is_not_failure(self) -> None:
        written, skipped, failures = ss.collect_shots(
            {"c1": [(1.6, 0.3)]}, {"c1": ["INSIDERS_SCREENSHOT skipped at=0.3 reason=level_not_loaded"]},
            os.path.join(self.dir, "raw"), self.dir, (80, 48), 8.0,
        )
        self.assertEqual((written, failures), ([], []))
        self.assertEqual(len(skipped), 1)


class PngTest(TempDirCase):
    def _image(self, width: int, height: int, channels: int, seed: int = 1) -> list[bytes]:
        rnd = random.Random(seed)
        return [bytes(rnd.randrange(256) for _ in range(width * channels)) for _ in range(height)]

    def test_unfilter_all_filter_types(self) -> None:
        for channels in (1, 3, 4):
            rows = self._image(13, 10, channels, seed=channels)
            data = encode_png(rows, 13, channels)
            raw = zlib.decompress(data[data.index(b"IDAT") + 4 : data.index(b"IEND") - 8])
            with self.subTest(channels=channels):
                self.assertEqual(ss._unfilter(raw, 13, 10, channels), rows)

    def test_stats_of_noise_and_flat(self) -> None:
        noisy = self.write("noisy.png", encode_png(self._image(64, 64, 4), 64, 4))
        info = ss.read_png_stats(noisy)
        self.assertEqual((info.width, info.height), (64, 64))
        self.assertGreater(info.stddev, 40.0)
        self.assertGreaterEqual(info.colors, ss.MIN_COLORS)
        flat = self.write("flat.png", encode_png([bytes([30, 30, 30]) * 64] * 64, 64, 3))
        info = ss.read_png_stats(flat)
        self.assertAlmostEqual(info.stddev, 0.0, places=6)
        self.assertEqual(info.colors, 1)

    def test_check_png(self) -> None:
        good = self.write("good.png", encode_png(self._image(80, 48, 3), 80, 3))
        black = self.write("black.png", encode_png([bytes(80 * 4)] * 48, 80, 4))
        two_tone = self.write("two.png", encode_png([bytes([0, 0, 0, 255] * 40 + [255] * 160)] * 48, 80, 4))
        self.assertEqual(ss.check_png(good, (80, 48), 8.0), "")
        self.assertIn("boş", ss.check_png(black, (80, 48), 8.0))
        self.assertIn("renk", ss.check_png(two_tone, (80, 48), 8.0), "yüksek sapma ama 2 renk")
        self.assertIn("boyut", ss.check_png(good, (1280, 720), 8.0))
        self.assertEqual(ss.check_png(os.path.join(self.dir, "yok.png"), (80, 48), 8.0), "dosya yok")
        broken = self.write("broken.png", b"not a png")
        self.assertIn("okunamadı", ss.check_png(broken, (80, 48), 8.0))


if __name__ == "__main__":
    unittest.main(verbosity=1)
