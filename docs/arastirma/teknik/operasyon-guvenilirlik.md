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
