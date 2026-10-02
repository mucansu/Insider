# Ağ kodu — teknik araştırma (Godot 4 çok oyunculu)

İşaretler: **[O]** olgu (kaynak aşağıda; "4.7 kaynak" = godotengine/godot `4.7` dalı kaynak kodu) · **[G]** görüş/çıkarım · **[?]** doğrulanmalı.
Proje kararları gözetildi: KR-008 (host yetkili + istemci yetkili hareket, lockstep yok), KR-020 (önce aramızda MVP; ENet + Tailscale; hile modeli yok), KR-022/023 (görüş paylaşılmaz; görünürlük kararı istemcide). Karar değiştiren öneriler "Karar gereken" diye ayrıldı.

---

## Tur 1 — 2026-10-02

### Kapsam
MultiplayerSynchronizer/Spawner en iyi kullanımı ve tuzakları (4.x sürüm durumu, delta senkron, görünürlük süzgeçleri — KR-022 ile ilişkisi), istemci yetkili hareket + host doğrulama, ara değerleme tamponu (sabit 100 ms vs uyarlanır; US-015), istemci tahmini/uzlaştırma gerekli mi, gecikme telafisi (gizlilik/yakalama kararları), ENet kanal/güvenilirlik, bant genişliği bütçesi (6 NPC × 15 Hz), RPC güvenliği, host göçü/yeniden bağlanma, deterministik tohum, Steam taşıyıcı soyutlaması, topluluk örnekleri (Godot demoları, netfox, GDQuest).

### Mevcut durum (dosya:satır; dev `16991a6`, faz2-int `27a77c2`)
- **Taşıma (S1):** `autoload/net.gd:209-259` yalnız burada ENet; `throttle_configure(5000, 32, 0)` (`:31-33`, `:243-249`) — ENet'in güvenilmez paketleri "tıkanıklık" diye düşürmesine karşı (US-001 t2); katılma zaman aşımı `set_timeout` (`:221-230`); ping ENet RTT'den (`:252-259`), IS-026 bunu ayrı kanallı, `unreliable` kendi ölçümüyle değiştiriyor (S2 metni; dalda henüz yok).
- **Oturum (S3):** `autoload/game.gd:412-452` SceneMultiplayer el sıkışmasında seviye yolu + sürüm; `PlayerSpawner` `spawn_function` (`:593-606`, `:737-741`) yetkiyi düğüm ağaca girmeden atıyor; geç katılana konum yetiştirme: bir kez `reliable` + 2 sn `unreliable_ordered` (`:486-493`, `:686-703`); seviye değişiminde "dondur" onayı (`:507-525`); istemci→host RPC'lerde gönderen doğrulaması (`:519-537`).
- **Oyuncu (S2):** istemci yetkili; `MultiplayerSynchronizer` 0,05 sn, 4 alan `ALWAYS` (`entities/player/player.tscn:12-24,42-44`); her fizik adımında `_publish` (`player.gd:235-239`); uzak kopya `synchronized` → `SnapshotBuffer.push` (`:252-253`); host kararları `interaction_position()` = en güncel `net_position` (`:160-164`), çizilen (100 ms geri) konum değil.
- **Ara değerleme:** `entities/player/snapshot_buffer.gd:35-40,54-87` sabit `delay` 0,1 sn (`data/player_tuning.tres:12`), saat farkı üstel ortalama (0,05), sıra dışı paket atılır, tampon tükenince son durumda bekler (ileri tahmin yok).
- **Etkileşim (S7):** `entities/props/interactable.gd:285-296` `busy_by/progress` `ON_CHANGE`, `delta_interval` 0,1; RPC kalıbı `:159-172`; host doğrulaması `:178-202` (menzil +24 px, taraf 24 px, süre +0,25 sn, tekrar 0,25 sn).
- **Prop durumu:** `door.tscn:14-33`, `register.tscn:11-24` `ON_CHANGE` (`replication_mode = 2`), `delta_interval` 0.
- **Faz 2 (faz2-int):** `Perception` yalnız host (`entities/npc/components/perception.gd:18-19,104-112`), `Suspicion` özeti `max_level/focus_direction` `ON_CHANGE` 0,1 sn (`suspicion.gd:122-133`); `NoiseBus` (`27a77c2 autoload/noise.gd`): istek `any_peer reliable` + gönderen/aktör/konum/tür/tempo doğrulaması, halka `authority unreliable`.
- **Test:** `tools/net_smoke.py` 0/150 ms + jitter/kayıp; IS-013 sert ağ (150 + 30 ms jitter + %1 kayıp): `store_walk` 5/5, `faz1_full` 5/10 (senkron sıçraması 40-64 px) → US-015 adayı.

### En iyi uygulamalar ve seçenekler

#### 1. Sürüm durumu (4.x)
- **[O]** Godot 4.5, 4.6 ve 4.7 sürüm notlarında multiplayer/ENet/RPC değişikliği yok; API 4.2 çağından beri sabit (bkz. kaynaklar: releases/4.5, 4.6, 4.7). 4.1 belgelerinde `delta_interval` zaten var [O]; `REPLICATION_MODE_ON_CHANGE` 4.2 ile [?]. Sonuç: 4.2+ için yazılmış topluluk rehberleri 4.7.2'ye uyar; "4.5'te çoğaltma düğümleri bölündü (MultiplayerAuthority)" gibi iddialar (yapay zekâ üretimi "skill" sayfaları) **yanlış/doğrulanamadı** — kullanılmamalı.

#### 2. MultiplayerSynchronizer iç işleyişi (4.7 kaynak, `scene_replication_interface.cpp`, `multiplayer_synchronizer.cpp`) [O]
- **Tam senkron (`ALWAYS`)**: `unreliable`, kanal 0; paket = 1 B komut + 2 B artan `uint16` zaman + düğüm başına 4 B net_id + 4 B boyut + sıkıştırılmış Variant'lar; `max_sync_packet_size` (1350 B) aşılırsa bölünür; alıcı `update_inbound_sync_time` ile **eski paketi atar** (sıra Godot'da zaten sağlanıyor; `SnapshotBuffer`'ın kendi sıra denetimi ikinci savunma).
- **Delta (`ON_CHANGE`)**: **`reliable`**, kanal 0; düğüm başına 4 + 8 (değişen alan bit maskesi) + 4 B + Variant'lar. `delta_interval` yalnız değişiklik taramasını seyreltir. **Yeni/geç katılan peer için `last_watch_usecs` kaydı yoktur → ilk delta turunda izlenen bütün alanlar gönderilir** (`get_delta_state`'te `last_change_usec <= 0` hiç sağlanmaz). Yani geç katılan kapı/kasa/`busy_by`/`max_level` durumunu ek RPC'siz alır — "ON_CHANGE geç katılana gitmez" diyen blog yazıları 4.7 için **yanlış**. Ön koşul: istemcide düğüm + eşitleyici host'un turundan önce var olmalı (bizde seviye kabulden önce yükleniyor, S3 — sağlanıyor).
- **Spawn**: `reliable`; "spawn" alanları yalnız `MultiplayerSpawner` ile üretilen düğümler için (seviye sahnesindeki prop'lar için anlamsız — `property_set_spawn(false)` doğru).
- **Görünürlük**: `set_visibility_for/add_visibility_filter`; görünmez olunca `last_watch_usecs` silinir → yeniden görünür olunca tam ON_CHANGE durumu tekrar gider. Spawner'lı düğümde görünmezlik = o peer'da **despawn**; sahnedeki düğümde yalnız senkron durur (düğüm son durumla kalır).
- **Yetki**: alıcı "Ignoring sync data from non-authority or for missing node" ile başkasının verisini atar. Eşitleyici yetkisi `_ready` içinde değil, spawner'ın `_enter_tree`'sinde (ya da `spawn_function` içinde, bizdeki gibi) değiştirilmeli (kaynaktaki uyarı).
- **Sınır**: Object/Resource/RID alanları senkronlanmaz (belge). Topluluk tuzakları: `public_visibility=false` + `set_visibility_for` + spawner birleşiminde "get_cached_object: ID not found in cache" hataları (forum), eşitleyici eşini bulamayınca sessizce durması (forum) — bizde görünürlük süzgeci kullanılmıyor, sorun yok.

#### 3. ENet kanal/güvenilirlik (4.7 kaynak `enet_multiplayer_peer.cpp`, `thirdparty/enet/host.c`) [O]
- ENet kanal 0 = Godot `reliable`, kanal 1 = Godot `unreliable` ve `unreliable_ordered` (ikisi aynı ENet kanalı; `unreliable` UNSEQUENCED bayrağıyla sırasız, `unreliable_ordered` sıralı). Kullanıcı kanalı k → ENet kanalı 1+k; kendi kanalında reliable ve unreliable **aynı ENet kanalını** paylaşır. `channel_count` 0 (bizim varsayılan) → ENet 255 kanal açar; özel kanal için ayar gerekmez (IS-026 ayrı kanalı hazır).
- Satır başı engellemesi (HOL) kanal başına: reliable bir paket kaybolursa aynı kanaldaki sonraki **reliable** paketler bekler; unreliable kanal etkilenmez. Bizde kanal 0 reliable akışı = etkileşim istek/karar + oturum RPC'leri + **delta senkronlar** + spawn; küçük hacimde sorun değil, ama ileride hacimli reliable akış (Faz 3 plan masası çizimleri) kanal 1'e alınmalı ki etkileşim kararını geciktirmesin.
- Steam (bkz. `docs/arastirma/steam-ag.md`): `unreliable_ordered` → reliable; kanal = şerit, `max_channels` ≥ kullanılan + 2. Bu yüzden yüksek frekanslı akışlarda `unreliable_ordered` kullanılmamalı (bizde yalnız yetiştirme RPC'si).

#### 4. Ara değerleme tamponu
- **[O]** Gaffer (Snapshot Interpolation): tampon "arka arkaya iki paket kaybına" dayanmalı → ~3 × gönderim aralığı (+ jitter payı). 20 Hz'de bu 150 ms; **100 ms yalnız tek kayba** dayanır — IS-013'teki 40-64 px sıçramalar bununla tutarlı [G]. Tamponu küçültmek yerine **gönderim sıklığını artırmak** gecikmeyi düşürür (30 Hz'de ~100 ms iki kayba dayanır).
- **[O]** Unity Netcode: gecikme = taban tik + jitter × ölçek + kayıp payı, yavaş uyarlanır ("hızlı değişim sıçrama yapar"). Overwatch (GDC 2017): bağlantıya göre paket oranı/tampon uyarlanır.
- Seçenekler: (a) sabit 150 ms — en basit, +50 ms görünür gecikme; oyun kararları `net_position` kullandığından adalet değişmez; (b) uyarlanır 100-180 ms (US-015): jitter = `|ölçülen − offset|` artığının üstel ortalaması (SnapshotBuffer zaten `measured` ve `_offset`'i tutuyor), kayıp = `underruns` oranı; `delay` yavaş kaydırılır (≤ 10 ms/sn) ki uzak kopya hızlanıp yavaşlamasın; (c) 30 Hz gönderim (bant genişliği 1,5×, hâlâ önemsiz; §6) + 100 ms sabit; (d) sınırlı ileri tahmin (≤ 1 aralık, hız kırpılmış) — S2 "ileri tahmin yok" kuralıyla çelişir, duvar taşması riski; önerilmez.
- **[G]** Öneri: önce (c) ucuz A/B (sert ağ profilinde `faz1_full` 10 koşu), sonra (b); ikisi birlikte de olabilir (30 Hz + 100-150 uyarlanır).

#### 5. İstemci tahmini / uzlaştırma
- Hareket istemci yetkili olduğundan (KR-008) klasik CSP + reconciliation **gerekmez** [G]. Gerekli olduğu tek yer: host'un oyuncuyu durdurduğu/konumladığı anlar (US-008 `held`/`caught`, ÇEK kurtarma). Kalıp: host bayrağı reliable yollar → istemci alınca girdiyi keser, **konum istemcide kalır** (host konuma yapıştırmaz); host, istemcinin bildirdiği durma konumunu kabul eder. Böylece uzlaştırma kodu yok, "ışınlandım" hissi yok.
- Yakalama adaleti: host oyuncuyu 100-175 ms eski görür = koşuda 22-38 px; yakalama yarıçapı 28 px ile aynı mertebede → host, kaçan oyuncuyu istemcinin gördüğünden **önce** yakalar ("yakalanmamıştım"). Çözümler: (i) 0,5 sn temas kuralı (US-008 AC5) zaten emer; (ii) ucuz "ölü hesap": host karar anında `net_position + hız × yaş` kullanır (yaş = şimdi − (`net_time` + saat farkı); host'taki uzak kopyanın `SnapshotBuffer.clock_offset()` bunu verir) — bu, hareket için gecikme telafisinin tamamı [G].

#### 6. Gecikme telafisi (lag compensation) — gizlilik/yakalama
- **[O]** Valve/Gambetta: sunucu, istemcinin zaman damgasına göre dünyayı geri sarar; hedef "geçmişte" vurulur (siper paradoksu). Bizde istemci kaynaklı aksiyon az (ÇEK kurtarma, ileride etkisiz hale getirme); bunlar için host'ta NPC poz geçmişi (0,5 sn halka tampon) + istemcinin `net_time`'ı ile doğrulama yeterli; Faz 2'de gerekmiyor.
- "Görüldüm mü" kararı için mevcut 0,2 sn oyuncu lehine pay = basit telafi. Pay, host'un gördüğü konumun bayatlığından büyük olmalı: 150 ms RTT'de bayatlık 100-175 ms (GDD §12 ölçümü) → 0,2 sınırda; 300 ms RTT'li Wi-Fi'da 250 ms > 0,2 → adaletsiz. Öneri: pay = `max(0,2; ölçülen bayatlık + 0,05)` oyuncu başına (host uzak kopyadan ölçer) — **karar gereken** (S2/S11 sabiti formüle dönüşür).

#### 7. Host doğrulaması (istemci yetkili hareket)
- **[O]** Genel öneri "girdi kabul et, konum kabul etme" rekabetçi oyunlar için; arkadaş co-op'unda (KR-020) düzeltme yok. Yine de **teşhis** değerli: ardışık iki senkron arasında hız > sprint × 1,25 ya da uzak kopya duvar içinde (`overlaps_world()` zaten var) → döküm sayacı `net_flag` (US-008 AC6 bunu anıyor) — senkron hatalarını testte yakalar, oyuncuyu etkilemez.

#### 8. Görünürlük süzgeçleri ve KR-022
- Soru: "istemciye yalnız görebildiğini gönder" gerekli mi? **[G] Gerekli değil, hatta zararlı:** (a) KR-023 görünürlük kararını istemcide veriyor (0,2 sn tutma + 1,5 sn hayalet, bakış konisi); host süzgeci bakış yönünü 100-175 ms bayat görür → "gördüm ama çizilmedi" şikâyeti; (b) NPC'ler seviye sahnesinde (spawner'sız) olduğu için süzgeç yalnız senkronu durdurur, düğüm son konumda kalır — "hayalet"e benzer ama zamanlaması host'a bağlı olur; (c) süzgeç + spawner birleşiminde topluluk hataları (§2); (d) tek kazanç hile önleme (duvar arkasını görme) — KR-020 tehdit modelinde yok. Açık lobi gelirse (Faz 5 sonrası) yeniden değerlendirilir. netfox da süzgeçleri "rekabetçi oyunda hile" gerekçesiyle sunuyor [O].

#### 9. Bant genişliği bütçesi
- **[G] Tahmin (4.7 paket biçimi + ENet/UDP/IP başlıkları ~38 B):** oyuncu senkron paketi ≈ 3 + 8 + (Vector2 9 + Vector2 9 + int ~3 + double 9) ≈ 41 B yük → ~80 B/paket; 20 Hz → **~1,6 KB/s akış başına**. 4 oyuncu: istemci yükleme 1,6 KB/s; host yükleme (kendi + röle) ≈ 3 × (1,6 + 2 × 1,6) ≈ 14 KB/s. 30 Hz'de ×1,5.
- **NPC 6 × 15 Hz:** aynı turda değişen eşitleyiciler **tek pakete paketlenir** (1350 B'ye kadar) → 3 + 6 × (8 + ~21 [konum 9 + yön 9 + durum 3]) ≈ 180 B + 38 ≈ **~220 B × 15 Hz ≈ 3,3 KB/s istemci başına**, 3 istemci ≈ 10 KB/s. Toplam host yükleme en kötü **~25-30 KB/s ≈ 0,25 Mbit/s** — ev hattı için önemsiz; delta sıkıştırma/nicemleme gerekmez. Steam SDR hız sınırı (steam-ag.md) için de rahat [G].
- Kural önerisi (S11'e cümle): NPC **pozu** (`position`, `facing`) `ALWAYS` 1/15 sn (unreliable); **ayrık** durum (FSM durumu, `max_level`, ajanda adımı) `ON_CHANGE` (reliable). `ON_CHANGE`'i sürekli değişen float'a bağlamamalı: `focus_direction` izlerken her tarama değişir → 10 Hz reliable akış (küçük ama gereksiz); 1/16'ya yuvarlamak yeter. İstemcide NPC pozu için `SnapshotBuffer` yeniden kullanılır (delay ≈ 1,5 aralık ≈ 100 ms), GDD §12 "15-20 Hz, istemcide yumuşatılır" ile uyumlu.
- Ölçüm: editör Network Profiler (kaynakta `_profile_node_data("sync_in")`) [O]; headless/dökümde `ENetConnection.pop_statistic(HOST_TOTAL_SENT_DATA / RECEIVED_DATA)` [O: ENetConnection sınıfı; Net taşıma katmanında] → `net_smoke` beklentisi `max_kbps`.

#### 10. RPC güvenliği (any_peer)
- **[O]** Belge: "bütün istemci girdisi güvenilmezdir"; `allow_object_decoding` varsayılan false (uzak kod çalıştırma riski); RPC imzaları (ad, dönüş tipi, yol) peer'larda aynı olmalı, **argüman tipleri denetlenmez** → statik tipli parametreler uyuşmazlıkta hata basar, çökmez [?]; `get_remote_sender_id()` yerel çağrıda 0.
- Bizde doğru olanlar: her `any_peer` gövdesi gönderen kimliğini kullanıyor, host'ta `is_server()`/`_is_host()` kapısı, ad kırpma, `bytes_to_var` (nesnesiz) el sıkışması, tempo sınırı (NoiseBus) ve tekrar beklemesi (Interactable), id ile içerik (S10).
- Ek kalıplar: (a) `authority` RPC **istemci yetkili düğümde** (oyuncu sahnesi) tanımlanmamalı — o istemci onu herkese çağırabilir; bugün `player.gd`'de RPC yok, bunu tarama testi korumalı; (b) Variant/Dictionary argümanlarda `typeof` denetimi (Game `_rpc_players` yalnız authority — tamam); (c) oturum doluyken `refuse_new_connections` (ENet `max_peers` zaten kesiyor).

#### 11. Host göçü ve yeniden bağlanma
- **[O]** Godot'da yerleşik host göçü yok; peer 1 = sunucu sabit (forum, tuzaklar.md). MVP: host düşerse iş biter (GDD §16/8, tuzaklar.md ile uyumlu).
- **[G]** "Aynı slota yeniden bağlanma" (rahatlik-ux.md UX-7, Faz 3 adayı) daha ucuz ve TR↔SE kopmasında işi kurtarır. Uygulama kalıbı: host `_players` kaydını ve donmuş avatarı 60 sn tutar; aynı ad + aynı adresle gelen yeni peer eski slotu alır; **eski düğümün yetkisini değiştirmek yerine** eski düğüm despawn + yeni peer_id ile aynı konum/durumda spawn (kaynak uyarısı: eşitleyici yetkisi yalnız spawn anında güvenle değişir; spawner düğüm adı = peer_id). Kimlik ada dayalı — arkadaş oyununda kabul, Faz 5'te SteamID.

#### 12. Deterministik tohum
- **[O]** Belge: tohumlu `RandomNumberGenerator` aynı tohumda aynı diziyi verir; ağda düzen yerine tohum gönderilir; her sistem kendi RNG örneğini kullanmalı (global `randi()` sıra bağımlı). Algoritma PCG32; tamsayı yolu platformlar arası deterministik [O], float türetimleri pratikte aynı [?].
- **[G]** Kalıp: host `start_level`'da `seed` seçer (ya da `--seed=N`), `_rpc_load_level(path, seed)` ve el sıkışma `hello`'suna ekler; `Game.session_seed()`; sistemler `hash("%d:%s" % [seed, "owner_agenda"])` ile alt tohum üretir. NPC davranışı yalnız host'ta olduğundan determinizm (a) seviye/senaryo üretimi (Faz 3, her peer aynı düzeni kurar) ve (b) test tekrarlanabilirliği (döküm `seed`) için gerekir; US-008 "ajanda tohumla belirlenimci" AC'si bunu şimdi istiyor.

#### 13. Steam taşıyıcı soyutlaması
- `steam-ag.md`'nin bulgularına ek: ENet'e özgü `throttle_configure`, `set_timeout`, RTT istatistiği zaten `_transport_*` arkasında — doğru. Yapılacaklar: yetiştirme RPC'si `unreliable_ordered` → `unreliable` + artan damga (konumlar idempotent) [XS]; IS-026 ping kanalı için Steam `max_channels` ≥ 3; tam/delta senkron kanal 0'da, etkilenmez.

#### 14. Topluluk örnekleri ve eklentiler
- **netfox** (foxssake; v1.35.3, 2025-11-23; MIT; "Godot 4.x", örnekler 4.1; 4.7 uyumu [?]) [O]: `NetworkTime` tik döngüsü, girdi→durum ayrımı, `RollbackSynchronizer` (CSP + uzlaştırma), `StateSynchronizer`, `TickInterpolator`, görünürlük yönetimi, ağ koşulu simülasyonu, fizik geri sarma, `netfox.noray` (NAT geçişi), `netfox.extras`. **Uygunluk [G]: alınmaz.** Sunucu yetkili + girdi gönderen model için tasarlanmış; bizde hareket istemci yetkili ve tahmin yok → geri sarma çekirdeği gereksiz; benimsemek oyuncu/NPC mantığını `_rollback_tick` + NetworkTime'a taşımak (US-004/005/006 yeniden) + 3-4 autoload (§6 "çatı yok"). Fikir olarak alınacaklar: jitter'a uyarlanır tampon, bant genişliği azaltma ölçümü, ağ koşulu simülasyonu (bizde proxy ile var).
- **Godot demoları** (multiplayer_bomber, multiplayer_pong; 4.x): Spawner/Synchronizer temel kullanımı, ara değerleme yok — bizim yapımızın ötesinde bir şey yok [O/G].
- **GDQuest/Campos kitabı** ("Essential Guide … Godot 4.0"): tahmin/ara değerleme bölümleri genel; bizim S2 uygulamasıyla aynı ilkeler [G].

### Bizim yapımıza uygunluk değerlendirmesi
- Host yetkili sonuç + istemci yetkili hareket + 100 ms anlık görüntü ara değerleme = 2-4 kişilik arkadaş co-op'u için topluluğun ve belgelerin önerdiği en basit doğru model; netfox/CSP gibi ağır çözümler gereksiz [G].
- Delta senkronun reliable olması ve geç katılana tam durum göndermesi, bizim "prop durumunu `ON_CHANGE` ile yay, geç katılana ek RPC yazma" yaklaşımımızı doğruluyor; Game'in konum yetiştirmesi ise gerekli (oyuncu eşitleyicileri istemci yetkili, host'un deltası yok).
- Bant genişliği hiçbir senaryoda sınırlayıcı değil; mühendislik eforu kayıp/jitter toleransına (tampon) ve adalete (bayatlık payı) gitmeli.

### Bulgular
**Doğru yaptıklarımız**
- Taşıma yalnız `Net._transport_*` içinde; sync ordering ve yetki denetimi motorda, bizde ikinci savunma.
- Spawn'da yetki `spawn_function` içinde (motorun uyardığı `_ready` tuzağı yok); seviye kabulden önce yükleniyor (eşitleyici "düğüm yok" hatası yok).
- `any_peer` RPC'lerde gönderen doğrulaması, nesnesiz el sıkışması, tempo sınırı, id tabanlı içerik.
- `ON_CHANGE` ayrık durumda, `ALWAYS` sürekli durumda; `property_set_spawn(false)` sahne düğümlerinde doğru.
- Host kararları çizilen değil en güncel konumla; 0,2 sn oyuncu lehine pay GDD'de "zorunluluk" diye yazılı.

**Saptığımız yerler / riskler**
- R1 Sabit 100 ms tampon 20 Hz'de tek kayba dayanır (Gaffer 3× kuralı); sert ağda sıçrama (IS-013). → §4.
- R2 0,2 sn pay sabit; yüksek RTT'de bayatlıktan küçük kalır → adaletsiz tespit. → §6 (karar gereken).
- R3 Yakalama yarıçapı (28 px) bayatlıkla (22-38 px) aynı mertebede; US-008'de ölü hesap ya da temas süresi şart. → §5.
- R4 Yetiştirme RPC'si `unreliable_ordered` Steam'de reliable olur. → §13.
- R5 NPC çoğaltma sözleşmesi (S11) poz/ayrık ayrımını ve sıklığı yazmıyor; `focus_direction` `ON_CHANGE` ile sürekli reliable delta üretir. → §9.
- R6 Bant genişliği hiç ölçülmüyor (tahmin var, veri yok). → §9.
- R7 Tohum altyapısı yok; US-008 AC'si istiyor. → §12.
- R8 `authority` RPC'nin istemci yetkili düğüme konmasını engelleyen tarama yok. → §10.

### Öneriler (öncelik · maliyet · sahip · kalem adayı + AC)
- **P1 · S · oynanis — US-015 "Uyarlanır tampon + 30 Hz A/B"** — AC1: `SnapshotBuffer` jitter (artık EMA) ve `underrun` oranından `delay`'i 0,10-0,18 sn arasında ≤ 10 ms/sn kaydırarak uyarlar; 0 ms'de 0,10 kalır. AC2: Sert ağ profilinde (`--latency-ms 150 --jitter-ms 30 --loss 0.01`) `faz1_full` 10/10 PASS, `samples_near` host↔istemci < 32 px. AC3: 30 Hz gönderim (replication_interval 1/30) aynı profilde ayrı ölçülür; sonuç KR günlüğüne, seçilen değer `player_tuning.tres`'te; döküm `player_states.*.delay_ms`.
- **P1 · S · oynanis + koordinatör (S11 eki) — "NPC çoğaltma sözleşmesi"** (US-008/US-016 koda girmeden) — AC1: NPC `position/facing` `ALWAYS` 1/15 sn unreliable, ayrık durum `ON_CHANGE`; `focus_direction` 1/16 yuvarlanır. AC2: istemcide NPC `SnapshotBuffer` (delay ≈ 100 ms) ile çizilir; 150 ms'de titreme yok (`samples_near` NPC için eşik 32 px). AC3: 6 NPC ile host→istemci ≤ 5 KB/s ölçülür (aşağıdaki telemetriyle).
- **P1 · S · oynanis (US-008 içinde) — "Yakalama/tespit bayatlık payı"** — AC1: yakalama kararı `net_position + hız × yaş` (ölü hesap) ya da 0,5 sn temas; AC2: tespit payı `max(0,2; bayatlık + 0,05)` (**karar gereken**); AC3: `guard_detect`/yakalama senaryosu 150 ve 300 ms RTT'de "istemcinin gördüğü ile host kararı" farkı dökümde ≤ 1 karo.
- **P2 · XS · cekirdek — "Ağ telemetrisi"** — AC1: `Net.stats()` → gönderilen/alınan bayt ve paket (ENetConnection istatistiği; Steam'de `getConnectionRealTimeStatus`), döküm `net_bytes`; AC2: `net_smoke` beklentisi `max_kbps` (örn. host yükleme ≤ 40 KB/s); AC3: `faz1_full` ve NPC senaryosu bu eşiği taşır.
- **P2 · XS · cekirdek — "Yetiştirme RPC'si `unreliable` + damga"** — AC1: `_rpc_catchup_positions` `unreliable`, artan `seq`; eski damga atılır; AC2: `late_join_real` 0/150 ms PASS; AC3: S3 metni güncellenir (koordinatör).
- **P2 · XS · cekirdek — "Oturum tohumu"** — AC1: `Game.session_seed() -> int`, host seçer / `--seed=N`; `_rpc_load_level(path, seed)` + el sıkışma; AC2: döküm `seed`; AC3: birim test: aynı tohum → aynı alt tohum dizisi; S3/S6 ekleri (koordinatör).
- **P2 · XS · altyapi — "RPC hijyen taraması"** (mevcut entities/ui tarama testlerine ek) — AC1: istemci yetkili sahnelerde (`entities/player/**`) `@rpc("authority"` yok; AC2: her `@rpc("any_peer"` gövdesi `get_remote_sender_id()` (ya da `host_*` API'si) çağırır; AC3: ihlal FAIL.
- **P2 · M · cekirdek (Faz 3; karar gereken) — "Aynı slota yeniden bağlanma"** — AC1: istemci kopunca 3 otomatik deneme (2/4/8 sn), host slotu + donmuş avatarı 60 sn tutar; AC2: aynı ad + adres → aynı slot, eski konum/durum (despawn + yeniden spawn); AC3: `reconnect.json` senaryosu (proxy kesintisi 5 sn) 0/150 ms PASS.
- **P3 · XS · oynanis — "Hareket teşhisi"** — AC1: uzak kopyada hız > sprint × 1,25 ya da duvar içi → `net_flag` sayacı (döküm); AC2: ağ senaryolarında 0 beklenir; oyuncu düzeltmesi yok.
- **P3 · — — Görünürlük süzgeci, netfox, kanal ayırma:** şimdi yapılmaz (gerekçe §8, §14, §3); Faz 3 plan masası çizimleri gelince reliable hacim kanal 1'e (XS, cekirdek).

### Karar gereken (koordinatör)
1. S2/S11 oyuncu lehine payın sabit 0,2 sn'den "bayatlığa göre" formüle dönmesi (§6).
2. US-015 kapsamına 30 Hz A/B eklenmesi; 30 Hz tek başına yeterse uyarlanır tamponun ertelenmesi.
3. Yeniden bağlanma kaleminin fazı (Faz 3 vs Faz 5 SteamID) — rahatlik-ux.md'deki soruyla aynı.
4. S11'e NPC çoğaltma cümlesi (poz `ALWAYS` 15 Hz / ayrık `ON_CHANGE`) ve S3/S6 tohum ekleri.

### Bir sonraki tur için açık sorular
- Gerçek bayt ölçümü (telemetri sonrası) tahminle örtüşüyor mu; `focus_direction` deltası gerçekten ne kadar üretiyor?
- Steam'de delta (reliable) + şerit HOL etkisi: 150 ms FAKE_PACKET_LAG ile etkileşim karar gecikmesi.
- 30 Hz vs uyarlanır tampon A/B sonucu; NPC pozunda 15 Hz + 100 ms yeterli mi (chaser 200 px/sn → 13 px/aralık)?
- `held` anında istemci girdi kesme gecikmesi (RTT/2) oyun hissinde sorun mu?
- Godot 4.8 (varsa) multiplayer değişiklikleri; netfox'un 4.7 uyumu.

### Kaynaklar
- Godot belgeleri: MultiplayerSynchronizer https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html · (4.1) https://docs.godotengine.org/en/4.1/classes/class_multiplayersynchronizer.html · MultiplayerSpawner https://docs.godotengine.org/en/stable/classes/class_multiplayerspawner.html · SceneMultiplayer https://docs.godotengine.org/en/stable/classes/class_scenemultiplayer.html · MultiplayerPeer https://docs.godotengine.org/en/stable/classes/class_multiplayerpeer.html · ENetMultiplayerPeer https://docs.godotengine.org/en/stable/classes/class_enetmultiplayerpeer.html · ENetPacketPeer https://docs.godotengine.org/en/stable/classes/class_enetpacketpeer.html · Yüksek seviye multiplayer https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html · Rastgele sayı https://docs.godotengine.org/en/4.7/tutorials/math/random_number_generation.html
- Godot 4.7 kaynak: https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/scene_replication_interface.cpp · https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/multiplayer_synchronizer.cpp · https://github.com/godotengine/godot/blob/4.7/modules/enet/enet_multiplayer_peer.cpp · https://github.com/godotengine/godot/blob/4.7/thirdparty/enet/host.c
- Sürüm notları: https://godotengine.org/releases/4.5/ · https://godotengine.org/releases/4.6/ · https://godotengine.org/releases/4.7/
- Topluluk tuzakları: https://forum.godotengine.org/t/issues-with-multiplayerspawner-multiplayersynchronizer-public-visibility-and-setvisibilityfor-get-cached-object-id-not-found-in-cache-of-peer-1/94304 · https://forum.godotengine.org/t/multiplayersynchronizer-failing-to-sync-for-late-joiners/124269 · https://github.com/godotengine/godot/issues/76894 · https://godotforums.org/d/20394-host-migration-between-players · https://forum.godotengine.org/t/is-random-deterministic-between-platforms/135974
- netfox: https://github.com/foxssake/netfox · https://github.com/foxssake/netfox/releases · https://foxssake.github.io/netfox/latest/ · https://foxssake.github.io/netfox/latest/netfox/guides/visibility-management/
- Ara değerleme / telafi: https://gafferongames.com/post/snapshot_interpolation/ · https://www.gabrielgambetta.com/lag-compensation.html · Unity Netcode ClientTickRate (InterpolationDelayJitterScale) https://docs.unity3d.com/Packages/com.unity.netcode@1.5/api/Unity.NetCode.ClientTickRate.html · Overwatch GDC 2017 https://gdcvault.com/play/1024001/-Overwatch-Gameplay-Architecture-and · Valve Source Multiplayer Networking https://developer.valvesoftware.com/wiki/Source_Multiplayer_Networking (403 ile erişilemedi; Gambetta ile çapraz)
- Örnek projeler: https://github.com/godotengine/godot-demo-projects (networking/multiplayer_bomber, multiplayer_pong) · Campos & Lovato, "The Essential Guide to Creating Multiplayer Games with Godot 4.0" https://oreilly.com/library/view/the-essential-guide/9781803232614
- Proje içi: `docs/arastirma/steam-ag.md`, `docs/arastirma/tuzaklar.md`, `docs/tasarim/arastirma/rahatlik-ux.md`, `docs/surec/kararlar.md` (IS-013, US-004 günlükleri).

---

## Tur 2 — 2026-10-02 (ölçüm ağırlıklı)

### Kapsam
(1) Gerçek bayt/paket ölçümü vs tur 1 tahmini; (2) 20 Hz vs 30 Hz sert ağ A/B tabanı (IS-013 ölçümünün tekrarı) ve 30 Hz'in kod yüzeyi (US-015 AC önerisi); (3) Steam Networking Sockets şerit/HOL davranışı ve GodotSteam MultiplayerPeer'in reliable delta ile etkileşimi (Faz 5 notu); (4) `held`/`caught` anında istemci girdisinin kesilmesi; (5) Godot 4.8 dev sürecinde multiplayer değişiklikleri.

### Ölçüm düzeneği (depoya kod girmedi)
- Çıktılar: `%LOCALAPPDATA%\Temp\claude\...\scratchpad\agkodu-tur2-20261002-133943\` (`batch.out`, `hard20_N.log`, `hard30_N.log`, `*.bytes.json`, `*.cmds.json`, `measure.py`, `measure2.py`).
- **Bayt sayımı:** `tools/net_smoke.py` değiştirilmeden, `LatencyProxy` scratchpad'de bayt/paket sayan ve ENet komut başlıklarını ayrıştıran bir alt sınıfla değiştirildi (monkeypatch; `--latency-ms 2`). Proxy yalnız istemci↔host trafiğini görür; "up" = istemci yüklemesi, "down" = host'un o istemciye yüklemesi. Tel değeri = yük + 28 B (IPv4+UDP). ENet başlığı yükün içinde; `ENetMultiplayerPeer` sıkıştırma açmaz (4.7 kaynak `enet_multiplayer_peer.cpp`: `compress` çağrısı yok) [O].
- **30 Hz A/B:** `entities/player/player.tscn` kopyası (`replication_interval = 0.0333`, uid satırı silindi) scratchpad'e kondu; `main.gd:89-96` `--player-scene` için `ResourceLoader.exists` + `load` ile **mutlak OS yolunu kabul ediyor** (ext_resource `res://` yolları çözülüyor) → senaryo JSON kopyasında `player_scene` mutlak yol. Depoda değişiklik yok; aynı yöntem ileride her A/B için kullanılabilir [O].
- Sert ağ: `faz1_full.json --latency-ms 150 --jitter-ms 30 --loss 0.01`, 10 koşu × 2 varyant; ENet komut dökümü `store_walk` ve `faz1_full` (20 Hz, 2 ms).

### Mevcut durum (dosya:satır; dev `1704158`)
- Bant genişliği/paket istatistiği yok: `autoload/net.gd:252-259` yalnız `PEER_ROUND_TRIP_TIME`; döküm `ping_ms` (`game.gd:226`). `ENetConnection.pop_statistic(HOST_TOTAL_SENT_DATA|SENT_PACKETS|RECEIVED_DATA|RECEIVED_PACKETS)` "döner ve sıfırlar" [O: belge]; `get_statistic` ENetConnection'da **yok** (tur 1 metnindeki ad yanlış; ENetPacketPeer'de `get_statistic(PeerStatistic)` var). `ENetMultiplayerPeer.host` ile ENetConnection'a erişilir → IS-059 `Net.stats()` için yol açık.
- Senkron: `player.tscn:43` `0.05`; `tests/fixtures/dummy_player.tscn:23` `0.05`; `tests/unit/test_player.gd:147` "20 Hz" sabitini doğruluyor; `player.gd:13`, `snapshot_buffer.gd:6,32,94` yorumları; mimari.md §2 satır 10 ve S2 satır 54 "0,05 sn (20 Hz)". `SnapshotBuffer.MAX_FRAMES = 32` → 30 Hz'de 1,07 sn (yeterli).
- Yetkilendirme: SceneMultiplayer `poll` (`scene_multiplayer.cpp:97`) bekleyen (auth) peer'dan AUTH dışı paket gelirse `ERR_CONTINUE` basar; AUTH paketleri reliable kanal 0 [O: 4.7 kaynak].
- GodotSteam 4.22.1 (`godot4` dalı, Codeberg; GitHub deposu 2026-09-04 arşivlendi) `steam_packet_peer.cpp`: `ConfigureConnectionLanes(conn, configured_lanes, nullptr, nullptr)`, `configured_lanes = SteamProjectSettings::get_max_channels()`; `send`: `if (p_channel >= configured_lanes - 1) { WARN; p_channel = 0 }`, `m_idxLane = p_channel`; `godotsteam_multiplayer_peer.cpp` `_get_steam_packet_flags`: RELIABLE→Reliable, UNRELIABLE→Unreliable, **UNRELIABLE_ORDERED→Reliable** ("No equivalent"); `no_nagle`/`no_delay` her pakete eklenir; alış `ReceiveMessagesOnPollGroup` (≤ 255 mesaj/poll); istatistik/ping sarmalayıcısı **yok** [O].

### Bulgular ve ölçümler

#### 1. Gerçek bayt/paket ölçümü (3 oyuncu: host + 2 istemci, `faz1_full`, 2 ms)
| | 20 Hz | 30 Hz |
|---|---|---|
| İstemci yüklemesi (up), yük / tel | 2,05 KB/s / 3,1 KB/s · 38 paket/sn · ort 55 B | 2,86 KB/s / 4,27 KB/s · 51 paket/sn · ort 57 B |
| Host → bir istemci (down), yük / tel | 2,1 KB/s / 3,15 KB/s · 38 paket/sn · ort 56 B | 2,9 KB/s / 4,3 KB/s · 51 paket/sn · ort 58 B |
| Host toplam yükleme (2 istemci), tel | ≈ 6,3 KB/s | ≈ 8,6 KB/s |
| En büyük datagram | 210 B (down) / 122 B (up) | 210 / 122 |

ENet komut dökümü (`store_walk`, 20 Hz, saniye başına kararlı durumda; `*.cmds.json`) [O]:
- **İstemci yüklemesi:** `UNSEQ ch1 sync` ~20/sn × 57 B (yük 49 B: tur 1 tahmini 41 B'ye yakın) **+ `UNSEQ ch1 sys(RELAY)` ~20/sn × 63 B**. Yani istemci her senkron turunda **her uzak peer için ayrı paket** üretir: host'a düz senkron, diğer istemciye SYS_COMMAND_RELAY sarmalı (+6 B) kopya (SceneReplicationInterface `_send_sync` peer başına paket kurar; istemci hedefi host değilse SceneMultiplayer RELAY'e sarar). N oyuncuda istemci yüklemesi (N−1) × tur.
- **Her `put_packet` ayrı UDP datagramı:** aynı turdaki iki paket birleşmiyor (ENetMultiplayerPeer her gönderimde flush eder; ort datagram 55-58 B, 38 ≈ 2 × 20/sn). Paket sayısı bant genişliğinden önce büyür: 4 oyuncu 30 Hz'de istemci 90 paket/sn, host 270 paket/sn [G: ölçümden türetildi].
- **Host → istemci:** kendi senkronu 57 B + diğer istemcinin röle kopyası 63 B; ayrıca `REL ch0 sync` (ON_CHANGE delta: `busy_by/progress` tutma sırasında ~10/sn, kapı) 31 komut × 40 B, `UNREL ch1 rpc` 30 × 70-80 B (2 sn yetiştirme akışı; tur 1 R4), spawn/simplify_path/sys reliable tek seferlik; ACK ~2/sn, PING ~1,5/sn (ENet 500 ms ping aralığı) — ihmal edilir.
- **Tur 1 tahminiyle karşılaştırma:** akış başına tel maliyeti (57+28) × 20 ≈ 1,7 KB/s ≈ tahmin (1,6) ✓; ama **röle kopyası tahminde yoktu**: istemci yüklemesi 3 oyuncuda 2 × 1,7 ≈ 3,1 KB/s (ölçüldü 3,1 ✓), 4 oyuncuda ≈ 5,2 KB/s; host yüklemesi 4 oyuncuda 3 × 3 × 1,75 ≈ 16 KB/s (20 Hz), ≈ 24 KB/s (30 Hz). Hâlâ ev hattı için önemsiz [G]; NPC ekleri (host yetkili, röle yok, tek pakete paketlenir) tur 1 §9 bütçesini değiştirmez.
- Steam notu: SNS Nagle (varsayılan 5 ms, `k_ESteamNetworkingConfig_NagleTime`) aynı turdaki küçük mesajları tek UDP paketine birleştirir → Steam'de paket sayısı ENet'in yaklaşık yarısı [O: steamnetworkingtypes.h; G: bize uygulanışı].

#### 2. 20 Hz vs 30 Hz, sert ağ (150 ms + 30 ms jitter + %1 kayıp), `faz1_full`, 10'ar koşu
| | PASS | `samples_near` host↔istemci (< 32 px) | istemci↔istemci (< 48 px) | Diğer FAIL |
|---|---|---|---|---|
| **20 Hz (taban)** | **3/10** | 7 koşuda aşıldı: en kötü 32,1 · 34,7 · 40,8 · 42,5 · 50,2 · 77,0 · **264,6** px | 5 koşuda aşıldı: 61,8-71,2 px (+264,6) | 1 koşuda auth ERROR satırları (aşağıda §3) |
| **30 Hz (A/B)** | **9/10** | **10/10 geçti**, en kötü 29,1-30,4 px | 10/10 geçti, en kötü 41,2-45,3 px | 1 koşu: `c2.interaction.result_delay_ms` 417 > RTT+200 (reliable istek/sonuç kaybı → ENet yeniden gönderim; IS-013'teki "kayıpta 433-483 ms" ile aynı sınıf, ara değerlemeyle ilgisiz) |

- IS-013 tabanı 5/10'du; bu tur 3/10 (aynı sınıf: 40-77 px sıçramalar). 264 px (koşu 8, host kopyası) tek seferlik aykırı değer — tek makinede 3 Godot + proxy çalışırken süreç duraklaması olabilir [?]; dökümde "en uzun örnek boşluğu/underrun anı" olmadığı için ayrıştırılamadı (IS-059'a: dökümde `underruns` zaten var, `max_gap_ms` eklenmeli).
- Yorum: Gaffer'ın "tampon ≥ 3 × gönderim aralığı" kuralıyla tutarlı — 30 Hz'de 100 ms tampon iki ardışık kayba dayanıyor; 20 Hz'de tek kayıp + 30 ms jitter tamponu boşaltıyor [G]. **30 Hz tek başına ölçülebilir hedefi karşılıyor**; uyarlanır tampon (US-015 ikinci adım) bu veriye göre ertelenebilir (karar gereken).
- Maliyet: 30 Hz bant genişliği ×1,4 (ölçüldü), paket sayısı ×1,35; uzak kopyada CPU etkisi ihmal edilir (tampon push 30/sn).
- **30 Hz'in kod yüzeyi (US-015 için):** `player.tscn:43` `replication_interval` 0,05 → 0,0333 (ya da `PlayerTuning`'e `sync_interval` alanı + `_ready`'de `_sync.replication_interval = tuning.sync_interval` — veri odaklı, S10 kalıbı; ajan kararı); `tests/fixtures/dummy_player.tscn:23` (fikstür senaryolarının 40 px eşiği 20 Hz için türetildi, 30 Hz'de de geçer); `tests/unit/test_player.gd:147` beklentisi; `player.gd:13`, `snapshot_buffer.gd:6,32,94` yorumları; mimari.md §2/S2 "0,05 sn (20 Hz)" (koordinatör); `MAX_FRAMES` kalır. Geç katılma yetiştirmesi (`game.gd:686-703`, 20 Hz 2 sn) bağımsız, dokunulmaz.
- **US-015 AC önerisi (yeniden):** AC1 oyuncu senkron aralığı 1/30 sn (tek kaynak: `PlayerTuning.sync_interval` ya da tscn), birim testi günceller. AC2 sert ağ profilinde `faz1_full` 10 koşuda `samples_near` 10/10 (< 32 / < 48 px), toplam PASS ≥ 9/10 (reliable kayıp kaynaklı `result_delay` tek başına kabul edilir — ya da eşik `$rtt+350` olarak ayrı senaryoya alınır; karar gereken). AC3 bayt ölçümü (IS-059 `Net.stats()` varsa) istemci yüklemesi ≤ 5 KB/s, host ≤ 10 KB/s (3 oyuncu) dökümde; yoksa bu turdaki scratchpad sayımı kayıt. AC4 uyarlanır tampon **yapılmaz**; `delay` 0,10 sabit kalır; 0 ms'de davranış değişmez (`store_walk` 0/150 PASS).

#### 3. Kayıpta yetkilendirme (auth) hata satırları — yeni risk
- 20 Hz koşu 4'te `c1`'de 15 × `ERROR: Condition "len < 2 || (packet[0] & CMD_MASK) != NETWORK_COMMAND_SYS || packet[1] != SYS_COMMAND_AUTH" is true. Continuing. at: poll (scene_multiplayer.cpp:97)` — `INSIDERS_READY`'den **önce**. Mekanizma [O kaynak + G çıkarım]: host `complete_auth` paketini reliable kanal 0'dan yollar ve peer'ı hemen `connected_peers`'a alır → o andan itibaren ona senkron (unsequenced kanal 1) ve röle paketleri gider. AUTH paketi %1 kayba yakalanırsa ENet yeniden gönderimi `roundTripTime + 4 × varyans` sonra (bağlantı başında `roundTripTime` varsayılanı **500 ms**, `ENET_PEER_DEFAULT_ROUND_TRIP_TIME`) → o ~0,4-0,5 sn boyunca gelen her unsequenced paket istemcide "bekleyen peer'dan AUTH dışı paket" hatası basar (15 paket ≈ 375 ms × 40 paket/sn ✓). Zararsız (paketler zaten atılır, oturum normal kurulur, senaryo içerik olarak geçti) ama `net_smoke` ERROR satırını FAIL sayar → sert ağ profilinde PASS oranını düşüren bir **ölçüm gürültüsü**. GitHub'da bu satır için açık issue bulunamadı (arama 0 sonuç) [O].
- Öneri: sert ağ koşularında senaryo `allow_log`'una bu satırın regex'i (yalnız 150+kayıp profilinde; 0/150 ms temiz kalmalı) — karar gereken (kalite kapısı gevşetme); üst akışa küçük rapor (bekleyen peer için `ERR_CONTINUE` yerine sessiz atma) P3.

#### 4. Steam Networking Sockets: şerit (lane) / HOL ve GodotSteam MultiplayerPeer (Faz 5 notu)
- **[O] Steamworks belgesi (`ConfigureConnectionLanes`):** bir şerit içindeki mesajlar kuyruğa giriş sırasıyla gönderilir; farklı şeritler birbirini beklemez ("head-of-line blocking control"); öncelik (düşük öncelikli şerit yalnız yüksekler boşken) + ağırlık (aynı öncelikte bant paylaşımı); "3 civarı şerit iyi, > 8 çok". `SendRateMin/Max` varsayılanı 256 KB/s; `NagleTime` 5 ms; `SendBufferSize` 512 KB; tek mesaj ≤ 512 KB (parçalama/yeniden birleştirme SNS'te).
- **[O] GodotSteam 4.22.1:** şerit sayısı = `steam/multiplayer_peer/max_channels` (varsayılan 4; tur 1 steam-ag.md ile uyumlu), öncelik/ağırlık **nullptr** (eşit öncelik ve ağırlık [?: SNS nullptr davranışı belgede "eşit" olarak geçer]); `p_channel >= lanes − 1` eksik-bir denetimi → son şerit kullanılamaz, uyarı + kanal 0'a düşüş (steam-ag.md R4 doğrulandı); UNRELIABLE_ORDERED → Reliable; istatistik sarmalayıcısı yok → Steam'de bant ölçümü GodotSteam tekilinin `getConnectionRealTimeStatus` benzeri Networking Sockets çağrılarıyla [?: ad doğrulanmalı].
- **Bugünkü tasarıma etkisi [G]:** Godot'ta reliable ve unreliable aynı **kanalda** (0) gidiyor → Steam'de hepsi **şerit 0**. Şerit içi sıra "gönderim sırası"dır; ENet'teki gibi reliable kaybı aynı kanaldaki sonraki reliable'ı bekletir, unreliable senkronlar beklemez (SNS reliable akışı ayrı; sıralı teslim yalnız reliable'lar arasında) [?: SNS iç yeniden gönderimi şerit başına mı bağlantı başına mı — belgede açık değil]. Küçük mesajlarda (S2 ≤ 1 KB ilkesi) HOL etkisi ölçülemeyecek kadar küçük: 1 KB @ 256 KB/s = 4 ms. **Bozulan karar yok.** Tek dikkat: Faz 3 plan masası çizimleri gibi > 10 KB reliable yük şerit 0'a konursa 256 KB/s'de 40 ms+ boyunca aynı şeritteki senkronları kuyrukta bekletir → ayrı kanal (Godot kanal 1 = şerit 1; eksik-bir yüzünden `max_channels ≥ 3`) ve düşük öncelik; GodotSteam öncelik vermediğinden yalnız "ayrı şerit" kazanılır, öncelik yok [O/G].
- Yetiştirme RPC'si `unreliable_ordered` Steam'de reliable olur (IS-059'da `unreliable` + damga; tur 1 R4) — ölçümde bu akış 30 paket × 70-80 B / 2 sn, küçük.
- Doğrulama planı (Faz 5): `Steam.setGlobalConfigValueInt32(FAKE_PACKET_LAG_SEND/RECV 75, FAKE_PACKET_LOSS 1)` ile `faz1_full` tekrarı; `net_smoke`'un Steam taşıyıcısında proxy yerine bu ayarları kullanması (XS, cekirdek, Faz 5).

#### 5. `held`/`caught`: istemci yetkili harekette host'un "dur" kararı
- Zamanlama [G, S2 sayılarıyla]: host kararı istemcinin `net_position`'ının 50-175 ms bayat hâline dayanır (RTT/2 + ≤ 1 senkron aralığı + proxy jitter); karar RPC'si (reliable) RTT/2 sonra istemciye ulaşır → istemci kararın verildiği andan itibaren **RTT/2 + 1 kare** daha koşar: 150 ms RTT'de ≈ 20 px, 300 ms'de ≈ 36 px (220 px/sn). Diğer oyuncular donmayı RTT/2 + 100 ms sonra görür. Bayatlık (host geride görür, IS-057 ölü hesap) ile aşım (istemci ileride) **toplanır**: yakalanan oyuncunun ekranında sahip 150 ms'de ~40 px, 300 ms'de ~70 px uzaktan "tutmuş" görünebilir.
- Seçenekler:
  (a) **Yalnız host RPC'si, istemci aldığında girdiyi keser, konum istemcide kalır, host istemcinin bildirdiği durma konumunu kabul eder** (tur 1 §5 kalıbı). Artı: uzlaştırma kodu yok, "ışınlanma" yok; eksi: yukarıdaki görsel boşluk. Hissedilen gecikme girdi gecikmesi değildir (oyuncu "dur" basmadı); algılanan tek şey "uzaktan tutuldum".
  (b) İstemcide tahmini durma (istemci yerelde 28 px + 0,5 sn temas görünce kendini durdurur, host onaylamazsa serbest bırakır). Artı: boşluk küçülür; eksi: istemcideki NPC kopyası 100 ms + RTT/2 bayat (ters yönde hata), yanlış tahminde "takıldım-çözüldüm" hissi; iki yetkili karar (KR-008'e aykırı eğilim). Unity Netcode belgesi tahmin edilen eyleme sunucunun "stun" yollamasını klasik uyumsuzluk örneği olarak verir ve çözüm olarak **düzeltmeyi animasyonla gizlemeyi** ("controlled desync", "action anticipation") önerir [O].
  (c) (a) + görsel düzeltmeyi **host yetkili tarafta** yapmak: tutma anında host, sahibi oyuncunun en güncel `net_position`'ına atlatır/hamle ettirir ("lunge": ≤ 40 px, 0,1-0,2 sn, `owner_held` animasyonu); NPC host yetkili olduğundan bu her istemcide tutarlı ve ucuz; oyuncu kopyası hiç düzeltilmez. Artı: boşluk kapanır, uzlaştırma yok; eksi: tasarım dokunuşu (sahip "sıçrayarak" tutar — bakkal sahibi için makul, Fable'a soru).
  - Ek: istemcide "tutulmak üzere" ipucu (sahip yerelde 28 px içinde → kısa görsel/ses, "action anticipation") yalnız kozmetik; girdi kesilmez.
  - `held`/`caught` durumu host yetkili olduğu için **oyuncu eşitleyicisine konmaz** (istemci yetkili düğüm; tur 1 §10 kuralı). S3 `player_exposure` kalıbı: `Game` sözlüğü host yazar + reliable RPC (durum geçişi ayrık) ya da ON_CHANGE delta; istemci `Player.set_held(true)` ile girdiyi keser, `net_mode`'a `HELD` kipi ekler ki uzak kopyalar animasyonu doğru çizsin. 0,5 sn temas kuralı (AC7) kararı zaten toleranslı kılar; ÇEK (1 sn tut, 32 px) de aynı S7 doğrulamasıyla çalışır.
- Öneri: **(a) + (c)**; (b) yapılmaz.

#### 6. Godot 4.8 dev süreci
- [O] Dev snapshot'lar: 4.8 dev 1 (2026-07-06) … dev 7 (2026-09-29, **özellik dondurma**); duyurularda multiplayer/ENet/replication maddesi yok. GitHub: milestone 4.8 + `topic:multiplayer` birleşmiş PR = yalnız **#109864** "Fix peers stopping replication on deleting node they spawned with MultiplayerSpawner" (2026-06-18; birden çok peer'ın spawn ettiği düğümlerde `net_id` çakışması; **4.7.2'ye cherry-pick edildi**, bizde var); `topic:network` + 4.8 = 7 PR, hepsi mbedTLS/TLS/IP (ağ oyununa etkisi yok). Sonuç: 4.8'de bize dokunan API/davranış değişikliği yok; 4.7.2 kilidi (KR-007) rahat.

### Bizim yapımıza uygunluk değerlendirmesi
- Bant genişliği tur 1 sonucunu doğruluyor: sınırlayıcı değil (4 oyuncu 30 Hz host ≈ 24 KB/s tel). Yeni nüans: **röle kopyaları ve paket başına flush** yüzünden paket sayısı oyuncu sayısıyla kareye yakın büyür; 4 oyuncuda hâlâ düşük (host 270 paket/sn), Steam'de Nagle yarıya indirir.
- 30 Hz, mevcut S2 modelini (sabit 100 ms tampon, ileri tahmin yok) değiştirmeden sert ağ hedefini tutturuyor → en ucuz yol; uyarlanır tampon ertelenebilir.
- Steam'e geçişte kanal/şerit tasarımı değişmiyor; yalnız büyük reliable yük için ayrı kanal kuralı ve `max_channels ≥ kanal + 2` notu geçerli.

### Bulgular
**Doğru yaptıklarımız**
- Senkron yükü küçük ve tahmine yakın (49 B); ON_CHANGE delta akışı yalnız durum değişince (tutma sırasında ~10/sn × 40 B).
- `--player-scene` mutlak yol kabul ediyor → depo değişmeden A/B ölçümü mümkün (test altyapısı esnek).
- Throttle kapatma (`net.gd:31-33`) ölçümde teyit: `THROTTLE` komutu bağlantı başında 1 kez, unreliable düşüş gözlenmedi (2 ms'de underrun sıfır; sert ağda kayıp yalnız proxy'den).

**Saptığımız yerler / riskler**
- R9 20 Hz + 100 ms tampon sert ağda 3/10 — tur 1 R1'in sayısal teyidi; 30 Hz 9/10 (10/10 ara değerleme). → §2.
- R10 Kayıpta auth paketi kaybı → motor ERROR satırları → `net_smoke` yanlış FAIL (1/20 koşu). → §3.
- R11 İstemci her turda (N−1) ayrı datagram, host her istemciye (N−1)+1 datagram; Faz 5 SDR'de paket/sn sınırı yok ama Wi-Fi'da paket başına ek yük. İzlenir, aksiyon yok. → §1.
- R12 `held` görsel boşluğu (bayatlık + aşım 40-70 px) tasarımla kapatılmalı (NPC hamlesi). → §5.
- R13 Tur 1 metnindeki `ENetConnection.get_statistic` adı yanlış; IS-059 `pop_statistic` kullanmalı (sıfırlayan sayaç → Net kendi toplamını tutar).

### Öneriler (öncelik · maliyet · sahip · kalem adayı + AC)
- **P1 · XS · oynanis — US-015 kapsam daraltma: "Oyuncu senkronu 30 Hz"** — AC1: aralık 1/30 tek kaynaktan (`PlayerTuning.sync_interval` ya da tscn), `test_player.gd` ve fikstür güncel; AC2: sert ağ `faz1_full` 10 koşuda `samples_near` 10/10, PASS ≥ 9/10; AC3: 0/150 ms tüm senaryolar yeşil; uyarlanır tampon kapsam dışı (ileride veriyle açılır).
- **P1 · S · oynanis (US-008 içinde) — "held/caught ağ kalıbı"** — AC1: `held/caught` host yetkili (Game sözlüğü + reliable RPC ya da ON_CHANGE), oyuncu eşitleyicisinde değil; istemci alınca girdiyi keser, konum korunur, host istemcinin durma konumunu kabul eder (snap yok); AC2: tutma anında sahip host'ta oyuncunun en güncel `net_position`'ına ≤ 40 px hamle eder (`owner_held` animasyonu); AC3: `rescue.json` 150 ve 300 ms'de: tutulan kopyanın donma anından sonra yer değiştirmesi ≤ RTT/2 × 220 px/sn + 8 px, sahip–oyuncu mesafesi dökümde ≤ 32 px.
- **P2 · XS · cekirdek + altyapi — IS-059 eki "Telemetri ayrıntıları"** — AC1: `Net.stats()` `ENetConnection.pop_statistic` ile (sıfırlayan sayaç, Net toplar), dökümde `net_bytes {sent, recv, packets_sent, packets_recv}`; AC2: `net_smoke` `max_kbps` eşikleri bu turun ölçümüne göre (3 oyuncu 30 Hz: istemci ≤ 6 KB/s, host ≤ 12 KB/s tel; 4 oyuncu ×1,5); AC3: dökümde uzak kopya başına `max_gap_ms` (ardışık anlık görüntü arası en uzun boşluk) — 264 px aykırı değerini sınıflandırmak için; AC4 (**karar gereken**): sert ağ profilinde `allow_log` için auth satırı regex'i.
- **P3 · XS · cekirdek (Faz 5) — "Steam şerit kuralı"** — AC1: ikinci Godot kanalı kullanılacaksa `steam/multiplayer_peer/max_channels ≥ 3`; AC2: `net_smoke` Steam taşıyıcısında `FAKE_PACKET_LAG/LOSS` ile 150 ms + %1 profili; AC3: büyük reliable yük (> 1 KB) yalnız kanal 1'de (S2 ilkesi + S1 notu, koordinatör).
- **P3 · — — Üst akış:** `scene_multiplayer.cpp:97` bekleyen peer için sessiz atma önerisi (issue); bize etkisi test gürültüsü.

### Karar gereken (koordinatör)
1. 30 Hz'in varsayılan olması ve uyarlanır tamponun US-015'ten çıkarılıp "veriyle açılır" notuna düşmesi (S2 metni 20 Hz → 30 Hz, mimari §2).
2. Sert ağ profilinde motorun auth ERROR satırının `allow_log` ile izinli sayılması (yalnız kayıplı profil) ve `result_delay` için ayrı eşik (`$rtt+350`) ya da ayrı senaryo.
3. Tutma anında sahibin oyuncuya hamle etmesi (tasarım dokunuşu; Fable görüşü).
4. US-015 AC3 bayt eşiklerinin IS-059'a bağlanması (sıra: IS-059 önce mi?).

### Bir sonraki tur için açık sorular
- 264 px aykırı değer: süreç duraklaması mı, tampon mantığı mı (max_gap_ms sonrası tekrar)?
- NPC akışı gerçek ölçüm (faz2-int'te sahip + chaser + müşteriler): 6 NPC × 15 Hz tek pakete mi paketleniyor, `focus_direction` yuvarlama gerçekten delta'yı susturuyor mu?
- Steam'de şerit içi reliable yeniden gönderimi aynı şeritteki unreliable'ı bekletiyor mu (FAKE_PACKET_LOSS ile ölçüm)?
- 30 Hz ile 4 oyuncu (3 istemci) sert ağ: `samples_near` istemci↔istemci 48 px eşiği hâlâ tutuyor mu (relay yolu iki bacak)?
- `held` sırasında ÇEK isteğinin host doğrulaması (32 px) bayat konumla reddedilme oranı (150/300 ms).

### Kaynaklar (tur 2)
- Godot belgeleri: ENetConnection https://docs.godotengine.org/en/stable/classes/class_enetconnection.html · SceneTree.multiplayer_poll https://docs.godotengine.org/en/stable/classes/class_scenetree.html
- Godot 4.7 kaynak: https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/scene_multiplayer.cpp · https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/multiplayer_synchronizer.cpp · https://github.com/godotengine/godot/blob/4.7/modules/enet/enet_multiplayer_peer.cpp · https://github.com/godotengine/godot/blob/4.7/thirdparty/enet/protocol.c · https://github.com/godotengine/godot/blob/4.7/thirdparty/enet/peer.c · https://github.com/godotengine/godot/blob/4.7/thirdparty/enet/enet/enet.h
- Godot 4.8: https://godotengine.org/article/dev-snapshot-godot-4-8-dev-1/ … /dev-snapshot-godot-4-8-dev-7/ · PR #109864 https://github.com/godotengine/godot/pull/109864 · PR listeleri https://github.com/godotengine/godot/pulls?q=is%3Apr+is%3Amerged+label%3Atopic%3Amultiplayer+milestone%3A4.8 · https://github.com/godotengine/godot/pulls?q=is%3Apr+is%3Amerged+label%3Atopic%3Anetwork+milestone%3A4.8
- Steam: ISteamNetworkingSockets (ConfigureConnectionLanes, SendMessageToConnection, GetConnectionRealTimeStatus) https://partner.steamgames.com/doc/api/ISteamNetworkingSockets · GameNetworkingSockets README https://github.com/ValveSoftware/GameNetworkingSockets · steamnetworkingtypes.h https://github.com/ValveSoftware/GameNetworkingSockets/blob/master/include/steam/steamnetworkingtypes.h
- GodotSteam (Codeberg, godot4 dalı, 4.22.1): https://codeberg.org/godotsteam/godotsteam/src/branch/godot4/steam_packet_peer.cpp · https://codeberg.org/godotsteam/godotsteam/src/branch/godot4/godotsteam_multiplayer_peer.cpp · belge https://godotsteam.com/classes/multiplayer_peer/ · değişiklik günlüğü https://godotsteam.com/changelog/multiplayer_peer/ (GitHub deposu 2026-09-04 arşivlendi, Codeberg'e taşındı)
- Tahmin/stun: Unity Netcode "Dealing with latency" (client/server authority, stun örneği, action anticipation, controlled desync) https://mp-docs.dl.it.unity3d.com/netcode/2.3.2/learn/dealing-with-latency · Gaffer snapshot interpolation (tur 1)
- Proje içi: `docs/arastirma/steam-ag.md`, `docs/surec/kararlar.md` (IS-013, US-004 günlükleri), `tools/net_smoke.py`, `tools/latency_proxy.py`; ölçüm çıktıları scratchpad `agkodu-tur2-20261002-133943/`.
