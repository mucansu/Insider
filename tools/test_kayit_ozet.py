#!/usr/bin/env python3
"""tools/kayit_ozet.py tests (IS-111). Standard library only; no Godot needed.

Run: python3 tools/test_kayit_ozet.py   (on Windows `python`; tools/ci_local.sh `tools` step)
The GB-12 sample logs (docs/surec/olcum/20261006-gb12-kayit-{host,c1}.json) must yield the GB-12 chain by themselves; synthetic
dumps with missing/old/garbage fields must not crash.
"""

from __future__ import annotations

import io
import json
import os
import re
import sys
import tempfile
import unittest
from contextlib import redirect_stderr, redirect_stdout

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import kayit_ozet  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GB12_HOST = os.path.join(ROOT, "docs", "surec", "olcum", "20261006-gb12-kayit-host.json")
GB12_C1 = os.path.join(ROOT, "docs", "surec", "olcum", "20261006-gb12-kayit-c1.json")


def write_json(tmp: str, name: str, data: object) -> str:
    path = os.path.join(tmp, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    return path


@unittest.skipUnless(os.path.exists(GB12_HOST) and os.path.exists(GB12_C1), "GB-12 örnek kayıtları yok (docs/surec/olcum)")
class Gb12SampleTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.text, cls.problems = kayit_ozet.summarize([GB12_C1, GB12_HOST])  # client first: the host is found by is_host

    def test_session(self) -> None:
        self.assertEqual(self.problems, [])
        self.assertIn("# Kayıt özeti — 20261006-gb12-kayit-host.json", self.text)
        self.assertIn("Mustafa (p1, host), Ikinci (p78313522, istemci)", self.text)
        self.assertIn("tohum 170912729 · koşu sayısı 1", self.text)
        self.assertIn("Kayıt nedeni: Mustafa window_close, Ikinci window_close", self.text)
        self.assertIn("Ikinci→host 9 ms (16 örnek)", self.text)

    def test_result_and_players(self) -> None:
        self.assertIn("**Sonuç:** hepsi yakalandı (`caught_all`) · 153,5 sn · ganimet 0", self.text)
        self.assertIn("kefalet 200 · ekip nakdi 50 → -150", self.text)
        self.assertIn("sınıf gürültü", self.text)
        self.assertIn("| Mustafa | yakalandı (sahip) | 1 | 0 | 100 | 0 | bozuk: personel bölgesi, gören sahip |", self.text)
        self.assertIn("| Ikinci | yakalandı (sahip) | 1 | 0 | 100 | 0 | sağlam |", self.text)

    def test_gb12_chain_in_timeline(self) -> None:
        # GB-12: empty register found on return -> shout (tier 2) -> intact-cover Ikinci detected in the customer zone, held,
        # caught, no rescue -> Mustafa detected in the staff zone at 14 px, held, caught.
        chain = [
            "- 108,4 — sahip kasanın boş olduğunu fark etti (dönüş kontrolü)",
            "- 110,0 — uyarı kademesi → 2 (bağırdı)",
            "sahip Ikinci'yi tespit etti: müşteri bölgesi, 66 px, davranış alarm (ÖRTÜSÜ SAĞLAM",
            "- 130,3–136,3 — sahip Ikinci'yi tuttu (6,0 sn) → yakalandı; kurtarma yok",
            "sahip Mustafa'yı tespit etti: personel bölgesi, 14 px, davranış alarm",
            "- 147,5–153,5 — sahip Mustafa'yı tuttu (6,0 sn) → yakalandı; kurtarma yok",
            "- 153,5 — İŞ BİTTİ: hepsi yakalandı",
        ]
        pos = [self.text.find(line) for line in chain]
        self.assertNotIn(-1, pos, [c for c, p in zip(chain, pos) if p < 0])
        self.assertEqual(pos, sorted(pos), "zincir zaman sırasında olmalı")
        self.assertIn("- 98,7 — OYUNCU: kasa boşaltıldı (sahip o an: agenda/sent)", self.text)
        self.assertIn("(iş sonrası)", self.text)
        self.assertNotIn("tutma bitti", self.text, "tutma bitişi tutma satırına katılmalı")

    def test_timeline_sorted(self) -> None:
        block = self.text.split("**Zaman çizelgesi**", 1)[1].split("\n\n", 1)[0]
        times = [float(m.group(1).replace(",", ".")) for m in re.finditer(r"^- (\d+,\d)[ –]", block, re.M)]
        self.assertGreater(len(times), 40)
        self.assertEqual(times, sorted(times))

    def test_events_and_sections(self) -> None:
        self.assertIn("1. örtü bozuldu: Mustafa (personel bölgesi; gören sahip)", self.text)
        self.assertIn("3. GÖNDER: Mustafa sahibi arka odaya yolladı", self.text)
        self.assertIn("**Alışveriş / sipariş:** raf: alınan 2, ödenen 0, bırakılan 2 · sipariş ready (Mustafa)", self.text)
        self.assertIn("pencere 14,7 sn", self.text)
        self.assertIn("BackDoor: oyuncu 1 kez, NPC 1 kez, 2 değişim, kendiliğinden kapanma 1", self.text)
        self.assertIn("pencere sorusu: yok", self.text)

    def test_answer_table(self) -> None:
        self.assertIn("| # | Satır | T1 |", self.text)
        self.assertIn("| A1 | Sonuç ve süre | hepsi yakalandı, 153,5 sn |", self.text)
        self.assertIn("| B2 | Kasa / arka oda nakdi zamanı | kasa 98,7 sn; çanta 111,6 sn |", self.text)
        self.assertIn("| C2 | Keşif/bağırış ↔ iş sonu | keşif 108,4 (kasa); bağırış 110,0; iş sonundan 43,6 sn önce |", self.text)
        self.assertIn("| F3 | Keşif (kaynak, zaman) | kasa 108,4 (dönüş kontrolü) |", self.text)
        self.assertIn("| G3 | Örtü (neden, gören, tanınma) | Mustafa personel bölgesi (gören sahip); sağlam: Ikinci |", self.text)
        self.assertIn("| H1 | Kim, kim tarafından yakalandı | Ikinci ← sahip; Mustafa ← sahip; tespit 2 |", self.text)

    def test_host_alone(self) -> None:
        text, problems = kayit_ozet.summarize([GB12_HOST])
        self.assertEqual(problems, [])
        self.assertIn("Ikinci'yi tuttu", text)  # the name comes from heist.history without the client file
        self.assertIn("- Ping: tespit anı RTT: Ikinci 11 ms", text)  # no client file: only the host-side RTT at detection


def run_marker(run: int) -> dict:
    return {"kind": "level_started", "data": {"run": run, "level": "res://levels/store_a.tscn", "seed": 7}}


def result(outcome: str, duration: float, caught: list[str]) -> dict:
    return {
        "outcome": outcome,
        "duration_s": duration,
        "loot_total": 120,
        "payout": 102,
        "max_alert": 2,
        "players": {
            "1": {"name": "Ana", "caught": "1" in caught, "escaped": "1" not in caught},
            "55": {"name": "Ömer", "caught": "55" in caught, "escaped": "55" not in caught},
        },
        "strategy": {"class": "zaman", "cover_intact": {"1": True, "55": True}},
    }


class MultiRunTest(unittest.TestCase):
    def test_runs_split_by_level_started(self) -> None:
        host = {
            "is_host": True,
            "peer_id": 1,
            "players": {"1": {"name": "Ana"}},
            "events": [
                run_marker(1),
                {"kind": "shout", "data": {}},
                {"kind": "player_caught", "data": {"peer": 55, "by": "chaser"}},
                run_marker(2),
                {"kind": "owner_discover", "data": {"source": "cash"}},
                run_marker(3),
                {"kind": "purchase", "data": {"peer": 1, "item": "cola"}},
            ],
            "heist": {"history": [result("shouted", 80.0, ["55"]), result("clean", 60.5, [])], "elapsed": 12.0},
            "owner": {"log": [{"t": 3.0, "state": "agenda", "task": "counter", "why": "görev: counter"}]},
        }
        with tempfile.TemporaryDirectory() as tmp:
            text, problems = kayit_ozet.summarize([write_json(tmp, "h.json", host)])
        self.assertEqual(problems, [])
        self.assertIn("koşu sayısı 3", text)
        self.assertIn("| # | Satır | T1 | T2 | T3 |", text)
        run1 = text.split("## Koşu 1", 1)[1].split("## Koşu 2", 1)[0]
        run2 = text.split("## Koşu 2", 1)[1].split("## Koşu 3", 1)[0]
        run3 = text.split("## Koşu 3", 1)[1].split("## Protokol", 1)[0]
        self.assertIn("1. bağırış", run1)
        self.assertIn("2. Ömer yakalandı (mahalleli)", run1)
        self.assertIn("| Ömer | yakalandı (mahalleli) |", run1)
        self.assertIn("1. sahip keşfetti: arka oda nakdi eksik", run2)
        self.assertNotIn("bağırış", run2)
        self.assertIn("bitmedi (kayıt anında sürüyordu, 12,0 sn)", run3)
        self.assertIn("1. satın alma: Ana (item=cola)", run3)
        # Owner data belongs to the level loaded at write time (run 3) only.
        self.assertNotIn("Zaman çizelgesi", run1 + run2)
        self.assertIn("- 3,0 — sahip: görev: counter", run3)
        self.assertIn("| A1 | Sonuç ve süre | bağırdı, 80,0 sn | temiz, 60,5 sn | bitmedi |", text)
        self.assertIn("| H1 | Kim, kim tarafından yakalandı | Ömer ← mahalleli |", text)
        self.assertIn("keşif/bağırış var (zaman yalnız son koşuda)", text)

    def test_history_without_markers(self) -> None:
        host = {
            "is_host": True,
            "events": [{"kind": "player_caught", "data": {"peer": 1, "by": "owner"}}],
            "heist": {"history": [result("clean", 50.0, []), result("caught_all", 70.0, ["1", "55"])]},
        }
        with tempfile.TemporaryDirectory() as tmp:
            text, _ = kayit_ozet.summarize([write_json(tmp, "h.json", host)])
        self.assertIn("olaylar koşulara bölünemedi", text)
        self.assertIn("| A1 | Sonuç ve süre | temiz, 50,0 sn | hepsi yakalandı, 70,0 sn |", text)


class RobustnessTest(unittest.TestCase):
    """Old (58aaaa4-era) and damaged dumps: missing sections are skipped, never fatal."""

    CASES = {
        "minimal": {"is_host": True},
        "result_only": {"is_host": True, "heist": {"result": {"outcome": "hot", "duration_s": 40}}},
        "states_only": {
            "is_host": True,
            "owner": {"states": [["agenda", 0.0], ["chase", 12.5], "bozuk"], "detections": [{"peer": 9, "t_detect": 13.0}]},
            "chasers": {"ladder": [[0, 0.0], [2, 12.0], "x", [3]]},
        },
        "garbage": {
            "is_host": True,
            "owner": [],
            "events": "x",
            "players": [1, 2],
            "heist": {"history": [1, "a", {"outcome": None, "players": [], "strategy": "x"}], "cover_reason": "?"},
            "props": {"BackDoor": "kapı", "FrontDoor": {"interact": []}},
            "shop": {"order": None},
            "population": {"arrivals": [["customer"], None, ["passerby", "x"]]},
            "ping_ms": [],
        },
        "bad_log_rows": {
            "is_host": True,
            "owner": {
                "log": [{"why": "t yok"}, {"t": "abc"}, None, {"t": 5, "state": "hold", "target": 3}],
                "rescues": [{"peer": 3}],
                "discoveries": [{"source": "?", "t": 2}],
                "detections": "x",
                "search_questions": [{"peer": 3, "t": 4.0, "value": 61}],
            },
            "events": [run_marker(1), {"kind": "yeni_olay", "data": {"peer": 3, "x": 1}}, {"data": {}}, 5],
        },
    }

    def test_no_crash(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            for name, dump in self.CASES.items():
                with self.subTest(name):
                    text, problems = kayit_ozet.summarize([write_json(tmp, f"{name}.json", dump)])
                    self.assertEqual(problems, [])
                    self.assertIn("## Protokol §2", text)
                    self.assertIn("kayıtta yok", text)
            text = kayit_ozet.summarize([os.path.join(tmp, "states_only.json")])[0]
            self.assertIn("- 12,5 — sahip durumu → chase", text)
            self.assertIn("p9", text)
            text = kayit_ozet.summarize([os.path.join(tmp, "bad_log_rows.json")])[0]
        self.assertIn("5,0–? — sahip p3", text)
        self.assertIn("SORGU (aramada)", text)
        self.assertIn("yeni_olay (peer=p3, x=1)", text)

    def test_no_host_and_unreadable(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            client = write_json(tmp, "c.json", {"is_host": False, "peer_id": 5, "players": {"5": {"name": "Can"}}})
            bad = os.path.join(tmp, "bozuk.json")
            with open(bad, "w", encoding="utf-8") as f:
                f.write("{yarım")
            text, problems = kayit_ozet.summarize([client, bad])
        self.assertTrue(any("bozuk.json" in p and "okunamadı" in p for p in problems), problems)
        self.assertTrue(any("host dosyası yok" in p for p in problems), problems)
        self.assertIn("Can (p5", text)

    def test_accusative(self) -> None:
        for name, want in [
            ("Ikinci", "Ikinci'yi"),
            ("Mustafa", "Mustafa'yı"),
            ("Can", "Can'ı"),
            ("Ömer", "Ömer'i"),
            ("Su", "Su'yu"),
            ("Gül", "Gül'ü"),
            ("p78313522", "p78313522'i"),
        ]:
            self.assertEqual(kayit_ozet.accusative(name), want)

    def test_sec_half_up(self) -> None:
        self.assertEqual(kayit_ozet.sec(129.35), "129,4")
        self.assertEqual(kayit_ozet.sec(None), "?")
        self.assertEqual(kayit_ozet.sec("x"), "?")


class CliTest(unittest.TestCase):
    def test_md_and_stdout(self) -> None:
        dump = {"is_host": True, "owner": {"log": [{"t": 1.0, "state": "agenda", "why": "dönüş kontrolü: kasa dolu"}]}}
        with tempfile.TemporaryDirectory() as tmp:
            src = write_json(tmp, "h.json", dump)
            out = os.path.join(tmp, "alt", "ozet.md")
            buf = io.StringIO()
            with redirect_stdout(buf):
                self.assertEqual(kayit_ozet.main([src, "--md", out]), 0)
            with open(out, encoding="utf-8") as f:
                self.assertIn("dönüş kontrolü: kasa dolu", f.read())
            buf = io.StringIO()
            with redirect_stdout(buf):
                self.assertEqual(kayit_ozet.main([src]), 0)
            self.assertIn("dönüş kontrolü: kasa dolu", buf.getvalue())
            err = io.StringIO()
            with redirect_stderr(err):
                self.assertEqual(kayit_ozet.main([os.path.join(tmp, "yok.json")]), 1)
            self.assertIn("okunamadı", err.getvalue())


if __name__ == "__main__":
    unittest.main(verbosity=2)
