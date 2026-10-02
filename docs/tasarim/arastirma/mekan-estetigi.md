# Mekân estetiği, çevresel hikâye anlatımı ve seviye tasarım ilkeleri (tasarım araştırması, 4. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; kullanıcı isteği "görsel zevk ve oynanış güzelliği". Kapsam: mekânın **içeriği, düzeni ve hikâyesi**; renk paleti ve AI üretim hattı `sanat-yonu.md`'nin alanıdır (burada renk adı geçtiğinde yalnız `ThemeTokens` sınıfı kastedilir).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** store_a (IS-023 sürümü, 30×20 karo, 32 px) koordinatlarından türetildi; koordinat = (sütun, satır), sol üst (0,0).
Dayanak: GDD §6.5 (üç katman sis: statik dünya hafızada kalır, durum gizli), §9.1-9.3 (T1 tehdit modeli, sahip ajandası, araçlar), §10 (şablon/modül, doğrulayıcı), §14 (okunabilirlik önceliği, AI üretimi yalnız statik katmanlarda); `okunabilirlik-2d.md` §2 (iki kanal, ≥ 3:1 kontrast, ≥ 22 px); `ses-ve-sfx.md` kural 6 (sessizlik varsayılan, yalnız buzdolabı uğultusu); ekran görüntüleri `is027/z1.5_*.png` (düz karo zemin, gri ızgaralı raflar, sarı tezgâh, yeşil kasa; boş zemin alanı ~%45).

## 1. Emsaller ve dersler

| Kaynak | Olgu | Bize ders [görüş] |
|---|---|---|
| Gone Home (Fullbright, 4 kişi) [1][2] | Tek kapalı mekân; "taşınma ortası ev" bahanesiyle az ama anlamlı eşya; onlarca yıllık birikim yerine **"tanınabilir yüksek verimli dokunuşlar"**; hikâye nesnelerden okunur, mekanik yok. | Bakkal da tek mekân: 12-16 dekor öğesi yeter, her biri bir şey **söylemeli** (sahip kim, ne zaman ne yapar). Yığın değil seçki. |
| Hitman WoA "levels as social spaces" (GDC 2019) [3][4] | Seviye sosyal mimaridir: "gerçek insanların yaşayıp çalıştığı" hissi; kamusal / özel / sahne arkası bölgeleri NPC rolleriyle tanımlanır; çoklu giriş, rutin okuma, mekânı araç olarak kullanma. | Bizim `CustomerArea / StaffArea / Backroom` zaten sosyal bölge; dekor bölgeyi **görünür** kılmalı: müşteri tarafı "satış" eşyası, personel tarafı kişisel eşya, arka oda koli/temizlik. Oyuncu çizgiyi görmeden hissetmeli. |
| "Anatomy of a stealth encounter" [5] | Güvenli başlangıç noktası + gözetleme yeri şart; düşman **önce duyulur sonra görülür**; devriyeler duraklamalı (pencere açar); çevrede seyrek, hedefe yakın yoğun gözlemci; kaçış kolaylığı duyguyu belirler (kolay = güven, zor = korku). | Bakkalda kaldırım = güvenli gözetleme (camdan bak); sahibin telefon/raf sesi "önce duyulur" (§6.5 halkalar); kaçış T1'de **kolay** olmalı (güven; korku T4+). |
| Level Design Book, siper [6] | "Az siper daha iyidir": fazla engel görüş hatlarını kapatır, labirent hissi verir; gizlilikte düşman başta açıkta, orta kontrollü, yan yollar riskli. | Dekorun çoğu **alçak** (görüş kesmez, çarpışmaz); görüş kesen yeni engel sayısı bakkalda ≤ 3. |
| Darkwood, Door Kickers (okunabilirlik-2d §1) | Statik sahne hep çizili, dinamik şeyler yalnız görüşte; iki sis tonu. | Dekor hafıza katmanında kalır (ucuz "zenginlik"); **durumlu** dekor (devrilmiş raf, açık kapı) son görülen hâlde. |
| RimWorld [7] | Grafik "uzaktan da ne olduğu okunsun" diye basit; okunurluk için ağaç arkasındaki nesne üstte çizilir. | Oyun nesnesi her zaman dekorun üstünde; dekor hiçbir oyun işaretini örtmez. |
| Hotline Miami [8] | Düz plan görünümü; her katta tanınır detay (küvet, disko zemini) — mekân kişilik kazanır, tek renk versiyon "sıkıcı ve aynı". | Tek bir **imza öğesi** (bakkalda: meyve kasaları + buzdolabı ışığı + çay) mekânı akılda tutar; kademe başına imza öğesi listesi. |

## 2. Bakkalın yaşayan bir yer gibi görünmesi

### 2.1 Dekor öğeleri (hepsi `Props` altında `PropDef`; kolonlar: görsel · oyun işlevi · yer [hesap])
İşlev sözlüğü: **Ö** örtü (çarpışır, görüşü **kesmez**, alçak) · **G** görüş keser (çarpışır; `Walls` oklüderi gibi) · **S** ses kaynağı (ambiyans; `NoiseBus`'a girmez) · **E** etkileşim · **—** yalnız görsel (çarpışmaz, zemin/duvar çıkartması).

| # | Öğe | Görsel | İşlev | Yer (sütun,satır) | Not |
|---|---|---|---|---|---|
| 1 | İçecek dolabı | Camlı dik soğutucu, içi soğuk parlar | **G + S** (uğultu) | (13,5)-(13,7), batı duvarına yaslı 1×3 | Koridor 11-13 → 11-12 kalır (2 karo). ShopSpot k (10,7) doğuya "dolaba" bakar. 2b raf değerlileri (içki) burada olabilir. |
| 2 | Dondurucu sandık | Alçak, kapağı kaydırmalı | **Ö** | (13,13) | Ön kapı (11,13) ve (12,13) boş kalır. Alçak: arkasına çömelen oyuncu camdan (13,14)-(16,14) **görünmez değil** (alçak engel görüş kesmez) — ama "sanki saklandım" tuzağı olmasın diye kenarı MUTED, dolgusuz. |
| 3 | Meyve-sebze kasaları | Dış cephede 2 kasa, içeride batı rafı (2,6)-(2,11) "manav" | — (dış) | (4,15), (5,15) | Yoldan geçen rotası a→g satır 16'dan dolanır; nav yeniden üretim. Vitrine bakışı (g, cam (6,14)) kesmez. |
| 4 | Gazete/dergi standı | Döner tel stand | — | (2,13) | Köşe; ShopSpot n (3,11) komşusu değil. |
| 5 | Paspas + aşınma izi | "Hoş geldiniz" paspası; kapıdan kasaya solmuş yol | — | (11,13) + çıkartma (12,12)→(15,11) | Görsel yönlendirme: müşteri rotası okunur (Hitman "rehberli yol" ucuz hali). |
| 6 | Tezgâh üstü seti | Çay bardağı + tabak, tespih, cam kavanoz (sakız), katlı gazete | — | (17,9) kuzey ucu: kavanoz + gazete; (17,10): çay + tespih | Sahibin kişiliği (2.4). Kasa (17,11) üstü **boş** kalır: oyun nesnesi tek başına. |
| 7 | Radyo | Küçük transistörlü radyo | **S** (düşük, tohumla açık/kapalı) | (17,9) | ses-ve-sfx kural 6 ile çelişmesin: varsayılan **kapalı**; "radyo açık" tohum/modifikatör (Faz 3+). |
| 8 | Duvar telefonu | Kablolu, ahize; kablo PhoneSpot'a sarkar | — (ajanda telegrafı 2.4) | duvar (22,12), PhoneSpot (21,12) önü | Telefon köşesi daha sahip gitmeden okunur. |
| 9 | Sigara/içki duvar rafı | Tezgâh arkası duvar rafı, kilitli cam kapak | **E** (2b raf değerlileri: 3×30, 1 sn, tanık ×1,5) | duvar (20,8), (21,8); erişim (20,9)/(21,9) personel tarafı | GDD §9.3'teki "raf değerlileri"nin yeri: personel tarafında olması "kılık bozma" bedelini doğal kılar. |
| 10 | Pano: takvim + aile fotoğrafı + nazar/çerçeveli yazı | Küçük duvar panosu | — | doğu duvarı (22,9), (22,10)'un üstü (cam (22,10-11) değil, duvar (22,9)) | Türk mahallesi / nötr seçimine göre (Karar gereken). |
| 11 | Koli yığını (arka oda) | 3 koli üst üste, bant | **G** | (20,6) tek karo | **Kese** yaratır: (21,6)-(21,7), BackroomSpot O (18,5)'ten görüş hattı (20,6)'da kesilir; D kapısından (19,8)→(21,7) hattı (20,7) üstünden **açık** → kapıdan giren görür. D→O yolu (19,7),(19,6) serbest; B→O yolu (20,4),(20,5),(19,5) serbest. |
| 12 | Askıda palto + şapka, paspas/kova | Arka oda kişisel köşesi | — | duvar (14,5) askı; (18,7) kova | "Burada biri çalışıyor" + personel bölgesi işareti. |
| 13 | Tek ampul | Tavan ampulü çıkartması + yumuşak havuz | — (2.2) | (18,6) merkez | Köşeler (15,5-7), (21,6-7) havuz dışında kalır → kese görsel olarak da "karanlık köşe" okunur (oyun kuralı değil; 2.2). |
| 14 | Ara sokak kolisi | Islak koli yığını, çöp torbası | **G** | (21,2) tek karo | Kilit açan oyuncu (20,2): StreetRoute e (23,2)'den görüş hattı (21,2)'de kesilir; f (20,1)'den bitişik → görür. "e'de duran görmez, f'ye yürürse görür" ritmi; rota e→f (22,1)→(21,1) satır 1'den geçer. |
| 15 | Park etmiş araba | Kaldırıma yakın, kapalı | **G** | (7,17)-(9,17) | Cadde satır 18 ve kaldırım açık; spawn (3-6,16)→E (27,18) yolu bozulmaz. Cepheye "sokak" hissi; gözetleme noktası: arabanın arkası (8,18) kaldırımdan görünmez. |
| 16 | Tabela "BAKKAL" + vitrin çıkartmaları | Kapı iki yanı duvar karoları; cam parçalarında küçük fiyat etiketleri | — (2b: poster camı, §3.3) | duvar (10,14), (12,14); etiketler cam karoları | Etiketler görüşü **kesmez** (küçük). |

Yoğunluk kuralı [görüş]: iç zemin ~150 karo (bölgeler 188 − mobilya 39 [hesap]); çarpışan dekor ≤ 8 karo (%5), çıkartma ≤ 18 karo (%12); koridor (1 karo genişlik) karolarına hiçbir çarpışan öğe konmaz; hiçbir öğe `Markers`/`SpawnPoints` karosuna ya da kapı eşiğine (bitişik iki karo dahil) binmez.

### 2.2 Işık atmosferi (T1 gündüz, mesai; GDD §9)
- **Vitrin bandı:** camlara bitişik iç karolar (satır 13, sütun 3-9 ve 13-16; doğu camı için sütun 21 satır 10-11) zemin tonunun +%8 açığı (gün ışığı) — mekân arkaya doğru doğal olarak koyulaşır, noir kalır. Oyun etkisi yok.
- **Tezgâh lambası:** (17,9)-(18,11) üstünde sıcak havuz (yarıçap 64 px, α 0,12): "sahne" burasıdır — kasa ve sahip her zaman en okunur yerde. Oyun etkisi yok.
- **Arka oda:** tek ampul havuzu (18,6) yarıçap 72 px; köşeler havuz dışı. **v1'de yalnız görsel.** Oyun kuralı olarak **karanlık bölge** (KR-019 ikili ışık, §6.5: içindeki oyuncu 128 px görür, NPC onu yalnız karanlıkta ve ≤ 128 px'teyken görür) arka oda kesesi (15,5)-(15,7)+(21,6)-(21,7) için **tohum varyasyonu** ("ampul yanmıyor", Faz 3): keşifte öğrenilen bilgi olur ("arka odanın ampulü bozuk"). Karar gereken (§7).
- **Sis bağı:** tüm dekor statik katmandadır → hafıza tonunda (α 0,55, doygunluk ×0,5) çizilmeye devam eder; bilinmeyen katmanda (plan krokisi) **çizilmez** (yalnız duvar/kapı). Durumlu dekor (devrilmiş ShelfProp, açık dolap kapağı) son görülen durumda kalır — "biri buradan geçmiş" hikâyesi kendiliğinden çıkar.
- İlke: ışık havuzları **yalnız okunurluğu artırdığı** yerde (kasa, kapılar, kese köşeleri); rastgele "güzel" ışık yok (Monaco: ışık ikili).

### 2.3 Ses atmosferi (ses-ve-sfx kural 6 korunur: sessizlik varsayılan)
| Kaynak | Konum | Döngü / seviye | Not |
|---|---|---|---|
| Buzdolabı uğultusu | (13,6) | sürekli, -24 dB, 160 px zayıflama | Tek varsayılan ambiyans; arka odada duyulmaz → "arka odaya girdim" hissi sessizlikle gelir. |
| Sokak (araç geçişi, uzak korna) | cadde satır 17-18 | 20-40 sn'de bir 2-3 sn, tohum | Yoldan geçen üretimiyle eşleşir (aynı tohum): ses = "biri geçiyor" ipucu (**oyun bilgisi değil**, yalnız doku; halka çizilmez). |
| Kapı zili | F | mevcut (US-005/IS-024) | Sahibin 1 sn bakışıyla eş. |
| Telefon zili | (22,12) | ajandanın TELEFON görevinden **1 sn önce** 1 çalış, 160 px | 2.4 telegraf; NoiseBus'a girer (halka), ses kuralıyla tutarlı. |
| Arka oda: damlayan musluk / saat tıkırtısı | (18,7) | 4 sn'de bir, çok düşük | "Burada yalnızsın" dokusu; isteğe bağlı. |
| Radyo | (17,9) | tohum/modifikatörle; kapalı varsayılan | Açıkken müzik değil konuşma/uzak şarkı; **gürültü maskeleme kuralı yok** (karmaşıklık; Faz 4+ "radyo açık = sahip 120 px altı sesi duymaz" modifikatör adayı). |

### 2.4 Sahibin kişiliği ve "onu tanımak"
Çevre, sahibi tanıtır; ajanda **telegraflanır** (oyun bilgisi, GDD §9.3 "dikkat döngüsünü okuma"nın görünür hali):
- **Çay:** tezgâhtaki bardak boşaldığında (TEZGÂH görevinin son 3 sn'si) sahip bardağı alır → **ARKA ODA** görevine gidiyor (çay tazeleme = arka odaya gitmenin görünen nedeni). Oyuncu "bardak boş → şimdi kasa" okur.
- **Koliler:** bir sonraki `RestockSpot`'un önünde (o (4,5) / p (4,7) / r (4,9)) 1 koli çıkartması belirir (ajanda sonraki RAF noktasını seçtiğinde, geçişten ≥ 3 sn önce); sahip oraya gidince koli kaybolur. Oyuncu "hangi rafa gidecek, kasa ne kadar süre görüş dışı" hesabını mekândan yapar (uzak raf r → 5-7 karo).
- **Telefon:** 1 sn önce zil; sahip doğuya döner, koni 25°. Kablo görseli köşeyi önceden işaretler.
- **Tespih + gazete:** TEZGÂH beklemesinde tespih çeker / gazeteye bakar (kukla el animasyonu, US-014 eki): "sakin" durum siluetten okunur; "?"'de gazete düşer (pop) — iki kanal kuralı.
- **Fotoğraf, takvim, nazar:** mekanik yok; keşifte (Faz 3) "inceleme" ile tek satırlık not ("Takvimde her perşembe işaretli" → gelecek modifikatör kancası).
Kabul [görüş]: headless 300 sn ajandada her RAF/ARKA ODA/TELEFON geçişinin telegrafı geçişten 1-3 sn önce görünür/duyulur; telegrafsız geçiş 0.

## 3. Okunabilirlik ↔ zenginlik dengesi
Üç katman, üç kontrast seviyesi (okunabilirlik-2d §2.3 uzantısı; sayılar `sanat-yonu.md` paletiyle doğrulanır):
1. **Zemin dekoru** (çıkartma, çarpışmaz): zeminle kontrast ≤ 1,6:1; kenar çizgisi yok; hafıza tonunda neredeyse kaybolur.
2. **Mobilya ve engel** (raf, dolap, koli, araba): zeminle 2-3:1; 1 px kenar; görüş kesenler **dolu**, alçaklar **dolgusuz/çizgili** (Shadow Tactics "taralı = gizlenmez" dili: oyuncu neyin arkasına saklanabileceğini şekilden okur).
3. **Oyun nesneleri** (kasa, kapılar, çanta/arka oda nakdi, ShelfProp, kaçış bölgesi, duvar rafı): ≥ 3:1 + 22 px etkileşim halkası (ON-06) + **sabit siluet** (kasa her kademede aynı biçim). Dekor asla ALERT/CASH/PLAYER renklerini ve bu siluetleri kullanmaz; "çanta gibi görünen çanta" dekor olamaz.
Kurallar: dekor hiçbir oyun işaretinin (koni, halka, balon) altına girmez (z-sırası: zemin < dekor < mobilya < NPC/oyuncu < işaretler); 1280×720 görüntüsü %50 küçültülünce 3. katman hâlâ seçilir (otomatik test adayı); her oyun nesnesinin 1 karo çevresi dekorsuz ("nefes payı").

## 4. store_a düzenine somut iyileştirmeler (yürünebilir alan ve mevcut testleri bozmadan)
Tümü `Props`/`Decals` olarak gelir; ASCII ızgara ve `@`/`=` satırları **değişmez** (test_levels işaret/bölge/rota kuralları etkilenmez). Çarpışan öğeler nav yeniden üretimi gerektirir; `RestockSpot→Register` görüş kesikliği kuralı (aralarında ≥ 1 raf) eklemelerle bozulmaz.
Koordinat listesi (çarpışan **G/Ö** öğeleri — dikkat gerektirenler): içecek dolabı (13,5)-(13,7) · dondurucu (13,13) · koli (20,6) · koli (21,2) · araba (7,17)-(9,17) · dış kasalar (4,15),(5,15). Çıkartmalar §2.1.
Önerilen yardımcı çizim (yalnız okuma için; dosyaya işlenmez — `Props` koordinatı kaynak):
```
satır 2 : %,,,,,,,,,,,,,,,,,,,,,K,e,____%   K=koli(21,2)
satır 5 : %#..o..j.....F#:::O:::#,,____%   F=dolap(13,5..7) · satır 6: (20,6) K
satır 13: %#D...........Ç........#,,____%   D=gazete(2,13) · Ç=dondurucu(13,13); paspas (11,13)
satır 15: %,,a,K,K,g,,,b,,,h,,,,,,,,c,____%   K=meyve kasası (4,15),(5,15)
satır 17: %_______AAA______________XXXX%    A=araba(7..9,17)
```
Mevcut keseler (korunur): (15,5)-(15,7) nakit cebi — D kapısından ve O'dan (16-17 rafları) **yalnız satır 6-7 gizli**, (15,5) O'dan görünür → nakit M (15,7) doğru yerde. Yeni: (21,6)-(21,7) koli arkası (O'dan gizli, D'den açık). Her kese ≥ 2 karo derin, girişi 1 karo; bakkalda toplam 2 (T1 hedefi).
İsteğe bağlı 2b (düzen değişir, karar gereken): **poster camı** — tohumla ön camlardan 1 parça (ör. (8,14)) görüş kesen `WindowPoster` varyantı olur; o parçanın `WindowLook`'u iptal → "hangi cam kör" keşif bilgisi (Faz 3), bakkalın ikinci zamansal olmayan sırrı.

## 5. Seviye tasarım ilkeleri T1-T4 ve şablon/modül kuralları (§10 eki)
| İlke | T1 bakkal | T2 benzinlik | T3 kuyumcu | T4 depo | Kural |
|---|---|---|---|---|---|
| Giriş sayısı | 2 kapı (ön açık, arka T1 kilit) + cam görüşü | 2 kapı + araç yanaşma (yan) | 2 kapı + vitrin (gürültülü) | 3 kapı + kanal (§7.6) | Her mekânda ≥ 2 giriş, farklı cephelerden; biri "sessiz-yavaş", biri "hızlı-görünür". |
| Gözetleme noktası | dış: kaldırım cam önü (g,h,i = oyuncu için de); iç: raf koridoru ağzı (10,9) kasayı görür | dış: pompa arkası; iç: raf | dış: karşı kaldırım; iç: yok (küçük) | iç: raf üstü/kat | Her hedef (kasa, nakit) ≥ 1 güvenli noktadan görülür; "önce gör, sonra gir" [5]. |
| Saklanma kesesi | 2 (nakit cebi, koli arkası) | 2-3 (DVR odası, araç) | 2 | 4+ (koli, forklift, karanlık) | Her gözlemci rotası boyunca ≤ 6 karoda bir kese; kese ≥ 2 karo derin, görüş kesen kenar. |
| Kaçış çeşitliliği | ön→kaldırım (kısa, görünür) / arka→yan sokak (uzun, sessiz); E her ikisine ±3 karo eşit | + araç | + çatı/arka avlu | + yükleme kapısı | ≥ 2 kaçış, zıt yönlü, biri gürültülü-kısa biri sessiz-uzun; kaçış kolaylığı kademeyle düşer (T1 kolay = güven [5]). |
| Öğretme sırası (ilk 90 sn) | 1 camdan bak → 2 kapı zili/sahip bakışı → 3 müşteri tarafı serbest → 4 personel tarafı "?" → 5 pencere (sahip rafa gitti) → 6 arka kapı/kese | kamera görüş alanı önce boş odada | kod yeri | devriye periyodu | Her yeni öğe önce **tehditsiz** görülür (Hitman ilk seviye dersi [4]), sonra bedeliyle. |
Şablon/modül kuralları (§10 doğrulayıcıya ek) [görüş]: modül `occluders` (G), `low_props` (Ö), `decals`, `hiding_pockets` (karo listesi), `vantage_points` bildirir; doğrulayıcı: kese sayısı ≥ kademe hedefi, her hedefe ≥ 1 gözetleme noktası, G öğeleri koridor genişliğini < 2 karoya düşürmez, dekor yoğunluğu §2.1 sınırında, her kaçış rotası G öğelerle kapanmaz; "imza öğesi" listesi kademe başına 3 (bakkal: meyve kasaları, çay-tespih, buzdolabı ışığı) — tohum konumu değil varlığı değiştirir (Monaco 2 dersi: tekrar değeri davranıştan).

## 6. Kalem taslakları
| # | Başlık | Sahip | Büyüklük | Faz | AC (özet) |
|---|---|---|---|---|---|
| K1 | Bakkal dekor ve ışık v1 | seviye | S | 2b | §2.1'den ≥ 12 öğe `PropDef`/çıkartma; §3 üç katman (kontrast birim testi ThemeTokens'tan); hiçbir öğe işaret/eşik/koridor karosunda (test_levels eki); nav yeniden üretim, mevcut senaryolar geçer; ışık havuzları §2.2 (görsel, `GAMEPLAY_*` değil `LEVEL_*` token); 1280×720 görüntüde oyun nesneleri %50 küçültmede seçilir. |
| K2 | Sahibin ajanda telegrafları (çay, koli, telefon zili) | oynanis (+seviye çıkartma) | S | 2b | `Agenda.next_task_preview(name, in_s)` sinyali ≥ 3 sn önce; koli çıkartması sonraki RestockSpot'ta; telefon zili 1 sn önce (NoiseBus 160); çay bardağı durumu çoğaltılır; headless: her geçişte telegraf 1-3 sn önce, telegrafsız geçiş 0; hareket azaltmada da görünür. |
| K3 | Keseler ve koli engelleri (arka oda + ara sokak) | seviye | XS | 2a/2b | (20,6), (21,2) çarpışan oklüder; birim: O→(21,7) görüş kesik, D→(21,7) açık; e→(20,2) kesik, f→(20,2) açık; StreetRoute ve B/D yolları yürünebilir (nav testi). |
| K4 | Ambiyans sesi v1 (buzdolabı, sokak, arka oda) | arayuz (IS-024 uzantısı) | XS | 2b | 3 konumsal döngü, mesafe zayıflaması; NoiseBus'a girmez, halka çizmez; sokak geçişi nüfus tohumuyla eş; ayarlardan ambiyans ses düzeyi. |
| K5 | Poster camı tohum varyasyonu | seviye (+oynanis WindowLook iptali) | S | 3 | Tohumla 0-1 ön cam parçası görüş kesen; o parçanın WindowLook'u pasif; plan krokisinde (bilinmeyen katman) poster **çizilmez** (keşifle öğrenilir); senaryo: posterli parçadan yoldan geçen kasayı görmez. |
| K6 | Dekor-oyun nesnesi okunurluk kapısı | altyapi (+seviye) | XS | 2b | ci_local'e görüntü testi: her oyun nesnesi kenarı ↔ zemin ≥ 3:1, dekor ≤ 1,6:1; z-sırası testi (işaret daima dekor üstünde). |
Sıra önerisi: K3 (ucuz, kese mekaniği test-2'ye yetişir) → K1 → K2 → K4 → K6 → K5.

## 7. Riskler ve karar gereken
- **Dağınıklık okunurluğu bozar:** yoğunluk sınırı (%5 çarpışan, %12 çıkartma) ve K6 kapısı; test-2 anketine "kasa/kapıyı ilk bakışta buldum" sorusu. Neyi riske atıyor: çok az dekor "boş prototip" hissini sürdürür — bu yüzden imza öğeleri önce.
- **Yeni oklüderler sahip ajandasını bozar:** (13,5)-(13,7) dolabı sahibin RAF→TEZGÂH dönüş yolunu uzatmaz (yol sütun 11-12), ama US-008 AC2 ölçümü (kasa görüş dışı 60-120 sn) K1/K3 sonrası **yeniden koşulmalı**.
- **Alçak engel yanılgısı:** oyuncu dondurucunun arkasına "saklandım" sanır; şekil dili (dolgusuz = görüş kesmez) + test-2 gözlemi; gerekirse alçak engelleri çarpışmaz yap.
- **AI asset tutarlılığı:** 16 öğe farklı üretimlerden gelirse "kolaj" olur → `sanat-yonu.md` hattı: tek stil referansı, tek üretim oturumu, `assetler.md` kaydı; kuklalar kodla (KR-017) — dekor ile karakter ölçeği (44 birim) uyumu için tek "ölçek kartı" (1 karo = 32 px = ~70 cm; buzdolabı 1×3 karo).
- **Performans:** çıkartmalar tek `MultiMesh`/tek doku atlası; `_draw` değil Sprite2D; 30×20 haritada önemsiz, T8+ kanatlı şablonlarda atlas şart.
- **Telegraflar oyunu kolaylaştırır:** K2 ile pencere tahmini kesinleşir → IS-015 botlarında temiz oran > %80'e çıkarsa telegraf süresi 3 → 1,5 sn ya da yalnız bir görev için (çay) tutulur.
- **Karar gereken:** (1) Bakkal **Türk mahallesi** mi (çay, tespih, nazar, "BAKKAL" tabelası; IS-030 Türkçe seslerle uyumlu; öneri: evet, metinler i18n) yoksa nötr Avrupa köşe dükkânı mı (İsveçli oyuncular)? (2) Arka oda karanlık köşesi **oyun kuralı** (KR-019 karanlık bölge, tohumla "ampul bozuk") mı, yalnız görsel havuz mu? Öneri: v1 görsel, Faz 3'te tohum varyasyonu.

## Kaynaklar
[1] https://www.gamedeveloper.com/design/how-i-gone-home-i-s-design-constraints-lead-to-a-powerful-story
[2] GDC "Level Design in a Day: The Level Design of Gone Home" — https://www.gdcvault.com/play/1022112/
[3] GDC 2019 "'Hitman' Levels as Social Spaces" (M. Podenphant Andersen) — https://gdcvault.com/play/1025879/Level-Design-Workshop-Hitman-Levels · özet https://gdconf.com/news/what-makes-hitman-2-levels-tick-find-out-gdc-2019s-level-design-workshop
[4] GDC Europe 2016 "Level design in Hitman: guiding players in a non-linear sandbox" — https://gdcvault.com/play/1023849/Level-Design-in-HITMAN-Guiding
[5] "The anatomy of a stealth encounter" — https://www.gamedeveloper.com/design/the-anatomy-of-a-stealth-encounter
[6] The Level Design Book, Cover — https://book.leveldesignbook.com/process/combat/cover
[7] RimWorld okunurluk — https://blog.habrador.com/2019/06/why-rimworld-sold-more-than-1-million.html
[8] Hotline Miami incelemeleri — https://critpoints.net/2016/04/23/hotline-miami-review/ · https://www.thexboxhub.com/hotline-miami-collection-review/
Ayrıca: okunabilirlik-2d.md (Darkwood, Teleglitch, Door Kickers, Monaco), benzer-oyunlar.md (Monaco 2, Teardown), tezgahtar-sindirme.md (Hitman bozuk para), ses-ve-sfx.md.
