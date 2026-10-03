---
name: metin-ve-tema
description: Recipe for Insiders player-visible text (i18n/texts.csv, tr() keys, naming patterns, text-presence tests) and colour/theme tokens (ui/theme/tokens.gd, regenerating noir.tres). Use when adding UI, NPC balloons, HUD events, heist-end text or new colours.
---

# Text and theme

Rule (mimari.md S9, surec.md §9): no literal player-visible strings; text via `tr()` + `i18n/texts.csv`, colours from theme tokens. Player-facing text is written in Turkish (`tr`) and English (`en`).

## Add text
1. `i18n/texts.csv` (header `keys,tr,en`): row = `KEY,Türkçe,English`. tr and en must be non-empty; placeholders (`%s`, `%d`, `{name}`) identical in both; quote text containing commas.
2. Key format `UPPER_CASE_DIGITS` (`^[A-Z][A-Z0-9]*(_[A-Z0-9]+)+$`).
3. `"$GODOT" --headless --path . --import` (regenerates translations; otherwise `test_translations_match_csv` fails).
4. In code `tr(&"KEY")`; in a `.tscn` text field put the key itself.

## Naming patterns
- `EVENT_<KIND>` - HUD event text; `Hud.event_key(kind)` upper-cases the kind. Exceptions: `ui/hud.gd` `EVENT_KEY_OVERRIDES`; silent: `SILENT_EVENTS`. **Emitting a new `session_event` kind requires its text** (`test_every_session_event_has_hud_text`).
- `OWNER_*`, `CIVILIAN_*` - NPC balloons; add to `BALLOON_KEYS` in `entities/npc/components/npc_visual.gd`.
- `ALERT_T<tier>_<level>` - alert ladder.
- `END_OUTCOME_<OUTCOME>` (+ `_NOTE`), `NOTE_<KIND>` + `NOTE_<KIND>_DESC`, `HUD_*`, `MENU_*`, `INTERACT_*`, `PAUSE_*`.

Checked by `tests/unit/test_ui_texts.gd` (CSV format, translations, no prose in scenes/scripts, every event kind has text).

## Colour / theme
- Single source `ui/theme/tokens.gd` (`ThemeTokens`): BG, FG, ACCENT, SURFACE, `GAMEPLAY_*` (gameplay-meaningful, identical in every tone), PLAYER_COLORS...
- Type variations in `ui/theme/theme_builder.gd` (TitleLabel, CardPanel, HudChip, AlertPanel, AlertLabel, EscapeLabel...).
- After changes: `"$GODOT" --headless --path . -s res://ui/theme/build_themes.gd` -> `ui/theme/noir.tres` (never hand-edit). `test_ui_theme.gd` checks freshness, contrast and "tokens only in scenes".
- Respect the reduce-motion setting (pulses/sway off).
