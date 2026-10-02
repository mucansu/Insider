#!/usr/bin/env python3
"""tools/warn_count.py saf yardımcı testleri (IS-047). Yalnız standart kütüphane; Godot gerekmez.

Koşu: python tools/test_warn_count.py   (Windows'ta `python` ya da `py -3`)
Kapsam: grup sınıflaması, @@WC_JSON satırının çözülmesi, türe/dosyaya göre sayım (etkin/kapalı ayrımı,
sıralama, üretim listesi), metin özeti ve main'in başarısızlık/JSON yazma yolları (Godot koşusu taklit).
"""

from __future__ import annotations

import io
import json
import os
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout
from unittest import mock

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import warn_count as wc  # noqa: E402


def w(kind: str, path: str, line: int = 1) -> dict:
    return {"type": kind, "file": path, "line": line, "message": f"{kind} @ {line}"}


PAYLOAD = {
    "godot": "4.7.2-stable (official)",
    "levels": {"return_value_discarded": 1, "unsafe_cast": 0, "untyped_declaration": 2, "unused_signal": 1},
    "files": [
        "res://main.gd",
        "res://core/a.gd",
        "res://entities/b.gd",
        "res://tests/unit/test_a.gd",
        "res://tools/x.gd",
    ],
    "warnings": [
        w("return_value_discarded", "res://core/a.gd", 3),
        w("return_value_discarded", "res://core/a.gd", 4),
        w("unsafe_cast", "res://core/a.gd", 5),
        w("unsafe_cast", "res://entities/b.gd", 1),
        w("return_value_discarded", "res://tests/unit/test_a.gd", 1),
        w("return_value_discarded", "res://tests/unit/test_a.gd", 2),
        w("return_value_discarded", "res://tests/unit/test_a.gd", 3),
        w("unused_signal", "res://tools/x.gd", 9),
        w("brand_new_warning", "res://main.gd", 2),
    ],
    "errors": [],
    "stray": 0,
}


class GroupTest(unittest.TestCase):
    def test_groups(self) -> None:
        self.assertEqual(wc.group_of("res://main.gd"), "uretim")
        for d in ("autoload", "core", "entities", "levels", "ui", "data"):
            self.assertEqual(wc.group_of(f"res://{d}/sub/x.gd"), "uretim", d)
        self.assertEqual(wc.group_of("res://tests/unit/test_x.gd"), "test")
        self.assertEqual(wc.group_of("res://tests/t.gd"), "test")
        self.assertEqual(wc.group_of("res://tools/warn_count.gd"), "diger")
        self.assertEqual(wc.group_of("res://coreish/x.gd"), "diger")


class ExtractTest(unittest.TestCase):
    def test_last_marker_with_ansi_and_noise(self) -> None:
        lines = [
            "Godot Engine v4.7.2",
            "WARNING: The function \"f()\" returns a value that will be discarded if not used.",
            "   at: GDScript::reload (res://a.gd:3)",
            '@@WC_JSON {"stray": 1}',
            '\x1b[0m@@WC_JSON {"stray": 2}\r',
        ]
        self.assertEqual(wc.extract_payload(lines), {"stray": 2})

    def test_missing_marker(self) -> None:
        self.assertIsNone(wc.extract_payload(["Godot Engine", "ERROR: boom"]))


class AggregateTest(unittest.TestCase):
    def setUp(self) -> None:
        self.r = wc.aggregate(PAYLOAD, top=2)

    def test_file_counts(self) -> None:
        self.assertEqual(self.r["dosya_sayisi"], {"uretim": 3, "test": 1, "diger": 1})

    def test_by_type(self) -> None:
        t = self.r["turler"]
        self.assertEqual(t["return_value_discarded"],
                         {"level": 1, "uretim": 2, "test": 3, "diger": 0, "toplam": 5})
        self.assertEqual(t["unsafe_cast"], {"level": 0, "uretim": 2, "test": 0, "diger": 0, "toplam": 2})
        self.assertEqual(t["untyped_declaration"]["toplam"], 0)
        self.assertEqual(t["unused_signal"]["diger"], 1)
        # project.godot'ta adı olmayan tür: düzey -1, etkin sayılmaz.
        self.assertEqual(t["brand_new_warning"]["level"], -1)

    def test_active_vs_inactive_totals(self) -> None:
        self.assertEqual(self.r["etkin_toplam"], {"uretim": 2, "test": 3, "diger": 1, "toplam": 6})
        self.assertEqual(self.r["kapali_toplam"], {"uretim": 3, "test": 0, "diger": 0, "toplam": 3})

    def test_ranking(self) -> None:
        self.assertEqual([f["file"] for f in self.r["en_cok"]], ["res://tests/unit/test_a.gd", "res://core/a.gd"])
        a = self.r["dosyalar"]["res://core/a.gd"]
        self.assertEqual((a["etkin"], a["toplam"]), (2, 3))
        self.assertEqual(a["types"], {"return_value_discarded": 2, "unsafe_cast": 1})
        # Yalnız kapalı/bilinmeyen tür veren dosya listeye girmez; üretim listesi ayrı.
        self.assertEqual([f["file"] for f in self.r["en_cok_uretim"]], ["res://core/a.gd"])

    def test_tie_break_by_path(self) -> None:
        p = {"levels": {"x": 1}, "files": [], "warnings": [w("x", "res://ui/b.gd"), w("x", "res://ui/a.gd")]}
        self.assertEqual([f["file"] for f in wc.aggregate(p)["en_cok"]], ["res://ui/a.gd", "res://ui/b.gd"])

    def test_text(self) -> None:
        text = wc.render_text(self.r)
        self.assertIn("5 betik (üretim 3, test 1, diğer 1)", text)
        self.assertIn("Etkin türler (düzey >= 1): toplam 6", text)
        self.assertIn("Kapalı türler (düzey 0; açılsa, bilgi): toplam 3", text)
        self.assertRegex(text, r"return_value_discarded\s+uyar\s+2\s+3\s+0\s+5")
        self.assertNotIn("untyped_declaration", text)  # sıfır sayılı tür basılmaz
        empty = wc.render_text(wc.aggregate({"levels": {}, "files": [], "warnings": []}))
        self.assertGreaterEqual(empty.count("(yok)"), 3)


GATE_OK = (0, ['@@WC_JSON {"mode": "gate", "files": []}'], False)
HARD_LINES = [
    "Godot Engine v4.7.2",
    "\x1b[1;31mSCRIPT ERROR: Parse Error: The method \"foo()\" is not present on the inferred type \"Variant\" "
    "(but may be present on a subtype). (Warning treated as error.)\x1b[0m",
    "   at: GDScript::reload (res://core/noise_rules.gd:113)",
    "ERROR: Failed to load script \"res://core/noise_rules.gd\" with error \"Parse error\".",
    "   at: load (modules/gdscript/gdscript_resource_format.cpp:46)",
    "SCRIPT ERROR: Parse Error: The method \"foo()\" is not present on the inferred type \"Variant\" "
    "(but may be present on a subtype). (Warning treated as error.)",
    "   at: GDScript::reload (res://core/noise_rules.gd:113)",
    "SCRIPT ERROR: Parse Error: Identifier \"zz\" not declared in the current scope.",
    "   at: GDScript::reload (res://ui/x.gd:7)",
]


class ParseErrorsTest(unittest.TestCase):
    def test_hard_and_other_deduped(self) -> None:
        hard, other = wc.parse_script_errors(HARD_LINES)
        self.assertEqual(hard, [{
            "file": "res://core/noise_rules.gd", "line": 113,
            "message": 'The method "foo()" is not present on the inferred type "Variant" (but may be present on a subtype).',
        }])
        self.assertEqual(other, [{
            "file": "res://ui/x.gd", "line": 7,
            "message": 'Parse Error: Identifier "zz" not declared in the current scope.',
        }])

    def test_clean(self) -> None:
        self.assertEqual(wc.parse_script_errors(["Godot Engine", "ERROR: boom", "WARNING: x"]), ([], []))


class MainTest(unittest.TestCase):
    def _main(self, results: list[tuple], argv: list[str]) -> tuple[int, str, str, int]:
        out, err = io.StringIO(), io.StringIO()
        with mock.patch.object(wc, "find_godot", return_value="godot"), \
                mock.patch.object(wc, "run_godot", side_effect=results) as run, \
                redirect_stdout(out), redirect_stderr(err):
            code = wc.main(argv)
        return code, out.getvalue(), err.getvalue(), run.call_count

    def test_run_failures(self) -> None:
        code, _, err, _ = self._main([GATE_OK, (None, ["x"], False)], ["--json", ""])
        self.assertEqual((code, "zaman aşımı" in err), (1, True))
        code, _, err, _ = self._main([GATE_OK, (None, ["x"], True)], ["--json", ""])
        self.assertEqual((code, "Debugger Break" in err), (1, True))
        code, _, err, _ = self._main([GATE_OK, (0, ["no marker"], False)], ["--json", ""])
        self.assertEqual((code, "@@WC_JSON satırı yok" in err), (1, True))
        code, _, err, _ = self._main([GATE_OK, (3, ["@@WC_JSON {}"], False)], ["--json", ""])
        self.assertEqual((code, "çıkış kodu 3" in err), (1, True))
        code, _, err, calls = self._main([(None, ["x"], False)], ["--json", "", "--gate"])
        self.assertEqual((code, calls, "zaman aşımı" in err), (1, 1, True))  # tarama koşusu da kapı için şart

    def test_hard_violation_skips_count(self) -> None:
        code, _, err, calls = self._main([(0, HARD_LINES, False)], ["--json", "", "--gate"])
        self.assertEqual((code, calls), (2, 1))
        self.assertIn("res://core/noise_rules.gd:113", err)
        self.assertIn("1 betik hatası", err)
        code, _, _, _ = self._main([(0, HARD_LINES, False)], ["--json", ""])  # --gate yok: sayım alınamadı
        self.assertEqual(code, 1)
        code, _, _, calls = self._main([(0, HARD_LINES[-2:], False)], ["--json", "", "--gate"])
        self.assertEqual((code, calls), (1, 1))  # yalnız başka betik hatası: kapı değil, koşu başarısız

    def test_gate(self) -> None:
        bad = wc.gate_violations(wc.aggregate(PAYLOAD))
        self.assertEqual(bad, [])  # untyped_declaration düzey 2 ama sayısı 0
        hard = {**PAYLOAD, "levels": {**PAYLOAD["levels"], "unused_signal": 2}}
        line = (0, ["@@WC_JSON " + json.dumps(hard)], False)
        self.assertEqual([v["file"] for v in wc.gate_violations(wc.aggregate(hard))], ["res://tools/x.gd"])
        code, _, err, _ = self._main([GATE_OK, line], ["--json", "", "--gate", "--quiet"])
        self.assertEqual(code, 2)
        self.assertIn("res://tools/x.gd:9  [unused_signal]", err)
        code, _, _, _ = self._main([GATE_OK, line], ["--json", "", "--quiet"])  # --gate yoksa yalnız bilgi
        self.assertEqual(code, 0)
        ok = (0, ["@@WC_JSON " + json.dumps(PAYLOAD)], False)
        code, out, _, calls = self._main([GATE_OK, ok], ["--json", "", "--gate", "--quiet"])
        self.assertEqual((code, calls), (0, 2))
        self.assertIn("kapı", out)

    def test_writes_json(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = os.path.join(tmp, "sub", "wc.json")
            ok = (0, ["@@WC_JSON " + json.dumps(PAYLOAD)], False)
            code, out, _, _ = self._main([GATE_OK, ok], ["--json", path, "--top", "1"])
            self.assertEqual(code, 0)
            self.assertIn("En çok uyarı veren 1 dosya", out)
            with open(path, encoding="utf-8") as fh:
                data = json.load(fh)
            self.assertEqual(data["etkin_toplam"]["toplam"], 6)
            self.assertEqual(len(data["uyarilar"]), len(PAYLOAD["warnings"]))


if __name__ == "__main__":
    unittest.main(verbosity=2)
