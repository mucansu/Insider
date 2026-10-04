---
name: ag-senaryosu
description: Recipe for writing and running Insiders multi-process network tests (tests/net/*.json scenario + bot files) with net_smoke. Use for any change in network behaviour, new interactions/NPCs/events, or whenever "green at 0 and 150 ms" evidence is needed.
---

# Network scenario (net_smoke)

Rule (surec.md §9): network behaviour is never merged untested - at least one `tests/net` scenario green at **0 and 150 ms**.
Single source of the schema: the `tools/net_smoke.py` docstring (lines 1-82). This is a summary; check there when unsure.

## Scenario file `tests/net/<name>.json`
Keys (unknown key = FAIL): `_doc`, `level` (required), `player_scene`, `clients` (default 2: c1..cN), `duration` (default 8 s; common dump moment), `start_delay` ({"c2":14}), `quit_after`, `bots`, `names`, `exit_codes`, `allow_log` (regex), `deny_warnings`, `mem_sample_sec`, `timeout`, `expect` (required, non-empty).

```json
{
  "_doc": "US-040: two players walk empty-handed to escape -> aborted. Format: tools/net_smoke.py docstring.",
  "level": "res://tests/fixtures/store_a_nopop.tscn",
  "duration": 14,
  "bots": {"host": "res://tests/net/bots/abort_walk.json", "c1": "res://tests/net/bots/abort_walk.json"},
  "expect": [
    {"eq": ["host.heist.result.outcome", "aborted"]},
    {"same": ["host.heist.result.outcome", "c1.heist.result.outcome"]}
  ]
}
```
- `_doc` (may be Turkish): item id + what is tested + "Biçim: tools/net_smoke.py docstring."
- Path: `<process>.<key>...` (process `host|c1..cN|*`; list index `c1.events.0.kind`; `$host`/`$c1` resolve to peer ids).
- Assertions: `eq ne same all_equal near len has lacks between samples_players samples_near mem_stable`; `between` bounds may be `"$rtt"`, `"$rtt+200"`.
- `ERROR:`/`SCRIPT ERROR:` in a log = automatic FAIL (unless `allow_log`).

## Bot file `tests/net/bots/<name>.json`
`{"steps":[{"t":SEC, ...}]}` - clock starts at the local player's first physics step:
`{"t":1,"move":[x,y]}` · `{"t":2,"hold":"sprint|sneak|interact|intimidate","dur":3}` · `{"t":4,"press":"intimidate"}` · `{"t":5,"look":[x,y]}` · event wait `{"t":5,"wait":"owner_distracted","max":20}` (the clock stops until that session event is seen, later steps shift; use it instead of fixed times for windows that depend on join delay) · host hook `{"t":6,"heist":"alert|police|caught|shout|restart","data":{}}` · `"loop":{"from":F,"period":P}`.
Positions: use markers in `levels/layouts/<level>.txt` (tile = 32 px).

## Pick a fixture (`tests/fixtures/`)
- `store_a_nopop.tscn` - population off (default for most scenarios; no random customers)
- `store_a_quiet.tscn` - no owner, no population, back-room door D open
- `store_a_busy.tscn`, `store_a_late_customer.tscn`, `store_a_backroom_door.tscn`, `store_a_backroom_first.tscn` - special cases
Seeds: no session seed yet (IS-058); use `owner_tuning.agenda_seed`, `population.tres population_seed`, or `agenda_seed_override` in a fixture.

## What the dump contains
Base: `peer_id is_host peers players team_cash level player_nodes events host_lost ping_ms ping alert vision`.
Providers (registered only when `--dump` or `--log-on-exit` is given): `heist`, `owner`, `population`, `chasers`, `player_states`, `interaction`, `noise`, `props`. New field: `Game.register_dump_provider(KEY, callable)` (base keys cannot be overridden). IS-102: host `events` starts with a host-local `level_started {run, level, seed}` marker per level start (clients lack it) - compare peers with `all_equal "heist.events_shared"`, not `events`.

## Run
```bash
PYTHONUTF8=1 python tools/net_smoke.py tests/net/<name>.json
PYTHONUTF8=1 python tools/net_smoke.py tests/net/<name>.json --latency-ms 150
```
On FAIL only failed assertions + a log excerpt are printed; `--keep -v` keeps dumps and full logs. Ports are chosen free, so open game windows do not clash. `tools/ci_local.sh net` runs the `tests/net/*.json` glob at both latencies - adding a file is enough. One scenario takes ~15-100 s; iterate on one scenario, not the whole set.
