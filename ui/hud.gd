class_name Hud
extends CanvasLayer
## Oyun içi HUD (US-003 AC2, AC3): ekip nakdi, ping, oyuncu listesi, oturum olayı bildirimi,
## etkileşim istemi ("[E] eylem", tuş adı etkin cihaza göre) ve ilerlemesi, duraklat menüsü. Game, seviye yüklenince Game.HUD_SCENE olarak ekler (S3).
## US-013: uyarı merdiveni (ui/alert_ladder.gd) ve iş sonu ekranı (ui/heist_end.gd), S3 ekinden.
## US-011c: maruziyet rozeti (ui/exposure_badge.gd) ve ekip işaretleri (ui/team_markers.gd), S3 eki (mimari.md, US-011b/c) üyelerinden.
## US-038: kaçış paneli (ui/escape_panel.gd: hedef, polis sayacı, n/m) ve kaçış kenar oku (ui/escape_arrow.gd).
## Yalnız S1/S3 sinyal ve fonksiyonlarını, yerel oyuncunun S7 sinyallerini okur. Testler `net` ve
## `game`'i sahneye eklemeden önce sahte nesnelerle değiştirir; zaman `advance()` ile ilerletilebilir.

const PING_INTERVAL_SEC := 1.0
## Bu değer ve üstü uyarı renginde gösterilir (GDD §12 test gecikmesi 150 ms).
const PING_WARN_MS := 150
const TOAST_SECONDS := 4.0
const TOAST_FADE_SECONDS := 0.5
const TOAST_WIDTH := 420.0
const MAX_TOASTS := 3
## Etkileşim bitince çubuğun ekranda kalma süresi.
const INTERACTION_LINGER_SEC := 0.6
const CASH_FLASH_SEC := 0.35
const CASH_FLASH_ALPHA := 0.35
const SWATCH_SIZE := Vector2(10, 10)
## Ekip listesinde ad en fazla bu genişlikte (px); uzunu üç noktayla kısalır.
const PLAYER_NAME_MAX_WIDTH := 170.0
## Oturum olayı anahtarı: EVENT_<KIND> (ör. &"police_called" → EVENT_POLICE_CALLED).
const EVENT_KEY_PREFIX := "EVENT_"
## Kalıp dışı olay metni anahtarları (tür -> anahtar).
const EVENT_KEY_OVERRIDES := {&"owner_discover": "EVENT_OWNER_DISCOVERED"}
## Bildirim gösterilmeyen olaylar: başka HUD öğesi zaten gösterir (alert_level → uyarı merdiveni, US-013).
const SILENT_EVENTS: Array[StringName] = [&"alert_level"]
## Olay verisinde oyuncuyu belirten alan (S3 eki, US-008: player_held/caught/rescued {peer}); metne {name} olarak girer.
const EVENT_PEER_FIELD := "peer"
const EVENT_NAME_FIELD := "name"
## İstemdeki tuş adının alındığı eylem (S5).
const INTERACT_ACTION := &"interact"

var net: Object = Net
var game: Object = Game
## Testler için: atanırsa ana menüye geçmek yerine hata anahtarıyla bu çağrılır.
var menu_override: Callable
## Testler için: atanırsa eksik metin uyarısı push_warning yerine eksik anahtarla bu çağrılır.
var warning_override: Callable

var _player: Node = null
## Yakındaki etkileşim hedefinin eylem anahtarı (S7 interaction_target_changed); boş = hedef yok.
var _target_key: String = ""
var _interaction_running: bool = false
var _interaction_elapsed: float = 0.0
var _interaction_duration: float = 0.0
var _interaction_linger: float = 0.0
## Bildirim paneli -> kalan süre (sn).
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
	# US-038: kaçış paneli polis sayacını büyük gösterir; merdivenin küçük sayacı yalnız panel yoksa.
	_escape_panel.bind(game)
	_alert_ladder.show_timer = not EscapePanel.supports(game)
	_alert_ladder.refresh_timer()
	_escape_arrow.avoid = blocks
	_escape_arrow.bind(game)


func _process(delta: float) -> void:
	advance(delta)


## Yalnız gözlem: son girdinin cihazı değişince istemdeki tuş adı güncellenir (olay tüketilmez).
func _input(event: InputEvent) -> void:
	if UiInput.note_input(event):
		_refresh_prompt()


func _unhandled_input(event: InputEvent) -> void:
	if _heist_end.is_open():
		return  # iş sonu ekranında duraklat menüsü açılmaz
	var open: bool = is_pause_open()
	if (open and UiInput.is_pause_close_event(event)) or (not open and UiInput.is_pause_open_event(event)):
		toggle_pause()
		get_viewport().set_input_as_handled()


## Zamanlı öğeleri (etkileşim çubuğu, bildirimler) `delta` saniye ilerletir.
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


# --- ekip nakdi ---

## "1234567" → "1.234.567" (ayraç dile göre, NUMBER_GROUP_SEPARATOR).
static func group_digits(value: int, separator: String) -> String:
	var digits: String = str(absi(value))
	var out: String = ""
	while digits.length() > 3:
		out = separator + digits.right(3) + out
		digits = digits.left(digits.length() - 3)
	return ("-" if value < 0 else "") + digits + out


## Saniye → "d:ss" (yukarı yuvarlanır; sayaç 0'a inene dek "0:01" gösterir).
static func format_clock(seconds: float) -> String:
	var total: int = maxi(ceili(seconds), 0)
	return "%d:%02d" % [floori(total / 60.0), total % 60]


## Eksi tutar (borç, KR-029) işaret para biriminin önünde: "-$100".
func format_cash(value: int) -> String:
	var text: String = tr(&"HUD_CASH_VALUE") % group_digits(absi(value), tr(&"NUMBER_GROUP_SEPARATOR"))
	return "-" + text if value < 0 else text


func _on_team_cash_changed(value: int) -> void:
	_set_cash(value, value != _cash)


func _set_cash(value: int, flash: bool) -> void:
	_cash = value
	_cash_value.text = format_cash(value)
	# Borç (US-041, KR-029): eksi kasa uyarı token renginde (tema varyasyonu; geçersiz kılma yasak, S9).
	_cash_value.theme_type_variation = &"AlertLabel" if value < 0 else &"CashLabel"
	if flash:
		_cash_value.modulate.a = CASH_FLASH_ALPHA
		create_tween().tween_property(_cash_value, "modulate:a", 1.0, CASH_FLASH_SEC)


# --- ping ---

## Host'ta "Host"; istemcide host'a gecikme (bilinmiyorsa "— ms"), eşik üstü uyarı renginde.
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


# --- oyuncular ---

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
		# S3: Game renk değil katılım yuvası (slot) yayınlar; renk slot'tan (slot yoksa liste sırası).
		var slot: int = int(info["slot"]) if typeof(info.get("slot")) == TYPE_INT else i
		swatch.color = ThemeTokens.PLAYER_COLORS[posmod(slot, ThemeTokens.PLAYER_COLORS.size())]
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		var player_name: String = _player_name(peer_id, info)
		label.text = tr(&"HUD_PLAYER_YOU") % player_name if peer_id == local_id else player_name
		row.add_child(swatch)
		row.add_child(label)
		_player_list.add_child(row)
		# Ekip listesi dar kalır (haritayı az örter, US-013): uzun ad üç noktayla kısalır.
		var width: float = label.get_theme_font(&"font").get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1,
			label.get_theme_font_size(&"font_size")).x
		label.custom_minimum_size.x = minf(ceilf(width), PLAYER_NAME_MAX_WIDTH)
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS


# --- oturum olayları ---

## EVENT_<KIND> anahtarının metni; `data` alanları {ad} yer tutucularına yerleşir. `data` bir oyuncu
## (`peer`) taşıyorsa adı {name} olarak eklenir (veride `name` yoksa). Anahtar yoksa oyuncuya
## ham olay adı değil genel metin gösterilir, eksik anahtar geliştiriciye uyarıyla bildirilir.
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


## Olay türünün HUD metin anahtarı (S9): &"player_held" → "EVENT_PLAYER_HELD"; kalıba uymayan anahtar
## EVENT_KEY_OVERRIDES'tan (US-039: &"owner_discover" → "EVENT_OWNER_DISCOVERED").
static func event_key(kind: StringName) -> String:
	if EVENT_KEY_OVERRIDES.has(kind):
		return str(EVENT_KEY_OVERRIDES[kind])
	return EVENT_KEY_PREFIX + String(kind).to_upper()


## Oyuncunun görünen adı (S3 players() kaydından); ad yoksa "Oyuncu N".
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


func _on_session_event(kind: StringName, data: Dictionary) -> void:
	if kind in SILENT_EVENTS:
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


# --- etkileşim (S7 oyuncu sinyalleri) ---

## Yerel oyuncunun S7 sinyalleri; oyuncuda olmayan sinyal (eski fikstür) atlanır.
func _player_signals() -> Dictionary:
	return {
		&"interaction_target_changed": _on_interaction_target_changed,
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


## İstem: hedef varken ve etkileşim sürmüyorken "[tuş] eylem"; etkileşim başlayınca yerini çubuğa bırakır.
func _refresh_prompt() -> void:
	var visible_now: bool = not _target_key.is_empty() and not _interaction.visible
	if visible_now:
		var hint: String = UiInput.action_hint(INTERACT_ACTION)
		var action: String = tr(_target_key)
		_prompt_label.text = action if hint.is_empty() else tr(&"HUD_PROMPT") % [hint, action]
	_prompt.visible = visible_now


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


# --- oturumdan çıkış ---

func _on_leave_requested() -> void:
	_leaving = true
	net.call(&"leave")
	_open_main_menu(&"")


func _on_host_disconnected() -> void:
	_lost_session(&"MENU_ERROR_HOST_DISCONNECTED")


## İstemcide seviye el sıkışma bitmeden yüklenmişken bağlantı kurulamazsa (ana menü kaldırılmış olur).
func _on_connection_failed() -> void:
	_lost_session(&"MENU_ERROR_CONNECTION_FAILED")


## Oturum dışarıdan bitti: bir kez ana menüye, hatayla döner (kendi ayrılışında hata gösterilmez).
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


## Eksik metin anahtarını geliştiriciye bildirir (oyuncu görmez).
func _warn_missing_text(key: String) -> void:
	if warning_override.is_valid():
		warning_override.call(key)
	else:
		push_warning("Hud: metin anahtarı yok: %s (i18n/texts.csv)" % key)
