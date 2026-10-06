# Test-2 oyun testi protokolü ve gözlem formu (IS-032 + IS-017)

2026-10-06, tasarim ajanı (Fable). Paket `build/Insiders-faz2-58aaaa4-windows.zip` (PROTOCOL 6). Oyuncular: Mustafa (host, aynı zamanda gözlemci) + 1-2 arkadaş (Tailscale, Discord sesli). Oyunda ping/mesaj tekerleği **yok** (US-017..019 dilim 2.5); bu yüzden IS-032'nin asıl kıyası ("araçlar sesi ne kadar ikame eder") bu testte yapılamaz — burada yalnız **taban** alınır (§1 tur 5, §5 madde 5). Dayanak: `arastirma/oyun-testi-ve-klip.md` §2, `arastirma/ekip-iletisimi.md` §4, `arastirma/gorus-sis-hafiza.md` §2b, `danisma/us-045-store-b.md` §F, `docs/arastirma/yontem.md` §9, KR-034/038/039.

Varsayımlar: gözlemci ayrı yok → sayımlar üç kaynaktan gelir: **G** = host'un tur arasında hafızadan not alması + Discord/ekran kaydı (izinle; sayımlar kayıttan sonradan), **D** = kayıt dosyaları (`--log-on-exit`), **A** = tur sonu anket. "Aynı tohum" normal oyunda ayarlanamıyor (varsayım) → A/B "aynı harita, ardışık turlar" ile yapılır; tohum farkı sonuçta belirsizlik payıdır.

## 1. Tur planı (hedef 60-75 dk; 3 oyuncu)

| Dk | Adım | Harita / kip | Ne ölçer |
|---|---|---|---|
| 0-10 | Bağlantı + `--log-on-exit` kontrolü (host "Host ol", kart `100.x.y.z:7777`; herkes bir kez girip çıkar, dosya oluşmuş mu bakılır) | — | Teknik (J) |
| 10-12 | Brifing: **yalnız tuşlar** (WASD, Shift koş, Ctrl sız, E, Q, fare bakış) + amaç ("parayı al, yakalanmadan minibüse"). Sahip kuralı, pencere, damacana, örtü **anlatılmaz**. | — | — |
| 12-20 | **Tur 1** — yönlendirmesiz. Sorulara "sence?" | store_a, Çevresel (varsayılan; argüman yok) | Anlaşılırlık (B), §F alışveriş/damacana ilk temas |
| 20-28 | **Tur 2** — A/B: Yönlü | store_a, host `--vision-mode=directional` ile yeniden açar (ya da menüde Görüş: Yönlü), arkadaşlar yeniden katılır | Görüş (H), denge (C) |
| 28-36 | **Tur 3** — A/B: Çevresel (Yönlü'yü iki Çevresel'in ortasına koymak öğrenme eğilimini dengeler; T2 ↔ T3 kıyaslanır, T1 referans) | store_a, `--vision-mode=peripheral` | Görüş (H), denge (C), sahip tepkisi (F) |
| 36-37 | 30 sn oylama: "Yönlü mü Çevresel mi?" (A satır 5) | — | H |
| 37-47 | **Tur 4** — büyük bakkal | store_b: host `--level=res://levels/store_b.tscn` + oylamayı kazanan kip | store_b (G4), yürüme/boşluk hissi, "bakkal tezgâhta mı?" |
| 47-55 | **Tur 5 (isteğe bağlı, ≥ 10 dk kaldıysa)** — **sessiz taban turu**: herkes Discord mikrofonunu kapatır (kanaldan çıkmaz), host "başla" der, iş bitince açılır; 5 dk üst sınır | store_a, oylamayı kazanan kip | IS-032 tabanı: araçsız + sessiz sonuç; "en çok ne söylemek istedin?" (tekerlek dilimlerine girdi) |
| 55-65 | Grup sohbeti 10 dk: "Ne oldu?", "En iyi an?", "En kötü an?" — çözüm tartışması yok | — | Klip (I), tekrar isteği (K) |

Kurallar: her turun sonunda 1 dk anket (§3) **oynanmadan önce** doldurulur; turlar arası sahibin kurallarını açıklama (öğrenme veriyi bozar); "Bir daha" düğmesi aynı haritada yeni koşu açar (`level_started run` artar, dosyada ayrışır); harita/kip değişiminde host exe'yi yeniden açar, arkadaşlar yeniden katılır (dosya adı aynı kalabilir: her oturum sonu dosya **üstüne yazılır** → her tur sonunda host dosyayı `kayit-<ad>-T<n>.json` diye kopyalasın; arkadaşlar yalnız oturum sonunda gönderir). 2 oyuncu olursa: tur 4 atlanır, tur 5 kalır; görüş A/B yalnız bilgi (§5 madde 2 emniyeti).

Neden bu sıra: T1 bozulmamış ilk izlenim; A/B öğrenmenin en dik yerinden (T1) sonra; store_b en sona değil 4'e (yorgunlukta "uzun" hissi yanlış pozitif verir); sessiz tur en sona (en çok sinir bozma riski taşır, diğerlerini kirletmez). Riske attığı: 5 tur + yeniden katılmalar 75 dk'yı aşabilir → önce tur 5, sonra tur 4 düşer.

## 2. Gözlem formu (tur başına sütun; kaynak G/D/A)

| # | Satır (tek soru/sayım) | T1 | T2 | T3 | T4 | T5 | Kaynak |
|---|---|---|---|---|---|---|---|
| A1 | Sonuç (temiz / bağırdı / sıcak / yakalandı / eli boş) ve süre (sn) | | | | | | D `heist.history[run].outcome`, `duration_s` |
| A2 | En yüksek uyarı kademesi ve ganimet/ödeme | | | | | | D `max_alert`, `loot_total`, `payout` |
| B1 | İlk 2 dk'da "bu ne / nasıl yapılıyor?" sorusu sayısı (hangi konuda) | | | | | | G |
| B2 | Kasa, arka oda nakdi ve kaçış noktasını kaçıncı dakikada buldular (üçü ayrı) | | | | | | G + D `register_tick`, `bag_go`, `escape_point` t |
| C1 | Strateji: vuruş-kaç (sahip tezgâhta/yeni ayrılmışken kasa + ≤ 20 sn'de kaçış) mı, pencere bekleme (damacana/raf/telefon) mi; bekleme kaç sn | | | | | | G + D `owner.log` task ↔ `register_done` t |
| C2 | Bağırış/keşif kaçıştan kaç sn önce ya da sonra geldi ("temiz ama ucuz" hissi var mı) | | | | | | D `shout`/`owner_discover` t ↔ `escape_status`; A S2 |
| D1 | "Minibüs kalkıyor… 3" geri sayımı fark edildi mi; biri "neden bitmedi?" dedi mi | | | | | | G |
| D2 | Geri sayım iptal oldu mu (biri bölgeden çıktı / bağırış geldi) | | | | | | D `escape_settle_left`, `alert_level` |
| E1 | Arka kapı kaç kez açıldı; "kapı kendi kapandı?" yorumu oldu mu (yaylı kapı okunuyor mu, KR-039) | | | | | | D `door_open`/`door_close` (B); G |
| E2 | Zil → sahibin arkaya gelişi okundu mu ("duydu, geliyor!" dendi mi); kapıyı açık bırakma denemesi | | | | | | G + D `owner.log` why "door"/LISTEN |
| F1 | Kasa sahibin gözü önünde boşaltıldı mı; tepki ≤ 1 sn geldi mi (GB-04a tekrarı, IS-081 AC2) | | | | | | D `register_tick` t ↔ `owner.log` task/facing/target, `player_held` |
| F2 | "Önümde durdu, görmedi" şikâyeti sayısı; görev glifi/koni fark edildi mi ("telefonda!" dendi mi) | | | | | | G |
| F3 | Arka odaya giriş: sahip konisinde miydi; DİNLE geldi mi; eksik çanta/boş kasa keşfi kaç sn sonra (GB-05) | | | | | | D `owner.log`, `owner_discover` {source}, `discoveries[]` |
| G1 | Alışveriş: ilk 2 dk'da raftan ürün alan (kim, ürün, ödedi mi); "bu ne işe yarıyor?" zamanı; Kola bırakan ve sahibin gelişini okuyan var mı | | | | | | D `shop` {taken, paid, dropped}; G |
| G2 | Damacana: kim, kaçıncı dk; "arkaya gitti" sesle paylaşıldı mı; pencere kullanıldı mı; ödendi mi / +20 düştü mü; HUD "Damacana istendi" fark edildi mi | | | | | | D `order_phase`, `order_paid`, `send_costs[]`; G |
| G3 | Örtü: "Örtün bozuldu" ilk kaç sn'de, sebep ve gören; oyuncu sebebi söyleyebildi mi; "kimse görmedi ki" şikâyeti; polis gelişinde tanık salınan | | | | | | D `cover_reason`, `seen_by`, `cover_broken` t, `recognized`; A S2 |
| G4 | (store_b) Ek alanın doğu penceresini keşfeden oldu mu; "bakkal tezgâhta mı?" kaç kez soruldu; yürüme "uzun" şikâyeti | | | | | | G |
| H1 | "Arkamdan geldi" / "görmedim" yakalanma ya da tespit sayısı | | | | | | A S2 + D `player_caught` {by}, `detections[]` |
| H2 | "Nerede?" / "arkamı kolla" / "neredesin?" cümlesi sayısı (Discord; dk başına) | | | | | | G (kayıt) |
| H3 | Adalet ortalaması (A S1) ve tercih oyu (T3 sonu) | | | | | | A |
| I1 | Kahkaha/klip anı sayısı ve her biri hangi sistem olayına denk (kasa+cam, çanta düşürme, arka kapı+devriye, sahip arka odaya dönüş, başka) | | | | | | G + D en yakın olay (±5 sn) |
| I2 | Plan bozulma anı sayısı ("ÇIK ÇIK", "bekle bekle") | | | | | | G |
| I3 | Ölü zaman: bir oyuncu ≥ 30 sn boşta (kim, neden: pencere bekliyor / ne yapacağını bilmiyor) | | | | | | G; A S5 |
| J1 | Teknik: kopma, takılma, "beni görmemişti" (ağ) şikâyeti; RTT | | | | | | D `peers`, `host_lost`; G |
| K1 | "Bir daha" diyen kim, kendiliğinden mi | | | | | | G |
| T5 | Sessiz tur: sonuç, süre, "en çok ne söylemek istedin?" (3 cümle/oyuncu), yanlış kapı / "şimdi"yi kaçırma sayısı | | | | | | A; D; G |

Doldurma düzeni: tur biter → 1 dk anket (sesli, host not alır) → host A1-A2 ve G/D satırlarını boş bırakır (kayıttan/dosyadan sonra), yalnız G kaynaklı satırları o an hafızadan yazar (B, D1, E1-2, F2, G4, I, K). Kayıt yoksa H2 ve I1 "kaba sayım" olarak işaretlenir.

## 3. Tur sonu anketi (her oyuncu, 1 dk, sesli; host yazar)

1. Bu tur ne kadar adildi? 1 (hile gibi) – 5 (hak ettik) — H3.
2. Neden yakalandın / bakkal neden bağırdı? Tek cümle ("bilmiyorum" geçerli cevap) — dosyayla eşleştirilir (C2, G3, H1): söylenen sebep ↔ `player_caught.by`, `owner_discover.source`, `cover_reason`.
3. En eğlenceli an? — I1.
4. En sinir bozucu an? — I3/F2/H1.
5. (T2 ve T3 sonu) Bu görüş kipi mi, önceki mi? Neden? — H3.
6. (T5 sonu) Sessizken en çok ne söylemek istedin? Üç şey. — tekerlek dilimleri (US-019).
Oturum sonrası 24 saat içinde yazılı, kısa: yontem §9 anketinden yalnız S1 (tek cümle anlat), S4 (fark edilme nedenini anladın mı), S6 (yarın bir tur daha?), S8 (bir şeyi değiştirsen).

## 4. Kayıt dosyaları ve hangi soruya hangi alan

Her oyuncu oyunu `Insiders.exe -- --log-on-exit=kayit-<ad>.json` ile açar (dosya exe'nin yanına; yazılamazsa `user://`). Dosya oturum sonunda, pencere kapanınca ya da çıkışta yazılır; **görev yöneticisinden öldürülen süreç yazmaz**. Host her tur/oturum sonunda kendi dosyasını `kayit-mustafa-T<n>.json` olarak kopyalar; arkadaşlar oturum sonunda tek dosya gönderir. Host dosyası tur bazında `heist.events_shared` içindeki `level_started {run, level, seed}` işaretleriyle bölünür; istemci dosyasında bu işaret yoktur (kendi `vision.mode`, `player_states`, `host_lost` için okunur).

| Soru | Alan (host dökümü) |
|---|---|
| Sonuç/süre/uyarı/ödeme (A1-A2) | `heist.history[]` koşu başına `outcome`, `duration_s`, `max_alert`, `loot_total`, `payout`, `players{escaped, caught, bail}` |
| Kim, kim tarafından yakalandı (H1, anket S2) | `player_caught {peer, by: owner\|chaser}`, `player_held`, `player_rescued` |
| Vuruş-kaç mı pencere mi (C1-C2) | `register_tick`/`register_done` t ↔ `owner.log[]` {t, state, task, facing, target, why, top_peer, top_value} aynı anda sahip nerede; `shout` / `owner_discover {source: register\|cash}` t ↔ `escape_status` / `escape_settle_left` t |
| Geri sayım (D2) | `escape_settle_left`, `alert_level` sırası |
| Arka kapı zili / yaylı kapı (E1-E2) | `door_open`/`door_close` (kapı adı B), ardından `owner.log` why "door" + task LISTEN/BACKROOM, `discoveries[]` (çanta kontrolü) |
| Sahip "görmedi" iddiası (F1-F3) | `owner.log` satırı: kasa boşaltılırken task COUNTER ve facing kasaya dönükken `detections[]`'da kayıt yoksa gerçek hata (IS-081 kökü); task PHONE/RESTOCK ise okunurluk sorunu (IS-096) |
| Alışveriş / damacana (G1-G2) | `shop {taken, paid, dropped, order, held}`, `order_phase`, `order_paid`, `send_costs[]` (+20 düştü mü), `noise` kayıtları (`bottle` 160) |
| Örtü (G3) | `heist.cover {peer: bool}`, `cover_reason`, `seen_by`, `cover_broken` t, `recognized` |
| Görüş kipi doğrulaması (H) | her dosyada `vision.mode`; görünürlük sayıları yalnız çıkış anı anlık (A/B için kullanılmaz) |
| Ağ (J1) | `peers` (RTT alanı varsa), istemcide `host_lost`, `log_reason` |

Koordinatör notu: bu eşleme kod okumasından; alan adları `autoload/game.gd` `_heist_dump`, `core/owner_log.gd`, mimari.md S6 eklerinden. Dosyada `heist.history` koşu başına değilse `level_started` ile `events_shared` bölünür ve son `result` yalnız son koşuya aittir — ilk okumada doğrulanmalı.

## 5. Karar kuralları ("şu görülürse → şu")

1. **KR-034 ilkesi** ("araç para verir, sabır/ekip temizlik verir"; "fark edildiği an = shouted"). store_a 3 turunun ≥ 2'sinde C1 = vuruş-kaç **ve** A1 = temiz **ve** C2'de keşif kaçıştan sonra geldi **ve** anket S1 ≤ 3 ya da "ucuz/kolay" dendi → ilke uygulanır: kaçış geri sayımı sırasında ya da bitişten ≤ 5 sn sonra gelen keşif `shouted` sayılır + IS-105 (sahip kasa sesine yaklaşıp bakar) öne alınır. Vuruş-kaç çoğunlukla bağırdı/yakalandı bitiyor ve temizler pencere beklemeden (damacana/raf) geliyorsa → ilke zaten sağlanıyor, kural eklenmez; yalnız `sent_sec` 7 → 5 (store_b takım temiz > %40 ise, us-045 §B). Pencere bekleme ≥ 90 sn ve I3 ölü zaman ≥ 2 oyuncuda → pencere sıklığı artırılır (ajanda ardışık pencere arası 15 → 10 sn), bedel değil.
2. **Görüş varsayılanı** (gorus-sis-hafiza §2b kuralı, 3 oyuncuya indirgenmiş): Yönlü varsayılan olur ⇔ tercih ≥ 2/3 **ve** T2 adalet ortalaması ≥ 3,5 **ve** H1 (T2) − H1 (T3) ≤ 1. Aksi hâlde Çevresel varsayılan, Yönlü host seçeneği. 2 oyuncuyla oynandıysa karar verilmez (Çevresel kalır), A/B test-3'e. "Arkamı göremiyorum" şikâyeti T2'de ≥ 3 ama tercih yine Yönlü ise → Yönlü + yakın halka 64 → 96 px denemesi (ayar), kip değişmez.
3. **store_b / bakkal büyütme** (GB-10, KR-037): T4'te A1 temiz ya da bağırdı (yakalanmadı), adalet ≥ T1-T3 ortalaması − 0,5, G4 "bakkal tezgâhta mı?" ≥ 2 kez (bilgi bölünmesi çalışıyor, KR-035) ve "uzun/boş" şikâyeti ≤ 1 → büyütme yönü doğru: store_b ikinci resmî harita, raf/ürün görselleri (US-046) store_b'yi de kapsar; store_a boyutu T1 kalır. T4 "uzun/boş" ≥ 2 şikâyet, yürüme payı belirgin (süre > 90 sn ve kasa/çanta dışı zaman > %60), adalet < 3 → store_b yalnız deneme haritası kalır; büyütme dükkânı değil **sokağı** (dış gözcü) büyütür. T4'te takipçi kapıya > 8 sn (`shout` → `chaser`) ve kaçış hep temiz → store_b `neighbour_delay_sec` 7 → 5, `shout_radius` 640 kalır.
4. **IS-097 (açık arka kapı izi) / IS-092 (küçük bedeller) önceliği**: E2'de kapıyı açık bırakma ≥ 1 tur **ve** F2'de "kapı açık kaldı, görmedi mi?" dendi → IS-097 dilim 2.4 başına (P1). Hiç açık bırakılmadıysa (yaylı kapı zaten kapatıyor) → IS-097 iptal adayı (KR-039 ihtiyacı karşıladı), kapanışta yeniden bakılır. IS-092: raf devirip koşarak uzaklaşan bedelsiz temiz ≥ 2 kez ya da kuyruktaki müşteri kasayı boşaltana bakmadı ve biri bunu söyledi → IS-092 2.4'e; aksi hâlde 2.6 kalır.
5. **Ping önceliği (US-017..019) ve IS-032**: H2 ≥ 2 cümle/dk ve tur başına ≥ 1 yanlış kapı / "şimdi" kaçırma → ping+tekerlek dilim 2.5'te P1 kalır; tekerlek dilimleri T5 "en çok ne söylemek istedin" listesinden (ilk 8). H2 < 1/dk ve turlar yine temiz → ping P2'ye düşer, 2.5 lobi (US-031/027/025) ile başlar. T5 oynandıysa IS-032 tabanı: sessiz sonuç A1 ve süre; **asıl kabul (sessiz+araçlı temiz ≥ sesli temizin %60'ı) test-3'te**, US-017..019 sonrası aynı protokolle (tur 5 yerine "araçlı sessiz tur"). T5 oynanmadıysa taban test-3 başına eklenir (2 tur: sessiz araçsız, sessiz araçlı).
6. **Örtü B (zamanla dönüş)**: G3'te "kimse görmedi ki" şikâyeti ≥ 1 **ve** `seen_by` o anda gerçekten bir NPC gösteriyorsa → okunurluk (ekran kenarındaki gözcüyü göstermek: "görüldü" ikonu süresi), kural değil; `seen_by` boşsa hata. Örtü turların ≥ 2/3'ünde ilk 60 sn'de bozuluyor ve oyuncular "damgalandık" diyorsa → B (bozulmadan 90 sn sonra görülmeden dönüş) dilim 2.4'e.
7. **Sahip tepkisi (GB-04a/05 kapanışı)**: F1'de kasa koni içinde boşaltılıp tepki ≥ 1,5 sn gecikti ve `owner.log` task COUNTER gösteriyorsa → IS-081 yeniden açılır (P1, blocker). Task PHONE/RESTOCK/BACKROOM ise ve oyuncu "önümde" dediyse → IS-096 glif/koni yeterli değil: glif boyutu ve "sahip seni görmüyor" göz ikonu 2.4'e.

## 6. Karar gereken (kullanıcıya)

Koordinatör (2026-10-06): 1 ve 3 kabul (süreç kararı). 2 kullanıcıda (arkadaşların onayı; kayıt yoksa sayımlar kaba).

1. IS-032'nin asıl kıyası US-017..019 sonrasına (test-3) ertelensin; test-2'de yalnız T5 tabanı (isteğe bağlı) — öneri evet.
2. Discord sesi + host ekranı kaydı (OBS) için arkadaşlardan izin; kayıt yoksa H2/I1 kaba sayım.
3. Tur 4 (store_b) ve tur 5 (sessiz) ikisi de sığmazsa hangisi düşsün — öneri: önce tur 5 düşer.
