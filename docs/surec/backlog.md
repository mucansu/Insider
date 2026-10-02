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
| US-001 | Ağ çekirdeği ve oturum | 1 | cekirdek | P1 | M | IS-003 | Bitti | bc49aef |
| US-002 | Bakkal seviyesi v0 + test arenası | 1 | seviye | P1 | S | IS-003 | Bitti | d8ab983 |
| US-003 | Ana menü, HUD iskeleti, tema ve metin altyapısı | 1 | arayuz | P1 | M | IS-003 | Bitti | 7b34286 |
| IS-011 | Windows'ta yerel geliştirme: net_smoke süreç yönetimi (killpg yerine Windows eşdeğeri) ve get_godot Windows dalı ya da WSL kılavuzu | 1 | altyapi | P1 | S | — | Bitti | 8124e82 |
| IS-010 | OOP/genişletilebilirlik (A) uygulaması: Level API, slot, bağımlılık yönü | 1 | cekirdek | P1 | S | US-001 | Bitti | f6bd55c |
| US-004 | Oyuncu karakteri ve senkron hareket | 1 | oynanis | P1 | M | US-001, US-002, IS-010 | Bitti | a88d9c1 |
| US-005 | Etkileşim çerçevesi + kasa + kapı | 1 | oynanis | P1 | M | US-004 | Bitti | e32adf7 |
| IS-012 | Gecikme proxy testinin Windows'ta yük altında kararsızlığı (test_multiple_clients_get_own_replies 56 vs 40±15 ms) | 1 | altyapi | P1 | XS | IS-011 | Hazır | |
| IS-005 | Faz 1 çıkış testi + Windows/Linux build | 1 | altyapi | P1 | M | US-003, US-005 | Backlog | |
| IS-006 | Kullanıcı doğrulaması: iki makine + arkadaş oturumu | 1 | kullanıcı | P1 | S | IS-005 | Backlog | |
| IS-007 | Faz 1 tasarım değerlendirmesi (Fable) | 1 | tasarim | P1 | S | IS-005 | Backlog | |
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

### IS-005 — Faz 1 çıkış testi + Windows/Linux build
EP-01 · P1 · M · Sahip: altyapi · Bağımlılık: US-003, US-005
**Kabul:** (1) `tests/net/faz1_full.json`: host + 2 istemci store_a'da; biri arka kapıyı açar, biri kasayı boşaltır; tüm peer'larda team_cash 150; 0 ve 150 ms; ayrıca GDD §12 "sert ağ" profili (150 ms + 30 ms jitter + %1 kayıp) gerçek oyuncu sahnesiyle `store_walk` ve `faz1_full` için koşulur (KR günlüğü US-001). (2) `tools/soak.sh`: host + 2 bot 10 dk dolaşır, log'da hata/uyarı yok. (3) `export_presets.cfg` (Windows Desktop, Linux) + `tools/export.sh` export şablonlarını indirip `build/`'e iki platform çıktısı üretir; CI `main` push'unda build'leri artifact olarak yükler. (4) (`tools/test_latency_proxy.py`'nin ci_local'a eklenmesi IS-011'e taşındı) (entities/ kapsülleme taraması US-004'te `test_player_rules.gd` ile geldi; tekrar yazılmaz) gerçek oyuncu sahnesiyle geç katılma senaryosu (tampon boşken konuma dokunulmaz kuralı + Game yetiştirme akışı; geç katılan değişmiş prop durumunu — boş kasa, çevrilmiş kapı — alır (US-005 denetiminde geçici senaryoyla doğrulandı, kalıcılaştırılır); mevcut store_late_move `dummy_player` fikstürüyle koşuyor; US-004 inceleme nit'i); S4 Level API imzaları (tipleriyle) test_smoke CONTRACTS'a; net_smoke `known` ara düğümün zamanı kayıttan farklıysa çocukları aranmaz (IS-011 denetci nit'i); test_deps `uid://` ile ui başvurusunu da yakalar (IS-010 denetci nit'leri). (5) README'ye "Arkadaşla internet üzerinden (Tailscale)" ve "Build'i çalıştırma" bölümleri; renderer seçimi (Forward+ / Compatibility) arkadaş makineleri için değerlendirilir. (6) `tools/ci_local.sh` tüm senaryolarla yeşil.
**Dokunulacak:** tests/net/faz1_full.json, tests/net/bots/**, tools/{soak,export}.sh, export_presets.cfg, .github/workflows/**, README.md, tools/ci_local.sh
**Dokunulmayacak:** autoload/**, entities/**, levels/**, ui/**

### IS-006 — Kullanıcı doğrulaması: iki makine + arkadaş oturumu
EP-01 · P1 · S · Sahip: kullanıcı · Bağımlılık: IS-005
**Kabul:** Kullanıcı build'i (ya da editörü) iki pencerede çalıştırıp host/katıl, yürüme ve kasa boşaltmayı dener (US-004: hareket hissi, koşu halkası/sızma dolgusu, ad etiketi okunurluğu, kamera yalnız kendi karakterinde, Esc menüsü açıkken yürümeme, gamepad kısmi hız; 120/144 Hz ekranda yerel oyuncuda takılma var mı — varsa `physics_interpolation` kararı); bir arkadaşla Tailscale üzerinden bağlanır (≤ 5 sn), 10 dk oynar; his notları GB olarak yazılır. Faz kapanışını engellemez; Engelli(kullanıcı-cihaz) olarak taşınır.

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
EP-01 · P1 · S · Sahip: tasarim · Bağımlılık: IS-005 (faz kapanışından önce)
**Kabul:** KR-017 animasyon/karakter stilini GDD §14'e (referans ilkeler, zamanlama aralıkları, okunabilirlik kuralları) ve GB-02'yi (havalandırma girişi, duvar patlatma, alttan kasa düşürme; ileri kademe + ekipman/yetenek kapılı) GDD §7/§9/§10'a işler: hangi kademede açıldığı, gereken ekipman/perk, gürültü ve zamanlama bedeli, keşifte nasıl fark edildiği. `docs/tasarim/degerlendirmeler/faz-1.md` surec.md §5a biçiminde yazılır (Faz 1 temel yapı olduğu için ağırlık: hareket hızları, etkileşim süreleri, bakkal yerleşimi ve online hissin GDD'ye uyumu; Faz 2-3 için erken uyarılar). Koordinatör önerileri oneriler.md'ye işler. Koordinatör okumasıyla kapanır.

## 3. Sonraki fazların kalemleri (Backlog; faz başında ayrıntılanır)
**Faz 2 — Gizlilik:** (altyapi: `t.gd`'ye `expect_warning()` yardımcısı, test_ui_theme `_quietly` oraya taşınır; birim çıktısında WARNING satırı CI'da hata sayılır — IS-009 adayı) (cekirdek+arayuz: S3'e `level_load_failed(level_path)` sinyali, menü 10 sn zaman aşımı yerine buna tepki verir — IS-009 adayı) (ekran görüntüsü aracı: Xvfb ile sahne/arayüz görüntüsü alan tools betiği — US-003 kalem adayı) (ara tasarım değerlendirmesi: muhafız + şüphe + kaçış oynanabilir olunca; kapanışta tam değerlendirme + ilk yeni özellik önerileri) muhafız durum makinesi + devriye + NavigationRegion2D · görüş konisi + şüphe ölçeri (0-100, eşikler 30/60/100) + oyuncu lehine 0,2 sn · kamera = statik muhafız (aynı algı kodu) · küresel uyarı kademeleri · oyuncu görüş hattı/sis · gürültü v0 (NoiseBus, S8) · görüş: `Window*` şekilleri görüşü geçirir, rafların görüşü kesip kesmeyeceği kararı · tezgâhtar sivil + sindirme · T1 kilit (arka kapı) · ganimet çantası + kaçış bölgesi + iş sonu ekranı (ödeme + derece) · bağlantı kopması (avatar donar; kopma paketi kaybolursa host'un ayrılan oyuncuyu ENet zaman aşımına kadar tutması — US-001 notu) · throttle ayarı için kesin (olasılıksız) birim testi (cekirdek, P3) · net_smoke: senaryoda anahtar yoksa `--player-scene` geçmesin + docstring'de `samples_near` `procs` seçeneği (cekirdek, US-004 nit'i) · gecikmeye duyarlı `samples_near` eşiği (hız × gecikme; US-004 seçenek c) · boş oyuncu adında arayüz yedeği (`PLAYER_DEFAULT_NAME`, arayuz) · girdi günlüğü/replay · 5-6 temel SFX · ucuz keşif ön testi (60 sn izle → krokiye ikon) · Steam spike (480 lobisi + davet + SteamMultiplayerPeer, 2 kişi; kullanıcı cihazı) · Faz 2 kullanıcı oyun testi · **karakter kuklası v0 (KR-017):** oyuncu, tezgâhtar ve muhafız için prosedürel animasyonlu kukla (yürü/sız/koş/bekle/etkileşim/tepki), parametreler data/*.tres'te, görsel katman yalnız durumu okur; sahibi Faz 2 planında (seviye ya da yeni görsel ajanı) · **otomatik oyun testi (GB-01):** kural tabanlı bot oyuncular (yol bul, saklan, kasaya git, kaç) headless yüzlerce soygun koşar; yakalanma oranı, süre, ödeme istatistiği Fable değerlendirmesine girer · Xvfb ekran görüntüsüyle okunabilirlik kontrolü.
**Faz 3 — Keşif ve plan:** (KR-018 B: şablon/modül üretici + doğrulayıcı `core/level_gen.gd` + `ModuleDef`; test_levels Grid/BFS core'a taşınır) (ara değerlendirme: keşif → plan akışı oynanabilir olunca) keşif fazı (müşteri rolü, dış gözlemci, oyalanma şüphesi, yüz tanınma, otomatik işaretleme yok) · plan masası (hazır duvarlı kroki, ikon + rota, ortak gerçek zamanlı) · soygunda plan katmanı · tohum/rastgeleleştirme v0 (kamera konumu, tezgâhtar, polis periyodu) · iş sonu "plan doğruluğu" göstergesi (GDD açık soru 3) · Faz 3 oyun testi · **ajan oyun testi düzeneği (GB-01):** oyun adım kipinde durur, her oyuncu için "gördüğü" durum JSON'u verir, eylem alır (git, etkileşim, bekle, sohbet); 3 Claude ajanı keşif → plan (yazılı sohbetle, hafızadan) → soygun oynar, raporlarını Fable değerlendirir.
**Faz 4 — Sığınak ve ikinci kademe:** (KR-018 B: Economy — nakit/ısı/itibar — Game'den ayrı düğüm + sözleşme, game.gd bölünür; loadout/StatBlock çözücü `core/stats.gd`; ton oturum durumu static var yerine host'tan) para + ısı v0 · dükkân (3-4 eşya, yetenek kapısı) · benzinlik şablonu (kamera, DVR, sessiz alarm, sahte kamera) · kayıt (host kampanya + kişisel profil, JSON) · perk ağacı v0 · ton altyapısı iskeleti (ikinci tema yok; ton doğrulayıcı: yeni tonda boş/siyah kalan `level_*`/palet alanı hata verir; tokens.gd başlık yorumu güncellemesi) · CC0 asset geçişi (assetler.md).
**Faz 5 — Steam ve MVP:** (KR-018 B: net.gd taşıma yardımcıları EnetTransport/SteamTransport iç sınıflarına) GodotSteam GDExtension 4.22.1'i resmî kaynaktan (codeberg) indirip IS-004 sha256'larıyla doğrulama (bu konteynerde codeberg kapalı: ağ izni ya da kullanıcı indirir) · temiz import'ta GDExtension ilk-yükleme çöküşüne karşı CI'da çift import (altyapi) · S1'e Steam katılım imzası (lobby_id/steam_id) · GodotSteam lobi/davet UI + SteamMultiplayerPeer (ENet yedek) · Steam Cloud profil · Windows/Linux paket · itch gizli build · arkadaş oyun testi turu · KR-013 ad, KR-014 Steamworks.

## 4. Fikir havuzu
**Alternatif giriş ve kasa erişimi (GB-02, MVP sonrası; KR-018 B: önce level_layout.gd'de tür başına tek satırlık öznitelik tablosu):** havalandırma kanalları (sürünme, çanta/zırh sığmaz, ızgara sökme aleti) · zayıf duvar patlatma (patlayıcı + zamanlama/gürültü maskeleme, insider ya da keşifle bulunan zayıf duvar) · alttan patlatıp kasayı alt kata düşürme (çok katlı seviye, ağır ekipman, T9-T10).
İkinci ton (retro/neon, absürt) · 3D geçişi (Faz 5 sonrası değerlendirme) · çatışma genişletmesi (koridor tutma ötesi) · bot yoldaş · kılık/sosyal mühendislik rolü · insider pazarı · günlük tohum + lider tablosu.
