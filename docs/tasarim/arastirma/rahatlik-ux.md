# Rahatlık (UX), kontroller ve erişilebilirlik tasarımı (tasarım araştırması, 4. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; kalem kimlikleri (IS-UX-n) koordinatörce verilir. Kullanıcı isteği: oynanış rahatlığı.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[mevcut]** koddan okunan (ui/main_menu.gd, project.godot, texts.csv, tokens.gd).
Dayanak: GDD §6.5 (görüş kipleri host kuralı), §11, §12, §14.1 kural 5 (hareket azaltma), §15; mimari S5 (girdi), S9 (tr(), token); README Tailscale akışı; steam-yayin.md Ö5 (Deck: yazı ≥ 12 px @1280×800, tüm menüler gamepad); okunabilirlik-2d.md §3 (renk körlüğü seçeneği); tuzaklar.md #6 "son %10" (ayarlar, yeniden atama backlog'da yok), §2 sürüm uyuşmazlığı mesajı.
Kısıtlar: tek kişi + ajanlar, sanatçı yok, hedef kitle kullanıcı + 2-3 arkadaş (TR + SE), ilk etapta Tailscale ile IP girerek; tr/en.

## 0. Özet
- Bugün en pahalı rahatsızlık bağlantı: ad + IP + port her açılışta elle, host kendi adresini oyun dışından öğreniyor, hata metni tek cümle ("adresi kontrol et") [mevcut]. İlk 15 dakikanın iade/terk nedeni budur (tuzaklar §1) → §2'deki üç XS iş test-1'den önce.
- Kontrolde eksik: her "basılı tut" (sızma, koşu, etkileşim) için "geçiş" seçeneği (GAG orta seviye, XAG 107: zorunlu sayılıyor [olgu]); kip göstergesi yok; gamepad istemi "[E]" yazıyor.
- Ayarlar ekranı yok; hareket azaltma bayrağı US-014'te var ama kullanıcı arayüzü yok. Küçük bir "Ayarlar v0" (ses 4 kanal, pencere, hareket azaltma, yazı ölçeği) test-2'den önce yetişir.
- Öğretici: ayrı seviye değil, bakkalın üstüne tetikleyici bazlı tek satırlık ipuçları (Overcooked ilkesi: ilk seviye "öğretici" demeden öğretir [olgu]).
- Host kuralı yalnız oyun bilgisini değiştiren şeyler (görüş kipi, tohum, ton); kalan her şey kişisel ve anında uygulanır.

## 1. Kontrol şemaları

| Eylem | Klavye + fare (varsayılan) | Yalnız klavye | Gamepad (Xbox adlandırması) | Not |
|---|---|---|---|---|
| Hareket | WASD / oklar | aynı | sol çubuk + D-pad | 8 yön + analog; analog büyüklük yalnız hızı ölçekler (≥ 0,5×), **kipi değiştirmez** (algı kipe bakar, GDD §6.1) |
| Bakış (Yönlü kip) | fare imleci: karakter merkezinden imlece yön; imleç 16 px'ten yakınsa yön değişmez (titreme yok) | hareket yönüne 0,33 sn'de yumuşak döner (GDD §6.5) | sağ çubuk; radyal ölü bölge 0,25; çubuk bırakılınca 0,33 sn'de hareket yönüne döner | dönüş tavanı 240°/sn her cihazda; "Tek çubuk" ayarı = klavye-yalnız davranışı (XAG: çekirdek mekanik iki çubuk gerektirmesin [olgu]) |
| Sızma | Ctrl | Ctrl | LT (eksen 4) | öneri varsayılan **geçiş** (toggle); seçenek "tut" |
| Koşu | Shift | Shift | RT (eksen 5) | varsayılan **tut**; seçenek "geçiş"; koşu basılınca sızma kilidi düşer (tek zihinsel model: "koştun, artık sızmıyorsun") |
| Etkileşim | E (tut) | E | A (tut) | seçenek "tek basış": basınca başlar, süre aynı (kasa 3 sn), iptal = tekrar bas / hareket girdisi / menzil dışı; host protokolü (S7) değişmez |
| Sindirme (T2+) | Q | Q | X | bakkalda yok (KR-020) |
| Oyala/Satın al vb. (US-010) | E (bağlamsal, en yakın Interactable) | E | A | tek tuş; ikinci eylem gerekirse F / Y (`alt_action_key`, S7 PropDef) |
| Ekip paneli ayrıntısı (§6) | Tab (tut) | Tab | Back (tut) | nakit büyük, ping, çanta kimde |
| Duraklat | Esc | Esc | Start | mevcut |
| Hata ayıklama | F3 | F3 | — | gamepad LB'den **kaldır** (yanlışlıkla; yalnız dev build) |

- **Fare imleci:** oyun içinde sistem imleci gizli, 8 px FG nokta + 1 px BG dış çizgi (sis ve cam üstünde okunur); UI açıkken sistem imleci geri gelir. Neden: imleç = bakış hedefi, dünya üstünde net görünmeli. Risk: imleç ekran kenarına gidince `Input.MOUSE_MODE_CONFINED` gerekir, Alt-Tab'de serbest bırak.
- **Sızma geçiş gerekçesi [görüş]:** gizlilik oyununda sızma dakikalarca sürer; Ctrl'yi tutmak yorucudur (GAG "holds" maddesi [olgu]). Risk: oyuncu sızmada kaldığını unutur, müşteri bölgesinde çömelmiş yürür (çarpan 0,5, GDD §6.1) → HUD'da kip ikonu şart (§6) ve kukla silueti (§14.1 kural 1). Varsayılanı test-2'de ölç: koşu sonunda "kip karışıklığı" sorusu ≤ 1 kişi.
- **Etkileşim tek basış** oyun dengesini değiştirmez (süre ve host doğrulaması aynı); yalnız "bırakınca iptal" yerine "hareket edince iptal". Risk: kasa başında yanlışlıkla WASD'ye değen oyuncu iptal olur → ölü bölge 0,3 ve 0,15 sn gecikme.
- **Tuş yeniden atama** (GAG temel, XAG 107 "tüm kontroller oyun içinde" [olgu]): Ayarlar > Kontroller; eylem başına 1 klavye + 1 gamepad yuvası; `ui_*` ve Esc/B sabit (menüden çıkış kilitlenmesin); çakışmada uyarı, "Varsayılana dön"; `user://input.cfg` (ConfigFile; InputMap çalışma anı değişiklikleri kaydedilmez, açılışta yeniden uygulanır [olgu]). Eklenti değil kendi küçük uygulamamız (KR-009 bakım ilkesi). Zaman: Faz 4 yayın hazırlığı; arkadaş testinde gerekmez.
- **Cihaz algılama + simgeler:** son girdi cihazına göre istem metni `[E]` ↔ `[A]` (HUD_PROMPT zaten biçimli; anahtar `KEY_<eylem>_KB` / `_PAD`); 0,5 sn içinde iki cihaz karışırsa son basılan. Steam Input glyph API'si Faz 5 (Deck Verified).
- Hassasiyet: fare/çubuk için bakış dönüş tavanı ±%50 (XAG: her analog girdi için ±%50 aralık [olgu]); sol çubuk ölü bölge 0,1-0,4 kaydırıcı.

## 2. Bağlantı akışı (ENet + Tailscale dönemi)
Mevcut: ad, host port, katıl adres+port; `parse_address` "adres:port" kabul ediyor [mevcut]. Öneriler (ucuzdan pahalıya):
1. **Hatırla:** ad, son host adresi:port ve "son 5 adres" `user://session.cfg`; açılışta alanlar dolu, odak doğrudan "Katıl" ya da "Host ol" (GAG: oyunu çok katmanlı menüsüz başlat [olgu]). AC: ikinci açılışta tek tuşla katılım; ilk açılışta ad alanı odakta.
2. **Host kendi adresini görür:** host olunca "Oturum açıldı — arkadaşlarına gönder: `100.64.0.2:7777` [Kopyala]"; adres `IP.get_local_addresses()` içinden 100.64.0.0/10 (Tailscale CGNAT) aralığındaki adres, yoksa ilk özel adres + "Tailscale bulunamadı" notu. Katılan tarafta "[Yapıştır]" panodan `adres:port` alır. Neden: README adımı 2 ve 4 oyun dışına çıkmadan biter. Risk: birden çok 100.x arabirimi (VPN) → listede ilkini göster, altına diğerleri.
3. **Port alanı "Gelişmiş" altına:** varsayılan 7777; arkadaş hiç görmez.
4. **Anlaşılır hatalar** (metin anahtarları `MENU_ERROR_*`, tr/en; her biri ≤ 2 satır + 3 maddelik kontrol listesi):
   - Zaman aşımı (5 sn): "`100.64.0.2`'ye ulaşılamadı. Host oyunu açtı mı? · Tailscale'de aynı ağda mısınız (`tailscale ping`)? · Host'ta güvenlik duvarı UDP 7777'ye izin verdi mi?"
   - **Sürüm uyuşmazlığı:** host el sıkışmada reddediyor ama istemciye neden gitmiyor [mevcut, Game PROTOCOL_VERSION] → ret nedeni el sıkışma yanıtında kodla (`version_mismatch`, `full`, `in_progress`) ve mesaj: "Sürümler farklı: sende 0.2.1 (a1b2c3), host'ta 0.2.3. Aynı build'i indirin." (cekirdek XS + arayuz XS)
   - Dolu: "Oturum dolu (4/4)". Host koptu: "Host ile bağlantı koptu. [Yeniden bağlan] [Menü]".
5. **Build kimliği** ana menü sağ altta: `v0.2.1 · a1b2c3 · 2026-10-02` + [Kopyala] (hata bildiriminde ekran görüntüsü yeter). 15 px MUTED.
6. **Bağlanıyor… geri bildirimi:** sayaç "(2/5 sn)" ve Vazgeç (var); "Bağlandı, seviye yükleniyor…" (var).
7. **Yeniden bağlanma (aynı slot), Faz 2b/3:** istemci kopunca aynı adrese 3 otomatik deneme (2/4/8 sn); host 60 sn slotu ve donmuş avatarı tutar (GDD §11: 10 sn sonra bot — MVP'de donar); aynı ad + aynı adres → aynı slot ve avatar. Risk: kimlik ada dayalı (sahte ad) — arkadaş oyununda kabul; Faz 5'te SteamID. Maliyet orta (cekirdek).
8. **LAN keşfi:** UDP yayın 7778 ile "yakındaki oturumlar" listesi; Tailscale'de yayın çalışmaz → yalnız aynı ev ağı; TR↔SE için değersiz, **P3**. "Son 5 adres" listesi aynı işi görür.

## 3. Lobi (bekleme odası)
Bugün host "Host ol" deyince seviye hemen yükleniyor, geç gelen süren işin ortasına düşüyor [mevcut]. Bakkal 3-5 dk olduğundan "hep birlikte başla" gerekir.
- **Lobi v0** (ui/lobby.tscn; seviye yüklenmeden önce): oyuncu listesi (ad, slot rengi atkı yayı, ping, Hazır işareti), host kuralları paneli (Görüş: Yönlü / Çevresel — US-011c ile aynı seçim; tohum; oyuncu sayısı; ileride ton), davet adresi + [Kopyala], istemcide [Hazır] geçişi, host'ta [Başla] (herkes hazır değilse de basılabilir, 3 sn geri sayım herkeste), kontrol kartı (§1 tablosunun 5 satırı, cihaz simgeleriyle — ölü zamanı öğrenmeye çevirir).
- Kural satırının altında tek cümle açıklama: "Yönlü: fareyle bakarsın, arkan görünmez." Kural değişimi herkeste anında (çoğaltılan lobi durumu, host yetkili).
- Ad ve renk: ad ana menüden, renk = slot (KR-018; 4 slot 4 renk, seçim gereksiz); "yer değiştir" (renk takası) Faz 4 kozmetik.
- Geç katılan: lobideyse hemen; soygun sürüyorsa "izleyici" (kamera bir ekip arkadaşında, girdi yok) + iş sonu "Bir daha"da ekibe girer. Risk: izleyici kipi seviye yükleme + spawn'suz oyuncu → cekirdek S; yoksa "soygun sürüyor, bitince katılacaksın" bekleme ekranı (XS) yeter.
- Sohbet: metin sohbeti **yok** (Discord var, tuzaklar §2 "sesli iletişim" notu); Faz 3 plan masasında ping/çizim bunun yerine geçer.
- İş sonu: "Bir daha" (aynı lobi + yeni tohum) / "Lobiye dön" (kural değişikliği) / "Ayrıl".
- Zaman: 2b (test-2 için "hep birlikte başla" gerekli [görüş]); Steam lobisi (Faz 5) aynı ekranın altına taşıma değişikliği olur.
- AC: 3 oyuncu lobiye girip host Başla'dan ≤ 5 sn'de hepsi seviyede; görüş kipi her peer'da aynı (döküm `vision.mode`); gamepad ile tüm lobi gezilir.

## 4. İlk iş öğreticisi: rehberli bakkal
- İlke: ayrı öğretici seviye yok (bütçe), metin paragrafı yok. Bakkal + **ipucu katmanı**: tetikleyici bazlı, tek satır, alt orta, FG 18 px, 3-4 sn, oyuncu başına **bir kez**, yerel (ağ yok). Emsal: Overcooked ilk seviye tezgâhı ayırıp iş bölümünü dayatır, "öğretici" demez [olgu]; Monaco ilk seviyede tek mekanik.
- Rehber ipuçları (anahtar `HINT_*`; tetik → metin):
  | Tetik (mevcut sinyal) | İpucu |
  |---|---|
  | seviye yüklendi (`level_loaded`) | "[WASD] yürü · [Shift] koş · [Ctrl] sız" (5 sn, cihaz simgeli) |
  | ilk kez kip değişti (`move_mode`) | sızma: "Sızarken ses çıkarmazsın ama müşteri gibi görünmezsin" / koşu: "Koşarken ses halkası çıkar" |
  | ilk cam görüş hattı (US-011 karo 2 + `see_through`) | "Camdan içeri bak: sahip nerede?" |
  | ilk Interactable menzilde (`interaction_target_changed`) | istem zaten var; ek: "basılı tut" çubuk altı yazısı yalnız ilk kez |
  | ilk "?" (şüphe ≥ 30, ON-04 çoğaltma) | "Sahip şüphelendi: dur, masum davran" |
  | ilk "!" (`alert_level_changed` ≥ 2) | "Bağırdı! Çantayı kap, kaçış noktasına koş" + kaçış bölgesine kenar oku |
  | ekip arkadaşı tutuldu (`held`) | arkadaşa: "[E] Çek — 6 sn için" |
  | içeride 45 sn (US-010 oyalanma) | "Uzun kaldın: bir şey satın al ya da çık" |
- Ayar: İpuçları **yalnız ilk 2 koşu** (varsayılan) / hep / kapalı; kişisel. Host rehber kutusu yok (ipucu bilgi vermez, kuralı hatırlatır).
- Ölü zaman: lobi kontrol kartı (§3) + ilk koşuda spawn kaldırımda, kasa 10 karo içinde; ilk 30 sn'de ilk ipucu dışında ipucu yok (yüklenme hissi).
- AC (test-2, yontem §9 K türü): brifing yalnız tuşlar; 3 arkadaşın ≥ 2'si ilk koşuda kasayı dener; "ne yapacağım?" sorusu koşu başına ≤ 2; ipucu yüzünden "ekranı kapatıyor" şikâyeti 0 (ipucu panel alfa 0,88, dünya üstünde ≤ 1 satır).
- Maliyet: arayuz S (kuyruk, tek sefer kaydı `user://hints.cfg`, cihaz simgesi), oynanis XS (eksik sinyal: ilk cam görüşü — US-011a'dan `first_window_seen` ya da HUD'un VisionGrid sorgusu).

## 5. Ayarlar ekranı
Erişim: ana menü "Ayarlar" + duraklat menüsü "Ayarlar" (aynı sahne, oyun içinde anında uygulanır). Kayıt `user://settings.cfg` (ConfigFile, `schema_version`); GAG "tüm ayarlar hatırlanır" [olgu]. Her sekmede "Varsayılana dön". Tek ayar kaynağı = US-014'ün "ayar API'si" (`Settings` autoload değil — mimari §6 "sistem başına Manager yok"; `ui/settings.gd` statik okuyucu + `settings_changed(key)` sinyali, oynanış/görsel katman anahtarla okur).

| Sekme | Ayar | Varsayılan | Kişisel / host | Not |
|---|---|---|---|---|
| Ses | Ana · Efekt · Müzik · Arayüz (4 bus, IS-024 kataloğu) | 80/100/70/100 | kişisel | kaydırıcıda değişince önizleme SFX; "pencere arkadayken kıs" |
| Görüntü | Tam ekran / pencere (Alt+Enter) · VSync · FPS sınırı (kapalı/60/120/144) · arayüz ölçeği %100/125/150 (`content_scale_factor`) · kamera yakınlaştırma 1,25/1,5/1,75 | pencere, VSync açık, sınır kapalı (Deck 60), %100, 1,5 | kişisel | zoom avantaj değil: görüş yarıçapı sabit (GDD §6.5) → AC: zoom `visible_tiles` sayısını değiştirmez |
| Erişilebilirlik | Hareket azaltma (US-014 AC4 + sis geçişi + halka + balon pop) · Yanıp sönme azaltma ("!" titreme, uyarı kutusu pop → sabit; ≤ 3 flaş/sn kuralı [olgu]) · Kamera sarsıntısı 0-100 (ileride) · Yazı ölçeği 1,0/1,25/1,5 (FONT_SIZE token çarpanı) · Yüksek kontrast arayüz (panel alfa 0,88 → 1,0) · ALERT rengi: kırmızı / vermilyon #d55e00 / mavi #0072b2 (okunabilirlik §3) · Oyuncu rengi seti: noir / Okabe-Ito · İpuçları (§4) | hepsi kapalı/1,0 | kişisel | hiçbir bilgi yalnız renkle değil (şekil zaten var); ses olayları görsel halka → "yalnız sesle bilgi yok" sağlanır |
| Kontroller | Sızma: geçiş/tut · Koşu: tut/geçiş · Etkileşim: tut/tek basış · Bakış hassasiyeti ±%50 · Sol çubuk ölü bölge · Tek çubuk kipi · Titreşim (ileride) · Tuş atama (Faz 4) | §1 | kişisel | cihaz simgesi otomatik |
| Oyun | Dil (sistem/tr/en) · Ad | sistem | kişisel | — |
| **Host kuralları (lobi, ayarlar değil)** | Görüş kipi · tohum · oyuncu sayısı · ton (KR-005) | GDD/KR-023 | **host** | oyun bilgisini değiştiren her şey host'ta; görüş yarıçapı, sis, karanlık asla ayar değil (hile sınırı) |

Zaman: **Ayarlar v0** test-2 öncesi = Ses + Görüntü (pencere/VSync) + hareket azaltma + yazı ölçeği + ipuçları + kip tut/geçiş (arayuz M); renk körlüğü, kontrast, tuş atama, sarsıntı Faz 4.

## 6. HUD rahatlığı
- Mevcut yerleşim: nakit sol üst, ekip + ping sağ üst, uyarı merdiveni üst orta (US-013), istem + çubuk alt orta, maruziyet rozeti sol alt (US-011c) [mevcut]. Kenar boşluğu `SCREEN_MARGIN` 20 px, metin 18/15 px [mevcut].
- **İki katman:** "her zaman" = uyarı merdiveni, kendi rozeti + **kip ikonu** (sız/yürü/koş, 22 px, rozetin yanında), istem; "bakınca" (Tab/Back tut) = ekip ayrıntısı (ping, çanta kimde, yakalandı/kaçtı ikonları), nakit büyük. Varsayılanda ekip paneli yalnız ad + durum ikonu (tek satır), ping yalnız > 120 ms ise küçük uyarı (ON-05 ruhu: sayı değil durum).
- Bütçe: 1280×720'de HUD ≤ %12 ekran alanı; her panel ≤ 2 satır; oyun bilgisi metni ≥ 18 px, ikon ≥ 22 px; panel alfa 0,88, kontrast seçeneğiyle 1,0.
- Oyalanma (US-010): sayı değil, rozet yanında 45 sn'den sonra dolan ince yay (müşteri kılığı bitiyor); sayaç metni yok (Invisible Inc. tuzağı, okunabilirlik §5).
- Kenar okları: ekip (atkı rengi, var); bağırıştan sonra kaçış bölgesine CASH renkli ok (ipucu değil, kalıcı).
- **Steam Deck (1280×800, 16:10):** `aspect=expand` dikeyde fazla alan verir; köşe anchor'ları yeterli; 18 px yazı 800p'de ≥ 12 px kuralını [olgu] geçer; 15 px SMALL yalnız ikincil (sınırda, Deck'te 16'ya çek). LineEdit odaklanınca sanal klavye (Steam Input otomatik; test). Tüm menü/lobi/ayarlar gamepad ile gezilir (US-003 AC6 odak halkası var; yeni ekranlar aynı `UiInput` yardımcılarını kullanır). AC: 1280×800 ve 1920×1080 headless düzen testi taşmasız (mevcut teste çözünürlük ekle).

## 7. Öncelik: test-1 / test-2 öncesi en yüksek getirili 8 iş

| # | Başlık | Sahip | B | Ne zaman | Kabul kriteri (özet) |
|---|---|---|---|---|---|
| UX-1 | Bağlantı kolaylığı: ad + son adres hatırlanır, host kendi Tailscale adresini + [Kopyala] görür, [Yapıştır], port "Gelişmiş" altında | arayuz | XS-S | **test-1 öncesi** | ikinci açılışta tek tuş katılım; host ekranında `100.x.y.z:7777`; `parse_address` panodan; birim: adres seçimi 100.64/10 önceliği; sabit metin 0 |
| UX-2 | Anlaşılır bağlantı hataları + sürüm uyuşmazlığı nedeni istemciye + build kimliği menüde | cekirdek XS + arayuz XS | S | test-1 (mümkünse) / test-2 | el sıkışma reti kodlu (`version_mismatch`/`full`/`in_progress`); her hata ≤ 2 satır + 3 madde; `late_join` senaryosuna sürüm farkı varyantı |
| UX-3 | Tut↔geçiş: sızma/koşu/etkileşim kipleri ayarı + HUD kip ikonu | oynanis XS + arayuz XS | S | test-2 öncesi | `PlayerInput` geçiş mantığı birim testli (koşu sızma kilidini düşürür; etkileşim tek basışta hareketle iptal); bot girdisi etkilenmez; ikon 22 px üç durum |
| UX-4 | Ayarlar v0 (ses 4 kanal, pencere/tam ekran, VSync/FPS, hareket azaltma, yazı ölçeği, ipuçları, kip ayarları) + `user://settings.cfg` + duraklat menüsünden erişim | arayuz | M | test-2 öncesi | her ayar anında uygulanır ve yeniden açılışta kalır; hareket azaltma US-014/US-011 bayraklarını tek kaynaktan sürer; gamepad ile gezilir; 0 sabit metin |
| UX-5 | İpucu sistemi + rehberli bakkal (§4 tablosu) | arayuz S + oynanis XS | S | test-2 öncesi | 8 ipucu tetikleyiciden bir kez; `user://hints.cfg`; ayarla kapanır; headless: sahte sinyallerle sıra ve tek-seferlik birim testi |
| UX-6 | Cihaz algılama ve tuş simgeleri (`[E]`/`[A]`), fare imleci noktası, sağ çubuk ölü bölge/eğri, F3'ü gamepad'den kaldır | arayuz XS + oynanis XS + altyapi XS | S | test-2 öncesi (US-011b/d ile) | son cihaz 0,5 sn kuralı; istem metni cihazla değişir (birim); imleç 16 px ölü bölge; `look_*` ölü bölge 0,25 |
| UX-7 | Lobi v0: bekleme odası, Hazır/Başla, host kuralı (görüş kipi — US-011c'nin seçimi buraya), kontrol kartı, geç katılan bekleme/izleyici | arayuz S + cekirdek S | M | 2b (test-2 "hep birlikte başla") | 3 oyuncu ≤ 5 sn'de aynı anda seviyede; kip her peer'da aynı; geç gelen işin ortasına düşmez |
| UX-8 | HUD katmanlama (Tab ayrıntı, ekip paneli tek satır, oyalanma yayı, kaçış oku) + 1280×800 düzen testi + kontrast seçeneği | arayuz | S | 2b | HUD alanı ≤ %12; 720p/800p/1080p taşmasız; ekran görüntüsü kanıtı (IS-022) |

Faz 4'e: tuş yeniden atama (S), renk körlüğü paleti + oyuncu renk seti (S), yeniden bağlanma aynı slot (cekirdek M), kamera sarsıntısı ayarı (sarsıntı gelince). Faz 5: Steam Input glyph'leri, Deck sanal klavye doğrulaması, Steam lobisi (UX-7 ekranının altına). P3: LAN keşfi.

## 8. Riskler
- **R1 Sızma "geçiş" varsayılanı kip karışıklığı yaratır** (çömelmiş müşteri tuhaf, çarpan 0,5): kip ikonu + kukla silueti olmadan açılmamalı; test-2'de ölç, gerekirse varsayılan "tut".
- **R2 Ayarlar kapsam kayması:** tuzaklar §5 "son %10" tersi — Ayarlar v0 beş ayarla sınırlı kalmalı; renk/kontrast/atama Faz 4.
- **R3 Lobi, Faz 5 Steam lobisiyle iki kez yazılır:** ekran ve durum makinesi taşımadan bağımsız (S1 üstünden) kurulursa yalnız "davet" satırı değişir.
- **R4 Yeniden bağlanma ada dayalı:** arkadaş oyununda kabul; açık lobi gelirse SteamID şart.
- **R5 İpuçları ekranı kirletir / küçümser:** tek satır, bir kez, alt orta, kapatılabilir; "rehber modu" gibi ayrı kip yok.
- **R6 Fare imleci kenetleme (CONFINED) Alt-Tab ve ikinci monitörde rahatsız eder:** pencere odağı kaybolunca serbest bırak; ayarla kapatılabilir.
- **R7 Host adresi tespiti yanlış arabirimi gösterir** (VPN, sanal ağ): listeyi göster, elle düzenlenebilir alan kalır.
- **R8 Steam Deck hiç test edilmedi:** 800p düzen testi headless'ta yapılabilir; sanal klavye ve glyph yalnız cihazda (Faz 5).

## 9. Karar gereken (kullanıcıya, en fazla 3)
1. Sızma varsayılanı **geçiş** mi (öneri; kip ikonuyla), **tut** mu? İkisi de ayarda olacak; soru yalnız varsayılan ve test-2 ölçümü.
2. Lobi v0 (UX-7) **2b'de** mi (öneri; test-2'de "hep birlikte başla"), yoksa Faz 5 Steam lobisiyle birlikte mi?
3. Yeniden bağlanma aynı slota (ada dayalı) **Faz 3**'e mi alınsın (öneri; TR↔SE kopmalarında işi kurtarır), yoksa Faz 5 SteamID'yi mi beklesin?

## Kaynaklar
- Game Accessibility Guidelines, temel ve orta seviye: https://gameaccessibilityguidelines.com/basic/ · https://gameaccessibilityguidelines.com/?p=21 (holds alternatifi, yeniden atama, ayarların hatırlanması, menüsüz başlatma, etkileşimli öğretici)
- Xbox Accessibility Guidelines 107 Input: https://devdocs.xbox.com/build/game-principles/accessibility/xag-deep-dives/xag-107-input.md (oyun içi yeniden atama, uzun tutma yerine geçiş, eşzamanlı basış yok, analog hassasiyet ±%50, tek çubuk)
- Steam Deck uyumluluk: https://partner.steamgames.com/doc/steamdeck/compat (yazı ≥ 9 px, önerilen 12 px @1280×800; gamepad simgeleri; sanal klavye)
- Lethal Company davet akışı: https://twinfinite.net/guides/how-to-invite-friends-in-lethal-company/ · PEAK lobi (Invite Only varsayılan, arkadaş listesinden katıl): https://www.destructoid.com/?p=1096910 · Deep Rock Galactic (overlay'den katılma, görev ortasına katılım): https://deeprockgalactic.wiki.gg/wiki/Multiplayer
- Overcooked ilk seviye tasarımı: https://superjumpmagazine.com/overcooked-how-design-creates-teamwork · https://www.wayline.io/blog/tutorials-onboarding-level-design
- Godot InputMap kalıcılığı (ConfigFile, user://): https://bugnet.io/blog/fix-godot-input-default-actions-not-persisted-when-customized · Maaack's Input Remapping (yalnız referans, eklenti kullanılmaz): https://store.godotengine.org/asset/maaack/maaacks-input-remapping/
- Flaş eşiği (≤ 3/sn) ve hareket azaltma: https://help.play.date/accessibility/reduce-flashing/ · https://www.w3.org/2020/10/TPAC/w3cx-motion.html
