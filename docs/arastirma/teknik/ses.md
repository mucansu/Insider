# Ses: Godot 4 ses mimarisi ve üretilmiş ses hattı (teknik araştırma)

İşaretler: **[O]** olgu (kaynakta yazıyor / kodda var) · **[G]** görüş/çıkarım · **[?]** belirsiz, doğrulanmadı. Sürümler kaynağıyla; Godot 4.7.2 (KR-007) esas alındı.

---

## Tur 1 — 2026-10-02

### Kapsam
Godot 4 ses veri yolu düzeni (bus, efekt, ducking), AudioStreamPlayer2D ayarları (üstten 2D), ses sayısı/öncelik, AudioStreamRandomizer, katmanlı müzik (AudioStreamInteractive/Synchronized), ucuz duvar arkası örtme (occlusion), ağda ses olaylarının senkronu, headless test, AI ses üretim hattı (araç, lisans, Steam beyanı, kalite kontrol, Türkçe ses satırları için TTS ↔ kullanıcı kaydı), dosya biçimi/boyutu, FMOD/Wwise uygunluğu. Tasarım dayanağı: GDD §14 (duyulabilirlik oyun bilgisi; alarm/telsiz kademeyi taşır; müzik kademeyle gerilir, tespitte kesilir), `docs/tasarim/arastirma/ses-ve-sfx.md` (7 kural, olay tablosu, §5 müzik katmanları, §6 kabul önerisi), `oyun-hissi.md` §2 (olay → ses anahtarı), mimari S8/S11 (NoiseBus ve Hearing: oyun gürültüsü ses değildir), KR-020 (önce aramızda MVP; AI üretimi içerik serbest, kayıtlı), IS-024/IS-030.

### Mevcut durum (dosya:satır)
IS-024 henüz commit'siz, worktree `.claude/worktrees/agent-a7f9b86f90c83f2c1` (faz2-int üstünde; US-006/US-013 birleşik). Aşağıdaki yollar o worktree'ye göredir.

| Parça | Nerede | Ne yapıyor |
|---|---|---|
| Katalog girdisi | `data/sfx_entry.gd:9-23` | `event, stream, volume_db, pitch_min/max, min_interval (0,08), max_distance (0 = çaların kendi), placeholder`. **Bus alanı yok.** |
| Katalog | `data/sfx_catalog.gd:19-64`, `data/sfx_catalog.tres` | 14 olay (door_open/close, register_tick/done, ui_click/focus, alert_step/high, stinger_success/caught, clerk_question/interrogate/shout, run_step). `take()` eksik olayı sessiz + süreçte bir `push_warning`; en kısa aralık kontrolü. Konumlu olaylarda `max_distance` = S8 yarıçapı × 2 (320/180/240/640). |
| Konumlu çalar | `entities/fx/sfx_emitter.gd:1-82` | `SfxEmitter extends AudioStreamPlayer2D`; sahibin `Sfx` alt düğümü; `of/play_on/play_event/repeat_while`. Her çalışta `stream`, `volume_db`, `pitch_scale`, `max_distance` atanır, `play()`. `max_polyphony` varsayılan 1, `attenuation` varsayılan 1,0, `bus` Master. |
| Arayüz çaları | `ui/ui_sfx.gd:1-68` | `UiSfx extends AudioStreamPlayer`; `wire_buttons()` her `BaseButton`'a focus→ui_focus, pressed→ui_click. |
| Bağlamalar | `entities/props/door.gd:118`, `register.gd:34,68`, `ui/alert_ladder.gd:103`, `ui/heist_end.gd:53,102`, `ui/main_menu.gd:53`, `ui/pause_menu.gd:16` | Ses çoğaltılan durum değişiminden (`is_open`, `busy_by/progress`, `emptied`, kademe) her peer'da yerel çalar; ağa ses gitmez. [O] Doğru kalıp. |
| Testler | `tests/unit/test_sfx.gd`, `test_ui_sfx.gd`, `test_assets_registry.gd` | Her olayın `.ogg` dosyası var, döngü kapalı, süre 0-3 sn, `max_distance` = 2× yarıçap, FakeClock ile aralık, headless'ta hata/uyarı yok; `assets/` ↔ `assetler.md` tutarlılığı. |
| Varlıklar | `assets/sfx/*.ogg` (14), `assets/licenses/kenney_*.txt`, `docs/notes/assetler.md` | Hepsi Kenney CC0, `placeholder = true`. Dosya ölçümü (kendi okumam): **8/14 stereo**, 3'ü 48 kHz (door_open/close, register_tick), nominal 160 kbps; ui_click 0,01 sn, ui_focus 0,02 sn; toplam ≈ 150 KB. |
| Proje ayarları | `project.godot` | `[audio]` bölümü yok → yalnız `Master` busı; `default_bus_layout.tres` yok; `2d_panning_strength` varsayılan 0,5; `mix_rate` 44100; ses düzeyi ayarı/kaydırıcı yok. |
| Dinleyici | `entities/player/player.gd:89` (`Camera2D.make_current`) | `AudioListener2D` yok → dinleyici **ekran merkezi** (= kamera merkezi). Kamera dili (oyun-hissi §4) look-ahead ile merkezi avatardan 80 px'e kadar kaydıracak. |
| Oyun gürültüsü | faz2-int `autoload/noise.gd` (US-009), `entities/fx/noise_ring.tscn` | Host yetkili yayılım + görsel halka (`noise_shown`, güvenilmez RPC). Ses ile ilgisi yok; ses çoğaltılan durumdan çalıyor (yukarıda). |

### En iyi uygulamalar ve seçenekler

#### 1. Bus düzeni ve ayar kaydırıcıları
- **Ne:** `res://default_bus_layout.tres` (proje ayarı `audio/buses/default_bus_layout`) içinde `Master ← Music, SFX (← SFX_World, SFX_Muffled), Voice, UI, Ambience`. Çalarlar `bus` özelliğiyle yönlenir; olmayan bus adı Master'a düşer [O docs AudioStreamPlayer2D]. Ses düzeyi `AudioServer.set_bus_volume_linear(get_bus_index("SFX"), v)` [O docs AudioServer]; sessiz kalan bus 2 sn sonra efektleriyle devre dışı kalır (`channel_disable_time`), yani boş bus ucuzdur [O docs Audio buses / ProjectSettings].
- **Artı:** Ayarlarda üç kaydırıcı (ses-ve-sfx §6 AC5) doğrudan; müzik/VO/örtme efektleri bus düzeyinde, dosyaya gömülmez (Godot öneri: reverb vb. gerçek zamanlı bus efektiyle, dosya küçülür [O docs Importing audio]). **Eksi:** Katalog girdisine `bus` alanı eklenmeli; `UiSfx` ve `SfxEmitter` bus atamalı.
- **Kaynak:** [1][2][3].

#### 2. Ducking / sidechain
- **Ne:** `AudioEffectCompressor.sidechain = "Voice"` efekti Music busına konur; Voice busında ses geçince Music kısılır (eşik 0 dB, oran 4, atak 20 µs, bırakma 250 ms varsayılan) [O docs AudioEffectCompressor]. Alternatif: olay güdümlü bus ses düzeyi tween'i (ör. `alert_level_changed` / tespit sinyalinde Music −∞ dB'ye 0,3 sn).
- **Artı/eksi:** Sidechain sinyal düzeyine bağlı, tasarım belgesindeki "tespitte müzik ≤ 0,3 sn'de kesilir, 4 sn sessizlik, A döner" (ses-ve-sfx §5) olay güdümlüdür ve headless birim testle doğrulanabilir; sidechain testle doğrulanamaz (dummy sürücüde dinleyemeyiz). [G] Bizde: **olay güdümlü tween** ana yol, sidechain yalnız VO (bağırış) sırasında müziği hafif kısmak için isteğe bağlı.
- **Kaynak:** [4].

#### 3. AudioStreamPlayer2D: mesafe, zayıflama, panning (üstten 2D)
- **Formül [O kaynak kod 4.7 `audio_stream_player_2d.cpp`]:** çarpan = `pow(1 − d/max_distance, attenuation) × db_to_linear(volume_db)`; `d > max_distance` ise o görünüme katkı **0** ama çalma sürer (ses kanalı tüketir). Panning: dinleyiciye göre ekran x farkı / ekran genişliği, [−1,1]'e kırpılır, × `panning_strength × audio/general/2d_panning_strength (0,5) × 0,5` + 0,5 → `l = 1 − pan, r = pan`. Varsayılanlarla ekran kenarındaki ses en fazla 0,75/0,25 dağılır. Güncelleme çalarken **fizik karesinde** (her kare değil).
- **Dinleyici [O docs AudioListener2D]:** `AudioListener2D` yoksa ekran merkezi. Kamera look-ahead (oyun-hissi §4, 80 px'e kadar) gelince ekran merkezi ≠ avatar; "dinleyici = yerel avatar" kuralı (ses-ve-sfx §1 kural 3) için yerel oyuncuya `AudioListener2D` + `make_current()` (yalnız yerel kopyada) gerekir.
- **Yarıçap ↔ duyulma [G]:** `max_distance = 2 × yarıçap` ve `attenuation = 1,0` ile yarıçapta ses %50 (−6 dB) — "halka sınırı = belirgin kısılma" hissi zayıf. `attenuation = 2,0` → yarıçapta −12 dB, 2×'te sıfır: halka içi net, dışı fısıltı. Kulakla ayar; başlangıç 1,5-2,0.
- **Stereo dosya [O kaynak kod + G]:** 2D çalar sol/sağ kazancı dosyanın kendi kanallarına uygular; stereo "genişlik" konum panningiyle çelişir. Konumlu sesler **mono** olmalı (import "force mono" ya da dosyada mono). Bugün 8/14 dosya stereo.
- **Panning gücü [G]:** üstten, kamera merkezli oyunda `2d_panning_strength` 0,75-1,0 (kenarda tam sol/sağ) denenebilir; başta 0,75, hareket hastalığı/okunurluk testinde geri çekilir.
- **Kaynak:** [5][6][7][3].

#### 4. Ses sayısı, polifoni, öncelik
- **[O kaynak kod `audio_stream_player_internal.cpp`]:** `set_stream()` çalanların **hepsini durdurur**; `max_polyphony` dolunca **en eski** kesilir; `pitch_scale` tüm aktif çalmalara uygulanır. Bu yüzden `SfxEmitter` tek-kanallı: aynı sahipten art arda iki farklı olay (kapı aç → 0,1 sn sonra kapa; oyuncuda koşu adımı + çanta hışırtısı; mahallelide adım + zil) birbirini keser.
- **Seçenek A — `AudioStreamPolyphonic` [O docs 4.7]:** tek `AudioStreamPlayer2D`'ye `AudioStreamPolyphonic` atanır; `get_stream_playback().play_stream(stream, 0, volume_db, pitch_scale, playback_type, bus)` her çağrıda yeni kanal, `polyphony` ile sahibe tavan (ör. 4); `stop_stream/set_stream_volume` kimlikle. Çalar pozisyonu ortak (sahip = konum) — bizim modelde yeterli. **Artı:** tek düğüm, bus akışa göre; **eksi:** `finished` sinyali kanal başına yok (`is_stream_playing` ile sorgu).
- **Seçenek B — küçük havuz:** sahip başına 2-3 `AudioStreamPlayer2D`. Daha çok düğüm, ağ dökümünde gürültü.
- **Küresel bütçe [G]:** motorda toplam kanal tavanı yok; maliyet OGG çözme × kanal. 3 oyuncu + ~10 NPC + prop'lar için 32 eşzamanlı kanal çok rahat. Ucuz öncelik: `play_event` öncesi yerel dinleyiciye uzaklık > `max_distance` ise **hiç başlatma** (kanal tüketmez; 2D çalar bunu kendisi yapmıyor); sahnede ≤ 4 halka kuralı (oyun-hissi §1 kural 5) sesi de kapsar.
- **Kaynak:** [8][9].

#### 5. AudioStreamRandomizer (varyant)
- **[O docs]:** stream havuzu + ağırlık, `PLAYBACK_RANDOM_NO_REPEATS`, `random_pitch` (çarpan) / `random_pitch_semitones`, `random_volume_offset_db`. Katalog girdisinin `stream`'i bir Randomizer `.tres` olabilir → `SfxEmitter` kodu değişmez; `SfxEntry.pitch_min/max` tek dosyalı girdiler için kalır (ikisi üst üste binmesin: Randomizer'lı girdide `pitch_min = pitch_max = 1`).
- **Artı:** adım/çekmece/kapı için 2-3 varyant bıkkınlığı keser; AI üretiminde "4 aday üret, 2-3'ünü varyant yap" hattına doğal uyar. **Eksi:** test "her girdinin stream'i `assets/sfx/*.ogg`" varsayıyor (`test_sfx.gd:76`); Randomizer için `resource_path` `.tres` olur, test alt stream'leri gezmeli.
- **Kaynak:** [10].

#### 6. Dinamik / katmanlı müzik (Godot 4.3+)
- **[O release 4.3, docs]:** `AudioStreamSynchronized` (≤ 32 alt stream, hepsi senkron başlar, `set_sync_stream_volume(idx, db)` çalışırken değişir) = **dikey katmanlama** (ses-ve-sfx §5: A pad / B nabız / C gerilim). `AudioStreamInteractive` = **yatay geçiş** (klip, geçiş zamanı anında/sonraki vuruş/bar/klip sonu, cross-fade, dolgu klip; OGG import'taki `bpm/beat_count/bar_beats` meta verisiyle vuruş senkronu). `AudioStreamPlaylist` sıralı/karışık.
- **Bize uygunluk [G]:** bakkalda yalnız dikey (3 stem) + stinger; Synchronized tek `AudioStreamPlayer` (bus Music) yeter, geçiş 1-2 sn tween (bus değil stem düzeyi). Interactive gerekmiyor (yatay geçiş yok). Kademe→stem eşlemesi düğümsüz `core/music_rules.gd` (girdi: kademe, tespit; çıktı: stem dB dizisi) headless test edilir; çalar yalnız uygular.
- **Kaynak:** [11][12][13].

#### 7. Duvar arkası örtme (occlusion) — ucuz yöntemler
- **A. İki bus + ışın [G, yaygın kalıp]:** `SFX_World` (temiz) ve `SFX_Muffled` (`AudioEffectLowPassFilter` ~900-1200 Hz + −6 dB). Çalar `play_event` anında (kısa ses) ya da döngü sesinde 5 Hz'de yerel dinleyici → kaynak ışını (katman `world` + `vision_block`; `see_through` gövdeler geçer — S11 Hearing kuralının **yerel, kozmetik** ikizi) atar; kesilirse `bus = "SFX_Muffled"`. Maliyet: olay başına 1 ışın. Polyphonic'te bus kanal başına verilir [O docs play_stream bus parametresi].
- **B. Area2D bus override [O docs Area2D]:** `audio_bus_override + audio_bus_name` ve çaların `area_mask`; "arka oda" gibi odalar için ikili. Eksi: kaynağın odasına bakar, dinleyicinin değil; bakkalda iki oda (dükkân/arka oda) için bile ışın daha doğru.
- **C. Kanal başına filtre:** Godot'ta yok; filtre yalnız bus'ta. (3D'de occlusion eklentileri de aynı ışın + lowpass kalıbı [O asset library].)
- **Kural [G]:** KR-022 "halkalar duvar arkasından görünür" → ses de **kısılır, susmaz**; oyun gürültüsü (host Hearing ×0,5) ile kozmetik örtme ayrı kalır (S8/S11'e dokunmaz).
- **Kaynak:** [14][15][16].

#### 8. Ağda ses olaylarının senkronu
- **İlke [O proje kalıbı + G]:** ses ağa gitmez; her peer **çoğaltılan durum değişimi**nde (S3/S7 sinyalleri, synchronizer alanları, NPC özet durumu) yerel çalar. IS-024 bunu yapıyor. Sınıflama (oyun-hissi §3 A/O): yerel oyuncunun koşu adımı **A** (yerel kadans; aynı zamanlayıcı `NoiseBus.emit_noise` çağrısını da yapar → "ses + halka aynı olay"); uzak oyuncunun adımı kuklanın ara değerlenmiş kipinden/kadansından (görsel ile tam senkron, tampon 100 ms), halka olayından **değil** (halka güvenilmez RPC, konumu host'tan; kayıpta adım sesi atlamaz).
- **Stinger/kademe:** yalnız güvenilir S3 sinyallerinden (`alert_level_changed`, `heist_finished`, tutulma/yakalanma) — zaten öyle (alert_ladder, heist_end).
- **Riskler [?]:** (1) Geç katılan istemcide prop'un ilk eşitleme paketi `is_node_ready()` sonrası gelir → `door.gd:118` kapı açıksa katılırken `door_open`, kasa boşsa `register_done` **çalabilir** (başlangıç durumu değil, değişim sayılır). (2) `register.gd:34` `repeat_while` tik sesi istemcide `progress` eşitlemesine bağlı: 20 Hz'de `progress_ratio() > 0` aralıklı gelir, ritim `min_interval` 0,35 ile sabit — tamam; ama host iptalinde `busy_by = 0` gelene kadar ≤ 1 tik fazla. Kabul edilebilir.
- **Kaynak:** mimari S2/S3/S7, oyun-hissi §3.

#### 9. Headless test
- **[O docs CLI + kaynak kod 4.7 `audio_driver_dummy.*`]:** `--headless` = `--display-driver headless --audio-driver Dummy`. Dummy sürücü `use_threads = true`, 4096 kare tampon, mix_rate proje ayarından (44100 → ~93 ms'de bir `audio_server_process`) → çalma ilerler, `finished` yayılır. "Çıkış aygıtı yokken `finished` gelmiyor" hatası (#71640) 4.3'te kapandı (PR #87010) [O]. Yani IS-024'ün headless "çal, hata/uyarı yok" testi geçerli; `finished`'e dayanan test de yazılabilir (dummy zamanlaması ±100 ms, beklemeyle).
- **Ne test edilir [G]:** olay eşlemesi (sinyal → katalog anahtarı), aralık/polifoni/bus seçimi, uzaklık kapısı (başlatma/başlatmama), müzik kuralı (kademe → stem dB), ışın örtme kararı (gerçek fizik ışınıyla, US-009 bileşen testi gibi), varlık kaydı. Ses çıkışının kendisi test edilmez; mikser değerleri okunabilir (`AudioServer.get_bus_volume_db`).
- **Kaynak:** [17][18][19].

#### 10. AI ile ses üretim hattı (IS-030)
Araçlar ve lisans (indirme/üretim anında yeniden doğrulanır; sayfalar değişiyor):

| Araç | Tür | Lisans / ticari kullanım [O] | Teknik | Not |
|---|---|---|---|---|
| ElevenLabs Sound Effects | bulut, metin→SFX | Ücretsiz plan: ticari kullanımda "elevenlabs.io" atfı zorunlu; ücretli planlar: atıfsız ticari; çıktı kullanıcıya ait; rekabet ürünü geliştirme yasak | 0,1-30 sn, döngü desteği, WAV 48 kHz (döngüsüz) / MP3; 40 kredi/sn; prompt influence | Kısa vuruş/UI/adım tipi tek sesler güçlü [G, karşılaştırma yazıları] |
| Stable Audio 2.5 (API/web) | bulut | Web ücretsiz katman **ticari değil**; Pro ($12/ay) ticari; API ürün koşulları | 3 dk'ya kadar, stereo | Doku/ambiyans güçlü |
| Stable Audio Open 1.0 / Open Small | yerel ağırlık | Stability AI Community License: yıllık gelir < 1 M$ ticari serbest; "Powered by Stability AI" notu + lisans kopyası; çıktı kullanıcıya ait | 47 sn, 44,1 kHz stereo, GPU önerilir (1B parametre) | Eğitim verisi Freesound CC0/CC-BY + FMA; SFX'te müzikten iyi; sesli konuşma üretemez |
| Meta AudioCraft / AudioGen | yerel ağırlık | Kod MIT, **ağırlıklar CC-BY-NC** → ticari oyun için **kullanılmaz** | — | Eleniyor |

- **Steam beyanı [O]:** Ocak 2026 yeniden yazımı: yalnız oyuncunun tükettiği içerik beyan edilir — ön-üretilmiş (oyunla gelen; "artwork, sound, narrative, localization" sayılıyor) ve canlı üretilen; geliştirme araçları (kod yardımcısı vb.) muaf. Bizde: üretilmiş SFX/VO = ön-üretilmiş → beyan; `assetler.md` "Yapay zekâ üretimi" listesi Faz 5 anketinin kaynağı (yontem.md §4 ile uyumlu).
- **Kalite kontrol hattı [G] (`tools/sfx_prep.py` adayı; ffmpeg/sox):** (1) aynı "stil son eki" ile iste ("close-mic, dry, no reverb, no music, small Turkish corner shop, 1990s, quiet") — tutarlılık; (2) olay başına 4-6 aday, 2-3'ü varyant (Randomizer); (3) kırp (sessizlik ≤ 5 ms baş, 10 ms fade-out), **mono**ya indir (konumlu), 44,1 kHz 16-bit; (4) düzey: tepe −1 dBTP, kategori hedefleri (dünya SFX −18 LUFS-S, UI −22, VO −16, stinger −14; başlangıç, kulakla) — oyun bütünü için ASWG-R001 −24 LUFS ±2 / −1 dBTP referans [O]; (5) reverb/oda bus'ta, dosyada değil; (6) kayıt: dosya, araç, tarih, istem özeti, tohum, Steam beyanı; (7) kabul: ton testi (noir: oyuncak gibi duran "confirm" çıkar — oyun-hissi R5).
- **Türkçe ses satırları (bakkal sahibi "Hı?", "Hey!", "Hırsız var!"; mahalleli) — seçenekler:**

| Seçenek | Lisans/beyan [O] | Kalite/tutarlılık [G] | Maliyet |
|---|---|---|---|
| Kullanıcı/arkadaş kaydı (öz kaynak) | Beyan yok; öz kaynak | Tek ses, tona en uyumlu, duygu doğal; gürültü temizliği gerekir (telefon 10 dk) | ~1 saat |
| ElevenLabs TTS (Multilingual v2 / Flash v2.5 / v3 / v4: Türkçe var) | Ücretli plan ticari; beyan **evet** | Çok ifadeli (v4 oyun diyaloğu için öneriliyor); sesler arası tutarlılık iyi; klonlama için rıza şart | $5-22/ay |
| Azure AI Speech (tr-TR Ahmet/Emel Neural) | Ücretli abonelikle ticari; Responsible AI; beyan evet | Nötr, "spiker" tınısı; bağırış zayıf | kredi başı |
| Chatterbox Multilingual (Resemble, MIT; Türkçe var) | MIT, ticari serbest; çıktı PerTh filigranlı; beyan evet | Duygu abartı kontrolü; yerel GPU | ücretsiz |
| Piper (MIT motor; tr_TR dfki/fahrettin/fettah) | **dfki veri seti CC BY-NC-SA → ticari değil**; fahrettin/fettah lisansı [?] (model kartı alınamadı) | Robotik | ücretsiz |

  [G] Bakkal (5-8 satır, tek karakter): **kullanıcı kaydı**; çeşitlilik gerekince (mahalleli, müşteri, T2 telsiz) ElevenLabs ya da Chatterbox + beyan. Piper yayına girmez.
- **Kaynak:** [20]-[31].

#### 11. Dosya biçimi, boyut, döngü
- **[O docs Importing audio samples (4.7)]:** WAV = kısa, tekrarlayan SFX (en düşük CPU, yüzlerce kanal; disk büyük); OGG Vorbis = müzik, konuşma, uzun SFX (küçük, CPU yüksek); MP3 = CPU kısıtlı web/mobil. WAV import: PCM/IMA-ADPCM/QOA sıkıştırma, döngü kipleri + nokta (`loop_begin/end`), force mono/8-bit/max rate, normalize, trim. OGG/MP3: `loop` + `loop_offset`, `bpm/beat_count/bar_beats`. 48 kHz üstü yararsız; VO 22 kHz mono yeterli; 24-bit gereksiz.
- **Bize [G]:** < 1 sn SFX için **WAV 16-bit mono 44,1 kHz** (çözme sıfır, döngü noktası hassas; 14 dosya ≈ 1 MB), VO/ambiyans/müzik **OGG** (q 5-6, mono VO 22-44 kHz). `test_sfx.gd:76` `.ogg` şartı `.wav|.ogg`'a genişler. Mix rate 44100 ile 48 kHz dosyalar yeniden örneklenir — kaynakta 44,1'e indirmek daha temiz. Boyut bütçesi: Faz 4 sonu ≤ 30 MB ses (OGG müzik 3 stem × 2 dk ≈ 6-8 MB).
- **Kaynak:** [2][3].

#### 12. FMOD / Wwise
- **[O arama/kaynak sayfaları]:** FMOD Indie: geliştirme bütçesi < 600 k$ ücretsiz, 12 ayda 1 oyun, FMOD logosu zorunlu (feragat ücretli); Godot entegrasyonları **topluluk** GDExtension'ları (utopia-rise `fmod-gdextension`, alessandrofama `fmod-for-godot`); resmî FMOD-Godot sayfası doğrulanamadı [?]. Wwise Indie: bütçe < 250 k$ ücretsiz, ses sınırı yok [O arama; pricing sayfası 403]; Godot entegrasyonu alessandrofama `wwise-godot-integration` (Win/mac/Linux/Android/iOS, Web deneysel), Audiokinetic tarafından resmî değil.
- **Bize [G]:** **Uygun değil.** Gerekçe: KR-020 (aramızda MVP), mimari §6 "çatı yok", tek kişi + ajanlar (ikinci araç ve platform başına yerel ikili, CI/headless'ta ek kurulum, export'ta eklenti), ihtiyaç listemizin tamamı (bus, sidechain, Synchronized katmanlama, Randomizer, Polyphonic, lowpass) Godot yerleşik. Yeniden değerlendirme koşulu: ses tasarımcısı katılır ya da T5+ müzik yatay geçişleri Interactive'i aşar.
- **Kaynak:** [32]-[36].

### Bizim yapımıza uygunluk değerlendirmesi
| Konu | Seçim | Neden |
|---|---|---|
| Bus | 6 bus `.tres`, katalogda `bus` alanı, ayarlarda 3 kaydırıcı (Master/Music/SFX; UI SFX'e bağlı, Voice SFX'e bağlı) | ses-ve-sfx §6 AC5; sıfır bağımlılık |
| Dinleyici | Yerel oyuncuda `AudioListener2D` | kural 3 + kamera look-ahead |
| Çalar | Prop: mevcut `SfxEmitter`; oyuncu/NPC: `AudioStreamPolyphonic` (tavan 4) | kesme sorunu yalnız çok-olaylı sahiplerde |
| Varyant | Randomizer `.tres`, kod aynı | AI hattıyla uyum |
| Müzik | Synchronized 3 stem + ayrı stinger çaları; kural `core/` | headless test, §5 |
| Örtme | 2 bus + ışın, 5 Hz | ucuz, kozmetik, S8/S11'den ayrı |
| Üretim | ElevenLabs SFX (ücretli, atıfsız) ana; Stable Audio Open yerel yedek; VO kullanıcı kaydı | lisans net, beyan kayıtlı |
| Middleware | yok | §6, KR-020 |

### Bulgular
**Doğru yaptıklarımız [O]**
- Ses çoğaltılan durumdan her peer'da yerel çalıyor; ağa ses gitmiyor; stinger/kademe güvenilir sinyalden.
- Olay adıyla katalog (S10 kalıbı), eksik olay sessiz + tek uyarı, `placeholder` işareti ve `assetler.md` + kayıt testi: IS-030 değişimi kodsuz.
- Aralık (`min_interval`) ve tekrar (`repeat_while`) FakeClock ile test edilmiş; headless çalma hata vermiyor (dummy sürücü gerçekten mikser çalıştırıyor, bu doğrulandı).
- UI sesi konumsuz ayrı çalarda; "hiçbir bilgi yalnız sesle" (alert_ladder sesi hareket azaltmadan bağımsız ama görseli de var).

**Saptığımız yerler**
- [O] Bus yok: Master dışında bus olmadan ses düzeyi ayarı, ducking, örtme, VO ayrımı yapılamaz; katalogda `bus` alanı yok (ses-ve-sfx §6 AC5 karşılanmıyor).
- [O] `SfxEmitter` tek kanal: `set_stream` çalanı keser; `max_polyphony` 1; aynı sahipten art arda olaylar birbirini keser (oyuncu/NPC'de belirgin olacak; US-009 adım + US-012 çanta).
- [O] 8/14 dosya stereo, 3'ü 48 kHz; 2D çalarda stereo genişlik panningle çelişir; `.ogg` zorunluluğu kısa SFX için Godot önerisine (WAV) ters.
- [O] Dinleyici ekran merkezi; `attenuation` 1,0 ile yarıçapta yalnız −6 dB (halka sınırı duyulmuyor); `2d_panning_strength` 0,5 ile kenar ≤ 0,75/0,25.
- [O] `max_distance` sadece > 0 girdide atanıyor, sonraki 0'lı girdi öncekini **miras alır** (`sfx_emitter.gd:61`); UI olayı aynı emitter'dan çalınırsa yanlış mesafe.
- [G] Uzak ses için uzaklık kapısı yok: `max_distance` dışındaki sesler kanal tüketiyor.

**Riskler**
- [?] Geç katılımda ilk eşitleme değişim sayılıp kapı/kasa sesi çalabilir (door.gd:118, register.gd:68).
- [G] Örtme ışını istemcide `world + vision_block` kullanırsa Hearing (host, ×0,5) ile iki farklı "duvar" tanımı yaşamamalı; aynı maske sabiti `core/`'da paylaşılmalı.
- [O] AI SFX ücretsiz katmanda atıf zorunlu — yanlışlıkla ücretsiz plandan üretilen dosya yayına girerse atıf eksik kalır; kayıt satırında "plan" sütunu gerekir.
- [O] Piper dfki Türkçe sesi CC BY-NC-SA — "ücretsiz TTS" diye kullanılırsa lisans ihlali.
- [G] Dummy sürücü iş parçacığı birim testlerde ±100 ms zamanlama oynaklığı; `finished`'e dayanan test yazılırsa toleranslı olmalı.

### Öneriler
| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri (2-3) |
|---|---|---|---|---|---|
| 1 | **P1** | S | altyapi (bus/ayar) + arayuz (katalog/çalar) | **Ses busları ve düzey ayarı (IS-024 eki / IS-031):** `default_bus_layout.tres` (Master, Music, SFX, SFX_Muffled, Voice, UI), `SfxEntry.bus`, çalarlar bus atar, ayarlar menüsünde 3 kaydırıcı (`user://`), `volume_db` kataloğu bus mantığıyla sadeleşir | AC1 birim: her katalog olayının bus'ı var ve düzende mevcut; AC2 kaydırıcı `AudioServer.get_bus_volume_linear` ile okunur/yazılır, yeniden açılışta kalıcı; AC3 headless'ta bus düzeni yüklenir, uyarı yok |
| 2 | **P1** | XS | arayuz | **Konumlu ses hijyeni (IS-024 denetim notu):** mono + 44,1 kHz, `.wav` izinli (<1 sn), `max_distance` her çalışta atanır (0 → varsayılan), `attenuation` katalogda (varsayılan 2,0), uzaklık > `max_distance` ise başlatma | AC1 test: konumlu girdilerin dosyası mono; AC2 `max_distance` miras testi; AC3 uzak olay `played` yaymaz |
| 3 | **P1** | XS | oynanis | **Yerel dinleyici:** oyuncu sahnesine `AudioListener2D`, yalnız yetkili kopyada `make_current()`; `2d_panning_strength` 0,75 proje ayarı (test-2 kulak A/B) | AC1 uzak kopyada dinleyici current değil (birim); AC2 görünümde tek current dinleyici |
| 4 | **P2** | S | oynanis | **Çok-olaylı sahipler için Polyphonic emitter:** `SfxEmitter.polyphony` (>1 ise `AudioStreamPolyphonic` + `play_stream` bus/pitch/volume), oyuncu ve NPC'de 4; prop'larda 1 kalır; US-009 adım + US-012 çanta buna bağlanır | AC1 aynı sahipten iki olay aynı anda çalar (headless `is_stream_playing`); AC2 tavan aşımında en eski durur; AC3 min_interval olay başına korunur |
| 5 | **P2** | XS | arayuz | **Varyant desteği:** katalog girdisi `AudioStreamRandomizer` olabilir; test alt stream'leri gezer; adım/kapı/kasa tiki 2-3 varyant (yer tutucudan) | AC1 Randomizer'lı girdi çalar ve testi geçer; AC2 `pitch_min=max=1` zorunluluğu testte |
| 6 | **P2** | S | arayuz (+ koordinatör onayı) | **IS-030 üretim hattı tanımı:** `tools/sfx_prep.py` (kırp, mono, 44,1k, tepe −1 dBTP, LUFS raporu), istem stil son eki, `assetler.md` "plan/araç/istem/tohum" sütunları, ElevenLabs ücretli hesap (kullanıcı), Steam beyan listesi | AC1 araç testli (`tools/test_sfx_prep.py`); AC2 üretilen her dosya satırlı + "AI üretimi evet"; AC3 kayıt testinde ücretsiz plan/atıf alanı boş olamaz |
| 7 | **P2** | S | oynanis | **Ucuz örtme:** `SFX_Muffled` bus (lowpass 1 kHz, −6 dB); emitter çalışta ışın (5 Hz döngüde), maske sabiti `core/` paylaşımlı | AC1 bileşen testi gerçek fizik ışınıyla duvar arkası → muffled bus; AC2 cam → temiz; AC3 ışın sayısı ≤ olay + 5 Hz |
| 8 | **P3** | S | arayuz (+ müzik kaynağı kararı) | **Müzik katmanları (Faz 4):** `AudioStreamSynchronized` 3 stem, `core/music_rules.gd` (kademe/tespit → stem dB), tespitte ≤ 0,3 sn kesme + stinger + 4 sn sessizlik, Music busı | AC1 birim: kademe → dB tablosu; AC2 tespit kesme süresi; AC3 ayar kaydırıcısı |
| 9 | **P3** | XS | oynanis | **Geç katılım sessizliği:** prop ilk eşitleme paketinde ses çalmaz (spawn'dan 0,5 sn ya da ilk sync'e kadar bastır) | AC1 ağ senaryosu: geç katılan istemcide `played` sayacı 0; AC2 sonraki değişimde çalar |

### Karar gereken
- (a) AI SFX için ücretli ElevenLabs hesabı (≈ $5-22/ay; para → kullanıcı) mı, yerel Stable Audio Open (GPU, "Powered by Stability AI" notu) mu? Öneri: ElevenLabs Starter 1-2 ay, toplu üretim, sonra kapat.
- (b) Türkçe VO: kullanıcı kaydı (öneri) / AI (beyan). ses-ve-sfx (a) ile aynı soru.
- (c) `assetler.md`'ye "plan/atıf" sütunu ve CI kapısı (kayıt testine ek) — küçük süreç kararı.

### Bir sonraki tur için açık sorular
- Kamera zoom 1,5 (853×480 görüş) ile 320-640 px `max_distance` değerleri ekranla nasıl örtüşüyor; görüş dışı ama duyulur bant ne kadar? (test-2 kulak ölçümü.)
- Polyphonic'te `finished` eksikliği altyazı/görsel eşleme için sorun mu (ileride işitme erişilebilirliği: ses → HUD ikonu)?
- Steam beyan metni formatı (anket alanları) — Faz 5'te `steam-yayin.md` ile birleşir.
- ElevenLabs API vs web arayüzü: toplu üretim için API (40 kredi/sn) + script mi, yoksa elle mi?
- Piper fahrettin/fettah veri seti lisansı; Google Cloud TTS tr-TR (Chirp 3 HD) kalite/lisans [?].

### Kaynaklar
[1] Godot docs — Audio buses: https://docs.godotengine.org/en/stable/tutorials/audio/audio_buses.html
[2] Godot docs — Importing audio samples (4.7): https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/importing_audio_samples.html
[3] Godot docs — ProjectSettings `audio/*`: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html
[4] Godot docs — AudioEffectCompressor (sidechain): https://docs.godotengine.org/en/stable/classes/class_audioeffectcompressor.html
[5] Godot docs — AudioStreamPlayer2D: https://docs.godotengine.org/en/stable/classes/class_audiostreamplayer2d.html
[6] Godot kaynak 4.7 — `scene/2d/audio_stream_player_2d.cpp` (zayıflama/panning formülü, dinleyici, fizik karesi güncellemesi): https://github.com/godotengine/godot/blob/4.7/scene/2d/audio_stream_player_2d.cpp
[7] Godot docs — AudioListener2D: https://docs.godotengine.org/en/stable/classes/class_audiolistener2d.html
[8] Godot kaynak 4.7 — `scene/audio/audio_stream_player_internal.cpp` (`set_stream` durdurur, polifoni en eskiyi keser): https://github.com/godotengine/godot/blob/4.7/scene/audio/audio_stream_player_internal.cpp
[9] Godot docs — AudioStreamPlaybackPolyphonic (`play_stream(..., bus)`): https://docs.godotengine.org/en/stable/classes/class_audiostreamplaybackpolyphonic.html
[10] Godot docs — AudioStreamRandomizer: https://docs.godotengine.org/en/stable/classes/class_audiostreamrandomizer.html
[11] Godot 4.3 sürüm notları (Interactive/Synchronized/Playlist, web sample playback; 2024-08-15): https://godotengine.org/releases/4.3/
[12] Godot docs — AudioStreamSynchronized: https://docs.godotengine.org/en/stable/classes/class_audiostreamsynchronized.html
[13] Godot docs — AudioStreamInteractive: https://docs.godotengine.org/en/stable/classes/class_audiostreaminteractive.html
[14] Godot docs — Area2D (`audio_bus_override`, `audio_bus_name`): https://docs.godotengine.org/en/stable/classes/class_area2d.html
[15] Godot Asset Library — SpatialAudio3D (ışın + lowpass örtme kalıbı, 3D): https://www.godotengine.org/asset-library/asset/3444
[16] Godot docs — Audio streams (Area2D ile bus yönlendirme): https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html
[17] Godot docs — Command line tutorial (`--headless` = headless + Dummy): https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
[18] Godot kaynak 4.7 — `servers/audio/audio_driver_dummy.{h,cpp}` (iş parçacığı, 4096 kare): https://github.com/godotengine/godot/blob/4.7/servers/audio/audio_driver_dummy.cpp
[19] Godot issue #71640 — çıkış aygıtı yokken `finished` yok; 4.3'te PR #87010 ile kapandı: https://github.com/godotengine/godot/issues/71640
[20] ElevenLabs docs — Sound effects (0,1-30 sn, döngü, WAV 48 kHz, 40 kredi/sn): https://elevenlabs.io/docs/capabilities/sound-effects
[21] ElevenLabs — Commercial sound effects (ücretsiz plan atıf, ücretli atıfsız): https://elevenlabs.io/sound-effects/commercial
[22] ElevenLabs docs — Models (v4/v3/Multilingual v2/Flash v2.5; Türkçe): https://elevenlabs.io/docs/models
[23] ElevenLabs docs — Text to speech (dil listesi): https://elevenlabs.io/docs/capabilities/text-to-speech
[24] Stability AI Community License (< 1 M$ gelir, bildirim, çıktı sahipliği): https://stability.ai/community-license-agreement
[25] Stable Audio Open 1.0 model kartı (47 sn, 44,1 kHz, veri kaynakları): https://huggingface.co/stabilityai/stable-audio-open-1.0
[26] Stable Audio 2.5 / web ücretsiz katman ticari değil (üçüncü taraf özet): https://www.fast.io/resources/stability-ai-review-2026.md
[27] AudioCraft ağırlıkları CC-BY-NC (HF tartışma): https://huggingface.co/spaces/facebook/MusicGen/discussions/8
[28] Steamworks docs — Content survey (AI: pre-generated / live-generated; "sound" dahil): https://partner.steamgames.com/doc/gettingstarted/contentsurvey
[29] Steam AI beyanı Ocak 2026 yeniden yazımı (haber): https://games.slashdot.org/story/26/01/19/1735231/valve-has-significantly-rewritten-steams-rules-for-how-developers-must-disclose-ai-use
[30] Chatterbox Multilingual (MIT, Türkçe, PerTh filigran): https://resemble.ai/learn/models/chatterbox-multilingual
[31] Piper tr_TR dfki model kartı (CC BY-NC-SA 4.0): https://huggingface.co/rhasspy/piper-voices/resolve/main/tr/tr_TR/dfki/medium/MODEL_CARD · Piper ses listesi: https://github.com/rhasspy/piper/blob/master/VOICES.md · Azure tr-TR ticari kullanım (MS Q&A): https://learn.microsoft.com/en-us/answers/questions/1024732/can-i-use-microsoft-azure-neural-voice-in-my-game
[32] FMOD licensing: https://fmod.com/licensing · özet: https://gamefromscratch.com/?p=24152
[33] utopia-rise fmod-gdextension (topluluk, Godot 4): https://github.com/utopia-rise/fmod-gdextension
[34] alessandrofama fmod-for-godot: https://github.com/alessandrofama/fmod-for-godot
[35] alessandrofama wwise-godot-integration (README): https://github.com/alessandrofama/wwise-godot-integration
[36] Audiokinetic — Wwise Indie license (bütçe < 250 k$): https://www.audiokinetic.com/en/blog/free-wwise-indie-license
[37] ASWG-R001 / oyun ses düzeyi (−24 LUFS ±2, −1 dBTP): https://designingsound.org/2013/02/loudness-in-game-audio/
[38] AI SFX araç karşılaştırmaları (2026; [G] kaynağı): https://app.cinevva.com/guides/ai-sound-effect-generators · https://neuronfeed.com/compare/stable-audio-vs-elevenlabs

---

## Tur 2 — 2026-10-02

### Kapsam
(1) Zoom 1,5 görüş alanı ↔ katalog duyulma mesafeleri (yarıçap × 2): ekran kenarı/dışı sesin oyuncuya bilgi verme biçimi; gizlilik oyunlarında ses-görsel eşleme (Mark of the Ninja, Monaco); işitme erişilebilirliği (ses → HUD ikonu/yön; Polyphonic'te `finished` yokluğu). (2) KR-024 için AI SFX maliyet/iş akışı karşılaştırması (ElevenLabs SFX API, Stable Audio 3 yerel, diğer 2026 seçenekleri; lisans + Steam beyanı). (3) KR-025: Türkçe ünlem/replik ev kaydı rehberi + AI alternatif lisansları. (4) Bakkal için dinamik müzik minimumu (Godot 4.7 Synchronized/Interactive durumu, kaynak/lisans). (5) Ağda ses olaylarının çift çalınmaması (host + istemci, geç katılan). Dayanak: tur 1; KR-020/022/024/025; IS-024 (denetimde), IS-030, IS-033, IS-060..063; ses-ve-sfx §1 kural 1/3/7, oyun-hissi §2/§4, rahatlik-ux "Erişilebilirlik" satırı; mimari S8/S11.

### Mevcut durum (dosya:satır; IS-024 worktree `.claude/worktrees/agent-a7f9b86f90c83f2c1`, salt okunur)
| Parça | Nerede | Tur 2 için önemli olan |
|---|---|---|
| Görüş alanı | `project.godot:31-32` 1280×720; `player.gd:88` `camera_zoom` 1,5 (IS-027) | Dünya görüşü **853×480**, merkezden kenar **427 (yatay) / 240 (dikey)**, köşe 490. Look-ahead (oyun-hissi §4) avatarı merkezden ≤ 80 px kaydırır. |
| Duyulma | `data/sfx_catalog.tres` `max_distance`: register 180, run_step 240, door/clerk_question/interrogate 320, clerk_shout 640; S8 yarıçapları: kasa 90, koşu 120, kapı 160, bağırış 320 | Halka = NPC duyma yarıçapı (S8), ses = ×2. |
| Çalındı sinyali | `entities/fx/sfx_emitter.gd:12` `signal played(event)` ("ileride altyazı/görsel eş için") | HUD göstergesi için kanca hazır; konum = sahibin `global_position`. |
| Halka | `autoload/noise.gd` `noise_shown(pos, radius, kind)` → `entities/fx/noise_ring.tscn` (US-009) | Ekran dışı kaynak için halka da ekran dışı; kenar işareti yok (`edge_arrow`/`offscreen` araması boş). |
| Ağ çoğaltma | `entities/props/interactable.gd:285-296` ve `npc/components/suspicion.gd:122-132`: `property_set_spawn(false)` + `REPLICATION_MODE_ON_CHANGE`, `delta_interval = SYNC_INTERVAL`; kapı `door.gd:110-118` setter'da `is_node_ready()` koruması + ses; kasa `register.gd:68-74` setter'da ses | Prop'lar seviye sahnesinde yerel yüklenir (`game.gd` `_load_level_local`), **spawner ile gelmez** → spawn-state yolu yok. |
| İlk eşitleme damgası | `autoload/game.gd:660-676` uzak oyuncu için `synchronized`/`delta_synchronized` `CONNECT_ONE_SHOT` → `_SYNCED_META` | Aynı kalıp prop'lara "ilk paket sessiz" için uygulanabilir. |
| Kademe sesi | `ui/alert_ladder.gd:103` `UiSfx` (konumsuz; görseli HUD'da) | Konumsuz olaylar göstergeye girmez. |
| VO/balon | oyun-hissi §2: sorgu/bağırış **balon metni host'tan** | VO satırlarının altyazısı zaten var (balon); katalogda metin anahtarı yok. |

### En iyi uygulamalar ve seçenekler

#### 1. Görüş alanı ↔ duyulma bandı (geometri; sayılar [O], yorum [G])
Dinleyici = kamera merkezi (IS-061 ile avatar; look-ahead ≤ 80 px farkı aşağıda).

| Olay | Yarıçap r (halka) | Duyulma 2r | Yatayda ekran dışı duyulur bant (kenar 427) | Dikeyde (kenar 240) | Halka ekrana girer mi (d < kenar + r)? |
|---|---|---|---|---|---|
| register_tick/done | 90 | 180 | yok | yok | hep ekranda |
| run_step (koşu) | 120 | 240 | yok | tam kenarda (0) | — |
| door_open/close, clerk_question/interrogate | 160 | 320 | **yok** | 240-320 (**80 px**) | evet (d < 400) |
| clerk_shout | 320 | 640 | 427-640 (213 px) | 240-640 (400 px) | yatay evet (d < 747); dikey d < 560 → **560-640 arası ses var, halka yok** |

- [O] Ekran dışından duyulan tek anlamlı olay bağırış; kapı/sorgu yalnız dikeyde 80 px'lik bantta. Thief dersi ("mahalleliyi görmeden duy") zoom 1,5'ta katalog değerleriyle **gerçekleşmiyor**; bakkalda bu ciddi değil (tek oda + arka oda), ama ses-ve-sfx kural 3 ("duvar arkasından mahalleli adımı duyulur, görülmez") ancak dikeyde ve 80 px'te.
- [O] Look-ahead 80 px: avatarın baktığı yönde kenar 160 px'e iner (dikey) → kapı 160 px ekran dışından duyulur; arkada kenar 320 → arkadaki kapı tam sınırda. Yani kayma "önü duyma"yı artırır, arkayı kısar; dinleyici = avatar (IS-061) olunca bu asimetri doğal ve istenen.
- [G] Seçenekler: (a) bilgi taşıyan olaylarda çarpan 2 → 3 (kapı/sorgu 480: yatay 53 px, dikey 240 px bant) — ucuz, katalog değişimi; ses-ve-sfx §6 AC3 "≥ 2× yarıçapta duyulmaz" cümlesi "≥ 3×" olur (tasarım onayı). (b) Çarpan sabit, ekran dışı ses **kenar işareti**yle görselleşir (#2) — kural 7'yi de karşılar. Öneri: **(b) zorunlu, (a) test-2 kulak A/B'si** (2×/3× aynı tohum).
- [O] Mark of the Ninja: halka çapı = sesin NPC'ye duyulma mesafesi; halka muhafızın kulak ikonuna değerse duyar; oyuncuya "neden tepki verdi"yi anlatır. Monaco: ses halkaları (yürüme küçük, sızma yok, silah/noise maker büyük) muhafızı kaynağa çeker. [G] İkisinde de halka **NPC algısını** görselleştirir, oyuncunun duyması ayrı; bizim "halka = S8 yarıçapı, ses = 2×" aynı ayrımı yapıyor — doğru. Teleglitch için ses-görsel eşleme kaynağı bulunamadı [?] (oyun görüş hattı/sis üstüne; ses halkası yok).
- **Kaynak:** [39][40][41].

#### 2. Ekran dışı ses → HUD göstergesi (oyun bilgisi) ve işitme erişilebilirliği
- [O] Yönergeler: Game Accessibility Guidelines — "Ensure no essential information is conveyed by sounds alone" (temel), "all important supplementary information (eg. the direction you are being shot from) conveyed by audio is replicated in text/visuals" (orta), "Provide captions or visuals for significant background sounds" (orta), ayrı ses düzeyi denetimleri (temel). Xbox XAG 103: ses-kritik içerik görsel (tip ikonu + yön grafiği) ve/veya haptikle de verilir. Örnekler: Fortnite "Visualize Sound Effects" (yön + tip + yakınlık halkası; opsiyonel), Minecraft altyazıları (ekran dışı sesler için `<`/`>` ok, ses zayıfladıkça metin solar), Assassin's Creed Odyssey / Metro Exodus yönlü altyazı.
- [G] Bizde iki katman, tek mekanizma:
  - **Varsayılan (oyun bilgisi, kapatılamaz):** halkası/balonu ekran dışında kalan **duyulur** konumlu olay için kenar işareti: kaynak kamera dikdörtgeninin 16 px içine kenetlenir; ikon = olay türü (adım/kapı/kasa/insan sesi — 4 şekil, renk değil; rahatlik-ux ALERT seti), opaklık = 1 − d/max_distance, ömür = `stream.get_length()` (≥ 0,6 sn; `repeat_while`'da koşul sürdükçe), aynı anda ≤ 4 (halka bütçesiyle ortak, oyun-hissi §1 kural 5); hareket azaltmadan etkilenmez (hareket değil). Kapı 80 px bandı ve bağırış 213/400 px bandı böylece görünür; kural 7 ("hiçbir bilgi yalnız sesle") ekran dışı için de sağlanır.
  - **Seçenek "Ses görselleştirme" (US-025 ayarlar; kapalı / ekran dışı [varsayılan] / hepsi):** "hepsi" kipinde ekrandaki konumlu olaylar da kaynağın üstünde küçük ikonla gösterilir (Fortnite kalıbı); VO altyazısı zaten balon → katalog girdisine `caption_key` (i18n) eklenir, balon metni ile ses satırı tek kaynaktan gelir.
  - **Gösterge ↔ ses kapısı aynı kural:** gösterge yalnız sesin de çalacağı (d ≤ max_distance, IS-061 uzaklık kapısı) olaylarda; aksi hâlde işitenin duymadığı bilgiyi sızdırır. Karar fonksiyonu düğümsüz `core/` (girdi: dinleyici konumu, kaynak, kamera dikdörtgeni, max_distance → görünür mü, kenar noktası, opaklık) → headless birim test, ses sürücüsünden bağımsız.
- [O] Polyphonic `finished` yokluğu (#88941 açık): gösterge ömrü `AudioStream.get_length()` + katalog `min_interval`'dan türetildiği için **etkisi yok**; döngü/tekrar olaylarında ömür koşula bağlı. Ayrıca #123398 (`get_playback_position` 0 döner, 2026-09, açık) → Polyphonic'te konumdan ömür hesaplanamaz; uzunluktan hesaplanır.
- [O] Kamera dikdörtgeni: `Camera2D.get_screen_center_position()` + `get_viewport_rect().size / zoom` (IS-027 kenetleme sonrası gerçek merkez).
- **Kaynak:** [42][43][44][45][46][47].

#### 3. KR-024 — AI SFX: karşılaştırmalı maliyet/iş akışı (2026-10; sayfalar değişir, üretim günü yeniden bakılır)

| Seçenek | Lisans / ticari | Steam beyanı | Maliyet | Donanım/kurulum | Kalite [G] | Not |
|---|---|---|---|---|---|---|
| **ElevenLabs Sound Effects** (API `POST /v1/sound-generation`, model `eleven_text_to_sound_v2`) | Ücretsiz plan: ticari kullanımda elevenlabs.io atfı; ücretli: atıfsız; "rekabet eden ürün geliştirme" yasak [O] | Evet (ön-üretilmiş ses) | 40 kredi/sn; Free 10k kredi/ay (atıf), **Starter $5-6/ay 30k**, Creator $22 ~121k [O pricing 2026-10]. Bütçe [G]: 25 olay × 5 aday × 1,5 sn + 30 sn döngü ≈ 220 sn ≈ **9-10k kredi** → Starter 1 ay yeter | Yok; `xi-api-key`; `text`, `duration_seconds` 0,5-30 (boş = otomatik), `prompt_influence` 0-1 (0,3), `loop` (v2), `output_format` (mp3_44100_128 … pcm_44100/48000) [O] | Kısa vuruş/UI/foley güçlü | Önerilen ana yol (tur 1 ile aynı) |
| **Stable Audio 3 Small SFX** (açık ağırlık, 459M; HF `stabilityai/stable-audio-3-small-sfx`, gated-auto; `stable-audio-3` kütüphanesi; 2026-05) | Stability AI Community License: yıllık gelir < 1 M$ ticari serbest, çıktı kullanıcının; eğitim verisi lisanslı (AudioSparx) + Freesound CC0/CC-BY/Sampling+ [O model kartı] | Evet | Ücretsiz | Small: CPU'da çalışır (TFLite: Win/mac/Linux), ~1,7-2,4 GB VRAM; "MacBook Pro M4'te birkaç sn" [O README]; Windows+CUDA yolu README'de belirsiz [?]; HF hesabı + lisans kabulü gerekir | Open 1.0'dan iyi beklenir (yeni mimari, ters eğitim) [G, dinlenmedi] | Yerel yedek; `tools/sfx_gen_local.py` adayı. "Powered by Stability AI" notu model/türev dağıtımı içindir, yalnız çıktı dağıtan oyun için gerekmiyor [G yorum; ucuz olduğundan künyeye yine de yazılır] |
| Stable Audio Open 1.0 / Open Small (2024-25) | Aynı lisans | Evet | Ücretsiz | 1.0: ≥ 7 GB VRAM (ComfyUI) [O topluluk]; Small 497M | SA3 ile aşıldı | Eleniyor (SA3 Small SFX var) |
| Adobe Firefly Generate Sound Effects (GA 2026-08) | "Universally licensed", tüketici katmanında daha dar tazminat; **ortak modeller (ElevenLabs vb.) kapsam dışı** [O haber/ürün sayfası] | Evet | Firefly aboneliği/kredi [?] | Web | [?] | Abonelik varsa alternatif; yoksa gereksiz |
| TangoFlux (declare-lab) | **Araştırma/akademik, ticari değil** (WavCaps şartı + SAI Community) [O LICENSE.md] | — | — | — | — | **Elenir** |
| MMAudio (video→ses) | CC-BY-NC [O] | — | — | — | — | **Elenir** |

- **Toplu üretim betiği taslağı (`tools/sfx_gen.py`; kod değil, adımlar) [G]:** (1) `data/sfx_prompts.csv`: `event, prompt, duration_s, loop, variants, style_suffix` (tur 1 stil son eki). (2) Her satır için `variants` kez API çağrısı (`pcm_44100` → WAV; `prompt_influence` 0,4-0,6), çıktı `build/sfx_raw/<event>_<nn>.wav` + `meta.json` (plan, model, istem, tarih, kredi). (3) `tools/sfx_prep.py` (IS-061): kırp, mono, 44,1 k, tepe −1 dBTP, LUFS raporu → `assets/sfx/<event>_<nn>.wav|ogg`. (4) `assetler.md` satırı üret (araç/plan/istem/tarih, "AI üretimi evet", "Steam beyanı evet"); kayıt testi "plan = free ⇒ atıf metni dolu" kuralı. (5) Seçim elle: olay başına 1-3 varyant kalır, kalanı silinir (depo şişmez). API anahtarı ortam değişkeninde, repoya girmez; `--dry-run` kredi tahmini.
- **Kullanıcıya 3 satırlık özet (KR-024):** "Yer tutucu Kenney sesleri yerine 20-25 olay için üretilmiş ses: ElevenLabs Starter 1 ay (~5-6 $, atıfsız ticari, yaklaşık 10k kredi harcanır) ana yol; ücretsiz yedek olarak Stability'nin yeni açık modeli Stable Audio 3 Small SFX bilgisayarınızda GPU'suz çalışır (HF hesabı ister). Her iki yol da Steam'de 'yapay zekâ üretimi ses' beyanına girer; öz kaynak VO beyana girmez."
- **Kaynak:** [20][21][48][49][50][51][52][53][54].

#### 4. KR-025 — Türkçe ünlem/replik: ev kaydı rehberi ve AI alternatifleri
**Ev kaydı (öz kaynak; beyan yok) [G, sektör pratiği; dolap/battaniye/çorap tavsiyeleri O]:**
1. **Mekân:** dolap içi ya da başa/telefona örtülen kalın battaniye (yankı emer); buzdolabı/klima/bilgisayar fanı kapalı; gece.
2. **Mikrofon:** USB mikrofon varsa (kardioid, 15-20 cm, ağızdan 20° yana); yoksa telefon uçak kipinde, 15-20 cm, üstüne temiz çorap (p/b patlaması için). Uygulama kayıpsız WAV/ALAC'a ayarlanır (iOS Sesli Notlar "Kayıpsız"; Android'de WAV kaydeden ücretsiz uygulama).
3. **Düzey:** tepe −12…−6 dBFS; sessizlik tabanı ≤ −55 dBFS; kayıt başında 3-5 sn **oda tonu** (gürültü azaltma profili).
4. **Satırlar (bakkal, 5-8 satır):** "Hı?", "Hey!", "Ne yapıyorsun orada?", "Hırsız var!", "Dur!", mahalleli "Hey, sen!"; her satır 6-10 tekrar × 3 şiddet (sakin / tedirgin / bağırış); bağırışta mikrofona 40 cm. Arkadaş kaydında yazılı rıza (e-posta satırı) `assets/licenses/vo_<kişi>.txt`.
5. **İşlem (Audacity 3.5+ ya da ffmpeg) [O araç özellikleri]:** Noise Reduction (profil: oda tonu; 9-12 dB), High-pass 80 Hz, kes (baş ≤ 5 ms, kuyruk 50 ms fade), Loudness Normalization "perceived loudness" (Audacity varsayılanı −23 LUFS EBU; bizim VO dosya hedefi **−18 LUFS integrated, tepe −1 dBTP** — tur 1 kategori tablosuyla uyumlu; ffmpeg iki geçişli `loudnorm I=-18:TP=-1:LRA=7`). Mono 44,1 kHz; OGG q6. Oyun bütünü referansı ASWG-R001 −24 LUFS ±2 (tur 1 [37]).
6. **Dosya adı:** `vo_<ton>_<karakter>_<olay>_<nn>.ogg` (ör. `vo_noir_clerk_shout_01.ogg`); katalog `clerk_shout` → Randomizer `.tres` (3 varyant); `assetler.md` satırı "öz kaynak, kaydeden <ad>, tarih".
7. **Süre:** ~1 saat kayıt + 1 saat işlem (ilk sefer). Kazanım: tona en uygun, tutarlı tek ses; kötü oda telefonla bile kabul edilebilir (gürültü azaltma + yakın mikrofon).

**AI alternatifleri (hepsi Steam beyanı; indirme günü yeniden doğrulanır):**
| Araç | Türkçe | Lisans [O] | Maliyet | Not |
|---|---|---|---|---|
| Piper tr_TR **fahrettin / fettah** (medium, 22,05 kHz) | evet | **CC0** (NabuCasa voice-datasets; model kartı) — tur 1'deki [?] kapandı | ücretsiz, CPU | Robotik, bağırış/duygu yok; yalnız yer tutucu. dfki sesi CC BY-NC-SA → kullanılmaz (tur 1) |
| Chatterbox Multilingual (Resemble; HF `ResembleAI/chatterbox`) | evet (23 dil, `tr`) | MIT; çıktı PerTh filigranlı | ücretsiz, GPU önerilir | "exaggeration" ayarı; bağırış denenir; HF'de Türkçe TTS arenası var |
| ElevenLabs TTS (v3/v4; Türkçe) | evet | Ücretli plan ticari; SFX ile aynı Starter aboneliği | kredi/karakter | En ifadeli; satırlar kısa, Starter yeter |
| Google Cloud TTS tr-TR (Chirp 3 HD) | evet | Çıktı ticari kullanılır; rakip TTS eğitimi yasak [O forum/ToS]; fiyat/ücretsiz katman doğrulanamadı [?] | — | Spiker tınısı; bağırış zayıf |
| Azure tr-TR Neural | evet | tur 1 | — | tur 1 |

- [G] Karar önerisi değişmedi: bakkal **kullanıcı kaydı**; mahalleli/müşteri çeşitliliği (2b) Chatterbox (ücretsiz, MIT) ya da ElevenLabs (aynı abonelik). Piper fahrettin/fettah lisans açısından temiz ama kalite yer tutucu düzeyi.
- **Kaynak:** [55][56][57][58][59][30].

#### 5. Bakkal için dinamik müzik minimumu (Faz 4; Godot 4.7 durumu)
- **[O docs 4.7] `AudioStreamSynchronized`:** ≤ 32 alt stream, hepsi aynı anda başlar, `set_sync_stream_volume(idx, db)` çalışırken değişir; döngü alt stream'lerde. `AudioStreamInteractive`: klip tablosu + `add_transition` (from: immediate / next_beat / next_bar / end; fade: disabled/in/out/cross/automatic; filler klip; `hold_previous`), `AudioStreamPlaybackInteractive.switch_to_clip(_by_name)`.
- **[O açık sorunlar/PR'lar, 2025-26]:** #106979 Synchronized stem ses düzeyi değişiminde **pop/klik** (PR açık, 4.x); #109381 Synchronized içindeki playback'lere erişim yok (Interactive'i Synchronized içine koymak sınırlı); Interactive: #122956 "at end" cross-fade ölü bölge, #121952 filler klip fade hatası (PR'lar açık); #88133 Interactive'de `get_playback_position` 0. Yani 4.7.2'de **Synchronized basit kullanımda çalışır, hızlı ses düzeyi tween'inde pop riski; Interactive'den kaçınılır.**
- **[G] Minimum tasarım (ses-ve-sfx §5 ile aynı, 4.7'ye uyarlanmış):**
  - 3 stem (A pad, B nabız, C gerilim) **aynı uzunluk/bpm, döngü noktaları aynı**, tek `AudioStreamPlayer` (bus Music) + `AudioStreamSynchronized`; kural `core/music_rules.gd`: kademe 0 → (0, −80, −80) dB; 1-2 → (0, 0, −80); 3 → (0, 0, 0); tespit → hepsi −80 ≤ 0,3 sn, stinger (ayrı çalar), 4 sn sessizlik, A döner. Geçiş 1-2 sn, **≤ 1 dB / 50 ms** adımlarla (pop'u küçültür); kulak testinde pop duyulursa **B planı:** 3 ayrı `AudioStreamPlayer` aynı karede `play()` + 3 alt bus (MusicA/B/C → Music), geçiş bus düzeyinde (`AudioServer.set_bus_volume_db`, headless'ta okunur). Her iki yolda birim test: kademe → dB tablosu, kesme süresi.
  - Stem'siz en küçük MVP (KR-020): yalnız A pad + stinger + sessizlik kuralı; B/C stem'ler müzik kaynağı kararıyla gelir.
- **Kaynaklar/lisans (müzik):** CC0: Kenney Music Jingles (stinger), OpenGameArt CC0 süzgeci, Free Music Archive CC0 süzgeci [G liste]; Pixabay Content License: atıfsız ticari, "standalone" satış yasak, oyun içi kullanım açıkça yazmıyor ama değiştirilmiş eser kapsamında [O lisans özeti; G yorum] — AI etiketli içerik var, satır satır bakılır. AI müzik: **Stable Audio 3 Small Music** (açık ağırlık, 2 dk, Community License, lisanslı veri) [O]; **Eleven Music** (lisanslı eğitim verisi; "gaming" açıkça; **plan kademesine göre hak**: üçüncü taraf özete göre indie oyun için Pro ($99) gerekli, Creator'da yok [? resmî "music model-specific terms" sayfası alınamadı — satın almadan önce doğrulanır]); Suno Pro $10 (ticari lisans, davalar sürüyor, ücretsiz katman geriye dönük lisanslanamaz) [O üçüncü taraf]; Udio dışa aktarım yok [O üçüncü taraf]. Stem üretimi için AI araçlarının "aynı bpm/ton'da 3 ayrı istem" çıktısı hizalanmaz [G]; Stable Audio 3 inpainting/continuation ile tek parçadan türetme denenebilir [?]. Öneri: Faz 4'te önce CC0 pad + Kenney stinger; stem'ler için karar (ücretli/AI) ayrı KR.
- **Kaynak:** [12][13][60][61][62][63][64][65][66].

#### 6. Ağda ses olaylarının çift çalınmaması (IS-024 için)
- **Kalıp [O proje + docs]:** ses yalnız **çoğaltılan durum setter'ında** çalar; host da durumu aynı setter'dan değiştirir (`door.gd:_on_completed` → `is_open` setter) → her peer'da tam bir kez. **Yasak:** ses için RPC; `completed` sinyalinde + setter'da iki kez çalma; istemcide tahminle (A) çalıp host onayında (O) tekrar çalma — oyun-hissi §3'te A olaylar (yerel adım) yalnız yerelde, O olaylar yalnız durumdan. Aynı olayın hem halkadan (`noise_shown`, güvenilmez RPC) hem durumdan tetiklenmesi de çift sayılır: **halka görsel, ses durumdan** (tur 1 #8).
- **Geç katılan — kaynak kod doğrulaması [O 4.7 `scene_replication_interface.cpp`, `multiplayer_synchronizer.cpp`]:** ON_CHANGE özelliklerinde izleyici (`Watcher.last_change_usec`) ilk izlemede o anki zamanla kurulur; yeni görünür olan peer için `last_watch_usecs` kaydı yok → `get_delta_state(…, 0)` **tüm izlenen özellikleri** ilk delta paketinde yollar (bir `delta_interval` içinde). Sonuç: geç katılan, prop'ların tam durumunu `_ready` **sonrası** alır → `door.gd:118` açık kapı için `door_open`, `register.gd:72` boş kasa için `register_done` **çalar** (tur 1 riski doğrulandı). Spawn-state yolu (`property_set_spawn(true)`, `_ready` öncesi uygulanır) yalnız `MultiplayerSpawner` ile gelen düğümlerde; prop'lar seviye sahnesinde yerel yüklendiğinden **geçerli değil**.
- **Çözüm [G]:** istemcide prop `_ready`'de `_initial_sync_pending = not Net.is_host()`; `MultiplayerSynchronizer.delta_synchronized`/`synchronized` ilk yayınında (sinyal, özellikler yazıldıktan **sonra** gelir [O docs]) bayrak düşer; setter bayrak açıkken **durumu uygular, ses çalmaz**. İlk paket her zaman geldiği için (kaynak kod) "hiç değişmemiş prop'ta ilk gerçek değişim yanlışlıkla susar" durumu olmaz. `game.gd:660-676` `_mark_synced` kalıbıyla aynı; `Interactable._make_sync` sinyali sahibe köprüler. Zaman tabanlı susturma (0,5 sn) yedek ama `delta_interval`'a bağımlı. Test: ağ senaryosunda host kapıyı açar → istemci katılır → istemci `played` sayacı 0; sonra host kapatır → 1.
- **Host'ta ikinci kaynak:** `Interactable.progress` tiki (`repeat_while`) istemcide 20 Hz delta'ya bağlı; iptalde ≤ 1 fazla tik (tur 1) — kabul.
- **Kaynak:** [67][68][69][70].

### Bizim yapımıza uygunluk değerlendirmesi
| Konu | Seçim | Neden |
|---|---|---|
| Duyulma bandı | 2× sabit + ekran dışı kenar işareti (varsayılan); 3× test-2 A/B | Kural 7 ekran dışında ancak işaretle sağlanır; çarpan değişimi tasarım kararı |
| Gösterge | `played` + konum → HUD `SoundIndicator`; karar `core/`'da düğümsüz; ömür stream uzunluğundan | Polyphonic `finished` yok; headless test |
| Erişilebilirlik | Ayar "Ses görselleştirme" (kapalı / ekran dışı / hepsi) + `caption_key` | GAG orta düzey; balon zaten altyazı |
| AI SFX | ElevenLabs Starter 1 ay (ana) + Stable Audio 3 Small SFX yerel (yedek) | lisans net, bütçe ~10k kredi; SA3 CPU'da |
| VO | Kullanıcı kaydı rehberi (§4); Chatterbox 2b çeşitlilik | beyan yok, ton tutarlı |
| Müzik | Synchronized 3 stem, küçük adımlı tween; pop'ta 3 çalar + 3 bus; Interactive yok | #106979 açık; yatay geçiş gerekmiyor |
| Ağ | Setter'da ses + ilk delta sessiz bayrağı | kaynak kodla doğrulandı |

### Bulgular
**Doğru yaptıklarımız [O]**
- Halka = NPC duyma yarıçapı, ses = oyuncu bilgisi ayrımı Ninja/Monaco ile aynı; `played` sinyali göstergeye hazır; ses yalnız setter'da (host dahil tek kez); VO satırlarının balonu altyazı işlevi görüyor.
- Interactive kullanmama kararı (tur 1) 4.7'deki açık hatalarla doğrulandı.

**Saptığımız yerler**
- [O] Zoom 1,5'ta kapı/sorgu sesleri yatayda hiç, dikeyde 80 px ekran dışından duyuluyor; "görmeden duy" neredeyse yok; bağırışın 560-640 dikey bandında ses var halka yok → kural 7 ihlali (küçük).
- [O] Ekran dışı halka/balon için kenar işareti yok; ekran dışı sesin görseli yok.
- [O] Geç katılan istemcide açık kapı/boş kasa sesi çalar (kaynak kodla doğrulandı; tur 1'de [?] idi).
- [O] Katalogda `kind`/`caption_key` yok → gösterge ikonu ve altyazı için alan gerekir.

**Riskler**
- [O] #118498 (2026-04; 4.3/4.6.2/4.7.dev4'te doğrulandı, açık, milestone yok): `AudioStreamPlaybackPolyphonic.play_stream` **bus parametresi yok sayılıyor** → IS-062 Polyphonic + IS-063 kanal başına `SFX_Muffled` bus planı 4.7.2'de çalışmayabilir; örtme için çaların kendi `bus`'ı değiştirilir (tüm kanallar birlikte) ya da örtme yalnız tek kanallı prop çalarlarında. IS-062 başlarken 4.7.2'de yeniden denenir.
- [O] #106979 Synchronized ses düzeyi tween'inde pop (açık) → müzik geçişi kulak testi şart; B planı hazır.
- [?] Eleven Music plan kademeleri (indie oyun için Pro?) resmî sayfadan doğrulanamadı; satın almadan önce model-specific terms okunur.
- [?] Stable Audio 3 Small SFX Windows+CUDA yolu; CPU/TFLite yolu belgelenmiş. Google TTS fiyatı alınamadı.
- [G] Kenar işareti + halka + balon üst üste binince HUD kalabalığı (ortak ≤ 4 sayaç gerekir).

### Öneriler
| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri (2-3) |
|---|---|---|---|---|---|
| 10 | **P1** | S | arayuz (+ oynanis konum) | **Ekran dışı ses göstergesi (IS-033 eki):** `core/sound_indicator_rules.gd` (dinleyici, kaynak, kamera dikdörtgeni, max_distance → görünür/kenar noktası/opaklık), HUD `SoundIndicator` (`played` + sahip konumu; ikon = katalog `kind`; ömür stream uzunluğu; ≤ 4), katalog `kind` alanı | AC1 birim: ekran içi kaynak → gösterge yok; ekran dışı & d ≤ max → kenar noktası 16 px içeride, opaklık 1−d/max; d > max → yok; AC2 headless: 5 olay art arda → en fazla 4 gösterge, en eski düşer; AC3 hareket azaltma göstergeyi değiştirmez |
| 11 | **P1** | XS | oynanis (+ cekirdek sinyal köprüsü) | **Geç katılım sessizliği (tur 1 #9 netleşti):** prop setter'ları ilk `delta_synchronized`/`synchronized`'a kadar sessiz; `Interactable._make_sync` sinyali sahibe köprüler | AC1 ağ senaryosu: host kapıyı açıp kasayı boşaltır → istemci katılır → istemci `played` 0, durum doğru; AC2 sonraki değişimde 1; AC3 host tarafı etkilenmez |
| 12 | **P2** | XS | arayuz | **Erişilebilirlik ayarı "Ses görselleştirme" + altyazı anahtarı (US-025 eki):** kapalı / ekran dışı [varsayılan] / hepsi; katalog `caption_key`, balon metni ile aynı anahtar | AC1 "hepsi" kipinde ekran içi konumlu olay kaynağın üstünde ikon; AC2 "kapalı"da ekran dışı kapı için kenar işareti yine var (oyun bilgisi, kapatılamaz); AC3 VO olaylarının `caption_key` i18n'de var (test) |
| 13 | **P2** | XS | tasarim + arayuz | **Duyulma çarpanı A/B (test-2):** `--sfx-range-mult=2|3` geliştirici argümanı; ses-ve-sfx §6 AC3 cümlesi karara göre | AC1 argüman katalog `max_distance`'ı çarpar (yalnız konumlu); AC2 test-2 anketinde "mahalleliyi görmeden duydum" sorusu |
| 14 | **P2** | S | arayuz (+ kullanıcı hesabı) | **IS-030 üretim betiği `tools/sfx_gen.py` + `data/sfx_prompts.csv`** (§3 adımları; API anahtarı ortamdan; meta.json; assetler satırı üretir) | AC1 `--dry-run` istek listesi ve kredi tahmini basar; AC2 çıktı `sfx_prep.py`'den geçmeden `assets/`'e girmez; AC3 kayıt testinde plan=free ⇒ atıf zorunlu |
| 15 | **P2** | XS | oynanis | **IS-062/063 ön kontrolü:** 4.7.2'de `play_stream(bus=…)` davranışını headless'ta ölçen tek test — #118498 varsa IS-063 tasarımı "çalar düzeyinde bus" olur | AC1 test sonucu rapor; AC2 IS-063 AC'leri sonuca göre yazılır |
| 16 | **P3** | XS | arayuz | **KR-025 kayıt rehberi `docs/notes/ses-kayit.md`** (§4 adımları, dosya adı kuralı, rıza satırı) + `sfx_prep.py` "vo" ön ayarı (−18 LUFS / −1 dBTP / HPF 80 Hz) | AC1 rehber 1 sayfa; AC2 `sfx_prep.py --preset vo` LUFS raporu ±1 LU; AC3 örnek dosya kataloğa Randomizer ile bağlanır |
| 17 | **P3** | S | arayuz | **Müzik v0 (Faz 4):** A pad + stinger + 4 sn sessizlik; `core/music_rules.gd`; Synchronized 3 stem iskeleti (B/C boş stem'le), tween ≤ 1 dB/50 ms; pop testi kulakla, B planı belgeli | AC1 birim: kademe/tespit → dB tablosu; AC2 kesme ≤ 0,3 sn (FakeClock); AC3 Music kaydırıcısı (IS-060) etkiler |

### Karar gereken
- **KR-024 (3 satırlık özet §3):** ElevenLabs Starter 1 ay (~5-6 $) ana + Stable Audio 3 Small SFX yerel yedek; her ikisi Steam beyanı. (Varsayılanla yer tutucuyla ilerlenebilir.)
- **KR-025:** kullanıcı/arkadaş kaydı (rehber §4) — öneri değişmedi; Piper fahrettin/fettah CC0 çıktı ama yalnız yer tutucu kalitesinde.
- **Duyulma çarpanı 2× → 3× (tasarım; ses-ve-sfx §6 AC3):** test-2 A/B'den sonra; şimdilik 2× + kenar işareti.
- **Erişilebilirlik varsayılanı:** ekran dışı gösterge kapatılamaz oyun bilgisi mi (öneri: evet), yoksa yalnız ayar mı?
- **Müzik kaynağı (Faz 4):** CC0 pad + Kenney stinger (öneri) / Stable Audio 3 Small Music (ücretsiz, beyan) / Eleven Music (plan kademesi doğrulanmalı).

### Bir sonraki tur için açık sorular
- IS-061 sonrası kulak ölçümü: `attenuation` 1,5-2,0 ve çarpan 2/3 ile "halka sınırı duyuluyor mu"; panning 0,75 hareket hastalığı.
- #118498 4.7.2'de gerçek davranış (IS-062 ön kontrolü); Polyphonic yerine sahip başına 2 çalar havuzu daha mı ucuz?
- Örtme (IS-063) + kenar işareti: duvar arkası ekran dışı ses için işaret "kısık" mı gösterilsin (opaklık ×0,5)?
- Eleven Music model-specific terms (plan kademesi) ve Stable Audio 3 inpainting ile stem türetme denemesi.
- Kenar işareti ile GDD §6.5 "kenar oku" (ekip arkadaşı) aynı bileşen olabilir mi (tek `EdgeMarker`)?

### Kaynaklar (tur 2)
[39] Game Informer — Afterwords: Mark of the Ninja (halka = duyulma yarıçapı): https://gameinformer.com/b/features/archive/2012/10/15/afterwords-mark-of-the-ninja.aspx
[40] Mark of the Ninja ses halkaları (GamesBeat önizleme): https://gamesbeat.com/mark-of-the-ninja-preview/
[41] Monaco "noise maker" ve ses halkaları (Uppsala oyun tasarımı blogu): https://babel.speldesign.uu.se/?p=6028
[42] Game Accessibility Guidelines — tam liste (Hearing bölümü): https://gameaccessibilityguidelines.com/full-list/
[43] Xbox Accessibility Guidelines 103 — Multisensory cues: https://devdocs.xbox.com/gaming/accessibility/xbox-accessibility-guidelines/103
[44] Can I Play That — Deaf/HoH erişilebilirlik rehberi (Fortnite visualize sound effects, AC Odyssey, Metro): https://caniplaythat.com/basic-accessibility-options-for-deaf-hoh-players/
[45] Minecraft Wiki — Subtitles (ekran dışı `<`/`>` ok, solma): https://minecraft.wiki/w/Subtitles
[46] Godot issue #88941 — AudioStreamPlaybackPolyphonic `finished` yok (açık): https://github.com/godotengine/godot/issues/88941
[47] Godot issue #123398 — Polyphonic `get_playback_position` 0 döner (2026-09): https://github.com/godotengine/godot/issues/123398
[48] ElevenLabs pricing (Free 10k / Starter 30k / Creator 121k kredi; 2026-10): https://elevenlabs.io/pricing
[49] ElevenLabs API — Sound generation (`/v1/sound-generation`, parametreler, formatlar): https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert
[50] Stability AI — Stable Audio 3 duyurusu (Small SFX/Small/Medium açık ağırlık, Community License, < 1 M$): https://stability.ai/news-updates/meet-stable-audio-3-the-model-family-built-for-artistic-experimentation-with-open-weight-models
[51] HF model kartı — stable-audio-3-small-sfx-base (lisans, veri: AudioSparx + Freesound CC0/CC-BY/Sampling+, M4'te birkaç sn): https://huggingface.co/stabilityai/stable-audio-3-small-sfx-base · gated model: https://huggingface.co/stabilityai/stable-audio-3-small-sfx
[52] GitHub Stability-AI/stable-audio-3 (kurulum `uv`, VRAM tablosu, CPU/TFLite, CLI): https://github.com/Stability-AI/stable-audio-3
[53] TangoFlux LICENSE.md (araştırma/akademik, WavCaps şartı): https://huggingface.co/declare-lab/TangoFlux/blob/main/LICENSE.md · MMAudio CC-BY-NC: https://huggingface.co/hkchengrex/MMAudio
[54] Adobe Firefly ses araçları GA (universally licensed; ortak modeller kapsam dışı): https://itwire.com/business-it-news/business-software/adobe-makes-firefly-a-full-audio-studio-and-the-licence-is-the-actual-product · ürün açıklaması: https://helpx.adobe.com/nz/legal/product-descriptions/adobe-firefly.html
[55] Piper tr_TR fettah / fahrettin MODEL_CARD (CC0, NabuCasa voice-datasets): https://huggingface.co/rhasspy/piper-voices/blob/6fb8245d6d27fef8988272e0c8e9f5018da1bbbf/tr/tr_TR/fettah/medium/MODEL_CARD · VOICES.md: https://github.com/rhasspy/piper/blob/master/VOICES.md
[56] HF ResembleAI/chatterbox (MIT, 23 dil, `tr`): https://huggingface.co/ResembleAI/chatterbox
[57] Google Cloud TTS lisans tartışması (çıktı ticari; rakip TTS eğitimi yasak): https://discuss.google.dev/t/text-to-speech-api-license/187973 · Chirp 3 HD tr-TR: https://docs.cloud.google.com/text-to-speech/docs/chirp3-hd
[58] Audacity manual — Loudness Normalization (LUFS, −23 varsayılan, dual-mono): https://manual.audacityteam.org/man/loudness_normalization.html · ffmpeg-normalize (loudnorm iki geçiş): https://github.com/slhck/ffmpeg-normalize
[59] Ev kaydı: dolap/battaniye (Laptop Mag): https://laptopmag.com/how-to/voiceover-studio · telefonla VO (grumomedia): https://grumomedia.com/how-to-record-great-voiceover-audio-with-an-iphone/
[60] Godot docs — AudioStreamPlaybackInteractive (`switch_to_clip`): https://docs.godotengine.org/en/stable/classes/class_audiostreamplaybackinteractive.html
[61] Godot PR #106979 — Synchronized ses düzeyi değişiminde pop/klik (açık): https://github.com/godotengine/godot/pull/106979
[62] Godot PR #109381 — synced audio iç playback erişimi (açık): https://github.com/godotengine/godot/pull/109381 · Interactive PR'ları #122956, #121952; issue #88133
[63] Pixabay Content License özeti: https://pixabay.com/service/license-summary/
[64] ElevenLabs — Eleven Music (gaming; plan başına haklar music-terms'te): https://elevenlabs.io/docs/capabilities/music · https://elevenlabs.io/music-terms
[65] AI müzik lisansları 2026 (Suno/Udio/Eleven; üçüncü taraf, 2026-02): https://licenseorg.com/blog/ai-music-licensing-suno-elevenlabs
[66] HF stabilityai/stable-audio-3-small-music (açık ağırlık): https://huggingface.co/stabilityai/stable-audio-3-small-music
[67] Godot kaynak 4.7 — `modules/multiplayer/scene_replication_interface.cpp` (spawn-state `_ready` öncesi; görünürlükte `last_watch_usecs` yok → ilk delta tüm izlenenler): https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/scene_replication_interface.cpp
[68] Godot kaynak 4.7 — `modules/multiplayer/multiplayer_synchronizer.cpp` (`get_delta_state`, `Watcher.last_change_usec` ilk izlemede kurulur): https://github.com/godotengine/godot/blob/4.7/modules/multiplayer/multiplayer_synchronizer.cpp
[69] Godot docs — MultiplayerSynchronizer (`synchronized`/`delta_synchronized` özellikler yazıldıktan sonra): https://docs.godotengine.org/en/stable/classes/class_multiplayersynchronizer.html
[70] Godot docs — SceneReplicationConfig (`property_set_spawn`, ReplicationMode): https://docs.godotengine.org/en/stable/classes/class_scenereplicationconfig.html
[71] Godot issue #118498 — Polyphonic `play_stream` bus parametresi yok sayılıyor (4.3/4.6.2/4.7.dev4; açık): https://github.com/godotengine/godot/issues/118498
