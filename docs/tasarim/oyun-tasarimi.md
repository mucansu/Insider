# Insiders — Oyun Tasarım Belgesi (GDD)

Durum: v0.3 taslak, MVP öncesi (IS-021, 2026-10-02: KR-020 senaryo bazlı tehdit modeli — §9.1 kademe tablosu, §9.2 mekân nüfusu, §9.3 bakkal tasarımı; §6.1 sivil gözlemci çarpanları; §15 MVP metni. Önceki: IS-007 A — §14.1 kukla stili KR-017, §7.6 alternatif giriş GB-02). Bu dosya projenin tek tasarım kaynağıdır; tasarım kararı değişirse önce burası güncellenir.
Teknik mimari (sınıf/dosya yapısı) ayrı belgede; burada yalnız tasarımı etkileyen teknik kurallar var.

## 1. Konumlandırma

Insiders, Steam'de arkadaş davetiyle oynanan, üç kişilik ekibin önce hedefi gözlemlediği, sonra sığınaktaki masada kroki üzerinde birlikte plan yaptığı, sonra planın kaçınılmaz olarak bozulduğu gerçek zamanlı, üstten bakışlı co-op soygun oyunudur. Kalıcı karakter ekipmanla tanımlanan bir build'e dönüşür; işler köşe bakkalından merkez bankasına uzanan bir merdivende her kademede yeni bir güvenlik mekaniği öğretir; her işte içeriden bilgi satan, güvenilmez olabilen bir "insider" vardır.

Rakiplerden farkı:
- Payday 2/3: birinci şahıs, gizlilik ikili (tek hata = tam gürültülü), gürültülü yol asıl fantezi, plan fazı yok. Bizde keşif ve plan oyunun yarısı, gizlilik kademeli, gürültü mümkün ama pahalı, ağ P2P host'lu ve hesapsız.
- Monaco / Monaco 2: arcade, sınıf başına tek yetenek, kalıcı ekonomi yok, plan "haritaya bakmak"tan ibaret; Monaco 2 (2025) prosedürel seviyeler ve 4 kişilik online getirdi. Bizim ayırt edici sütunlarımız: hafızaya dayalı keşif, ortak plan masası, para/ısı/insider ekonomisi, öğreten güvenlik merdiveni. "Rastgele soygun" tek başına ayırt edici değildir.

Hedef kitle: 25-45 yaş, arkadaş grubuyla düzenli oynayan, Overcooked/Dungeon Defenders tarzı "birlikte kaos" seven, Payday'in shooter ağırlığından yorulmuş oyuncular. Oturum: 45-90 dk (2-4 iş).

## 2. Tasarım ilkeleri

1. Bilgi oyuncunun kafasındadır. Keşifte görülen hiçbir şey otomatik işlenmez; ekip hatırlar, aktarır, yanlış hatırlar.
2. Kur → yaşa ritmi. Keşif ve plan sakin, soygun kaotik. Plan mekanik olarak bağlayıcıdır, süs değildir.
3. Kaos eşzamanlı taleplerden doğar, rastgele cezadan değil. Her kademede üç talep akışı: erişim, gözlem, lojistik.
4. Gizlilik kademelidir. Unutulan bir kamera oyunu bitirmez; şüphe birikir, doğaçlama anı yaratır.
5. Gürültü bir para birimidir. Gürültülü yol her zaman mümkündür ama en iyi ganimeti kilitler, aracıyı küstürür, ısıyı yükseltir.
6. Ekipman yaklaşım açar, istatistik şişirmez. Üst kademe daha çok can değil, daha çok sistem demektir.
7. Roller dayatılmaz, çantadan ve mekândan doğar. Üç kişi birbirine muhtaçtır: çift anahtar anları ve üçüncü el anları.
8. Başarısızlık görünür ve komiktir. Kuru mizah dünyadan değil planın çözülmesinden gelir.
9. Gecikme oyuncu lehine çözülür. Şüpheli durumda oyuncu haklıdır.
10. Oyun mantığı görselden ayrıdır. 2D ile başlıyoruz; mantık 3D'ye taşınabilir kalır.

## 3. Çekirdek döngü

keşif → plan → soygun → kaçış → para/ısı → ekipman → daha büyük iş

1. Sığınak / iş panosu. Kademe, şablon, risk seviyesi (1-5), modifikatörler; insider teklifi; istihbarat satın alma (keşfin kısmi ikamesi).
2. Keşif (isteğe bağlı ama pahalı atlanır). Üç paralel rol, sınırlı süre, davranışsal risk. Çıktı: oyuncuların hafızası ve en fazla birkaç fotoğraf.
3. Plan masası. Kroki üzerinde ikon, rota, rol, giriş, gadget ön yerleşimi, insider anlaşması.
4. Soygun. Varsayılan gizlilik; kademeli uyarı; plan katmanı ekranda.
5. Kaçış. Ganimetle kaçış noktası; gürültülüyse baskı altında çıkış; geride kalan yakalanır (kefalet).
6. Ödeme ve ısı. Ganimet × aracı oranı; ısı değişimi; itibar.
7. Ekipman ve perk. Parayla ekipman, XP ile perk; sonraki kademe itibar + sermaye ile açılır.

Bir iş döngüsü hedef süreleri: keşif 4-8 dk, plan 2-4 dk, soygun 3-25 dk (kademeye göre), sığınak 2-3 dk.

## 4. Keşif fazı

Amaç: ekibin hedef hakkında bilgi toplaması; bilgi oyun tarafından değil oyuncu tarafından taşınır.

### 4.1 Üç paralel rol (kimse boş beklemez)
- İçerideki (müşteri): hedefe sıradan müşteri olarak girer. Gerçek bir "işi" vardır (sıraya gir, form doldur, para boz); iş, oyalanmanın meşru gerekçesidir ve bitince kalma süresi şüphe üretir. Görüş hattındakini görür: kamera, muhafız, kapı, kasa, kart taşıyan personel, personel alanı kapıları.
- Dışarıdaki (minibüs/sokak): arka kapı, kurye/para transferi saatleri, vardiya değişimi, çatı erişimi, polis devriyesi periyodu (T2+; T1'de yoldan geçen yoğunluğu ve sahibin ajandası, §9.3). Dürbün kullanır. Araç uzun süre park ederse park görevlisi/polis şüphesi.
- Hat (telefon/ağ, MVP sonrası): sosyal mühendislik mini diyalogları; personel adı, vardiya listesi, alarm firması, bakım randevusu (kılık için), insider bulma. Yanlış soru şüphe ve ısı üretir.

### 4.2 Hafıza kuralı
- Keşifte görülen hiçbir şey krokiye, haritaya ya da listeye otomatik işlenmez. Plan masasında oyuncular hafızadan ikon yerleştirir.
- Ekran görüntüsü ya da kâğıt-kalem engellenmez ve engellenmeye çalışılmaz. Değerli bilgi zamansal ve davranışsaldır: devriye periyodu, kamera dönüş süresi, kurye saati, kimin kart taşıdığı, hangi kapının içeriden açıldığı. Statik yerleşim tek başına yetmez.
- Fotoğraf (telefon): iş başına sınırlı kare (3), çekim anı fark edilebilir; fotoğraf plan masasında kroki kenarında küçük görüntü olarak durur, ikon üretmez.

### 4.3 Keşfin bedeli
- Oyalanma şüphesi: işi bittiği halde içeride kalma, aynı noktada durma.
- Bakış şüphesi: kameraya ya da muhafıza uzun "inceleme" (inceleme bir eylemdir: tut; süre uzadıkça şüphe).
- Personel alanına yaklaşma; "yalnızca personel" kapısını deneme.
- Tanınma: aynı yüz ikinci ziyarette tanınma sayacı başlar; kılık sayacı sıfırlar ama kılık yakından bakışta şüphe doldurur. Tanınan yüz soygunda daha hızlı tespit edilir.
- Keşif sırasında doluşan şüphe soygunun başlangıç ısısına küçük pay ekler; keşifte yakalanmak işi iptal etmez, hedefi "tetikte" moduna sokar (ek muhafız, kısa süreli).

### 4.4 Keşif ekipmanları
- Telefon (sınırlı fotoğraf), dürbün (dışarıdaki), kılıklar (kurye/temizlikçi/tamirci: personel alanına kısa erişim), kart kopyalayıcı (kart taşıyanın yanında birkaç saniye), bırakılabilir mini kamera (soygunda o noktayı Tech'e gösterir; bulunursa hedef tetikte), kamera dedektörü (ileri kademe; gizli kamerayı 2-3 m içinde titreşimle bildirir).

### 4.5 Görünmeyen önlemler
Alt kademelerde her şey görünür; yukarıda görünmeyenler artar ve keşif değeri yükselir. Merdiven: sahte kamera (T2), gizli kamera (T5; dedektör ya da mercek parıltısı ile), sivil polis (T5), basınç plakası (T6), kızılötesi lazer (T6 görünür/T9 görünmez), GPS'li para çantası (T8), ağ tuzağı/sessiz tel (T9), dönen kodlar (T10). Dağılım tablosu 9. bölümde.

### 4.6 Keşif ile soygun arası değişim
Keşif ile soygun arasında kademeyle artan olasılıkla (T1 %5 → T10 %30) bir değişiklik olur: vardiya değişimi, yeni kamera, tadilat, kapatılan kapı. "Taze keşif" (aynı oturumda soygun) olasılığı yarıya indirir. Insider krokisi eski olabilir (tarihli).

### 4.7 Keşfi atlamak
İstihbarat satın alınabilir (para): 0 = yalnız duvarlar, 1 = sabit güvenlik ikonları (doğruluk %70-90), 2 = devriye rotaları (zamanlama yok). Satın alınan bilgi de ikon olarak "iddia"dır; yanlış olabilir. Bakkal gibi alt kademelerde camdan bakmak yeter; T4+ keşifsiz soygun belirgin biçimde pahalıdır.

## 5. Plan masası

- Mekân: sığınaktaki masa; üzerinde hedefin krokisi. Duvarlar, kapı boşlukları ve kat planı hazır gelir (belediye planı ya da insider). Güvenlik öğeleri yoktur; oyuncular ikon paletinden hafızadan yerleştirir: kamera (sabit/dönen), muhafız, devriye rotası, kart taşıyan, kasa/kasa dairesi, alarm paneli, DVR, sensör, sivil yoğunluğu, zaman notu ("kurye 03:10").
- Herkes aynı anda çizer: rota çizgileri, ping, serbest not. Geri alma var. Üç oyuncunun çizimi renkle ayrışır.
- Kararlar: giriş noktaları (oyuncu başına ayrı olabilir), rol ataması (kim kilit, kim kamera, kim çanta), gadget ön yerleşimi (yalnız dışarıdan erişilebilir noktalar: dış kamera jammer'ı, kaçış aracı), insider anlaşması (ücret, ne zaman), kaçış rotası.
- Tetik zinciri (MVP sonrası): "A gerçekleşince B" türünden basit koşullar; plan katmanında geri sayım olarak görünür.
- Plan katmanı: soygun sırasında planlanan ikonlar ve rotalar yarı saydam katman olarak görünür. Gerçek nesneyle çakışmazsa oyun uyarı vermez; farkı oyuncu fark eder. İkonlar "iddia"dır.
- Plan bonusu: plan adımları (kontrol listesi) tutturulursa aracı oranı +%5-10. Plansız girmek mümkündür; bonus yoktur, plan katmanı boştur.
- Süre: zamansız. Host "masayı kapatır"; herkes hazır işaretleyince soygun başlar.

## 6. Gizlilik ve uyarı sistemi

### 6.1 Algı
- Görüş: her muhafız/sivil/kamera için görüş hattı (duvar keser) × ışık (karanlık bölge menzili kısar) × mesafe × hedefin durumu (koşma, çanta taşıma, silah elde, kılık). Oyuncu da yalnız görüş hattındakini görür; görülmeyen alan sisli (Monaco kuralı; ekip görüşleri paylaşılır).
- Hareket kipleri (Faz 1'de kesinleşti, `data/player_tuning.tres`): sızma 70, yürüme 140, koşma 220 px/sn; 1 karo = 32 px, karakter çapı ~24 px. Kip, algıdaki "hedefin durumu" çarpanının ve gürültü yarıçapının girdisidir.
- Duyma: gürültü olayları yarıçapla yayılır; duvar azaltır, yağmur maskeler. Koşma, kırma, ateş, matkap, düşen nesne.
- Şüphe ölçeri: her gözlemcinin her oyuncuya karşı 0-100 ölçeri; görünürlük × süre ile dolar, görünmeyince boşalır. Eşikler: 30 "?" (gözlemci bakar, ≥0,5 sn tepki penceresi), 60 inceleme (yürüyerek gelir, sorgular), 100 tespit.
- Tespit sonucu gözlemciye bağlı: muhafız telsizle bildirir (bölgesel arama → sessiz alarm sayacı), sivil panikler ya da düğmeye basar, kamera operatörlüyse muhafız yönlendirir, operatörsüzse yalnız kayıt (DVR silinmezse ısı).

### 6.2 Küresel uyarı kademeleri
0 Sakin → 1 Şüphe (yerel, zamanla söner) → 2 Arama (bölgesel; muhafızlar rotadan çıkar, kapılar kontrol edilir; 60-90 sn sonra söner) → 3 Sessiz alarm (polis gelişi için T sn sayaç; ECM uzatır; geri dönmez) → 4 Yüksek alarm (kepenk, saat kilidi, boya paketi, müdahale dalgaları) → 5 Kilitleme (yalnız kaçış).
Kademe 1-2 geri döner; 3+ dönmez. Bayıltılan muhafız bulunursa 2, telsiz yoklaması cevapsız kalırsa 2 → 3.

### 6.3 Gürültü ve ganimet kuralı
- Temiz iş (alarm yok) ana ganimet + aracı %85-90.
- Sessiz alarm: ana ganimet hâlâ alınabilir, süre baskısı; aracı %70.
- Yüksek alarm: T5+'ta ana ganimet kilitlenir (saat kilidi/kepenk/boya), yalnız "kapılabilir" ganimet; aracı %45; ısı sıçrar.
- Ölü/yaralı başına ek ısı; "kimseye zarar vermeden" bonusu.

### 6.4 Çatışma (ilk sürüm: minimal)
Gizlilik varsayılan. Gürültü = baskı altında kaçış ve 30-60 saniyelik koridor tutma anları. Silahlar gürültü yarıçapı + ölümcüllük + ağırlıkla tanımlıdır; muhafız her silahla düşer, kısıt sayı ve sonuçtur. Can/hasar/silah veri güdümlü; muhafız davranışı genişletilebilir. Büyüyen çatışma ileride belirli kademelere (T7 transfer) ya da ayrı "gürültülü iş" türüne gider; plan fazını zayıflatmasına izin verilmez.

## 7. Karakter, roller, perk, ekipman

### 7.1 Model: hibrit
Sert sınıf yok. Rolü getirilen ekipman belirler, küçük perk ağacı keskinleştirir (etkiler %10-25 bandında; yetenek kazandıran düğüm az). Kimse "hacker olmak zorunda" değil; kimse her şeyi taşıyamaz (slot ve ağırlık).

### 7.2 Üç talep akışı ve roller
- Ghost (eller): kilit, sessiz bayıltma, ceset saklama, lazer/plaka geçişi, kırılgan taşıma. Ekipman: maymuncuk kademeleri, cam kesici, bayıltıcı, kanca, sessiz ayakkabı.
- Tech (gözler): kamera döngüsü, DVR silme, alarm paneli, kapı/kepenk, matkap bakıcılığı; güvenli yerden tablet arayüzüyle kamera akışı görür, telsizle yönlendirir (bilgi asimetrisi). Ekipman: hack deck kademeleri, jammer, ECM, keşif dronu, kart klonlayıcı.
- Muscle (sırt): çift çanta, rehine yönetimi, kapı kırma, matkap/lans taşıma, gürültüde koridor tutma. Ekipman: zırh yeleği, levye, pompalı/karabina, duman, kapı takozu.
- T3+'ta her işte en az bir çift anahtar anı (iki kişi iki ayrı yerde, pencere ≥0,5-1 sn) ve bir üçüncü el anı (biri taşır/gözetler/rehineyi tutarken diğer ikisi çalışır).

### 7.3 Perk ağacı (3 dal × 6 düğüm, seviye 30, ~18 puan)
- Ghost: sessiz adım → hızlı kilit → çift bayıltma → gölge (karanlıkta görünürlük -%40) → kanca ustası → hayalet (kamera 1 sn gecikmeli görür).
- Tech: hızlı hack → döngü süresi +%50 → uzaktan kapı → ikinci kamera akışı → matkap soğutma → sıfır iz (DVR otomatik).
- Muscle: çanta +1 → hızlı taşıma → sindirme menzili → zırh → sarsmaz → tank (koridor tutma).
Uçlarda imza yetenek, ortada sayısal. Tek dalda ustalaşma + ikinci dala giriş mümkün; üç dal birden değil.

### 7.4 Ekipman slotları ve kategorileri
Birincil silah, ikincil silah, Alet A, Alet B, Gadget ×2 (sarf), Kıyafet, Kanca/İmza.
- Silahlar: susturuculu tabanca, uyuşturucu tüfek, taser, cop, SMG, pompalı, karabina.
- Aletler kademeli yetenek verir: T1 maymuncuk T1 kilidi 6 sn'de açar; T3 kilit T3 maymuncuk ya da matkap (gürültülü) ya da insider anahtarı ister. İleri kademe giriş aletleri (§7.6): ızgara sökücü (T4+), kat delici (T9+).
- Gadget: jammer, ECM, duman, flaş, ses yemi, hareket sensörü, ceset torbası, kapı takozu, kanca ipi, mini kamera; şekilli patlayıcı (T6+, §7.6).
- Kıyafet: sneak (sessiz, zırhsız), zırh (yavaş, gürültülü adım, havalandırmaya sığmaz), üniforma (yakın bakışta şüphe).

### 7.5 Kalıcılık ve katılım
Karakter (seviye, perk, ekipman, cüzdan) oyuncuda. Ekip kampanyası (ısı, itibar, kasa, açık kademeler, aracı/insider listesi) host'ta. Yeni karakterle katılan arkadaş kademeye uygun ödünç set alır. Oyuncu düşerse avatarı bot olur (takip/bekle/taşı); bot aynı zamanda solo ve 2 kişilik oyunun temelidir (MVP sonrası).

### 7.6 Alternatif giriş ve kasa erişimi (GB-02; MVP sonrası, kademe + ekipman kapılı)
İlke: her yöntem gürültü para birimiyle (§2.5) yapılan bir alışveriştir; alt kademelerde yoktur, keşifte fark edilir, hazırlığı çift anahtar/üçüncü el anı üretir; ekipman yaklaşım açar, istatistik şişirmez (§2.6). Teknik kapı mimari.md §7 (karo türleri: kanal, zayıf duvar, kat geçişi).

| Yöntem | Açıldığı kademe | Ekipman / perk | Zaman ve gürültü bedeli | Keşifte fark edilme |
|---|---|---|---|---|
| Havalandırma kanalı (giriş, çıkış, iç geçiş) | T4 depo (ilk), T5+ yaygın; T1-T3'te yok | Izgara sökücü (Alet, T4 dükkânı ~1.500); kanalda sürünme kipi 50 px/sn, görüş kanalda kesilir; zırh ve ganimet çantası sığmaz (yalnız veri/mücevher cepte), zırhlı Muscle giremez. Perk: Ghost "sessiz adım" kanal gürültüsünü de yarılar. | Izgara sökme 8 sn tut (gürültü 60 px); kanalda her 2 sn'de bir 40 px metalik ses (yakın sivilde "?"); ızgarayı düşürmek 140 px. Kanal "gizli ama yavaş"tır, hiç gürültüsüz değildir. | Dış ızgaralar dışarıdaki rolünce (arka cephe, çatı), iç ızgaralar içeridekince tavanda görülür; kroki ikonu "kanal" hafızadan konur. Keşif-soygun değişimi kanalı kapatabilir (T6+). Insider teklifi: "havalandırma planı". |
| Zayıf duvar patlatma (bina kabuğu ya da kasa dairesi arka duvarı) | T6 müze dış duvarı (ilk), T8 banka kasa dairesi arka duvarı; T9'da zayıf nokta görünmez (yalnız insider/plan) | Şekilli patlayıcı (Gadget sarf, ~4.000, Muscle taşır, 1 slot); yerleştirme çift anahtar: biri yerleştirir, biri gözetler. Perk: Muscle "sarsmaz" yerleştirmeyi %25 kısaltır; Tech "döngü süresi" düğümü maskeleme penceresini 3 → 5 sn yapar. | Yerleştirme 10 sn tut + 5 sn fitil geri sayımı; patlama 400 px (bina geneli) → uyarı doğrudan 2 (arama). Maskeleme: keşifte öğrenilen ya da modifikatörden gelen gürültü penceresi (tren geçişi, jeneratör testi, havai fişek; 3 sn) içinde patlatılırsa yarıçap ×0,3 → yalnız yakın muhafız. Yıkık duvar kalıcıdır; devriye görürse 2 → 3 (sessiz alarm). Isı +10. | Dışarıdaki: tadilat, çatlak, ek bina dikişi görünür ipucu (T6-T8); içerideki: "yalnızca personel" arkasındaki duvarı yoklama (bakış şüphesi işler). T9: yalnız insider teklifi "zayıf duvar". |
| Alttan patlatıp kasayı alt kata düşürme | Yalnız T9-T10 (çok katlı, yeraltı girişli şablonlar) | Ağır patlayıcı (2 slot, Muscle), kat delici (Alet), termal lans (düşen kasayı açma 60 sn); zemin zayıf noktası insider zinciri ya da satın alınan bina planıyla bilinir. | Hazırlık eşzamanlı 2 × 10 sn (çift anahtar: üst katta yerleştirme, alt katta boşaltma alanı) + 5 sn fitil; gürültü 600 px → uyarı doğrudan 4 (yüksek alarm, müdahale dalgaları). İstisna: düşen kasa saat kilidi/kepenk/boya kilidini atlar (kasa artık kilitli odada değil), ana ganimet alınabilir; aracı %45, ısı sıçrar; altın ağır lojistik (2 kişi taşır). "Büyük final" seçeneği: yüksek risk, yüksek getiri. | Alt kat ve zemin kalınlığı keşifte görülmez; yalnız insider zinciri (T10 "zorunlu keşif" + insider) ya da satın alınan plan. Keşif-soygun değişimi: alt kat dolu olabilir (tadilat). |

Not: perk ağacı (§7.3) büyümez, etkiler mevcut düğümlere eklenir (karar gereken: ağaç büyüsün mü). Hiçbir yöntem şablonun "gizli rota" garantisinin (§10) yerine geçmez; ekipmansız ekip her zaman kapıdan girebilmelidir.

## 8. Ekonomi

- Para: kişisel cüzdan (ekipman) + ekip kasası (ön ödeme, kefalet, aklama). Ödeme = ganimet değeri × aracı oranı; plan bonusu; kişi başı eşit pay (host değiştirebilir).
- Isı (0-100, ekip): gürültü, yaralı/ölü, tanık, başarısız iş, keşif şüphesi ile artar; iş döngüsü başına -10, "sessiz kal" (tur atla) -25, aklama (para) -15. Etkiler: >40 muhafız +1, >60 insider'lar çekilir ve ihanet olasılığı, >80 müdahale hızı ×1,5 ve fiyat +%20.
- İtibar (kademe başına): temiz tamamlama sayısı; sonraki kademeyi ve daha iyi aracıları açar.
- Aracı: taban %85 temiz; sıcak mal düşürür; itibarla daha iyi aracılar (%90+).
- Insider: iş başına 0-2 teklif (arka kapı açık, alarm kodu, vardiya listesi, eski kroki), ücret, güvenilirlik yıldızı; ısı >60'ta ihanet (polis bekliyor).
- Ganimet tipleri: nakit (hafif, boya riski), mücevher (aracı şart), altın (ağır, yavaş), sanat (kırılgan), veri (ağırlıksız, yükleme süresi), tahvil.
- Ölçek: bakkal 0,5-1,5 bin; kuyumcu 5-15 bin; müze 60-150 bin; banka şubesi 200-500 bin; merkez bankası 2-5 milyon. Fiyat: T1 maymuncuk 200, susturuculu tabanca 1.500, ECM 5.000, T3 deck 25.000, termal lans 40.000.
- Risk seviyesi 1-5: muhafız sayısı, kamera kapsamı, alarm süreleri, müdahale hızı ve ödemeyi ölçekler. Modifikatörler yaklaşımı değiştirir, can değil ("gece vardiyası", "yalnız sessiz alarm", "insider muhbir", "yağmur", "ağır ganimet", "köpekler", "VIP içeride").

## 9. Senaryo merdiveni

| # | Mekân | Hedef | Yeni mekanik / fiil | Görünmeyen önlem | Keşif değeri | Süre | Varyasyon |
|---|---|---|---|---|---|---|---|
| 1 | Köşe bakkalı | Kasa + arka oda nakdi | Sessiz/koşma, gürültü, kasa boşaltma (tut 3 sn, +150, yalnız tezgâh arkasından), sivili sindirme, T1 kilit (arka kapı; ön kapı mesaide açık), kaçış noktası | yok | Düşük (camdan bak) | 3-5 dk | Tezgâhtar/nakit yeri, müşteri, devriye polisin periyodu |
| 2 | Benzinlik / gece eczanesi | Kasa + ilaç dolabı | Kamera (sabit/dönen), DVR silme, tezgâh altı sessiz alarm, rehine = üçüncü el | Sahte kamera | Orta (hangi kamera gerçek) | 4-6 dk | Kamera açıları, DVR odası, sivil sayısı |
| 3 | Rehinci / kuyumcu | Kasa + vitrinler | Kasa çevirme vs matkap, cam kesici vs kırma, tuş takımı kodu; ilk çift anahtar | yok | Orta (kod yeri, bekçi) | 5-7 dk | Kasa modeli, kod yeri, gece bekçisi, insider |
| 4 | Depo / nakliye ambarı | Manifestodaki kasalar | Devriye rotaları/programı, ışık-karanlık, ceset saklama, ağır ganimet (2 kişi), forklift, havalandırma kanalı (ilk; §7.6) | yok | Yüksek (devriye periyodu, manifesto) | 6-8 dk | Rota grafiği, manifesto, köpek |
| 5 | Kumarhane sayım odası | Sayım nakdi | Kılık, kalabalık (örtü/tanık), kart klonlama, zaman penceresi, rüşvetli krupiye | Gizli kamera, sivil polis | Yüksek (kim kart taşıyor, sayım saati) | 8-10 dk | Sayım saati, müdür rotası, kalabalık |
| 6 | Sanat müzesi | 1-3 eser | Lazer ızgara, basınç plakası, kırılgan taşıma, telsiz yoklaması, çok kat, zayıf duvar patlatma (ilk; §7.6) | Basınç plakası, kızılötesi lazer (görünür kademe) | Yüksek (yoklama aralığı, sensör düzeni) | 8-12 dk | Eser yeri, sensör düzeni, kat modülleri |
| 7 | Zırhlı araç transferi | Transfer anındaki para | Zamanlama soygunu; kontrollü gürültü: koridor tutma, çanta zinciri; gizli varyant: araç/manifesto değişimi | Sivil polis eskort | Kritik (transfer saati) | 6-10 dk | Transfer saati, araç sayısı, rota |
| 8 | Banka şubesi | Kasa dairesi | Saat kilidi penceresi, müdür biyometrisi, boya paketi, çoklu eşzamanlı gereksinim, matkap ısı bakımı, rehine pazarlığı | GPS'li çanta, gizli kamera | Kritik (kilit penceresi, müdür) | 10-14 dk | Kasa tipi, müdür konumu, şube modülleri |
| 9 | Şirket merkezi / kripto borsası | Veri + cüzdan anahtarı | Hack'in mekânsal bulmacası (sunucu odası), rozet/kat erişimi, güvenlik ofisi işgali, yükleme baskısı | Görünmez lazer, ağ tuzağı | Kritik (erişim seviyeleri) | 10-15 dk | Kat modülleri, erişim dağılımı |
| 10 | Merkez bankası / darphane | Altın | Çok aşamalı (yeraltı giriş, termal lans, altın lojistiği, askeri müdahale, insider zinciri, çoklu giriş vektörü, alttan kasa düşürme; §7.6) | Hepsi + dönen kodlar | Zorunlu | 15-25 dk | Aşama modülleri, giriş vektörleri, insider zinciri |

Her kademede 2-3 elle yapılmış şablon + risk seviyesi + modifikatör + tohum. Keşif-soygun arası değişim olasılığı T1 %5 → T10 %30.
Alternatif giriş vektörlerinin merdiveni (GB-02, §7.6): T1-T3 yok (yalnız kapı/pencere) · T4-T5 havalandırma kanalı · T6-T8 zayıf duvar (görünür ipucu) · T9 görünmez zayıf duvar + kat geçişi · T10 hepsi + kasayı alt kata düşürme. Her yeni vektör ilk göründüğü kademede "öğretilir": o kademenin bir şablonunda vektör, tohumdan bağımsız açıktır.

## 10. Senaryo üretimi

Tamamen prosedürel bina yok. Adalet elle kurulur, çeşitlilik parametreyle gelir.
- Şablon (elle): bina kabuğu, odalar, kapılar, pencereler, giriş noktaları, görüş hatları; slot taşır. Her şablonda garanti: bir gizli rota, bir sessiz yedek, bir gürültülü çıkış. T4+ şablonlarında ek olarak en az bir alternatif giriş vektörü slotu (kanal ya da zayıf duvar; tohum açar/kapatır, "öğreten" şablonda hep açık), T9+'ta kat geçişi düğümleri (§7.6, §9). Karo türleri: duvar, pencere (görüşü geçirir), raf, tezgâh, kapı, kanal (yalnız sürünme, görüşü keser), zayıf duvar (yıkılabilir), kat geçişi.
- Modül (elle, varyantlı): oda ölçeğinde prefab; kendi güvenlik düğümlerini ve kapı sözleşmesini bildirir. T8+'ta şablonlar kanatlardan birleşir (lobi + ofis + kasa).
- Tohum: slot başına modül varyantı; güvenlik yapılandırması (kamera açık/kapalı/sahte, DVR yeri, muhafız sayısı ve yazarlı waypoint grafından rota, kart sahibi, kasa tipi, kod yeri, sivil programı); ganimet yerleşimi; insider teklifi; modifikatörler; saat ve hava; keşif-soygun arası değişim.
- Doğrulayıcı (headless): muhafız görüş kapsamını zaman adımlarıyla simüle eden yol arama: bütçe içinde gizli rota var mı, gürültülü kaçış ulaşılabilir mi, çift anahtar anları fiziksel olarak mümkün mü, keşifle öğrenilebilir en az bir zamansal bilgi var mı. Geçmezse yeniden üret. Alternatif vektörler (§7.6) için ek kurallar: gizli rota garantisi ekipman gerektiren vektörlere dayanamaz (ekipmansız ekip kapıdan girebilmeli); kanal karoları görüş simülasyonunda görüşü keser ve yalnız sürünme hızıyla yürünür; zayıf duvarın iki yanı yol aramada "patlayıcı varsa bağlı" sayılır; çok katlı şablonda kat geçişi düğümleri yol aramaya girer ve kasa düşürme için üst/alt kat çifti fiziksel olarak hizalı olmalıdır.
- İçerik verisi metin tabanlı kaynaklardır (şablon, modül, eşya, perk, modifikatör, cihaz, rota, insider teklifi); kod içinde sabit içerik yoktur. AI ajan içerik varyantı üretir, doğrulayıcı eler.

## 11. Co-op ve ölçekleme

- Merkez: 3 kişi. Talepler jeneratörde akış olarak tanımlıdır; oyuncu sayısı akışları ölçekler.
- 2 kişi: çift anahtar anları sıralıya çevrilir (pencereler uzar) ya da Tech'in bir uzaktan aracı otomasyona bağlanır; muhafız/kamera -1; rol birleşmesi Ghost+Tech ("sessiz olan") + Muscle. Bot yoldaş (MVP sonrası) üçüncü eli doldurur.
- 4 kişi: ek talep (ikinci kasa kapısı, ek devriye, fazla çanta); Tech ikiye bölünür (hacker + gözcü/dron) ya da "Face" (kılık/sosyal mühendislik); ödeme kişi başı dengelenir.
- Formül: muhafız = taban + (oyuncu − 3) × k; çanta sayısı, zamanlayıcılar ve keşif süresi oyuncu sayısıyla ölçeklenir.
- Keşifte 2 kişi: içerideki + dışarıdaki; 4 kişi: hat rolü ikiye (telefon + ağ) ya da ikinci içerideki (tanınma riski paylaşılır).
- Katılım: lobi ve plan masasında serbest; soygun ortasında yalnız "kaçış sürücüsü" olarak (MVP sonrası). Düşen oyuncunun avatarı donar ve 10 sn sonra bota döner.

## 12. Ağ ve gecikme tasarım kuralları

- Topoloji: host oyunculardan biri (İsveç'ten seçilir; iki oyuncu İsveç, biri Türkiye, ~50-90 ms RTT). Ayrı sunucu yok.
- Yetki: oyuncunun kendi avatarının hareketi istemci yetkili (anında his). Sonuç üreten her şey host yetkili: etkileşim başlat/bitir, kilit/hack ilerlemesi, muhafız ve sivil AI, şüphe ölçeri, uyarı kademesi, kapı/ganimet/çanta durumu, hasar, ekonomi.
- Oyuncu lehine tolerans: saklanma/görüş hattından çıkma kararında 0,2 sn oyuncu lehine; "tut" eylemlerinde ilerleme yerelde gösterilir, host onaylar; iptal host'tan gelirse ilerleme geri alınır ama ceza uygulanmaz. Faz 1'de kesinleşen host payları (mimari S2, `core/interaction_rules.gd`): menzile +24 px, taraf kısıtına 16 px (müşteri tarafı yine reddedilir), basılı tutma süresine +0,25 sn (yerelde çubuk dolmuşken bırakan oyuncu cezalanmaz); istemci istemi toleranssız, host onun üst kümesini kabul eder.
- Tepki pencereleri: muhafız tespit öncesi "?" ≥0,5 sn; çift anahtar pencereleri ≥0,5-1 sn; çanta devri 0,3 sn kilitli el sıkışma (host).
- Uzak oyuncular 100 ms interpolasyon tamponuyla çizilir (Faz 1: `interpolation_delay` 0,1 sn; hareket senkronu istemci yetkili 20 Hz; veri gecikirse son durumda bekler, ileri tahmin yok); muhafız konumu host'tan 15-20 Hz, istemcide yumuşatılır; görüş konisi istemcide senkron yön ve durumdan çizilir.
- Ölçülen (Faz 1, US-004/US-005): 150 ms RTT'de hareket sırasında senkron farkı host↔istemci < 32 px (1 karo), istemci↔istemci < 48 px (host üzerinden iki bacak); kasa sonucu istemcilerde ~85 ms içinde görünür (kabul ≤ RTT + 200 ms). Faz 2 şüphe/tespit kararları bu payın içinde kalmalıdır: host oyuncuyu ~100-175 ms eski konumda görür, bu yüzden 0,2 sn oyuncu lehine payı tasarım değil zorunluluktur.
- Plan masası ve keşif notları host'ta tutulur; çizimler eşzamanlı, çakışmada son yazan kazanır.
- Test kuralı: ilk fazdan itibaren gerçek internet (Tailscale) + yapay gecikme (150 ms, 30 ms jitter, %1 kayıp) ile oynanır. "Beni görmemişti" türü şikâyet tasarım hatası sayılır, oyuncu hatası değil.
- Oyun mantığı görselden ayrıdır: mantık 2D düzlemde (konum, görüş hattı, gürültü) hesaplanır; görsel katman durumu okur. 3D'ye geçişte mantık değişmez.

## 13. Ton sistemi

- Başlangıç tonu: noir / kuru soygun komedisi. Dünya ciddi görünür; mizah planın çözülmesinden gelir.
- Ton yalnız kozmetik katmandır: palet/filtre, müzik ve SFX seti, metin seti (anahtarlarla), UI teması. Kurallar, sayılar, sinyal anlamları (kart renkleri, uyarı renkleri, ikon şekilleri) her tonda aynıdır.
- Online'da tonu host seçer; herkes aynısını görür.
- Mimari baştan hazır: tüm metinler anahtarla; renkler tema tokenları; ses olayları set adıyla. İkinci ton MVP sonrası.

## 14. Görsel ve ses yönü

- 2D üstten, hafif eğik "3/4" bakış. Sanatı ışık yapar: 2D ışık + oklüder, görüş konileri, görülmeyen alan sisi, neredeyse tek renk palet + tek uyarı vurgu rengi.
- Karakterler prosedürel "kukla" (§14.1; KR-017); binalar tile kitleri ya da düz renk vektör geometrisi; ikonlar CC-BY oyun ikon seti; insider portreleri siluet + kod adı.
- Okunabilirlik önceliği: kamera konisi, muhafız bakış yönü, şüphe ölçeri ("?" ve "!"), gürültü halkası, karanlık bölge, plan katmanı her zaman ayırt edilir.
- Ses: gürültü olaylarının duyulabilirliği oyun bilgisidir (koşma adımı, cam, matkap); alarm, telsiz ve yoklama sesleri uyarı kademesini taşır. Müzik kademe ile gerilir, tespitte kesilir.

### 14.1 Karakter ve animasyon stili (KR-017, GB-03)
Referans ilkeler:
- Hedef his: anime oyunlarının tatlılığı ve zarafeti, kendine has akıcılık; ne retro/pixel platform ne gerçekçi; sert ve itici hiçbir hareket yok. Dünya noir ve koyu kalır (KR-005); sıcak ton yalnız karakterlerde (ten, atkı, yanak, vurgu rengi).
- Sanatçısız üretim: karakter, tamamen kodla canlanan prosedürel bir kukladır: iri baş + yüz (gözler, göz parıltısı, yanak), rol siluetini veren başlık (Ghost kapüşon, Tech bere + kulaklık, Muscle kasket, muhafız/polis şapka + rozet, sivil başlıksız), küçük gövde, iki el, atkı/palto ucu. Oran chibi'ye yakın: baş çapı ≈ gövde yüksekliği, toplam ~44 birim × kukla ölçeği. Rol ayrı sınıf değil, loadout + kozmetik parametre (mimari S10).
- Animasyon ilkeleri (hepsi kodla, sprite tablosu yok): lineer hareket yok (yumuşatma + yay/aşma); hazırlık ve devam (kalkışta minik çökme, duruşta öne taşıp yerine yaylanma, atkının savrulmayı sürdürmesi); ezilme-esneme (adım inişinde, tepkide); yürüyüşte sekme + gidilen yöne eğilme + ellerin karşıt salınımı; sızmada çömelme + kısa adım + öne uzanan eller; koşuda uzama + daha çok eğilme + toz; beklemede nefes + göz kırpma + etrafa ve ekibe bakınma; ikincil hareket (atkı verlet zinciri); tepki balonları "?" ve "!" aşmalı pop; fark edilince sıçrama + göz büyümesi (hem muhafız hem oyuncu).
- Görsel katman yalnız durumu okur (KR-003): kukla, oyuncunun kip/hız/yön/etkileşim durumundan ve NPC'nin senkronlanan yön/kademesinden beslenir; mantığa, çarpışmaya ve ağa dokunmaz. Uzak kopyada aynı animasyon ara değerlenmiş durumdan üretilir (girdiden değil). 3D'ye geçilirse aynı ilkeler toon/cel shading ile sürer.

Zamanlama aralıkları — başlangıç değerleri (`docs/tasarim/kukla-denemesi.html` varsayılanları); kullanıcının kaydırıcı denemesiyle ayarlanır, son değerler `data/puppet_tuning.tres`'e yazılır:

| Öğe | Başlangıç | Aralık / not |
|---|---|---|
| Yay frekansı (gövde ezilme / eğilme) | 4,5 Hz; sönüm 0,32 / 0,42 | 1,5-10 Hz; düşük = salınımlı, yüksek = çevik |
| Sekme çarpanı | 1,0 | 0-2; adım inişi ezilme darbesi 0,9 (sızma ×0,45, koşu ×1,4) |
| Abartı çarpanı | 1,0 | 0-2; eğilme, kalkış çökmesi ve ezilme-esnemeyi ölçekler |
| Hız yumuşatma | kalkış k=10, duruş k=13 (≈%95'e 0,30 / 0,23 sn) | üstel; rampa yok |
| Yön dönüşü | k=9 (≈0,33 sn) | gövde ve bakış birlikte |
| Adım boyu / sekme genliği | sız 13 / yürü 20 / koş 30 px; genlik 0,9 / 2,2 / 3,4 birim | kadans = hız ÷ adım boyu |
| Gövde ölçeği (kip) | sız 0,84 / yürü 1,00 / koş 1,07; etkileşimde 0,95 | sızma siluet olarak ayrı okunmalı |
| Eğilme | hız/220 × 0,16 rad (koşuda ×1,35); tavan ±0,38 rad (~22°) | ivmede ek öne taşma |
| Nefes | ~2,7 sn periyot, ±%2,4 ölçek | yalnız beklerken |
| Göz kırpma / bakınma | 0,13 sn, her 2-5,5 sn / her 1,4-3,6 sn, ±1,2 rad | beklerken; %35 yeniden ileri |
| Tepki balonu | easeOutBack pop 0,2 sn; "!" 0,4 sn titreme | "?" şüphe 30 (≥0,5 sn görüldükten sonra), "!" 100 |
| Sıçrama (fark edilince) | 260 px/sn, yerçekimi 1500 (~0,35 sn havada) | inişte ezilme |
| Atkı / toz | 6 parça, sönüm 0,92 / koşu adımında 3 parçacık, 0,45-0,7 sn | ikincil hareket |

Okunabilirlik kuralları:
1. Kip siluetten okunur: sızma = çömelmiş ve alçak; yürüme = dik; koşma = uzamış, eğik, tozlu. Uzak oyuncunun kipi atkı renginden sonra ikinci bakışta anlaşılmalı (ekip bilgisidir).
2. Oyun bilgisi taşıyan işaretler (görüş konisi, şüphe halkası, "?"/"!", gürültü halkası, etkileşim halkası) kuklanın üstünde, animasyondan bağımsız sabit bağlantı noktasında ve 1280×720'de ≥ 22 px çizilir; sekme/eğilme bunları oynatmaz.
3. Animasyon çarpışma yarıçapını (12 px) ve etkileşim menzilini değiştirmez; görsel aşma ≤ 6 px.
4. Rol silueti başlıktan, oyuncu kimliği atkı renginden (`ThemeTokens.PLAYER_COLORS[slot]`); muhafız/polis ayrı palet + rozet; sivil başlıksız ve atkısız.
5. Hareket azaltma seçeneği (ayarlar): sekme, eğilme ve toz kapanır; balonlar ve halkalar kalır.
6. 150 ms gecikmede uzak kopyanın kalkış/duruş yumuşatması tampondan gelen hız değişimine uygulanır; tampon sıfırlanınca animasyon da sessizce yeniden kurulur, "pop" yapmaz.

Kabul (Faz 2 "karakter kuklası v0"): oyuncu, tezgâhtar ve muhafız için yürü/sız/koş/bekle/etkileşim/tepki; parametreler `.tres`'te; görsel katmanın bağımlılık yönü testi geçer; headless ekran görüntüsünde üç kip silueti ayırt edilir; kullanıcı kaydırıcı değerleri kaydedilmiş olur.

## 15. MVP kapsamı

İçinde:
- Kademe 1 (bakkal) ve 2 (benzinlik: kamera, DVR, sessiz alarm, sahte kamera), her biri 1 şablon + tohum varyasyonu.
- Keşif: içerideki (müşteri) + dışarıdaki; oyalanma ve bakış şüphesi; tanınma sayacı; fotoğraf (3 kare). Hat rolü yok.
- Plan masası: ortak kroki, ikon paleti, rota, ping, rol ataması, giriş seçimi, plan katmanı. Tetik zinciri ve gadget ön yerleşimi yok.
- Gizlilik: görüş hattı/sis, muhafız FSM + navigasyon, kamera, şüphe ölçeri, uyarı 0-3 (4-5 yalnız "kaybettin" olarak), gürültü, ceset saklama yok.
- Çatışma: yok; yakalanma = iş biter. Sindirme var.
- Karakter: perk ağacı v0 (3 dal × 3 düğüm), dükkân 4-6 eşya (T2 maymuncuk, jammer, sessiz ayakkabı, ECM, dürbün, kılık yok).
- Ekonomi: para, aracı oranı (temiz/sessiz/yüksek), ısı v0 (muhafız sayısı etkisi), insider v0 (tek teklif tipi).
- Co-op: 2-4 oyuncu, 3 merkez; bot yok; düşen oyuncu donar.
- Steam: lobi, arkadaş daveti, Steam ağı; ENet yedek.
- Ton: tek ton, altyapı anahtarlı.

Sonraya:
- Kademe 3-10, modül birleşimi, doğrulayıcı (T3 ile gelir), kılık, hat rolü, mini kamera, dedektör, gizli önlemler (sahte kamera hariç), tetik zinciri, gadget ön yerleşimi, çatışma, bot yoldaş, soygun ortası katılım, ikinci ton, günlük tohum, lider tablosu.

## 16. Açık tasarım soruları

1. Keşif süresi sabit mi (dakika), olay bazlı mı (işin bitmesi)? Öneri: iş bitince 60 sn tolerans, sonra şüphe.
2. Fotoğraf plan masasında ne kadar yardımcı olmalı? Küçük görüntü yeterli mi, yoksa yakınlaştırma şüpheyi mi öldürür?
3. Yanlış yerleştirilen ikon için geri bildirim: soygun sonu özetinde "plan doğruluğu" gösterilsin mi (öğretir) yoksa gösterilmesin mi (hafızayı ödüllendirir)?
4. Sindirilen sivil kaç saniye "tutulmalı"; üçüncü el anı bakkalda bile gerekli mi, yoksa T2'den mi başlasın?
5. Aracı oranı ekip genelinde mi, kişi başı davranışa göre mi (gürültü yapan daha az alır)?
6. Keşifte yakalanmanın bedeli: iş iptali mi, "tetikte" modu mu, ısı mı? (Taslak: tetikte + küçük ısı.)
7. Plan katmanı yanlış ikonu hiç işaretlemesin mi, yoksa nesne görüş hattına girince ikon solsun mu?
8. Host değişimi: host düşerse iş biter mi (MVP), sonradan host göçü mü?
