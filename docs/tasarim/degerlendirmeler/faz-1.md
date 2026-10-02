# Faz 1 tasarım değerlendirmesi — "İki kişi bakkalda" (IS-007 B)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil (surec.md §5a; KR-016).
Girdi: GDD v0.3; Faz 1 kalemleri US-001..005, IS-005, IS-008..014, IS-019 ve KR-018..021; `data/player_tuning.tres`, `data/props/{register,door}.tres`, `core/interaction_rules.gd`, `entities/player/*.gd`, `entities/props/*.gd`, `levels/layouts/store_a.txt`; IS-013 ölçümleri (store_walk 150 ms en kötü fark 28/32 ve 37-44/48 px; sert ağ 150 + 30 jitter + %1 kayıp: store_walk 6/6, faz1_full 3/6-5/10, sonuç gecikmesi 360-617 ms, senkron 55-66 px; kasa sonucu istemcide ~80-90 ms, isteyene RTT + ~170 ms; 10 dk soak hatasız, bellek +5 MB); IS-022 ekran görüntüleri (store_walk host/c1/c2); IS-026 (HUD ping yerelde 106-160 ms).
Varsayım: oyun oynanmadı; "his" yargıları sayılara, kod akışına ve ekran görüntülerine dayanır. İnsan testi (IS-006, test-1) henüz yok; aşağıdaki test-1 bölümü o boşluğu kapatmak içindir.

## Uyum özeti

Faz 1 hedefi "online his: bağlan, yürü, kasayı boşalt" GDD'ye uygun kuruldu:
- Hareket kipleri GDD §6.1 ile birebir (sızma 70 / yürüme 140 / koşma 220 px/sn; 1 karo 32 px, gövde 24 px). İvme 1400, fren 2000 px/sn² → yürümeye 0,10 sn, koşuya 0,16 sn, durmaya 0,07-0,11 sn: mantık "anında" sınıfında, doğru tercih (yumuşaklık kuklaya, KR-017, bırakılmış).
- Etkileşim: kasa 3 sn tut, +150, yalnız personel tarafı (GDD §9 T1 satırı); kapı anlık; menzil 40 px. Host payları (menzil +24 px, taraf 24 px, süre +0,25 sn) GDD §12 "gecikme oyuncu lehine" ilkesini uyguluyor; müşteri tarafı yine reddediliyor (−26 px'e karşı −8 eşik).
- Ağ: istemci yetkili hareket + 100 ms tampon + 20 Hz; 150 ms'de senkron farkı < 1 karo (çıkış kriteri 2 sağlandı; 28/32 ile sınıra yakın). Kasa sonucu temiz 150 ms'de RTT + 200 içinde (kriter 3). 10 dk soak temiz (kriter 4). Build iki platform (kriter 5).
- Bakkal yerleşimi (store_a.txt) §9.3 ile uyumlu: tezgâh doğuda, kasa tezgâhın güney ucunda, tezgâhtar noktası kasanın 1 karo doğusunda, arka oda kapısı 3 karo kuzeyde ve tezgâhtar konisinin dışında; raf koridorları 1 karo; ön cam geniş (7 + 4 karo), doğu duvarında 2 karo cam; iki rota (ön kapı → tezgâh ucu, arka kapı → arka oda → iç kapı). Kaçış noktası güneydoğu köşede (ön kapıdan ~20 karo ≈ 2,9 sn koşu).
- Sapma sayılmayan eksikler: T1 kilit, gürültü, çanta, sahip (hepsi KR-015 ile Faz 2'ye kesildi).

## Sapmalar (oyun zevkini/mekaniği tam karşılamayan; kanıt + öneri)

**S1 — Kamera ve çerçeve: harita gri boşlukta yüzüyor, oyuncu 1280 px'lik ekranda 24 px.** Kanıt: ekran görüntülerinde harita (30×20 karo = 960×640 px) `camera_zoom` 1,0 ile viewport'a (1280×720) tamamen sığıyor; kamera oyuncuyu izlediği için harita kayıyor ve kenarlarda gri (#4d4d4d) boşluk kalıyor; kasa 16×10 px yeşil kutu, kapılar 2 px çizgi. GDD §14 "okunabilirlik önceliği" ve §14.1 kural 2 (oyun bilgisi işaretleri ≥ 22 px) sağlanmıyor. Öneri: ON-1 (yakınlaştırma 1,5 + harita sınırına kenetleme) ve ON-7 (temizleme rengi).

**S2 — Kasa sonucunun görünme gecikmesi oyuncuya "oldu mu?" sorduracak.** Kanıt: yerel çubuk 3,0 sn'de dolar; host sonucu isteyene RTT + ~170 ms'de döner (150 ms'de ≈ 320 ms, gerçek 50-90 ms RTT'de ≈ 220-260 ms); sert ağda 360-617 ms. GDD §12 "ilerleme yerelde gösterilir, host onaylar" uygulanmış ama onay anına kadar ekranda hiçbir şey olmuyor (HUD yalnız `interaction_finished` ve `team_cash_changed` dinliyor). Öneri: ON-2 (iki aşamalı geri bildirim).

**S3 — Sert ağ profilinde senkron 55-66 px (2 karo) ve sonuç 0,6 sn: Faz 1'de "yalnız ölçüm" kabul edildi, ama Faz 2'nin tutma/yakalama kuralları bu payla çakışıyor.** Kanıt: §9.3 sahip tutması 28 px + 0,5 sn temas, mahalleli 200 px/sn vs koşu 220 (fark 20 px/sn); host koşan oyuncuyu temiz ağda 22-38 px, kayıpta 55-66 px geride görür → host "yakaladı" derken oyuncu ekranında 1-2 karo öndedir. GDD §12 "beni görmemişti" türü şikâyet tasarım hatasıdır. Öneri: ON-3 (yakalamada ileri tahmin) ve ON-4 (şüphe durumunu sürekli çoğaltma).

**S4 — HUD ping güvenilmez; test-1'de "lag" algısını şişirir.** Kanıt: IS-026 (yerel pencerede 106-160 ms); ekran görüntülerinde 150 ms proxy altında c1 123 ms, c2 202 ms. Arkadaşlar sayıya bakıp "gecikme var" diyecek, his yerine gösterge ölçülecek. Öneri: ON-5.

**S5 — Yerel oyuncu ve etkileşim hedefleri görsel olarak vurgulanmıyor; ekip paneli haritayı örtüyor.** Kanıt: üç daire aynı ağırlıkta; "sen" yalnız panel metninde; hedefe yaklaşınca nesne üstünde işaret yok (istem yalnız HUD'da); panel NE köşede haritanın üstünde (US-013'e not düşülmüş). Öneri: ON-6.

## Mekanik iyileştirmeleri (ON adayları; etki/maliyet; faz)

- **ON-1 Kamera yakınlaştırma 1,5 (görüş 853×480 px ≈ 27×15 karo, gövde 36 px) + harita sınırına kenetleme (IS-025 kapsamı).** Etki orta / maliyet düşük (`camera_zoom` zaten `.tres`'te) / Faz 1 kapanışı-2a. Neden: okunurluk ve "dünyanın içinde olma" hissi; harita bütünü yine ~1 ekranda. Risk: T1'de tam harita görünürlüğü (Monaco hissi) kaybolur; test-1'de 1,0 ve 1,5 arka arkaya denenebilir (kullanıcı kararı).
- **ON-2 Kasa için iki aşamalı geri bildirim: yerel çubuk dolunca anında "klik" sesi + çubuk yeşile döner (host onayı bekleniyor), host onayıyla nakit sayacı + kasa boş görseli; onay 1 sn gelmezse çubuk sıfırlanır.** Etki orta / maliyet düşük (HUD + IS-024 SFX; yeni ağ yok) / 2a. Neden: 0,25-0,6 sn boşluğu maskeler; şüphe ölçerine ("?"→"!") aynı kalıp uygulanır. Risk: host reddederse (menzil dışı) "yeşil çubuk sonra kaybolur" — nadir, reddi görünür kıl.
- **ON-3 Yakalama/tutma kararında oyuncu lehine ileri tahmin: host, hedefin konumunu `velocity × min(RTT/2, 0,1 sn)` ileri taşır; 28 px temas bu konumla ölçülür; 0,5 sn pencere korunur.** Etki yüksek (adalet) / maliyet düşük (core kuralı, birim test) / 2a (US-008 AC'si). Neden: S3. Risk: hile değil (oyuncu hızı zaten istemci yetkili); aşırı pay yakalamayı 1 karo zorlaştırır → chaser 200 kalır.
- **ON-4 Şüphe ölçeri (0-100) olay değil sürekli durum olarak 15 Hz güvenilmez çoğaltılsın; "?" (30) ve "!" (100) balonları istemcide eşikten türesin; yalnız sonuç (uyarı kademesi, tutuldu) güvenilir RPC.** Etki yüksek / maliyet düşük-orta (US-006/US-008 sözleşmesi) / 2a. Neden: %1 kayıpta güvenilir olay 1 RTT geç gelir (ölçülen 0,36-0,62 sn), "?"→tespit penceresi 0,56 sn → balon tespitle aynı anda gelir. Risk: kayıp karede balon 66 ms geç; kabul edilebilir.
- **ON-5 Ping göstergesi: IS-026 kök neden bulunana kadar HUD'da gizle ya da "~" önekiyle göster; test-1 öncesi.** Etki düşük / maliyet düşük / Faz 1. Risk: yok.
- **ON-6 Yerel oyuncuya ince dış halka (2 px, FG token), menzile giren kasa/kapıya 22 px'lik etkileşim halkası (GDD §14.1 kural 2), ekip paneli harita dışına (sol üst nakdin altı).** Etki orta / maliyet düşük / 2a (US-014 kukla + US-013 HUD). Neden: S5; test-1'de "hangisi benim?" sorusunu öldürür. Risk: kukla gelince halka atkı rengiyle çakışır — halka FG, atkı oyuncu rengi.
- **ON-7 Viewport temizleme rengi BG token'ı (koyu), gri #4d4d4d değil.** Etki düşük / maliyet çok düşük / Faz 1. Neden: gri boşluk noir paleti kırıyor (KR-005). Risk: yok.
- **ON-8 Hız oranlarını test-1'e kadar sabit tut; test-1 gözlemi 3 ile birlikte kabul kriteri: koşan oyuncu 10 karoluk düz hatta chaser'dan (200) ≥ 1 karo açar, köşede yakalanır (hesap: 10 karo = 1,45 sn, fark 29 px ≈ 0,9 karo → sınırda; chaser 190 düşünülür).** Etki orta / maliyet sıfır (tres) / 2a. Risk: 190 kovalamayı "kolay kaçılır" yapabilir; US-008 botla 200 koşu ölçer.
- **ON-9 Sert ağ profili Faz 2 çıkış kriterine "faz1_full/heist_full ≥ 8/10, senkron < 48 px" olarak girsin (US-015 uyarlanır tampon 100-180 ms).** Etki orta / maliyet orta (US-015 zaten planlı) / 2b. Neden: TR↔SE hattında jitter gerçek; Faz 2'nin "beni görmemişti" kriteri bu profilde ölçülmeli. Risk: tampon 180 ms'de uzak oyuncu 40 px geride çizilir; çift anahtar anları (T3+) için üst sınır 150 ms.

Yeni özellik ve geliştirme önerileri: Faz 2 kapanışından itibaren (KR-016); Faz 1'de önemli bir aday yok.

## Riskler (Faz 2-3 erken uyarılar)

- **R1 Senkron payı ↔ algı sayıları.** Kasa tutarken sahip yakın bantta 1,0 sn'de "!" (GDD §6.1); host oyuncuyu 100-175 ms eski görür, koşuda 22-38 px geride. Kasa tutma sırasında oyuncu hareketsiz olduğu için sorun yok; **koşarak kaçma ve kovalama** (S3) sorunlu → ON-3/ON-4 2a'da olmalı, 2b'ye kalmamalı.
- **R2 Kukla yumuşatması ile mantık ivmesi farkı.** GDD §14.1 kalkış k=10 (≈0,30 sn), duruş k=13 (0,23 sn); mantık 0,10 sn. Kukla **konumu** yumuşatırsa 140 px/sn'de 20-28 px aşma → kural 3 (görsel aşma ≤ 6 px) ihlali ve etkileşim menzili yanıltır. US-014: yalnız poz (eğilme, ezilme, adım) yumuşatılır, kök konum gövdeyle aynı karede.
- **R3 Doğu camı kasayı 5 karodan görüyor.** Yoldan geçen bakışı (koni 40°/192 px = 6 karo, %30, 2 sn, 20±8 sn aralık) doğu yan sokağından kasayı doğrudan görür (≈ 70 sn'de bir 2 sn). Klip kaynağı (iyi), ama §9.3 kabulü "300 sn'de kasa görüş hattı dışı 60-120 sn" **yalnız sahibe** göre hesaplanmış; yoldan geçen eklenince net pencere ölçülmeli (US-016 headless ölçümü camı dahil etsin).
- **R4 Tam harita bir ekranda → sis (US-011, 2b, P2) bakkalda gerekli mi?** Bakkalda keşif değeri "camdan bak" (düşük); sis olmadan sahibin konisi her an görünür, oyun "koni okuma"ya döner — tasarım bunu istiyor (§9.3). Sis kararını Faz 3 keşif testine bırak; 2a'da sis yok, kabul.
- **R5 Raf koridorları 1 karo (32 px), gövde 24 px, kukla ~44 birim × ölçek.** Kukla 32 px'i aşarsa koridorda raflarla üst üste biner; çarpışma değişmez ama okunurluk bozulur. US-014 AC: kukla genişliği ≤ 30 px (atkı hariç).
- **R6 Faz 3 keşif ↔ kamera.** Tüm harita bir ekrandaysa "dışarıdan camdan bakma" ile "içeri girme" arasında bilgi farkı kalmaz; Faz 3 başında kamera/sis/görüş hattı kararı (ON-1 + US-011) önce verilmeli.
- **R7 Test-1 araç hataları hissi gölgeler.** IS-006 fazı engellemiyor (doğru) ama ON-5 ve ON-7 yapılmadan test-1 koşulursa ilk izlenim "gri ekran + yüksek ping" olur. Test-1 öncesi asgari: ON-5, ON-7 (ikisi de XS).
- **R8 IS-022 c2 görüntüsü (c2_3.png) tamamen gri.** Büyük olasılıkla araç zamanlaması (c2 1 sn geç başlıyor); kukla/okunurluk doğrulaması bu araca dayanacağı için IS-022 denetiminde kontrol edilmeli (tasarım değil, not).

## Test-1: arkadaşlarla neye bakılmalı (Faz 1 kapsamı; yontem.md §9 ve oyun-testi-ve-klip.md ile uyumlu)

Hazırlık: hipotez H1 "arkadaş yardım almadan 60 sn içinde kendi karakterini bulur ve yürür", H2 "kasa kuralı (tezgâh arkası + basılı tut) söylenmeden 2 denemede anlaşılır", H3 "10 dk'da 'lag' cümlesi ≤ 2". Kullanıcı en az bir koşuda gözlemci; brifing yalnız tuşlar ("WASD/sol çubuk, Shift koş, Ctrl sız, E tut; kasayı boşalt"). Kayıt izni önceden. 3 kişi toplanamazsa 2 kişiyle koş (GDD §11: bakkal 2 kişiyle tam oynanır).

**Gözlem listesi (koşu başına, zaman damgalı; yontem §9 formu K/G/P/S/Ö/T türleriyle):**
1. Bağlanma: Tailscale ile katılma süresi (hedef ≤ 5 sn), kaç deneme, "Bağlanıyor…" takılması, güvenlik duvarı/SmartScreen uyarısı.
2. İlk 60 sn: oyuncu kendi karakterini ve bakış yönünü bulana kadar geçen süre; "hangisi benim?" sorusu (H1).
3. Yürüme hissi: tuşa basınca "anında" mı, kayma/takılma var mı, duvara ve rafa takılma; koşu ve sızma kipini kim ne zaman kendiliğinden keşfetti.
4. Uzak oyuncu: arkadaşın karakteri akıcı mı; ışınlanma/sıçrama görüldü mü (kaç kez, kimde, ne yaparken — koşarken?).
5. Kasa: tezgâh arkasına geçmesi gerektiğini kendiliğinden anladı mı; müşteri tarafından deneme sayısı; 3 sn tutma sırasında diğer oyuncular ne yaptı (ölü zaman) (H2).
6. Kasa sonucu: çubuk dolunca nakit "hemen" geldi mi; "oldu mu?" soruldu mu; tutmayı erken bırakma oldu mu.
7. Kapı: arka kapıyı açıp kapatma; birinin üstüne kapatma denemesi; aynı anda iki kişi basınca ne oldu (şikâyet var mı).
8. Gecikme hissi: "lag var" / "geç geldi" cümlesi sayısı; HUD ping değerine bakıldı mı, bakınca ne dendi (H3).
9. Görsel okunurluk: gri boşluk, haritanın kayması, panelin haritayı örtmesi, "kasa/kapı nerede?" sorusu; yazıların okunurluğu (ad etiketleri, nakit).
10. Ölü zaman ve kendiliğinden ilgi: 10 dk içinde kim ne zaman "başka bir şey yok mu?" dedi (Faz 1'de beklenen; ölç, yargılama); kendiliğinden denenen şeyler (koşarak tur, rafların arası, kaçış köşesi).

**Anket (5 soru; 24 saat içinde bireysel):**
1. Oyuna bağlanmak ve girmek ne kadar zordu? (Çok kolay / Kolay / Uğraştırdı / Olmadı) — Takıldığın yer neydi? (açık)
2. Karakterin tuşlara tepkisi nasıldı? (Anında / Hafif gecikmeli / Belirgin gecikmeli) · Arkadaşının karakteri? (Akıcı / Ara sıra sıçradı / Sürekli sıçradı)
3. Kasayı boşaltma kuralını (tezgâh arkasından, basılı tutarak) kimse söylemeden anladın mı? (Hemen / Deneyerek / Söylenince)
4. Ekranda en zor seçtiğin şey neydi? (Kendim / Arkadaşım / Kasa / Kapı / Harita kenarı / Yazılar / Hiçbiri) — kısaca neden?
5. Bu iskelete "bakkal sahibi var, yakalanmadan soy" eklense oynar mısın? (Kesin / Muhtemelen / Emin değilim / Hayır) — Şu an en çok ne eksik? (tek cümle)

Değerlendirme: her gözlem satırı sıklık × şiddet ile GB'ye; H1-H3 sonuçları Faz 2a hipotezlerine girdi; anket 5'in cevabı Faz 2a'nın "eğlenceli mi" kapısı için taban çizgisidir.
