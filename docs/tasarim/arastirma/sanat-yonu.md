# Sanat yönü ve yapay zekâ ile görsel üretim rehberi (tasarım araştırması)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; koordinatör kaleme çevirir, karar kullanıcıda.
Dayanak: GDD §6.5 (sis tonları), §13 (ton kozmetik), §14 (görsel yön: AI yalnız statik katmanlarda, kukla kodla), §14.1 (KR-017); KR-005 noir; KR-012 yer tutucu; KR-019 ikili ışık; KR-020/3 (AI üretimi evet, assetler.md kaydı, Steam beyanı); KR-022/023 (sis karo ızgarası, Light2D değil); `ui/theme/tokens.gd`; ekran görüntüleri (IS-027 bakkal, US-014 kukla, US-013 HUD).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** token değerlerinden. Kısıt: tek kişi + AI ajan + sanatçısız; görsel iş oynanışın önüne geçmez (test-2 öncesi toplam görsel bütçe ≤ 2 kalem-hafta önerisi).

## 1. Görsel kimlik özeti

**Üç sıfat:** **Loş** (sanatı ışık yapar: sıcak lamba havuzları, soğuk sokak, sis) · **Düz** (az renk, düz yüzeyler, ince koyu kenar; doku değil siluet okunur) · **Zarif** (kuklaların yumuşak oranı ve hareketi; dünya sert, figürler tatlı). Mizah dünyadan değil planın çözülmesinden gelir (GDD ilke 8): görsel ciddi, olaylar komik.

**Referans panosu** (adlar + neden; hepsi "bak, kopyalama"):
| Kaynak | Alınan |
|---|---|
| Monaco [olgu: yalnız görüş hattı, düz renk] | Üstten düz geometri + tek vurgu; okunabilirlik önce |
| Invisible, Inc. | Temiz siluetler, az renk, her nesne 1 bakışta ne olduğu belli |
| Intravenous 2 [olgu: gri-kahve palet, sıcak lamba vs floresan/LED kontrastı, %95 olumlu] | Lamba sıcaklığı ↔ floresan soğukluğu kademe kimliği olur (T1 lamba, T2 floresan) |
| Teleglitch | Karanlığı ucuz çokgenle satmak; "görmediğin yer" tasarım öğesi |
| This Is the Police | Düz vektör noir; az ayrıntıyla "suç şehri" hissi |
| Edward Hopper, *Nighthawks* | **Sıcak iç mekân / soğuk gece dışarısı** — paletimizin özü |
| Saul Bass afişleri | Düz şekil + tek vurgu rengi; kapsül/menü dili |
| Tom Haugomat illüstrasyonları | Sınırlı palet, kalın gölge blokları, insan figürü küçük ve zarif |
| *The Third Man* (film) | Sert ışık, ıslak kaldırım yansıması, köşe ve kapı aralıkları |
| *Fargo* / *In Bruges* (film) | Ton: kuru suç komedisi; dünya ciddi, insanlar beceriksiz |

**Yasaklar:** piksel-retro görünüm (KR-017) · fotogerçekçi doku ve 3B render · izometrik derinlik (bakış hafif 3/4, perspektif yok) · gradyan/lens flare/neon gökkuşağı · birden fazla vurgu rengi (ALERT tek) · dünyada okunması gereken yazı (32 px'te okunmaz; tabela = şekil) · kan/gore · "koyu gri bulamacı" (zemin ile işaret kontrastı < 3:1, okunabilirlik-2d §3).

## 2. Palet

**Mevcut token değerlendirmesi [hesap/görüş]:** BG #0f1114 (soğuk mavi-siyah) ve FG #e6e2d8 (sıcak krem) zıt sıcaklıkta — iyi, "soğuk dünya, sıcak insan/yazı" zaten kurulu. ACCENT #c9a24b (eski altın) noir'a uygun; tezgâh rengi buradan türüyor, işaret rengi olarak kullanılmıyor (doğru). LEVEL_FLOOR #2f2c26 sıcak-kahve (iç mekân) ↔ SIDEWALK #212429 / STREET #15171b soğuk (dış) ayrımı zaten var; bugünkü ekran görüntüsünde fark zayıf okunuyor çünkü doku ve ışık yok, yalnız düz dolgu. Öneri: token'lara dokunma; sıcaklık farkını **ışık havuzu + doku** ile görünür kıl (§3-4). Eksik iki token: `LEVEL_FLOOR_LIT` (zemin + lamba havuzu merkezi, FLOOR→ACCENT %22 ≈ #3a3426) ve `LEVEL_GLASS_NIGHT` (dışarıdan bakınca cam yansıması, MUTED α0,25) — arayuz ekler, S9 kuralı (tona bağlı).

**Kural:** sıcak renkler (ten, yanak, atkı, lamba sarısı) yalnız karakterlerde ve ışık kaynaklarında; mekân soğuk-nötr; vurgu tek (ALERT). Oyuncu rengi yalnız atkı/ad/ping/çizim (okunabilirlik §2.8).

**Kademe başına atmosfer (ışık rengi = CanvasModulate + havuz dokusu rengi; sayılar başlangıç, `ui/theme/tones/` değil `data/levels/<id>_atmosphere.tres` — tonlar bunu çarpar):**
| Kademe | Saat (GDD §9) | Ambiyans (CanvasModulate) | Işık kaynağı rengi | Dış mekân | Kimlik cümlesi |
|---|---|---|---|---|---|
| T1 bakkal | gündüz, mesai → **öneri: ikindi, kapalı hava** (karar gereken, §9) | #b9b6ad (nötr-sıcak, %72 parlaklık) | tungsten #ffd59a, raf üstü lamba | çelik grisi gök, ıslak kaldırım yansıması | "Mahalle dükkânı, lambalar erken yandı" |
| T2 benzinlik | gece | #6f7a86 (soğuk) | floresan #d9ffe8 (yeşilimsi beyaz) + tabela neon tek renk | zifiri, pompaların üstü aydınlık ada | "Floresan adası" |
| T3 kuyumcu | gündüz randevu / gece bekçi | #a89f90 / #4d4f5a | vitrin spotu #fff1c4 | vitrin ışığı sokağa taşar | "Cam ve spot" |
| T4 depo | gece sanayi | #4a4f5c | sodyum #ffb347 | hareket sensörlü ışık (ikili, oyun bilgisi) | "Turuncu lamba, mavi gölge" |
| T5 kumarhane | gece | #5a3f3f | altın #ffd27a + kırmızı halı | vale ışıkları | "Kırmızı ve altın" |
| T6 müze | gece | #3f4652 | soğuk spot #e8f0ff, mermer | yok | "Beyaz ışık, siyah salon" |
| T7 transfer | gündüz sokak | #c2c2bd | gün ışığı, gölgeler kısa | tamamı dış | "Gri gün, parlak zırh" |
| T8 banka | gündüz | #b5b2aa | nötr beyaz | şehir merkezi | "Mermer ve kepenk" |
| T9 ofis | gece | #2f3a4d | monitör mavisi #9ec5ff | cam cephe | "Mavi ekran ışığı" |
| T10 darphane | gece/yeraltı | #2b2a2a | altın yansıması + beton | askeri | "Altın karanlıkta" |

## 3. Işık ve gölge (Compatibility renderer)

**[olgu]** Godot 4 Compatibility'de 2D ışık (PointLight2D, DirectionalLight2D, add/sub/mix karışımı, CanvasModulate, LightOccluder2D, PCF gölge) çalışır; belge "ek (additive) sprite'lar dinamik efektler için 2D ışıktan daha hızlıdır", "PCF13 yalnız birkaç ışıkta" der. KR-023: sis **karo ızgarası + CPU ışını**, Light2D değil; KR-019: oyun mantığında ışık **ikili** (karanlık bölge evet/hayır).

**Öneri — "boyanmış ışık" (iki katman, Light2D yok, Faz 2-3):**
1. `CanvasModulate` = kademe ambiyans rengi (tablo §2). Tek düğüm, sıfır maliyet; "gece/gündüz" hissinin %60'ı buradan.
2. **Işık havuzu dokuları**: yumuşak kenarlı radyal/elips PNG (64-256 px, 2-3 çeşit: tavan lambası dairesi, vitrin şeridi, kapı aralığı yelpazesi), `Sprite2D` + `CanvasItemMaterial.blend_mode = ADD`, renk = kaynağın rengi, α 0,25-0,45. Yerleşim **seviye verisinden**: her `LightSpot` işareti bir havuz; karanlık bölgeler (KR-019) havuzsuz kalır. Böylece "görünen ışık" ile "oyun ışığı" çelişmez: oyuncunun karanlık sandığı yer gerçekten karanlık bölgedir.
3. Gölge: baked. Prop'ların altında 2-3 px yumuşak koyu elips (güneye), duvar diplerinde 4 px iç gölge şeridi (BG α0,35). Dinamik gölge yok (sis zaten "göremediğin yer"i anlatıyor; iki sistem üst üste okunabilirliği bozar).
4. Sisle uyum (GDD §6.5): çizim sırası zemin → havuz (ADD) → prop → kukla → **sis örtüsü** (MEMORY α0,55 + doygunluk ×0,5; UNKNOWN α0,88) → işaretler/HUD. Havuzlar hafıza katmanında soluklaşır (doğru: "ışık vardı" hatırlanır), bilinmeyende görünmez. Karanlık bölge taraması sis katmanının altında, havuzun üstünde.
5. Light2D ne zaman: T2 el feneri / dönen kamera konisi gibi **hareket eden** 1-3 ışık (Faz 4), gölgesiz (occluder yok), PCF yok. Kabul: 1280×720'de ≤ 4 PointLight2D, GPU süresi ≤ 1 ms (altyapi ölçer).

**Kabul (ışık kalemi):** headless ekran görüntüsünde T1 sahnesinde en az 3 havuz görünür; işaret kontrast testi (okunabilirlik §6 AC 6) havuz merkezinde de ≥ 3:1 (ALERT havuz üstünde 1 px FG dış çizgiyle); hareket azaltma ışığı etkilemez; sis tonları değişmez.

## 4. Mekân görselleri

**Stil kuralları (her karo/prop için):**
- Bakış: üstten + hafif 3/4: nesnenin **üst yüzü** ana şekil, **ön yüz** alt kenarda ince bant (yükseklik ≤ %25). Perspektif yok; her prop aynı sanal kameradan.
- Işık yönü: tavandan (üst yüz en açık), ön bant bir ton koyu, zemin gölgesi güneye 2-3 px. Prop içinde ışık kaynağı çizilmez (havuz sistemi yapar).
- Çizgi: 1 px koyu kenar (BG α0,6), iç detay en fazla 2-3 ton; yazı yok, logo yok, tabela = renkli dikdörtgen + simge.
- Ölçek: 1 karo = 32 px dünya; zoom 1,5 → 48 px ekran. Asset **64 px/karo** (2×) üretilir, doğrusal süzgeç, mipmap kapalı; prop boyutu karonun tam katı (1×1, 2×1, 1×2, 2×2).
- Zemin dokusu: parlaklık varyansı ≤ ±%6 (işaret kontrastı için; dokulu zemin "gürültü" değil "tahta/karo" izlenimi), 4×4 karo (256 px) döşenebilir, 2 varyant (sırt-sırt döşemede desen görünmesin).
- Duvar: üst yüz LEVEL_WALL düz + 1 px kenar (bugünkü gibi), yalnız dış cephede ince tuğla/sıva dokusu (α0,3). Raf: üstten ürün blokları (3-4 doygunluğu düşük renk, her raf farklı karışım; ürün = 6×6 px dikdörtgen, okunmaz). Tezgâh: ahşap üst yüz + ön bant; kasa ayrı prop. Cam: LEVEL_GLASS şerit + 2 çapraz açık çizgi (yansıma); kapı: açık/kapalı iki sprite (durum ekip görüşünde; §6.5).
- Zemin bölgeleri birbirinden **malzeme** ile ayrılır (satış alanı: eski tahta/karo; arka oda: beton; kaldırım: taş plaka; cadde: asfalt + beyaz çizgi) — bugün yalnız ton farkı var.

**Bakkal dekor listesi (23 öğe; konum `store_a.txt` düzeni; yıldızlı = kültürel vurgu, §9 soru 2):** tezgâh üstü: yazar kasa (R, mevcut), sigara rafı (K arkası doğu duvarı, kilitli cam), sakız/çikolata standı, piyango/kart standı, tespih*, nazar boncuğu* (kapı üstü), takvim* (duvar), kedi (bekleme noktalarından birinde uyur; tıklanmaz, dekor) — satış alanı: gazete standı (F yanı), buzdolabı-içecek (batı duvar S sütunu yerine 1 adet, cam kapı aydınlık), dondurma dolabı, ekmek rafı, meyve kasası (F dışı kaldırım), süpürge+kova (köşe), elektrik sayacı/panel (duvar), "yalnızca personel" kapı tabelası (D; simge) — arka oda: çay ocağı/semaver* (V yanı), koli yığını (2×2, görüşü keser → `vision_block`), evrak dolabı, taşınabilir radyo, çekmeceli masa (nakit çantası yeri), katlanır sandalye — dış: kaldırım bordürü, çöp kutusu, tabela (şekil), rögar kapağı, park halinde bisiklet/mobilet, lamba direği (havuz). Kuzey ara sokak: çöp konteyneri (gizlenme, görüşü keser), yangın merdiveni gölgesi. Oynanışa dokunan 3'ü (koli, konteyner, buzdolabı görüşü keser) seviye kaleminde `vision_block` grubuna girer; gerisi salt dekor.

**Kültürel ton (karar gereken):** öneri **"Türk vurgulu evrensel"**: dükkânın iskeleti evrensel (raf, kasa, buzdolabı, piyango), 4-5 vurgu öğesi Türk mahallesi (çay ocağı, tespih, nazar, takvim, meyve kasası). Üst kademeler şehirleştikçe vurgu azalır (banka/ofis evrensel). Neden: iki İsveçli oyuncu için okunur, Türk kökeni kimlik verir (BOMBANANA! emsali, pazarlama §3), yazı gerektirmez. Risk: karikatür; çözüm vurgu ≤ 5 öğe, hepsi "sıcak" (ev gibi), hiçbiri şaka.

## 5. Karakterler

- Kuklalar **kodla kalır** (GDD §14: AI içeriği sayılmaz). `PuppetLook` doku yuvaları (baş, başlık, gövde, el) Faz 2-3'te **boş**; dolu yuva yalnız düz-şekil PNG kabul eder (AI boyama yok). Neden: kod-çizim parça + AI-boyanmış parça yan yana stil kırılması; US-014 görüntüleri (yuvarlak baş, yanak, atkı) zaten hedef hissi veriyor.
- Rol başlıkları (GDD §14.1): Ghost kapüşon · Tech bere + kulaklık · Muscle kasket; sivil: sahip **önlük + kel/kasket**, müşteri **torba/şemsiye** (başlıksız), yoldan geçen **palto**, mahalleli **terlik + sıvalı kol**. Ek öneri: sahibe bıyık (2 px çizgi) ve tezgâh arkasında gövde ölçeği 1,05 (kim sahip, bir bakışta); mahalleliye elinde terlik/sopa silueti (kovalayan okunur).
- Sıcaklık kuralı: ten #f1dcc4 / yanak #f0a0a0 / atkı oyuncu rengi — sahnedeki en sıcak renkler karakterlerdir; NPC teni aynı, atkısız.
- AI'nin karakterlere temas ettiği tek yer: **portreler** (insider kartı, iş sonu "Notlar" kartları, lobi avatarı) — siluet + kod adı (GDD §14), 128×128, aynı stil referansıyla; kukla ile yan yana durmazlar (ayrı ekran).
- Doku yuvaları için küçük istisna adayı (karar gereken, §9 soru 3): önlük/çizgili gömlek/rozet gibi **desen** katmanları (başlık ve gövde yuvası), AI ile üretilip palet kuantizasyonundan geçirilmiş düz desenler.

## 6. AI üretim hattı

**Steam kuralı [olgu]:** Ocak 2026 güncellemesi: beyan oyuncunun gördüğü/duyduğu üretilmiş içerik içindir; kod yardımcıları gibi "arka plan araçları" muaf; ön-üretilmiş (geliştirmede) ve canlı-üretilmiş (oyun sırasında) ayrı işaretlenir; metin mağaza sayfasında "About This Game" altında herkese görünür; Temmuz 2026'da mağazadaki oyunların ~1/5'i beyanlı. Biz: ön-üretilmiş **evet**, canlı-üretilmiş **hayır**.

**Araç bağımsız istem şablonu** (her asset aynı önek; araç/model adı assetler.md'de):
- Stil öneki: `top-down 3/4 view game asset, flat shaded, minimal noir palette, muted desaturated colors, cool grey-blue shadows, one warm accent at most, thin dark outline, overhead lighting, plain solid background, no text, no logo` (+ `seamless tileable texture` karolar için; + `isolated single object, centered` prop için).
- Negatif: `text, letters, logo, watermark, photorealistic, 3d render, perspective, isometric, gradient, lens flare, neon, people, hands, blur, noise, grain, multiple objects, frame, border`.
- Nesne satırı: `<nesne>, <malzeme>, <boyut: 1x1 tile / 2x1>`; renk anahtarı `#2f2c26 floor, #55585f wall` (modeller hex'i yaklaşık uygular; kuantizasyon düzeltir).

**Tutarlılık yöntemi (sırayla; en ucuz önce):**
1. **Stil kilidi sayfası**: ilk 6 onaylı asset (zemin, duvar, raf, tezgâh, buzdolabı, lamba direği) tek sayfada; sonraki her üretimde **stil referansı** (IP-Adapter / "style reference" / img2img %35-50 güç) olarak verilir [olgu: IP-Adapter LoRA eğitimsiz stil aktarımı; ControlNet lineart silueti kilitler]. LoRA eğitimi **gerekmez** (asset sayısı < 200, tek stil).
2. Aynı model/sürüm + seed aralığı kaydı; "aile" halinde üretim (bir sayfada 4-6 benzer prop, sonra kesme) — sayfa içi tutarlılık tek tek üretimden iyidir.
3. **Son işlem her zaman aynı** (asıl eşitleyici): 2× ölçeğe küçült → proje paletine kuantize (≤ 24 renk: token'lar + 8 ara ton; ImageMagick `-remap palette.png` ya da Aseprite) → 1 px BG α0,6 kenar → gölge elipsi → döşeme dikişi kontrolü (2×2 döşe, görsel) → kontrast ölçümü (işaret renkleri üstünde ≥ 3:1).
4. İnsan son dokunuşu **şart** olan yerler: dikiş/artefakt temizliği, yazı kalıntısı silme, prop boyutunu karo katına kırpma, kapı/raf gibi **durumlu** nesnelerin iki halinin aynı hizada olması, ürün renklerinin ALERT/CASH ile çakışmaması, nihai "yan yana" bakış (bir ekranda 20 prop).

**Dosya adlandırma ve kayıt:** `assets/gen/<tür>/<id>_v<n>.png` (tür: tiles, props, light, ui, portrait, sfx); id snake_case Türkçe-siz (`floor_shop_wood`, `fridge_drinks_2x1`). `docs/notes/assetler.md` sütunları: id · dosya · tür · **AI üretimi** (evet / hayır / karma) · araç + model + sürüm · istem özeti · seed · tarih · insan dokunuşu (ne yapıldı) · lisans/çıktı hakkı notu · kullanıldığı sahne. CC0 yer tutucular "yer tutucu" bayrağıyla aynı tabloda (KR günlüğü 2026-10-02).

**Steam beyan metni taslağı (TR/EN, ön-üretilmiş):** "Oyundaki bazı statik görseller (zemin ve duvar dokuları, dekor nesneleri, tabela ve ikonlar, portreler) ve bazı ses efektleri üretken yapay zekâ araçlarıyla üretilmiş, geliştirici tarafından elden geçirilip oyuna uyarlanmıştır. Karakterler, animasyon, seviyeler, oyun kuralları ve arayüz elle/prosedürel yapılmıştır. Oyun sırasında canlı yapay zekâ içeriği üretilmez." / "Some static art (floor and wall textures, props, signage, icons, portraits) and some sound effects were produced with generative AI tools, then reviewed, edited and integrated by the developer. Characters, animation, levels, game rules and UI are hand-made or procedural. No content is generated live during play."

## 7. Öncelik listesi — test-2 öncesi en yüksek getirili 5 iş

| # | Kalem taslağı | Sahip | Büyüklük | Kabul kriteri |
|---|---|---|---|---|
| 1 | **Stil kilidi**: 6 onaylı asset + stil sayfası + palet.png + son işlem betiği + `assetler.md` şablonu | seviye (üretim) + koordinatör (onay, kullanıcı bakar) | S | 6 asset tek sayfada; kuantize palet ≤ 24; `tools/asset_post.sh` tek komutla çalışır; assetler.md ilk 6 satır dolu |
| 2 | **Bakkal zemin/duvar/cam seti v0**: 4 zemin malzemesi (2 varyant), dış cephe, cam, kapı 2 hal | seviye | M | Döşeme dikişsiz (2×2 test görüntüsü); işaret kontrast testi (okunabilirlik AC 6) geçer; `level_layout.gd` token'dan değil atlas'tan çizer, yer tutucu yolu `--placeholder-art` ile korunur |
| 3 | **Bakkal dekor paketi v0**: §4 listesinden 20 prop; 3'ü `vision_block` | seviye (+oynanis yalnız vision_block grubu) | M | 20 prop 1280×720'de ayırt edilir; görüş kesen 3 prop headless görüş testinde kesiyor; hiçbiri ALERT/CASH tonunda |
| 4 | **Atmosfer ışığı v0**: CanvasModulate + 3 havuz dokusu + `LightSpot` işaretleri + baked gölge; T1 "ikindi" ayarı | seviye (+arayuz 2 token) | S/M | §3 kabul; sis üç tonu hâlâ tek karede ayırt edilir (§6.5 kabul); GPU süresi ölçümü ≤ +0,5 ms |
| 5 | **Arayüz cilası**: OFL başlık yazı tipi (dar, geniş harf aralıklı noir), CC-BY ikon seti (game-icons.net) ile HUD/iş sonu ikonları, iş sonu kartlarına 3 portre silueti | arayuz | S | Yazı tipi lisansı assetler.md'de; 1280×720 ve 1920×1080 taşmasız (US-013 AC); sabit metin 0 |

Sıra: 1 → (2 ∥ 3) → 4 → 5. 1 bitmeden üretim başlamaz (stil sürüklenmesini önler). Kapsül/klip görseli (pazarlama §7) test-2 **sonrası**: 2-4 bitince ekran görüntüsü kendisi kapsül adayıdır.

## 8. Riskler

- **Stil sürüklenmesi**: 20 prop 20 ayrı stil → kalem 1 önce, son işlem tek betik, "yan yana bakış" kabulü. Etki yüksek / maliyet düşük.
- **Okunabilirlik kaybı**: doku + ışık havuzu işaretleri boğar → zemin varyansı ≤ ±%6, kontrast testi her kalemde, ALERT dış çizgi. Yüksek / düşük.
- **Işık ↔ oyun ışığı çelişkisi**: havuz var ama karanlık bölge sayılır (ya da tersi) → havuz yalnız `LightSpot`/karanlık bölge verisinden. Orta / düşük.
- **Cila zaman tuzağı**: görsel iş oynanış testinden önce şişer → test-2 öncesi en fazla kalem 1-4, her biri S/M; "güzel ama oynanmıyor" durumunda görsel kalem durur. Orta / —.
- **Steam/itibar**: AI beyanı bir kesimi caydırır (1/5 oyun beyanlı; tartışmalı) → kuklalar ve oynanış el yapımı vurgusu, beyan dürüst ve kısa. Orta / düşük.
- **Model çıktı hakları ve eğitim verisi**: araç seçerken çıktı ticari kullanım iznini kayda al (assetler.md "lisans" sütunu); kaynağı belirsiz model yok. Orta / düşük.
- **Kültürel karikatür**: vurgu öğeleri şakaya dönerse → ≤ 5 öğe, sıcak ve sessiz; kullanıcı onayı (soru 2). Düşük / düşük.
- **Compatibility GPU**: ADD sprite ucuz, PointLight2D pahalı; ölçüm olmadan Light2D eklenmez. Düşük / düşük.

## 9. Karar gereken (kullanıcıya; her biri seçenek + öneri)

1. **T1 bakkalın saati/atmosferi.** (a) **İkindi, kapalı/yağmurlu hava** [öneri]: GDD "gündüz, mesai" ve tanık mantığı korunur, lambalar erken yanar → sıcak iç / soğuk dış noir kontrastı gündüz bile kurulur. (b) Gece: en güçlü noir ama GDD §9/§9.1 (mesai, müşteri, yoldan geçen) değişir — KR gerekir. (c) Açık gündüz: en gerçekçi, noir en zayıf.
2. **Kültürel ton.** (a) **Türk vurgulu evrensel** [öneri, §4]. (b) Tam Türk mahallesi (güçlü kimlik, pazarlama kancası; İsveçli oyuncular için bazı öğeler okunmaz). (c) Evrensel-nötr (en güvenli, en kişiliksiz). (d) Kademe başına ülke karışımı (T1 TR, T2 İsveç benzinliği…): ilginç ama tutarlılık maliyeti yüksek.
3. **AI'nin kuklaya teması.** (a) **Kuklalar tamamen kodla; AI yalnız statik katman + portre** [öneri; GDD §14 ile aynı]. (b) Başlık/gövde doku yuvalarına AI üretimi düz desen (önlük, gömlek) — küçük kazanç, stil kırılma riski.

## Kaynaklar
- Valve AI beyanı Ocak 2026: https://gigazine.net/gsc_news/en/20260120-steam-updates-ai-disclosure-guidelines · https://www.notebookcheck.net/Steam-updates-AI-disclosure-form-requiring-developers-to-report-visible-and-in-game-AI-but-not-background-tools.1206103.0.html · https://blog.promise.legal/ai-game-assets-copyright-steam-disclosure-2026/
- Godot 2D ışık ve gölge (Compatibility, ADD sprite notu, PCF maliyeti): https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html
- Stil aktarımı (IP-Adapter, ControlNet lineart): https://blog.segmind.com/comfyui-workflow-for-style-transfer · https://help.scenario.com/introducing-ip-adapter · https://aiindigo.com/tutorials/getting-started-with-ip-adapter-style-transfer-without-fine-tuning
- Döşenebilir doku üretimi ("seamless" anahtarı, karo boyutları): https://www.scenario.com/models/sdxl-for-textures · https://sorceress.games/blog/tile-a-seamless-texture-generator-game-ready-loops-2026
- Intravenous 2 ışık/palet: https://driffle.com/blog/intravenous-2-review/ · https://vaporlens.app/app/2608270/intravenous_2.md
- Noir 2D referansları: https://www.thesixthaxis.com/2014/10/08/indie-focus-at-egx-part-one-calvino-noir-octahedron-soul-axiom/ · https://gamedeveloper.com/art/deep-dive-behind-the-starkly-stylish-art-direction-of-bloodless
- Proje içi: `docs/tasarim/arastirma/okunabilirlik-2d.md` (kontrast tablosu), `docs/arastirma/pazarlama-satis.md` §7 (kapsül), `ui/theme/tokens.gd`, `entities/player/puppet/puppet_look.gd` (doku yuvaları), `levels/layouts/store_a.txt`.
