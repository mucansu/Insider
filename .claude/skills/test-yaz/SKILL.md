---
name: test-yaz
description: Recipe for Insiders unit tests - tests/run_tests.gd runner, TestCase assert API, orphan-node gate, tests/contracts.gd contract lines, fake Game, NpcStage fixture. Use when adding a module, rule, UI or Game member.
---

# Unit tests

## File and runner
- `tests/unit/test_<topic>.gd`, `extends TestCase`; a test = argument-less `func test_*()` (`await` allowed; a test with arguments FAILS). Each test runs on a fresh instance. Start the file with a `##` description.
- Run: `"$GODOT" --headless --path . -s res://tests/run_tests.gd -- --filter=test_heist` (`--filter` matches a substring of "file.gd::test_name"; `--timeout=SEC`, default 30).
- Gate: `bash tools/ci_local.sh import unit tools` (import after adding files; leave no warnings/errors).

## Assert API (`tests/t.gd`; returns bool, does not stop the test)
`eq(a,b,msg)` · `ne` · `is_true` · `is_false` · `near(a,b,tol)` (number/Vector2) · `has(container,item)` · `fail(msg)` · `allow_errors()` (intentional push_error) · `autofree(obj)` · `tree()`.
Chain with: `if not is_true(x, "..."): return`.

## Gates
- SCRIPT ERROR always fails; push_error fails unless `allow_errors()`.
- **Orphan-node gate:** orphan count before/after each test must be equal -> `autofree(node)` or `free()` everything you create.
- `leaked|still in use at exit` on exit -> unit step red.
- `tools/warn_count.py --gate`: level-2 GDScript warnings (unsafe_method/property_access) are red. Strict static typing.

## Contracts (`tests/contracts.gd`)
Net/Game/NoiseBus/Level signatures in `LINES`, identical to `docs/notes/mimari.md` S1/S3/S4/S8. Adding a Game member:
1. line in the mimari.md S3 appendix, 2. signature in `LINES["Game"]`, 3. same-signature member on `FakeGame` in `tests/unit/test_ui_fakes.gd`.
Members not written yet go in `PENDING`; remove them once they exist.

## Fake Game (UI tests)
`const Fakes := preload("res://tests/unit/test_ui_fakes.gd")` -> `var p := Fakes.make_pair(self)` -> `[net, game, journal]`; `hud.net = net; hud.game = game`. Example: `tests/unit/test_ui_alert_ladder.gd`.

## NPC stage (`tests/fixtures/npc_stage.gd`)
```gdscript
var stage := NpcStage.new(self)
await stage.enter()            # store_a, synchronous nav, auto_step off
var p := stage.player(2, stage.marker(&"Register"))
stage.run(5.0)                 # fixed step 1/60
# assert via stage.owner() / .population() / .alert() (see test_owner.gd for the real API)
stage.leave()
```
`with_population = true` also steps the population. Example: `tests/unit/test_owner.gd`.

## Where rule tests go
Rules are node-free `core/*.gd` (RefCounted/static) -> pure unit tests are cheapest. For network behaviour also use the `ag-senaryosu` skill.
