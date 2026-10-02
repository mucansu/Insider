# Süreç (2026-10-01)

Tek kullanıcı + koordinatör (Claude Code ana oturumu) + uzman ajanlar için hafif süreç. Takip projesinin düzeninden uyarlandı; farklar `docs/notes/ajanlar.md` sonunda. İş **faz** (EP) ve **kalem** (US-/IS-) ile yürür.

## 0. Tek doğruluk kaynağı
| Dosya | Tuttuğu bilgi | Yazan |
|---|---|---|
| notes/durum.md | Aktif faz, Sürüyor/Denetimde kalemler, kullanıcıdan bekleyenler, son kapanış (≤40 satır) | koordinatör |
| surec/backlog.md | Fazlar (çıkış kriterleriyle), kalemler ve ayrıntıları | koordinatör |
| surec/kararlar.md | Bekleyen ve verilen kararlar (KR) + günlük | koordinatör |
| surec/gecmis.md | Faz kapanışları, yayınlar, ölçütler, retro | koordinatör |
| surec/geri-bildirim.md | Kullanıcı ve oyun testi geri bildirimleri (GB) | koordinatör |
| tasarim/oyun-tasarimi.md | Oyun tasarımı (GDD) | tasarim ajanı + koordinatör |
| surec/oneriler.md | Fable tasarım önerileri (ON) ve durumları | koordinatör |
| tasarim/degerlendirmeler/ | Fable değerlendirme raporları | tasarim ajanı |
| notes/mimari.md | Teknik mimari ve sözleşmeler S1..S9 | koordinatör |

Bir olgu tek dosyada yaşar; başka yerde bağlantı verilir.

## 1. Kimlikler, durumlar, öncelik
- `EP-nn` faz (EP-00 = Faz 0 …) · `US-nnn` oyuncu değeri taşıyan kalem (AC1..n, Given/When/Then) · `IS-nnn` iş (altyapı, test, doküman, doğrulama) · `KR-nnn` karar · `GB-nn` geri bildirim. Kimlikler sıfır dolgulu, yeniden kullanılmaz.
- Commit öneki `US-004: …` / `IS-003: …`; yalnız süreç dosyaları `pano: …`.
- Durumlar (yalnız koordinatör değiştirir): **Backlog → Hazır → Sürüyor → Denetimde → Bitti**; her durumdan **Engelli** (`Engel: KR-nnn | kullanıcı-cihaz | dış`) ve **Elendi** (tek satır gerekçe).
- Kullanıcının cihazını gerektiren kabul → ayrı **doğrulama kalemi** (IS, sahip: kullanıcı). Kod kalemi headless eşdeğeriyle denetci PASS alıp Bitti olur.
- Öncelik **P1** bu fazda şart / **P2** fırsat olursa / **P3** sonraki faz adayı. Büyüklük **XS / S / M**; L yok, bölünür.

## 2. Geçiş koşulları
| Geçiş | Koşul |
|---|---|
| Backlog → Hazır | DoR tam (§3), bağımlılıklar Bitti, sözleşme mimari.md'de |
| Hazır → Sürüyor | Aktif paket ≤ 3, ajan başına 1, paralel paketlerin dosya kümeleri ayrık. Kart Sürüyor'a **ajan başlatılmadan önce** yazılır |
| Sürüyor → Denetimde | Rapor geldi (`Kalem:` ilk satır); "Karar gereken" günlüğe ya da KR'ye, "Açık kalan"/"Sınır dışı" kaleme ya da gerekçeyle atıldı |
| Denetimde → Sürüyor | denetci FAIL; kartta tur sayacı (`t2`) |
| Denetimde → Bitti | DoD (§4) |

## 3. Definition of Ready
ID + başlık · hikâye (US) ya da tek cümle (IS) · AC1..n · Sahip · Büyüklük · Öncelik · **Dokunulacak** · **Dokunulmayacak** · Oku (1-3 doküman bölümü) · Bağımlılık · Sözleşme (S-numarası) · Test beklentisi · Karar gereken (ön).

## 4. Definition of Done — kalem
1. Ajan raporu formatta; AC'ler komut çıktısıyla.
2. "Karar gereken" boş (günlüğe yazıldı / KR açıldı).
3. denetci PASS (AC'ler sıfırdan, `git diff --name-only` sınır kontrolü, yerel CI).
4. Koordinatör diff okuması; ağ/yetki kodu ve M kalemde çürütmeli inceleme; should-fix ve üstü kapandı.
5. Doküman güncel (sözleşme değiştiyse mimari.md, tasarım değiştiyse GDD).
6. `tools/ci_local.sh` yeşil; `US-nnn: …` commit'i dev'e push; `git add` yalnız kart dosyaları + test + doküman.
7. backlog satırı Bitti + commit hash; durum.md güncel.

Not: repoya dosya eklemeyen araştırma/ölçüm kalemleri (ör. IS-004) ve tasarım belgesi kalemleri denetci yerine koordinatör okumasıyla kapanır; bulgular kararlar.md günlüğüne ve ilgili kaleme işlenir.

## 5. Faz kapanışı ve yayın
- Faz, çıkış kriterlerinin hepsi sağlanınca ya da kalan maddeler kullanıcı onayıyla sonraki faza devredilince kapanır.
- Yayın zinciri: `git checkout main && git merge --ff-only dev && git tag faz-N && git push origin main --tags && git checkout dev`. main her zaman oynanabilir son faz sürümüdür.
- Kapanıştan önce tasarım değerlendirmesi (§5a).
- Kapanış: gecmis.md'ye satır (biten kalemler, ölçütler, retro 1-3 satır), durum.md baştan yazılır, kullanıcıya kapanış + sonraki faz planı mesajı (§7). **Kullanıcı "devam" demeden sonraki faz başlamaz** (durma noktası).

## 5a. Tasarım değerlendirmesi (KR-016)
tasarim ajanı (Fable) oyunun gidişatını belirli noktalarda değerlendirir; sonuç bağlayıcı değildir, kullanıcıya öneri olarak gider.
- **Ne zaman:** (1) her faz kapanışında, kapanış mesajından önce (zorunlu); (2) fazın "oynanabilir dilim" kaleminden sonra ara değerlendirme (backlog faz satırında işaretli; Faz 1'de yok, temel yapı); (3) oyun testi geri bildirimleri (GB) geldikten sonra.
- **Girdi:** GDD, faz kalemleri ve commit'leri, kod ve ayar değerleri (`data/*.tres`), test/senaryo çıktıları ve dökümler, GB kayıtları. Fable oyunu oynayamaz; "his" yargısını sayılara, akışa ve oyun testi notlarına dayandırır.
- **Çıktı:** `docs/tasarim/degerlendirmeler/faz-N[-ara].md` (Fable yazar): uyum özeti · sapmalar (oyun zevkini/mekaniği tam karşılamayan) + öneri · mekanik iyileştirmeleri · Faz 2 kapanışından itibaren yeni özellik ve geliştirme önerileri · riskler. Koordinatör önerileri `docs/surec/oneriler.md`'ye `ON-nn` olarak işler.
- **Karar:** öneriler faz plan mesajında "Fable önerileri" başlığıyla, numarayla sorulur; kabul edilen kaleme dönüşür, diğerleri Ertelendi/Reddedildi. Uygulamak zorunlu değildir.

## 6. Paralellik ve worktree
- Varsayılan sıralı, ana çalışma ağacında (repo kökü, dev).
- Paralel paket: kalem başına worktree — Agent aracının `isolation: "worktree"` seçeneği `.claude/worktrees/agent-<id>` altında `worktree-agent-<id>` dalı açar; taban `.claude/settings.json` `worktree.baseRef = head` ile ana checkout'un HEAD'i (dev). Faz entegrasyon dalında (ör. `faz2-int`, worktree `.claude/worktrees/faz2-int`) çalışan paket işe `git reset -q --hard <dal>` ile başlar. Ajan yalnız o yolda çalışır; denetci aynı worktree'de denetler; PASS sonrası koordinatör worktree'de kimlik önekli commit'i atar ve hedef dala (`dev` ya da `faz2-int`) `git merge --no-ff` eder; ortak dosyalardaki (game.gd, player.gd, texts.csv, store_a.tscn, args.gd) çakışmaları koordinatör iki tarafın eklemelerini koruyarak çözer ve birleşik ağaçta import + unit koşar. Scratchpad'de her ajan BENZERSİZ alt klasör kullanır.
- `project.godot`'u değiştiren iki paket aynı anda çalışmaz.

## 7. Faz plan / kapanış mesajı
```
Faz N — <ad>: kapanış + Faz N+1 planı
Biten: US-… · IS-… (denetci PASS) · Devreden: … (gerekçe)
Oynanabilir: <ne deneyebilirsin, nasıl çalıştırılır>
Fable değerlendirmesi: <1-2 satır özet> · Öneriler: ON-nn (a) … ON-nn (b) … (hangileri alınsın?)
Faz N+1 hedefi: <tek cümle> · Kapsam (sırayla): …
Kararlar (numara/harf; "sonra" olur): KR-… (a) … [öneri] (b) …
Sizden gereken (cihaz/hesap): …
Devam onayı: "devam" dersen Faz N+1 başlar.
```

## 8. Karar akışı
1. Ajan "Karar gereken" → koordinatör mimari.md/GDD'ye göre çözer, günlüğe tek satır. Oynanış ayrıntısıysa önce tasarim ajanına danışır.
2. Kullanıcı kararı gerekiyorsa (ajanlar.md "Karar yetkisi") → kararlar.md Bekleyen'e KR; etkilenen kalem Engelli; plan mesajında toplu sorulur (akış tıkanmışsa hemen).
3. Geri alınabilir ve para/hesap gerektirmeyen KR iki faz cevapsız kalırsa koordinatör öneriyle ilerler ve kapanışta bildirir.
4. Kullanıcının serbest geri bildirimi geldiği anda geri-bildirim.md'ye `GB-nn`; en geç sonraki faz planından önce kaleme/KR'ye bağlanır.

## 9. Kırmızı çizgiler (denetci bunlara karşı da denetler)
- İstemci yalnız kendi hareketinde yetkili; diğer her oyun sonucu host'ta karar verilir (S2).
- Oyuncuya görünen sabit dize yok; metin `tr()` + `i18n/texts.csv`, renk tema token'larından (S9).
- Keşifte görülen güvenlik öğeleri haritaya/krokiye otomatik işlenmez (GDD; KR-004).
- Ağ davranışı testsiz birleşmez: en az bir `tests/net` senaryosu 0 ve 150 ms'de yeşil.
- Statik tiplemesiz GDScript yok; import uyarı-hatası yok.
- Lisansı belirsiz asset yok (yalnız CC0 / açıkça izinli; kaynak `docs/notes/assetler.md`'de).
- Ajan commit/push yapmaz; `--force` yasak; main'e yalnız faz kapanışında ff.

## 10. Koordinatör reçetesi
**Açılış:** durum.md → backlog.md (Sürüyor, Denetimde, Hazır) → kararlar.md Bekleyen → `git status` + `git worktree list`; yazılı olmayan değişiklik kartla eşlenir ya da atılır.
**Kalem döngüsü:** Hazır'ın başındaki kart → WIP/bağımlılık/ayrıklık kontrolü → kart Sürüyor + tarih → paket (kart bölümü + Bağlam + rapor beklentisi) → rapor alımı (Ek 2) → Denetimde → denetci (+ gerekiyorsa inceleme) → PASS: doküman, `tools/ci_local.sh`, commit, push → Bitti → kullanıcıya kısa çıktı (oturum içinde birden çok kalem varsa toplu).
**Kapanış:** faz bittiyse §5; değilse durum.md güncel + `pano:` commit.

## Ek 1 — Görev paketi gövdesi
```
Sen Insiders projesinin <ajan> ajanısın. Önce <repo kökü>/.claude/agents/<ajan>.md dosyasını oku ve uy; Takip projesinin kuralları bu işte geçmez.
Kalem: US-nnn — <ad>. Bölüm: docs/surec/backlog.md. Çalışma yolu: <ana ağaç ya da worktree>.
Kapsam / Dokunulacak / Dokunulmayacak / Sözleşme (S-n) / AC1..n / Test beklentisi / Karar gereken (ön)
Bağlam: <ilgili KR'ler, paralel paketlerin dosya kümeleri: dokunma>
Rapor: ilk satır "Kalem: US-nnn"; Yapılan / Test (AC numaralı) / Açık kalan / Karar gereken / Sınır dışı.
```

## Ek 2 — Rapor alım kontrol listesi
`Kalem:` ilk satırda · Test AC numaralı · Açık kalan → kalem ya da gerekçeyle atıldı · Karar gereken → günlük ya da KR · Sınır dışı → sahibine kalem · `git status` dosya kümesi kartın Dokunulacak listesiyle uyumlu.
