---
name: metin-ve-tema
description: Insiders oyuncuya görünen metin (i18n/texts.csv, tr() anahtarları, adlandırma kalıpları, metin varlık testi) ve renk/tema token'ı (ui/theme/tokens.gd, noir.tres yeniden üretimi) reçetesi. UI, balon, HUD olayı, iş sonu metni ya da yeni renk eklerken kullan.
---

# Metin ve tema

Kural (mimari.md S9, surec.md §9): oyuncuya görünen sabit dize yok; metin `tr()` + `i18n/texts.csv`, renk tema token'ından.

## Metin ekle
1. `i18n/texts.csv` (başlık `keys,tr,en`): satır = `ANAHTAR,Türkçe,English`. tr ve en boş olamaz; yer tutucular (`%s`, `%d`, `{name}`) iki dilde aynı; virgüllü metin tırnak içinde.
2. Anahtar biçimi `BÜYÜK_HARF_SAYI` (`^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$`).
3. `"$GODOT" --headless --path . --import` (çeviri dosyaları yeniden üretilir; yoksa `test_translations_match_csv` düşer).
4. Kodda `tr(&"ANAHTAR")`; `.tscn`'de text alanına anahtarın kendisi.

## Adlandırma kalıpları
- `EVENT_<TÜR>` — HUD olay metni; `Hud.event_key(kind)` türü büyütür. Kalıba uymayan: `ui/hud.gd` `EVENT_KEY_OVERRIDES`; sessiz: `SILENT_EVENTS`. **Yeni `session_event` türü yayarsan metni şart** (`test_every_session_event_has_hud_text`).
- `OWNER_*`, `CIVILIAN_*` — NPC balonları; `entities/npc/components/npc_visual.gd` `BALLOON_KEYS` eşlemesine ekle.
- `ALERT_T<kademe>_<seviye>` — uyarı merdiveni.
- `END_OUTCOME_<SONUÇ>` (+ `_NOTE`), `NOTE_<KIND>` + `NOTE_<KIND>_DESC`, `HUD_*`, `MENU_*`, `INTERACT_*`, `PAUSE_*`.

Denetleyen test: `tests/unit/test_ui_texts.gd` (CSV biçimi, çeviriler, sahnelerde/betiklerde düzyazı yok, her olay türünün metni var).

## Renk / tema
- Tek kaynak `ui/theme/tokens.gd` (`ThemeTokens`): BG, FG, ACCENT, SURFACE, `GAMEPLAY_*` (oyun anlamlı renkler her tonda aynı), PLAYER_COLORS…
- Tür varyasyonları `ui/theme/theme_builder.gd` (TitleLabel, CardPanel, HudChip, AlertPanel, AlertLabel, EscapeLabel…).
- Değiştirdikten sonra: `"$GODOT" --headless --path . -s res://ui/theme/build_themes.gd` → `ui/theme/noir.tres` (elle düzenlenmez). `test_ui_theme.gd` güncellik, kontrast ve "sahnede yalnız token" denetler.
- Hareket azaltma ayarına saygı (nabız/salınım kapanır).
