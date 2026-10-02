# Ses ve SFX: gizlilikte ses = oyun bilgisi, Faz 2a listesi, CC0 kaynaklar, kayıt şablonu (tasarım araştırması, 3. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil. Lisans satırları indirme anında yeniden doğrulanır (sayfalar değişebilir).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım. Dayanak: GDD §13 (ses setleri ton başına), §14 (duyulabilirlik oyun bilgisi; alarm/telsiz kademeyi taşır; müzik kademeyle gerilir, tespitte kesilir); mimari S8 (NoiseBus yarıçapları); KR-019 (2a'da 5-6 SFX); yontem.md §5 (okunabilirlik testten önce); okunabilirlik-2d §4 (gürültü halkası). Bakkal tehdit modeli (tezgahtar-sindirme.md, 2026-10-02 yönü): bakkalda alarm/telsiz/polis **yok** → 2a sesleri bağırma ve mahalleli; telsiz/alarm T2+.

## 1. Sesin gizlilikte işlevi: emsaller

| Oyun | Kural [olgu] | Ders [görüş] |
|---|---|---|
| Mark of the Ninja [1][2][3] | Her ses ya dünya kurar ya oyuncuyu bilgilendirir; ses ekranda halka olarak çizilir ve halka yarıçapı **tam olarak** duyulma yarıçapıdır (oyuncular AI'nin neden tepki verdiğini anlamayınca eklendi); muhafızın adımları duyulur, ninjanınki duyulmaz (hiyerarşi); muhafız konuşması uyarı seviyesine göre değişir; müzik üç katman (ortam / arama / tespit), sessizlik bilinçli araç; kaçış sahnelerinde yükselen gerilim. | Halka = yarıçap (zaten okunabilirlik-2d'de); **ses ve halka aynı olaydan** çıkmalı, ikisi birbirini doğrular. Kendi adımın yalnız gürültü yaparken duyulsun (koşu); sızma/yürüme sessiz. NPC durum geçişleri sesle de taşınsın. |
| Thief (1998) [4][5] | Ses yayılımı ve zemine göre adım sesi oyun bilgisidir; oyuncu muhafız adımlarını dinleyerek zamanlar; kapıya yaslanıp dinleme. Ses yönetmeni Eric Brosius. | Muhafız/mahalleli adımları oyuncunun **görmediği** yerden gelebilmeli (duvar arkasından kısık). Faz 2'de yalnız mesafe zayıflatması, oklüzyon yok. |
| Payday 2 müziği [6][7] | Parçalar dört aşamalı: stealth → control (alarm) → anticipation (ilk polis) → assault; aşama uyarı durumuna göre geçer. | Bizim 0-3 merdiveni için 3 katman + tespit kesmesi (§5); bakkalda "assault" yok. |
| Uyarlanır müzik tekniği [8][9] | Dikey katmanlama: aynı tempo/tonda stem'ler, oyun yalnız ses düzeylerini değiştirir; yatay yeniden sıralama: bölümler arası vuruş sınırında geçiş. | Faz 4: dikey 3 stem (pad / nabız / gerilim) + tespit stinger'ı; yatay geçiş gerekmez. |

Kurallar [görüş] (US-009/US-011/US-013 ve SFX kalemi için): (1) Oyun bilgisi taşıyan her olayın sesi **ve** görseli vardır; biri olmadan diğeri çıkmaz (aynı `NoiseBus`/sinyal). (2) Kendi avatarının sesi yalnız gürültü üretirken (koşu, kapı, kasa); sızma/yürüme sessiz (Ninja hiyerarşisi). (3) Dinleyici = yerel oyuncunun avatarı; uzak olaylar mesafeyle kısılır (AudioStreamPlayer2D zayıflatma), ekip görüşü sesi **kısıtlamaz** (görsel halka kısıtlar): duvar arkasından mahalleli adımı duyulur, görülmez. (4) NPC durum geçişleri kısa, sözsüz ya da tek kelimelik ünlemlerle ("Hı?", "Hey!", "Hırsız var!"); uzun diyalog yok. (5) Tespit/yakalanma anı tek net vurgu (stinger) + müzik kesilir (GDD §14). (6) Sessizlik varsayılan: ortam yalnız düşük buzdolabı uğultusu; "kalabalık" yok. (7) Hiçbir bilgi yalnız sesle de verilmez (işitme engeli; okunabilirlik-2d §2).

## 2. Faz 2a olay → ses listesi (bakkal; 5-6 çekirdek + yer tutucu)

| # | Olay (sinyal / NoiseBus) | Ses | Yarıçap / görsel | Kaynak adayı · lisans | Dilim |
|---|---|---|---|---|---|
| 1 | Koşu adımı (oyuncu, her 0,35 sn) | kısa sert adım, 2-3 varyant, rastgele pitch ±%5 | 120 px (S8); halka | Kenney Impact Sounds (CC0) "footstep" dosyaları · OGA "100 CC0 SFX 2" footsteps (CC0) | 2a |
| 2 | Kapı aç / kapa / çarpma | menteşe + çarpma (kapa daha sert) | 160 px; halka | OGA "Platformer sounds…" door_open (CC0) · Kenney Impact "wood" (CC0) | 2a |
| 3 | Kasa boşaltma (tut 3 sn + tamamlandı) | çekmece tıkırtısı (döngü) + "çın" | 90 px; halka tamamlandığında | Kenney Impact "metal" + Interface "confirm" (CC0) | 2a |
| 4 | Bakkal sahibi "?" / sorgu (`clerk_question`, `clerk_interrogate`) | kısa sözsüz "Hı?" / "Hey" | görsel "?"; ses 160 px | Kenney Voiceover Pack (CC0; içerik indirince doğrulanır) ya da kullanıcı kaydı (öz kaynak) | 2a |
| 5 | Bağırış (`clerk_shout`, her 4 sn) | "Hırsız var!" (TR) ya da sözsüz bağırış | 320 px; halka + uyarı 3 pop | Kullanıcı kaydı (TR); yedek: sözsüz bağırış (Freesound CC0 "shout") | 2a |
| 6 | Yakalanma (`captured`) + müzik kesme | tek bas stinger 0,6 sn + "yakadan tutma" hışırtısı | — (HUD) | Kenney Music Jingles (CC0) kısa olumsuz jingle · Kenney Impact "cloth" | 2a |
| 7 | Mahalleli varış / adımları (`neighbor_arrive`) | koşan adım (oyuncudan ağır) + kapı zili | 120 px | #1 kaynakları, pitch −%10; Kenney Interface "bell" | 2a (yer tutucu) |
| 8 | Etkileşim istemi / tamam / host iptali | UI tık / onay / gri sönme sessiz | HUD | Kenney UI Audio / Interface Sounds (CC0) | 2a |
| 9 | Maymuncuk (tut 6 sn) + açıldı | tıkırtı döngü + "klik" | 0 (sessiz) · görsel çubuk | Kenney Impact "metal click" (CC0) | 2b (US-009) |
| 10 | Çanta düşürme / devir | tok düşme + fermuar | 160 px; halka | Kenney Impact "drop" (CC0) | 2b (US-012) |
| 11 | Raf devirme | kutu/şişe yığını | 90 px; halka | OGA "100 CC0 SFX 2" glass/wood (CC0) | 2b |
| 12 | Uyarı kademesi değişimi (HUD) | kademe 1-2: yumuşak tık; 3: kısa gerilim vuruşu; sayaç son 10 sn: tik | HUD | Kenney Interface (CC0) | 2a |
| T2+ | Telsiz cızırtısı, sessiz alarm "klik", kamera dönüş vınlaması, sindirme bağırışı | — | — | OGA "Frequency Static" (CC0; telsiz) · Kenney Sci-fi (CC0) | Faz 4 |

[görüş] 2a'nın "5-6": #1, #2, #3, #4, #5, #6 (+ #8 ücretsiz, UI). Toplam dosya ≈ 15-20; 2 saatlik iş (indir, kes, normalize, `.tres` eşle). Türkçe ses satırları: ya kullanıcı/arkadaş kaydı (öz kaynak, bildirim gerektirmez) ya da yapay zekâ TTS — ikincisi Steam bildirimi gerektirir (yontem.md §4 [20]); öneri **kullanıcı kaydı**, 10 dk telefon kaydı yeter; ton setine göre değişir (KR-005: ses olayları set adıyla).

Teknik dilek (koordinatöre, kod yazmıyorum): `data/audio/<ton>/sound_set.tres` (olay adı → AudioStream + taban ses düzeyi + pitch aralığı); tek `Sfx` düğümü havuzu (8 AudioStreamPlayer2D), olaylar `NoiseBus` görsel halka olayı ve NPC sinyallerinden; ses busları `Master/SFX/UI/Music`, ayarlarda üç kaydırıcı; dosya biçimi OGG Vorbis mono 44,1 kHz, tepe −1 dBFS, SFX ortalama ≈ −18 LUFS (görüş; test edilir); adlandırma `sfx_<olay>_<nn>.ogg`.

## 3. Kaynaklar: yalnız CC0 ya da açıkça ticari kullanıma izinli

| Kaynak | URL | Lisans [olgu] | Ne var | Not |
|---|---|---|---|---|
| Kenney — Impact Sounds | https://kenney.nl/assets/impact-sounds | CC0 | 130 darbe/foley (ahşap, metal, kumaş, adım) | Atıf zorunlu değil, "Kenney.nl" takdir edilir |
| Kenney — Interface Sounds | https://kenney.nl/assets/interface-sounds | CC0 | ~100 UI (tık, onay, zil) | Godot Asset Library'de WAV paketi #796 [10] |
| Kenney — UI Audio | https://kenney.nl/assets/ui-audio | CC0 | 50 UI | |
| Kenney — RPG Audio / Digital Audio / Sci-fi Sounds | https://kenney.nl/assets/rpg-audio · …/digital-audio · …/sci-fi-sounds | CC0 | kapı, kilit, para; dijital/telsiz benzeri | Sci-fi: T2 kamera/telsiz |
| Kenney — Voiceover Pack / Music Jingles | https://kenney.nl/assets/voiceover-pack · …/music-jingles | CC0 | İngilizce kısa ünlem/kelime; kısa jingle'lar | Ünlemlerin "Hey/Stop" içerip içermediği indirince doğrulanır |
| OpenGameArt — 100 CC0 SFX #2 (rubberduck, 2018) | https://opengameart.org/content/100-cc0-sfx-2 | CC0 | kapı, adım, cam, darbe, metal, anahtar, sokak ortamı | |
| OpenGameArt — CC0 Sounds Library (ETTiNGRiNDER) | https://opengameart.org/content/cc0-sounds-library | CC0 | 52 alt paket: adım (yüzeyler), alarm, UI, günlük nesneler, kalp atışı | |
| OpenGameArt — Platformer sounds (yd) | https://opengameart.org/content/platformer-sounds-terminal-interaction-door-shots-bang-and-footsteps | CC0 | door_open, çeşitli adımlar | |
| OpenGameArt — Frequency Static | https://opengameart.org/content/frequency-static-sound-effects | CC0 | telsiz/TV paraziti | T2 telsiz |
| Freesound (CC0 süzgeci) | https://freesound.org/search/?q=shout&f=license%3A%22Creative+Commons+0%22 | sese göre CC0 / CC BY / CC BY-NC [11] | her şey | **Yalnız CC0 süzgeciyle**; CC BY atıf ister, BY-NC yasak. Her dosyanın kendi lisans satırı kayda girer |
| Sonniss GDC Game Audio Bundle (2015-2026) | https://sonniss.com/gameaudiogdc | Royalty-free, ticari, atıfsız; yapay zekâ eğitimi ve "kendi malın gibi satma" yasak [12][13] | 10-30 GB profesyonel | CC0 **değil**; paket içindeki License.pdf okunur ve kopyası kayda eklenir; dosyalar depoya değil, yalnız kullanılan kesitler |

Kaçınılacaklar [görüş]: "royalty-free" yazan ama lisans metni olmayan siteler; YouTube/ses kütüphanesi (Steam'de dağıtım hakkı belirsiz); CC BY-NC; CC BY-SA (oyun ikili dosyasında paylaşım şartı belirsiz); yapay zekâ üretimi ses (Steam bildirimi + sektör algısı, yontem.md §4) — kullanılırsa kayıt şart.

## 4. `docs/notes/assetler.md` kayıt şablonu (dosya henüz yok; Faz 2a SFX kalemiyle açılır)

```
# Dış varlıklar ve lisanslar
Kural: oyuna giren her dış dosya burada bir satırdır; lisans metninin kopyası assets/licenses/<kaynak>.txt; satırsız dosya CI'da hata (tarama testi adayı).
| id | dosya | olay / kullanım | kaynak URL | yazar | lisans | indirme tarihi | atıf metni (gerekirse) | değişiklik (kesme/pitch/mix) | AI üretimi mi (araç, tarih) | Steam bildirimi |
| sfx_run_01 | assets/sfx/sfx_run_01.ogg | koşu adımı | https://kenney.nl/assets/impact-sounds | Kenney | CC0 | 2026-10-0x | — | 0,2 sn kesit, −3 dB | hayır | hayır |
| vo_shout_tr_01 | assets/vo/tr/vo_shout_01.ogg | clerk_shout | (kendi kaydımız) | <kullanıcı> | öz kaynak | … | — | gürültü temizliği | hayır | hayır |
Bölümler: SFX · Ses satırları (ton başına) · Müzik · Yazı tipi · İkon (CC-BY ikon seti: atıf metni zorunlu) · Yapay zekâ üretimi (ayrı liste; Faz 5 Steam bildirimi buradan yazılır).
```

[görüş] Faz 4 CC0 görsel geçişi (KR-012) aynı tabloyu kullanır; ikon seti CC-BY ise "atıf metni" sütunu Faz 5 kredilerine kopyalanır.

## 5. Müzik gerilim katmanları (Faz 4 için kısa)

- [görüş] Dikey katmanlama [8][9]: tek parça, 3 stem aynı tempoda: **A pad** (kademe 0, hep çalar, çok kısık), **B nabız** (kademe 1-2: perküsyon/bas girer), **C gerilim** (kademe 3: yüksek tel/sentez + sayaç son 10 sn'de tempo hissi); stem geçişleri 1-2 sn fade, vuruş sınırı gerekmez. Tespit/yakalanma: müzik 0,3 sn'de kesilir, stinger, 4 sn sessizlik (Ninja "sessizlik araçtır"), sonra A döner (iş sürüyorsa). Kaçış bölgesine giriş: kısa olumlu jingle.
- Bakkalda "assault" katmanı yok; T3+ (silah çekme) için D katmanı Faz 6.
- Kaynak: Kenney Music Jingles (CC0, kısa); uzun döngü için Freesound CC0 "ambient loop" ya da ücretli CC0 olmayan paket (karar kullanıcıda; ücretli = KR). Ton setine bağlı (noir: caz fırçası + kontrbas; ikinci ton MVP sonrası).
- Kabul (Faz 4 kalemi): katman ses düzeyi yalnız `alert_level_changed`'den; tespitte kesme ≤ 0,3 sn; ayarlarda müzik kaydırıcısı; headless birim test sinyal→katman eşlemesi.

## 6. 2a SFX kalemi için kabul kriteri önerisi

(1) `data/audio/noir/sound_set.tres` §2 #1-#6, #8, #12 olaylarını eşler; eksik olay sessiz ve `push_warning` (hata değil). (2) Her ses olayı görsel karşılığıyla aynı sinyalden tetiklenir (NoiseBus halka olayı / NPC durum sinyali / HUD kademe); birim test: sahte sinyal → doğru olay adı. (3) Dinleyici yerel avatar; ≥ 2 × yarıçap uzaklıkta duyulmaz; sızma/yürüme adımı yok. (4) `assetler.md` açılır, her dosya satırlı; `assets/licenses/` kopyaları; tarama testi: `assets/` altındaki her ses dosyası tabloda. (5) Ses düzeyi ayarı üç bus; hareket azaltma seçeneği sesi etkilemez. (6) Kullanıcı 10 dk oynayıp "koşu adımımı duyuyorum, mahalleliyi görmeden duyuyorum, bağırışı anlıyorum" üç cümlesini doğrular (IS-017 öncesi).

Karar gereken: (a) Türkçe ses satırları kullanıcı kaydı mı (öneri), sözsüz ünlem mi, TTS mi (bildirim)? (b) Sonniss paketleri kullanılacak mı (CC0 değil, lisans dosyası saklanır)? Öneri: 2a'da yalnız Kenney/OGA CC0; Sonniss Faz 4. (c) assetler.md'yi şimdi açmak (KR-012 "Faz 4'te açılır" diyor) — öneri 2a'da açılsın.

## Kaynaklar
[1] Designing Sound, "The Dynamics of Mark of the Ninja" — https://designingsound.org/2013/06/the-dynamics-of-mark-of-the-ninja
[2] Game Informer, "Afterwords: Mark of the Ninja" (halka = yarıçap kararı) — https://gameinformer.com/b/features/archive/2012/10/15/afterwords-mark-of-the-ninja
[3] Mark of the Ninja incelemesi (ses halkaları) — https://www.giantbomb.com/mark-of-the-ninja/3030-37615/user-reviews/2200-24070/
[4] PC Gamer, "The Sound of Silence" (Thief sesi) — https://www.pressreader.com/usa/pc-gamer-us/20181204/282389810507668
[5] Thief gizlilik sistemi (ışık taşı + ses) — https://www.gamedeveloper.com/design/building-the-original-i-thief-s-i-revolutionary-stealth-system
[6] Payday 2 müziği dört aşama — https://www.superjumpmagazine.com/payday-2-so-much-more-than-heists/
[7] Simon Viklund — https://en.wikipedia.org/wiki/Simon_Viklund
[8] Uyarlanır müzik rehberi — https://bugnet.io/blog/adaptive-music-a-beginners-guide
[9] Audiokinetic, interaktif müzikle sahne skorlama — https://blog.audiokinetic.com/how-to-use-interactive-music-to-score-gameplay/
[10] Godot Asset Library: Kenney UI Audio — https://godotengine.org/asset-library/asset/796
[11] Freesound SSS (lisanslar, süzgeç) — https://freesound.org/help/faq/
[12] Sonniss GDC 2026 paketi — https://rekkerd.org/sonniss-releases-gdc-2026-game-audio-bundle/
[13] Sonniss lisans özeti (atıfsız ticari, AI eğitimi yasak) — https://gamefromscratch.com/sonniss-27-5gb-sound-effect-giveaway-at-gdc-2024/
[14] Steam yapay zekâ bildirimi (2026-01) — https://www.videogameschronicle.com/news/valve-has-significantly-rewritten-steams-rules-for-how-developers-much-disclose-ai-use
