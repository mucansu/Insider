---
name: devir
description: Coordinator handoff recipe for Insiders - closes a work wave so the user can start a fresh chat with short context. Use when a wave of items is merged (e.g. a test package shipped), when the user says "devir", "sohbeti sıfırla", "müsait yerde dur", or when the conversation has grown very long.
---

# Handoff (devir)

Goal: a new chat continues from files alone - `CLAUDE.md` -> `docs/project-index.md` -> `docs/notes/durum.md`. Nothing important may live only in this conversation.

## 1. Reach a clean point
- KR-033: every **slice (dilim) end** is a mandatory handoff — merge the integration branch into dev, tag `dilim-N.M`, then this recipe; the closing message follows surec.md §7 (slice format). If context runs low mid-slice: stop agents, `WIP <id>` commit on their branches, record them in durum.md.
- Prefer handing off when **no agent is running**: a new chat cannot resume an agent's context. If one must keep running, record its worktree path, branch, item id and the exact package text location (backlog row) so the next chat can re-launch it.
- Every finished worktree: commit (`kalem-kapat`), merge into `faz2-int`, `import unit tools` + touched net scenarios, push.
- Run or schedule the daily full `tools/ci_local.sh` if it has not run since the last merges; record the result.

## 2. Rewrite `docs/notes/durum.md` (Turkish, keep it short)
Fixed sections, overwrite stale text instead of appending:
- `# Durum (<date>, <one-line situation>)` + control mode (KR-028) line.
- `## Aktif faz` - phase, integration branch head hash, last package/build.
- `## Sürüyor / yarım kalan` - each with worktree path, branch, what is done, what remains (or "yok").
- `## Yeni sohbette ilk adımlar` - numbered, at most 5, concrete (item ids, commands, which agent).
- `## Kullanıcıdan bekleyen` - decisions (KR ids) and user actions.
- `## Son kapanış` - unchanged unless a phase closed.
Move anything else (history, lessons) to `docs/surec/kararlar.md` log or `gecmis.md`.

## 3. Update the status board
Dashboard artifact: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (db collections `items`, doc `meta/board`; fields: group run|next|done|ask, order, id, title, tag, note, updated ISO time from `date`). Use `ArtifactData` (list -> batch with `if_version`). Move finished items to `done`, set `meta/board.build` and `checkpoint`. Keep the board in step with durum.md.

## 4. Commit and tell the user
- `git add docs && git commit -m "pano: devir noktası — <summary>"` (+ Co-Authored-By), push dev.
- Tell the user in Turkish, 3-5 lines: what is finished, what the next chat will start with, and that they can open a new chat and write "devam" (CLAUDE.md makes the new chat read durum.md). Link the board.

## During normal work (not only at handoff)
Every state change (item started, merged, blocked, new user decision needed) -> one `ArtifactData` batch update of the board, same moment as the backlog edit.
