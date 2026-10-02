# Tezgâhtar ve sindirme (Q): emsaller, durum makinesi, US-010 için sayılar (tasarım araştırması, 3. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; sayılar `data/npc/clerk_tuning.tres` başlangıç adayıdır, oyun testiyle ayarlanır.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** bizim sayılarımızdan türetilmiş.
Dayanak: GDD §6 (şüphe 30/60/100, tespit sonucu "sivil panikler ya da düğmeye basar"), §9 T1 ("sivili sindirme", T2 "rehine = üçüncü el"), §16 açık soru 4; KR-019 K2 (polis 75 ± 10 sn), K4 (8 sn tutulmazsa düğmeye uzanır; 3. el T2'de); mimari S8 (sindirme gürültüsü 140 px), S11 bileşenler; US-006/US-008 (`Perception`/`Suspicion`, `alert_level_changed`); muhafiz-davranisi.md §2-3.

## 1. Emsaller

| Oyun | Sivil/rehine kuralı [olgu] | Bize ders [görüş] |
|---|---|---|
| Payday 2 [1][2] | Bağırma sivili yere yatırır; **geçicidir**: göz kulak olunmazsa bir süre sonra kalkıp telefona/alarma/çıkışa koşar; kelepçe (cable tie) kalıcı: hareket edemez, haber veremez; panikleyen sivil en yakın panik düğmesine, telefona ya da harita dışına (alarm) gider; rehineler polis dalgasını geciktirir. Cevapsız telsiz/telefon 15-20 sn sonra alarm. | "Bağır → sakin → tekrar bağır" döngüsü hata bütçesi gibi hissedilir; düğme **somut bir hedef** (sivil "nereye" koşuyor okunur). Kelepçe = kalıcı çözüm, T2+ ekipman adayı. |
| Payday 3 [3][4] | Bağırma (orta tuş) → yere; F basılı tutarak bağla; geliştiriciler "bağırılan sivilin kalkıp kaçması" riskini **kaldırdı**; canlı kalkan; rehine takası (zaman, kaynak, kapı); gözaltından çıkış 1 rehine + her tekrar için +1. | Kalkma riskini kaldırmak sindirmeyi "ücretsiz" yapar; biz K4 ile tersini seçiyoruz (8 sn), ama **telegraf** şart. Rehine takası = Faz 4 kefalet/ekip kararı emsali. |
| Hitman WoA [5][6] | Sivil saldırmaz; şüphelenirse **en yakın muhafıza koşup bildirir**; tanıklar derecelendirmeyi düşürür; çatışmadan kaçar; muhafız izinsiz girende eşlik ederek dışarı çıkarır. | Sivil tehdit değil **haberci**: tehlikesi hız ve mesafeyle ölçülür (muhafıza/düğmeye kaç saniye?). Keşif fazı için "eşlikle dışarı" (Faz 3). |
| Ready or Not [7][8] | Bağırma (F) uyum emri; uymayan kaçar ya da ateş eder; uyum olasılığı flaş, sayıca üstünlük ve sürprizle artar; ateş etmeden önce teslim fırsatı verilmeli. | Uyum **olasılığı** bağlam çarpanı: T1'de %100 (öğretir), T5+ kalabalıkta sürpriz/sayı çarpanı. Bizim sindirmede "sürpriz" = koni dışından yaklaşmak. |
| Monaco [9][10] | Sizi gören sivil muhafız/polis çağırmaya çalışır; "hemen her şey yetkilileri uyandırır"; durum muhafız başında "?". | Sivil de "?"/"!" dilini konuşmalı; sivil için ayrı dil icat etme. |
| GTFO | Sivil yok; ikili uyanma eşiği (ışık/hareket/gürültü). | Emsal değil; "eşik ikili, telegraf uzun" ilkesi bizde REACH penceresi. |
| Gerçek dünya: tezgâh altı düğme [11][12][13] | Hold-up düğmesi sessizdir, izleme merkezi polisi yönlendirir; personel eğitimi: saldırganla yüz yüzeyken **basma**, fırsat bulunca bas; bazı sistemler önce yöneticiyi uyarır. | "Fırsat kollayan tezgâhtar" gerçekçi: izlenmediği an uzanır. Sessiz alarm oyuncuya ses vermez; yalnız HUD merdiveni 3'e çıkar (okunabilirlik-2d §5). |

Çıkarımlar [görüş]: (1) Sivil bir **saat**tir, düşman değil: her durumunun oyuncuya görünür bir "kaç saniye" karşılığı olmalı. (2) Payday'in gizli kalkma zamanlayıcısı sinir bozar; bizde kalkma yok, **uzanma** var ve 2 sn görünür. (3) Sindirme kendi başına bedel taşımalı (gürültü 140 px + camdan görünen "eller havada" tezgâhtar), yoksa her koşuda refleks olur.

## 2. Tezgâhtar tasarımı (bakkal, T1)

Mekân gerçeği: bakkal mesaide, ön kapı açık, oyuncular **müşteri** olarak içeri girer. Tezgâhtar `ClerkSpot`'ta durur (US-007), kasa yalnız tezgâh arkasından boşaltılır (US-005), arka oda nakdi arka kapıdan (T1 kilit, US-009) ya da dükkân içinden personel kapısıyla alınır. Tezgâh altı düğme tezgâhtarın 2 karo yakınında (`PanicButton` işareti, §5).

**Tezgâhtarın algısı** (US-006 bileşenleri aynen; yalnız "durum" çarpanı tablosu farklı — müşteri olmak suç değildir):

| Oyuncu durumu (tezgâhtarın görüş hattında) | Çarpan | "?" (30) | Uzanma (100) | Not |
|---|---|---|---|---|
| Müşteri tarafında yürüme | 0 | — | — | Normal müşteri; sonsuza kadar dolaşabilir (keşif oyalanması Faz 3). |
| Müşteri tarafında koşma | 0,5 | 1,2 sn (yakın) | 4 sn | "Tuhaf" ama suç değil; boşalma 20/sn. |
| Sızma (çömelme) | 1,0 | 0,6 sn | 2 sn | Raf arkasında görünmez (K1): sızma rafların arkasında anlamlı, açıkta şüpheli. |
| Personel tarafı (tezgâh arkası, personel kapısı, arka oda) | 2,0 + anında 30 | 0 sn | 1,4 sn | "Buyurun, oraya giremezsiniz" balonu; en keskin tetik. |
| Çanta taşıma görünür | 2,0 | 0,6 sn | 1,4 sn | Çanta = suç kanıtı. |
| Gürültü ≥ 120 px tezgâhtarın menzilinde | +30 | anında | — | Kapı çarpması, koşu adımı: muhafızla aynı kural (muhafiz-davranisi §2). |
| Yakalanmış/sindirilmiş başka sivil görmek | — | — | — | T1'de ikinci sivil yok; T2'de ×2. |

Eşik tepkileri: 30 → `BAK` (döner, "?"), 60 → `UYAR` ("Hey!" balonu; sözlü uyarı, alarm yok; 3 sn içinde personel tarafı terk edilirse 20'ye düşer), 100 → `UZAN` (2 sn telegraf) → `BAS` → küresel uyarı 3. Yani sindirmeden de iş yapılabilir ama tezgâhtarın gördüğü her personel-tarafı eylemi ~1,4 + 2 sn içinde alarmdır: **kasa (3 sn tut) tezgâhtar bakarken alınamaz** → sindirme ya da tezgâhtarın arkası dönükken. [görüş] Tezgâhtar her 45 sn'de 8 sn raf düzeltir (arkası dönük, koni raflara): keşifte öğrenilebilir ikinci zamansal bilgi; tohumla ±10 sn (Faz 3).

**Sindirme (Q):** anlık komut (0,3 sn animasyon, host yetkili), menzil 96 px (3 karo) + 24 px host payı (S2), hedef koni 60° içinde, görüş hattı şart; gürültü 140 px (S8) → dışarıdaki polis vitrin önündeyse duyar ("?" + DINLE). Bekleme 1 sn. T1'de uyum %100; başarısızlık yalnız menzil/görüş. Tezgâhtar `SINDI`: eller havada, hareketsiz, algısı kapalı (artık şüphe biriktirmez), düğmeye uzanmaz **tutulduğu sürece**.

**Tutma (K4):** herhangi bir oyuncu tezgâhtara ≤ 128 px (4 karo) ve görüş hattında ise "tutuyor" sayılır; ayrı tuş yok, oyuncu bu sırada kasayı boşaltabilir (kasa tezgâhtarın yanında → 2 kişilik iş mümkün). Tutan yoksa host sayacı başlar: **8 sn** sonra `UZAN` (2 sn, "!" balonu + `clerk_reach` SFX + eller düğmeye), 10. sn'de `BAS` → uyarı 3 (90 sn polis sayacı, US-008 AC4). `UZAN` sırasında yeniden Q → `SINDI`, sayaç sıfır ("Q! Q!" klip anı). `BAS` sonrası Q etkisiz (alarm gitti); tezgâhtar `SINDI_KALICI` (yerde, iş sonuna kadar).

**Polisin tezgâhtarı görmesi:** `SINDI` ya da `UZAN` durumundaki tezgâhtar polisin konisine girerse polis şüphesi +50/sn (yakın bantta koşan oyuncu gibi): 3 sn vitrin bakışında tespit. [hesap] Sindirme = saati oyuncu başlatır (Teardown ilkesi): polis geçtikten hemen sonra sindirirsen ~70 sn temiz pencere; polisin periyodu bakkalın tek keşif bilgisi olur (GDD §9 T1).

**Sonuç kuralı (US-012'ye öneri):** düğme basıldıysa iş sonucu en iyi "SESSİZ ALARM" (aracı %70); herkes çıktıktan sonra basılırsa sonuca etkisi yok (Faz 4'te ısı +5). Sindirme tek başına "TEMİZ"i bozmaz; gürültüsü ve polis riski bedelidir. Karar gereken §6.

## 3. Durum makinesi (`brain_clerk.gd`, `core/fsm.gd` ile; US-008 kalıbı)

`CALIS` → `RAF` (her 45 sn, 8 sn, arkası dönük) → `CALIS`; `CALIS`/`RAF` → `BAK` (şüphe ≥ 30) → `UYAR` (≥ 60) → `UZAN` (= 100 ya da tutulmadan 8 sn) → `BAS` → `SINDI_KALICI`; herhangi biri (BAS hariç) → `SINDI` (Q); `SINDI` → `UZAN` (tutan yok 8 sn) → `SINDI` (Q) ya da `BAS`.

| Geçiş | Koşul | Çoğaltılan çıktı |
|---|---|---|
| CALIS → BAK | şüphe ≥ 30 | yön = oyuncu; "?" balonu; `clerk_question` |
| BAK → CALIS | şüphe < 30 ve ≥ 0,5 sn | balon söner |
| BAK → UYAR | şüphe ≥ 60 | "Hey!" balonu; `clerk_warn`; **uyarı kademesi değişmez** |
| UYAR → UZAN | şüphe = 100 | "!" balonu; eller düğmeye; `clerk_reach`; 2 sn kilit |
| SINDI → UZAN | 8 sn boyunca tutan yok (host) | aynı |
| UZAN → BAS | 2 sn doldu, Q gelmedi | `Game` uyarı 3 (`cause: clerk_button`); HUD merdiveni 3; **ses yok** (sessiz) |
| * → SINDI | Q geçerli (menzil, koni, görüş) | eller havada; `clerk_comply`; gürültü 140 px (NoiseBus) |
| BAS → SINDI_KALICI | anında | yerde; algı kapalı; etkileşim yok |

Değişmezler (test edilebilir): I1 uyarı 3 `clerk_button` nedeniyle yalnız `BAS`'tan sonra; `BAS` yalnız kesintisiz 2,0 sn `UZAN`'dan sonra (±1 kare). I2 `SINDI → UZAN` yalnız host saatinde ≥ 8,0 sn "tutan yok" sonrası; tutan varken sayaç 0'da kalır. I3 Q menzil/koni/görüş şartı sağlanmadan hiçbir durumda `SINDI` üretmez; istemci tek başına durum değiştiremez. I4 `SINDI` ve `SINDI_KALICI`'de şüphe birikmez (0 sabit). I5 Aynı tohum + aynı bot zaman çizelgesi → olay günlüğü birebir aynı. I6 Tezgâhtar `ClerkSpot`–`PanicButton` dışına çıkmaz (T1'de kaçma yok). I7 Durum geçişi dışında şüphe |Δ| ≤ hız × Δt (ses +30 günlüklü).

## 4. 150 ms gecikme ve adalet

- Q istemi istemciden; host kendi eşitleyici konumuyla menzili doğrular (+24 px, S2). İstemci bağırma animasyonunu hemen oynatır; red gelirse (menzil dışı) animasyon biter, ceza yok (GDD §12).
- `UZAN` penceresi 2,0 sn host'ta; istemci "!" balonunu ~75-100 ms geç görür → gördüğü pencere ≥ 1,9 sn; Q + RTT yolculuğu 150 ms → kurtarma için fiilen ~1,7 sn. [görüş] 2 sn alt sınırdır; testte "göremedim" çıkarsa 2,5 sn.
- Tutma kararı (≤ 128 px) oyuncu lehine: host 100-175 ms eski konumu görür; uzaklaşırken sayaç geç başlar (lehine), yaklaşırken geç durur (aleyhine, en çok 0,2 sn) → sayaca 0,2 sn pay eklenir (fiilen 8,2 sn).
- Bakkal sis kuralı (okunabilirlik-2d §2.6): tezgâhtarın durumu yalnız ekip görüş hattındayken çizilir → arka odadaki ekip `UZAN`'ı **göremez**. Bu bilerek: biri gözünü tezgâhtarda tutmalı (co-op talebi). HUD'da "tezgâhtar tutulmuyor" uyarısı **yok** (bilgi oyuncunun kafasında, GDD ilke 1).

## 5. Sayılar (özet; `clerk_tuning.tres` adayı)

Sindirme menzili 96 px · koni 60° · bekleme 1 sn · gürültü 140 px · tutma yarıçapı 128 px · tutulmama 8 sn (+0,2 ağ payı) · uzanma 2 sn · düğme uzaklığı ≤ 64 px (`PanicButton` işareti `ClerkSpot`'a 2 karo içinde) · raf düzeltme her 45 sn 8 sn · tezgâhtar koni 45°/224 px (muhafızdan dar ve kısa; dükkân içi) · dönüş ≤ 120°/sn · polis için SINDI tezgâhtar +50/sn.

[hesap] 2 kişilik akış: polis vitrini geçer (t=0) → A içeri yürür, Q (t=6) → A kasa 3 sn (t=9, +150) → B bu sırada arka kapı maymuncuk 6 sn (t=0-6), arka oda nakdi tut 4 sn (t=10-14) → B çantayla arka kapıdan çıkar (t=18) → A çıkar (t=12'de bırakırsa düğme t=22'de basılır; A ve B kaçış bölgesine t≈25-30) → sonuç TEMİZ ya da SESSİZ ALARM (B hâlâ içerideyse). Polis bir sonraki bakışı t≈75: bol pay. 3 kişide C vitrinde gözcü (ping) ya da tezgâhtarı tutar, A+B iki ganimete paralel gider: **3. el bakkalda mekanik değil sosyaldir**; T2'de tezgâhtarı DVR odasından uzak tutmak için Q basılı tutma (tutan oyuncu başka şey yapamaz) → gerçek üçüncü el (açık soru 4'e cevap: T2).

## 6. US-010 için kabul kriteri önerileri ve karar gereken

AC önerisi: (1) `entities/npc/clerk/` + `brain_clerk.gd`; §3 durumları; sayılar `data/npc/clerk_tuning.tres`; `Perception`/`Suspicion` aynen, durum çarpanı tablosu (§2) veride. (2) Girdi eylemi `intimidate` (Q + gamepad; project.godot girdi istisnası, S5) → host RPC; menzil/koni/görüş/bekleme `core/clerk_rules.gd`'de düğümsüz birim test. (3) Tutma, 8 sn, 2 sn uzanma, `BAS` → `Game` uyarı 3 (`cause`); yeniden Q iptal; `BAS` sonrası Q etkisiz. (4) Sindirmesiz yol: personel tarafı ×2 + anında 30; kasa tezgâhtar bakarken tamamlanamaz (uzanma kasadan önce biter) — birim test. (5) Polis `SINDI`/`UZAN` tezgâhtarı +50/sn görür (US-008 `Perception` hedef grubu genişler: `suspicious_npcs`). (6) Seviye işareti `PanicButton` (US-007 eki ya da bu kalemde layouts; karar koordinatörün). (7) Senaryolar `clerk_intimidate.json` (0/150 ms): (a) bot Q → 3 sn kasa → uzaklaşır → t+10 sn'de tüm peer'larda uyarı 3; (b) t+9'da yeniden Q → uyarı 0 kalır; (c) bot sindirmeden tezgâh arkasına girer → ~3,4 sn'de uyarı 3; (d) raf arkasından sızan bot → şüphe 0. (8) SFX/görsel olay adları (`clerk_question`, `clerk_warn`, `clerk_reach`, `clerk_comply`) sinyalle; ses 2b'de bağlanır. (9) Değişmezler I1-I7 birim testte; ci_local yeşil.

Karar gereken: (a) Düğme basıldıktan sonra herkes kaçarsa sonuç TEMİZ mi (öneri: evet, Faz 4'te ısı +5) yoksa SESSİZ ALARM mı? (b) Tezgâhtar raf düzeltme döngüsü 2a'ya mı (sindirmesiz "temiz" yol açar; +S iş) 2b'ye mi? Öneri 2b. (c) `UZAN` 2 sn mi 2,5 sn mi? Öneri 2 sn, testte ayar. (d) Polis sindirilmiş tezgâhtarı görünce doğrudan tespit mi (+50/sn, 2 sn) yoksa yalnız inceleme (60'ta durur) mu? Öneri +50/sn; bakkal "polis geçince sindir" dersini öğretsin.

Riskler: sindirme refleksleşip her koşu aynı akışa dönerse (gürültü ve polis bedeli yetersizse) tezgâhtar "düğme" değil "tuş" olur → ölçü: koşuların ≥ %30'unda sindirmesiz (arka kapı) yol seçiliyor mu (koşu JSON'u `interaction` olayları). 2 sn pencere 150 ms'de dar kalırsa "göremeden bastı" şikâyeti → `net_flag` benzeri günlük (`t_reach`, `t_q`, `rtt`).

## Kaynaklar
[1] Payday 2 stratejisi (siviller, kelepçe) — https://gameinformer.com/b/features/archive/2013/08/13/payday-2-strategy-guide
[2] Payday 2 Steam tartışmaları: sivil kalkma/alarm davranışı, telefon 15-20 sn — https://steamcommunity.com/app/218620/discussions/8/371918937268806264 · https://steamcommunity.com/app/218620/discussions/8/1736595131056357980
[3] Payday 3 bağırma ve bağlama — https://primagames.com/gaming/how-to-shout-at-civilians-payday-3
[4] Payday 3 rehine takası ve geliştirici günlüğü — https://primagames.com/tips/how-to-trade-hostages-in-payday-3 · https://www.videogameschronicle.com/news/payday-3-developer-diary-details-the-games-evolved-heist-experience
[5] Hitman NPC davranışı — https://hitman.fandom.com/wiki/NPC
[6] Hitman (2016) — https://en.wikipedia.org/wiki/Hitman_(2016_video_game)
[7] Ready or Not uyum mekaniği — https://earlyguides.com/ready-or-not/combat
[8] Ready or Not AI — https://www.pcgamesn.com/authentic-tactical-shooter/
[9] Monaco incelemesi (siviller polis çağırır) — https://www.worthplaying.com/article/2013/5/16/reviews/89212-pc-review-monaco-whats-yours-is-mine/
[10] Monaco incelemesi — https://indiegamereviewer.com/monaco-game-review/
[11] Panik düğmesi uygulaması ve eğitimi — https://www.sdmmag.com/articles/82345-revisiting-the-panic-button
[12] Hold-up/duress sistemleri — https://forcesecurity.ca/panic-button-systems/
[13] Duress kodu (perakende) — https://www.huntingretailer.com/business/do-you-know-your-duress-code
