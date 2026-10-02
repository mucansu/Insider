# Kodsuz keşif ön testi: hafızaya dayalı keşif + ortak kroki (tasarım araştırması, 3. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: uygulanabilir senaryo önerisi; bağlayıcı değil. Dayanak: KR-004 (hafıza kuralı), GDD §4-5, §16 soru 1-3; yontem.md §8.2 (ucuz keşif ön testi) ve §9 (protokol/anket); yol-haritasi.md D3.0 ("3 oyuncunun birleşik krokisi tek oyuncudan ≥ %20 doğru"); benzer-oyunlar §2b; okunabilirlik-2d (ikon dili).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım.

## 1. Soru ve hipotezler

Oyunun özgün iddiası (keşifte görülen krokiye işlenmez; ekip hafızadan ortak kroki yapar) Faz 3'e kadar hiç sınanmadı; en büyük belirsizlik × en yüksek bedel. Kodsuz test 30-45 dk'da üç hipotezi sınar:
- **H1 Zevk:** Hafızadan ortak kroki yapmak "sınav" değil "oyun" gibi hissedilir (≥ 2/3 oyuncu).
- **H2 Ekip hafızası:** Üç kişinin ortak krokisi en iyi tek kişiden daha doğrudur (yalnız ortalamadan değil, **en iyiden**).
- **H3 Zamansal bilgi:** Periyot/saat türü bilgiler (keşfin asıl değeri, GDD §4.2) ±10 sn ile hatırlanır (en az 2/3'ü, en az bir oyuncu tarafından).

## 2. Bilimsel taban (test tasarımını belirler)

| Bulgu [olgu] | Kaynak | Test ve Faz 3 tasarımına etkisi [görüş] |
|---|---|---|
| **İşbirlikli ketleme:** birlikte hatırlayan grup, tek tek hatırlayıp birleştirilen "nominal" gruptan daha az hatırlar (ör. 47 vs 60, 53 vs 72 madde; ~%25-35 açık); yine de grup herhangi bir bireyden fazla hatırlar. | [1][2][3] | Testte üç ölçü alınmalı: birey · nominal birleşim · ortak tartışma. Faz 3 masası için aday kural: **önce 30-45 sn sessiz bireysel yerleştirme, sonra tartışma** (ketlemeyi azaltır). |
| Ketleme, üyeler **örtüşmeyen** bilgi taşıdığında azalır; çapraz ipucu (biri söyleyince diğerinin hatırlaması) mümkün ama kanıt karışık. | [4][5] | Asimetri (içerideki / dışarıdaki) doğru kaldıraç: her oyuncu farklı şey görmeli; test materyali üç farklı açı/zaman dilimi olmalı. |
| Sahne hafızası: ~15 sabitlemeden sonra nesne konum-kimlik eşlemelerinin ~%78'i hatırlanır; son bakılan 3 nesne çok doğru; konum, bakış süresiyle birikir; **nesneler arası mesafe/şekil** hatırlanmaz; konumlar yer imleri (landmark) yanında daha iyi; beklenmedik nesnelerde hata 2 kat (%18 vs %9). | [6][7][8] | Beklenti: 8-10 öğeli sahnede birey ~%70 doğru; kroki ikonları "oda içinde" ölçekle puanlanmalı (karo hassasiyeti değil); kroki hazır duvarlı olmalı (yer imi) — GDD §5 ile uyumlu; "sahte kamera" gibi beklenmedikler zor hatırlanır → keşif değeri. |
| Keep Talking: oyun iletişimin kendisidir; asimetri gerilim, hata, komedi ve dayanışma üretir; 48 saatlik prototipten doğdu. | [9][10] | Zevk ölçüsü = tartışmanın kendisi: iddialar, çelişkiler, "sen gördün mü?" sayısı. |
| Shadows of Doubt: NPC'nin söylediği ya hatırlanır ya yapışkan nota yazılır; otomatik kayıt yok; oyuncular dış not tutmaya teşvik edilir. | [11][12] | Kâğıt-kalem engellenmez (KR-004); testte **serbest** bırakılır ve kimin not aldığı kaydedilir. |
| Hitman: keşif = gözlemle NPC örüntülerini öğrenmek; ilk oynayış saatler, tekrar oynayışlar seçenek açar. | [13] | İkinci tur (aynı sahne) öğrenme ölçer: doğruluk artmalı. |
| Kim's Game: nesneleri kısa süre gösterip örtmek, hatırlananları yazdırmak (izcilik/gözlem eğitimi). | [14] | Isınma turu olarak 1 dk; oyuncuyu "hatırlama" moduna sokar. |

## 3. İzleme materyali: üç seçenek

| Seçenek | Nasıl | Artı | Eksi | Öneri |
|---|---|---|---|---|
| A — Oyun içi bakkal kaydı | Faz 1 build'de (IS-005) bir oyuncu dükkânda dolaşır, OBS/Win+G ile 60 sn kayıt; headless ekran görüntüsü **yok** (`--headless` çizmez) | Gerçek ikon dili, gerçek ölçek | Bakkalda henüz NPC/kamera yok; bakkalın keşif değeri zaten düşük (GDD §4.7) | Hayır (2a sonrası "bak, sonra soy" varyantı için saklanır) |
| B — Gerçek bakkal/benzinlik videosu | Kullanıcı bir dükkânı 60 sn çeker (izinle) ya da stok video | Gerçekçi, tezgâhtar/raf/arka oda doğal | Zamansal bilgi (periyot) yok; izin/gizlilik; krokiye çevrilmesi zor | Yalnız ısınma/alternatif |
| **C — Sahnelenmiş üstten animasyon** | Google Slides/PowerPoint'te üstten plan (bakkal değil, **T2 benzinlik ölçeği**: kamera ×2, DVR odası, tezgâhtar, personel kapısı, arka kapı, kasa) + hareketli ögeler (görevli turu, kamera dönüşü, kurye gelişi); "Slayt gösterisi → kaydet" ile 60 sn video (Slides: dosya → indir → MP4 ya da ekran kaydı) | Zamansal bilgi kontrol altında; iki açı (iç/dış) kolay; doğru cevap anahtarı kesin | Oyun hissi yok (soyut) | **Evet** (2 saat hazırlık) |

**Senaryo A "Gece benzinliği" (C seçeneği, öneri):** 12×8 oda ızgarası, Excalidraw boş krokisi aynı oranda. Statik 6: kamera K1 (giriş köşesi, döner), kamera K2 (koridor, sabit, **sahte** — mercek parıltısı yok; kimse söylemez), DVR kapısı (arka koridor), kasa (tezgâh arkası, sol), personel kapısı (sağ), arka kapı (dış, çöp konteynerinin yanı). Zamansal 3: görevli turu **20 sn** (tezgâh → raf → tuvalet kapısı → tezgâh), K1 dönüşü **8 sn**, kurye t=**35 sn**'de arka kapıdan 10 sn. Rahatsız edici 1: beklenmedik yerde bir anahtarlık (tezgâhın üstü) — "beklenmedik nesne" ölçüsü.
İki video: **İç** (içerideki müşteri: dükkân içi; dış kapı/kurye görünmez) · **Dış** (dışarıdaki: arka cephe, kurye, görevlinin dışarı çıkışı; iç kameralar görünmez). 3. oyuncu: İç videonun **ikinci 30 sn**'si + kısa "hat" notu (Discord'da 2 cümle: "Vardiya 23:00'te değişir; DVR arkada"). Hiç kimse tam resmi görmez (asimetri zorunlu).

## 4. Oturum akışı (Discord ses + ekran paylaşımı, Excalidraw; ~45 dk, 3 kişi; 2 kişiyle de olur: iç + dış)

1. **Brifing 3 dk:** "Bu dükkânı soyacaksınız; bir dakikalığına keşfe gidiyorsunuz; sonra hafızadan kroki çıkarıp plan yapacaksınız. Not alabilirsiniz." Kuralları (neyin önemli olduğunu) söyleme.
2. **Isınma 1 dk:** Kim's Game (10 nesne 20 sn → yaz) — moda sokar, puanlanmaz.
3. **İzleme 3 × 60 sn:** her oyuncu kendi videosunu özel mesajla alır ve **aynı anda** izler (kamera kapalı; "3-2-1"); ya da sırayla ekran paylaşımı, diğerleri ekrana bakmaz. Oyunu bilen kullanıcı **gözlemci**, oynamaz.
4. **Ara 2 dk** (sığınağa dönüş simülasyonu): basit sayma işi (Discord'da "10'dan geriye 7'şer say") — hafıza tazeliğini kırar.
5. **Aşama A — bireysel 90 sn (sessiz):** Excalidraw'da üç ayrı boş kroki (aynı dosyada yan yana, kişi başı renk); ikon paleti: kamera (döner/sabit), görevli, rota oku, kasa, DVR, kapı, zaman notu, "?" (emin değilim). Konuşma yok.
6. **Aşama B — ortak 4 dk:** dördüncü boş kroki; konuşarak birleştirirler. Gözlemci 3 dk'da "1 dakika kaldı" der (yumuşak sayaç denemesi, D3.2); süre aşılırsa kaydedilir, kesilmez.
7. **Aşama C — plan 2 dk:** rota + giriş + 2 zaman notu ("kurye 35'te", "görevli 20 sn'de bir") + kim ne yapar.
8. **Açıklama 3 dk:** doğru cevap krokisi gösterilir; farklar konuşulur (gülünç mü, kızgın mı — not).
9. **Tur 2 (10 dk, isteğe bağlı):** aynı videoları tekrar izle (30 sn), yeniden kroki; öğrenme ölçülür. Ya da ikinci sahne (yoksa atla).
10. **Sohbet 5 dk + anket (24 saat içinde, bireysel).**

Hazırlık: iki video + cevap anahtarı (Fable yazar, kullanıcı çizer: 2 saat) · Excalidraw: "Share → Start session" (uçtan uca şifreli oda linki) [15] · bir boş kroki şablonu 4 kopya · puanlama tablosu (§5) · Discord kayıt izni (yontem §9).

## 5. Ölçüm formu

**Doğruluk (cevap anahtarına göre, oda ölçeği):** statik ikon: doğru tür + doğru oda/bölge = 1; doğru tür yanlış bölge = 0,5; yanlış tür = 0; hayalet (olmayan) = −0,5. Zamansal: periyot ±10 sn = 1 (±20 = 0,5); kurye zamanı ±10 sn = 1. Üç skor: **birey** (A), **nominal** (A'ların birleşimi, çakışmalar tekil), **ortak** (B). Ayrıca "?" ile işaretlenenlerin doğruluk oranı (belirsizlik bilinci).
**Tartışma kalitesi (gözlemci, Aşama B):** iddia sayısı · çelişki sayısı ve çözüm yöntemi (gören kazanır / oylama / "?" bırakma) · zamansal bilgi kaç kez söylendi · en uzun sessizlik (sn) · gülme/klip anı sayısı · süre aşımı (sn) · kim not aldı.
**Zevk (anket, 1-5 + açık):** (1) "Hatırlamaya çalışmak sınav gibi miydi, oyun gibi mi?" (1 sınav – 5 oyun) · (2) "Kroki tartışması eğlenceli miydi?" · (3) "Yanlış hatırladığın bir şey ortaya çıkınca ne hissettin?" (komik / utanç / fark etmez / kızgın) · (4) "Ekip yarın yine yapar dese?" (yontem S6 ölçeği) · (5) "En çok hangi bilgi işine yaradı, hangisi eksikti?" (açık) · (6) "Kaç dakika keşif isterdin?" (sayı) · (7) "Not aldın mı; almasan daha mı eğlenceliydi?" (açık).
**Davranış:** kendiliğinden "bir daha" (kim, ne zaman) · Aşama B süresi · tur 2'de doğruluk farkı.

## 6. Kabul eşikleri ve Faz 3 tasarımına çeviri

| Eşik | Geçerse | Geçmezse → Faz 3 değişikliği |
|---|---|---|
| E1 Ortak kroki ≥ en iyi bireysel skor | Ortak masa olduğu gibi | Masaya **sessiz bireysel aşama** (30-45 sn) eklenir; sonra birleşme (ketleme önlemi) |
| E2 Ortak ≥ nominal × 0,9 | Tartışma bilgi kaybetmiyor | Tartışma yerine "oylama ikonu": aynı yere iki farklı ikon konursa "çift iddia" olarak kalır, oyun seçtirmez |
| E3 Zamansal bilgi ≥ 2/3 (herhangi bir oyuncuda) | Zaman notu paletin birincil aracı | Keşifte **kronometre** aracı (telefon: "başlat/durdur" basılı tut; hafızada değil ama eylem şüphe üretir) ya da iş başına tek zamansal bilgi |
| E4 "Oyun gibi" ≥ 2/3 ve "kızgın" = 0 | Doğruluk iş sonunda gösterilir (D3.1 ile) | Doğruluk oyuncuya hiç gösterilmez; yalnız plan bonusu; ikon "iddia" dili vurgulanır |
| E5 Aşama B ≤ 5 dk, en uzun sessizlik ≤ 30 sn | Masa zamansız kalabilir | 3 dk yumuşak sayaç (yol-haritasi §2) Faz 3'e |
| E6 Tur 2 doğruluğu > Tur 1 | Tekrar oynama değeri var | Keşif-soygun arası değişim oranı (GDD §4.6) düşürülür; öğrenme ödülü güçlendirilir |
| E7 Beklenmedik nesne hatırlanma ≤ %50 | Sahte kamera / gizli önlem keşif değeri taşır | Gizli önlemler daha görünür ipucu alır (mercek parıltısı daha büyük) |

Varsayımlar [görüş]: 3 nazik arkadaş istatistik değil sinyal verir; eşikler "yön" içindir. Video ≠ oyun: gerçek keşifte şüphe baskısı ve hareket vardır; bu test yalnız hafıza-tartışma çekirdeğini ölçer. Tur 2 öğrenmeyi şişirebilir (aynı video) — ikinci sahne varsa tercih.

## 7. Riskler ve karar gereken

Riskler: materyal hazırlığı 2 saati aşarsa test ertelenir (öneri: Slides'ta 12 kutu + 4 hareketli şekil, süsleme yok) · 3 kişi toplanamazsa 2 ile iç+dış (asimetri korunur, H2 zayıflar) · Discord video kalitesi ikonları bozarsa dosya gönder · gözlemci kullanıcı yönlendirmeye başlarsa veri bozulur ("sence?" kuralı).
Karar gereken (koordinatöre): (a) Bu test 2a oyun testinden **önce** mi (bağımsız, bu hafta) sonra mı? Öneri önce: kod gerektirmez, Faz 3 kapsamını belirler. (b) Sahne ölçeği T2 benzinlik mi (öneri; bakkalın keşif değeri düşük) yoksa bakkal (yoldan geçen sıklığı + raf döngüsü + arka oda yeri) mı? (c) Sonuçlar GB-nn satırı + Fable değerlendirmesi mi, yoksa ayrı `docs/tasarim/degerlendirmeler/kesif-on-testi.md` mi? Öneri ikincisi.

## Kaynaklar
[1] Frontiers in Psychology mini derleme, işbirlikli ketleme (2023) — https://www.frontiersin.org/articles/10.3389/fpsyg.2023.1214910
[2] PMC: nominal vs gerçek grup sayıları — https://pmc.ncbi.nlm.nih.gov/articles/PMC10697717/
[3] Psychology in Action, "Collaborative Inhibition" — https://www.psychologyinaction.org/?p=1032
[4] Harris ve ark. (2010), işbirlikli hatırlama — https://www.ida.liu.se/~729G12/mtrl/Harris%20et%20al.%202010.pdf
[5] Çapraz ipucu çalışması (Lancaster) — https://eprints.lancs.ac.uk/id/eprint/18980
[6] Göz hareketleri ve sahne hafızası (Stony Brook) — https://researchconnect.stonybrook.edu/en/publications/eye-movements-and-scene-perception-memory-for-things-observed/
[7] Nesne konumu kodlama, serbest keşif (Arizona) — https://experts.arizona.edu/en/publications/understanding-the-encoding-of-object-locations-in-small-scale-spa/
[8] Göz hareketleri ve nesne/konum hafızası (Northumbria) — https://researchportal.northumbria.ac.uk/en/publications/eye-movements-and-memory-for-objects-and-their-locations/
[9] Kane, "Designing Asymmetric Gameplay for Keep Talking…", GDC 2016 — https://gdcvault.com/play/1023113/Designing-Asymmetric-Gameplay-For-Keep
[10] Keep Talking üniversite kullanımı (iletişim) — https://hkarlsen.rbind.io/posts/eng/002-keep-talking/
[11] Shadows of Doubt: hatırla ya da yaz — https://gamepretty.com/shadows-of-doubt-10-things-you-should-know-before-playing/
[12] Shadows of Doubt inceleme rehberi — https://sia.hackernoon.com/shadows-of-doubt-a-guide-to-investigating-crime-scenes-and-solving-murder-cases
[13] Hitman (2016) ilk seviye ve keşif — https://www.bit-tech.net/reviews/gaming/hitmanreview/2/
[14] Kim's Game — https://en.wikipedia.org/wiki/Kim%27s_Game
[15] Excalidraw canlı oturum (Share → Start session, uçtan uca şifreli) — https://ossalt.com/guides/how-to-self-host-excalidraw-collaborative-whiteboard-2026 · https://plus.excalidraw.com/blog/one-year-of-excalidraw
