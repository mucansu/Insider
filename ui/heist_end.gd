class_name HeistEnd
extends Control
## Heist end screen (US-013 minimum 2a; S3 addendum heist_finished, KR-021; oyun-testi-ve-klip §4).
## Shows result title, duration, payout rows (loot x rate = payout), player rows (slot colour, name, escaped/caught, loot) and notes (NOTE_<KIND> + NOTE_<KIND>_DESC; generic text + warning if the key is missing),
## "Again" (host only, and only if Game has `request_restart()`; S3 addendum) and "Menu" (`menu_requested`). Does no maths: numbers come from the `result` dictionary. The loss screen is a variant of the same scene (title ALERT, rest FG).
## Blocks gameplay input while open (S5). HUD calls `bind(game, net)`; a late joiner gets `heist_result()`.
## US-040: `aborted` (empty-handed retreat) is not a loss: normal title. US-041 (KR-029): caught row shows bail, "- Bail" under the payout (if total > 0) and "Team cash a -> b" (if the result has `cash_before`/`cash_after`); negatives in the alert colour.
## US-042: a player released after witness questioning (`witness_released`) gets END_STATUS_WITNESS on their row; for the local player END_WITNESS_RELEASED (dim) under the title.
## US-053: otherwise a local player with `recognized` > 0 (including the owner's prep recognition, KR-046) reads END_RECOGNIZED (dim) there.
## US-051 (KR-044): session score table. Every shown result is recorded in `scores` (SessionScores, per process, local to this peer);
## the header always shows the session's fastest clean escape, the "Session scores" button swaps the body (payout/crew/notes) for the
## table (no, map, outcome, time, clean, crew cash change, strategy; this job's row on a panel, bests highlighted). The store is reset
## when the screen leaves the tree with the session over (Net offline: menu, lost host, failed connection).
## US-050 (KR-044): "Another shop" (host only, and only if Game has `map_list()` + `request_map_switch()`; S3 addendum) next to "Again":
## a drop-down of the other registry maps (the one after the current map first); picking one calls Game.request_map_switch() — every
## peer loads it in-session (prep), the score table survives (Net stays online).

## "Again" (host): request to restart the level; emitted after Game.request_restart() is called.
signal retry_requested()
## "Another shop" (host): emitted with the picked map after Game.request_map_switch() accepted it.
signal map_switch_requested(level_path: String)
## "Menu": leave the session and return to the main menu.
signal menu_requested()
## Screen opened (the HUD closes the pause menu).
signal opened()

## Loss results: title in the alert colour.
const LOSS_OUTCOMES: Array[StringName] = [&"caught_all", &"police"]
## Sound catalogue events (data/sfx_catalog.tres; IS-024).
const STINGER_WIN := &"stinger_success"
const STINGER_LOSS := &"stinger_caught"
const OUTCOME_KEY_PREFIX := "END_OUTCOME_"
const NOTE_KEY_PREFIX := "NOTE_"
const DESC_SUFFIX := "_DESC"
const NOTE_SUFFIX := "_NOTE"
## Single screen at 1280x720: at most this many notes shown (production rule lives in Game, US-012).
const MAX_NOTES := 3
const SWATCH_SIZE := Vector2(14, 14)
## Player name column width; long names are ellipsised.
const NAME_WIDTH := 240.0
## Caught cause (US-038 AC5): collected on every peer from session events (S3 addendum `player_caught {peer, by}`, `police_arrived`); a player not caught by an event
## counts as police if the result is POLICE or police arrived (police caught them outside the escape zone). Texts: END_STATUS_CAUGHT_<CAUSE> (player row), END_CAUSE_<CAUSE> (local player).
const CAUSE_POLICE := &"police"
const CAUSE_CHASER := &"chaser"
const CAUSE_OWNER := &"owner"
const EVENT_CAUGHT := &"player_caught"
const EVENT_POLICE := &"police_arrived"
const STATUS_CAUGHT_PREFIX := "END_STATUS_CAUGHT_"
const CAUSE_KEY_PREFIX := "END_CAUSE_"
## Score table column widths (px; map/outcome/strategy stretch by these ratios and ellipsise). CASH_COLUMN is right-aligned.
const COL_NO := 64.0
const COL_TIME := 96.0
const COL_CLEAN := 96.0
const COL_CASH := 176.0
const COL_MAP_RATIO := 1.0
const COL_OUTCOME_RATIO := 1.5
const COL_STRATEGY_RATIO := 0.9
const CASH_COLUMN := 5

var net: Object = null
var game: Object = null
## Missing-text-key notification (HUD binds; tests catch it); push_warning if unhandled.
var warn: Callable
## Session score store (US-051); tests inject their own.
var scores: SessionScores = SessionScores.shared()

var _result: Dictionary = {}
## peer -> catcher (&"chaser" | &"owner"), from `player_caught` events (first record stays).
var _caught_by: Dictionary = {}
## Whether a `police_arrived` event was seen this level.
var _police_seen: bool = false
## "Another shop" choices in drop-down order (popup item id = index): {"path", "name_key"}.
var _map_choices: Array[Dictionary] = []

@onready var _title: Label = %OutcomeTitle
@onready var _outcome_note: Label = %OutcomeNote
@onready var _cause_note: Label = %CauseNote
@onready var _duration: Label = %DurationValue
@onready var _payout_grid: GridContainer = %PayoutGrid
@onready var _player_grid: GridContainer = %PlayerGrid
@onready var _notes_box: Control = %NotesBox
@onready var _note_row: HBoxContainer = %NoteRow
@onready var _retry_button: Button = %RetryButton
@onready var _map_button: MenuButton = %MapButton
@onready var _retry_hint: Label = %RetryHint
@onready var _menu_button: Button = %MenuButton
@onready var _scores_button: Button = %ScoresButton
@onready var _best_value: Label = %BestValue
@onready var _body: Control = $Center/Card/Box/Body
@onready var _scores_box: Control = %ScoresBox
@onready var _scores_table: VBoxContainer = %ScoresTable
@onready var _scores_best: Label = %ScoresBest


func _ready() -> void:
	ThemeTokens.apply(self)
	UiSfx.wire_buttons(self)
	hide()
	UiInput.block_gameplay_while_visible(self)
	_retry_button.pressed.connect(_on_retry_pressed)
	_map_button.get_popup().auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED  # items are already translated map names
	_map_button.get_popup().id_pressed.connect(_on_map_picked)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	_scores_button.pressed.connect(func() -> void: show_scores(not scores_shown()))
	_link_buttons()
	_fill_scores_button()


func _exit_tree() -> void:
	# Session over (menu / host lost / connection failed: Net offline) -> the next session starts with an empty table.
	# A level restart re-creates the HUD while still online: the table survives.
	if net != null and net.has_method(&"is_online") and not bool(net.call(&"is_online")):
		scores.reset()


## Left/right ring over the visible buttons (Retry is hidden on clients); up/down stay put; Tab ring.
func _link_buttons() -> void:
	var ring: Array[Control] = []
	for b: Button in [_retry_button, _map_button, _scores_button, _menu_button]:
		if b.visible:
			ring.append(b)
	UiInput.tab_ring(ring)
	var n: int = ring.size()
	for i: int in n:
		UiInput.link(ring[i], SIDE_RIGHT, ring[(i + 1) % n])
		UiInput.link(ring[i], SIDE_LEFT, ring[(i - 1 + n) % n])
		UiInput.link(ring[i], SIDE_TOP, ring[i])
		UiInput.link(ring[i], SIDE_BOTTOM, ring[i])


## Binds to Game (S3 addendum); if the heist already ended (late join) shows the result immediately.
func bind(game_source: Object, net_source: Object) -> void:
	game = game_source
	net = net_source
	if game == null:
		return
	if game.has_signal(&"session_event"):
		game.connect(&"session_event", _on_session_event)
	if game.has_signal(&"heist_finished"):
		game.connect(&"heist_finished", show_result)
	if game.has_method(&"heist_result"):
		var existing: Dictionary = game.call(&"heist_result")
		if not existing.is_empty():
			show_result(existing)


func is_open() -> bool:
	return visible


func result() -> Dictionary:
	return _result


func show_result(value: Dictionary) -> void:
	_result = value
	scores.record(value, _level_path())
	_fill_header()
	_fill_payout()
	_fill_players()
	_fill_cause()
	_fill_notes()
	_fill_scores()
	show_scores(false)
	var host: bool = _is_host()
	_retry_button.visible = host and can_restart()
	_fill_map_choices()
	_map_button.visible = host and not _map_choices.is_empty()
	_retry_hint.visible = not host
	_link_buttons()
	show()
	opened.emit()
	(_retry_button if _retry_button.visible else _menu_button).grab_focus()
	UiSfx.of(self).play_event(stinger_event())  # after the focus tick: do not cut off the stinger


## Whether "Again" can be offered: Game has the S3 addendum restart request.
func can_restart() -> bool:
	return game != null and game.has_method(&"request_restart")


func _is_host() -> bool:
	return net != null and bool(net.call(&"is_host"))


## Only the host may request (S3 addendum: request_restart is host-only); the button is already hidden on clients.
func _on_retry_pressed() -> void:
	if not (_is_host() and can_restart()):
		return
	game.call(&"request_restart")
	retry_requested.emit()


# --- "Another shop" (US-050) ---

## Whether "Another shop" can be offered: Game has the S3 addendum map list + switch.
func can_switch_map() -> bool:
	return game != null and game.has_method(&"map_list") and game.has_method(&"request_map_switch")


## Other registry maps, the one after the current map first (wraps); every map if the current one is not listed (fixture).
func map_choices() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if not can_switch_map():
		return out
	var maps: Array = game.call(&"map_list")
	var current: String = _level_path()
	var at: int = -1
	for i: int in maps.size():
		if str((maps[i] as Dictionary).get("path", "")) == current:
			at = i
	for i: int in maps.size():
		if at >= 0 and i == 0:
			continue  # skip the current map itself
		out.append((maps[(maxi(at, 0) + i) % maps.size()] as Dictionary).duplicate())
	return out


func _fill_map_choices() -> void:
	_map_choices = map_choices()
	var popup: PopupMenu = _map_button.get_popup()
	popup.clear()
	for i: int in _map_choices.size():
		popup.add_item(tr(StringName(str(_map_choices[i].get("name_key", "")))), i)


## Popup pick: only the host may switch (S3 addendum: request_map_switch is host-only); the button is hidden on clients.
func _on_map_picked(id: int) -> void:
	if not (_is_host() and can_switch_map()) or id < 0 or id >= _map_choices.size():
		return
	var level_path: String = str(_map_choices[id]["path"])
	if bool(game.call(&"request_map_switch", level_path)):
		MainMenu.remembered_map = level_path
		map_switch_requested.emit(level_path)


# --- title ---

func outcome() -> StringName:
	return StringName(str(_result.get("outcome", "")))


## Opening accent (IS-024; ses-ve-sfx §1 rule 5): caught stinger on a loss, otherwise a short positive jingle.
func stinger_event() -> StringName:
	return STINGER_LOSS if LOSS_OUTCOMES.has(outcome()) else STINGER_WIN


func _fill_header() -> void:
	var key: String = OUTCOME_KEY_PREFIX + String(outcome()).to_upper()
	var title: String = tr(key)
	var known: bool = title != key and not String(outcome()).is_empty()
	if not known:
		_warn(key)
		title = tr(&"END_OUTCOME_GENERIC")
	_title.text = title
	_title.theme_type_variation = &"AlertTitleLabel" if LOSS_OUTCOMES.has(outcome()) else &"TitleLabel"
	var note_key: String = key + NOTE_SUFFIX
	var note: String = tr(note_key) if known else note_key
	_outcome_note.text = note if note != note_key else ""
	_outcome_note.visible = not _outcome_note.text.is_empty()
	_duration.text = Hud.format_clock(float(_result.get("duration_s", 0.0)))
	var best_no: int = int(scores.best()[SessionScores.BEST_FASTEST_CLEAN])
	_best_value.text = tr(&"END_LOOT_NONE") if best_no == 0 else _best_text(scores.run_by_no(best_no))


# --- payout ---

func _fill_payout() -> void:
	_clear(_payout_grid)
	var ratio_pct: int = roundi(float(_result.get("payout_ratio", 0.0)) * 100.0)
	_payout_row(tr(&"END_LOOT"), _cash(int(_result.get("loot_total", 0))), &"HeadingLabel")
	_payout_row(tr(&"END_RATIO"), tr(&"END_RATIO_VALUE") % ratio_pct, &"HeadingLabel")
	_payout_row(tr(&"END_PAYOUT"), _cash(int(_result.get("payout", 0))), &"CashLabel")
	var bail: int = int(_result.get("bail", 0))
	if bail > 0:
		_payout_row(tr(&"END_BAIL"), _cash(-bail), &"AlertLabel")
	if _result.has("cash_before") and _result.has("cash_after"):
		var after: int = int(_result["cash_after"])
		var change: String = tr(&"END_TEAM_CASH_CHANGE") % [_cash(int(_result["cash_before"])), _cash(after)]
		_payout_row(tr(&"END_TEAM_CASH"), change, &"AlertLabel" if after < 0 else &"CashLabel")


func _payout_row(caption: String, value: String, value_style: StringName) -> void:
	var name_label: Label = _label(caption, &"")
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_payout_grid.add_child(name_label)
	var value_label: Label = _label(value, value_style)
	value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_payout_grid.add_child(value_label)


# --- players ---

## Players in the result, in slot order: [{peer, name, slot, escaped, caught, loot, bail, witness, left}].
## IS-099: `left` = the player disconnected mid-heist; the row shows only "left" (no caught/escaped/bail, loot "—").
func player_entries() -> Array[Dictionary]:
	var players: Dictionary = _result.get("players", {})
	var out: Array[Dictionary] = []
	for key: Variant in players:
		var info: Dictionary = players[key]
		out.append({
			"peer": int(str(key)),
			"name": str(info.get("name", "")),
			"slot": int(info.get("slot", out.size())),
			"escaped": bool(info.get("escaped", false)),
			"caught": bool(info.get("caught", false)),
			"loot": int(info.get("loot", 0)),
			"bail": int(info.get("bail", 0)),
			"witness": bool(info.get("witness_released", false)),
			"recognized": int(info.get("recognized", 0)),
			"left": bool(info.get("left", false)),
		})
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["slot"] < b["slot"] if a["slot"] != b["slot"] else a["peer"] < b["peer"])
	return out


func _fill_players() -> void:
	_clear(_player_grid)
	var local_id: int = int(net.call(&"local_peer_id")) if net != null else 0
	for p: Dictionary in player_entries():
		_player_grid.add_child(_swatch(int(p["slot"])))
		var label: Label = _label(_player_name(p, local_id), &"")
		label.custom_minimum_size.x = NAME_WIDTH
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		_player_grid.add_child(label)
		if bool(p["left"]):
			_player_grid.add_child(_label(tr(&"END_STATUS_LEFT"), &"MutedLabel"))
			var none: Label = _label(tr(&"END_LOOT_NONE"), &"MutedLabel")
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			none.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			_player_grid.add_child(none)
			continue
		var status_key: StringName = &"END_STATUS_INSIDE"
		var status_style: StringName = &"MutedLabel"
		if bool(p["caught"]):
			status_key = caught_status_key(cause_of(p))
			status_style = &"AlertLabel"
		elif bool(p["escaped"]):
			status_key = &"END_STATUS_ESCAPED"
			status_style = &""
		elif bool(p["witness"]):
			status_key = &"END_STATUS_WITNESS"
		var status: String = tr(status_key)
		if int(p["bail"]) > 0:
			status = tr(&"END_STATUS_WITH_BAIL") % [status, _cash(int(p["bail"]))]
		_player_grid.add_child(_label(status, status_style))
		var loot: Label = _label(_cash(int(p["loot"])), &"")
		loot.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		loot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_player_grid.add_child(loot)


## Caught cause: &"" if not caught; the catcher (civilian/owner) from the event if any; else CAUSE_POLICE if the result is POLICE or police arrived (left outside the escape zone);
## &"" if unknown (late joiner who missed the event).
static func caught_cause(caught: bool, by: StringName, outcome_kind: StringName, police_seen: bool) -> StringName:
	if not caught:
		return &""
	if by == CAUSE_CHASER or by == CAUSE_OWNER:
		return by
	if outcome_kind == CAUSE_POLICE or police_seen:
		return CAUSE_POLICE
	return &""


## Caught cause of a `player_entries()` row.
func cause_of(p: Dictionary) -> StringName:
	return caught_cause(bool(p["caught"]), StringName(str(_caught_by.get(int(p["peer"]), ""))), outcome(), _police_seen)


## Status key of a player row: with cause (END_STATUS_CAUGHT_<CAUSE>) or generic END_STATUS_CAUGHT.
static func caught_status_key(cause: StringName) -> StringName:
	return &"END_STATUS_CAUGHT" if cause == &"" else StringName(STATUS_CAUGHT_PREFIX + String(cause).to_upper())


## Explanation of the local player's caught cause (END_CAUSE_<CAUSE>); empty if not caught or cause unknown.
func local_cause_text() -> String:
	var local_id: int = int(net.call(&"local_peer_id")) if net != null else 0
	for p: Dictionary in player_entries():
		if int(p["peer"]) != local_id:
			continue
		var cause: StringName = cause_of(p)
		return "" if cause == &"" else tr(CAUSE_KEY_PREFIX + String(cause).to_upper())
	return ""


## Whether the local player was released after witness questioning (US-042).
func local_witness() -> bool:
	var local_id: int = int(net.call(&"local_peer_id")) if net != null else 0
	for p: Dictionary in player_entries():
		if int(p["peer"]) == local_id:
			return bool(p["witness"])
	return false


## US-053: the local player's recognitions in this job (result `recognized`: witness questioning, window/search questioning and the
## owner's prep detection, KR-046).
func local_recognized() -> int:
	var local_id: int = int(net.call(&"local_peer_id")) if net != null else 0
	for p: Dictionary in player_entries():
		if int(p["peer"]) == local_id:
			return int(p["recognized"])
	return 0


func _fill_cause() -> void:
	_cause_note.text = local_cause_text()
	_cause_note.theme_type_variation = &"AlertLabel"
	if _cause_note.text.is_empty() and local_witness():
		_cause_note.text = tr(&"END_WITNESS_RELEASED")
		_cause_note.theme_type_variation = &"MutedLabel"
	elif _cause_note.text.is_empty() and local_recognized() > 0:
		_cause_note.text = tr(&"END_RECOGNIZED")  # US-053: the recognition line counts the prep recognition too
		_cause_note.theme_type_variation = &"MutedLabel"
	_cause_note.visible = not _cause_note.text.is_empty()


func _on_session_event(kind: StringName, data: Dictionary) -> void:
	if kind == EVENT_POLICE:
		_police_seen = true
	elif kind == EVENT_CAUGHT and typeof(data.get("peer")) == TYPE_INT:
		var peer: int = int(data["peer"])
		if not _caught_by.has(peer):
			_caught_by[peer] = StringName(str(data.get("by", "")))


func _player_name(p: Dictionary, local_id: int) -> String:
	var player_name: String = str(p["name"]).strip_edges().left(MainMenu.MAX_NAME_LENGTH)
	if player_name.is_empty():
		player_name = tr(&"HUD_PLAYER_UNNAMED") % int(p["peer"])
	return tr(&"HUD_PLAYER_YOU") % player_name if int(p["peer"]) == local_id else player_name


# --- notes ---

## Note title and description text: [title, description]. Generic text + developer warning if the key is missing.
func note_texts(kind: StringName) -> PackedStringArray:
	var key: String = NOTE_KEY_PREFIX + String(kind).to_upper()
	var title: String = tr(key)
	if title == key or String(kind).is_empty():
		_warn(key)
		return PackedStringArray([tr(&"NOTE_GENERIC"), tr(&"NOTE_GENERIC_DESC")])
	var desc: String = tr(key + DESC_SUFFIX)
	return PackedStringArray([title, "" if desc == key + DESC_SUFFIX else desc])


func _fill_notes() -> void:
	_clear(_note_row)
	var notes: Array = _result.get("notes", [])
	var by_peer: Dictionary = {}
	for p: Dictionary in player_entries():
		by_peer[int(p["peer"])] = p
	var local_id: int = int(net.call(&"local_peer_id")) if net != null else 0
	for i: int in mini(notes.size(), MAX_NOTES):
		var note: Dictionary = notes[i]
		var texts: PackedStringArray = note_texts(StringName(str(note.get("kind", ""))))
		var peer: int = int(note.get("peer", 0))
		var panel := PanelContainer.new()
		panel.theme_type_variation = &"ToastPanel"
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var box := VBoxContainer.new()
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(box)
		box.add_child(_label(texts[0], &"HeadingLabel"))
		var who := HBoxContainer.new()
		who.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if by_peer.has(peer):
			who.add_child(_swatch(int(by_peer[peer]["slot"])))
			var who_label: Label = _label(_player_name(by_peer[peer], local_id), &"")
			who_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			who_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			who.add_child(who_label)
		else:
			who.add_child(_label(tr(&"END_NOTE_TEAM"), &""))
		box.add_child(who)
		if not texts[1].is_empty():
			var desc: Label = _label(texts[1], &"MutedLabel")
			desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			box.add_child(desc)
		_note_row.add_child(panel)
	_notes_box.visible = _note_row.get_child_count() > 0


# --- session scores (US-051) ---

func scores_shown() -> bool:
	return _scores_box.visible


## Swaps the body (payout, crew, notes) for the session table and back; the header and buttons stay.
func show_scores(on: bool) -> void:
	_scores_box.visible = on
	_body.visible = not on
	_notes_box.visible = not on and _note_row.get_child_count() > 0
	_fill_scores_button()


func _fill_scores_button() -> void:
	_scores_button.text = tr(&"END_SHOW_RUN") if scores_shown() else tr(&"END_SHOW_SCORES") % scores.size()


## Map name of a level path: the MAP_<NAME> text, else the file name; "—" without a path.
func map_name(level_path: String) -> String:
	var key: String = SessionScores.map_key(level_path)
	if key.is_empty():
		return tr(&"END_LOOT_NONE")
	var text: String = tr(key)
	return level_path.get_file().get_basename() if text == key else text


## Strategy label text (END_STRATEGY_<CLASS>); "—" without a class, generic dash + developer warning for an unknown class.
func strategy_name(strategy_class: String) -> String:
	var key: String = SessionScores.strategy_key(strategy_class)
	if key.is_empty():
		return tr(&"END_LOOT_NONE")
	var text: String = tr(key)
	if text == key:
		_warn(key)
		return tr(&"END_LOOT_NONE")
	return text


## "0:38 (job 2)".
func _best_text(run: Dictionary) -> String:
	return tr(&"END_BEST_VALUE") % [Hud.format_clock(float(run["duration_s"])), int(run["no"])]


func _level_path() -> String:
	if game == null or not game.has_method(&"current_level"):
		return ""
	var level: Node = game.call(&"current_level")
	return "" if level == null else level.scene_file_path


func _fill_scores() -> void:
	_clear(_scores_table)
	var bests: Dictionary = scores.best()
	var current: int = int(scores.latest().get("no", 0))
	var header: Array[Label] = []
	for key: StringName in [&"END_COL_NO", &"END_COL_MAP", &"END_COL_OUTCOME", &"END_COL_TIME", &"END_COL_CLEAN",
			&"END_COL_CASH", &"END_COL_STRATEGY"]:
		header.append(_label(tr(key), &"CaptionLabel"))
	_scores_table.add_child(_score_row(header, false))
	for run: Dictionary in scores.visible_rows():
		var no: int = int(run["no"])
		var is_current: bool = no == current
		var outcome_kind := StringName(str(run["outcome"]))
		var fast: bool = no == int(bests[SessionScores.BEST_FASTEST]) or no == int(bests[SessionScores.BEST_FASTEST_CLEAN])
		var cash: int = int(run["cash"])
		var cash_style: StringName = &""
		if no == int(bests[SessionScores.BEST_TOP_CASH]):
			cash_style = &"CashLabel"
		elif cash < 0:
			cash_style = &"AlertLabel"
		var clean: bool = bool(run["clean"])
		var strategy_text: String = strategy_name(str(run["strategy"]))
		var cells: Array[Label] = [
			_label(tr(&"END_ROW_CURRENT") % no if is_current else str(no), &"HeadingLabel" if is_current else &""),
			_label(map_name(str(run["level"])), &""),
			_label(_outcome_title(outcome_kind), &"AlertLabel" if LOSS_OUTCOMES.has(outcome_kind) else &""),
			_label(Hud.format_clock(float(run["duration_s"])), &"HeadingLabel" if fast else &""),
			_label(tr(&"END_CLEAN_YES") if clean else tr(&"END_CLEAN_NO"), &"" if clean else &"MutedLabel"),
			_label(_signed_cash(cash), cash_style),
			_label(strategy_text, &"MutedLabel"),
		]
		_scores_table.add_child(_score_row(cells, is_current))
	_scores_best.text = best_summary()


## Session bests line: "Fastest clean: 0:38 (job 2) · Fastest: … · Most cash: …"; only the kinds that exist.
func best_summary() -> String:
	var bests: Dictionary = scores.best()
	var parts: PackedStringArray = []
	var fastest_clean: int = int(bests[SessionScores.BEST_FASTEST_CLEAN])
	var fastest: int = int(bests[SessionScores.BEST_FASTEST])
	var top_cash: int = int(bests[SessionScores.BEST_TOP_CASH])
	if fastest_clean > 0:
		parts.append(tr(&"END_BEST_FASTEST_CLEAN") % _best_text(scores.run_by_no(fastest_clean)))
	if fastest > 0 and fastest != fastest_clean:
		parts.append(tr(&"END_BEST_FASTEST") % _best_text(scores.run_by_no(fastest)))
	if top_cash > 0:
		parts.append(tr(&"END_BEST_TOP_CASH") % [_signed_cash(int(scores.run_by_no(top_cash)["cash"])), top_cash])
	return tr(&"END_BEST_NONE") if parts.is_empty() else tr(&"END_BEST_SEPARATOR").join(parts)


func _outcome_title(kind: StringName) -> String:
	var key: String = OUTCOME_KEY_PREFIX + String(kind).to_upper()
	var title: String = tr(key)
	return tr(&"END_OUTCOME_GENERIC") if title == key or String(kind).is_empty() else title


## One table row: fixed widths for no/time/clean/cash, map/outcome/strategy stretch and ellipsise. The current job's row sits on a
## panel (ToastPanel); the others sit in a margin box with the panel's content margins so the columns line up.
func _score_row(cells: Array[Label], current: bool) -> Control:
	var panel: Container
	if current:
		panel = PanelContainer.new()
		panel.theme_type_variation = &"ToastPanel"
	else:
		panel = MarginContainer.new()
		var source: StyleBox = get_theme_stylebox(&"panel", &"ToastPanel")
		# Only the side margins (column alignment); no vertical padding so a long session fits 1280x720.
		var names: Array[StringName] = [&"margin_left", &"margin_right"]
		var sides: Array[Side] = [SIDE_LEFT, SIDE_RIGHT]
		for i: int in names.size():
			panel.add_theme_constant_override(names[i], roundi(source.get_content_margin(sides[i])) if source != null else 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(row)
	var widths: Array[float] = [COL_NO, -COL_MAP_RATIO, -COL_OUTCOME_RATIO, COL_TIME, COL_CLEAN, COL_CASH, -COL_STRATEGY_RATIO]
	for i: int in cells.size():
		var cell: Label = cells[i]
		var width: float = widths[i]
		if width > 0.0:
			cell.custom_minimum_size.x = width
		else:
			cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			cell.size_flags_stretch_ratio = -width
			cell.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		if i == CASH_COLUMN:
			cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(cell)
	return panel


## Crew cash change with a sign: "+$1,200" / "-$300" / "$0".
func _signed_cash(value: int) -> String:
	return tr(&"END_CASH_GAIN") % _cash(value) if value > 0 else _cash(value)


# --- helpers ---

## Negative amounts put the sign before the currency symbol: "-$100" (same as Hud.format_cash).
func _cash(value: int) -> String:
	var text: String = tr(&"HUD_CASH_VALUE") % Hud.group_digits(absi(value), tr(&"NUMBER_GROUP_SEPARATOR"))
	return "-" + text if value < 0 else text


static func _label(text: String, style: StringName) -> Label:
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.theme_type_variation = style
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


static func _swatch(slot: int) -> ColorRect:
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = SWATCH_SIZE
	swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	swatch.color = ThemeTokens.PLAYER_COLORS[posmod(slot, ThemeTokens.PLAYER_COLORS.size())]
	return swatch


static func _clear(container: Node) -> void:
	for child: Node in container.get_children():
		container.remove_child(child)
		child.queue_free()


func _warn(key: String) -> void:
	if warn.is_valid():
		warn.call(key)
	else:
		push_warning("HeistEnd: metin anahtarı yok: %s (i18n/texts.csv)" % key)
