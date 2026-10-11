# Faz 2 yeniden kesimi — mekanik + harita + akış (KR-043)

2026-10-11, tasarim ajanı (Fable). Girdi: GDD §3/§6/§9.3/§15, backlog §1-§1a-§2b, test-2 protokolü §5 (karar kuralları K1-K7), `olcum/20261004-2330-is107-store-a-vs-b.md`, `data/npc/owner_tuning.tres`, `data/heist_tuning.tres`, `levels/layouts/store_{a,b}.txt`, `ui/heist_end.gd`, `autoload/args.gd`. Oynayamadığım için "his" yargıları sayı + akış + GB-04..12 notlarına dayanır; test-2 bulguları gelmeden kesinleşmez. Varsayımlar: tohum "Bir daha"da değişir ama oyuncuya görünmez; harita yalnız `--level` ile (menüde seçim yok); "Bir daha" yalnız host, aynı harita.

## 1. Akış (flow) bu oyunda ne demek

Flow = oyuncunun **bir sonraki 10 saniyede ne yapacağını bilmesi** ve bunun bir öncekinden doğması: hazırlık → gözlem → fırsat → eylem → sonuç → yeni fırsat. Oturum ölçeğinde: bağlan → iş → sonuç → "bir daha" zinciri **ekran/exe değiştirmeden** dönmeli.

Bugünkü oturum (3 kişi, dakika; kopuş tahminleri **K** ile):
| Dk | Adım | Kopuş tahmini | Test-2 doğrulaması |
|---|---|---|---|
| 0-3 | Exe, Tailscale adresi, Host ol → Kopyala → Discord → Katıl ×2 | K1: host "Host ol" deyince **hemen seviyeye düşer**, sahip ajandası başlar; arkadaşlar gelene kadar tek başına dolaşır, "iş başladı mı?" belirsiz; geç gelen beklemez, dalar | J1 bağlanma süreleri; G: ilk oyuncu katılmadan host kasaya dokundu mu |
| 3-4 | Rol dağılımı sözlü | K2: ne yapacağını bilmeyen oyuncu (B1 sorular, I3 ölü zaman) | B1, I3 |
| 4-8 | İş: pencere bekleme 60-90 sn, kasa + çanta ~30 sn, kaçış 10 sn | K3: pencere beklerken bir oyuncu ≥ 30 sn boşta; K4: bağırış sonrası "kim gördü / nereye" okunmuyor | I3, C1, F2, G3, H1 |
| 8-9 | İş sonu ekranı (ödeme, kefalet), "Bir daha" (host) | K5: **tekrar nedeni yok** — aynı harita, aynı sahip, tohum farkı görünmez, ısı/tanınma sonuçsuz sayı | K1 kendiliğinden "bir daha"; anket S6 |
| 9-12 | Harita/kip değişimi = host exe'yi kapatır, herkes yeniden katılır | K6: 2-3 dk kayıp, oturum temposu sıfırlanır | Tur 2→3→4 geçiş süreleri (host not alsın) |

Akışı en çok iyileştirecek 4 değişiklik (öncelik sırası):
1. **İş-içi "Başla"** (US-031'in yarısı): host seviyeye düşer ama iş `hazırlık` durumunda: sahip ajandası ve nüfus çalışır, kasa/çanta/arka kapı kilitli (etkileşim istemi "Ekip toplanıyor 2/3"); host E "Başla" → iş sayacı. Geç katılan hazırlıkta dalar, iş başladıysa seyirci. Neden: K1 — ilk saniyeler eğitim/gözlem olur (ucuz keşif provası). Risk: ayrı lobi ekranı kadar "hazır" hissi vermez; host unutursa herkes bekler (30 sn sonra HUD hatırlatması).
2. **Harita seçimi menüde + iş sonunda "Başka bakkal"** (host; seviye yolu el sıkışmada zaten var — `level_change` senaryosu): exe yeniden açılmaz. Neden: K6. Risk: istemci paketinde o harita yoksa (aynı PROTOCOL zorunlu, zaten var).
3. **Oturum skor tablosu** iş sonu ekranında: koşu başına sonuç / süre / ödeme / strateji etiketi (`heist.history`, `heist.strategy`) yan yana; "en iyi: 534 / 38 sn". Neden: K5 — "bir daha"ya ölçülebilir hedef verir (daha hızlı, daha temiz, başka yol). Risk: skor baskısı deneme/kaos oyununu daraltabilir → "temiz" ve "hızlı" iki ayrı sütun, tek toplam yok.
4. **Bekleyene iş**: pencere beklerken gözcünün aktaracağı şey olmalı — ping çekirdeği (US-017; görünen NPC kesin, görülmeyen iddia) ya da en azından ardışık pencere arası 15 → 10 sn (K1 kuralı). Neden: K3. Risk: ping tekerleği (US-019) ses varken fazlalık — çekirdek + tek "bak" pingi yeter, tekerlek T5 listesine bağlı.

## 2. Mekanik oturtma — Faz 2 sonuna kadar kesinleşmesi gerekenler

| Kural | Durum | Eksik / oturmamış | Test-2 bağı |
|---|---|---|---|
| Algı: şüphe tablosu, yakın bant, tezgâh alçak engel, "?" ≥ 0,5 sn | Oturdu (IS-096/098) | Görüş kipi varsayılanı | K2 |
| Sahip dikkat döngüsü, pencereler (4-6 kasa / 300 sn) | Oturdu | Pencere sıklığı; "fark edildiği an = shouted" (KR-034); IS-105 | K1 |
| Görülmeyen ihlal → iz / keşif (US-039) | Oturdu | Açık kapı izi IS-097 | K4 |
| Örtü (US-042/048, KR-038 A, KR-041) | Kural var | Zamanla dönüş (B); "görüldü" ikonu süresi | K6 |
| Kaçış: 3 sn geri sayım, eli boş, kefalet 100, polis 60 sn | Oturdu | Kaçış baskısı: store_b'de ilk takipçi kapıya 5,2 sn (store_a 1,4) → kaçış hep temiz | K3 (`neighbour_delay` 7→5) |
| Ödül/ceza: ödeme %85/70, ısı, tanınma | **Oturmamış**: ısı ve tanınma yalnız sayı, hiçbir şeyi değiştirmiyor | Oturum içi en küçük etki: ısı ≥ 10 → sonraki koşuda komşu gecikmesi −2 sn, yoldan geçen +1; tanınma ≥ 1 → sahip o oyuncuya 30'dan başlar ("sen yine mi?") | K1 yoksa yeni: anket S6 "yarın bir tur daha" + K1 |
| Tekrar oynama nedeni | **Yok** | §1 madde 3 + §3 harita çeşidi; tohumun görünür etkisi (çanta yeri 2-3 nokta arasında tohumla değişsin: `BackroomCash1..3`) | K1 |
| 2 kişi dengesi (GDD §9.3 kabul: fark ≤ 15 puan) | **Sapma**: bot team 2 = %0 temiz, team 3 = %80 (store_a) | Bot beyni 2 kişi stratejisi mi, kural mı belli değil; EP-02 "2 kişilik ≥ 1 koşu" insan verisi şart | A1 2 kişilik koşu; yoksa heist_stats team 2 yeniden |
| Alışveriş/damacana v0 | Var | Ürünlerin oyun etkisi kullanılıyor mu (Kola bırakma, damacana penceresi) | G1, G2 |

## 3. Yeni keyifli haritalar (bakkal ailesi, aynı sistemler — KR-037)

store_b kararı önce (K3). Ölçüm uyarısı: store_b'de team 3 %0 temiz / %40 herkes yakalandı, kasacı 23-40 sn bekliyor, arka oda tezgâha bitişik (sahip boş çanta yerini hemen görüyor) → T4 "adalet" düşük çıkarsa harita hatası, mekanik değil.

| Harita | Neyi farklı oynatır | Maliyet (seviye-duzeni) | Yeni mekanik |
|---|---|---|---|
| **A. "Kalabalık saat"** — store_a varyantı: yalnız harita ayarı (müşteri akışı ×2, kuyruk 2 kişi sürekli, sahip MÜŞTERİ kesmesi sık, kasa 150 → 250) | Örtü kolay, kasa penceresi zor (kuyruk tanığı), arka oda pencereleri bol → "arka odacı" rolü öne çıkar; aynı dükkân, farklı ritim | **XS** (VenueTuning ezmesi + `.txt` kopyası; yeni geometri yok) | Gerekmez |
| **B. "Ev-dükkân"** (store_c, ~30×22): arka oda yerine **L koridor + iki oda** (depo: `BackroomSpot`, mutfak: `BackroomCash`), ara kapı düz kapı; sahip depodayken mutfaktaki görülmez, mutfak penceresi yan sokağa bakar | KR-035 kat olmadan: arka odacı sahibin depoya girdiğini **duyar ama görmez**, dışarıdaki mutfak camından görür → bilgi üç kişiye bölünür; çanta rotası uzar (koşarken düşürme riski anlamlı) | **S-M** (çok parçalı `Backroom` bölgesi destekli; düz iç kapı için yeni kapı adı — sahip navigasyonu/DİNLE `BackroomDoor` adına bağlıysa XS kod) | Yeni kapı adı; iki kat yok |
| **C. "Köşe — iki kapı"** (store_d): cadde ve yan sokağa iki müşteri kapısı, tezgâh köşede | Sahip iki kapıya bakamaz: "kapıyı kolla" gözcü rolü, YÖNLENDİR iki yönlü, kaçış iki yoldan; vuruş-kaç'ı ödüllendirir (dikkat) | **M** | `FrontDoor2`: nüfus rotası iki giriş, zil iki kapı, sahip `serve_facing` türetimi — S kod |

Öneri sırası: A (hemen, ölçülebilir) → B (2.6 ya da Faz 3 ilk şablon; KR-035 provası) → C (Faz 3 şablon havuzuna; iki kapı T2 benzinlikte de gerekir).

**Faz 3 keşfini öne çekmek:** tam Faz 3 (plan masası, kroki, ikon) hayır — M-L iş, Faz 2 kapanmaz. Ama **"keşif ön testi"** (backlog §3'te zaten aday: 60-90 sn izle → krokiye ikon) 2.6'ya alınabilir: iş öncesi 90 sn "müşteri turu" (kasa/çanta/arka kapı etkileşimi kapalı, sahip çalışıyor, oyalanma şüphesi işler; sonra herkes dışarı → "Başla"), çıktı yalnız hafıza katmanı (sis zaten var). Harita çeşidi (A+B) ve tohumlu çanta yeri olmadan keşfin öğreteceği bir şey yok — bu yüzden §3 haritalar ön koşul. Risk: oyuncular keşfi "bekleme" sanır (ölü zaman); kabul: ≥ 2/3 "değdi" demezse Faz 3'te plan masasıyla birlikte yeniden.

## 4. Önerilen dilim kesimi

| Dilim | Tek hedef | Kalemler (5-8) | Tek çıkış kriteri |
|---|---|---|---|
| **2.4 Akış ve harita** | Oturum exe değiştirmeden döner; ikinci resmî harita | yeni: iş-içi Başla (§1.1) · yeni: harita seçimi menü + iş sonu (§1.2) · yeni: oturum skor tablosu (§1.3) · yeni: "Kalabalık saat" varyantı (§3 A) · store_b düzeltmesi ya da deneme haritası kararı (K3) · IS-097 / IS-092 / IS-105 (K1/K4 sonucuna göre, XS-S) · yeni: ısı/tanınma oturum içi etkisi (§2) · US-046 lite (§5) | 3 kişi exe'yi yeniden açmadan art arda 3 koşu (≥ 2 harita/varyant) oynar; test-3 paketi |
| **2.5 Ekip ve iletişim** | Bilgi bölünmesi konuşturur | US-017 (çekirdek; K5 ile P1/P2) · US-018 · US-019 (dilimler T5 listesinden; H2 < 1/dk ise Havuz) · US-031 kalanı (Hazır, kontrol kartı, görüş kuralı) · US-027 · US-025 (ses/kip/hareket azaltma asgarisi) · IS-033'ün kenar işareti kısmı (§5) | Ping 0/150 ms yeşil; test-3 "araçlı sessiz tur" temiz ≥ sesli temizin %60'ı (IS-032) |
| **2.6 Kapanış + keşif ön testi** | EP-02 kriterleri + Faz 3 sinyali | IS-040 · IS-064 · IS-057 · IS-075 · US-015 · IS-043 · yeni: keşif ön testi (§3, kullanıcı onayı) · yeni: 2 kişi dengesi (bot 2 kişi stratejisi + hedef fark ≤ 30 puan) · IS-018 kapanış | EP-02 çıkış kriterleri + 2 kişilik insan koşusu; `faz-2` |

Ping'in yeri: akış için **çekirdek + tek "bak" pingi** gerekli (K3 ölü zaman, K4 okunurluk), tekerlek değil. K5 "H2 ≥ 2/dk" çıkarsa US-017 2.4'e alınır (2.4 9 kalem olur → ısı etkisi 2.6'ya kayar). Ev-dükkân (B) 2.6'ya sığmazsa Faz 3'ün ilk şablonu olur.

## 5. Havuz'dan geri çekilecek "cila" (aslında okunurluk/mekanik)

1. **IS-033'ün ekran dışı ses kenar işareti** (`core/sound_indicator_rules`): GDD §6.5 "görüş yoksa sahip nerede dinlemeyle cevaplanır" — kenar işareti olmadan ekran dışı telefon/kapı sesi yalnız halka olarak duyuluyor, ekran dışıysa hiç. Mekanik. Stinger/müzik kısmı cila kalır. XS-S, 2.5.
2. **US-023'ün tutulma/ÇEK/sendeleme alt kümesi**: "sahip 2 sn sendeler", "tutuldu" kukla üstünde okunmazsa ÇEK sonucu görünmez (GB-12'nin ikinci yarısı; IS-110 yalnız HUD rozeti). Ürkme/çanta kısmı cila. XS, 2.4 ya da 2.5.
3. **US-046 lite**: raf üstünde ürün noktası ve elde ürün türü okunmalı (alışveriş v0'ın kendisi okunmuyor: ekmek nerede, elimde ne var); ikon sanatı ve raf dolu/boş animasyonu cila. XS, 2.4.

## 6. Karar gereken (kullanıcı)

1. **Yeni kesim** (§4): A) onay · B) 2.5 ↔ 2.6 yer değişsin (önce kapanış) · C) değişiklik.
2. **Harita sırası** (§3): A) Kalabalık saat varyantı + store_b kararı (2.4), ev-dükkân 2.6 (öneri) · B) ev-dükkân hemen 2.4 · C) iki kapılı köşe önce (M).
3. **Faz 3'e erken geçiş**: A) hayır, tam kapanış · B) keşif ön testi 2.6'da, plan masası Faz 3 (öneri) · C) 2.5 sonrası Faz 3 hemen.
4. **Ping'in yeri**: test-2 K5 sonucuna bırak (öneri) · peşinen 2.4'e al · peşinen Havuz.
5. **2 kişi dengesi** Faz 2 kapanış şartı olsun mu (öneri evet, hedef fark ≤ 30 puan; GDD'deki 15 şimdilik gevşer).
6. **Tohumun görünür etkisi**: çanta yeri 2-3 nokta arasında tohumla değişsin mi (keşif ön testinin ön koşulu; XS seviye + XS kod).
