# Sanatçısız üstten 2D'de okunabilirlik: koni, şüphe, karanlık, gürültü, sis (tasarım araştırması, 2. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; US-011 (sis + işaretler) ve US-013 (HUD) için somut kurallar.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** WCAG bağıl parlaklık formülüyle `ui/theme/tokens.gd` değerlerinden hesaplandı (2026-10-02).
Dayanak: GDD §14 (okunabilirlik önceliği, tek uyarı vurgu rengi, işaretler ≥ 22 px), §14.1 kural 2; mimari S9 (`ThemeTokens.GAMEPLAY_*` her tonda aynı); KR-012 (geometrik yer tutucu); KR-019 (ikili karanlık).

## 1. Emsaller

| Oyun | Görüş / ışık / ses nasıl gösteriliyor [olgu] | Ders [görüş] |
|---|---|---|
| Monaco [1][2] | Yalnız görüş hattı görünür; "ışık VEYA gölge" (analog ışık kötü); muhafız başında "?"; son görülen konum kırmızı "!" olarak dünyada kalır. | Durumlar üç, ışık ikili, son görülen konum dünyada işaretli. |
| Mark of the Ninja [3][4] | Ses = ekranda yarıçap halkası; duvar arkasına yol yoksa duyulmaz (yol bulma); muhafız durumu başının üstünde (?, !, dehşet); ışık sert kenarlı. | Halka = yarıçap, duvar kırpar; durum ikonu sabit bağlantı noktasında. |
| Shadow Tactics / Desperados III [5][6] | Koni üç bölge: dolu renk = her durumda görür; **taralı/çizgili** = çömelince gizli; noktalı = sığınak. | Bantları **şekille** (taralı) kodla, yalnız saydamlıkla değil. |
| Darkwood [7] | Oyuncunun koni görüşü; dinamik şeyler (düşman, eşya) yalnız konide; **statik** sahne (mobilya, kapı, ağaç) koninin dışında da görünür → "göremediğin yer" sürekli hatırlatılır. | Sis: duvar/raf/kapı hep çizili, yalnız hareketli ve durumlu şeyler gizli. |
| Teleglitch [8][9] | 360° görüş hattı; görülmeyen alan duvarlardan uzatılan siyah çokgenler (perspektifsiz, ucuz). | Sis geometrisi: oklüder çokgenleri + Light2D yerine basit gölge çokgeni de yeter. |
| Door Kickers [10] | Görüş konisi sisi kaldırır; sis yarı saydam mavi ya da düz siyah; "renkli yollar" seçeneğiyle her asker kendi renginde. | İki sis tonu (hiç görülmedi / görüldü ama şu an değil); oyuncu rengi yalnız oyuncuya ait şeylerde. |
| Invisible, Inc. [11] | Renk tek başına hiçbir bilgiyi taşımıyor; 3 renk körlüğü kipi; duvar arkası muhafızın **adımları görsel** olarak çiziliyor; sorun: küçük metin (cihaz açıklamaları, görev sonu ekranı). | Ses olayının görseli şart; oyun bilgisi taşıyan metin ≥ gövde boyu. |
| Splinter Cell Blacklist [12] | Tespit sayacı büyüyen HUD ögesi = oyuncunun "görüş hattını kırma penceresi"; tasarım asgari HUD istediği için ses geri bildirimi HUD yerine bağırışla. | Şüphe çubuğu muhafızın üstünde (HUD'da değil); ses için kısa bağırış/SFX. |
| Thief, Volume [13][14] | Işık taşı = oyuncunun kendi görünürlüğü; Volume'da koniler 1:1, belirsizlik yok. | "Gizli/açıkta" rozeti; koni tam olarak muhafızın gördüğü alan. |
| Erişilebilirlik [15][16][17] | Hiçbir temel bilgi yalnız sabit renkle verilmez (şekil, ikon, desen, etiket ekle); kırmızı-yeşil, yeşil-kahverengi, yeşil-gri çiftlerinden kaçın; mavi-turuncu güvenli; metin dışı UI ögesi ve grafik için kontrast ≥ 3:1; Okabe-Ito paleti renk körlüğüne dayanıklı; renkli öge kalın/büyük olsun. | Palet denetimi (§3) + her işaret için ikinci kanal. |

## 2. Kurallar (olgulardan türetilen, US-011/US-013 için bağlayıcı öneri)

1. **Üç durum, gradyan yok.** Şüphe 0-100 içeride; ekranda sakin / "?" / "!" (+ tespit). Çubuk yalnız muhafızın üstünde, 0-100 ince yay (Blacklist penceresi), eşiklerde çentik.
2. **Her işaret iki kanal.** Renk + şekil ya da renk + hareket: "?" (beyaz, soru işareti, pop), "!" (ALERT, ünlem, titreme), koni bandı (saydamlık + tarama), halka (çember + genişleme), karanlık (koyuluk + çapraz tarama).
3. **Kontrast ≥ 3:1 her zeminde** (metin dışı WCAG). Bakkal zeminleri: LEVEL_FLOOR #2f2c26, BACKROOM #232323, SIDEWALK #212429, STREET #15171b, WALL #55585f (işaretler duvar üstüne de düşebilir).
4. **Boyut:** oyun bilgisi işaretleri 1280×720'de ≥ 22 px (GDD §14.1), çizgi ≥ 2 px, halka kalınlığı 2-3 px; metin ≥ FONT_SIZE_BODY 18 (Invisible Inc. dersi; SMALL 15 yalnız ikincil).
5. **Sabit bağlantı noktası:** balon ve yay kukla animasyonundan bağımsız (GDD §14.1 kural 2).
6. **Statik dünya hep görünür, durum gizli** (Darkwood/Monaco): duvar, raf, tezgâh, kapı boşluğu her zaman çizilir; kapı **durumu**, NPC, uzak oyuncu, çanta, kasa durumu yalnız ekip görüş hattında. Görülmeyen alan: ışıklı bölgede %60 koyulaştırma, hiç görülmemiş yoksa (bakkal tek ekran; "keşfedilmemiş" sis Faz 3).
7. **Işık ikili** (KR-019): karanlık bölge = BG %70 örtü + 45° tarama (4 px aralık, %8 FG); içindeki oyuncu kuklası %60 parlaklık; koni karanlık bölgeyi **kesmez**, orada tarama taralı kalır (görmüyor).
8. **Tek uyarı vurgusu** (GDD §14): ALERT kırmızı yalnız "!" / tespit / uyarı kademesi / yakalanma için. Sakin koni ve "?" nötr (FG), para CASH yeşil, oyuncu rengi yalnız atkı/ad/ping/çizim.

## 3. Palet denetimi ve token önerileri [hesap]

| Renk | FLOOR | BACKROOM | STREET | WALL | Not |
|---|---|---|---|---|---|
| GAMEPLAY_ALERT #d8453a | 3,20 | 3,62 | 4,13 | **1,64** | Zemin sınırda geçer; duvar üstünde geçmez → ALERT ögeleri 1 px FG dış çizgi ile çizilir ya da işaret duvara binmez |
| GAMEPLAY_CASH #58b368 | 5,34 | 6,03 | 6,89 | 2,74 | ALERT ile 1,67 (kırmızı-yeşil çifti) → asla yan yana, şekilleri farklı ("$" / "!") |
| ACCENT #c9a24b | 5,80 | 6,55 | 7,48 | 2,97 | Tezgâh rengi buradan türüyor; işaret rengi olarak kullanma (zeminle karışır) |
| FG #e6e2d8 | 10,8 | 12,2 | 13,9 | 5,51 | Koni, "?", halka, rozet dış çizgisi için güvenli |
| MUTED #868a92 | 4,02 | 4,54 | 5,18 | 2,06 | Yalnız ikincil çizgi |
| PLAYER_COLORS (4) | 4,4-5,8 | 5,0-6,5 | 5,7-7,4 | 2,3-3,0 | P2 turuncu #e48a3a ALERT ile 1,65 → turuncu oyuncunun hiçbir işareti ünlem/alarm şekli taşımaz |

Öneri yeni token'lar (S9: `GAMEPLAY_*`, her tonda aynı; arayuz ekler):
- `GAMEPLAY_CONE` = FG; sakin dolgu α 0,10 (yakın bant) / tarama α 0,08 (uzak bant); "?"'da α ×2; "!"'de ALERT α 0,25. Ayrı renk gerekmez.
- `GAMEPLAY_NOISE` = FG, kesikli çember 2 px; ikinci renk istenirse #7fd6e8 (8,4 / 4,3 duvar) — noir dışına çıktığı için **karar gereken**.
- `GAMEPLAY_DARK` = BG α 0,70 (+ tarama).
- `GAMEPLAY_PLAN` (Faz 3) = #b9a6ff (6,6 / 3,4), plan katmanı ikon/rota; oyuncu renkleriyle ayrışır.
- İsteğe bağlı `GAMEPLAY_SUSPECT` = #f2b63d (7,6 / 3,9): testte "?" ile "!" karışırsa açılır; P2 turuncuya yakın olduğu için varsayılan **hayır**.
Renk körlüğü: ALERT (kırmızı) ↔ CASH (yeşil) tek çift sorunlu; şekil ayrımı var, ayrıca ayarlarda "ALERT'i Okabe-Ito vermilyon #d55e00 / mavi #0072b2 ile değiştir" seçeneği Faz 4 (GAG önerisi: tam filtre değil, tekil renk değişimi) [15][17].

## 4. US-011 için somut çizim kuralları (görsel katman, istemci; durum host'tan)

- **Koni:** senkron yön + yarım açı 50° + 256 px; 24 kenarlı yelpaze; yakın bant (≤ 128 px) düz dolgu, uzak bant 4 px aralıklı tarama (Shadow Tactics); dış çizgi 1 px FG α 0,35; görüş hattı kırpma istemcide hafif raycast (yalnız görsel; 8-12 ışın, duvar+raf keser, `see_through` geçer); durum: sakin FG / "?" FG ×2 / "!"-kovalama ALERT. Kamera konisi aynı, dönüşsüz, kenarı kesikli.
- **Şüphe yayı:** muhafız başının üstünde 26 px çaplı yay, 0-100; 30 ve 60'ta çentik; renk FG, 60+ ALERT; yalnız ≥ 5 iken görünür; en yüksek oyuncuya göre (çoğaltılan özet).
- **Balonlar:** "?" 24 px FG, easeOutBack 0,2 sn; "!" 28 px ALERT, 0,4 sn titreme; bağlantı noktası kukla boyu + 8 px, animasyondan bağımsız.
- **Bakış noktası / son görülen konum:** "?"'da muhafızın baktığı noktaya 12 px FG nokta + ince çizgi (Mark of the Ninja dersi: "seni gördü mü" tartışması biter); tespit sonrası görüş kaybında ALERT "!" halkası (20 px) son görülen konumda 3 sn, sönerek.
- **Gürültü halkası:** NoiseBus görsel olayı: yarıçap r (S8: koşma 120, kasa 90, kapı 160, sindirme 140) 0,4 sn'de 0 → r genişler, α 0,8 → 0; kesikli 2 px; duvar kırpması: aynı hafif raycast; yalnız ekip görüşündeki olaylar. Koşu adımı her 0,35 sn bir halka (üst üste 2'den fazla değil).
- **Karanlık bölge:** §2.7; kenarı 1 px koyu çizgi; içindeki NPC yalnız görüş hattında.
- **Sis:** §2.6; görülmeyen alan BG α 0,60 örtü (Teleglitch çokgeni ya da Light2D oklüder — teknik seçim koordinatörün); ekip görüşleri birleşik; uzak oyuncunun konisi değil, **görüş alanı** paylaşılır.
- **Kendi rozeti:** HUD sol alt 20 px göz ikonu: "gizli" (FG dış çizgi, karanlık ∧ hiçbir koni içinde değil) / "görünür" (FG dolu) / "görüldü" (ALERT dolu, şüphe ≥ 30). Metin yok, ikon + tooltip anahtarı.
- **Hareket azaltma** (GDD §14.1 kural 5): halka genişlemesi ve balon pop kapanır, durum anında görünür.
- **Headless ekran görüntüsü kontrolü** (Xvfb/Windows `--write-movie` ya da `get_image`): altı durum tek karede ayırt edilir: sakin koni, "?" koni + balon + bakış noktası, "!" koni + son görülen halka, karanlık bölge içinde oyuncu, gürültü halkası duvarla kırpılmış, sis kenarı; görüntü %50'ye küçültülünce de ayırt edilir (uzak oyuncu için).

## 5. US-013 için HUD kuralları

- **Uyarı merdiveni:** üst orta, 4 kutu (0-3) + 2 kilitli kutu (4-5 silik); dolu kutu ALERT, boş kutu LINE; kademe **sayısı ve adı** yazılı (`ALERT_LEVEL_2` → "2 ARAMA"); değişimde 0,3 sn pop + SFX; sayaç yalnız 3'te (90 sn geri sayım, ALERT); 1-2'de sayaç yok (Invisible Inc. tuzağı).
- **Ekip nakdi / çanta:** CASH rengi, "$" ikonu + sayı; çanta taşıyan oyuncu adının yanında çanta ikonu (slot rengi değil, FG).
- **Oyuncu listesi:** slot rengi atkı rengiyle aynı; durum ikonu: koni içinde (FG göz), yakalandı (ALERT kelepçe), kaçtı (CASH ok). Renk + ikon.
- **Etkileşim çubuğu:** mevcut; host iptalinde kısa ALERT yanıp sönme yerine gri sönme (ceza yok, GDD §12).
- **Metin:** oyun bilgisi ≥ 18 px; iş sonu tablosu ≥ 18, başlık ≥ 24; satır arası ≥ 1,3.
- **Kayıp ekranı:** sonuç başlığı ALERT, geri kalan FG; ekran kırmızıya boyanmaz (tek vurgu kuralı).

## 6. Kabul kriteri önerileri ve karar gereken

US-011 AC adayları: (1) §4 ögelerinin hepsi `ThemeTokens` okur, sabit renk yok (tarama testi); (2) birim: koni çokgeni yarım açı/menzil/kırpma; halka süresi ve yarıçapı `noise_profile.tres`'ten; (3) headless altı-durum ekran görüntüsü üretilir ve `tests/screenshots/` altında diff ile karşılaştırılır (±%2 piksel); (4) 150 ms'de koni yönü ara değerlemeli, sıçrama yok (dönüş ≤ 120°/sn istemcide de uygulanır); (5) hareket azaltma seçeneği; (6) kontrast tablosu (§3) için birim test: her `GAMEPLAY_*` × her `LEVEL_*` zemin ≥ 3:1, değilse dış çizgi zorunlu bayrağı.
US-013 AC adayları: (7) merdiven kademe adı + sayı; (8) 1280×720 ve 1920×1080 taşmasız; (9) gamepad odak; (10) sabit metin 0.
Karar gereken: (a) Gürültü halkası FG mi, ikinci renk (#7fd6e8) mi? Öneri FG (noir tek vurgu). (b) Sis tekniği: Light2D + oklüder mi, gölge çokgeni mi? Teknik karar koordinatörde; tasarım gereği yalnız "statik dünya görünür, durum gizli". (c) Renk körlüğü seçeneği Faz 4'e mi? Öneri evet, ama ALERT/CASH şekil ayrımı şimdi.

## Kaynaklar
[1] https://www.gamedeveloper.com/business/doing-stealth-the-i-monaco-i-way
[2] https://i1.trueachievements.com/game/Monaco/walkthrough/2
[3] Miles, Game AI Pro §32 — https://www.gameaipro.com/GameAIPro/GameAIPro_Chapter32_How_to_Catch_a_Ninja_NPC_Awareness_in_a_2D_Stealth_Platformer.pdf
[4] https://critpoints.net/2015/03/30/stealth-game-spotting-deconstruction/
[5] https://godisageek.com/reviews/shadow-tactics-blades-of-the-shogun-review
[6] https://godisageek.com/2020/06/10-desperados-iii-tips-to-help-you-out-in-the-wild-west/ · https://www.gry-online.pl/poradniki/desperados-iii/eksploracja-i-skradanie-sie/z619ad7
[7] https://store.epicgames.com/news/darkwood-is-a-horror-masterpiece-viewed-from-an-atypical-perspective
[8] https://indiegamereviewer.com/review-teleglitch-a-fast-paced-arcade-style-rogue-like-yes-it-is/
[9] https://simonschreibt.de/tag/teleglitch/
[10] https://en.wikipedia.org/wiki/Door_Kickers
[11] https://caniplaythat.com/?p=11130
[12] Walsh, Game AI Pro 2 §28 — https://www.gameaipro.com/GameAIPro2/GameAIPro2_Chapter28_Modeling_Perception_and_Awareness_in_Tom_Clancy%27s_Splinter_Cell_Blacklist.pdf
[13] https://www.gamedeveloper.com/design/building-the-original-i-thief-s-i-revolutionary-stealth-system
[14] https://www.pcgamer.com/uk/volume-duping-guards-in-a-tense-tactical-sneak-em-up
[15] https://gameaccessibilityguidelines.com/ensure-no-essential-information-is-conveyed-by-a-fixed-colour-alone/
[16] https://boldist.co/usability/ui-design-for-color-blind-users/ · WCAG 2 metin dışı kontrast 3:1
[17] Okabe & Ito, "Color Universal Design" — https://jfly.uni-koeln.de/color/
