class_name HeistEnd
extends Control
## Heist end screen (US-013 minimum 2a; S3 addendum heist_finished, KR-021; oyun-testi-ve-klip §4).
## Shows result title, duration, payout rows (loot x rate = payout), player rows (slot colour, name, escaped/caught, loot) and notes (NOTE_<KIND> + NOTE_<KIND>_DESC; generic text + warning if the key is missing),
## "Again" (host only, and only if Game has `request_restart()`; S3 addendum) and "Menu" (`menu_requested`). Does no maths: numbers come from the `result` dictionary. The loss screen is a variant of the same scene (title ALERT, rest FG).
## Blocks gameplay input while open (S5). HUD calls `bind(game, net)`; a late joiner gets `heist_result()`.
## US-040: `aborted` (empty-handed retreat) is not a loss: normal title. US-041 (KR-029): caught row shows bail, "- Bail" under the payout (if total > 0) and "Team cash a -> b" (if the result has `cash_before`/`cash_after`); negatives in the alert colour.
## US-042: a player released after witness questioning (`witness_released`) gets END_STATUS_WITNESS on their row; for the local player END_WITNESS_RELEASED (dim) under the title.

## "Again" (host): request to restart the level; emitted after Game.request_restart() is called.
signal retry_requested()
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

var net: Object = null
var game: Object = null
## Missing-text-key notification (HUD binds; tests catch it); push_warning if unhandled.
var warn: Callable

var _result: Dictionary = {}
## peer -> catcher (&"chaser" | &"owner"), from `player_caught` events (first record stays).
var _caught_by: Dictionary = {}
## Whether a `police_arrived` event was seen this level.
var _police_seen: bool = false

@onready var _title: Label = %OutcomeTitle
@onready var _outcome_note: Label = %OutcomeNote
@onready var _cause_note: Label = %CauseNote
@onready var _duration: Label = %DurationValue
@onready var _payout_grid: GridContainer = %PayoutGrid
@onready var _player_grid: GridContainer = %PlayerGrid
@onready var _notes_box: Control = %NotesBox
@onready var _note_row: HBoxContainer = %NoteRow
@onready var _retry_button: Button = %RetryButton
@onready var _retry_hint: Label = %RetryHint
@onready var _menu_button: Button = %MenuButton


func _ready() -> void:
	ThemeTokens.apply(self)
	UiSfx.wire_buttons(self)
	hide()
	UiInput.block_gameplay_while_visible(self)
	_retry_button.pressed.connect(_on_retry_pressed)
	_menu_button.pressed.connect(func() -> void: menu_requested.emit())
	UiInput.tab_ring([_retry_button, _menu_button])
	for pair: Array in [[_retry_button, _menu_button], [_menu_button, _retry_button]]:
		var from: Control = pair[0]
		var to: Control = pair[1]
		UiInput.link(from, SIDE_RIGHT, to)
		UiInput.link(from, SIDE_LEFT, to)
		UiInput.link(from, SIDE_TOP, from)
		UiInput.link(from, SIDE_BOTTOM, from)


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
	_fill_header()
	_fill_payout()
	_fill_players()
	_fill_cause()
	_fill_notes()
	var host: bool = _is_host()
	_retry_button.visible = host and can_restart()
	_retry_hint.visible = not host
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

## Players in the result, in slot order: [{peer, name, slot, escaped, caught, loot, bail}].
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


func _fill_cause() -> void:
	_cause_note.text = local_cause_text()
	_cause_note.theme_type_variation = &"AlertLabel"
	if _cause_note.text.is_empty() and local_witness():
		_cause_note.text = tr(&"END_WITNESS_RELEASED")
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
