# Backlog

## 0. Süreç özeti
Durumlar: Backlog → Hazır → Sürüyor → Denetimde → Bitti; Engelli (KR / kullanıcı-cihaz / dış); Elendi. Öncelik P1 (bu faz) / P2 (fırsat) / P3 (sonraki faz). Büyüklük XS/S/M. Yalnız koordinatör yazar. Kalem Hazır olmadan (DoR tam, sözleşme mimari.md'de) ajana verilmez. Aktif paket ≤ 3, ajan başına 1, dosya kümeleri ayrık; paralel paket worktree'de. Ayrıntı: surec.md. Sözleşmeler: mimari.md S1-S9. Tasarım: docs/tasarim/oyun-tasarimi.md.

## 1. Fazlar (MVP yol haritası; her faz sonu durma noktası)
Faz planı Fable (tasarim) incelemesiyle düzeltildi (KR-015).

| EP | Faz | Hedef | Çıkış kriterleri (ölçülebilir) | Durum |
|---|---|---|---|---|
| EP-00 | Faz 0 — Kurulum | Süreç, tasarım, Godot iskeleti, test ve CI hazır; Steam riski erken ölçülmüş | 1) `tools/ci_local.sh` boş projede yeşil, 1 geçen birim testle < 5 dk · 2) import uyarı-hatasız · 3) GodotSteam GDExtension'ın 4.7.2'de yüklenip yüklenmediği biliniyor (IS-004) · 4) GDD v0.1 ve mimari sözleşmeler yazılı | Bitti (2026-10-01; uzak CI ilk koşusu repo açılınca) |
| EP-01 | Faz 1 — İki kişi bakkalda | Online his: bağlan, yürü, kasayı boşalt | 1) Tüm ağ senaryoları 0 ve 150 ms RTT'de yeşil · 2) 150 ms'de hareket sırasında senkron hatası < 1 karo (32 px) · 3) Kasa boşaltma sonucu tüm peer'larda RTT + 200 ms içinde · 4) 10 dk headless dayanıklılık koşusunda hata logu yok · 5) Windows + Linux build'i üretiliyor · 6) Kullanıcı doğrulaması: iki makine (Tailscale) ≤ 5 sn'de bağlanıyor, bir arkadaş oturumu notlandı (IS-006; fazı engellemez, taşınır) | Sürüyor (2026-10-01) |
| EP-02 | Faz 2 — Gizlilik | 3 kişi bakkal soygununu baştan sona oynar (ilk "eğlenceli mi" kapısı) | Koşan oyuncu koni içinde ≤ 1 sn'de tespit, saklanan hiç tespit edilmiyor (otomatik test) · "?"→inceleme→tespit görünür · kazanma ve kaybetme yolu · iş sonu ekranı · 150 ms'de 20 dk tutarsızlık 0 · 3 arkadaş 3 koşu, ≥ 2'si "tekrar" · Steam spike: 480 lobisiyle 2 kişi hareket | Backlog |
| EP-03 | Faz 3 — Keşif ve plan | Oyunun özgün iddiası: hafızaya dayalı keşif + ortak plan masası (ikinci eğlence kapısı) | keşif→plan→soygun→kaçış ≤ 15 dk · ikon doğruluk oranı ölçülüyor · oyalanma şüphesi ve tanınma tetikleniyor · ardışık 3 koşu ≥ 2 güvenlik parametresinde farklı (tohum) · ≥ 2/3 oyuncu "keşif değdi" | Backlog |
| EP-04 | Faz 4 — Sığınak ve ikinci kademe | İki kademeli mini kampanya | Kampanya + profil kaydı yükleniyor · ekipman yetenek kapısı çalışıyor (T2 maymuncuk → T2 kilit) · ısı > 40'ta muhafız +1 · benzinlik (kamera, DVR, sessiz alarm, sahte kamera) · UI'da sabit metin 0 | Backlog |
| EP-05 | Faz 5 — Steam ve MVP paketi | Arkadaşlar Steam davetiyle oynar = MVP | Davet ≤ 10 sn'de lobiye sokuyor · TR↔SE SteamMultiplayerPeer 30 dk kopmasız · ENet yedeği aynı build'de · build'ler 3 arkadaş makinesinde açılıyor · 3 oturum yazılı geri bildirim · çökme 0 | Backlog |

## 2. Faz 0 ve Faz 1 kalemleri
| ID | Başlık | Faz | Sahip | Ö | B | Bağımlılık | Durum | Commit |
|---|---|---|---|---|---|---|---|---|
| IS-001 | Süreç ve ajan altyapısı | 0 | koordinatör | P1 | S | — | Bitti | |
| IS-002 | Oyun tasarım belgesi v0.1 | 0 | tasarim | P1 | M | — | Bitti | |
| IS-003 | Godot proje iskeleti, test koşucusu, CI | 0 | altyapi | P1 | M | IS-001 | Bitti | (bkz. git log --grep=IS-003) |
| IS-004 | GodotSteam × 4.7.2 uyumluluk kontrolü | 0 | cekirdek | P1 | S | — (yalnız /tmp; IS-003'le paralel) | Bitti (araştırma; koordinatör okuması) | — |
| US-001 | Ağ çekirdeği ve oturum | 1 | cekirdek | P1 | M | IS-003 | Sürüyor (2026-10-01, wt) | |
| US-002 | Bakkal seviyesi v0 + test arenası | 1 | seviye | P1 | S | IS-003 | Sürüyor (t2, wt) | |
| US-003 | Ana menü, HUD iskeleti, tema ve metin altyapısı | 1 | arayuz | P1 | M | IS-003 | Sürüyor (2026-10-01, wt) | |
| US-004 | Oyuncu karakteri ve senkron hareket | 1 | oynanis | P1 | M | US-001, US-002 | Backlog | |
| US-005 | Etkileşim çerçevesi + kasa + kapı | 1 | oynanis | P1 | M | US-004 | Backlog | |
| IS-005 | Faz 1 çıkış testi + Windows/Linux build | 1 | altyapi | P1 | M | US-003, US-005 | Backlog | |
| IS-006 | Kullanıcı doğrulaması: iki makine + arkadaş oturumu | 1 | kullanıcı | P1 | S | IS-005 | Backlog | |
| IS-007 | Faz 1 tasarım değerlendirmesi (Fable) | 1 | tasarim | P1 | S | IS-005 | Backlog | |
| IS-008 | Seviye renklerini ThemeTokens'a taşı (LEVEL_* token'ları) | 1 | seviye | P2 | XS | US-002, US-003 | Backlog | |

### IS-001 — Süreç ve ajan altyapısı
EP-00 · P1 · S · Sahip: koordinatör
**Kabul:** CLAUDE.md, docs/project-index.md, docs/notes/{ajanlar,mimari,durum}.md, docs/surec/{surec,backlog,kararlar,gecmis,geri-bildirim}.md ve .claude/agents/*.md (cekirdek, oynanis, seviye, arayuz, altyapi, denetci, tasarim) yazılı ve birbirine tutarlı.

### IS-002 — Oyun tasarım belgesi v0.1
EP-00 · P1 · M · Sahip: tasarim (Fable)
**Kabul:** docs/tasarim/oyun-tasarimi.md kullanıcı kararlarını (KR-001..006) içerir; MVP kapsamı ve açık sorular yazılı. Koordinatör okuması ile kapanır (kod kalemi değil, denetci yok).

### IS-003 — Godot proje iskeleti, test koşucusu, CI
EP-00 · P1 · M · Sahip: altyapi · Sözleşme: mimari.md §1, §2, §4, §5, S1/S3/S5/S8/S9 (stub imzaları) · Bağımlılık: IS-001
**Kapsam:** Boş ama sözleşmeye uygun Godot projesi; tüm ajanların üzerine çalışacağı ayar, autoload stub'ları, girdi haritası, test koşucusu, yerel ve uzak CI.
**Kabul kriterleri:**
- AC1 `tools/get_godot.sh` Godot 4.7.2-stable Linux ikilisini `.tools/godot`'a indirir (varsa atlar), yolunu basar; `GODOT` ortam değişkeni verilmişse onu kullanır. `"$(tools/get_godot.sh)" --version` 4.7.2 verir.
- AC2 `project.godot`: ad "Insiders", ana sahne `res://main.tscn`, mimari.md §1 pencere/stretch/fizik ayarları, `untyped_declaration` uyarısı hata, S5 girdi eylemlerinin hepsi (klavye + gamepad), §4 katman adları, autoload'lar `Args`, `Net`, `Game`, `NoiseBus` (stub dosyaları; `NoiseBus` dosyası autoload/noise.gd), `i18n/texts.csv` çevirisi kayıtlı (tr, en).
- AC3 Stub'lar S1/S3/S8 imzalarını birebir taşır, gövdeleri tipli varsayılan değer döner; `ui/theme/tokens.gd` (`class_name ThemeTokens`) temel palet sabitleriyle (BG, FG, MUTED, ACCENT, WALL, FLOOR, GAMEPLAY_ALERT, GAMEPLAY_CASH, PLAYER_COLORS) stub olarak var; `main.tscn` + `main.gd` boş açılış.
- AC4 `"$GODOT" --headless --path . --import` hatasız ve uyarı-hatasız biter.
- AC5 `tests/run_tests.gd` `tests/unit/test_*.gd` dosyalarını bulur, `test_` ile başlayan metotları koşar, `tests/t.gd` doğrulama yardımcıları (eq, ne, is_true, is_false, near, has, fail) sağlar, test başına ad + süre + sonuç basar, başarısızlıkta çıkış kodu 1. `tests/unit/test_smoke.gd` (girdi eylemleri ve autoload'lar var) geçer; kasıtlı başarısız bir testle çıkış kodunun 1 olduğu raporda gösterilir (kasıtlı test commit'lenmez).
- AC6 `tools/ci_local.sh`: Godot getir → import → birim testler → `tests/net/*.json` varsa her biri için `python3 tools/net_smoke.py <s>` ve `--latency-ms 150` (net_smoke.py yoksa uyarıyla atlar); tek komut, ilk hatada sıfır olmayan çıkış.
- AC7 `.github/workflows/ci.yml` aynı adımları `dev`/`main` push'unda koşar (Godot ikilisi önbellekli); YAML ayrıştırılabilir.
- AC8 `.gitignore` (`.godot/`, `.tools/`, `build/`, `*.tmp`); `README.md` kısa tanım + "Çalıştırma" (Godot 4.7.2 kur, projeyi aç, iki pencere: Debug → Customize Run Instances) + "Test" (ci_local).
**Dokunulacak:** project.godot, main.tscn, main.gd, autoload/{net,args,game,noise}.gd (stub), ui/theme/tokens.gd (stub), i18n/texts.csv, tests/run_tests.gd, tests/t.gd, tests/unit/test_smoke.gd, tools/get_godot.sh, tools/ci_local.sh, .github/workflows/ci.yml, .gitignore, .gitattributes, README.md, icon.svg
**Dokunulmayacak:** docs/**, .claude/**
**Oku:** mimari.md tamamı · **Test beklentisi:** AC komutları raporda · **Karar gereken (ön):** —

### IS-004 — GodotSteam × 4.7.2 uyumluluk kontrolü
EP-00 · P1 · S · Sahip: cekirdek · Bağımlılık: — (depo dosyasına dokunmadığı için IS-003 ile paralel)
**Kabul:** GodotSteam GDExtension'ın (ve varsa SteamMultiplayerPeer'in) 4.7.2 ile uyumlu en yeni sürümü belirlenir, geçici bir kopyada (`/tmp`, repo dışı) headless yüklenir: `ClassDB.class_exists("Steam")` ve `SteamMultiplayerPeer` sınıfının varlığı raporlanır; app 480 ile `steamInitEx` denenir (Steam istemcisi olmadığından beklenen hata kodu kaydedilir). Sonuç ve önerilen sürüm/indirme adresi raporda; repoya dosya eklenmez.
**Dokunulacak:** yok (yalnız /tmp) · **Dokunulmayacak:** depo dosyalarının hepsi · **Oku:** mimari.md §1, S1

### US-001 — Ağ çekirdeği ve oturum
EP-01 · P1 · M · Sahip: cekirdek · Sözleşme: S1, S2, S3, S6 · Bağımlılık: IS-003
**Hikâye:** Oyuncu olarak arkadaşımın adresine bağlanıp aynı oturuma girmek istiyorum ki aynı seviyede birlikte oynayabilelim.
**Kabul kriterleri:**
- AC1 Given `--host --port=P`, When iki istemci `--join=127.0.0.1 --port=P` ile bağlanır, Then üç süreçte de dökümde `peers` 3 kimlik ve `players` 3 kayıt (isimleriyle) — `tests/net/connect_3.json`.
- AC2 Given host `--level=res://tests/fixtures/empty_level.tscn` ile başladı, When istemciler bağlanır (biri host seviyeyi yükledikten 2 sn sonra), Then hepsinde aynı seviye yüklü ve her peer için `Players/<peer_id>` oyuncu düğümü (test fikstürü `tests/fixtures/dummy_player.tscn`, `--player-scene` ile) var — `late_join.json`.
- AC3 Given bot girdisiyle hareket eden fikstür oyuncuları, Then hareket sırasında örneklenen konum farkı diğer peer'larda < 32 px ve son konum farkı < 8 px — `move_sync.json`.
- AC4 Given oturum, When bir istemci kopar, Then diğer peer'larda oyuncusu silinir; When host kapanır, Then istemciler `host_disconnected` alır, dökümde `"host_lost": true` yazıp çıkış kodu 0 ile kapanır — `disconnect.json`.
- AC5 `Game.raise_session_event` herkese ulaşır ve dökümde `events` listesinde görünür; `Game.add_team_cash` host'ta toplar, herkese yayınlar — `session_events.json`.
- AC6 `tools/latency_proxy.py`: çoklu istemcili UDP röle, `--delay-ms` (yön başına), `--jitter-ms`, `--loss`; python birim testi ölçülen gecikmeyi ±15 ms doğrular. `net_smoke.py --latency-ms 150` bu proxy'yi araya koyar; AC1-AC5 senaryoları 150 ms'de de geçer.
- AC7 Argümansız açılışta `main.gd` `res://ui/main_menu.tscn` varsa ona geçer (yoksa uyarı). Birim testler: Args ayrıştırma, dump birleştirme, geçersiz adreste `connection_failed`.
**Dokunulacak:** autoload/{net,args,game}.gd, main.tscn, main.gd, tools/net_smoke.py, tools/latency_proxy.py, tools/test_latency_proxy.py, tests/net/**, tests/fixtures/**, tests/unit/test_{net,args,game}*.gd
**Dokunulmayacak:** project.godot, entities/**, levels/**, ui/**, i18n/texts.csv (paralel US-003 ile birleştirme çakışmasını önlemek için; metin gerekiyorsa raporda anahtar öner)
**Oku:** mimari.md §1-3, §5 · GDD §12 · **Test beklentisi:** senaryolar 0 ve 150 ms + birim · **Karar gereken (ön):** —

### US-002 — Bakkal seviyesi v0 + test arenası
EP-01 · P1 · S · Sahip: seviye · Sözleşme: S4, S9 · Bağımlılık: IS-003
**Hikâye:** Ekip olarak küçük bir köşe bakkalında dolaşabilmek istiyoruz ki ilk soygunu deneyelim.
**Kabul kriterleri:**
- AC1 `levels/store_a.tscn` S4 düzeninde: `Walls` (StaticBody2D + çarpışma şekilleri, katman world), `SpawnPoints` (Spawn1-4, dış kaldırımda), `Players`, `Props`, `NPCs`, `Markers` (`FrontDoor`, `BackDoor`, `Register`, `Counter`, `ClerkSpot`, `BackroomSafe`, `Exit`).
- AC2 Yerleşim GDD §9 T1 bakkal tarifine uyar: satış alanı + raflar (engel) + tezgâh + arka oda + ön kapı boşluğu + arka (sokak) kapı boşluğu + dış kaldırım/sokak; yaklaşık 30×20 karo; ön kapıdan ve arka kapıdan iki ayrı rota ile kasaya ulaşılır; kapı boşlukları Markers ile işaretli (kapı nesnesini US-005 yerleştirir).
- AC3 Geometrik yer tutucu görseller (zemin, duvar, raf, tezgâh) renklerini `ThemeTokens`'tan alır; sabit renk yok.
- AC4 `levels/test_arena.tscn`: S4 düzeninde boş 20×15 karo oda.
- AC5 `tests/unit/test_levels.gd`: iki sahne yüklenir; zorunlu düğümler ve Markers tam; spawn noktaları duvar şekillerinin içinde değil; ön kapı ve arka kapı Marker'larından Register'a duvarı kesmeyen yol var (ızgara üzerinde basit BFS).
**Dokunulacak:** levels/**, tests/unit/test_levels.gd
**Dokunulmayacak:** autoload/**, entities/**, ui/** (ThemeTokens yalnız okunur), project.godot
**Oku:** mimari.md S4, S9 · GDD §9 (T1), §14 · **Test beklentisi:** birim test + import temiz

### US-003 — Ana menü, HUD iskeleti, tema ve metin altyapısı
EP-01 · P1 · M · Sahip: arayuz · Sözleşme: S1, S3, S7 (oyuncu sinyalleri), S9 · Bağımlılık: IS-003
**Hikâye:** Oyuncu olarak oyunu açınca host olmak ya da adres girip katılmak, oyun içinde ekip nakdini, gecikmeyi ve etkileşim ilerlemesini görmek istiyorum.
**Kabul kriterleri:**
- AC1 `ui/main_menu.tscn`: oyun adı, oyuncu adı alanı, "Host" (port), "Katıl" (adres + port), "Çıkış". Host → `Game.set_local_name`, `Net.host(port)`, `Game.start_level(Game.DEFAULT_LEVEL)`; Katıl → `Game.set_local_name`, `Net.join(...)` + "Bağlanıyor…"; `connection_failed`/`host_disconnected` → hata metni ve menü.
- AC2 `ui/hud.tscn`: ekip nakdi (`team_cash_changed`), ping (`Net.get_ping_ms`, saniyede bir), oyuncu listesi (`players_changed`), oturum olay bildirimi (`session_event` → `EVENT_<KIND>` anahtarlı kısa bildirim), etkileşim istemi + ilerleme çubuğu (`local_player_changed` ile yerel oyuncunun `interaction_started`/`interaction_finished` sinyallerine bağlanır).
- AC3 Esc ile duraklat menüsü: "Devam", "Ayrıl" (`Net.leave()` → ana menü).
- AC4 Tema: `ui/theme/tokens.gd` tamamlanır (noir paleti + GAMEPLAY_* sabitleri), `ui/theme/noir.tres` Theme; tüm ekranlar bunları kullanır. Tüm metinler `tr()` ile, `i18n/texts.csv`'de tr + en.
- AC5 Birim testler: menü butonları enjekte edilen sahte Net/Game nesnelerinde doğru çağrıları yapar; HUD sahte oyuncu sinyaline ve `team_cash_changed`'e tepki verir; `ui/` altındaki .tscn/.gd'de anahtar olmayan sabit metin yok (tarama testi).
- AC6 Klavye ve gamepad ile menüde gezinme (odak sırası tanımlı); 1280×720 ve 1920×1080'de taşma yok (headless'ta düzen boyut kontrolü).
**Dokunulacak:** ui/**, i18n/texts.csv, tests/unit/test_ui_*.gd
**Dokunulmayacak:** autoload/**, entities/**, levels/**, project.godot
**Oku:** mimari.md S1, S3, S7, S9 · GDD §13, §14 · **Test beklentisi:** birim + import temiz; görsel kontrol IS-006'da

### US-004 — Oyuncu karakteri ve senkron hareket
EP-01 · P1 · M · Sahip: oynanis · Sözleşme: S2, S5, S6 · Bağımlılık: US-001, US-002
**Hikâye:** Oyuncu olarak karakterimi yürüyerek, sızarak ve koşarak hareket ettirmek ve arkadaşlarımı akıcı hareket ederken görmek istiyorum.
**Kabul kriterleri:**
- AC1 `entities/player/player.tscn`: CharacterBody2D (katman players; world ve npcs ile çarpışır), yer tutucu görsel (oyuncu renginde daire + yön göstergesi + ad etiketi), Camera2D yalnız yerel oyuncuda etkin.
- AC2 Hız: yürüme 140, sızma 70, koşma 220 px/sn (`data/player_tuning.tres`); 8 yön + analog; duvardan geçmez.
- AC3 `PlayerInput`: klavye/gamepad (S5) ve bot zaman çizelgesi (S6); yalnız yerel oyuncuda girdi okunur.
- AC4 Ağ: istemci yetkili konum/yön/kip senkronu 20 Hz; uzak kopyalar ara değerleme (~100 ms tampon) ile çizilir.
- AC5 `tests/net/store_walk.json`: store_a'da host + 2 istemci bot rotası yürür; hareket sırasında örneklenen konum farkı < 32 px, son konum farkı < 8 px, kimse duvar içinde değil; 0 ve 150 ms.
- AC6 Birim testler: ayar okuma, kipe göre hız, bot zaman çizelgesi ayrıştırma.
**Dokunulacak:** entities/player/**, data/player_tuning.tres, tests/unit/test_player*.gd, tests/net/store_walk.json, tests/net/bots/**
**Dokunulmayacak:** autoload/{net,args,game}.gd, levels/**, ui/**, project.godot
**Oku:** mimari.md S2, S5, S6 · GDD §12

### US-005 — Etkileşim çerçevesi + kasa + kapı
EP-01 · P1 · M · Sahip: oynanis · Sözleşme: S2, S7 · Bağımlılık: US-004
**Hikâye:** Oyuncu olarak kasaya yaklaşıp basılı tutarak boşaltmak ve kapıları açıp kapatmak istiyorum; arkadaşlarım sonucu aynı anda görmeli.
**Kabul kriterleri:**
- AC1 `Interactable` tabanı (S7) + oyuncunun yakındaki en yakın nesneyi bulması + `interaction_started`/`interaction_finished` sinyalleri.
- AC2 Yazar kasa: basılı tut 3 sn → host ekip nakdine +150 (`data/props.tres`), kasa boş durumuna geçer ve bir daha etkileşilmez; yarıda bırakılırsa ilerleme sıfırlanır. Kasa yalnız tezgâh arkasından (personel tarafı) boşaltılabilir: müşteri tarafından istek menzil içinde olsa da reddedilir (koordinatör kararı 2026-10-01).
- AC3 Kapı: anında aç/kapa; kapalıyken world katmanında engel; durum tüm peer'larda aynı.
- AC4 Yetki: aynı nesneye aynı anda iki oyuncu → yalnız biri (`busy_by`); menzil dışı (tolerans +24 px üstü) istek reddedilir; istemci kendi başına sonuç üretemez.
- AC5 Nesneler `levels/store_a.tscn` → `Props` altına `Register`, `FrontDoor`, `BackDoor` Marker konumlarında yerleştirilir (seviyenin başka kısmına dokunulmaz).
- AC6 Senaryolar `register_empty.json` (istemci boşaltır → tüm peer'larda team_cash 150, kasa boş; sonucun görünme gecikmesi dökümde ölçülür), `door_sync.json`, `contention.json`; 0 ve 150 ms.
- AC7 Birim: `core/interaction_rules.gd` (menzil + tolerans, süre, meşguliyet).
**Dokunulacak:** entities/props/**, core/**, data/props.tres, levels/store_a.tscn (yalnız Props altı), tests/unit/test_interaction*.gd, tests/net/{register_empty,door_sync,contention}.json, tests/net/bots/**, i18n/texts.csv (satır ekleme)
**Dokunulmayacak:** autoload/{net,args,game}.gd, ui/**, project.godot, levels/store_a.tscn'nin Props dışı
**Oku:** mimari.md S2, S7 · GDD §6.3, §12

### IS-005 — Faz 1 çıkış testi + Windows/Linux build
EP-01 · P1 · M · Sahip: altyapi · Bağımlılık: US-003, US-005
**Kabul:** (1) `tests/net/faz1_full.json`: host + 2 istemci store_a'da; biri arka kapıyı açar, biri kasayı boşaltır; tüm peer'larda team_cash 150; 0 ve 150 ms. (2) `tools/soak.sh`: host + 2 bot 10 dk dolaşır, log'da hata/uyarı yok. (3) `export_presets.cfg` (Windows Desktop, Linux) + `tools/export.sh` export şablonlarını indirip `build/`'e iki platform çıktısı üretir; CI `main` push'unda build'leri artifact olarak yükler. (4) README'ye "Arkadaşla internet üzerinden (Tailscale)" ve "Build'i çalıştırma" bölümleri; renderer seçimi (Forward+ / Compatibility) arkadaş makineleri için değerlendirilir. (5) `tools/ci_local.sh` tüm senaryolarla yeşil.
**Dokunulacak:** tests/net/faz1_full.json, tests/net/bots/**, tools/{soak,export}.sh, export_presets.cfg, .github/workflows/**, README.md, tools/ci_local.sh
**Dokunulmayacak:** autoload/**, entities/**, levels/**, ui/**

### IS-006 — Kullanıcı doğrulaması: iki makine + arkadaş oturumu
EP-01 · P1 · S · Sahip: kullanıcı · Bağımlılık: IS-005
**Kabul:** Kullanıcı build'i (ya da editörü) iki pencerede çalıştırıp host/katıl, yürüme ve kasa boşaltmayı dener; bir arkadaşla Tailscale üzerinden bağlanır (≤ 5 sn), 10 dk oynar; his notları GB olarak yazılır. Faz kapanışını engellemez; Engelli(kullanıcı-cihaz) olarak taşınır.

### IS-008 — Seviye renklerini ThemeTokens'a taşı
EP-01 · P2 · XS · Sahip: seviye · Bağımlılık: US-002, US-003
**Kabul:** US-002'de `levels/level_layout.gd` başında duran seviye renk oranları `ThemeTokens`'a `LEVEL_FLOOR, LEVEL_BACKROOM, LEVEL_SIDEWALK, LEVEL_STREET, LEVEL_WALL, LEVEL_WALL_EDGE, LEVEL_GLASS, LEVEL_SHELF, LEVEL_COUNTER` olarak eklenir (ekleme; arayuz'un mevcut token'larına dokunulmaz) ve seviye bunları okur; test_levels yeşil.
**Dokunulacak:** ui/theme/tokens.gd (yalnız ekleme), levels/level_layout.gd, tests/unit/test_levels.gd

### IS-007 — Faz 1 tasarım değerlendirmesi (Fable)
EP-01 · P1 · S · Sahip: tasarim · Bağımlılık: IS-005 (faz kapanışından önce)
**Kabul:** `docs/tasarim/degerlendirmeler/faz-1.md` surec.md §5a biçiminde yazılır (Faz 1 temel yapı olduğu için ağırlık: hareket hızları, etkileşim süreleri, bakkal yerleşimi ve online hissin GDD'ye uyumu; Faz 2-3 için erken uyarılar). Koordinatör önerileri oneriler.md'ye işler. Koordinatör okumasıyla kapanır.

## 3. Sonraki fazların kalemleri (Backlog; faz başında ayrıntılanır)
**Faz 2 — Gizlilik:** (ara tasarım değerlendirmesi: muhafız + şüphe + kaçış oynanabilir olunca; kapanışta tam değerlendirme + ilk yeni özellik önerileri) muhafız durum makinesi + devriye + NavigationRegion2D · görüş konisi + şüphe ölçeri (0-100, eşikler 30/60/100) + oyuncu lehine 0,2 sn · kamera = statik muhafız (aynı algı kodu) · küresel uyarı kademeleri · oyuncu görüş hattı/sis · gürültü v0 (NoiseBus, S8) · görüş: `Window*` şekilleri görüşü geçirir, rafların görüşü kesip kesmeyeceği kararı · tezgâhtar sivil + sindirme · T1 kilit (arka kapı) · ganimet çantası + kaçış bölgesi + iş sonu ekranı (ödeme + derece) · bağlantı kopması (avatar donar) · girdi günlüğü/replay · 5-6 temel SFX · ucuz keşif ön testi (60 sn izle → krokiye ikon) · Steam spike (480 lobisi + davet + SteamMultiplayerPeer, 2 kişi; kullanıcı cihazı) · Faz 2 kullanıcı oyun testi.
**Faz 3 — Keşif ve plan:** (ara değerlendirme: keşif → plan akışı oynanabilir olunca) keşif fazı (müşteri rolü, dış gözlemci, oyalanma şüphesi, yüz tanınma, otomatik işaretleme yok) · plan masası (hazır duvarlı kroki, ikon + rota, ortak gerçek zamanlı) · soygunda plan katmanı · tohum/rastgeleleştirme v0 (kamera konumu, tezgâhtar, polis periyodu) · iş sonu "plan doğruluğu" göstergesi (GDD açık soru 3) · Faz 3 oyun testi.
**Faz 4 — Sığınak ve ikinci kademe:** para + ısı v0 · dükkân (3-4 eşya, yetenek kapısı) · benzinlik şablonu (kamera, DVR, sessiz alarm, sahte kamera) · kayıt (host kampanya + kişisel profil, JSON) · perk ağacı v0 · ton altyapısı iskeleti (ikinci tema yok) · CC0 asset geçişi (assetler.md).
**Faz 5 — Steam ve MVP:** GodotSteam GDExtension 4.22.1'i resmî kaynaktan (codeberg) indirip IS-004 sha256'larıyla doğrulama (bu konteynerde codeberg kapalı: ağ izni ya da kullanıcı indirir) · temiz import'ta GDExtension ilk-yükleme çöküşüne karşı CI'da çift import (altyapi) · S1'e Steam katılım imzası (lobby_id/steam_id) · GodotSteam lobi/davet UI + SteamMultiplayerPeer (ENet yedek) · Steam Cloud profil · Windows/Linux paket · itch gizli build · arkadaş oyun testi turu · KR-013 ad, KR-014 Steamworks.

## 4. Fikir havuzu
İkinci ton (retro/neon, absürt) · 3D geçişi (Faz 5 sonrası değerlendirme) · çatışma genişletmesi (koridor tutma ötesi) · bot yoldaş · kılık/sosyal mühendislik rolü · insider pazarı · günlük tohum + lider tablosu.
