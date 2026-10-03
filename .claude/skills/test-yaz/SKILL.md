---
name: test-yaz
description: Insiders birim test yazma reçetesi (tests/run_tests.gd koşucusu, TestCase assert API'si, yetim düğüm kapısı, tests/contracts.gd sözleşme satırları, sahte Game, NpcStage fikstürü). Yeni modül, kural, UI ya da Game üyesi eklerken kullan.
---

# Birim test

## Dosya ve koşucu
- `tests/unit/test_<konu>.gd`, `extends TestCase`; test = argümansız `func test_*()` (`await` serbest; argümanlı test FAIL). Her test yeni örnekte koşar. Dosya başına `##` açıklama.
- Koş: `"$GODOT" --headless --path . -s res://tests/run_tests.gd -- --filter=test_heist` (`--filter` "dosya.gd::test_adı" etiketinde alt dize; `--timeout=SN`, vars. 30).
- Kapı: `bash tools/ci_local.sh import unit tools` (yeni dosyadan sonra import şart; uyarı/hata bırakma).

## Assert API (`tests/t.gd`; bool döner, testi durdurmaz)
`eq(a,b,msg)` · `ne` · `is_true` · `is_false` · `near(a,b,tol)` (sayı/Vector2) · `has(kap,öğe)` · `fail(msg)` · `allow_errors()` (bilerek push_error) · `autofree(obj)` · `tree()`.
Zincir için: `if not is_true(x, "…"): return`.

## Kapılar
- SCRIPT ERROR her zaman düşürür; push_error `allow_errors()` yoksa düşürür.
- **Yetim düğüm kapısı:** test öncesi/sonrası yetim düğüm farkı 0 olmalı → oluşturduğun her düğümü `autofree(node)` ya da `free()`.
- Çıkışta `leaked|still in use at exit` → unit adımı kırmızı.
- `tools/warn_count.py --gate`: düzey-2 GDScript uyarısı (unsafe_method/property_access) kırmızı. Katı statik tipleme.

## Sözleşmeler (`tests/contracts.gd`)
Net/Game/NoiseBus/Level imzaları `LINES` içinde, `docs/notes/mimari.md` S1/S3/S4/S8 ile birebir. Yeni Game üyesi sırası:
1. mimari.md S3 ekine satır, 2. `LINES["Game"]`'e imza, 3. `tests/unit/test_ui_fakes.gd` `FakeGame`'e aynı imzalı üye.
Henüz yazılmamış üye `PENDING`'e; gelince listeden silinir.

## Sahte Game (UI testleri)
`const Fakes := preload("res://tests/unit/test_ui_fakes.gd")` → `var p := Fakes.make_pair(self)` → `[net, game, journal]`; `hud.net = net; hud.game = game`. Örnek: `tests/unit/test_ui_alert_ladder.gd`.

## NPC sahnesi (`tests/fixtures/npc_stage.gd`)
```gdscript
var stage := NpcStage.new(self)
await stage.enter()            # store_a, senkron nav, auto_step kapalı
var p := stage.player(2, stage.marker(&"Register"))
stage.run(5.0)                 # sabit adım 1/60
# stage.owner() / .population() / .alert() üzerinden durumu doğrula (gerçek API için test_owner.gd'ye bak)
stage.leave()
```
`with_population = true` nüfusu da adımlar. Örnek: `tests/unit/test_owner.gd`.

## Kural testi nerede
Kurallar düğümsüz `core/*.gd` (RefCounted/static) → saf birim testi en ucuzu. Ağ davranışı için ayrıca `ag-senaryosu` skill'i.
