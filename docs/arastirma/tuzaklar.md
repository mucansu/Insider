# Tuzaklar ve riskler (araştırma, 2026-10-02)

Geliştirme dışı araştırma; bağlayıcı değildir, koordinatör ON/kalemlere çevirir. Kaynak önceliği: Steamworks/Godot resmî belgeleri > veri temelli bülten (GameDiscoverCo, howtomarketagame) > geliştirici yazıları/forumlar.
İşaretler: **[O]** = kaynakla doğrulanmış olgu · **[G]** = görüş/yorum (topluluk ortak dersi ya da bizim çıkarımımız). Olasılık/etki: D (düşük) · O (orta) · Y (yüksek).
Hukuk/vergi bölümleri **hukuki/mali tavsiye değildir; karar öncesi avukat ve mali müşavire danışın.**

## Özet
- En pahalı tuzak teknik değil, **ad**: "Insiders" adıyla Steam'de 2021'den beri yayında bir oyun var [O] → KR-013 bu adla kapanamaz; mağaza sayfasından ve herhangi bir paylaşımdan önce ad + marka taraması.
- Türün yapısal riski **"arkadaşın yoksa oynayamazsın"**: MVP'de bot yok, matchmaking yok. Yalnız arkadaş daveti; Steam demo/Next Fest ve iade penceresinde (2 saat) yalnız gelen oyuncu ürünü deneyemez [G]. R.E.P.O. ve OMD Deathtrap'te matchmaking yokluğu şikâyet/iade konusu oldu [O].
- Ağ tarafı iyi yönetiliyor (host yetkili, protokol sürümü, gecikme proxy'si, Steam relay planı). Açık kalan: **host düşerse ne olur** (GDD §16/8) ve Godot'da yerleşik host göçü yok [O].
- Godot yayın riskleri ucuz ama sinsi: imzasız .exe antivirüs yanlış pozitifi (Steam dışı dağıtımda, yani arkadaş testinde en çok), `.tres` kayıtlarında kod çalıştırma açığı, Deck metin boyu.
- Süreç riski: kapsam (10 kademe, 4 rol, ekonomi) tek kişi + AI ajanlarla çok büyük; "son %10" (Steam entegrasyonu, ayarlar, kayıt, yerelleştirme, mağaza materyali) planda görünmüyor [G].

## Risk tablosu (ilk 15, öncelik sırasıyla)
| # | Risk | O | E | Bizde durum | Önlem | Faz |
|---|---|---|---|---|---|---|
| 1 | Ad çakışması / marka ihtilafı | Y | Y | "Insiders" Steam'de var (app 1488860, 2021) [O]; KR-013 açık | Ad listesi → Steam/TÜRKPATENT/EUIPO/USPTO + alan adı taraması; sayfa öncesi kesinleştir | Faz 4 sonu (en geç Faz 5 başı) |
| 2 | Yalnız oyuncu oynayamıyor (bot/matchmaking yok) → iade, kötü yorum, ölü demo | Y | Y | GDD §15: MVP'de bot yok; MVP = yalnız arkadaşlar | MVP sonrası halka açık sürümden önce: bot yoldaş ya da tek kişilik eğitim/keşif dilimi + Steam lobi tarayıcısı; mağazada "co-op odaklı" açık beyan | Faz 5 sonrası (karar Faz 4'te) |
| 3 | Kapsam kayması / bitmeyen proje | Y | Y | GDD 10 kademe, 4 rol, perk, ekonomi; MVP 2 kademe | MVP kesimini kilitle; her faz çıkışında "keyif kapısı"; yeni özellik yalnız ON üzerinden | Her faz |
| 4 | Host düşünce oturum kaybı | O | Y | GDD §16/8 açık; Godot'da host göçü yok [O] | MVP: host düşerse iş biter + kampanya son "güvenli nokta"dan devam; göç ayrı kalem değil | Faz 2 (kopma davranışı) |
| 5 | Çok az wishlist ile çıkış / sayfa geç açma | Y | Y | Pazarlama henüz yok | Coming Soon sayfası çıkıştan ≥ 6-12 ay önce [G]; sayfa için ad + sanat yönü + 3 ortam görüntüsü şart [G] | Faz 5 sonrası |
| 6 | "Son %10": ayarlar, kayıt, Steam başarıları, hata raporu, yerelleştirme, mağaza materyali | Y | O | Backlog'da yok | MVP sonrası "Yayın hazırlığı" epiği; yayın kontrol listesi | Faz 5 + sonrası |
| 7 | Sanat yönü tutarsızlığı (kukla karakter + CC0 karışık paketler) | O | Y | KR-017 prosedürel kukla; KR-012 CC0 planı | Tek palet/çizgi kalınlığı kuralı; asset paketi azaltımı; stil rehberi sayfası | Faz 4 |
| 8 | Asset/font/müzik lisans hatası | O | Y | assetler.md Faz 4'te açılacak | Her dosya için kaynak URL + lisans + indirme tarihi; CC0 dışı (CC-BY) atıf ekranı; "CC0" etiketi tek başına güvenilmez | Faz 4 |
| 9 | Tek geliştiricinin tükenmesi | O | Y | Yoğun dönem; faz sonu beklemesi askıda | Faz sonu duraklarını geri getir; haftalık oyun testi ritmi; "oynamadan kod" süresine sınır | Her faz |
| 10 | AI üretimi kodun bakım riski (yinelenen kod, kimsenin anlamadığı sistemler) | O | O | Denetçi + sözleşmeler + 400 satır sınırı var | Faz sonu sadeleştirme/kopya taraması; kritik ağ kodunda kullanıcı okuma turu | Her faz |
| 11 | Windows antivirüs yanlış pozitifi (arkadaş build'i) | O | O | IS-005 build üretiyor, imza yok | Arkadaş testinde .zip + SHA; PCK ayrı dosya denemesi; Steam'den dağıtımda risk düşer [O] | Faz 1-5 |
| 12 | Steam AI içerik bildirimi yanlış/eksik | D | O | Kod Claude ile; oyuna giren içerik prosedürel | Kod asistanı muaf [O]; AI üretimi görsel/ses/metin girerse bildir; assetler.md'ye "AI: evet/hayır" sütunu | Faz 4-5 |
| 13 | Senkron/desync ve "beni görmemişti" | O | Y | S2, 150 ms testleri, host yetkili algı | Faz 2 çıkışındaki 20 dk tutarsızlık 0 ölçütü; replay | Faz 2 |
| 14 | GodotSteam sürüm uyumu / çift kayıt | O | O | IS-004: 4.22.1 yükleniyor; repo Codeberg'e taşındı [O] | Sürüm kilidi + SHA; Godot yükseltmesi ayrı IS | Faz 5 |
| 15 | Vergi/ödeme düzeni kurulmadan gelir | O | O | KR-014 bekliyor | Steamworks'ten önce mali müşavir görüşmesi; W-8BEN; ortaklık yazılı | Faz 5 öncesi |

## 1. Steam'de indie çıkış hataları
| Tuzak | Belirti | O/E | Bizde | Önlem | Faz |
|---|---|---|---|---|---|
| Coming Soon geç açma | Viral bir paylaşım sayfasız kalır; çıkışta wishlist yok | Y/Y | Sayfa yok (KR-014) | Ad + stil + 3 ortam hazır olunca aç; çıkıştan ≥ 6-12 ay önce [G] | Faz 5 sonrası |
| Coming Soon çok erken (hazır olmayan görsel) | Kötü kapsül/ekran görüntüsü, düşük dönüşüm, sonradan ad değişikliği | O/O | Yer tutucu görseller (KR-012) | Yer tutucuyla sayfa açma; önce kukla + ışık dilimi | Faz 4 |
| Az wishlistle çıkış | İlk hafta "Popular Upcoming"a girmez | Y/Y | — | Eşik Valve verisi değil: ~7 bin "yaygın kural" [G], Zukowski 2026 bantları 5k/8k/50k/90k [G]; çıkış tarihini wishlist'e göre kaydır | Yayın öncesi |
| Next Fest'i boşa harcama | Demo hazır değil / multiplayer demosu tek kişiyle oynanamıyor | O/Y | Bot yok | Her oyun **yalnız bir kez** katılabilir; sayfa yayında ve demo festival başında oynanabilir olmalı; çıkış festival bitiminden sonra [O]. Co-op demoya solo/eğitim yolu ya da açık lobi [G] | Yayın öncesi |
| 2 haftalık Coming Soon kuralını unutmak | Çıkış tarihi kayar | D/O | — | Sayfa ≥ 2 hafta Coming Soon olmadan çıkış yok; son 14 günde tarih değişikliği Valve'e sorulur [O] | Yayın |
| Yanlış etiket/tür | Yanlış kitle → düşük dönüşüm, kötü yorum | O/O | Tür: co-op gizlilik/soygun | Etiketlerde "Co-op", "Online Co-Op", "Heist", "Stealth", "Top-Down"; "Singleplayer" etiketi bot gelmeden **konmaz** [G] | Yayın öncesi |
| Fiyat | Çok düşük: "friendslop" algısı; çok yüksek: arkadaş grubunun 3 kopya alma eşiği | O/O | — | Co-op'ta grup maliyeti (3× fiyat) düşünülmeli; friendslop nişi genelde < 10 $ [O, Acer blog]; Türkiye Steam'de 2023'ten beri USD fiyatlı [O] | Yayın öncesi |
| İlk 10 yorum | 10 yorumun altında puan etiketi yok ("Need more user reviews") [O]; algoritmik görünürlüğe etkisi topluluk kanısı [G] | Y/O | — | Çıkış günü arkadaş/tester çevresi gerçek satın almayla oynasın; anahtar (key) ile gelen yorumlar puana sayılmaz [O] | Yayın |
| Düşük puan | %40 altı (Mostly Negative) öne çıkarılma şansını düşürür [O] | O/Y | — | İlk hafta yamaya hazır ol; bilinen sorunlar sayfası | Yayın |
| Yüksek iade oranı | 2 saat / 14 gün içinde sebepsiz iade [O]; medyan ~%8-10 [O, GameDiscoverCo] | O/O | İlk 2 saat bağlantı + öğrenme | İlk 15 dk'yı (bağlan, ilk soygun) parlat; bağlantı hatası iadenin bir numaralı nedeni olur [G] | Faz 5 + yayın |
| Çıkış günü hataları | Yanlış branch'i yayınlamak, depot eksik, bölge kilidi | D/Y | — | Yayın provası: beta branch'te 3 makinede temiz kurulum; Steamworks "release" kontrol listesi | Yayın |

## 2. Çok oyunculu / co-op'a özgü
| Tuzak | Belirti | O/E | Bizde | Önlem | Faz |
|---|---|---|---|---|---|
| NAT / bağlanamama | "Katıl"a basınca zaman aşımı; port açtırma ricası | Y/Y (ENet'te) | Faz 1-4 ENet + Tailscale | Faz 5'te Steam Networking: P2P trafiği gerektiğinde Valve omurgası üzerinden aktarılır, IP gizlenir [O]. ENet yedeği yalnız geliştirici/LAN için | Faz 5 |
| Host göçü yok | Host'un interneti gidince herkes menüye düşer, ilerleme kaybolur | O/Y | GDD §16/8 açık | Godot'da yerleşik göç yok, peer 1 sabit [O]. MVP: göç yapma; kopmada temiz bitiş + kampanya kaydı host'ta düzenli; istemci yeniden bağlanma (aynı slot) daha ucuz kazanç [G] | Faz 2 / Faz 4 |
| Desync / "beni görmemişti" | Ekranda görünen ile host kararı farklı | O/Y | S2, 32 px eşik, 150 ms testleri | Var olan disiplin sürsün; algı kararlarında istemciye görsel tolerans; replay ile kanıt | Faz 2 |
| Keşfedilebilirlik ("arkadaşın yoksa oynayamazsın") | Satın alan tek oyuncu iade eder; demo oynanmaz | Y/Y | MVP yalnız davet | Halka açık sürüm için bot yoldaş ya da açık lobi tarayıcısı **ve** Steam "Looking for group" yönlendirmesi; matchmaking yokluğu R.E.P.O.'da tepki çekti [O] | MVP sonrası, karar Faz 4 |
| Solo beklentisi | "Solo oynanır mı?" mağaza sorusu, olumsuz yorum | O/O | 2 kişi uyarlaması var, 1 kişi yok | Mağazada açık dil; bot gelene kadar "Singleplayer" etiketi yok [G] | Yayın öncesi |
| Sesli iletişim beklentisi | Discord'a bağımlılık; proximity chat yokluğu türde eksik sayılabilir | O/O | GDD'de ping + plan masası çizimi; ses yok | Gizlilik oyununda yakınlık sesi güçlü dram üretir (Lethal Company dersi) [G]; MVP'de Discord yeterli, ses ayrı karar (Steam ses API'si, gürültü sistemiyle bağlanabilir: konuşmak = gürültü) | Karar Faz 3, uygulama sonrası |
| Hile | Herkese açık lobide değiştirilmiş istemci | D/D (arkadaş) | S2: istemci konumunu host doğrulamaz | Arkadaş oyununda önemsiz; açık lobi gelirse host taraflı hız/mesafe kontrolü; lider tablosu (GDD sonrası) gelirse ciddi | Açık lobi kalemiyle |
| Ağ üzerinden nesne çözme | Kötü niyetli peer kod çalıştırır | D/Y | `var_to_bytes` + protokol sürümü | `bytes_to_var_with_objects` / `allow_object_decoding` asla kullanılmasın [G, Godot güvenlik ilkesi] | Her faz (denetçi maddesi) |
| Sürüm uyumsuzluğu | Arkadaş eski build'le katılır, garip hatalar | O/O | PROTOCOL_VERSION el sıkışması var [O, game.gd] | Reddedilince kullanıcıya okunur mesaj ("sürümler farklı: X/Y"); build kimliği menüde görünsün; Steam'de otomatik güncelleme yardımcı | Faz 1-5 |
| Gecikme TR↔SE | Hissedilen gecikme, kapıda/kasada çekişme | O/O | KR-002, host İsveç | Mevcut gecikme testleri; Faz 5'te SDR rotası gerçek ölçüm | Faz 5 |

## 3. Godot'a özgü yayın tuzakları
| Tuzak | Belirti | O/E | Bizde | Önlem | Faz |
|---|---|---|---|---|---|
| Antivirüs yanlış pozitifi | Defender/SmartScreen "bilinmeyen yayıncı" ya da trojan uyarısı | O/O | IS-005 imzasız build | Godot export'u signtool/osslsigncode ile imzalayabilir [O]; sertifika ücretli. PCK'nın exe'ye gömülmesi sezgisel taramayı tetikleyebilir [G, topluluk]; Steam'den dağıtılan oyunlarda sorun nadir [G]. Arkadaş testinde ayrı .pck + SHA notu | Faz 1 (deneme), Faz 5 |
| Export şablonu uyumu | Şablon sürümü editörle farklı → açılmayan build | D/O | IS-005: 4.7.2 + SHA doğrulamalı | Sürüm kilidi korunur; yükseltme ayrı IS | Faz 1 |
| Renderer seçimi | Eski GPU/dizüstünde açılmama, Deck'te performans | O/O | IS-005'te Forward+/Compatibility kararı bekliyor | 2D oyun için Compatibility en geniş donanım; ışık/gölge görünümü iki renderer'da farklı olabilir → seçim erken ve tek | Faz 1 kararı |
| 2D ışık/gölge maliyeti | Noir ışık sahneleri zayıf makinede FPS düşüşü | O/O | Noir ton, görüş/sis Faz 2 | Işık boyutu büyüdükçe maliyet artar [O, Godot belgesi]; gölgeli ışık sayısına bütçe; görüş sisini ışıkla değil maske/shader ile çöz; en zayıf arkadaş PC'sinde ölçüm | Faz 2-4 |
| Steam Deck / Proton | Gamepad'in yerel Linux build'de çalışmaması; Deck doğrulamasında metin küçük | O/O | Gamepad S5'te var; 1280×720 | Deck: metin 1280×800'de en az 9 px (önerilen 12 px), tüm işlevler varsayılan gamepad şemasıyla [O]. Linux yerel build yoksa Valve Windows build'ini Proton'la test eder; yerel build sorunluysa o seçilir [O] → yerel Linux'u ancak Deck'te test edilmişse yayınla | Faz 5 |
| GodotSteam sürüm uyumu | Godot yükseltince eklenti yüklenmez; ayrı SMP eklentisiyle çift kayıt | O/O | IS-004: 4.22.1 (SDK 1.65) çalışıyor; ayrı SMP yok | Godot + GodotSteam + SDK üçlüsü birlikte kilitlenir; depo GitHub'dan Codeberg'e taşındı [O] → indirme adresi güncellensin | Faz 5 |
| Kayıt dosyasında kod çalıştırma | Paylaşılan `.tres` kayıt/profil zararlı GDScript taşır | O/Y | Faz 4 "kampanya + profil kaydı" | `.tres/.res` ile kullanıcı verisi saklama: Resource yüklemek gömülü betik çalıştırabilir [O]. JSON ya da `store_var` (nesnesiz) + şema sürümü | Faz 4 |
| Kayıt uyumluluğu | Güncelleme sonrası eski kayıt açılmaz | O/O | Kayıt Faz 4 | Kayıtta `schema_version` + göç fonksiyonları + test fikstürü; Steam Cloud yolu baştan `user://` | Faz 4 |

## 4. Hukuk ve iş (hukuki/mali tavsiye değildir; uzmana danışın)
| Tuzak | Belirti | O/E | Bizde | Önlem | Faz |
|---|---|---|---|---|---|
| Ad/marka çakışması | İtiraz, zorunlu ad değişikliği (DieselStormers → Roguestormers örneği [O]) | Y/Y | "Insiders" Steam'de mevcut [O]; "Insider Trading" adlı başka oyun da var [O] | Aday adlar: Steam araması + TÜRKPATENT + EUIPO (TMview) + USPTO, sınıf 9/41; alan adı ve sosyal hesap kontrolü; ad değişikliği maliyeti wishlist biriktikçe artar [G] | Faz 4 sonu |
| CC0 doğrulama | Yeniden yüklenmiş "CC0" asset aslında başkasının | O/Y | KR-012 Kenney planı | Asset'i yalnız özgün kaynaktan indir (Kenney sitesi CC0 [O]); OpenGameArt'ta lisans asset başına değişir [O]; kaynak sayfa arşivi | Faz 4 |
| Font lisansı | Ticari kullanım ya da gömme yasağı | O/O | Tema token'ları, font seçimi yok | SIL OFL ya da CC0 fontlar; lisans dosyası build'e | Faz 4 |
| Müzik/ses | Yayıncı videolarına Content ID talebi → yayıncılar oyunu bırakır | O/O | Temel SFX Faz 2 | CC0 ses/müzik; Content ID'ye kayıtlı "telifsiz" kütüphanelerden kaçın [G]; co-op türünde yayıncı görünürlüğü kritik [G] | Faz 2-4 |
| Steam AI içerik bildirimi | Yanlış beyan → inceleme gecikmesi/itibar | D/O | Kod Claude Code ile | İçerik anketi: oyuna giren (önceden üretilmiş) ve oyun içinde canlı üretilen AI içeriği bildirilir; geliştirme verimliliği araçları odak değil [O]; Ocak 2026 güncellemesinde kod asistanlarının açıkça muaf tutulduğu bildiriliyor [O, ikincil] | Faz 5 |
| Gizlilik (KVKK/GDPR) | İzinsiz telemetri, IP kaydı | D/O (telemetri yoksa) | Telemetri planı yok | Telemetri eklenirse: varsayılan kapalı/opt-in, anonim kimlik, gizlilik politikası; IP ve kalıcı kimlik kişisel veridir [G, kaynak yorumu]. Steam ID kişisel veri sayılır | Telemetri kalemiyle |
| Yaş derecelendirme | Mağaza bazı bölgelerde görünmez | D/O | Soygun, minimal şiddet | Steam içerik anketi bölgesel derecelendirmeleri üretir [O]; şiddet/kumar/suç temasını dürüst işaretle | Faz 5 |
| Türkiye'de gelir/vergi | Gelir gelince beyan, KDV, döviz soruları | O/O | Bireysel geliştirici | Genel çerçeve: TR mukimi gelirini TR'de beyan eder; şahıs şirketi ya da (birden çok kişi varsa) adi ortaklık yaygın [G, muhasebetr 2025]; yurt dışına yazılım/hizmet kazancında koşullu indirim/istisna görüşleri var [G]; 20/B istisnası "mobil uygulama" için yazılmıştır, PC/Steam kapsamı belirsiz [G] → mali müşavire sor | KR-014 öncesi |
| ABD stopajı | Valve ödemelerinden %30 kesinti | O/O | — | Steamworks vergi görüşmesinde W-8BEN (şirketse W-8BEN-E) + TR vergi no; TR-ABD anlaşmasıyla oran düşer (kaynakta %10) [G, muhasebetr]; Valve standart oran %30 [O] | KR-014 |
| Steam Direct ücreti | — | D/D | KR-014 | 100 $, oyun 1.000 $ brüt geliri geçince geri ödenir [O] | Faz 5 |
| İsveçli arkadaşların katkısı | Sonradan pay/telif iddiası, ödeme dağıtım sorunu | O/Y (katkı varsa) | Şimdilik oyuncu/test | Katkı yalnız geri bildirimse sorun yok; tasarım/sanat/ses/para katkısı başlarsa **yazılı** anlaşma: fikrî hak devri ya da lisans, gelir payı oranı ve süresi, ayrılma hali. Steam ödemesi tek hesaba gider [O]; sınır ötesi pay her ülkede ayrı vergilendirilir [G] | Katkı başlamadan |

## 5. Kapsam ve süreç tuzakları
| Tuzak | Belirti | O/E | Bizde | Önlem | Faz |
|---|---|---|---|---|---|
| Kapsam kayması | Her fazda yeni sistem; MVP tarihi uzar | Y/Y | GDD geniş; KR-016 öneri akışı açık | ON'lar yalnız faz planında kabul; MVP listesi (GDD §15) değişirse KR kaydı; "kes" listesi tut | Her faz |
| "Son %10" | Oyun "bitmiş" ama yayınlanamaz | Y/O | Ayarlar, kayıt UI'si, başarılar, kontrol yeniden atama, hata raporu, yerelleştirme, kapsül/fragman backlog'da yok | "Yayın hazırlığı" epiği; Faz 5 çıkışına "temiz kurulumdan ilk soyguna < 10 dk" | Faz 5 |
| İçerik üretim darboğazı | Kademe başına şablon/modül/muhafız davranışı elle; içerik yetişmez | Y/O | GDD: AI ajan varyant üretir + doğrulayıcı | Doğrulayıcı önce, üretici sonra; kademe başına içerik bütçesi; MVP'de 2 kademe | Faz 3-4 |
| Sanat yönü tutarsızlığı | Kukla karakterler + farklı CC0 paketleri + yer tutucu karışımı | O/Y | KR-017 | Tek palet (tema token'ları), tek çizgi/gölge kuralı; tek asset ailesi; dikey dilim görseli Faz 4'te onaylanır | Faz 4 |
| AI kodunun bakım riski | Yinelenen kod, ani kayma, "kimse bilmiyor" | O/O | Denetçi, S1-S11, 400 satır, kapsülleme testleri | GitClear 2025: AI döneminde yinelenen blok ve "churn" arttı, yeniden düzenleme azaldı [O]. Faz sonu kopya/ölü kod taraması; mimari.md güncel tutma; kritik modüllerde insan okuma | Her faz |
| Tek kişinin tükenmesi | Oynamadan haftalar; motivasyon düşüşü | O/Y | Yoğun dönem, beklemeler askıda | Haftada en az bir arkadaş oturumu; faz sonu durma noktasını yoğun dönem bitince geri al; "eğlenceli mi" kapısı geçmezse dönüş, devam değil | Her faz |
| Erken optimizasyon / altyapı fazlalığı | Test/CI düzeneği oyundan hızlı büyür | O/O | Güçlü test altyapısı | Faz 2 sonuna kadar oyun hissine öncelik; yeni araç kalemleri gerekçeli | Faz 2 |

## Kalem / karar önerileri (koordinatöre)
- KR-013'ü güncelle: "Insiders" kalıcı ad olamaz (Steam'de mevcut); ad aday listesi + tarama kalemi (Faz 4 sonu, sayfa öncesi).
- GDD §16/8 kararı Faz 2 "kopma davranışı" kalemine: MVP'de host göçü yok; host kopunca temiz bitiş + istemcinin aynı slotla yeniden bağlanması değerlendirilir.
- Halka açık sürüm koşulu olarak "solo/bot ya da açık lobi" kararı (Faz 4 plan mesajında sorulsun); mağaza etiketleri buna göre.
- Faz 4 kayıt kalemine kabul maddesi: kayıt `.tres` değil (JSON/`store_var`, nesnesiz) + `schema_version` + göç testi.
- denetci kontrol listesine: ağda nesne çözme (`allow_object_decoding`, `bytes_to_var_with_objects`) yasak.
- IS-005'e not: renderer kararı (Compatibility öneri) + arkadaş build'inde antivirüs uyarısına README notu; imza Faz 5'te değerlendirilir.
- assetler.md şablonuna sütunlar: kaynak URL, lisans, indirme tarihi, atıf gerekir mi, AI üretimi mi.
- MVP sonrası "Yayın hazırlığı" epiği (ayarlar, başarılar, Deck metin boyu, kayıt UI'si, kapsül/fragman, yayın provası).
- Yakınlık sesli sohbeti tasarım sorusu olarak Fable'a (gürültü sistemiyle bağ).

## Kaynaklar
- Steamworks, Coming Soon: https://partner.steamgames.com/doc/store/coming_soon
- Steamworks, çıkış tarihi: https://partner.steamgames.com/doc/store/release_dates
- Steamworks, Next Fest: https://partner.steamgames.com/doc/marketing/upcoming_events/nextfest
- Steamworks, kullanıcı yorumları: https://partner.steamgames.com/doc/store/reviews
- Steamworks, içerik anketi (AI, derecelendirme): https://partner.steamgames.com/doc/gettingstarted/contentsurvey
- Steamworks, ağ/SDR: https://partner.steamgames.com/doc/features/multiplayer/networking
- Steamworks, Steam Deck uyumluluk: https://partner.steamgames.com/doc/steamdeck/compat
- Steamworks, vergi SSS: https://partner.steamgames.com/doc/finance/taxfaq
- Steam Direct: https://partner.steamgames.com/steamdirect
- Steam iade politikası: https://store.steampowered.com/steam_refunds/
- Steam "Insiders" (2021): https://store.steampowered.com/app/1488860/
- Godot, Windows export (imzalama): https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
- Godot, 2D ışık ve gölge: https://docs.godotengine.org/en/4.7/tutorials/2d/2d_lights_and_shadows.html
- GDQuest, Godot 4 kayıt (Resource güvenliği): https://gdquest.com/library/save_game_godot4
- Godot Safe Resource Loader: https://github.com/derkork/godot-safe-resource-loader
- Godot forumu, antivirüs: https://forum.godotengine.org/t/viruses-in-my-game/126589
- itch.io, Godot kod imzalama: https://itch.io/blog/744096/code-signing-your-games-mainly-godot
- Godot forumu, host göçü: https://godotforums.org/d/41338-godot-host-migration-help
- GodotSteam (Codeberg'e taşındı notu): https://github.com/GodotSteam/GodotSteam
- GamingOnLinux, Deck testinde yerel Linux/Proton: https://www.gamingonlinux.com/2022/02/valve-clarifies-how-they-test-native-linux-or-proton-for-steam-deck/page=1/
- GameDiscoverCo, iade oranları: https://newsletter.gamediscover.co/p/steam-refunds-how-many-should-you
- howtomarketagame, Coming Soon zamanlaması: https://howtomarketagame.com/2025/03/10/when-should-i-post-my-steam-coming-soon-page/
- Wishlist eşikleri (ikincil): https://www.steampageanalyzer.com/blog/how-many-wishlists-before-launch
- 10 yorum eşiği: https://automaton-media.com/en/news/steam-developers-need-your-review-more-than-you-think-even-if-its-literally-just-one-word/
- R.E.P.O. matchmaking: https://esports.gg/news/repo/r-e-p-o-continues-to-grow-but-it-has-one-major-flaw-matchmaking/
- OMD Deathtrap matchmaking tartışması: https://steamcommunity.com/app/2273980/discussions/0/599642934595360126
- Friendslop: https://blog.acer.com/en/discussion/3477/what-are-friendslop-games
- Steam AI bildirimi 2026 (ikincil): https://tech-insider.org/steam-ai-disclosure-2026
- Ad/marka dersleri: https://www.gamedeveloper.com/business/5-minute-legal-lessons-for-indie-devs-part-2-game-names-and-trade-mark-troubles
- DieselStormers: https://www.techdirt.com/tag/diesel/
- Kenney CC0 / OpenGameArt: https://opengameart.org/content/kenney-fonts
- GDPR ve hata raporu: https://bugnet.io/blog/crash-reporting-gdpr-indie-games
- Steam oyun geliştirici vergilendirmesi (TR, 2025): https://www.muhasebetr.com/yazarlarimiz/evrenozmen/0365/
- GVK 20/B istisnası: https://tr.andersen.com/tr/images/pdf/2022-15-sosyal-icerık-kazanc%20istısnası.pdf
- Steam Türkiye USD fiyatı: https://www.haberturk.com/steam-turkiye-den-cekiliyor-mu-oyunculara-kotu-haber-steam-dolar-kuruna-geciyor-3632207-ekonomi
- GitClear 2025 AI kod kalitesi: https://devclass.com/2025/02/20/ai-is-eroding-code-quality-states-new-in-depth-report/
- Lethal Company yakınlık sesi: https://sg.news.yahoo.com/lethal-company-2023s-best-indie-151953794.html
