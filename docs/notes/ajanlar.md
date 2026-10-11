# Ajan düzeni ve koordinatör protokolü (2026-10-01)

Kullanıcı yalnızca koordinatörle muhatap olur. Koordinatör = Claude Code ana oturumu (alt ajanlar başka ajan başlatamaz ve kullanıcıyla konuşamaz). Uzman ajanlar `.claude/agents/` altında tanımlıdır; koordinatör onları Agent aracıyla kalem başına görev paketiyle çalıştırır, raporlarını toplar, kararı verir, kullanıcıya yalnız çıktıyı iletir. Takip projesindeki düzenin oyun projesine uyarlanmış hâlidir; farklar en sonda.

## Ajanlar ve sahiplik
| Ajan | Sahip olduğu iş | Model |
|---|---|---|
| cekirdek | Ağ ve oturum: `autoload/{net,args,game}.gd`, `main.tscn/main.gd`, seviye yükleme ve oyuncu üretimi, `tools/{net_smoke,latency_proxy}.py`, `tests/net/` altyapısı ve `tests/fixtures/`; ileride lobi mantığı, GodotSteam köprüsü, kayıt sistemi | inherit |
| oynanis | Oyun kuralları ve varlıklar: `entities/**` (oyuncu, PlayerInput, Interactable ve nesneler, siviller, ileride muhafızlar), `autoload/noise.gd`, `core/**`, ilgili `data/*.tres`; ileride uyarı/şüphe, ganimet, ekonomi kuralları | inherit |
| seviye | Dünya ve içerik: `levels/**`, seviye şablonları/modülleri, görsel yer tutucular ve ileride CC0 asset entegrasyonu, ışık, seviye `data/*.tres`; ileride senaryo üretici ve doğrulayıcı | inherit |
| arayuz | Oyuncu arayüzü: `ui/**` (menü, bağlantı/lobi ekranı, HUD, ileride plan masası ve sığınak ekranları), tema token'ları ve ton altyapısı, `i18n/texts.csv` bakımı | inherit |
| altyapi | Proje iskeleti ve teslim: `project.godot` (ayar, autoload kaydı, girdi haritası, katmanlar), `tests/{run_tests,t}.gd`, `tools/{get_godot,ci_local}.sh`, `.github/workflows/**`, `.gitignore`, export ön ayarları ve build; faz çıkış testleri | inherit |
| denetci | Salt okunur bağımsız doğrulayıcı: kalemin AC'lerini sıfırdan tekrarlar, sınır/sözleşme denetimi, PASS/FAIL | inherit |
| kosucu | Test koşucu ve kayıt okuyucu (salt okunur): ci_local adımları, net_smoke senaryoları 0/150 ms (FAIL'i bir kez yeniden koşar, YÜK işaretini ayırır), ekran görüntüsü alma, `kayit_ozet` ile oyun testi kayıtları, git/grep bakışları; kısa PASS/FAIL tablosu. Karar vermez, kod yazmaz (KR-042) | haiku |
| tasarim | Tasarım danışmanı (Fable): oyun tasarımı soruları, denge, kapsam; belirli noktalarda gidişat değerlendirmesi ve öneri raporu (surec.md §5a); yalnız koordinatör isterse `docs/tasarim/**` yazar | fable |

Ortak yüzeyler: `project.godot` yalnız altyapi'nin (başka ajanın ihtiyacı → "Karar gereken" ya da kalem); `i18n/texts.csv` satır ekleme herkese serbest, mevcut satırı değiştirmek arayuz'un; `data/` dosyası onu tanımlayan ajanın; seviyeye nesne yerleştirme kalemin Dokunulacak listesinde açıkça yazıyorsa içerik sahibi ajan yapabilir. Testler modül sahibine aittir. `docs/**` koordinatörün (tasarim/ hariç).

Model yönlendirme (KR-042, 2026-10-11, kullanıcı isteği; Haiku 5.5 = en hızlı/en ucuz, Sonnet 5.5'in gerisinde: Terminal-Bench 4.0 %39 vs %71, SWE-bench Pro %65 vs %81):
- **Haiku** (`kosucu` ajanı ya da Agent çağrısında `model: "haiku"`): test/CI koşma ve yeniden koşma, karşılaştırmalı koşular, ekran görüntüsü alma, oyun testi kaydı özetleme, geniş kod/doküman araması (Explore), dış kaynak/lisans toplama, AC'si tam yazılmış **XS** kalemler (metin anahtarı, tema token'ı, ses düzeyi/`.tres` sayı ayarı, doküman satırı, test ekleme, nit düzeltmesi) — yalnız ağ/yetki/kablo dışı ve tek ajanın alanında.
- **Ana model (inherit)**: ağ/yetki/kablo düzeni, NPC beyni ve oynanış kuralları, çok dosyalı S/M kalemler, mimari/sözleşme değişikliği, bağımsız denetim (denetci), birleştirme çakışmaları. **Fable**: tasarım (tasarim), teknik araştırma (arastirmaci).
- Haiku'nun teslimi aynı kapılardan geçer (ci_local + koordinatör diff okuması). İki kez kapıdan dönen Haiku işi ana modele yükseltilir; pilot ilk 5 Haiku kaleminde geri dönüş oranı ölçülür (kararlar.md KR-042).
- Paralellik: LLM ağırlıklı işler (okuma, arama, doküman, özet) paralel Haiku ajanlarına bölünür; **CPU ağırlıklı işler (Godot/net_smoke/ekran görüntüsü) aynı anda en çok bir** — tek PC'de paralel koşu sahte zamanlama FAIL'i üretir (2026-10-06 tam CI).

Düşünme seviyesi (2026-10-02, kullanıcı onayı): denetci, cekirdek ve tasarim `effort: high` (hata bulma, ağ/yetki kodu, tasarım derinliği); diğerleri varsayılan.

Ajanlar arası sözleşmeler `docs/notes/mimari.md` S1-S9'da yaşar, raporlarda değil. Sözleşme değişikliği koordinatör kararıdır, önce dokümana yazılır.

## Skill'ler ve AGENTS.md (2026-10-03, kullanıcı isteği)
"Nasıl yapılır" bilgisi ajan tanımlarından ayrı, araçtan bağımsız reçeteler olarak `.claude/skills/` altında: `test-yaz`, `ag-senaryosu`, `npc-ekle`, `seviye-duzeni`, `metin-ve-tema`, `kalem-kapat`, `oyunu-ac`. Başka bir geliştirici kendi ajanlarıyla çalışırsa giriş `AGENTS.md` + bu skill'ler; bu dosyadaki ajanlar yalnız rol/sahiplik/sınır tanımıdır. Ajan tanımları ve skill'ler İngilizce (KR-030; raporlar Türkçe). Skill güncellemesi koordinatörde (hook `.claude/` yazımını ajanlara kapatır); ajan, reçete eksik/yanlışsa raporunda "Karar gereken" altında önerir.

## Ortak ajan kuralları (her ajan dosyasında tekrarlanır)
1. Proje kökü = repo kökü (ana oturumun çalışma dizini; ya da koordinatörün verdiği worktree yolu). İşe `docs/project-index.md` ile başla; yalnız kalemin `docs/surec/backlog.md` bölümünü ve "Oku" listesini aç. Bu projede Takip'in kuralları geçmez.
2. Yalnız kalemin **Dokunulacak** listesinde çalış; **Dokunulmayacak**'a ya da başka ajanın alanına giren iş görürsen dokunma, raporda "Sınır dışı" yaz. Ortak dosyalara ekleme serbest, mevcut davranışı değiştirmek "Karar gereken".
3. Commit, push, branch değiştirme YAPMA; değişiklikler çalışma ağacında kalır. Gizli değer yazdırma.
4. Kullanıcıya soru sorma; karar gerektiren her şeyi raporda "Karar gereken" başlığıyla, seçenek + önerinle koordinatöre bırak.
5. Godot: `GODOT` ortam değişkeni, yoksa `tools/get_godot.sh` ile `.tools/godot`. Yazdığın her modül için test ekle (birim: `tests/unit/test_*.gd`; ağ davranışı: `tests/net/*.json` senaryosu) ve raporda çalıştır. Yeni dosyadan sonra `--import` çalıştır; uyarı-hata bırakma.
6. Rapor (en fazla ~20 satır; ilk satır `Kalem: US-nnn`): **Yapılan** / **Test** (AC numaralı komut + sonuç) / **Açık kalan** (her madde "kalem adayı" | "nit") / **Karar gereken** (seçenek + öneri) / **Sınır dışı**.
7. Pano dosyalarına (`docs/notes/durum.md`, `docs/surec/{backlog,kararlar,gecmis}.md`) dokunma.
8. Ajan dosyalarında `description` değeri çift tırnak içinde yazılır.

## Kalite katmanları
> **Geçerli kip: KR-028 hafif kontrol (2026-10-03):** katman 2 yalnız ağ/yetki/kablo düzeni kaleminde, katman 3'te çürütme kapalı, katman 4 tam CI günde bir. Ayrıntı kararlar.md KR-028.

1. **Ajan içi:** sahip ajan kendi testlerini yazar, AC'leri komut çıktısıyla gösterir.
2. **Bağımsız denetim (denetci):** raporu okumadan AC'leri sıfırdan tekrarlar, testleri ve yerel CI'ı koşar, diff'i Dokunulacak listesine ve sözleşmelere karşı denetler, bulgularını önce kendisi çürütmeye çalışır. Ekran/his gerektiren kabul (pencere görüntüsü, oynanış hissi, gerçek internet) için headless eşdeğerini koşar ve kullanıcı adımlarını listeler (doğrulama kalemi).
3. **Koordinatör diff okuması:** her kalemde tek geçiş (doğruluk, sözleşme sadakati, sadelik); M kalemde ve ağ/yetki kodunda ayrıca çürütmeli inceleme (ayrı ajan, salt okunur).
4. **CI kapısı:** `tools/ci_local.sh` push öncesi zorunlu; uzak CI dev ve main push'unda.
5. **Tasarım değerlendirmesi (tasarim / Fable):** faz kapanışında ve ara noktalarda oyunun tasarıma ve oyun zevkine uyumu; öneriler ON kaydına, karar kullanıcıda (surec.md §5a).
6. **Oyun testi:** her faz sonunda kullanıcı + arkadaşlar gerçek oyun testi (doğrulama kalemi); bulgular `docs/surec/geri-bildirim.md`'ye GB olarak.

## Karar yetkisi
Koordinatör sormadan karara bağlar: teknik tercihler (motor ayarı, mimari, ağ modeli ayrıntısı, test yöntemi), dosya/isimlendirme, ajan bulgularının önceliği, sıra ve paralellik, sözleşmeler, `docs/tasarim/oyun-tasarimi.md`'de zaten kararlaştırılmış her şey. Tasarım belgesinin sustuğu oynanış ayrıntısında önce tasarim ajanına danışır, sonra karar verir; kararı `kararlar.md` günlüğüne tek satır yazar.

Kullanıcıya gider (faz plan mesajında toplu, bir kez; cevapsız kalan KR kimliğiyle hatırlatılır):
- Oyun ve kapsam tercihleri: tasarım yönünü değiştiren kararlar, MVP kapsamı, faz sırası, oyun adı.
- Kullanıcının hesabını/cihazını gerektiren işler: kendi PC'sinde test, arkadaşlarla oyun testi, Tailscale kurulumu, Steamworks hesabı.
- Para harcayan ya da geri alınamaz işler (Steamworks 100 $, mağaza sayfası, ücretli asset).
- Faz kapanışında devam/dur onayı.

## Kullanıcıya rapor formatı
```
US-nnn — <ad>: Bitti / Engelli (KR-nnn)
Çıktı: <ne çalışıyor, nasıl doğrulandı; 2-5 satır>
Sizden gereken: <varsa>
Sırada: <sonraki kalem>
```
Faz kapanış + plan mesajının biçimi `docs/surec/surec.md` §7'de.

## Takip düzeninden farklar (bilinçli)
- Haftalık iterasyon yerine **faz** (kilometre taşı) ve **dilim** (KR-033: 5-8 kalem, bir context): her dilim sonu durma noktası (devir + kullanıcı "devam"); faz kapanışında oynanabilir build + kullanıcı onayı.
- "Canlıda/UPDATER_OK" yok; yayın = faz kapanışında `dev → main` fast-forward + `faz-N` etiketi (oynanabilir sürüme geri dönmek için).
- Tasarım danışmanı ajanı (tasarim, Fable) eklendi; teknik kararlar koordinatörde.
- Paralel paketler ayrı git worktree'de (`.claude/worktrees/agent-<id>`, Agent aracının `isolation: worktree`; taban `worktree.baseRef = head`; ayrıntı surec.md §6), birleştirme denetci PASS sonrası. Kırmızı çizgiler (ajan commit/push/merge yapmaz, pano ve `.claude` yapılandırmasına dokunmaz, denetci yazmaz) `.claude/hooks/agent_guard.py` ile deterministik (IS-053); engellenen çağrıda ajan nedeni stderr'den görür ve işi koordinatöre bırakır; hook ve ajan tanımı değişikliği yalnız koordinatörde.
- FR/NFR kataloğu yok; tasarım belgesi + kalem AC'leri yeterli. Kırmızı çizgiler `surec.md` §9'da.
