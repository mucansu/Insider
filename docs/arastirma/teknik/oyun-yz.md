# Oyun yapay zekâsı (gizlilik NPC'leri): teknik araştırma

Yazan: arastirmaci ajanı · Kod yazılmadı · İşaretler: **[O]** olgu (kaynağı sonda) · **[G]** görüş/çıkarım · **[?]** doğrulanmalı.
Godot sürümü: 4.7.2 (KR-007); 4.7.x'e uymayan eski bilgi ayrıca işaretlenir.

---

## Tur 1 — 2026-10-02

### Kapsam
Karar mimarisi (FSM / hiyerarşik FSM / davranış ağacı — Beehave, LimboAI / utility AI / GOAP) küçük NPC sayısı ve test edilebilirlik için; ajanda/zamanlama (smart object, Sims kalıbı); algı sistemleri (Thief, Splinter Cell Blacklist, Mark of the Ninja, Crytek TTPS, Game AI Pro); Godot 4.7 NavigationServer2D en iyi uygulamaları (eşitleme, avoidance/RVO, dinamik engel, bağlar, performans, headless test); kalabalık/ambient NPC (LOD, üst sınır, çoğaltma); determinizm ve tohumlu RNG; AI hata ayıklama görselleştirme; bot oyuncular (IS-015).

### Mevcut durum (dosya:satır)
Okunan dallar: `faz2-int` (US-006, US-007, US-009 birleşik) ve US-008 çalışma kopyası (`.claude/worktrees/agent-aad82679a5ece5354`, henüz birleşmemiş; "US-008 wt" diye anılır).

**Algı/şüphe çekirdeği (US-006, faz2-int)**
- `core/perception.gd:42-62` koni (menzil + yarım açı) ve iki bant; `:87-96` dolum = taban × bant × durum; `:101-112` dönüş tavanı. Düğümsüz statik fonksiyonlar; sahne bilmiyor.
- `core/suspicion.gd:50-78` ölçer adımı: 0,2 sn oyuncu lehine pay, 0,2 sn kesinti toleransı, eşik listesi; `:82-87` düzey.
- `entities/npc/components/perception.gd:104-112` her fizik adımında `interaction_actors` grubundaki tüm oyuncuları gezer; `:125-129` **önce koni testi, sonra ışın** (Crytek kalıbı); `:156-172` görüş hattı: world+vision_block maskesi, `see_through` gövdeleri RID dışlamayla atlanır (en fazla 8).
- `entities/npc/components/suspicion.gd:40-43` yalnız host, 60 Hz; `:122-133` `MultiplayerSynchronizer` 0,1 sn, değişince, yalnız `max_level` + `focus_direction`.
- `data/npc/perception_tuning.tres` 50°/256 px, yakın bant ×2, 25/sn taban, boşalma 20/sn, eşikler 30/60/100, pay 0,2, kesinti 0,2.
- US-009: `entities/npc/components/sight_line.gd:18-34` paylaşılan ışın yardımcısı (`SightLine.first_blocker`); `hearing.gd:33-44` `noise_listener` → `heard(pos, radius, kind)` sinyali. `sight_line.gd:7` notu: Perception'ın aynı kodu "ileride" buna geçecek — bugün **iki kopya** var (`perception.gd:156-172` ve `sight_line.gd:18-34`).

**Gezinme (US-007, faz2-int)**
- `levels/tools/build_levels.gd:328-360` üretim anında senkron bake (`NavigationServer2D.bake_from_source_geometry_data`), ajan yarıçapı 12 px, kapı karoları engel + kapı başına `NavigationLink2D` (uçlar ±1 karo; `:336-339`); `level.gd:70-77` `navigation_region()`, `door_link()`.
- `tests/unit/test_levels_nav.gd:358-388` yalıtık harita: `map_set_use_async_iterations(false)`, `region_set_use_async_iterations(false)`, `map_force_update` + yineleme kimliği bekleme; kapı bağı `enabled=false` → yol değişir (`:161-176`). Headless'ta bake ve yol sorgusu kanıtlı.

**NPC davranışı (US-008 wt, geliştiriliyor)**
- `core/fsm.gd` (101 satır): tamsayı durum, izinli kenar tablosu, `go/can/step`, BFS `route`, `history` (zaman damgası yok), `is_valid_sequence`.
- `core/civilian_rules.gd` (166): davranış çarpan tablosu (en şüpheli satır), bölge, ON-03 ileri konum (`predicted_position`, RTT/2 ≤ tavan), temas sayacı, "?"/"!" histerezisi.
- `entities/npc/components/agenda.gd` (223): görev listesi + **tohumlu `RandomNumberGenerator`** (`agenda_seed`, `owner_tuning.gd:10`, .tres'te sabit), kesme öncelikleri (GÖNDERİLDİ > MÜŞTERİ > DİNLE > ZİL), kalan süre korunur, `sequence` günlüğü.
- `entities/npc/components/npc_mover.gd` (198): `NavigationAgent2D` **kullanmıyor**; `NavigationServer2D.map_get_path` doğrudan (`:127-131`), 0,5 sn / 16 px yeniden yol, harita hazır mı (`map_get_iteration_id > 0`, `:72-74`), kapalı kapı: en uygun kapıya yürü → `Interactable.host_use_by_npc` ile aç (`:138-175`), bağ üzerindeyken yol yenilenmez. Avoidance yok.
- `entities/npc/owner/brain_owner.gd` (**487 satır**, mimari §6 ≲ 400 sınırını aşıyor): 8 durum, tek `match`; kesme API'si (`serve_customer`, `send_to_backroom`, `ring_bell`, `hear`) yalnız AGENDA'da; `hear()` yalnız DİNLE kesmesi (ölçere +30 yok); `detections` kaydı (band, mode, lit, t_question, t_detect, rtt, dist, behaviour, `flagged`).
- `entities/npc/chaser/brain_chaser.gd` (126): RUN/CHASE/SEARCH/WAIT; her adımda tüm oyunculara ışın.
- `entities/npc/store_alert.gd` (185): uyarı merdiveni de `Fsm` (I4 kenar kümesi), komşu sayaçları, `MultiplayerSpawner`.
- `entities/npc/components/npc_visual.gd` (128): koni, "?"/"!", balon, tutma bağı — istemcide çoğaltılandan çizim.
- `tests/fixtures/npc_stage.gd`: yalıtık harita + **sabit adım** (1/60), `auto_step=false`, uzak oyuncu kopyaları → determinist birim sahnesi.

**Botlar ve hata ayıklama**
- `entities/player/bot_timeline.gd`: zaman çizelgeli, **açık döngü** girdi (dünyayı okumaz).
- `project.godot:100` `toggle_debug` (F3) tanımlı; kodda yalnız `tests/unit/test_smoke.gd` referans veriyor → hiçbir katmana bağlı değil. Ortak bir AI/gezinme debug çizimi yok (NpcVisual konisi oynanış görseli).
- Tohum: oyun kodunda `randi/randf/randomize` yok (yalnız `test_player_interpolation.gd:92-93` tohumlu RNG). Oturum düzeyinde tohum kaynağı (Game) yok.

### En iyi uygulamalar ve seçenekler

#### A. Karar mimarisi

| Seçenek | Ne | Artı | Eksi | Kaynak |
|---|---|---|---|---|
| **Düz FSM (elle, core)** | Durum + kenar tablosu; bizim `core/fsm.gd` | Düğümsüz, headless test, değişmezler (I1-I7) `history` üzerinden kanıtlanır; "öngörülebilir tetik" (Goose Game dersi) için en okunur | Kesmeler/alt durumlar büyüyünce tek `match` şişer (brain_owner 487 satır); aynı "tepki" zinciri her beyinde tekrar | GAIP3 §12 (Graham, hafif FSM) [O] |
| **Hiyerarşik FSM (HFSM)** | Üst durum {AJANDA, TEPKİ, ALARM}, her birinde alt FSM; kesmeler üst düzeyde | Bizdeki örtük iki katmanı (Agenda kesmeleri + tepki FSM'i) açık hale getirir; alt makineler tek tek test edilir; chaser/müşteri aynı TEPKİ alt makinesini paylaşır | Küçük ek karmaşıklık; geçiş tablosu iki seviyeli | GAIP3 §11 (FFXV: BT + FSM karışımı) [O]; LimboAI `LimboHSM` iç içe [O] |
| **Davranış ağacı — Beehave** | GDScript, MIT, v2.9.3 (2026-08-18, Godot 4.7; 4.7.1 singleton çakışması düzeltmesi) [O] | Saf GDScript, editör + debugger, topluluk büyük (3,3k yıldız) | Düğüm ağacıyla tik'ler (sahne bağımlı → düğümsüz core testi zor); motor sürümü değişince kırılma geçmişi var (4.7.1 düzeltmesi); KR-018 "çatı yok" ile çelişir | github.com/bitbrain/beehave [O] |
| **Davranış ağacı — LimboAI** | C++ GDExtension, MIT, v1.8.1 (2026-08-20, Godot 4.7.2; 4.6 build'i de var), BT + HSM + blackboard + görsel debugger [O] | Olgun, hızlı, HSM de verir | Platform başına yerel ikili (Windows/Linux export + CI indirmesi, `tools/get_godot.sh` benzeri ek adım); motor sürüm kilidi; davranış dosyaları Resource (diff zor) | github.com/limbonaut/limboai [O] |
| **Utility AI** | Her seçenek için puan (eksenler/eğriler), en yüksek kazanır; IAUS (Mark & Lewis), Dual-utility (Dill) | Hedef seçimi ("en şüpheli oyuncu"), ajanda görev seçimi, chaser hedefi için doğal; veri güdümlü | Bütün beyin için **öngörülemez** (oyuncu "neyin neyi tetiklediğini" öğrenemez); değişmezleri yazmak zor | GAIP1 §9-10, GAIP2 §3, GAIP3 §13, §31 [O] |
| **GOAP / HTN** | Hedef + eylem ön/son koşulları, planlayıcı | Esnek, yeniden kullanılabilir eylemler | Bizim NPC'lerin hedefleri sabit sıralı; planlama okunabilirliği düşürür, hata ayıklama ağır; 1-6 NPC için gereksiz | GAIP1 §12, GAIP2 §13 [O] |

[G] Küçük NPC sayısı (≤ 6), değişmez odaklı denetim (I1-I7) ve KR-018 ("çatı yok", bileşim) birlikte düşünülünce: **düz FSM'i koru, iki katmanı açık HFSM-lite yap, utility'yi yalnız seçim fonksiyonu olarak core'a koy** (GAIP1 §10 "utility'yi var olan BT'ye göm" kalıbının FSM karşılığı). BT eklentisi ancak T4 muhafızı (devriye + telsiz + çok noktalı arama + rol dağılımı) 12+ durumu aşarsa yeniden değerlendirilir.

#### B. Algı ve farkındalık (teknik dersler)
- **Thief (Leonard 2003)** [O]: iki duyu (görüş: koni + ışın; duyma: dünya geometrisinde yayılan, anlam etiketli ses); farkındalık ayrık kademeler; **"sense link"** = NPC↔varlık/konum bağı (zaman, konum, görüş hattı önbelleği) = NPC'nin hafızası; görünürlük = ışık × hareket × açıklık (boyut/ayrışma); ışık **oyuncunun ayağının dibine** göre (oyuncu güvenliğini okuyabilsin); "kondansatör" sönümü (ara kademelerden geçerek iner); kademe yükselmesinde zaman gecikmesi **şimdiki kademenin özelliği** (tepki payı); duyu sistemi CPU bütçesinin önemli kısmı.
- **Splinter Cell Blacklist (Walsh, GAIP2 §28; GDC 2014)** [O]: görüş şekilleri (yakın koni + geniş çevresel kutu + arka "altıncı his"), tespit sayacı mesafeyle ölçekli, ekran dışı NPC'nin duyması ½ (adalet), "simülasyonun ne gördüğü değil, oyuncunun NPC'nin ne görmesi gerektiğini düşündüğü" ilkesi, sınır titremesi = tutarlılık + geri bildirim.
- **Mark of the Ninja (Miles, GAIP1 §32)** [O]: ilgi öncelikleri, eşitlikte en yeni; ses yol bulmayla yayılır; grup rolleri. (Tasarım tarafı `tasarim/arastirma/muhafiz-davranisi.md` §1'de; burada yalnız teknik yapı.)
- **Crytek Target Tracks (Welsh, GAIP1 §31)** [O]: uyaran (**stim**: tür, kaynak, konum, yarıçap) → tek giriş noktası (perception manager) → hedef başına **track**; her stim türü için **ADSR zarfı** (attack süresi, peak, sustain oranı, release); türe göre peak (ayak sesi 25, silah 50, birincil görüş 100); mesafe çarpanı; **pulse** (koddan geçici artış, ör. kovalanan hedefi öncelikli tutmak); threat level = peak oranı; hepsi XML veri. Maliyet: önce "düşman mı" ve koni testi, ışın **asenkron** (sonuç aynı karede şart değil); 16 ajanda 136 → 16 ışın.
- Bize karşılığı [G]: `SuspicionMeter` zaten tek hedef-track'tir (dolum = attack, boşalma = release, kesinti toleransı = sustain). Eksik olan **ses uyaranının aynı ölçere "pulse" olarak girmesi** (GDD §6.1/§9.3: gürültü +30) ve "sense link" alanları (son görülen konum **+ zaman + hız**) — bugün `_last_seen` yalnız konum.

#### C. Godot 4.7.2 NavigationServer2D
- **Eşitleme** [O]: setter'lar kuyruklanır, **bir sonraki fizik karesinin sonunda** uygulanır; sorgular (`map_get_path`) o ana kadar eski veriyi görür. Harita ilk eşitlenene kadar yol boştur → `map_get_iteration_id > 0` beklenir (bizde `npc_mover.gd:72-74`). `map_changed` sinyali bölge/değişiklik eşitlenince yayılır.
- **`map_force_update` 4.7'de kullanımdan kaldırıldı (deprecated)** [O]: "asenkron güncellemelerle uyumsuz; yalnız tek iş parçacıklı bağlamda, riski size ait". Bizde `test_levels_nav.gd:383` ve `npc_stage.gd:56` çağırıyor (ardından yineleme kimliği bekleniyor; bu yüzden şu an zararsız).
- **Asenkron yineleme** [O]: `map_set_use_async_iterations` / `region_set_use_async_iterations` harita/bölge kurulumunu `WorkerThreadPool` görevinde yapar; testlerde kapatıp fizik karesi beklemek doğru kalıp (zaten yapılıyor). Proje genelinde `navigation/world/map_use_async_iterations` ayarı [?] (varsayılan `true` olduğu belgede ima ediliyor; `project.godot`'ta açıkça yazılı değil).
- **Bağlar (NavigationLink2D)** [O]: `link_connection_radius` varsayılanı **4 px** (`navigation_constants_2d.h`); bağ ucu çokgenin 4 px içinde olmalı. Bizim uçlar kapı yanı karo merkezinde (duvara 16 px, ajan yarıçapı 12 → 4 px pay) — sınırda ama test kanıtlı (`test_levels_nav.gd:134-178`). `enabled=false` da eşitleme bekler (bir kare).
- **Dinamik engel** [O]: `NavigationObstacle2D` iki iş yapar: (a) avoidance (yalnız RVO ajanlarını iter, çokgeni değiştirmez), (b) `affect_navigation_mesh` ile **bake sırasında** oyma — çalışma anında yeniden bake ister ("her değişiklik avoidance haritasını yeniden kurar", sık taşıma pahalı). Kapı için bağ aç/kapa (bizim yöntem) doğru kalıp; obstacle gereksiz.
- **Avoidance / RVO** [O]: ajanlar boş uzayda daireler, navmesh'i ve fizik gövdelerini bilmez; kafa kafaya eşit hızlarda **başarısız**; "yalnız gerçekten ihtiyacı olan ajanlarda aç" (maliyet). Hesap `NavMap2D::step` içinde `WorkerThreadPool` ile (`navigation/avoidance/thread_model/avoidance_use_multiple_threads`), geri çağrılar `active_avoidance_agents` sırasıyla fizik karesi sonunda dağıtılır [O, kaynak kodu]. Her ajan aynı anlık görüntüden bağımsız hesaplandığı için sıra bağımsız görünür, ama çok iş parçacıklı float determinizmi **doğrulanmadı** [?]. Bizde avoidance yok; ≤ 6 NPC ve "NPC oyuncuyu itmez" (GDD §9.2) kararıyla gerek de yok [G].
- **Performans** [O]: maliyeti harita boyutu değil **çokgen sayısı** belirler; **ulaşılamayan hedef** en pahalı sorgudur (`path_search_max_polygons` 4096'ya kadar tarar); her karede yol sorma, hedef yeterince kayınca sor; ajanları **güncelleme gruplarına** böl (aynı karede hepsi sormasın); çalışma anı bake'i arka planda (`bake_from_source_geometry_data_async`). Bizde 0,5 sn/16 px eşiği var; grup kaydırması yok; ulaşılamayan hedefte `_failed` koşulu dar (aşağıda).
- **Headless** [O]: `--headless` + `-s` betik; `--fixed-fps N` gerçek zaman eşitlemesini kapatır (deterministik delta); `--time-scale`; `--quit-after`. Hepsi 4.7 komut satırı belgesinde.
- **Debug** [O]: `--debug-navigation`, `--debug-avoidance`, `--debug-paths` bayrakları; `NavigationServer2D.set_debug_enabled(true)`; görünüm `debug/shapes/navigation/*`. **Yalnız debug build'de**; "görselleştirme SceneTree düğümlerine dayanır" → `map_get_path`'i doğrudan çağıran `NpcMover` yolu `--debug-paths`'te **görünmez** (o NavigationAgent2D içindir).

#### D. Kalabalık / ambient NPC
- Hitman Absolution G2 (GDC 2012) 1200 kişilik kalabalık; Hitman 2 1700 karakter, uzaktaki ajanlar basit modele düşer, gerekince tam NPC'ye "terfi" (AI LOD) [O]. GAIP1 §14 (LOD Trader: bütçeye göre ajan detay seçimi), §36 (arka plan karakterleri), GAIP2 §11 (smart zone: alana bağlı ambient davranış), GAIP3 §34 (1000 NPC @ 60 FPS) [O].
- Sims/smart object kalıbı [O/G]: nesne, "ne yapılabilir + nasıl" bilgisini kendisi taşır; NPC nesneden görev çeker. Bizde `AgendaTask` sahibin tuning'inde (`owner_tuning.gd:12`), nokta konumu seviyeden (`marker_positions`). Mekân değişince (T2 benzinlik) görev listesi tuning'de yeniden yazılır; görev verisi **seviye işaretine** taşınırsa (AgendaSpot) yeni mekân = yeni düzen dosyası.
- Bizim ölçek [G]: üst sınır 6 NPC (GDD §9.2) → LOD gereksiz; önemli olan **çoğaltma disiplini** (NPC başına tek özet, 15 Hz, değişince güvenilir; `SuspicionSync` + sahibin kendi `net_*` alanları şu an **iki kanal**, `max_level` ile `net_meter` yarı yineleniyor) ve `MultiplayerSpawner` üretim maliyeti (sahne örnekleme ≈ ms; 1-2 komşu için önemsiz). T5+ (20-40 sivil) için "simülasyon katmanı" notu: ekip görüşü dışındaki NPC yalnız ajanda tik'ler, algı/ışın kapalı, 5 Hz çoğaltma — bugün uygulanmaz (KR-020).

#### E. Determinizm ve tohum
- `RandomNumberGenerator` PCG32; aynı tohum → aynı dizi; `state` kaydedilip geri yüklenebilir; `randomize()` çağrılmazsa global de deterministtir ama sürüm/platform garantisi **belgede yok**; forum (2026-03) platformlar arası aynı diziyi varsayıyor, **float determinizmi (FMA/SIMD) ele alınmamış** [O/?].
- Bizim ihtiyaç [G]: I6 "aynı tohum + aynı bot → aynı olay günlüğü" yalnız **host'ta, tek süreçte, sabit adımla** gerekir (S2: istemci simüle etmez). `npc_stage.gd` bunu sağlıyor (sabit 1/60, `auto_step=false`, uzak oyuncu kopyası). Ağ duman testlerinde (gerçek süreçler, RTT) determinizm beklenmez; orada istatistik (200 koşu) doğru ölçü.
- Eksik: oturum tohumu. `agenda_seed` .tres'te sabit → her maç aynı ajanda (oyuncu ezberler; KR-009 tohumlama Faz 3'e alındı). Doğru kalıp: host `session_seed` seçer (ya da `--seed=`, S6), katılana çoğaltır, her sistem `hash(session_seed, &"agenda")` türevini kullanır, dökümde `seed` yazılır; oyun kodunda global `randi()` yasak (bugün zaten yok).
- Fizik: 2D fizik varsayılan ana iş parçacığında (`physics/2d/run_on_separate_thread=false`) → `move_and_slide` sırası deterministik [?, varsayılan ayar; project.godot'ta yazılı değil].

#### F. Hata ayıklama görselleştirme
- GAIP3 §3 (FFXV günlük görselleştirme), §6 (anında geri sarma/"scrubbing": durum geçmişi + zaman) [O]. Blacklist/Welsh: her geçişin görünür geri bildirimi hem oyuncu hem geliştirici için [O].
- Bizde: `Fsm.history` zaman damgasız; `detections`/`rescues`/`sequence` dökümde var; ekranda yalnız oynanış görseli (koni, "?"/"!"). `--screenshot-at` (IS-022) var → debug katmanı açıkken ekran görüntüsü denetçi kanıtı olur [G].

#### G. Bot oyuncular (IS-015)
- Endüstri [O]: The Division "Client Bots" (GDC 2019) — insan girdisini taklit eden bot katmanı, görev tamamlama + performans/rapor; DICE AutoPlayers — 64 kişilik soak + betikli vakalar (RL değil, betikli bot); modl.ai / Sea of Thieves benzer. Ortak nokta: bot = **girdi katmanına takılan** beyin (oyun kodu değişmez) + rapor.
- Skarupke (GAIP Online 2021 §1) [O]: AI hatalarının çoğu **iki karakterle** yeniden üretilir; test = "X, N sn içinde olsun" (zaman aşımlı bekleme, kesin kare değil); test düzeni içerikte (seviye), kod kısa; duraklat / yeniden başlat / tekrarla özellikleri nadir hatayı yakalar; yavaş ve "her şeyi" test eden testler bakım yükü, yalnız yeni özellik ya da hata yeniden üretimi için yaz; görüşü dinamik test et (duvar arkasına yürü → görmemeli → inceleme → tekrar görmeli).
- Bize [G]: `BotTimeline` açık döngü; IS-015 repertuvarı ("pencere bekle", "GÖNDER + kasa", "kaç") **dünyayı okuyan** kapalı döngü ister. Bot beyni: `PlayerInput` sağlayıcısı (S5/S6'ya uyar), kendi `Fsm`'i, istemcide `NavigationServer2D.map_get_path` (bölge her peer'da var) → hareket vektörü; okuduğu şey yalnız **çoğaltılan** durum (`net_task`, `bubble`, kendi bölgesi, `alert_level`) — hile yok, 150 ms'de gerçek oyuncu gibi geç görür. İstatistik dökümü: outcome, süre, ilk "?" anı, yakalanma, `flagged` sayısı.

### Bizim yapımıza uygunluk değerlendirmesi
- Düğümsüz core + bileşen beyin (KR-018, S11) ile en iyi örtüşen seçenek **FSM/HFSM-lite + core'da puanlama fonksiyonları**. Eklenti (Beehave/LimboAI) KR-018'in "çatı yok" ve tek ikili/CI sadeliğiyle çelişir; kazanımı (editör, debugger) bizim headless/denetçi akışında düşük [G].
- Gezinme: sunucuyu doğrudan kullanan `NpcMover` (ajan düğümü ve avoidance yok) determinizm, test ve S2 (yalnız host) için doğru; 4.7 belgeleriyle çelişen tek şey `map_force_update` [O].
- Algı: Crytek/Thief'in "tek ölçer, farklı uyaranlar" modeli bizim `SuspicionMeter`'a doğrudan eklenir; ayrı bir "stim manager" gerekmez (6 NPC).
- Determinizm: sabit adımlı fikstür var; eksik olan tohum borusu — Faz 3 kalemi (KR-009) ama borusu küçük.
- Bot: mevcut `PlayerInput` soyutlaması (S5) tam da Division/DICE kalıbı; eksik olan beyin.

### Bulgular
**Doğru yaptıklarımız**
1. Kurallar düğümsüz (`PerceptionRules`, `SuspicionMeter`, `CivilianRules`, `Fsm`) → Skarupke'nin "koni testini 0 ms'de yaz" ölçütü karşılanıyor; `test_perception/suspicion/fsm/civilian` bunun kanıtı.
2. Koni testi ışından önce (`perception.gd:125-129`); oyuncu/NPC gövdeleri maskede değil; görüşü geçiren cam ayrı gövde — Crytek maliyet sırası.
3. 0,2 sn pay + 0,2 sn kesinti toleransı + koni histerezisi (US-008 wt `perception.gd:18-22`) Blacklist "1 cm" sorununun doğru çözümü.
4. Kapı = bağ aç/kapa (obstacle değil); bake üretim anında, deterministik ve testte karşılaştırmalı (`test_levels_nav.gd:112-117`).
5. `NpcMover` harita hazır olana kadar yol sormuyor; bağ üstünde yenilemiyor; kapıyı NPC açıyor (I7 donmama).
6. Sabit adımlı NPC fikstürü (`npc_stage.gd`) + yalıtık harita = determinist birim sahnesi; `detections.flagged` "beni görmemişti" günlüğü (muhafiz-davranisi §4) uygulanmış.
7. Uyarı merdiveni de `Fsm` kenar tablosuyla (I4 kümesi) — aynı sınıf, aynı test yöntemi.

**Saptığımız yerler**
1. **`map_force_update` 4.7'de deprecated** [O] — `test_levels_nav.gd:383`, `npc_stage.gd:56`. Şu an yineleme bekleme sayesinde çalışıyor; ileride kaldırılırsa testler kırılır.
2. `brain_owner.gd` 487 satır (mimari §6 ≲ 400): ajanda kesmeleri (`agenda.gd`) ile tepki FSM'i **örtük iki katman**; HOLD/STAGGER/kurtarma mantığı ayrı bileşene çıkmadan dosya küçülmez.
3. Görüş hattı kodu iki kopya (`perception.gd:156-172` ↔ `sight_line.gd:18-34`); `sight_line.gd:7` birleşmeyi vaat ediyor, US-008/US-009 birleşmesinde yapılmazsa kalıcılaşır.
4. Ses uyaranı ölçere girmiyor: `brain_owner.hear()` yalnız DİNLE kesmesi; GDD §6.1/§9.3 "gürültü +30 '?'" `apply_delta` ile mümkün ama bağlı değil, günlüğü (I2 istisnası) yok.
5. Algı 60 Hz (`suspicion.gd:40-43`): tasarım 15-20 Hz örnekleme varsayıyor (muhafiz-davranisi §4); 6 NPC × 3 oyuncu × 60 = ~1080 ışın/sn — bugün sorun değil, ama `gap_tolerance` 0,2 sn ile örnekleme aralığı ilişkisi tek sabitte değil.
6. Tohum: `agenda_seed` .tres sabiti; oturum tohumu, `--seed`, döküm `seed` yok.
7. `Fsm.history` zaman damgasız → I3 (süre değişmezleri) yalnız canlı `time_in_state` ile; dökümden "scrubbing" yapılamaz.
8. `NpcMover._plan` (`:104-120`): yol hedefe varmıyor ve açılacak kapı yoksa `_failed` yalnız `path.size() < 2` iken `true`; kısmi yol (en yakın çokgen noktasına) varsa yol bitince `desired_velocity` **düz çizgi** ile hedefe iter (`:98-99`) → duvara yaslanma (I7 "duvar içi yok" bozulmaz ama NPC duvarı itekler, `arrived()` olmaz) [G].
9. `toggle_debug` (F3) boşta; `--debug-paths` bizim yolu göstermez; NPC iç durumu (ölçer, görev, kalan süre, yol) ekranda yok.
10. Çoğaltma: NPC başına iki eşitleme kanalı (`SuspicionSync` + sahibin `net_*`); küçük ama ileride her NPC türünde tekrarlanır.

**Riskler**
- Eklenti kararı verilmeden T4 muhafız FSM'i büyürse "BT'ye geçelim" tartışması kodun ortasında çıkar → şimdi KR olarak kapatmak ucuz.
- Avoidance açılırsa (ileride kalabalık) çok iş parçacıklı RVO'nun determinizmi [?] I6'yı bozabilir; açılacaksa `avoidance_use_multiple_threads=false` ile ölçülmeli.
- Asenkron harita yinelemesi açıkken kapı bağı kapanması ile NPC yolu arasında 1-2 karelik tutarsızlık; `_on_link` koruması var ama hızlı kapı kapanmasında NPC kapı karosunda kalabilir (test senaryosu yok) [G].

### Öneriler

| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri (2-3) |
|---|---|---|---|---|---|
| 1 | P1 | XS | altyapi (test), oynanis (fikstür) | **Gezinme testlerinde `map_force_update`'ten vazgeç** | (a) `test_levels_nav.gd` ve `npc_stage.gd` yalnız `*_set_use_async_iterations(false)` + fizik karesi/`map_get_iteration_id` bekler; (b) deprecated API çağrısı sıfır (grep); (c) ci_local yeşil, test süresi artmaz (ölçülür). |
| 2 | P1 | S | oynanis | **HFSM-lite + zaman damgalı geçmiş** (`core/fsm.gd` + beyin bölünmesi) | (a) `Fsm` geçmişi `(t, from, to)` tutar ve dökümde `states` olarak çıkar; I3 testleri bu günlükten; (b) `brain_owner.gd` ≤ 400 satır: HOLD/STAGGER/ÇEK mantığı `owner_hold.gd` (ya da ortak `npc_react.gd`) bileşenine, chaser aynı tepki kodunu paylaşır; (c) mevcut `test_fsm/owner/chaser` değişmeden geçer. |
| 3 | P1 | S | oynanis | **Uyaran birleştirme: `SuspicionMeter.pulse()` + Hearing → şüphe** | (a) core'da `pulse(amount)` (ADSR "pulse": anında artış, normal boşalma) + yukarı geçilen eşikleri döner; (b) `Hearing.heard` → beyin `apply_pulse(+N, kind)` (N `civilian_tuning`), olay günlüğe `kind` ile yazılır, I2 testi günlüklü darbeleri dışlar; (c) `noise_t1.json` senaryosu: arka odadaki sahip arka kapı sesinde "?" alır, tezgâhtaki almaz. |
| 4 | P2 | XS | oynanis | **NpcMover ulaşılamayan hedef + grup kaydırma** | (a) yol hedefe varmıyor ve kapı yoksa `failed()=true`, düz çizgi itme yok (birim test: duvar arkası hedef → `failed`, hız 0); (b) yeniden yol zamanı NPC indeksine göre kaydırılır (aynı karede ≤ 2 sorgu); (c) kapı kapanırken bağ üstündeki NPC için senaryo testi (kapı karosunda kalmaz ya da kapıyı yeniden açar). |
| 5 | P2 | S | cekirdek (Game/Args), oynanis (tüketici) | **Oturum tohumu** (`session_seed`) | (a) host seçer (`--seed=` ya da zaman), katılana S3 ile çoğaltılır, dökümde `seed`; (b) `Game.derive_seed(&"agenda")` türevleri; `Agenda`/nüfus bunu kullanır, `.tres` tohumu kalkar; (c) aynı seed + aynı bot → `owner.agenda` ve `states` birebir (I6), farklı seed → farklı dizi (birim test). **Karar gereken** (KR-009 tohumlamayı Faz 3'e koyar; yalnız boru 2b'ye alınabilir). |
| 6 | P2 | S | arayuz (çizim) + oynanis (veri) | **AI hata ayıklama katmanı (F3 / `--debug-ai`)** | (a) `toggle_debug` → her NPC üstünde durum adı, görev + kalan süre, oyuncu başına ölçer çubuğu, yol çizgisi (`NpcMover.path()` getter), son görülen işaret, uyarı merdiveni; (b) istemcide çoğaltılandan, host'ta ek olarak yol/ölçer; release build'de kapalı; (c) `--screenshot-at` ile katman görüntüsü alınır (denetçi kanıtı). |
| 7 | P2 | M | cekirdek (kalem IS-015 sahibi) + oynanis (beyin) | **Bot beyni (kapalı döngü) + istatistik** | (a) `entities/player/bot_brain.gd`: `PlayerInput` sağlayıcısı, `Fsm` {BEKLE_PENCERE, KASAYA_GİT, TUT, KAÇ, KAÇIN}, istemci tarafı `map_get_path` → hareket; yalnız çoğaltılan durumu okur; (b) `--bot=brain:<repertuvar>` (S6 eki) ve döküm `bot: {outcome, t_first_notice, caught, stuck_sec}`; (c) net_smoke ile 2 ve 3 bot × N koşu özet JSON'u (temiz oranı, yakalanma, `flagged`), bot 10 sn'den uzun takılmaz. |
| 8 | P3 | XS | oynanis | **Görüş hattı tekilleştirme** (`Perception` → `SightLine`) | (a) `perception.gd` kendi ışın döngüsünü silip `SightLine.first_blocker` kullanır; (b) `test_perception_components` ve `test_noise*` değişmeden geçer. US-008/US-009 birleşmesinde. |
| 9 | P3 | XS | oynanis | **Algı örnekleme 20 Hz + tek sabit** | (a) `Suspicion.tick` her 3. fizik karesinde, NPC'ler kaydırmalı; `gap_tolerance ≥ 2 × aralık` koşulu testte; (b) AC3 süre testleri ±1 örnek toleransla aynı. |
| 10 | P3 | S | seviye + oynanis (Faz 4) | **Smart spot: ajanda görevi seviye işaretinde** (`AgendaSpot`) | (a) `Markers` altında görev verisi (süre aralığı, bakış, koni, zil keser mi) taşıyan düğüm; `Agenda` listeyi seviyeden çeker; (b) T2 benzinlik için kod değişmeden yeni ajanda; (c) store_a aynı diziyi üretir (regresyon). |
| 11 | P3 | — | koordinatör (mimari §7 notu) | **T5+ simülasyon katmanı notu** (ekip görüşü dışındaki NPC: yalnız ajanda, algı kapalı, 5 Hz) | Bugün uygulanmaz; mimari §7'ye bir satır. |

### Karar gereken (koordinatöre)
1. **Eklenti yok** kararı KR'ye yazılsın mı: davranış mimarisi `core/fsm.gd` (HFSM-lite) + core puanlama; Beehave/LimboAI T4 muhafız kalemine kadar gündem dışı. Öneri: evet.
2. Oturum tohumu borusu (öneri 5) Faz 2b'ye mi, KR-009 gereği Faz 3'e mi? Öneri: boru 2b (XS-S), rastgeleleştirme içeriği Faz 3.
3. Bot beyni sahipliği: backlog IS-015 cekirdek; FSM/algı bilgisi oynanis'te. Öneri: beyin oynanis, koşu/istatistik aracı cekirdek (iki paket).
4. NPC avoidance: resmen **yok** (NPC oyuncuyu itmez, NPC-NPC örtüşmesi kabul). Öneri: evet, T5 kalabalığında yeniden bak.

### Sonraki tur için açık sorular
- Çok iş parçacıklı RVO'nun float determinizmi (yalnız avoidance açılırsa gerekir) [?].
- `navigation/world/map_use_async_iterations` varsayılanının 4.7.2'de `true` olduğu ve `project.godot`'ta açıkça yazılmasının gerekip gerekmediği [?].
- 2D fizik ana iş parçacığı varsayımı (`physics/2d/run_on_separate_thread`) ve `move_and_slide` determinizmi ölçümü (aynı tohum, 10 koşu, konum birebir?) [?].
- T4 muhafız: Welsh arama (kapsama noktaları, 2-3 arayan, rol dağılımı) için veri yapısı — FSM mi yoksa burada ilk BT gerekçesi mi?
- 6 NPC × 150 ms çoğaltma ölçümü (KB/sn, soak) ve tek "NpcSync" kanalına birleştirme.
- `--fixed-fps` ile net_smoke süreçlerinin uyumu (gerçek zaman kapalıyken RTT proxy'si).

### Kaynaklar
- Godot 4.7 belgeleri: NavigationServer2D sınıfı (map_force_update deprecated, async iterations, iteration id, avoidance callback) — https://docs.godotengine.org/en/4.7/classes/class_navigationserver2d.html · Using NavigationServer (eşitleme, iş parçacığı havuzu) — https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationservers.html · NavigationAgent (RVO sınırları) — https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_using_navigationagents.html · NavigationObstacle2D — https://docs.godotengine.org/en/4.7/classes/class_navigationobstacle2d.html · Performans — https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_optimizing_performance.html · Debug araçları — https://docs.godotengine.org/en/4.7/tutorials/navigation/navigation_debug_tools.html · Komut satırı (`--fixed-fps`, `--debug-*`) — https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html · RNG (PCG) — https://docs.godotengine.org/en/4.7/tutorials/math/random_number_generation.html
- Godot kaynak kodu 4.7.2-stable: `servers/navigation_2d/navigation_constants_2d.h` (LINK_CONNECTION_RADIUS 4, path_search_max_polygons 4096) — https://github.com/godotengine/godot/blob/4.7.2-stable/servers/navigation_2d/navigation_constants_2d.h · `modules/navigation_2d/nav_map_2d.cpp` (avoidance WorkerThreadPool, callback sırası) — https://github.com/godotengine/godot/blob/4.7.2-stable/modules/navigation_2d/nav_map_2d.cpp
- Godot forum, RNG platformlar arası (2026-03) — https://forum.godotengine.org/t/is-random-deterministic-between-platforms/135974
- LimboAI (MIT; v1.8.1 2026-08-20, Godot 4.7.2) — https://github.com/limbonaut/limboai/releases · https://limboai.readthedocs.io/en/stable/
- Beehave (MIT, GDScript; v2.9.3 2026-08-18, Godot 4.7) — https://github.com/bitbrain/beehave/releases
- Leonard, "Building an AI Sensory System: Examining the Design of Thief: The Dark Project" (2003) — https://www.gamedeveloper.com/programming/building-an-ai-sensory-system-examining-the-design-of-i-thief-the-dark-project-i-
- Walsh, "Modeling Perception and Awareness in Splinter Cell Blacklist", Game AI Pro 2 §28 — https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy%27s_Splinter_Cell_Blacklist.pdf · GDC 2014 — https://gdcvault.com/play/1020195/Modeling-AI-Perception-and-Awareness
- Welsh, "Crytek's Target Tracks Perception System", Game AI Pro 1 §31 — http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter31_Crytek's_Target_Tracks_Perception_System.pdf
- Miles, "How to Catch a Ninja", Game AI Pro 1 §32 — https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter32_How_to_Catch_a_Ninja_NPC_Awareness_in_a_2D_Stealth_Platformer.pdf
- Game AI Pro dizini (BT: 1§6-7, 3§9; HFSM: 3§11-12; utility: 1§9-10, 2§3, 3§13, 3§31; planlama: 1§12, 2§13; ambient/LOD: 1§14, 1§36, 2§11, 3§34; debug: 3§3, 3§6; arama: 2§27) — https://www.gameaipro.com/
- Skarupke, "Automated AI Testing: Simple tests will save you time", Game AI Pro Online 2021 §1 — http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter01_Automated_AI_Testing_Simple_tests_will_save_you_time.pdf
- Dave Mark / Mike Lewis, Infinite Axis Utility System — https://gameai.com/iaus.php
- Ubisoft Reflections, The Division "Client Bots" (GDC 2019) — https://80.lv/articles/gdc-using-ai-controlled-players-to-test-the-division/ · EA/DICE AutoPlayers, "AI for Testing: Battlefield V" (GDC 2019) — https://gdcvault.com/play/1025905/AI-for-Testing-The-Development · Gillberg vd., "Technical Challenges of Deploying RL Agents for Game Testing in AAA Games" (2023) — https://arxiv.org/pdf/2307.11105
- IO Interactive, "Crowds in Hitman" (GDC 2012) — https://gdcvault.com/play/1016518/Crowds-in-Hitman · Hitman 2 ölçeklenebilir dünya (Intel) — https://www.intel.com/content/dam/develop/external/us/en/documents/06-create-a-scalable-and-destructible-world-in-hitman2-807276.pdf
- Proje içi: `docs/tasarim/arastirma/muhafiz-davranisi.md`, `tezgahtar-sindirme.md`, `faz2-bakkal-kalemleri.md`; `docs/notes/mimari.md` S2, S4, S6, S8, S11, §6; GDD §6, §9.2-9.3, §12.
