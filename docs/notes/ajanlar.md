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
| tasarim | Tasarım danışmanı (Fable): oyun tasarımı soruları, denge, kapsam; belirli noktalarda gidişat değerlendirmesi ve öneri raporu (surec.md §5a); yalnız koordinatör isterse `docs/tasarim/**` yazar | fable |

Ortak yüzeyler: `project.godot` yalnız altyapi'nin (başka ajanın ihtiyacı → "Karar gereken" ya da kalem); `i18n/texts.csv` satır ekleme herkese serbest, mevcut satırı değiştirmek arayuz'un; `data/` dosyası onu tanımlayan ajanın; seviyeye nesne yerleştirme kalemin Dokunulacak listesinde açıkça yazıyorsa içerik sahibi ajan yapabilir. Testler modül sahibine aittir. `docs/**` koordinatörün (tasarim/ hariç).

Ajanlar arası sözleşmeler `docs/notes/mimari.md` S1-S9'da yaşar, raporlarda değil. Sözleşme değişikliği koordinatör kararıdır, önce dokümana yazılır.

## Ortak ajan kuralları (her ajan dosyasında tekrarlanır)
1. Proje kökü `/home/user/insiders` (ya da koordinatörün verdiği worktree yolu). İşe `docs/project-index.md` ile başla; yalnız kalemin `docs/surec/backlog.md` bölümünü ve "Oku" listesini aç. Bu projede Takip'in kuralları geçmez.
2. Yalnız kalemin **Dokunulacak** listesinde çalış; **Dokunulmayacak**'a ya da başka ajanın alanına giren iş görürsen dokunma, raporda "Sınır dışı" yaz. Ortak dosyalara ekleme serbest, mevcut davranışı değiştirmek "Karar gereken".
3. Commit, push, branch değiştirme YAPMA; değişiklikler çalışma ağacında kalır. Gizli değer yazdırma.
4. Kullanıcıya soru sorma; karar gerektiren her şeyi raporda "Karar gereken" başlığıyla, seçenek + önerinle koordinatöre bırak.
5. Godot: `GODOT` ortam değişkeni, yoksa `tools/get_godot.sh` ile `.tools/godot`. Yazdığın her modül için test ekle (birim: `tests/unit/test_*.gd`; ağ davranışı: `tests/net/*.json` senaryosu) ve raporda çalıştır. Yeni dosyadan sonra `--import` çalıştır; uyarı-hata bırakma.
6. Rapor (en fazla ~20 satır; ilk satır `Kalem: US-nnn`): **Yapılan** / **Test** (AC numaralı komut + sonuç) / **Açık kalan** (her madde "kalem adayı" | "nit") / **Karar gereken** (seçenek + öneri) / **Sınır dışı**.
7. Pano dosyalarına (`docs/notes/durum.md`, `docs/surec/{backlog,kararlar,gecmis}.md`) dokunma.
8. Ajan dosyalarında `description` değeri çift tırnak içinde yazılır.

## Kalite katmanları
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
- Haftalık iterasyon yerine **faz**: her faz çıkış kriterli bir durma noktası; kapanışta oynanabilir build + kullanıcı onayı.
- "Canlıda/UPDATER_OK" yok; yayın = faz kapanışında `dev → main` fast-forward + `faz-N` etiketi (oynanabilir sürüme geri dönmek için).
- Tasarım danışmanı ajanı (tasarim, Fable) eklendi; teknik kararlar koordinatörde.
- Paralel paketler ayrı git worktree'de (`/home/user/insiders-wt/<kalem>`), birleştirme denetci PASS sonrası.
- FR/NFR kataloğu yok; tasarım belgesi + kalem AC'leri yeterli. Kırmızı çizgiler `surec.md` §9'da.
