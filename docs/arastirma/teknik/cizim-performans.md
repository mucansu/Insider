# Teknik araştırma: cizim-performans (Godot 4.7 2D çizim ve performans, Compatibility / GL 3.3)

İşaretler: **[O]** olgu (kaynaklı ya da bu turda ölçülmüş) · **[G]** görüş/değerlendirme · **[?]** doğrulanmadı. Sürümler kaynağıyla; Godot 4.7.2'ye uymayan bilgi "eski" diye işaretli. Hedef: 3 oyuncu + 6 NPC, 60 fps, eski/tümleşik GPU'lu arkadaş makineleri, ileride Steam Deck.

---

## Tur 1 — 2026-10-02

### 1. Kapsam
Compatibility renderer'da 2D batching davranışı ve tuzakları; `_draw` vs Polygon2D/MeshInstance2D/MultiMesh; CanvasItem sayısı; TileMapLayer'a geçiş sorusu; sis (fog-of-war) yöntemleri ve maliyetleri; Light2D/LightOccluder2D'nin Compatibility'deki durumu; CanvasModulate + ADD ışık havuzları; parçacıklar (CPU/GPU); profil alma (editör, `--print-fps`, RenderingServer, headless); Steam Deck / düşük GPU ayarları; ölçek (1,5 yakınlaştırma, 64 px/karo asset), piksel kesinliği ve doku süzgeci.

### 2. Mevcut durum (dosya:satır)
- **Renderer/ayar:** `project.godot:140-141` `gl_compatibility` (masaüstü + mobil); `:33-34` stretch `canvas_items` + `expand`; 1280×720 taban. Doku süzgeci/snap/MSAA ayarı yok → 4.7.2 varsayılanları (bu turda headless ölçüldü) [O]: `default_texture_filter = 1` (Linear, mipmap yok), `default_texture_repeat = 0`, `snap_2d_transforms_to_pixel = false`, `snap_2d_vertices_to_pixel = false`, `msaa_2d = 0`, `hdr_2d = false`, `gl_compatibility/item_buffer_size = 16384`, `nvidia_disable_threaded_optimization = true`, `fallback_to_angle = true`, `2d/shadow_atlas/size = 2048`, `vsync_mode = 1`, `max_fps = 0`, `thread_model = 1`.
- **Seviye çizimi:** `levels/level_layout.gd` tek `Node2D` (`Tiles`, `build_levels.gd:59-60`) ve tek `_draw` (`:174-181`): her karo için `_draw_cell` (`:184-200`) → zemin `draw_rect` + cam şeridi `draw_rect` + sınır karosunda 7 çapraz `draw_line` (genişlik 2; `:218-225`) + duvar kenarı/bordür `draw_rect`'leri; sonra raf/tezgâh dolgu + 1 px dış çizgi + bölme çizgileri (`:242-261`). 30×20 = 600 karo (`levels/layouts/store_a.txt`). Yeniden çizim yalnız `rows` değişince (`:55-58`); yani CPU maliyeti tek seferlik, GPU/driver maliyeti her kare.
- **Oyuncu görseli (dev):** `entities/player/player_visual.gd:63-80` `draw_circle` ×2-3 (`antialiased = true`, `:71,73`) + `draw_colored_polygon`; `_process` yalnız durum değişince `queue_redraw` (`:55-60`).
- **Kukla (US-014, worktree `agent-a081…`):** `entities/player/puppet/puppet.gd:177-205` tüm parçalar `PuppetMesh` tamponunda toplanıp `RenderingServer.canvas_item_add_triangle_array` ile tek komut (`puppet_mesh.gd:62-77`), koşu tozu ayrı komut (`puppet.gd:210-216`); kenar yumuşatma kendi "tüy" halkasıyla (AA parametresi değil); segment sayısı ekran ölçeğine göre (`PIXEL_RATIO_STEP`, `puppet.gd:42,179-180`); indeks ve birim-daire önbellekleri statik. **Her kare** `queue_redraw` (`puppet.gd:106-110`), ekran dışı/hareketsiz ayrımı yok. Doku yuvası dolu parça tamponu böler (`:351-356`). Test: `tests/unit/test_puppet_scene.gd:275-295` komut sayısı ≤ 1 + toz.
- **Diğer çizimler:** `faz2-int/entities/fx/noise_ring.gd:67` `draw_arc` genişlik 3, `antialiased = true`, her kare yeniden çizim (0,4 sn ömür); US-008 worktree `entities/npc/components/npc_visual.gd:50-79` daire + yay + koni çokgeni + "?"/"!" + `draw_string` balon (kukla gelince yerini bırakır).
- **Sis (US-011a, worktree `agent-a9a34…`):** `entities/fx/fog_layer.gd` — `Shade` = seviye boyunda tek dörtgen + `fog_layer.gdshader` + 30×20 RGBA8 veri dokusu (`_rebuild_texture` `:304-315`, `_upload` `:319-332` `ImageTexture.update`), `Outline` = görünmeyen karolarda duvar kenarı rect'leri + kapı kesik çizgisi, **her değişimde tüm ızgara** yeniden (`_draw_outline` `:342-357`); geçişte `_process` 1800 float döngüsü + her kare upload (`:241-257`); ölçüm `stats()` (`update_ms_avg`, `rays_per_update`, `:205-215`). `core/vision_grid.gd:188-233` karo başına fizik ışını (`Perception.has_line_of_sight`), 8-komşuluk kuralı, her güncellemede `_states.duplicate()` + tam tarama (`_commit` `:253-266`).
- **Kamera/temizleme:** `entities/player/player.gd:204-221` zoom 1,5 + harita sınırı; `main.gd:56-57` temizleme rengi = ton BG.
- **Ölçüm altyapısı:** testlerde `Time.get_ticks_usec` (CPU); `Puppet.draw_stats()`; IS-022 ekran görüntüsü. `Performance` monitörleri, `--print-fps`, `viewport_set_measure_render_time` kullanılmıyor; hedef makinelerden (arkadaşlar) performans verisi toplanmıyor.

### 3. Bu turun ölçümü (4.7.2, Windows, Ryzen 5 5600 + Radeon RX 6650 XT, 1280×720 pencere, gl_compatibility, vsync kapalı; scratchpad betiği, projeye girmedi) [O]

| Senaryo | draw call | nesne | ilkel | kare | render CPU / GPU |
|---|---|---|---|---|---|
| 600 `draw_rect` | **1** | 600 | 1200 | 0,18 ms | 0,07 / 0,08 |
| 600 rect + 700 kalın `draw_line`, **gruplu** (önce rect'ler) | **2** | 2000 | 2600 | 0,24 ms | 0,18 / 0,08 |
| aynı komutlar **karışık** (rect, line, rect, line…) | **1200** | 1800 | 2400 | 2,79 ms | 1,15 / 1,48 |
| 600 `draw_circle` (dolu) | 600 | 600 | 38 400 | 1,28 ms | 0,72 / 0,28 |
| 100 `draw_arc` genişlik 3 **AA** | **300** | 300 | 13 800 | 0,44 ms | 0,32 / 0,08 |
| 600 `draw_rect` **AA** | **1200** | 10 200 | 10 800 | 2,90 ms | 2,06 / 1,63 |
| 600 `draw_texture_rect` tek doku | 1 | 600 | 1200 | 0,16 ms | 0,08 / 0,09 |
| 600 `draw_texture_rect` iki doku dönüşümlü | **600** | 600 | 1200 | 1,00 ms | 1,04 / 0,10 |
| 600 rect, kamera zoom 4 (çoğu ekran dışı) | 1 | **600** | 1200 | 0,16 ms | — |
| **store_a** (Tiles + props), zoom 1 ve 1,5 (aynı) | **218** | 2291 | 3162 | 0,60 ms | 0,37 / 0,27 |
| store_a, `Tiles` gizli | 6 | 6 | 30 | 0,13 ms | 0,04 / 0,05 |
| store_a + **9 kukla koşuyor** | 229 | 2302 | 9296 | **1,90 ms** | 0,33 / 0,33 |
| store_a, kuklalar gizli + durmuş | 218 | 2291 | 3162 | 0,57 ms | 0,35 / 0,25 |

Okuma: (1) `Tiles` tek başına **212 draw call** üretiyor; aynı komutlar gruplu olsa ~3-5 olurdu (karışık rect/line deneyi 1200'e karşı 2). (2) Kamera yakınlaşınca nesne sayısı değişmiyor → **komut başına kırpma yok**, tüm harita her kare gönderiliyor. (3) 9 koşan kukla = +11 draw call ve bu masaüstü CPU'da **+1,3 ms** (≈ 0,15 ms/kukla, GDScript rig + tampon); koordinatör notu "4 kukla 1,79 ms" (US-014, başka makine/yöntem) ile uyumlu büyüklük. GPU tarafı ihmal edilebilir. (4) Çokgen (daire, yay, polyline, triangle_array) = komut başına bir draw call; AA parametresi yayı 3'e, rect'i rect+8 ilkel'e çeviriyor ve batch'i kırıyor.

### 4. En iyi uygulamalar ve seçenekler

#### 4.1 Compatibility'de 2D batching: nasıl çalışır, ne kırar
- **[O]** Batching Compatibility'de 4.0'dan beri var; 4.4 aynı batching'i Forward+/Mobile'a getirdi (4.4 sürüm notu). 4.5-4.7'de 2D çizim yolunda büyük değişiklik yok; 4.7 kırılması: `CanvasItem` çizgilerde AA tüyünü artık kalınlığa eklemiyor (GH-105122) — çizgiler eskisinden ince görünebilir.
- **[O, kaynak kodu `drivers/gles3/rasterizer_canvas_gles3.cpp` 4.7]** Rect/NinePatch `glDrawElementsInstanced`, ilkel (çizgi, 2-4 nokta) `glDrawArraysInstanced` ile **instancing** batch'i; **çokgen, mesh, multimesh, parçacık batch'lenmez** ("Polygon's can't be batched, so always create a new batch"), her biri kendi vertex dizisiyle ayrı çağrı. Batch şu değişimlerde kırılır: materyal/shader, doku, blend kipi, doku süzgeci, doku tekrarı, ışık durumu (`light_mask`/ışıksız), clip sahibi, **komut türü** (rect → ilkel → rect) ve **ilkel nokta sayısı** (2 noktalı ince çizgi ↔ 4 noktalı kalın çizgi). CanvasItem sınırı batch'i **kırmaz**: aynı doku/materyalli ardışık düğümler tek çağrıda gider. Instance tamponu `item_buffer_size` (16384) dolunca yeni tampon; renk (modulate) instance verisidir, kırmaz.
- **[O]** Kırpma (culling) **CanvasItem dikdörtgeni** düzeyindedir (`renderer_canvas_cull.cpp` `_cull_canvas_item`; komut başına kırpma yok) — ölçümde doğrulandı. Tek büyük `_draw` düğümü ekranın dışındaki komutlarını da her kare gönderir; parçalı düğümler (TileMapLayer'ın 16×16 "quadrant" canvas item'ları gibi) kırpılır.
- **[O]** Kalın `draw_line` (genişlik ≥ 0) 4 noktalı **ilkel**, negatif genişlik 2 noktalı ilkel (CanvasItem belgesi); `draw_multiline`/`draw_dashed_line` kalınken parça başına ilkel; `draw_polyline`, `draw_arc`, `draw_circle`, `draw_polygon`, `draw_colored_polygon`, `canvas_item_add_triangle_array` → **çokgen** (ayrı çağrı); `antialiased = true` rect'e 8 ilkel, çokgene 1-2 tüy çokgeni ekler (kaynak kodu + ölçüm).
- **Tuzak listesi [G, ölçümle]:** (a) rect ve çizgileri karo karo karıştırmak (bizim `_draw_cell`); (b) `antialiased` parametresi; (c) birden çok doku/atlas (karo seti tek atlasta olmalı); (d) her düğüme ayrı `ShaderMaterial` (aynı shader + farklı uniform bile ayrı materyal = kırılma; `use_parent_material` ya da instance uniform'u yoksa modulate ile çözülür); (e) çok sayıda küçük çokgen (daire tabanlı yer tutucular: NPC başına 5-8 çağrı); (f) `z_index` farklı dokulu öğeleri araya sokarak sırayı karıştırır (kırılma sayısı artar) [G].
- Draw call maliyeti: GL'de her komut sürücüde doğrulama ister (GPU optimizasyonu belgesi) [O]; bizim masaüstünde ~1 µs/çağrı ölçüldü (1200 çağrı ≈ +2,6 ms kare), eski Intel/AMD GL sürücülerinde çağrı başına 5-30 µs tipik [G, deneyim; ölçüm yok] → 200 çağrı 1-6 ms, 1200 çağrı kare bütçesini yiyebilir. Bu yüzden hedef: oyun sahnesinde **< 50 draw call** [G].

#### 4.2 `_draw` vs Polygon2D vs MeshInstance2D vs MultiMeshInstance2D (prosedürel geometri)
| Yol | Ne | Artı | Eksi | Bize |
|---|---|---|---|---|
| `_draw` + `canvas_item_add_triangle_array` (mevcut kukla) | Kare başına tampon kur, tek çokgen komutu | 1-2 draw call/kukla [O ölçüm]; komutlar önbelleklenir, yalnız `queue_redraw`'da yeniden kurulur; düğüm yok | Geometri her kare GDScript'te (0,15 ms/kukla bu CPU'da) | Doğru seçim; maliyet CPU'da, GPU'da değil |
| `MeshInstance2D` + `ArrayMesh` | Mesh kaynağını her kare yeniden yükle | Tek çağrı; forumda "şaşırtıcı hızlı" [O, forum] | Her güncelleme `surface_remove + add_surface_from_arrays` (kaynak nesnesi yeniden kurulur); kazanım yok, API daha hantal | Gerekmez |
| `Polygon2D` | Düğüm; `polygon` değişince CPU üçgenleme | Editörde görünür | Üçgenleme pahalı (büyük çokgenlerde saniyeler, forum) [O]; parça başına düğüm | Yer tutucu dışında hayır |
| `MultiMeshInstance2D` | Aynı mesh'in yüzlerce kopyası, tek çağrı; `multimesh_set_buffer` ile tüm dönüşümler bir dizi | Yüzlerce aynı şekil (toz, yağmur, kalabalık silueti) için ideal; Compatibility'de destekli [O] | Kopya başına özel şekil yok; az sayıda (< 50) öğede getirisi yok | Toz/yağmur gibi "çok aynı parça" gelirse |

Kukla için asıl kaldıraç CPU: (i) ekran dışı / görünmeyen (sis) kuklada `queue_redraw` ve rig güncellemesini atlamak (`VisibleOnScreenNotifier2D` ya da kamera dikdörtgeni; atkı/yay durumunu dondurup "ışınlanma" yoluyla yeniden kurmak zaten var, `puppet_rig.gd:113-114`); (ii) uzak/hareketsiz kuklada 30 Hz güncelleme; (iii) `pixel_ratio` adımı zaten var. Hedef bütçe: 9 kukla ≤ 2 ms zayıf dizüstü CPU'da [G]; ölçüm için `draw_stats` + kare süresi dökümü (§4.8).

#### 4.3 CanvasItem sayısı
- Düğüm sayısı 10-20 varlıkta sorun değil; sorun olan (a) binlerce küçük düğüm (her biri ağaç/transform/kırpma maliyeti) ve (b) tersine tek dev düğüm (kırpılmaz). Orta yol: dünya statik katmanını **parçalara** (ör. 8×8 karo = 256 px) bölmek; TileMapLayer bunu `rendering_quadrant_size` (varsayılan 16) ile kendisi yapar [O, sınıf belgesi].
- Bakkal (600 karo) için parçalama gereksiz; T2+ haritalar 60×40 ve üstüne çıkarsa (2400+ karo) ya parçalı `_draw` ya TileMapLayer [G].

#### 4.4 TileMapLayer'a geçmeli miyiz?
- **[O]** TileMapLayer (4.3'te `TileMap` katmanlarının yerine) karoları quadrant başına tek canvas item'da toplar (rect batch'i, atlas tek doku → birkaç draw call), quadrant'lar kırpılır; `physics_quadrant_size` ile çarpışma şekillerini birleştirir; navigasyon ve ışık oklüderleri karo verisinden gelir; `update_internals()` pahalıdır (sık karo değişimi kötü; bizim harita statik). Y-sort açılırsa quadrant batch'i Y'ye göre bölünür.
- Bizim durum: ızgara zaten veri (`rows`), çizim kodla yer tutucu; `build_levels.gd` çarpışma/navigasyon/işaretleri kendi üretiyor. Şu an TileMapLayer **kazandırmaz** (kırpma ve atlas yok ki kazansın); getirisi dokulu karo seti (sanat-yonu.md §7 kalem 2: 4 zemin + duvar + cam + kapı, 64 px/karo) geldiğinde başlar: terrains/autotile ile duvar kenarı-bordür-köşe otomatik, editörde görülebilir, quadrant kırpma, tek atlas.
- Seçenekler [G]: (A) `LevelLayout._draw` kalır, `draw_texture_rect_region` ile atlastan çizer (tek doku → 1-3 çağrı; kod kontrolü; kırpma yok; kenar/köşe mantığı elle) — en az değişiklik. (B) `Tiles` düğümü `TileMapLayer` olur, `build_levels.gd` `rows`'tan `set_cell` yazar (TileSet `.tres` tek kaynak, terrain set'leriyle kenarlar); `LevelLayout` ızgara/`kind_at`/`merged_rects` API'si olarak kalır (çarpışma/nav üretimi değişmez), yalnız `_draw`'ı kalkar; `--placeholder-art` yolu için `_draw` korunabilir. S4 "Tiles (LevelLayout)" ifadesi değişir → **karar gereken**. (C) İkisi: TileMapLayer zemin/duvar, `_draw` kroki/sis çizgileri (zaten FogLayer'da). Öneri: asset seti kalemiyle birlikte (B); öncesinde dokunma.

#### 4.5 Sis (fog-of-war) yöntemleri ve maliyetleri
| Yöntem | Maliyet (CPU / GPU) | Hafıza katmanı | Headless test | Not |
|---|---|---|---|---|
| **Karo ızgarası + veri dokusu + shader (mevcut US-011a)** | CPU: ~254 fizik ışını / 100 ms (`intersect_ray` 3-10 µs → 1-2,5 ms/güncelleme ≈ 0,1-0,25 ms/kare amorti) [G]; GPU: tam ekran 1 çağrı, N doku örneği/piksel | Doğal (dizi) | Evet (dizi) | KR-023 ile uyumlu; kenar yumuşatma veri dokusunun **LINEAR** süzgeci (`fog_layer.gd:70`) + shader'da ucuz |
| Izgara gölge-dökümü (symmetric shadowcasting) yerine fizik ışını | CPU: fizik yok, O(yarıçap içindeki karo), rasyonel aritmetik, deterministik, simetrik ("A B'yi görüyorsa B A'yı görür") [O, Ford] | Aynı dizi | Evet | Kapı/cam durumu ızgaraya yazılmalı (PORTAL hücresi güncelle); karo-altı geometri (cam şeridi 6 px) kaybolur; yalnız AC9 (≤ 1 ms) hedef makinede tutmazsa [G] |
| Görüş çokgeni (Red Blob tarama) + kalıcı SubViewport maskesi | CPU: duvar uç noktası başına O(n log n) (bakkal ~200 kenar → ucuz) [O]; GPU: ek viewport geçişi her kare (tümleşik GPU'da dolgu maliyeti), kalıcı hedefte biriktirme | GPU dokusunda → NPC görünürlük kararı için ayrıca ışın/örnekleme | Hayır (render yok) | Pürüzsüz kenar; iki sistem (Fable §5 ile aynı sonuç) |
| Light2D + LightOccluder2D (gölge = görüş) | Işık geçişi + oklüder gölge çizimi (nokta ışık 4 yön) her kare; `shadow_atlas/size` 2048 | Yok | Hayır | Compatibility'de çalışır [O] ama "görülmüş ama şimdi değil" yok; KR-023 dışı |

Mevcut yolun ince ayarları [G]: `edge_blur_px` örnek sayısını ≤ 9 tut (1080p'de 2 Mpx × örnek); `_draw_outline` tüm ızgarayı değil yalnız değişen karoları çizmek yerine basitçe parçalı (quadrant) `Outline` düğümleri — bakkalda gereksiz, büyük haritada; `_upload` yalnız `_animating` iken çalışıyor (doğru); `VisionGrid.update` 600 karelik `duplicate` + tam tarama ≈ 0,1-0,3 ms GDScript [?] — `stats().update_ms_avg` ölçüyor, AC9 var. Işın sayısı artarsa (288 px yarıçap → 254) güncellemeyi iki kareye yaymak (yarım daire/kare) mümkün.

#### 4.6 Light2D / LightOccluder2D Compatibility'de
- **[O]** Belge (2D ışık ve gölge) ve 4.7 GLES3 kaynak kodu: PointLight2D/DirectionalLight2D, ADD/SUB/MIX, gölge (PCF yok/5/13), CanvasModulate, LightOccluder2D hepsi Compatibility'de var; öğe başına ışık sınırı (`max_lights_per_item`), kare başına `max_lights_per_render`, gölge atlası 2048. Işık geçişi: ışık ulaşan her öğe için piksel başına ek iş; gölgeli nokta ışık oklüderleri 4 yönde ayrı geçişle çizer; PCF13 "yalnız birkaç ışıkta". Belge açıkça: **"ek (additive) sprite'lar çok daha hızlıdır, ayrı çizim hattından geçmez."** Işık batch'i de kırar (ışık durumu değişimi).
- Uygunluk: sanat-yonu.md §3 planı (CanvasModulate + ADD sprite havuzları, Light2D yalnız 1-3 hareketli ışık, gölgesiz) **doğru**. CanvasModulate tek uniform, sıfır maliyet [O]. ADD sprite'lar aynı dokuyu paylaşırsa tek batch (blend kipi değişimi 1 kırılma). Kabul ölçütü olarak `viewport_get_measured_render_time_gpu` ≤ +0,5 ms (sanat-yonu kalem 4) ölçülebilir (§4.8).

#### 4.7 Parçacıklar
- **[O]** `GPUParticles2D` Compatibility'de çalışır (OpenGL3'e transform feedback ile eklendi; sürüm 4.3 civarı [?]) ama `emit_particle` yalnız Forward+/Mobile (sınıf belgesi), **trail ve alt-emitter yok** (renderers belgesi: Compatibility'de "particle trails" yok); her parçacık düğümü batch'i kırar (parçacık = mesh yolu). `CPUParticles2D` her yerde çalışır, az parçacıkta (yüzler) ucuz; belge "GPU'yu tercih et, ancak düşük uçta/GPU darboğazında CPU daha iyi olabilir".
- Bize: kukla tozu zaten tamponda (düğüm yok, doğru). Ortam etkisi (yağmur, buhar; sanat-yonu "ikindi, yağmurlu") gelirse: **tek** `CPUParticles2D` ya da kaydırmalı doku; NPC/oyuncu başına parçacık düğümü açma [G].

#### 4.8 Profil alma
- **[O]** Araçlar: `--print-fps` (stdout'a FPS); `--gpu-profile`; editör Debugger → Profiler, **Monitors** (otomatik kayıt, sonradan açılabilir), **Visual Profiler** (Compatibility'de destekli, macOS hariç); `Performance.get_monitor` → `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_*_MEM_USED` (bazıları release'de 0); `RenderingServer.viewport_set_measure_render_time(vp, true)` + `viewport_get_measured_render_time_cpu/gpu`, `get_frame_setup_time_cpu` (ölçümde çalıştı, 4.7.2); `Engine.get_frames_per_second`. GDScript tarafı: `Time.get_ticks_usec`, 1000+ tekrar (CPU optimizasyonu belgesi).
- **[O]** `--headless` tüm çizimi kapatır → RENDER_* sayaçları ve render süreleri anlamsız; headless'ta yalnız CPU süreleri (VisionGrid, rig, ağ) ölçülür — bizim test düzeni zaten böyle. Çizim maliyeti ancak pencereli koşuda (IS-022 `tools/screenshot.py` düzeni) ya da arkadaş makinelerinden gelen dökümle görülür.
- Önerilen düzen [G]: geliştirici argümanı `--perf` → döküm anahtarı `"render"` = {adapter, driver, window, draw_calls_avg/max, objects, primitives, frame_ms p50/p95, render_cpu_ms, render_gpu_ms, process_ms, physics_ms, fps_min}; `tests/perf/` pencereli senaryo (host + 2 bot + 6 NPC, 30 sn) CI dışı; arkadaş test checkpoint'inde dev build'in otomatik koşu JSON'u (KR-019) bu anahtarı taşır → gerçek hedef donanım verisi.

#### 4.9 Steam Deck ve düşük GPU ayarları
- **[O]** Steam Deck: 1280×800 (16:10), RDNA2 "Van Gogh", ~GTX 1050 sınıfı; Linux/SteamOS, Godot'un Linux kontrolcü desteği aynen geçer (kodeco; forum 4.7.1). Compatibility belgesi: "eski/düşük uç donanım, en geniş uyumluluk; 2D için genellikle yeterli"; Compatibility'de **MSAA 2D yok**. Windows'ta yerli GL başarısız olursa ANGLE'a düşme varsayılan açık (`fallback_to_angle = true`) → eski/bozuk Intel sürücülü dizüstülerde D3D11 üzerinden çalışır [O ayar, davranış G].
- Ölçek ve dolgu [G]: `canvas_items` modu hedef çözünürlükte çizer → 1080p'de piksel sayısı 720p'nin 2,25 katı; tam ekran sis shader'ı ve ADD havuzları dolgu maliyeti taşır; tümleşik GPU'da 1080p'de sorun çıkarsa seçenek `display/window/stretch/mode = viewport` (taban 1280×720'de çiz, ölçekle; metin dahil yumuşar) ya da fog shader örnek sayısını düşürmek. `aspect = expand` 16:10'u zaten karşılar (Deck'te 1280×800 → dikeyde +80 px dünya görünür; sis yarıçapı 288 < yarım ekran, sorun yok).
- Ayarlar menüsü adayları: V-Sync (aç/kapa), `max_fps` 60/120 (pil), hareket azaltma (var). "Düşük grafik" kipi = ışık havuzları kapalı + sis kenar yumuşatma 0 [G].

#### 4.10 Ölçek, piksel kesinliği, doku süzgeci
- Dünya 32 px/karo, zoom 1,5 → 720p'de 48 px, 1080p'de (canvas ölçeği ×1,5) 72 px ekran. 64 px/karo asset: 720p'de **küçültme** (0,75), 1080p'de hafif büyütme (1,125). Küçültmede mipmap'siz Linear süzgeç titreşim/örnekleme gürültüsü yapar → `rendering/textures/canvas_textures/default_texture_filter = 2` (Linear Mipmap) ve dünya asset'lerinde içe aktarmada mipmap üretimi [G, belge: LINEAR_WITH_MIPMAPS "küçültülebilecek piksel-dışı sanat için önerilir"]; anisotropic 2D'de "nadiren yararlı" [O]. Bellek artışı ihmal edilebilir (küçük atlas).
- Piksel sanatı değiliz (KR-017): `snap_2d_*` **kapalı kalsın**; snap + kamera yumuşatma titremeye yol açıyor (forum/bugnet 2025-26) [O]; kesirli zoom (1,5) ve zoom darbesi (oyun-hissi.md) Linear süzgeçle sorunsuz. Kukla kendi tüy halkasıyla AA yapıyor (ölçek bağımsız, batch dostu) — diğer `draw_*` çağrılarında `antialiased` yerine aynı yaklaşım ya da AA'sız kalınlık [G].
- Metin: `canvas_items` modunda yazı tipleri hedef ölçekte rasterize edilir (keskin) [O belge]; Label'lar aynı font atlasını paylaştığı için batch'lenir.

### 5. Uygunluk değerlendirmesi
- Renderer seçimi (Compatibility) hedef kitleye (eski/tümleşik GPU, ileride Deck) uygun; eksikleri (MSAA 2D, trail, compute) bu oyunu etkilemiyor [G].
- Kukla yaklaşımı (tek üçgen dizisi, kendi AA'sı, segment ölçeklemesi) Compatibility batching'inin ne yapıp ne yapamadığına tam oturuyor; maliyet GDScript CPU'sunda ve kontrol altında (draw_stats testi).
- Sis tasarımı (karo ızgarası + veri dokusu + tek shader) KR-023'ü en ucuz yolla gerçekliyor; ölçüm kancaları (AC9) baştan var.
- Seviye çizimi işlev olarak doğru ama **komut sırası** Compatibility'nin batch kurallarına ters (212 çağrı); bu, projedeki en büyük tek çizim maliyeti ve düzeltmesi XS.

### 6. Bulgular
**Doğru yaptıklarımız**
- Tek `_draw` düğümüyle 600 karo (düğüm başına maliyet yok); Puppet tek komut; FogLayer tek dörtgen + veri dokusu `update()` (yeniden `create_from_image` değil — belge/forum tam bunu öneriyor); CanvasModulate + ADD planı; ışık mantığı ikili ve CPU'da (Light2D'ye bağımlılık yok); testlerde CPU ölçümü; hareket azaltma tek bayrak.

**Saptığımız yerler**
1. `level_layout.gd:184-200` rect/çizgi karışımı → store_a `Tiles` **212 draw call** (gruplu olsa ≤ 5). Düzeltme: `_draw`'ı iki geçişe ayır (önce tüm `draw_rect`'ler — zemin, cam, kenar, bordür, raf/tezgâh dolgusu — sonra tüm çizgiler; raf 1 px çizgileri ve bordür 2 px çizgileri ayrı nokta sayısı → iki ilkel grubu). Görsel çıktı birebir aynı (ressam sırası: çizgiler zaten rect'lerin üstünde).
2. `antialiased = true` kullanımı (`player_visual.gd:71,73` dev; `noise_ring.gd:67`) ve daire/yay tabanlı yer tutucular (`npc_visual.gd`): öğe başına 3-8 çağrı; şimdilik ucuz (≤ 10 öğe), kukla geçişiyle kalkar; kural olarak "AA parametresi yok, kalınlıkla çöz" [G].
3. Çizim ölçümü yok: hedef makinelerde draw call/kare süresi görülmüyor; `--print-fps` bile bağlı değil. Sanat/ışık/sis kalemlerinin "GPU ≤ +0,5 ms" kabulleri ölçülemez durumda.
4. Doku süzgeci/mipmap ayarı asset seti öncesi belirlenmemiş (varsayılan Linear, mipmap yok → 720p'de küçültme titreşimi gelecek).
5. Puppet her kare `queue_redraw` + rig güncellemesi, görünürlükten bağımsız; sis "görünmeyen NPC çizilmez" kuralı (US-011b) rig'i de atlamalı.
6. FogLayer `Outline` her karo değişiminde 600 hücre taraması; `VisionGrid.update` tam kopya + tarama — bakkalda ucuz, büyük haritada büyür (ölçüm kancası var, risk düşük).

**Riskler**
- Eski GL sürücülerinde draw call başına maliyet masaüstünün 5-30 katı [G] → 200+ çağrı tek başına bütçeyi aşabilir; ölçüm olmadan görünmez (3. sapma).
- GDScript rig + sis + algı CPU maliyeti zayıf dizüstü CPU'da birikir (9 kukla ~1,3 ms burada → ~3-4 ms orada [G]).
- 1080p + tam ekran shader + ADD havuzları tümleşik GPU'da dolgu sınırı [?].
- TileMapLayer geçişi S4 "Tiles" sözleşmesine dokunur; asset setiyle eş zamanlı planlanmazsa iki kez iş.

### 7. Öneriler
| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri (2-3) |
|---|---|---|---|---|---|
| 1 | **P1** | XS | seviye | **IS — LevelLayout çizim komutlarını batch dostu sırala** (rect geçişi + çizgi geçişi; tek `_draw` kalır) | AC1 store_a `Tiles` tek başına ≤ 8 draw call (pencereli ölçüm betiği/`--perf` dökümü); AC2 1280×720 ekran görüntüsü piksel-eş (IS-022 aracı, yer tutucu sanatta fark yok); AC3 `tests/unit/test_levels*` değişmeden geçer |
| 2 | **P1** | S | altyapi (+cekirdek döküm anahtarı) | **IS — Çizim/performans ölçüm kancası**: `--perf` argümanı + döküm `"render"` (Performance monitörleri, `viewport_get_measured_render_time_*`, kare p50/p95, adapter/driver) + `--print-fps` kullanım notu; pencereli perf senaryosu `tests/perf/` (CI dışı) | AC1 pencereli koşuda döküm `render.draw_calls_avg`, `frame_ms_p95`, `render_gpu_ms` dolu, headless'ta 0/atlanır; AC2 dev build otomatik koşu JSON'u (KR-019) bu anahtarı taşır; AC3 `ci_local` süresi değişmez |
| 3 | P2 | S | oynanis | **IS — Kukla CPU bütçesi**: ekran dışı/görünmeyen kuklada rig+redraw atlama, uzak hareketsiz kuklada 30 Hz; ölçüm `draw_stats` + `--perf` | AC1 9 kukla (3 oyuncu + 6 NPC) pencereli perf senaryosunda process ≤ 2 ms (referans: koordinatör makinesi, dizüstü varsa o); AC2 ekran dışına çıkıp dönen kuklada "pop" yok (ışınlanma yolu); AC3 `test_puppet_scene` komut sınırı korunur |
| 4 | P2 | XS | altyapi | **IS — Doku süzgeci ve içe aktarma ön ayarı**: `default_texture_filter = Linear Mipmap`, dünya asset'leri için import preset (mipmap açık, lossless), UI ikonları Linear | AC1 project.godot ayarı + `.import` şablonu; AC2 1280×720 ve 1920×1080 ekran görüntüsünde 64 px karo seti titreşimsiz (sanat kalemi 2 ile birlikte doğrulanır); AC3 `--import` uyarısız |
| 5 | P2 | M | seviye | **Karar gereken → TileMapLayer geçişi** (sanat-yonu kalem 2 ile birlikte; §4.4 seçenek B): `Tiles` = TileMapLayer, `build_levels.gd` `set_cell`, TileSet `.tres` tek kaynak, `LevelLayout` ızgara API'si kalır, `--placeholder-art` için `_draw` yolu | AC1 store_a dokulu karo seti ≤ 6 draw call, quadrant kırpma; AC2 `test_levels` ızgara–sahne tutarlılığı + çarpışma/nav üretimi değişmez; AC3 S4 metni güncel (koordinatör) |
| 6 | P3 | XS | koordinatör (mimari §6 kuralı) | **Karar gereken → çizim stil kuralı**: `draw_*` `antialiased` yasak (kalınlık ya da tüy), daire/yay yer tutucuları çokgen sayısı bilinciyle, tek atlas, düğüm başına ShaderMaterial yok | AC: `tests/unit` taraması (`antialiased\s*=\s*true` ve `draw_circle(` AA) entities/levels/ui'de 0 (kukla hariç) |
| 7 | P3 | S | seviye | **FogLayer ölçeklenme**: `Outline` parçalı (quadrant) düğümler + yalnız değişen parçaların redraw'ı; `edge_blur_px` örnek sayısı ≤ 9 | AC1 2400 karolu test haritasında `update_ms_avg` ≤ 1 ms, outline redraw ≤ 0,3 ms; AC2 görsel eş |
| 8 | P3 | XS | seviye (+altyapi ölçüm) | **Işık bütçesi kuralı** (atmosfer kalemiyle): ≤ 4 PointLight2D, gölge yok, PCF yok; ADD havuzları tek atlas | AC: `--perf` ile `render_gpu_ms` artışı ≤ 0,5 ms (sanat-yonu kalem 4 kabulü ölçülebilir olur) |

Sıra: 1 → 2 → (3 ∥ 4) → 5 (asset setiyle) → 6-8 ilgili kalemlerde.

### 8. Bir sonraki tur için açık sorular
- Arkadaş makinelerinin GPU/sürücü envanteri (Intel UHD? GL sürümü? ANGLE'a düşüyor mu?) — öneri 2'nin dökümü gelince: draw call başına gerçek maliyet ve 1080p dolgu sınırı.
- 1080p'de fog shader + ADD havuzları GPU süresi tümleşik GPU'da (ölçüm) [?].
- Sis ışınları: fizik `intersect_ray` mi, ızgara gölge-dökümü mü — AC9 hedef makinede tutuyor mu? Kapı/cam karo-altı geometrisi gölge-dökümünde kabul edilebilir mi (tasarım sorusu)?
- TileMapLayer geçişinin zamanı: asset seti v0 (sanat kalemi 2) ne zaman; S4 sözleşme değişikliği.
- Kamera: zoom darbesi/sarsıntı (oyun-hissi.md) ile Linear süzgeç/kesirli ölçek etkileşimi; Steam Deck'te 16:10 görünür alan farkının adalet etkisi (sis yarıçapı sabit → sorun yok [G], test).
- 4.8/5.0 yol haritasında 2D için kayda değer değişiklik var mı (bu turda 4.5-4.7 notlarında yok) [?].

### Kaynaklar
- Godot 4.7 geçiş notları: https://docs.godotengine.org/en/4.7/tutorials/migrating/upgrading_to_godot_4.7.html (CanvasItem çizgi AA tüyü GH-105122; parçacık `process_time_residual`)
- Godot 4.4 sürüm sayfası (batching Forward+/Mobile'a; Compatibility'de 4.0'dan beri): https://godotengine.org/releases/4.4/
- Godot 4.3 sürüm sayfası (Compatibility "feature complete", TileMapLayer, 2D fizik ara değerleme): https://godotengine.org/releases/4.3/ · 4.6: https://godotengine.org/releases/4.6/ · 4.7: https://godotengine.org/releases/4.7/
- GLES3 canvas renderer kaynak kodu (batch kırılma koşulları, çokgen/mesh ayrı çağrı, ışık geçişi): https://raw.githubusercontent.com/godotengine/godot/4.7/drivers/gles3/rasterizer_canvas_gles3.cpp
- Canvas cull (komut türleri, öğe düzeyinde kırpma): https://raw.githubusercontent.com/godotengine/godot/4.7/servers/rendering/renderer_canvas_cull.cpp
- CanvasItem sınıfı (texture_filter, genişlik/ilkel kuralı, draw_polygon notu): https://docs.godotengine.org/en/stable/classes/class_canvasitem.html
- TileMapLayer sınıfı (quadrant, update_internals): https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html
- MultiMeshInstance2D: https://docs.godotengine.org/en/stable/classes/class_multimeshinstance2d.html
- 2D ışık ve gölge (ek sprite önerisi, PCF maliyeti): https://docs.godotengine.org/en/stable/tutorials/2d/2d_lights_and_shadows.html · Light2D/PointLight2D sınıfları: https://raw.githubusercontent.com/godotengine/godot/4.7/doc/classes/Light2D.xml
- 2D parçacıklar: https://docs.godotengine.org/en/stable/tutorials/2d/particle_systems_2d.html · GPUParticles2D (emit_particle Compatibility'de yok): https://raw.githubusercontent.com/godotengine/godot/4.7/doc/classes/GPUParticles2D.xml
- Renderer'lar (Compatibility hedefi, MSAA 2D/trail yok): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- 2D kenar yumuşatma (MSAA 2D yalnız Forward+/Mobile): https://docs.godotengine.org/en/stable/tutorials/2d/2d_antialiasing.html
- Performance sınıfı (monitörler): https://docs.godotengine.org/en/stable/classes/class_performance.html · RenderingServer (get_frame_setup_time_cpu, custom_rect, triangle_array): https://raw.githubusercontent.com/godotengine/godot/4.7/doc/classes/RenderingServer.xml
- Debugger paneli (Visual Profiler Compatibility desteği, Monitors): https://docs.godotengine.org/en/stable/tutorials/scripting/debug/debugger_panel.html
- Komut satırı (`--print-fps`, `--gpu-profile`, `--headless`): https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- GPU optimizasyonu (draw call/durum değişimi, dolgu): https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html · CPU optimizasyonu: https://docs.godotengine.org/en/stable/tutorials/performance/cpu_optimization.html
- Çoklu çözünürlük (canvas_items vs viewport, scale_mode, mipmap): https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html
- ImageTexture (`update` vs `create_from_image`): https://docs.godotengine.org/en/stable/classes/class_imagetexture.html
- Symmetric shadowcasting (ızgara FOV, ışınsız): https://www.albertford.com/shadowcasting/ · 2D görüş çokgeni (tarama): https://www.redblobgames.com/articles/visibility/
- Steam Deck hedefleme (donanım): https://www.kodeco.com/41495624-targeting-the-steam-deck-with-godot · Godot forum 4.7.1 Deck: https://forum.godotengine.org/t/does-current-godot-engine-version-4-7-1-fully-support-valve-s-steam-deck-and-steam-machine/142477
- Pixel snap + kamera titreme (snap kapalı gerekçesi): https://bugnet.io/blog/fix-godot-camera2d-smoothing-jitter-on-pixel-snap · https://forum.godotengine.org/t/fine-tuning-camera-zoom-in-pixel-art/122564
- MeshInstance2D vs triangle_array forum deneyimi: https://godotforums.org/d/39548-how-to-draw-using-canvas-item-add-triangle-array · Polygon2D üçgenleme maliyeti: https://forum.godotengine.org/t/what-is-great-reading-material-on-multimeshinstance2d-videos-ok-too/139841
- Proje içi: `docs/tasarim/arastirma/gorus-sis-hafiza.md` §5, `docs/tasarim/arastirma/sanat-yonu.md` §3-4, `docs/surec/kararlar.md` KR-017/022/023, bu turun ölçüm betiği (scratchpad, projeye girmedi; öneri 2 kalıcı hâlini kurar).
