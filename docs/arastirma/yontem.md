# Ürün geliştirme yöntemi: küçük ekip + yapay zekâ ajanlarıyla oyun (2026-10-02)

Araştırma notu; bağlayıcı değil (kararlar.md günlüğü 2026-10-02). Koordinatör bulguları ON/kalem/KR'ye çevirir.
İşaretler: **[O]** olgu (kaynaklı; numara sondaki listeye) · **[G]** görüş/öneri (bu notun yorumu).

## Özet
- [O] Prototip "yapmalı mıyız?", dikey dilim "yapabilir miyiz?" sorusunu yanıtlar; prototip hızlı, kirli ve atılabilir olmalı [1].
- [G] Bizim en büyük riskimiz teknik değil, eğlence: hafızaya dayalı keşif + plan masası (oyunun özgün iddiası) Faz 3'te, ilk gerçek oyun testi Faz 2 sonunda. Kod ajanlarla günler içinde çıkıyor (Faz 1 ≈ 3 gün); darboğaz artık **insan testi ve his kararı**.
- [O] Arkadaşlarla co-op testinde oyuncular daha kolay heyecanlanır ama daha çabuk sıkılır, öldüklerinde farklı yol denemezler [10]. [G] Arkadaş grubu nazik ve önyargılıdır; anket yerine **davranış** (kendiliğinden "bir tur daha", gönüllü koşu sayısı, kahkaha/klip anı) ölçülmeli.
- [O] Yapay zekâ kodlamada: ajanın işini doğrulayabileceği bir kontrol ve işi yapandan bağımsız ikinci göz önerilir [14]; uzun koşan ajanlar erken "bitti" der, uçtan uca test etmeden özellik kapatır [15]. [G] Denetci + çürütmeli inceleme düzenimiz bu en iyi uygulamalarla örtüşüyor; güçlü yanımız.
- [O] Yapay zekâ mevcut düzeni büyütür (iyi süreçte fayda, dağınık süreçte zarar) [17]; hız arttıkça ekibin sistemi anlama payı düşer ("bilişsel borç") [18][19]. [G] Tek kullanıcının kod tabanını anlamayı kaybetmesi orta vadeli risk; faz başına "mimari tur" ve otomatik mimari kurallar (bağımlılık testi gibi) sürmeli.
- [O] Steam (Ocak 2026): oyunda/mağaza sayfasında/pazarlamada yapay zekâ üretimi içerik ve oyun sırasında üretilen içerik bildirilir; kod yardımcıları gibi geliştirme araçları muaf [20]. [O] GDC 2026 anketinde geliştiricilerin %52'si üretken yapay zekâyı sektöre zararlı görüyor [21]. [G] Oyuncuya görünen içerikte yapay zekâ üretimini sınırlı tut, kullanırsan kaydını şimdiden tut.
- [G] Beş somut değişiklik (§8): Faz 2'yi böl (2a çirkin dilim + hemen test), keşif riskini kağıt/ucuz prototiple şimdi sına, düzenli test ritmi + telemetri, prototip şeridi + his turu, bilişsel borç ve yapay zekâ içerik kaydı.

## 1. "Eğlenceyi bul": prototip, gri kutu, dikey dilim
- [O] Prototipler küçük, dağınık ve izole; her büyük belirsizlik (mekanik, görsel, ses) için ayrı prototip; prototip kodu/içeriği sonra kullanılmaz; prototipi mükemmelleştirmek ve dikey dilimi "ileri prototip" sanmak tuzaktır [1].
- [O] Valve'ın Half-Life sürecinde düzlem dokular ve geçici kodla erken oynanabilir hâle gelip test edildi [5]. Monaco (2D üstten co-op soygun) 6 haftalık tek kişilik çalışmayla IGF büyük ödülü aldı; tasarım hızlı yinelemeyle bulundu [11].
- [O] Peak, iki stüdyonun bir aylık oyun şenliğinde yapıldı ve ilk haftalarda milyonlar sattı [9]; Lethal Company'nin "korkunç-komik" anları yakınlık sesli sohbeti ve işe yaramaz eşyalar gibi sistemlerden doğuyor [10].
- [G] Bizim için çıkarım: gri kutu (geometrik yer tutucu, KR-012) doğru; ama bakkal soygununun tamamı (muhafız, kamera, sivil, kukla, bot, Steam spike) bitmeden ilk test yapılmamalı **değil**. "En çirkin oynanabilir soygun" (1 muhafız + koni + şüphe + kasa + kaçış + kazan/kaybet) ilk sorudur: "Yakalanmamaya çalışırken birlikte soymak, gri kutuda bile gergin ve komik mi?"
- [G] Co-op/"friendslop" türünde eğlenceyi sistemlerin çarpışması (plan bozulması, birinin hatası, panik) üretir; bunu ancak gerçek insanlar ortaya çıkarır. Bot/ajan testleri (GB-01) denge ve regresyon içindir, eğlence kapısı yerine geçmez.

## 2. Çok oyunculu oyunda erken oyun testi
**Ne ölçülür** ([G], [3][4][6]'daki genel ilkelerden uyarlandı)
| Ölçü | Nasıl | Neden |
|---|---|---|
| Kendiliğinden tekrar isteği | Koşu bitince kim, sorulmadan "bir daha" dedi; gönüllü koşu sayısı | Ankette "tekrar oynar mısın" nezaketle şişer |
| Klip/kaos anı | Gözlemci zaman damgalı işaretler: kahkaha, bağırış, "gördün mü?!" | Co-op'un satış anı; paylaşılabilirlik |
| Plan bozulma anı | Konuşulan planın sapması + ekibin tepkisi | Oyunun vaadi (GDD §1) |
| Ölü zaman | Bir oyuncunun ≥ 30 sn anlamlı eylemsiz kalması | Co-op'ta "boş bekleyen" en hızlı sıkılandır |
| Kafa karışıklığı | "Neden gördü?", "Ne yapacağım?" soruları | Okunabilirlik/geri bildirim eksiği, eğlence eksiği sanılmasın |
| Oturum süresi ve koşu süresi | Telemetri | GDD hedefi (bakkal 3-5 dk) |
| İletişim yoğunluğu | Sesli konuşma sıklığı, işaretleme | Ortak oyunun canlılığı |
- [O] Oyuncuyu bilgilendirmeden, müdahale etmeden sessizce gözlemle; ilk testçi oyun hakkında bir şey bilmemeli [4][5]. Oyun testi bir deneydir: hipotezi önceden yaz [10].
- [O] Sean Ellis sorusu ("artık kullanamasan ne hissederdin?"; ≥ %40 "çok üzülürdüm" eşiği) ürün uyumu için kullanılıyor [24]. [G] Oyunda 3-6 kişiyle istatistik değil sinyal verir; yalnız eğilim olarak kullan.
- [O] GDC 2026'da çok küçük ekipler için hafif, tekrarlanabilir test süreci anlatıldı (doğru testçi, odaklı oturum, oyuncuyu anlamlı tepkiye hazırlama, eyleme dönük bulgu) [3]. (Yalnız oturum özeti okunabildi.)
- [G] Aynı 3 arkadaş birkaç testten sonra "kirlenir" (oyunu bilir, nazik davranır). Faz 3'ten itibaren her testte en az 1 yeni kişi (arkadaşın arkadaşı) olmalı.

**Notları tasarıma çevirme** ([G])
1. Gözlem ile öneriyi ayır: oyuncunun dile getirdiği sorun genelde gerçektir, önerdiği çözüm çoğu zaman değildir. GB satırında "ne oldu" ve "oyuncu ne önerdi" ayrı sütun.
2. Her bulguya sıklık (kaç oyuncu/koşu) × şiddet (eğlenceyi öldürür / sinir bozar / kozmetik) ver; yalnız "öldürür" ve 2+ kez görülen "sinir bozar" kaleme döner.
3. Fable bulguları ON'a çevirir (surec §5a (3) zaten var); koordinatör en fazla 3 değişiklik seçer, bir sonraki test bunları hipotez olarak sınar.
4. "Kill your darlings": iki testte de ilgi görmeyen mekanik (ör. plan masasında kullanılmayan ikon türleri) kesilir ya da P3'e iner; kesme kararı kararlar.md'ye yazılır.

## 3. Kapsam, risk-önce plan, tükenmişlik, 2 kişiyle test
- [O] Derek Yu'nun iki "ölüm döngüsü": sürekli baştan yazmak (yanlara büyümek) ve sonsuz cilalama; öneri: bitmiş işlere göre kapsam, cilayı sona bırak, geri bildirimi dürüst oku [7].
- [G] Risk-önce sıralama: en yüksek belirsizlik × en yüksek bedel önce. Bizde sıra: (1) gizlilik gri kutuda eğlenceli mi, (2) hafızaya dayalı keşif sinir bozucu değil keyifli mi, (3) TR↔SE ağ, (4) Steam. (3) Faz 1'de büyük ölçüde ölçüldü; (2) hiç sınanmadı ve Faz 3'e kadar bekliyor — en büyük açık.
- [O] Co-op oyunlar çoğu zaman "ideal" oyuncu sayısında iyi oynanır; 2 kişide işbirliği dinamiği değişir, oyuncular bağımsız çalışmaya kayar; her seviye tasarımında "her oyuncu sayısında çalışır mı?" diye sormak önerilir [8].
- [G] KR-002 (2 İsveç + 1 Türkiye): 3 kişiyi aynı saatte toplamak testin asıl darboğazı olacak. GDD §11'deki 2 kişilik ölçekleme kuralları Faz 2'de en az bir kez gerçek 2 kişiyle denenmeli; "3 kişi toplanamadı" testi iptal ettirmesin.
- [G] Tükenmişlik: kod yükü ajanlarda, ama karar, test organizasyonu ve "his" kullanıcıda. Rapor seli (kalem başına rapor) tek kişiyi yorar; haftalık tek özet + yalnız kullanıcı kararı gereken maddeler önerilir. Faz sonu durma noktasının askıya alınması (2026-10-02) hızı artırır ama "oyun testi olmadan faz atlama" riskini doğurur: test kapısı askıya alınmamalı.

## 4. Yapay zekâ ajanlarıyla kalite
- [O] Anthropic önerileri: ajana koşabileceği kontrol ver (test, build, ekran görüntüsü); başarıyı iddia değil kanıtla göster; işi yapandan bağımsız taze bağlamlı inceleyici; inceleyici bulgu bulmaya zorlandığında her şeyi kovalamak aşırı mühendisliğe götürür — yalnız doğruluk/şartı etkileyen bulguları işaretlet; CLAUDE.md kısa tut, kesin kurallar için hook kullan [14].
- [O] Uzun koşan ajan düzeneğinde görülen hatalar: erken "bitti", uçtan uca test olmadan özellik kapatma, her şeyi tek seferde yapma, belgesiz devir; çözümler: yapılandırılmış özellik listesi, oturum başında temel uçtan uca test, ilerleme dosyası, testleri silmeyi yasaklamak [15].
- [O] METR (2025) deneyinde deneyimli geliştiriciler yapay zekâyla %19 daha yavaş çalıştı ama %20 hızlandıklarını sandı [16]. DORA 2025: kullanım %90, yüksek güven %3 düzeyinde; yapay zekâ "yükseltici" [17].
- [O] Bilişsel borç: uygulama ile ekibin "nasıl ve neden çalışır" anlayışı arasındaki açı; önlem: ajan çıktısına geri besleme sensörleri, ekip bilişsel yükünü izlemek, mimari uygunluk fonksiyonları (otomatik kural testleri) [18]; tek bir incelemenin yakalamadığı yavaş mimari sürüklenme [19].
- [G] Bizde iyi olanlar: AC'ler komut çıktısıyla, denetci sıfırdan tekrar, ağ kodunda çürütmeli inceleme, 0/150 ms senaryoları, bağımlılık yönü testi (IS-010), sözleşmeler önce dokümanda. Eksik: (a) **testin testi**: ajanın beklentiyi gevşetmesine karşı kural (US-005 t2'de beklentiler zaman bağımsızlaştırıldı — doğru, ama "test silme/gevşetme" denetci kontrol listesinde açık madde olmalı); (b) **görsel/his doğrulaması** headless'ta yok (Xvfb ekran görüntüsü aracı Faz 2 backlog'unda; öne alınmalı); (c) kullanıcının kod anlayışı ölçülmüyor.
- **İnsanda kalmalı** ([G]): eğlence kapısı kararı; oyun hissi (hız, ivme, süreler, kamera) son ayarı; sanat yönü ve ton (KR-005, KR-017 zaten kullanıcıdan); ses kimliği (alarm, adım, müzik gerilimi); kesme kararları; para/hesap. Ajanlar seçenek üretir, sayıları önerir, insan oynayıp seçer.
- **Yapay zekâ içerik ve Steam** ([O] [20]): bildirilecekler — geliştirmede üretilip oyunda/mağaza sayfasında/pazarlamada yer alan içerik ve oyun sırasında üretilen içerik; kod yardımcıları muaf. [G] Kod (Claude) bildirim gerektirmez; prosedürel kukla (KR-017) kodla çizildiği için yapay zekâ "içeriği" sayılmaz. Görsel/ses/metin için yapay zekâ kullanılırsa `assetler.md`'ye "kaynak: AI (araç, tarih, nerede)" satırı; Faz 5'te bildirim metni buradan yazılır.

## 5. Oyun hissi ve yer tutucudan gerçeğe geçiş
- [O] Swink oyun hissini girdi → tepki → bağlam → cila katmanlarında ele alır [12]. "Juice it or lose it" (Jonasson & Purho, GDC Europe 2012) ve Vlambeer'in "Art of Screenshake" konuşması aynı prototipe geri bildirim efektleri eklemenin algıyı nasıl değiştirdiğini gösterir (konuşma adları; video URL'leri bu notta doğrulanmadı).
- [G] İki ayrı şey: **okunabilirlik/geri bildirim** (oyuncu neden görüldüğünü anlar: "?" "!" balonu, şüphe ölçeri, gürültü halkası, 5-6 temel SFX) ilk testten **önce** şart — yoksa test eğlenceyi değil bilgisizliği ölçer. **Cila/juice** (sarsıntı, parçacık, kukla ikincil hareketleri) eğlence kapısından **sonra**; ama bir "minimum his paketi" (kalkış/duruş yumuşatma, adım sesi, yakalanma anı vurgusu) 2a'ya girer.
- [G] Gerçek görsel/sese geçiş zamanı: çekirdek döngü iki testte "tekrar" aldıktan sonra (bizde Faz 3 kapanışı). KR-012'deki CC0 geçişi Faz 4 için uygun; ama **ses** erken etkilidir (gizlilikte duyulabilirlik oyun bilgisidir, GDD §14) — CC0 SFX Faz 2a'da.
- [G] His ayarı insan işi: `data/*.tres` değerlerini oyun içinde canlı değiştiren bir hata ayıklama paneli (yalnız dev build) kullanıcıya 30 dk'da ajanlara günlerce anlatamayacağı bilgiyi verir.

## 6. Topluluğu erken kurmak (kısa; ayrıntı pazarlama araştırmasında)
- [O] Zukowski: Steam sayfasını paylaşacak bir şey olduğu anda aç, viral an sayfasız boşa gider; Discord sadık çekirdek kitlenin yeri [23]. Steam Playtest: ayrı alt uygulama kimliği, istek kuyruğu, istek listesiyle yarışmaz [22] (Steamworks hesabı gerekir — KR-014).
- [G] Sıra: Faz 2'de kapalı küçük Discord (testçiler + arkadaşların arkadaşları; build kanalı, geri bildirim kanalı, klip kanalı). Faz 3'te ilk GIF/kısa video devlog (plan bozulma anı). Steam sayfası ve Playtest için KR-014'ün öne çekilmesi kullanıcıya sorulmalı.

## 7. Mevcut sürecin eleştirisi (surec.md, ajanlar.md, backlog §1)
**Güçlü** ([G]): ölçülebilir faz çıkış kriterleri; bağımsız denetim + çürütme (Anthropic önerisiyle örtüşür [14]); erken Steam riski ölçümü (IS-004) ve Faz 1'de arkadaşa build; kararların tek yerde izi; sözleşme-önce mimari; Fable değerlendirmeleri; GB→kalem bağlama kuralı; bot/ajan test fikirleri (GB-01).
**Eksikler** ([G]):
1. **Oyun testi geç ve seyrek.** İlk eğlence kapısı Faz 2'nin sonunda; Faz 2 kapsamı çok geniş (muhafız, kamera, sivil, kilit, kukla, bot, replay, Steam spike...). Test faz sonuna bağlı; hız günler mertebesindeyken bu, testsiz çok iş demek.
2. **Özgün iddia en geç sınanıyor.** Hafızaya dayalı keşif Faz 3'te; "ucuz keşif ön testi" Faz 2 listesinin içinde kaybolmuş.
3. **His sahibi yok.** Kalite katmanları doğruluğu ölçüyor; "his" yalnız IS-006 gibi doğrulama kalemlerinde, Fable ise oynayamıyor. His turu ve canlı ayar aracı yok.
4. **Süreç ağırlığı deneyi boğabilir.** Her şey DoR/denetci/commit hattından geçiyor; atılabilir prototip için hafif şerit yok.
5. **Ölçüm anketin "tekrar" cevabına dayalı** (≥ 2/3). Küçük ve nazik örnek; davranış ölçüsü ve telemetri tanımlı değil.
6. **İçerik üretim hattı tanımsız:** ses (Faz 2 SFX'in sahibi yok), CC0 seçimi, yapay zekâ içerik kaydı, seviye şablonu üretimi (Faz 3) — "kim, hangi araçla, hangi lisansla" yok.
7. **Bilişsel borç:** kullanıcı her kalemin kodunu okumuyor; mimari.md uzadıkça kimse bütünü bilmeyebilir.

## 8. Somut öneriler (faz planına etkisiyle)
| # | Ne | Neden | Maliyet | Faz etkisi |
|---|---|---|---|---|
| 1 | **Faz 2'yi böl: 2a "çirkin dilim"** = 1 muhafız (devriye) + görüş konisi + şüphe ölçeri + "?"/"!" + kasa + çanta + kaçış + kazan/kaybet + iş sonu (ham) + 5-6 CC0 SFX + minimum his; **hemen oyun testi** (2 ya da 3 kişi). **2b** = kamera, sivil/sindirme, T1 kilit, kukla v0, botlar, replay, Steam spike | Eğlence sinyali haftalar değil günler içinde; 2b kapsamı test bulgusuna göre budanır | Planlama ~1 saat; kod sırası değişir, ek iş yok | EP-02 çıkış kriterlerine "2a testi yapıldı, GB'ler bağlandı" eklenir |
| 2 | **Keşif ön testi şimdi** (2a ile paralel, kodsuz ya da çok ucuz): bakkalın 60 sn videosu/görüntüsü → oyuncular hafızadan ortak krokiye (Excalidraw/Discord) işaret koyar → doğruluk ve "zevkli miydi" konuşması. Sonra 2a'da gerçek seviyede "dışarıdan bak, sonra soy" varyantı | Oyunun özgün iddiası en büyük ve hiç sınanmamış risk; Faz 3 tasarımı bu veriye dayanır | 20-30 dk arkadaş oturumu; Fable senaryoyu hazırlar | Faz 3 kapsamı test sonucuna göre (ör. işaretleme yardımı, süre) |
| 3 | **Sabit oyun testi ritmi + protokol (§9) + telemetri**: faz sonuna bağlı değil, 1-2 haftada bir sabit saat; host her koşuda JSON döker (süre, tespitler, uyarı zaman çizelgesi, ganimet, oyuncular arası mesafe, ölü zaman) | Davranış ölçüsü nazik ankete üstün; ajan hızına insan geri bildirimi yetişir | Telemetri: cekirdek S kalemi (döküm altyapısı var); oturum başına ~1 saat kullanıcı | EP-02/03 kriterlerinde "tekrar" ölçüsü davranışa çevrilir |
| 4 | **Prototip şeridi + his turu**: `proto/<konu>` dalı, DoR/denetci yok, birleşmez, sonuç GB/KR'ye; her fazda kullanıcı sahipli "his turu" kalemi + dev build'de canlı ayar paneli (`.tres` değerleri) | His ve deney insan + hız ister; ana hattın kalitesi bozulmaz | Panel: arayuz S kalemi; şerit kuralı surec.md'ye 3 satır | Her fazda 1 his kalemi (kullanıcı) |
| 5 | **Bilişsel borç ve içerik kaydı**: faz kapanışında koordinatör 1 sayfalık "mimari tur" (ne değişti, neden, nereye bakılır) + kullanıcıyla 15 dk soru-cevap; denetci listesine "test silindi/gevşetildi mi" maddesi; Xvfb ekran görüntüsü aracı 2a'ya; `assetler.md` şimdiden açılır, yapay zekâ ve CC0 kaynağı satır satır | Uzun vadede tek kişinin sistemi anlaması ve Steam bildirimi | Faz başına ~1 saat; araç S kalemi | Faz 2'den itibaren kapanış adımı |
Ek (P2-P3): 2 kişilik ölçeklemeyi Faz 2b'de test et (GDD §11); Faz 3'ten itibaren her testte 1 yeni testçi; kapalı Discord Faz 2; haftalık kullanıcı özeti (kalem başına rapor yerine).

## 9. Faz 2 oyun testi protokolü (taslak)
**Hazırlık (T-2 gün → T-0)**
- Hipotezler yazılı (≤ 3; ör. "H1: oyuncu neden görüldüğünü %80 anlar", "H2: her koşuda ≥ 1 plan bozulma anı", "H3: ilk koşudan sonra kendiliğinden tekrar isteği").
- Build: Windows zip, sürüm etiketi; her makinede açılış + Tailscale/bağlantı denemesi 1 gün önce (5 dk). Ping ölçümü kaydedilir.
- Telemetri açık; host'ta OBS kaydı (oyun + Discord sesi) — **kayıt için herkesten önceden açık izin**; kayıt yalnız ekip içinde kalır.
- Gözlem formu açık; kullanıcı en az bir koşuda **oyuncu değil gözlemci** (oyunu bilen oyuncu yönlendirir, veri bozulur).
- Anket formu hazır (çevrimiçi, bireysel).
**Oturum akışı (~60-75 dk)**
1. 3 dk brifing: yalnız tuşlar ve amaç ("kasayı al, yakalanmadan çık"). Muhafız kurallarını anlatma.
2. Koşu 1 (yardım yok; sorulara "sence?" cevabı). Gözlemci not alır.
3. Koşu 2-3: ekip isterse; isteyip istemedikleri ölçüdür. Koşular arası soru sorma, yalnız dinle.
4. Kendiliğinden "bir daha" anı: kim, kaçıncı koşudan sonra — not et. Sonrasında serbest oyun.
5. 10 dk grup sohbeti: "Ne oldu?" (anlatı), "En iyi an?", "En kötü an?". Çözüm tartışmasına girme.
6. 24 saat içinde bireysel anket (grup etkisini azaltır).
**Gözlem formu (koşu başına satır satır)**
| Zaman | Oyuncu | Tür (K=karışıklık, G=gülme/klip, P=plan bozulma, S=sinir, Ö=ölü zaman, T=teknik) | Ne oldu (gözlem) | Söylenen (kısa) |
Koşu sonu: süre · sonuç (kaçış/yakalanma/terk) · tespit sayısı · klip anı sayısı · tekrar isteği (kim/kendiliğinden mi) · teknik sorun (kopma, takılma).
**Anket (8 soru)**
1. Bu soygunu bir arkadaşına tek cümleyle nasıl anlatırsın? (açık)
2. Aklında kalan en iyi an neydi? (açık)
3. En kafa karıştıran ya da sinir bozan an neydi? (açık)
4. Muhafız seni ya da ekibi fark ettiğinde nedenini anladın mı? (Her zaman / Çoğu zaman / Bazen / Hiç)
5. Ekipte kendini gereksiz ya da boşta hissettiğin an oldu mu? Ne zaman? (Evet-açık / Hayır)
6. Ekip yarın "bir tur daha" dese? (Kesin katılırım / Büyük ihtimalle / Emin değilim / Muhtemelen hayır)
7. Bu oyunu bir daha hiç oynayamasan ne hissederdin? (Çok üzülürdüm / Biraz üzülürdüm / Fark etmezdi) — eğilim, istatistik değil [24]
8. Bir şeyi değiştirebilseydin ne olurdu? (açık; öneri olarak kaydedilir, gözlemden ayrı)
**Sonrası:** 48 saat içinde GB-nn satırları (gözlem ve öneri ayrı), sıklık × şiddet, Fable değerlendirmesi (§5a (3)), en fazla 3 değişiklik → sonraki testin hipotezi.
**Faz 2 kapısı önerisi ([G], mevcut "≥ 2/3 tekrar" yerine/yanında):** 3 oturumun ≥ 2'sinde kendiliğinden tekrar isteği · koşu başına ortalama ≥ 1 klip/plan bozulma anı · soru 4'te "Bazen/Hiç" ≤ 1 kişi · ölü zaman koşunun ≤ %15'i · çökme/kopma 0.

## 10. Kullanıcıya sorulacaklar (koordinatöre öneri)
1. Faz 2'nin 2a/2b diye bölünmesi ve ilk testin 2a sonunda (gerekirse 2 kişiyle) yapılması?
2. Testlerde sen oyuncu musun, gözlemci mi? (Öneri: en az bir koşuda gözlemci.) 3 arkadaş + sen = 4 kişi mi?
3. Arkadaşlardan ekran/ses kaydı izni ve 1-2 haftada bir sabit test saati (TR-SE saat farkı) mümkün mü?
4. Kodsuz keşif ön testi için 20-30 dk ayrılabilir mi (bu hafta)?
5. Oyuncuya görünen görsel/ses/metinde yapay zekâ üretimi kullanılsın mı? (Öneri: hayır ya da sınırlı; kullanılırsa kayıt + Steam bildirimi.)
6. Kapalı Discord (Faz 2) ve Steam sayfası/Playtest için KR-014'ün öne çekilmesi?
7. Kalem başına rapor yerine haftalık tek özet ister misin?

## Kaynaklar
1. Rami Ismail, "Prototypes & Vertical Slice" — https://ltpf.ramiismail.com/prototypes-and-vertical-slice/
2. GDC Vault: G. Donovan, "The Vertical Slice Challenge" — https://gdcvault.com/play/1022328/contactUs · K. Santiago, "Prototyping for Innovation" — https://gdcvault.com/play/1021659/contactUs
3. B. Cronin, "Playtesting Process for Ultra-Small Teams", GDC 2026 (slaytlar) — https://media.gdcvault.com/gdc2026/Slides/Cronin_Brian_PlaytestingProcessForUltraSmallTeams.pdf
4. G. McAllister, "Implementing an In-House Playtesting Process" — https://gdcvault.com/play/1016497/Implementing-an-In-House-Playtesting
5. Valve Cabal süreci — https://developer.valvesoftware.com/wiki/Cabal_process
6. S. Bromley, Games User Research / Playtest Kit — https://gamesuserresearch.com/about/ · https://stevebromley.gumroad.com/l/playtest
7. Derek Yu, "Death Loops" — https://www.derekyu.com/makegames/deathloops.html
8. Pandaqi, "A game for 1-4 players, or is it?" — https://pandaqi.itch.io/package-party/devlog/105422/15-a-game-for-1-4-players-or-is-it
9. Peak — https://en.wikipedia.org/wiki/Peak_(video_game) · https://www.inverse.com/gaming/peak-steam-landcrab-friendslop-update-interview-nick-kaman-pc
10. Co-op test, hipotezli test ve Lethal Company — https://filmstories.co.uk/?p=83402 (çok oyunculu test) · https://filmstories.co.uk/features/how-to-playtest-your-game-on-a-budget/ · https://tabletop.events/conventions/protospiel-indy-2026/pages/how-to-playtest · https://gameindustrylibrary.com/documents/pushtotalk-how-lethal-company-sold-10-million-copies
11. A. Schatz, "How to Win the IGF in 15 Weeks or Less" (Monaco) — https://gdcvault.com/play/1014072/How-to-Win-the-IGF
12. S. Swink, *Game Feel* (inceleme) — https://lizengland.com/blog/review-game-feel-by-steve-swink/
13. Juice / screenshake konuşmaları (bağlam) — https://amara.org/v/C3BGA
14. Claude Code best practices — https://code.claude.com/docs/en/best-practices
15. Anthropic, "Effective harnesses for long-running agents" (2025-11-26) — https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
16. METR 2025 deneyi (özet) — https://simonwillison.net/2025/Jul/12/ai-open-source-productivity/
17. DORA 2025 — https://blog.google/technology/developers/dora-report-2025/
18. Thoughtworks Radar Vol. 34, "Codebase cognitive debt" (2026-04) — https://www.thoughtworks.com/radar/techniques/codebase-cognitive-debt
19. "Agentic entropy" (arXiv 2604.16323) — https://arxiv.org/pdf/2604.16323
20. Steam yapay zekâ bildirimi yeniden yazımı (2026-01) — https://www.videogameschronicle.com/news/valve-has-significantly-rewritten-steams-rules-for-how-developers-much-disclose-ai-use
21. GDC 2026 State of the Game Industry — https://gdconf.com/article/gdc-2026-state-of-the-game-industry-reveals-impact-of-layoffs-generative-ai-and-more/
22. Steamworks Playtest — https://partner.steamgames.com/doc/features/playtest
23. C. Zukowski — https://howtomarketagame.com/ · https://gameworldobserver.com/2025/03/11/steam-page-launch-guide-wishlists-zukowski
24. Sean Ellis testi — https://learningloop.io/plays/product-market-fit-survey
