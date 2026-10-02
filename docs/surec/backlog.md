# Backlog

## 0. Süreç özeti
Durumlar: Backlog → Hazır → Sürüyor → Denetimde → Bitti; Engelli (KR / kullanıcı-cihaz / dış); Elendi. Öncelik P1 (bu faz) / P2 (fırsat) / P3 (sonraki faz). Büyüklük XS/S/M. Yalnız koordinatör yazar. Kalem Hazır olmadan (DoR tam, sözleşme mimari.md'de) ajana verilmez. Aktif paket ≤ 3, ajan başına 1, dosya kümeleri ayrık; paralel paket worktree'de. Ayrıntı: surec.md. Sözleşmeler: mimari.md S1-S9. Tasarım: docs/tasarim/oyun-tasarimi.md.

## 1. Fazlar (MVP yol haritası; her faz sonu durma noktası)
Faz planı Fable (tasarim) incelemesiyle düzeltildi (KR-015).

| EP | Faz | Hedef | Çıkış kriterleri (ölçülebilir) | Durum |
|---|---|---|---|---|
| EP-00 | Faz 0 — Kurulum | Süreç, tasarım, Godot iskeleti, test ve CI hazır; Steam riski erken ölçülmüş | 1) `tools/ci_local.sh` boş projede yeşil, 1 geçen birim testle < 5 dk · 2) import uyarı-hatasız · 3) GodotSteam GDExtension'ın 4.7.2'de yüklenip yüklenmediği biliniyor (IS-004) · 4) GDD v0.1 ve mimari sözleşmeler yazılı | Bitti (2026-10-01; uzak CI ilk koşusu repo açılınca) |
| EP-01 | Faz 1 — İki kişi bakkalda | Online his: bağlan, yürü, kasayı boşalt | 1) Tüm ağ senaryoları 0 ve 150 ms RTT'de yeşil · 2) 150 ms'de hareket sırasında senkron hatası < 1 karo (32 px) · 3) Kasa boşaltma sonucu tüm peer'larda RTT + 200 ms içinde · 4) 10 dk headless dayanıklılık koşusunda hata logu yok · 5) Windows + Linux build'i üretiliyor · 6) Kullanıcı doğrulaması: iki makine (Tailscale) ≤ 5 sn'de bağlanıyor, bir arkadaş oturumu notlandı (IS-006; fazı engellemez, taşınır) | Sürüyor (2026-10-01) |
| EP-02 | Faz 2 — Gizlilik (bakkal, KR-020/021) | 2-3 kişi bakkal soygununu baştan sona oynar (ilk "eğlenceli mi" kapısı) | 1) Algı: kasa tutarken sahip yakın ≤ 1,0 sn, uzak ≤ 1,8 sn "!"; müşteri bölgesinde yürüyen 60 sn hiç; raf arkası hiç; "?" her tespitten ≥ 0,5 sn önce · 2) 300 sn ajandada ≥ 4 kasa penceresi (≥ 10 sn); botla temiz ≥ %30, yakalanma ≤ %70 (3 kişi, 200 koşu) · 3) Zincir görünür (? → sorgu → bağırış → mahalleli → polis sayacı); kazanma (temiz, bağırışlı) ve kaybetme (polis, herkes yakalandı) yolları + iş sonu ödeme · 4) 150 ms'de 20 dk tutarsızlık 0, NPC ≤ 6, `net_flag` 0 · 5) İnsan testi: 3 arkadaş ≥ 3 koşu, ≥ 2 oturumda kendiliğinden "bir daha", koşu başına ≥ 1 klip anı, ölü zaman ≤ %15, 2 kişilik ≥ 1 koşu | Sürüyor (erken; 2026-10-02) |
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
| US-001 | Ağ çekirdeği ve oturum | 1 | cekirdek | P1 | M | IS-003 | Bitti | bc49aef |
| US-002 | Bakkal seviyesi v0 + test arenası | 1 | seviye | P1 | S | IS-003 | Bitti | d8ab983 |
| US-003 | Ana menü, HUD iskeleti, tema ve metin altyapısı | 1 | arayuz | P1 | M | IS-003 | Bitti | 7b34286 |
| IS-011 | Windows'ta yerel geliştirme: net_smoke süreç yönetimi (killpg yerine Windows eşdeğeri) ve get_godot Windows dalı ya da WSL kılavuzu | 1 | altyapi | P1 | S | — | Bitti | 8124e82 |
| IS-010 | OOP/genişletilebilirlik (A) uygulaması: Level API, slot, bağımlılık yönü | 1 | cekirdek | P1 | S | US-001 | Bitti | f6bd55c |
| US-004 | Oyuncu karakteri ve senkron hareket | 1 | oynanis | P1 | M | US-001, US-002, IS-010 | Bitti | a88d9c1 |
| US-005 | Etkileşim çerçevesi + kasa + kapı | 1 | oynanis | P1 | M | US-004 | Bitti | e32adf7 |
| IS-012 | Gecikme proxy testinin Windows'ta yük altında kararsızlığı (test_multiple_clients_get_own_replies 56 vs 40±15 ms) | 1 | altyapi | P1 | XS | IS-011 | Bitti | 918d0cd |
| IS-005 | Faz 1 build: Windows/Linux export, CI artifact, README, IS-010 test nit'leri | 1 | altyapi | P1 | S | US-005 | Bitti | 9594144 |
| IS-013 | Faz 1 çıkış senaryoları: faz1_full, sert ağ profili, 10 dk dayanıklılık, gerçek oyuncuyla geç katılma | 1 | cekirdek | P1 | M | US-005 | Bitti | afe5b6b |
| IS-019 | Renderer: Compatibility (GL 3.3) — arkadaş makinelerinde geniş donanım (IS-005 kararı) | 1 | altyapi | P2 | XS | IS-005 | Bitti | b985e8b |
| IS-014 | US-005 nit'leri: koşuda taraf toleransı, kapı oyuncu üstüne kapanmaz, uzak oyuncu etkileşim göstergesi, testlerde özel üye erişimi | 1 | oynanis | P2 | S | US-005 | Bitti | 0d215b5 |
| IS-006 | Kullanıcı doğrulaması: iki makine + arkadaş oturumu | 1 | kullanıcı | P1 | S | IS-005, IS-013 | Backlog | |
| IS-007 | Faz 1 tasarım değerlendirmesi (Fable) | 1 | tasarim | P1 | S | (A) — · (B) IS-005, IS-013 | Bitti (A: a30c69c; B: degerlendirmeler/faz-1.md, ON-01..09) | |
| IS-027 | Test-1 görünüm cilası: kamera yakınlaştırma 1,5 (ayarlanabilir) + harita sınırına kenetleme, arka plan BG token'ı (ON-01, ON-07) | 1 | oynanis | P1 | XS | — | Bitti | e99319b |
| IS-008 | Seviye renklerini ThemeTokens'a taşı (LEVEL_* token'ları) | 1 | seviye | P2 | XS | US-002, US-003 | Bitti | f0f027f |
| IS-009 | Girdi haritası (`pause`, ui gamepad) + US-003 nit'leri | 1 | arayuz | P1 | S | US-003 | Bitti | 332fb08 |

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
- AC3 `PlayerInput`: klavye/gamepad (S5) ve bot zaman çizelgesi (S6); yalnız yerel oyuncuda girdi okunur; `UiInput.is_gameplay_input_blocked()` true iken oyun girdisi okunmaz (duraklat menüsü açıkken karakter yürümez).
- AC4 Ağ: istemci yetkili konum/yön/kip senkronu 20 Hz; uzak kopyalar ara değerleme (~100 ms tampon) ile çizilir.
- AC5 `tests/net/store_walk.json`: store_a'da host + 2 istemci bot rotası yürür; hareket sırasında örneklenen konum farkı host↔istemci < 32 px, istemci↔istemci < 48 px (iki bacak; KR günlüğü US-004), son konum farkı < 8 px, kimse duvar içinde değil; 0 ve 150 ms.
- AC6 Birim testler: ayar okuma, kipe göre hız, bot zaman çizelgesi ayrıştırma.
**Dokunulacak:** entities/player/**, data/player_tuning.tres, tests/unit/test_player*.gd, tests/net/store_walk.json, tests/net/bots/**
**Dokunulmayacak:** autoload/{net,args,game}.gd, levels/**, ui/**, project.godot
**Oku:** mimari.md S2, S5, S6 · GDD §12

### US-005 — Etkileşim çerçevesi + kasa + kapı
EP-01 · P1 · M · Sahip: oynanis · Sözleşme: S2, S7 · Bağımlılık: US-004
**Hikâye:** Oyuncu olarak kasaya yaklaşıp basılı tutarak boşaltmak ve kapıları açıp kapatmak istiyorum; arkadaşlarım sonucu aynı anda görmeli.
**Kabul kriterleri:**
- AC1 `Interactable` **bileşeni** (S7 bileşen modeli, KR-018: Area2D alt düğüm, `requirement`, `completed`/`cancelled` sinyalleri) + `InteractionRequirement` Resource + oyuncunun yakındaki en yakın uygun bileşeni bulması + `interaction_target_changed`/`interaction_started`/`interaction_finished` sinyalleri (HUD istemi ve ilerleme çubuğu bunlarla çalışır).
- AC2 Yazar kasa: basılı tut 3 sn → host ekip nakdine +150 (`data/props/register.tres`, S10 `PropDef`), kasa boş durumuna geçer ve bir daha etkileşilmez; yarıda bırakılırsa ilerleme sıfırlanır. Kasa yalnız tezgâh arkasından (personel tarafı) boşaltılabilir: müşteri tarafından istek menzil içinde olsa da reddedilir (koordinatör kararı 2026-10-01).
- AC3 Kapı: anında aç/kapa; kapalıyken world katmanında engel; durum tüm peer'larda aynı.
- AC4 Yetki: aynı nesneye aynı anda iki oyuncu → yalnız biri (`busy_by`); menzil dışı (tolerans +24 px üstü) istek reddedilir; istemci kendi başına sonuç üretemez.
- AC5 Nesneler `levels/store_a.tscn` → `Props` altına `Register`, `FrontDoor`, `BackDoor` Marker konumlarında yerleştirilir (seviyenin başka kısmına dokunulmaz).
- AC6 Senaryolar `register_empty.json` (istemci boşaltır → tüm peer'larda team_cash 150, kasa boş; sonucun görünme gecikmesi dökümde ölçülür), `door_sync.json`, `contention.json`; 0 ve 150 ms.
- AC7 Birim: `core/interaction_rules.gd` (menzil + tolerans, süre, meşguliyet).
**Dokunulacak:** entities/props/**, entities/player/** (yalnız S7 oyuncu tarafı: hedef bulma, `interact` isteği, oyuncu sinyalleri; US-004 hareket/senkron davranışı değişmez), core/**, data/props/**, levels/store_a.tscn (yalnız Props altı), tests/unit/test_interaction*.gd, tests/net/{register_empty,door_sync,contention}.json, tests/net/bots/**, i18n/texts.csv (satır ekleme)
**Dokunulmayacak:** autoload/{net,args,game}.gd, ui/**, project.godot, levels/store_a.tscn'nin Props dışı
**Oku:** mimari.md S2, S7 · GDD §6.3, §12

### IS-005 — Faz 1 build: Windows/Linux export, CI artifact, README
EP-01 · P1 · S · Sahip: altyapi · Bağımlılık: US-005 (IS-012 ile paralel; dosya kümeleri ayrık) · Çıkış kriteri 5
Not (2026-10-02): eski IS-005'in ağ senaryoları ve dayanıklılık kısmı IS-013'e (cekirdek) bölündü; bu kart build ve teslim kısmıdır.
**Kabul:** (1) `export_presets.cfg` (Windows Desktop, Linux) + `tools/export.sh`: export şablonlarını (4.7.2, SHA doğrulamalı) indirip `build/`'e iki platform çıktısı üretir; Windows'ta (Git Bash) ve Linux'ta çalışır; üretilen Windows build'i headless `--quit-after` ile açılıp kapanır. (2) CI: `main` push'unda iki platform build'i artifact olarak yüklenir (dev push'unda yalnız ci_local adımları). (3) IS-010 denetci nit'leri: S4 Level API imzaları (tipleriyle) test_smoke CONTRACTS'a; test_deps `uid://` ile ui başvurusunu da yakalar. (4) README'ye "Arkadaşla internet üzerinden (Tailscale)" ve "Build'i çalıştırma" bölümleri; renderer seçimi (Forward+ / Compatibility) arkadaş makineleri için değerlendirilir, karar raporda "Karar gereken". (5) `tools/ci_local.sh` tam yeşil.
**Dokunulacak:** export_presets.cfg, tools/export.sh, .github/workflows/**, README.md, tools/ci_local.sh (yalnız gerekirse), tests/unit/test_smoke.gd, tests/unit/test_deps*.gd, .gitignore
**Dokunulmayacak:** autoload/**, entities/**, levels/**, ui/**, core/**, tests/net/**, tools/{net_smoke,latency_proxy}.py

### IS-013 — Faz 1 çıkış senaryoları (tam soygun, sert ağ, dayanıklılık, geç katılma)
EP-01 · P1 · M · Sahip: cekirdek · Sözleşme: S2, S6, S7 · Bağımlılık: US-005 · Çıkış kriterleri 1-4
**Kabul:** (1) `tests/net/faz1_full.json`: store_a'da host + 2 istemci gerçek oyuncu sahnesiyle; biri arka kapıyı açar, biri kasayı tezgâh arkasından boşaltır; tüm peer'larda team_cash 150, kasa boş, kapı durumu eşit; kasa sonucunun her peer'da görünme gecikmesi ≤ RTT + 200 ms beklentiyle ölçülür (çıkış kriteri 3); hareket sırasında senkron farkı < 32 px (kriter 2); 0 ve 150 ms. (2) GDD §12 "sert ağ" profili (150 ms + 30 ms jitter + %1 kayıp) `store_walk` ve `faz1_full` için koşulur ve geçer (ci_local'ın varsayılan net adımına girmesi zorunlu değil; ayrı komut + raporda sonuç; kararsızsa "Karar gereken"). (3) `tools/soak.sh` (bash, Windows Git Bash + Linux): host + 2 bot 10 dk store_a'da dolaşır, kasa/kapı etkileşir; log'da ERROR/WARNING yok, süreçler temiz kapanır, bellek/oyuncu sayısı kararlı (dökümle); `--minutes N` ile kısa koşu. (4) Gerçek oyuncu sahnesiyle geç katılma senaryosu: geç gelen istemci diğer oyuncuları doğru konumda görür (tampon boşken konuma dokunulmaz) ve değişmiş prop durumunu (boş kasa, çevrilmiş kapı) alır; 0 ve 150 ms. (5) IS-011 nit'i: net_smoke `known` ara düğümün şimdiki oluşturma zamanı kayıttan farklıysa çocukları aranmaz (+ test). (6) Mevcut senaryolar ve `tools/ci_local.sh` tam yeşil.
**Dokunulacak:** tests/net/{faz1_full,late_join_real}.json (ad serbest), tests/net/bots/**, tools/soak.sh, tools/net_smoke.py, tools/test_net_smoke.py, tests/fixtures/** (yalnız gerekirse)
**Dokunulmayacak:** autoload/**, entities/**, core/**, levels/**, ui/**, project.godot, tools/{latency_proxy,test_latency_proxy}.py (paralel IS-012), tools/ci_local.sh, .github/**
**Oku:** mimari.md S2, S6, S7 · GDD §12

### IS-019 — Renderer: Compatibility
EP-01 · P2 · XS · Sahip: altyapi · Bağımlılık: IS-005
**Kabul:** (1) project.godot `rendering/renderer/rendering_method` (ve mobil karşılığı) `gl_compatibility`; Forward+'a özgü ayar kalmaz. (2) test_smoke renderer beklentisi. (3) İçe aktarma temiz, ci_local ve `tools/export.sh` (Windows build + smoke) yeşil. (4) Kullanıcı doğrulaması IS-006'ya eklenir: build arkadaş makinesinde açılıyor, görüntü bozulmuyor. Gerekçe: projede Forward+'a özgü özellik yok; Compatibility 2D ışık/gölgeyi destekler (GDD §14 "sanatı ışık yapar" kapanmaz); Faz 4'te ışık efektleri istenirse yeniden değerlendirilir.
**Dokunulacak:** project.godot (yalnız renderer), tests/unit/test_smoke.gd
**Dokunulmayacak:** autoload/**, entities/**, levels/**, ui/**, core/**, tools/**

### IS-027 — Test-1 görünüm cilası
EP-01 · P1 · XS · Sahip: oynanis (main.gd'de yalnız temizleme rengi için cekirdek alanına istisna) · Bağımlılık: — · Fable Faz 1 değerlendirmesi ON-01, ON-07
**Kabul:** (1) Yerel oyuncu kamerası yakınlaştırması `data/player_tuning.tres` `camera_zoom` = 1,5 (ayarlanabilir; geliştirici argümanı `--camera-zoom=X` ile test-1'de 1,0/1,5 karşılaştırılabilir — Args'ta yalnız bu argüman). (2) Kamera `Level` sınırlarına (S4 API'sinde yoksa ekle: oynanabilir alan dikdörtgeni; harita kenarı dolgusu dahil) `limit_*` ile kenetlenir; harita ekrandan küçükse ortalanır; gri boşluk yok. (3) Viewport temizleme rengi ThemeTokens BG (noir `bg_color`); test. (4) US-004/US-005 senaryoları ve ci_local yeşil; ekran görüntüsü kanıtı (GUI exe ile pencereli kısa koşu ya da IS-022 aracı varsa) 1,0 ve 1,5 için.
**Dokunulacak:** entities/player/player.gd ve player.tscn (yalnız kamera), data/player_tuning.tres, levels/level.gd (yalnız sınır API'si; S4 eki), autoload/args.gd (yalnız `--camera-zoom`), main.gd (yalnız temizleme rengi), tests/unit/test_player*.gd, tests/unit/test_levels_api.gd
**Dokunulmayacak:** ui/**, core/**, entities/props/**, levels/*.tscn ve layouts, tools/**, project.godot

### IS-014 — US-005 nit'leri
EP-01 · P2 · S · Sahip: oynanis · Sözleşme: S2, S7 · Bağımlılık: US-005
**Kabul:** (1) Koşuda taraf toleransı: host koşan oyuncuyu ~22 px geriden görür → `SIDE_TOLERANCE` koşu hızını da karşılar (ör. 24 px) ya da hıza bağlı; müşteri tarafı hâlâ red (birim test, en yakın müşteri konumu −26 px). (2) Kapı, kapı boşluğunda gövdesi olan bir oyuncu varken kapanmaz (host reddi `blocked`, istemcide istem yine görünür; birim + mevcut senaryolar yeşil); açma her zaman serbest. (3) Uzak oyuncunun "etkileşimde" göstergesi diğer peer'larda da çizilir (çoğaltılan küçük durum; ThemeTokens rengi). (4) `test_interaction_props.gd` özel üyelere (`_host_start`, `_host_cancel`, `_physics_process`) erişmez; genel API ya da test kancası (KR-018 §6). (5) ci_local tam yeşil; US-004/US-005 senaryoları geçer.
**Dokunulacak:** core/interaction_rules.gd, entities/props/**, entities/player/** (yalnız etkileşim göstergesi), tests/unit/test_interaction*.gd, tests/net/{register_empty,door_sync,contention}.json (yalnız beklenti uyarlaması)
**Dokunulmayacak:** autoload/**, ui/**, levels/**, project.godot, tools/**, tests/net/faz1_full.json ve IS-013 dosyaları

### IS-006 — Kullanıcı doğrulaması: iki makine + arkadaş oturumu
EP-01 · P1 · S · Sahip: kullanıcı · Bağımlılık: IS-005
**Kabul:** Kullanıcı build'i (ya da editörü) iki pencerede çalıştırıp host/katıl, yürüme ve kasa boşaltmayı dener (US-004: hareket hissi, koşu halkası/sızma dolgusu, ad etiketi okunurluğu, kamera yalnız kendi karakterinde, Esc menüsü açıkken yürümeme, gamepad kısmi hız; 120/144 Hz ekranda yerel oyuncuda takılma var mı — varsa `physics_interpolation` kararı; IS-019: build arkadaş makinesinde açılıyor mu, görüntü bozuk mu — özellikle eski/tümleşik GPU'da OpenGL 3.3; IS-005: Linux paketi gerçek Linux'ta `./Insiders.x86_64` ile açılıyor mu, Windows'ta SmartScreen/güvenlik duvarı uyarıları); bir arkadaşla Tailscale üzerinden bağlanır (≤ 5 sn), 10 dk oynar; his notları GB olarak yazılır. Faz kapanışını engellemez; Engelli(kullanıcı-cihaz) olarak taşınır.

### IS-008 — Seviye renklerini ThemeTokens'a taşı
EP-01 · P2 · XS · Sahip: seviye · Bağımlılık: US-002, US-003
**Kabul:** US-002'de `levels/level_layout.gd` başında duran seviye renk oranları `ThemeTokens`'a `LEVEL_FLOOR, LEVEL_BACKROOM, LEVEL_SIDEWALK, LEVEL_STREET, LEVEL_WALL, LEVEL_WALL_EDGE, LEVEL_GLASS, LEVEL_SHELF, LEVEL_COUNTER` olarak eklenir (ekleme; arayuz'un mevcut token'larına dokunulmaz) ve seviye bunları okur; test_levels yeşil.
**Dokunulacak:** ui/theme/tokens.gd (yalnız ekleme), levels/level_layout.gd, tests/unit/test_levels.gd

### IS-010 — OOP/genişletilebilirlik (A) uygulaması
EP-01 · P1 · S · Sahip: cekirdek (seviye ve arayüz dosyalarında yalnız aşağıdaki değişiklikler için istisna) · Sözleşme: S3, S4, §6 (KR-018) · Bağımlılık: US-001
**Kabul:** (1) `levels/level.gd` (`class_name Level`, S4 API'si) yazılır; `build_levels.gd` üretilen sahnelerin köküne bu betiği atar; `store_a`/`test_arena` ve test fikstür seviyeleri yeniden üretilir/güncellenir. (2) `game.gd` ve `main.gd` seviye düğümlerine yalnız Level API'siyle erişir (dize yol gezintisi yok; ör. eski game.gd:639/661, main.gd:175). (3) S3 `players()` sözlüğü `{"name", "slot"}` taşır, `game.gd` `ThemeTokens`'ı içe almaz; HUD oyuncu listesi rengi `ThemeTokens.PLAYER_COLORS[slot]` ile eşler. (4) Bağımlılık yönü testi: `core/` ve `autoload/` altındaki betiklerin `ui/` sınıf/yollarına başvurmadığını (Game'in HUD `load()` istisnası hariç) tarayan birim test. (5) ci_local yeşil, tüm ağ senaryoları 0/150 ms geçer.
**Dokunulacak:** autoload/game.gd, main.gd, levels/level.gd (yeni), levels/tools/build_levels.gd (yalnız kök betik ataması), levels/*.tscn (yeniden üretim), tests/fixtures/** (seviye fikstürleri), ui/hud.gd ve ilgili ui testi/sahtesi (yalnız slot→renk), tests/unit/test_{game,levels,deps}*.gd
**Dokunulmayacak:** project.godot, autoload/net.gd, ui/theme/**, levels/layouts/**

### IS-009 — Girdi haritası (pause, ui gamepad) + US-003 nit'leri
EP-01 · P1 · S · Sahip: arayuz (project.godot'ta yalnız bu iki girdi değişikliği için altyapi alanına istisna) · Bağımlılık: US-003
**Kabul:** (1) project.godot'a `pause` eylemi (Esc + gamepad Start) ve `ui_accept` (+A), `ui_cancel` (+B) gamepad olayları eklenir (S5); `test_smoke` bunları denetler; `UiInput.ensure_gamepad_ui()` geçici çözümü kaldırılır, duraklatma `pause` eylemini okur. (2) Denetci nit'leri: anahtarı olmayan oturum olayında ham `kind` yerine genel metin + push_warning (`hud.gd`); host'ta `start_level` başarısız olursa menü STARTING'de takılı kalmaz (zaman aşımı/vazgeç); HUD `Net.connection_failed`'i dinler ve el sıkışma sırasında seviye yüklenmişken bağlantı düşerse `MENU_ERROR_CONNECTION_FAILED` ile menüye döner; beklenen push_warning birim test çıktısında WARNING satırı basmaz. (3) ci_local yeşil.
**Dokunulacak:** project.godot (yalnız girdi), tests/unit/test_smoke.gd, ui/**, i18n/texts.csv, tests/unit/test_ui_*.gd
**Dokunulmayacak:** autoload/**, main.*, levels/**, ui/theme/tokens.gd (paralel IS-008)

### IS-011 — Windows'ta yerel geliştirme
EP-01 · P1 · S · Sahip: altyapi (net_smoke/latency_proxy'de yalnız Windows uyumu için cekirdek alanına istisna) · Bağımlılık: —
**Ölçüm (koordinatör, 2026-10-02; Windows 11, Git Bash, Python 3.13, `GODOT`=win64 console exe):** godot/import/unit yeşil (131 test); 8 ağ senaryosu `python` ile 0 ve 150 ms'de geçti; `ci_local.sh net` düşer (`python3` yok); `test_latency_proxy.py` 3 FAIL: ölçülen gecikme +20-25 ms (Windows zamanlayıcı çözünürlüğü), `test_command_line` terminate sonrası çıkış 1.
**Kabul:** (1) `ci_local.sh` Python yorumlayıcısını bulur (`python3` → `python` → `py -3`, ≥ 3.10 denetimi); Linux'ta davranış değişmez. (2) `net_smoke.py` Windows'ta süreç ağacını öldürür (POSIX yolu aynen; Windows: yeni süreç grubu + CTRL_BREAK, ardından zorla öldürme; t2: pid yeniden kullanımına karşı oluşturma zamanı süzgeci, `/T` yok); zaman aşımı yolu bir testle gösterilir. (3) `latency_proxy` Windows'ta testlerin mevcut toleransını (±15 ms) tutturur: tolerans gevşetilmez, zamanlama düzeltilir (ör. `timeBeginPeriod(1)` ya da bekleme yöntemi); `test_command_line` Windows'ta zarif kapanışla 0 döner. (4) `tools/test_latency_proxy.py` ci_local'a ayrı adım olarak eklenir (IS-005 (4)'ten taşındı); ci.yml ci_local'ı koştuğu için uyum korunur. (5) `get_godot.sh` Windows (MINGW/MSYS) dalı: 4.7.2 win64 zip'ini indirir, resmi SHA512-SUMS değeriyle doğrular, console exe'yi `.tools/` altına koyar. (6) README'ye "Windows'ta geliştirme" bölümü (Git Bash, Python, `GODOT` ya da get_godot). (7) `tools/ci_local.sh` Windows'ta (Git Bash) tam yeşil; Linux yeşili push sonrası uzak CI ile.
**Dokunulacak:** tools/{ci_local,get_godot}.sh, tools/{net_smoke,latency_proxy,test_latency_proxy}.py, README.md, .github/workflows/ci.yml (yalnız gerekirse)
**Dokunulmayacak:** autoload/**, entities/**, levels/**, ui/**, tests/**, project.godot, docs/**

### IS-012 — Gecikme proxy testinin Windows kararsızlığı
EP-01 · P1 · XS · Sahip: altyapi (latency_proxy'de yalnız zamanlama için cekirdek alanına istisna) · Bağımlılık: IS-011
**Kabul:** (1) `tools/test_latency_proxy.py::test_multiple_clients_get_own_replies` Windows'ta yük altında (ör. paralel Godot/ağ senaryosu koşarken) da kararlı: 20 ardışık koşuda 0 hata; tolerans (±15 ms) gevşetilmez — kök neden (zamanlayıcı, iş parçacığı uyanması, ölçüm yöntemi) bulunur ve düzeltilir ya da ölçüm yükten bağımsız hale getirilir (ör. proxy'nin kendi zaman damgalarıyla). (2) Diğer proxy testleri ve 150 ms ağ senaryoları yeşil. (3) `tools/ci_local.sh` tam yeşil (Windows).
**Dokunulacak:** tools/{latency_proxy,test_latency_proxy}.py
**Dokunulmayacak:** tools/net_smoke.py, tests/**, autoload/**, entities/**, docs/**

### IS-007 — Faz 1 tasarım değerlendirmesi (Fable)
EP-01 · P1 · S · Sahip: tasarim · Bağımlılık: (A) yok · (B) IS-005, IS-013 (faz kapanışından önce)
İki adım (2026-10-02): **(A)** KR-017 → GDD §14 ve GB-02 → GDD §7/§9/§10 işlenir + Faz 2 kapsam önerisi (koordinatöre rapor; faz plan mesajına girdi). **(B)** `faz-1.md` değerlendirmesi IS-005/IS-013 sonuçlarıyla.
**Kabul:** KR-017 animasyon/karakter stilini GDD §14'e (referans ilkeler, zamanlama aralıkları, okunabilirlik kuralları) ve GB-02'yi (havalandırma girişi, duvar patlatma, alttan kasa düşürme; ileri kademe + ekipman/yetenek kapılı) GDD §7/§9/§10'a işler: hangi kademede açıldığı, gereken ekipman/perk, gürültü ve zamanlama bedeli, keşifte nasıl fark edildiği. `docs/tasarim/degerlendirmeler/faz-1.md` surec.md §5a biçiminde yazılır (Faz 1 temel yapı olduğu için ağırlık: hareket hızları, etkileşim süreleri, bakkal yerleşimi ve online hissin GDD'ye uyumu; Faz 2-3 için erken uyarılar). Koordinatör önerileri oneriler.md'ye işler. Koordinatör okumasıyla kapanır.

## 2b. Faz 2 kalemleri (EP-02 — Gizlilik, bakkal; plan 2026-10-02, KR-019/020/021)
Tam kart metinleri (hikâye, AC, Dokunulacak/Dokunulmayacak): US-008 → `docs/tasarim/arastirma/faz2-bakkal-kalemleri.md` §2 · US-016 → §3 · US-010 → §4 · IS-023 → §5 (taslakta "IS-022" yazılı) · US-009/US-011/US-012/US-013/IS-015 AC değişiklikleri → §6. Kartlar GDD v0.3 §6.1, §9.1-9.3'e dayanır.
**2a çirkin dilim** (sıra): US-006 → US-007 → IS-023 → US-008 → US-009 → US-010 → US-012 → US-016 → US-013 asgari → SFX → IS-017a oyun testi. **Tasarım dalgası eki (2026-10-02, Fable: sanat-yonu, oyun-hissi, rahatlik-ux, ekip-iletisimi, mekan-estetigi):** 2a'ya (test-2 öncesi) US-021 his turu, US-022 kamera dili, US-025 ayarlar v0, US-028 tut/geçiş, US-030 tuş simgeleri, US-033 keseler, IS-033 ses bağlama, US-027 hatalar; US-026 bağlantı kolaylığı test-1'e; geri kalanı 2b. Faz 3-4 tasarımları: t2-benzinlik.md, ekonomi-kefalet.md, plan-masasi-ui.md (kalem taslakları orada; faz başında açılır). **2b:** US-011, US-014 (NPC başlıkları), IS-015, US-015, raf değerlileri. Faz 2 kod kalemleri `faz2-int` entegrasyon dalında birleşir; Faz 1 checkpoint'inden sonra dev'e.

| ID | Başlık | EP | Sahip | Öncelik | Büyüklük | Bağımlılık | Durum | Commit |
|---|---|---|---|---|---|---|---|---|
| US-006 | Algı çekirdeği: koni + görüş hattı + şüphe (core) + Perception/Suspicion bileşenleri | 2 | oynanis | P1 | M | US-005 | Bitti (faz2-int) | 6e3f782 |
| US-007 | Bakkal v1: navigasyon, see_through camlar, kaçış bölgesi, polis rotası, tezgâhtar noktası | 2 | seviye | P1 | S | US-002 | Bitti (dal `faz2/US-007`, Faz 1 checkpoint'inden sonra dev'e) | 3280e78 |
| IS-023 | Bakkal v1 nüfus işaretleri: StreetRoute (PolicePatrol yerine), NeighbourSpawn, WindowLook, ShopSpot, QueueSpot, RestockSpot, PhoneSpot, BackroomSpot, ShelfProp; CustomerArea/StaffArea/Backroom bölgeleri | 2 | seviye | P1 | XS | US-007 | Bitti (faz2-int) | ce9cfc2 |
| US-008 | Bakkal sahibi v0: Agenda + sivil çarpan + sorgu/bağırış/tutma + ÇEK kurtarma + mahalleli (chaser) + polis sayacı | 2 | oynanis | P1 | M | US-006, US-007, IS-023 | Denetim sırasında (2026-10-02; yapım bitti, ci yeşil) | |
| US-009 | Gürültü v0: NoiseBus + noise_profile.tres + Hearing (sinyal) + görsel halka; kilit IS-021 sonrası | 2 | oynanis | P1 | S | US-005 | Bitti (faz2-int 3adb01d) | |
| US-010 | Bakkal etkileşimleri: SATIN AL, OYALA, ARKA ODAYA GÖNDER, DİKKAT DAĞIT, oyalanma sayacı (teknik/oyun-yz.md tur 2 #14-#15: sahip kesme API'si LOOK/QUESTION'da da, peer'lı `start_blocker`, NPC olay kanalı genişlemesi, `loiter_s` dökümü + dükkândan çıkışta sıfırlama; Fable kararları KR-026: DİKKAT DAĞIT raf devirme yarıçapı 320 px — AC: ShelfProp1..3'ten sahip ClerkSpot'tayken ≤ 1 sn'de DİNLE, yönü prop; BackroomSpot/PhoneSpot'tan geçmez; kasa penceresi ≥ 10 sn; tezgâh E = SATIN AL, Q (`intimidate`, gamepad X) = GÖNDER, istem iki satır, GÖNDER kullanılınca Q satırı gizli, sahip bağırmışsa ikisi gizli) | 2 | oynanis | P1 | M | US-008, IS-023 | Backlog | |
| US-012 | Soygun sonucu: outcome (clean/shouted/hot/caught_all/police), ödeme oranı, çanta, kaçış, held ≠ caught (US-008 olaylarına sahte sinyallerle; bağlama birleşmede) | 2 | oynanis | P1 | S | US-008 | Sürüyor (t2; HEAT_HOT, by argümanı, çanta ağ testi, §6 bağımlılık) | |
| US-016 | Mekân nüfusu v0: müşteri akışı + yoldan geçenler (tanık, örtü, chaser'a dönüşüm) — Agenda lineer rota kipi + `core/spot_registry.gd` (claim/release) + `population.gd` üretici + örtü çarpanı (Context'e müşteri sayısı) + `population.json` (oyun-yz tur 2 #12-#13, #20) | 2 | oynanis | P1 | M | US-008, IS-023 | Backlog | |
| US-013 | İş sonu ekranı + uyarı merdiveni HUD (asgari 2a; S3 heist_finished sözleşmesine karşı, sahte Game ile) | 2 | arayuz | P1 | S | — (sözleşme S3 eki) | Bitti (faz2-int) | c8c699f |
| IS-024 | 2a SFX: yer tutucu sesler (CC0 indirme, kullanıcı izni) + ses kataloğu + SfxEmitter; kapı/kasa/UI bağlı, sahip/adım anahtarları US-008/US-009'a | 2 | arayuz | P1 | S | — | Bitti (2026-10-02; faz2-int e6cf397; birleştirme sonrası sızıntı düzeltmesi sürüyor) | |
| IS-030 | Yer tutucu seslerin üretilmiş (AI) seslerle değiştirilmesi + Türkçe bakkal/mahalleli ses satırları (kullanıcı kaydı ya da üretim; `tools/sfx_gen.py` + `data/sfx_prompts.csv`, ev kaydı rehberi −18 LUFS, Piper fahrettin/fettah CC0 yalnız yer tutucu; ses tur 2); assetler.md + Steam AI bildirimi işaretleri | 4 | arayuz | P2 | S | IS-024 | Backlog (kullanıcı notu) | |
| IS-017 | Faz 2a oyun testi (2-3 kişi; kullanıcı + arkadaşlar; test-2 checkpoint) | 2 | kullanıcı | P1 | S | 2a kalemleri | Backlog | |
| US-011a | Görüş: VisionGrid (core, düğümsüz) + sis katmanı (üç ton) + görüş ayarları — gorus-sis-hafiza.md §6 AC1, AC2, AC9, AC10 (seviye payı) | 2 | seviye | P1 | M | US-006 | Bitti (2026-10-02; faz2-int f1d6aff + 1f9353d) | |
| US-011b | Görüş: bakış yönü (fare/sağ çubuk, look_dir 20 Hz), NPC görünürlük kapısı + hayalet + çevresel siluet, kukla baş/göz, noise_ring çizim koşulu, Game.player_exposure/vision_mode — §6 AC3, AC4, AC6 (Game), AC7 | 2 | oynanis | P1 | M | US-011a, US-008, US-014, US-009 | Backlog | |
| US-011c | Görüş: HUD maruziyet rozeti, görüldü ikonu, ekip kenar oku, lobi "Görüş" seçimi, i18n (FOG token'ları US-011a'da) — §6 AC5 (UI), AC6 (UI) | 2 | arayuz | P1 | S | — (FakeGame) | Bitti (2026-10-02; faz2-int 949cc00) | |
| US-011d | Görüş: look_* girdi eylemleri (project.godot), --vision-mode= argümanı | 2 | altyapi | P1 | XS | — | Bitti (2026-10-02; faz2-int f59fbfe) | |
| IS-029 | Test hijyeni: birim koşu sonu "9 ObjectDB leaked / 2 resources" uyarısının kök nedeni + ci_local kapısı | 1 | altyapi | P2 | S | — | Bitti (2026-10-02; dev 330fd37) | |
| IS-028 | Görüş A/B senaryosu + görsel kanıt (vision_split.json, iki kip × 0/150 ms, screenshot) — §6 AC7/AC8 | 2 | cekirdek | P1 | S | US-011a, US-011b | Backlog | |
| US-014 | Karakter kuklası v0 (GDD §14.1) — önce oyuncu; NPC kuklaları gözlemci kalemiyle | 2 | oynanis (görsel) | P1 | M | US-004 | Bitti (2026-10-02; faz2-int 579a96e) | |
| IS-015 | Oyun testi botları: kapalı döngü `bot_brain.gd` (çoğaltılan durumu okur, PlayerInput sağlayıcısı; beyin oynanis) + koşu istatistiği dökümü (cekirdek) (pencere bekle, GÖNDER + kasa, kaç) + 150 ms 20 dk + kopma davranışı | 2 | cekirdek + oynanis | P1 | M | US-008, US-012 | Backlog (2b) | |
| US-015 | Oyuncu senkronu 30 Hz (aralık tek kaynaktan; sert ağ 10 koşuda samples_near ≥ 9/10 — ag-kodu tur 2 ölçümü 20 Hz 3/10 → 30 Hz 9/10); uyarlanır tampon ertelendi | 2 | oynanis | P1 | S | US-004 | Backlog | |
| IS-020 | net_smoke/main: mutlak çıkış zamanı (`--quit-at`) + `level_change.json` 150 ms kararsızlığı (yük altında 53 px, IS-037 koşusu) + dökümde halka tampon örnekler + test_net_smoke turn_frame_patterns anahtar yuvarlama nit'i + allow_log süreç başına (IS-013 adayları) | 2 | cekirdek | P3 | XS | IS-013 | Backlog | |
| IS-022 | Ekran görüntüsü aracı: Windows'ta GPU'lu pencerede seviye + botlarla belirli anların PNG'si | 2 | cekirdek | P1 | S | — | Bitti (dev) | fac4488 |
| IS-025 | (IS-027'ye taşındı — test-1 öncesi Faz 1'de yapılıyor) | 2 | oynanis | — | — | — | Elendi (IS-027) | |
| IS-026 | HUD ping'i yerelde 106-160 ms (pencereli) — ölçüm kök nedeni ve düzeltme | 1 | cekirdek | P1 | S | — | Denetimde (t3; medyan + elle flush kaldırıldı + hello RPC) | |
| US-026 | Bağlantı kolaylığı: ad + son adres hatırlanır, host kendi Tailscale/LAN adresini görür + Kopyala/Yapıştır, port 'Gelişmiş' altında (docs/tasarim/arastirma/rahatlik-ux.md UX-1) | 1 | arayuz | P1 | S | — | Sürüyor (t2; gizli port alanına odak + aday/yapıştır nit'leri) | |
| US-027 | Anlaşılır bağlantı hataları + sürüm uyuşmazlığı nedeni istemciye (game.gd:427 ret nedeni yollanır) + menüde/dökümde build kimliği (application/config/version + git kısa hash, export_presets sürüm alanları) (UX-2 + teknik/operasyon-guvenilirlik.md Ö1) | 2 | cekirdek + arayuz | P1 | S | IS-026 | Backlog | |
| US-028 | Sızma/koşu/etkileşim için tut↔geçiş seçenekleri + HUD kip ikonu (UX-3) | 2 | oynanis + arayuz | P1 | S | US-025 | Backlog | |
| US-025 | Ayarlar v0 (`user://settings.cfg`; ses kanalları, görüntü, hareket azaltma tek kaynak — kukla/sis/halka/merdiven bağlanır, yazı ölçeği, ipuçları, kip seçenekleri) + duraklat erişimi (UX-4 + oyun-hissi #7) | 2 | arayuz | P1 | M | US-014 | Backlog | |
| US-029 | İpucu sistemi + rehberli bakkal (8 tetik bazlı tek satır ipucu) (UX-5) | 2 | arayuz + oynanis | P2 | S | US-008 | Backlog (2b) | |
| US-030 | Cihaz algılama + tuş simgeleri ([E]↔[A]), fare imleci, sağ çubuk ölü bölge (UX-6) | 2 | arayuz + oynanis + altyapi | P1 | S | US-011d | Backlog | |
| US-031 | Lobi v0: Hazır/Başla, host kuralları (görüş kipi), davet adresi, kontrol kartı, geç katılan bekler (UX-7) | 2 | arayuz + cekirdek | P2 | M | US-026 | Backlog (2b) | |
| US-032 | HUD katmanlama (her zaman / bakınca) + 1280×800 düzen testi + kontrast seçeneği (UX-8) | 2 | arayuz | P2 | S | US-011c | Backlog (2b) | |
| US-021 | His turu v1 — etkileşim ve kasa: iki aşamalı geri bildirim (ON-02), 22 px hedef halkası (ON-06), kapı ön-aralanma, red gri sönüm (docs/tasarim/arastirma/oyun-hissi.md #1) | 2 | oynanis + arayuz | P1 | S | US-014 | Backlog | |
| US-022 | Kamera dili v1: camera_tuning.tres (yumuşatma, look-ahead, zoom darbesi, trauma sarsıntı, vinyet, hareket azaltma kapısı) (oyun-hissi #2) | 2 | oynanis | P1 | S | US-011b | Backlog | |
| US-023 | Tepki kuklası: ürkme, sorgu donması, tutulma + ÇEK, sendeleme, yakalanma, çanta (oyun-hissi #3) | 2 | oynanis (görsel) | P2 | M | US-008, US-014, US-012 | Backlog (2b) | |
| IS-033 | Olay → ses-görsel bağlama: oyun-hissi §2 anahtarları, stinger + müzik kesme kancası (IS-024 eki) + ekran dışı ses kenar işareti (`core/sound_indicator_rules.gd`, katalog `kind`; kapatılamaz oyun bilgisi; ses tur 2 #10) | 2 | arayuz | P1 | S | IS-024, US-008 | Backlog | |
| US-024 | HUD tepkileri v1: nakit sayarak artış, çanta ikonu, Kaçtı n/3, TUTULDUN/ÇEK istemi, sayaç pulse (oyun-hissi #5) | 2 | arayuz | P2 | S | US-012 | Backlog (2b) | |
| IS-035 | His ölçüm eki: koşu JSON `feel` alanları, gözlem formu H sütunu (oyun-hissi #8) | 2 | cekirdek | P2 | XS | IS-015 | Backlog (2b) | |
| US-017 | Bağlamsal ping çekirdeği (core/comm_rules, request_ping → host doğrular → ping_shown; görünen NPC kesin, görülmeyen iddia) (docs/tasarim/arastirma/ekip-iletisimi.md) | 2 | oynanis | P1 | M | US-011b | Backlog (2b; kullanıcıya soruldu) | |
| US-018 | Ping/mesaj görselleri + HUD günlüğü + token/i18n | 2 | arayuz | P1 | S | US-017 | Backlog (2b) | |
| US-019 | Hızlı mesaj tekerleği (8) + go-kodu + gürültülü 'Kaç!' | 2 | arayuz + oynanis + altyapi | P2 | S | US-017 | Backlog (2b) | |
| IS-032 | Test-2 'Discord sessiz turu' protokolü ve ölçümü (yakınlık sesi ihtiyacı) | 2 | tasarim + koordinatör | P2 | S | — | Backlog | |
| US-033 | Bakkal keseler ve koli engelleri (arka oda + ara sokak, içecek dolabı) — vision_block (docs/tasarim/arastirma/mekan-estetigi.md K3) | 2 | seviye | P1 | XS | IS-023 | Denetimde (2026-10-02; kullanıcı onayıyla) | |
| US-034 | Bakkal dekor + ışık v1 (16 öğe, vitrin/tezgâh/arka oda ışık havuzları; CanvasModulate + ADD) (mekan-estetigi K1 + docs/tasarim/arastirma/sanat-yonu.md #4) | 2 | seviye | P2 | M | US-033, IS-036 | Backlog (2b) | |
| US-035 | Sahibin ajanda telegrafları (çay bardağı → arka oda, koli çıkartması → raf, zil → telefon) (mekan-estetigi K2) | 2 | oynanis + seviye | P2 | S | US-008 | Backlog (2b) | |
| IS-036 | Stil kilidi: 6 onaylı AI asset + palet ≤ 24 + `tools/asset_post.py` (Pillow: palete eşleme dither'sız, dikişsizlik yarım kaydırma + edge_mae; unittest) + assetler.md (sanat-yonu #1; kullanıcı onayı) | 2 | seviye + koordinatör | P2 | S | kullanıcı onayı | Backlog (2b) | |
| US-036 | Bakkal zemin/duvar/cam seti v0 (AI, dikişsiz, --placeholder-art yolu korunur; `Tiles` = TileMapLayer + build_levels `set_cell`, LevelLayout ızgara API'si kalır — S4 güncellenir) (sanat-yonu #2 + teknik/cizim-performans.md) | 3 | seviye | P2 | M | IS-036 | Backlog | |
| IS-037 | Fizik katmanı ve grup sabitleri tek kaynak `core/physics_layers.gd` + test_smoke bit eşleşmesi (mimari tur #1) | 2 | cekirdek | P1 | XS | — | Bitti (2026-10-02; faz2-int 927f668) | |
| IS-038 | §6 katman matrisi testi (yol + class_name; entities→ui, ui→entities, levels→entities) (mimari tur #4) | 2 | altyapi | P1 | S | — | Sürüyor (2026-10-02; faz2-int, IS-039 ile) | |
| IS-039 | Sözleşme testi S3/S4 eklerini kapsar (Level marker_sequence/zone/navigation_region/door_link/map_rect/tier; Game S3 eki PENDING) (mimari tur #5) | 2 | altyapi | P1 | XS | — | Sürüyor (2026-10-02; faz2-int, IS-038 ile) | |
| IS-041 | README Tailscale teşhis notu: paylaşılan makineye FQDN ile erişim, `tailscale status` relay, exe'ye özel UDP 7777 güvenlik duvarı kuralı (`netsh`), yer tutucu ses notu (teknik/operasyon-guvenilirlik.md Ö4) | 1 | altyapi | P1 | XS | — | Bitti (2026-10-02; dev 676e28f) | |
| IS-042 | Checkpoint dağıtımı: `test-N` etiketinde GitHub Release + sürümlü zip (CI); itch gizli sayfa test-2'de karar (Ö5) | 1 | altyapi | P1 | XS | — | Bitti (2026-10-02; dev 676e28f) | |
| IS-043 | Yapılandırılmış günlük v0 (`Logger` alt sınıfı + OS.add_logger, seviye/kategori, halka tampon, release backtrace) + "Sorun bildir" paketi (log + döküm + PNG + sistem bilgisi zip) + `session.lock` temiz kapanmadı bayrağı (Ö2 + Ö3) | 2 | cekirdek + arayuz | P1 | S | — | Backlog | |
| IS-044 | Oturum izi v0: host karar günlüğü + peer durum izi (jsonl; S6 samples/events'in uzantısı); girdi replay'i yerine (Ö6; karar gereken: GDD replay maddesi daraltılır) | 2 | cekirdek | P2 | S | IS-043 | Backlog | |
| IS-045 | (S2 notu mimari §5'e yazıldı; ölçüm IS-059'a taşındı) | 2 | — | — | — | — | Elendi (IS-059) | |
| IS-046 | Test hijyeni kapısı: koşucu orphan/sızıntı sayacı (`OBJECT_ORPHAN_NODE_COUNT` farkı + `--verbose` Leaked instance taraması) → test başına uyarı, takım sonu FAIL eşiği (teknik/mimari-test.md; IS-029 sonrası; tur 2: faz2-int'te orphan farkı 0 — koşucu içi `[ORPHAN]` satırı + özet, eşik 0) | 2 | altyapi | P1 | XS | IS-029 | Denetim sırasında (2026-10-02; yapım bitti, dev) | |
| IS-047 | Uyarı sıkılaştırma ölçümü: `unsafe_method_access`, `unsafe_property_access`, `unsafe_call_argument`, `return_value_discarded` = 1 (warn) + sayım raporu; hata (2) kararı ölçüm sonrası | 2 | altyapi | P2 | XS | — | Denetim sırasında (2026-10-02; t1b bitti: unsafe_method/property = 2 + warn_count --gate) | |
| IS-048 | Typed koleksiyon geçişi (üretimde 73 tipsiz Array/Dictionary → typed ya da küçük Resource; modül sahipleri) | 3 | cekirdek + oynanis | P2 | S | IS-047 | Backlog | |
| IS-049 | Deterministik zaman: `core/clock.gd` (sahte saat) — üretimde `Time.get_ticks_*` 8 yer, testlerde duvar saati döngüleri; hedef birim toplam 30 → ≤ 15 sn, önce test_noise_bus (sürenin ~%33'ü) | 2 | cekirdek + oynanis | P2 | S | — | Backlog | |
| IS-050 | Autoload test dikişleri (testlerin 33 özel üye erişimi → açık test API'si), IS-040 öncesi | 2 | cekirdek | P2 | S | — | Backlog | |
| IS-051 | gdlint (gdtoolkit 4.5): `gdlintrc` satır 130, max-file-lines 400 (tests/ hariç), class-definitions-order kapalı, tests/ için max-public-methods kapalı; test_perception_components.gd:143 dize düzeltmesi; ci_local tools adımına (~8 sn); gdformat yok | 3 | altyapi | P3 | XS | — | Backlog | |
| IS-052 | Süreç: worktree tabanı (ajan worktree'si güncel dalı alsın; ayar doğrulanıyor) + `.gitignore` `.claude/worktrees/` + surec.md §6 yol düzeltmesi (teknik/ajan-sureci.md) | 2 | koordinatör + altyapi | P1 | XS | — | Bitti (2026-10-02; denetci PASS; ajanlar.md yol düzeltmesi) | |
| IS-053 | Süreç: ajan hook'ları v1 (PreToolUse: ajanlarda git yazma işlemleri, pano dosyaları ve .claude yapılandırması engellenir; denetci yazamaz) — kaleme özel Dokunulmayacak yollar, `func test_` silme ve project.godot sahipliği IS-054/IS-072'ye | 2 | altyapi | P1 | S | IS-052 | Bitti (2026-10-02; dev, kullanıcı onayı) | |
| IS-054 | Süreç: denetim kontrol listesi v2 — M/ağ kalemlerinde çürütme ajanı 1-3 ajanın görmediği (holdout) test yazar + denetci 2-3 elle mutant uygular; denetci/çürütme effort xhigh; somut metin teknik/ajan-sureci.md tur 2: holdout `tests/unit/test_<kalem>_holdout.gd` Denetimde'de kodu okumadan karttan yazılır (kör kural istem düzeyinde), IS-053 hook'u `*_holdout.gd` düzenlemesini reddeder; mutantlar scratchpad kopyasında; `curutme` ajan tanımı | 2 | koordinatör | P1 | XS | — | Backlog | |
| IS-055 | Süreç: pano lint (`tools/pano_check.py`: S-sayısı, kimlik tekilliği, durum değerleri, ölü yol) + ortak ajan kuralları tek kaynak + backlog §0 paket sınırı güncel | 2 | altyapi | P2 | S | — | Backlog | |
| IS-056 | Süreç: XS/S arayüz-altyapı kalemlerinde düşük model kademesi deneyi (kalite = t2 oranı, süre, token) | 2 | koordinatör | P3 | XS | — | Backlog | |
| IS-057 | Yakalama/tespit bayatlık payı: oyuncu lehine pay `max(0,2; bayatlık + 0,05)` sn, yakalamada ölü hesap (`net_position + hız × yaş`) (ag-kodu P1; US-008 sonrası) | 2 | oynanis | P1 | S | US-008 | Backlog | |
| IS-058 | NPC çoğaltma sözleşmesi uygulaması (S11 eki: poz 15 Hz unreliable + istemci SnapshotBuffer, ayrık durum ON_CHANGE, yön 1/16) + oturum tohumu `Game.session_seed()` / `--seed=` (US-008 içinde yapılmadıysa) | 2 | oynanis + cekirdek | P1 | S | US-008 | Backlog | |
| IS-059 | Ağ telemetrisi: `Net.stats()` bayt/paket, döküm `net_bytes`, net_smoke `max_kbps` + en büyük paket; yetiştirme RPC'si `unreliable` + damga; RPC hijyen taraması (testte) (ag-kodu P2 + Ö8) | 2 | cekirdek + altyapi | P2 | S | — | Backlog | |
| IS-060 | Ses busları (Master/Music/SFX/UI/VO, `default_bus_layout.tres`) + katalogda `bus` alanı + düzey ayarları US-025'e bağlanır (teknik/ses.md P1) | 2 | altyapi + arayuz | P1 | S | IS-024 | Backlog | |
| IS-061 | Konumlu ses hijyeni: mono 44,1 kHz (dönüştürme aracı `tools/sfx_prep.py`), kısa SFX `.wav` izinli, `max_distance` her çalışta sıfırlanır, attenuation katalogda (2,0), uzaklık kapısı; yerel `AudioListener2D` + panning 0,75 (IS-024 t2'de kalanı) | 2 | arayuz + oynanis | P1 | XS | IS-024 | Backlog | |
| IS-062 | Çok sesli emitter (`AudioStreamPolyphonic`) oyuncu/NPC için + Randomizer varyantları (US-009 adım, US-012 çanta önkoşulu; önce Godot #118498 ön kontrolü: 4.7.2'de `play_stream(bus=…)` bus'ı yok sayıyor olabilir → gerekirse 2 çalarlı havuz) | 2 | oynanis | P2 | S | IS-024 | Backlog | |
| IS-063 | Ucuz ses örtme: `SFX_Muffled` bus + yerel ışın 5 Hz | 3 | oynanis | P2 | S | IS-060 | Backlog | |
| IS-064 | NPC karar mimarisi temizliği: HFSM-lite, zaman damgalı Fsm geçmişi, `SuspicionMeter.pulse` (ses → şüphe, günlüklü), NpcMover ulaşılamayan hedef `failed` + repath kaydırma, testlerde `map_force_update` yerine iterasyon bekleme (US-008'de yapılmayan kalanı; teknik/oyun-yz.md) | 2 | oynanis | P1 | S | US-008 | Backlog | |
| IS-065 | AI hata ayıklama katmanı (F3 / `--debug-ai`: NPC durum, yol, koni, şüphe; ekran görüntüsüyle) | 2 | arayuz + oynanis | P2 | S | US-008 | Backlog | |
| IS-066 | Görüş hattı tekilleştirme (Perception → ortak SightLine core yardımcısı; US-011b ile) + algı örnekleme 20 Hz tek sabit | 2 | oynanis | P3 | XS | US-011b | Backlog | |
| IS-067 | Çizim ölçümü: `--perf` argümanı + döküm `"render"` (draw call, CPU/GPU ms `viewport_get_measured_render_time_*`, fps) + pencereli perf senaryosu + sürücü yolu (adapter, api_version; ANGLE/D3D11 mi yerli GL mi); arkadaş makinesi dökümüyle karşılaştırma (teknik/cizim-performans.md P1) | 2 | altyapi + cekirdek | P1 | S | — | Denetim sırasında (2026-10-02; yapım bitti) | |
| IS-068 | Kukla CPU bütçesi + cila: ekran dışı/görünmeyen kuklada rig + `queue_redraw` atlanır, uzak kukla 30 Hz (puppet.gd:106-110); atkı ucu yuvarlak, toz/bere segment sayısı, `_draw` tahsisleri (US-014 nit) | 2 | oynanis | P2 | S | US-014 | Backlog | |
| IS-069 | Doku süzgeci ve import ön ayarı: `default_texture_filter` Linear kalır, mipmap yalnız asset bazında (açılırsa TileSet 2-4 px oluk + extrude), `snap_2d_*` kapalı (cizim-performans tur 2) | 3 | altyapi | P2 | XS | IS-036 | Backlog | |
| IS-070 | Proje ayarı varsayılan kilidi: `tests/unit/test_project_settings.gd` (gezinme async iterasyon, link yarıçapı, avoidance iş parçacığı, 2D fizik ayrı iş parçacığı kapalı vb. 4.7.2 varsayılanları) + mimari §1 satırı; project.godot'a satır eklenmez (oyun-yz tur 2 #17) | 2 | altyapi | P2 | XS | — | Backlog | |
| IS-071 | Uyarı temizliği 2: `t.gd` yardımcıları void (test uyarısının ~%87'si), üretimde `connect()` dönüş deseni (67), varsayılan açık türlerde 19 uyarı (static_called_on_instance, shadowed_*, incompatible_ternary) → sıfır; sonra `return_value_discarded` düzeyi kararı (IS-047 ölçümü) | 2 | altyapi + modül sahipleri | P2 | S | IS-047 | Backlog | |
| IS-072 | Süreç: `tools/kart.py` + kart dosyaları `docs/surec/kartlar/<ID>.md` (yeni kalemler; Hazır/Sürüyor Faz 2 kartları taşınır) + skill'ler `/paket`, `/kapat`, `/dalga` (ajan-sureci tur 2) | 2 | altyapi + koordinatör | P2 | S | IS-053 | Backlog | |
| IS-073 | Süreç içi loopback ağ fikstürü `tests/fixtures/loopback_peer.gd` (test_game kalıbı taşınır; S7 RPC akışı < 0,5 sn; test_net transport taramasına fixtures istisnası) (mimari-test tur 2) | 2 | cekirdek | P2 | S | — | Backlog | |
| IS-074 | Net adımı süre bütçesi: senaryo başına süre özeti (`$GITHUB_STEP_SUMMARY` + yerel), > 600 sn'de 0/150 matris bölmesi, uzun senaryoların duration gerekçesi | 2 | altyapi + cekirdek | P3 | XS | — | Backlog | |
| IS-075 | Sis lite shader (ekran okumasız, doygunluksuz) + `--low-gfx` / ayar; varsayılan kararı IS-067 arkadaş ölçümüyle (Intel UHD'de hint_screen_texture ~4-8 ms riski, GH #108935) (cizim-performans tur 2) | 2 | seviye | P1 | XS | US-011a | Backlog | |
| IS-076 | Test build'i hata görünürlüğü: test-* etiketinde debug şablonu export, `config/version="0.1.0"`, README Tailscale = Private / Engelle kuralı kontrolü (operasyon tur 2) | 1 | altyapi | P1 | XS | — | Sürüyor (2026-10-02; dev) | |
| US-037 | NPC'lerle temas ve itme (kullanıcı fikri, 2026-10-02): sakin kipte NPC'ler yumuşak engel (oyuncu yavaşlar/yol verir, itmez); "it/omuz at" eylemi her zaman mümkün ama sakinken görenlerde küçük şüphe (+N), kısa pencerede art arda itme katlanır; işler çığırından çıkınca (uyarı ≥ 2 ya da kaçış) itme serbest ve NPC sendeler — Fable tasarımı + AC'ler; US-008'in 'oyuncu NPC içinden geçer' geçici kararını değiştirir | 2 | tasarim → oynanis | P1 | S | US-008, US-016 | Backlog (Fable'a sorulacak) | |
| IS-040 | game.gd iç yardımcılara bölünür (seviye yükleme + el sıkışma, oyuncu listesi, iş durumu); dış yüzey aynı (mimari tur #3; karar: US-008/US-012 birleşince) | 2 | cekirdek | P2 | M | US-008, US-012 | Backlog | |
| IS-018 | Faz 2 ara + kapanış tasarım değerlendirmesi (Fable) | 2 | tasarim | P1 | S | US-012 | Backlog | |
| IS-021 | Senaryo bazlı tehdit modeli: GDD §9 kademe tablosu + bakkal yeniden tasarımı + Faz 2 kalem revizyonu (Fable) | 2 | tasarim | P1 | S | — | Bitti (GDD v0.3; koordinatör okuması) | |
| IS-016 | Steam spike: 480 lobisi + davet + SteamMultiplayerPeer, 2 kişi (kullanıcı cihazı) — KR-020 ile sona kaydı | 5 | cekirdek + kullanıcı | P3 | S | — | Backlog (ertelendi) | |

### US-008 — (ESKİ TASLAK, KR-020 ile geçersiz: bakkalda polis/muhafız yok; IS-021 sonrası yeniden yazılır. FSM/adalet AC'leri gözlemci için yeniden kullanılır)
EP-02 · P1 · M · Sahip: oynanis · Sözleşme: S2, S3, S6, S11 · Bağımlılık: US-006, US-007 · 2a dilimi (kamera iskeleti 2b'de tamamlanır)
**Hikâye:** Oyuncu olarak dışarıda devriye gezen polisin camdan beni fark edip şüphelenmesini, inceleyip son gördüğü yere gelmesini, telsizle durumu yükseltmesini ve kaçarsam aramayı bırakmasını istiyorum; ne olduğunu her an okuyabilmeliyim.
**Kabul kriterleri** (sayılar ve FSM: `docs/tasarim/arastirma/muhafiz-davranisi.md`; ayarlar veride):
- AC1 `entities/npc/guard/` sahnesi: CharacterBody2D (katman npcs), US-006 `Perception` + `Suspicion` bileşenleri, `core/fsm.gd` (küçük durum makinesi, düğümsüz) + `brain_guard.gd`; durumlar DEVRIYE → BAK → INCELE → TELSIZ → KOVALA → SEZGI → ARA → DON (+ YAKALADI); `data/npc/guard_tuning.tres` (hızlar 90/110/130/240, dönüş ≤ 120°/sn, bakış 0,5-1 sn, inceleme 2 sn, telsiz 1,5 sn, sezgi 2 sn, arama ≤ 20 sn, yakalama 28 px + 0,5 sn temas, aramada şüphe tabanı 60). Yalnız host'ta işler; konum/yön/durum özeti 15-20 Hz çoğaltılır, istemcide yumuşatılır.
- AC2 Devriye: US-007 `PolicePatrol*` noktalarını navigasyonla izler; dükkâna 75±10 sn'de bir bakar/girer (K2); tohumla belirlenimci.
- AC3 Algı → davranış: "?" (30) BAK, 60 INCELE (son görülen konuma gider), 100 TELSIZ (1,5 sn pencere) → uyarı yükselir + KOVALA; görüş kaybında SEZGI 2 sn → ARA ≤ 20 sn (3-4 nokta) → DON; aramada ikinci tespit = uyarı 3.
- AC4 Küresel uyarı kademesi 0-3 (host'ta, Game/S3 eki: `alert_level_changed(level: int)` sinyali + döküm `alert`): sönüm 2→1→0 60+20 sn; 3 geri dönmez ve 90 sn sayaç başlatır (sayacın sonucu US-012). S3 eki koordinatörce mimari.md'ye yazılır; autoload/game.gd'ye bu ek için istisna.
- AC5 Yakalama: KOVALA'da 28 px + 0,5 sn temas → oyuncu `captured` (K3: donar; sonucu US-012 uygular); yakalanan oyuncunun girdisi kesilir (oyuncuya küçük API; S7 dışı).
- AC6 Adalet (S2, GDD §12): aleyhte kararlar host'un eşitleyici konumuyla; lehte kararlar 0,2 sn; tespit günlüğü (dökümde `detections`: zaman, peer, mesafe, bant, durum, `net_flag`).
- AC7 Kapı etkileşimi: muhafız kapalı kapıyı açabilir (Interactable host API'siyle) ya da kapıda yol değiştirir — seçim "Karar gereken"; kapı durumu US-007 navigasyon bağına bağlanır (`Level.door_link(kapı).enabled` = açık; kapalı arka kapıdan NPC yolu geçmez); IS-014 nit'i: kapı engel denetimi yalnız `interaction_position()` kullanır ve npcs katmanını da engel sayar.
- AC8 Testler: FSM değişmezleri (I1 tespit öncesi "?" şart, I2 |Δşüphe| ≤ hız×Δt, I3 süre tavanları, I4 uyarı geçiş kümesi, I5 dönüş ≤ 120°/sn, I6 tohum belirlenimciliği, I7 duvar içi yok) birim; `tests/net/guard_detect.json` (camdan görülen koşan oyuncu → ?, inceleme, tespit; tüm peer'larda aynı uyarı; 0 ve 150 ms).
- AC9 SFX ve görsel için olay adları sinyal olarak (çizim US-011/US-014; ses 2a'da yer tutucu).
**Dokunulacak:** entities/npc/** (guard, brain, components'e yalnız ekleme), core/fsm.gd, core/guard_rules.gd (gerekirse), data/npc/**, autoload/game.gd (yalnız uyarı kademesi S3 eki), entities/player/** (yalnız `captured` durumu ve girdi kesme), entities/props/door.gd (yalnız AC7 nit'i), levels/store_a.tscn (yalnız NPCs altına muhafız yerleşimi), tests/unit/test_guard*.gd, tests/unit/test_fsm*.gd, tests/net/guard_detect.json, tests/net/bots/**
**Dokunulmayacak:** autoload/{net,args}.gd, ui/**, levels/ (NPCs dışı), project.godot, tools/**
**Oku:** mimari.md S2, S3, S6, S11 · GDD §6, §12 · muhafiz-davranisi.md · KR-019

### US-009 — Gürültü v0
EP-02 · P1 · S · Sahip: oynanis · Sözleşme: S8, S2, §6 · Bağımlılık: US-005 (US-006'ya bağımlı değil: dinleyici sinyal yayar, şüpheye bağlama gözlemci kalemi US-008'de)
**Hikâye:** Oyuncu olarak koşarken, kapıyı çarparken ya da kasayı boşaltırken çıkardığım sesin bir halka olarak görünmesini ve yakındakilerin onu duyabilmesini istiyorum; sızarken ses çıkarmamalıyım.
**Kabul kriterleri:**
- AC1 `autoload/noise.gd` (`NoiseBus`, S8) gerçek uygulama: `emit_noise(pos, radius, kind, source_peer)`; istemciden çağrılırsa host'a iletilir (gönderen kimliği `get_remote_sender_id`; istemci başka peer adına ses üretemez, konum host'un bildiği aktör konumuna kenetlenir/doğrulanır); host `noise_listener` grubundaki düğümlerin `hear_noise(pos, radius, kind)`'ını çağırır ve herkese görsel halka olayı yollar.
- AC2 `data/noise_profile.tres` (S10 kalıbı): yürüme 0, sızma 0, koşma 120 (adım başına, en fazla ~3 Hz), kapı 160, kasa boşaltma 90 (başlangıç değerleri S8); `core/noise_rules.gd` (düğümsüz): duvar arkası zayıflama (görüş hattı yoksa yarıçap ×0,5 — host fizik sorgusu bileşende, kural core'da), mesafe kontrolü.
- AC3 Yayımcılar: oyuncu (koşu adımları; yalnız yerel oyuncu yayar, host doğrular), kapı (aç/kapa), kasa (boşaltma tamamlanınca ve sürerken düşük oranla — profil). Mevcut US-004/US-005 davranışı değişmez.
- AC4 `entities/npc/components/hearing.gd` (`Hearing`, S11): `noise_listener` grubunda; duyunca `heard(pos: Vector2, radius: float, kind: StringName)` sinyali (yalnız host); şüpheye bağlama US-008.
- AC5 Görsel halka (tüm peer'larda): genişleyen halka 0,4 sn, renk ThemeTokens (GAMEPLAY_* ya da noir FG — KR-019), ≥ 22 px okunurluk (GDD §14.1 kural 2); "hareket azaltma"da da görünür.
- AC6 Testler: core kural birim testleri; bileşen testi (duvar arkası zayıflama gerçek fizik ışınıyla); ağ senaryosu `tests/net/noise_ring.json` (koşan istemci → host ve diğer istemci halka olayını alır, sızan → hiç; test dinleyicisi `heard` sayar; 0 ve 150 ms); hile: istemcinin başka peer adına ya da uzak konumda ses üretemediği birim testi.
**Dokunulacak:** autoload/noise.gd, core/noise_rules.gd, data/noise_profile.{gd,tres}, entities/npc/components/hearing.gd, entities/fx/** (halka), entities/player/player.gd (yalnız gürültü yayımı), entities/props/{door,register}.gd (yalnız yayım), tests/unit/test_noise*.gd, tests/net/noise_ring.json, tests/net/bots/**, tests/fixtures/** (yalnız yeni)
**Dokunulmayacak:** autoload/{net,args,game}.gd, ui/**, levels/**, project.godot, tools/**, entities/player/player_visual.gd ve kukla dosyaları (paralel US-014), core/{perception,suspicion}.gd
**Oku:** mimari.md S8, S2, S11, §6 · GDD §6, §12 · KR-019, KR-020

### US-014 — Karakter kuklası v0 (oyuncu)
EP-02 · P1 · M · Sahip: oynanis (görsel) · Sözleşme: §6 (görsel katman yalnız durum okur), S9 · Bağımlılık: US-004
**Hikâye:** Oyuncu olarak karakterimin ve arkadaşlarımın anime zarafetinde, akıcı, yumuşak animasyonlu şirin kuklalar olarak görünmesini; kipimin (sız/yürü/koş) siluetten okunmasını istiyorum.
**Kabul kriterleri** (GDD §14.1 tümü; değerler `data/puppet_tuning.tres`):
- AC1 `entities/player/puppet/` altında prosedürel kukla (iri baş + yüz/gözler/parıltı/yanak, başlık yuvası, küçük gövde, iki el, atkı verlet zinciri 6 parça); oyuncunun mevcut yer tutucu görselinin yerini alır; atkı rengi `ThemeTokens.PLAYER_COLORS[slot]`; ad etiketi ve etkileşim göstergesi (IS-014) korunur, sabit bağlantı noktasında ve animasyondan bağımsız.
- AC2 Animasyonlar: yumuşatma + yay/aşma, kalkış/duruş hazırlık-devam, ezilme-esneme, yürüyüşte sekme + eğilme + karşıt el salınımı, sızmada çömelme, koşuda uzama + toz, beklemede nefes + göz kırpma + bakınma, etkileşimde gövde 0,95; tepki balonları ("?"/"!") için çağrılabilir API (NPC'ler sonra kullanır).
- AC3 Yalnız durum okur: kip, hız, yön, etkileşim durumu (yerelde girdi değil durum; uzak kopyada ara değerlenmiş durumdan); çarpışma yarıçapı 12 ve menziller değişmez; görsel aşma ≤ 6 px; bağımlılık yönü testi (kukla mantık/ağ betiklerine başvurmaz).
- AC4 Hareket azaltma bayrağı (ayar API'si; UI sonra): sekme, eğilme, toz kapanır.
- AC5 Testler: parametre okuma, kip → siluet ölçeği/çömelme eşlemesi, yay/yumuşatma adım boyundan bağımsız (sabit adım), uzak kopyada tampon sıfırlanınca "pop" yok (konum/ölçek sıçraması sınırı), bağımlılık yönü. US-004 testleri ve senaryoları yeşil. Görsel doğrulama IS-022 aracıyla (bitince) üç kip ekran görüntüsü — kalem raporunda varsa ekle, yoksa koordinatör sonra çeker.
**Dokunulacak:** entities/player/puppet/** (yeni), entities/player/player_visual.gd, entities/player/player.tscn (yalnız görsel düğüm), data/puppet_tuning.{gd,tres}, tests/unit/test_puppet*.gd
**Dokunulmayacak:** entities/player/{player,player_input,player_motion,snapshot_buffer,player_interaction}.gd (davranış), autoload/**, ui/**, levels/**, core/**, project.godot, tools/**
**Oku:** GDD §14, §14.1 · docs/tasarim/kukla-denemesi.html · mimari §6, S9 · KR-017

### IS-022 — Ekran görüntüsü aracı
EP-02 · P1 · S · Sahip: cekirdek · Sözleşme: S6 · Bağımlılık: —
**Amaç:** Görsel kalemlerin (kukla, okunabilirlik, sis, HUD) ve kullanıcıya ilerleme raporlarının ekran görüntüsüyle doğrulanması; Windows'ta GPU'lu gerçek pencere (headless renderer görüntü üretmez).
**Kabul:** (1) S6'ya argümanlar: `--screenshot-at=SN[,SN…]` ve `--screenshot-dir=YOL` (+ isteğe bağlı `--window-size=1280x720`): verilen anlarda viewport görüntüsü PNG olarak yazılır, sonra normal akış (`--quit-after`) sürer. (2) `tools/screenshot.py` (ya da net_smoke'a `screenshots` seçeneği): bir senaryo/seviye + botlarla host (ve istemciler) GPU'lu pencerede açılır, istenen peer(ler)in görüntüleri `build/screens/<ad>/` altına toplanır; Windows'ta (Git Bash) çalışır; headless/CI ortamında açıkça "atlandı" der ve 0 döner. (3) Örnek: store_a'da 3 oyuncu (yürü/sız/koş botları) için 3 an; PNG'ler 1280×720, boş/siyah değil (piksel varyansı denetimi). (4) Birim test: argüman ayrıştırma ve zamanlama; mevcut senaryolar ve ci_local yeşil. (5) README'ye kısa kullanım.
**Dokunulacak:** autoload/args.gd (yalnız yeni argümanlar), main.gd (yalnız görüntü alma), tools/screenshot.py (yeni) ya da tools/net_smoke.py (yalnız seçenek), tests/unit/test_args*.gd / test_screenshot*.gd, README.md (yalnız bölüm)
**Dokunulmayacak:** entities/**, levels/**, ui/**, core/**, project.godot, tests/net/** (paralel IS-013), tools/{latency_proxy,soak}.*

### US-007 — Bakkal v1
EP-02 · P1 · S · Sahip: seviye · Sözleşme: S4 · Bağımlılık: US-002 · K1, K2
**Hikâye:** Oyuncu olarak bakkalda camlardan görülebildiğim, rafların arkasına saklanabildiğim ve dışarıda bir kaçış noktasına koşabildiğim bir harita istiyorum; polis dışarıda devriye gezsin.
**Kabul kriterleri:**
- AC1 `build_levels.gd`: `Window*` gövdeleri `see_through` grubuna eklenir (S4 eki); raflar (`Shelf*`) ve duvarlar görüşü keser (grup yok). Üretim deterministik; `test_levels` bunu denetler.
- AC2 `NavigationRegion2D` (ya da Godot 4.7 navigasyon karşılığı) store_a ve test_arena için: yürünebilir alan duvar/raf/tezgâh/kapalı kapı engelleriyle; headless'ta bake ve yol sorgusu birim testle doğrulanır (ör. ön kapı → arka oda yolu var, kapalı arka kapı kenarında yol değişir). Kapıların dinamik engel olması US-008'de gerekirse; bu kalemde kapı açıklığı bilgisi işaretle verilebilir.
- AC3 Düzene yeni işaretler: `EscapeZone` (dışarıda kaçış bölgesi; Area2D, triggers katmanı 5), `PolicePatrol*` (dış devriye rotası noktaları, sıralı), `ClerkSpot` (tezgâh arkası), `BackroomCash` (arka oda nakdi konumu). `.txt` düzeninde tanımlı, `Markers`/uygun düğüm altında.
- AC4 Mevcut US-002..US-005 testleri ve senaryoları yeşil (Props korunur; store_walk rotası bozulmaz).
**Dokunulacak:** levels/** (layouts, tools/build_levels.gd, level_layout.gd, *.tscn yeniden üretim; Props altı korunur), tests/unit/test_levels*.gd, i18n/texts.csv (satır ekleme)
**Dokunulmayacak:** autoload/**, entities/**, core/**, ui/**, project.godot, tools/**, levels/store_a.tscn Props altı
**Oku:** mimari.md S4, §4, §7 · GDD §8-9 (bakkal), §10 · KR-019

## 3. Sonraki fazların kalemleri (Backlog; faz başında ayrıntılanır)
**Faz 2 — Gizlilik:** (altyapi: `t.gd`'ye `expect_warning()` yardımcısı, test_ui_theme `_quietly` oraya taşınır; birim çıktısında WARNING satırı CI'da hata sayılır — IS-009 adayı) (cekirdek+arayuz: S3'e `level_load_failed(level_path)` sinyali, menü 10 sn zaman aşımı yerine buna tepki verir — IS-009 adayı) (ekran görüntüsü aracı: Xvfb ile sahne/arayüz görüntüsü alan tools betiği — US-003 kalem adayı) (ara tasarım değerlendirmesi: muhafız + şüphe + kaçış oynanabilir olunca; kapanışta tam değerlendirme + ilk yeni özellik önerileri) muhafız durum makinesi + devriye + NavigationRegion2D · görüş konisi + şüphe ölçeri (0-100, eşikler 30/60/100) + oyuncu lehine 0,2 sn · kamera = statik muhafız (aynı algı kodu) · küresel uyarı kademeleri · oyuncu görüş hattı/sis · gürültü v0 (NoiseBus, S8) · görüş: `Window*` şekilleri görüşü geçirir, rafların görüşü kesip kesmeyeceği kararı · tezgâhtar sivil + sindirme · T1 kilit (arka kapı) · ganimet çantası + kaçış bölgesi + iş sonu ekranı (ödeme + derece) · bağlantı kopması (avatar donar; kopma paketi kaybolursa host'un ayrılan oyuncuyu ENet zaman aşımına kadar tutması — US-001 notu) · throttle ayarı için kesin (olasılıksız) birim testi (cekirdek, P3) · net_smoke: senaryoda anahtar yoksa `--player-scene` geçmesin + docstring'de `samples_near` `procs` seçeneği (cekirdek, US-004 nit'i) · gecikmeye duyarlı `samples_near` eşiği (hız × gecikme; US-004 seçenek c) · boş oyuncu adında arayüz yedeği (`PLAYER_DEFAULT_NAME`, arayuz) · girdi günlüğü/replay · 5-6 temel SFX · ucuz keşif ön testi (60 sn izle → krokiye ikon) · Steam spike (480 lobisi + davet + SteamMultiplayerPeer, 2 kişi; kullanıcı cihazı) · Faz 2 kullanıcı oyun testi · **karakter kuklası v0 (KR-017):** oyuncu, tezgâhtar ve muhafız için prosedürel animasyonlu kukla (yürü/sız/koş/bekle/etkileşim/tepki), parametreler data/*.tres'te, görsel katman yalnız durumu okur; sahibi Faz 2 planında (seviye ya da yeni görsel ajanı) · **otomatik oyun testi (GB-01):** kural tabanlı bot oyuncular (yol bul, saklan, kasaya git, kaç) headless yüzlerce soygun koşar; yakalanma oranı, süre, ödeme istatistiği Fable değerlendirmesine girer · Xvfb ekran görüntüsüyle okunabilirlik kontrolü.
**Faz 3 — Keşif ve plan:** (KR-018 B: şablon/modül üretici + doğrulayıcı `core/level_gen.gd` + `ModuleDef`; test_levels Grid/BFS core'a taşınır) (ara değerlendirme: keşif → plan akışı oynanabilir olunca) keşif fazı (müşteri rolü, dış gözlemci, oyalanma şüphesi, yüz tanınma, otomatik işaretleme yok) · plan masası (hazır duvarlı kroki, ikon + rota, ortak gerçek zamanlı) · soygunda plan katmanı · tohum/rastgeleleştirme v0 (kamera konumu, tezgâhtar, polis periyodu) · iş sonu "plan doğruluğu" göstergesi (GDD açık soru 3) · Faz 3 oyun testi · **ajan oyun testi düzeneği (GB-01):** oyun adım kipinde durur, her oyuncu için "gördüğü" durum JSON'u verir, eylem alır (git, etkileşim, bekle, sohbet); 3 Claude ajanı keşif → plan (yazılı sohbetle, hafızadan) → soygun oynar, raporlarını Fable değerlendirir.
**Faz 4 — Sığınak ve ikinci kademe:** (KR-018 B: Economy — nakit/ısı/itibar — Game'den ayrı düğüm + sözleşme, game.gd bölünür; loadout/StatBlock çözücü `core/stats.gd`; ton oturum durumu static var yerine host'tan) para + ısı v0 · dükkân (3-4 eşya, yetenek kapısı) · benzinlik şablonu (kamera, DVR, sessiz alarm, sahte kamera) · kayıt (host kampanya + kişisel profil, JSON) · perk ağacı v0 · ton altyapısı iskeleti (ikinci tema yok; ton doğrulayıcı: yeni tonda boş/siyah kalan `level_*`/palet alanı hata verir; tokens.gd başlık yorumu güncellemesi) · CC0 asset geçişi (assetler.md).
**Faz 5 — Steam ve MVP:** (KR-018 B: net.gd taşıma yardımcıları EnetTransport/SteamTransport iç sınıflarına) GodotSteam GDExtension 4.22.1'i resmî kaynaktan (codeberg) indirip IS-004 sha256'larıyla doğrulama (bu konteynerde codeberg kapalı: ağ izni ya da kullanıcı indirir) · temiz import'ta GDExtension ilk-yükleme çöküşüne karşı CI'da çift import (altyapi) · S1'e Steam katılım imzası (lobby_id/steam_id) · GodotSteam lobi/davet UI + SteamMultiplayerPeer (ENet yedek) · Steam Cloud profil · Windows/Linux paket · itch gizli build · arkadaş oyun testi turu · KR-013 ad, KR-014 Steamworks.

## 4. Fikir havuzu
**Alternatif giriş ve kasa erişimi (GB-02, MVP sonrası; KR-018 B: önce level_layout.gd'de tür başına tek satırlık öznitelik tablosu):** havalandırma kanalları (sürünme, çanta/zırh sığmaz, ızgara sökme aleti) · zayıf duvar patlatma (patlayıcı + zamanlama/gürültü maskeleme, insider ya da keşifle bulunan zayıf duvar) · alttan patlatıp kasayı alt kata düşürme (çok katlı seviye, ağır ekipman, T9-T10).
İkinci ton (retro/neon, absürt) · 3D geçişi (Faz 5 sonrası değerlendirme) · çatışma genişletmesi (koridor tutma ötesi) · bot yoldaş · kılık/sosyal mühendislik rolü · insider pazarı · günlük tohum + lider tablosu.
