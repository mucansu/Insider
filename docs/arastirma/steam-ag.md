# GodotSteam ile Steam ağına geçiş: durum ve tuzaklar (araştırma)

Tarih damgası: 2026-10-02 · Kapsam: Insiders (Godot 4.7.2, host yetkili, 2-4 oyuncu) için ENet → SteamMultiplayerPeer · Yazan: araştırma ajanı (kod yazılmadı)
İşaretler: **[O]** olgu (kaynağı aşağıda), **[K]** GodotSteam kaynak kodundan okunmuş olgu (`godot4` dalı, 2026-10-02), **[G]** görüş/çıkarım, **[?]** doğrulanmalı.

## Özet (10 satır)
1. Güncel sürüm **GodotSteam 4.22.1** (4 Eyl 2026, Steamworks SDK 1.65). GDExtension sürümü (`-gde`) Godot 4.4 ve üstü içindir, modül sürümü 4.7.2 için derlenmiş. Depo GitHub'dan **Codeberg'e taşındı**, GitHub deposu 4 Eyl 2026'da arşivlendi. [O]
2. SteamMultiplayerPeer (SMP) 4.17'den beri (Ara 2025) ana GDExtension'ın içinde. Altta ISteamNetworkingSockets P2P kullanıyor (ConnectP2P + şeritler). MultiplayerAPI, Spawner, Synchronizer ve RPC ile çalışıyor. [O/K]
3. Kritik tuzak: `server_relay` varsayılan olarak **false**. Yıldız topolojide (bizim modelimiz) `true` yapılmazsa istemciler birbirini görmez. [K]
4. `unreliable_ordered` aktarım kipi Steam'de **güvenilir** gönderilir. Bizde `Game._rpc_catchup_positions` bu kipi kullanıyor. Kanallar Steam şeritlerine eşleniyor, varsayılan 4 şerit var ve kodda bir eksik-bir hatası var: yalnız 0-2 kullanılabiliyor. [K]
5. SMP, ulaşılamayan host için `connection_failed` **üretmiyor**: istemci CONNECTING durumunda kalıyor. Zaman aşımını Net kendisi tutmalı. Kopma, Steam'in 10 sn'lik varsayılanıyla algılanıyor. [K/O]
6. Açık hata #894 (4.22.1'de hâlâ açık): aynı süreçte ayrılıp yeniden host olma ya da yeniden katılmada "zehirli peer" sorunu çıkıyor (yanlış peer kimliği). Eski SMP nesnesine referans kalmamalı. Spike bunu mutlaka sınamalı. [O]
7. Appid 480 (Spacewar) ile lobi ve P2P çalışıyor ama lobi listesinde çok çöp var ve Kasım 2025'te arama kesintisi yaşandı. Arama yerine **lobi kimliği / davet** ile katılınmalı. [O]
8. Aynı makinede iki Steam hesabı pratikte yok: **iki makine (ya da VM) + iki hesap** gerekir. CI Steam'sizdir. ENet yolu korunur, Steam'e özgü mantık ince bir adaptörde kalır. [O/G]
9. SDR, NAT'ı ve IP gizliliğini çözer. İstanbul-Stockholm veri merkezi RTT'si yaklaşık 59 ms. Ev bağlantılarıyla TR↔SE için **~65-100 ms** beklenir [G]. 150 ms RTT testlerimiz bunu kapsıyor.
10. Steam Deck'te yerel Linux build önerilir. Windows build'i Proton'da çalışacaksa SDK ≥1.63 için Proton 10.0-4 ya da üstü gerekir. [O]

---

## 1. GodotSteam sürümü, derleme türü, MultiplayerAPI uyumu
- **[O]** Codeberg sürümleri: 4.20 (24 Haz 2026, SDK 1.64), 4.21 (30 Tem, SDK 1.65), 4.22 (22 Ağu), **4.22.1 (4 Eyl 2026, SDK 1.65)**. Modül sürümleri "Godot 4.7.2 ve 4.5.2" için. `-gde` sürümleri "Godot 4.4+" ile uyumlu. IS-004'teki bulgu (4.22.1-gde, compatibility_minimum 4.4) güncel en son sürümle örtüşüyor.
- **[O]** GDExtension standart Godot dışa aktarma şablonlarıyla çalışır. Modül sürümü özel şablon ister. **[G]** Bizim için GDExtension doğru seçim: motor kilidi (KR-007) korunur, CI aynı Godot ikilisini kullanır.
- **[O]** 4.17 (Ara 2025) ile SMP ana eklentiye girdi. ExpressoBits SMP ile birlikte kullanılamaz (aynı sınıf iki kez kaydedilir), bu IS-004 kararıyla uyumlu. Sürüm notlarındaki kırıcı değişiklikler: 4.16 sinyal ve dönüş yapıları, 4.18 `lobby_chat_update` parametre adları, 4.20 "MultiplayerPeer ile üye ayrılınca lobby_chat_update çökmesi" düzeltmesi, 4.21 `isSteamRunningOnSteamDeck()` kaldırıldı, 4.22.1 SMP `close()` düzeltmesi.
- **[K] SMP iç yapısı:** `create_host()` peer 1'dir, P2P dinleme soketi ve poll group açar. `create_client(host_steam_id)` rastgele peer kimliği üretir, ConnectP2P (SymmetricConnect) kurar ve kimliği bağlantı sonrası güvenilir bir "ping" mesajıyla takas eder. `host_with_lobby` / `connect_to_lobby` **tam ağ (mesh)** kurar: her lobi üyesine bağlanır, `lobby_chat_update` ile yeni üyeyi ekler.
- **[K] Aktarım kipleri:** RELIABLE → `k_nSteamNetworkingSend_Reliable`, UNRELIABLE → `Unreliable`, **UNRELIABLE_ORDERED → Reliable** ("No equivalent"). Gelen paket yalnızca güvenilir ya da güvenilmez diye raporlanır. Azami mesaj boyutu 512 KB'tır.
- **[K] Kanallar:** Godot kanalı = Steam şeridi (lane). Şerit sayısı `steam/multiplayer_peer/max_channels` ayarından gelir (varsayılan 4). `send()` içinde `p_channel >= lanes - 1` koşulu yüzünden son şerit kullanılamaz, uyarı basılıp kanal 0'a düşülür. **[G]** Bizde özel kanal yok, sorun değil. İleride kanal eklenirse `max_channels` = kullanılan kanal sayısı + 2 olmalı.
- **[K]** `server_relay` özelliği varsayılan olarak `false` ve SceneMultiplayer'ın röle desteğini belirliyor. Resmî öğretici de `peer.server_relay = true` yapıyor. **[G]** Bizim S2/S3 düzenimiz (host üzerinden yayın, Spawner, istemci↔istemci iki bacak) bunu **zorunlu** kılıyor.
- **[O] Bilinen hatalar:** #894 (açık, 2026-09-30'da hâlâ tartışılıyor): host oturumu kapatıp yeniden host olunca ya da başka lobiye katılınca istemci yanlış peer kimliği taşıyor ve host'ta `on_sync_receive: Ignoring sync data from non-authority` hatası yağıyor. #844 (kapandı, "muhtemelen düzeldi"): eski SMP örneği bellekte kalınca yeni bağlantıda eski kimlik gidiyor. #906 (4.22.1'de düzeldi): `close()` sonrası `create_host` → ERR_CANT_CREATE. #908 (açık): `server_relay=true` iken istemci, başka bir istemcinin SteamID'sini çözemiyor (çözüm: host SteamID'leri yayar). #835 (4.17'de, Mayıs 2026'da düzeldi): peer_disconnected sonrası çökme. Godot tarafındaki iç içe Spawner "node not found" hatası (#91342) Godot 4.5'te kapandı.
- **[G]** #894/#844'ün kökü büyük olasılıkla şu: Steam geri çağrısı (`STEAM_CALLBACK` üyesi) her canlı SMP örneğine ayrı ayrı gidiyor. Bu yüzden `leave()` sonrasında eski peer'a hiçbir referans kalmamalı (Net `_peer`, `multiplayer.multiplayer_peer`, sinyal bağlantıları).

## 2. Lobi, davet, rich presence, host'un ayrılması
- **[O] Akış (GodotSteam lobi öğreticisi):** `Steam.createLobby(type, max)` → `lobby_created`. Katılma: `Steam.joinLobby(id)` → `lobby_joined` (ChatRoomEnterResponse ile). `getLobbyOwner`, `setLobbyData` / `getLobbyData`, `setLobbyJoinable(false)` (oyun başlayınca), `leaveLobby`.
- **[O] Davet:** Arkadaş listesinden "Oyuna katıl" ya da kabul edilen davet, oyun açıksa `join_requested` (GameLobbyJoinRequested_t) sinyalini tetikler. Oyun kapalıysa Steam oyunu `+connect_lobby <id>` argümanıyla başlatır. Bu argüman `OS.get_cmdline_args()` içinde gelir, `--` sonrasındaki kullanıcı argümanlarında **değil** (S6/Args bunu ayrıca okumalı). Oyun içi davet `Steam.activateGameOverlayInviteDialog(lobby_id)` ile yapılır (overlay gerekir).
- **[O] Rich presence:** `connect` anahtarı "Join Game" düğmesini açar ve GameRichPresenceJoinRequested_t / komut satırı üretir. `steam_display` için Steamworks'e yüklenmiş yerelleştirme token'ları gerekir. **[G]** Bu yüzden appid 480'de kendi `steam_display` metnimiz görünmez. Lobi tabanlı katılma (`+connect_lobby`) yeterli, rich presence Faz 5'e.
- **[G] Host ayrılırsa:** Steam lobi sahipliğini otomatik olarak başka üyeye devreder ama oyun oturumu host'tadır. Bizde host göçü yok (S3). İstemci `host_disconnected` alır, lobiden çıkar ve menüye döner (bugünkü ENet davranışı). Yeni lobi sahibi lobiyi kendiliğinden "devralmamalı". Kopma süresi: GNS varsayılanı `TimeoutConnected = 10000 ms` [O, açık kaynak GNS]. Temiz çıkışta `ClosedByPeer` hemen gelir. [K]

## 3. Test: appid 480, iki hesap, CI
- **[O]** 480 ile lobi, P2P ve overlay çalışıyor. GodotSteam belgesi 480'de "çok sayıda çöp/test lobisi" olduğunu yazıyor. #834: Kasım 2025'te Spacewar sunucusunda lobi araması birkaç hafta çalışmadı. Bakıcının önerisi: sahip olunan başka bir appid de kullanılabilir. **[ESKİ/?]** Bir forum yanıtı (Oca 2026) "480'de createLobby çalışmaz" diyor. Bu, GodotSteam belgeleri ve kullanıcı raporlarıyla çelişiyor, güvenilmez.
- **[O]** Bir makinede aynı anda tek Steam oturumu açılabilir. Bakıcıya göre yaygın yol "ayrı makineler ya da VM" (GitHub tartışma #881, Ağu 2025). Sandboxie ile çoklu Steam mümkün ama desteklenmiyor.
- **[O]** `steam_appid.txt` yalnızca Steam dışından başlatmada kullanılır ve **dağıtılmaz**. Proje ayarı `steam/initialization/app_id` de var. `steamInitEx()` sonuç kodları: 0 OK, 1 genel hata, 2 Steam çalışmıyor, 3 istemci eski. `Steam.run_callbacks()` her karede çağrılmalı. "Embed callbacks" ile "initialize on startup" birlikte açılamaz (#911, açık).
- **[G] CI stratejisi:** CI Steam başlatmaz. `initialize_on_startup=false`, Steam'i yalnızca Net, Steam taşıması istendiğinde başlatır. Eklenti CI'da da yüklenir. Bu "Steam yok → zarif düşüş" yolunu otomatik sınamayı sağlar (`steamInitEx` → status 1/2). Lobi durum makinesi, sahte bir Steam nesnesiyle (duck typing: `createLobby`, `joinLobby`, sinyaller) ve **ENet peer'ıyla** headless çalıştırılabilir: "sahte lobi" senaryosu net_smoke'a girer. Gerçek Steam yolu yalnız elle, iki makinede sınanır. Her iki makine `--dump` alır ve mevcut `expect` mantığı iki döküm dosyasına çevrimdışı uygulanır.
- **[O]** Steam yolunda yapay gecikme ve kayıp: `setGlobalConfigValueInt32(NETWORKING_CONFIG_FAKE_PACKET_LAG_SEND/RECV, ms)` ve `..._LOSS_...`. Proxy kullanmadan Steam üzerinde 150 ms denemesi yapılabilir.

## 4. SDR, NAT, gecikme, bağlantı kalitesi
- **[O]** SDR, Valve'ın röle ağıdır. Trafik kimlik doğrulamalı, şifreli ve hız sınırlıdır, IP adresleri açığa çıkmaz. P2P için yalnızca `CreateListenSocketP2P`/`ConnectP2P` yeterli, port yönlendirme gerekmez. Rölenin yol tahmini "tutucu"dur. Doğrudan IP yolu daha iyi ya da daha kötü olabilir. `initRelayNetworkAccess()` açılışta çağrılırsa hazırlık "birkaç saniye" sürer.
- **[O]** GNS'de ICE (doğrudan/NAT delme) varsayılanı "kullanıcı varsayılanı" (`P2P_Transport_ICE_Enable_Default`). **[?]** Steam istemcisinde bu, "IP paylaşımı yalnız arkadaşlarla" ayarına karşılık geliyor gibi (doğrulanmadı). Arkadaş co-op'unda doğrudan yol açılabilir, açılmazsa röle devreye girer.
- **[O]** İstanbul↔Stockholm veri merkezi ölçümü (WonderNetwork, 18 Eyl - 2 Eki 2026): ortalama **~58,8 ms**, ara sıra 100 ms üstü sıçramalar var. **[G]** Ev hattı ve Wi-Fi ile TR↔SE için 65-100 ms RTT beklenir. S2 toleransları ve 150 ms testleri yeterli payı bırakıyor.
- **[O] Kalite API'leri:** `Steam.getConnectionRealTimeStatus(handle, lanes, true)` → `connection_status.ping`, `local_quality`, `remote_quality`, `pending_reliable`, `queue_time`... `getConnectionInfo(handle)` → `remote_pop`, `pop_relay` (röle mi doğrudan mı). `getDetailedConnectionStatus` ayrıntılı metin döner. Handle şöyle alınır: `peer.get_peer(id).get_connection_handle()` [K]. Ayrıca `getRelayNetworkStatus()` / `relay_network_status` sinyali ve `estimatePingTimeFromLocalHost(location)` (lobiye host'un ping konumu yazılırsa katılmadan önce tahmin yapılabilir).

## 5. ENet ve Steam aynı build'de
- **[G] Desen:** S1 imzaları değişmez. Net içinde `_create_peer()` bir taşıma fabrikası olur. Steam'e özgü her şey `autoload/net_steam.gd` adlı tek dosyada durur (autoload değil, Net'in çocuğu ya da RefCounted). Bu dosya yalnız `ClassDB.class_exists("SteamMultiplayerPeer") and Engine.has_singleton("Steam")` doğruysa `load()` ile yüklenir. Kod `Steam` tanımlayıcısını ve `SteamMultiplayerPeer` tipini **doğrudan yazmaz**: `Engine.get_singleton("Steam")` / `ClassDB.instantiate()` ile `Object` üzerinden çağırır. Böylece eklenti bir makinede yüklenemezse (ör. eksik `steam_api64.dll`) Net derlenmeye devam eder ve ENet yedeği yaşar. Statik tipleme kuralı yalnız `untyped_declaration`'ı hata sayıyor, `Object` tipli değişken buna uyuyor.
- **[G] Hata yönetimi:** (a) Steam başlatılamazsa (`status` ≠ 0) Net Steam'i "kullanılamaz" işaretler, menü yalnız ENet'i gösterir. (b) Katılmada SMP `connection_failed` üretmediği için `connect_timeout_ms` bekçisi Net'te kalır. (c) `lobby_joined` yanıtı ≠ 1 ise (dolu, yok, kilitli) `connection_failed` döner. (d) Steam ağ geri çağrıları için Net `_process` içinde `run_callbacks()` çağırır (ya da Steam başlatılınca bir kez etkinleştirir).
- **[G] Sürüm uyuşmazlığı:** Host lobiye `setLobbyData(id, "v", <oyun sürümü + git kısa özeti>)` yazar. İstemci `lobby_joined` sonrası bunu okur, uyuşmazlıkta lobiden çıkar ve "sürüm farklı" mesajı gösterir. Mevcut Game el sıkışmasındaki sürüm kontrolü ikinci savunma hattı olarak kalır. Kendi appid'mizde `Steam.getAppBuildId()` beta dalı farkını da yakalar (480'de anlamsız).
- **[G]** Topoloji: `connect_to_lobby` (mesh) yerine **`create_host` + `create_client(getLobbyOwner(lobby))` + `server_relay = true`** (yıldız). Bu, ENet semantiğini birebir korur (Game auth, Spawner, host üzerinden röle, `get_ping_ms` yalnız host için). Mesh'te istemciler host'tan önce birbirine bağlanabilir ve SceneMultiplayer el sıkışması varsayımlarımız bozulur.

## 6. Steam Deck / Proton
- **[O]** SDK 1.63 ve üstüyle derlenen Windows build'i Proton'da "No SteamClient023" hatası verir. Çözüm: Proton 10.0-4+ / Experimental ya da yerel Linux build. Linux'ta `libsteam_api.so` çalıştırılabilir dosyanın yanında olmalı. Flatpak Steam ve Wayland'de overlay sorunları var (#839 açık). Deck OLED'de kayan klavye sorunu var (#852).
- **[O]** `isSteamRunningOnSteamDeck()` 4.21'de kaldırıldı. **[G]** Deck algılaması için `OS.get_environment("SteamDeck") == "1"` kullanılabilir **[?]**. Faz 1'de Linux build zaten var (KR-015), Deck için ayrıca yerel Linux depotu yeterli.

## 7. Faz 2 Steam spike: minimum adımlar
1. Eklentiyi edin: Codeberg'den `v4.22.1-gde` indir, `addons/godotsteam/` altına yalnızca win64 + linux64 kütüphanelerini koy. Ya da get_godot.sh gibi sağlama toplamlı bir `tools/get_godotsteam.sh` yaz. Proje ayarları: `initialize_on_startup=false`, `embed_callbacks=false`, `app_id=480` (ya da `steamInitEx(480)`).
2. `net_steam.gd` adaptörü (§5) ve Args ekleri: `--steam-host`, `--steam-join=<lobby_id>`, ayrıca ham `+connect_lobby <id>`.
3. Host akışı: createLobby (FRIENDS_ONLY, 4) → `v` verisi → SMP `create_host` + `server_relay=true`. İstemci akışı: joinLobby → sürüm kontrolü → `create_client(owner)`.
4. `get_ping_ms` → `getConnectionRealTimeStatus`. Döküme `transport`, `lobby_id`, `relay_pop` eklenir.
5. Ayrıl/yeniden host ol döngüsü (#894) ve host kopması elle sınanır. Sonuçlar spike raporuna yazılır.

## 8. Önerilen mimari değişiklik taslağı (öneri; koordinatör karar verir)
- **S1'e ek:** `func host_lobby(max_peers: int = 4) -> Error` (Steam; sonuç `lobby_ready(lobby_id: int)` sinyaliyle gelir). `func join_lobby(lobby_id: int) -> Error`. `func steam_available() -> bool`. `func transport() -> StringName` (`&"enet"` / `&"steam"`). `signal lobby_ready(lobby_id: int)`. Mevcut `host/join` ENet olarak kalır. Steam sınıflarına yalnız `autoload/net_steam.gd` dokunur (S1 cümlesi buna göre genişler).
- **S1 uygulama notu:** Steam'de `server_relay = true`, yıldız topoloji, `run_callbacks` her karede, bağlantı bekçisi Net'te, `leave()` eski peer'a referans bırakmaz, `unreliable_ordered` Steam'de güvenilir olur.
- **S2'ye ek:** Yüksek frekanslı akışlarda `unreliable_ordered` kullanılmaz, `unreliable` kullanılır (Steam'de ordered kip güvenilire dönüşüp tıkanmada satır başı engellemesi yaratır). `Game._rpc_catchup_positions` bu kurala göre gözden geçirilir. Özel RPC kanalı kullanılacaksa `steam/multiplayer_peer/max_channels` ≥ kanal + 2.
- **S3'e ek:** `players()` girdisine `steam_id: int` eklenir (host yayar; #908 nedeniyle istemci↔istemci eşlemesi SMP'den alınamaz). Lobi sürüm anahtarı `v` el sıkışmasındaki sürümle aynı kaynaktan gelir.
- **S6'ya ek:** `--steam-host`, `--steam-join=ID`, `+connect_lobby ID` (OS argümanı).

## 9. Faz 2 spike kalem taslağı
**IS-0xx: Steam spike — 480 lobisiyle 2 kişi hareket (cekirdek; altyapi: eklenti edinme ve CI)**
- AC1: CI (ENet) yeşil kalır. Eklenti CI'da yüklenir ama Steam başlatılmaz, import ve birim testleri yeni uyarı-hata vermez.
- AC2: Steam kapalıyken `Net.steam_available()` false döner, `host_lobby()` hata döner. Aynı build'de ENet host/katıl çalışır. Bu, CI'da birim testiyle doğrulanır.
- AC3: İki makine, iki hesap, appid 480. Host FRIENDS_ONLY lobi açar. İstemci `--steam-join=<id>` ile katılır, 5 dk boyunca iki oyuncu birbirini hareket ederken görür. İki taraftaki dökümlerde birbirinin konumu S6 eşikleri içinde tutarlıdır.
- AC4: İstemcide `get_ping_ms(1)` > 0 döner. Dökümde `relay_pop` ya da "doğrudan" bilgisi yer alır.
- AC5: Host süreci kapanınca istemci ≤ 12 sn içinde `host_disconnected` alır ve menüye döner. İstemci çıkınca host `peer_disconnected` alır.
- AC6: Aynı süreçte 3 kez ayrıl → yeniden host ol ve ayrıl → yeniden katıl çalışır, sync hatası çıkmaz (#894). Başarısızsa geçici çözüm ve hata kaydı "Karar gereken" olarak raporlanır.
- AC7: Var olmayan ya da dolu lobiye katılma `connection_failed` ile ≤ `connect_timeout_ms` + 1 sn içinde biter. Sürüm uyuşmazlığında katılım reddedilir ve mesaj gösterilir.
- AC8 (isteğe bağlı): Arkadaş listesinden "Oyuna katıl" ya da overlay daveti çalışır (`join_requested`, `+connect_lobby`).
- Kapsam dışı (Faz 5): rich presence, 30 dk TR↔SE, Steam Deck, kendi appid'miz, 3-4 oyunculu Steam testi.

## 10. Kullanıcıdan gerekenler
- İki Steam hesabı (ikincisi ücretsiz açılabilir). Hesaplar birbirine arkadaş eklenmeli. **[?]** Sınırlı (hiç harcama yapmamış) hesap arkadaşlık isteği gönderemez ama kabul edebilir: isteği ana hesap göndermeli.
- İki makine (ya da biri VM). Her ikisinde Steam istemcisi güncel, açık ve oturum açık olmalı, overlay açık olmalı. İlk açılışta güvenlik duvarı izni verilmeli. Build paylaşımı için bir zip/bulut yolu.
- Faz 5 için İsveç'teki arkadaşın Steam hesabı ve 30 dakikalık ortak test zamanı. Kendi appid için KR-014 (100 $).

## 11. Riskler
- **R1 (yüksek):** #894 yeniden bağlanma hatası, menüye dönüp yeniden oynama akışını bozabilir. Azaltma: AC6, peer'ı tamamen serbest bırakma, gerekirse süreç yeniden başlatma ya da upstream yama.
- **R2:** Bakım riski: SMP tek bir katkıcıya bağlı ("MultiplayerPeer benim alanım değil" — gramps, #894). Depo Codeberg'e taşındı, eski GitHub bağlantıları kırılabilir.
- **R3:** 480'de lobi altyapısı kesintisi (#834). Azaltma: lobi kimliğiyle ya da davetle katılım, gerekirse sahip olunan başka bir appid.
- **R4:** Kip farkı (ordered → reliable) ve şerit sınırı nedeniyle Steam'deki zamanlama ENet testlerinden farklı davranabilir. Azaltma: Steam'de FAKE_PACKET_LAG ile 150 ms elle tekrar.
- **R5:** CI Steam yolunu sınayamaz, Steam'e özgü hatalar elle teste kalır. Azaltma: ince adaptör ve sahte lobi + ENet senaryosu.
- **R6:** Eklenti bir oyuncu makinesinde yüklenemezse doğrudan `Steam` başvurusu Net'i düşürür. Azaltma: §5 dinamik yükleme.

## Kaynaklar
- Codeberg sürümleri: https://codeberg.org/godotsteam/godotsteam/releases · Kaynak (`godot4` dalı): https://codeberg.org/godotsteam/godotsteam/src/branch/godot4/godotsteam_multiplayer_peer.cpp , `steam_packet_peer.cpp`, `godotsteam_project_settings.cpp`
- Arşiv notu: https://github.com/GodotSteam/GodotSteam · Değişiklik günlüğü: https://godotsteam.com/changelog/godot4/
- SMP blog (4.16, 4.17): https://godotsteam.com/blog/category/multiplayerpeer/ · SMP sınıfı: https://godotsteam.com/classes/multiplayer_peer/ · Öğretici: https://godotsteam.com/tutorials/multiplayer_peer/
- Lobiler: https://godotsteam.com/tutorials/lobbies/ · Başlatma: https://godotsteam.com/tutorials/initializing/ · Dışa aktarma: https://godotsteam.com/tutorials/exporting_shipping/
- Sorunlar: https://codeberg.org/godotsteam/godotsteam/issues/894 , /908 , /911 , /906 , /844 , /834 , /835 , /839 , /852
- Linux/Windows sorunları: https://godotsteam.com/issues/linux_issues/ , https://godotsteam.com/issues/windows_issues/
- Networking API: https://godotsteam.com/classes/networking_sockets/ , https://godotsteam.com/classes/networking_utils/
- Steamworks: https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay , https://partner.steamgames.com/doc/api/ISteamNetworkingSockets , https://partner.steamgames.com/doc/api/ISteamNetworkingUtils , https://partner.steamgames.com/doc/api/ISteamFriends
- GNS varsayılanları: https://github.com/ValveSoftware/GameNetworkingSockets (steamnetworkingtypes.h, csteamnetworkingsockets.cpp)
- Test tartışması: https://github.com/GodotSteam/GodotSteam/discussions/881 · 480 forum iddiası (çelişkili): https://forum.godotengine.org/t/if-i-want-to-test-the-online-multiplayer-functionality-using-steam-do-i-need-to-register-a-game-or-will-using-the-480-app-be-sufficient/131625
- Godot #91342: https://github.com/godotengine/godot/issues/91342 · RTT: https://wondernetwork.com/pings/Istanbul/Stockholm
