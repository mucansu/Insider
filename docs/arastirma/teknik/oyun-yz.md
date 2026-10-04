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

---

## Tur 2 — 2026-10-02

### Kapsam
Koordinatörün tur 1 kararları (eklenti yok, HFSM-lite, avoidance yok, tohum borusu 2b/IS-058, bot beyni oynanis) veri alındı. Bu tur beş konu: (1) mekân nüfusu (US-016) için hafif sivil simülasyonu — ambient davranış, rezervasyonlu ilgi noktası (smart object/zone), zamanlama, okunabilirlik, ≤ 6 NPC bütçesi; (2) bakkal etkileşimleri (US-010) için "sosyal gizlilik" kalıbı — host otoriteli etkileşim + NPC beyin kesmesi; (3) bot beyni (IS-015) tasarım taslağı (kapalı döngü, pencere algılama, kaçış); (4) T4 muhafız araması için veri yapısı ve "ne zaman BT" ölçütü (yalnız ileri uyum); (5) Godot 4.7.2 NavigationServer2D/fizik proje ayarı varsayılanları ve `project.godot`.
Okunan kod: `faz2-int` (62af45a) ve US-008 çalışma kopyası (`.claude/worktrees/agent-aad82679a5ece5354`, "US-008 wt"). Godot varsayılanları yerel 4.7.2-stable ikilisiyle headless betikle **ölçüldü** (aşağıda).

### Mevcut durum (dosya:satır)
**Ajanda ve kesmeler (US-008 wt)**
- `entities/npc/components/agenda.gd:44-51` `setup(tasks, seed, resolver)`; `:159-175` `_begin`: işaret dizisinden **tohumla rastgele nokta** seçer (`_spots_for` → `resolver(marker)`), rezervasyon yok (iki NPC aynı `ShopSpot`'u seçebilir); `:187-196` `_next`: yalnız **ev ↔ uzak** dönüşümü (lineer rota yok; müşteri "kapı → raf → kuyruk → kapı" bu makineyle yazılamaz); `:120-134` kesme önceliği `kind < _interrupt` ise ret; `:143-146` `restart_home`.
- `agenda_task.gd:7-20` görev alanları: name, marker, min/max_sec, facing, half_angle_deg, home, bell_interrupts. Görev listesi `data/npc/owner_tuning.gd:12` (`tasks`), tohum `:10`.
- `entities/npc/owner/brain_owner.gd:93-129` kesme API'si (`serve_customer`, `send_to_backroom`, `ring_bell`, `hear`) **yalnız `State.AGENDA`'da kabul** (`:126-129`); `hear()` sese `question_stop` mesafesine kadar yürür (`:114-123`); `_shout` kesmeyi iptal eder (`:281`); QUESTION adımı `:249-273`; `_pick_chase_target` `:383-402` (görünen + DETECT + serbest, süren hedef öncelikli).
- `entities/npc/owner/store_owner.gd:143-160` host API'si: `apply_suspicion(peer, delta)`, `serve_customer()`, `send_to_backroom()`, `reset_loiter(peer)`; `:27-28` `EVENT_KINDS` sabit beş olay (US-010/US-016 olayları yok); `:192-210` olay RPC'si; `:237-248` `_publish` (net_task yalnız AGENDA'da dolu; `net_meter` en yüksek ölçer).
- `entities/npc/components/civilian_senses.gd:65-79` oyalanma sayacı (`_loiter`, yalnız içeride) ve zil (`door_crossed`); `:86-92` `loiter_time/reset_loiter`; `:120-127` `interaction_of` (busy_by → CASH/TAMPER); `:177-189` `marker_positions` (dizi → tüm konumlar); `:193-207` `prop_taken_near`.
- `core/civilian_rules.gd:83-100` aday satırlar (LOITER `loiter_grace` sonrası); örtü çarpanı (`×0,5` müşteri varken) **yok**; `:132-138` `zone_at`.
- `entities/npc/chaser/brain_chaser.gd:109-126` her adımda tüm aktörlere ışın; `:92` kovalama hedefi `_last_seen`; SEARCH 15 sn → WAIT (`:71-77`).
- `entities/npc/store_alert.gd:136-166` komşu üretimi: `_pending` sayaçları, `MultiplayerSpawner.spawn_function` (`_spawn_chaser`), `chasers()` NPCs kökünü tarar; `:179-190` "içeride" kararı.
- Etkileşim: `entities/props/interactable.gd:183-207` `host_start` (requirement + `start_blocker` **peer bağımsız** `func() -> bool`, `:51-53`); `:219-227` `host_use_by_npc` (yalnız anlık, boş, menzilde). `entities/player/player_interaction.gd:80-100` en yakın `can_start` olanı seçer (bir prop'ta iki Interactable varsa seçim mesafeyle; "alt eylem" seçme girdisi yok).
- Oyuncu API'si `entities/player/player.gd:182-221` (`is_free/is_held/is_caught/times_held/host_hold/host_catch/interaction_position`), sinyaller `:40-46` (`rescued`, `status_changed`).

**Bot ve girdi (US-008 wt / faz2-int)**
- `entities/player/player_input.gd:31-39` kaynak seçimi (`Args.bot_path` → `BotTimeline.from_file`), `:52-53` `use_bot(timeline: BotTimeline)` (**somut tip**; başka sağlayıcı takılamaz), `:62-79` `poll`: BOT kaynağı `tick(frame, delta)` + `move_vector/is_held/is_just_pressed`.
- `entities/player/bot_timeline.gd` açık döngü (dünyayı okumaz). `autoload/args.gd:88-90` `--bot=`, `:186` `load_bot`, `:206` `parse_bot_step`; `--seed` yok (IS-058).

**Seviye ve işaretler (faz2-int)**
- `levels/layouts/store_a.txt:28-61`: `StreetRoute1..6`, `NeighbourSpawn`, `WindowLook1..3`, `ShopSpot1..5`, `QueueSpot1..2`, `RestockSpot1..3`, `PhoneSpot`, `BackroomSpot`, `ShelfProp1..3`; bölgeler `CustomerArea` (2 parça), `StaffArea`, `Backroom`. `levels/level.gd:19-77` API (`players_root`, `props_root`, `npcs_root`, `marker`, `marker_sequence`, `zone`, `navigation_region`, `door_link`). Bölge istemcide de var → bot kendi bölgesini `CivilianSenses.zone_rects` (statik, `:45-61`) ile okuyabilir.
- `entities/npc/components/hearing.gd:33-43` (faz2-int): yarıçap → ışın → `heard(pos, effective_radius, kind)`.

**Gezinme / fizik ayarları**
- `project.godot:145-157` (faz2-int): `[navigation]` bölümü **yok**; `[physics]` yalnız `common/physics_ticks_per_second=60`.
- Yerel 4.7.2-stable ile ölçülen varsayılanlar [O] (`ProjectSettings.get_setting` + dünya haritası sorguları, headless): `navigation/world/map_use_async_iterations = true` · `navigation/2d/default_cell_size = 1.0` · `navigation/2d/use_edge_connections = true` · `navigation/2d/default_edge_connection_margin = 1.0` · `navigation/2d/default_link_connection_radius = 4.0` · `navigation/2d/merge_rasterizer_cell_scale = 1.0` · `navigation/avoidance/thread_model/avoidance_use_multiple_threads = true` · `…/avoidance_use_high_priority_threads = true` · `navigation/pathfinding/max_threads = 4` · `navigation/baking/use_crash_prevention_checks = true` · `navigation/baking/thread_model/baking_use_multiple_threads = true` · `physics/2d/run_on_separate_thread = false` · `physics/common/physics_jitter_fix = 0.5` · `physics/common/max_physics_steps_per_frame = 8`; dünya haritasında `map_get_use_async_iterations() = true`, `link_connection_radius = 4`.
- `tests/fixtures/npc_stage.gd:36-45` yalıtık harita, async kapalı; `:54-60` `map_force_update` (IS-064 kapsamında).

### En iyi uygulamalar ve seçenekler

#### A. Hafif sivil simülasyonu (US-016)
| Seçenek | Ne | Artı | Eksi | Kaynak |
|---|---|---|---|---|
| **Zaman çizelgesi / ajanda (schedule)** | Girdi zaman, çıktı "şuraya git + şunu yap"; veri güdümlü **hiyerarşik FSM**; eylem = hedef nesne türü + süre; tehdit gelince çekirdek AI çizelgeyi ezer, bitince kaldığı yerden sürer; geçiş zamanına Gauss gürültüsü ("herkes 18:00'de hana koşmasın") | Bizim `Agenda` tam bu; ucuz, ölçeklenir, "ana NPC AI'ını arka plan karakterine taşıma" uyarısı bizi `brain_owner`'ı müşteriye kopyalamaktan korur | Tek NPC tekdüze; canlılık **farklı çizelgeli birkaç NPC**'den gelir | Graham, GAIP1 §36 [O] |
| **Smart object (slot/claim)** | Nesne "ne yapılabilir"i taşır; ajan slot **claim** eder (Free → Claimed → Occupied → Free), claim tutamacı, bırakmak ajanın sorumluluğu, nesne yok olunca geçersizleme | Aynı rafa iki müşteri gelmez; yeni mekân = yeni işaret verisi | Bir alt sistem (kayıt + sorgu); bizde 6 NPC için sözlük yeter | UE5 Smart Objects belgesi [O]; Sims kalıbı (Forbus) [O] |
| **Smart zone / living scene** | Bölge roller (ana / destek / figüran) + zaman çizelgesi + tetik taşır; NPC bölgeye girince rol alır; kardinalite (juggler 1, seyirci 5 slot); örtüşen bölgelerde öncelik; NPC kendi hedefi baskınsa sahneyi bırakır | "Kuyruk" tam örnek: ilk gelen ana rol (kasa), sonrakiler destek (sırada bekle) | Rol ataması + orkestrasyon motoru; 2 müşteri için aşırı | de Sevin vd., GAIP2 §11 [O] |
| **Smart location + kural tabanlı etkileşim (FFXV)** | STRIPS kuralları ortak blackboard'da; rezervasyon `reserved(X, me)` eyleme **taahhüt anında**, tamamlanma bilgisi **deferred** (bitince); rol kardinalitesi min..max + `dynamicJoin`; konum prop'larına **tek sahip** → eşzamanlılık sorunu yok; eylemler alt FSM/BT ("otur", "git", "konuş") | "Taahhütte rezerve et, bitince bırak" kuralı bizim `Agenda._begin/_end` ile birebir | Kural dili, derleyici — bize yok | Skubch, GAIP3 §35 [O] |
| **Situation (Warhorse / Hitman Absolution)** | Merkezî yönetici min/max aralıkla sahne planlar, CSP ile uygun NPC bulur (≤ 1 ms); NPC **açıkça abone olur**, rol alınca davranışı askıya alınır, bitince kaldığı yerden sürer; yüksek öncelikli davranış (savaş) gelince sahne **herkes için** biter; Hitman: NPC situation nesnesine abone olur, lider/diğer rolü + "ne kadar sert tepki" bilgisi enjekte edilir | Tanık→sahip zinciri ve "müşteri kuyruğu" küçük birer situation; "tehdit sahneyi herkes için bitirir" kuralı bizde `_shout → cancel_interrupt` | CSP gereksiz (NPC ≤ 6) | Černý vd., AIIDE 2014 [O]; Vehkala (Hitman Absolution) aktarımı [O] |
| **Kalabalık FSM (Hitman 2016)** | 1200 kalabalık ajanı için 3 durumlu FSM (idle / walking / pending walk); "behaviour zone" darbesi (panik, yat, kaç); etkileşim türüne göre **anında** ya da **gecikmeli** kesme; tehdit geçince rutine dönüş; LOD | "Anında/gecikmeli kesme" = bizim kesme öncelik tablosu; T5+ kalabalık notu | — | Game Developer, "The AI of Hitman (2016)" [O] |

[G] Bizim ölçek için bileşim: **Agenda (lineer rota kipi eklenmiş) + core'da küçük slot kaydı (`SpotRegistry`: işaret adı → sahibi) + situation-benzeri iki küçük zincir (kuyruk, tanık→sahip)**. Smart zone/kural motoru gerekmez; ama "taahhütte rezerve, bitince bırak" ve "ana rol bitince destek roller düşer" kurallarını aynen alırız.

**Zamanlama ve okunabilirlik (ambient)**
- Graham: geçiş zamanına gürültü [O] → bizim 35 ± 15 sn ve 20 ± 8 sn aralıkları doğru; ek olarak **müşteri üst sınırına ulaşınca gelen beklemez, rota iptal** (GDD §9.2) = Hitman "pending walk" düşürme.
- Welsh (GAIP2 §27): dikkat dağıtma ("cautious" uyaran) için **tek araştırmacı** kuralı; diğerleri ilgiyi kaybeder; geçiş **telegraf** edilmeli (diyalog/animasyon) [O] → bizde sahip yürür, müşteriler yalnız 2 sn bakar (GDD §9.3 DİKKAT DAĞIT) — kalıpla uyumlu.
- Blacklist/Welsh (tur 1): her geçiş görünür → müşteri/yoldan geçen "?" balonu (US-016 AC3) ve yoldan geçen konisi **yalnız bakarken** (US-011 notu) doğru.
- Monaco / Invisible Inc / Teleglitch için birincil kaynak (postmortem, GDC) **bulunamadı** [?]; yalnız inceleme/forum düzeyi. Dishonored 2 GDC 2017 ("Taking Back What's Ours") NPC koordinasyonu + arama için uzamsal akıl yürütme içeriyor [O, özet düzeyinde]; ayrıntı T4 turunda.

#### B. Sosyal gizlilik mekaniği (US-010)
- **Hitman**: dikkat dağıtma = uyaran → en yakın NPC araştırır → rutine döner; etkileşim türüne göre anında/gecikmeli [O]. **Payday 2**: bağırma sivili **geçici** yatırır, bir süre sonra kalkar; panik düğmesine **tek deneme** (kesilirse yinelemez); kelepçe kalıcı [O, wiki/forum düzeyi]. Çıkarım [G]: "etkisi zamanla sönen, tekrarda azalan uyum" kalıbı bizim OYALA (−40 / −20 / 0) ve "bağırıştan sonra işlemez" kuralıyla aynı; GÖNDER "iş başına 1" = Payday "tek deneme".
- **Kalıp (bize)**: `Interactable.completed(peer)` (host) → prop betiği → `StoreOwner` host API'si → `OwnerBrain` kesmesi (`Agenda.interrupt`) → `host_event` ile her peer'da aynı sırada olay (balon/SFX). İstemci sonuç üretemez (S2/S7); bot da aynı yoldan geçer. Eksikler aşağıda (Bulgular 2-6).

#### C. Bot beyni (IS-015) — kapalı döngü taslağı
- Endüstri [O]: Borovikov (GAIP Online 2021 §10, EA): ajan **oyuncunun kullandığı arayüzü** kullanır (eylemler programatik API'den, oyun kodu "koşullu derlenen" küçük bir kanca); rastgele/açgözlü politika bile **göreli** ölçütleri (zorluk sırası) optimize politikayla aynı verir; softmax "sıcaklığı" = oyuncu becerisi; ölçüm kısmi durum güncellemeleriyle tabloya yazılır; "tasarıma ajanla başla". Division/DICE (tur 1): girdi katmanına takılan bot + rapor. Rebellion GDC AI Summit: planlayıcı + BT ile otomatik test [O, başlık düzeyi].
- Taslak [G] (sahip oynanis, araç cekirdek; KR tur 1):
  1. **Takma noktası**: `PlayerInput.use_bot()` somut `BotTimeline` yerine duck-typed sağlayıcı (`tick(frame, delta)`, `move_vector()`, `is_held(a)`, `is_just_pressed(a)`); `BotTimeline` ve yeni `BotBrain` aynı arayüzü sunar. `--bot=brain:<repertuvar>[,skill=0.7]` (S6 eki; `Args.bot_path` ayrıştırması `args.gd:88-90`).
  2. **Okuduğu şey (yalnız çoğaltılan / yerel)**: kendi konumu + bölgesi (`CivilianSenses.zone_rects(level)` statik, istemcide de çalışır); sahip `net_position/net_facing/net_task/net_state/net_alarmed/bubble` (`store_owner.gd:44-55`) ve `cone_half_angle()`; `Game.alert_level()`, `Game.player_world_position(peer)`, `Game.team_cash`; `Interactable.busy_by/enabled` ve `PlayerInteraction.target_key()`; kendi `is_held/is_caught`. Hile yok: 100-150 ms geç görür, oyuncu gibi.
  3. **Pencere algılama**: "sahip kasayı görebilir mi?" = `PerceptionRules` koni testi (core, statik) sahibin çoğaltılan konum/yönü ve `cone_half_angle()` ile + istemci fizik ışını (`SightLine.first_blocker`, world + vision_block istemcide de var) Register işaretine. Ek tetik: `net_task ∈ {restock, backroom, phone}` ya da `net_task == &"customer"/&"sent"` → "pencere açık"; kapanış tahmini `time_left` çoğaltılmıyor → bot, kasa süresi (3 sn) + yürüme süresini (yol uzunluğu / hız) pencere görev **min süresiyle** (veri, `owner_tuning.tasks`) karşılaştırır.
  4. **FSM** (`core/fsm.gd`): `DISGUISE` (müşteri bölgesinde ShopSpot'lar arasında yürü; oyalanma 60 sn'e yaklaşınca SATIN AL) → `WAIT_WINDOW` → `GO_REGISTER` (tezgâh ucundan; istemci `NavigationServer2D.map_get_path`, harita hazır kontrolü `map_get_iteration_id > 0`) → `EMPTY` (`interact` basılı, `target_key()` beklenen anahtar olana kadar konumlan) → `ESCAPE` (`EscapeZone`); kesmeler: `bubble == ALARM` ya da `alert ≥ 2` → `FLEE` (en uzak kapı, koşu); `is_held` → girdi yok; `SEND` repertuvarı: Counter müşteri tarafı → GÖNDER → takım arkadaşı için pencere. Rol = slot (1 müşteri/gönderen, 2 kasacı, 3 arka odacı) — mesajlaşma gerekmez, herkes çoğaltılanı okur.
  5. **Takılma**: 3 sn'de < 4 px ilerleme → yeniden yol / hedef değiştir; 10 sn → `stuck` sayacı (AC'de "bot 10 sn'den uzun takılmaz").
  6. **Beceri ve determinizm**: tepki gecikmesi ve "pencere eşiği" `skill`'den; RNG `hash(session_seed, slot)` (IS-058); host sabit adımda aynı seed → aynı günlük (I6 kapsamı tur 1'deki gibi).
  7. **Döküm** `bot: {repertoire, outcome, t_first_notice, windows_seen, windows_taken, caught, held, stuck_sec, flee_count}`; net_smoke toplayıcı (cekirdek) 2/3 bot × N koşu → temiz oranı, yakalanma, `flagged`.
- Alt eylem sorunu [?]: Counter'da SATIN AL ve GÖNDER iki Interactable; `PlayerInteraction._select_target` **en yakını** seçer → oyuncu/bot ikinciyi nasıl seçer (ayrı konum, `intimidate` tuşu "alt eylem", ya da istem döngüsü)? US-010 kararı; bot bu karara bağlı.

#### D. T4 muhafız araması (ileri uyum notu)
- Welsh (GAIP2 §27) [O]: iki tür — **cautious** (uyaran, kaynak bilinmiyor; yürüyerek, yalnız 1. faz, tek araştırmacı) ve **aggressive** (hedef biliniyor; koşarak, 1+2. faz, 2-3 eşzamanlı). Faz 1 = son bilinen konum (LKP); görüş kaybında **2-3 sn daha konumu "bilme"** (Halo/Crysis/Crackdown hilesi; dış değerleme yerine). Faz 2 = **search coordinator**: arama noktası havuzu (LKP'den gizli örtü/köşe noktaları; yetmezse navmesh'te LKP'den görünmeyen rastgele noktalar); nokta durumu {free, in_progress, searched}; yürürken görünen tüm `unsearched` noktalar 1-2 sn'de bir ışınla `searched` yapılır; puan = LKP'ye uzaklık + NPC'ye uzaklık + **hafif** gerçek konuma uzaklık ("sezgi"); havuz bitince eski `searched`'ler açılır ya da yarıçap büyür; bitiş **kademeli** (herkes aynı anda dönmez); gap detection (yan ışınlarla boşluğa bakış).
- Akademik [O]: Isla occupancy map (2006); Xu & Verbrugge 2025 (arXiv 2508.18527) bilgi/güven/bağlantı haritalarından tek karar ölçütü, az parametre, grid ve navmesh'te — eğitimsiz, açıklanabilir; bizim için fazla.
- Bize uyarlama [G] (yalnız tasarım notu; T4 kalemi): core `search_plan.gd` (RefCounted): `spots: Array[{pos, state, t}]`, `claim(npc_id) -> Vector2`, `release`, `invalidate_visible(from, los_cb)`, puanlama ağırlıkları veri; noktalar seviye `SearchSpot*` işaretleri (Fable T4 notu) + gerekirse `NavigationServer2D.map_get_random_point` ile üretilen, LKP'den görünmeyen noktalar; beyin durumları `SEARCH_LKP` → `SEARCH_SWEEP`; `Observation`'a `t_seen` + `velocity` ("sense link", tur 1). Chaser bugün yalnız faz 1 (LKP → 15 sn → WAIT) — T1 için yeterli.
- **"Ne zaman BT" ölçütü** [G]: (a) beyin ≥ 12 durum **ve** (b) ≥ 3 eşzamanlı kesme kaynağı (telsiz, arama koordinatörü, örtü/pozisyon, devriye) **ya da** (c) ikinci beyin aynı alt makineyi kopyalıyor → önce HFSM-lite alt makine çıkar (tur 1 öneri 2), yine aşılırsa LimboAI HSM/BT (tur 1 tablosu) KR ile. T1 bakkalda hiçbiri tetiklenmiyor.

#### E. Godot 4.7.2 gezinme/fizik ayarları — `project.godot`'a ne yazılmalı
- [O] Varsayılanlar yukarıda ölçüldü. Godot editörü `project.godot`'a yalnız **varsayılandan farklı** değerleri yazar; varsayılan değeri elle yazmak editör kaydında düşer → "açıkça yazmak" kalıcı belge olmaz [O, ProjectSettings davranışı].
- [G] Öneri: `project.godot`'a gezinme için **hiçbir şey yazma** (hepsi varsayılan; avoidance kullanılmıyor; `map_use_async_iterations=true` oyunda doğru: ana iş parçacığı durmaz, kapı bağı değişimi 1-2 kare gecikir ve `NpcMover._on_link` bunu zaten tolere ediyor). Testlerde harita başına `map_set_use_async_iterations(false)` (zaten var). Bunun yerine **varsayılanları birim testle kilitle**: `test_project_settings.gd` → `map_get_use_async_iterations(world) == true`, `physics/2d/run_on_separate_thread == false`, `link_connection_radius == 4`, `physics_ticks_per_second == 60`; motor yükseltmesinde varsayılan değişirse test kırılır, karar görünür olur. `mimari.md §1`'e tek satır: "2D fizik ana iş parçacığında (varsayılan), gezinme eşitlemesi asenkron (varsayılan); testler yalıtık senkron harita kullanır".
- [O] `navigation/2d/default_link_connection_radius = 4` → kapı bağı uçları çokgenin 4 px içinde olmalı (tur 1 bulgusu doğrulandı; `test_levels_nav` kanıtı var). Yeni mekânlarda kapı karosu/ajan yarıçapı değişirse bu sınır ilk kırılacak yer.

### Bizim yapımıza uygunluk değerlendirmesi
- **US-016**: `Agenda` + `AgendaTask` + `CivilianSenses` + `MultiplayerSpawner` (store_alert kalıbı) ile yazılabilir; eksik üç parça küçük: lineer rota kipi, slot kaydı, örtü çarpanı. `brain_customer`/`brain_passerby` **`brain_owner`'ın kopyası olmamalı** (Graham uyarısı): müşteri = `Agenda` lineer + `Perception/Suspicion` (koni 50°/160) + 4-5 durumlu tepki (`TELL`/`FLEE`); yoldan geçen = `StreetRoute` dizisi + bakış penceresi, algı yalnız bakarken açık (ışın bütçesi).
- **US-010**: kalıp doğru; API'de üç boşluk (yalnız-AGENDA kabulü, peer bağımlı `start_blocker`, olay listesi) US-010'un sahibine görev paketi notu olarak gitmeli.
- **IS-015**: `PlayerInput` soyutlaması tam yerinde; tek değişiklik `use_bot` tipinin genişlemesi. Bot "pencere" kararını **NPC ile aynı core koni fonksiyonuyla** vermesi hem adil hem ucuz; `FogLayer.has_line_of_sight` (KR-023, US-011a) gelince istemci ışını yerine o kullanılabilir.
- **T4**: core `SearchPlan` + işaretler KR-018'e uyar; BT ölçütü yazılı olunca tartışma kodun ortasında çıkmaz.
- **Ayarlar**: proje varsayılanlarla uyumlu; yalnız kilitleyici test eksik.

### Bulgular
**Doğru yaptıklarımız**
1. `Agenda` = Graham'ın "schedule system"i (zaman → eylem, veri, HFSM, çekirdek AI ezer ve sürdürür): `interrupt`/`_end_interrupt` kalan süreyi koruyor (`agenda.gd:149-156`).
2. "Taahhütte başla, bitince bırak" kuralı `_begin/_end` yapısında doğal; kesme önceliği (GÖNDERİLDİ > MÜŞTERİ > DİNLE > ZİL) Hitman "anında/gecikmeli kesme" ayrımının bizdeki karşılığı.
3. Bağırış herkes için kesmeyi bitiriyor (`_shout` → `cancel_interrupt`, `brain_owner.gd:281`) = situation "yüksek öncelik sahneyi herkes için bitirir".
4. Dikkat dağıtmada tek araştırmacı (sahip), diğerleri yalnız bakar (GDD) = Welsh cautious.
5. Komşu üretimi `MultiplayerSpawner.spawn_function` + `NeighbourSpawn` işareti (`store_alert.gd:142-166`) US-016 nüfus üreticisinin hazır kalıbı.
6. `CivilianSenses.zone_rects` statik ve düğümsüz → bot istemcide bölgesini aynı kuralla okur.
7. Gezinme/fizik proje ayarları varsayılanda ve varsayılanlar bizim ihtiyacımızla örtüşüyor (asenkron harita, tek iş parçacıklı 2D fizik).

**Saptığımız / eksik yerler**
1. **Ajanda lineer rota kipi yok** (`agenda.gd:187-196` yalnız ev ↔ uzak): müşteri rotası (kapı → 1-2 raf → kuyruk → kapı) ve yoldan geçen rotası (StreetRoute1..6 sırayla) bugünkü `Agenda` ile yazılamaz; `brain_customer` kendi listesini tutarsa ikinci bir ajanda çıkar.
2. **Nokta rezervasyonu yok**: `_begin` tüm dizi konumlarından rastgele seçer (`agenda.gd:168-170`); 2 müşteri + sahip aynı rafı seçebilir, `QueueSpot1`'e iki müşteri gelebilir.
3. **Kesme API'si yalnız AGENDA'da** (`brain_owner.gd:126-129`): SATIN AL/GÖNDER sahip LOOK/QUESTION'dayken sessizce reddedilir; GDD SATIN AL "o oyuncuya şüphe 0" diyor → beyin düzeyinde "sorguyu bırak + ajandaya dön + kesme" zinciri gerek. Reddin oyuncuya geri bildirimi yok (Interactable `completed` yine yayılır → "satın aldım ama sahip gelmedi").
4. **`start_blocker` peer bağımsız** (`interactable.gd:51-53`): OYALA "sahibin **o oyuncuya** şüphesi 30-99 iken" koşulu bugünkü engelle yazılamaz; `Callable(peer_id) -> bool` ya da `InteractionRules.Target`'a host-side peer koşulu gerekir.
5. **Olay listesi sabit** (`store_owner.gd:27-28`): `owner_serve`, `owner_sent`, `owner_stalled`, `owner_listen`, `customer_tell/flee`, `passerby_shout` için `EVENT_KINDS`/ayrı NPC olay kanalı gerekir; okunabilirlik (neden → sonuç 1-2 sn) bu olaylara bağlı.
6. **Örtü çarpanı ve müşteri sayısı**: `CivilianRules.Context`'te "içeride müşteri var" yok; `factor_for` ×0,5 için `Population.customers_inside()` + `Params.cover_factor` gerekir.
7. **Oyalanma dökümde yok** (`loiter_s`); sayaç dükkândan çıkınca sıfırlanmıyor (`civilian_senses.gd:72-74` yalnız artırır) — GDD "dükkândan çıkış sıfırlar".
8. **`PlayerInput.use_bot(BotTimeline)` somut tip** (`player_input.gd:52`): kapalı döngü beyin takılamaz.
9. **Chaser `_visible_target` her adımda tüm aktörlere ışın** (`brain_chaser.gd:109-126`): 2 komşu + 2 yoldan geçen dönüşümüyle ışın sayısı artar; IS-066 örnekleme kaydırması chaser'ı da kapsamalı.
10. **DİKKAT DAĞIT menzili**: ShelfProp 120 px ↔ ClerkSpot ~258 px (kararlar günlüğü IS-023): sahip tezgâhtayken sesi duymaz → araç ölü; duvar çarpanı ×0,5 ile daha da kısa. US-010'da ya yarıçap 200-240 ya `ShelfProp` konumu ya da "sahip tezgâhta değilken" aracı — tasarım kararı.
11. **Dönüşüm yoldan geçen → chaser**: `Chaser` ayrı sahne; en basit yol yoldan geçeni **silip** aynı konumda `chaser.tscn` üretmek (spawner zaten var) — "aynı NPC" hissi için kostüm/ad çoğaltılmalı [G].

**Riskler**
- Müşteri/yoldan geçen için ikinci bir ajanda/rota sınıfı yazılırsa US-016 kodu şişer ve I6 (tohum) iki yerde doğrulanır → rota kipi `Agenda`'ya girmeli.
- Rezervasyonsuz noktalar oyun testinde "iki müşteri üst üste" klibi üretir (yarı saydam çizimle bile okunaksız).
- Bot beyni istemci ışını kullanırsa US-011a sis katmanı (`FogLayer`) ile iki görüş kuralı olur; biri diğerine bağlanmalı.
- `start_blocker` peer'lı hale getirilirken IS-014 kapı engeli (peer bağımsız) kırılmamalı (geriye uyumlu imza).

### Öneriler

| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri (2-3) |
|---|---|---|---|---|---|
| 12 | P1 | S | oynanis (US-016 paketi içinde) | **Agenda lineer rota kipi + nokta rezervasyonu** (`Agenda.setup_route(tasks)`, `finished` sinyali; core `spot_registry.gd`: `claim(marker, owner_id) -> Vector2`, `release(owner_id)`, `is_free`) | (a) müşteri `kapı → ShopSpot×1-2 → QueueSpot → kapı` dizisi `sequence`'ta sırayla, bitince `finished`; (b) iki Agenda aynı anda aynı `ShopSpot`/`QueueSpot`'u alamaz (birim test), görev bitince/kesmede bırakılır, NPC silinince serbest; (c) sahip ajandası (`owner_window` 300 sn ölçümü) değişmez — regresyon. |
| 13 | P1 | S | oynanis (US-016) | **Nüfus üreticisi `population.gd` + örtü çarpanı** (store_alert spawner kalıbı; `PopulationDef` S10; `Params.cover_factor` + `Context.customers_inside`) | (a) aynı seed → aynı üretim zamanları/rotaları (sabit adım fikstürü), NPC ≤ 6, üst sınırda gelen iptal; (b) içeride ≥ 1 müşteri varken müşteri bölgesi satırları ×0,5, personel/kasa satırları değişmez (birim test); (c) döküm `population` alanları + `tests/net/population.json` 0/150 ms. |
| 14 | P1 | XS | oynanis (US-010 paketi notu) | **Kesme API'si LOOK/QUESTION'da da çalışsın + peer'lı `start_blocker`** | (a) `serve_player(peer)`: sahip LOOK/QUESTION'daysa `owner_shrug` + ajanda + MÜŞTERİ kesmesi, o peer'a `forget`/0; (b) `Interactable.start_blocker` `func(peer_id: int) -> bool` (0 argümanlı eski Callable de kabul: `get_argument_count()`), IS-014 kapı testi değişmez; (c) OYALA 30-99 koşulu host'ta `blocked`, istemci istem süzgeci bakmaz (S7 kuralı). |
| 15 | P1 | XS | oynanis (US-010) | **NPC olay kanalı genişlemesi + oyalanma dökümü** | (a) `EVENT_KINDS` → `owner_serve/owner_sent/owner_stalled/owner_listen` (+ US-016 `customer_tell/customer_flee/passerby_shout` kendi düğümlerinde), her peer'da aynı sıra (mevcut `_rpc_event` testi genişler); (b) döküm `loiter_s` (peer → sn), dükkândan çıkışta sıfır; (c) DİKKAT DAĞIT yarıçapı/konumu kararı sonrası `noise_profile` güncellenir, `bakkal_tools.json` sahibin tezgâhtan sese yürüdüğünü kanıtlar. **Karar gereken:** yarıçap 200-240 mi, ShelfProp konumu mu? |
| 16 | P1 | M | oynanis (beyin) + cekirdek (toplayıcı) — IS-015 | **Bot beyni kapalı döngü** (C bölümü taslağı) | (a) `PlayerInput.use_bot` duck-typed sağlayıcı; `--bot=brain:<repertuvar>[,skill=x]`; beyin yalnız çoğaltılan/yerel durumu okur (kod taraması: `_suspicion`, host alanlarına erişim yok); (b) pencere kararı `PerceptionRules` koni + istemci görüş hattı ile; `owner_window.json`'da bot ≥ 1 pencereyi yakalar, `caught` 0; `flee` senaryosunda `bubble == ALARM` → 0,5 sn içinde koşu; (c) 2 ve 3 bot × 200 koşu özet JSON'u (temiz oranı, yakalanma, `flagged`, `stuck_sec` ≤ 10). |
| 17 | P2 | XS | altyapi | **Proje ayarı varsayılanlarını kilitleyen test** (`tests/unit/test_project_settings.gd`) + mimari §1 satırı | (a) `map_get_use_async_iterations(world)==true`, `physics/2d/run_on_separate_thread==false`, `link_connection_radius==4`, `physics_ticks_per_second==60`; (b) `project.godot`'a gezinme satırı eklenmez (diff yok); (c) ci_local yeşil. |
| 18 | P2 | XS | oynanis (IS-066 eki) | **Chaser ve müşteri algı örneklemesi 20 Hz, kaydırmalı** | (a) `brain_chaser._visible_target` her 3. karede, NPC indeksine göre kaydırmalı; (b) yoldan geçen algısı yalnız bakış penceresinde; (c) `rescue`/`owner_detect` senaryoları ±1 örnek toleransla aynı. |
| 19 | P3 | — | koordinatör (mimari §7 notu) | **T4 arama ileri uyum notu**: core `SearchPlan` (claim/release/invalidate), `Observation.t_seen+velocity`, 2-3 sn "bilme" penceresi, "ne zaman BT" ölçütü (D bölümü) | Bugün uygulanmaz; §7'ye 3 satır. |
| 20 | P3 | XS | oynanis (US-016 içinde) | **Yoldan geçen → chaser dönüşümü tek sahneyle** | (a) dönüşüm = yoldan geçen silinir, aynı konumda `chaser.tscn` üretilir, görsel kimlik (kostüm/ad) taşınır; (b) `tests/net/population.json`: bağırışta 320 px içindeki yoldan geçen ≤ 1 kare içinde chaser olarak her peer'da görünür; (c) NPC sayısı ≤ 6 korunur. |

### Karar gereken (koordinatöre)
1. **DİKKAT DAĞIT menzili** (öneri 15c): GDD 120 px ile sahip tezgâhta sesi duymuyor (IS-023 günlüğü). Seçenekler: (a) yarıçap 200-240 + duvar çarpanı; (b) ShelfProp'ları tezgâha yakın raf uçlarına taşı (seviye); (c) araç yalnız sahip raf/arka odadayken anlamlı (tasarım niyeti "kasa ya da arka oda açılır"). Öneri: (a) + Fable onayı.
2. **Counter alt eylem seçimi** (SATIN AL / GÖNDER aynı prop): en yakın Interactable kuralı iki eylemi ayıramaz. Seçenekler: iki ayrı menzil dairesi (müşteri tarafı sol/sağ), `intimidate` (Q) "alt eylem" tuşu, ya da istem döngüsü. Bot beyni ve HUD istemi bu karara bağlı. Öneri: Q = alt eylem (S5 zaten tanımlı, kullanılmıyor).
3. **US-016 kapsamı**: Agenda rota kipi + SpotRegistry (öneri 12) US-016 paketine mi, ayrı XS kalem mi? Öneri: US-016 içinde ama "Dokunulacak"a `agenda.gd` + `core/spot_registry.gd` eklenir (US-008 birleştikten sonra).
4. **project.godot**: gezinme/fizik satırı eklenmesin, varsayılanlar testle kilitlensin (öneri 17). Öneri: evet.

### Sonraki tur için açık sorular
- Monaco / Invisible Inc / Teleglitch sivil-muhafız davranışı için birincil kaynak (postmortem, GDC) bulunamadı; T4 turunda Dishonored 2 GDC 2017 videosu ve Mark of the Ninja ilgi öncelikleri ayrıntılı taranmalı.
- `FogLayer.has_line_of_sight` (US-011a) ile bot/NPC görüş hattının tek kaynağa bağlanması — IS-066 ile birlikte mi?
- 6 NPC × 15 Hz poz + `ON_CHANGE` durum çoğaltması ölçümü (KB/sn) nüfus geldikten sonra (ag-kodu turu ile ortak).
- Kuyruk davranışı: `QueueSpot1` dolu iken 2. müşteri `QueueSpot2`'de bekleyip ilerlemeli (smart zone "ana rol bitince destek rol terfi eder") — `SpotRegistry` sıralı slot desteği gerekir mi, yoksa kuyruk 2 nokta ile sabit mi?
- Bot "beceri" ölçeğinin insan testiyle kalibrasyonu (Borovikov sıcaklık fikri): test-2 verisiyle.

### Kaynaklar (tur 2)
- Godot 4.7.2-stable yerel ölçüm (headless `ProjectSettings.get_setting` + `NavigationServer2D.map_get_*`; betik bu turun geçici dosyası) · Godot 4.7 belgeleri NavigationServer2D — https://docs.godotengine.org/en/4.7/classes/class_navigationserver2d.html · Godot kaynak 4.7.2-stable `servers/navigation_2d/navigation_server_2d.cpp` (`navigation/2d/*` GLOBAL_DEF) — https://github.com/godotengine/godot/blob/4.7.2-stable/servers/navigation_2d/navigation_server_2d.cpp · `servers/navigation_3d/navigation_server_3d.cpp` — https://github.com/godotengine/godot/blob/4.7.2-stable/servers/navigation_3d/navigation_server_3d.cpp
- Graham, "Breathing Life into Your Background Characters", Game AI Pro 1 §36 — https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter36_Breathing_Life_into_Your_Background_Characters.pdf
- de Sevin, Chopinaud, Mars, "Smart Zones to Create the Ambience of Life", Game AI Pro 2 §11 — https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter11_Smart_Zones_to_Create_the_Ambience_of_Life.pdf
- Skubch, "Ambient Interactions: Improving Believability by Leveraging Rule-Based AI" (FFXV), Game AI Pro 3 §35 — https://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter35_Ambient_Interactions_Improving_Believability_by_Leveraging_Rule-Based_AI.pdf
- Welsh, "Looking for Trouble: Making NPCs Search Realistically", Game AI Pro 2 §27 — https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter27_Looking_for_Trouble_Making_NPCs_Search_Realistically.pdf
- Borovikov, "AI-Driven Autoplay Agents for Prelaunch Game Tuning", Game AI Pro Online 2021 §10 — http://www.gameaipro.com/GameAIProOnlineEdition2021/GameAIProOnlineEdition2021_Chapter10_AI-Driven_Autoplay_Agents_for_Prelaunch_Game_Tuning.pdf
- Černý, Brom, Barták, Antoš, "Spice It Up! Enriching Open World NPC Simulation Using Constraint Satisfaction", AIIDE 2014 (Warhorse; Hitman Absolution situations aktarımı: Vehkala 2012) — https://cdn.aaai.org/ojs/12715/12715-52-16232-1-2-20201228.pdf
- Game Developer, "The AI of Hitman (2016)" — https://www.gamedeveloper.com/design/the-ai-of-hitman-2016-
- Unreal Engine 5, Smart Objects Overview (slot claim/occupy/release modeli) — https://dev.epicgames.com/documentation/unreal-engine/smart-objects-in-unreal-engine---overview
- Xu & Verbrugge, "Generic Guard AI in Stealth Game with Composite Potential Fields" (2025) — https://arxiv.org/abs/2508.18527
- Arkane, "Taking Back What's Ours: The AI of Dishonored 2", GDC 2017 (özet) — https://gamedeveloper.com/design/video-inside-the-ai-design-of-i-dishonored-2-i- · GDC Vault — https://www.gdcvault.com/play/1024660/Taking-Back-What-s-Ours
- Payday 2 sivil mekanikleri (wiki/forum, ikincil) — https://payday.fandom.com/wiki/File:Stockpiler.png · https://steamcommunity.com/app/218620/discussions/8/1631916887501002397
- Rebellion, "Automated Game Testing Using a Numeric Domain Independent AI Planner", GDC AI Summit (başlık) — https://www.gdcvault.com/play/1027537/
- Proje içi: `docs/tasarim/arastirma/faz2-bakkal-kalemleri.md` §3-§4, §6; GDD §9.2-9.3; `docs/surec/kararlar.md` günlük 2026-10-02 (IS-023 DİKKAT DAĞIT menzili, oyun-yz tur 1 kararları); mimari S5-S7, S11.

---

## Tur 3 — 2026-10-03 — Utility AI (fayda puanlaması)

### Kapsam
Kullanıcı sorusu: NPC karar vermede Utility AI Insiders'a uyar mı, nasıl? Yalnız karar katmanı; algı/gezinme tur 1-2'de. KR-018 (davranış ağacı/eklenti yok, düz FSM/HFSM-lite core'da) ve KR-028 (dar kapsam) gözetildi. Kod yazılmadı.

### Mevcut durum (dosya:satır)
- `core/fsm.gd:33-65` — `Fsm(initial, edges)`: izinli kenar tablosu, `go()` yalnız kenar varsa, zaman damgalı geçmiş (`history`/`history_times`), `route()` en kısa yol. Karar **vermez**; beyinler verir.
- `entities/npc/owner/brain_owner.gd:32-56` — 9 durum, kenarlar sabit; karar noktaları: `_agenda_triggers` (293-318: kasa/çekmece keşfi, boş dükkânda keşif — if zinciri), `_agenda_step` (327-331: `level >= NOTICE` → LOOK), `top_peer` (421-433: en yüksek şüphe değerli **serbest** oyuncu, eşitlikte ilk gelen kazanır — zaten tek eksenli argmax, yani örtük utility).
- `entities/npc/components/agenda.gd:313-322` — `_next()`: ev → rastgele "away" görevi (`_rng` tohumlu, aynısı peş peşe gelmez). Görev seçimi tohumlu rastgele, puan yok.
- `entities/npc/civilian/brain_civilian.gd:135-146` — `_react()`: tanık → `_sees_owner()` ise TELL, değilse FLEE (ikili kural).
- Veri: `data/npc/*_tuning.tres` (S10) var; eğri/ağırlık dosyası yok. Döküm: `states` geçmişi var; puan dökümü yok.

### En iyi uygulamalar ve seçenekler
**1. Ne / farkı.** Utility AI: her aday eylem için 0-1 arası puan = (girdi → normalize → tepki eğrisi → ağırlık) sonuçlarının çarpımı; en yüksek (ya da ağırlıklı rastgele) seçilir [O, GAIP1 §9 Graham]. FSM "hangi durumdayım + hangi kenar izinli" (yapı), BT "hangi dalı dene" (öncelik sırası), GOAP/HTN "hedefe plan" (arama); utility "şu an hangisi en iyi" (sürekli değerleme), geçiş kuralı yazmaz [O, GAIP1 §9; Rasmussen 2016]. Dave Mark IAUS (GW2 HoT, GDC 2015): consideration = (girdi, eğri m/k/b/c; 4 tip: doğrusal, polinom, lojistik, logit), **compensation factor** `mod = 1 - 1/n; puan += (1-puan)*mod*puan` (consideration sayısı arttıkça çarpımın sıfıra çökmesini telafi) [O, GDC 2015 "Building a Better Centaur"; formül konuşmadan, uintel belgesi de Mark'a atfediyor]. Geometrik ortalama alternatifi (Graham) [O, uintel]. **Momentum**: seçili eylemin puanına ×1,1-1,25 bonus → titreme (dithering) önlenir [O, uintel; Mark 2015]. The Sims: en yüksek değil, **en iyi N arasından ağırlıklı rastgele** (robotik görünmesin) [O, GMTK]. Dill "dual-utility" (GAIP2 §3, Zoo Tycoon 2): önce **rank** (kategori/öncelik), sonra kategori içinde ağırlık — "kaçış her zaman yemekten önce" gibi değişmezleri eğri hilesi olmadan verir [O].
**2. Hibrit kalıp.** "Utility seçer, FSM/BT yürütür" yerleşik: GAIP1 §10 (Mark & Dill: BT selector'ını utility ile değiştir); Apex/Rasmussen (utility karar + FSM geçiş + BT yürütme); UE EQS (BT içinde puanlı konum seçimi) [O]. Looman (UE, 2026-04): utility'yi görev seçimi, kafa takibi hedefi, konum seçimi gibi **küçük argmax noktalarında** kullanmak BT dosya çoğalmasını azaltır [G, blog].
**3. Godot örnekleri.** `Pennycook/godot-utility-ai` (MIT, Godot 4.2; Behavior/Consideration/ResponseCurve/Option Resource'ları, Inspector'da eğri) ve "Utility AI (GDExtension)" asset'i (düğüm tabanlı + Node Query System) [O]. Eklenti **almıyoruz** (KR-018); alınacak kalıp: eğri ve ağırlık `Resource`, puanlama saf fonksiyon, Godot `Curve` kaynağı.
**4. Zayıflıklar (kaynaklar ortak).** Öngörülebilirlik: oyuncu "neyin neyi tetiklediğini" öğrenemez, tasarımcı "neden bunu seçti"yi puan dökümü olmadan çözemez; eğri ayarı yineleme ister; yasak geçişleri ceza ile yazmak ölçeklenmez (FSM kenarı daha dürüst) [O, GAIP1 §9; Aversa 2022]. Determinizm: puanlama saf matematik → aynı girdi aynı seçim; yalnız eşitlik bozma ve ağırlıklı rastgele tohum ister [G].

### Bizim yapımıza uygunluk değerlendirmesi
- **Okunabilirlik ilkesi** (GDD §9.3 "bir çift göz okunabilir ve yönetilebilir") utility'nin zıt ucunda: oyuncunun öğreneceği kural "≥ 30 bakar, ≥ 60 sorgular, 100 bağırır, kuyruk gelince tezgâha gelir" = eşik + kenar. Utility ile yazılırsa aynı girdiyle farklı tepki (ağırlıklı rastgele) ya da eğri kesişimlerinde açıklanamaz dönüşler çıkar. Sonuç [G]: **tepki zinciri FSM'de kalır**; utility yalnız "aynı kademede birden çok aday var, hangisi?" sorusuna.
- **Sahip:** tepki (LOOK/QUESTION/SHOUT/HOLD) kalır. Değer katabileceği yer: `top_peer` (tek eksen: şüphe) → şüphe × görünürlük × mesafe × serbest; `_next()` görev seçimi ("uzun süredir gidilmemiş rafa git" ağırlığı). İkisi de bugün yeterli; örtü ×0,5 zaten `Suspicion`'da.
- **Müşteri/yoldan geçen:** TELL/FLEE ikili kural; T1'de tek sonuç → utility fayda yok.
- **Kovalayan:** hedef seçimi (en yakın görünen / en şüpheli / en son görülen) tek argmax; `top_peer` ile aynı yardımcı fonksiyon.
- **T2 çalışan:** "düğmeye uzan / bağır / uy / kaç" seçimi sindirme, mesafe, silah, tanık sayısına bağlı → **ilk gerçek çok eksenli karar**; dual-utility (rank = tehdit kademesi, weight = mesafe/sindirme) tam uyar.
- **T4 muhafız:** `SearchPlan` nokta puanı (LKP uzaklığı + NPC uzaklığı + sezgi; tur 2 §D) **zaten utility**; devriye/telsiz/arama kesme önceliği FSM kenarı kalır.
- **Ağ/performans:** karar yalnız host (S2); 6 NPC × ≤ 5 aday × ≤ 4 consideration = 120 çarpım/karar, 15 Hz'de önemsiz. Replay (KR-009) için puanlama saf, eşitlik bozma tohumlu.

### Bulgular
1. [O] Doğru yaptığımız: `Fsm` kenar tablosu değişmezleri (I1-I7) açık tutuyor; `top_peer` ve `SearchPlan` puanı "utility'yi seçim fonksiyonu olarak göm" kalıbının (tur 1 §A) iki örneği zaten var.
2. [G] Sapma yok; ama `top_peer` tek eksenli (görünürlük/mesafe yok) ve eşitlikte ilk peer kazanır — 3 oyuncu aynı anda eşit şüphede ise seçim peer kimliğine (host=1) bağlı, tasarımsal değil.
3. [G] Risk: bütün beyni utility'ye taşımak okunabilirliği, test edilebilirliği (I3 geçiş günlüğü) ve determinizmi zayıflatır; KR-018 "çatı yok" ile çatışır. Dar kullanımda (argmax yardımcı) risk yok.
4. [?] Ağırlıklı rastgele (The Sims) bizde yalnız ajanda görev seçiminde anlamlı; tepkide **asla** (aynı girdi aynı tepki; 150 ms ağda "neden bana bağırdı" tartışması çıkmasın).

### Öneriler
| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri (taslak) |
|---|---|---|---|---|---|
| 19 | P3 (T2 öncesi; şimdi değil) | S | oynanis (core) | **`core/utility.gd` düğümsüz puanlayıcı** (`RefCounted`; `Consideration(value: float, curve: Curve, weight: float)`, `Utility.score(candidates: Array[Dictionary], current: StringName) -> Dictionary{best, scores}`; compensation factor; momentum `commit_bonus` (varsayılan 1,15) `current` adayına; eşitlik bozma tohumlu — `Game.derive_seed(&"utility")`; `Curve` kaynağı `.tres`, S10) | (a) birim: sabit girdi → deterministik seçim; momentum ile aynı girdide seçim değişmez; consideration sayısı artınca puan çökmez (compensation testi); (b) dökümde `utility_scores` (aday → puan + kırılım) yalnız host, `--debug-ai` katmanında (tur 1 öneri 6) metin; (c) `core/` bağımlılık kuralı (Node yok) ve kapsülleme taraması geçer. |
| 20 | P3 (öneri 19 ile) | XS | oynanis | **İlk kullanım: `top_peer` çok eksenli** (şüphe × görünürlük (0,2 sn kuralı) × mesafe × serbest; eşitlik tohumlu) | (a) `owner_detect` ve `rescue` senaryoları değişmez; (b) iki oyuncu eşit şüphede ise yakın olan seçilir (birim); (c) döküm `utility_scores.top_peer`. |
| 21 | P3 (T2 kalemi içinde) | M | oynanis + tasarim | **T2 çalışan dual-utility** (rank = tehdit kademesi: silah > bağırış > şüphe; weight = düğme mesafesi, sindirme süresi, tanık sayısı) | (a) yüksek rank düşük rank'i her zaman yener (değişmez testi); (b) aynı tohum + aynı girdi → aynı eylem; (c) GDD T2 tablosuna karşı 4 senaryo (uyar/uzan/bağır/kaç). |

Şimdi (bakkal, test-2 öncesi) **yapılmaz**: KR-028 dondurma + T1'de çok eksenli karar yok; mevcut if/argmax yeter. Eşitlik bozma (bulgu 2) istenirse XS: `top_peer`'da `value` eşitse mesafeyle kır — utility altyapısı gerekmez.

### Karar gereken (koordinatöre)
1. Yön: "utility yalnız seçim fonksiyonu (argmax yardımcı); tepki zinciri ve kenarlar FSM'de; ağırlıklı rastgele yalnız ajanda görev seçiminde" KR-018 eki olarak yazılsın mı? Öneri: evet, T2 planlamasında.
2. `core/utility.gd` zamanı: T2 çalışan kalemiyle (öneri) mi, T4 `SearchPlan` ile mi? Öneri: T2 (ilk çok eksenli karar orada).

### Sonraki tur için açık sorular
- T2 çalışan kararı için GDD §9.1 T2 satırının eylem listesi ve girdileri (sindirme ölçeri var mı?) — tasarim.
- `Curve` kaynağının replay'de versiyonlanması (eğri değişince eski replay bozulur; `data` sürüm damgası?).
- Ağırlıklı rastgele ajanda seçimi "sahip her 2 dakikada arka odaya gidiyor" keşif bilgisini (GDD §9.2 keşif bağı) bozar mı — tasarım sorusu.

### Kaynaklar
- Graham, "An Introduction to Utility Theory", Game AI Pro 1 §9 — http://www.gameaipro.com/GameAIPro/GameAIPro_Chapter09_An_Introduction_to_Utility_Theory.pdf
- Mark & Dill, "Building Utility Decisions into Your Existing Behavior Tree", GAIP1 §10 — http://www.gameaipro.com/
- Dill, "Dual-Utility Reasoning", GAIP2 §3 — https://www.oreilly.com/library/view/game-ai-pro/9781482254792/K23980_C003.xhtml
- Lewis, "Choosing Effective Utility-Based Considerations", GAIP3 §13 — http://www.gameaipro.com/GameAIPro3/GameAIPro3_Chapter13_Choosing_Effective_Utility-Based_Considerations.pdf
- Mark & Dill, "Improving AI Decision Modeling Through Utility Theory", GDC 2010 — https://gdcvault.com/play/1012410
- Mark & Lewis, "Building a Better Centaur: AI at Massive Scale", GDC 2015 (GW2 HoT, IAUS) — https://gdcvault.com/play/1021848 · IAUS özeti — https://gameai.com/iaus.php
- Mark, "Embracing the Dark Art of Mathematical Modeling in AI", GDC 2012 — https://gdcvault.com/play/1015421
- Rasmussen, "Are Behavior Trees a Thing of the Past?", Game Developer 2016 — https://gamedeveloper.com/programming/are-behavior-trees-a-thing-of-the-past-
- Aversa, "Utility-based AI", 2022 — https://davideaversa.it/blog/utility-based-ai/
- Looman, "Journey into Utility AI with Unreal Engine (Part 1)", 2026-04 — https://tomlooman.com/unreal-engine-utility-ai-part1/
- Utility Worlds belgesi (compensation factor / geometrik ortalama / momentum bonus; ikincil) — https://uintel-ecs.utilityworlds.com/Documentation/UtilityIntelligence/Considerations/
- Pennycook, godot-utility-ai (MIT, Godot 4.2) — https://github.com/Pennycook/godot-utility-ai · Godot Asset Library "Utility AI (GDExtension)" — https://godotengine.org/asset-library/asset/1937
- GMTK, "The Genius AI Behind The Sims" (ikincil) — https://gameindustrylibrary.com/documents/gmtk-the-genius-ai-behind-the-sims
- Wikipedia "Utility system" — https://en.wikipedia.org/wiki/Utility_system
- Proje içi: `core/fsm.gd`, `brain_owner.gd:293-331, 421-433`, `agenda.gd:313-322`, `brain_civilian.gd:135-146`; KR-018, KR-028; GDD §9.2-9.3; `docs/tasarim/arastirma/muhafiz-davranisi.md` §3.
