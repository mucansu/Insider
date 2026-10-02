# Araştırma: ajan süreci — çok ajanlı geliştirme sürecimizin en iyi uygulamalara göre değerlendirilmesi

Araştırma notu; bağlayıcı değil. Koordinatör bulguları kaleme/KR'ye çevirir. İşaretler: **[O]** olgu (kaynaklı; numara sondaki listede) · **[G]** görüş/öneri · **[?]** belirsiz ya da doğrulanamadı. Sürüm bilgisi: Claude Code belgeleri 2026-10-02'de okundu; belge içi sürüm notları (v2.1.2xx) olduğu gibi aktarıldı.

## Tur 1 — 2026-10-02

### Kapsam
Süreç tasarımı (surec.md, ajanlar.md, CLAUDE.md, .claude/agents/*.md, .claude/settings.json) ve son iki günün pratiği (kararlar.md günlüğü, git geçmişi, worktree durumu). Ölçüt: Anthropic'in Claude Code belgeleri ve mühendislik yazıları; diğer ekiplerin 2025-2026 çok ajanlı deneyimleri; yapay zekâ koduna özgü kalite riskleri (ödül hilesi/test gevşetme, aynı model denetimi, bilişsel borç); doğrulama (bağımsız denetim, boz-yakala/mutasyon, CI); birleştirme; maliyet. Kod kalitesi ya da oyun tasarımı bu turun konusu değil.

### Mevcut durum (dosya:satır)
- **Yönetişim:** CLAUDE.md 11 satır (kısa; iyi). Ortak ajan kuralları `docs/notes/ajanlar.md:22-30`'da ve altı ajan dosyasında birebir kopya (`cekirdek.md:17-24`, `oynanis.md:17-24` vb.). Kalite katmanları `ajanlar.md:32-38` (ajan içi test → denetci → koordinatör diff + çürütmeli inceleme (M, ağ) → CI → Fable → insan testi). Kırmızı çizgiler `surec.md:86-93`; koordinatör reçetesi `surec.md:95-98`.
- **Ajan tanımları:** hepsi `model: inherit` (ana oturum Fable 5.1) — yalnız tasarim `model: fable`. `effort: high` denetci/cekirdek/tasarim'da (`denetci.md:5`, `cekirdek.md:5`, `tasarim.md:5`); oynanis/seviye/arayuz/altyapi'de yok. Yalnız denetci'de `tools:` kısıtı var (`denetci.md:6`: Read, Grep, Glob, Bash) — Bash yazabildiği için "dosya değiştirmez" kuralı istem düzeyinde kalıyor (`denetci.md:9`). Hiçbir ajanda `hooks`, `memory`, `maxTurns`, `isolation` yok.
- **Hook/skill:** `.claude/settings.json:1-17` yalnız izin listesi (push/ff/ci_local allow; `--force` deny). `.claude/hooks/` ve `.claude/skills/` yok. Hiçbir otomatik kapı (lint, test, sınır denetimi) hook ile bağlı değil; hepsi istem ve denetci'ye dayanıyor.
- **CI:** `tools/ci_local.sh:103-104` godot→import→unit→tools→net; uzak CI `ci.yml:7-9` dev/main push'unda aynı adımlar. 223 birim testi (`tests/unit`), 14 ağ senaryosu (`tests/net/*.json`, her biri 0 ve 150 ms). Test satırı ≈ 5,7k, ürün GDScript ≈ 5,3k. Mimari uygunluk testleri var: bağımlılık yönü (`test_deps.gd`), kapsülleme taraması (`mimari.md:155`).
- **Paralellik:** `surec.md:65` worktree'leri `../insiders-wt/<kalem>` + `wt/<kalem>` dalı olarak tarif eder; gerçekte 12 worktree `.claude/worktrees/agent-<id>/` altında, `worktree-agent-<id>` dallarında (Claude Code `isolation: worktree`). Altısı `ef982c8`'de (faz2-int'in US-006 birleşmesi), dev'in 34 commit gerisinde. İkisi (`agent-aad82679…`, `agent-ae406ef9…`) aynı anda `autoload/game.gd` ve `entities/player/player.gd`'yi değiştirmiş; `i18n/texts.csv`, `levels/store_a.tscn`, `ui/main_menu.gd`, `entities/props/door.gd` de birden fazla worktree'de kirli. Entegrasyon dalı `faz2-int` (`backlog.md:216`, `kararlar.md:101`). `.gitignore`'da `.claude/worktrees/` yok.
- **Pano:** 111 commit / ~2 gün; 71'i `pano:` (%64). Tek saatte 26 commit (10-02 12:xx). Tutarsızlıklar: `ajanlar.md:20` ve tüm ajan dosyaları "S1-S9" der, mimari.md'de S10-S11 var (`mimari.md:125,134`); `backlog.md:4` hâlâ "aktif paket ≤ 3" yazarken `kararlar.md:108` askıya almış; `surec.md:65` worktree yolu gerçekle uyuşmuyor; `gecmis.md:5-6` tablosu boş (Faz 0 kapanışı `durum.md:29`'da ama gecmis'te satır yok).
- **Düzeltme turu oranı:** 27 Bitti kalemin 12'si t2 ya da t3 gördü (%44): denetci t1 FAIL ×4 (US-001, US-002, IS-009, IS-011), çürütmeli inceleme should-fix ×2 (US-004, US-005), diğerleri karışık (`git log --grep t2`). IS-026 t3.
- **Test hijyeni (olgu):** geçmişte silinen test dosyası yok; hiçbir commit testlerden >20 satır silmemiş; tek `allow_log` istisnası `tests/net/late_join_real.json` (gerekçeli, kök çözüm kalemi IS-020; `kararlar.md:103`). US-004 t2'de "6 hatalı varyantla kanıtlandı" (`kararlar.md:112`) — elle boz-yakala uygulanmış, sistematik değil.
- **Scratchpad çakışması ve CI izleyici bildirimleri:** pano dosyalarında kayıt yok (koordinatör aktarımı) [?]. Teknik olarak scratchpad oturum başına tektir, alt ajan başına değildir; aynı dosya adını kullanan iki paralel ajan çakışır.

### En iyi uygulamalar ve seçenekler
1. **Doğrulanabilir kapı ("give Claude a way to verify")** [O][1]: ajanın koşabileceği pass/fail sinyali; kanıt göstertme; kapı sertliği sırası: istem içinde → `/goal` → **Stop/SubagentStop hook** (deterministik) → taze bağlamlı doğrulayıcı alt ajan. Artı: insansız döngü kapanır. Eksi: yavaş kontroller (Godot import+unit) her durakta koşarsa süre maliyeti.
2. **Çürütmeli inceleme kuralı** [O][1]: "boşluk bul" denen inceleyici boşluk bulur; yalnız doğruluk/şartı etkileyeni işaretlet, gerisi isteğe bağlı. Akademik destek: LLM inceleyiciler doğru kodu "uyumsuz" diye işaretleme eğiliminde; ayrıntılı/açıklama isteyen istemler yanlış yargıyı artırıyor [O][7]. Artı: aşırı mühendislik ve t2 şişmesi azalır.
3. **Aynı model kendi işini puanlamasın** [O][8][9]: kendini tercih yanlılığı nedensel; güçlü modellerde çoğu "haklı" tercih ama model hata yaptığında kendi hatasını tanımakta zorlanıyor; Chain-of-thought ve nesnel doğrulama (test) yanlılığı azaltıyor. Seçenekler: (a) denetci farklı model (ör. `model: opus`) — artı bağımsızlık, eksi aile farkı küçük ve maliyet; (b) aynı model, nesnel kanıt zorunlu (zaten) + farklı bakış (held-out test) — ucuz; (c) iki model dönüşümlü.
4. **Ödül hilesi / sahte yeşil** [O][10][11]: görünür testleri doyuran ajanlar gizli testlerde düşüyor; kod büyüdükçe fark 10×'te +28 puan; test düzenleme/zayıflatma ve test-özel durum yazma bilinen kalıplar. Mitigasyon: held-out (ajanın görmediği) test, test silmeyi yasaklayan kural [O][2], denetci'nin AC'yi karttan türetmesi (bizde var).
5. **Mutasyon / boz-yakala** [O][12][13]: kapsama yanıltıcı; mutasyon "testler bu semantiği soruyor mu" diye sorar. Ajan çağı aracı: önceliklendirilmiş mutantlar, SQLite çıktı, ajanın incelemesi; uyarı: mutasyon güdümlü test üretimi "kazara davranışı" teste dondurabilir — şüpheci ajan, kritik bileşene odaklı kampanya. GDScript için hazır mutasyon aracı yok [?]; elle boz-yakala (US-004'teki gibi) ölçeklenebilir.
6. **Uzun koşan ajan düzeneği** [O][2]: ilerleme dosyası + özellik listesi (JSON, test adımlı) + oturum başı uçtan uca test + "test silmek/düzenlemek kabul edilemez" kuralı + küçük artımlı özellik; gözlenen hatalar: aşırı hırs, erken "bitti", uçtan uca doğrulamasız kapatma.
7. **Paralel ajan + worktree** [O][3][14][15][16]: worktree dosya çakışmasını çözer, birleştirme çakışmasını çözmez; 10 ajanlı örnekte 3 çakışmanın hepsi tek "kayıt noktası" dosyasında (`cli/main.py` ithalat bloğu), 6 lint düzeltme turu (ajanlar `ruff format --check`'i atladı), 3 ajan ana ağaca dosya sızdırdı (kabuk durumu Bash çağrıları arasında kalmıyor) [O][14]. Önerilen disiplin: dosya sahipliği yazılı, bağımlılık sırasına göre birleştirme, worktree'yi düzenli olarak ana daldan güncelleme, çakışmayı yalnız birleştirme anında PR+CI kapısıyla çözme [O][15][16]. Claude Code: worktree'ler varsayılan olarak **uzak varsayılan daldan (origin/HEAD = main)** açılır; `worktree.baseRef: "head"` ayarı mevcut HEAD'den açtırır [O][3]. `.claude/worktrees/` gitignore'a eklenmeli [O][3]. Hook'larda `${CLAUDE_PROJECT_DIR}` ana ağaçta kalır, worktree yolu `cwd` alanından okunur [O][3].
8. **Alt ajan tanımı alanları** [O][4]: `tools`/`disallowedTools`, `model`, `effort` (low…max), `maxTurns`, `memory: project` (ajanın kalıcı MEMORY.md'si), `hooks` (yalnız o ajan koşarken), `isolation: worktree`, `skills` (açılışta yüklenen), `background`. Alt ajan kullanıcıyla konuşamaz; 3 katman derinliğe kadar alt ajan açabilir; eşzamanlı 20 (ayarlanabilir). Alt ajan ana sohbet geçmişini görmez; CLAUDE.md'yi görür.
9. **Hook olayları** [O][5]: PreToolUse (engelleyebilir, exit 2 / JSON deny), PostToolUse (bilgi), Stop/SubagentStop (engelleyebilir → "bitmeden önce şu kontrol geçsin"), SessionStart (bağlam yükle), SubagentStart/Stop eşleyicisi ajan adıyla, TaskCompleted/TeammateIdle (ajan ekipleri). Tipler: command, prompt, agent. "Her seferinde istisnasız olması gereken şey hook'tur; CLAUDE.md tavsiyedir" [O][1].
10. **Skill'ler** [O][6]: isteğe bağlı yüklenen prosedür/kontrol listesi; `disable-model-invocation: true` ile yalnız kullanıcı/koordinatör çağırır; `!`komut`` ile canlı veri (git diff) gömülür; ajan frontmatter'ında `skills:` ile ortak kurallar tek yerden önyüklenir. CLAUDE.md < 200 satır; ayrıntı skill'e [O][17].
11. **Ajan ekipleri ve dinamik iş akışları** [O][18][19]: ekipler deneysel, ~7× token, eş-ajanlar birbirine mesaj atar, dosya çakışması riski; "önce araştırma/incelemede dene". Workflows: betikle düzinelerce ajan, bulguları birbirine çürüttürme, kodda tekrar edilebilir orkestrasyon; ara sonuçlar bağlama girmez.
12. **Maliyet** [O][17][20][21]: çok ajanlı sistem ≈ 15× token; token kullanımı performans varyansının %80'ini açıklıyor; alt ajana küçük model (`model: sonnet/haiku`), hook ile çıktı süzme (test çıktısından yalnız FAIL satırları), `/clear`, CLAUDE.md'den skill'e taşıma. Sonnet 5.5 `medium` ≈ Opus 5 `high` [O][21]; `max` effort "aşırı düşünmeye" eğilimli. Fable 5.1'de varsayılan effort zaten `high` [O][21] → `effort: high` ekleme (ajanlar.md:18) oturum high'daysa etkisizdir.
13. **16 ajanlı C derleyicisi** [O][22]: 2.000 oturum, ~20 bin $; görev kilidi dosyaları + git çakışmasıyla yeniden atama; "testler neredeyse kusursuz olmalı, Claude önüne konan problemi çözer"; bilinen-iyi kahin (GCC) ile rastgele karşılaştırma; sık regresyon; "zaman körlüğü" için önceden hesaplanmış istatistik/README.

### Bizim yapımıza uygunluk
- Orkestratör-işçi deseni (koordinatör + uzman alt ajanlar) Anthropic'in araştırma sisteminin yapısı [O][20]; kod işinde "sıkı bağımlı görevlerde daha az etkili" uyarısı bize bakkal NPC zincirinde (US-008→010→012→016 sıralı, aynı `entities/npc/`) uygulanıyor — zaten sıralı planlanmış, doğru.
- Ajan ekipleri bizim için uygun değil [G]: tek kullanıcı, kalem bazlı sahiplik, denetci zinciri; ekiplerin "eşler tartışır" faydası bizde tasarim/Fable danışmasıyla karşılanıyor; 7× maliyet gereksiz. Workflow'lar faz sonu "mimari tur" ve toplu denetim (her dosyaya bir inceleyici + çürütücü) için uygun aday [G].
- Hook'suz çalışmak bugüne kadar denetci sayesinde taşınmış; paralellik 10+ ajana çıkınca istem-düzeyi kurallar (ajan commit atmaz, pano dosyasına dokunmaz, Dokunulmayacak) deterministik kapıya dönüşmeli [G]; Anthropic'in "istisnasız şey = hook" ilkesiyle örtüşür [O][1].

### Bulgular
**Doğru yaptıklarımız**
- Bağımsız denetim + çürütmeli inceleme + "önce kendin çürüt" kuralı Anthropic'in callout'uyla birebir [O][1]; t2 oranı %44 bu katmanın gerçekten yakaladığını gösteriyor (4 t1 FAIL, 2 should-fix ağ/yetki kodunda).
- Test hijyeni temiz: test silme yok, tek `allow_log` gerekçeli ve kök-çözüm kalemli; AC'ler karttan, komut çıktılı; ağ davranışı 0/150 ms iki profilde; mimari uygunluk testleri (bağımlılık yönü, kapsülleme) "bilişsel borç" literatürünün tam önerdiği şey [O][23].
- CLAUDE.md kısa; "tek doğruluk kaynağı" tablosu (`surec.md:5-18`) uzun koşan ajan düzeneğinin ilerleme dosyası/özellik listesi karşılığı [O][2].
- Entegrasyon dalı (`faz2-int`) ve Faz 1 checkpoint'ini temiz tutma kararı, "bağımlılık sırasına göre birleştir" pratiğiyle uyumlu [O][14].
- Faz başına "mimari tur" ve kullanıcıyla soru-cevap (yontem.md §8/5) bilişsel borç önlemi olarak doğru; yeni dalgaya alınmış (`ae3a8f4`).

**Saptığımız yerler / riskler**
- **R1 — Dosya kümeleri ayrık değil (kanıtlı).** İki aktif worktree aynı anda `autoload/game.gd` ve `entities/player/player.gd`'yi değiştiriyor; `texts.csv`, `store_a.tscn`, `main_menu.gd`, `door.gd` birden fazla worktree'de kirli. `surec.md:31`'deki "dosya kümeleri ayrık" şartı 10-17 ajanda tutmuyor; birleştirme çakışması ve "stale context" (34 commit geride) birikti. Bernstein'ın 3 çakışması da "paylaşılan kayıt noktası" dosyasındaydı [O][14] — bizde `game.gd` (S3 ekleri) ve `player.gd` aynı rolde.
- **R2 — Worktree tabanı yanlış dal.** Claude Code worktree'yi `origin/HEAD` (= main, Faz 0 commit'i) üzerinden açar [O][3]; "worktree'lerin eski main'den açılması" olayının nedeni bu. `.claude/settings.json`'da `worktree.baseRef` yok. Ayrıca `.gitignore`'da `.claude/worktrees/` yok; surec.md §6 yolu/dal adı gerçekle uyuşmuyor.
- **R3 — Denetim aynı modelle.** Tüm ajanlar Fable 5.1; kendini tercih yanlılığı nesnel kanıtla azalır ama model kendi hatasını tanımakta zorlanır [O][9]. Bizde nesnel kanıt var (test, CI); eksik olan "ajanın görmediği test" (held-out) — SpecBench'in ölçtüğü boşluk tam bu [O][10].
- **R4 — Kurallar istem düzeyinde, hook yok.** "Ajan commit/push atmaz", "pano dosyasına dokunmaz", "Dokunulmayacak", "test silme" hiçbiri deterministik değil; denetci'nin Bash'i yazabilir. Bernstein'da 3/10 ajan ana ağaca dosya sızdırdı [O][14]; bizde "ortak scratchpad çakışması" aynı sınıf.
- **R5 — Koordinatör darboğazı.** Commit'lerin %64'ü pano; tek saatte 26 pano commit'i. Paketleme, rapor alımı, diff okuma, denetci, birleştirme, CI, commit, pano: her adım koordinatör bağlamında → bağlam dolar, performans düşer [O][1]. Ajan sayısı sınırı kalkınca (`kararlar.md:108`) darboğaz koordinatöre taşındı.
- **R6 — Pano tutarlılığı aşınıyor.** S1-S9 (7 dosyada) vs S11; "≤ 3 paket" askıda ama backlog §0'da yazılı; gecmis.md boş; surec §6 yolu eski. Alt ajanlar CLAUDE.md + ajan dosyası + project-index'i her açılışta okur → eski referans her ajana yayılır.
- **R7 — Effort ayarı etkisiz / tek yönlü.** Fable 5.1 varsayılanı `high` [O][21]; `effort: high` değişikliği muhtemelen no-op. Asıl kazanç ters yönde: XS/S arayüz/altyapı kalemlerinde daha düşük effort ya da küçük model (Sonnet 5.5 medium ≈ Opus 5 high) [O][21]; denetci/çürütme için `xhigh` denenebilir ("max" aşırı düşünür) [O][21].
- **R8 — Her ajan açılışta ağır doküman okuyor.** backlog.md 320 satır (tüm kartlar), mimari 160, GDD 397, ajanlar 64, surec 111 (toplam ≈ 27,6k kelime). "Yalnız kalemin bölümünü aç" kuralı Read aracının dosya bütününü getirmesine takılır; 10+ paralel ajanda ×10 token.
- **R9 — Scratchpad paylaşımı.** Scratchpad oturum başına; `denetci.md:9` `/tmp` altında "kendine ait dizin" der ama ad kuralı yok; paralel ajanlar aynı dosya adını kullanabilir [?].
- **R10 — CI izleyici bildirimleri.** Ajanlar push yapamaz, dolayısıyla izleyecekleri CI koşusu yoktur; ajanın CI/PR izleme araçlarına (Monitor, PR durumu) uzanması token ve karışıklık [?]. Ajan kurallarında "CI'yı izleme, koordinatör izler" açıkça yok.
- **R11 — Boz-yakala sistematik değil.** US-004'te 6 hatalı varyant elle; denetci kontrol listesinde "testi geçmek için özel durum yazılmış mı" var (`denetci.md:16`) ama "testler kırılan kodu yakalıyor mu" (mutant) yok.
- **R12 — Faz sonu durma noktası askıda + insan testi henüz yok.** yontem.md §3'teki uyarı geçerli: hız günler mertebesinde, eğlence kapısı (IS-017) hâlâ Backlog. Süreç değil tasarım riski; burada yalnız not.

### Öneriler
| # | Ne | Neden | Ö | Maliyet | Sahip | Kalem adayı + AC |
|---|---|---|---|---|---|---|
| 1 | **Worktree düzeltmesi:** `.claude/settings.json`'a `"worktree": {"baseRef": "head"}`; `.gitignore`'a `.claude/worktrees/`; surec.md §6 gerçek yola/dala göre yeniden yazılır (`.claude/worktrees/agent-*`, `worktree-agent-*`; ya da koordinatör `git worktree add .claude/worktrees/<kalem> -b wt/<kalem> faz2-int` ile adlı açar); paket şablonuna "Çalışma yolu" zorunlu + ajan raporunda `git rev-parse --show-toplevel` çıktısı | R2, R4 (ana ağaca sızma); belge-gerçek uyumu | P1 | XS | altyapi (ayar) + koordinatör (surec) | "IS: worktree tabanı ve kayıt": AC1 yeni worktree faz2-int/dev HEAD'den açılır (`git merge-base` kanıtı) · AC2 `git status` ana ağaçta worktree dizinini göstermez · AC3 surec §6 ve ajanlar.md son bölümü gerçek yolu anlatır |
| 2 | **Hook paketi v1 (deterministik kırmızı çizgiler):** (a) her kod ajanı ve denetci frontmatter'ına `hooks.PreToolUse` Bash eşleyici: `git (commit|push|checkout|switch|reset|stash|rebase|merge)` → exit 2; (b) aynı yerde `Edit|Write` eşleyici: `docs/notes/durum.md`, `docs/surec/{backlog,kararlar,gecmis}.md`, `project.godot` (altyapi hariç) → deny; (c) `Edit|Write` eşleyici: `tests/**` içinde `func test_` satırı silen düzenleme → deny, gerekçe "test silme = Karar gereken"; (d) koordinatör `SessionStart` hook'u: `durum.md` + `git worktree list` + "HEAD'i dev/faz2-int gerisinde N commit olan worktree" uyarısı. Betikler `.claude/hooks/*.sh`, Git Bash'te çalışır; hook girdisindeki `cwd` worktree'yi verir [O][3] | R4, R9; "istisnasız = hook" [O][1] | P1 | S | altyapi | "IS: ajan hook'ları v1": AC1 denetci içinde `git commit` denemesi hook tarafından reddedilir (log) · AC2 oynanis ajanı `docs/notes/durum.md`'yi düzenleyemez · AC3 `func test_` silen Edit reddedilir, ekleme serbest · AC4 ci_local'a `hooks` adımı: betikler sahte girdiyle birim test edilir (Python) |
| 3 | **Held-out test + boz-yakala denetci adımı:** M kalemde ve ağ/yetki kodunda çürütmeli inceleme ajanı, ajanın yazmadığı 1-3 "gizli" testi `tests/unit/test_<kalem>_holdout.gd` olarak yazar (koordinatör commit eder); denetci kontrol listesine madde: değişen `core/` ve `autoload/` dosyalarında 2-3 elle mutant (eşik ±1, koşul tersine, erken return) → en az bir test kırılmalı; kırılmıyorsa should-fix | R3, R11; SpecBench boşluğu [O][10], mutasyon uyarıları [O][13] | P1 | S (süreç) | denetci + inceleme ajanı; kural koordinatör | "IS: denetim kontrol listesi v2": AC1 denetci.md'de mutant maddesi + rapor alanı "Boz-yakala: n/m" · AC2 M kalemde holdout dosyası var ve ajan diff'inde yok · AC3 iki kalemde uygulanıp günlüğe sonuç yazıldı |
| 4 | **Birleştirme disiplini:** paralel paket açılırken koordinatör "kayıt noktası" dosyalarını (`autoload/game.gd`, `entities/player/player.gd`, `levels/store_a.tscn`, `i18n/texts.csv`, `project.godot`) tek sahibe verir ya da ekleri **ayrı dosyaya** aldırır (S3 ekleri için `autoload/game_heist.gd` gibi bileşim; `texts.csv`'ye yalnız sonuna ekleme); Denetimde'ye geçmeden koordinatör `git merge faz2-int` ile worktree'yi günceller, çakışma varsa ajana t2 olarak döner; birleştirme sırası bağımlılık sırasıyla ve pano'da yazılı | R1; Bernstein kayıt-noktası dersi [O][14], "worktree'yi düzenli güncelle" [O][15] | P1 | XS (kural) + S (game.gd bölme) | koordinatör; bölme: cekirdek | "IS: paylaşılan dosya sahipliği": AC1 surec §6'da kayıt-noktası listesi ve "denetim öncesi entegrasyon güncellemesi" adımı · AC2 `game.gd` S3 eklerinin bileşen dosyasına ayrılması (mimari §6 400 satır ölçüsüne uyum) · AC3 aynı dalgada iki worktree aynı `.gd`'ye dokunmuyor (`git status` kesişimi boş) |
| 5 | **Koordinatör yükünü skill'e taşı:** `.claude/skills/paket/SKILL.md` (`/paket US-nnn`: backlog kartından Ek 1 görev paketini üretir, worktree açar, durum.md satırını yazar), `/kapat US-nnn` (DoD §4 listesi: denetci PASS kanıtı, `git diff --name-only` ∩ Dokunulacak, ci_local, commit mesajı, backlog satırı, durum.md), `/dalga` (pano commit'lerini dalga sonunda tek `pano:` commit'te toplar). Hepsi `disable-model-invocation: true` | R5; skill = isteğe bağlı yüklenen prosedür [O][6][17] | P2 | S | koordinatör (yazar), altyapi (doğrular) | "IS: koordinatör skill'leri": AC1 `/paket` çıktısı Ek 1 şablonuyla birebir · AC2 `/kapat` eksik DoD maddesini listeler ve commit atmaz · AC3 bir dalgada pano commit sayısı ≤ kalem sayısı |
| 6 | **Pano tutarlılık denetimi:** `tools/pano_check.py` (XS): S-numarası aralığı (mimari'deki en büyük S ile ajan dosyaları uyumlu), Sürüyor kalem ↔ worktree eşlemesi, durum.md ≤ 40 satır, gecmis.md faz satırı, surec/backlog'daki askıya alınmış kuralların "(askıda, KR/günlük)" notu; ci_local'a `pano` adımı. Ortak ajan kurallarını altı dosyada kopyalamak yerine `.claude/skills/ajan-ortak/SKILL.md` + ajan frontmatter `skills: [ajan-ortak]` | R6; CLAUDE.md/kural tekrarı sürüklenir [O][17] | P2 | XS-S | altyapi | "IS: pano lint": AC1 mevcut tutarsızlıkların 4'ü (S1-S9, ≤3, §6 yolu, gecmis) betikle yakalanır · AC2 düzeltildikten sonra ci_local yeşil · AC3 ajan dosyalarında ortak kurallar tek kaynaktan |
| 7 | **Model/effort kademesi:** denetci ve çürütme ajanı `effort: xhigh` (max değil) [O][21]; XS/S arayüz-altyapı kalemlerinde `model: sonnet` denemesi (2 kalem, t2 oranı ve denetci bulgusu karşılaştırılır); cekirdek/oynanis M kalemleri Fable'da kalır; tasarim Fable. `ajanlar.md:18` notu "varsayılan zaten high" diye düzeltilir | R7; maliyet-kalite [O][17][21] | P2 | XS | koordinatör | "IS: model kademesi deneyi": AC1 iki XS kalem sonnet'te, denetci PASS turu ve bulgu sayısı günlükte · AC2 denetci xhigh ile bir M kalemde ek bulgu var/yok kaydı · AC3 karar KR olarak |
| 8 | **Ajan okuma yükü:** kalem kartları `docs/surec/kalemler/<ID>.md` (Faz 2 için zaten `faz2-bakkal-kalemleri.md` var; standartlaştır), backlog.md yalnız tablo; paket metnine kartın tamamı gömülür (ajan backlog'u hiç açmaz); mimari.md'de kaleme ilgili S bölümleri paket "Oku" listesinde satır aralığıyla | R8; bağlam en kıymetli kaynak [O][1] | P2 | S | koordinatör | "IS: kart dosyaları": AC1 yeni kalemler tek dosyada · AC2 paket şablonu kart içeriğini gömer · AC3 bir ajan açılışında okunan doküman satırı ölçülüp (≤ ~600) günlüğe |
| 9 | **Scratchpad ve CI izleme kuralı:** ortak kurallara "geçici dosyalar `<scratchpad>/<kalem>-<ajan>/` ya da `mktemp -d`; CI/PR izleme araçlarını kullanma, push koordinatörde" | R9, R10 | P2 | XS | koordinatör | — (ajanlar.md + 6 ajan dosyası tek satır) |
| 10 | **Denetci hafızası:** `denetci.md`'ye `memory: project` ve "tekrarlayan bulgu kalıplarını MEMORY.md'de tut" [O][4] — ör. "kapı engel denetimi eski konum", "allow_log istisnası" | kalıp öğrenme; t2 azalması | P3 | XS | koordinatör | deneme: 3 kalem sonra MEMORY.md içeriği gözden geçirilir; sürüklenirse kapatılır |
| 11 | **Faz sonu mimari tur = workflow:** `/mimari-tur` dinamik iş akışı: değişen her modül için bir inceleyici (bağımlılık yönü, sözleşme sadakati, 400 satır ölçüsü) + bulguları çürüten ikinci katman, tek sıralı rapor; sonucu kullanıcıyla 15 dk soru-cevap | bilişsel borç [O][23]; workflows [O][19] | P3 | S | koordinatör | "IS: mimari tur v1": AC1 rapor `docs/notes/mimari-tur-faz-N.md` · AC2 her bulgu dosya:satır + sözleşme · AC3 kullanıcı soru-cevabı günlükte |
| 12 | **Ajan ekipleri: kullanma** (şimdilik) | deneysel, 7× token, dosya çakışması; faydası (eşler tartışır) bizde Fable danışmasıyla var [O][18] | — | — | — | KR notu yeterli |

**Karar gereken (koordinatör / kullanıcı)**
- Denetci farklı modelde mi (öneri 7'nin uzantısı)? Araştırma farklı modeli önerir [O][8]; bizde nesnel kanıt yoğun olduğu için [G] önce held-out test + xhigh (öneri 3, 7), fayda görülmezse Opus denetci. Kullanıcı "token bol" dedi (`kararlar.md:94`); yine de kalem başına maliyet ölçümü (`/usage` özeti) günlüğe yazılmalı.
- `game.gd` / `player.gd` bölme (öneri 4 AC2) mimari §6 kararı; koordinatör yetkisinde.
- Hook'lar `.claude/settings.json`'a (paylaşılan) mı, ajan frontmatter'ına mı: öneri frontmatter (yalnız o ajan koşarken etkili, koordinatörün kendi git akışını engellemez) [O][4][5].

### Bir sonraki tur için açık sorular
- Hook betikleri Git Bash + Windows'ta `jq` olmadan (Python ile) yazılmalı; `cwd` alanı worktree için güvenilir mi (test edilmedi) [?].
- `$GODOT --headless --check-only -s <file>` PostToolUse lint'i olarak kullanılabilir mi (proje bağımlılıklı betiklerde çalışır mı)? gdtoolkit `gdlint` (4.x) katı tipleme kuralı sunmuyor [?]; hangisi daha ucuz sinyal?
- Scratchpad çakışması ve CI izleyici olaylarının somut kayıtları (hangi ajan, hangi dosya) — günlüğe yazılırsa öneri 9 kesinleşir.
- `SubagentStop` hook'uyla "birim testler geçmeden rapor yok" kapısı: Godot import+unit süresi ölçülmeli (ci_local adım süreleri); > 60 sn ise yalnız denetci'de.
- Dinamik iş akışı mimari tur: Pro planda `small` boyut varsayılanı [O][19]; hesabın planı/limitleri?
- Held-out testlerin uzun vadede ajanlara "görünür" hale gelmesi (repo'da dururlar) — SpecBench etkisi zamanla azalır; dönüşümlü yenileme gerekir mi?

### Kaynaklar
1. Claude Code — Best practices — https://code.claude.com/docs/en/best-practices
2. Anthropic Engineering — Effective harnesses for long-running agents (2025-11-26) — https://www.anthropic.com/engineering/effective-harnesses-for-long-running-agents
3. Claude Code — Worktrees (baseRef, `.claude/worktrees/`, isolation, hook `cwd`) — https://code.claude.com/docs/en/worktrees
4. Claude Code — Subagents (frontmatter alanları, memory, hooks, limitler) — https://code.claude.com/docs/en/sub-agents
5. Claude Code — Hooks reference — https://code.claude.com/docs/en/hooks
6. Claude Code — Skills — https://code.claude.com/docs/en/skills
7. "Are LLMs Reliable Code Reviewers? Systematic Overcorrection…" (arXiv 2603.00539) — https://arxiv.org/abs/2603.00539
8. "Do LLM Evaluators Prefer Themselves for a Reason?" (arXiv 2504.03846) — https://arxiv.org/abs/2504.03846
9. "Breaking the Mirror: Self-Preference in LLM Evaluators" (NeurIPS 2025) — https://neurips.cc/virtual/2025/122352
10. SpecBench — ödül hilesi, görünür/gizli test farkı (arXiv 2605.21384) — https://arxiv.org/abs/2605.21384
11. "The Verification Horizon: No Silver Bullet for Coding Agent Rewards" (arXiv 2606.26300) — https://arxiv.org/pdf/2606.26300
12. Augment Code — Mutation testing AI-generated code — https://www.augmentcode.com/guides/mutation-testing-ai-generated-code
13. Trail of Bits — Mutation testing for the agentic era (2026-04-01) — https://blog.trailofbits.com/2026/04/01/mutation-testing-for-the-agentic-era/
14. Bernstein — Ten agents, one release (10 worktree, 3 çakışma, 6 lint turu) — https://docs.bernstein.run/en/latest/blog/ten-agents-one-release/
15. braindetox — Multiple AI agents on one repo (2026) — https://braindetox.kr/en/posts/multiple_ai_agents_one_repo_2026.html
16. Codex CLI merge conflict prevention (worktrees, integration) — https://codex.danielvaughan.com/2026/04/25/codex-cli-merge-conflict-prevention-resolution-worktrees-clash/
17. Claude Code — Manage costs (CLAUDE.md < 200 satır, alt ajan modeli, hook ile süzme, ekip 7×) — https://code.claude.com/docs/en/costs
18. Claude Code — Agent teams — https://code.claude.com/docs/en/agent-teams
19. Claude Code — Dynamic workflows — https://code.claude.com/docs/en/workflows
20. Anthropic Engineering — How we built our multi-agent research system (15× token, %80 varyans) — https://www.anthropic.com/engineering/multi-agent-research-system
21. Claude Code — Model configuration ve effort seviyeleri — https://code.claude.com/docs/en/model-config
22. Anthropic Engineering — Building a C compiler with parallel Claudes (16 ajan, 2.000 oturum) — https://www.anthropic.com/engineering/building-c-compiler
23. Thoughtworks Radar Vol. 34 — Codebase cognitive debt — https://www.thoughtworks.com/radar/techniques/codebase-cognitive-debt
24. Claude Agent SDK — Building agents (gather context → act → verify; kural tabanlı > LLM-yargıç) — https://claude.com/blog/building-agents-with-the-claude-agent-sdk
25. gdtoolkit (gdlint/gdformat, Godot 4) — https://github.com/Scony/godot-gdscript-toolkit

## Tur 2 — 2026-10-02

### Kapsam
Tur 1 kararlarının (IS-052..IS-056) somutlaştırılması: (1) IS-054 denetim kontrol listesi v2 — holdout test nerede/nasıl, boz-yakala (mutant) seçimi, denetci.md'ye eklenecek metin; (2) koordinatör darboğazı (R5) için `/paket`, `/kapat`, `/dalga` skill iskeletleri (Claude Code skill biçimi belgeden doğrulandı); (3) kart dosyaları (R8) maliyet/fayda ve geçiş planı; (4) eşzamanlı 20 alt ajan sınırı altında önceliklendirme; (5) `pano:` commit oranı. Belgeler 2026-10-02'de okundu; Claude Code sürüm notları (v2.1.1xx-2xx) olduğu gibi aktarıldı.

### Mevcut durum (dosya:satır)
- **Denetim:** `denetci.md:6` tools Read/Grep/Glob/Bash; `:9` "dosya değiştirmez, /tmp altında kendi dizini"; `:12-18` kontrol listesi — madde 5'te "testi geçmek için özel durum yazılmış mı" var, "testler kırılan kodu yakalıyor mu" (mutant) ve holdout yok. Çürütmeli inceleme için ajan dosyası yok (`.claude/agents/` 8 dosya; "inceleme/çürütme" yok) → her seferinde koordinatör istem yazıyor [?].
- **Test koşucusu:** `tests/run_tests.gd:80` `DirAccess.get_files_at(UNIT_DIR)` — yalnız `tests/unit/` düz dizini, alt dizin taranmaz; dosya adı `test_*.gd` olmalı (`:81`). `ci_local.sh:50-54` unit adımı aynı koşucu → holdout dosyası `tests/unit/test_<kalem>_holdout.gd` adıyla konursa ek CI adımı gerekmez.
- **Skill/hook:** `.claude/skills/` ve `.claude/hooks/` yok; `settings.json:1-19` izinler + `worktree.baseRef: head` (IS-052 uygulanmış). `git worktree list` 22 satır, 17 `worktree-agent-*` dalı.
- **Kart yükü:** `backlog.md` 376 satır / 72,9k karakter (≈ 20-25k token [?]); 101 kimlik satırı, 26 tam `###` kartı; Faz 2 kart metinleri zaten ayrı dosyada (`backlog.md:215` → `docs/tasarim/arastirma/faz2-bakkal-kalemleri.md`) → kart düzeni fiilen iki yerli. Bir ajanın açılışta okuyabileceği doküman toplamı 194k karakter (backlog + mimari + GDD + ajanlar + surec + CLAUDE.md + index) ≈ 60k+ token [?].
- **Pano bayatlığı (kanıt):** `durum.md:17-18` US-006/US-013 "Denetimde", US-009/US-014/IS-022 "Sürüyor" yazarken `backlog.md:220,228,238,242` Bitti, `:224` t2. "Her durum geçişini anında yaz" kuralı durum.md'de tutmuyor; backlog satırı tutuyor. Son 60 commit'in 44'ü `pano:` (%73); 13:00 saatinde 25 commit / 20 pano.
- **Süreç belgesi:** `surec.md:65` §6 güncel (IS-052); `ajanlar.md:62` hâlâ `../insiders-wt/<kalem>` diyor (IS-055 pano lint adayı).

### En iyi uygulamalar ve seçenekler
1. **Holdout testi — kim, ne zaman, nerede.** [O] SpecBench'in ölçtüğü boşluk "görünür testleri geçen, gizli testlerde düşen" koddur [10]; Anthropic "doğrulayan ajan işi yapan ajan olmasın, taze bağlamla çürütmeye çalışsın" der [1]; Trail of Bits "kazara davranışı teste dondurma" uyarısı yapar [13]. Gizleme seçenekleri:
   - (a) **Sıra ile gizleme** [G, önerilen]: holdout kalem **Denetimde**'ye geçince, ajan raporunu verdikten sonra yazılır; ajanın worktree'si o ana kadar ki anlık görüntüdür, dosyayı görmemiştir. t2'de görür — istenen budur; o aşamada koruma hook'tur ("holdout dosyasını değiştirme/silme" deny). Artı: sıfır altyapı, mevcut unit koşucusu/CI olduğu gibi. Eksi: duvar saati seri (yazma Denetimde başlar); çözüm: çürütme ajanı Sürüyor sırasında **başka worktree'de** paralel yazar, koordinatör Denetimde'de kopyalar.
   - (b) Repo dışı saklama + CI'da kopyalama: gizlilik uzun sürer ama test kalıcı regresyon olamaz, CI karmaşıklaşır — hayır [G].
   - (c) Ayrı `holdout/<kalem>` dalı: (a)'nın pahalı hâli — hayır [G].
   - **Körlük kuralı** [G]: holdout, ürün kodunu okumadan yalnız kart AC'si + mimari.md sözleşmesi (S-n imzaları) + GDD bölümünden yazılır; kodu okuyan test ajanın varsayımlarını kopyalar (kendini tercih yanlılığı [9]). Sözleşmelerin mimari.md'de yaşaması bunu mümkün kılar. Holdout düşünce önce testin AC'yi doğru okuyup okumadığı koordinatörce kontrol edilir (test de hatalı olabilir), sonra t2.
   - **Kalıcılık:** holdout `tests/unit/test_<kalem>_holdout.gd` olarak kalır (normal regresyon); tur 1'in "görünürlük zamanla azalır" sorusu böylece düşer — her yeni kalem kendi taze holdout'unu alır.
2. **Mutant seçimi (elle boz-yakala) sezgileri.** [O] PIT varsayılan seti: sınır (`<`↔`<=`), koşul tersine, dönüş değeri (true/false/0/null/boş), void çağrı silme, artım/azalım tersine, aritmetik değişimi [26]; Stryker aynı sınıflar + blok boşaltma + dize literal boşaltma [27]. Trail of Bits şiddet sırası: ifade/dal silme (yüksek: "bu dal hiç test edilmiyor") > satır yorumlama (orta: yan etki doğrulanmamış) > operatör değişimi (düşük); aynı satırda yüksek şiddetli mutant yakalanmıyorsa düşükleri atla [13]. GDScript için araç yok [?]; elle 2-3 mutant ölçeklenir.
   - **Bizim koda çeviri** [G] — diff'te şunlardan birer tane, öncelik sırasıyla, en fazla 3: (M-ağ) RPC/sinyal çağrısını sil ya da `multiplayer.is_server()`/yetki koşulunu kaldır (S2 kırmızı çizgi); (M-eşik) yeni sabit/eşik ±1 birim ya da ±%20 (`SIDE_TOLERANCE 24`, 0,2 sn pay gibi); (M-dal) yeni `if` dalını tersine çevir ya da erken `return`; (M-dönüş) bool dönüşü sabitle; (M-metin) `tr()` anahtarını değiştir (S9). Zaman kısıtlıysa yalnız M-ağ ve M-dal.
   - **Uygulama yolu** (denetci "dosya değiştirmez"): (i) worktree'nin **kopyasında** çalış: `cp -r <worktree> <scratchpad>/<kalem>-mut/` (`.godot/` dahil), orada düzenle, `--headless --path . -s res://tests/run_tests.gd -- --filter=<modül>` koş, sonunda sil [G; `.godot/` kopyasının import'suz geçerli olduğu doğrulanmalı [?], değilse `--import` + süre ölçümü]; (ii) aynı ağaçta `git stash`/`checkout --` ile geri alma — kural ihlali, paralel ajan riski, hayır; (iii) ayrı "mutant" ajanı — fazla.
   - **Sonuç kuralı** [G]: yakalanmayan mutant = should-fix ("test eksik: <mutant> için beklenti yaz"); koordinatör davranışın bilerek test dışı olduğuna karar verirse nit + günlük satırı. Rapor alanı: `Boz-yakala: n/m — M1 door.gd:88 '<'→'<=' → test_interaction_door_block FAIL (yakalandı) · M2 … (kaçtı)`.
3. **Skill biçimi** [O][6]: `.claude/skills/<ad>/SKILL.md`; frontmatter alanları `name`, `description`, `disable-model-invocation: true` (yalnız `/ad` ile çağrılır), `user-invocable`, `allowed-tools` (o turda sormadan izinli; ör. `Bash(git merge --no-ff *)`), `disallowed-tools`, `argument-hint`, `arguments` (adlı), `model`, `effort`, `context: fork` + `agent`, `hooks` (skill çağrılınca kaydedilir, `once: true` ilk başarılı koşudan sonra kalkar), `paths`, `shell: bash|powershell`. Yer tutucular `$ARGUMENTS`, `$0`/`$1`, `$ad`, `${CLAUDE_SESSION_ID}`, `${CLAUDE_PROJECT_DIR}` (v2.1.196+). `` !`komut` `` içerik modele gitmeden koşar, çıktısı yerine konur; argümanlar komuttan önce yerine konur; `disable-model-invocation` ile de çalışır; sıfır-dışı çıkış **tüm çağrıyı iptal eder** (`|| true`); yalnız `bash` yoksa PowerShell. SKILL.md < 500 satır, ayrıntı yan dosyada; yüklenen içerik oturum boyunca bağlamda kalır (her satır tekrarlayan maliyet). Tuzak [G]: skill `$0` yerine koyar → `awk '{print $0}'` gibi kabuk komutları bozulur; kart çıkarmayı `tools/kart.py $ARGUMENTS` gibi bir yardımcıya ver.
4. **Kart dosyaları** [O]: Backlog.md aracı kalem başına Markdown dosyası (`backlog/tasks/`), ajan odaklı; gerekçe "biten kalem neyin neden denendiğinin kalıcı kaydı, sonraki ajana okunur" [28]. Beads kayıt başına JSONL + hash kimlik; gerekçe paralel ajan yazımlarında birleştirme çakışması, bağımlılık grafiği, `bd ready` (engeli olmayan iş) sorgusu [29]. Bizde yalnız koordinatör yazar → çakışma gerekçesi geçersiz; geçerli olan **okuma maliyeti** (ajan tek kart okur) ve **paket üretimi** (`/paket` tek dosyayı gömer).
5. **Eşzamanlılık sınırı** [O][4]: varsayılan 20; aşınca Agent çağrısı `Concurrent subagent limit reached` ile **düşer, kuyruk yok**, "tekrar deneme" denir; ayar `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`; biten alt ajanı sürdürmek (resume) sınırı saymaz; `ultracode` oturumları muaf. Dinamik iş akışları ayrı havuz: 16 eşzamanlı (CPU'ya göre azalır), `CLAUDE_CODE_WORKFLOW_MAX_CONCURRENT_AGENTS` (v2.1.269+), çalıştırma başına 1.000 ajan, > 25 ajan/1,5M token'da "Large workflow" uyarısı [19]. Üçüncü taraf yazılar "fazlası kuyruğa girer" diyor [34] — resmî belgeyle çelişiyor, belge esas [?]. Önceliklendirme kaynakları: DORA WIP sınırı — "bitir, sonra çek"; sınıra gelince önce bir kart ileri sütuna geçmeli [30]; WSJF = gecikme maliyeti / süre, kısa ve pahalı-gecikenler önce [31]; kuyruk kuramı: kısa iş önce (SJF) ortalama bekleme süresini düşürür [32]; Anthropic derleyici deneyi: görev kilidi + bağımlılık sırası [22]. Bizde gerçek darboğaz 20 değil, **CPU/RAM**: her kod worktree'si kendi Godot import + unit koşusunu yapar (ci_local adım süreleri ölçülmedi [?]).
6. **Pano yazma vs commit** [G]: "anında yaz" (dosya, çökmeye dayanıklı, sonraki oturum okur) ile "anında commit" (tarih) ayrı şeylerdir; CLAUDE.md yalnız ilkini ister, uygulama ikincisini de yapıyor. Worktree'deki ajanlar ana ağacın commit'lenmemiş panosunu zaten görmez (anlık görüntü) → anlık pano commit'inin ajanlara faydası yok; tüketicisi yalnız gelecekteki oturum/başka makine ve faz kapanış tarihi. Anthropic uzun koşan ajan düzeneğinde ilerleme dosyası sık güncellenir, commit özellik başınadır [2].

### Bizim yapımıza uygunluk
- Holdout (1a) + hook koruması, IS-053'ün hook paketine bir satır ekler (`tests/unit/*_holdout.gd` Edit/Write deny — kod ajanlarında); yeni ajan dosyası `curutme.md` (Write yalnız holdout kalıbına; hook ile) bugünkü "her seferinde istem yaz" yükünü kaldırır. Koşucu düz dizin taradığından dosya adı kuralı yeterli; `run_tests.gd` değişmez.
- Mutant uygulaması (2-i) denetci'nin "dosya değiştirmez" kuralını korur (kopya, scratchpad); IS-053 hook'u scratchpad yoluna Edit/Write izni vermeli (yalnız `<scratchpad>/**`).
- Skill'ler yalnız koordinatörün oturumunda çalışır (alt ajanlar `/paket` çağırmaz); `disable-model-invocation` ile otomatik tetiklenmez. `/kapat` push yapmaz (push `settings.json` allow listesinde, ayrı adım) — "ajan commit atmaz" kuralına dokunmaz.
- Kart dosyaları Faz 2'de fiilen başladı (faz2-bakkal-kalemleri.md); standartlaştırma = yeni kalemler için kural + yardımcı betik, geçmiş kartlar taşınmaz.
- Önceliklendirme kuralı KR-020 (önce aramızda MVP) ve "ajan sınırı yok" kararıyla uyumlu: sınır değil sıra; makine yükü ölçülünce kod paketi tavanı buna göre.

### Bulgular
**Doğru yaptıklarımız**
- Sözleşmelerin mimari.md'de yaşaması holdout'un "kör" (kodu okumadan) yazılmasını mümkün kılıyor; çoğu projede bu yok.
- Unit koşucusu dosya adıyla keşif yapıyor → holdout için ek altyapı gerekmiyor; CI otomatik koşar.
- Faz 2 kartlarını ayrı dosyaya almak (faz2-bakkal-kalemleri.md) R8'in yarısını zaten çözmüş.
- IS-052 uygulanmış: `worktree.baseRef: head`, surec §6 gerçek akış.

**Saptığımız yerler / riskler**
- **R13 — durum.md bayat, backlog güncel.** İki yerde durum tutuluyor, biri sürükleniyor (`durum.md:17-18` ↔ `backlog.md:220-242`). Sürüyor/Denetimde listesi üretilebilir bilgi; elle yazılması hem pano commit sayısını hem tutarsızlığı artırıyor.
- **R14 — Çürütme ajanı tanımsız.** Her M/ağ kaleminde koordinatör istemi yeniden yazıyor; holdout/mutant kuralları bir ajan dosyasına bağlanmadıkça tutarlı uygulanmaz.
- **R15 — Mutant uygulaması denetci kuralıyla çelişir.** "Elle mutant" kalemde (IS-054) yöntem yazılmazsa denetci ya kuralı bozar ya atlar.
- **R16 — `$0` çakışması.** Skill içindeki `` !`awk … $0` `` kalıpları sessizce bozulur; belgede uyarı yok.
- **R17 — Sınır aşımında kuyruk yok.** 20'nin üstünde Agent çağrısı düşer; koordinatör "tekrar deneme" uyarısı alır; araştırma/tasarım ajanları slot tutarken denetim bekleyebilir.
- **R18 — ajanlar.md:62** eski worktree yolu (IS-055'e).

### IS-054 için denetci.md ek metni (öneri; dosyaya koordinatör işler)
```
8. Boz-yakala ve holdout (M kalem, ağ/yetki kodu, `core/`/`autoload/` değişen her kalem):
   a. Holdout: `tests/unit/test_<kalem>_holdout.gd` varsa ajanın diff'inde olmadığını doğrula
      (`git log --diff-filter=A -- <dosya>` koordinatör commit'i; ajan dalında değişiklik yok). Yoksa raporda
      "holdout yok" yaz (M/ağ kalemde should-fix).
   b. Mutant seç (en fazla 3, diff'ten, sırayla): RPC/sinyal/yetki koşulu silme → yeni eşik ±1 birim → yeni `if`
      dalı tersine / erken return → bool dönüş sabitleme → tr() anahtarı değişimi.
   c. Uygula: worktree'yi `<scratchpad>/<kalem>-mut/` altına kopyala (`.godot/` dahil), mutantı orada yaz,
      `--headless --path . -s res://tests/run_tests.gd -- --filter=<modül>` koş, kopyayı sil. İzlenen ağaca dokunma.
   d. Sonuç: her mutant için "yakalandı (hangi test)" ya da "kaçtı". Kaçan mutant = should-fix
      ("test eksik: …"); koordinatör bilerek test dışı derse nit.
   e. Rapor satırı: `Boz-yakala: n/m — M1 <dosya:satır> <değişim> → <test> FAIL · M2 …`.
   f. Çürütme ajanı holdout yazdıysa raporunu OKUMA; yalnız dosyanın koştuğunu ve sonucunu bildir.
   g. Mutant/holdout için üretim kodunu "düzeltme" önerme; yalnız test boşluğunu yaz.
```

### `curutme` ajanı iskeleti (öneri; `.claude/agents/curutme.md`)
```
---
name: curutme
description: "Kör holdout testi yazarı ve çürütmeli inceleyici: ajanın kodunu okumadan kart AC'si + mimari S-n sözleşmesi + GDD'den 1-3 holdout birim testi yazar (tests/unit/test_<kalem>_holdout.gd), koşar; M/ağ kalemde diff'i AC'ye karşı çürütür. Yalnız holdout dosyasını yazar."
model: inherit
effort: xhigh
tools: Read, Grep, Glob, Bash, Write
hooks:
  PreToolUse:
    - matcher: "Write|Edit"
      hooks:
        - type: command
          command: "python .claude/hooks/only_holdout.py"   # tool_input.file_path tests/unit/test_*_holdout.gd değilse exit 2
---
Önce kart (Dokunulacak, AC, Sözleşme), mimari.md S-n ve GDD bölümünü oku. Ürün kodunu (entities/, core/, autoload/, ui/, levels/) OKUMA;
imzalar sözleşmeden. Her AC için en az bir beklenti; sınır (eşik ±1), yetki (istemci dener → host reddeder), zaman (0/150 ms) açıları.
Testi koş; düşerse önce kendi okumanı sorgula (AC yanlış mı okundu?). Rapor: Kalem: … / Holdout: dosya + n test + sonuç / Okuduğum dosyalar / Karar gereken.
```

### Skill iskeletleri (öneri; dosyaya yazılmadı)
**`/paket US-nnn`** — `.claude/skills/paket/SKILL.md`
```
---
name: paket
description: Kalem kartından Ek 1 görev paketi üretir (ajan adı, çalışma yolu, çakışma kontrolü).
disable-model-invocation: true
argument-hint: "[US-nnn|IS-nnn]"
allowed-tools: Bash(python tools/kart.py *) Bash(git worktree list) Bash(git status *)
---
## Kart
!`python tools/kart.py show $ARGUMENTS`          # tablo satırı + ### bölümü ya da docs/surec/kartlar/<ID>.md; yoksa exit 1 → çağrı iptal
## Sürüyor kalemler ve dosya kümeleri
!`python tools/kart.py active --files`           # Sürüyor/Denetimde kalemlerin Dokunulacak listeleri
## Worktree'ler
!`git worktree list`
## Görev
1. DoR eksikse (AC, Dokunulacak, Sözleşme, Oku) dur ve eksiği listele; paket üretme.
2. Dokunulacak ∩ aktif kalemlerin Dokunulacak'ı boş değilse "ayrıklık ihlali" yaz ve dur (ortak dosyalar: game.gd, player.gd, texts.csv, store_a.tscn → birleştirme koordinatörde, surec §6).
3. surec.md Ek 1 gövdesini kartla doldur: ajan = kartın Sahip sütunu; çalışma yolu = "worktree (isolation)"; Bağlam'a ilgili KR'ler ve paralel kümeler; rapor beklentisi.
4. Çıktı: yalnız paket metni + "Agent(subagent_type=<ajan>, isolation=worktree)" satırı. Agent'ı sen çağırma; backlog/durum'a yazma (koordinatör yapar).
```
**`/kapat US-nnn`** — `.claude/skills/kapat/SKILL.md`
```
---
name: kapat
description: PASS almış kalemi DoD listesine göre kapatır — commit (worktree'de), hedef dala --no-ff birleştirme, ci_local, pano satırları. Push yapmaz.
disable-model-invocation: true
argument-hint: "[US-nnn] [worktree-yolu] [hedef-dal]"
arguments: [kalem, yol, dal]
allowed-tools: Bash(git -C * status *) Bash(git -C * diff *) Bash(git -C * log *) Bash(tools/ci_local.sh) Bash(python tools/kart.py *)
---
## Değişen dosyalar
!`git -C "$yol" status --short && git -C "$yol" diff --name-only "$dal"...HEAD`
## Kart
!`python tools/kart.py show $kalem`
## DoD (surec.md §4) — her madde için kanıt iste, eksikse DUR ve listele; commit atma:
1. Denetci raporu "Sonuç: PASS" (koordinatör yapıştırır; M/ağ kalemde Boz-yakala satırı ve holdout var).
2. Değişen dosyalar ⊆ Dokunulacak (+ makul yardımcı: .uid, .import); Dokunulmayacak'a düşen → DUR.
3. "Karar gereken" boş; doküman güncel (sözleşme → mimari.md; tasarım → GDD).
4. Adımlar (onaydan sonra, sırayla): worktree'de `git add` yalnız kart dosyaları + test + doküman → `git commit -m "<kalem>: <özet>"` →
   ana ağaçta `git merge --no-ff <worktree dalı>` (çakışma → iki tarafın eklemeleri; şüphede DUR) → `tools/ci_local.sh` → yeşilse
   backlog satırı Bitti + hash (tools/kart.py set-status) → durum.md yenile → tek `pano:` commit. Push ayrı komut (koordinatör).
```
**`/dalga <rapor-yolu>`** — `.claude/skills/dalga/SKILL.md`
```
---
name: dalga
description: Araştırma/tasarım raporunun öneri tablosunu backlog kalem adaylarına çevirir (kimlik, satır, kart taslağı); yazmadan önce listeler.
disable-model-invocation: true
argument-hint: "[docs/arastirma/.../dosya.md]"
allowed-tools: Bash(python tools/kart.py *)
---
## Rapor
!`python tools/kart.py extract-oneriler "$ARGUMENTS"`   # "### Öneriler" tablosunu satır satır (Ne/Neden/Ö/Maliyet/Sahip/AC) verir
## Mevcut kimlikler ve Bekleyen KR'ler
!`python tools/kart.py next-id && python tools/kart.py pending-kr`
## Görev
1. Her öneri → ya mevcut kaleme ek (kimliğini yaz) ya yeni kalem: `| IS-nnn | başlık | faz | sahip | Ö | B | bağımlılık | Backlog | |` satırı + kart taslağı (DoR alanları, AC'ler rapordan).
2. "Karar gereken" işaretli öneriler kalem değil KR adayı: kararlar.md Bekleyen satırı taslağı.
3. Çıktı: iki blok (backlog satırları; kart taslakları docs/surec/kartlar/<ID>.md) + KR adayları. Dosyaya yazma; koordinatör onaylayınca yazar (ya da `--write` ikinci çağrı).
```

### Kart dosyaları (R8): maliyet/fayda ve geçiş planı [G]
- **Fayda:** ajan açılışında backlog yerine tek kart (≈ 20-25k → ≈ 0,5-1k token [?]); `/paket` tek dosyayı gömer; kart bütünü git geçmişinde kalem başına izlenir; pano lint "satır var, kart yok" denetimi yapabilir. Bitti kartlar "ne denendi, neden" kaydı olarak kalır [28].
- **Maliyet (S):** `docs/surec/kartlar/<ID>.md` kuralı + surec §3/Ek 1 + project-index satırı (XS); `tools/kart.py` (show / active --files / set-status / next-id; ≈ 100-150 satır Python, testli; XS-S); durum iki yerde kalmasın: **durum yalnız backlog tablo satırında**, kart DoR alanlarını taşır (satır ↔ kart tek yönlü bağ).
- **Geçiş:** (1) bugünden itibaren yeni kalemler kart dosyasıyla açılır; (2) Hazır/Sürüyor Faz 2 kartları (faz2-bakkal-kalemleri.md §2-5 ve backlog `###` 305-367) taşınır, kaynakta "→ kartlar/<ID>.md" bırakılır; (3) Bitti kartlar taşınmaz (arşiv; backlog.md'de kalır); (4) IS-055 lint'e "tablo satırı ↔ kart dosyası" ve "kart yolu ölü değil" kuralları. Beads tarzı veri tabanı/JSONL gerekmez: tek yazar, 100 kalem ölçeği [G].

### 20 eşzamanlı ajan altında önceliklendirme kuralı [G; kaynak 4, 19, 22, 30-32]
1. **Önce boşalt, sonra çek** (Kanban): Denetimde kuyruğu (denetci, curutme, holdout) her zaman önce başlar — kısa işler (dakikalar) slotu hızlı boşaltır (SJF) ve Bitti sayısını artırır (WIP düşer).
2. **Kritik yol** (WSJF/gecikme maliyeti): bağımlılık zincirinin başındaki Hazır kalem (bugün US-008 → US-010 → US-012 → US-016) bağımsız P1'lerden önce; zincirde bekleyen her kalem gecikme maliyeti taşır.
3. **Slot bütçesi** (20'den): denetim/çürütme rezervi 4 (asla araştırmaya verilmez) · kod paketleri ≤ makine ölçümüne göre (ilk tahmin 5-6; her biri Godot import + unit koşar) · tasarım/araştırma boşlukta, en çok 6, `run_in_background` · yedek 4. Dinamik iş akışı (mimari tur) kendi havuzunda (16), ama CPU ortak.
4. **Sınır hatasında** tekrar deneme yok (belge [4]); bir denetim bitince (tamamlanma bildirimi) sıradaki başlar. Araştırma ajanları "slot doluysa ertele" sınıfı.
5. **Bağımlılık sırasıyla birleştir**; aynı ortak dosyaya (game.gd, player.gd, texts.csv, store_a.tscn) dokunan iki paket aynı dalgada açılmaz (surec §6).
6. **Ölçüm:** ci_local adım süreleri (import/unit/net) ve paralel 2-4 Godot sürecinde süre artışı bir kez ölçülüp günlüğe; kod paketi tavanı bu sayıdan.

### Pano commit oranı [G]
- **Kural ayrımı:** "her durum geçişini anında yaz" = **dosyaya** (backlog satırı; durum.md üretilir). Commit: (a) her kalem commit'inin hemen ardından tek `pano:` (merge + pano çifti; `/kapat` yapar), (b) dalga açılışında bir kez (Sürüyor'a geçen kartlar toplu), (c) oturum durması/kapanışı, (d) 30 dk'da bir en fazla bir. Hedef: `pano:` ≤ kalem commit sayısı (tur 1 öneri 5 AC3; bugün 44/16).
- **durum.md üretilsin:** Sürüyor/Denetimde/Denetimde-t2 listesi backlog satırlarından (`tools/kart.py durum`), elle yalnız "Kullanıcıdan bekleyen" ve "Son kapanış"; R13 kökten kapanır. CLAUDE.md satırı "her durum geçişini backlog satırına anında yaz; durum.md üretilir, commit `/kapat`/dalga/kapanışta" diye güncellenir (karar gereken: CLAUDE.md değişikliği).
- Risk yok: dosya diskte; commit'lenmemiş pano yalnız tarihte gecikir. Worktree ajanları zaten anlık görüntü görür; paket kartı gömdüğü için bayat backlog'u okumaz.

### Öneriler
| # | Ne | Ö | Maliyet | Sahip | Kalem / AC |
|---|---|---|---|---|---|
| 13 | **IS-054 somut:** denetci.md madde 8 (yukarıdaki metin) + `curutme.md` ajanı + IS-053 hook'una `*_holdout.gd` deny (kod ajanları) ve scratchpad Write izni (denetci) + `.claude/hooks/only_holdout.py` | P1 | S | koordinatör (metin) + altyapi (hook) | AC1 bir M kalemde holdout dosyası koordinatör commit'inde, ajan diff'inde yok · AC2 denetci raporunda `Boz-yakala: n/m` satırı, ≥ 1 kaçan mutant should-fix'e dönüştü ya da hepsi yakalandı · AC3 kopya-worktree yöntemi `.godot/` kopyasıyla çalışıyor ya da `--import` süresi günlükte |
| 14 | **`tools/kart.py` + kart dosyaları:** show/active/set-status/next-id/durum; `docs/surec/kartlar/`; surec §3/Ek 1, project-index | P2 | S | altyapi (betik) + koordinatör (kural) | AC1 yeni kalem tek dosyada, backlog yalnız satır · AC2 `kart.py active --files` Sürüyor kalemlerin Dokunulacak kesişimini raporlar · AC3 `kart.py durum` çıktısı durum.md'nin Faz bölümlerini üretir |
| 15 | **Skill üçlüsü** `/paket`, `/kapat`, `/dalga` (iskeletler yukarıda; 14'e bağlı) | P2 | S | koordinatör | AC1 `/paket` Ek 1 ile birebir, ayrıklık ihlalinde durur · AC2 `/kapat` eksik DoD'de commit atmaz, PASS'ta merge + ci + tek pano commit · AC3 bir dalgada `pano:` ≤ kalem commit sayısı |
| 16 | **Önceliklendirme kuralı** surec §6'ya 6 madde + ci_local adım süreleri ve 2-4 paralel Godot ölçümü | P2 | XS | koordinatör + altyapi (ölçüm) | AC1 §6'da slot bütçesi ve sıra · AC2 ölçüm günlükte, kod paketi tavanı sayıyla |
| 17 | **Pano kuralı:** CLAUDE.md satırı + durum.md üretimi (14'e bağlı) | P2 | XS | koordinatör | AC1 durum.md Faz bölümleri üretilmiş, elle bölüm ayrı · AC2 bir günde pano/kalem commit oranı ≤ 1 |
| 18 | ajanlar.md:62 worktree yolu düzeltmesi → IS-055 lint listesine | P3 | XS | koordinatör | — |

**Karar gereken**
- CLAUDE.md "her durum geçişini anında yaz" satırının "dosyaya yaz, commit toplu" diye netleştirilmesi (öneri 17) — CLAUDE.md değişikliği kullanıcı/koordinatör kararı.
- Çürütme ajanı `effort: xhigh` (IS-054 kartında var) + `model: inherit`; Opus denetci kararı tur 1'deki gibi ertelenmiş kalır.
- Holdout "kör" kuralı istem düzeyinde mi, hook ile (Read deny `entities/**` vb.) mi — öneri istem + raporda "okuduğum dosyalar" listesi (hook fazla katı; sözleşme dışı imzalar gerekebilir).
- `/dalga` adı tur 1'de "pano toplu commit" anlamındaydı; bu turda koordinatör tanımı (rapor → kalem) esas alındı.

### Bir sonraki tur için açık sorular
- `.godot/` dizini kopyalanan worktree'de import'suz geçerli mi (mutant koşusu süresi); değilse `--import` kaç saniye? [?]
- IS-053 hook'ları Windows/Git Bash'te `cwd` worktree'yi doğru veriyor mu (tur 1 sorusu açık).
- Skill `allowed-tools` kalıplarının `git -C <yol>` biçimiyle eşleşmesi (`Bash(git -C * status *)`) doğrulanmalı [?].
- 2-4 paralel Godot import+unit süresi ölçümü (öneri 16 AC2) — kod paketi tavanı.
- Holdout'un "AC yanlış okundu" oranı: 3 kalem sonra sayı (test hatası vs kod hatası).

### Kaynaklar (tur 2 ekleri)
26. PIT — varsayılan mutator seti — https://pitest.org/quickstart/mutators/
27. Stryker — desteklenen mutator'lar — https://stryker-mutator.io/docs/mutation-testing-elements/supported-mutators/
28. Backlog.md (MrLesk) — kalem başına Markdown dosyası, ajan odaklı — https://github.com/MrLesk/Backlog.md
29. Beads (steveyegge) — kayıt başına JSONL, hash kimlik, `bd ready` — https://github.com/steveyegge/beads
30. DORA — WIP limits — https://dora.dev/capabilities/wip-limits/
31. SAFe — WSJF (gecikme maliyeti / süre) — https://v5.scaledagileframework.com/?p=22083
32. Kanban Tool — kuyruk kuramı (SJF, FIFO) — https://kanbantool.com/kanban-guide/queuing-theory
33. Claude Code — Skills (frontmatter, `!`komut``, `$ARGUMENTS`, 500 satır) — https://code.claude.com/docs/en/skills (tur 1 [6] ile aynı sayfa; bu turda alan alan doğrulandı)
34. startdebugging.net — "2.1.213 caps runaway subagent fleets" (kuyruk iddiası; belgeyle çelişir) — https://startdebugging.net/2026/07/claude-code-2-1-213-caps-runaway-subagent-fleets/
35. Claude Code — Sub-agents: eşzamanlılık 20, `CLAUDE_CODE_MAX_CONCURRENT_SUBAGENTS`, kuyruk yok — https://code.claude.com/docs/en/sub-agents (tur 1 [4])
36. Claude Code — Dynamic workflows: 16 eşzamanlı, 1.000/çalıştırma, Large workflow uyarısı — https://code.claude.com/docs/en/workflows (tur 1 [19])
