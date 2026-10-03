---
name: npc-ekle
description: Recipe for adding an NPC or NPC behaviour to Insiders - scene + brain_*.gd, components (agenda, perception, suspicion, hearing, mover, visual), host-only execution, 15 Hz replication, authority RPC events, MultiplayerSpawner, data/npc tuning, dump. Use for civilians, the shop owner, chasers, guards.
---

# Add / change an NPC

Principle (mimari.md S11): **a new NPC = scene + brain script; perception code does not change.** Rules live node-free under `core/` (`civilian_rules.gd`, `population_rules.gd`, `fsm.gd`...); scenes only apply them. Reactions/edges stay in FSMs (KR-018); utility scoring, if used, only picks among candidates (research oyun-yz.md round 3).

## Layout (`entities/npc/`)
`owner/` (store_owner, brain_owner, owner_reaction) · `civilian/` · `chaser/` · `population.gd` (spawner logic) · `store_alert.gd` · `components/`: `agenda` (+`agenda_task`; seeded, interrupts, `setup_route` linear route), `perception`, `suspicion` (0-100, `threshold_reached`), `hearing` (`noise_listener` group), `sight_line`, `civilian_senses`, `npc_mover` (nav + opening doors), `npc_visual` (balloon, role).

## Runs on the host only
```gdscript
static func _host_side() -> bool:
	return Net.is_host() or Net.local_peer_id() == 0
```
`_ready`: on host `brain.setup(...)`. `step(delta)`: host -> brain -> `move_and_slide` -> write `net_*`; client -> exponential smoothing to `net_position`, snap if > 96 px. `@export var auto_step := true` (tests set false and drive `step()`).

## Replication and events
- Child `MultiplayerSynchronizer` at 15 Hz (`replication_interval = delta_interval = 0.0667`): `net_position`, `net_facing` ALWAYS (unreliable); `net_state` ON_CHANGE (reliable). Round continuous values to 1/16 steps.
- Events: `@rpc("authority", "call_local", "reliable") func _rpc_event(kind: StringName, peer_id: int)`; allowed kinds in `EVENT_KINDS`. Client -> host requests use `any_peer` + validate `get_remote_sender_id()` (S2). One RPC <= 1 KB.
- **Wire format changed => bump `Game.PROTOCOL_VERSION`** (mimari.md S2).

## Spawning and tuning
- `MultiplayerSpawner` (spawn_path = NPCs) + `spawn_function`; host calls `spawner.spawn(data)`; late joiners receive existing NPCs. Add to `levels/<level>.tscn` under NPCs by hand (build_levels preserves it).
- Tuning in `data/npc/<name>_tuning.tres` + `<name>_tuning.gd` (`class_name XTuning extends Resource`); no magic numbers in code.
- Dump: `if not Args.dump_path.is_empty(): Game.register_dump_provider(DUMP_KEY, dump_state)`; host-only fields inside `_host_side()`.
- Balloon/event text: `metin-ve-tema` skill (`BALLOON_KEYS`, `EVENT_*`).

## Before finishing
- Unit tests (`test-yaz`; NpcStage) + at least one `tests/net` scenario at 0/150 ms (`ag-senaryosu`).
- If existing scenarios break, disable in a fixture (`active=false`) - never silently change a scenario; say it in the report.
- `test_deps.gd` layer matrix (core -> no project dir), mimari.md S11/dump appendix.
