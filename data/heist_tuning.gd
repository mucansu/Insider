class_name HeistTuning
extends Resource
## Heist result tuning (US-040 empty-handed abort, IS-103 escape settle, US-041 bail / KR-029, US-042 cover and witness questioning; mimari.md S10 tuning-file pattern).
## Single source is `data/heist_tuning.tres`; defaults here are neutral. Rules are node-free in `HeistRules` (core/heist_rules.gd); Game (host) reads this resource at job start and passes it to the rules.

const PATH := "res://data/heist_tuning.tres"

## Empty-handed abort: seconds all uncaught players stay in the escape zone with no loot before the job ends as `aborted`.
@export_range(0.0, 30.0, 0.1, "suffix:s") var abort_hold_s: float = 0.0
## Escape settle (IS-103, KR-034): seconds all uncaught players stay in the escape zone with loot (nobody shouted yet) before the job is won;
## a shout (alert >= 2) meanwhile ends it as `shouted`. 0 = instant win.
@export_range(0.0, 30.0, 0.1, "suffix:s") var escape_settle_s: float = 0.0
## Bail: venue tier -> amount deducted from team cash for each player caught at job end.
## A tier not in the table uses the nearest lower tier's amount (HeistRules.bail_for_tier).
@export var bail_by_tier: Dictionary[int, int] = {}

@export_group("Örtü ve tanık sorgusu (US-042)")
## Association window: if a friend was marked this many seconds ago (owner shouted/held, mask), a close interaction seen with them breaks cover.
@export_range(0.0, 60.0, 0.1, "suffix:s") var cover_mark_window_s: float = 0.0
## Association distance: max distance between the two interacting players (px).
@export_range(0.0, 256.0, 1.0, "suffix:px") var association_radius_px: float = 0.0
## Suspicion gained against that player by an observer who saw the association (same as the customer-witness path: population.tres
## tell_suspicion).
@export_range(0.0, 100.0, 1.0) var association_suspicion: float = 0.0
## Team heat for each player released by witness questioning.
@export_range(0, 50) var witness_heat: int = 0

static var _default: HeistTuning = null


## `data/heist_tuning.tres` (loaded once per process).
static func load_default() -> HeistTuning:
	if _default == null:
		_default = load(PATH) as HeistTuning
		if _default == null:
			push_error("HeistTuning: %s yüklenemedi" % PATH)
			_default = HeistTuning.new()
	return _default
