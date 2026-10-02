class_name ConnectInfo
extends RefCounted
## Bağlantı kolaylığı (US-026, rahatlik-ux.md UX-1 ve §2): davet adresi seçimi, "adres[:port]" ayrıştırma
## ve son bağlantı bilgisinin (oyuncu adı, son katılınan adres) kalıcılığı. Düğümsüz, saf yardımcılar;
## ekranlar (ana menü, davet paneli) bunları kullanır. Net'e dokunmaz (S1 imzaları değişmez).

const DEFAULT_PORT := 7777
const MIN_PORT := 1024
const MAX_PORT := 65535
## Hiç uygun arabirim yoksa davet adresi (yalnız aynı makinede çalışır).
const LOOPBACK := "127.0.0.1"
const SETTINGS_PATH := "user://connect.cfg"
const SECTION := "connect"
const KEY_NAME := "name"
const KEY_ADDRESS := "address"
## Kalıcı ad bu uzunlukta kesilir (MainMenu.MAX_NAME_LENGTH ile aynı).
const MAX_NAME_LENGTH := 16
## Kalıcı adres bu uzunlukta kesilir (adres alanının max_length'i).
const MAX_ADDRESS_LENGTH := 253

## Ayar dosyasının yolu; testler geçici bir yola çevirir.
static var settings_path: String = SETTINGS_PATH
## Bu oturumda menüden host olunan port (0 = menüden host olunmadı; duraklat menüsü Args.port'a düşer).
static var hosted_port: int = 0

static var _ipv4_in_text: RegEx = RegEx.create_from_string(
		"(?<![0-9.])([0-9]{1,3}(?:\\.[0-9]{1,3}){3})(?::([0-9]{1,5}))?(?![0-9]|\\.[0-9]|:[0-9])")
## Metin içindeki Tailscale MagicDNS adı: "makine.tailXXXX.ts.net[:port]".
static var _ts_name_in_text: RegEx = RegEx.create_from_string(
		"(?<![A-Za-z0-9.-])((?:[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?\\.)+ts\\.net)(?::([0-9]{1,5}))?(?![A-Za-z0-9-]|\\.[A-Za-z0-9]|:[0-9])")
static var _hostname: RegEx = RegEx.create_from_string(
		"^[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)*$")


# --- davet adresi ---

## Geçerli IPv4 ise dört sekizli, değilse boş dizi.
static func ipv4_octets(text: String) -> PackedInt32Array:
	var parts: PackedStringArray = text.split(".")
	if parts.size() != 4:
		return PackedInt32Array()
	var out := PackedInt32Array()
	for p: String in parts:
		if p.is_empty() or p.length() > 3 or not p.is_valid_int() or not _all_digits(p):
			return PackedInt32Array()
		var v: int = p.to_int()
		if v > 255:
			return PackedInt32Array()
		out.append(v)
	return out


## Tailscale (CGNAT) aralığı 100.64.0.0/10.
static func is_tailscale(ip: String) -> bool:
	var o: PackedInt32Array = ipv4_octets(ip)
	return o.size() == 4 and o[0] == 100 and o[1] >= 64 and o[1] <= 127


## Özel ev/ofis ağı: 10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16.
static func is_private_lan(ip: String) -> bool:
	var o: PackedInt32Array = ipv4_octets(ip)
	if o.size() != 4:
		return false
	return o[0] == 10 or (o[0] == 172 and o[1] >= 16 and o[1] <= 31) or (o[0] == 192 and o[1] == 168)


## Sanal makine/konteyner ağı (VirtualBox host-only 192.168.56.0/24, Docker köprüsü 172.17.0.0/16):
## arkadaşın ulaşamayacağı, çoğu makinede bulunan adresler; LAN listesinin sonuna konur.
static func is_virtual_lan(ip: String) -> bool:
	var o: PackedInt32Array = ipv4_octets(ip)
	return o.size() == 4 and ((o[0] == 192 and o[1] == 168 and o[2] == 56) or (o[0] == 172 and o[1] == 17))


## Davet adresi adayları, önerilen ilk sırada: önce Tailscale, sonra özel LAN, en sonda sanal ağlar
## (is_virtual_lan); her grupta giriş sırası, tekrarsız. IPv6, 169.254 (link-local), loopback ve genel
## adresler atlanır. Aday yoksa [LOOPBACK].
static func invite_candidates(addresses: PackedStringArray) -> PackedStringArray:
	var tailscale: PackedStringArray = []
	var lan: PackedStringArray = []
	var virtual: PackedStringArray = []
	for raw: String in addresses:
		var ip: String = raw.strip_edges()
		if is_tailscale(ip):
			if not tailscale.has(ip):
				tailscale.append(ip)
		elif is_virtual_lan(ip):
			if not virtual.has(ip):
				virtual.append(ip)
		elif is_private_lan(ip):
			if not lan.has(ip):
				lan.append(ip)
	var out: PackedStringArray = tailscale + lan + virtual
	if out.is_empty():
		out.append(LOOPBACK)
	return out


## Bu makinenin arabirimlerinden davet adresi adayları.
static func local_invite_candidates() -> PackedStringArray:
	return invite_candidates(IP.get_local_addresses())


## Davette gönderilen biçim: her zaman "adres:port".
static func invite_text(address: String, port: int) -> String:
	return "%s:%d" % [address, port]


## Menüden host olunduysa o port, yoksa `fallback_port` (çağıran komut satırı portunu verir: Args.port).
static func session_port(fallback_port: int) -> int:
	return hosted_port if hosted_port > 0 else fallback_port


# --- ayrıştırma ---

## Geçerli port (MIN_PORT..MAX_PORT) ya da -1.
static func parse_port(text: String) -> int:
	var t: String = text.strip_edges()
	if t.is_empty() or t.length() > 5 or not _all_digits(t):
		return -1
	var port: int = t.to_int()
	return port if port >= MIN_PORT and port <= MAX_PORT else -1


## Geçerli IPv4 ya da makine adı (Tailscale MagicDNS adı dahil). Boşluk, IPv6 ve boş ad geçersiz.
static func is_valid_host(address: String) -> bool:
	if address.is_empty() or address.length() > MAX_ADDRESS_LENGTH:
		return false
	if _all_digits(address.replace(".", "")):
		return ipv4_octets(address).size() == 4  # yalnız rakam ve nokta: IPv4 olmalı
	return _hostname.search(address) != null


## "adres" ya da "adres:port" (baş/son boşluklar atılır; port yoksa `default_port`).
## Dönüş {"ok": bool, "address": String, "port": int}; geçersizse ok=false (adres/port yine dolu olabilir).
static func parse_host_port(text: String, default_port: int = DEFAULT_PORT) -> Dictionary:
	var t: String = text.strip_edges()
	var address: String = t
	var port: int = default_port
	var colons: int = t.count(":")
	if colons > 1:
		return {"ok": false, "address": t, "port": -1}  # IPv6 desteklenmez
	if colons == 1:
		address = t.get_slice(":", 0).strip_edges()
		port = parse_port(t.get_slice(":", 1))
	var ok: bool = is_valid_host(address) and port >= MIN_PORT and port <= MAX_PORT
	return {"ok": ok, "address": address, "port": port}


## Panodaki metinden davet adresi. Metnin tamamı "adres[:port]" ise o (tek sözcük, noktasız ve rakamsız
## metin makine adı sayılmaz: "merhaba"). Değilse metindeki "IPv4[:port]" ve "ad.ts.net[:port]" adayları
## arasından: önce portu yazılmış olan, sonra Tailscale (100.64/10 ya da ts.net), sonra özel ağ, sonra
## diğerleri; eşitlikte metindeki sıra. Bulunamazsa ok=false.
static func find_invite(text: String, default_port: int = DEFAULT_PORT) -> Dictionary:
	var whole: Dictionary = parse_host_port(text, default_port)
	if whole["ok"] and _looks_like_address(whole["address"]):
		return whole
	var best: Dictionary = {"ok": false, "address": "", "port": -1}
	var best_rank: int = 1 << 30
	var found: Array[RegExMatch] = _ipv4_in_text.search_all(text)
	found.append_array(_ts_name_in_text.search_all(text))
	for m: RegExMatch in found:
		var has_port: bool = not m.get_string(2).is_empty()
		var candidate: Dictionary = parse_host_port(m.get_string(1) + (":" + m.get_string(2) if has_port else ""), default_port)
		if not candidate["ok"]:
			continue
		var address: String = candidate["address"]
		var tier: int = 3
		if is_tailscale(address) or address.ends_with(".ts.net"):
			tier = 1
		elif is_private_lan(address):
			tier = 2
		var rank: int = ((0 if has_port else 4) + tier) * 100000 + m.get_start(1)
		if rank < best_rank:
			best_rank = rank
			best = candidate
	return best


## Adres alanına yazılacak biçim: port varsayılansa yalnız adres, değilse "adres:port".
static func format_address(address: String, port: int, default_port: int = DEFAULT_PORT) -> String:
	return address if port == default_port else invite_text(address, port)


# --- kalıcılık ---

## Varsayılan ayarlar (dosya yok ya da bozuk).
static func default_settings() -> Dictionary:
	return {KEY_NAME: "", KEY_ADDRESS: ""}


## Ayarları okur. Dosya yoksa, bozuksa ya da değerler beklenen tipte değilse varsayılanlar döner; hata basılmaz.
static func load_settings(path: String = "") -> Dictionary:
	var out: Dictionary = default_settings()
	var cfg := ConfigFile.new()
	var file_path: String = path if not path.is_empty() else settings_path
	if not FileAccess.file_exists(file_path):
		return out
	# Bozuk dosyada ConfigFile ayrıştırma hatası basar; oyuncu için önemsiz (varsayılana düşülür).
	var previous: bool = Engine.print_error_messages
	Engine.print_error_messages = false
	var err: Error = cfg.load(file_path)
	Engine.print_error_messages = previous
	if err != OK:
		return out
	var player_name: Variant = cfg.get_value(SECTION, KEY_NAME, "")
	if player_name is String:
		out[KEY_NAME] = strip_control(player_name as String).strip_edges().left(MAX_NAME_LENGTH)
	var address: Variant = cfg.get_value(SECTION, KEY_ADDRESS, "")
	if address is String:
		out[KEY_ADDRESS] = strip_control(address as String).strip_edges().left(MAX_ADDRESS_LENGTH)
	return out


## Ayarları yazar; `values`ta olmayan anahtarlar dosyadaki değerini korur.
static func save_settings(values: Dictionary, path: String = "") -> Error:
	var file_path: String = path if not path.is_empty() else settings_path
	var merged: Dictionary = load_settings(file_path)
	for key: String in [KEY_NAME, KEY_ADDRESS]:
		if values.has(key):
			merged[key] = str(values[key]).strip_edges()
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, KEY_NAME, merged[KEY_NAME])
	cfg.set_value(SECTION, KEY_ADDRESS, merged[KEY_ADDRESS])
	return cfg.save(file_path)


## Yapıştırılan tek parça metin adres sayılır mı: nokta ya da rakam içermeli (MagicDNS kısa adı elle yazılır).
static func _looks_like_address(address: String) -> bool:
	if address.contains("."):
		return true
	for i: int in address.length():
		var c: int = address.unicode_at(i)
		if c >= 48 and c <= 57:
			return true
	return false


## Kontrol karakterleri (C0, DEL, C1) atılır.
static func strip_control(text: String) -> String:
	var out: String = ""
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if c >= 32 and not (c >= 127 and c <= 159):
			out += text[i]
	return out


static func _all_digits(text: String) -> bool:
	for i: int in text.length():
		var c: int = text.unicode_at(i)
		if c < 48 or c > 57:
			return false
	return not text.is_empty()
