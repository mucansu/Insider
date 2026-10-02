# T2 benzinlik: gece görevlisi, kamera/DVR, düğme, ilk polis sayacı (tasarım araştırması, 4. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; sayılar `data/npc/clerk_night_tuning.tres`, `data/scenario/t2_benzinlik.tres` başlangıç adayıdır, oyun testiyle ayarlanır.
Dayanak: GDD v0.4 §6.1-6.5, §8, §9 T2 satırı, §9.1 T2, §9.3 (bakkal sahibi ajandası), §15; KR-020 (bakkalda güvenlik yok → kamera/düğme/sindirme T2), KR-021, KR-023; `tezgahtar-sindirme.md` §5-6 (T2 notu), `muhafiz-davranisi.md` §2 (hız/sezgi sayıları), `kesif-on-testi.md` §3 (benzinlik sahnesi).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** bizim sayılarımızdan türetilmiş.

## 1. Gerçek dünya ve emsaller (ne biliyoruz)

| Kaynak | Olgu | Bize ders [görüş] |
|---|---|---|
| IPVM sahte kamera testi [1] | Test edilen tüm sahte modellerde **yanıp sönen kırmızı LED** vardı; modern gerçek kameralar yanıp sönen ışık kullanmaz. Gerçek kamerada koaksiyel **kablo** vardır, sahtelerde yok ya da plastik taklit. Gerçek-sahte farkı IR LED dizilimi ve merceğin dış camdan ayrılmasında; kutu tipi sahteler küçük ve pil kapaklı. Yükseğe/uzağa asılan sahtenin ayrıntısı seçilemez. | Keşifte iki ipucu, iki mesafe: **kablo** uzaktan (görüş hattı; raf/tabela gizleyebilir, tohum), **LED** yakından (≤ 3 karo, 2 sn inceleme = bakış şüphesi). Yükseğe asılı kamera (tohum "yüksek montaj") yalnız kabloyla okunur. |
| DVR hırsızlığı haberleri [2][3] | Benzinlik soyguncuları kayıt cihazını söküp götürmüş (Ridgetop, TN; ormana saklamış, polis bulmuş); başka olaylarda DVR ya da yalnız diski alınmış. | DVR'ı **silmek** (Tech, sessiz, uzun) ve **sökmek** (herkes, kısa, gürültülü, çanta gibi taşınır) iki yol; sökülen DVR kaçışta düşürülürse kayıt polise kalır (ısı). |
| Tezgâhtar eğitimi [4][5] | Çalışan soygunda "bir dakikadan az sürede her şeyi doğru yapmalı": direnme yok, uyum, ayrıntı not et, kovalama yok. Hold-up düğmesi sessizdir; "yüz yüzeyken basma, fırsat bulunca bas" ([5] T3 notu). | Görevli **bağırmaz, kovalamaz**: uyar, fırsat kollar, düğmeye uzanır. Sindirme = "fırsat vermemek". |
| Sessiz alarm akışı [6][7] | Alarm firması → polis; bankada bir dakikadan az, ama 3.000 mil ötedeki firma yüzünden 5 dk gecikme örneği; Largo polisi benzinlikteki sessiz alarma gece 01:22'de yanıt verdi; perakendede 30 dk-2 saat yanıt da var. | Gerçek yanıt dakikalardır; oyun 120 sn'ye sıkıştırır (GDD §9.1). HUD sayacı "alarm firması → polis" iki aşamalı okunabilir (60 sn "bildirildi", 60 sn "yolda"). |
| Payday 2 kamera odası [8][9] | Kameralar güvenlik odasından izlenir; operatör yok edilince kameralar sorun olmaktan çıkar; ECM kameraları yarıçap içinde kör eder; kamera döngüsü beceriyle. | T2'de **operatör yok** (GDD: operatörlü kamera T5): kamera yalnız kaydeder; "kameradan kurtulma" = DVR. Jammer (dükkân) = ECM'in ucuz hali: 20 sn kör. |
| Kodsuz keşif testi sahnesi (`kesif-on-testi.md` §3) | Senaryo A zaten "gece benzinliği": K1 döner, K2 sahte, DVR arka koridor, görevli turu 20 sn, kurye t=35. | Bu dosyanın düzeni o sahneyle **aynı cevap anahtarını** taşır: test materyali ile Faz 4 şablonu uyumlu kalsın. |

## 2. Mekân düzeni önerisi (ASCII, 32 px karo; 40×25 = bakkalın ~1,7 katı; iç alan 30×12 ≈ 1,7×)

Bakkal lejantı (`levels/level_layout.gd`) + yeni karakterler: `P` pompa adası (engel, görüşü **geçirir**), `A` araç durma noktası (`ArrivalSpot*`), `Y` kaçış aracı (`GetawayCar`, EscapeZone eşdeğeri), `c` soğutucu dolap (raf gibi görüşü keser), `X` DVR, `U` panik düğmesi, `a`/`b` kamera işaretleri (`Camera1/2`; hangisi sahte **tohumdan**), `G` depo-ofis iç kapısı, `H` "yalnızca personel" depo kapısı, `W` tuvalet dış kapısı (kilitli; anahtar tezgâhta). Kuzey: arka servis sokağı (yaya kaçışı E) · güney: kanopili ön alan + cadde · doğu: tuvalet cephesi (karanlık).

```
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%E,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,%   arka sokak (karanlık)
%,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,%
%,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,%
%,,#########B######################,,,,%   B arka kapı (T1 kilit 6 sn)
%,,#::::::::::::::#:::::::::::#:::#,,,,%   depo | ofis | tuvalet
%,,#::::::::::::::#:::::::::X:#:::#,,,,%   X DVR (ofis)
%,,#::::::::::::::G:::::::::::#:::W,,,,%   G depo→ofis, W tuvalet dış kapısı
%,,#::::::::::::::#:::::::::::#:::#,,,,%
%,,#::::::::::::::#:::::::::::#:::#,,,,%
%,,#####H####################D#####,,,,%   H personel kapısı, D tezgâh arkası→ofis
%,,#cb...........................a#,,,,%   a/b kameralar (köşe, tavan)
%,,#c..SSSSS..SSSSS..SSSSS.T......#,,,,%   T tezgâh (dikey), sağı personel tarafı
%,,#c......................T......#,,,,%
%,,#c..SSSSS..SSSSS..SSSSS.R.K....#,,,,%   R kasa, K görevli noktası
%,,#c......................T.U....#,,,,%   U düğme (tezgâh altı, K'nın yanı)
%,,#c.............................#,,,,%
%,,#wwwwww#F#wwwwwwwwwwwwww########,,,,%   F ön kapı; cam cephe (gece içerisi aydınlık)
%,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,%   kanopi altı (aydınlık) / kenarlar karanlık
%,,,,,,,PP,,A,,,,,,,,PP,,A,,,,,,,,,,,,,%   PP pompa adaları, A araç durağı
%,,,,,,,PP,,,,,,,,,,,PP,,,,,,,,,,,,,,,,%
%,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,,%
%_1234________________________Y____%   cadde: oyuncu doğuşu, Y kaçış aracı, devriye rotası
%______________________________________%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```

Bölgeler (IS-023 sözdizimi): `= StaffArea 28 11 6 6` (tezgâh arkası) · `= Dark 1 1 38 3` (arka sokak) · `= Dark 35 4 4 14` (doğu cephe) · `= Dark 1 18 4 4` ve `= Dark 30 18 9 4` (kanopi dışı ön alan) · `= Lit 5 18 25 4` (kanopi). Ofis ve depo `:` = arka oda kuralı (personel tarafı çarpanı 1,5). Üç rota: **F → satış → tezgâh ucu → R/U/D → ofis** (bakkalın öğrettiği) · **B → depo → G → ofis (DVR) → D → tezgâh arkası** (yeni: DVR'a tezgâhtan geçmeden ulaşılır, ama B'yi açmak arka sokakta 6 sn) · **W tuvalet** (anahtar isteyen müşteri = görevliyi tezgâhtan çeker; tuvaletten iç geçiş yok, yalnız dikkat aracı). Kamera `a` (NE köşe, 60° koni, SW'ye bakar: tezgâh + ön kapı) ve `b` (NW köşe, SE'ye: raf koridorları + H kapısı); tohum ikisinden birini sahte yapar, sahte olanın konisi de **çizilir** (oyun ayırt ettirmez, GDD §5 "iddia" ilkesi).

## 3. Tehdit zinciri ve sayılar (`t2_benzinlik.tres`)

**Gece görevlisi** (`brain_owner` varyantı; sahip ajandasının "düğmeli" hali): TEZGÂH 40-60 sn (K'da, batıya; koni 50°/224 px) ↔ {RAF 10-15 sn (sırtı dönük) · KAHVE/TEMİZLİK 15-20 sn (tuvalet önü, doğu) · OFİS 10-15 sn (D'den girer; DVR odasında — ofis kapalı, kasa açık) · DIŞARI SİGARA 20-30 sn (F önü, kanopi altı; **dükkân boş**, en büyük pencere, tohumla iş başına 0-1 kez)}; MÜŞTERİ kesmesi 6 sn; araç geldiğinde 1 sn cama bakış. Şüphe çarpanları §6.1 tablosu aynen. Fark tepki zincirinde: 30 "?" → 60 SORGU (bakkal gibi yürür, "Yardımcı olabilir miyim?") → **100 PANİK**: bağırmaz; durur, "!" 0,5 sn, tezgâha **döner/koşar** (180 px/sn; tezgâhtaysa 0) → UZAN 1,5 sn (görünür telegraf: eğilme + "!" titreme + SFX) → BAS → uyarı 3, polis 120 sn. [hesap] Pencere = 0,5 + mesafe/180 + 1,5 sn: tezgâhta 2,0 sn; raf önünde (~6 karo) 3,1 sn; dışarıda sigarada (~9 karo) 3,6 sn. "Görevliyi tezgâhtan uzaklaştır" planı kendiliğinden ödüllenir.

**Sindirme (Q; `tezgahtar-sindirme.md` §6 değerleri):** menzil 96 px, koni 60°, görüş hattı, bağırış gürültüsü 140 px (silah yok, KR-020); görevli SİNDİ (eller yukarı, algı kapalı, ajanda durur). Herhangi bir oyuncu ≤ 128 px + görüş hattında → "tutuluyor". Tutan yoksa **8 sn** sonra UZAN (2 sn telegraf) → BAS; UZAN sırasında yeniden Q iptal eder, BAS sonrası Q etkisiz. UZAN sırasında Q = GDD §16 soru 4'ün cevabı: 8 sn sabit, bırakınca koşmaz, **tezgâha yürür** (110 px/sn) — düğme tezgâhta olduğundan sindirilen görevliyi tezgâhtan uzağa (raf koridoru) götürmek pencereyi 2-3 sn büyütür ("yere yat" = tutan oyuncu 1 sn tut, görevli oturur, kalkış +3 sn). Üçüncü el budur: biri tutar, ikisi çalışır. Kamera SİNDİ görevliyi görürse: kayıt (ısı), alarm yok (operatör yok).

**Kameralar:** 2 adet, 1 sahte (tohum). Gerçek: sabit 60°/320 px ya da dönen (90° tarama, 8 sn periyot; keşifte sayılabilir zamansal bilgi). Gören kamera → oyuncuya **REC** rozeti (HUD, kırmızı nokta + kaydedilen saniye), oyuncu kaydedildiğini bilir, sonuç yok; iş sonunda DVR silinmemişse "kayıt" → ısı +15 ve tanınma sayacı (GDD §9.1). Jammer (dükkân, Faz 4): 20 sn tüm kameralar kör, 1 kullanım. Sahte kamera ipuçları §1: LED (yakından) + kablo (uzaktan); insider v0 teklifi "hangisi sahte" (doğruluk %80, GDD §4.7 "iddia").

**DVR (ofis, X):** SİL = Tech 6 sn tut (sessiz; kaydı siler, kameralar çalışmaya devam eder: silmeden **sonra** görülürsen yine kayıt) · SÖK = herkes 3 sn tut, gürültü 120 px, DVR çanta nesnesi olur (1 slot; koşunca %50 düşürme, düşerse kayıt polise kalır = ısı +15). Ofis D kapısı tezgâh arkasından: görevli tezgâhtayken ofise sızmak = personel tarafı 1,5 çarpanı (yakın bant 1,5 sn); G kapısından (depo) girmek görünmez ama B kilidi 6 sn.

**Araç ve müşteri trafiği (`t2_population.tres`):** müşteri aracı 60 ± 20 sn (tohum; aynı anda ≤ 1): caddeden girer, `A` noktasında durur (3 sn), **araç görüşü keser** (hareketli engel; kanopi altında siper), müşteri iner: %60 pompada öder (25-40 sn pompa başında; her 10 sn'de %30 olasılıkla cama 2 sn bakış, koni 40°/192), %40 içeri girer (kalış 20-35 sn, kuyruk; görevliyi 6 sn tezgâha kilitler). Müşteri tanıklığı §6.1 tablosu; eşik 100'de bağırmaz, **görevliye söyler** (bakkal müşterisi gibi) ya da dışarıdaysa aracına binip gider ve polisi arar: 90 sn sonra devriye gelir (uyarı 3 eşdeğeri, "tanık" klibi). **Devriye arabası** 3-4 dk'da bir caddeden geçer (8 sn görünür; koni 60°/256, ön alana bakar): koşan ya da çanta taşıyan oyuncuyu görürse durur → doğrudan uyarı 3 (sayaç 60 sn, "zaten buradalar"); yürüyen/sızan oyuncuyu görmez (gece, cam yansıması). Keşif değeri: periyot (dışarıdaki rol) + hangi kamera döner + görevli sigara saati.

**Kaçış:** yaya E (arka sokak, karanlık) ya da **Y kaçış aracı** (cadde kenarı; 3 kişi/kalan herkes 24 px içinde + 2 sn kalkış; polis sayacı bitmeden). Araç önceden seçilen yerde (Faz 3 plan masası "kaçış rotası"; Faz 4'te sabit Y). **Polis 120 sn**: HUD sayacı yalnız uyarı 3'te; 60 sn "bildirildi" / 60 sn "yolda" (iki renk); bitince polis aracı caddeden gelir, forecourt + dükkân içindeki herkes yakalanır (K3), arka sokakta ya da Y'de olanlar kaçar. ECM (dükkân, Faz 4-5): sayaç +30 sn, 1 kullanım.

**Uyarı eşlemesi (§9.1 T2):** 0 sakin · 1 görevli şüphe/sorgu (söner) · 2 görevli paniği (tezgâha gidiyor; sindirme ya da görüş kaybı 10 sn ile 1'e iner) · 3 sessiz alarm (120 sn, dönmez) · 4 yok · 5 polis geldi. Uyarı 2'de görevli "sindirilmemişse" 2 → 3 **kaçınılmaz** değildir: görüş hattını kaybederse tezgâha varır, 3 sn bekler ("gittiler mi?"), basmaz, uyarı 1'e döner, ajandası "tetikte" (koni 70°, 60 sn). Geri dönüş oynanabilir kalır (Payday tuzağı, benzer-oyunlar §1).

**Ganimet ve süre:** kasa 300 (3 sn, tezgâh arkası) + sigara dolabı (tezgâh arkası kilitli, 3 × 60, 1 sn alma, kamera `a` tam görür) + ofis kasası 600-1.200 (tohum; T1 kilit 6 sn ya da görevlinin anahtarı: sindirilmiş görevliden 2 sn "al") + DVR'ın kendisi (aracıya 100, "sıcak"). Toplam 1.080-1.680 (GDD §8 ölçeği: bakkal 0,5-1,5k → T2 ~1,5-2,5× [görüş]). Hedef süre 4-6 dk (GDD §9): pencere bekleme 60-90 sn, DVR 10-15 sn, kasa + ofis 20 sn, kaçış 15 sn.

## 4. Öğrettiği yeni beceriler ve bakkaldan öğrenme eğrisi

| Beceri | Bakkal (T1) öğretti | Benzinlik (T2) ekler | Sonraki (T3) |
|---|---|---|---|
| Gözlemci yönetimi | Bir çift göz, dikkat pencereleri, oyala/gönder/satın al | Gözün **elinin altında düğme** var: pencere artık mesafe + 1,5 sn; sindirme = üçüncü el | Bekçi telefonu 10 sn, kepenk |
| Kayıt / iz | Yok | Kamera koni + REC rozeti; DVR sil/sök; sahte kamera (keşif) | Cam alarmı, kod |
| Saat | Yalnız 3'te 60 sn (mahalleli) | İlk **görünür polis sayacı** 120 sn; sayaç altında ganimet toplama kararı | 150 sn + alarm firması |
| Dışarısı | Yoldan geçenler (gündüz) | Gece: karanlık kenarlar siper, araç siper, devriye periyodu (zamansal keşif) | Komşu dükkân tanıkları |
| Kaçış | Yaya E | Araç Y (toplanma + kalkış) | — |

[görüş] T2 dört yeni sistemi aynı anda açıyor (kamera, DVR, düğme/sindirme, sayaç) — fazla. Öneri: iki şablon ya da tohum rampası: **T2-a "tanıtım"** (1 gerçek kamera, sahte yok; devriye arabası yok; görevli sigara molası garantili; insider teklifi "DVR ofiste") ve **T2-b "tam"** (2 kamera 1 sahte, devriye, sigara molası tohuma bağlı). Hitman ilk-seviye dersi (benzer-oyunlar): ilk T2 koşusunda sindirme **gerekmesin**, mümkün olsun. Kabul: bot koşularında T2-a temiz oranı ≥ %60, T2-b %35-55 (bakkal hedefi %80 üstüyse mahalleli sertleşir, KR-021).

## 5. Faz 4 kalem taslakları (AC'li; sahipler öneri)

**US-T2a — Benzinlik şablonu v1** (seviye; S4; bağımlılık: IS-023 bölge sözdizimi). AC1 `levels/layouts/gas_a.txt` §2 düzeni; yeni lejant karakterleri `level_layout.gd` tablosunda (KR-018 B tür öznitelik tablosu: `P` görüş geçirir/engel, `c` görüş keser). AC2 İşaretler: `Camera1/2`, `Dvr`, `PanicButton`, `ArrivalSpot1/2`, `GetawayCar`, `EscapeZone`, `RestroomDoor`, `StockDoor`, `OfficeDoor`, `SmokeSpot`, `CoffeeSpot`, `RestockSpot1..3`, `PatrolRoute1..n` (cadde). AC3 Bölgeler: `StaffArea`, `Dark`×4, `Lit`; `test_levels` karanlık/ışık bölgelerinin görüş hesabına girdiğini doğrular. AC4 Navigasyon: F→ofis, B→depo→G→ofis, A→F yolları var; kapalı W/B/H/G/D kenarında yol değişir. AC5 1280×720 ekran görüntüsünde kanopi altı/karanlık kenar/arka sokak üç ton olarak ayırt edilir.

**US-T2b — Gece görevlisi + panik düğmesi + sindirme** (oynanis; S7/S11; bağımlılık: US-008/US-010 bakkal sahibi). AC1 `brain_owner` ajanda varyantı veriden (`clerk_night_tuning.tres`: TEZGÂH/RAF/KAHVE/OFİS/SİGARA süreleri, sigara olasılığı tohum). AC2 PANİK zinciri: 100'de bağırış yok; tezgâha dönüş 180 px/sn, UZAN 1,5 sn telegraf (sinyal `clerk_reach`), BAS → `Game` uyarı 3 + 120 sn sayaç; headless ölçüm: tezgâhtayken pencere 2,0 ± 0,2 sn, 6 karo uzaktayken 3,1 ± 0,3. AC3 Q sindirme: menzil 96/koni 60/görüş hattı; SİNDİ'de algı kapalı ve ajanda durur; tutan ≤ 128 px; tutansız 8 sn → UZAN 2 sn → BAS; UZAN'da Q iptal; BAS sonrası Q etkisiz; "yere yat" 1 sn tut → kalkış +3 sn. AC4 Uyarı 2 → 1 geri dönüşü: görüş kaybı 10 sn → tezgâhta 3 sn bekleyip basmaz. AC5 Değişmezler: I1 BAS yalnız UZAN tamamlanınca; I2 uyarı 3 yalnız BAS, devriye tespiti ya da tanık çağrısından; I3 SİNDİ sırasında şüphe değişmez; I4 tohum belirlenimciliği. AC6 Senaryo `t2_panic.json` (0/150 ms): (a) sindirmesiz kasa → ≤ 2,2 sn'de BAS; (b) A sindirir, B kasa + ofis, 8 sn içinde C "yere yat" → uyarı 0; (c) UZAN'da Q → iptal; (d) 150 ms'de Q isteği host payı +0,25 sn.

**US-T2c — Kamera + DVR + kayıt sonucu** (oynanis; S7/S8/S11). AC1 `entities/npc/camera/`: statik algı bileşeni (US-006), sabit/dönen (90°, 8 sn), tespitte alarm **yok**: `recorded(peer_id, seconds)` olayı; HUD REC rozeti (arayuz alt paketi). AC2 Sahte varyant: tohumdan `fake_index`; koni çizimi aynı; görsel ipuçları (LED 1 Hz kırmızı yakından ≤ 96 px görünür; kablo dokusu tohumla gizli/açık) görsel katmanda, mantığa dokunmaz. AC3 DVR Interactable: SİL 6 sn (Tech başlığı; Faz 4'te "Tech deck" eşyası kapısı), SÖK 3 sn + gürültü 120 + çanta nesnesi (US-012 kuralları); silme sonrası yeni kayıt mümkün. AC4 İş sonu: DVR silindi/söküldü-kaçtı/düştü/kaldı → `Economy` ısı +0/+0/+15/+15 (US-E2 ile). AC5 Jammer: 20 sn tüm kameralar `blind`; 1 kullanım; senaryo `t2_camera.json`: dönen kamera periyodu ±0,1 sn, jammer altında kayıt 0, sahte kamera kayıt 0.

**US-T2d — Araç trafiği + devriye arabası** (oynanis + seviye; S11). AC1 `Vehicle` NPC: caddeden `ArrivalSpot`'a, 3 sn park, görüşü keser (`vision_block` dinamik), müşteri çıkarır; pompa/içeri oranı 60/40 tohum. AC2 Pompa müşterisi: 10 sn'de bir %30 cam bakışı; tanıklık 100 → görevliye söyler ya da gidip polisi çağırır (90 sn → uyarı 3). AC3 Devriye arabası 3-4 dk (tohum), 8 sn görünür; koşan/çantalı tespitinde uyarı 3 + 60 sn; yürüyen görülmez. AC4 Host NPC üst sınırı ≤ 8 (görevli 1 + müşteri 1 + araç 1 + devriye 1 + polis 2 + yedek); 15 Hz özet ≤ 3 KB/sn.

**US-T2e — Kaçış aracı + polis gelişi + T2 iş sonu** (oynanis + arayuz; US-012 üstüne). AC1 `GetawayCar`: 24 px içinde kalan herkes + 2 sn → kaçış; sayaç bitmeden. AC2 Sayaç HUD'da yalnız uyarı 3'te, iki aşama 60/60 sn, iki renk; ECM +30 sn. AC3 Polis gelişi: 2 polis aracı caddeden, forecourt + dükkân içindeki oyuncular `captured`; arka sokak/Y serbest; iş sonu ekranında kim nerede yakalandı (klip notu). AC4 2 ve 3 kişiyle bot temiz tamamlama farkı ≤ 15 puan (IS-015).

**IS-T2f — T2 keşif ipuçları ve kodsuz test cevap anahtarı** (seviye görsel + tasarim). Sahte kamera LED/kablo yer tutucu görselleri; `kesif-on-testi.md` Senaryo A cevap anahtarı bu düzene göre güncellenir (Faz 3 keşif testinde kullanılacak); ekran görüntüsünde LED ve kablo ≥ 3 px fark edilir.

## 6. Riskler ve karar gereken

Riskler: sindirme tek doğru çözüm olursa her koşu aynı (ölçü: koşu JSON'unda sindirme kullanılmayan temiz koşu oranı ≥ %30; değilse sigara molası sıklığı ↑) · dört yeni sistem aynı anda → T2-a/T2-b rampası · kamera "sonuçsuz" (yalnız ısı) hissedilirse: Faz 4'te ısı HUD'da görünür olmalı (ekonomi-kefalet.md) · araç görüş kesme 150 ms'de titreme → araç konumu host'tan 15 Hz + istemcide yumuşatma; görüş hesabı karo ızgarasında (US-011a) · kanopi aydınlığı ile GDD ikili ışık kuralı (KR-019) çakışmaz: Lit/Dark bölgeleri ikilidir.

Karar gereken: (a) Sindirme tutma süresi 8 sn ve "yere yat" +3 sn (öneri) mi, yoksa tutma süresiz ama tutan eli bağlı mı? (b) Kameranın T2'de yalnız kayıt (GDD) olması korunsun mu, yoksa "görevli REC ekranına bakar" (tezgâhtaki küçük monitör: görevli tezgâhtayken kamera `b` gördüğünü 2 sn gecikmeyle görevliye şüphe +30 olarak aktarır) eklensin mi? Öneri: T2-b'de ekle (kamera ilk kez "sonuç" üretir, operatörsüz). (c) T2-a/T2-b iki şablon mu (seviye maliyeti ×1,3) yoksa tek şablon + modifikatör mü? Öneri modifikatör. (d) DVR SÖK yolunun çanta slotu tüketmesi (lojistik baskı) kabul mü?

## Kaynaklar
[1] IPVM, Dummy Camera Shootout — https://ipvm.com/reports/dummy-camera-shootout
[2] NewsChannel 5, benzinlikten kayıt sistemi çalındı (Ridgetop) — https://www.newschannel5.com/news/burglars-steal-cash-video-recording-system-from-gas-station
[3] Local10, soyguncu DVR'ı aldı (Miami) — https://www.local10.com/news/2013/06/28/armed-robber-steals-dvr-from-cell-phone-store/
[4] Canadian Occupational Safety, tezgâhtar soygun eğitimi — https://thesafetymag.com/ca/news/general/why-clerks-need-updated-robbery-training/422475
[5] SDM Magazine, panic button uygulaması — https://www.sdmmag.com/articles/82345-revisiting-the-panic-button
[6] NBC San Diego, sessiz alarm gecikmeleri — https://www.nbcsandiego.com/news/local/how-silent-alarms-can-help-bank-robbers/1915418
[7] FOX 13, Largo polisi benzinlik sessiz alarmı — https://www.fox13news.com/news/police-surround-convenience-store-as-would-be-robber-dawdles
[8] Payday Wiki, Diamond Store (güvenlik odası/operatör) — https://payday.fandom.com/wiki/Diamond_Store
[9] West Games, Payday 2 camera loop — https://west-games.com/payday-2-camera-loop
