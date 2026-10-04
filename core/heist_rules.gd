class_name HeistRules
extends RefCounted
## Heist outcome rules (US-012; GDD §9.3 "Loot and outcome", §3 K3; mimari.md S3 addendum). Node-free (KR-003): Game (host) feeds each
## player's view (in escape zone, caught, held, carried bag value, sprinting) to `Tracker` every physics step; `decide` and the result dict (`Tracker.build_result`) come from here.
##
## Rules:
## - Win: every uncaught player is in the escape zone with loot > 0 (carried bag or self-emptied register cash). Outcome by max alert level: <= 1 clean, 2 shouted, >= 3 hot.
## - Loss: everyone caught (`caught_all`) or police arrived (`police_arrived`): those outside the zone are caught; if the rest have loot the job is a hot win, else `police`.
## - held != caught: a held player is not caught (rescuable; US-008 makes them caught when the timer expires).
## - Payout = loot x broker ratio (integer percent, round half up); a caught player's share is 0.
## - Empty-handed abort (US-040): all uncaught players stay in the escape zone with loot 0 for `abort_hold_s` (data/heist_tuning.tres, 3 s) -> `aborted`:
##   share 0, players in the zone count as escaped, heat +5 if alert >= 2. Resets if someone leaves or is caught; loot > 0 triggers the win rule (escape settle below); police arrival the police rule.
## - Escape settle (IS-103, KR-034): when the win condition first holds while max alert < ALERT_SHOUTED and police have not arrived, the job does not end at once:
##   a `escape_settle_s` countdown (data/heist_tuning.tres, 3 s) runs; when it fills the job is won (clean). If alert reaches >= ALERT_SHOUTED meanwhile, the win
##   happens at once with that tier (`shouted`/`hot`, payout rules unchanged). Leaving the zone / a catch / a new outside player cancels it; it restarts from 0 when the condition
##   holds again. Alert already >= ALERT_SHOUTED on arrival (or police): instant win as before. Never overlaps the abort counter (abort needs loot 0, settle loot > 0).
## - Bail (US-041, KR-029): each player caught at job end costs the venue tier's amount (data/heist_tuning.tres) from team cash;
##   cash may go negative (debt), repaid by the next payout. Team cash = before + payout - bail.
## - Cover (US-042; GDD §9.3): per-player "looks like a customer" state on the host. Intact: unmasked, no bag/tool in hand, in the customer zone or outside,
##   walking/idle, and no close (48 px) interaction (PULL, bag handoff) seen by an observer with a friend marked (masked, or shouted at/held by the owner) in the last `cover_mark_window_s` (10 s).
##   Breakers (`cover_breaker`): mask, bag, holding register/cash, staff side, sprinting, sneaking; taking/receiving a bag; a seen association (observer suspicion of that player +60, applied by Game).
##   A broken cover never returns during the job.
## - Witness questioning (US-042): when police arrive, a player outside the escape zone with intact cover, no loot and not held is not caught: `witness_released`
##   (did not escape, not caught; no bail; recognized +1; team heat +2). Released players do not count toward the zone condition: if the rest are in the zone with loot the job is a (hot) win.
## - Strategy label (US-042 AC4, test-2 measurement): `strategy_class` (explicit ordered rules) + `Tracker.strategy`.
## - Bag: each full second of running has a 25% drop chance (noise 160); handoff 0.3 s; take time in data/props/bag.tres.

const OUTCOME_CLEAN := &"clean"
const OUTCOME_SHOUTED := &"shouted"
const OUTCOME_HOT := &"hot"
const OUTCOME_CAUGHT_ALL := &"caught_all"
const OUTCOME_POLICE := &"police"
## Empty-handed abort (US-040): neither a loss nor a win; share 0.
const OUTCOME_ABORTED := &"aborted"
const LOSS_OUTCOMES: Array[StringName] = [OUTCOME_CAUGHT_ALL, OUTCOME_POLICE]
## `decide` return: job continues / won (outcome type from the alert tier) / lost (OUTCOME_POLICE, OUTCOME_CAUGHT_ALL).
const DECISION_NONE := &""
const DECISION_WIN := &"win"

## Alert tiers (S3 addendum, grocery mapping): 2 shouted, 3 neighbourhood arrived (5 police).
const ALERT_SHOUTED := 2
const ALERT_HOT := 3
## Broker ratio (percent). A clean job adds the "nobody shouted" bonus.
const RATIO_PCT_CLEAN := 85
const RATIO_PCT_NO_SHOUT_BONUS := 5
const RATIO_PCT_SHOUTED := 85
const RATIO_PCT_HOT := 70
## Heat change per outcome type (KR-026; only reported in the result until the Phase 4 economy). Single constant block.
const HEAT_CLEAN := 0
const HEAT_SHOUTED := 5
const HEAT_HOT := 10
const HEAT_POLICE := 15
const HEAT_CAUGHT_ALL := 15
## Empty-handed abort: +5 if someone shouted (alert >= ALERT_SHOUTED), else 0 (US-040).
const HEAT_ABORTED_SHOUTED := 5
## Fallback abort-counter duration (s): the real value is data/heist_tuning.tres `abort_hold_s` (Game supplies it).
const ABORT_HOLD_S := 3.0
## Float accumulation tolerance (a sum of 60 Hz steps must not miss 3.0 by 1e-9).
const ABORT_EPS := 1e-6
## Escape settle (IS-103): the real value is data/heist_tuning.tres `escape_settle_s` (Game supplies it). The Tracker's own default is 0 (= no countdown,
## instant win as before IS-103) so rule tests that drive `evaluate` without the tuning keep the old timing.
const ESCAPE_SETTLE_S := 3.0

## Cover (US-042). Fallback values: the real ones are data/heist_tuning.tres (Game supplies them).
const COVER_MARK_WINDOW_S := 10.0
const WITNESS_HEAT := 2
## Player movement mode (same values as PlayerMotion.Mode; duplicated so core does not depend on entities).
const MOVE_WALK := 0  # walk mode
const MOVE_SNEAK := 1
const MOVE_SPRINT := 2  # sprint decision comes from the "sprinting" (moving) field
## Cover-breaking reasons (dump/event data).
const COVER_MASK := &"mask"
const COVER_BAG := &"bag"
const COVER_CASH := &"cash"
const COVER_STAFF := &"staff"
const COVER_RUN := &"run"
const COVER_SNEAK := &"sneak"
const COVER_SEEN_WITH := &"seen_with"

## Strategy classes (US-042 AC4; dump values).
const STRATEGY_TIME := &"zaman"
const STRATEGY_SOCIAL := &"sosyal"
const STRATEGY_NOISE := &"gürültü"
const STRATEGY_BACK_DOOR := &"arka_kapı"
const STRATEGY_COVER := &"örtü"

## Bag (GDD §9.3; card US-012).
const BAG_GROUP := &"loot_bags"
## Drop chance per full second of running.
const BAG_DROP_CHANCE := 0.25
const BAG_DROP_NOISE_RADIUS := 160.0
const BAG_DROP_NOISE_KIND := &"bag_drop"
const HANDOFF_HOLD_TIME := 0.3
## A dropped bag cannot be picked up again before this delay (KR-026; s).
const BAG_RETAKE_DELAY := 0.3
## Tag of an empty-handed player (S7 InteractionRequirement.required_tag): a bag can only be taken/received with free hands.
const FREE_HANDS_TAG := &"free_hands"

## Reason for being caught (for note selection): police (left inside), neighbourhood chaser (US-008), unknown.
const CAUGHT_BY_POLICE := &"police"
const CAUGHT_BY_CHASER := &"chaser"
## Method names that read player state (US-008 player API; false if absent).
const CAUGHT_METHODS: Array[StringName] = [&"is_caught"]
const HELD_METHODS: Array[StringName] = [&"is_held"]
const SPRINT_METHODS: Array[StringName] = [&"is_sprinting"]

## Notes (S3 addendum note kinds; those this item can produce). Priority order is `NOTE_ORDER`.
const NOTE_GHOST_CREW := &"ghost_crew"
const NOTE_SLIPPER := &"slipper"
const NOTE_BAIL := &"bail"
const NOTE_PORTER := &"porter"
const NOTE_MARATHON := &"marathon"
const NOTE_ORDER: Array[StringName] = [NOTE_GHOST_CREW, NOTE_SLIPPER, NOTE_BAIL, NOTE_PORTER, NOTE_MARATHON]
const MAX_NOTES := 3
const MAX_NOTES_PER_PEER := 2
## Minimum sprint seconds for "marathon".
const MARATHON_MIN_S := 5.0


## Type of a won job (from the highest alert tier).
static func win_outcome(max_alert: int) -> StringName:
	if max_alert >= ALERT_HOT:
		return OUTCOME_HOT
	if max_alert >= ALERT_SHOUTED:
		return OUTCOME_SHOUTED
	return OUTCOME_CLEAN


static func is_loss(outcome: StringName) -> bool:
	return LOSS_OUTCOMES.has(outcome)


## Broker ratio (percent); 0 on a loss.
static func ratio_pct(outcome: StringName, shouted: bool) -> int:
	match outcome:
		OUTCOME_CLEAN:
			return RATIO_PCT_CLEAN + (0 if shouted else RATIO_PCT_NO_SHOUT_BONUS)
		OUTCOME_SHOUTED:
			return RATIO_PCT_SHOUTED
		OUTCOME_HOT:
			return RATIO_PCT_HOT
	return 0


## Cover-breaking reason (&"" if none): `view` = {"masked", "bag_value", "holding_cash", "staff_side", "sprinting"
## (running while moving), "move_mode" (MOVE_SNEAK = sneaking)} (a missing field breaks nothing). Order: mask, bag, cash,
## staff side, sprinting, sneaking.
static func cover_breaker(view: Dictionary) -> StringName:
	if bool(view.get("masked", false)):
		return COVER_MASK
	if int(view.get("bag_value", 0)) > 0:
		return COVER_BAG
	if bool(view.get("holding_cash", false)):
		return COVER_CASH
	if bool(view.get("staff_side", false)):
		return COVER_STAFF
	if bool(view.get("sprinting", false)):
		return COVER_RUN
	if int(view.get("move_mode", MOVE_WALK)) == MOVE_SNEAK:
		return COVER_SNEAK
	return &""


## Association (US-042): the interacted friend was marked within the last `window_s` (`marked_age_s` >= 0; -1 if unmarked),
## both are within `radius`, and at least one observer saw it.
static func associates(marked_age_s: float, distance: float, observed: bool, window_s: float, radius: float) -> bool:
	return observed and marked_age_s >= 0.0 and marked_age_s <= window_s and distance <= radius


## Result `players` record of a player who left mid-job (IS-099): `departed` = {"name", "slot"}; no share, no bail, not caught/escaped.
static func left_entry(departed: Dictionary) -> Dictionary:
	return {
		"name": str(departed.get("name", "")),
		"slot": int(departed.get("slot", 0)),
		"escaped": false,
		"caught": false,
		"loot": 0,
		"bail": 0,
		"witness_released": false,
		"recognized": 0,
		"left": true,
	}


## Witness questioning (US-042 AC2): whether a player left outside the zone when police arrive is released.
static func witness_released(cover_intact: bool, loot: int, held: bool) -> bool:
	return cover_intact and loot <= 0 and not held


## Dominant strategy class (US-042 AC4), first match in order: alert >= ALERT_HOT -> NOISE; back door (BackDoor) opened by a player -> BACK_DOOR;
## social action (BUY/stall/send; US-010) > 0 -> SOCIAL; some players' cover intact and some broken -> COVER; otherwise TIME.
static func strategy_class(max_alert: int, back_door_used: bool, social_actions: int, cover_intact: Dictionary) -> StringName:
	if max_alert >= ALERT_HOT:
		return STRATEGY_NOISE
	if back_door_used:
		return STRATEGY_BACK_DOOR
	if social_actions > 0:
		return STRATEGY_SOCIAL
	var intact: int = 0
	for peer: Variant in cover_intact:
		if bool(cover_intact[peer]):
			intact += 1
	if intact > 0 and intact < cover_intact.size():
		return STRATEGY_COVER
	return STRATEGY_TIME


## Heat change; `max_alert` only matters for an empty-handed abort (+5 if someone shouted).
static func heat_for(outcome: StringName, max_alert: int = 0) -> int:
	match outcome:
		OUTCOME_ABORTED:
			return HEAT_ABORTED_SHOUTED if max_alert >= ALERT_SHOUTED else 0
		OUTCOME_CLEAN:
			return HEAT_CLEAN
		OUTCOME_SHOUTED:
			return HEAT_SHOUTED
		OUTCOME_HOT:
			return HEAT_HOT
		OUTCOME_POLICE:
			return HEAT_POLICE
		OUTCOME_CAUGHT_ALL:
			return HEAT_CAUGHT_ALL
	return 0


## Payout = loot x percent / 100, round half up (integer: identical on every peer).
static func payout(loot: int, pct: int) -> int:
	return (maxi(loot, 0) * maxi(pct, 0) + 50) / 100


## Bail amount: the tier itself in `table` (tier -> amount), else the nearest lower tier; 0 if none.
static func bail_for_tier(table: Dictionary, tier: int) -> int:
	var best_tier: int = -1
	var amount: int = 0
	for key: Variant in table:
		var t: int = int(key)
		if t <= tier and t > best_tier:
			best_tier = t
			amount = maxi(int(table[key]), 0)
	return amount


## End-of-job team cash = before + payout - bail - in-job purchases (US-010 BUY; may be negative: debt, repaid by the next payout, KR-029).
static func cash_after(before: int, payout_value: int, bail: int, purchases: int = 0) -> int:
	return before + maxi(payout_value, 0) - maxi(bail, 0) - maxi(purchases, 0)


## Empty-handed abort condition (instant): at least one uncaught player, all in the escape zone, loot 0.
## `players` has the same shape as `decide`. If `secured` >= 0 the loot is the team's secured total (IS-094).
static func abort_ready(players: Dictionary, secured: int = -1) -> bool:
	var free: int = 0
	for peer: Variant in players:
		var p: Dictionary = players[peer]
		if bool(p.get("caught", false)) or bool(p.get("released", false)):
			continue
		free += 1
		if not bool(p.get("in_zone", false)) or (secured < 0 and int(p.get("loot", 0)) > 0):
			return false
	return free > 0 and secured <= 0


## Job state. `players`: peer -> {"caught": bool, "in_zone": bool, "loot": int} (loot: what an uncaught player carries out). `police`: police arrived
## (players outside the zone are already marked caught by the caller). `abort_due`: empty-handed counter is full (AbortClock.done); `aborted` only if the condition still holds.
## `"released": true` (freed by witness questioning, US-042) is skipped in the zone condition like a caught player.
## `secured` >= 0 (IS-094): loot the team secured (register cash that reached team cash, even if the emptier was caught later, plus bags carried by uncaught players);
## it replaces the released players' loot sum, so a caught register-emptier's friends in the zone still win (not an empty-handed abort).
## `win_hold` (IS-103): the escape settle countdown is still running — the win condition returns DECISION_NONE instead of DECISION_WIN (Tracker decides when to hold).
static func decide(players: Dictionary, police: bool, abort_due: bool = false, secured: int = -1,
		win_hold: bool = false) -> StringName:
	if players.is_empty():
		return DECISION_NONE
	var free: int = 0
	var all_in_zone: bool = true
	var loot: int = 0
	for peer: Variant in players:
		var p: Dictionary = players[peer]
		if bool(p.get("caught", false)) or bool(p.get("released", false)):
			continue
		free += 1
		all_in_zone = all_in_zone and bool(p.get("in_zone", false))
		loot += int(p.get("loot", 0))
	if free == 0:
		return OUTCOME_POLICE if police else OUTCOME_CAUGHT_ALL
	if secured >= 0:
		loot = secured
	if all_in_zone and loot > 0:
		return DECISION_NONE if win_hold else DECISION_WIN
	if police:
		return OUTCOME_POLICE
	if abort_due and all_in_zone and loot == 0:
		return OUTCOME_ABORTED
	return DECISION_NONE


## Escape settle condition (IS-103, instant): the win condition holds (at least one uncaught player, all in the escape zone, loot > 0), police aside.
## Same `players`/`secured` shape as `decide`.
static func settle_ready(players: Dictionary, secured: int = -1) -> bool:
	return decide(players, false, false, secured) == DECISION_WIN


## Bag: number of dice to roll when run time goes from `prev_s` to `new_s` (whole seconds crossed).
static func rolls_due(prev_s: float, new_s: float) -> int:
	return maxi(floori(new_s) - floori(maxf(prev_s, 0.0)), 0)


## Bag: whether the roll (0..1) drops it.
static func drops(roll: float) -> bool:
	return roll < BAG_DROP_CHANCE


## True if `node` has one of the given methods and it returns true (false while the US-008 API is absent).
static func node_flag(node: Object, methods: Array[StringName]) -> bool:
	if node == null:
		return false
	for method: StringName in methods:
		if node.has_method(method):
			return bool(node.call(method))
	return false


## Adapts an optional signal (from another item) to the target. The target takes `max_args` params, those after `min_args` default.
## A signal with fewer than `min_args` args yields an invalid Callable (not connected); extras beyond `max_args` are dropped.
static func adapt_callable(target: Callable, signal_args: int, min_args: int, max_args: int) -> Callable:
	if signal_args < min_args:
		return Callable()
	if signal_args > max_args:
		return target.unbind(signal_args - max_args)
	return target


## Note candidates (priority order, each kind at most once): `stats` =
## {"max_alert": int, "caught": {peer: cause}, "bags": {peer: int}, "sprint_s": {peer: float}, "slots": {peer: int}}.
## Ties go to the lower slot. Ghost crew (peer 0 = team): no alert at all.
static func note_candidates(stats: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var slots: Dictionary = stats.get("slots", {})
	var caught: Dictionary = stats.get("caught", {})
	if int(stats.get("max_alert", 0)) <= 0 and caught.is_empty():
		out.append({"kind": NOTE_GHOST_CREW, "peer": 0})
	var by_chaser: Dictionary = {}
	var any_caught: Dictionary = {}
	for peer: Variant in caught:
		any_caught[peer] = 1.0
		if StringName(str(caught[peer])) == CAUGHT_BY_CHASER:
			by_chaser[peer] = 1.0
	_append_top(out, NOTE_SLIPPER, by_chaser, slots, 1.0)
	_append_top(out, NOTE_BAIL, any_caught, slots, 1.0)
	_append_top(out, NOTE_PORTER, stats.get("bags", {}), slots, 1.0)
	_append_top(out, NOTE_MARATHON, stats.get("sprint_s", {}), slots, MARATHON_MIN_S)
	return out


## At most `max_notes` notes from the candidates: each kind once, at most `max_per_peer` per player (team note unlimited).
static func pick_notes(candidates: Array[Dictionary], max_notes: int = MAX_NOTES,
		max_per_peer: int = MAX_NOTES_PER_PEER) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var per_peer: Dictionary = {}
	var kinds: Dictionary = {}
	for c: Dictionary in candidates:
		if out.size() >= max_notes:
			break
		var kind: StringName = StringName(str(c.get("kind", "")))
		var peer: int = int(c.get("peer", 0))
		if kind == &"" or kinds.has(kind):
			continue
		if peer != 0 and int(per_peer.get(peer, 0)) >= max_per_peer:
			continue
		kinds[kind] = true
		if peer != 0:
			per_peer[peer] = int(per_peer.get(peer, 0)) + 1
		out.append({"kind": kind, "peer": peer})
	return out


## Adds the note if the largest of `values` (peer -> number) is not below `min_value`; ties go to the lower slot, then the lower peer.
static func _append_top(out: Array[Dictionary], kind: StringName, values: Dictionary, slots: Dictionary,
		min_value: float) -> void:
	var best_peer: int = 0
	var best: float = -INF
	for key: Variant in values:
		var peer: int = int(key)
		var value: float = float(values[key])
		if value < min_value or peer == 0:
			continue
		if best_peer == 0 or value > best or (is_equal_approx(value, best) and _before(peer, best_peer, slots)):
			best_peer = peer
			best = value
	if best_peer != 0:
		out.append({"kind": kind, "peer": best_peer})


static func _before(a: int, b: int, slots: Dictionary) -> bool:
	var sa: int = int(slots.get(a, 1 << 20))
	var sb: int = int(slots.get(b, 1 << 20))
	return sa < sb if sa != sb else a < b


## Hold counter for the empty-handed abort (US-040) and the escape settle (IS-103): the condition (`abort_ready` / `settle_ready`) is fed every step; it fills after `hold_s` uninterrupted,
## and resets when the condition breaks or `epoch` changes (caught count). Decides inside Tracker on the host; clients only derive the HUD countdown from a local copy.
class AbortClock:
	extends RefCounted

	var hold_s: float = HeistRules.ABORT_HOLD_S
	## Seconds the condition has held uninterrupted; 0 = counter idle.
	var held_s: float = 0.0
	## Longest time seen on this counter (dump/diagnostics only).
	var peak_s: float = 0.0
	var _epoch: int = 0

	func _init(hold: float = HeistRules.ABORT_HOLD_S) -> void:
		hold_s = maxf(hold, 0.0)

	## `epoch`: restarts the counter when it changes (e.g. caught count; counts as an interruption even if the condition holds).
	func step(holding: bool, delta: float, epoch: int = 0) -> void:
		if epoch != _epoch:
			_epoch = epoch
			held_s = 0.0
		held_s = held_s + maxf(delta, 0.0) if holding else 0.0
		peak_s = maxf(peak_s, held_s)

	func running() -> bool:
		return held_s > 0.0

	func done() -> bool:
		return running() and held_s >= hold_s - HeistRules.ABORT_EPS

	## Seconds left; -1 if the counter is idle.
	func left() -> float:
		return maxf(hold_s - held_s, 0.0) if running() else -1.0


## Per-job counters and decision on the host. Game calls `observe` + `evaluate` every physics step; events (alert, police,
## caught, register cash, bag pickup) come in through the matching methods. View (`views`):
## peer -> {"in_zone": bool, "caught": bool, "held": bool, "bag_value": int, "sprinting": bool}.
class Tracker:
	extends RefCounted

	var elapsed: float = 0.0
	var max_alert: int = 0
	var shouts: int = 0
	var police: bool = false
	var finished: bool = false
	## peer -> reason caught (StringName; &"" unknown).
	var caught: Dictionary = {}
	## peer -> cash emptied (register; already in team cash, counts as loot if they escape).
	var cash: Dictionary = {}
	## peer -> bags taken/received.
	var bags: Dictionary = {}
	## peer -> sprint seconds.
	var sprint_s: Dictionary = {}
	## Empty-handed abort counter (US-040); Game sets `abort.hold_s` from data/heist_tuning.tres.
	var abort: HeistRules.AbortClock = HeistRules.AbortClock.new()
	## Escape settle counter (IS-103); Game sets `settle.hold_s` from data/heist_tuning.tres `escape_settle_s`. 0 = no countdown (instant win).
	var settle: HeistRules.AbortClock = HeistRules.AbortClock.new(0.0)
	## Cover (US-042): peer -> breaking reason (absent = intact). Once broken it never returns.
	var cover_broken: Dictionary = {}
	## Newly broken covers (Game drains this each step and emits events): [{"peer", "reason"}].
	var cover_events: Array[Dictionary] = []
	## peer -> time marked (`elapsed`; owner shouted/held, mask): association window.
	var marked_at: Dictionary = {}
	var cover_mark_window_s: float = HeistRules.COVER_MARK_WINDOW_S
	## Released by witness questioning (peer -> true; US-042 AC2).
	var released: Dictionary = {}
	var witness_heat: int = HeistRules.WITNESS_HEAT
	## Strategy label inputs (US-042 AC4).
	var interactions: int = 0
	var social_actions: int = 0
	var back_door_used: bool = false
	var register_emptied_at_s: float = -1.0
	var cash_bag_taken_at_s: float = -1.0
	## Purchases paid from team cash during the job (US-010 BUY cost; deducted from end-of-job cash).
	var purchases_paid: int = 0
	## Extra recognition (US-044: player questioned by the owner at the door while staring at the window): peer -> count.
	var recognized_extra: Dictionary = {}
	## Players who left the session mid-job (IS-099): peer -> {"name", "slot"} (roster entry at the moment they left).
	## They appear in the result's `players` with `left: true`; economy is unchanged (no share, no bail).
	var departed: Dictionary = {}

	func set_alert(level: int) -> void:
		max_alert = maxi(max_alert, level)

	func note_shout() -> void:
		shouts += 1

	## Whether anyone shouted (otherwise the "nobody shouted" bonus applies).
	func shouted() -> bool:
		return shouts > 0 or max_alert >= HeistRules.ALERT_SHOUTED

	func mark_caught(peer: int, cause: StringName = &"") -> void:
		if peer <= 0:
			return
		if not caught.has(peer) or str(caught[peer]).is_empty():
			caught[peer] = cause

	func is_caught(peer: int) -> bool:
		return caught.has(peer)

	func add_cash(peer: int, amount: int) -> void:
		if peer > 0 and amount > 0:
			cash[peer] = int(cash.get(peer, 0)) + amount
			if register_emptied_at_s < 0.0:
				register_emptied_at_s = snappedf(elapsed, 0.01)

	## Total loot cash that entered team cash during the job (replaced by the payout at the end).
	func cash_grabbed() -> int:
		var total: int = 0
		for peer: Variant in cash:
			total += int(cash[peer])
		return total

	func note_bag(peer: int) -> void:
		if peer > 0:
			bags[peer] = int(bags.get(peer, 0)) + 1
			break_cover(peer, HeistRules.COVER_BAG)
			if cash_bag_taken_at_s < 0.0:
				cash_bag_taken_at_s = snappedf(elapsed, 0.01)

	## An interaction completed by a player (strategy label; US-042 AC4).
	func note_interaction(peer: int) -> void:
		if peer > 0:
			interactions += 1

	## Social action (BUY / stall / send; US-010 hooks in).
	## BUY cost paid (US-010; deducted from team cash immediately).
	func note_purchase(cost: int) -> void:
		purchases_paid += maxi(cost, 0)

	## The owner recognised the player (US-044 window questioning): `recognized` +1 in the result.
	func note_recognized(peer: int) -> void:
		if peer > 0:
			recognized_extra[peer] = int(recognized_extra.get(peer, 0)) + 1

	func note_social(peer: int) -> void:
		if peer > 0:
			social_actions += 1

	# --- cover (US-042) ---

	func cover_intact(peer: int) -> bool:
		return not cover_broken.has(peer)

	## Breaks cover; true and appended to `cover_events` if newly broken.
	func break_cover(peer: int, reason: StringName) -> bool:
		if peer <= 0 or cover_broken.has(peer):
			return false
		cover_broken[peer] = reason
		cover_events.append({"peer": peer, "reason": reason})
		return true

	## Owner shouted/held (or mask): the association window counts from now.
	func mark_target(peer: int) -> void:
		if peer > 0:
			marked_at[peer] = elapsed

	## Seconds since marked; -1 if never marked.
	func marked_age(peer: int) -> float:
		return elapsed - float(marked_at[peer]) if marked_at.has(peer) else -1.0

	## Association attempt: `actor` interacted with marked `other` at `distance` px; `observed` = an observer saw it.
	## If the rule matches, cover breaks and returns true (Game gives observers +60).
	func associate(actor: int, other: int, distance: float, observed: bool, radius: float) -> bool:
		if not HeistRules.associates(marked_age(other), distance, observed, cover_mark_window_s, radius):
			return false
		break_cover(actor, HeistRules.COVER_SEEN_WITH)
		return true

	func is_released(peer: int) -> bool:
		return released.has(peer)

	## A player left the session mid-job (IS-099); `entry` = their roster entry {"name", "slot"}. Ignored once the job is finished.
	func note_left(peer: int, entry: Dictionary) -> void:
		if finished or peer <= 0:
			return
		departed[peer] = {"name": str(entry.get("name", "")), "slot": int(entry.get("slot", 0))}

	## Police arrived: every uncaught player outside the escape zone is caught (held included); one with intact cover, no loot
	## and not held is released by witness questioning (US-042 AC2).
	func arrive_police(views: Dictionary) -> void:
		police = true
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			var id: int = int(peer)
			if bool(v.get("in_zone", false)) or is_caught(id):
				continue
			var loot: int = int(cash.get(id, 0)) + int(v.get("bag_value", 0))
			if HeistRules.witness_released(cover_intact(id) and HeistRules.cover_breaker(v).is_empty(), loot,
					bool(v.get("held", false))):
				released[id] = true
			else:
				mark_caught(id, HeistRules.CAUGHT_BY_POLICE)

	## One time step: elapsed time and sprint times; catches reported by the player API are recorded permanently
	## (held is not recorded: a held player is not caught).
	func observe(views: Dictionary, delta: float) -> void:
		elapsed += maxf(delta, 0.0)
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			if bool(v.get("caught", false)):
				mark_caught(int(peer))
			if bool(v.get("sprinting", false)):
				sprint_s[int(peer)] = float(sprint_s.get(int(peer), 0.0)) + maxf(delta, 0.0)
			if not is_caught(int(peer)) and cover_intact(int(peer)):
				var reason: StringName = HeistRules.cover_breaker(v)
				if not reason.is_empty():
					break_cover(int(peer), reason)
		var state: Dictionary = players_state(views)
		var secured: int = secured_loot(views)
		abort.step(not police and HeistRules.abort_ready(state, secured), delta, caught.size())
		settle.step(settle_applies() and HeistRules.settle_ready(state, secured), delta, caught.size())

	## Escape settle can run (IS-103): a countdown is configured, police have not arrived and nobody has shouted yet (max alert < ALERT_SHOUTED);
	## otherwise the win is instant.
	func settle_applies() -> bool:
		return settle.hold_s > HeistRules.ABORT_EPS and not police and max_alert < HeistRules.ALERT_SHOUTED

	## The win is being held back by the escape settle countdown (condition may or may not hold; `decide` only applies it to the win rule).
	func settle_pending() -> bool:
		return settle_applies() and not settle.done()

	## Rule input: peer -> {"caught", "in_zone", "loot"}.
	func players_state(views: Dictionary) -> Dictionary:
		var out: Dictionary = {}
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			var id: int = int(peer)
			var is_caught_now: bool = is_caught(id) or bool(v.get("caught", false))
			out[id] = {
				"caught": is_caught_now,
				"released": released.has(id) and not is_caught_now,
				"in_zone": bool(v.get("in_zone", false)),
				"loot": 0 if is_caught_now else int(cash.get(id, 0)) + int(v.get("bag_value", 0)),
			}
		return out

	func evaluate(views: Dictionary) -> StringName:
		if finished:
			return HeistRules.DECISION_NONE
		return HeistRules.decide(players_state(views), police, abort.done(), secured_loot(views), settle_pending())

	## Loot the team secured (IS-094): register cash that entered team cash during the job (stays even if the emptier is caught later)
	## plus bags carried by uncaught (and not witness-released) players (a caught player's bag is lost).
	func secured_loot(views: Dictionary) -> int:
		var total: int = cash_grabbed()
		for peer: Variant in views:
			var v: Dictionary = views[peer]
			var id: int = int(peer)
			if is_caught(id) or released.has(id) or bool(v.get("caught", false)):
				continue
			total += maxi(int(v.get("bag_value", 0)), 0)
		return total

	## Result dict (S3 addendum): `roster` = Game.players() (peer -> {"name", "slot"}). `bail_each`: bail per caught player (KR-029);
	## `players[str(peer)]` = {"name", "slot", "escaped", "caught", "loot", "bail", "witness_released", "recognized", "left"};
	## `left` is true only for a player who left mid-job (IS-099, see `left_entry`), false for everyone in the roster.
	## `cash_before`: team cash before the job (excluding raw register cash that entered instantly).
	func build_result(decision: StringName, views: Dictionary, roster: Dictionary, bail_each: int = 0,
			cash_before: int = 0) -> Dictionary:
		var win: bool = decision == HeistRules.DECISION_WIN
		var outcome: StringName = HeistRules.win_outcome(max_alert) if win else decision
		var got_away: bool = win or outcome == HeistRules.OUTCOME_ABORTED
		var state: Dictionary = players_state(views)
		var players: Dictionary = {}
		var slots: Dictionary = {}
		var loot_total: int = 0
		var bail_total: int = 0
		var witnesses: int = 0
		for key: Variant in roster:
			var id: int = int(key)
			var entry: Dictionary = roster[key]
			var s: Dictionary = state.get(id, {"caught": is_caught(id), "released": is_released(id), "in_zone": false,
				"loot": 0})
			var escaped: bool = got_away and not bool(s["caught"]) and bool(s["in_zone"])
			var loot: int = int(s["loot"]) if escaped and win else 0
			var bail: int = maxi(bail_each, 0) if bool(s["caught"]) else 0
			var witness: bool = bool(s.get("released", false))
			if witness:
				witnesses += 1
			loot_total += loot
			bail_total += bail
			slots[id] = int(entry.get("slot", 0))
			players[str(id)] = {
				"name": str(entry.get("name", "")),
				"slot": int(entry.get("slot", 0)),
				"escaped": escaped,
				"caught": bool(s["caught"]),
				"loot": loot,
				"bail": bail,
				"witness_released": witness,
				"recognized": (1 if witness else 0) + int(recognized_extra.get(id, 0)),
				"left": false,
			}
		# IS-099: players who left mid-job are listed with `left: true` and zero share/bail (economy as before: they are not
		# in the roster, so they never counted toward loot, bail, notes or strategy).
		for key: Variant in departed:
			var id: int = int(key)
			if players.has(str(id)):
				continue
			players[str(id)] = HeistRules.left_entry(departed[key])
		var pct: int = HeistRules.ratio_pct(outcome, shouted())
		var caught_now: Dictionary = {}
		for id: Variant in state:
			if bool((state[id] as Dictionary)["caught"]):
				caught_now[int(id)] = caught.get(int(id), &"")
		var stats: Dictionary = {
			"max_alert": max_alert, "caught": caught_now, "bags": bags, "sprint_s": sprint_s, "slots": slots,
		}
		# Payout comes from the loot the team secured (IS-094): a caught register-emptier's cash stays with the team, their personal
		# share is 0; when everyone escapes this equals the old "sum of escapees' loot".
		if win:
			loot_total = secured_loot(views)
		var paid: int = HeistRules.payout(loot_total, pct)
		return {
			"outcome": outcome,
			"loot_total": loot_total,
			"payout_ratio": pct / 100.0,
			"payout": paid,
			"duration_s": snappedf(elapsed, 0.01),
			"players": players,
			"notes": HeistRules.pick_notes(HeistRules.note_candidates(stats)),
			"heat": HeistRules.heat_for(outcome, max_alert) + witnesses * maxi(witness_heat, 0),
			"max_alert": max_alert,
			"bail": bail_total,
			"purchases": purchases_paid,
			"cash_before": cash_before,
			"cash_after": HeistRules.cash_after(cash_before, paid, bail_total, purchases_paid),
			"strategy": strategy(roster),
		}

	## Strategy label (US-042 AC4): {class, interactions, max_alert, back_door_used, cover_intact {peer: bool},
	## register_emptied_at_s, cash_bag_taken_at_s} (-1 if the moment never happened).
	func strategy(roster: Dictionary) -> Dictionary:
		var intact: Dictionary = {}
		for key: Variant in roster:
			intact[str(int(key))] = cover_intact(int(key))
		return {
			"class": HeistRules.strategy_class(max_alert, back_door_used, social_actions, intact),
			"interactions": interactions,
			"max_alert": max_alert,
			"back_door_used": back_door_used,
			"cover_intact": intact,
			"register_emptied_at_s": register_emptied_at_s,
			"cash_bag_taken_at_s": cash_bag_taken_at_s,
		}
