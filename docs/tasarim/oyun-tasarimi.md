# Insiders — Oyun Tasarım Belgesi (GDD)

Durum: v0.4 taslak, MVP öncesi (US-011 tasarımı, 2026-10-02: §6.5 oyuncu görüşü / sis / hafıza katmanı, iki görüş kipi, ekip görüşü paylaşılmaz — kullanıcı kararı; gerekçe `docs/tasarim/arastirma/gorus-sis-hafiza.md`. Önceki: IS-021: KR-020 senaryo bazlı tehdit modeli — §9.1 kademe tablosu, §9.2 mekân nüfusu, §9.3 bakkal tasarımı; §6.1 sivil gözlemci çarpanları; §15 MVP metni. Önceki: IS-007 A — §14.1 kukla stili KR-017, §7.6 alternatif giriş GB-02). Bu dosya projenin tek tasarım kaynağıdır; tasarım kararı değişirse önce burası güncellenir.
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
- Fotoğraf (telefon): iş başına sınırlı kare (3), çekim anı fark edilebilir; fotoğraf plan masasında kroki kenarında küçük görüntü olarak durur, ikon üretmez. Kare, çekildiği andaki **görünen** katmandır (§6.5): hafıza ve bilinmeyen alan fotoğrafta da sislidir.
- Sisin hafıza katmanı (§6.5) **faz içidir**: keşifte açılan alan plan masasına geçerken silinir, soygun bilinmeyenden (krokideki duvarlarla) başlar. Oyun hiçbir fazda "nereyi gördün" bilgisini sonraki faza taşımaz; taşıyan oyuncunun hafızasıdır (KR-004).

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
- Görüş: her muhafız/sivil/kamera için görüş hattı (duvar keser) × ışık (karanlık bölge menzili kısar) × mesafe × hedefin durumu (koşma, çanta taşıma, silah elde, kılık). Oyuncu da yalnız kendi görüş hattındakini görür; görülmeyen alan sisli (Monaco kuralı). **Ekip görüşleri paylaşılmaz** (kullanıcı kararı 2026-10-02): arkadaşının kuklasını her zaman görürsün, onun gördüğü insanları görmezsin. Oyuncu görüşünün kuralları ve sayıları §6.5.
- Hareket kipleri (Faz 1'de kesinleşti, `data/player_tuning.tres`): sızma 70, yürüme 140, koşma 220 px/sn; 1 karo = 32 px, karakter çapı ~24 px. Kip, algıdaki "hedefin durumu" çarpanının ve gürültü yarıçapının girdisidir.
- Duyma: gürültü olayları yarıçapla yayılır; duvar azaltır, yağmur maskeler. Koşma, kırma, ateş, matkap, düşen nesne.
- Şüphe ölçeri: her gözlemcinin her oyuncuya karşı 0-100 ölçeri; görünürlük × süre ile dolar, görünmeyince boşalır. Eşikler: 30 "?" (gözlemci bakar, ≥0,5 sn tepki penceresi), 60 inceleme (yürüyerek gelir, sorgular), 100 tespit.
- Tespit sonucu gözlemciye bağlı: muhafız telsizle bildirir (bölgesel arama → sessiz alarm sayacı), sivil panikler ya da düğmeye basar (T2+), kamera operatörlüyse muhafız yönlendirir, operatörsüzse yalnız kayıt (DVR silinmezse ısı). **Dükkân sahibi / mahalleli (T1):** düğme ve telsiz yok; sorgular, bağırır, sokaktakiler gelir, tutmaya çalışır (§9.3). Hangi gözlemcinin hangi mekânda bulunduğu §9.1'de.
- **Sivil gözlemci davranış çarpanı (KR-020):** muhafız için "hedefin durumu" çarpanı hareket kipidir (koşu 2 / yürüme 1 / sızma 0,5). Sahip, müşteri ve yoldan geçen için çarpan, oyuncunun o an yaptığı **en şüpheli** davranıştan gelir (çarpılmaz, en büyüğü alınır); formül aynı: dolum/sn = 25 × bant × çarpan, boşalma 20/sn görünmeyince, 10/sn görünüp masum davranırken (çarpan 0). Tablo (`data/npc/civilian_tuning.tres` başlangıç değerleri):

| Davranış (görülürken) | Çarpan | Yakın bantta tespit (0,2 + dolum) | "?" → tespit aralığı |
|---|---|---|---|
| Müşteri bölgesinde yürüme/bekleme (ilk 60 sn) | 0 | hiç | — |
| Oyalanma: 60 sn'den sonra içeride kalma (§4.3) | 0,25 | 16 sn | uzun |
| Sızma (çömelmiş müşteri tuhaf, suç değil) | 0,5 | 4,2 sn | 2,8 sn |
| Koşma (dükkân içinde) | 1 | 2,2 sn | 1,4 sn |
| Personel tarafı / arka oda / "yalnızca personel" kapısı | 1,5 | 1,5 sn | 0,9 sn |
| Çanta taşıma, kilit açma (arka kapı, dışarıdan) | 1,5 | 1,5 sn | 0,9 sn |
| Kasa ya da nakit etkileşimi (tut sürerken) | 2,5 | 1,0 sn | 0,56 sn |
| Bağırıştan sonra herkes (uyarı ≥ 2) | 2,5 | 1,0 sn | 0,56 sn |

Uzak bantta (×1) süreler iki katıdır. Kasa 3 sn tutar: sahip yakın banttayken kasa boşaltma her zaman görülür (1,0 sn < 3 sn); uzak banttan görüş hattı varsa 1,8 sn'de; görüş hattı yoksa hiç. "?" → tespit aralığı her satırda ≥ 0,5 sn (GDD tepki penceresi) — kasa satırı sınırda, bu yüzden çarpan 2,5'i aşmaz.

### 6.2 Küresel uyarı kademeleri
0 Sakin → 1 Şüphe (yerel, zamanla söner) → 2 Arama (bölgesel; muhafızlar rotadan çıkar, kapılar kontrol edilir; 60-90 sn sonra söner) → 3 Sessiz alarm (polis gelişi için T sn sayaç; ECM uzatır; geri dönmez) → 4 Yüksek alarm (kepenk, saat kilidi, boya paketi, müdahale dalgaları) → 5 Kilitleme (yalnız kaçış).
Kademe 1-2 geri döner; 3+ dönmez. Bayıltılan muhafız bulunursa 2, telsiz yoklaması cevapsız kalırsa 2 → 3.
Kademelerin **anlamı mekâna bağlıdır** (KR-020): sayı ve HUD merdiveni her kademede aynı, tetikleyen olay ve sonuç §9.1 tablosunun "uyarı eşlemesi" sütunundan gelir. Bakkalda: 1 = sahibin şüphesi/sorgusu (söner), 2 = sahip bağırdı (mahalleli yolda; 30 sn kimse görmezse 1'e iner), 3 = mahalleli içeride (geri dönmez, 60 sn sayaç), 4 yok, 5 = polis geldi (yalnız kaçış). Sessiz alarm sayacı T2'de, kepenk/saat kilidi T3/T8'de başlar.

### 6.3 Gürültü ve ganimet kuralı
- Temiz iş (alarm yok) ana ganimet + aracı %85-90.
- Sessiz alarm: ana ganimet hâlâ alınabilir, süre baskısı; aracı %70.
- Yüksek alarm: T5+'ta ana ganimet kilitlenir (saat kilidi/kepenk/boya), yalnız "kapılabilir" ganimet; aracı %45; ısı sıçrar.
- Ölü/yaralı başına ek ısı; "kimseye zarar vermeden" bonusu.

### 6.4 Çatışma (ilk sürüm: minimal)
Gizlilik varsayılan. T1-T2'de silah fiili yoktur (KR-020: bakkal/benzinlik soygunu abartılmaz; silah çekme, sindirme T2'de düğme penceresini kesmek için gelir, T1'de yok); silahlı NPC ilk kez T7'de (§9.1). Gürültü = baskı altında kaçış ve 30-60 saniyelik koridor tutma anları. Silahlar gürültü yarıçapı + ölümcüllük + ağırlıkla tanımlıdır; muhafız her silahla düşer, kısıt sayı ve sonuçtur. Can/hasar/silah veri güdümlü; muhafız davranışı genişletilebilir. Büyüyen çatışma ileride belirli kademelere (T7 transfer) ya da ayrı "gürültülü iş" türüne gider; plan fazını zayıflatmasına izin verilmez.

### 6.5 Oyuncu görüşü, sis ve hafıza katmanı (US-011; gerekçe `arastirma/gorus-sis-hafiza.md`)

Tüm harita tek seferde görünmez; kamera oyuncuyu izler (1,5 yakınlaştırma, harita sınırına kenetli) ama bilgiyi saklayan sistir: görüş yarıçapı her ekran çözünürlüğünde aynıdır (büyük ekran avantaj değildir). Her oyuncu dünyayı üç katmanda görür; katmanlar üç bilgi kaynağına karşılık gelir:

| Katman | Kaynak | Çizilen | Gizli | Görünüm (`ThemeTokens.GAMEPLAY_FOG_*`) |
|---|---|---|---|---|
| Görünen | göz (şu an görüş hattında) | her şey: NPC, prop durumu, balon, koni, halka | — | örtü yok |
| Hafıza | bu fazda daha önce görülmüş | yapı + mobilya + prop **son görülen durumda** (kapı, çanta) | canlılar, güncel durum | `MEMORY` = BG α 0,55, doygunluk ×0,5 |
| Bilinmeyen | kroki/plan (§5: duvarlar hazır) | yalnız duvar ve kapı boşluğu çizgileri | mobilya, raf düzeni, prop, canlılar | `UNKNOWN` = BG α 0,88; çizgiler sisin üstünde |

Kurallar (başlangıç değerleri `data/vision_tuning.tres`, oyun testiyle ayarlanır):
- Görüş hattı kuralı NPC'ninkiyle **aynı** (§6.1, US-006): duvar, raf, kapalı kapı keser; cam geçirir (camdan içerisi ve dışarısı görünür → "camdan bak" §4.7 kendiliğinden çalışır); açık kapı geçirir.
- Menzil 288 px (9 karo) = NPC menzili + 1 karo: oyuncu sahibi, sahip oyuncuyu görmeden önce görür (§2.9). Kenar 32 px yumuşak. Karanlık bölgede duran oyuncu 128 px; karanlık bölge görüş hattında bile hafıza tonunda + tarama kalır, içindeki NPC yalnız oyuncu da karanlıkta ve ≤ 128 px ise görünür (KR-019 ikili ışık).
- Çözünürlük 32 px karo ızgarası, 100 ms'de bir güncellenir; görünürlük kararı **istemcide, yerel konumdan** (150 ms RTT'de sıçrama yok; host görünürlük kararı vermez). Hile notu: istemci tüm NPC konumlarını alır; arkadaş oyunu, düşük öncelik.
- **İki görüş kipi, host'un oyun kuralı** (lobide seçer, herkes aynı; kişisel ayar değil): **Çevresel 360°** (yarıçap içinde her yön) · **Yönlü** (fare / gamepad sağ çubuk; klavye-yalnız oyuncuda bakış hareket yönüne 0,33 sn'de yumuşak döner): önde 90° net koni (288 px) · yanlarda 180°'ye kadar çevresel bölge (192 px; yapı ve prop durumu güncel, canlılar soluk siluet, balon/koni yok; `PERIPHERAL` = BG α 0,30, doygunluk ×0,6 — blur değil) · 360° yakın halka 64 px (arkadan tutma menziline giren görülür) · arkası yalnız hafıza + ses halkaları. Dönüş tavanı 240°/sn (etrafı taramak zaman ister). Bakış yönü çoğaltılır (istemci yetkili, 20 Hz); kukla baş ve gözler bakışı izler (§14.1), ekip arkadaşının üstünde atkı renginde 32 px / 90° ince yay. NPC algısı oyuncunun bakışını **kullanmaz** (arkası dönük oyuncuya çarpan yok; §6.1 tablosu davranış bazlıdır). Varsayılan kip test-2 A/B ile kesinleşir (§16 soru 9).
- NPC görünürlüğü: karo görünen ∧ görüş hattı; görüşten çıkınca 0,2 sn tutma (§12 payı), sonra son konumda 1,5 sn hareketsiz **hayalet** (MUTED α 0,5, başlık silueti: kim olduğu okunur), sonra yok. "Nereye gitti" sorusu oyunun kendisidir.
- Ses halkaları duvar arkasından görünür, ama yalnız **duyana**: halka çizilir ⇔ kaynak görünen karoda ∨ yerel oyuncu (duvarla ×0,5) yarıçapında. Sahibin ajanda sesleri gürültüdür: telefon 160 px / 3 sn'de bir, raf düzeltme 96 px / 2 sn'de bir, kapılar ve zil 160. Görüş yoksa "sahip nerede" dinlemeyle cevaplanır; sahibin görev ikonu yalnız görünürken.
- Ekip arkadaşı **her zaman** tam çizilir (konum, kip, atkı rengi, bakış), sis üstünde, görüş hattı gerekmez; ekran dışındaysa kenarda atkı renginde ok. Üstünde "görüldü" ikonu (ALERT göz, 16 px): herhangi bir gözlemcinin ona şüphesi ≥ 30 iken — başının dertte olduğunu görürsün, kimin gördüğünü görmezsin. Kendi rozeti HUD'da: gizli / görünür (bir konide) / görüldü (≥ 30); host'tan 10 Hz özet.
- Geçişler: karo açılması 0,15 sn, hayalet solması 0,3 sn; hareket azaltma açıkken anlık. Keşif ekipmanı dürbün (Faz 3): tut → 30° / 640 px koni, bakış şüphesi işler. Yönlü kipte keşifteki "inceleme" (§4.3) net konide ≥ 3 sn bakmakla doğal olur; çevresel kipte "tut" eylemi kalır.
- Kabul (bakkal, 3 kişi): sokaktaki oyuncu camdan tezgâhı görür, arka oda bilinmeyendir; arka odadaki oyuncu D kapısı kapalıyken sahibi görmez, telefon halkasını duyar; aynı anda host sahibi görür (paylaşım yok); headless senaryo iki kipte ve 0/150 ms'de geçer; 1280×720 ekran görüntüsünde üç ton (yönlüde dört) tek karede ayırt edilir.

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
| 1 | Köşe bakkalı (gündüz, mesai) | Kasa + arka oda nakdi | Sessiz/koşma, gürültü, kasa boşaltma (tut 3 sn, +150, yalnız tezgâh arkasından), sahibin dikkat döngüsünü okuma ve yönetme (oyalama, dikkat dağıtma, arka odaya gönderme, müşteri kılığı), T1 kilit (arka kapı; ön kapı mesaide açık), çanta, kaçış noktası; güvenlik öğesi yok (§9.1, §9.3) | yok | Düşük (camdan bak: sahip nerede, sokak boş mu) | 3-5 dk | Sahibin ajandası (tohum), müşteri sıklığı, arka oda nakdi yeri, yoldan geçen yoğunluğu |
| 2 | Benzinlik / gece eczanesi (gece) | Kasa + ilaç dolabı | Kamera (sabit/dönen), DVR silme, tezgâh altı sessiz alarm düğmesi, sindirme (düğme penceresini keser) = üçüncü el, ilk polis (sessiz alarm sayacı) | Sahte kamera | Orta (hangi kamera gerçek) | 4-6 dk | Kamera açıları, DVR odası, sivil sayısı |
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

### 9.1 Kademe başına tehdit modeli (KR-020)

Kural: bir güvenlik öğesi ya da tepki ancak o mekânda gerçek hayatta beklenirse vardır; her öğe merdivende ilk göründüğü kademede öğretilir (kamera/düğme T2, sesli alarm T3, telsizli görevli T4, operatörlü kamera T5, sensör T6, silahlı NPC T7, kepenk/saat kilidi T8, dijital tuzak T9). Süreler başlangıç değeridir (`data/` altında, oyun testiyle ayarlanır). "Uyarı eşlemesi" §6.2 merdiveninin o mekândaki anlamıdır; HUD merdiveni her kademede aynıdır.

| # | Mekân (saat) | İçeridekiler | Dışarıdakiler | Güvenlik öğeleri | Tepki zinciri ve süreler | Uyarı eşlemesi | Gerçekçi en kötü sonuç |
|---|---|---|---|---|---|---|---|
| T1 | Köşe bakkalı (gündüz, mesai) | Sahip 1 (ajanda: tezgâh/raf/arka oda/telefon/müşteri); müşteri 0-2 (geliş 35±15 sn, kalış 25-45 sn) | Yoldan geçen ≤2 (20±8 sn'de bir; camdan bakma olasılığı %30, 2 sn); komşu 1 (bağırıştan 8 sn sonra) | **Yok.** Kamera, alarm, panik düğmesi, güvenlik görevlisi, polis devriyesi yok. Arka kapı T1 kilit (6 sn), arka oda nakdi çekmecede | Sahip "?" (durur, bakar 0,5-1 sn) → sorgu (yürür 110 px/sn, 64 px'te "Ne yapıyorsun orada?") → bağırma ("!" + gürültü 320 px) → menzildeki yoldan geçenler döner, komşu 8 sn sonra `NeighbourSpawn`'dan çıkar (200 px/sn) → tutma (sahip, 6 sn kurtarma penceresi) / yakalama (mahalleli, kalıcı) → mahalleli içerideyken 60 sn sonra "polis geldi" | 0 sakin · 1 sahip şüphe/sorgu (söner) · 2 bağırış (mahalleli yolda; 30 sn görüş yoksa 1) · 3 mahalleli içeride (dönmez; 60 sn sayaç) · 4 yok · 5 polis geldi (yalnız kaçış; içeride kalan yakalandı) | Mahalleliye yakalanmak; dayak/silah yok; ısı +5, tanınma sayacı |
| T2 | Benzinlik / gece eczanesi (gece) | Gece çalışanı 1 (tezgâh, düğme); müşteri 0-1 (araçla, 60±20 sn) | Araç müşterisi; yoldan geçen seyrek; devriye arabası 3-4 dk'da bir geçer (ilk polis varlığı) | Kamera 2 (1 sahte), DVR arka odada, tezgâh altı sessiz alarm düğmesi; görevli yok | Çalışan "?" → "!" → düğmeye uzanır 1,5 sn (sindirme keser: üçüncü el) → sessiz alarm: polis 120 sn. Kamera görürse yalnız kayıt; DVR silinmezse ısı +15 (tanınma) | 1 şüphe · 2 çalışan paniği (bağırmaz, düğmeye gider) · 3 sessiz alarm (120 sn) · 5 polis | Polis gelişi = kilitleme; kayıt = tanınma |
| T3 | Rehinci / kuyumcu (gündüz randevulu ya da gece bekçili) | Sahip + çalışan 1 (gündüz) ya da gece bekçisi 1 (silahsız, telefon); müşteri 0-1 | Komşu dükkânlar (tanık); polis çağrıyla 150 sn | Kamera 2-3 + DVR, vitrin cam alarmı (sesli), buzzer kapı, kasa (çevirme/matkap), tuş takımı kodu | Cam kırılınca sesli alarm → alarm firması 90 sn → polis 150 sn; bekçi telefon eder (10 sn pencere, sindirme keser); sahip kepenk indirir | 1 şüphe · 2 bekçi/çalışan telefon-düğme · 3 alarm (150 sn) · 4 kepenk · 5 polis | Sesli alarm + mahalle tanıkları; polis 2,5 dk |
| T4 | Depo / nakliye ambarı (gece, sanayi) | Güvenlik görevlisi 2 (devriye, telsiz, yoklama 90 sn), forklift sürücüsü 0-1, köpek (modifikatör) | Yok (sanayi bölgesi); özel güvenlik aracı 90 sn | Dış kamera 2, hareket sensörlü ışık, telsiz, kilitli yükleme kapıları | Görevli "?" → telsiz 1,5 sn → arama (2) → ikinci tespit ya da yoklama cevapsız → merkez: özel güvenlik 90 sn, polis 180 sn (muhafız FSM: `muhafiz-davranisi.md`) | 0-3 tam · 4 yok (kilitleme yok, kaçış açık) · 5 polis | Özel güvenlik + polis; ağır ganimet geride kalır |
| T5 | Kumarhane sayım odası (gece) | Sivil 20-40, üniformalı güvenlik 4-6 + sivil polis 1-2, krupiye/müdür (kart) | Vale/otopark; polis 120 sn | Operatörlü canlı kamera (10 sn yönlendirme), kart kapıları, çift kapılı sayım odası, gizli kamera | Operatör gördü → en yakın güvenlik 10 sn → kilitleme 30 sn → polis 120 sn; kalabalık hem örtü hem tanık (§9.2) | 0-5 tam; 5 (kilitleme) 30 sn'de | Kilitleme + tutuklama |
| T6 | Sanat müzesi (gece) | Bekçi 3-4 (telsiz yoklaması 60-90 sn), kamera operatörü 1 | Yok; polis 90 sn (merkez) | Lazer, basınç plakası, operatörlü kamera, sessiz alarm doğrudan polise, kırılgan eserler | Sensör → sessiz alarm 90 sn (bekçi görmeden); bekçi tespit → telsiz → arama → sessiz alarm | 0-3 + 5; 4 yok (kepenk yok) | Polis 90 sn; eser hasarı değer 0 |
| T7 | Zırhlı araç transferi (sokak, gündüz) | Silahlı kurye 2-3 (ilk silahlı NPC), sivil polis eskortu 1 | Sokak sivilleri (tanık, panik); polis 60 sn | Araç GPS, GPS'li/boyalı çanta, kurye telsizi 5 sn | Kurye fark eder → telsiz 5 sn → polis 60 sn; silah çekilir (§6.4 koridor tutma) | 2 → 4 doğrudan (sessiz alarm yok, her şey açık) | Ateşli çatışma, boya, yaralı, ısı sıçrar |
| T8 | Banka şubesi (gündüz) | Görevli 1-2, personel 6-10, müşteri 5-15, müdür (biyometri) | Şehir merkezi: polis 90 sn, özel tim 240 sn | Tam kamera (merkez izleme), her tezgâhta sessiz alarm, saat kilidi, boya paketi, GPS çanta, kepenk | Düğme 1 sn → sessiz alarm → polis 90 sn → kepenk/saat kilidi (4) → özel tim 240 sn (5); rehine pazarlığı | 0-5 tam | Kilitleme + rehine durumu + özel tim |
| T9 | Şirket merkezi / kripto borsası | Lobi güvenliği 2, güvenlik ofisi 1-2 (kamera duvarı), personel (gündüz çok / gece az) | Özel güvenlik 60 sn, polis 120 sn | Rozet kapıları, görünmez lazer, ağ tuzağı (sessiz tel), sunucu odası biyometri | Ağ tuzağı → dijital iz (ısı +30) + güvenlik ofisi 20 sn → kilitleme; fiziksel tespit → ofis → özel güvenlik 60 sn; yükleme kesilir | 0-5 tam; 3 "dijital" olabilir | Kilitleme + dijital iz; veri yarım |
| T10 | Merkez bankası / darphane | Askeri koruma 10+, personel, operatörler | Askeri müdahale dalgaları 30/90/180 sn | Hepsi + dönen kodlar, çok kat, yeraltı giriş | Herhangi bir tespit → anında 4; dalgalar; 1-2 kademeleri saniyeler sürer | 4-5 hızlı | Ekip tamamen kaybolur |

Tutarlılık notları: "polis" T1'de dolaylı ve geç (mahalleli → 60 sn → polis), T2'de ilk kez sayaçla gelir; sindirme/üçüncü el T2'den; kamera T2'de öğretilir (K2/K4 değişikliği, KR-020). §15 MVP buna göre: Faz 2 bakkalı sivil gözlemcilerle, Faz 4 benzinliği kamera + düğme + sessiz alarm ile kurar.

### 9.2 Mekân nüfusu (sivil ajanda sistemi)

Her mekânın bir **nüfus profili** vardır (`data/levels/<id>_population.tres`, S10): kim, ne sıklıkla, kaç kişi, ne kadar, hangi rotayla. Nüfus tohumla belirlenimcidir (aynı tohum + aynı girdi = aynı geliş zamanları ve rotalar; replay/CI). Bileşenler (mimari S11): `Perception` + `Suspicion` (§6.1 sivil çarpan tablosu) + `Agenda` (rota/görev listesi: işaret noktası, süre, bakış yönü) + tür başına beyin (`brain_owner`, `brain_customer`, `brain_passerby`, `brain_chaser`). Aynı sistem ileri kademelerde yoğunlukla ölçeklenir (benzinlik 0-1 müşteri, banka 5-15, kumarhane 20-40).

| Parametre | T1 bakkal (başlangıç) | Not |
|---|---|---|
| Müşteri geliş aralığı | 35 ± 15 sn (tohum) | İlk müşteri 10-20 sn'de; 2 kişilik oyunda aynı |
| Aynı anda içeride en fazla | 2 | Üst sınıra ulaşınca gelen beklemez, rota iptal |
| Kalış süresi | 25-45 sn | Rota: ön kapı → 1-2 raf noktası (`ShopSpot*`, 8-12 sn, rafa döner) → kuyruk noktası (`QueueSpot*`) → servis 6 sn (sahip tezgâhta ve boşsa; değilse bekler, 20 sn sonra bırakıp çıkar) → ön kapı |
| Yoldan geçen aralığı | 20 ± 8 sn, sokakta ≤ 2 | Rota `StreetRoute1..6` (eski `PolicePatrol*`); her cam parçasında %30 olasılıkla 2 sn içeri bakış (koni 40°/192 px, camdan geçer) |
| Komşu | 1, yalnız bağırışta, 8 sn sonra `NeighbourSpawn`'dan | İkinci bağırış (20 sn sonra) +1 |
| NPC üst sınırı (host) | 6 (sahip 1 + müşteri 2 + yoldan geçen 2 + komşu 1) | Algı: 6 × 3 oyuncu × 15 Hz ≈ 270 ışın/sn; çoğaltma konum + yön + durum 15 Hz ≈ 2 KB/sn |

Müşterilerin oyuna etkisi:
- **Tanık:** sivil çarpan tablosuyla şüphe biriktirir; eşik 100'de bağırmaz, **sahibe söyler**: sahibi görüyorsa ona yürür (3-5 sn), sahibin o oyuncuya şüphesi +60 (sorgu başlar); sahibi görmüyorsa (arka odada) ön kapıdan kaçar ve T1'de başka sonuç yok. "?" balonu müşteride de görünür: oyuncu kimin gördüğünü okur.
- **Örtü:** dükkânda ≥ 1 müşteri varken sahibin müşteri bölgesindeki oyunculara dolumu ×0,5 (dikkat bölünür); personel tarafı ve kasa satırları etkilenmez.
- **Dikkat:** müşteri kuyruk noktasına gelince sahip ajandasını keser, tezgâha gelir, batıya döner, 6 sn servis — bu, **arka oda** için pencere açar (kasa açmaz: kasa sahibin burnunun dibinde). Her ön kapı geçişi (zil) sahibi 1 sn kapıya baktırır.
- **Engel:** kuyruk noktasındaki müşteri kasa boşaltmayı fiziksel olarak engellemez (kasa personel tarafından) ama yakın bantta tanıktır; raf koridorları 1 karo olduğundan müşteri ile oyuncu **çarpışmaz** (npcs katmanı oyuncuları itmez; iç içe geçince yarı saydam) — koridor tıkanması sinir bozucu olur, kaçınılır.
- Keşif bağı (Faz 3): müşteri sıklığı ve sahibin ajanda sırası dışarıdan camdan izlenebilir zamansal bilgidir ("sahip her 2 dakikada arka odaya gidiyor").

### 9.3 Köşe bakkalı (T1) tasarımı

**Eğlence nereden gelir:** güvenlik yok, ama **bir çift göz** var ve o gözün dikkati okunabilir ve yönetilebilir. Oyun "muhafızdan kaç" değil, "sahibi meşgul tut, zamanı yakala, sokağı kolla"; iki kişi iki yerde (kasa ve arka oda) aynı anda çalışmak isteyince sahip hep birinin yanında — plan bozulur, ekip bağırarak koordine eder. Kaos küçük ölçeklidir (bağıran bakkal, terlikli komşu, düşen çanta), ceza komik ölçekte (yakalanan payı düşer; yakalanan başına küçük kefalet 100 ekip kasasından, KR-029).

**Sahibin dikkat döngüsü** (`brain_owner`, ajanda tohumla; süreler `data/npc/owner_tuning.tres`):

| Görev | Nerede / bakış | Süre | Hangi pencereyi açar |
|---|---|---|---|
| TEZGÂH | `ClerkSpot`, batıya (kapıya) bakar; koni 50°/224 px, yakın bant ≤ 112 px | 20-40 sn | Hiçbiri (kasa 1 karo yanında, arka oda kapısı 3 karo arkasında ama koni dışında: arka odaya **sızarak** girilebilir, D kapısı sesi 160 px "?") |
| RAF DÜZELTME | `RestockSpot1..3` (raf önü), rafa döner (sırtı satış alanına) | 15-25 sn | **Kasa** (uzak raf: tezgâha 5-7 karo, görüş hattı raflarla kesik) |
| ARKA ODA | `BackroomSpot`, arka odada | 10-20 sn | **Kasa** tamamen; arka oda kapalı (içerideki görülür) |
| TELEFON | `PhoneSpot` (tezgâh arkası doğu duvarı), doğuya döner; koni 25° daralır | 10-15 sn | **Kasa** (koni dışında) ve arka oda; kapı zili telefonu kesmez |
| MÜŞTERİ (kesme) | `ClerkSpot`, batıya | 6 sn / müşteri | **Arka oda**; kasa kapalı |
| ZİL (kesme) | Durur, kapıya bakar | 1 sn | Dikkati kapıya çeker (yakın banttaki kasa dışında her şey) |

Ajanda sırası tohumdan: TEZGÂH ↔ {RAF, ARKA ODA, TELEFON} dönüşümlü; ardışık iki pencere arasında ≥ 15 sn tezgâh. 3-5 dk'lık işte 4-6 kasa penceresi (her biri ≥ 10 sn; kasa 3 sn + tezgâh ucundan dolanma ~2 sn → yeterli ama sınırlı) ve 2-4 arka oda penceresi çıkar. Kabul: headless ölçümde 300 sn ajandada kasa görüş hattı dışı toplam süre 60-120 sn.

**Tepki zinciri (sayılar):** şüphe 30 "?" → durur, bakar 0,5-1 sn · 60 SORGU → oyuncuya yürür (110 px/sn), 64 px'te durur, "Ne yapıyorsun orada?" balonu, 3 sn bekler; oyuncu masum davranışa dönerse (çarpan 0, boşalma 10/sn) 3 sn'de 30'un altına düşer ve söylenerek ajandaya döner; OYALA ile anında -40 · 100 BAĞIR → "!" + gürültü 320 px (kaldırım + cadde) → uyarı 2; menzildeki yoldan geçenler ve komşu (8 sn) `brain_chaser` olur (200 px/sn; koşan oyuncu 220 ile açık alanda kaçar, köşe ve kapıda yakalanır) → uyarı 3 ilk mahalleli ön kapıdan girince; 60 sn sayaç → 5 "polis geldi" · Sahip TUTMA: 120 px/sn kovalar, 28 px + 0,5 sn temas = oyuncu **tutuldu** (donar; 6 sn pencere; ekip arkadaşı 32 px içinde "çek" 1 sn tutar → ikisi serbest, sahip 2 sn sendeler; aynı oyuncu ikinci kez tutulursa pencere 3 sn) · Mahalleli yakalaması 28 px + 0,5 sn = **yakalandı** (K3: donar, kurtarma yok) · Bağırış sonrası sahip her 5 sn bağırmayı yineler (gürültü), kimseyi 30 sn görmezse uyarı 2 → 1, ajandaya döner (arka oda nakdini kontrol eder: nakit alınmışsa 60 sn sonra yine bağırır, bu kez komşu +1 — "geç fark etme" klibi).

**Oyuncunun araçları** (US-010; hepsi Interactable bileşeni, host doğrular):

| Araç | Nasıl | Etki | Bedel / sınır |
|---|---|---|---|
| Müşteri kılığı (pasif) | Müşteri bölgesinde yürümek | Çarpan 0, 60 sn | 60 sn'den sonra oyalanma 0,25; koşma/sızma kılığı bozar |
| SATIN AL | Tezgâh önünde 2 sn tut (sahip tezgâhtaysa ya da 20 sn içinde gelir) | Oyalanma sayacı sıfırlanır; sahip 6 sn tezgâha kilitlenir, batıya bakar → arka oda penceresi | Ekip nakdinden 10 (yoksa bedava, Faz 2); iş başına sınırsız ama her satın alma sahibin o oyuncuya şüphesini 0'a çeker, diğerlerine değil |
| OYALA / SOHBET | Sahip 64 px içinde ve o oyuncuya şüphesi 30-99 iken 1,5 sn tut | Şüphe -40, sahip 2 sn daha konuşur (ajanda duraklar) | 1. kez tam, 2. kez -20, 3. kez etkisiz ("bir daha tutmaz"); bağırıştan sonra (100) işlemez |
| ARKA ODAYA GÖNDER | Tezgâh önünde 2 sn tut ("Arkada X var mı?") | Sahip arka odaya gider, 10 sn arar, "yok" der, döner → **kasa penceresi ~14 sn**; arka oda bu sürede kapalı | İş başına 1; dönüşte soran oyuncuya şüphe +20; o sırada arka odadaki ekip arkadaşı görülürse çarpan 1,5 |
| DİKKAT DAĞIT | Raf ucundaki `ShelfProp*` (3 adet) anında: ürün devirme, gürültü 120 px | Sahip sese 8 sn bakmaya gider (`DINLE` → inceleme), yönü ses; o sırada kasa ya da arka oda açılır | Prop tek kullanımlık; sesi duyan müşteri de bakar; o noktadan koşarak uzaklaşan oyuncuya +15 |
| ÇEK (kurtarma) | Tutulan ekip arkadaşının 32 px içinde 1 sn tut | İkisi serbest, sahip 2 sn sendeler, kurtarana şüphe 100 (artık o da hedef) | 6 sn pencere içinde; mahalleli tutmasında işlemez |
| KAP-KAÇ | Kasayı sahibin gözü önünde tut | 1,0 sn'de bağırır; tezgâhtaysa 1 karo mesafeden 1,5 sn içinde tutar → kasa iptal | Yalnız sahip ≥ 4 karo uzaktayken anlamlı (3 sn kasa + kaçış) ve sokak boşken (yoldan geçenler 1-2 sn'de kapıda) |
| YÖNLENDİR "o tarafa kaçtı!" (US-043) | Örtüsü sağlam oyuncu, uyarı ≥ 2'de sahibe ya da mahalleliye 64 px içinde 1,5 sn tut | Söyleyene 480 px içindeki mahalleliler 8 sn kaçış noktasının tersine koşar, sonra orada arar; mahalleli örtüsü sağlam oyuncuyu zaten kovalamaz (seyirci), tutulurken dinler | İş başına 1; söyleyene sahipte +30 şüphe |
| Vitrinden bakma (US-044, bedel) | Dışarıda vitrine 64 px yakın, içeri bakarak durmak | İlk 6 sn serbest (yoldan geçen örtüsü), sonra sahibin konisindeyse şüphe yavaş dolar (×0,15): "?" → vitrine döner → 60'ta ön kapıya gelip "Bir şey mi arıyorsun?" diye sorar (bağırmaz, şüphe 90'da durur) | Sorgulanan tanınır (iş sonucu `recognized` +1) |
| Arka kapı kilidi (US-009) | Dışarıdan 6 sn tut (T1 maymuncuk), gürültü 60 px | Arka odaya ikinci giriş; sahip arka odadayken kapı sesi 160 px "?" | Yan sokaktan geçen yoldan geçen görürse çarpan 1,5 → bağırır (gürültü 240) |

**Ganimet ve sonuç:** kasa 150 (anında ekip nakdine, US-005) + arka oda nakdi 300-600 (tohum; **çanta** nesnesi: 2 sn alma, taşıyan koşarsa %50 olasılıkla düşürür + gürültü 160, devir 0,3 sn) + opsiyonel raf değerlileri (sigara/içki, 3 × 30, 1 sn alma, tanık çarpanı 1,5; Faz 2b). Kazanma: yakalanmamış herkes `EscapeZone`'da (uyarı 3'ten sonra 60 sn içinde). Kaybetme: herkes yakalandı ya da sayaç bitti. Örtü (US-042): dükkânda müşteri gibi duran (maskesiz, eli boş, müşteri tarafında, yürüyen; işaretli arkadaşla görülmemiş) oyuncu polis geldiğinde tanık olarak sorgulanıp serbest bırakılır (kefalet yok, tanınır, ısı +2); koşma/sızma, personel tarafı, çanta ya da kasa örtüyü iş boyunca bozar. Ödeme = ganimet × oran: uyarı ≤ 1 %85 (temiz; "kimse bağırmadı" bonusu +%5), 2 %85 + ısı +5, 3 %70 ("sıcak"); yakalananın payı 0 (K3), kalanlar kaçtıysa kısmi; iş sonunda yakalanan başına kefalet 100 ekip kasasından düşer (KR-029; kasa eksiye düşebilir, sonraki ödeme kapatır). Ganimetsiz herkes kaçış bölgesinde 3 sn kalırsa iş "eli boş" biter (pay 0, yakalanma yok; US-040). Hedef süre 3-5 dk: temiz koşuda sahip penceresi beklemek 60-90 sn, kasa + arka oda 30 sn, kaçış 10 sn.

**Rol bölüşümü:** 3 kişi — **Müşteri** (satın al/oyala/gönder ile sahibi yönetir, kapı zili zamanlar, "şimdi!" der), **Kasacı** (tezgâh ucundan dolanır, pencereyi yakalar), **Arka odacı** (arka kapı kilidi, nakit çantası, yan sokağı kollar). 2 kişi — Müşteri + Hırsız; nakit ya kasa ya arka oda, ikisi de "açgözlü" rotadır (pencere iki kez beklenir). Üçüncü el yok (T2'de); "sahibin dikkatini yöneten ikinci kişi" onun yerine geçer.

**Plan bozulunca kaos (klip adayları):** (1) kasa tutarken cama yoldan geçen gelir — "?" camda; (2) müşteri arkadaş "arkada var mı?" derken arka odacı içeride: sahip arka odaya yürür, ekip "ÇIK ÇIK!"; (3) sorgu anı: "Ne yapıyorsun orada?" balonu, tezgâh arkasındaki arkadaş donup kalır; (4) tutulan arkadaşı çekip kurtarma, sahip sendeler, ikisi birden kapıya; (5) çantayla koşup düşürme, mahalleli terlikle yetişir. Hepsi "görünür neden + görünür sonuç + 1-2 sn gecikme" kalıbına uyar (oyun-testi-ve-klip.md).

**Faz 2 kabul (bakkal dilimi):** sahip ajandası headless 300 sn ölçümünde ≥ 4 kasa penceresi (her ≥ 10 sn) · kasa boşaltma sahip yakın banttayken ≤ 1,0 sn'de "!" (oyuncu lehine 0,2 dahil), uzak banttan ≤ 1,8 sn, görüş hattı yokken hiç · "?" her tespitten ≥ 0,5 sn önce · bağırış → mahalleli ön kapıda ≤ 10 sn (sokak boşsa 8 sn komşu) · oyala 1. kez -40, 3. kez 0 · 2 ve 3 kişilik botla temiz tamamlama oranı farkı ≤ 15 puan (IS-015).

## 10. Senaryo üretimi

Tamamen prosedürel bina yok. Adalet elle kurulur, çeşitlilik parametreyle gelir.
- Şablon (elle): bina kabuğu, odalar, kapılar, pencereler, giriş noktaları, görüş hatları; slot taşır. Her şablonda garanti: bir gizli rota, bir sessiz yedek, bir gürültülü çıkış. T4+ şablonlarında ek olarak en az bir alternatif giriş vektörü slotu (kanal ya da zayıf duvar; tohum açar/kapatır, "öğreten" şablonda hep açık), T9+'ta kat geçişi düğümleri (§7.6, §9). Karo türleri: duvar, pencere (görüşü geçirir), raf, tezgâh, kapı, kanal (yalnız sürünme, görüşü keser), zayıf duvar (yıkılabilir), kat geçişi.
- Modül (elle, varyantlı): oda ölçeğinde prefab; kendi güvenlik düğümlerini ve kapı sözleşmesini bildirir. T8+'ta şablonlar kanatlardan birleşir (lobi + ofis + kasa).
- Tohum: slot başına modül varyantı; güvenlik yapılandırması (kamera açık/kapalı/sahte, DVR yeri, muhafız sayısı ve yazarlı waypoint grafından rota, kart sahibi, kasa tipi, kod yeri, sivil programı); ganimet yerleşimi; insider teklifi; modifikatörler; saat ve hava; keşif-soygun arası değişim.
- Doğrulayıcı (headless): muhafız görüş kapsamını zaman adımlarıyla simüle eden yol arama: bütçe içinde gizli rota var mı, gürültülü kaçış ulaşılabilir mi, çift anahtar anları fiziksel olarak mümkün mü, keşifle öğrenilebilir en az bir zamansal bilgi var mı. Geçmezse yeniden üret. Alternatif vektörler (§7.6) için ek kurallar: gizli rota garantisi ekipman gerektiren vektörlere dayanamaz (ekipmansız ekip kapıdan girebilmeli); kanal karoları görüş simülasyonunda görüşü keser ve yalnız sürünme hızıyla yürünür; zayıf duvarın iki yanı yol aramada "patlayıcı varsa bağlı" sayılır; çok katlı şablonda kat geçişi düğümleri yol aramaya girer ve kasa düşürme için üst/alt kat çifti fiziksel olarak hizalı olmalıdır.
- İçerik verisi metin tabanlı kaynaklardır (şablon, modül, eşya, perk, modifikatör, cihaz, rota, insider teklifi); kod içinde sabit içerik yoktur. AI ajan içerik varyantı üretir, doğrulayıcı eler.

## 11. Co-op ve ölçekleme

- Merkez: 3 kişi. Talepler jeneratörde akış olarak tanımlıdır; oyuncu sayısı akışları ölçekler.
- 2 kişi: çift anahtar anları sıralıya çevrilir (pencereler uzar) ya da Tech'in bir uzaktan aracı otomasyona bağlanır; muhafız/kamera -1; rol birleşmesi Ghost+Tech ("sessiz olan") + Muscle. Bot yoldaş (MVP sonrası) üçüncü eli doldurur. Bakkal (T1) 2 kişiyle tam oynanır (KR-019 K4): müşteri + hırsız; nüfus parametreleri değişmez (§9.3). Görüş paylaşılmadığı için (§6.5) 2 kişide bilgi kapsaması daha dardır (tahmin: 3 kişide ~%80, 2 kişide ~%55); dinleme ve hayalet daha çok iş görür; host 2 kişide "Çevresel 360°" kipini seçebilir — ekip paylaşımı ayarı yoktur.
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

- 2D üstten, hafif eğik "3/4" bakış. Sanatı ışık yapar: görüş konileri, üç katmanlı sis (görünen / hafıza / bilinmeyen, §6.5; Light2D değil, karo ızgarası + görüş hattı — Compatibility renderer, test edilebilirlik), neredeyse tek renk palet + tek uyarı vurgu rengi. Sis tonları `GAMEPLAY_FOG_*` her tonda aynıdır; "bulanık" alfa + doygunluk düşürmedir, blur değil.
- Karakterler prosedürel "kukla" (§14.1; KR-017); binalar tile kitleri ya da düz renk vektör geometrisi; ikonlar CC-BY oyun ikon seti; insider portreleri siluet + kod adı. Yapay zekâ üretimi görsel/ses/metin serbesttir (KR-020 3) ve kukla stiliyle çelişmez: kuklalar kodla çizilir (yapay zekâ içeriği sayılmaz), yapay zekâ üretimi yalnız statik katmanlarda (zemin/duvar dokusu, raf ürünleri, tabela, ikon, insider portresi, SFX) kullanılır; her biri `docs/notes/assetler.md`'de "AI üretimi" sütunuyla kayıtlı. Sivil kukla başlıkları: sahip önlük + kel/kasket, müşteri başlıksız (çeşit: torba, şemsiye), yoldan geçen palto, mahalleli terlik + kolu sıvalı (okunabilirlik: kim kovalıyor belli olmalı).
- Okunabilirlik önceliği: kamera konisi, muhafız bakış yönü, şüphe ölçeri ("?" ve "!"), gürültü halkası, karanlık bölge, sis katmanları ve NPC hayaleti, ekip arkadaşının bakış yayı ve "görüldü" ikonu, plan katmanı her zaman ayırt edilir. Kukla başı ve gözleri oyuncunun bakış yönünü izler (§6.5; gövde hareket yönünü) — ekip arkadaşının nereye baktığı bir bakışta okunur.
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
- Gizlilik: görüş hattı/sis, şüphe ölçeri, gürültü; T1'de gözlemciler sivildir — sahip (ajanda FSM + navigasyon), müşteriler ve yoldan geçenler (mekân nüfusu §9.2), mahalleli dalgası; uyarı eşlemesi §9.1 (bakkal: 0-3 + 5, sayaç yalnız 3'te). Muhafız FSM, kamera/DVR ve sessiz alarm T2 benzinlikle gelir; ceset saklama yok.
- Çatışma: yok; silah fiili yok (T1-T2). Yakalanma: tutulan oyuncu 6 sn içinde ekip arkadaşınca kurtarılabilir, mahalleliye yakalanan donar (K3), kalanlar kaçarsa kısmi ödeme. Sindirme T2'de (düğme penceresi), bakkalda yok.
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
4. ~~Sindirilen sivil kaç saniye "tutulmalı"; üçüncü el anı bakkalda bile gerekli mi, yoksa T2'den mi başlasın?~~ KR-020: sindirme ve üçüncü el T2'den başlar; bakkalda üçüncü el yerine "sahibin dikkatini yöneten" ikinci kişi (§9.3). Açık kalan: T2'de sindirme tutma süresi (taslak 8 sn, bırakınca çalışan düğmeye koşar).
5. Aracı oranı ekip genelinde mi, kişi başı davranışa göre mi (gürültü yapan daha az alır)?
6. Keşifte yakalanmanın bedeli: iş iptali mi, "tetikte" modu mu, ısı mı? (Taslak: tetikte + küçük ısı.)
7. Plan katmanı yanlış ikonu hiç işaretlemesin mi, yoksa nesne görüş hattına girince ikon solsun mu?
8. Host değişimi: host düşerse iş biter mi (MVP), sonradan host göçü mü?
9. Görüş kipi varsayılanı (§6.5): Yönlü (fare; öneri) mi, Çevresel 360° mi? İki kip de yapılır, host seçer; test-2'de aynı tohumla A/B: yönlü varsayılan olur eğer tercih ≥ 2/3 ∧ adalet ≥ 3,5 ∧ "?" görmeden tespit farkı ≤ 1. Çevresel bölgede canlılar: soluk siluet (öneri) / hiç / yalnız hareket edenler (v1 adayı). Ekip görüşü paylaşımı **kapalı** (kullanıcı kararı 2026-10-02, soru değil).
