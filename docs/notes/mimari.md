# Teknik mimari ve sözleşmeler (2026-10-01)

Tasarımın kaynağı `docs/tasarim/oyun-tasarimi.md`; bu dosya **nasıl yapıldığını** ve ajanlar arası **sözleşmeleri** (S1..S9) tutar. Sözleşme değişikliği koordinatör kararıdır ve önce bu dosyaya yazılır; kalem ancak ondan sonra Hazır olur.

## 1. Temel seçimler (KR-007, KR-008)
- **Motor:** Godot **4.7.2-stable**. Ajanlar ve CI aynı sürümü kullanır (`tools/get_godot.sh`). Sürüm yükseltmesi ayrı IS kalemidir.
- **Dil:** GDScript, **katı statik tipleme**: her değişken/parametre/dönüş tipli (`var x: int`, `:=` çıkarımı serbest), `untyped_declaration` uyarısı proje ayarında **hata**. C# yok; sıcak nokta çıkarsa GDExtension ayrı karar.
- **Görünüm:** 2D üstten. Oyun mantığı görselden ayrı yazılır (3D'ye geçiş ihtimali, KR-003): kurallar `core/` altında düğümsüz `RefCounted` sınıflarda ya da sahnenin görsel olmayan düğümlerinde; görsel düğümler yalnız durumu okur.
- **Ağ:** Godot yüksek seviye multiplayer. Faz 1-4 taşıma **ENet** (`ENetMultiplayerPeer`), Faz 5'te **GodotSteam** `SteamMultiplayerPeer` aynı arayüzün arkasına eklenir (S1). Host oyunculardan biridir (peer 1), ayrı sunucu yok.
- **Fizik/tick:** `physics_ticks_per_second = 60`; ağ senkron aralığı oyuncular için 0,05 sn (20 Hz).
- **Pencere:** 1280×720, `stretch/mode = canvas_items`, `aspect = expand`.

## 2. Dizin yapısı
```
project.godot            ayarlar, autoload'lar, girdi haritası, katmanlar (altyapi)
main.tscn / main.gd      açılış: argümanlara göre menü ya da doğrudan host/katıl (cekirdek)
autoload/                Net, Args, Game (cekirdek); NoiseBus (oynanis)
core/                    düğümsüz kurallar (RefCounted): gürültü hesabı, etkileşim kuralları, ileride uyarı/ekonomi
entities/player/         oyuncu sahnesi ve girdi (oynanis)
entities/props/          etkileşimli nesneler: Interactable tabanı, kasa, kapı, kilit (oynanis)
entities/npc/            siviller, ileride muhafızlar (oynanis)
levels/                  seviye sahneleri ve test arenası (seviye)
ui/                      menü, lobi, HUD, tema (arayuz)
i18n/                    texts.csv: tüm görünür metinler (arayuz; ekleme herkese serbest)
data/                    .tres içerik kaynakları (sahip: içeriği tanımlayan ajan)
tests/                   run_tests.gd + t.gd (altyapi), unit/test_*.gd (modül sahibi), net/*.json senaryolar, fixtures/
tools/                   get_godot.sh, ci_local.sh (altyapi); net_smoke.py, latency_proxy.py (cekirdek)
.github/workflows/ci.yml (altyapi)
docs/                    koordinatör (tasarim/ → tasarim ajanı, koordinatör isteğiyle)
```
`.godot/` ve `.tools/` gitignore'dadır; `*.uid` ve `*.import` dosyaları commit'lenir. Yeni dosya ekleyen ajan `godot --headless --path . --import` çalıştırıp oluşan `.uid` dosyalarını da çalışma ağacında bırakır.

## 3. Sözleşmeler

### S1 — Net (autoload `Net`, `autoload/net.gd`)
```
signal peer_connected(peer_id: int)
signal peer_disconnected(peer_id: int)
signal connected_to_host()
signal connection_failed()
signal host_disconnected()
func host(port: int = 7777, max_peers: int = 4) -> Error
func join(address: String, port: int = 7777) -> Error
func leave() -> void
func is_host() -> bool
func is_online() -> bool
func local_peer_id() -> int
func get_ping_ms(peer_id: int = 1) -> int      # host için 0; bilinmiyorsa -1
```
Taşıma seçimi Net'in içinde kalır (`_create_peer()`); başka hiçbir dosya `ENetMultiplayerPeer`/Steam sınıflarına doğrudan dokunmaz. Varsayılan port 7777 (UDP).

### S2 — Yetki modeli
- **Host yetkili:** etkileşim sonuçları, NPC davranışı, gürültü yayılımı, ekip nakdi, oturum durumu, ileride uyarı/muhafız/ekonomi. Host'ta çalışan kod `multiplayer.is_server()` ile korunur.
- **İstemci yetkili:** yalnız her oyuncunun **kendi hareketi** (konum, yön, hareket kipi). Uygulama (US-004): yerel oyuncu `net_position/facing/mode` ile kendi saatinden `net_time`'ı 20 Hz güvenilmez kanaldan senkronlar; uzak kopya gönderenin saatine göre (saat farkı üstel ortalama) şimdi − 100 ms anını iki anlık görüntü arasında doğrusal ara değerler, veri gecikirse son durumda bekler (ileri tahmin yok). Oyuncu kökü `set_multiplayer_authority(peer_id)`; `MultiplayerSynchronizer` bu alanları 0,05 sn aralıkla yayınlar; uzak kopyalar ara değerleme (interpolasyon) ile çizilir.
- **Gecikme toleransı** (GDD "Ağ ve gecikme"): host, istemci isteğini doğrularken menzile +24 px ve zamana +0,25 sn pay verir; saklanma/görülme kararlarında şüphe oyuncu lehine ~0,2 sn geç başlar (Faz 2).
- RPC kuralları: istemci→host istekleri `@rpc("any_peer", "call_remote", "reliable")` ve host gönderen kimliğini `multiplayer.get_remote_sender_id()` ile doğrular; host→herkes durum olayları `@rpc("authority", "call_local", "reliable")`; yalnız görsel olaylar (gürültü halkası) `unreliable`.

### S3 — Oturum ve oyuncular (autoload `Game`, `autoload/game.gd`)
```
signal players_changed()
signal local_player_changed(player: Node)
signal team_cash_changed(value: int)
signal level_loaded(level: Node)
signal session_event(kind: StringName, data: Dictionary)   # herkeste yayılır (ör. &"police_called")
const DEFAULT_LEVEL := "res://levels/store_a.tscn"
const HUD_SCENE := "res://ui/hud.tscn"
var player_scene: PackedScene             # varsayılan res://entities/player/player.tscn; testler değiştirebilir
func set_local_name(player_name: String) -> void   # bağlanınca host'a bildirilir
func players() -> Dictionary              # peer_id -> {"name": String, "slot": int}  (KR-018: renk yok; görsel taraf slot → ThemeTokens.PLAYER_COLORS[slot])
func local_player() -> Node               # yerel oyuncu düğümü ya da null
func start_level(level_path: String) -> void   # yalnız host; herkese yükletir
func current_level() -> Node
func add_team_cash(amount: int) -> void        # yalnız host
func team_cash() -> int
func raise_session_event(kind: StringName, data: Dictionary = {}) -> void   # yalnız host; herkese yayınlar, dökümde "events" listesine girer
func register_dump_provider(key: String, provider: Callable) -> void
func collect_dump() -> Dictionary
```
- Uygulama (US-001): seviye her peer'da `/root/Game/World/Level` yoluna yüklenir (`current_scene` dışında); `PlayerSpawner` oyuncu sahnesini `spawn_function` ile üretir. Geç katılan istemci, oturuma kabulden önce SceneMultiplayer el sıkışmasında (`auth_callback`, Game'e ait) host'tan seviye yolunu ve sürümü alıp yükler; host oyuncuları gönderdiğinde yol hazırdır. Oturum içi seviye değişimi: istemciler eşitlemeyi durdurup onay yollar → eski oyuncular kaldırılır → yükleme RPC'si → yeni oyuncular. Kabulde (ve seviye değişiminden sonra) host bildiği güncel oyuncu konumlarını spawn paketlerinin hemen ardından güvenilir RPC ile yollar, ardından 2 sn 20 Hz güvenilmez yetiştirme akışı gelir; istemci bunu o düğümün senkronlayıcısından ilk veri gelene kadar uygular (geç katılan diğerlerini doğma noktasında görmez). ENet paket kısma (throttle) her peer'da `throttle_configure(5000, 32, 0)` ile ayarlanır; aksi halde düşük gecikmede güvenilmez senkron paketleri atılır. Uzak oyuncu varken `start_level` ~1 RTT sonra tamamlanır; bitişi `level_loaded` bildirir. `Net.leave()` ya da `host_disconnected` sonrası Game seviyeyi kaldırır; menüye dönüşü HUD yapar (`MainMenu.open`), argümanla açılan oturum menüye dönmez, çıkar.
- Sözleşmeye eklemeler (US-001): `Net.connect_timeout_ms` (varsayılan 5000), Args alanları, `Game.to_json_value()`, `Game.BASE_DUMP_KEYS` (sağlayıcılar taban anahtarları ezemez). Döküme `samples` (0,2 sn dilimli konum örnekleri) ve `exit_reason` eklendi.
- Headless değilse ve `HUD_SCENE` varsa Game, seviye yüklenince HUD'u seviyenin üstüne `CanvasLayer` olarak ekler. Argümansız açılışta `main.gd` `res://ui/main_menu.tscn`'e geçer; `Net.leave()` sonrası da oraya döner.
- Seviye yüklenince Game, seviye kökünün altına (her peer'da aynı yolda) `PlayerSpawner` adında `MultiplayerSpawner` kurar: `spawn_path = Players`, spawnable = `player_scene`. Host her bağlı peer (kendisi dahil) için oyuncu üretir; düğüm adı `str(peer_id)`, konum `SpawnPoints` altındaki sıradaki `Marker2D`.
- Ekip nakdi host'ta tutulur, değişince herkese RPC ile yayınlanır.

### S4 — Seviye sahnesi düzeni (`levels/*.tscn`)
Kök `Level` (`levels/level.gd`, `class_name Level extends Node2D`, build_levels köke atar; KR-018) ve API'si: `players_root() -> Node2D`, `props_root() -> Node2D`, `npcs_root() -> Node2D`, `spawn_count() -> int`, `spawn_position(index: int) -> Vector2`, `marker(marker_name: StringName) -> Node2D` (yoksa null). Çekirdek ve diğer sistemler seviye düğümlerine **yalnız bu API ile** erişir, ad dizesiyle gezmez. Zorunlu çocuklar: `Walls` (duvarlar; fizik katmanı `world`), `SpawnPoints` (en az 4 `Marker2D`: `Spawn1..4`), `Players` (boş `Node2D`), `Props` (etkileşimli nesneler), `NPCs` (siviller), `Markers` (yerleşim işaretleri: `Register`, `BackDoor`, `FrontDoor`, `Counter`, `Exit` vb.; içerik ekleyen ajan bunları kullanır). Faz 2'de `NavigationRegion2D` ve `EscapeZone` eklenir. Ölçek: 1 karo = 32 px; karakter çapı ~24 px.
- **Üretim kuralı (US-002):** seviyeler `levels/layouts/<ad>.txt` ASCII düzeninden `levels/tools/build_levels.gd` ile üretilir (`$GODOT --headless --path . -s res://levels/tools/build_levels.gd`); `.tscn`'nin `Walls`/`Tiles`/`SpawnPoints`/`Markers` kısmı elle düzenlenmez, düzen değişikliği .txt'de yapılıp yeniden üretilir. `Players`, `Props`, `NPCs` altına eklenen düğümler yeniden üretimde korunur.
- Ek düğüm `Tiles` (`LevelLayout`, `levels/level_layout.gd`): zemin/duvar çizimi ve ızgara bilgisi.
- Kapı işaretleri (`FrontDoor`, `BackDoor`, `BackroomDoor` …): konum = 1 karoluk boşluğun merkezi; dönüş 0° → yatay duvarda, 90° → dikey duvarda.
- Çarpışma şekil adları: `Bound*`, `Wall*`, `Window*` (Faz 2'de görüşü geçirir), `Shelf*`, `Counter*`.

### S5 — Girdi eylemleri (project.godot, altyapi tanımlar)
`move_up/down/left/right` (WASD + oklar + sol çubuk) · `sprint` (Shift) · `sneak` (Ctrl) · `interact` (E; basılı tut) · `intimidate` (Q) · `pause` (Esc + Start; IS-009) · `toggle_debug` (F3) · `ui_*` varsayılanlar (`ui_accept` + gamepad A, `ui_cancel` + gamepad B; IS-009). Gamepad eşlemeleri aynı eylemlere eklenir. Oyuncu girdisi doğrudan `Input` değil **`PlayerInput`** soyutlamasından okunur (S6 bot girdisi için).
- Oyun içi menü/odaklı arayüz açıkken oyun girdisi okunmaz: `PlayerInput` her karede `UiInput.is_gameplay_input_blocked() -> bool` (statik, `ui/ui_input.gd`, arayuz) sorgular; bot girdisi bundan etkilenmez.

### S6 — Komut satırı, bot girdisi ve test dökümü
- Kullanıcı argümanları `--` sonrasında (autoload `Args`, `autoload/args.gd`): `--host` · `--join=ADDR` · `--port=N` · `--name=AD` · `--level=res://...` · `--bot=PATH.json` · `--dump=PATH.json` · `--quit-after=SN` · `--player-scene=res://...` (yalnız test).
- Bot dosyası: `{"steps":[{"t":0.0,"move":[1,0]},{"t":1.5,"move":[0,0]},{"t":2.0,"hold":"interact","dur":4.5},{"t":7.0,"press":"intimidate"}]}`; `t` saniye, oyun başlangıcına göre. `PlayerInput` bot modunda bu zaman çizelgesini oynatır.
- Döküm (`--dump`, çıkışta yazılır): `{"peer_id":int,"is_host":bool,"peers":[int],"players":{"<peer>":{"pos":[x,y]}},"team_cash":int, ...sağlayıcı anahtarları}`. Her sistem `Game.register_dump_provider()` ile kendi anahtarını ekler (ör. `"civilians"`, `"props"`; US-004: `"player_states"` — kip, yön, duvar içi kare sayısı, tampon tükenmesi).
- `samples_near` eşikleri görüntü gecikmesini ölçer (hız × (tek yön gecikme + 100 ms tampon + kare)); oyun kuralı değildir, oyun toleransı S2'dedir. Gerçek oyuncu: host↔istemci 32 px, istemci↔istemci (host üzerinden iki bacak) 48 px; fikstür oyuncu (ara değerleme yok) 40 px.
- Ağ duman testi: `python3 tools/net_smoke.py tests/net/<senaryo>.json [--latency-ms 150]`. Senaryo: `{"level":..., "clients":2, "duration":12, "bots":{"host":"...","c1":"..."}, "expect":[{"all_equal":"team_cash"}, {"eq":["host.team_cash", 150]}, {"near":["host.players.2.pos","c1.players.2.pos", 8]}]}`. Gecikme `tools/latency_proxy.py` ile (UDP röle, yön başına RTT/2 gecikme + isteğe bağlı jitter/kayıp).

### S7 — Etkileşim protokolü
- **Bileşen modeli (KR-018):** `Interactable` bir prop'un kökü değil, **alt bileşenidir** (`entities/props/interactable.gd`, `class_name Interactable extends Area2D`, katman interactables). Alanlar: `@export var action_key: String` (i18n anahtarı), `@export var hold_time: float`, `@export var interact_range: float = 40.0`, `@export var enabled: bool = true`, `@export var requirement: InteractionRequirement` (opsiyonel Resource: gereken etiket + kademe + taraf kısıtı, ör. "yalnız tezgâh arkasından"); sinyaller `completed(peer_id: int)` ve `cancelled(peer_id: int)` (yalnız host'ta yayılır). RPC'ler, doğrulama ve çoğaltılan `busy_by: int` (0 = boş) / `progress: float` bileşendedir.
- Prop (`register.gd`, `door.gd` …) yalnız kendi durumunu tutar, bileşenin `completed`'ine bağlanıp sonucu uygular ve durumunu `MultiplayerSynchronizer` (host yetkili) ile yayar. Bir prop birden çok Interactable taşıyabilir (kapı: aç/kapa, maymuncuk, ileride tekme). Yeni nesne = sahne + kısa betik; yeni yöntem = sahneye bir Interactable düğümü. Menzil/tolerans/meşguliyet/gereksinim kuralları `core/interaction_rules.gd`'de düğümsüz.
- Akış: oyuncu yakındaki en yakın uygun `Interactable`'ı yerelde bulur ve istem gösterir → `interact` basılınca host'a istek (S2 RPC) → host doğrular (S2 toleransı + requirement), `busy_by` atar, süreyi sayar → oyuncu bırakırsa ya da menzilden çıkarsa iptal → süre dolunca host `completed` yayar, prop sonucu uygular ve herkese yayınlar.
- Oyuncu sinyalleri (HUD sözleşmesi): `interaction_target_changed(action_key: String)` (yakındaki etkileşilebilir hedef değişti; boş dize = hedef yok; HUD "[E] <eylem>" istemi gösterir), `interaction_started(action_key: String, duration: float)`, `interaction_finished(success: bool)`; yalnız yerel oyuncuda yayılır.
- Arayüz sahneleri (`ui/*.tscn`) autoload'larda `preload` edilmez, çalışma anında `load()` ile yüklenir (UI betikleri autoload adlarına derlemede bağlı).

### S8 — Gürültü (autoload `NoiseBus`, `autoload/noise.gd`)
Autoload adı `NoiseBus`'tır: `Noise` Godot'un yerleşik sınıfıyla çakışır (KR günlüğü 2026-10-01).
`func emit_noise(pos: Vector2, radius: float, kind: StringName, source_peer: int = 0) -> void` — istemciden çağrılırsa host'a iletilir; host `noise_listener` grubundaki düğümlerin `hear_noise(pos: Vector2, radius: float, kind: StringName) -> void` metodunu çağırır ve herkese görsel halka olayı yollar. Yarıçaplar `data/noise_profile.tres` içinde (yürüme 0, sızma 0, koşma 120, kapı 160, kasa boşaltma 90, sindirme 140 — başlangıç değerleri). Hesap kuralları `core/` altında, düğümsüz test edilir.

### S9 — Metin ve tema (ton altyapısı, KR-005)
- Oyuncuya görünen **her metin** `tr("ANAHTAR")` ile; anahtarlar `i18n/texts.csv` (kolonlar `keys,tr,en`). Sabit dize UI'da yasak.
- Seviye çizimi renkleri ton paletinden okur: karo dolgu/kenarları `ThemeTokens.tone().level_*`, harita kenarı dolgusu `bg_color`, cam dolgusu/tarama/bordür çizgileri `wall_color` (IS-008); noir'in `LEVEL_*` değerleri MUTED'dan bağımsız sabitlerdir (arayüz kontrast ayarı dünya renklerini kaydırmaz).
- Renk ve yazı tipleri yalnız tema token'larından (`ui/theme/tokens.gd`, `class_name ThemeTokens`) ve `ui/theme/noir.tres` temasından okunur. Oyun için anlamlı renkler (kart rengi, uyarı rengi) her tonda aynı kalır ve `ThemeTokens.GAMEPLAY_*` adını taşır.

### S10 — İçerik verisi (KR-018)
- Katalog içeriği (eşya, perk, prop tanımı, modifikatör, iş şablonu …) `data/<tür>/<id>.tres` dosyalarıdır; tür başına `class_name <X>Def extends Resource`; **id = dosya adı** (StringName). Katalog dizin taramasıyla yüklenir.
- Ağda yalnız id gider, Resource nesnesi gitmez; host her isteği id + yetenek kapısıyla doğrular.
- Etkiler küçük tipli Resource alt sınıflarıdır (`StatModifier`, `GrantTag` …); sayılar tek bir düğümsüz çözücüde hesaplanır (`core/stats.gd`: `resolve(base, loadout, perks) -> StatBlock`, Faz 4). Yeni eşya = 1 `.tres` + i18n satırı, kod değişmez; yeni etki türü = 1 küçük Resource + çözücüde 1 `match` kolu.
- Karakter/rol ayrı sınıf değildir: tek `player.tscn`; rol = loadout + perk verisi + kozmetik (KR-017 kukla parametreleri).
- Ayar dosyaları (ör. `data/player_tuning.tres`) katalog değildir; aynı `class_name … extends Resource` kalıbını kullanır.

### S11 — NPC bileşenleri (Faz 2, KR-018)
Muhafız, sivil ve kamera aynı algı bileşenlerini birleştirir: `entities/npc/components/` altında `Perception` (koni + görüş hattı → görünürlük), `Suspicion` (oyuncu başına 0-100, `threshold_reached(peer_id, level)` sinyali), `Hearing` (`noise_listener`, S8), `Patrol`. Davranış `core/fsm.gd` (küçük durum makinesi) + NPC türü başına bir "beyin" betiği (`brain_guard.gd`, `brain_civilian.gd`); kamera = hareketsiz NPC sahnesi. Bileşenler yalnız host'ta işler; senkronlanan durum (yön, kademe) istemcide çizilir. Yeni NPC = sahne + beyin betiği; algı kodu değişmez.

## 4. Fizik katmanları (project.godot)
1 `world` (duvar, kapalı kapı) · 2 `players` · 3 `npcs` · 4 `interactables` · 5 `triggers` (bölge alanları) · 6 `vision_block` (görüşü kesen ama yürünebilen; Faz 2).

## 5. Test katmanları ve CI
- **Birim:** `godot --headless --path . -s res://tests/run_tests.gd` → `tests/unit/test_*.gd` içindeki `test_*` metotları; doğrulamalar `tests/t.gd`; çıkış kodu 0/1.
- **Ağ duman:** S6; her ağ davranışı en az bir senaryo taşır; senaryolar 0 ms ve 150 ms RTT ile geçer.
- **İçe aktarma temizliği:** `godot --headless --path . --import` hata/uyarı-hata vermez.
- **Yerel CI:** `tools/ci_local.sh` = Godot indir (yoksa) → import → birim → tüm `tests/net/*.json` (0 ve 150 ms). Push öncesi koordinatör çalıştırır. Uzak CI `.github/workflows/ci.yml` aynısını dev ve main push'unda çalıştırır.

## 7. İleri uyumluluk notları (bugün uygulanmaz, kapı kapatılmaz)
- **Alternatif giriş ve kasa erişimi (GB-02):** seviye düzenine ileride yeni karo türleri eklenecek: havalandırma kanalı (yalnız sürünme kipinde geçilir, görüşü keser), zayıf duvar (yıkılabilir parça), kat geçişi (delik/merdiven). Bu yüzden `build_levels.gd` birleştirdiği duvar dikdörtgenlerinde türleri ayrı tutar (zaten `Wall*`/`Window*`/`Shelf*` ayrımı var); yıkılabilir duvar ayrı düğüm olacağı için birleştirmeye girmez. Çok katlı seviye: her kat ayrı katman/alt sahne, oyuncunun bulunduğu kat çoğaltılan bir alan; S4'e o kalemde ekleme yapılır.

## 6. Stil ve tasarım kuralları (KR-018)
- **Bağımlılık yönü:** `core/` → hiçbir proje dizini (yalnız Vector2/float/StringName gibi değerler; Node2D/Node3D bilmez — 3D'ye taşınabilirlik); `autoload/` → core, data, `levels/level.gd` (yalnız S4 Level API'si); `entities/` → core, autoload, data; `levels/` → core, data; `ui/` → autoload sözleşmeleri. `autoload/` ve `core/` `ui/`'yi içe almaz. İstisna: görsel düğümler (entity görselleri, seviye çizimi) `ThemeTokens` okuyabilir; `PlayerInput` yalnız S5'teki `UiInput.is_gameplay_input_blocked()` statik sorgusunu çağırabilir; Game'in HUD'u `load()` ile yol dizesinden eklemesi bilinçli istisnadır (derleme bağımlılığı yok).
- **Bileşim > kalıtım:** kalıtım derinliği en fazla Godot sınıfı → proje sınıfı → +1 (Npc→Guard→ArmedGuard yok, Item→Weapon→Pistol yok). Davranış küçük bileşen düğümleri, veri Resource, olay sinyal.
- **Çatı yok:** ECS çatısı, genel olay otobüsü (`session_event` dışında), servis bulucu/DI kabı, ifade dili, sistem başına "Manager" autoload yok; autoload yalnız süreç geneli servis (Net, Args, Game, NoiseBus; ileride en fazla bir katalog). Soyut taban taklidi (`assert(false)` dolu sınıf) yok; ajan sınırlarında duck typing + `has_method/has_signal`.
- **Kapsülleme:** `_` önekli üyeler sınıf dışından erişilmez; ui/ için `test_ui_fakes` bunu otomatik denetler, entities/ için eşdeğer tarama testi IS-005'te eklenir.
- **Sadelik ölçüsü:** bir ajan bir örnek dosya + bu belgede bir paragraf okuyarak yeni prop/NPC/eşya ekleyebilmeli; dosya ≲ 400 satır (aşan dosya bölünme adayıdır; `game.gd` Faz 4 ekonomi ayrımında bölünür); bir kavram için tek `match`.
- Dosya ve düğüm adları `snake_case` (dosya) / `PascalCase` (düğüm, class_name). Sinyaller geçmiş zaman (`interaction_started`).
- Autoload'lar arası çağrı yalnız S1/S3/S8 arayüzleriyle; başka ajanın dosyasındaki özel metoda erişim yok.
- `print` yerine `push_warning`/`push_error`; tekrar eden ağ log'u yok.
- Sihirli sayılar `data/*.tres` ya da dosya başı `const`.
