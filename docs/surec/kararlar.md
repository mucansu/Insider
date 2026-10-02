# Kararlar

Yalnız koordinatör yazar. Bekleyen KR'ler kullanıcıya faz plan mesajında toplu sorulur (surec.md §8).

## Bekleyen
| KR | Soru | Seçenekler (öneri) | Etkilenen | Varsayılanla ilerlenebilir mi |
|---|---|---|---|---|
| KR-013 | Oyunun kalıcı adı | "Insiders" çalışma adı olarak kalsın, mağaza sayfasından (Faz 5) önce karar [öneri] / şimdi başka ad | Faz 5 Steam sayfası | Evet (çalışma adı) |
| KR-014 | Steamworks hesabı ve 100 $ uygulama ücreti | Faz 5'te, MVP keyif verdiğinde [öneri] / daha erken | Faz 5 | Hayır (para) |

## Verilen
### KR-001 — Oyun konsepti (2026-09-30, kullanıcı)
Fable danışmanlığında çıkan seçeneklerden kullanıcı co-op soygun (Insiders) fikrini seçti ve genişletti: kalıcı karakter, Minecraft Dungeons tarzı yavaş gelişim, silah/ekipman parayla satın alınır, yetenekler, bakkaldan merkez bankasına senaryo merdiveni. Kaynak: docs/tasarim/oyun-tasarimi.md.

### KR-002 — Platform ve oyuncu sayısı (2026-09-30, kullanıcı)
Steam üzerinden arkadaşlarla online; merkez 3 kişi (2 ve 4 de çalışır). Oyunculardan ikisi İsveç'te, biri Türkiye'de (~50-90 ms RTT): host İsveç'ten, gecikme toleranslı tasarım (mimari.md S2).

### KR-003 — Görünüm (2026-10-01, kullanıcı)
2D üstten başla; oyun sevilir ve ilerlerse 3D sonra zorlanabilir. Sonuç: oyun mantığı görselden ayrı (mimari.md §1).

### KR-004 — Keşif fazı (2026-10-01, kullanıcı + koordinatör)
Bir oyuncu soyulacak yere müşteri gibi girip gözlem yapar; gördükleri haritaya/krokiye otomatik işlenmez, ekibe hafızadan aktarılır; ileri kademelerde gizli önlemler. Koordinatör eklemeleri (kullanıcı onayladı): üç paralel keşif rolü, keşfin bedeli (oyalanma şüphesi, yüz tanınma), görüş hattı/sis, değerli bilginin zamansal olması, keşif ekipmanları, hazır duvarlı kroki, keşif-soygun arası ara sıra değişiklik. Kırmızı çizgi: surec.md §9.

### KR-005 — Ton (2026-10-01, kullanıcı)
Noir / kuru soygun komedisi ile başla; ileride ton seçimi oyuncuya bırakılabilir, yalnız kozmetik katman (palet, müzik/SFX, metin setleri, UI teması), kurallar değişmez, online'da host seçer. Altyapı baştan: metin anahtarları + tema token'ları (mimari.md S9). İkinci ton MVP sonrası.

### KR-006 — Çatışma kapsamı (2026-10-01, kullanıcı)
İlk sürümde minimal: gizlilik varsayılan, gürültü = baskı altında kaçış + kısa koridor tutma; silahlar az, ölümcül olanlar yüksek bedelli. Sonraki sürümlerde artabilir; can/hasar/silah veri güdümlü, muhafız davranışı genişletilebilir yazılır.

### KR-007 — Motor ve dil (2026-10-01, kullanıcı + koordinatör)
Kullanıcı Godot'yu seçti. Koordinatör: Godot 4.7.2-stable (oturumdaki en yeni kararlı), GDScript katı statik tipleme; GodotSteam Faz 5'te (GDExtension ileri uyumlu; gerekirse ayrı IS ile sürüm hizası).

### KR-008 — Ağ modeli (2026-10-01, koordinatör)
Host yetkili + istemci yetkili kendi hareketi; Godot yüksek seviye multiplayer (MultiplayerSpawner/Synchronizer + RPC); Faz 1-4 ENet, Faz 5 SteamMultiplayerPeer aynı Net arayüzünün arkasında. Deterministik lockstep yok. Ayrıntı mimari.md S1-S3.

### KR-009 — Test yöntemi (2026-10-01, koordinatör)
Bağımlılıksız kendi birim test koşucumuz (tests/run_tests.gd) + çok süreçli headless ağ duman testi (tools/net_smoke.py, senaryo JSON'ları) + Python UDP gecikme proxy'si (0 ve 150 ms RTT). Gerekçe: eklenti bakım yükü yok, AI ajanın okuyup yazması kolay, ağ davranışı gerçek süreçlerle sınanır.

### KR-010 — Süreç (2026-10-01, kullanıcı + koordinatör)
Takip düzeni uyarlandı: faz = durma noktası, kalem = iş birimi, denetci PASS olmadan Bitti yok, ajanlar commit atmaz; faz sonunda dev → main ff + `faz-N` etiketi; paralel paketler ayrı worktree'de. Farklar ajanlar.md sonunda.

### KR-011 — Repo (2026-10-01, koordinatör)
Repo GitHub'da `mucansu/Insider` (kullanıcı açtı, 2026-10-01; bulut oturumundaki yerel klasör adı `insiders`), private. Branch'ler: `dev` (çalışma), `main` (faz sonu oynanabilir sürüm).

### KR-012 — Görsel yer tutucular (2026-10-01, koordinatör)
Faz 1-2'de görseller geometrik yer tutucu (Polygon2D/ColorRect, tema token renkleri); CC0 asset (Kenney vb.) entegrasyonu ayrı kalem, lisans kaydı docs/notes/assetler.md.

### KR-015 — MVP faz planı (2026-10-01, koordinatör; tasarim danışmanlığı)
Fable incelemesiyle: Faz 0'a GodotSteam × 4.7.2 uyumluluk kontrolü (IS-004); Faz 1 kesildi (sivil/sindirme, T1 kilit, gürültü v0 → Faz 2), Faz 1'e Windows/Linux build eklendi (arkadaş testi editörsüz olmalı); Faz 2'ye kamera = statik muhafız, Steam spike, kopma davranışı, replay, temel SFX, ucuz keşif ön testi; tohum/rastgeleleştirme Faz 4'ten Faz 3'e. Faz başına ölçülebilir çıkış kriterleri backlog.md §1'de.

### KR-016 — Fable tasarım değerlendirmeleri (2026-10-01, kullanıcı)
tasarim ajanı (Fable) belirli noktalarda (faz kapanışı, fazın oynanabilir dilimi sonrası, oyun testi sonrası) oyunun gidişatını değerlendirir; oyun zevkini/mekaniği tam karşılamayan noktaları önerileriyle, temel yapı kurulduktan sonra (Faz 2 kapanışından itibaren) yeni özellik ve geliştirme önerilerini raporlar. Öneriler bağlayıcı değil; ON kaydına girer, faz plan mesajında kullanıcıya sorulur. Süreç: surec.md §5a, kayıt: surec/oneriler.md.

### KR-017 — Animasyon ve karakter stili (2026-10-01, kullanıcı + koordinatör)
Kullanıcı: ne retro/klasik platform oyunu gibi ne gerçekçi; anime oyunlarının tatlılığı ve zarafeti, kendine has akıcılık, sert/itici değil. Koordinatör uygulaması: sanatçısız **prosedürel "kukla" karakterler** — birkaç yumuşak parçadan (iri baş + yüz/gözler, rol siluetini veren şapka/kapüşon, küçük gövde, eller, atkı/palto ucu) oluşan şirin oranlı (chibi'ye yakın) figürler; tüm animasyon kodla: yumuşatma (lineer hareket yok), yay/aşma (spring/overshoot), hazırlık ve devam (anticipation/follow-through), ezilme-esneme, yürüyüşte sekme + harekete eğilme, sızmada çömelme, koşuda uzama + toz, nefes alma, göz kırpma ve bakış yönü, tepki balonları ("?" "!") pop animasyonu, atkı/palto ucu için ikincil hareket (verlet). Ton noir kalır (KR-005): koyu dünya + zarif, okunur karakterler. Görsel katman durum okur, mantığa dokunmaz (KR-003); 3D'ye geçilirse aynı ilke toon/cel shading ile sürer. GDD §14'e IS-007'de işlenir; uygulama Faz 2 "karakter kuklası v0" kalemi.

### KR-018 — OOP ve genişletilebilirlik kuralları (2026-10-01, kullanıcı isteği + tasarim/Fable danışması + koordinatör)
Kullanıcı OOP ilkelerine (kapsülleme, polimorfizm …) uyup uymadığımızı ve yeni harita/karakter/ekipman eklemenin kolay olup olmayacağını sordu. Fable değerlendirmesi: büyük ölçüde uyuyoruz (sözleşmeler önce yazılmış, iç durum gizli, ui/'nin yalnız sözleşmeye eriştiği testle korunuyor, ton/renk/metin/seviye veri güdümlü, kalıtım derinliği sıfır). Godot'da genişletilebilirlik sınıf ağaçlarından değil bileşim + veri dosyalarından gelir. Koordinatör kararları (A — şimdi): S7 Interactable bileşen modeli; S4 `Level` API'si; bağımlılık yönü kuralı ve `players()` → slot (game.gd ui'ye bakmaz); S10 içerik verisi kuralı (`data/<tür>/<id>.tres`, id ağda, host doğrular, etki = tipli Resource + core çözücü); S11 NPC bileşenleri (Faz 2); §6 kalıtım tavanı, çatı yok, sadelik ölçüsü; entities/ kapsülleme tarama testi (IS-005). (B — kalem gelince): karo öznitelik tablosu (GB-02), Economy ayrımı + StatBlock çözücü + ton oturum durumu (Faz 4), şablon/modül üretici (Faz 3), taşıma iç sınıfları (Faz 5). (C — gerekmez): autoload class_name dikişi, şimdi 3D soyutlama, karo başına Resource, genel etki/olay çerçevesi. Uygulama: IS-010 (US-004'ten önce).

## Günlük
- 2026-10-01 (US-004): AC5 eşiği seçenek (a): host↔istemci 32 px, istemci↔istemci 48 px (eşitleme host üzerinden iki bacak; 140 px/sn × ~280 ms ≈ 40 px fizik sınırı). Tamponu küçültmek (b) GDD §12'ye aykırı. Gecikmeye duyarlı eşik (c) Faz 2 adayı. Ara değerleme yöntemi mimari S2'de.
- 2026-10-01 (IS-010): Fikstür oyunculu ağ senaryolarında `samples_near` eşiği 40 px (ara değerleme yok + host üzerinden iki bacak); gerçek oyuncu sahnesiyle 32 px. Kökü Level olmayan seviye artık reddedilir.
- 2026-10-02 (IS-011): Yerelde Windows yolu seçildi (WSL kurulu değil; oyun Windows'a çıkıyor); ci_local Linux + Windows/Git Bash, yeni `tools` adımı (araç testleri), `PYTHONUTF8=1`. t1 denetci FAIL: Windows torun toplaması yalnız ebeveyn pid'iyle → pid yeniden kullanımında ilgisiz süreçler (masaüstü dahil) öldürülebilirdi; t2'de oluşturma zamanı süzgeci + `/T` kaldırıldı, PASS. Kalan nit (kalem adayı, IS-005'e): `known` ara düğümün pid'i grace süresinde yeniden kullanılırsa çocukları ağaca girebilir — düğümün şimdiki zamanı kayıttan farklıysa aranmasın. POSIX'te kök SIGTERM'le ölüp torun sinyali yok sayarsa torun kalır (bugün etkisiz; Linux Godot tek süreç).
- 2026-10-01 (US-001 t1): denetci FAIL (ENet paket kısma blocker'ı: düşük gecikmede güvenilmez senkron paketleri atılıyor) + çürütmeli inceleme 3 should-fix (auth sırasında leave temizliği, `_sanitize_name` O(n²) donma, 150 ms koşusunun gecikmeyi doğrulamaması). Hepsi t2'de. GDD §12 sert ağ profili fikstür senaryolarında kapı değil (fikstürde interpolasyon yok); gerçek oyuncu sahnesiyle IS-005 çıkış testinde koşulur.
- 2026-10-01 (US-001): Geç katılma el sıkışmada seviye yolu ile çözüldü; S3 uygulama notları ve eklemeler mimari.md'ye yazıldı (imza değişikliği yok). latency_proxy testi IS-005'e. `--reorder` modunda motor içi ERROR satırı bilinen nit.
- 2026-10-01 (IS-009): Host açılırken de Vazgeç görünür (seçenek a) + 10 sn zaman aşımı; `level_load_failed` sinyali ve `expect_warning()` yardımcısı Faz 2 adayı.
- 2026-10-01 (IS-008): LEVEL_* noir değerleri MUTED'dan bağımsız sabit (seçenek A); seviye renkleri `tone().level_*`'tan (mimari S9). Ton doğrulayıcı Faz 4 ton altyapısına.
- 2026-10-01 (US-003): S7'ye `interaction_target_changed(action_key)` eklendi (HUD istemi); S5'e `pause` eylemi ve ui_accept/ui_cancel gamepad olayları (IS-009); oyun içi menü açıkken oyun girdisi `UiInput.is_gameplay_input_blocked()` ile engellenir; UI sahneleri autoload'da preload edilmez. MUTED #868a92 (AA kontrast).
- 2026-10-01 (US-002): Seviyeler ASCII .txt'den üretilir; S4'e ekleme: `Tiles` düğümü, kapı işareti dönüş kuralı, `BackroomDoor` işareti, üretim kuralı (mimari.md S4). Kasa yalnız tezgâh arkasından boşaltılır (US-005 AC2). LEVEL_* token'ları IS-008'e.
- 2026-10-01: Süreç ve ajan dosyaları kuruldu (IS-001).
- 2026-10-01: GDD v0.1 yazıldı (IS-002, tasarim); faz planı KR-015 ile düzeltildi.
- 2026-10-01 (IS-004): GodotSteam GDExtension 4.22.1 (SDK 1.65, compatibility_minimum 4.4) Godot 4.7.2'de yükleniyor; `Steam` tekili ve yerleşik `SteamMultiplayerPeer` var, ayrı SMP eklentisi (expressobits) kullanılmayacak (çift kayıt hatası). 4.7.2 kilidi değişmiyor. Resmî kaynak doğrulaması ve CI çift-import önlemi Faz 5'e kalem olarak yazıldı.
- 2026-10-01: Araştırma/ölçüm kalemleri (repoya dosya eklemeyen) denetci yerine koordinatör okumasıyla kapanır (surec.md §4 notu).
- 2026-10-01 (IS-003): Gürültü autoload'ı `NoiseBus` (yerleşik `Noise` sınıfıyla ad çakışması; dosya autoload/noise.gd). `.translation` dosyaları gitignore'da (Godot VCS önerisi), import iki geçiş. `.gitattributes` (LF) IS-003'e eklendi. Test yardımcıları is_true/is_false.
- 2026-10-01: GitHub entegrasyonu repo oluşturamadı (403); repo kullanıcı tarafından açılacak, iş yerelde sürüyor.
