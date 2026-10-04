class_name Hud
extends CanvasLayer
## In-game HUD (US-003 AC2, AC3): team cash, ping, player list, session event notices, interaction prompt ("[E] action", key name by active device) and progress, pause menu. Game adds it as Game.HUD_SCENE on level load (S3).
## Hosts the alert ladder (US-013), heist end screen (US-013), exposure badge and team markers (US-011c), escape panel and escape arrow (US-038), fed by the S3 addendum.
## Reads only S1/S3 signals and functions plus the local player's S7 signals. Tests swap `net` and `game` for fakes before adding to the scene; time can be advanced with `advance()`.

const PING_INTERVAL_SEC := 1.0
## At or above this value shown in the alert colour (GDD §12 test latency 150 ms).
const PING_WARN_MS := 150
const TOAST_SECONDS := 4.0
const TOAST_FADE_SECONDS := 0.5
const TOAST_WIDTH := 420.0
const MAX_TOASTS := 3
## How long the bar stays on screen after an interaction ends.
const INTERACTION_LINGER_SEC := 0.6
const CASH_FLASH_SEC := 0.35
const CASH_FLASH_ALPHA := 0.35
const SWATCH_SIZE := Vector2(10, 10)
## Max name width (px) in the team list; longer names are ellipsised.
const PLAYER_NAME_MAX_WIDTH := 170.0
## Session event key: EVENT_<KIND> (e.g. &"police_called" -> EVENT_POLICE_CALLED).
const EVENT_KEY_PREFIX := "EVENT_"
## Text keys for events that do not fit the pattern (kind -> key).
const EVENT_KEY_OVERRIDES := {&"owner_discover": "EVENT_OWNER_DISCOVERED"}
## Events with no notice: another HUD element already shows them (alert_level -> alert ladder, US-013;
## cover_broken -> cover row in the escape panel, US-042).
const SILENT_EVENTS: Array[StringName] = [&"alert_level", &"cover_broken"]
## Events shown only when the named data field is true (kind -> field). IS-096 (US-037 decision): `npc_pushed` toasts only for a
## calm shove; heated shoves stay silent (no spam during a chase).
const CONDITIONAL_EVENTS := {&"npc_pushed": "calm"}
## Event data field naming the player (S3 addendum, US-008: player_held/caught/rescued {peer}); enters the text as {name}.
const EVENT_PEER_FIELD := "peer"
const EVENT_NAME_FIELD := "name"
## Action the prompt key name is taken from (S5).
const INTERACT_ACTION := &"interact"
## Input action of the second prompt row (US-010 Q / gamepad X; IS-091).
const ALT_ACTION := &"intimidate"

var net: Object = Net
var game: Object = Game
## For tests: if set, called with the error key instead of switching to the main menu.
var menu_override: Callable
## For tests: if set, called with the missing key instead of push_warning for missing text.
var warning_override: Callable

var _player: Node = null
## Action key of the nearby interaction target (S7 interaction_target_changed); empty = no target.
var _target_key: String = ""
## Target action key of the Q row (S7 interaction_alt_target_changed); empty = no target.
var _alt_target_key: String = ""
var _interaction_running: bool = false
var _interaction_elapsed: float = 0.0
var _interaction_duration: float = 0.0
var _interaction_linger: float = 0.0
## Notice panel -> remaining time (s).
var _toast_ttl: Dictionary = {}
var _cash: int = 0
var _leaving: bool = false

@onready var _root: Control = %Root
@onready var _cash_value: Label = %CashValue
@onready var _ping_label: Label = %PingLabel
@onready var _player_list: VBoxContainer = %PlayerList
@onready var _toasts: VBoxContainer = %Toasts
@onready var _prompt: Control = %Prompt
@onready var _prompt_label: Label = %PromptLabel
@onready var _prompt_alt_label: Label = %PromptAltLabel
@onready var _interaction: Control = %Interaction
@onready var _interaction_label: Label = %InteractionLabel
@onready var _interaction_bar: ProgressBar = %InteractionBar
@onready var _pause_menu: PauseMenu = %PauseMenu
@onready var _ping_timer: Timer = %PingTimer
@onready var _alert_ladder: AlertLadder = %AlertLadder
@onready var _heist_end: HeistEnd = %HeistEnd
@onready var _exposure_badge: ExposureBadge = %ExposureBadge
@onready var _team_markers: TeamMarkers = %TeamMarkers
@onready var _escape_panel: EscapePanel = %EscapePanel
@onready var _escape_arrow: EscapeArrow = %EscapeArrow


func _ready() -> void:
	ThemeTokens.apply(_root)
	game.connect(&"team_cash_changed", _on_team_cash_changed)
	game.connect(&"players_changed", refresh_players)
	game.connect(&"session_event", _on_session_event)
	game.connect(&"local_player_changed", _bind_player)
	net.connect(&"host_disconnected", _on_host_disconnected)
	net.connect(&"connection_failed", _on_connection_failed)
	_pause_menu.leave_requested.connect(_on_leave_requested)
	_ping_timer.wait_time = PING_INTERVAL_SEC
	_ping_timer.timeout.connect(refresh_ping)
	_ping_timer.start()
	_interaction.hide()
	_prompt.hide()
	_set_cash(int(game.call(&"team_cash")), false)
	refresh_players()
	refresh_ping()
	_bind_player(game.call(&"local_player") as Node)
	_alert_ladder.warn = _warn_missing_text
	_alert_ladder.bind(game)
	_heist_end.warn = _warn_missing_text
	_heist_end.opened.connect(_pause_menu.close)
	_heist_end.menu_requested.connect(_on_leave_requested)
	_heist_end.bind(game, net)
	_exposure_badge.bind(game, net)
	var blocks: Array[Control] = [$Root/Frame/Layout/Top/CashPanel as Control,
		$Root/Frame/Layout/Top/Right as Control, _alert_ladder, _escape_panel, _exposure_badge, _prompt, _interaction]
	_team_markers.avoid = blocks
	_team_markers.bind(game, net)
	# US-038: the escape panel shows the police timer large; the ladder's small timer only when there is no panel.
	_escape_panel.bind(game)
	_alert_ladder.show_timer = not EscapePanel.supports(game)
	_alert_ladder.refresh_timer()
	_escape_arrow.avoid = blocks
	_escape_arrow.bind(game)


func _process(delta: float) -> void:
	advance(delta)


## Observe only: when the last input's device changes the prompt key name updates (the event is not consumed).
func _input(event: InputEvent) -> void:
	if UiInput.note_input(event):
		_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _heist_end.is_open():
		return  # the pause menu does not open on the heist end screen
	var open: bool = is_pause_open()
	if (open and UiInput.is_pause_close_event(event)) or (not open and UiInput.is_pause_open_event(event)):
		toggle_pause()
		get_viewport().set_input_as_handled()


## Advances timed items (interaction bar, notices) by `delta` seconds.
func advance(delta: float) -> void:
	_tick_interaction(delta)
	_tick_toasts(delta)
	_alert_ladder.advance(delta)
	_team_markers.advance(delta)
	_escape_panel.advance(delta)
	_escape_arrow.advance(delta)


func toggle_pause() -> void:
	if _pause_menu.is_open():
		_pause_menu.close()
	else:
		_pause_menu.open()


func is_pause_open() -> bool:
	return _pause_menu.is_open()


# --- team cash ---

## "1234567" -> "1.234.567" (separator by language, NUMBER_GROUP_SEPARATOR).
static func group_digits(value: int, separator: String) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = separator + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## Seconds -> "m:ss" (rounded up; shows "0:01" until the counter reaches 0).
static func format_clock(seconds: float) -> String:
	var total: int = maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


## Negative amounts (debt, KR-029) put the sign before the currency symbol: "-$100".
func format_cash(value: int) -> String:
	var text: String = tr(&"HUD_CASH_VALUE") % group_digits(absi(value), tr(&"NUMBER_GROUP_SEPARATOR"))
	return "-" + text if value < 0 else text


func _on_team_cash_changed(value: int) -> void:
	_set_cash(value, value != _cash)


func _set_cash(value: int, flash: bool) -> void:
	_cash = value
	_cash_value.text = format_cash(value)
	# Debt (US-041, KR-029): negative cash in the alert token colour (theme variation; overrides are forbidden, S9).
	_cash_value.theme_type_variation = &"AlertLabel" if value < 0 else &"CashLabel"
	if flash:
		_cash_value.modulate.a = CASH_FLASH_ALPHA
		create_tween().tween_property(_cash_value, "modulate:a", 1.0, CASH_FLASH_SEC)


# --- ping ---

## "Host" on the host; on a client the latency to the host ("-- ms" if unknown), alert colour above the threshold.
func refresh_ping() -> void:
	var variation: StringName = &"MutedLabel"
	if bool(net.call(&"is_host")):
		_ping_label.text = tr(&"HUD_PING_HOST")
	else:
		var ms: int = int(net.call(&"get_ping_ms"))
		if ms < 0:
			_ping_label.text = tr(&"HUD_PING_UNKNOWN")
		else:
			_ping_label.text = tr(&"HUD_PING_MS") % ms
			if ms >= PING_WARN_MS:
				variation = &"AlertLabel"
	_ping_label.theme_type_variation = variation


# --- players ---

func refresh_players() -> void:
	for row: Node in _player_list.get_children():
		_player_list.remove_child(row)
		row.queue_free()
	var players: Dictionary = game.call(&"players")
	var ids: Array = players.keys()
	ids.sort()
	var local_id: int = int(net.call(&"local_peer_id"))
	for i: int in ids.size():
		var peer_id: int = ids[i]
		var info: Dictionary = players[peer_id]
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var swatch := ColorRect.new()
		swatch.custom_minimum_size = SWATCH_SIZE
		swatch.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		swatch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# S3: Game publishes a join slot, not a colour; colour comes from the slot (list order if no slot).
		var slot: int = int(info["slot"]) if typeof(info.get("slot")) == TYPE_INT else i
		swatch.color = ThemeTokens.PLAYER_COLORS[posmod(slot, ThemeTokens.PLAYER_COLORS.size())]
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var player_name: String = _player_name(peer_id, info)
		label.text = tr(&"HUD_PLAYER_YOU") % player_name if peer_id == local_id else player_name
		row.add_child(swatch)
		row.add_child(label)
		_player_list.add_child(row)
		# The team list stays narrow (covers little map, US-013): long names are ellipsised.
		var width: float = label.get_theme_font(&"font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size(&"font_size")).x
		label.custom_minimum_size.x = minf(ceilf(width), PLAYER_NAME_MAX_WIDTH)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


# --- session events ---

## Text of the EVENT_<KIND> key; `data` fields fill {name}-style placeholders. If `data` carries a player (`peer`), the name is added as {name} (unless `data` has `name`).
## If the key is missing the player sees generic text, not the raw event name, and the developer gets a warning.
func event_text(kind: StringName, data: Dictionary) -> String:
	var key: String = event_key(kind)
	var text: String = tr(key)
	if text == key:
		_warn_missing_text(key)
		return tr(&"EVENT_GENERIC")
	var fields: Dictionary = data.duplicate()
	if typeof(data.get(EVENT_PEER_FIELD)) == TYPE_INT and not fields.has(EVENT_NAME_FIELD):
		var peer_id: int = int(data[EVENT_PEER_FIELD])
		var players: Dictionary = game.call(&"players")
		var info: Dictionary = players.get(peer_id, {}) if typeof(players.get(peer_id)) == TYPE_DICTIONARY else {}
		fields[EVENT_NAME_FIELD] = _player_name(peer_id, info)
	return text.format(fields) if not fields.is_empty() else text


## HUD text key of an event kind (S9): &"player_held" -> "EVENT_PLAYER_HELD"; kinds that break the pattern
## come from EVENT_KEY_OVERRIDES (US-039: &"owner_discover" -> "EVENT_OWNER_DISCOVERED").
static func event_key(kind: StringName) -> String:
	if EVENT_KEY_OVERRIDES.has(kind):
		return str(EVENT_KEY_OVERRIDES[kind])
	return EVENT_KEY_PREFIX + String(kind).to_upper()


## Player's display name (from the S3 players() record); "Player N" if there is no name.
func _player_name(peer_id: int, info: Dictionary) -> String:
	var player_name: String = str(info.get("name", "")).strip_edges().left(MainMenu.MAX_NAME_LENGTH)
	if player_name.is_empty():
		player_name = tr(&"HUD_PLAYER_UNNAMED") % peer_id
	return player_name


func show_toast(text: String) -> void:
	var panel := PanelContainer.new()
	panel.theme_type_variation = &"ToastPanel"
	panel.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var label := Label.new()
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.custom_minimum_size.x = TOAST_WIDTH
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(label)
	_toasts.add_child(panel)
	_toast_ttl[panel] = TOAST_SECONDS
	while _toasts.get_child_count() > MAX_TOASTS:
		_remove_toast(_toasts.get_child(0) as Control)


## Whether an event gets a toast (S9 text): not silent and, for CONDITIONAL_EVENTS, its data field is true.
static func wants_toast(kind: StringName, data: Dictionary) -> bool:
	if kind in SILENT_EVENTS:
		return false
	if CONDITIONAL_EVENTS.has(kind):
		return data.get(str(CONDITIONAL_EVENTS[kind])) == true
	return true


func _on_session_event(kind: StringName, data: Dictionary) -> void:
	if not wants_toast(kind, data):
		return
	show_toast(event_text(kind, data))


func _tick_toasts(delta: float) -> void:
	for panel: Control in _toast_ttl.keys():
		var left: float = float(_toast_ttl[panel]) - delta
		if left <= 0.0:
			_remove_toast(panel)
		else:
			_toast_ttl[panel] = left
			panel.modulate.a = clampf(left / TOAST_FADE_SECONDS, 0.0, 1.0)


func _remove_toast(panel: Control) -> void:
	_toast_ttl.erase(panel)
	_toasts.remove_child(panel)
	panel.queue_free()


# --- interaction (S7 player signals) ---

## The local player's S7 signals; a signal the player lacks (old fixture) is skipped.
func _player_signals() -> Dictionary:
	return {
		&"interaction_target_changed": _on_interaction_target_changed,
		&"interaction_alt_target_changed": _on_interaction_alt_target_changed,
		&"interaction_started": _on_interaction_started,
		&"interaction_finished": _on_interaction_finished,
	}


func _bind_player(player: Node) -> void:
	var handlers: Dictionary = _player_signals()
	if is_instance_valid(_player):
		for sig: StringName in handlers:
			if _player.has_signal(sig) and _player.is_connected(sig, handlers[sig]):
				_player.disconnect(sig, handlers[sig])
	_player = player
	_target_key = ""
	_alt_target_key = ""
	_interaction_running = false
	_interaction_linger = 0.0
	_interaction.hide()
	_refresh_prompt()
	if player == null:
		return
	for sig: StringName in handlers:
		if player.has_signal(sig):
			player.connect(sig, handlers[sig])


func _on_interaction_target_changed(action_key: String) -> void:
	_target_key = action_key
	_refresh_prompt()


func _on_interaction_alt_target_changed(action_key: String) -> void:
	_alt_target_key = action_key
	_refresh_prompt()


## Prompt: "[key] action" while there is a target and no interaction in progress; the bar replaces it when an interaction starts.
## Two rows: E (interact) on top, Q (intimidate) below; a row without a target is hidden (IS-091).
func _refresh_prompt() -> void:
	var idle: bool = not _interaction.visible
	var main_now: bool = idle and _fill_prompt_row(_prompt_label, _target_key, INTERACT_ACTION)
	var alt_now: bool = idle and _fill_prompt_row(_prompt_alt_label, _alt_target_key, ALT_ACTION)
	_prompt_label.visible = main_now
	_prompt_alt_label.visible = alt_now
	_prompt.visible = main_now or alt_now


## Fills one prompt row with "[key] action"; false if the key is empty (row will be hidden).
func _fill_prompt_row(label: Label, action_key: String, input_action: StringName) -> bool:
	if action_key.is_empty():
		return false
	var action: String = tr(action_key)
	var hint: String = UiInput.action_hint(input_action)
	label.text = action if hint.is_empty() else tr(&"HUD_PROMPT") % [hint, action]
	return true


func _on_interaction_started(action_key: String, duration: float) -> void:
	_interaction_label.text = tr(action_key)
	_interaction_label.theme_type_variation = &""
	_interaction_duration = maxf(duration, 0.0)
	_interaction_elapsed = 0.0
	_interaction_running = true
	_interaction_linger = 0.0
	_interaction_bar.value = 0.0 if _interaction_duration > 0.0 else 1.0
	_interaction.show()
	_refresh_prompt()


func _on_interaction_finished(success: bool) -> void:
	if not _interaction.visible:
		return
	_interaction_running = false
	if success:
		_interaction_bar.value = 1.0
	else:
		_interaction_label.text = tr(&"HUD_INTERACT_CANCELLED")
		_interaction_label.theme_type_variation = &"MutedLabel"
	_interaction_linger = INTERACTION_LINGER_SEC


func _tick_interaction(delta: float) -> void:
	if _interaction_running:
		if _interaction_duration > 0.0:
			_interaction_elapsed += delta
			_interaction_bar.value = clampf(_interaction_elapsed / _interaction_duration, 0.0, 1.0)
	elif _interaction_linger > 0.0:
		_interaction_linger -= delta
		if _interaction_linger <= 0.0:
			_interaction.hide()
			_refresh_prompt()


# --- leaving the session ---

func _on_leave_requested() -> void:
	_leaving = true
	net.call(&"leave")
	_open_main_menu(&"")


func _on_host_disconnected() -> void:
	_lost_session(&"MENU_ERROR_HOST_DISCONNECTED")


## If a client's level loaded before the handshake finished and the connection cannot be made (the main menu has been removed).
func _on_connection_failed() -> void:
	_lost_session(&"MENU_ERROR_CONNECTION_FAILED")


## Session ended externally: returns once to the main menu with an error (no error on one's own leave).
func _lost_session(error_key: StringName) -> void:
	if _leaving:
		return
	_leaving = true
	_open_main_menu(error_key)


func _open_main_menu(error_key: StringName) -> void:
	if menu_override.is_valid():
		menu_override.call(error_key)
	else:
		MainMenu.open(get_tree(), error_key)


## Reports a missing text key to the developer (the player does not see it).
func _warn_missing_text(key: String) -> void:
	if warning_override.is_valid():
		warning_override.call(key)
	else:
		push_warning("Hud: metin anahtarı yok: %s (i18n/texts.csv)" % key)
