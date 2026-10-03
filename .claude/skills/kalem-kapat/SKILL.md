---
name: kalem-kapat
description: Recipe for finishing, verifying and merging an Insiders backlog item (US-/IS-) - KR-028 light control mode, CI steps, commit format, worktree -> faz2-int merge, conflict-prone files, PROTOCOL_VERSION, board update. Use when work is done, before merging, or when asking "how do I deliver this".
---

# Close an item

Process sources: `docs/surec/surec.md` (§4 DoD, §6 worktrees), `docs/surec/kararlar.md` KR-028, `docs/notes/ajanlar.md` (all in Turkish).

## Current mode: KR-028 (light, temporary)
| Item | Evidence | Independent audit |
|---|---|---|
| Touches network/authority/wire format | ACs + `ci_local.sh import unit tools` + related net scenarios 0/150 ms | light (RPC direction/authority, scenarios) |
| Anything else | ACs with command output + `import unit tools` | none; coordinator reads the diff |
- Fix round only for a **blocker** (crash, failing AC, authority hole, breakage the player sees immediately). Everything else goes to `docs/surec/nit-havuzu.md`; no separate item.
- Full `tools/ci_local.sh` (~18 min) once a day and before a test-N checkpoint.

## CI
`bash tools/ci_local.sh [godot|import|unit|tools|net|export]` - no args = `godot import unit tools net`. import runs twice (WARNING/ERROR on the 2nd = red); unit has a leak gate; tools = Python tool tests + `warn_count --gate`; net = `tests/net/*.json` x {0, 150 ms}.

## If you are an agent
- No commit/push/branch switching (`.claude/hooks/agent_guard.py` blocks it); do not touch board files.
- Report in Turkish, first line `Kalem: US-nnn`; headings **Yapılan / Test / Açık kalan (Nit) / Karar gereken / Sınır dışı** + "nasıl denenir".
- Out-of-scope finding -> "Sınır dışı"; decision -> "Karar gereken" (options + recommendation). Do not ask the user.

## Merge (coordinator)
1. In the worktree: `git add -A` (if no scratch files) -> `git commit -m "US-nnn: <summary>"` (Co-Authored-By trailer last).
2. In `.claude/worktrees/faz2-int`: `git merge --no-ff -q worktree-agent-<id> -m "faz2-int: US-nnn birleştir"`.
3. Conflict-prone files: `autoload/game.gd` (dump keys, PROTOCOL_VERSION), `i18n/texts.csv`, `levels/store_a.tscn` (ext_resource lines), `ui/hud.gd`, `docs/notes/mimari.md` (S3 appendix is one long line) -> **keep both sides' additions**.
4. In the merged tree: `ci_local.sh import unit tools` + touched net scenarios -> `git push origin faz2-int`.
5. Board (dev, main checkout): backlog row `Bitti (faz2-int <hash>; evidence)`, nits to nit-havuzu, decisions to the log -> batched `pano: ...` commit.

## Rules
- **PROTOCOL_VERSION:** bump `Game.PROTOCOL_VERSION` when RPC/synchronizer/handshake layout changes (adding a dict field does not). Friends on an old build cannot connect -> new package (`oyunu-ac`).
- Commit prefixes: `US-nnn:` / `IS-nnn:` / merge `faz2-int: X birleştir` / process-only files `pano:`.
- Phase close: `main` only by fast-forward + `faz-N` tag; the next phase does not start until the user says "devam".
