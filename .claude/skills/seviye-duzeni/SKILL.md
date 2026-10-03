---
name: seviye-duzeni
description: Recipe for Insiders level layout - levels/layouts/*.txt ASCII grid, marker/zone lines, generating .tscn with build_levels.gd, preserved hand-added nodes, S4 node layout. Use when adding or changing maps, doors, markers or zones.
---

# Level layout

**Never hand-edit the generated part of a level .tscn.** The layout is `levels/layouts/<name>.txt`; the scene is generator output.

## Flow
1. Edit `levels/layouts/<name>.txt`.
2. `"$GODOT" --headless --path . -s res://levels/tools/build_levels.gd -- <name>` (no name = all; exit 1 = error).
3. `bash tools/ci_local.sh import unit` - `test_levels*.gd` checks scene/grid consistency.
4. If store_a changed, run the related net scenarios (`ag-senaryosu`).

## Syntax
- `;` comment.
- `@ <letter> <MarkerName> <floor>` - the letter appears **exactly once** in the grid; `Spawn*` -> SpawnPoints, others -> Markers. Example `@ R Register T`.
- `= <letter> <ZoneName> <floor>` - the letter's cells form a filled rectangle; becomes `Zones/<name>` Area2D. Example `= X EscapeZone _`.
- `= <ZoneName> <col> <row> <w> <h>` - unpainted part; repeating a name = multi-part zone.
- Remaining lines: equal-width tile grid (tile 32 px).

Legend (`levels/level_layout.gd` LEGEND): `%` boundary · `#` wall · `w` shop window (sight passes) · `+` door gap · `.` interior floor · `:` back-room floor · `,` pavement · `_` street · `S` shelf · `T` counter · `I` cooler (blocks sight) · `G` crate (blocks sight).

## Generated vs preserved
- Generated (rebuilt every run): `Tiles, Walls, SpawnPoints, Markers, Zones, Navigation` (a `Navigation/<Door>` NavigationLink2D per door marker).
- **Preserved** (added by hand): `Players, Props, NPCs` and other root nodes (EscapeMarker, Owner, StoreAlert, Population/PopulationSpawner, ChaserSpawner, door instances).
- Every door marker needs a same-named door instance under `Props` (`entities/props/door.tscn`) - IS-086 found D missing.

## S4 layout (mimari.md S4)
Root `Level` (`levels/level.gd`); order Tiles, Walls, SpawnPoints (>= Spawn1..4), Players, Props, NPCs, Markers, Zones, Navigation. Access only through the Level API (`marker`, `marker_sequence`, `zone`, `spawn_position`, `door_link`, `map_rect`, `tier`, `attach_fog`...).
When adding markers/zones update the tables in `tests/unit/test_levels_population.gd` (SINGLES/SEQUENCES/MARKER_ZONES).

## store_a markers
FrontDoor, BackDoor, BackroomDoor, Register, Counter, ClerkSpot, BackroomSafe, BackroomCash, Exit, StreetRoute1..6, NeighbourSpawn, WindowLook1..3, ShopSpot1..5, QueueSpot1..2, RestockSpot1..3, PhoneSpot, BackroomSpot, ShelfProp1..3, Spawn1..4; zones EscapeZone, CustomerArea, StaffArea, Backroom.
