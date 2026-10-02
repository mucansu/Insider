# Muhafız davranışı: emsaller ve US-008 için sayılar (tasarım araştırması, 2. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; sayılar `data/npc/*.tres` başlangıç değeri adayıdır, oyun testiyle ayarlanır.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** benim çıkarımım · **[hesap]** bizim sayılarımızdan türetilmiş.
Dayanak: GDD §6, §12; KR-019 (iki bantlı koni, 25 × bant × durum, eşikler 30/60/100, boşalma 20/sn, dönüş ≤ 120°/sn); backlog US-006/US-008; benzer-oyunlar.md §2a. Kaynak numaraları sonda.

## 1. Emsaller (ne yapıyorlar, hangi sayılarla)

| Oyun / kaynak | Durumlar | Sayılar ve kurallar [olgu] | Son görülen konum ve arama |
|---|---|---|---|
| Splinter Cell Blacklist (Game AI Pro 2 §28) [1][2] | görmedi → (ara eşik: incele) → tespit; tespit sonrası farkındalık düşmez | Tespit sayacı, oyuncunun bulunduğu görüş şekline göre bir aralıkta, mesafeyle doğrusal ölçeklenir; sayaç dolunca tespit. Yakın koni + uzak "tabut" kutusu (uzakta yanlara daralır). Şeklin 1 cm dışı asla, 1 cm içi "en fazla birkaç saniyede" tespit = eşik sorunu; çözüm tutarlılık + geri bildirim. Ekran dışı ve uzak NPC'lerin duyması ½ (adalet). Üç kademeli bağırış havuzu (özel → genel). Yan yana duran NPC 10 sn duyup 5 sn duymayınca "arkadaşım nerede" incelemesi. | "Adil, tutarlı, iyi geri bildirimli, makul" dörtlüsü; oyuncunun ne gördüğü simülasyondan önemli. |
| "Looking for Trouble" (Game AI Pro 2 §27, Welsh) [3] | temkinli arama (kaynak bilinmiyor: ses) / saldırgan arama (hedef biliniyor) | Görüşü kaybedince NPC hedef konumunu **2-3 sn daha bilir** ("sezgi"); temkinli: yürüyerek uyaranın yerine git, bak, bitir; saldırgan: koşarak son konuma, sonra 2. faz: saklanabilecek noktalar listesi, aynı anda **2-3 arayan**, zaman sınırı; arayanlar tek tek, aynı anda değil vazgeçer. | 1. faz = son görülen konum, 2. faz = kapsama noktaları; geçiş sesle/animasyonla duyurulur. |
| Mark of the Ninja (Game AI Pro §32 + wiki) [4][5] | boşta → "?" (şüpheli, arar) → "!" (alarm, devriyeye dönmez) | İlgi öncelikleri: kırık ışık 1, kayıp arkadaş 2, şüpheli/ceset/ses 4, dehşet 20; eşit öncelikte **en yeni kazanır**; grup: lider / araştıran / seyirci rolleri (herkes koşmaz); her ilgi bir kez fark edilir; "şüpheli" ilgisi hedef görüş menzilinden uzun → görmeden önce bakmaya gelir; ses yol bulmayla yayılır (duvar keser); art arda adımlar tek ilgi. | Alarmdan sonra "bir süre görünmeyince" devriyeye dönüş. |
| Shadow Tactics / Desperados III [6][7] | koni üç bölge | Açık renk yakın bölge: anında; koyu/taralı uzak: çömelince görünmez; noktalı: sığınak (her zaman gizli). | Sıra tabanlı değil; süre kaynaklarda yok. |
| Dishonored 2 [8][9] | 4 kademe: kısa bakış → kısmi beyaz (gelir, son yere bakar) → tam kırmızı (kovalar) | Göz üstü çubuk; görüş kaybında "birkaç saniye" arar, "birkaç dakika" sonra alt kademeye iner. | Son görülen konuma yürüyerek bakar. |
| Thief / Dark Engine [10] | belirsiz (bağırış) → kesin (arama kipi) → edinim (saldırı) | Üç farkındalık düzeyi; kanıt türüne göre farklı yükseliş ve unutma hızı. | Işık taşıyla oyuncu görünürlüğü gösterilir. |
| Metal Gear Solid (1998 kılavuzu) [11] | Sızma → Alarm (takviye, saldırı) → görüş kaybında geri sayım → Kaçış (rotadan çıkar, arar; tekrar görülürse Alarm) → sayaç bitince Sızma | Ses kipi: sese yürür, bir şey yoksa rotaya döner; sayaç süreleri kılavuzda yok. | Kademe geri döner; alarmda ses kipi yok. |
| Payday 2 [12] | gizli ikili | Muhafız düşünce 12 sn sonra çağrı, ~10 sn cevap penceresi; iş başına 4 çağrı. | Hata bütçesi görünür. |
| Invisible, Inc. [13] | alarm 0-6 | Kademe başına 5 puan; her tur +1, tespit ve olaylar ekler; bazı önlemler ajan konumunu en yakın muhafıza 3 tur verir; geri dönmez. | Sahte alarm incelemesi sonrası "hareketsiz". |
| Monaco [14] | ? → ! | Son görülen konum kırmızı "!" ile dünyada işaretli; görüş hattını kır + işaretten uzaklaş. | Çalılar sığınak. |
| Hitman WoA [15] | şüpheli → aranıyor → avlanıyor | "Avlanıyor" kaçana kadar düşmez; izinsiz girişte uyarı payı duruma göre değişir. | Bizim için: 3+ geri dönmez (GDD) ile uyumlu. |

**Çıkarımlar [görüş]:** (1) Herkes üç durum kullanıyor; ara durum (inceleme) "adil" hissinin kaynağı. (2) Son görülen konum + 2-3 sn sezgi standart; sezgisiz muhafız "aptal", 5+ sn sezgili muhafız "hileci". (3) Arama kısa ve kapsama noktalı; vazgeçiş tek tek. (4) Geri bildirim sayı kadar önemli: her geçişin sesi/balonu olmalı (Blacklist, Welsh). (5) Ekran dışı/uzak gözlemcinin algısını yarılamak (Blacklist ½) co-op'ta "beni görmemişti" şikâyetinin panzehiri; bizde karşılığı: ekip görüşü dışındaki muhafızın **duyması** ½ (görmesi değil).

## 2. Bakkal ölçeğine çevrilmiş öneri tablosu (karo 32 px, yürüme 140 px/sn, devriye 75 ± 10 sn)

| Parametre | Öneri | Dayanak / hesap |
|---|---|---|
| Devriye hızı | 90 px/sn (0,64 × yürüme) | [görüş] Sızan oyuncu (70) devriyeden yavaş, yürüyen hızlı: "arkasından yürüyerek geç" mümkün. |
| İnceleme hızı | 110 px/sn | Welsh temkinli = yürüyüş; oyuncunun yürüyerek uzaklaşmasına izin verir. |
| Arama hızı | 130 px/sn | Yürümeden az hızlı; sızan yakalanır, yürüyen kaçar. |
| Kovalama hızı | 240 px/sn (1,09 × koşu) | [hesap] 128 px (4 karo) avans 6,4 sn dayanır: kapı/köşe/kaçış bölgesine yetecek, açık alanda sonsuza değil. |
| Yakalama | 28 px yarıçap, 0,5 sn temas (host) | [hesap] Host oyuncuyu 100-175 ms eski konumda görür → koşan oyuncu lehine ~22-38 px pay kendiliğinden; temas süresi kısa tutulur. |
| Dönüş hızı | ≤ 120°/sn (KR-019); "?" anında hedefe dönüş aynı tavanla | 180° dönüş ≥ 1,5 sn → arkadan geçen oyuncu kaçabilir. |
| Koni | 50° yarım açı, 256 px; yakın bant ≤ 128 px (×2), uzak 128-256 (×1) | US-006 AC3 / KR-019. |
| Dolum (sn) | koşu yakın 1,0 · yürü yakın 2,0 · sız yakın 4,0 · koşu uzak 2,0 · yürü uzak 4,0 · sız uzak 8,0 | [hesap] 25 × bant × durum; "?" (30) tespitten önce: koşu yakın 0,7 sn önce (≥ 0,5 ✓), yürü yakın 1,4 sn. |
| Boşalma | 20/sn; **arama sırasında taban 60** | [görüş] "sıcak hafıza": aramada yeniden görülme 40 puan ister (koşu yakın 0,4 sn, sız uzak 3,2 sn). Arama bitince taban 0. |
| "?" (30) tepkisi | Durur, hedefe döner, 0,5-1,0 sn bakar; 30 altına düşerse devriyeye döner | GDD §6.1 "≥ 0,5 sn tepki penceresi". Hareket yok. |
| İnceleme (60) | Son görülen konuma yürür (48 px'e ya da görüş hattına kadar), 2 sn ±60° tarama, telsiz homurtusu; bir şey yoksa döner; **küresel uyarı 1** (20 sn'de söner) | Welsh 1. faz; Dishonored kısmi beyaz. |
| Tespit (100) | "!" + **telsiz 1,5 sn** (durur, bakar) → küresel uyarı 2 → kovalama | [görüş] 1,5 sn = Payday "çağrı" penceresinin küçük hali; US-010 sindirme bu pencerede kesebilir. |
| Sezgi | Görüş kaybında 2 sn hedef konumunu bilir, sonra son görülen konum | Welsh 2-3 sn; bizde 150 ms ağ payı için alt uç. |
| Arama | Son görülen konum çevresinde 160 px içinde 3-4 nokta (raf arkası, arka oda kapısı, tezgâh arkası), noktada 2 sn bakış, toplam ≤ 20 sn; bulamazsa 5 sn "söylenerek" rotaya döner | Welsh 2. faz; bakkalda 1 muhafız → nokta listesi seviye işaretlerinden (`SearchSpot*`, US-007 ekine aday). |
| Uyarı 2 → 1 → 0 | Aramada tespit yoksa 60 sn sonra 1, +20 sn sonra 0 (GDD 60-90 sn) | Geri dönüş oynanabilir olmalı (Payday tuzağı). |
| Uyarı 3 (sessiz alarm) | Arama (2) sırasında **ikinci tespit** ya da tezgâhtar düğmesi (US-010) ya da yoklama cevapsız (T6) → polis sayacı 90 sn; geri dönmez | GDD §6.1-6.2; bakkalda sayaç bitimi = US-012 "kilitleme/kaybet". |
| Devriye döngüsü (K2) | Dış rota 60 sn + vitrin önünde 3 sn içeri bakış; her 2. turda içeri girip tezgâha kadar 10 sn | [görüş] Keşifte öğrenilebilir tek zamansal bilgi; tohumla ±10 sn (Faz 3). |
| Ses (US-009 ile) | Yüksek ses (kapı 160, koşma 120 px) görüş hattı olmadan şüphe +30 ("?") ve temkinli inceleme; aramada ses = arama merkezi oraya kayar; ekip görüşü dışındaki muhafız ses yarıçapını ½ duyar | Blacklist ½ kuralı; Mark of the Ninja art arda adım = tek ilgi. |
| Çoklu muhafız (T2+) | Lider/araştıran/seyirci rolleri; aynı anda ≤ 2 arayan | Mark of the Ninja, Welsh. Bakkalda tek muhafız: not. |

## 3. Durum makinesi (US-008 `brain_guard.gd` için öneri)

Durumlar: `DEVRIYE` → `BAK` (şüphe ≥ 30) → `INCELE` (≥ 60) → `TELSIZ` (= 100, 1,5 sn) → `KOVALA` → `SEZGI` (görüş kaybı, 2 sn) → `ARA` (≤ 20 sn) → `DON` (rotaya) → `DEVRIYE`. Ek: `DINLE` (ses; `BAK`'ın görüşsüz hali, hedef = ses konumu) ve `YAKALADI` (temas 0,5 sn; US-012'ye sinyal).

| Geçiş | Koşul | Çıktı (herkese çoğaltılan) |
|---|---|---|
| DEVRIYE → BAK | herhangi bir oyuncunun şüphesi ≥ 30 | yön = oyuncu; "?" balonu; dünyada bakış noktası işareti |
| BAK → DEVRIYE | şüphe < 30 ve ≥ 0,5 sn geçti | balon söner |
| BAK → INCELE | şüphe ≥ 60 | yürüyüş hedefi = son görülen konum; uyarı 1 |
| INCELE → DON | hedefe vardı + 2 sn tarama, şüphe < 60 | homurtu SFX |
| * → TELSIZ | şüphe = 100 | "!" balonu; telsiz SFX; 1,5 sn kilit |
| TELSIZ → KOVALA | 1,5 sn doldu (sindirme kesmezse) | uyarı 2 (ya da 3, aramadaysa); kovalama SFX |
| KOVALA → YAKALADI | 28 px içinde 0,5 sn | US-012 `player_caught(peer_id)` |
| KOVALA → SEZGI | görüş hattı 0,2 sn kesik (oyuncu lehine) | hedef = oyuncunun gerçek konumu 2 sn boyunca |
| SEZGI → ARA | 2 sn doldu, görüş yok | son görülen konum işareti ("!" halkası, 3 sn) |
| ARA → KOVALA | şüphe ≥ 100 (taban 60'tan) | ikinci tespit → uyarı 3 |
| ARA → DON | 20 sn ya da noktalar bitti | "söylenme" SFX; şüphe tabanı 0 |

Tasarım notu [görüş]: kademe sayacı (polis gelişi) yalnız 3'te başlar; 0-2'de ekranda sayaç yok (Invisible Inc. tuzağı).

## 4. 150 ms gecikmede adalet notları

- Host oyuncuyu 100-175 ms geriden görür (GDD §12 ölçümü). Oyuncu aleyhine kararlar (şüphe dolumu, yakalama) **eşitleyiciden gelen konumla**; lehine kararlar (görüş hattından çıkış, sezgi bitişi) 0,2 sn beklemeli (KR-019). Yakalama için ek pay gerekmez: eski konum zaten oyuncunun gerisinde.
- Koni kenarı titremesi (Blacklist "1 cm" sorunu): içeride/dışarıda kararına histerezis — giriş 50°/256 px, çıkış 53°/272 px; raycast 15-20 Hz'de örneklendiği için tek karelik kesilme şüpheyi boşaltmaz (boşalma yalnız 0,2 sn sürekli görünmezlikten sonra başlar).
- "?" balonu istemcide çoğaltma paketiyle ~75-100 ms geç görünür; koşu-yakın bantta "?"→tespit 0,7 sn olduğundan oyuncunun gördüğü pencere ≥ 0,5 sn kalır. Yürüme-yakın ve tüm uzak bant rahat.
- Kovalamada göreli hız 20 px/sn: 150 ms'de oyuncunun ekranındaki muhafız konumu ≤ 36 px hatalı; yakalama yarıçapı (28) bunun altında → oyuncu "yakalanmadım ki" diyebilir. Çözüm: yakalama anında 0,5 sn temas + istemcide "yakalanıyor" göstergesi (muhafız kolu/halka) temasın ilk karesinde başlar.
- "Beni görmemişti" günlüğü (yol-haritasi D2.1): her tespitte host `band, mode, lit, t_question, t_detect, rtt_ms, dist_px` yazar; ağ gecikmesi kaynaklı tespit = `t_detect − t_question < 0,5 + rtt` ise bayrak.

## 5. US-008 için önerilen kabul kriterleri ve değişmezler

Kabul (AC önerisi):
1. `core/fsm.gd` + `brain_guard.gd`: §3 durumları ve geçişleri; tüm süre/hız/yarıçap değerleri `data/npc/guard_tuning.tres` (S10 kalıbı).
2. Devriye: `PolicePatrol*` noktalarını NavigationRegion2D ile sırayla gezer; döngü süresi 75 ± 10 sn (vitrin bakışı ve 2. turda içeri giriş dahil); headless ölçümle doğrulanır.
3. "?" → inceleme → tespit zinciri: koşan oyuncu yakın bantta ≤ 1 sn, uzak bantta ≤ 2 sn; sızan uzak bantta ≥ 6 sn; raf arkası hiç; "?" tespitten ≥ 0,5 sn önce (US-006 testleri bileşenle tekrar).
4. Telsiz 1,5 sn penceresi: bu sürede görüş kesilirse ya da (US-010) sindirme gelirse uyarı yükselmez; pencere sonunda uyarı 2.
5. Son görülen konum: görüş kaybından 2 sn sonra muhafız o noktaya gider, ≤ 20 sn arar, rotaya döner; arama sırasında şüphe tabanı 60; ikinci tespit uyarı 3.
6. Küresel uyarı 0-3 host'ta `Game` üzerinden çoğaltılır (`alert_level_changed(level: int)`), 2 → 1 → 0 sönümü 60 + 20 sn; 3 geri dönmez; 3'te polis sayacı 90 sn.
7. Kamera = hareketsiz muhafız sahnesi (devriye yok, dönüş yok, tespitte telsiz yerine "operatör" olayı); aynı algı bileşenleri; Faz 2b'de etkinleşir (sınıf iskeleti yeter).
8. Ağ senaryosu `guard_detect.json` (0 ve 150 ms): bot koşarak koniye girer → tüm peer'larda "?"→"!" sırası ve uyarı 2 aynı; bot raf arkasında bekler → şüphe 0; bot kaçış bölgesine koşar → yakalanmaz (128 px avans). Dökümde §4 tespit günlüğü alanları.
9. Her durum geçişi için SFX olay adı (`guard_question`, `guard_radio`, `guard_lost`, `guard_give_up`) `session_event` benzeri bir kanaldan yayılır (SFX kalemi bunları bağlar).

Test edilebilir değişmezler (birim + senaryo dökümünden):
- I1 Hiçbir `detected` olayı öncesinde aynı muhafız-oyuncu çifti için `question` olmadan oluşmaz.
- I2 Şüphe değişimi iki örnek arasında |Δ| ≤ max(dolum, boşalma) × Δt (sıçrama yok; ses +30 hariç, o olay günlüklü).
- I3 `ARA` süresi ≤ 20 sn; `TELSIZ` tam 1,5 sn (±1 kare); `BAK` ≥ 0,5 sn.
- I4 Uyarı yalnız {0→1, 1→2, 2→3, 2→1, 1→0} geçişlerini yapar; 3'ten düşüş yok.
- I5 Muhafız yön değişimi kare başına ≤ 120° × Δt.
- I6 Aynı tohum + aynı bot zaman çizelgesi → host olay günlüğü birebir aynı (replay/CI kararlılığı).
- I7 Muhafız hiçbir durumda duvar/raf içinde değil; navigasyon başarısızsa `DON`'a düşer, donmaz.

## 6. Karar gereken (koordinatöre)
1. Kovalama hızı koşudan hızlı mı (240) yoksa eşit mi (220)? Eşitse açık alanda asla yakalanmaz, yakalama yalnız köşe/kapı ile olur (daha "Monaco", daha az "yakalandım" hissi). Öneri 240.
2. Aramada ikinci tespit doğrudan uyarı 3 mü (öneri) yoksa 2'de kalıp sayacı mı uzatır? GDD §6.1 "telsiz → bölgesel arama → sessiz alarm sayacı" ilkini destekler.
3. `SearchSpot*` işaretleri seviyeye mi (US-007 eki) yoksa muhafızın navmesh'ten rastgele mi? Öneri: seviye işareti (deterministik, tohumlanabilir).

## Kaynaklar
[1] Walsh, "Modeling Perception and Awareness in Splinter Cell Blacklist", Game AI Pro 2 §28 — https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy%27s_Splinter_Cell_Blacklist.pdf
[2] https://www.gamedeveloper.com/design/bringing-balance-to-stealth-ai-in-splinter-cell-blacklist
[3] Welsh, "Looking for Trouble: Making NPCs Search Realistically", Game AI Pro 2 §27 — https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter27_Looking_for_Trouble_Making_NPCs_Search_Realistically.pdf
[4] Miles, "How to Catch a Ninja", Game AI Pro §32 — https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter32_How_to_Catch_a_Ninja_NPC_Awareness_in_a_2D_Stealth_Platformer.pdf
[5] https://en.wikipedia.org/wiki/Mark_of_the_Ninja
[6] https://godisageek.com/reviews/shadow-tactics-blades-of-the-shogun-review · https://godisageek.com/2020/06/10-desperados-iii-tips-to-help-you-out-in-the-wild-west/
[7] GMTK, "How Stealth Game Guards See and Hear" (School of Stealth 1) — https://amara.org/v/C3BDw
[8] https://twinfinite.net/2016/11/dishonored-2-the-different-alert-levels-and-what-they-mean/
[9] https://steamcommunity.com/app/403640/discussions/0/152390014801365271
[10] https://en.wikipedia.org/wiki/Dark_Engine
[11] MGS kılavuzu (PlayStation, EN) — https://secure.cdn.us.playstation.com/manuals/classic/games/metal-gear-solid-manual-en.pdf
[12] https://steamcommunity.com/app/218620/discussions/8/1698294337780392688
[13] https://gcores.com/articles/138848 · https://forums.kleientertainment.com/forums/topic/56683-can-someone-explain-countermeasures/
[14] https://i1.trueachievements.com/game/Monaco/walkthrough/2
[15] https://steamcommunity.com/app/1659040/discussions/0/3770111248604313866
