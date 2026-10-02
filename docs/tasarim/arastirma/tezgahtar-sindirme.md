# Bakkal sahibi, mahalleli ve müşteri etkileşimleri: bakkalın tehdit modeli (tasarım araştırması, 3. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; sayılar `data/npc/*.tres` ve `data/scenario/t1_bakkal.tres` başlangıç adayıdır, oyun testiyle ayarlanır.
Kullanıcı yönü (2026-10-02, koordinatör iletisi): **bakkalda güvenlik yok** — devriye polisi, güvenlik görevlisi, kamera, panik/alarm düğmesi yok; silah çekme yok. Bakkal sahibi en fazla bağırır, sokaktan/komşulardan birileri gelir; polis dolaylı ve geç. Her kademenin kendi gerçekçi tehdit modeli olmalı. Bu not GDD §9 T1 satırını ("sivili sindirme", "devriye polisin periyodu"), KR-019 K2/K4'ü ve US-008/US-010 kartlarını **değiştirmeyi önerir** (Karar gereken §7); ilk sürüm (silahlı sindirme + düğme) T2+ notu olarak §6'da.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** bizim sayılarımızdan türetilmiş. Dayanak: GDD §2 (ilke 3, 4, 5, 8), §6, §12; US-006 algı bileşenleri; muhafiz-davranisi.md §2-4 (hız/sezgi/arama sayıları aynen kullanılır).

## 1. Emsaller (silahsız/sosyal gizlilik ve "haberci" siviller)

| Oyun / kaynak | Kural [olgu] | Bize ders [görüş] |
|---|---|---|
| Untitled Goose Game [1][2] | Dükkâncı kazı görünce süpürgeye koşar ve kovalar; köylüler kazdan biraz hızlıdır, kendi alanlarından kovar, kazın elinde kendi eşyaları varsa alana kadar kovalar; AI öngörülebilir, oyuncu "neyin neyi tetiklediğini" hızla öğrenir. | Bakkalın tehdidi silah değil **kovma ve eşyayı geri alma**; öngörülebilir tetikler (personel tarafı, çanta) komedi üretir. Mahalleli koşan oyuncudan yavaş, çanta taşıyandan hızlı. |
| Thief Simulator [3] | Ev sahibi hırsızı görünce çığlık atar, dışarı koşar, polisi arar; yoldan geçen sokakta şüpheli davranışı (çömelme, alet taşıma, büyük eşya, bahçeye girme, kilit açma) görürse polisi arar; polis 2 yıldızla gelir, mahalle uyarı seviyesi devriye getirir. | "Yoldan geçen" ikinci gözlemci; şüpheli davranış listesi bizim durum çarpanı tablosuyla aynı mantık. Polis **sonradan ve dolaylı**: bakkalda sahne dışı sayaç. |
| Hitman WoA [4][5] | Sivil saldırmaz, en yakın muhafıza koşup bildirir; bozuk para fırlatma NPC'yi "inceleme" durumuna sokar, rota bozulur; sivil izinsiz girende "eşlikle dışarı". | Bakkalda muhafız yok → sivilin bildireceği kişi **mahalleli**; dikkat dağıtma (raf devirme, kapı zili) = bozuk para. Sorgulama = eşlik etmenin yumuşak hali. |
| Payday 3 casing kipi [6] | Maskesiz: kamusal alanda sivil/muhafız/kamera görmez; özel alanda muhafız yakalarsa kamusal alana **eşlik eder** (anında bitiş yok); arama kipi açıksa gözaltına alır. | Müşteri tarafı = kamusal; tezgâh arkası/arka oda = özel. İlk ihlal = sorgu ve dışarı, ikinci = bağırış. Kademeli sonuç "adil" hissettirir. |
| Payday 2/3 siviller [7][8] | Bağırılan sivil geçici olarak yere yatar, bakılmazsa kalkıp alarma/telefona koşar (PD2); PD3 bu kalkma riskini kaldırdı; rehine takası zaman/kaynak alır. | **Bakkal için kapsam dışı** (silah/bağırarak sindirme T2+). Ders: gizli zamanlayıcı sinir bozar; her bekleyiş görünür olmalı. |
| Ready or Not [9] | Bağırma uyum emri; uymayan kaçar; uyum sürpriz/sayı ile artar. | T5 kalabalık için uyum olasılığı; bakkalda yok. |
| Monaco [10] | Sizi gören sivil polis çağırmaya çalışır; durum "?" ile okunur. | Sivil de "?"/"!" dilini konuşur; ayrı dil yok. |
| GTA V dükkân soygunu [11] | Silah doğrult → tezgâhtar yavaşça çantayı doldurur; mikrofona bağırmak hızlandırır. | Tam olarak **yapmayacağımız** şey (kullanıcı yönü): bakkalda silah yok. |
| Gerçek dünya: esnaf ve hırsız [12][13] | "Shopkeeper's privilege": makul sürede, makul biçimde alıkoyma hakkı; ama kolluk tavsiyesi: peşinden gitme, elini sürme, polisi ara; mağaza politikaları çatışmayı yasaklar. | Bakkal sahibi **kovalamaz**: bağırır, kapıyı tutar, mahalleli gelir. Gerçekçi ve komik ("Hırsız var!"). |

Çıkarımlar [görüş]: (1) Bakkalın tehdidi bir **saat**tir (bağırış → mahalleli 12-25 sn → polis 120 sn), düşman değil. (2) Oyuncunun araçları sosyaldir: oyala, arkaya gönder, dikkat dağıt, müşteri gibi davran. (3) Kaybetmek komik: yakadan tutulup bekletilmek, polise teslim; vurulmak değil.

## 2. Bakkal sahibi (BS) tasarımı

Mekân: bakkal mesaide, ön kapı açık; oyuncular **müşteri** olarak girer; tezgâh arkası ve arka oda "özel" (personel tarafı; US-005 kasa kuralı). Ganimet: kasa 150 (tezgâh arkası, 3 sn) + arka oda nakdi (çanta). BS `ClerkSpot`'ta; algı bileşenleri US-006 ile aynı (koni 45°/224 px, dönüş ≤ 120°/sn, eşikler 30/60/100), yalnız **durum çarpanı tablosu** farklı: müşteri olmak suç değildir.

| Oyuncu durumu (BS görüş hattında) | Çarpan | "?" (30) | Bağırış (100) | Not |
|---|---|---|---|---|
| Müşteri tarafında yürüme | 0 | — | — | İstediği kadar dolaşır (oyalanma şüphesi Faz 3 keşif). |
| Müşteri tarafında koşma | 0,5 | 1,2 sn | 4 sn (yakın bant) | Tuhaf, suç değil; boşalma 20/sn. |
| Sızma (çömelme) açıkta | 1,0 | 0,6 sn | 2 sn | Raf arkası görünmez (K1): sızma raf arkasında anlamlı. |
| Personel tarafı (tezgâh arkası, personel kapısı, arka oda) | 2,0 + anında 30 | 0 | 1,4 sn | "Buyurun, oraya giremezsiniz." En keskin tetik. |
| Çanta taşıma görünür | 2,0 | 0,6 sn | 1,4 sn | Çanta = kanıt. |
| Gürültü ≥ 120 px (kapı, koşu, raf) | +30 | anında | — | `HIZMET`'te 120 px altı yok sayılır (dalgın). |
| Müşteri damgalı oyuncu (alışveriş yapmış, 20 sn) | ×0,5 | — | — | 2b; "iyi müşteri" örtüsü. |

Durumlar (`brain_clerk.gd`, `core/fsm.gd`): `TEZGAH` (varsayılan) · `RAF` (her 40-60 sn 6 sn raf düzeltme, arkası dönük; 2b) · `HIZMET` (bir oyuncu tezgâhta sohbet/alışveriş: koni 20°'ye daralır ve yalnız o oyuncuya bakar; diğerleri görüş dışı) · `ARKA_ODA` ("arkada var mı?" isteği: 10 sn arka odada; kasa boş kalır) · `BAK` (≥ 30: "?" "Buyurun?", 0,5-1 sn) · `SORGU` (≥ 60: tezgâhtan çıkar, oyuncuya 110 px/sn yürür, 48 px'te durur, "Ne arıyorsunuz?" 3 sn; oyuncu müşteri tarafındaysa ve çantasızsa şüphe 20'ye iner, BS tezgâha döner — **kasa 6-8 sn boş**; personel tarafındaysa/çantalıysa/koşarsa → 100) · `BAGIR` (= 100: "Hırsız var!", gürültü 320 px her 4 sn; 2 sn'de ön kapıya gider, kapıyı tutar — `blocked`, içeri bakar, dükkânı terk etmez, kovalamaz; mahalleli ve polis sayaçları başlar; **geri dönmez**).

Tasarım notu [görüş]: `SORGU` bakkalın gizli hediyesidir: şüphelenen BS tezgâhı bırakır → ekip arkadaşına kasa penceresi açılır. "Birimiz şüpheli olsun" planı bilerek mümkündür; bedeli 100'e yakın yürümek.

## 3. Müşteri etkileşimleri (sindirmenin bakkal karşılığı; `Interactable` S7)

| Etkileşim | Nerede / nasıl | Etki | Bedel / sınır | Dilim |
|---|---|---|---|---|
| Oyala (sohbet) | Tezgâh müşteri tarafı, E tut 4 sn | BS `HIZMET`: koni 20° yalnız sohbet edene; gürültü < 120 px yok sayılır | En fazla 2 kez/iş; 3.'de +30 ("İşiniz yoksa…"); sohbet eden başka şey yapamaz (**üçüncü el**, bakkalda bile) | 2a |
| Arkada var mı? | Tezgâh, E 1 sn (şüphe < 30, bekleme 60 sn) | BS `ARKA_ODA` 10 sn (gidiş 2 + arama 6 + dönüş 2); kasa boş | Arka oda meşgul: orada görülen oyuncu anında 100; ikinci istek +30 | 2a |
| Raf devir | Raf, E 1 sn, gürültü 90 px | BS `BAK` → rafa yürür, 6 sn toplar (tezgâh boş) | Deviren BS konisindeyse +30 (suçüstü); iş başına 2 raf | 2b |
| Alışveriş | Tezgâh, E 2 sn | "Müşteri damgası" 20 sn (×0,5; koşma 0) | Para düşmez (Faz 2); 3.'de "yine mi?" +10 | 2b |
| Kapı zili | Ön kapı aç/kapa (var) | BS 1 sn kapıya bakar (koni döner) | Gürültü 160 (S8) → aynı zamanda +30 değil, yalnız bakış; kapı çarpma = +30 | 2a (mevcut) |
| Çanta devri / kaçış | US-012 | `BAGIR`'da ön kapı kapalı → arka kapı/arka sokak; `EscapeZone` arka sokakta | Çantayla koşan düşürür (160 px) | 2a |

[görüş] Sindirme (Q) bakkalda **yok**: silah yok, bağırmak BS'yi sindirmez, kızdırır (`BAGIR`'ı tetikler: Q = +100 BS'ye). Bu ileride T2'de "bağırarak sindirme" öğretilince anlamlı bir fark olur.

## 4. Mahalleli ve polis (tepki modeli)

**Mahalleli (`NPC responder`):** `BAGIR`'dan sonra `NeighborSpawn*` (kaldırım uçları) noktalarından 1. kişi t+12 sn, 2. kişi t+25 sn (tohum ±4; risk seviyesi 1-5 → 1-3 kişi). Hız 180 px/sn (koşan oyuncu 220: açık alanda yakalanmaz; çantayla yürüyen 140: yakalanır — çanta kararı gerilimi). FSM (muhafız kalıbı, muhafiz-davranisi §3 sayılarıyla): `GEL` (BS'nin son gördüğü konuma) → `ARA` (dükkân + arka sokak, 3 nokta, ≤ 25 sn) → `KOVALA` (görünür oyuncu; sezgi 2 sn) → `TUT` (28 px, 0,7 sn temas → `captured`, K3 donar; "yakadan tuttu") → `VAZGEC` (ön kapıda durur, kalır: dükkân kapanmıştır, içeride kalan ganimet alınamaz). Kapalı kapıyı 1 sn'de açar. Algı: koni 60°/256, dolum ×2 (sinirli; herkes şüpheli, müşteri çarpanı yok).

**Polis (dolaylı, geç):** sahnede yok. `BAGIR`'dan **120 sn** sonra "polis geldi": içeride ya da `EscapeZone` dışında kalan herkes yakalanmış sayılır, iş biter. HUD'da sayaç yalnız 3. kademede (okunabilirlik-2d §5). Yakalanan oyuncu iş sonunda "polise teslim" (kefalet Faz 4). Isı: bağırış +5, yakalanma +10 (Faz 4).

**Yoldan geçen (2b):** her 20-40 sn kaldırımdan geçer (140 px/sn), vitrine koni 40°/160 px, çarpan ×0,5; 100'e ulaşırsa durup BS'ye seslenir (BS şüphesi anında 60 → `SORGU`), BS arka odadaysa 5 sn sonra kendi bağırır (`BAGIR` eşdeğeri). Keşif değeri (Faz 3): geçiş sıklığı ("sokak sakin/yoğun" modifikatörü) ve BS raf döngüsü — bakkalın iki zamansal bilgisi (KR-019 K2 devriye polisinin yerine).

**Uyarı merdiveni bakkalda (0-3, `alert_level_changed` aynen):** 0 sakin · 1 şüphe (BS "?") · 2 sorgu (BS tezgâhı bıraktı / yoldan geçen seslendi; 20 sn'de söner) · 3 bağırış (kapı tutuldu, mahalleli geliyor, 120 sn polis; geri dönmez). Kademe adları ve tepki türü senaryo verisinden gelir (§5).

## 5. "Her senaryonun kendi tehdit modeli" (veri, kod değil)

[görüş] Tek `ThreatModel` Resource (`data/scenario/<kademe>.tres`, S10): gözlemci tipleri ve durum çarpanı tablosu, tepki veren tipi ve varış süreleri, kademe adları/metin anahtarları, "geri dönmez" eşiği, sahne dışı sayaç (polis), sonuç eşlemesi (aracı oranı). Muhafız/kamera/düğme kodu bir kere yazılır, hangi kademede var olduğu veride.

| Kademe | Gözlemci | Tepki veren | Geri dönmez eşik | Sahne dışı sayaç | Yeni öğrenilen |
|---|---|---|---|---|---|
| T1 bakkal | bakkal sahibi (+ yoldan geçen) | mahalleli 1-2 (12/25 sn) | bağırış | polis 120 sn | müşteri rolü, oyalama, arka oda, kaçış |
| T2 benzinlik | gece görevlisi + kamera/DVR + tezgâh altı düğme | görevli sessiz alarm → polis | düğme | polis 90 sn | kamera, DVR, **bağırarak sindirme + 8 sn tutma** (ilk sürümün tasarımı buraya) |
| T3 kuyumcu | gece bekçisi + alarm paneli | bekçi telsiz → özel güvenlik | telsiz | güvenlik 60 sn, polis 150 sn | kod, çift anahtar; silah çekme = gürültü para birimi (KR-006) |
| T4 depo | devriye güvenlik görevlileri + köpek | görevliler (muhafız FSM tam) | ikinci tespit | polis 120 sn | devriye rotası, ışık-karanlık, ceset saklama |

## 6. İlk sürüm notu (T2+): silahlı/bağırarak sindirme ve düğme

Bu notun ilk taslağı (aynı gün) bakkal için şunu öneriyordu; kullanıcı yönüyle **T2 benzinlik** kalemine taşınır: Q sindirme (menzil 96 px, koni 60°, görüş hattı, gürültü 140 px, bekleme 1 sn, T2'de uyum %100) → tezgâhtar `SINDI` (eller havada, algı kapalı); herhangi bir oyuncu ≤ 128 px + görüş hattında ise "tutuyor"; tutan yoksa 8 sn → `UZAN` (2 sn görünür telegraf, "!" + SFX) → `BAS` → sessiz alarm (uyarı 3, polis 90 sn); `UZAN` sırasında yeniden Q iptal eder ("Q! Q!" klip anı); `BAS` sonrası Q etkisiz; düğme = seviye işareti `PanicButton` (≤ 64 px). Kamera/gece görevlisi `SINDI` tezgâhtarı görürse +50/sn. Payday 2'nin gizli "kalkma" sayacı yerine görünür 2 sn pencere; Payday 3'ün "kalkma riskini kaldırma" kararının tersi, ama telegraflı [7][8]. Gerçek dünyada hold-up düğmesi sessizdir ve personel "yüz yüzeyken basma, fırsat bulunca bas" diye eğitilir [14] → fırsat kollayan tezgâhtar gerçekçi.

## 7. Kabul kriteri önerileri (US-008 ve US-010 yeniden tanımı) ve karar gereken

**US-008' — Tepki veren v0 (mahalleli) + bakkal tehdit modeli** (oynanis; US-006, US-007' bağımlı): (1) `entities/npc/responder/` (muhafız FSM kalıbı: `GEL/ARA/KOVALA/TUT/VAZGEC`; `data/npc/responder_tuning.tres` hız 180, arama ≤ 25 sn, tut 28 px + 0,7 sn, sezgi 2 sn, dönüş ≤ 120°/sn); yalnız host; 15-20 Hz özet. (2) `data/scenario/t1_bakkal.tres` (`ThreatModel`): varış 12/25 sn (tohum ±4), sayı risk seviyesine göre, polis 120 sn, kademe adları. (3) `Game` uyarı kademesi 0-3 (`alert_level_changed`, `cause`); 3'te 120 sn sayaç; sönüm 1→0 ve 2→1 20 sn; 3 geri dönmez. (4) Mahalleli kapalı kapıyı açar (Interactable host API); ön kapı `BAGIR`'da `blocked`. (5) Adalet (S2): aleyhte kararlar eşitleyici konumla, lehte 0,2 sn; tespit günlüğü `detections` + `net_flag`. (6) Değişmezler: I1 `captured` yalnız `TUT` ≥ 0,7 sn temas sonrası; I2 mahalleli yalnız `BAGIR` sonrası var olur ve varış ≥ 12 sn; I3 uyarı yalnız {0→1,1→2,2→3,2→1,1→0}; I4 tohum belirlenimciliği; I5 duvar içi yok. (7) Senaryo `neighbor_chase.json` (0/150 ms): BS bağırır → t+12 ilk mahalleli tüm peer'larda; koşan bot arka sokaktan `EscapeZone`'a varır (yakalanmaz); çantayla yürüyen bot yakalanır; t+120 polis → sonuç. (8) US-007 eki: `PolicePatrol*` yerine `NeighborSpawn*` (2) + `SearchSpot*` (3) + arka sokak `EscapeZone`; kamera/polis işaretleri kalkar. Muhafız FSM (devriye/telsiz) kodu korunur, T4'e kadar seviyede kullanılmaz.

**US-010' — Bakkal sahibi + müşteri etkileşimleri** (oynanis; US-006, US-008' bağımlı): (1) `entities/npc/clerk/` + `brain_clerk.gd`; §2 durumları; `data/npc/clerk_tuning.tres` (koni 45°/224, durum çarpanı tablosu, sorgu 3 sn/48 px, bağırış gürültüsü 320 px/4 sn, arka oda 10 sn, oyalama 4 sn/2 kez, bekleme 60 sn). (2) Etkileşimler 2a: Oyala, Arkada var mı? (`Interactable` bileşenleri tezgâhta; `InteractionRequirement` müşteri tarafı). (3) `SORGU`: BS tezgâhı bırakır ve döner; kasa bu sırada boşaltılabilir (senaryo). (4) `BAGIR`: ön kapı `blocked`, gürültü yayını, uyarı 3; US-008' sayaçları tetiklenir; Q/sindirme eylemi **yok** (girdi haritasına eklenmez). (5) Birim: durum çarpanı tablosu (müşteri yürüme 0 birikmez; personel tarafı anında 30; `HIZMET`'te koni 20° ve < 120 px gürültü yok sayılır; `ARKA_ODA`'da kasa 3 sn tamamlanır; 2. oyalama sonrası 3.'de +30). (6) Senaryo `clerk_social.json` (0/150 ms): (a) A oyalar 4 sn, B kasa 3 sn → 150, uyarı 0; (b) A "arkada var mı?" → B kasa → uyarı 0; (c) B sohbetsiz tezgâh arkasına → ~1,4 sn'de `BAGIR` → uyarı 3; (d) `SORGU` sırasında müşteri tarafına dönen oyuncu → uyarı 1'e iner. (7) SFX/görsel olay adları (`clerk_question`, `clerk_interrogate`, `clerk_shout`, `clerk_backroom`, `neighbor_arrive`) sinyalle; ses 2a yer tutucu. (8) Değişmezler: I1 `BAGIR` yalnız şüphe = 100'den; I2 `BAGIR` sonrası `TEZGAH`'a dönüş yok; I3 `HIZMET` yalnız etkileşim süresince; I4 |Δşüphe| ≤ hız×Δt (gürültü +30 günlüklü); I5 BS `ClerkSpot`–kapı–raf–arka oda dışına çıkmaz.

[hesap] 2 kişilik akış: A içeri (t=0), B arka kapı maymuncuk 6 sn (t=0-6, BS 160 px dışı: duymaz) → A oyalar (t=5-9), B arka oda nakdi 4 sn (t=8-12) ve arka kapıdan çıkar → A "arkada var mı?" (t=10) → BS arka odaya (t=12-22; B çıkmış olmalı, yoksa 100) → A kasa 3 sn (t=13-16) → A ön kapıdan yürüyerek çıkar (t=20) → TEMİZ, ~25 sn. 3 kişide C gözcü/çanta taşıyıcı ya da ikinci oyalayıcı; **üçüncü el** bakkalda "sohbet eden eli bağlı" olarak zaten var (açık soru 4'e cevap: bakkalda sosyal 3. el, T2'de mekanik). Faz 2 çıkış kriteri "koşan oyuncu ≤ 1 sn tespit" artık BS/mahalleli konisi için ölçülür; sayılar değişmez.

**Karar gereken:** (a) GDD §9 T1 satırı ve KR-019 K2/K4 bu modele göre güncellensin mi (sindirme/düğme → T2; devriye polisi → mahalleli + yoldan geçen)? (b) Polis sahne dışı 120 sn mi, yoksa Faz 2'de hiç yok (yalnız mahalleli) mu? Öneri 120 sn: kaybetme yolu ve sayaç deneyi için gerekli. (c) `SORGU`'da BS'nin tezgâhı bırakması 2a'da mı (kasa penceresi = planlı kaos) 2b'de mi? Öneri 2a. (d) Mahalleli sayısı: 2 kişilik oyunda 1, 3 kişide 2 (benzer-oyunlar §2d tablosu)? Öneri evet. (e) Yoldan geçen 2b'de mi (keşif değeri için Faz 3'e kadar şart)? Öneri 2b, Faz 3 öncesi.

Riskler: BS kovalamayınca iş "çok kolay" olabilir → ölçü: bot koşularında temiz tamamlama > %80 ise mahalleli 1. varış 12 → 8 sn, hızı 180 → 200. Oyalama tek çözüm haline gelirse (her koşu aynı) → "arkada var mı?" ve raf devirme bedelleri ayarlanır; ölçü: koşu JSON'unda etkileşim çeşitliliği (≥ 2 farklı yöntem/3 koşu). 150 ms'de `SORGU`'daki 3 sn pencere ve "müşteri tarafına geç" kararı host konumuyla → taraf kısıtına 24 px pay (S2, IS-014).

## Kaynaklar
[1] Untitled Goose Game dükkâncı — https://untitledgoosegame.fandom.com/wiki/Shopkeeper
[2] Untitled Goose Game AI öngörülebilirliği — https://godisageek.com/reviews/untitled-goose-game-review/
[3] Thief Simulator polis ve komşular — https://thief-simulator.fandom.com/wiki/Police
[4] Hitman NPC davranışı — https://hitman.fandom.com/wiki/NPC
[5] Hitman bozuk para dikkat dağıtma — https://kotaku.com/hitman-s-deadliest-weapon-is-a-coin-1830384113 · https://hitman.fandom.com/wiki/Classic_Coin
[6] Payday 3 casing / sosyal gizlilik — https://payday.fandom.com/wiki/Social_Stealth · https://steamah.com/payday-3-stealth-mechanics-guide/
[7] Payday 2 siviller (kalkma, alarm) — https://gameinformer.com/b/features/archive/2013/08/13/payday-2-strategy-guide · https://steamcommunity.com/app/218620/discussions/8/371918937268806264
[8] Payday 3 bağırma/bağlama/rehine takası — https://primagames.com/gaming/how-to-shout-at-civilians-payday-3 · https://primagames.com/tips/how-to-trade-hostages-in-payday-3
[9] Ready or Not uyum — https://earlyguides.com/ready-or-not/combat
[10] Monaco incelemesi — https://www.worthplaying.com/article/2013/5/16/reviews/89212-pc-review-monaco-whats-yours-is-mine/
[11] GTA V dükkân soygunu — https://cyberpost.co/which-stores-can-you-rob-gta-v-story/
[12] Shopkeeper's privilege — https://en.wikipedia.org/wiki/Shopkeeper%27s_privilege
[13] Hırsıza müdahale politikaları — https://marshalldennehey.com/articles/guidelines-dealing-suspected-shoplifters · https://int.foxillinois.com/news/local/retailers-rights-when-it-comes-to-shoplifting
[14] Hold-up düğmesi uygulaması (T2 notu) — https://www.sdmmag.com/articles/82345-revisiting-the-panic-button
