# Steam'de yayın süreci — uçtan uca (araştırma)

Tarih damgası: 2026-10-02 · Kapsam: küçük bağımsız co-op oyunu, Türkiye'den tek geliştirici · Yazan: araştırma ajanı (geliştirme dışı)
İşaretler: **[O]** olgu (kaynağı aşağıda), **[G]** görüş/yorum, **[?]** belirsiz ya da doğrulanması gereken, **[ESKİ]** eski/çelişkili bilgi.

## Özet (10 satır)
1. Steam Direct: uygulama başına 100 $, iade edilmez; oyun 1.000 $ düzeltilmiş brüt gelire ulaşınca geri ödenir. Ödemeden sonra yayına en az 30 gün bekleme var. [O]
2. Kayıt: yasal ad her yerde (banka, vergi, kimlik) birebir aynı olmalı; vergi doğrulaması 10-15 iş günü sürer. Türkiye'den bireysel geliştirici W-8BEN dengi formu doldurur, ABD-TR anlaşmasıyla stopaj %30 yerine en fazla %10 olur. [O]
3. İlk oyununu çıkaran geliştirici, AppID açıldıktan 3 hafta sonra Steam anahtarı isteyebilir. Yayın öncesi test anahtarı ("Release State Override") en fazla ~2.500 adettir. [O]
4. Mağaza sayfası ve build ayrı ayrı incelenir (3-5 iş günü). Her biri için en az 7 iş günü önce gönder. "Coming Soon" sayfası yayından en az 2 hafta önce açık olmalı. [O]
5. Wishlist çıkışta ve %20 ve üstü indirimlerde e-posta tetikler. Valve 2026'da "Personal Calendar" adlı kişisel takvimi getirdi. "7.000 wishlist / Popular Upcoming" kuralını yazarı arşivledi. [O]
6. Next Fest: oyun başına bir kez katılınır. Herkese açık mağaza sayfası ve demo şarttır. Sıradaki tarihler: 22 Şub-1 Mar 2027, 14-21 Haz 2027. Playtest, Next Fest'te demonun yerini tutmaz. [O]
7. Fiyat: Türkiye 20.11.2023'ten beri MENA-USD bölgesinde (USD), İsveç ise EUR fiyatı görür. Yeni "4'lü paket" (çoklu kopya) oluşturulamaz. Bu tür oyunlarda (friendslop) tipik fiyat 5-10 $. [O]
8. Yapay zekâ beyanı (16-19 Ocak 2026 güncellemesi): kod asistanları gibi verimlilik araçları beyan dışı. Oyuncunun gördüğü içerik (oyun içi, mağaza, pazarlama) beyan edilmeli. [O]
9. Yaş derecelendirmesi Steam'in ücretsiz içerik anketiyle yapılır. Almanya (15.11.2024'ten beri) ve Endonezya'da derecelendirme yoksa oyun görünmez. IARC'ye gerek yok. [O]
10. MVP (yalnızca arkadaşlar) için herkese açık yayın gerekmez: kendi AppID'n, SteamPipe build'i ve test anahtarı yeter. Steamworks kaydını Faz 5'e bırakmak takvime 4-6 hafta risk ekler. [G]

---

## 1. Kayıt, ücret, vergi ve banka
- **[O]** Steamworks iş ortağı kaydında bireysel ("Sole Proprietorship") ya da şirket olarak kaydolunur. Yasal ad; banka hesap sahibi, vergi formu ve imzacı kimliğinde birebir aynı olmalı. Takma ad ya da marka adı kabul edilmez.
- **[O]** Steam Direct ücreti uygulama başına 100 $'dır (ya da yerel karşılığı). Steam cüzdanıyla ödenmez, iade edilmez. Ürün 1.000 $ düzeltilmiş brüt gelire ulaştıktan sonraki ödemede geri verilir. Ülkeye göre KDV eklenebilir. Ödemeyi yapan yönetici hesabına kredi olarak yazılır.
- **[O]** Ücret ödendikten sonra yayına kadar 30 gün beklenir (Valve bu sürede kimlik doğrular). Bu kural steamdirect sayfasında yazıyor ama "releasing" belgesinde geçmiyor. **[?]** Hâlâ uygulandığını varsayıp planla.
- **[O]** Vergi mülakatı: ABD dışı kişiler W-8BEN dengi bilgi verir. Vergi doğrulaması 10-15 iş günü sürer ve bu sürede bilgi değiştirilemez.
- **[O]** ABD-Türkiye vergi anlaşmasında telif/royalty stopaj tavanı %10'dur (sınai ekipman %5). Formsuz stopaj %30'dur. Türk kaynakları (muhasebetr, 07.10.2025) Steam geliri için de %10'u yazıyor.
- **[O/?]** Türkiye tarafı: Türk muhasebe kaynakları, Steam'den düzenli gelir için vergi mükellefiyeti ve şirket (çoğunlukla şahıs/adi ortaklık) öneriyor. Genç girişimci istisnası ve SGK desteği mümkün olabilir. GVK 20/B (%15 banka stopajı) **mobil uygulama** geliştiricileri için yazılmış; PC/Steam oyununu kapsayıp kapsamadığı belirsiz. **[G]** İlk Steam ödemesinden önce bir mali müşavire danış. Bireysel kayıtta yasal ad ve banka (USD hesap, SWIFT) şimdiden tutarlı olsun.
- **[O]** Build yüklemek için ayrı bir "build hesabı" önerilir (yalnızca metadata düzenleme ve yayınlama yetkisi). Yayındaki uygulamada bu hesaba telefon ya da Steam Mobile bağlı olmalı. Güvenlik değişikliğinden sonra 3 gün bekleme var.
- **[O]** Gelir payı standart olarak %30 (yüksek ciro eşiklerinde düşer).

## 2. Uygulama kurulumu, depot/branch, SteamPipe, Godot
- **[O]** SteamPipe: SDK'daki ContentBuilder (steamcmd + `app_build`/`depot_build` VDF betikleri) ya da Windows'ta SteamPipeGUI kullanılır. Yüklenen build "Builds" sayfasından **default** ya da şifreli **beta branch**'e alınır. Dağıtım dosya bazlı delta ile yapılır; büyük paket dosyalarını sık yeniden düzenleme (Godot'ta `.pck`) yama boyutunu büyütür.
- **[O]** GodotSteam (GDExtension) ile paket kuralları:
  - Windows paketine `steam_api64.dll`, Linux paketine doğru mimarideki `libsteam_api.so` eklenir.
  - `steam_appid.txt` **gönderilmez**; yalnızca Steam dışından çalıştırma için kullanılır.
  - Her platform için ayrı depot açılır.
- **[O]** Valve, kendi build'ini yükleyip incelemeye göndermeden yayına izin vermez. Bir kez onaylanan uygulamanın sonraki güncellemeleri yeniden incelenmez.
- **[G]** Projemiz için:
  - İki depot olsun: Windows x64 ve Linux x64. Linux, Steam Deck'te yerel çalışır; yerel build yoksa Proton denenir.
  - İç test için şifreli bir `playtest` branch'i ve CI çıktısını steamcmd ile yükleyen bir betik olsun.
  - `.pck` dosyasını tek parça tutmak basit; yama boyutu şimdilik sorun değil.

## 3. Mağaza sayfası, inceleme, zaman çizelgesi
- **[O]** Mağaza ve kütüphane görselleri: header 920×430, small 462×174, main 1232×706, vertical 748×896, isteğe bağlı arka plan 1438×810. En az 5 ekran görüntüsü (≥1920×1080, 16:9, yalnızca oynanış). Kütüphane için capsule, hero ve logo ayrıca hazırlanır.
- **[O]** Capsule görsellerinde yalnızca sanat, oyun adı ve resmî alt başlık olabilir. İnceleme puanı, ödül, "indirimde" gibi yazılar yasak. Geçici "artwork override" en fazla 1 ay sürer ve oyunun desteklediği dillere çevrilmelidir.
- **[O]** Coming Soon: mağaza kontrol listesi tamamlanır, "Mark as ready for review" ile gönderilir, onaydan sonra "Post as Coming Soon" ile yayına alınır. Topluluk merkezi ve wishlist bu adımda açılır. Valve'e göre sanat yönü ve çekirdek özellikler netse sayfayı erken (yıllar önce bile) açmanın bir sakıncası yok.
- **[O]** Yayın kendiliğinden başlamaz; "Release App" düğmesine elle basılır.

**Çıkıştan geriye zaman çizelgesi (herkese açık yayın, en kısa güvenli yol)** — [O] kurallar + [G] tampon
| Çıkıştan önce | Ne |
|---|---|
| ≥ 10-12 hafta | Steamworks kaydı, vergi/banka (10-15 iş günü), 100 $ ödemesi (30 gün sayacı başlar), AppID |
| ≥ 9 hafta | Ad ve marka kontrolü bitmiş; capsule ve logo üretimi |
| ≥ 7 hafta | Mağaza sayfası incelemeye (3-5 iş günü + düzeltme payı) |
| ≥ 6 hafta (kural: 2 hafta) | Coming Soon yayında; wishlist toplanmaya başlar |
| ≥ 3 hafta | AppID'den 3 hafta sonra test anahtarları açılır (ilk oyun); arkadaş/basın anahtarları |
| ≥ 2 hafta | Build incelemeye (≥ 7 iş günü önce); içerik anketi + AI beyanı + Deck isteği isteğe bağlı |
| Çıkış günü | Release App; çıkış indirimi (isteğe bağlı) |
| +30 gün | Fiyat değişikliği ve yeni indirim ancak bundan sonra; indirim bitiminden sonra da 30 gün beklenir |
**[G]** Wishlist toplamak için gerçekçi süre 6 hafta değil, 6-12 ay; 2 hafta yalnızca alt sınır.

## 4. Wishlist, algoritma, Next Fest, demo ve Playtest
- **[O]** Wishlist e-postası şu durumlarda gider: çıkışta (EA'da ve 1.0'da ayrı ayrı); lowest-price paketinde en az %20 ve en az 8 saat süren indirimde; demo çıkışından sonraki 2 hafta içinde bir kez (geliştirici tetikler). Aynı uygulama için iki e-posta arasında 2 hafta bekleme var. Wishlist, çıkış öncesi ve sonrası listelerde ve önerilerde etkili.
- **[O][ESKİ]** "Çıkışta ~7.000 wishlist, ~%20 dönüşüm, Popular Upcoming ilk 10" ölçütleri 2022 tarihli. Zukowski bunları Haziran 2026'da, Valve'in kişisel takvimi (Personal/Personalized Calendar) gelince arşivledi. Takvim benzer oyuncuların wishlist ve oynama verisiyle her gün yeniden eğitiliyor; görünürlük artık kişiselleşmiş. **[?]** Yeni eşikler yayımlanmadı.
- **[O]** Next Fest kuralları:
  - Oyun fest bitmeden çıkmamalı ve yalnızca bir fest'e katılabilir.
  - Ana mağaza sayfası herkese açık olmalı; fest başladığında herkesin oynayabileceği bir demo bulunmalı.
  - Prolog ya da kısa sürüm kabul edilmez.
  - Demo inceleme son tarihleri: basın önizlemesi için festten 5 hafta önce, fest için 3 hafta önce. Basın önizlemesi festten 11 gün önce başlar, fest 7 gün sürer.
- **[O]** Tarihler: 19-26 Eki 2026 (bizim için geç), 22 Şub-1 Mar 2027, 14-21 Haz 2027. Kayıt sayfaları açık.
- **[O]** Zukowski (Tem 2026) iki strateji karşılaştırıyor:
  - **Taban:** sayfayı ve demoyu erken aç, çıkıştan önceki son festi seç.
  - **İvme:** duyuruları festten önceki 2 haftaya topla.

  Yüksek taban + ivme birleşiminin başarı oranı %82, yalnızca yüksek tabanın %27. Deneyimsiz ekiplere taban stratejisini öneriyor. Başka bir yazısında da "demoyu oynayanların çoğu wishlist eklemez, bu normal" diyor.
- **[O]** Demo:
  - Ayrı, ücretsiz bir AppID'dir; Valve incelemesinden geçer.
  - Kendi sayfası ve incelemeleri olabilir, ya da yalnızca ana sayfada bir düğme olur.
  - **Steam, demo ile tam oyun arasında çok oyunculu eşleşmeyi desteklemez.** Co-op'ta demoyu her oyuncunun ayrıca indirmesi gerekir.
- **[O]** Playtest:
  - Ücretsiz bir alt AppID'dir; ana sayfada kayıt bölümü olarak görünür.
  - Oyuncular dalgalar halinde ya da otomatik onayla alınır, ~50.000 anahtar dağıtılabilir.
  - Wishlist, inceleme, oynama süresi ve iade ana oyunla paylaşılmaz.
  - Gizli projeye uygun değildir; Next Fest'te demo yerine geçmez.
- **[G]** Co-op için seçim:
  - Arkadaş grubu ve ilk dış testler → Release State Override anahtarı (≤ 2.500) ya da kapalı Playtest.
  - Herkese açık keşif → Next Fest öncesi co-op demo. Demo tek bir kademe olabilir (ör. bakkal + benzinlik), çünkü oyunun özgün yanı keşif + plan masası ilk 15 dakikada görülmeli.

## 5. Early Access mı tam sürüm mü
- **[O]** EA kuralları:
  - Gelecek özellik ya da tarih için kesin söz verilmez.
  - EA anketi doldurulur; satın alındığı anda oynanabilir olmalı.
  - EA çıkışında ve 1.0'da iki ayrı wishlist e-postası gider; Valve'e göre EA çıkışı tam sürüme göre daha az görünürlük alır.
  - Fiyat yükseltildikten sonra 30 gün indirim yapılamaz.
- **[O]** Sektör görüşü (2025-26): oyuncular "EA" etiketini çoğunlukla görmezden gelir. Çıkış, tam çıkış gibi hazırlanmalı. 1.0 sıçraması da garanti değil.
- **[G]** Bizim için öneri, MVP'den sonra **EA**:
  - 10 kademeli merdiven ve perk ağacı MVP'de yok (2 kademe). Bu tür oyunlar topluluk geri bildirimiyle büyür.
  - Ancak EA çıkışında en az 3-5 kademe ve "tekrar oynanır" bir döngü olmalı; yoksa ilk incelemeler kalıcı zarar verir.
  - Kesin karar, Faz 5 geri bildirimleri ve demo/Playtest verisinden sonra verilmeli.

## 6. Fiyatlandırma
- **[O]** Valve'in önerdiği bölgesel fiyat aracı ("Multi-Variable Conversion") 2022'de güncellendi. GameDiscoverCo (31.10.2025) önerilerin eskidiğini yazıyor: bağımsızlar önerilere uyuyor, Polonya fiyatını ~%20-25 düşürmek gerekiyor, MENA-USD'de bazıları önerinin %20-30 altına iniyor.
- **[O]** Türkiye: 20.11.2023'ten beri fiyatlar USD ve MENA-USD bölgesinde; cüzdanlar o gün USD'ye çevrildi. Geliştirici MENA fiyatını girmezse normal USD fiyatı uygulanır. **[G]** MENA önerisini mutlaka gir; Türk arkadaş da TR'den satın alacak.
- **[O]** İsveç: Steam SEK desteklemiyor; İsveç kullanıcıları EUR fiyatı görür. Bölgeler arası hediyede, düşük fiyatlı bölgeden yüksek fiyatlıya hediye sınırlı.
- **[O]** Fiyat kuralları:
  - Çıkıştan sonraki 30 gün fiyat değiştirilemez.
  - Çıkış indirimi serbest; çıkıştan sonraki 30 gün ve çıkış indirimi bittikten sonraki 30 gün yeni indirim girilemez.
  - Zam yapılırsa 30 gün indirim yapılamaz.
  - Fiyat değişikliği inceleme gerektirir, otomatik zamanlanamaz.
- **[O]** Çoklu paket: yeni "4'lü paket" (bir alımda birden çok kopya) **oluşturulamaz**; eskiler yalnızca miras olarak duruyor. Bundle'lar (Complete the Set) farklı ürünleri birleştirir, aynı oyunun kopyalarını değil.
- **[O]** "Friend's Pass" örnekleri var: Split Fiction, Whisper Mountain Outbreak. Ücretsiz ayrı bir uygulama (demo türü) yalnızca sahibin lobisine katılabilir, host olamaz. **[?]** Ayrı AppID ile lobi/P2P bağlantısının teknik kurgusu doğrulanmalı; demo ile tam oyun eşleşmesinin desteklenmediği kuralıyla çelişebilir.
- **[O]** Tür verisi:
  - 2025'in en çok satan 10 oyunundan 4'ü friendslop: R.E.P.O. 18,5 M, PEAK 15,4 M kopya. PEAK 8 $, çıkış haftasında 5 $; çıkışta yalnızca ~29 bin wishlist vardı, var olan kitle ve izlenebilirlik belirleyici oldu.
  - Zukowski (Tem 2026): tür doymuş değil, ama tepedeki oyunlar 3-9 ayda payını kaybediyor.
- **[O]** İade: 14 gün ve 2 saatten az oynama. Erken erişimde çıkış öncesi oynama da 2 saate sayılır.
- **[G]** Fiyat ve iade için öneri:
  - Taban fiyat 9,99-14,99 $ bandında olsun; çıkışta %10-20 indirim.
  - İade kuralı yüzünden ilk 2 saat kritik: keşif → plan → soygun döngüsü ≤ 15 dk hedefi (Faz 3) iadeye karşı da korur.
  - Çoklu paket olmadığı için "3 kişi alacak" engeli düşük fiyat ya da ileride Friend's Pass ile azaltılır.

## 7. Co-op'a özgü Steam özellikleri — MVP için gereklilik
| Özellik | Ne | MVP (Faz 5) | Sonra |
|---|---|---|---|
| Lobi + davet (ISteamMatchmaking, Friends) | [O] GodotSteam ile lobi oluştur/katıl, `join_requested`, `+connect_lobby` ve rich presence ile arkadaş listesinden katılma | **Gerekli** (faz çıkış kriteri) | — |
| SteamNetworkingSockets P2P + SDR | [O] P2P için ücretsiz, başvuru gerekmez; trafik rölelerden geçer, IP gizlenir | **Gerekli** (TR↔SE NAT sorununu çözer) | — |
| ENet yedeği | proje kararı | Gerekli (faz kriteri) | Steam dışı test |
| Remote Play Together | [O] Yalnızca yerel/paylaşımlı ekran çok oyunculu oyunlar için; online-only oyunda anlamsız | Hayır | Yerel co-op eklenirse |
| Steam Deck incelemesi | [O] Ücretsiz, ~1 hafta; Verified için: varsayılan gamepad şeması, ekrandaki tuş simgeleri giriş aygıtına uyumlu, yazı en az 9 px (önerilen 12) @1280×800, metin girişi Steam klavyesiyle, 800p'de 30 fps | Hayır (ama kurallara şimdiden uy) | Çıkış sonrası iste |
| Başarımlar | isteğe bağlı | Hayır | EA çıkışında (ucuz görünürlük) |
| Steam Cloud | [O] isteğe bağlı | Hayır (kayıt host'ta) | Profil/kampanya kaydı Faz 4'te tasarlanırken yolu Cloud'a uygun seç |
| Steam Input / glyph API | isteğe bağlı | Hayır | Deck Verified için |
**[G]** Faz 2 spike'ı AppID 480 (Spacewar) ile yapılabilir. Ama Faz 5'te kendi AppID'miz olmadan Steam daveti gerçekçi test edilemez: 480'in lobileri herkese ortaktır ve test anahtarı verilemez.

## 8. Yapay zekâ içerik beyanı (güncel kural)
- **[O]** 16-19 Ocak 2026 güncellemesi. İçerik anketinin AI bölümünde iki tür var:
  - **(a) Önceden üretilmiş:** oyunda, mağaza sayfasında ya da pazarlama malzemesinde gönderilen ve oyuncunun tükettiği AI içeriği (görsel, ses, metin, anlatı). Yazılı açıklama gerekir; Valve bunu diğer içerikler gibi yasallık ve tanıtımla tutarlılık açısından değerlendirir.
  - **(b) Canlı üretilen:** oyun çalışırken üretilen içerik. Korkuluklar (guardrail) beyan edilir; canlı üretilen yetişkin cinsel içerik yasak.
- **[O]** Kod asistanları, hata ayıklama ve ofis araçları gibi "verimlilik" araçları **beyan dışıdır**. Yayımlanmayan AI kavram çalışmaları da beyan dışı.
- **[G]** Bizim için:
  - Claude Code ile yazılan GDScript beyan gerektirmez.
  - Ajanların yazdığı ve oyunda gösterilen metinler (`texts.csv`, ipuçları, senaryo adları), AI ile üretilen görsel/ses ve AI yardımıyla yazılan mağaza açıklaması "önceden üretilmiş içerik" sayılır; dürüstçe beyan edilmeli. Valve kuralı "oyuncunun tükettiği" ölçütüyle çiziyor; insan elinden geçirilmiş metinde sınır gri.
  - Canlı AI kullanılmıyor, (b) "hayır".
  - Faz 4'te açılacak `notes/assetler.md`'ye her varlık için bir "AI ile mi üretildi?" sütunu eklemek beyanı kolaylaştırır.

## 9. Yaş derecelendirme, içerik anketi, ad/marka
- **[O]** Steam'de IARC kullanılmaz. Derecelendirme, Steam içerik anketinden Valve'in kendi derecelendirmesiyle üretilir; USK ya da IGRS belgesi varsa ayrıca girilir. Üçüncü taraf mağazalardan IARC kaynaklı USK sonucu girilmemeli.
- **[O]** Derecelendirme olmadan görünmeme: Almanya'da 15.11.2024'ten beri, Endonezya'da da (IGRS: 3+/7+/13+/15+/18+/RC). Anket doldurulmazsa oyun bu ülkelerde görünmez.
- **[O]** Ankette olgun içeriğin tamamı bildirilir, build'de erişilemeyen içerik dahil.
- **[G]** İçeriğimiz: soygun teması, minimal çatışma, kan yok. Muhtemelen "şiddet: ara sıra/stilize" ve "suç teması" işaretlenir; yetişkin cinsel içerik yok. Sonuç büyük olasılıkla 12-16 bandı olur.
- **[O]** Ad: USPTO, EUIPO ve ulusal sicil (TÜRKPATENT) aranmalı. Ses benzerliği ve sınıf (yazılım/oyun, Nice 9 ve 41) önemli; ad ne kadar geç değişirse maliyet o kadar artar.
- **[G]** "Insiders" ad olarak riskli:
  - Genel bir kelime; "Insider Gaming" gibi bilinen markalar ve "Insider" adlı başka ürünler var.
  - Steam ve web aramasında ayırt edilmesi zor.
  - Kapsamlı arama yapılmadı. KR-013, Coming Soon sayfasından en az 2 ay önce kapanmalı. Kontrol listesi: Steam araması + 3 marka sicili + alan adı + sosyal hesaplar.

## 10. Projemize somut öneriler (faz/kalem önerisi)
| # | Ne | Ne zaman | Neden |
|---|---|---|---|
| Ö1 | **KR-014'ü öne çek:** Steamworks kaydı, vergi/banka, 100 $, AppID. Öneri kalemi: "IS-Steamworks kaydı" (sahip: kullanıcı; koordinatör kontrol listesi) | Faz 3 kapanışında, eğlence kapıları geçilince (en geç Faz 4 başı) | Vergi 10-15 iş günü + ilk oyun için anahtar beklemesi 3 hafta + yayın beklemesi 30 gün. Faz 5'te başlamak MVP'yi 4-6 hafta kaydırır. Kendi AppID'miz olmadan davet testi ve arkadaş anahtarı olmaz |
| Ö2 | **Ad ve marka (KR-013) kalemi:** aday ad listesi, Steam/USPTO/EUIPO/TÜRKPATENT araması, alan adı | Faz 4 içinde, AppID açılmadan | Mağaza ve uygulama adı, anahtarlar, topluluk; geç değişiklik pahalı |
| Ö3 | **Steam teslim hattı (altyapi):** Win+Linux depot, `playtest` şifreli branch, steamcmd yükleme betiği, `steam_appid.txt` export dışı, CI çıktısından yükleme | Faz 5 ilk kalem (Ö1 bittiyse) | Faz 5 kriteri "build 3 arkadaşta açılıyor" Steam üzerinden doğrulanır; güncelleme dağıtımı otomatikleşir |
| Ö4 | **Steam davet akışı (cekirdek):** lobi + `join_requested` + `+connect_lobby` + rich presence; SDR üzerinden SteamNetworkingSockets; ENet yedeği | Faz 2 spike'ı 480 ile, asıl iş Faz 5 | Faz 5 kriteri "davet ≤ 10 sn" ve "TR↔SE 30 dk"; SDR NAT ve IP sorununu çözer |
| Ö5 | **Deck/gamepad kuralları (arayuz, tema token'ları):** en küçük yazı ≥ 12 px @1280×800, tüm menüler gamepad ile gezilebilir, glyph'ler giriş aygıtına göre değişsin, metin girişi için Steam klavyesi | Şimdiden (Faz 2+ arayüz kalemlerinin DoD'sine) | Sonradan eklemek pahalı; Deck Verified ücretsiz görünürlük getirir |
| Ö6 | **AI içerik günlüğü:** `assetler.md`'de "AI ile üretildi" sütunu; oyundaki metinler için kaynak notu | Faz 4 (assetler.md açılırken) | Ocak 2026 kuralına göre doğru beyan; kod beyan dışı |
| Ö7 | **Herkese açık yayın yolu (MVP sonrası, ayrı epik):** Coming Soon (sanat yönü KR-017 ile sabitlenince) → co-op demo → Next Fest (Haz 2027 ya da Eki 2027) → EA | Faz 5 kapanışından sonra karar | Wishlist 6-12 ay ister; Next Fest bir kez kullanılır, erken harcanmamalı |
| Ö8 | **Fiyat taslağı:** 9,99-14,99 $; MENA-USD ve EUR için önerilen fiyat girilsin; çıkış indirimi %10-20; Friend's Pass teknik spike'ı ileride | Herkese açık yayından önce | Tür fiyat bandı; çoklu paket yok |

## 11. Açık sorular
- 30 günlük bekleme hâlâ geçerli mi? (steamdirect sayfasında var, releasing belgesinde yok) **[?]**
- Release State Override anahtarlarıyla, yayınlanmamış ve build incelemesinden geçmemiş bir uygulama oynanabiliyor mu? Belge açıkça söylemiyor, ilk anahtarda denenmeli. **[?]**
- GVK 20/B ya da genç girişimci istisnası Steam PC oyun gelirini kapsıyor mu? Mali müşavir sorusu. **[?]**
- Valve'in Türkiye için uyguladığı fiilî stopaj oranı (anlaşma tavanı %10) vergi mülakatı sonucuna bağlı. **[?]**
- Friend's Pass gibi ayrı AppID'li katılımcı uygulama, SteamMultiplayerPeer/GodotSteam ile nasıl kurulur? Teknik spike gerekir. **[?]**
- Kişisel takvim döneminde yeni wishlist eşikleri yayımlanmadı. **[?]**
- Valve'in ödeme eşiği ve ödeme takvimi bu araştırmada resmî belgeden doğrulanmadı. **[?]**

## 12. Kaynaklar
Resmî (Steamworks / Steam):
- https://partner.steamgames.com/steamdirect
- https://partner.steamgames.com/doc/gettingstarted/appfee
- https://partner.steamgames.com/doc/gettingstarted/onboarding
- https://partner.steamgames.com/doc/store/coming_soon
- https://partner.steamgames.com/doc/store/review_process
- https://partner.steamgames.com/doc/store/releasing
- https://partner.steamgames.com/doc/store/assets/standard
- https://partner.steamgames.com/doc/store/assets/rules
- https://partner.steamgames.com/doc/store/pricing
- https://partner.steamgames.com/doc/store/pricing/currencies
- https://partner.steamgames.com/doc/store/application/packages
- https://partner.steamgames.com/doc/store/application/bundles
- https://partner.steamgames.com/doc/store/application/demos
- https://partner.steamgames.com/doc/store/earlyaccess
- https://partner.steamgames.com/doc/marketing/wishlist
- https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest
- https://partner.steamgames.com/doc/marketing/upcoming_events
- https://partner.steamgames.com/doc/features/playtest
- https://partner.steamgames.com/doc/features/keys
- https://partner.steamgames.com/doc/features/remoteplay
- https://partner.steamgames.com/doc/features/multiplayer/steamdatagramrelay
- https://partner.steamgames.com/doc/steamdeck/compat
- https://partner.steamgames.com/doc/sdk/uploading
- https://partner.steamgames.com/doc/gettingstarted/contentsurvey
- https://partner.steamgames.com/doc/gettingstarted/contentsurvey/germany
- https://partner.steamgames.com/doc/gettingstarted/contentsurvey/indonesia
- https://store.steampowered.com/steam_refunds/
- https://help.steampowered.com/faqs/view/2720-4EC7-B95A-1D2A (LATAM/MENA USD geçişi)
- https://godotsteam.com/tutorials/exporting_shipping/

Sektör:
- https://howtomarketagame.com/2026/06/25/archive-how-many-wishlists-should-i-have-when-i-launch-my-game/
- https://howtomarketagame.com/2026/07/14/games-that-used-momentum-for-steam-next-fest-success/
- https://howtomarketagame.com/2026/07/30/is-friendslop-saturated/
- https://howtomarketagame.com/2026/06/30/nobody-plays-demos-and-that-is-ok/
- https://newsletter.gamediscover.co/p/does-steam-have-its-regional-pricing
- https://newsletter.gamediscover.co/p/how-peak-sold-45m-copies-in-less
- https://www.dexerto.com/gaming/steam-makes-major-change-to-ai-rules-for-games-3306274 (AI beyanı, Ocak 2026)
- https://insider-gaming.com/steams-new-personal-calendar-feature-helps-you-manage-your-games/
- https://gameworldobserver.com/2023/10/25/steam-turkey-argentina-usd-convert-regional-pricing-abandoned
- https://www.gamingonlinux.com/2024/10/from-november-15-all-steam-games-sold-in-germany-will-need-an-age-rating
- https://www.muhasebetr.com/yazarlarimiz/evrenozmen/0365/ (TR vergi, 07.10.2025)
- https://freemanlaw.com/international-tax-treaties/turkey/ (ABD-TR anlaşması)
- https://bugnet.io/blog/your-games-name-is-taken-now-what
