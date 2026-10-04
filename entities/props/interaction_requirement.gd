class_name InteractionRequirement
extends Resource
## Interaction requirement (US-005; S7): optional Interactable condition. Rules live in `core/interaction_rules.gd`; this file is data only
## (S10 pattern). Example: the register can only be emptied from behind the counter (staff side) -> `side` = staff direction in the prop's
## local axes, `side_min` = counter edge.

## Required tag (e.g. &"lockpick"; empty = none) and its minimum tier (Phase 2+: from loadout/perk data).
@export var required_tag: StringName = &""
@export_range(0, 10) var min_tier: int = 0
## Side constraint: direction the actor must be on, in the prop's LOCAL axes (rotates with the prop); ZERO = no constraint.
## Actor must be at least `side_min` px from the Interactable center along this direction.
@export var side: Vector2 = Vector2.ZERO
@export_range(-64.0, 64.0, 1.0, "suffix:px") var side_min: float = 0.0
## IS-106 (KR-037 map independence): derive the side from the level's zones instead of a fixed direction - the direction from the
## prop's tile to its 4-neighbour tile inside zone `side_zone` (S4 zone name, e.g. &"CustomerArea"), or away from it with
## `side_zone_away` (register: behind the counter = away from the customers). `side` (rotated with the prop) stays the hint for ties and
## the fallback without the zone (test scenes). Empty = `side` as written.
@export var side_zone: StringName = &""
@export var side_zone_away: bool = false
