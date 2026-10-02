# Teknik araştırma: mimari-test (GDScript mimarisi, statik tipleme, test, CI/teslim)

İşaretler: **[O]** olgu (kaynaklı) · **[G]** görüş/değerlendirme · **[?]** doğrulanmadı. Sürümler kaynağıyla; Godot 4.7.2'ye uymayan bilgi "eski" diye işaretli.

---

## Tur 1 — 2026-10-02

### 1. Kapsam
GDScript proje mimarisi (dizin/bağımlılık yönü, class_name, autoload, sinyal/bileşim), statik tipleme (typed Dictionary, `unsafe_*` uyarıları), test katmanları (kendi koşucumuz vs GUT/gdUnit4, sahte nesneler, saat bağımlılığı, sızıntı), ağ testi, görsel regresyon, CI (GitHub Actions), dışa aktarma/imzalama, linter/format, kod kapsamı. Bilinen sorunlar: `game.gd` 840 satır; tipsiz `Array`/`Dictionary`; testlerde özel üye erişimi; gerçek saate bağlı testler; "9 ObjectDB leaked" (IS-029 sürüyor); >400 satır dosyalar.

### 2. Mevcut durum (dosya:satır)
- **Sürüm/ayar:** Godot 4.7.2 (`tools/get_godot.sh:12`); `project.godot:27` yalnız `gdscript/warnings/untyped_declaration=2` (hata). Diğer tüm uyarılar motor varsayılanında. `@warning_ignore` hiç yok (0).
- **Dizin ve bağımlılık yönü:** `docs/notes/mimari.md` §2, §6 (core → hiçbir dizin; autoload → core/data/level API; entities → core/autoload/data; ui → sözleşmeler). Tarayıcı `tests/unit/test_deps.gd:9-16` yalnız **core/ ve autoload/ → ui/** yönünü denetler (yol dizesi, class_name, uid çözümü); §6'nın geri kalan matrisi (entities → ui?, levels → autoload?, core → autoload?) denetlenmiyor.
- **class_name:** 21 adet (ui 7, entities 11, core 1, levels 2, tests 1). Autoload'larda class_name yok (KR-018 C). Kalıtım derinliği 0-1.
- **Autoload:** 4 (`Args`, `Net`, `Game`, `NoiseBus`; `project.godot:18-23`). `game.gd` 840 satır: oturum/el sıkışma (355-456), RPC'ler (457-541), oyuncu üretimi/çoğaltma (542-680), yetiştirme (681-722), seviye yükleme (723-770), HUD (771-793), döküm (197-267, 794-840).
- **Tipleme sayımı (üretim kodu: autoload, core, entities, levels, ui, main.gd):** tipsiz `: Array`/`: Dictionary` 73 yer (grep; koordinatörün "97" sayısı testler dahil olabilir — testlerle 153); typed koleksiyon (`Array[...]`/`Dictionary[...]`) 37; `: Variant` 22; `as X` dönüşümü 74; duck typing (`has_method/has_signal/.call(/.get("`) 47.
- **Test koşucusu:** `tests/run_tests.gd` (168 satır) + `tests/t.gd` (158). Özellikler: `Logger` ile hata yakalama (run_tests.gd:14-40; `push_error`/motor hatası testi düşürür, `allow_errors()` istisnası), bekçi zaman aşımı (135-141), `--filter`, test başına yeni örnek, `autofree`, `ScriptBacktrace` ile başarısızlık satırı (t.gd:135-141). Eksikler: parametreli test, orphan (yetim düğüm) sayacı, JUnit XML, sahte saat/kare adımlama, sahte girdi.
- **Test envanteri:** `tests/unit/` 28 dosya, 236 `test_*`; 112 `await`, 62 `autofree`. >400 satır: `test_interaction_props.gd` 524, `test_levels.gd` 491 (faz2-int dalında `test_levels_population` 517, `test_levels_nav` 498 de var).
- **Özel üye erişimi testlerde:** `test_game.gd` 19 (ör. 64-65 `Game._dump_providers`, 83-98 `Game._sanitize_name`, 156 `Game._rpc_set_name`, 288-295 `Game._add_player/_players`, 349 `_load_level_local`, 360 `_unload_level`), `test_player_rules.gd` 9, `test_player.gd` 5 (`Game._rpc_players` 172-204). ui/ için `test_ui_fakes.gd:146` yasaklıyor; entities/ için `test_player_rules`; autoload'lar için denetim yok.
- **Gerçek saat:** üretimde `Time.get_ticks_*` 8 yer (`game.gd:164,330,682,696`; `player.gd:295`; `player_interaction.gd:104,127`; `prop_dump.gd:34` unix). Testlerde duvar saatiyle bekleme: `test_game.gd:251-269` (3 sn), `test_net.gd:52-53,120-125` (4 sn), `test_player.gd:269,280` (`create_timer` 0,25/0,45 sn), `test_player.gd:244`.
- **Sahteler:** `tests/unit/test_ui_fakes.gd` — `FakeNet/FakeGame/FakePlayer` + sözleşme imza testi (124-134: sahtenin her üyesi gerçek betikte aynı argüman sayısıyla var) + ui/ yalnız sözleşme üyelerini kullanır (137-157). Ağ fikstürü `tests/fixtures/dummy_player.gd`.
- **Ağ duman:** `tools/net_smoke.py` (gerçek süreçler, UDP gecikme proxy'si, 15 senaryo `tests/net/*.json`, her biri 0 ve 150 ms → CI'da 30 koşu); `tools/soak.sh` dayanıklılık; `tools/screenshot.py` GPU'lu pencere, CI'da atlanır.
- **CI:** `tools/ci_local.sh` = godot → import (iki geçiş, uyarı = hata) → unit → tools (Python unittest ×3) → net; `.github/workflows/ci.yml` aynı adımlar ubuntu-24.04, `.tools` önbelleği (anahtar get_godot.sh özeti), main push'unda build işi (şablon önbelleği ~1,3 GB, Windows+Linux artifact 30 gün). Build `tools/export.sh` (SHA-512 doğrulamalı şablon, PE/ELF denetimi, headless host+istemci duman). İmzalama yok.

### 3. En iyi uygulamalar ve seçenekler

#### 3.1 Statik tipleme
- **Typed Dictionary** `Dictionary[K, V]` 4.4'ten beri [O]; yazmada anahtar/değer tipi denetlenir, çözümleyici `for` ve `[]` için tipi bilir; **Dictionary metotları yine Variant döner**; **iç içe typed koleksiyon yok** (`Array[Array[int]]`, `Dictionary[String, Dictionary[String,int]]` sözdizimi hatası) [O]. Bizim `players()` gibi `peer -> {name, slot}` yapıları için en iyisi `Dictionary[int, Dictionary]` (iç sözlük tipsiz kalır) ya da küçük `RefCounted`/`Resource` sınıfı.
- **Uyarı varsayılanları (4.7 ProjectSettings) [O]:** `untyped_declaration 0`, `inferred_declaration 0`, `unsafe_property_access 0`, `unsafe_method_access 0`, `unsafe_cast 0`, `unsafe_call_argument 0`, `unsafe_void_return 1`, `return_value_discarded 0`; `directory_rules {"res://addons": 0}` (addons dışlama). Yani biz yalnız `untyped_declaration`'ı yükselttik; `unsafe_*` ailesi kapalı.
- **`unsafe_*` açmanın maliyeti/getirisi [O+G]:** `unsafe_method_access`/`unsafe_property_access` "çıkarsanan tipte yok (alt tipte olabilir)" durumlarını yakalar; `Variant`/`Node` üzerinden erişim ve duck typing (`has_method` sonrası `obj.foo()`) uyarı üretir; güvenli kalıp `if obj is X: var x: X = obj` ya da `.call()/.get()` (Godot "interfaces" belgesi duck typing'i meşru sayar) [O]. Bizde 47 duck typing + 22 Variant + 74 `as` var; `as` tip uyuşmazlığında sessizce `null` döner [O] — `unsafe_cast` bunu işaretlemez, yalnız derleme anında bilinmeyen dönüşümü işaretler. Getiri: ajan sınırlarındaki yanlış ad/arg hataları derlemede çıkar; maliyet: önce sayım, sonra `Variant`'tan tipli yerel değişkene geçiş (küçük düzenleme, çok dosya). Önerim: önce **warn (1)** + sayım, hata (2) kararı ölçüme göre (§6 öneri 3).
- **Performans [O, üçüncü taraf ölçüm]:** tipli kod optimize opcode kullanır (resmî belge); mikro ölçümde toplama %34, Vector2 mesafe %59 daha hızlı (beep.blog 2024-02, Godot 4.2; 4.7 için yeniden ölçüm yok [?]).
- **4.7 kırılma [O]:** tipli dönüş veren metodu ezen alt metot artık aynı dönüş tipini miras alır; `-> void` gibi yazılmış ezmelerde açık `return` gerekir. Bizde kalıtım yok denecek kadar az, risk düşük.
- **4.5+ dil ekleri [O]:** `@abstract` sınıf/metot, variadic parametre (`...args`), özel `Logger` (`OS.add_logger`) ve betik backtrace'leri. Koşucumuz `Logger` ve `Engine.capture_script_backtraces` kullandığı için **4.5 altına inemez** (sürüm yükseltme/indirme notu). `@abstract` mimari §6 "soyut taban taklidi yok" kuralını etkiler: taklit (assert(false)) zaten yasak; gerçek `@abstract` de "bileşim > kalıtım" gereği kullanılmasın [G] — karar gereken küçük madde.

#### 3.2 class_name, döngüsel bağımlılık, autoload
- `class_name` tipleri global kaydeder; iki betik birbirini tip ipucu olarak kullanınca (preload olmasa da) "cyclic dependency" hatası çıkabilir; çözüm: bir yönü `load()`/Variant/duck typing'e çevirmek [O, forum + bugnet 2025-26]. Bizim §6 bağımlılık yönü tek yönlü olduğu için döngü yok; ancak **tarayıcı yalnız ui yönünü denetliyor** — entities ↔ levels, core → autoload gibi sapmalar sessiz kalır.
- Autoload: resmî rehber "geniş kapsamlı, kendi verisini yöneten sistem" için uygun, aksi halde düğüm ağacı + sinyal; 4.1+ `static var` küçük paylaşımlar için autoload'a alternatif [O]. 4 autoload (en fazla +1 katalog) kuralı makul; sorun sayı değil `Game`'in 840 satırlık çoklu sorumluluğu.
- `game.gd` bölme kalıbı [G]: S3 cephesi (`Game`) kalır, iç sorumluluklar autoload'un çocuğu küçük düğümler/RefCounted'lara iner: `SessionRoster` (el sıkışma + oyuncu listesi + ad), `LevelLoader` (yükle/boşalt/dondur/onay), `Catchup` (yetiştirme akışı), `DumpCollector` (döküm). RPC'ler cephede kalır (RPC yolu değişmesin, S2), gövdeler delege eder. Önce testlerdeki özel erişimler (19 yer) kamusal "test dikişi"ne (ör. `Game.debug_roster()` yerine var olan `players()`, `_sanitize_name` → `core/names.gd` statik) taşınmalı; aksi halde bölme testleri kırar.

#### 3.3 Sinyal vs doğrudan çağrı, bileşim
- Resmî "interfaces" belgesi: referans/`get_node` (en hızlı), duck typing (`has_method/call/get/set`), gruplar = arayüz, `Callable` iletme; "aşağı çağır, yukarı sinyal" kalıbı topluluk standardı [O/G]. Bizde: host→herkes olaylar sinyal (21 `signal`), istek yolu RPC, bileşen → prop `completed` sinyali (S7), ui ← autoload sinyalleri. Uygun. Sapma yok; yalnız `session_event` genel kanalının "ikinci olay otobüsü"ne dönüşmesi riski (mimari §6 bilinçli sınır).

#### 3.4 Test çerçeveleri: GUT vs gdUnit4 vs bizim koşucu
| | GUT 9.6.1 [O] | gdUnit4 v6.2.1 [O] | Bizim (KR-009) |
|---|---|---|---|
| Godot | 4.x | 4.5 – 4.7.1 (uyum tablosu) | 4.5+ (Logger/backtrace) |
| Headless/CLI | `gut_cmdln.gd`, çıkış 0/1, `-gexit`, JUnit XML | `GdUnitCmdTool.gd`, HTML + JUnit, flaky yeniden deneme | `run_tests.gd`, çıkış 0/1, `--filter/--timeout` |
| Sahte nesne | double/spy/stub (sınıf tabanlı) | mock/spy | elle Fake* + imza sözleşme testi |
| Sahne/girdi | `add_child_autofree`, await yardımcıları | SceneRunner: kare adımlama, fare/klavye/dokunma simülasyonu, `set_time_factor` | yok (await process_frame elle) |
| Sızıntı | orphan sayacı test başına (`get_orphan_node_ids`), `assert_no_new_orphans` | orphan tespiti + stack trace | yok |
| Hata yakalama | push_error'ı başarısızlık saymaz (varsayılan) [?] | saymaz [?] | **sayar** (Logger) |
| CI eylemi | yok (kendi godot kurulumu) | `gdunit4-action` (Godot indirir, önbellekler, rapor yayınlar) | ci_local.sh |
| Repo yükü | addons/gut (~yüzlerce dosya) | addons/gdUnit4 (editör eklentisi) | 2 dosya |
**Geçiş değerlendirmesi [G]:** 236 test/28 dosya yeniden yazımı (M-L), eklenti import uyarıları (import adımımız uyarıyı hata sayar), ajanların yeni API öğrenmesi; kazanç: SceneRunner girdi simülasyonu, orphan sayacı, JUnit. Bunların ilk ikisi koşucumuza XS-S maliyetle eklenebilir (`Performance.OBJECT_ORPHAN_NODE_COUNT` farkı; `Input.parse_input_event` ile girdi — zaten `PlayerInput` soyutlaması bot girdisini veriyor, girdi simülasyonuna ihtiyaç az). **Öneri: kalmak (KR-009 korunur)**, eksikleri ekle. gdUnit4'ün 4.7.1'e kadar listelenmesi (4.7.2 [?]) ayrıca bağımlılık riski.

#### 3.5 Sahne testleri ve sahte nesneler
- Sözleşme-imza testi (`test_ui_fakes.gd:124`) iyi uygulama: sahte ile gerçek arasındaki sapma derlemede değil testte yakalanır. Aynı kalıp `NoiseBus` (S8) ve `Level` API (S4) sahteleri için henüz yok.
- Düğüm testlerinde sızıntı: GUT/gdUnit `autofree` + orphan sayacı; Godot `--verbose` çıkışta "Leaked instance: Sınıf:id" listesi basar, `Node.print_orphan_nodes()`/`get_orphan_node_ids()` yetim düğümleri verir; RefCounted döngüleri için `WeakRef` [O]. IS-029 için önerilen kapı: `ci_local unit` koşusunu `--verbose` ile de koşup "Leaked instance" satırlarını saymak (0 olmalı) + run_tests'te test başına orphan farkı.

#### 3.6 Ağ testi yaklaşımları
- Resmî API: `OfflineMultiplayerPeer` (varsayılan; tek süreçte "sunucu" gibi davranır), **aynı ağaçta sunucu + istemci**: `SceneTree.set_multiplayer(SceneMultiplayer.new(), NodePath("/root/Branş"))` ile dal başına ayrı MultiplayerAPI; iki `ENetMultiplayerPeer` 127.0.0.1 üzerinden tek süreçte bağlanabilir [O docs/forum]. Bu, kare adımlamalı, deterministik RPC/senkron birim testleri sağlar (gecikme yok; gecikme için yine proxy).
- Çok süreçli gerçek koşu (bizim net_smoke) sektörde "integration/soak" katmanıdır; GUT/gdUnit'in ağ desteği yok [O]. netfox (ağ eklentisi) kendi `vest` çerçevesiyle birim test eder [O]; çok süreçli koşu benzeri açık örnek bulunamadı [?].
- Değerlendirme [G]: üç katman — (1) `core/` düğümsüz kurallar (var), (2) süreç içi iki-peer ENet loopback (yok; S7/S8 RPC doğrulamalarını 30 süreçli koşuya gitmeden test eder), (3) net_smoke (var). CI süresi büyüdükçe (15 senaryo × 2) katman 2 kazanç sağlar.

#### 3.7 Görsel regresyon
- Godot'ta yerleşik `Image.compute_image_metrics(compared, use_luma)` → `max, mean, mean_squared, root_mean_squared, peak_snr` [O]; PNG okuma/yazma `Image.load_png_from_buffer/save_png`. Dış araç gerekmeden PSNR eşiğiyle baseline karşılaştırması yazılabilir.
- Genel ilke [O, bugnet 2025]: sabit kamera/çözünürlük/tohum, deterministik kare, tolerans eşiği, başarısızlıkta diff görseli. Bizde kukla animasyonu (KR-017, nefes/göz kırpma) ve rastgele NPC nüfusu determinizmi bozar → `--fixed-fps` + sabit tohum + bot zaman çizelgesi gerekir; CI ubuntu runner'da GPU yok, gl_compatibility ile `xvfb` + Mesa llvmpipe çalışabilir [?] (denenmedi). `screenshot.py` zaten PNG üretip boş/siyah denetimi yapıyor; eksik olan baseline + metrik karşılaştırma. Öncelik düşük (P3), oyun testi öncesi "ekran görüntüsü arşivi" olarak değer taşır.

#### 3.8 CI (GitHub Actions)
- Seçenekler [O]: `barichello/godot-ci` docker imajı (`4.7.2-stable` etiketi var; şablonlar imajda), `chickensoft-games/setup-godot@v2` (Ubuntu/Windows/macOS, `include-templates`, önbellek, `GODOT` env), `gdunit4-action`. Bizim yaklaşım (get_godot.sh + actions/cache) aynı işi yapıyor, Windows'ta da çalışıyor; değiştirmek için neden yok [G].
- GitHub önbellek: repo başına 10 GB, 7 gün erişilmeyen giriş silinir, restore-keys kısmi eşleşme [O]. Şablon önbelleği 1,3 GB; main'e 7 günden seyrek push olursa her build yeniden indirir (dakikalar; başarısızlık değil).
- İyileştirme adayları [G]: (a) `actions/*` sürümlerini SHA'ya sabitleme (tedarik zinciri; P3), (b) `--check-only` ile hızlı sözdizimi adımı gereksiz (import zaten derliyor), (c) CI'da `--verbose` sızıntı kapısı (3.5), (d) net adımının süresi: senaryo sayısı artınca `matrix` ile 0/150 ms paralel iki iş (P3).

#### 3.9 Dışa aktarma ve imzalama
- Godot export'ta imzalama: Windows'ta `SignTool`, diğer OS'te `osslsigncode`; ön ayarda `codesign/enable` + `identity` [O]. Steam dağıtımı SmartScreen/antivirüs kontrolünden kaçınır (gömülü PCK notu) [O docs]; OV sertifika ~85 $/yıl+, SmartScreen güveni için ya düzinelerce indirme ya EV (300 $+/yıl) [O, üçüncü taraf]. Azure Trusted Signing desteği Godot'ta [?] (doğrulanmadı).
- Değerlendirme [G]: KR-020 (önce aramızda) + Steam'in imza istememesi → **imzalama gerekmez**; arkadaş testinde SmartScreen "Daha fazla bilgi → Yine de çalıştır" notu test paketine yazılmalı. Konsol exe (`Insiders.console.exe`) ve PCK gömme mevcut, doğru.

#### 3.10 Linter/format: gdtoolkit
- gdtoolkit **4.5.0 (2025-10-09)** [O PyPI]; Python ≥3.7; typed dictionary (4.3.2), `@abstract` ve variadic (4.5.0) desteklenir; 4.6/4.7'ye özgü sözdizimi değişikliği az olduğundan parse riski düşük [?]. `gdlint` kuralları: ad kalıpları (function/class/signal/enum/const), `max-file-lines` (varsayılan 1000), `max-line-length` (100), `class-definitions-order`, `unused-argument`, `duplicated-load`, `expression-not-assigned`, `no-elif-return` vb.; `private-method-call` kuralı 4.3.2'de kaldırıldı (bizim tarayıcımız bu açığı kapatıyor) [O]. `gdformat` yıkıcı olabilir (VCS ile kullanın uyarısı) [O]; `gdradon` döngüsel karmaşıklık.
- Uygunluk [G]: `gdlint` + `.gdlintrc` (`max-file-lines: 400` → mimari §6 ölçüsünü otomatikleştirir, `max-line-length: 120`, sinyal adı snake_case) `ci_local tools` adımına eklenebilir (Python zaten var; `pip install gdtoolkit==4.5.*`). `gdformat` 7 ajanın worktree'lerinde diff gürültüsü yaratır; önce `--check` modunda ölçüm, benimseme kararı sonra. Bilinmeyen: parser bizim 11 bin satırı hatasız okuyor mu → XS deneme.

#### 3.11 Kod kapsamı ve mutasyon
- Godot 4 için satır kapsamı aracı **yok**: `jamie-pate/godot-code-coverage` 3.5 ile sınırlı, kaynak enstrümantasyonu (×1,7 yavaş, autoload `_ready` kapsanmaz) [O]. gdUnit4/GUT kapsam ölçmez [O].
- **gdmutant 0.1.3 (2026-09-21)**: mutasyon testi; GUT 9, gdUnit4 6 ya da `--runner command` ile **özel komut** (bizim run_tests.gd uyar); Godot 4.7.0'da doğrulanmış, Python ≥3.12 [O]. Kapsam yerine "mutasyon skoru" verir; `core/` gibi küçük, saf modüllerde (interaction_rules, perception, suspicion) anlamlı, tüm projede yavaş (mutant başına tam koşu) [G].
- Ucuz yerli ölçüm [G]: run_tests sonunda hangi `res://` betiklerinin yüklendiği (`ResourceLoader`/`get_script_method_list` değil; `Engine` düzeyinde yok) — pratik değil; dosya düzeyinde "test_*.gd var mı" eşlemesi (modül → test dosyası) tabloyu tutmak yeter.

### 4. Yapımıza uygunluk değerlendirmesi
- **Kalınacaklar:** kendi koşucu (KR-009), 4 autoload, bileşen modeli, sözleşme-imza sahteleri, çok süreçli net_smoke, get_godot.sh + actions/cache CI, imzasız build.
- **Eklenecekler (düşük maliyet, yüksek getiri):** orphan/sızıntı kapısı; bağımlılık tarayıcısının tam matris; `unsafe_*` warn ölçümü; typed Dictionary geçişi (iç içe sınırını bilerek); sahte saat; gdlint denemesi.
- **Erteleme/karar:** gdformat, görsel regresyon, süreç içi iki-peer düzeneği (spike), mutasyon testi (aylık el koşusu).
- KR-020 (önce aramızda MVP) ile uyum: hiçbir öneri oyun kapsamını büyütmez; hepsi iç kalite; ilk oyun testi öncesi yalnız P1'ler.

### 5. Bulgular
**Doğru yaptıklarımız**
1. `untyped_declaration=2` + 4.5+ Logger tabanlı hata yakalama: push_error'ı test başarısızlığı saymak GUT/gdUnit'te varsayılan değil; bizim koşucu daha katı [O/?].
2. Sözleşme-imza testi ve ui/ kapsülleme taraması (test_ui_fakes) — eklentisiz "contract test" kalıbı.
3. Çok süreçli ağ dumanı + gecikme proxy'si + dayanıklılık + bellek örnekleme: topluluk çerçevelerinde karşılığı yok.
4. CI: import adımında uyarı = hata, SHA-512 doğrulamalı ikili/şablon, build artifact + headless duman; Windows/Linux yerel eşdeğeri.
5. Bağımlılık yönü ve bileşen modeli, kalıtım derinliği 0-1, çatı yok (3.2-3.3 ile uyumlu).

**Saptığımız yerler**
6. `game.gd` 840 satır / 5+ sorumluluk; §6 ≲400 ölçüsünün 2 katı; "Faz 4'te bölünür" notu geç — testler özel üyelere bağlı (19 yer) olduğu için bölme gittikçe pahalılaşır.
7. Tipsiz `Array`/`Dictionary` 73 üretim yeri; 4.4+ typed Dictionary varken `Dictionary[int, Dictionary]` gibi en azından anahtar tipi verilebilir; `Variant` 22, `as` 74 (sessiz null).
8. Testlerde autoload özel üye erişimi (`Game._rpc_players`, `_add_player`, `_load_level_local`) — ui/ için yasak olan şey autoload için serbest; tarama yok.
9. Gerçek saate bağlı testler: 3-4 sn'lik polling döngüleri ve `create_timer` beklemeleri; yavaş makinede kırılgan, toplamda koşuyu uzatıyor.
10. Bağımlılık tarayıcısı §6 matrisinin yalnız bir hücresini denetliyor.
11. Test dosyaları da 400 satırı aşıyor (2 dosya; faz2-int'te 4) — §6 ölçüsü testleri kapsamıyor, kapsamalı mı karar.

**Riskler**
12. "ObjectDB leaked" uyarısı CI'da kapı değil (IS-029 sürüyor); RefCounted döngüsü ise `--verbose` listesinde görünür ama orphan sayacında görünmez.
13. Koşucu `Logger`/backtrace nedeniyle 4.5+'a bağlı; sürüm düşürme yok, yükseltmede (4.8 dev başladı [O]) Logger imzası değişebilir [?].
14. gdUnit4'e geçilseydi 4.7.2 uyumu listede yok; kalma kararını destekler.
15. CI net adımı doğrusal büyüyor (senaryo × 2); 20 dakikalık `timeout-minutes` yakınlaşabilir [?] (süre ölçümü yok).

### 6. Öneriler
| # | Öneri | Öncelik | Maliyet | Sahip | Kalem adayı + AC |
|---|---|---|---|---|---|
| 1 | Koşucuya orphan/sızıntı kapısı (IS-029 ile birleşir) | P1 | S | altyapi | **IS: Test hijyeni kapısı** — AC1 run_tests test başına `OBJECT_ORPHAN_NODE_COUNT` farkını raporlar, >0 ise FAIL (autofree sonrası); AC2 `ci_local unit` `--verbose` koşusunda "Leaked instance" satırı 0; AC3 mevcut 9 sızıntı kök nedeniyle giderilir (RefCounted döngüsü ise WeakRef) |
| 2 | Bağımlılık tarayıcısını §6 tam matrisine genişlet | P2 | S | altyapi | **IS: Bağımlılık matrisi testi** — AC1 `test_deps` her dizin için izinli hedef kümesini tablo olarak taşır (core→∅, autoload→core/data/levels/level.gd, entities→core/autoload/data, levels→core/data, ui→autoload); AC2 istisnalar (ThemeTokens görsel, UiInput statik, HUD/noise_ring load) satır birebir listede; AC3 mutasyon testi her hücre için |
| 3 | `unsafe_*` ölçüm turu: `unsafe_method_access`, `unsafe_property_access`, `unsafe_call_argument`, `return_value_discarded` = 1 (warn) ile import, sayım tablosu | P2 | XS | altyapi | **IS: Uyarı sıkılaştırma ölçümü** — AC1 dosya başına uyarı sayısı raporu; AC2 ≤ N yerde düzeltme planı (`is` + tipli yerel, `.call()`); AC3 import adımı yeşil kalır (karar: hangileri 2 olacak → karar gereken) |
| 4 | Tipsiz koleksiyonları typed'a çevir (anahtar/değer tipi; iç içe sınır belgelensin) | P2 | S | her modül sahibi (cekirdek 29, oynanis ~15, arayuz ~10, seviye ~6) | **IS: Typed koleksiyon geçişi** — AC1 üretim kodunda `: Array`/`: Dictionary` tipsiz sayısı 73 → ≤10 (gerekçeli istisna listesi); AC2 mimari §6'ya "iç içe typed yok; iç sözlük tipsiz kalır ya da küçük Resource" kuralı (koordinatör yazar); AC3 testler geçer, net_smoke 0/150 ms geçer |
| 5 | Testlerde autoload özel üye erişimini kaldır + tarama | P2 | S | cekirdek (test_game, test_player), oynanis (test_player_rules) | **IS: Autoload test dikişleri** — AC1 `_sanitize_name` → `core/` statik; AC2 `_rpc_*`/`_add_player`/`_load_level_local` çağrıları kamusal sözleşme ya da `tests/fixtures` üzerinden; AC3 `test_ui_fakes` tarzı tarama tüm `tests/unit` için (`Game._x`, `Net._x`, `NoiseBus._x` yasak) |
| 6 | `game.gd` bölme (5 → cephe + 4 yardımcı) | P2 | M | cekirdek | **IS: Game bölümlemesi** — AC1 `game.gd` ≤ 400 satır, S3 imzası değişmez (test_ui_fakes sözleşme testi geçer); AC2 RPC yolları/adları aynı (eski istemciyle protokol farkı yok, `PROTOCOL_VERSION` sabit); AC3 tüm net senaryoları 0/150 ms geçer; öneri 5'ten sonra |
| 7 | Sahte saat: `core/clock.gd` (statik `now_ms()`; testte sabitlenebilir) ve testlerin kare adımlamaya geçişi | P2 | S | cekirdek + oynanis | **IS: Deterministik zaman** — AC1 üretimde `Time.get_ticks_*` yalnız `core/clock.gd`'de; AC2 `test_game/test_net/test_player` duvar saati döngüleri yerine sahte saat/`process_frame` sayımı; AC3 birim koşu süresi ölçülür ve düşer |
| 8 | gdlint denemesi (parser uyumu + `.gdlintrc` ile max-file-lines 400) | P3 | XS→S | altyapi | **IS: gdlint** — AC1 `gdlint` tüm .gd dosyalarını parse eder; AC2 kural seti mimari §6 ile hizalı (`.gdlintrc`); AC3 `ci_local tools` adımına eklenir, CI'da pip kurulumu önbellekli; gdformat yalnız `--check` raporu (benimseme ayrı karar) |
| 9 | Süreç içi iki-peer ENet loopback test düzeneği (spike) | P3 | M | cekirdek | **IS: Loopback ağ fikstürü** — AC1 tek süreçte host + istemci `SceneMultiplayer` dalı, `set_multiplayer` ile; AC2 bir S7 RPC akışı (request_start → completed) kare adımlı test; AC3 net_smoke'a göre süre kazancı raporu |
| 10 | Görsel regresyon: baseline + `compute_image_metrics` PSNR eşiği | P3 | S | altyapi | **IS: Ekran görüntüsü karşılaştırma** — AC1 `screenshot.py --compare` baseline dizini, PSNR < eşik → FAIL + diff PNG; AC2 deterministik koşu (`--fixed-fps`, tohum, bot); AC3 CI'da değil, el ile/test checkpoint öncesi |
| 11 | Mutasyon testi `core/` için aylık el koşusu (gdmutant, özel runner) | P3 | XS | altyapi | **IS: Mutasyon ölçümü** — AC1 `gdmutant --runner command` ile `core/` skoru; AC2 hayatta kalan mutantlar için test kalemi önerisi; CI kapısı değil |
| 12 | CI küçük bakımlar: actions SHA sabitleme, net adımı matris (0/150 ms paralel), süre ölçümü | P3 | XS | altyapi | **IS: CI bakımı** — AC1 adım süreleri iş özetine yazılır; AC2 net 0/150 ayrı işler; AC3 `actions/*` SHA pinli |

### 7. Bir sonraki tur için açık sorular
- `set_multiplayer` ile iki ENet peer'ın tek süreçte 4.7.2'de sorunsuz çalıştığı doğrulanmalı (spike, öneri 9) [?].
- gdtoolkit 4.5.0 parser'ının 4.7 sözdizimimizi (typed dictionary literal'leri, `&"..."`, lambda) hatasız okuyup okumadığı [?].
- CI ubuntu runner'da gl_compatibility + xvfb/llvmpipe ile pencereli ekran görüntüsü alınabiliyor mu [?].
- `Logger._log_error` imzası 4.8'de değişiyor mu (sürüm yükseltme riski) [?].
- Testler için 400 satır ölçüsü uygulanacak mı (test dosyası bölme kuralı) — karar.
- `@abstract` yasağı (KR-018 C uyarınca) mimari §6'ya açık yazılsın mı — karar.
- `unsafe_*` uyarılarından hangileri hata (2) olacak — ölçüm sonrası karar (öneri 3).

### 8. Kaynaklar
- Godot docs, GDScript warning system (4.7): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/warning_system.html
- Godot docs, ProjectSettings `debug/gdscript/warnings/*` varsayılanları: https://docs.godotengine.org/en/stable/classes/class_projectsettings.html
- Godot docs, Static typing (typed Dictionary, iç içe sınır, `as`): https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/static_typing.html
- Godot docs, Godot interfaces (duck typing, gruplar, Callable): https://docs.godotengine.org/en/stable/tutorials/best_practices/godot_interfaces.html
- Godot docs, Autoloads vs regular nodes: https://docs.godotengine.org/en/stable/tutorials/best_practices/autoloads_versus_internal_nodes.html
- Godot docs, Command line (`--headless`, `--check-only`, `--import`, `--verbose`, `--fixed-fps`): https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- Godot docs, OfflineMultiplayerPeer: https://docs.godotengine.org/en/stable/classes/class_offlinemultiplayerpeer.html
- Godot forum, server + client aynı ağaçta (`set_multiplayer`): https://forum.godotengine.org/t/multiplayer-server-and-client-in-the-same-scene-tree/127134
- Godot docs, Image.compute_image_metrics: https://docs.godotengine.org/en/stable/classes/class_image.html
- Godot docs, Exporting for Windows (codesign, SmartScreen, Steam notu): https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
- Godot 4.4 sürüm notu (typed Dictionary): https://godotengine.org/releases/4.4/ · 4.5 (`@abstract`, variadic, Logger, backtrace): https://godotengine.org/releases/4.5/ · 4.6: https://godotengine.org/releases/4.6/ · 4.7: https://godotengine.org/releases/4.7/
- Godot 4.7 yükseltme rehberi (tipli dönüş mirası): https://docs.godotengine.org/en/latest/tutorials/migrating/upgrading_to_godot_4.7.html
- Godot 4.8 dev 1 duyurusu: https://godotengine.org/article/dev-snapshot-godot-4-8-dev-1/
- Tipli GDScript performans ölçümü (2024, 4.2): https://www.beep.blog/2024-02-14-gdscript-typing/
- Döngüsel bağımlılık (class_name/preload): https://forum.godotengine.org/t/understanding-unsupported-cyclic-dependencies/142828 · https://bugnet.io/blog/fix-godot-resource-preload-error-cyclic
- GUT 9.6.1 belgeleri: https://gut.readthedocs.io/en/latest/ · Komut satırı: https://gut.readthedocs.io/en/latest/Command-Line.html · Bellek/orphan: https://gut.readthedocs.io/en/latest/Memory-Management.html
- gdUnit4 v6.2.1 (uyum tablosu, özellikler): https://github.com/MikeSchulze/gdUnit4 · gdunit4-action: https://github.com/godot-gdunit-labs/gdUnit4-action
- ObjectDB sızıntısı (`--verbose`, print_orphan_nodes): https://bugnet.io/blog/how-to-fix-objectdb-instances-leaked-at-exit-warnings-in-godot · https://forum.godotengine.org/t/why-i-get-warning-objectdb-instances-leaked-at-exit-run-with-verbose-for-details-from-one-scene-and-not-from-other-scene-with-same-setting/95708
- barichello/godot-ci (4.7.2-stable imajı): https://hub.docker.com/r/barichello/godot-ci · chickensoft setup-godot v2: https://github.com/chickensoft-games/setup-godot
- GitHub Actions önbellek sınırları: https://docs.github.com/en/actions/reference/dependency-caching-reference
- gdtoolkit (4.5.0, 2025-10-09): https://pypi.org/project/gdtoolkit/ · sürümler: https://github.com/Scony/godot-gdscript-toolkit/releases · gdlint kuralları: https://github.com/Scony/godot-gdscript-toolkit/wiki/3.-Linter
- godot-code-coverage (yalnız 3.5): https://github.com/jamie-pate/godot-code-coverage · gdmutant 0.1.3: https://pypi.org/project/gdmutant/
- netfox / vest (ağ eklentisi test yaklaşımı): https://github.com/foxssake/netfox · https://godotengine.org/asset-library/asset/edit/17638
- Görsel regresyon ilkeleri: https://bugnet.io/blog/how-to-automate-screenshot-comparison-testing
- Kod imzalama maliyeti (OV/EV): https://godotengine.org/qa/70752/code-signing-certificate-others-windows-export-application
