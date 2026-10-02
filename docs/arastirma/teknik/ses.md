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
