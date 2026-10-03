class_name HeistEnd
extends Control
## İş sonu ekranı (US-013 asgari 2a; S3 eki heist_finished, KR-021; oyun-testi-ve-klip §4).
## Sonuç başlığı, süre, ödeme satırları (ganimet × oran = ödeme), oyuncu satırları (slot rengi, ad,
## kaçtı/yakalandı, ganimet), notlar (NOTE_<KIND> + NOTE_<KIND>_DESC; anahtar yoksa genel metin + uyarı),
## "Bir daha" (yalnız host ve Game `request_restart()` taşıyorsa; S3 eki) ve "Menü" (`menu_requested`). Ekran hesap yapmaz:
## sayılar `result` sözlüğünden. Kayıp ekranı aynı sahnenin hâli; başlık ALERT, geri kalan FG.
## Açıkken oyun girdisi engellenir (S5). HUD `bind(game, net)` ile bağlar; geç katılan `heist_result()` alır.
## US-040: `aborted` (eli boş çekilme) kayıp değildir: normal başlık. US-041 (KR-029): yakalanan satırında kefalet,
## ödeme altında "− Kefalet" (toplam > 0 ise) ve "Ekip kasası a → b" (sonuçta `cash_before`/`cash_after` varsa);
## eksi tutar uyarı renginde.
## US-042: tanık sorgusuyla serbest bırakılan (`witness_released`) oyuncu satırında END_STATUS_WITNESS; yerel oyuncu
## ise başlık altında END_WITNESS_RELEASED (soluk).

## "Bir daha" (host): seviyeyi yeniden başlatma isteği; Game.request_restart() çağrıldıktan sonra yayılır.
signal retry_requested()
## "Menü": oturumdan ayrılıp ana menüye dönüş.
signal menu_requested()
## Ekran açıldı (HUD duraklat menüsünü kapatır).
signal opened()

## Kayıp sonuçları: başlık uyarı renginde.
const LOSS_OUTCOMES: Array[StringName] = [&"caught_all", &"police"]
## Ses kataloğu olayları (data/sfx_catalog.tres; IS-024).
const STINGER_WIN := &"stinger_success"
const STINGER_LOSS := &"stinger_caught"
const OUTCOME_KEY_PREFIX := "END_OUTCOME_"
const NOTE_KEY_PREFIX := "NOTE_"
const DESC_SUFFIX := "_DESC"
const NOTE_SUFFIX := "_NOTE"
## 1280×720'de tek ekran: en fazla bu kadar not gösterilir (üretim kuralı Game'de, US-012).
const MAX_NOTES := 3
const SWATCH_SIZE := Vector2(14, 14)
## Oyuncu adı sütunu genişliği; uzun ad üç noktayla kısalır.
const NAME_WIDTH := 240.0
## Yakalanma nedeni (US-038 AC5): oturum olaylarından (S3 eki `player_caught {peer, by}`, `police_arrived`) her
## peer'da toplanır; olayla yakalanmayan (polis kaçış bölgesi dışında yakaladı) sonuç POLICE ise ya da polis
## geldiyse polis sayılır. Metinler END_STATUS_CAUGHT_<NEDEN> (oyuncu satırı) ve END_CAUSE_<NEDEN> (yerel oyuncu).
const CAUSE_POLICE := &"police"
const CAUSE_CHASER := &"chaser"
const CAUSE_OWNER := &"owner"
const EVENT_CAUGHT := &"player_caught"
const EVENT_POLICE := &"police_arrived"
const STATUS_CAUGHT_PREFIX := "END_STATUS_CAUGHT_"
const CAUSE_KEY_PREFIX := "END_CAUSE_"

var net: Object = null
var game: Object = null
## Eksik metin anahtarı bildirimi (HUD bağlar; testler yakalar). Geçersizse push_warning.
var warn: Callable

var _result: Dictionary = {}
## peer -> yakalayan (&"chaser" | &"owner"), `player_caught` olaylarından (ilk kayıt kalır).
var _caught_by: Dictionary = {}
## Bu seviyede `police_arrived` olayı görüldü mü.
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


## Game'e (S3 eki) bağlanır; iş zaten bittiyse (geç katılım) sonucu hemen gösterir.
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
	UiSfx.of(self).play_event(stinger_event())  # odak tikinden sonra: stinger kesilmesin


## "Bir daha" sunulabilir mi: Game S3 ekindeki yeniden başlatma isteğini taşıyor.
func can_restart() -> bool:
	return game != null and game.has_method(&"request_restart")


func _is_host() -> bool:
	return net != null and bool(net.call(&"is_host"))


## Yalnız host isteyebilir (S3 eki: request_restart yalnız host); istemcide düğme zaten gizli.
func _on_retry_pressed() -> void:
	if not (_is_host() and can_restart()):
		return
	game.call(&"request_restart")
	retry_requested.emit()


# --- başlık ---

func outcome() -> StringName:
	return StringName(str(_result.get("outcome", "")))


## Açılış vurgusu (IS-024; ses-ve-sfx §1 kural 5): kayıpta yakalanma stinger'ı, değilse kısa olumlu jingle.
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


# --- ödeme ---

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


# --- oyuncular ---

## Sonuçtaki oyuncular, slot sırasıyla: [{peer, name, slot, escaped, caught, loot, bail}].
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


## Yakalanma nedeni: yakalanmadıysa &""; olayda yakalayan (mahalleli/sahip) varsa o; yoksa sonuç POLICE ya da polis
## geldiyse CAUSE_POLICE (kaçış bölgesi dışında kalan); bilinmiyorsa &"" (geç katılan, olayı görmedi).
static func caught_cause(caught: bool, by: StringName, outcome_kind: StringName, police_seen: bool) -> StringName:
	if not caught:
		return &""
	if by == CAUSE_CHASER or by == CAUSE_OWNER:
		return by
	if outcome_kind == CAUSE_POLICE or police_seen:
		return CAUSE_POLICE
	return &""


## `player_entries()` satırının yakalanma nedeni.
func cause_of(p: Dictionary) -> StringName:
	return caught_cause(bool(p["caught"]), StringName(str(_caught_by.get(int(p["peer"]), ""))), outcome(), _police_seen)


## Oyuncu satırının durum anahtarı: nedenli (END_STATUS_CAUGHT_<NEDEN>) ya da genel END_STATUS_CAUGHT.
static func caught_status_key(cause: StringName) -> StringName:
	return &"END_STATUS_CAUGHT" if cause == &"" else StringName(STATUS_CAUGHT_PREFIX + String(cause).to_upper())


## Yerel oyuncu yakalandıysa nedeninin açıklaması (END_CAUSE_<NEDEN>); değilse ya da neden bilinmiyorsa boş.
func local_cause_text() -> String:
	var local_id: int = int(net.call(&"local_peer_id")) if net != null else 0
	for p: Dictionary in player_entries():
		if int(p["peer"]) != local_id:
			continue
		var cause: StringName = cause_of(p)
		return "" if cause == &"" else tr(CAUSE_KEY_PREFIX + String(cause).to_upper())
	return ""


## Yerel oyuncu tanık sorgusuyla serbest bırakıldı mı (US-042).
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


# --- notlar ---

## Notun başlık ve açıklama metni: [başlık, açıklama]. Anahtar yoksa genel metin + geliştirici uyarısı.
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


# --- yardımcılar ---

## Eksi tutar (kefalet, borç) işaret para biriminin önünde: "-$100" (Hud.format_cash ile aynı).
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
