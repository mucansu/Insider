# Fable danışması — US-045 (gerçek alışveriş v0, damacana, örtü) + IS-107 (store_b özeti)

2026-10-04, tasarim ajanı (Fable) raporu; koordinatör kararları KR-038'de (docs/surec/kararlar.md). Bu dosya uygulayıcı ajanların başvuru metnidir; KR-038 ile çelişen yerde KR-038 geçerlidir.

Varsayımlar: süreler yürüyüş yolu + ayar değerlerinden hesaplandı (sahip 100 px/sn; store_a ClerkSpot→BackroomSpot ≈ 8 karo ≈ 2,6 sn).

## A) Gerçek alışveriş v0

**İlke:** tezgâhtaki E tek adımlı kalır (tezgâh ürünü), raftan alınan ürün ikinci bir "öde" yolu açar; böylece bot `buy` stratejisi ve mevcut SERVE/keşif kancası hiç değişmez.

| Ürün (oyuncu metni) | Fiyat | Yer | Oyun etkisi |
|---|---|---|---|
| Sakız | 3 | Tezgâh (elde ürün yokken E "Sakız al") | Bugünkü SATIN AL aynen: sahip 6 sn tezgâha kilitlenir, o oyuncuya şüphe 0, oyalanma sıfır |
| Ekmek | 5 | Kapıya en yakın raf ucu | Yalnız kılık: alınca oyalanma sayacı sıfırlanır (ürün başına 1 kez) |
| Kola (cam şişe) | 10 | Soğutucu (I karosu) | Q "Bırak" → kırılır, gürültü **160 px** (çanta düşmesiyle aynı sınıf), sahip DİNLE 6 sn; bırakan "kabahatli" (`again_suspicion` +30 kuralı işler); tek kullanım |
| Konserve (teneke) | 8 | Orta raf | **v0'da yok (KR-038).** Bırak → gürültü 96 px, kırılmaz, yeniden alınabilir |
| Damacana | 40 | Rafta yok; tezgâhta Q sipariş (bkz. B) | Sahip depodan getirir; taşıyan oyuncu yürümeye kilitli (koşu/sızma yok), kasa/çanta/kilit istemleri gizli ("Önce damacanayı bırak") |

- Akış: raf ürün noktasında E 0,5 sn → ürün elde (çoğaltılan durum, kuklada basit yer tutucu; raf doluluk görseli US-046) → tezgâhta E 2 sn "Öde N" → mevcut `serve_player` akışı (servisin 2. sn kasa açılır → boş kasa keşfi aynen) → ekip nakdinden N, ürün `paid`. Ödenmiş ürün elde kalır (kılık), Q ile bırakılır.
- **Atma v0'da yok; yalnız "Bırak" (ayağının dibine).** Fırlatma = nişan + mermi + ağ çoğaltma (yeni sistem); bırakma mevcut çanta düşürme kalıbını (160 px, NoiseBus) yeniden kullanır.
- Elde en çok 1 ürün; çanta alınınca ürün yere düşer (gürültüsüz, cam şişe hariç). Kasa nakdi anında ekip kasasına gider (US-005), elle çakışmaz.
- Örtü: elde ürün (ödenmiş ya da ödenmemiş) örtüyü **bozmaz** (ürün müşteri eşyasıdır). Ödenmemiş ürünle ön kapıdan çıkmak v0'da **bedelsiz** (v0.1 adayı: sahip çıkışı görüyorsa +60 "Parasını vermedin!").
- Kabul: ürün alma/ödeme/bırakma 0 ve 150 ms senaryoda aynı; dump "shop" {taken, paid, dropped}; Kola bırakınca sahip tezgâhtaysa ≤ 1 sn'de DİNLE; damacana eldeyken koşu girdisi yürümeye kırpılır; elde ürünle 60 sn gezen oyuncunun örtüsü sağlam kalır.

## B) Damacana siparişi (GÖNDER'in yerine)

- İstem: **"Damacana iste"** (Q, 2 sn tut; `intimidate` tuşu aynı). Kabul koşulları bugünkü `can_send` (sakin, gönderilmemiş). **İş başına 1** (bugünkü `sent_used`).
- Sahip balonları: kabulde **"Hemen getiriyorum!"** (OWNER_SENT metni değişir); dönüşte damacanayı tezgâha koyunca **"Buyrun, 40 lira."**; 20 sn içinde ödenmezse **"Nereye gitti bu?"**.
- Süre: gidiş 100 px/sn (~2,6 sn) + `sent_sec` 7 sn depoda + **dönüş taşıyarak 60 px/sn** (`walk_speed` ×0,6; ~4,3 sn) → kasa penceresi ≈ 14 sn (bugün ≈ 12). `listen_sec` 6 dokunulmaz. store_b ölçümünde takım temiz oranı > %40'a çıkarsa `sent_sec` 7 → 5.
- Dönüşte `return_check_sec` 1 sn kasa kontrolü **aynen**; damacana prop'u Counter karosuna konur; ödeme = A'daki "Öde 40" (2 sn, SERVE akışı); ödedikten sonra E "Damacanayı al" 1 sn.
- **+20 dönüş bedeli koşullu:** sahip döndükten sonra `order_pay_sec` 20 sn içinde isteyen öderse +20 yok ve şüphesi 0'a çekilir (SATIN AL kuralı); ödemezse 20. saniyede isteyene +20 (bugünkü `send_return_suspicion`, zamanlayıcıya taşınır; arada bağırış olursa iptal).
- Bot `send` ve `team` oyalayıcı: değişiklik yok (Q basar, pencereyi bekler, ödemez → 20 sn sonra +20).
- HUD olay metni: "Bakkal arka odaya gitti." kalkar → **"Damacana istendi."** (nötr; yeri yazmaz). Sahip görev glifi (IS-096) dokunulmaz.

## C) Dışarıdan arka kapıyı çalmak
v0 dışı (KR-038); test-2 sonrası aday. Taslak: B'nin dış yüzünde E "Kapıyı çal" 0,5 sn (30 sn'de 1), gürültü 240 px; sahip tezgâhta sakin ve kesmesizse "Tedarikçi mi geldi?" → BackDoor'a yürür, açar, 2 sn bakar, kapatır, döner (pencere ≈ 7-8 sn; çanta kontrolü yok); koni içinde biri varsa "Önden gel!" +30 + `recognized`.

## D) GB-08 örtü — seçenek A (yalnız görülünce bozulur)
Mevcut bozma tetikleri (heist_rules.gd `cover_breaker`, gözlemciden bağımsız; + olay tabanlı çanta alma):
1. `mask` 2. `bag_value > 0` 3. `holding_cash` 4. `staff_side` (StaffArea/Backroom) 5. `sprinting` 6. `move_mode` sızma 7. çanta alma/devralma olayı 8. `seen_with` (işaretli arkadaşla 48 px — zaten gözlemci şart).
Kural: 1-6 her adımda "durum × o an ≥ 1 NPC görüyor" (sahip/müşteri/yoldan geçen/mahalleli algısının hesapladığı görünürlük); süreklilik taşıyan 1-4 görüldüğü ilk anda bozulur, anlık 5-6 yalnız görülürse. 7 kaldırılır (2 kapsar). 8 değişmez. Polis gelişindeki `witness_released` anlık durum kontrolü koşulsuz kalır.
B (zamanla dönüş) test-2 sonrası veriyle.
Kabul: tek başına sokakta (kimse görmezken) koşan oyuncunun örtüsü sağlam; sahip konisinde 1 adım koşan bozuk; dump `cover` reason + görenin adı (yeni alan `seen_by`). US-043: mahalleli bagger'ı çantayla gördüğü adımda örtü bozulur, kovalama başlar.

## E) store_b tasarım özeti (IS-107)
Aynı S4 işaret/bölge adlarıyla, farklı yön ve ölçekte bakkal. **40 × 24 karo** (store_a 30 × 20). Cadde **batıda** (ön kapı F batı duvarında), yan sokak güneyde, arka sokak **doğuda** (B doğu duvarında). Tezgâh **kuzeyde, güneye bakar** (store_a batıya); raflar **dikey** 5 sıra × 8 karo, 1 karolu koridorlar. Kaçış bölgesi güney caddesinin ortasında (ön kapıdan ≈ 22 karo, arka kapıdan ≈ 28 karo).

Odalar: satış alanı (batı, raflar) + tezgâh önü + **güneydoğu ek alan** (soğutucu köşesi; sahibin tezgâhtan göremediği kör nokta; güney vitrini yan sokağa, doğu penceresi arka sokağa bakar) · personel (tezgâh arkası, telefon, iç kapı D) · arka oda (kasa V, O, nakit M sandık G arkasında köşede: O'dan ve D'den görünmez) · arka sokak (B, sandık G: kapıyı açanı güneyden saklar).

Bilgi bölünmesi anları (KR-035): (1) ek alandaki oyuncu arka sokağı ve bagger'ı görür, sahibi görmez; tezgâh önündeki sahibi görür, sokağı görmez; bagger ikisini de görmez. (2) Ön kapıdan giren tezgâhı raflar yüzünden görmez. (3) Nakit köşesi derinde: bagger içeri girmeden çantanın yerinde olup olmadığını bilemez.
Girişler: müşteri F (batı kaldırımı), yoldan geçen a→f (batı vitrini → ön kapı → GB köşesi → güney kaldırımı → GD köşesi → arka sokak), komşu N arka sokakta (bağırışta F'ye uzun yoldan ≈ 7-8 sn).

Taslak (store_a.txt sözdizimine yakın; satır genişlikleri tutarsız, kesin konumlar seviye ajanında):
```
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%____,,,#############################,,%
%____,a,#.................P#V::::::#,,%
%____,,,w...................D:::::::#,f%
%____,,gw.................K.#:::::::#,,%
%____,,,w...............TCRT#:::O:::#,,%
%____,,,w....z...y.x......q.#:::::::B,,%
%____,,,#..S.S.S.S.S......u.#:::::G:#,,%
%____,,,#..S.S.S.S.S........#::::::M#G,%
%____,,,#..SjS.S.S.S........#########,,%
%____,b,F..S.S.SlS.S..................#,,%
%____,,,#..S.S.S.S.S.........I......#,,%
%____,,,#..S.SkS.S.S.........I......#,,%
%____,,,w..S.S.S.SmS.........I......w,,%
%____,,,w..S.S.S.S.S................w,,%
%____,,hw...o...p.r............n....#,,%
%____,,,w...........................#,,%
%____,,,#...........................#,N%
%____,,,#...........................#,,%
%____,,,######################wwwww##,,%
%____,c,,,,,,,,,,,,,d,,,,,,,,,,,i,,,,,,e%
%_________1234____XXXXXX_______________%
%_________________XXEXXX_______________%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
```
Bölgeler: `= StaffArea 22 2 6 4` · `= CustomerArea 9 2 13 17` · `= CustomerArea 22 6 6 13` · `= CustomerArea 28 10 8 9` · `= Backroom 29 2 7 7` · `= X EscapeZone _`.

**Bilerek konan harita-bağımlılık tuzakları** (IS-106 katmanı yakalamalı): (a) tezgâh görevi ve `serve_facing` batı → store_b'de güney (harita ayarı ya da C karosunun müşteri bölgesine bakan komşusundan türetme); (b) bot `COUNTER_STAND (-32,0)` ve `QUEUE_FALLBACK` → müşteri bölgesi tarafından türetilmeli; (c) ShelfProp x 233 / y 295 / **z 421 px** — z 320 px'i bilerek aşar: bot `distract` ClerkSpot'a en yakın rafı seçmeli; (d) `shout_radius` 320 tezgâhtan güney caddesine (≈ 512 px) ulaşmaz → harita başına ya da türetim; (e) komşu yolu uzun → "bağırış → kapıda ≤ 10 sn" store_b'de yeniden ölçülür. heist_stats aynı hücreler iki haritada; store_b'de hedef uyumu şart değil (KR-034), fark bilgi.

## F) Test-2 gözlem formu satırları
1. Alışveriş: ilk 2 dk'da raftan ürün alan oldu mu (kim, hangi ürün, ödedi mi); "bu ne işe yarıyor?" sorusu/zamanı; Kola bırakmayı deneyen var mı, sahibin gelişini okudular mı.
2. Damacana: kim, kaçıncı dakikada istedi; sahibin arkaya gittiğini ekip sesle paylaştı mı; pencere kullanıldı mı; ödeme yapıldı mı / 20 sn bedeli düştü mü; HUD "Damacana istendi" fark edildi mi.
3. Örtü: "Örtün bozuldu" ilk ne zaman, hangi sebep (dump reason + seen_by); oyuncu sebebi söyleyebildi mi; "kimse görmedi ki" şikâyeti tekrar etti mi; polis gelişinde tanık salınan sayısı.
(store_b oynanırsa: ek alanın doğu penceresini keşfeden oldu mu; "bakkal tezgâhta mı?" sorusu kaç kez soruldu.)
