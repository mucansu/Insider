#!/usr/bin/env python3
"""tests/run_tests.gd çıktı kipi testi (IS-090). Yalnız standart kütüphane; Godot ister (GODOT ortam değişkeni,
yoksa atlanır). Geçici dizinde bir geçen + bir başarısız test yazar, koşucuyu `--dir=` ile koşar ve doğrular:
kısa kipte [PASS] satırı yok, [FAIL] satırı ve nedeni var, özet satırı biçimi değişmedi, çıkış kodu 1;
`--verbose-tests` ve TESTS_VERBOSE=1 [PASS] satırlarını geri getirir.

Koşu: python tools/test_run_tests.py
"""

from __future__ import annotations

import os
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GODOT = os.environ.get("GODOT", "")
SUMMARY = re.compile(r"^(\d+) test: (\d+) geçti, (\d+) başarısız \((\d+) ms\)$", re.M)

FIXTURE = """extends TestCase


func test_gecer() -> void:
	eq(1 + 1, 2)


func test_duser() -> void:
	eq(1 + 1, 3)
"""


@unittest.skipUnless(GODOT, "GODOT ortam değişkeni yok")
class RunnerOutputTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.tmp = tempfile.mkdtemp(prefix="test_run_tests_")
        with open(os.path.join(cls.tmp, "test_ornek.gd"), "w", encoding="utf-8", newline="\n") as f:
            f.write(FIXTURE)

    @classmethod
    def tearDownClass(cls) -> None:
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def run_runner(self, *extra: str, env: dict[str, str] | None = None) -> tuple[int, str]:
        cmd = [GODOT, "--headless", "--path", ROOT, "-s", "res://tests/run_tests.gd", "--",
               "--dir=" + self.tmp.replace("\\", "/"), *extra]
        full_env = {**os.environ, "TESTS_VERBOSE": "", **(env or {})}
        p = subprocess.run(cmd, capture_output=True, text=True, encoding="utf-8", errors="replace",
                           env=full_env, timeout=120)
        return p.returncode, p.stdout + p.stderr

    def test_brief_hides_pass_shows_fail_and_summary(self) -> None:
        code, out = self.run_runner()
        self.assertEqual(code, 1, out)
        self.assertNotIn("[PASS]", out)
        self.assertIn("[FAIL] test_ornek.gd::test_duser", out)
        m = SUMMARY.search(out)
        self.assertIsNotNone(m, out)
        assert m is not None
        self.assertEqual(m.group(1, 2, 3), ("2", "1", "1"))
        self.assertNotIn("Yetim düğüm farkı", out)

    def test_verbose_flag_and_env_restore_pass_lines(self) -> None:
        for extra, env in ((("--verbose-tests",), None), ((), {"TESTS_VERBOSE": "1"})):
            code, out = self.run_runner(*extra, env=env)
            self.assertEqual(code, 1, out)
            self.assertIn("[PASS] test_ornek.gd::test_gecer", out)
            self.assertIn("Yetim düğüm farkı", out)
            self.assertIsNotNone(SUMMARY.search(out), out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
