# Insiders - entry point for developers and AI agents

Common entry point whatever tool you use (Claude Code, Codex, Cursor, another agent, or by hand). Claude-Code-specific coordinator rules are in `CLAUDE.md`; the rules here apply to everyone. Project documents are in Turkish; agent instructions and recipes are in English.

## Project
3-player (2-4) online co-op, top-down 2D heist game for Steam. Godot 4.7.2, GDScript (strict static typing), host-authoritative networking (ENet).

## Read first
1. `docs/project-index.md` - file map (open only what you need).
2. `docs/notes/mimari.md` - directory layout, contracts S1-S11, test layers.
3. `docs/surec/surec.md` §9 - red lines (summary below).
4. Your item's row in `docs/surec/backlog.md` (item id US-/IS-, acceptance criteria).
Single source of design: `docs/tasarim/oyun-tasarimi.md`; decisions: `docs/surec/kararlar.md` (KR-).
Large files: grep for the section and read only that range.

## How-to recipes (skills)
`.claude/skills/<name>/SKILL.md` - one "how to" each. Claude Code loads them automatically; with another tool, read the relevant file:
| Skill | When |
|---|---|
| `test-yaz` | unit tests, contract lines, fake Game, NpcStage |
| `ag-senaryosu` | network behaviour: `tests/net/*.json` + bots, 0/150 ms |
| `npc-ekle` | NPC/behaviour: brain, components, host-only, replication |
| `seviye-duzeni` | maps: ASCII layout, build_levels, preserved nodes |
| `metin-ve-tema` | player-visible text (i18n) and colour tokens |
| `kalem-kapat` | finishing, CI, commit format, merging, PROTOCOL_VERSION |
| `oyunu-ac` | opening the game to test, packages for friends, Tailscale |

## Red lines (surec.md §9)
- A client is authoritative only over its own movement; every other outcome is decided on the host (S2).
- No literal player-visible strings (`tr()` + `i18n/texts.csv`); colours from theme tokens (S9).
- Network behaviour is never merged untested: at least one `tests/net` scenario green at 0 and 150 ms.
- No untyped GDScript; no import warnings/errors.
- No assets with unclear licences (CC0 / explicitly permitted; `docs/notes/assetler.md`).
- `main` only by fast-forward at phase close; no `--force`.

## Way of working
- Branches: `dev` (process/board + merged), phase integration branch (currently `faz2-int`); `main` = last phase release.
- Commit prefix: `US-nnn:` / `IS-nnn:`; process-only files `pano:`.
- Before pushing at least `bash tools/ci_local.sh import unit tools` + the net scenarios you touched (KR-028); full `tools/ci_local.sh` once a day.
- Godot path: `GODOT` env var or `tools/get_godot.sh`. On Windows use Git Bash + Python >= 3.10.
- Bringing your own agents: they must not commit, must not touch board files (`docs/notes/durum.md`, `docs/surec/{backlog,kararlar,gecmis,geri-bildirim,nit-havuzu}.md`), and should report out-of-scope findings and decisions instead of acting on them. This project's Claude agent definitions are examples in `.claude/agents/`; the guard hook is `.claude/hooks/agent_guard.py`.
- Talk to the project owner in Turkish.
