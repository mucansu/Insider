# Operasyon ve güvenilirlik: arkadaş co-op'unun canlıda ayakta kalması (teknik araştırma)

Yazan: arastirmaci · Kod yazılmadı · İşaretler: **[O]** olgu (kaynak aşağıda) · **[K]** proje kodundan okunan olgu · **[G]** görüş/çıkarım · **[?]** doğrulanmalı · **[ESKİ]** Godot 4.7.2'ye uymayan/eski bilgi.

---

## Tur 1 — 2026-10-02

### Kapsam
Tailscale ile barındırma pratikleri (MagicDNS, ACL, ping, MTU/UDP, Windows güvenlik duvarı) · NAT/UDP delme alternatifleri (Steam SDR Faz 5) · çökme raporlama (Godot crash handler, `OS` günlükleri, `user://logs`, Sentry Godot SDK) · yapılandırılmış günlük (seviye, dosya, döndürme) · oyun testinde hata yakalama ve log toplama akışı · tekrar oynatma (girdi günlüğü/replay) · kayıt dosyası güvenliği ve sürümleme (JSON + `schema_version`, göç testi, bozuk dosya) · sürüm/protokol uyumluluğu ve build kimliği · asgari hile önlemi · güncelleme dağıtımı (itch butler, Steam branch) · telemetri (KVKK/GDPR).
Dayanak: KR-020 (önce aramızda MVP, ENet + Tailscale), KR-009 (bağımlılıksız test), mimari S1/S3/S6, tuzaklar.md, steam-ag.md, rahatlik-ux.md §2 (UX-1/UX-2).

### Mevcut durum (dosya:satır)
- **Taşıma ve kopma [K]:** `autoload/net.gd:25` `connect_timeout_ms = 5000` (ENet yeniden deneme adımına yuvarlanır, ~7,5 sn); `net.gd:31-33` throttle kapalı (deceleration 0, US-001 t2); `net.gd:221-230` yalnız bağlanma süresince kısa zaman aşımı, kabulde ENet varsayılanlarına dönüş (`net.gd:233-239`); `net.gd:252-259` RTT = `PEER_ROUND_TRIP_TIME` (düzgünleştirilmiş). `host_disconnected` ENet'in varsayılan kopma algısına bağlı (ENet varsayılan `timeout_max` 30 sn [O, ENet]; mimari S2 ping ölçümü ayrı, IS-026).
- **Protokol sürümü [K]:** `autoload/game.gd:46` `PROTOCOL_VERSION := 1`; `game.gd:422-429` uyuşmazlıkta `disconnect_peer` — istemciye **neden gitmiyor**, istemci yalnız `connection_failed` görür (`ui/main_menu.gd:180` → `MENU_ERROR_CONNECTION_FAILED` "Adresi ve portu kontrol et" — yanlış teşhis). El sıkışma `var_to_bytes`/`bytes_to_var` nesnesiz [K, güvenli].
- **Build kimliği [K]:** `project.godot` `application/config/version` **yok**; `export_presets.cfg` `application/file_version` ve `product_version` boş; menüde sürüm yazısı yok (`ui/main_menu.gd` grep: sürüm/build geçmiyor). Steam-ag §5 lobide `v` anahtarı önerisi var ama ENet yolunda yok.
- **Günlük [K]:** `project.godot`'ta `[debug] file_logging` ayarı yok → Godot varsayılanı geçerli: masaüstünde `debug/file_logging/enable_file_logging.pc = true`, yol `user://logs/godot.log`, 5 dosya döndürme [O, ProjectSettings]. Yani arkadaş build'i zaten `%APPDATA%/Godot/app_userdata/Insiders/logs/godot.log` yazıyor; README bunu söylemiyor, kullanıcıdan log isteme akışı yok. `flush_stdout_on_print` release'te false [O]: çökmede son satırlar tamponda kalabilir. Mimari §6: `print` yerine `push_warning/push_error`; yapılandırılmış seviye/kategori yok; `tools/net_smoke.py:125-126` ERROR/WARNING satırlarını regex'le süzüyor (`allow_log`, `deny_warnings`).
- **Döküm [K]:** S6 `--dump` yalnız çıkışta (`main.gd:259-267`), JSON; `events` halka tamponu 256 (`game.gd:49`); `samples` 0,2 sn konum örnekleri yalnız otomasyonda (`main.gd:270-288`). Oyuncu makinesinde gerçek oyunda döküm yazılmıyor.
- **Çökme [K]:** `debug/settings/crash_handler/message` varsayılan; `.console.exe` sarmalayıcı var (README "sorun bildirirken onu kullanın"); backtrace için sembol yok (resmî şablon).
- **Kayıt [K]:** Faz 4'te; bugün `user://` yazan tek şey Godot'un kendi log'u. Bot/senaryo JSON'ları `Args.load_bot` (`args.gd:185-201`) biçim denetimli, bozuk adımı uyarıyla atlıyor — kayıt yükleyici için iyi örnek.
- **Dağıtım [K]:** `tools/export.sh` Windows (pck gömülü, console exe) + Linux tar.gz; CI yalnız `main` push'unda artifact (30 gün) (`.github/workflows/ci.yml:53-104`); imza yok; sürüm damgası yok (artifact adı `github.sha`).
- **Hile [K]:** S2 istemci yetkili hareket, host konum doğrulamaz; etkileşim/gürültü host doğrulamalı (S7/S8 toleranslar); ağda nesne çözme yok.

### En iyi uygulamalar ve seçenekler

#### A. Tailscale ile barındırma
| Konu | Ne | Artı / eksi | Kaynak |
|---|---|---|---|
| Bağlantı türü | Tailscale sırayla doğrudan (UDP) → peer relay → DERP dener; `tailscale status` satırında `direct` / `relay` / `peer-relay` görünür; `tailscale ping <ad>` önce "via DERP", sonra doğrudan `ip:port`'a geçer **[O]** | DERP TCP+TLS üstünden aktarır → ek gecikme ve tamponlama; oyun çalışır ama ping artar **[O]** | tailscale.com/kb/1257, blog NAT traversal pt3 |
| Doğrudan yol | Engeller: UDP'yi engelleyen ağ, iki tarafta da "hard NAT" **[O]**. Çözüm: ev modeminde NAT-PMP/UPnP, Tailscale'in UDP 41641 portuna izin **[O]** | TR↔SE ev hatlarında genelde doğrudan **[G]**; kurumsal/otel ağında relay | kb/1257 |
| MTU | Tailscale arabirim MTU'su **1280** (IPv6 asgarisi); daha büyük paket sessizce düşebilir **[O, forum/komünite; resmî KB doğrulanmadı [?]]**. ENet varsayılan MTU'su 1392 (1.3.18 `enet.h`) **[?]**; MTU'yu aşan paketi ENet parçalar ve **güvenilire çevirir** (unreliable bile olsa) **[O, ENet listesi]**. Godot ENetConnection MTU ayarı sunmaz **[O]** | Bizim paketler küçük (20 Hz konum, kısa RPC'ler) → sorun beklenmez **[G]**; ama `_rpc_players` sözlüğü, `_rpc_catchup_positions` ve ileride plan masası çizimi büyürse 1280'i aşan paket Tailscale'de IP parçalanmasına düşer: tek parça kaybı = paket kaybı | ENet-discuss 2014/2024; Godot ENetConnection docs; Godot thirdparty README (ENet 1.3.18) |
| MagicDNS | Kısa makine adı yalnız **aynı tailnet**te çözülür; başka tailnet'ten paylaşılan makineye yalnız FQDN (`makine.tailnet-adi.ts.net`) ile ulaşılır (v1.4+) **[O]** | README "MagicDNS açıksa makine adı da olur" eksik: arkadaş **kendi** hesabıyla girip paylaşım aldıysa kısa ad çalışmaz | kb/1081, kb/1084 |
| Paylaşım vs davet | Makine paylaşımı tüm planlarda var; alıcı kendi tailnet'inin sahibi/yöneticisi olmalı; paylaşılan makine varsayılan "karantinada" (yalnız gelen bağlantıya yanıt verir — host için tam uygun) **[O]** | Davet (aynı tailnet) daha basit: kısa ad çalışır, ACL tek yerde | kb/1084 |
| ACL | Varsayılan politika "herkes herkese" **[O]**; kısıtlanırsa kural `{"action":"accept","src":[...],"dst":["host:udp:7777"]}` biçiminde, kurallar yönlüdür (host→istemci ayrıca gerekmez, UDP yanıtı durum bilgisiyle geçer) **[O]** | Arkadaş tailnet'inde ACL'ye dokunmamak en güvenlisi **[G]** | kb/1018 |
| Windows güvenlik duvarı | Godot ilk `host()`'ta Windows "bu uygulamaya izin ver" sorar; **Özel** ağa izin şart (README'de var). Tailscale arabiriminin profil sınıfı (Özel/Genel) kurulumda değişebilir **[?]** → "yalnız Özel" izni verilmiş exe'de Tailscale trafiği düşebilir. Kesin yol: gelen UDP 7777 kuralını exe'ye göre, tüm profiller için eklemek (`netsh advfirewall firewall add rule name="Insiders" dir=in action=allow program="…\Insiders.exe" protocol=udp localport=7777`) **[G]** | Teşhis sırası: `tailscale status` (relay mi) → `tailscale ping` → host'ta `netstat -an \| findstr 7777` → güvenlik duvarı kuralı | README; Tailscale KB |
| Teşhis komutları | `tailscale status`, `tailscale ping <ad>`, `tailscale netcheck` (NAT türü, DERP gecikmeleri), `tailscale bugreport` **[O]** | Oyun içinde tekrar etmeye değmez; README/menü "Bağlanamıyor musun?" kutusuna üç satır yeter | kb/1023 |

#### B. NAT/UDP delme alternatifleri (ENet dönemi)
| Seçenek | Ne | Artı / eksi | Kaynak |
|---|---|---|---|
| Tailscale (mevcut) | Her oyuncuda istemci; WireGuard; DERP yedeği | Sıfır kod; her arkadaş kurulum + hesap; relay'de gecikme | KR-020 |
| netfox.noray (MIT) | Kendi barındırdığınız küçük orkestratör: UDP delme + delme başarısızsa röle; Godot eklentisi ENet'le aynı soketi kullanır **[O]** | Sunucu kiralamak/çalıştırmak gerekir (VPS); arkadaş kurulumu sıfır; MVP için fazla **[G]** | github.com/foxssake/netfox |
| WebRTC (`WebRTCMultiplayerPeer` + GDExtension, STUN/TURN) | Tarayıcı sınıfı NAT geçişi | Sinyal sunucusu + TURN gerekir; GDExtension bağımlılığı; bizim mimariyi değiştirir **[G]** | Godot docs |
| Steam SDR (Faz 5) | Valve rölesi, IP gizli, port yönlendirme yok **[O]** | Plan zaten bu; steam-ag.md | partner.steamgames.com |
**[G] Sonuç:** Faz 1-4 için Tailscale doğru; alternatif aramak yerine Tailscale teşhisini oyun içine/README'ye gömmek daha ucuz. noray yalnız "arkadaş Tailscale kurmak istemiyor" durumunda yedek fikir.

#### C. Çökme raporlama
| Seçenek | Ne | Artı / eksi | Kaynak |
|---|---|---|---|
| Godot crash handler | Çökmede stderr'e "handle_crash: Program crashed…" + backtrace; mesaj `debug/settings/crash_handler/message` ile özelleştirilir **[O]** | Resmî export şablonlarında sembol yok → adresler anlamsız; anlamlı backtrace için şablonu kendin derlemen gerekir **[O]**. Windows'ta console exe açıksa görünür, aksi hâlde yalnız log dosyasında | Godot logging docs |
| GDScript backtrace (4.5+) | Release'te `debug/settings/gdscript/always_track_call_stacks = true` ile script hatalarında çağrı yığını; `Engine.capture_script_backtraces()` **[O]** | Küçük performans maliyeti **[O]**; en değerli teşhis bu: çökmelerin çoğu motor değil script hatası olacak **[G]** | Godot 4.5 notları, ScriptBacktrace docs |
| `Logger` sınıfı (4.5+) | `OS.add_logger()` ile motor mesaj akışına girilir: `_log_message(msg, error)` ve `_log_error(function, file, line, code, rationale, editor_notify, error_type, script_backtraces)` **[O]** | Kendi dosya/döndürme/seviye katmanı yazılabilir, bağımlılık yok (KR-009 ruhu); hata anında backtrace + son N olay ("breadcrumb") birleştirilebilir | Godot logging docs; forum 127006 |
| Sentry Godot SDK | GDExtension; **Godot 4.5+** (1.x/2.x), en yeni 2.3.0 **[O]**; Windows/Linux native çökme (sentry-native), script hataları, log/breadcrumb, release `app@version` otomatik, `send_default_pii=false`, IP toplamaz **[O]** | Dış servis + hesap; GDExtension bağımlılığı; arkadaş oyunu için fazla, ama Steam öncesi "çökme 0" ölçütü için (EP-05) ciddi aday **[G]**. KVKK: açık rıza + gizlilik metni gerekir (aşağıda) | docs.sentry.io/platforms/godot, github getsentry/sentry-godot |
| Forge Logger (asset) | F8 ile oyun içi rapor: ekran görüntüsü + log + sahne/build bilgisi, çevrimdışı kuyruk **[O]** | Üçüncü taraf arka uç; incelenmedi; kendi 1 ekranlık "Hata bildir" akışı daha uygun **[G]** | asset 5321 |

#### D. Yapılandırılmış günlük
- **Godot yerleşik:** `user://logs/godot.log`, her oturumda yeni dosya, eskiler tarihle yeniden adlandırılır, 5 dosya tutulur **[O]**. `--log-file <yol>` komut satırı ile yol değişir **[O]**. Satırlar yapılandırılmamış (print/err çıktısı).
- **[G] Önerilen asgari biçim:** tek satır, `t=+12.345 lvl=W cat=net peer=2 msg="…"` (anahtar=değer; JSON satırı da olur ama göze zor). Kategoriler: `net`, `session`, `interact`, `ai`, `ui`, `save`. Seviye: D/I/W/E. Release'te D kapalı. Ağ olayları (bağlan/kop/ret nedeni/ping sıçraması > 2×) **her zaman** I seviyesinde; "tekrar eden ağ log'u yok" kuralı (mimari §6) → aynı mesaj ≥ 1 sn içinde tekrarlanmaz (sayaçla bastırma).
- **Halka tampon ("breadcrumb"):** son 200 I/W/E satırı bellekte; hata/çökme raporuna ve `--dump`'a eklenir. `Game._events` zaten oturum olaylarını tutuyor (`game.gd:477-482`) — aynı fikir, günlük katmanına genellenir.
- **Döndürme:** Godot'un 5 dosya kuralı yeter; kendi dosyamız yazılırsa boyut sınırı (ör. 2 MB) + 3 dosya.
- **Flush:** release'te stdout tamponlu **[O]**; dosya log'u için `FileAccess.flush()` W/E'de hemen, I'de saniyede bir **[G]**.

#### E. Oyun testinde hata yakalama ve log toplama akışı
**[G] Arkadaşın yapacağı iş ≤ 2 tıklama olmalı:**
1. Oyun içi `F8` / duraklat menüsü "Sorun bildir": tek satır metin + otomatik paket: `user://reports/<tarih>_<build>.zip` = son log + `collect_dump()` JSON + ekran görüntüsü (IS-022 `take_screenshot` zaten var) + sistem bilgisi (`OS.get_name/get_version_alias/get_processor_name/get_video_adapter_driver_info`, `Engine.get_version_info`, build kimliği, taşıma, ping, peer sayısı). Paket oluşunca `OS.shell_show_in_file_manager(path)` ile klasör açılır; arkadaş Discord'a sürükler. Sunucu yok, rıza sorunu yok (dosyayı gönderen oyuncunun kendisi).
2. Host tarafında aynı tuş: tüm peer'ların durumu host dökümünde zaten var (players, ping_ms, events).
3. Eşleştirme: rapor adında build kimliği + oturum kimliği (host açılışında rastgele 6 hane, el sıkışmada istemcilere gider) → üç oyuncunun raporu aynı oturuma bağlanır.
4. Senkron şikâyetleri ("beni görmemişti") için: host ve istemci raporlarındaki `samples` + `events` zaman damgalarıyla karşılaştırılır (S6 `samples_near` mantığı çevrimdışı uygulanır; net_smoke'un `expect` motoru iki döküm dosyasına koşturulabilir — steam-ag §3'te aynı öneri).
5. Rapor önceliği: çökme (process yok → sonraki açılışta "son oturum temiz kapanmadı" bayrağı: `user://session.lock` açılışta yazılır, temiz çıkışta silinir; bayrak varsa menüde "Geçen oyun çöktü, logu gönder?" **[G]**).

#### F. Tekrar oynatma (replay)
| Yaklaşım | Ne | Bize uyum | Kaynak |
|---|---|---|---|
| Girdi günlüğü + belirlenimci sim (DOOM LMP, Klotho) | Yalnız girdiler + tohum kaydedilir; aynı sim aynı sonucu üretir | **Uymaz [G]:** bizim sim belirlenimci değil (float fizik, 3 peer'ın bağımsız saatleri, istemci yetkili hareket, ara değerleme). Tam replay = tüm oyunun lockstep'e dönüşmesi | Klotho asset 5234 |
| Durum anlık görüntü günlüğü ("ghost") | Her peer kendi gördüğü durumu (konumlar, kipler, NPC kademe/yön, olaylar) 10-20 Hz kaydeder; oynatma = ara değerleme ile çizim | **Uyar:** `main.gd` `samples` ve `Game._events` bunun %60'ı; eksik: NPC/prop durumları, görüş sonuçları, host kararları (ret nedeni) | main.gd:270-288 |
| Host olay günlüğü | Host'un her kararını (etkileşim kabul/ret + neden, algı eşik geçişleri, uyarı kademesi) zaman damgalı yazması | **Uyar, en ucuz ve en değerli [G]:** "beni görmemişti" tartışmasını host günlüğü bitirir; muhafiz-davranisi I6 (aynı tohum → aynı olay günlüğü) CI'da da kullanılır | GDD §9.2, muhafiz-davranisi.md |
**[G] Öneri:** GDD "girdi günlüğü/replay" maddesi → "host karar günlüğü + peer durum izi" olarak daraltılsın (yol-haritasi.md zaten Faz 3'e itmiş). Görsel oynatıcı (iz dosyasını seviyede çizen geliştirici sahnesi) Faz 3 sonu; önce dosya biçimi.

#### G. Kayıt dosyası güvenliği ve sürümleme (Faz 4 hazırlığı)
- **Biçim:** JSON (tuzaklar.md: `.tres` yüklemek gömülü betik çalıştırabilir **[O]**). `store_var(value, false)` da güvenli ama ikili ve göç/okunurluk zor **[G]**. Godot docs JSON'un Vector2/Color'ı elle çevirmeyi gerektirdiğini söyler **[O]** — `Game.to_json_value()` (`game.gd:236-262`) zaten bunu yapıyor; tersi (`from_json`) yazılır.
- **Zarf:** `{"schema_version": 3, "game_version": "0.4.1+a1b2c3", "saved_at": "...", "checksum": "sha256(payload)", "payload": {...}}`. `checksum` hile değil **bozulma** tespiti (yarım yazılmış dosya).
- **Atomik yazım:** `kayit.json.tmp` yaz → `flush/close` → `DirAccess.rename_absolute(tmp, kayit.json)`; önceki dosya `kayit.json.bak` olarak tutulur; okuma sırası `json` → bozuksa `bak` **[O, yaygın pratik]**.
- **Göç:** `migrate(data) -> data` zinciri `v1→v2→v3`; alan silme yok, yeni alan varsayılanla; `tests/fixtures/saves/v1.json…` her sürüm için fikstür ve "en eski fikstür bugünkü yükleyiciden geçer" birim testi **[G]**. Gelecek sürüm (schema > bilinen) → "daha yeni sürümle kaydedilmiş" mesajı, dosya **ezilmez**.
- **Doğrulama:** `JSON.parse` hata satırı; şema kontrolü `Args.parse_bot_step` tarzı (tip + aralık), bilinmeyen anahtar yoksay-uyar; dizi uzunlukları ve sayılar sınırlı (dev dosya host'u dondurmasın — `_sanitize_name` ile aynı refleks).
- **Ağ:** kayıt host'ta; istemcilere yalnız türetilmiş durum (nakit, envanter kimlikleri) RPC ile; dosya ağdan gitmez.
- **Steam Cloud (Faz 5):** `user://` altındaki dosya adı/klasörü baştan sabit (tuzaklar #7-8).

#### H. Sürüm/protokol uyumluluğu ve build kimliği
- **Üç ayrı sayı [G]:** `PROTOCOL_VERSION` (el sıkışma; her ağ sözleşmesi değişiminde +1), oyun sürümü (`application/config/version`, SemVer, insan için), build kimliği (git kısa özeti + tarih; CI/`export.sh` export öncesi `res://build_info.json` ya da `override.cfg` yazar). `ProjectSettings.get_setting("application/config/version")` export'ta çalışır **[G; forumdaki "export'ta görünmez" iddiası eski/yanlış görünüyor, doğrulanmalı [?]]** — en güvenlisi kendi `build_info.json`'ımız.
- **El sıkışma reti nedeni:** host reddetmeden önce `send_auth(peer, {"reject": "version_mismatch", "host_v": 1, "host_build": "…"})` yollayıp bir kare sonra kesmek **[G]**; istemci `_on_auth_data`'da `reject` görürse nedeni saklar, `connection_failed` sonrası menü doğru metni gösterir (UX-2). Ret kodları: `version_mismatch`, `full`, `in_progress`, `level_load_failed`.
- **Windows exe meta:** `export_presets.cfg` `application/file_version`/`product_version` doldurulsun (Özellikler → Ayrıntılar'da görünür; "hangi exe'yi açtın" sorusunu bitirir) **[G]**.
- **Steam (Faz 5):** `Steam.getAppBuildId()` + lobi `v` anahtarı (steam-ag §5).

#### I. Asgari hile önlemleri (arkadaş oyunu)
- **[G] Gerekli değil.** Tehdit modeli: 3 arkadaş, davetle; değiştirilmiş istemci yok. Mevcut host doğrulamaları (S7 menzil/süre, S8 gürültü konumu, el sıkışma biçim/sürüm, ad temizleme, `MAX_EVENTS`) yeterli — bunlar hile değil **hata/bozuk veri** savunması ve korunmalı.
- Ucuz ve zararsız ekler (yalnız teşhis amaçlı): host, istemci konum sıçramasını (> hız × dt × 3) sayar ve günlüğe W yazar (gerçek hile değil; desync/paket kaybı göstergesi).
- Açık lobi/lider tablosu gelirse (fikir havuzu) ayrı araştırma; o gün istemci yetkili hareket (S2) yeniden değerlendirilir.

#### J. Güncelleme dağıtımı
| Kanal | Ne | Artı / eksi | Kaynak |
|---|---|---|---|
| GitHub Actions artifact (mevcut) | `main` push'unda 30 gün | Artifact indirmek için GitHub hesabı gerekir **[O]**; arkadaşlara link vermek zahmetli | ci.yml |
| GitHub Release (etiket) | `test-N` etiketinde release + zip ekleri; herkese açık/özel repo'da link | Sıfır yeni araç; sürüm adı = etiket; "test-3 zip'ini indir" tek cümle **[G]** | — |
| itch.io + butler | `butler push build/windows kullanici/oyun:windows-test --userversion 0.3.0+a1b2c3`; kanal adı platformu etiketler; delta yama; gizli/sınırlı sayfa + indirme anahtarı; itch uygulaması otomatik günceller, doğrudan indirenler güncellenmez **[O]** | Arkadaşlar itch uygulaması kurarsa "güncelle" düğmesi; kurmazsa yine zip. Faz 5 planında "itch gizli build" zaten var | itch.io/docs/butler |
| Steam beta branch (Faz 5) | Şifreli adlandırılmış dal; oyuncu Özellikler → Betalar'dan seçer; dalda build "set live" elle **[O]** | Nihai yol; SteamPipe + `steamcmd` CI adımı | partner.steamgames.com/doc/store/application/branches |
**[G] Sıra:** şimdi GitHub Release (XS) → test-2'den itibaren itch gizli sayfa (S, butler CI adımı) → Faz 5 Steam dalı. Üçünde de zip adı `Insiders-<platform>-<sürüm>+<özet>.zip` ve içinde `build_info.json`.

#### K. Telemetri (KVKK/GDPR)
- **[O]** KVKK'da IP, cihaz kimliği, Steam ID kişisel veridir; Kurul oyun şirketlerine açık rıza/aydınlatma eksikliğinden ceza kesti (Knight Online 750 bin TL; çerez için 300 bin TL). GDPR'de aynı: çökme raporu da kişisel veri içerebilir (bugnet yazısı, tuzaklar.md).
- **[G] İlke:** Arkadaş testi döneminde **otomatik gönderim yok**; her şey yerel dosya, oyuncu kendi elinden gönderir (E akışı) → rıza sorunu doğmaz. Steam öncesi Sentry/telemetri eklenirse: ilk açılışta açık rıza ekranı (varsayılan **kapalı**), ayarlardan kapatılabilir, toplanan alan listesi gizlilik metninde, `send_default_pii=false`, IP/ad/Steam ID gönderilmez, oturum kimliği rastgele ve oturum ömrülü.

### Bizim yapımıza uygunluk değerlendirmesi
- KR-009 (bağımlılıksız) ve KR-020 (önce aramızda) ile en uyumlu çizgi: **yerleşik Godot günlüğü + kendi ince `Logger` katmanı + yerel rapor paketi**; dış servis (Sentry) Faz 5 öncesi karar.
- Godot 4.7.2'de `Logger`, `ScriptBacktrace`, `always_track_call_stacks` mevcut (4.5'te geldi) **[O]** — kullanılmıyor; sıfır bağımlılıkla en büyük teşhis kazancı burada.
- S6 döküm altyapısı (sağlayıcı anahtarları, `to_json_value`, `samples`, `events`) rapor paketinin ve replay izinin çekirdeği; yeni sistem değil, "çıkışta değil her an + oyuncu tetikli" genişlemesi.
- Protokol reddi nedeni ve build kimliği UX-2 ile aynı kalem (rahatlik-ux §2); burada teknik gövdesi.

### Bulgular
**Doğru yaptıklarımız**
- Protokol sürümü el sıkışması, nesnesiz serileştirme, ad temizleme, olay halka tamponu, console exe + README notu, SHA doğrulamalı şablon/Godot indirme, CI'da build artifact'ı, ENet throttle bulgusu (US-001 t2) — hepsi sağlam zemin.
- Godot'un dosya log'u varsayılan açık: arkadaş makinelerinde log **zaten** var, yalnız kimse bilmiyor.

**Saptığımız / eksik yerler**
1. Sürüm uyuşmazlığı istemciye "adresi kontrol et" olarak gidiyor (`game.gd:427`, `main_menu.gd:180`) → test günü en pahalı yanlış teşhis.
2. Build kimliği hiçbir yerde yok (menü, exe meta, döküm, zip adı) → "hangi build" sorusu cevapsız.
3. Script backtrace release'te kapalı; crash handler mesajı varsayılan İngilizce; hata anında bağlam (son olaylar) kaydedilmiyor.
4. Gerçek oyunda döküm yazılmıyor; oyuncu tetikli rapor yok; log yolu README'de yok.
5. README MagicDNS cümlesi paylaşılan makine için yanlış (FQDN gerekir); güvenlik duvarı adımı "Özel ağ" ile sınırlı, Tailscale arabirim profili bunu boşa çıkarabilir **[?]**.
6. Temiz kapanmama (çökme) algısı yok.

**Riskler**
- R1 Tailscale relay'de (DERP) TR↔SE ping 150 ms'yi aşabilir **[G]**; `tailscale status` kontrolü test protokolünde olmalı (yontem.md §9 "ping ölçümü kaydedilir" ile uyumlu).
- R2 MTU: ileride büyüyen RPC'ler (plan masası çizimi, nüfus durumu) 1280'i aşarsa Tailscale'de kayıp artar; S2'ye "tek RPC yükü ≤ 1 KB" kuralı **[G]**.
- R3 Kayıt göçü testsiz kalırsa Faz 4-5 arası arkadaş kampanyaları silinir.
- R4 Dış telemetri rızasız eklenirse KVKK riski (şimdilik yok).

### Öneriler (öncelik P1-P3 · maliyet XS-M · sahip · kalem adayı + AC)
| # | Öneri | P | M | Sahip | Kalem adayı ve AC |
|---|---|---|---|---|---|
| Ö1 | El sıkışma ret nedeni + build kimliği (UX-2'nin teknik gövdesi) | P1 | S | cekirdek (+arayuz XS) | **IS: Ret nedeni ve build kimliği.** AC1 host reddetmeden `{"reject": kod, "host_v", "host_build"}` yollar, istemci `MENU_ERROR_VERSION_MISMATCH` ("sende X, hostta Y") gösterir; `late_join` senaryosuna `--protocol-override` ile uyuşmazlık varyantı. AC2 `res://build_info.json` (`version`, `git`, `date`) export.sh/CI'da üretilir, editörde "dev"; menü sağ altta ve dökümde `build` anahtarı. AC3 `export_presets.cfg` file/product_version dolu. |
| Ö2 | Günlük katmanı v0: `Logger` alt sınıfı (autoload değil, `Game`/`Net`'ten bağımsız `core/log.gd` + Net'te `OS.add_logger`), seviye+kategori, halka tampon 200, `always_track_call_stacks=true`, crash handler mesajı tr/en + log yolu | P1 | S | cekirdek (altyapi: project.godot) | **IS: Yapılandırılmış günlük v0.** AC1 ağ olayları (bağlan/kop/ret/ping > 2× sıçrama) I seviyesinde tek satır `t= lvl= cat= msg=`; aynı satır 1 sn içinde tekrarlanmaz. AC2 script hatasında backtrace release build'de log'a düşer (export smoke'ta kasıtlı hata ile doğrulanır). AC3 net_smoke `allow_log/deny_warnings` kırılmaz. |
| Ö3 | Oyuncu tetikli sorun raporu paketi + temiz kapanmama bayrağı | P1 | S | cekirdek (arayuz XS: tuş + mesaj) | **IS: "Sorun bildir" paketi.** AC1 F8/duraklat → `user://reports/<tarih>_<build>_<oturum>.zip` (log, dump JSON, PNG, sistem bilgisi) ve klasör açılır. AC2 `session.lock` ile sonraki açılışta "geçen oyun temiz kapanmadı" uyarısı + son log'a bağlantı. AC3 headless'ta paket PNG'siz üretilir (birim test). |
| Ö4 | README/menü Tailscale teşhis kutusu: `tailscale status` relay/direct, FQDN notu, güvenlik duvarı kuralı (tüm profiller), 3 satırlık kontrol listesi | P1 | XS | altyapi (README) + arayuz (MENU_ERROR_CONNECTION_FAILED metni) | **IS: Bağlantı teşhis notu.** AC1 README §Tailscale'de FQDN + `netsh` kuralı + relay uyarısı. AC2 zaman aşımı mesajı 3 maddelik liste (rahatlik-ux UX-2 metni). |
| Ö5 | Dağıtım: `test-N` etiketinde GitHub Release + zip adı sürümlü; test-2'den itibaren itch gizli sayfa + butler CI adımı | P2 | XS→S | altyapi (+kullanıcı: itch hesabı) | **IS: Checkpoint dağıtımı.** AC1 etiket push'unda release ve iki zip (`Insiders-<platform>-<sürüm>+<özet>.zip`, içinde build_info.json). AC2 (itch) `butler push … --userversion` CI'da gizli anahtarla; README'de arkadaş için "itch uygulaması → güncelle". |
| Ö6 | Replay kapsam daraltma: host karar günlüğü + peer durum izi (dosya biçimi), oynatıcı sonra | P2 | S (biçim) / M (oynatıcı) | cekirdek (biçim), seviye/arayuz (oynatıcı) | **IS: Oturum izi v0.** AC1 host: etkileşim kabul/ret + neden, algı eşik geçişleri, uyarı kademesi zaman damgalı `user://traces/<oturum>.jsonl`. AC2 peer: 10 Hz konum/kip + NPC özetleri aynı dosyada. AC3 net_smoke `expect` iki iz dosyasına çevrimdışı uygulanır. **Karar gereken:** GDD "girdi günlüğü/replay" maddesinin daraltılması. |
| Ö7 | Faz 4 kayıt sözleşmesi (mimari'ye S12 taslağı): JSON zarf (`schema_version`, `game_version`, `checksum`), atomik yazım + `.bak`, göç zinciri + sürüm fikstürleri, bilinmeyen ileri sürümde ezmeme | P2 (Faz 4'te P1) | S | cekirdek | **US kabul maddeleri:** AC1 yarım yazılmış dosya → `.bak`'tan yüklenir (test: dosyayı ortadan kes). AC2 `tests/fixtures/saves/v*.json` hepsi yüklenir ve eşdeğer durum verir. AC3 schema > bilinen → mesaj, dosya değişmez. AC4 `.tres/.res` yükleme yok (denetçi grep). |
| Ö8 | S2/S6 notu: tek RPC yükü ≤ 1 KB (Tailscale MTU 1280); net_smoke'a "en büyük paket" istatistiği | P3 | XS | cekirdek | AC: döküm `net.max_packet_bytes`; senaryoda `max_packet` beklentisi. |
| Ö9 | Sentry Godot SDK değerlendirmesi (yalnız karar notu; Faz 5 öncesi) | P3 | XS (karar) | koordinatör/altyapi | **Karar gereken:** dış çökme servisi + rıza ekranı Faz 5'te mi, hiç mi. |

### Karar gereken (koordinatöre)
1. Replay (GDD/backlog "girdi günlüğü/replay") → "host karar günlüğü + peer izi"ne daraltma (Ö6). Belirlenimci replay bizim mimariyle uyumsuz.
2. Dış telemetri/çökme servisi (Sentry) politikası: arkadaş döneminde yok (öneri), Faz 5 öncesi rıza ekranıyla değerlendirme (Ö9).
3. Dağıtım kanalı: GitHub Release hemen mi, itch gizli sayfa test-2'de mi (kullanıcı hesabı gerekir) (Ö5).

### Bir sonraki tur için açık sorular
- Tailscale Windows'ta arabirim ağ profili (Özel/Genel) gerçekte ne; "yalnız Özel" izni Tailscale trafiğini düşürüyor mu — kullanıcı makinesinde `Get-NetConnectionProfile` ile doğrulansın **[?]**.
- Godot 4.7.2 Windows crash handler'ı: sembolsüz şablonda log'a ne düşüyor (deneme: `OS.crash()` ile bir kez test build'inde) **[?]**.
- `ProjectSettings.get_setting("application/config/version")` export'ta döner mi (deneme) **[?]**; dönmüyorsa `build_info.json` tek kaynak.
- ENet 1.3.18 varsayılan MTU'su Godot kopyasında kaç (`thirdparty/enet/enet.h` `ENET_HOST_DEFAULT_MTU`) **[?]**; 1280 altına çekmek Godot'tan mümkün değil → paket boyutu disiplini.
- Steam Cloud ile `user://` kayıt yolu ve çakışma çözümü (Faz 5 turu).
- Linux build'de `user://` yolu ve log izinleri (Steam Deck turu).

### Kaynaklar
- Godot ProjectSettings (file_logging, crash_handler, always_track_call_stacks, flush_stdout): https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html
- Godot logging (Logger sınıfı, backtrace, sembol gereksinimi): https://docs.godotengine.org/en/4.7/tutorials/scripting/logging.html · forum: https://forum.godotengine.org/t/how-to-use-the-new-logger-class-in-godot-4-5/127006
- Godot OS (add_logger, crash, get_user_data_dir, sistem bilgisi): https://docs.godotengine.org/en/stable/classes/class_os.html
- Godot ScriptBacktrace / 4.5 release backtrace: https://docs.godotengine.org/en/4.5/classes/class_scriptbacktrace.html · https://godotengine.org/article/dev-snapshot-godot-4-5-dev-3/
- Godot komut satırı (`--log-file`, `--disable-crash-handler`): https://docs.godotengine.org/en/4.7/tutorials/editor/command_line_tutorial.html
- Godot ENetConnection / ENetPacketPeer: https://docs.godotengine.org/en/4.7/classes/class_enetconnection.html · https://docs.godotengine.org/en/4.7/classes/class_enetpacketpeer.html · Godot thirdparty (ENet 1.3.18): https://github.com/godotengine/godot/blob/4.7/thirdparty/README.md
- ENet parçalanma ve güvenilire dönüşme: https://lists.puremagic.com/pipermail/enet-discuss/2014-May/002303.html · https://lists.puremagic.com/pipermail/enet-discuss/2024-June/002502.html · ChangeLog: https://github.com/lsalzman/enet/blob/master/ChangeLog
- Godot kayıt öğreticisi: https://docs.godotengine.org/en/4.7/tutorials/io/saving_games.html · Resource güvenliği (tuzaklar.md): https://gdquest.com/library/save_game_godot4
- Tailscale bağlantı türleri: https://tailscale.com/kb/1257/connection-types · ACL: https://tailscale.com/kb/1018/acls · paylaşım: https://tailscale.com/kb/1084/sharing · MagicDNS: https://tailscale.com/kb/1081/magicdns · sorun giderme dizini: https://tailscale.com/kb/1023/troubleshooting · NAT geçişi blog: https://tailscale.com/blog/nat-traversal-improvements-pt3-looking-ahead · MTU forum: https://forum.tailscale.com/t/mtu-issue-searching-the-best-way-to-solve-it/1799
- netfox.noray: https://github.com/foxssake/netfox
- Sentry Godot: https://docs.sentry.io/platforms/godot/ · seçenekler: https://docs.sentry.io/platforms/godot/configuration/options/ · depo: https://github.com/getsentry/sentry-godot
- Forge Logger (oyun içi rapor, referans): https://godotengine.org/asset-library/asset/5321 · bugnet: https://bugnet.io/blog/how-to-add-bug-reporter-to-godot-game
- itch butler: https://itch.io/docs/butler/pushing.html · Steam branch'leri: https://partner.steamgames.com/doc/store/application/branches
- KVKK oyun cezaları: https://www.tgrthaber.com/teknoloji/kvkk-knight-online-oyununa-idari-para-cezasi-verdi-2952079 · https://www.istiklal.com.tr/teknoloji/kvkkdan-oyun-platformuna-cerez-cezasi-300-bin-tl-768317h · GDPR ve çökme raporu: https://bugnet.io/blog/crash-reporting-gdpr-indie-games
- Klotho (belirlenimci replay örneği, .NET): https://godotengine.org/asset-library/asset/5234

---

## Tur 2 — 2026-10-02 (doğrulama turu: bu makinede ölçüm + motor kaynağı)

### Kapsam
Tur 1'in açık sorularının doğrulanması: (1) Tailscale arabiriminin Windows ağ profili ve "Özel" izninin yeterliliği; (2) Godot 4.7.2 `Logger` API'si ve release'te script backtrace — IS-043 taslak arayüzü; (3) `application/config/version` export'ta okunuyor mu, git hash'i gömme yolları; (4) `OS.crash()`/çökme işleyicisi çıktısı Windows'ta nereye düşüyor, `session.lock` kalıbı; (5) `build_info.json` ve el sıkışmasında protokol/build alanı. Ek: ENet MTU, auth zaman aşımı, `disconnect_peer` kuyruk davranışı.
İşaret eki: **[Ö]** = bu makinede ölçüldü (Windows 11 Pro 26200, resmî Godot 4.7.2 Windows şablonları, deney projesi scratchpad `opguv-t2`). Yalnız okuma/ölçüm komutları koşuldu; sistem/güvenlik duvarı ayarı değiştirilmedi.

### Mevcut durum (dosya:satır) — tur 1'e ek
- `autoload/game.gd:47` `AUTH_TIMEOUT_SEC := 10.0`, `game.gd:105` `sm.auth_timeout` **set ediliyor** [K] (SceneMultiplayer varsayılanı 3 sn; `scene_multiplayer.cpp:144-158` süre dolunca `disconnect_peer` + `peer_authentication_failed`). İstemci seviye yüklemesini el sıkışması içinde yapıyor (`game.gd:442-446`); 10 sn yavaş diskte bile yeter [G].
- `game.gd:414` hello = `{"v", "level"}`; `game.gd:451` yanıt = `{"v", "name", "level"}`; `game.gd:427-428` ret = `push_warning` + aynı karede `disconnect_peer` [K].
- `autoload/net.gd:215` `enet.create_server(port, …)` — `set_bind_ip` çağrısı yok → `*` (tüm arabirimler) [K]; `net.gd:168-181` el sıkışması sırasında host kopunca `connection_failed` yayılıyor (tur 1 bulgusuyla tutarlı).
- `main.gd:259-267` döküm; `Args.is_automation()` (`args.gd:136`) var → otomasyon koşusunu ayırt etmek için hazır kanca [K].
- `.github/workflows/ci.yml:111-181` (IS-042, Sürüyor): `test-*` etiketinde `Insiders-<etiket>-<platform>.zip` + GitHub Release (prerelease) **zaten var** [K]; zip içinde `build_info.json` henüz yok; `actions/checkout@v7` varsayılan derinlik 1 → `git describe` etiket görmez (etiket release işinde ayrıca `fetch`leniyor, `ci.yml:155`).
- `project.godot`: `application/config/version` yok; `debug/settings/gdscript/always_track_call_stacks` yok; `export_presets.cfg:32-33` `file_version`/`product_version` boş [K].
- `README.md:58-60` (IS-041, Sürüyor): "Özel ve Ortak ikisini de işaretleyin; yalnız Özel seçilirse Ortak'ta Engelle kuralı oluşur ve izin kuralını ezer (Tailscale arabirimi Ortak profilde olabilir)" [K] — aşağıda A ile netleştirildi.
- **Bu makinede güvenlik duvarı durumu [Ö]:** aktif ağ profili `Ethernet` = **Public**. Kurallar: `Godot Engine` (masaüstü `Godot_v4.7.2…exe`) Allow/Public; `.tools\godot_v4.7.2…exe` **Block**/Public (TCP+UDP); `Insiders`/`insiders.exe` **Block**/Public ×4 çift (worktree build'i, denetçi temp build'i, scratchpad build'i). Yani otomasyon koşuları (net_smoke, denetçi, worktree) her yeni exe yolunda Windows'un "izin ver" penceresini açmış, kimse yanıtlamayınca Windows **Engelle** kuralı yazmış (MS belgesi: iptal/yanıtsız → TCP+UDP iki block kuralı [O]). Tailscale **kurulu değil** (adaptör listesinde yok).
- **`user://logs` [Ö]:** `%APPDATA%\Godot\app_userdata\Insiders\logs\` içinde 5 dosya, hepsi aynı dakikadan test/net_smoke koşuları (içerik `--verbose` "Loading resource:" satırları, 270-566 KB). Geliştirici makinesinde gerçek oyun log'u otomasyon koşularıyla saniyeler içinde döndürülüp siliniyor. Dosya adı biçimi `godot2026-10-02T13.44.04.log` (alt çizgi yok).

### En iyi uygulamalar ve seçenekler

#### A. Tailscale arabirimi ve Windows güvenlik duvarı (konu 1)
| Bulgu | Kaynak |
|---|---|
| Tailscale Windows istemcisi kendi adaptörünün ağ kategorisini **Private** yapar: `setPrivateNetwork` — kategori Private ya da Domain değilse `SetCategory(Private)`; başarısızsa sağlık uyarısı `set-network-category-failed` ("Failed to set the network category to private on the Tailscale adapter…"), yeniden dener; her açılışta/yeniden başlatmada tekrar uygular **[O]** | `wgengine/router/osrouter/ifconfig_windows.go:163-235, 239-283` (main); KB "Windows network configuration failed" |
| Tailscale iki gelen kuralı yazar: `Tailscale-In` dir=in action=allow **localip=<Tailscale IP'niz> profile=private,domain** (program/port kısıtı yok → Tailscale IP'nize gelen **her** paket Private/Domain profilinde serbest) ve `Tailscale-Process` (tailscaled.exe, UDP, profile=any) **[O]** | `wgengine/router/osrouter/router_windows.go:270-330` |
| Windows kural önceliği: açık **Engelle** kuralı çakışan her İzin kuralını ezer; iptal/yanıtsız istem → TCP+UDP **Engelle** kuralları yazılır ve silinene kadar istem bir daha çıkmaz **[O]** | MS Learn "Windows Firewall rules" §Rule precedence, §Applications rules |
| **Sonuç [G, O'lara dayanır]:** Tailscale adaptörü normalde Private olduğundan, host'ta Insiders.exe için **hiç izin kuralı olmasa bile** Tailscale'den gelen UDP 7777 `Tailscale-In` ile geçer. Tailscale yolunu bozan tek şey Insiders.exe için **Private profilde Engelle** kuralı (istem Private ağdayken iptal edildiyse ya da "yalnız Ortak" seçildiyse). Bu makinedeki Block/Public kuralları Tailscale yolunu etkilemez; **LAN üzerinden** (Ethernet=Public) host olmayı engeller. | — |
| README düzeltmesi: "Tailscale arabirimi Ortak profilde olabilir" yerine "Tailscale adaptörü Private'tır (Tailscale zorlar); Private'ta Engelle kuralı varsa Tailscale de kesilir; iki kutuyu da işaretlemek LAN testi ve güvenli taraf için" **[G]** | — |
| `tailscale ping`/`status` teşhisine ek: host'ta `Get-NetConnectionProfile` çıktısında `Tailscale` satırı **Private** olmalı; `Get-NetFirewallRule -DisplayName Insiders* \| ft DisplayName,Action,Profile` ile Block var mı bakılır (salt okunur) **[G]** | — |
| Otomasyon istemi: `ENetMultiplayerPeer.set_bind_ip("127.0.0.1")` yalnız yerel koşularda (net_smoke, testler, export smoke) kullanılırsa Windows istemi/Block kuralı çıkmaz **[? — belgede `set_bind_ip` "varsayılan `*`" [O]; loopback'e bağlanmanın istem açmadığı doğrulanmalı]** | ENetMultiplayerPeer docs |

#### B. `Logger` API'si ve release'te script backtrace (konu 2) — ölçüldü
- **İmzalar (4.7 docs) [O]:** `Logger extends RefCounted`; `_log_message(message: String, error: bool)`; `_log_error(function: String, file: String, line: int, code: String, rationale: String, editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace])`; enum `ERROR_TYPE_ERROR=0, WARNING=1, SCRIPT=2, SHADER=3`; kayıt `OS.add_logger(l)`/`OS.remove_logger(l)`. Her iki metot **herhangi bir iş parçacığından, eşzamanlı** çağrılabilir → `Mutex`; içinde `push_error/push_warning` **yasak** (sonsuz özyineleme) [O].
- **Ölçüm [Ö] (release şablonu, `always_track_call_stacks=true`):** `push_warning("x")` → `_log_error(fn="push_warning", file="core/variant/variant_utility.cpp", line=1033, code="x", rationale="", notify=false, type=1, bt_count=1)`; `push_error` aynı, `code` mesajı taşır, `rationale` boş. `OS.crash("m")` → `type=0, fn="crash", code="FATAL: Method/function failed.", rationale="m"`. `_log_message` her `print` satırını (sonunda `\n` ile) alır; `error=true` yalnız stderr'e giden metinler için. `ScriptBacktrace.format(4)` çıktısı "GDScript backtrace (most recent call first): [0] _ready (res://main.gd:47)". `Engine.capture_script_backtraces(false)` release'te 1 iz/1 kare döndürdü.
- **Kritik sınır [Ö + O]:** release şablonunda GDScript **çalışma zamanı hataları yoktur**: `arr[3]` (sınır dışı) → `<null>` döner, hata yok; `null_node.name` → hata yok, fonksiyon devam eder; `d["yok"]` → null; `10 / 0` (int) → işlem **sert çöker** (0xC0000094) ve hiçbir satır düşmez. Kaynak: `gdscript_vm.cpp` OPCODE_GET_NAMED'de geçersiz erişim denetimi `#ifdef DEBUG_ENABLED` içinde (129 DEBUG_ENABLED bloğu). `always_track_call_stacks` yalnız **push_error/push_warning/motor ERR_FAIL** hatalarına iz ekler; script hatasını görünür kılmaz. **Debug şablonunda** aynı kod "SCRIPT ERROR: Invalid access to property or key 'name' on a base object of type 'null instance'" + 3 kareli iz verdi ve fonksiyon kesildi (sonraki `quit()` çalışmadı → süreç açık kaldı; test tasarımında dikkat).
- **Seçenek — test build'leri debug şablonuyla [G, karar gereken]:** `--export-debug` ile üretilen build script hatalarını iz ile log'a yazar, çökmede crash handler çalışır (aşağıda D). Bedel: GDScript denetimleri (performans; 2D küçük oyunda ölçülmedi [?]), exe 103 MB vs 109 MB (release daha büyük çıktı; fark önemsiz), `OS.has_feature("debug")=true` → `flush_stdout_on_print.debug=true` (her print flush). net_smoke/CI release ile koşmaya devam eder; yalnız `test-N` zip'leri debug olur ya da her ikisi de üretilir ("Insiders-test-3-windows-debug.zip").

#### C. Sürüm/build kimliği gömme (konu 3) — ölçüldü
| Soru | Sonuç |
|---|---|
| `ProjectSettings.get_setting("application/config/version")` export'ta? | **Döner [Ö]** (`"0.9.7+abc1234"` aynen; `has_setting=true`). Tur 1 [?] kapandı. |
| `res://build_info.json` export'a giriyor mu? | `export_filter=all_resources`, **include_filter boş** iken **giriyor [Ö]** (JSON 4.x'te Resource; export docs'un ".json include filter ister" cümlesi [ESKİ/yanıltıcı]). `.txt` girmiyor; `include_filter="build_info.json"` yazmak yine de açıklık için önerilir [G]. |
| `override.cfg` | Export'ta `res://override.cfg` yoktu [Ö]; exe yanına konursa çalışma zamanında okunur [O, ProjectSettings docs] — kullanıcı silebilir/değiştirebilir; build kimliği için uygun değil [G]. |
| Windows exe meta (`file_version` boş) | `EditorExportPreset::get_version`: boşsa `application/config/version`'a düşer; **yalnız rakam ve nokta** kabul eder, 4 parçaya `.0` ile doldurur; geçersizse WARNING + `1.0.0.0` [O, `editor_export_preset.cpp`]. Ölçüm [Ö]: `config/version="0.9.7+abc1234"` → 4× "Invalid version number" uyarısı, exe `1.0.0.0`; preset `file_version="0.9.7.0"` → exe `FileVersion 0.9.7.0`. **rcedit gerekmez**: `TemplateModifier` PE kaynağını kendisi yazar, Linux'tan export'ta da çalışır [O, `template_modifier.cpp`]. |
| Git hash gömme yolu (CI'ya en az dokunan) | **Seçilen [G]:** `tools/export.sh` export öncesi `build_info.json`'u proje köküne yazar (`.gitignore`'a eklenir), `version` = `project.godot config/version` (yalnız `X.Y.Z`), `git` = `git rev-parse --short HEAD` (CI'da `GITHUB_SHA` kısaltması; `.git` yoksa "nogit"), `tag` = `GITHUB_REF_NAME` (`test-*` ise) ya da `git describe --tags --always` (yerelde), `date` UTC, `protocol` = Game.PROTOCOL_VERSION (export.sh `grep`le okur; drift testi birim testte), `debug` = şablon türü. Aynı dosya `build/<platform>/` yanına da kopyalanır → zip'te görünür. CI değişikliği sıfır (export.sh zaten çağrılıyor); `git describe` için `fetch-depth: 0` **gerekmez** (hash yeter; etiket adı env'den). Editörde dosya yok → `BuildInfo.version = "dev"`. Alternatif `EditorExportPlugin._export_begin + add_file` (addons/ klasörü, tool script) daha "Godot'ça" ama bir eklenti daha [G]. |

#### D. Çökme çıktısı ve `session.lock` (konu 4) — ölçüldü
- **Resmî 4.7.2 Windows şablonları MinGW-GCC 15.2 ile derlenmiş [Ö, exe içi "GCC: (MinGW-W64 x86_64-msvcrt-posix-seh…)"]** → `crash_handler_windows_signal.cpp` (SIGSEGV/SIGFPE/SIGILL + libbacktrace); `CRASH_HANDLER_EXCEPTION` `crash_handler_windows.h:37`'de koşulsuz tanımlı [O].
- **Release şablonu [Ö]:** `OS.crash("m")` → log'a yalnız "ERROR: m / at: crash (core/core_bind.cpp:349) / GDScript backtrace …" düşer (bu satır `CRASH_NOW_MSG`'nin kendi hatası; **flush edilir**, `logger.cpp:216` `p_err || flush_stdout_on_print`), sonra süreç 0xC000001D ile ölür; **"CrashHandlerException: Program crashed…" satırı YOK**, `debug/settings/crash_handler/message` **hiç görünmez**. Int sıfıra bölme çökmesinde (0xC0000094) hiçbir satır yok. Neden (handler'ın release'te hiç koşmaması) kaynaktan açıklanamadı **[?]** — ölçüm kesin.
- **Debug şablonu [Ö]:** aynı çağrıda stderr+log'a "CrashHandlerException: Program crashed with signal 4 / Engine version: Godot Engine v4.7.2.stable.official (ed1daf0b…) / Dumping the backtrace. <bizim mesaj> / Load address … / [3..24] adres (main+…) - no debug info in PE/COFF executable / -- END OF C++ BACKTRACE -- / GDScript backtrace (most recent call first): (boş; await sonrası) / -- END OF GDSCRIPT BACKTRACE --". Adresler sembolsüz (beklenen, tur 1), ama **çökme olgusu + mesaj + o anki script izi** log'a düşüyor; kullanıcıya "logu gönder" mesajı ancak debug şablonunda görünür.
- **WER minidump [Ö/O]:** Çökmede Windows `%LOCALAPPDATA%\CrashDumps\<exe>.<pid>.dmp` yazdı (3,7 MB) — ama **yalnız** `HKLM\…\Windows Error Reporting\LocalDumps` anahtarı var olduğu için (bu makinede var; MS: varsayılan **kapalı**, yönetici gerekir) [O, MS Learn]. Arkadaş makinesinde beklenmemeli; önerilmez (yönetici/registry).
- **Nereye yazılır — özet:** release'te çökme kanıtı = log'un son satırlarında kesilen akış (+ `print` tamponda kalabilir, hata satırları flush'lı) + sonraki açılışta `session.lock`; debug'da ayrıca crash handler bloğu. `.console.exe` ile açılırsa aynı metin konsolda; kapanınca kaybolur → log dosyası tek kalıcı yer.
- **`session.lock` kalıbı (Godot'a özgü noktalar) [G]:** (a) `user://session.lock` içeriği `{"pid", "build", "started_at", "log": <bu oturumun godot.log yolu>}`; açılışta `_ready`'de yazılır, `NOTIFICATION_WM_CLOSE_REQUEST`/`quit()` yolunda silinir. (b) `OS.is_process_running(pid)` **yalnız `create_process` çocuklarına bakar** (`os_windows.cpp`) → eski kilidin sahibi yaşıyor mu bilinemez; bu yüzden **otomasyonda kilit yazılmaz** (`Args.is_automation()` ya da `DisplayServer.get_name()=="headless"`), aynı makinede ikinci pencere açan geliştirici yanlış uyarı görebilir (kabul edilir; mesaj "temiz kapanmamış olabilir"). (c) Açılışta kilit varsa: `user://logs/` içindeki en yeni `godot*.log` (kilitteki yol) **rapor paketine önceki oturum log'u olarak** eklenir; kilit silinir; menüde tek satır "Geçen oyun temiz kapanmadı — Sorun bildir (F8)". (d) `MainLoop.NOTIFICATION_CRASH` (`crash_handler…:220`) handler çalışırsa gelir — release'te güvenilmez, debug'da bonus: orada `Game.collect_dump()`'ı `user://reports/crash_<t>.json`'a yazmak denenebilir (çökme bağlamında dosya yazmak riskli; try-best).
- **Geliştirici makinesi log kirliliği [Ö→G]:** testler/net_smoke aynı `user://logs`'u döndürüyor; `--log-file <tmp>` (CLI, [O]) ile otomasyon koşuları ayrı dosyaya yazdırılırsa gerçek oyun logu korunur (net_smoke.py + run_tests çağrısı, XS).

#### E. `build_info.json` zip'te + el sıkışmasında sürüm alanı (konu 5)
- **Zip:** `build/windows/build_info.json` ve `build/linux/build_info.json` (export.sh kopyalar) → `ci.yml:120-123` `cp -a build/<platform>` zaten klasörü kopyaladığı için **CI'da ek adım yok** [K+G]. Alanlar: `version, git, tag, date, protocol, debug`.
- **Oyun içi `BuildInfo` (core/build_info.gd, static) [G]:** `static func load() -> Dictionary` (`res://build_info.json` yoksa `{"version":"dev","git":"","protocol":Game.PROTOCOL_VERSION}`); `static func label() -> String` → "dev" ya da "test-3 (a1b2c3d)"; menü sağ alt + `collect_dump()["build"]` + rapor paketi.
- **El sıkışması (Game, S3) — alan yerleri [G]:** host hello `{"v": PROTOCOL_VERSION, "level": …, "build": BuildInfo.label()}`; istemci yanıtı `{"v", "name", "level", "build"}`. Ret: host `v` uyuşmazlığında **kesmek yerine** `send_auth(peer, var_to_bytes({"reject": "version_mismatch", "host_v": PROTOCOL_VERSION, "host_build": label}))` yollar ve peer'ı **pending** bırakır; istemci `_on_auth_data`'da `reject` görünce nedeni `Net.last_reject` (ya da `Game.last_reject_reason`) olarak saklar ve **kendisi `Net.leave()`** çağırır → `connection_failed` → menü nedene göre `MENU_ERROR_VERSION_MISMATCH` ("Sende v%d / %s, hostta v%d / %s") gösterir. Host tarafında `auth_timeout` (10 sn) kapatmayan istemciyi düşürür. **Neden host kesmesin:** `ENetMultiplayerPeer.disconnect_peer` → `enet_peer_disconnect` → `enet_peer_reset_queues` [O, `peer.c:538-559`, `enet_multiplayer_peer.cpp:271-279`] → aynı karede kuyruğa konan ret paketi **silinir**; en az bir `poll` sonra kesmek gerekir, istemci-güdümlü kapanış daha basit ve test edilebilir. Ret kodları: `version_mismatch`, `level_mismatch`, `full`, `in_progress`. Eski istemci (ret alanını bilmeyen) `reject` sözlüğünde `v` görmeyince mevcut `disconnect_peer(1)` yoluna düşer → geriye uyumlu.
- **`v` kontrolü sırası:** `reject` anahtarı **`v` kontrolünden önce** okunmalı (`game.gd:425-429` koşulu `v` yoksa reddediyor) — IS/US-027 uygulamasında dikkat.

#### F. Ek doğrulamalar (tur 1 açık soruları)
- ENet (Godot `thirdparty/enet`, 1.3.18): `ENET_HOST_DEFAULT_MTU = 1392`, `ENET_PEER_TIMEOUT_MINIMUM 5000`, `MAXIMUM 30000`, `TIMEOUT_LIMIT 32` [O, `enet.h`]. Tailscale 1280 < 1392 → 1280'i aşan tek paket IP parçalanır (tur 1 R2 geçerli; "tek RPC yükü ≤ 1 KB" kuralı yerinde).
- SceneMultiplayer: host el sıkışması sırasında kesince istemcide `_del_peer(1)` → `peer_authentication_failed(1)`; `_update_status` CONNECTED→DISCONNECTED → `server_disconnected`; `net.gd:168-181` bunu kabul öncesiyse `connection_failed`'a çeviriyor [O+K] — tur 1 teşhisi doğru.

### Bizim yapımıza uygunluk değerlendirmesi
- KR-009/KR-020 çizgisi korunur: hiçbir öneri dış servis/eklenti istemez; `Logger` + `build_info.json` + `session.lock` saf GDScript/bash.
- En büyük düzeltme: **release şablonu script hatalarını göstermez** (B) — IS-043'ün "release backtrace" kabul maddesi (tur 1 Ö2 AC2 "script hatasında backtrace release'te log'a düşer") **yalnız push_error için doğru**; AC yeniden yazılmalı ya da test build'i debug şablonuna geçmeli (karar gereken).
- IS-041 README metni (A) küçük netleştirme ister; IS-042 zip'ine `build_info.json` export.sh üzerinden sıfır CI değişikliğiyle girer.

### Bulgular
**Doğru yaptıklarımız**
- `auth_timeout = 10` set edilmiş (varsayılan 3 sn seviye yüklemesini düşürebilirdi); el sıkışması nesnesiz; CI zaten `test-*` zip'i + Release üretiyor; README iki profil önerisi güvenli tarafta.

**Saptığımız / eksik yerler**
1. Release şablonu: GDScript çalışma zamanı hataları sessiz, çökme işleyicisi çıktı vermiyor, crash mesajı görünmüyor [Ö] → tur 1 Ö2 AC2 ve "crash handler mesajı tr/en" öğeleri release'te **boş**.
2. `config/version`'a `+hash` yazılırsa Windows meta `1.0.0.0`'a düşer + 4 uyarı [Ö] → `config/version` yalnız `X.Y.Z`, hash `build_info.json`'da.
3. Host "ret nedeni yolla, aynı karede kes" tasarımı ENet kuyruğunu sıfırlar [O] → istemci-güdümlü kapanış.
4. Otomasyon koşuları geliştirici makinesinde Windows güvenlik duvarı istemi açıyor, yanıtsız kalınca Block kuralı yazıyor (4 yol × 2) ve `user://logs`'u dolduruyor [Ö].
5. README'deki "Tailscale arabirimi Ortak olabilir" ihtiyatı yanlış yönde: Tailscale Private'ı zorlar; tehlike Private'ta Engelle kuralı [O].

**Riskler**
- R5 Test build'i release kalırsa arkadaş testinde "oyun dondu/kapandı" raporları iz bırakmaz; teşhis maliyeti yükselir.
- R6 `session.lock` çoklu-pencere/otomasyonda yanlış pozitif; otomasyon dışlanmazsa net_smoke'ta kilit çakışması.
- R7 Debug şablonu seçilirse `flush_stdout_on_print.debug=true` + script denetimleri → performans farkı ölçülmeli (150 ms RTT senaryosu + 20 Hz akış).

### Öneriler (öncelik · maliyet · sahip · kalem adayı + AC)
| # | Öneri | P | M | Sahip | Kalem adayı ve AC |
|---|---|---|---|---|---|
| T2-1 | **IS-043 AC düzeltmesi + `Logger` taslağı (aşağıda G)**: release'te yalnız push_error/motor hataları iz taşır; crash handler mesajına güvenilmez | P1 | XS (AC metni) + S (uygulama) | cekirdek | **IS-043 (mevcut) AC yeniden:** AC2 → "push_error/push_warning release build'de log'a backtrace ile düşer (export smoke: kasıtlı push_error, log'da `[0] <fn> (res://…)` satırı)". Yeni AC: "`Logger` alt sınıfı `_log_error`'da push_error kullanmaz; Mutex ile korunur; headless+release'te `user://logs/insiders.log` döndürmeli (2 MB × 3)". |
| T2-2 | **Karar gereken:** `test-N` zip'leri **debug şablonu** ile (ya da release+debug iki zip) — script hatası izi ve crash handler bloğu için | P1 | XS (export.sh/CI) | altyapi (+kullanıcı kararı) | **IS-042 eki:** AC1 `tools/export.sh windows-debug` adımı ve zip adı `-debug`; AC2 export smoke debug build'de kasıtlı `null.name` → log'da "SCRIPT ERROR" + iz; AC3 150 ms net senaryosu debug build'de de geçer (R7 ölçümü döküme `build.debug=true` ile). |
| T2-3 | `build_info.json` üretimi export.sh'ta + `config/version="0.1.0"` (yalnız rakam) + preset `file_version` boş bırakılıp fallback (ya da export.sh `sed`) + `BuildInfo` static sınıfı + menü/döküm/el sıkışması `build` alanı | P1 | S | altyapi (export.sh, project.godot, .gitignore) + cekirdek (BuildInfo, Game) + arayuz (menü etiketi) | **US-027 teknik gövdesi:** AC1 export çıktısında `build/<platform>/build_info.json` ve `res://build_info.json` aynı içerik; editörde `BuildInfo.label()=="dev"`. AC2 `(Get-Item Insiders.exe).VersionInfo.FileVersion == "0.1.0.0"` (export smoke, Windows'ta). AC3 döküm `build` anahtarı; menü sağ alt etiket. AC4 export günlüğünde "Invalid version number" **yok** (check_log'a WARNING eşlemesi). |
| T2-4 | El sıkışması ret nedeni: host `reject` sözlüğü yollar ve peer'ı pending bırakır; istemci nedeni saklayıp kendisi ayrılır; `reject` `v`'den önce okunur | P1 | S | cekirdek (+arayuz: `MENU_ERROR_VERSION_MISMATCH`) | **US-027 AC:** AC1 `--protocol-override=2` ile katılan istemci dökümünde `last_reject="version_mismatch"`, `host_v=1`; menü metninde iki sürüm. AC2 host dökümünde peer `events`'te `auth_reject` kaydı, host kesmeden önce ≥1 poll geçmiş ya da istemci ayrılmış. AC3 eski istemci (reject bilmeyen) davranışı değişmez. |
| T2-5 | README A netleştirmesi: Tailscale adaptörü Private; Private'ta Engelle kuralı → Tailscale kesilir; `Get-NetConnectionProfile`/`Get-NetFirewallRule` salt okunur kontrol satırları; "iki kutu" önerisi kalır | P1 | XS | altyapi | **IS-041 eki:** AC1 README §Tailscale 4. adım yeni metin; AC2 teşhis listesine iki PowerShell satırı. |
| T2-6 | Otomasyon hijyeni: net_smoke/testler/export smoke `--log-file <tmp>`; yerel koşularda `set_bind_ip("127.0.0.1")` (Args `--bind=127.0.0.1` ya da otomasyonda otomatik) → istem/Block kuralı ve log döndürme yok | P2 | XS-S | cekirdek (net.gd/args.gd) + altyapi (net_smoke.py, export.sh) | **IS adayı "Otomasyon izolasyonu":** AC1 net_smoke sonrası `user://logs` değişmez; AC2 `--bind` ile host loopback'e bağlanır, net_smoke tüm senaryoları geçer; AC3 Windows'ta temiz makinede istem çıkmadığı el ile bir kez doğrulanır (not). |
| T2-7 | `session.lock` D'deki kalıp (otomasyonda kapalı; önceki log yolunu taşır; rapor paketine ekler) | P1 (IS-043 içinde) | XS | cekirdek | **IS-043 AC eki:** AC `--dump` koşusunda kilit yazılmaz; kilitli açılışta `collect_dump()["unclean_previous"]=true` ve rapor paketinde `previous.log`. |
| T2-8 | Debug şablonu performans ölçümü (R7): aynı senaryo release/debug, döküm `fps_min`/`frame_ms_p95` | P2 | XS | altyapi (CI matrisi) | T2-2 AC3 ile birleşir. |

#### G. IS-043 taslak arayüzü (imza düzeyi, kod yazılmadı) [G]
```
# core/log.gd  (class_name Log; RefCounted değil, static yardımcılar + tek Logger örneği)
class_name Log
enum Level { D, I, W, E }
const CATS := [&"net", &"session", &"interact", &"ai", &"ui", &"save", &"build"]
static func d(cat: StringName, msg: String) -> void          # release'te derlenir ama yazılmaz
static func i(cat: StringName, msg: String) -> void
static func w(cat: StringName, msg: String) -> void          # push_warning'e sarar (iz için)
static func e(cat: StringName, msg: String) -> void          # push_error'a sarar (iz için)
static func breadcrumbs(n: int = 200) -> PackedStringArray   # halka tampon (I/W/E), rapor paketi için
static func install() -> void                                 # Net._ready'den: OS.add_logger(_sink); session.lock
static func uninstall() -> void                               # çıkışta: remove_logger, kilit sil, flush
static func set_min_level(level: Level) -> void              # release varsayılanı I; --log-level=D arg

# core/log_sink.gd  (extends Logger; yalnız Log kullanır)
func _log_message(message: String, error: bool) -> void      # Mutex; "t=+s lvl=I cat=? msg=" satırını dosyaya; push_* YOK
func _log_error(function: String, file: String, line: int, code: String, rationale: String,
        editor_notify: bool, error_type: int, script_backtraces: Array[ScriptBacktrace]) -> void
    # type 0/2 → lvl=E, 1 → W, 3 → E cat=shader; code boşsa rationale; iz varsa bt.format(2) alt satır;
    # aynı (file,line,code) 1 sn içinde tekrarında sayaç ("x12") — ağ log tekrarı kuralı (mimari §6)
    # dosya: user://logs/insiders.log, 2 MB'da döndür (insiders.1.log, .2.log); W/E'de flush, I'de 1 sn'de bir

# core/build_info.gd
class_name BuildInfo
static func load() -> Dictionary        # res://build_info.json ya da {"version":"dev"}
static func label() -> String           # "dev" | "test-3 (a1b2c3d)" | "0.1.0 (a1b2c3d)"
static func protocol() -> int

# core/report.gd  ("Sorun bildir" paketi; main.gd F8/duraklat'tan)
static func build_package(note: String, dump: Dictionary, screenshot: Image) -> String  # zip yolu döner
    # içerik: note.txt, dump.json, insiders.log (+ previous.log kilit varsa), godot.log, screenshot.png,
    # system.json {os, version_alias, cpu, gpu/driver, engine, build, transport, ping_ms, peers}
```
Not: `_log_message` çok sık çağrılır (her print); release'te `print` zaten az (mimari §6 `push_*` kuralı). `Logger` sink'inin kendi `print` çağırması **yasak** (özyineleme).

### Karar gereken (koordinatöre)
1. **Test build şablonu:** `test-N` dağıtımı debug şablonuyla mı (script hata izi + crash bloğu), release mi, ikisi mi? (T2-2; performans ölçümü T2-8 ile birlikte.)
2. **IS-043 AC2'nin daraltılması:** "release'te script backtrace" → "push_error/motor hataları + debug build'de script hataları" (T2-1).
3. **`config/version` biçimi:** yalnız `X.Y.Z` (Windows meta fallback'i için), `+hash` yalnız `build_info.json`'da (T2-3).

### Bir sonraki tur için açık sorular
- Release şablonunda crash handler'ın hiç koşmamasının nedeni (MinGW `signal()` + LTO? `-fno-asynchronous-unwind-tables`?) — godot-build-scripts `build-windows.sh` bayrakları okunmalı [?]; davranış ölçüldü, neden açıklanmadı.
- Loopback'e `set_bind_ip` ile Windows istemi gerçekten çıkmıyor mu (temiz VM'de) [?].
- Debug şablonu performans farkı (R7) 2D 20 Hz akışta ölçülmeli [?].
- Linux (Steam Deck) için aynı ölçümler: crash handler (`crash_handler_linuxbsd.cpp`, `execinfo`) release'te yazıyor mu [?].
- `Logger` sink'i `print` yoğunluğunda (bot/`--verbose`) darboğaz mı [?].

### Kaynaklar (tur 2 ekleri)
- Tailscale Windows: adaptör kategorisi https://github.com/tailscale/tailscale/blob/main/wgengine/router/osrouter/ifconfig_windows.go · güvenlik duvarı kuralları https://github.com/tailscale/tailscale/blob/main/wgengine/router/osrouter/router_windows.go · KB "Windows network configuration failed" https://tailscale.com/docs/reference/messages/client/set-network-category-failed · forum 22621 Private profili https://forum.tailscale.com/t/tailscale-windows-build-22621-and-taildrop/2308
- MS Learn Windows Firewall rules (öncelik, iptal → Block): https://learn.microsoft.com/en-us/windows/security/operating-system-security/network-security/windows-firewall/rules · WER LocalDumps: https://learn.microsoft.com/en-us/windows/win32/wer/collecting-user-mode-dumps
- Godot 4.7: Logger https://docs.godotengine.org/en/4.7/classes/class_logger.html · OS https://docs.godotengine.org/en/4.7/classes/class_os.html · ProjectSettings https://docs.godotengine.org/en/4.7/classes/class_projectsettings.html · logging https://docs.godotengine.org/en/4.7/tutorials/scripting/logging.html · ENetMultiplayerPeer https://docs.godotengine.org/en/4.7/classes/class_enetmultiplayerpeer.html · exporting https://docs.godotengine.org/en/4.7/tutorials/export/exporting_projects.html
- Godot 4.7 kaynak: `platform/windows/crash_handler_windows_signal.cpp`, `crash_handler_windows.h`, `godot_windows.cpp`, `os_windows.cpp` · `core/io/logger.cpp` · `modules/gdscript/gdscript_vm.cpp` · `editor/export/editor_export_preset.cpp` · `platform/windows/export/template_modifier.cpp` · `modules/multiplayer/scene_multiplayer.cpp` · `modules/enet/enet_multiplayer_peer.cpp` · `thirdparty/enet/peer.c`, `enet.h` (https://github.com/godotengine/godot/tree/4.7)
- Deney projesi ve ham çıktılar: scratchpad `opguv-t2/` (`proj/main.gd`, `custom_*.log`, `godot_*.log`)
