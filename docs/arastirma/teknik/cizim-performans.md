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

---

## Tur 2 — 2026-10-02

### 1. Kapsam
(1) Sis geçiş animasyonunu shader'a taşıma kalıbı ve veri dokusu güncelleme maliyeti (`ImageTexture.update` vs `RenderingServer.texture_2d_update`, "yalnız değişen texel") — Compatibility'de kaynak kodu + ölçüm; (2) AI üretimi 2D asset hattının teknik gereksinimleri (dikişsiz karo, atlas, doku boyutu/mipmap, palet kilidi) ve `tools/asset_post.sh` (IS-036) için araç/lisans seçimi; (3) ışık havuzu (CanvasModulate + ADD) ile sis katmanının sırası ve harmanlama, z_index düzeni; (4) Steam Deck / 1280×800 ve tümleşik GPU'da Compatibility'nin bilinen sorunları (4.5-4.7); (5) kamera zoom darbesi (US-022) × doku süzgeci.

Koordinatör kararları gözetildi: mimari §6 çizim kuralları, IS-067..IS-069, US-036 (TileMapLayer asset setiyle), US-011a t2 (sis kroki önbelleği, değişen texel yükleme, level_layout batch düzeltmesi — sürüyor; worktree salt okunur okundu).

### 2. Mevcut durum (dosya:satır; US-011a worktree `agent-a9a34…`, t2 düzenlemesi sürüyor)
- **Sis geçişi:** `entities/fx/fog_layer.gd:241-257` `_process` her kare `_shown` (30×20×3 = 1800 float) üzerinde `move_toward` döngüsü + `_upload()`; `_upload` `:319-332` tüm ızgarayı `PackedByteArray`'e çevirir (`roundi(clampf(...))` ×3/karo), `Image.set_data` + `ImageTexture.update`; yalnız `_animating` iken (`:245`). `_on_grid_changed` `:271-287` hedefleri yazar, `reduce_motion`'da anlık. `data/vision_tuning.tres`: `transition_sec = 0.15`, `update_interval_sec = 0.1`, `edge_blur_px = 8`, `soft_edge_px = 32`, `view_radius = 288`. Geçiş (150 ms) güncelleme aralığından (100 ms) uzun: her güncelleme öncekinin ortasına düşer.
- **Sis shader'ı:** `entities/fx/fog_layer.gdshader:6` `render_mode unshaded`; `:8` `hint_screen_texture, filter_nearest`; `:42-46` ekran okuması + doygunluk düşürme; `:55` `COLOR = vec4(col, 1.0)` (tam örtme; harman shader içinde). `Shade.texture_filter = LINEAR` (`fog_layer.gd:70`), `Z_INDEX = 50` (`:20`). `noise_ring.gd:16` `Z_INDEX = 20` (sisin altında).
- **Kamera:** `entities/player/player.gd:196-227` zoom `tuning.camera_zoom` (1,5) ya da `--camera-zoom`; sınır kenetleme `camera_limits`. Zoom darbesi yok (US-022 Backlog).
- **Kukla ölçek adımı:** `puppet.gd:42` `PIXEL_RATIO_STEP = 0.25`, `:180` `pixel_ratio = snappedf(ekran ölçeği, 0.25)`; tüy ve segment sayısı bundan türer (`puppet_mesh.gd:89,224`).
- **Doku/ışık ayarı:** `project.godot` doku süzgeci varsayılan (Linear, mipmap yok); CanvasModulate/ADD havuzu henüz yok (US-034 Backlog); sanat-yonu.md §4 "64 px/karo, doğrusal süzgeç, **mipmap kapalı**" derken IS-069 "Linear Mipmap" diyor → çelişki (bkz. §6).
- **Araçlar (bu makine):** Python 3.13 + Pillow 11.3 + numpy 2.2 var; ImageMagick ve pngquant **yok**.

### 3. Bu turun ölçümü (4.7.2, Windows, RX 6650 XT, 1280×720, gl_compatibility, vsync kapalı; scratchpad `cp_t2_fog_upload/main.gd`, projeye girmedi) [O]
Sahne: 200 renkli rect (`_draw`) + tam ekran sis dörtgeni. 240 kare, p50/p95.

| Senaryo | draw call | betik iş p50/p95 ms | kare p50/p95 ms | render CPU | render GPU |
|---|---|---|---|---|---|
| 0 yalnız arka plan | 1 | 0,002 | 0,17 / 0,23 | 0,06 | **0,07** |
| 1 sis shader (ekran okumalı), yükleme yok | 2 | 0,002 | 0,22 / 0,31 | 0,07 | **0,15** |
| 2 sis shader **ekran okumasız** (blend_mix) | 2 | 0,002 | 0,18 / 0,25 | 0,06 | **0,11** |
| 3 CPU geçiş 1800 float + tam `set_data` + `ImageTexture.update` her kare (30×20) | 2 | **0,300 / 0,321** | 0,46 / 0,54 | 0,07 | 0,17 |
| 4 aynı, `RS.texture_2d_update` | 2 | 0,307 / 0,324 | 0,47 / 0,69 | 0,07 | 0,17 |
| 5 yalnız değişen 40 texel yaz + tam yükleme her kare (30×20) | 2 | **0,022 / 0,028** | 0,22 / 0,28 | 0,07 | 0,15 |
| 6 shader geçişi: iki doku + `t`; yükleme 6 karede bir (30×20) | 2 | **0,005 / 0,029** | 0,22 / 0,28 | 0,07 | 0,16 |
| 7 CPU geçiş + tam yükleme her kare (**120×80 = 9600 karo**) | 2 | **4,52 / 4,94** | 4,84 / 6,92 | 0,12 | 0,18 |
| 8 değişen 40 texel + tam yükleme her kare (120×80) | 2 | 0,034 / 0,069 | 0,37 | 0,08 | 0,17 |
| 9 shader geçişi iki doku (120×80) | 2 | 0,005 / 0,041 | 0,23 | 0,07 | 0,16 |
| 10 `Image.set_pixel` ×40 + update (30×20) | 2 | 0,023 / 0,029 | 0,22 | 0,07 | 0,15 |

Okuma: (1) **Yükleme ucuz, döngü pahalı.** 30×20 dokuyu her kare tam yüklemek 0,02 ms (9600 karoda 0,03 ms); bugünkü maliyetin tamamı GDScript `move_toward` + bayt dönüşümü (0,30 ms; 9600 karoda 4,5 ms = kare bütçesinin dörtte biri). "Yalnız değişen texel yükleme" tek başına kazandırmaz (yükleme zaten tam dokudur, §4.1); kazanç geçişi shader'a taşımaktan gelir (0,30 → 0,005 ms, ölçek bağımsız). (2) `ImageTexture.update` ile `RS.texture_2d_update` aynı (sarmalayıcı yalnız boyut/format denetimi + `changed` sinyali, `image_texture.cpp`). (3) `set_pixel` ×40 ile bayt yazımı aynı maliyet; kod sadeliği için `set_pixel` yeter. (4) Ekran okumalı sis shader'ı bu GPU'da +0,08 ms (0,07 → 0,15), ekran okumasız +0,04; fark masaüstünde önemsiz, tümleşik GPU'da değil (§4.3).

### 4. En iyi uygulamalar ve seçenekler

#### 4.1 Veri dokusu güncelleme: Compatibility'de ne olur [O, kaynak kodu 4.7]
- `drivers/gles3/storage/texture_storage.cpp` `texture_2d_update` → `texture_set_data` → `_texture_set_data`: `_get_gl_image_and_format` (RGBA8 için dönüşüm yok), `img->get_data()` (COW, kopya yok), `glBindTexture` + mip başına **`glTexImage2D`** (`glTexSubImage2D` değil; yalnız 2D array'de SubImage). Her güncelleme dokunun **tamamını** yeniden tanımlar; kısmi bölge (x,y,w,h) **genel API'de yok** — `texture_2d_update(rid, image, layer)` yalnız katman seçer. Bu yüzden "değişen texel" optimizasyonu GDScript tarafında **Image'a yazılan texel sayısını** azaltır, GPU'ya giden bayt sayısını değil; 2,4 KB (30×20) ya da 38 KB (120×80) için sürücü maliyeti ölçümde ~0,02-0,03 ms.
- `ImageTexture.update` kısıtları (`image_texture.cpp`): boyut, format ve mipmap durumu eşleşmeli; aksi hata. `create_from_image` yeni RID üretir (materyal/atlas bağları kopar) — tur 1 notu doğru, `update` kullanılmalı.
- Bellek: `Image.set_data` PackedByteArray'i kopyalar; `set_pixel` yerinde yazar. 2400 bayt için ikisi de önemsiz.

#### 4.2 Sis geçişini shader'a taşıma kalıpları
| Kalıp | Ne | Artı | Eksi | Bize |
|---|---|---|---|---|
| **A. Önceki + yeni doku, tek `t` uniform'u** (ölçüm 6/9) | `prev`/`next` iki RGBA8 doku; `_process` yalnız `t = elapsed/transition_sec` yazar; shader `mix(texture(prev), texture(next), t)` | Kare başına 1 `set_shader_parameter` (0,005 ms); ölçek bağımsız; `reduce_motion` = `t=1` | Tüm karolar aynı fazı paylaşır: geçiş ortasında yeni güncelleme gelince (bizde 150 ms > 100 ms aralık) **önceki turda değişen karolar** için `prev := mix(prev,next,t)` CPU'da yazılır (≤ ~50-100 karo / 100 ms, ucuz); değişmeyen karolarda prev == next, sıçrama yok | **Önerilen**: `_shown` dizisi ve kare başına döngü kalkar |
| **B. Önceki + yeni doku + karo başına başlangıç zamanı dokusu** | Üçüncü doku `FORMAT_RF` (GL_R32F; GL 3.3 core ve ANGLE'da var) karo başına `start`; shader `t = clamp((now - start)/dur, 0, 1)`; `now` uniform (TIME yerine; TIME 3600 s'de sarar [O belge]) | Karo başına tam zamanlama, CPU bookkeeping yok | Üç doku, float doku; headless testte `shown_weights` için CPU'da aynı formül | A yetmezse |
| C. Tek doku, iki kanal çifti | RGBA8'e iki durumu sığdırmak | Tek doku | Üç ağırlık (bilinmeyen/hafıza/çevresel) + karanlık tarama 4 kanala sığmaz; 16-bit paketleme GLES3'te zahmet | Hayır |
| D. Bugünkü (CPU döngüsü + tam yükleme) | — | Basit, headless'ta `shown_weights` doğrudan | 0,3 ms/kare bakkalda, 4,5 ms 60×40+ haritada [O ölçüm] | Kalmasın |

A'nın testi: `shown_weights(cell)` (`fog_layer.gd:219-223`, testler kullanıyor) `prev`, `next` ve `t`'den hesaplanır (aynı `mix`); `is_animating()` = `t < 1`. Karanlık tarama (A kanalı, `:330`) `next` dokusunda kalır (geçişsiz). Kroki `Outline` zaten ayrı (koordinatör: önbellekli).

#### 4.3 Ekran okuması (`hint_screen_texture`) Compatibility'de [O, kaynak + issue]
- Mekanizma (`rasterizer_canvas_gles3.cpp` + `texture_storage.cpp:3657`): ekran dokusu kullanan ilk öğeden önce **tüm ekran** ayrı bir arka tampon FBO'ya **tam ekran dörtgen çizimiyle kopyalanır** (`CopyEffects::copy_to_and_from_rect`, blit değil); kare başına bir kez; `filter_*_mipmap` istenirse ardından Gauss zinciri (`render_target_gen_back_buffer_mipmaps`). Bizim `filter_nearest` → mipmap yok, doğru.
- Maliyet: 1280×720'de kopya + okuma bu masaüstünde +0,08 ms (§3). **GH #108935** (açık, 2025-07, Intel UHD, 4.4/4.5): tam ekran `hint_screen_texture` `filter_nearest` **~4 ms**, mipmap'li **~8 ms**; iki katman iki kat. Tümleşik GPU'da 1080p'de 2,25× piksel → sis katmanı tek başına 5-9 ms olabilir [G, ölçeklenmiş]. Projedeki en büyük **GPU** riski.
- Seçenekler: (a) **iki shader dosyası**: `fog_layer.gdshader` (ekran okumalı, doygunluk) ve `fog_layer_lite.gdshader` (ekran okumasız; `COLOR = vec4(tint, a)` blend_mix; doygunluk yok) — `uses_screen_texture` shader derlemesinde sabit, uniform'la kapatılamaz, dosya ayrımı şart; "düşük grafik" ayarı/`--low-gfx` ile seçilir, IS-067 dökümüyle arkadaş makinelerinde karşılaştırılır; (b) doygunluğu `CanvasModulate`/ton ile taklit etmek mümkün değil (sabit işlevli harman doygunluk düşüremez); (c) `BackBufferCopy` rect ile bölge daraltma: sis zaten tam ekran, kazanç yok (rect kipi 4.5'te bozuktu, GH #111096 kapalı). Öneri: (a); varsayılan **karar gereken** (ölçüm gelene dek ekran okumalı kalabilir; Intel UHD'li arkadaş varsa lite).

#### 4.4 Işık havuzu (CanvasModulate + ADD) ↔ sis sırası ve harmanlama
- **[O kaynak `canvas.glsl:713-717`]** `render_mode unshaded` olan öğe `canvas_modulation` ile **çarpılmaz**; sis shader'ımız unshaded → ekranı (zaten modüle edilmiş) ikinci kez karartmaz. Doğru. ADD havuzu sprite'ları (unshaded değil) ambiyansla çarpılır (T1 #b9b6ad ≈ ×0,72) → havuz alfa/rengi buna göre ayarlanır ya da havuz materyali `unshaded` + ADD (ambiyanstan bağımsız parlar; sanat kararı).
- **Sıra:** sis ekranı okuyup `COLOR.a = 1` ile örttüğü için **sisin altındaki her şey** (zemin, havuz, prop, kukla) hafıza tonunda soluklaşır ve bilinmeyende görünmez (sanat-yonu §3 madde 4 ile aynı); sisin **üstündeki** (z > 50) öğeler bilinmeyen opak tonun üstünde ham çizilir. Havuz z < 50 **zorunlu**; aksi halde ışık bilinmeyen alanda "sızar". Önerilen z düzeni (dünya canvas'ı; HUD ayrı `CanvasLayer`, CanvasModulate'ten etkilenmez): zemin 0 (TileMapLayer) · duvar/cam 1 · **havuz ADD 5** · prop 10 · kukla/NPC 20 (gürültü halkası 20, mevcut) · karanlık bölge taraması sis içinde (A kanalı) · **sis 50** · sis üstü (ekip arkadaşı hayaleti, kenar oku, ping, plan katmanı) 60-70 · HUD CanvasLayer.
- **Batch:** blend kipi değişimi batch kırar (`rasterizer_canvas_gles3.cpp`: `blend_mode != batch.blend_mode → _new_batch`) [O]; z_index ile gruplanmış 16 havuz **tek atlas + tek paylaşılan `CanvasItemMaterial` (.tres)** ile 1 kırılma (ADD'e giriş, çıkış) = +2 draw call. Her sprite'a ayrı materyal örneği = havuz başına kırılma — §6 kuralı "düğüm başına ShaderMaterial yok" CanvasItemMaterial için de geçerli olmalı.

#### 4.5 AI asset hattı: teknik gereksinimler ve araçlar
- **Doku içe aktarma [O belge]:** 2D için `Compress > Mode = Lossless` (varsayılan; WebP lossless, `force_png` kapalı yeter); VRAM sıkıştırma 2D'de artefakt, kullanma; `Fix Alpha Border` açık (alfa kenarlı prop'larda bilinear hale); `Mipmaps > Generate` "2D'de yalnız görünür yarar varsa".
- **Ölçek bandı [G, hesap]:** 64 px asset → 720p/Deck'te 48 px (×0,75), zoom darbesi +%8'de ×0,69, zoom seçeneği 1,25'te ×0,625; 1080p'de ×1,125 (büyütme). Küçültme hiçbir yerde 0,5'in altına inmiyor → bilinear **mipmap'siz** bu bantta titreşim yapmaz (sanat-yonu "mipmap kapalı" tutarlı); mipmap ancak ×0,5 altı (kroki/plan görünümü asset'leri küçültürse) gerekir. **IS-069 kapsam notu:** varsayılan `Linear` kalsın, mipmap asset bazında (import preset) — "Linear Mipmap" tüm canvas'ı değiştirir, UI/ADD havuzlarına mipmap bellek + atlas sızma riski getirir → karar gereken (küçük); tur 1 öneri 4 bu yönde düzeltilir.
- **Atlas ve sızma [O/G]:** TileSet atlası `use_texture_padding = true` (varsayılan) karo başına 1 px iç dolgu üretir ("karolar arası çizgi" artefaktını önler; kaynak değiştikçe yeniden üretim maliyeti) — mip 0 için yeter; mipmap açılırsa her mip seviyesi için dolgu 2× → kaynak atlasta **2-4 px oluk + kenar uzatma (extrude)** ve `separation` = oluk. Prop'lar `AtlasTexture` (`filter_clip = true`, `margin`) ya da az sayıda ayrı doku (her doku batch kırar; 20 prop → tek atlas tercih). Zemin 4×4 karo (256 px) deseni: TileSet'te 64 px karolar, `build_levels` `set_cell(atlas_coords = (x mod 4, y mod 4))` → desen dikişsiz döşenir, varyant = ikinci 4×4 blok.
- **Dikişsizlik denetimi [O, yaygın yöntem]:** yarım boy kaydır (`ImageChops.offset(w/2, h/2)`) → dikiş ortaya gelir; sayısal ölçü = karşıt kenar sütun/satırlarının ortalama mutlak farkı (`edge_mae` ≤ eşik, ör. 6/255); düzeltme = kaydırılmış görüntüde dikiş bandını (%10-12) karşı kenarla çapraz soldurma. AI "seamless tileable" istemi güvenilir değil → araç her karoyu denetlesin.
- **Palet kilidi:** Pillow `Image.quantize(palette=palette_img, dither=Image.Dither.NONE)` verilen palete **yeniden eşler** (≤ 24 renk; dither kapalı — düz boyama) [O belge]; çıktı indexed PNG (küçük). RGBA'da `FASTOCTREE`/palet; alfa ayrı tutulup sonra birleştirilir.
- **Araç/lisans [O]:** Pillow MIT-CMU (kurulu) · numpy BSD · ImageMagick "ImageMagick License" (Apache-2.0 benzeri, GPL uyumlu; yalnız araç olarak kullanımda oyuna yükümlülük yok; kurulu değil) · pngquant/libimagequant **GPLv3 ya da ticari**; "üretilen dosyalar lisanstan etkilenmez" (pngquant.org) → yalnız komut satırı aracı olarak kullanılabilir, oyuna bağlanmaz; gereksiz (Pillow yeter). **Öneri: tek bağımlılık Pillow** — `tools/asset_post.py` (+ `asset_post.sh` sarmalayıcı), `tools/test_asset_post.py` unittest (ci_local "araç testleri" adımı, Godot gerekmez).
- Önerilen adımlar (sanat-yonu §6 madde 3 ile aynı sırada): `--scale 0.5` küçült (LANCZOS; 128→64) → palet eşleme → (prop) 1 px BG α0,6 kenar + gölge elipsi → (karo) dikişsizlik ölçümü + 2×2 döşeme önizlemesi → kontrast ölçümü (işaret renkleri ≥ 3:1, WCAG formülü) → atlas paketleme (raf algoritması, 4 px oluk + extrude, `atlas.json` bölgeleri) → `assetler.md` satırı şablonu.

#### 4.6 Steam Deck / tümleşik GPU: bilinen durumlar (4.5-4.7)
- **ANGLE zorlaması (Windows) [O `main.cpp:2416-2486`, `display_server_windows.cpp:8217-8231`]:** `force_angle_on_devices` varsayılan listesi eşleşmeyi `containsn` (harf duyarsız **içerir**) ile yapar: `"Intel(R) HD Graphics"` → **tüm Intel HD Graphics** (HD 520/620/630 dahil) ANGLE/D3D11'e gider; `"Intel(R) UHD Graphics"`, `Iris Xe` ve Iris Plus 640/650 dışı Iris'ler **yerli GL**'de kalır; AMD'de Radeon HD 2-8, R2-R9 2xx/3xx/M, Fury ANGLE; RX/Vega **yerli GL**. Sonuç: arkadaş makinelerinde iki ayrı sürücü yolu (ANGLE-D3D11 ve yerli GL) olabilir; IS-067 dökümüne `get_video_adapter_name/api_version` ("ANGLE" dizesi) girmeli.
- **GH #122100** (açık, 2026-08, Compatibility, Windows, **4.6-beta2+ regresyon**, NVIDIA yerli GL; Intel HD 620/ANGLE'da yok): tam ekranda üstte 2 px çizgi; düzeltme PR #122119 **4.8 milestone** → 4.7.2'de var sayılmalı. Rahatlık-UX "Alt+Enter tam ekran" kalemi NVIDIA'da `WINDOW_MODE_FULLSCREEN` ile bu artefaktı test etmeli; gerekirse `EXCLUSIVE_FULLSCREEN` [?].
- **GH #95797** (kapalı, 4.4'te düzeltildi): AMD Vega 6-7 APU + ANGLE/web'de GPUParticles çizilmiyordu — 4.7.2'de yok; parçacık = CPUParticles kuralı (tur 1) riski sıfırlar.
- **GH #108935**: §4.3 (ekran okuması Intel UHD ~4 ms).
- **Steam Deck [O/G]:** Linux yerli build + Mesa radeonsi (GL 4.6 sürücü; Compatibility 3.3 ister) — Compatibility için Deck'e özgü açık issue bulunmadı (GitHub arama; forum 142477). Algılama (kodeco): `OS.get_processor_name().contains("AMD CUSTOM APU 0405")` (Compatibility'de `RenderingDevice` yok; GPU adı `RenderingServer.get_video_adapter_name()` "vangogh" içerir [?]); Deck GPU saati düşer (1050-1100 MHz tipik) → `max_fps = 60`/40 ve VSync varsayılan açık (pil, ısı) [G]. 1280×800: `aspect = expand` zaten karşılıyor (tur 1).

#### 4.7 Zoom darbesi (US-022) × doku süzgeci
- **[O forum 76194 + bugnet]** Kesirli zoom titremesi **piksel sanatı + nearest + snap** sorunudur; önerilen "tam sayı zoom" bize gerekmez: Linear süzgeçli 64 px asset'te ×0,69-1,2 bandında kesirli zoom pürüzsüzdür [G]. `snap_2d_*` kapalı kalsın (KR-017, tur 1); `position_smoothing` + zoom birleşimi jitter üretebilir (bugnet) → darbe `_process`'te tween (TRANS_SINE/EASE_OUT, 0,25 sn in / 0,6-1,0 sn out; uhiyama) ve kamera `process_callback` oyuncu ara değerlemesiyle aynı adımda.
- **Kukla etkileşimi [G, hesap]:** `pixel_ratio` 0,25 adımına yuvarlanır (`puppet.gd:180`): 720p'de 1,5 → +%8 = 1,62 → 1,5 (değişmez); **1080p'de** 2,25 → 2,43 → **2,5** (adım atlar: segment sayısı ve tüy kalınlığı bir karede değişir, "pop"). Çözüm: `pixel_ratio`'yu darbesiz taban zoom'dan hesapla ya da adım geçişine histerezis; HUD `CanvasLayer`'da (darbe görmez); sis `view_radius`/`edge_px` dünya px → zoom'dan bağımsız (doğru).
- Hareket azaltma: darbe 0 (oyun-hissi §7) — tek kapı `FeelSettings.reduced`.

### 5. Uygunluk değerlendirmesi
- Sis mimarisi (veri dokusu + tek shader) doğru; yalnız **geçişin yeri** yanlış katmanda (CPU). Kalıp A ile `_process` döngüsü tamamen kalkar; US-011a t2'nin "değişen texel yükleme" kararı ölçümle **gereksiz** çıkıyor (yükleme 0,02 ms) — asıl kalem geçişi shader'a taşımak. KR-023'e dokunmaz.
- Ekran okuması KR-023'ün "üç ton + doygunluk" isteğinin bedeli; masaüstünde bedava, tümleşik GPU'da kare bütçesinin yarısı olabilir → lite shader varyantı MVP'de "düşük grafik" anahtarı olarak ucuz sigorta (KR-020: arkadaş makineleri hedef).
- Işık/sis sırası sanat-yonu planıyla uyumlu; z düzeni yazılı kural olmalı (bugün yalnız 50 ve 20 sabitleri var).
- Asset hattı için Pillow tek bağımlılık; GPL araç (pngquant) gereksiz. Mipmap kararı sanat-yonu ile IS-069 arasında çelişiyor; ölçek bandı hesabı sanat-yonu'nu haklı çıkarıyor.

### 6. Bulgular
**Doğru yaptıklarımız:** `ImageTexture.update` (yeniden oluşturma yok); shader `unshaded` (CanvasModulate çift uygulanmaz); `filter_nearest` ekran okuması (mipmap zinciri yok); `transition_sec` kısa (150 ms) ve yalnız `_animating` iken yükleme; kroki ayrı düğüm; snap kapalı; HUD ayrı katman planı.

**Saptığımız yerler**
1. `fog_layer.gd:241-257` kare başına 1800 float döngüsü + tam bayt dönüşümü: 0,30 ms bakkalda, **4,5 ms** 120×80 haritada (ölçüm 3/7) — geçiş shader'da olmalı (kalıp A).
2. "Yalnız değişen texel yükleme" (US-011a t2 kararı) GPU tarafında anlamsız (GLES3 her zaman tam `glTexImage2D`); CPU tarafında `set_pixel` ile 0,02 ms — kalem bunu değil, döngüyü hedeflemeli.
3. `hint_screen_texture` maliyeti tümleşik GPU'da bilinmiyor/ölçülmüyor; GH #108935 ~4 ms (720p, Intel UHD). Lite shader yok.
4. Mipmap kararı çelişkili (sanat-yonu §4 "kapalı" ↔ IS-069 "Linear Mipmap"); ölçek bandı ×0,625-1,2 → mipmap gereksiz.
5. z_index düzeni yazılı değil; ışık havuzu kalemi (US-034) sisin altında olmak zorunda (ekran okuması + opak bilinmeyen); paylaşılan tek materyal kuralı CanvasItemMaterial'ı da kapsamalı.
6. Kukla `pixel_ratio` adımı zoom darbesinde 1080p'de atlar (pop) — US-022 ile US-014 kesişimi.
7. Tam ekran 2 px çizgi regresyonu (4.6+, NVIDIA, Compatibility) 4.7.2'de düzeltilmemiş — rahatlık-UX tam ekran kalemi bunu bilmeli.

**Riskler:** Intel HD (ANGLE/D3D11) ve Intel UHD (yerli GL) arkadaş makinelerinde iki farklı sürücü davranışı; 1080p + ekran okumalı sis + ADD havuzları tümleşik GPU'da 5-9 ms [G]; asset hattında mipmap açılırsa 1 px TileSet dolgusu yetmez (sızma çizgileri).

### 7. Öneriler
| # | Öncelik | Maliyet | Sahip | Kalem adayı | Kabul kriterleri |
|---|---|---|---|---|---|
| T2-1 | **P1** | S | seviye (US-011a t2 kapsamına ya da ayrı IS) | **Sis geçişi shader'da**: `prev`/`next` RGBA8 doku + `t` uniform (kalıp A); `_shown` döngüsü kalkar; önceki turda değişen karolar yeni güncellemede CPU'da kapatılır; `shown_weights`/`is_animating` prev/next/t'den | AC1 `_process`'te ızgara boyutuna bağlı döngü yok; 120×80 sentetik ızgarada kare başına sis betik maliyeti ≤ 0,05 ms (ölçüm betiği `tests/perf/` ya da birim testte `Time.get_ticks_usec`); AC2 `test_fog_layer` geçiş süresi/`reduce_motion`/karanlık tarama testleri değişmeden geçer; AC3 IS-022 görüntüsü geçiş sonunda piksel-eş |
| T2-2 | **P1** | XS | seviye (+altyapi anahtar) | **Sis lite shader** (`fog_layer_lite.gdshader`, ekran okumasız, doygunluk yok) + `--low-gfx`/ayar anahtarı; IS-067 dökümünde hangi varyantın koştuğu | AC1 iki varyant aynı veri dokusu/uniform'larla çalışır, lite'ta `render_gpu_ms` düşer (koordinatör makinesinde ölçülür); AC2 üç ton lite'ta da ayırt edilir (headless görüntü, kontrast testi); AC3 varsayılan **karar gereken** |
| T2-3 | P2 | XS | koordinatör (mimari §6/S4 eki) + seviye | **z_index düzeni kuralı**: 0 zemin · 5 havuz (ADD, tek atlas, paylaşılan tek CanvasItemMaterial) · 10 prop · 20 kukla/halka · 50 sis · 60-70 sis üstü · HUD CanvasLayer; "paylaşılan materyal" kuralı CanvasItemMaterial'ı kapsar | AC1 mimari §6'da tablo; AC2 US-034'te 16 havuz ≤ +2 draw call (IS-067 ölçümü); AC3 bilinmeyen alanda havuz görünmez (headless görüntü) |
| T2-4 | P2 | S | seviye (IS-036 kapsamı) | **`tools/asset_post.py`** (Pillow tek bağımlılık): küçült → palet eşleme (dither yok) → kenar/gölge → dikişsizlik ölçümü (`edge_mae`) + 2×2 önizleme → kontrast ≥ 3:1 → atlas paketleme (4 px oluk + extrude, `atlas.json`) → assetler.md satırı; `tools/test_asset_post.py` | AC1 sentetik görüntüde palet ≤ 24 renk ve dikiş ölçüsü eşiği doğrulanır (unittest, Godot'suz, ci_local araç adımı); AC2 çıktı PNG Godot `--import` uyarısız; AC3 assetler.md şablon satırı üretir |
| T2-5 | P2 | XS | altyapi (IS-069 düzeltmesi) | **Karar gereken → mipmap kapsamı**: `default_texture_filter` Linear kalır (mipmap yok); mipmap yalnız ×0,5 altı gösterilen asset'te import preset'iyle; TileSet `use_texture_padding` açık, `separation` 0 | AC1 720p/1080p ve zoom 1,25/1,5/1,75'te 64 px karo seti titreşimsiz (IS-022 görüntüleri); AC2 import preset belgesi (assetler.md) |
| T2-6 | P3 | XS | oynanis (US-022 + US-014) | **Zoom darbesi kuralı**: tween `_process`, snap yok, `pixel_ratio` darbesiz taban zoom'dan (ya da histerezis) | AC1 1080p'de +%8 darbede `draw_stats` segment sayısı değişmez; AC2 hareket azaltmada darbe 0; AC3 HUD CanvasLayer'da (darbe görmez) |
| T2-7 | P3 | XS | altyapi (IS-067 eki) | **Sürücü yolu dökümü**: `render` anahtarına `adapter`, `api_version`, `is_angle` (api_version "ANGLE" içerir), `window_mode`; tam ekran 2 px çizgi (GH #122100) NVIDIA'da test maddesi | AC1 dökümde alanlar dolu; AC2 arkadaş checkpoint anketinde "tam ekranda üstte çizgi?" sorusu |

Sıra: T2-1 (US-011a t2 ile) → T2-2 → T2-3 (US-034 öncesi) → T2-4/T2-5 (IS-036 ile) → T2-6/T2-7 ilgili kalemlerde.

### 8. Bir sonraki tur için açık sorular
- Intel UHD/Iris Xe'li gerçek makinede ekran okumalı vs lite sis `render_gpu_ms` (IS-067 dökümü gelince); 1080p'de ADD havuzlarının eklenmiş maliyeti.
- Kalıp A'da "önceki turda değişen karoları kapatma" yerine kalıp B (R32F zaman dokusu) daha mı sade çıkar? Prototipte karar.
- TileMapLayer'da `use_texture_padding` iç dokusunun 4×4 desen (16 karo) + 2 varyantta bellek/yeniden üretim süresi; terrain set'leriyle duvar köşeleri (US-036).
- Deck'te 40 Hz kipi + `max_fps` + fizik 60 Hz ara değerleme etkileşimi (US-015 tamponuyla).
- Tam ekran 2 px çizgi: 4.7.3'e backport var mı; `EXCLUSIVE_FULLSCREEN` geçici çözüm mü [?].
- 4.8 yol haritasında 2D batching/ekran dokusu değişikliği var mı (bu turda görülmedi) [?].

### Kaynaklar (tur 2)
- GLES3 doku güncelleme (`glTexImage2D`, kısmi bölge yok) ve arka tampon kopyası: https://raw.githubusercontent.com/godotengine/godot/4.7/drivers/gles3/storage/texture_storage.cpp · https://raw.githubusercontent.com/godotengine/godot/4.7/drivers/gles3/effects/copy_effects.cpp · ImageTexture.update kısıtları: https://raw.githubusercontent.com/godotengine/godot/4.7/scene/resources/image_texture.cpp
- Canvas renderer (blend batch kırılması, backbuffer tetikleme): https://raw.githubusercontent.com/godotengine/godot/4.7/drivers/gles3/rasterizer_canvas_gles3.cpp · `unshaded` → canvas_modulation atlanır: https://raw.githubusercontent.com/godotengine/godot/4.7/drivers/gles3/shaders/canvas.glsl (satır 713-717)
- Ekran okuma shader'ları: https://docs.godotengine.org/en/4.7/tutorials/shaders/screen-reading_shaders.html · canvas_item shader (TIME 3600 s sarma, blend kipleri): https://docs.godotengine.org/en/4.7/tutorials/shaders/shader_reference/canvas_item_shader.html
- GH #108935 `hint_screen_texture` Intel UHD 4/8 ms: https://github.com/godotengine/godot/issues/108935 · GH #122100 tam ekran 2 px çizgi + PR #122119 (4.8): https://github.com/godotengine/godot/issues/122100 · GH #95797 Vega ANGLE parçacık (4.4'te düzeltildi): https://github.com/godotengine/godot/issues/95797 · GH #111096 BackBufferCopy rect: https://github.com/godotengine/godot/issues/111096
- ANGLE zorlama listesi ve eşleşme kuralı: https://raw.githubusercontent.com/godotengine/godot/4.7/main/main.cpp (2416-2486) · https://raw.githubusercontent.com/godotengine/godot/4.7/platform/windows/display_server_windows.cpp (8217-8231) · ProjectSettings (fallback_to_angle, snap, default_texture_filter, force_png): https://raw.githubusercontent.com/godotengine/godot/4.7/doc/classes/ProjectSettings.xml
- Doku içe aktarma (Lossless, mipmap 2D notu, Fix Alpha Border): https://docs.godotengine.org/en/4.7/tutorials/assets_pipeline/importing_images.html · TileSetAtlasSource (`use_texture_padding`, separation): https://docs.godotengine.org/en/4.7/classes/class_tilesetatlassource.html · AtlasTexture (`filter_clip`, margin): https://docs.godotengine.org/en/latest/classes/class_atlastexture.html · TileMap kullanımı (quadrant, Y-sort): https://docs.godotengine.org/en/4.7/tutorials/2d/using_tilemaps.html
- Atlas oluk/extrude kuralları (2-4 px, mipmap'te 2×): https://bugnet.io/blog/how-to-fix-texture-bleeding-and-seams-in-an-atlas · https://webglfundamentals.org/webgl/lessons/webgl-qna-how-to-prevent-texture-bleeding-with-a-texture-atlas.html
- Dikişsizlik denetimi (yarım kaydırma, edge MAE): https://inzomnia5.itch.io/seamless-texture-checker
- Pillow quantize(palette, dither): https://pillow.readthedocs.io/en/stable/reference/Image.html · Pillow lisansı MIT-CMU: https://pillow.readthedocs.io/en/stable/about.html · ImageMagick lisansı: https://imagemagick.org/license/ · pngquant lisansı (GPL/ticari; üretilen dosyalar etkilenmez): https://pngquant.org/licensing.html
- Zoom titremesi (piksel sanatı bağlamı): https://forum.godotengine.org/t/pixels-flickering-when-changing-camera-zoom/76194 · kamera smoothing × zoom jitter: https://bugnet.io/blog/fix-godot-camera-2d-smoothing-jitter-on-zoom · zoom tween/trauma kalıbı: https://uhiyama-lab.com/en/notes/godot/camera2d-techniques/
- Steam Deck algılama ve saat davranışı: https://www.kodeco.com/41495624-targeting-the-steam-deck-with-godot · forum 4.7.1 Deck: https://forum.godotengine.org/t/does-current-godot-engine-version-4-7-1-fully-support-valve-s-steam-deck-and-steam-machine/142477
- Bu turun ölçüm betiği: scratchpad `cp_t2_fog_upload/main.gd` (SceneTree betiği, 11 senaryo; projeye girmedi; T2-1 AC1 için `tests/perf/`'e uyarlanabilir).
