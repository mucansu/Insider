# Faz 4 ekonomisi: kefalet, ısı, aracı, dükkân fiyatları, T1-T3 kazanç eğrisi (tasarım araştırması, 4. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; sayılar `data/economy/*.tres` başlangıç adayıdır, IS-E5 tablo simülasyonu ve bot koşularıyla (IS-015) ayarlanır.
Dayanak: GDD v0.4 §3 (döngü), §6.3 (gürültü-ganimet), §8 (ekonomi), §9.3 (bakkal ganimeti), §15 (MVP ekonomi: para, aracı, ısı v0, insider v0), §16 soru 5; KR-019 K3 (yakalanan donar, kefalet Faz 4), KR-021 (SATIN AL Faz 2'de bedava); `yol-haritasi.md` §3 (D4.1/D4.2), `benzer-oyunlar.md` §2d; `t2-benzinlik.md` §3 (T2 ganimet 1.080-1.680).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** bizim sayılarımızdan türetilmiş.

## 1. Emsaller

| Oyun | Kural [olgu] | Bize ders [görüş] |
|---|---|---|
| Payday 2 [1][2] | Gelirin %80'i "offshore" (harcanamaz: sözleşme satın alma, infamy), %20'si harcanabilir nakit; önceden 95/5 idi, oyuncular için gevşetildi. Yakalanan (custody) oyuncu düşük zorlukta süre sonunda döner, yoksa ekip **rehine takası** yapar; herkes yakalanınca iş biter. Ön planlama "iyilik" bütçesiyle (Bank Heist: 8), fazla iyilik şüphe uyandırır. | İki kasa fikri doğru ama oran ters olmalı: harcanabilir pay büyük (ilerleme hissi), ekip kasası küçük (kefalet/ön ödeme). Yakalanan oyuncu **asla oyundan düşmez**: ya kefalet ya takas. Plan bonusu/ön yerleşim bütçeli olmalı (Faz 3). |
| Payday 3 [3][4] | İş bitirmek XP vermez; seviye yalnız menüdeki "challenge"larla; oyuncular "seviye sistemi berbat" dedi; para yalnız işten. | İlerleme **işin kendisinden** gelmeli: ödeme ekranı = ilerleme ekranı; meta görev listesi yok (en azından MVP'de). |
| Deep Rock Galactic [5] | Başarısız görev yine de kredi/XP/mineralin **%25**'ini verir; kozmetikler kalır. | Kayıp asla sıfır değil: kaçan çanta ödenir, yakalanan payı düşer, ama ekip toplamı sıfırlanmaz. |
| Monaco 2 [6] | Seviye içindeki coin'ler o seviyedeki açılışları (duman, kılık, kilitli kapı) öder; ek hedeflerle elmas → "trinket" (yetenek değiştirici); remix seviyeler kazancı ikiye katlar. | Yan ganimet (raf değerlileri, sigara dolabı) "anında küçük harcama" değil, kalıcı ekipmana gider; ek hedef ("kimse bağırmadı", "DVR silindi") küçük bonus. |
| PEAK [7][8] | Koşu ≤ ~1 saat, başarısızlık = yeniden; 5 $; ilk 6 günde 1 M, toplam 10 M+; "co-op'un duygusal zirveleri temiz kazanmaktan değil kaostan gelir"; solo hız koşusu dağın kendisi tarafından cezalandırılır. | Kısa koşu + ucuz tekrar: bakkal 3-5 dk, benzinlik 4-6 dk doğru ölçek; ceza oyundan değil mekândan gelmeli (polis sayacı), ve kayıp koşu da "anlatılacak an" üretmeli (iş sonu klip özeti). |
| Hades [9][10] | "Take the sting out of failure": her ölüm hikâyeyi ilerletir; ölüm hem ödül (eve dönüş) hem acı (koşu bitti) — "çift kayıt". | Yakalanma ekranı sığınağa dönüş gibi okunmalı: kefalet makbuzu + istatistik + bir sonraki iş teklifi aynı ekranda; acı var (para gitti), reddediliş yok. |
| Thief Simulator [11][12] | Yakalanınca ganimet el konur, kefalet parayla ödenir ya da hücreden kaçılır (maymuncuk/levye); hardcore kipte hapis + tüm mal el konur. Polisi atlatınca "bir tur daha devriye" sonra gider. | El koyma **ekipmana** uzanmasın (karakter gelişimi parayla; kaybı felaket); kefalet ganimetten değil kasadan. Isı sönümü "görülmeden geçen zaman"la (GTA) değil **iş döngüsüyle** (GDD): oturum arası sayaç yok. |
| GTA Online [13] | Lider kurulum masraflarını öder, ~%40 pay alır, rolleri dağıtır; kurulum görevlerinde lidere para yok. | Host "payı değiştirebilir" (GDD) kalsın ama varsayılan **eşit**: 3 arkadaş ekonomisinde lider payı kırgınlık üretir. |
| GTA wanted sönümü [14] | Görüş dışı kalınca yıldızlar zamanla gider; GTA 6'da "iz silme / yanıltma" yönüne gidildiği konuşuluyor. | Isı düşürme eylemleri (DVR silme, aklama, sessiz kal) GDD ile uyumlu; zaman tabanlı sönüm yok. |

## 2. Para akışı (öneri)

- **Ödeme** = Σ(kaçırılan ganimet değeri) × aracı oranı × (1 + bonuslar). Ödemenin **%80'i cüzdanlara eşit** (yakalananın payı 0, K3; onun payı diğerlerine **dağıtılmaz**, kasaya gider), **%20'si ekip kasası** (kefalet, ön ödeme, aklama, insider ücreti). Host eşit payı değiştirebilir (GDD), MVP'de arayüz yok.
- **Aracı oranı:** taban 0,85 temiz; uyarı 3 (sessiz alarm/mahalleli içeride) 0,70; uyarı 4+ 0,45 (T5+). Bonuslar: "kimse bağırmadı / düğmeye basılmadı" +0,05; "kayıt yok" (T2: DVR silindi ya da hiç görülmedi) +0,05; plan bonusu (Faz 3) +0,05-0,10; itibar (kademede ≥ 3 temiz) taban 0,90. Ceza: "sıcak mal" (DVR kaydı polise kaldı) sonraki 2 işte −0,05. Tavan 0,95. **Ekip oranı**, kişi başı değil (§16 soru 5; öneri: MVP'de ekip; "gürültü yapan −%10" MVP sonrası, karar gereken).
- **Ganimet ölçeği** (GDD §8/§9.3, t2-benzinlik §3): T1 450-840 (ort. 650) · T2 1.080-1.680 (ort. 1.400) · T3 5.000-15.000 (ort. 8.000).

## 3. Kefalet (K3) — "bir daha" isteğini öldürmeyen ceza

| Kural | Değer | Neden / neyi riske atıyor |
|---|---|---|
| Yakalananın bu işten payı | 0 (K3) | Görünür, adil, kişiye bağlı. Risk: sürekli aynı kişi yakalanırsa küser → 4. satır. |
| Kefalet (ekip kasasından, otomatik) | T1 200 · T2 500 · T3 1.000 (≈ o kademede bir kişinin temiz payının 1,5-2 katı) | Kayıp **ekip** kaybıdır (co-op). Risk: kasa boşsa → borç. |
| Borç | Kasa yetmezse eksik, sonraki işlerin kasa payından (%20) ödenir; cüzdanlara dokunmaz; HUD iş panosunda "borç: 300" | Oyuncu hiçbir zaman ekipman alamaz hale gelmez. Risk: borç sürüklenir → ısı değil, yalnız kasa; görünür tavan 2 × kefalet. |
| Yakalanan oyuncu bir sonraki işte | Tam oynar; "parmaklıktan yeni çıktı" rozeti (kozmetik), tanınma sayacı +1 (o mekânda) | Hades: ceza hikâyeye döner. Risk: tanınma sayacı T2+'ta hızlı tespit → mekân değiştirmeyi teşvik (iyi). |
| Herkes yakalandı | Ödeme 0, kefalet ×3, ganimet el konur; ekipman **kalır** | Thief Sim hardcore'un tersi. |
| Tavan | Bir işin toplam cezası ≤ o kademenin beklenen ekip gelirinin %60'ı [hesap: T1 200+0 vs 425; T2 500 vs 830] | "Bir koşu daha" beklenen değeri hep pozitif tutar (DRG %25 ilkesi). |
| Rehine takası (T5+) | Payday 2 kuralı: rehine tutan ekip yakalananı iş içinde geri alır | MVP dışı; GDD §9 T8 "rehine pazarlığı" ile gelir. |

İlkeler [görüş]: (1) kayıp sıfır değil (DRG); (2) ceza isimli ve görünür ("kefalet makbuzu" ekranı, komik metin); (3) ceza bir sonraki işte **seçeneğe** dönüşür (sessiz kal turu, aklama); (4) ekipman/karakter asla el konmaz; (5) kayıp koşu da istatistik ve klip üretir; (6) bir sonraki koşunun beklenen değeri daima pozitif.

## 4. Isı (0-100, ekip; GDD §8 üstüne T1/T2 eşlemesi)

Artış: bağırış/panik +5 · sessiz alarm +10 · yakalanma (kişi başı) +10 · DVR kaydı polise kaldı +15 · keşif şüphesi (Faz 3) +0-5 · iş başarısız +5. Azalış: iş döngüsü başına −10 (başarı/başarısızlık fark etmez) · "sessiz kal" (bir iş atla; sığınakta düğme, 3 kişi onaylar) −25 · aklama (kasadan 300) −15. [hesap] Temiz koşu net −10 (tabanda 0); sıcak koşu 0; bir yakalanmalı koşu +10; DVR'lı kötü koşu +25. Isı 40'a ancak 3-4 ardışık kötü koşuda çıkar — "görünmez kalır" riski (yol-haritasi D4.2) gerçek; bu yüzden **HUD'da ısı ölçeri sığınakta ve iş panosunda, etkisi metinle** ("ısı 45: devriye arabası 2 dk'da bir").

Etkiler (GDD): >40 "muhafız +1" → mekân eşlemesi: T1 komşu +1 ve varış 8 → 6 sn; T2 devriye arabası 3-4 → 1,5-2 dk ve polis 120 → 100 sn · >60 insider çekilir, ihanet (MVP sonrası) · >80 polis ×1,5 hız, dükkân +%20. Kabul (D4.2): ısı > 40 ile oynanan 3 koşuda anket "ısı kararını değiştirdi mi" ≥ 2/3 evet.

## 5. Dükkân (MVP 6 eşya) ve yetenek kapıları

| Eşya | Fiyat | Kapı / etki | Kim alır [görüş] |
|---|---|---|---|
| Dürbün | 150 | Keşif dışarıdaki (Faz 3): 30°/640 px koni | herkes (ucuz ilk alım) |
| Sessiz ayakkabı | 250 | Koşma gürültüsü 120 → 80 px, adım sesi yok | Ghost |
| T2 maymuncuk | 350 | T2 kilit (benzinlik ofis kasası, T3 kapıları) 8 sn; T1 kilit 4 sn | Ghost — **T2'yi açan kapı** (backlog EP-04 çıkış kriteri) |
| Deck v0 | 450 | DVR SİL (6 sn); dönen kamera periyodunu HUD'da gösterir | Tech |
| İkinci çanta | 300 | Bir oyuncu 2 çanta (hız −%30) | Muscle |
| Kamera jammer | 500 | 20 sn tüm kameralar kör, iş başına 1 | Tech/Muscle |
| (sonra) ECM | 5.000 (GDD) | Polis sayacı +30 sn | T3 hedefi, MVP dükkânında görünür ama pahalı ("hedef göster") |

GDD §8 merdiveni (T1 maymuncuk 200 → susturuculu 1.500 → ECM 5.000 → T3 deck 25.000) korunur; MVP eşyaları 150-500 bandına oturur. KR-021 "SATIN AL bedava" Faz 4'te 10'a döner (ekip kasasından).

## 6. Tablo simülasyonu (kod yok; IS-E5 bunu hesap tablosuna ve bot koşularına taşır)

Varsayımlar [görüş]: 3 kişi; sonuç dağılımı T1 temiz %50 / sıcak (uyarı 3, kaçtı) %30 / 1 yakalanan %15 (ganimetin yarısı kaçar, oran 0,70, kefalet 200) / tam kayıp %5; T2 %40/%35/%20/%5 (kefalet 500); T3 %35/%35/%20/%10 (kefalet 1.000). Temiz oran 0,875 (taban + bir bonus).

| Kademe | Ganimet ort. | Beklenen ekip ödeme/koşu [hesap] | Kişi cüzdanı (%80/3) | Kasa (%20) | Koşu + sığınak süresi | Kişi geliri/saat |
|---|---|---|---|---|---|---|
| T1 bakkal | 650 | 0,5·650·0,875 + 0,3·650·0,70 + 0,15·(325·0,70 − 200) ≈ **425** | ≈ 113 | ≈ 85 | ~7 dk | ≈ 970 |
| T2 benzinlik | 1.400 | 490 + 343 − 2 ≈ **830** | ≈ 222 | ≈ 166 | ~8 dk | ≈ 1.660 |
| T3 kuyumcu | 8.000 | 2.450 + 1.960 + 360 ≈ **4.770** | ≈ 1.270 | ≈ 950 | ~10 dk | ≈ 7.600 |

Koşu koşu (beklenen değerlerle, rol başına alım):

| Koşu | Kademe | Ghost cüzdan | Tech cüzdan | Muscle cüzdan | Kasa (kefalet sonrası) | Alım / olay |
|---|---|---|---|---|---|---|
| 1 | T1 | 113 | 113 | 113 | 85 | — |
| 2 | T1 | 226 | 226 | 226 | 140 | Dürbün (Tech, 150) |
| 3 | T1 | 339 | 189 | 339 | 195 | **T2 maymuncuk (Ghost −350 → kasa borçsuz, cüzdan −11 → 4. koşuda)** ; itibar T1 ≥ 2 temiz |
| 4 | T1 | 452 → 102 | 302 | 452 | 250 | T2 maymuncuk alındı → **T2 açıldı**; ikinci çanta (Muscle, 300 → 152) |
| 5 | T2 | 324 | 524 → 74 | 374 | 416 | Deck v0 (Tech, 450) |
| 6 | T2 | 546 → 46 | 296 | 596 → 96 | 582 | Jammer (Muscle, 500), sessiz ayakkabı (Ghost, 250 → 296) |
| 7-8 | T2 | — | — | — | ~900 | Kit tamam; ECM 5.000 "uzak hedef" (≈ 20 T2 koşusu → T3 gerekir) |

Okuma [hesap]: T2'ye **4. koşuda** geçilir (hedef "4-6 işte Alet A+B + 1 gadget" tutuyor; D4.1); 6. koşuda tam kit; 10. koşuda dükkânın tamamı **alınamaz** (ECM) → fiyatlar ne düşük ne yüksek. Kötü senaryo (ardışık 3 yakalanma T2'de): kasa 416 → −84 borç → 7. koşu kasa payıyla kapanır; cüzdanlar etkilenmez, kit gecikmesi ≤ 2 koşu. İyi senaryo (hep temiz): T2 3. koşuda, kit 5. koşuda — 1 koşu fark; başarı ilerlemeyi hızlandırır ama başarısızlık kilitlemez.

## 7. Faz 4 kalem taslakları (AC'li; sahipler öneri)

**US-E1 — Economy çekirdeği** (cekirdek + oynanis; KR-018 B: `Economy` düğümü Game'den ayrı, sözleşme S12 adayı). AC1 `data/economy/payout_rules.tres`: aracı tabanı, uyarı eşlemesi, bonus/ceza listesi, 80/20 bölüşüm; formül birim testli (6 örnek: temiz/sıcak/yakalanan/herkes yakalandı/bonuslu/itibarlı). AC2 Host hesaplar, `payout_resolved(summary)` çoğaltılır; 3 peer'da aynı özet (senaryo `payout_sync.json`, 0/150 ms). AC3 Kişisel cüzdan oyuncu profilinde, kasa/itibar/ısı kampanyada (JSON kayıt, Faz 4 kayıt kalemi ile). AC4 Koşu JSON'una (oyun-testi-ve-klip şeması) ödeme ayrıntısı eklenir.

**US-E2 — Isı v0** (oynanis + arayuz). AC1 Kaynak/sönüm tablosu veriden; iş döngüsü −10; "sessiz kal" ve aklama sığınak düğmeleri (host; 3 kişi onayı MVP sonrası). AC2 Mekân eşlemesi `t1_bakkal.tres`/`t2_benzinlik.tres` içinde (`heat_40`, `heat_60` alanları: komşu +1 / devriye sıklığı / polis süresi). AC3 Sığınak ve iş panosunda ısı ölçeri + etki metni (i18n anahtarı); soygun HUD'da yok. AC4 Senaryo: ısı 45 ile T2 koşusunda devriye ≤ 2 dk'da gelir; ısı 0'da 3-4 dk.

**US-E3 — Kefalet ve yakalanma sonucu** (oynanis + arayuz; US-012/US-T2e üstüne). AC1 Kefalet tablosu veriden; kasadan otomatik; borç modeli (§3) ve tavan. AC2 İş sonu ekranı: "kefalet makbuzu" paneli (kim, nerede, ne kadar), yakalananın payı 0, pay dağılımı. AC3 Yakalanan oyuncu bir sonraki lobide tam yetkili; rozet kozmetik; tanınma sayacı +1 (Faz 3 keşif ile). AC4 Birim: herkes yakalandı → ödeme 0, kefalet ×3, ekipman değişmez.

**US-E4 — Dükkân + yetenek kapısı** (arayuz + oynanis; S10). AC1 6 eşya `data/items/*.tres` (id, fiyat, slot, etki = tipli Resource); satın alma host doğrular (cüzdan ≥ fiyat), profile yazılır. AC2 Kapılar: T2 kilit `InteractionRequirement` (maymuncuk kademesi), DVR SİL (deck v0), jammer Gadget; kapısız ekip benzinliği **kapıdan** yine oynayabilir (GDD §7.6 notu: ofis kasası yerine kasa + sigara; ganimet düşer). AC3 Loadout lobide; ödünç set (GDD §7.5) MVP sonrası. AC4 "SATIN AL" 10 (kasa).

**IS-E5 — Ekonomi tablo simülasyonu (D4.1)** (tasarim + altyapi; dosya eklemez, rapor). §6 tablosu hesap tablosuna; IS-015 bot koşularından gerçek sonuç dağılımı; kabul: medyan ekip 4-6. koşuda T2 maymuncuk + deck + 1 gadget; 10 koşuda ECM alınamıyor; kötü senaryoda borç ≤ 2 koşuda kapanır. Geçmezse fiyatlar/kefalet ±%20 ayarlanır.

**US-E6 — İş panosu v0** (arayuz). T1/T2 seçimi, risk 1-3, modifikatör metni, ısı etkisi, itibar, insider v0 tek teklif tipi ("hangi kamera sahte" T2 / "arka oda nakdi nerede" T1; ücret 100/kasa, doğruluk %80), "sessiz kal" düğmesi.

## 8. Riskler ve karar gereken

Riskler: 3 kişiden biri hep yakalanırsa (ağ/yetenek farkı) payı hep 0 → anket "adil mi" düşer; önlem: tutulma kurtarması (ÇEK) ve 2 kişilik oyunda kefalet ×0,5 · beklenen değer varsayımları (temiz %50) bot koşusuyla doğrulanmadan fiyatlar yanlış olabilir → IS-E5 önce · "sessiz kal" turu 3 kişilik oturumda "boş tur" demek → oturumda 1 kez, 20 sn'lik sığınak sahnesi olarak (gerçek bekleme yok).
Karar gereken: (a) Bölüşüm %80 cüzdan / %20 kasa (öneri) mi, GDD'deki gibi oran belirtilmeden host ayarı mı? (b) Kefalet ekip kasasından + borç (öneri) mi, yoksa yakalananın cüzdanından mı (daha "kişisel", daha kırıcı)? (c) Aracı oranı ekip geneli (öneri, MVP) mi, kişi davranışına göre mi (§16 soru 5)? (d) MVP dükkân fiyatları 150-500 bandı (öneri) — GDD §8 "T1 maymuncuk 200" ile uyumlu; ECM 5.000 dükkânda görünür ama alınamaz "hedef" olarak kalsın mı?

## Kaynaklar
[1] Payday 2 offshore/spending oranı (80/20; önceden 95/5) — https://www.co-optimus.com/article/10802/payday-2-succeeds-1-6-million-sales-update-11-goes-live-on-pc.html · https://en.wikipedia.org/wiki/Payday_2
[2] Payday 2 custody/rehine takası ve ön planlama iyilik sınırı — https://steamcommunity.com/app/218620/discussions/8/1698293255121541857 · https://payday.fandom.com/wiki/Bank_Heist · https://payday.fandom.com/wiki/Favors
[3] Payday 3 seviye sistemi eleştirisi — https://www.wepc.com/news/payday-3s-leveling-system-sucks/
[4] Payday 3 infamy/para — https://www.dexerto.com/gaming/payday-3-how-to-level-up-2235183/
[5] Deep Rock Galactic başarısız görev %25 — https://deeprockgalactic.wiki.gg/wiki/Mission
[6] Monaco 2 coin/elmas/trinket — https://entertainium.co/2025/04/monaco-2-review/ · https://www.shacknews.com/article/139427/monaco-2-gdc-2024-preview
[7] PEAK satış ve koşu süresi — https://www.gosugamers.net/entertainment/news/75783-co-op-climbing-indie-hit-peak-sells-one-million-copies-in-just-six-days-on-steam · https://checkpointgaming.net/reviews/2025/06/peak-review-getting-over-it/
[8] PEAK co-op tasarım analizi — https://www.co-optimus.com/blog/article-poster/3381/five-dollars-one-mountain-and-a-masterclass-in-co-op.html
[9] Hades "take the sting out of failure" — https://inlander.com/culture/hades-writer-greg-kasavin-on-how-he-made-video-game-deaths-drive-a-feel-good-story-22725237
[10] Hades ölümün çift kaydı — https://reverseshot.org/features/3477/hades2
[11] Thief Simulator polis/kefalet — https://thief-simulator.fandom.com/wiki/Police
[12] Thief Simulator 2 hapis ve kefalet — https://prodigygamers.com/2023/10/06/thief-simulator-2-get-out-of-jail-exit-key-location-guide/
[13] GTA Online heist lideri ve pay — https://www.sportskeeda.com/gta/how-heists-gta-5 · https://www.videogamer.com/?p=130077
[14] GTA wanted sönümü — https://en.wikigta.org/wiki/Wanted_level · https://www.gfinityesports.com/article/gta-6-wanted-system-explained
