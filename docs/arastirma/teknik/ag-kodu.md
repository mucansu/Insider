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
