# Devir notu — buluttan yerele (2026-10-01)

Bu proje ilk oturumda Claude Code'un bulut ortamında başladı; kullanıcı kredi kullanımını fark edince yerelde devam etmek için burada duruldu. Bu not, yerelde **aynı düzenle** kaldığı yerden devam etmek için gereken her şeyi içerir. Yerelde ilk oturumda okunur; IS-011 bittikten ve US-004 kapandıktan sonra silinebilir.

## Neredeyiz
- **Faz 0 — Kurulum:** Bitti (IS-001..IS-004).
- **Faz 1 — İki kişi bakkalda:** sürüyor. Bitti: US-001 ağ çekirdeği, US-002 bakkal, US-003 menü/HUD/tema, IS-008, IS-009, IS-010 (OOP kuralları, KR-018).
- **US-004 oyuncu karakteri:** kod `wip/US-004` dalında, ajan raporuna göre tam CI yeşil; **denetci ve çürütmeli inceleme yarıda durduruldu**. Dev'e alınmadı.
- **Sırada:** US-004 denetimi → US-005 etkileşim (kasa + kapı; S7 bileşen modeli) → IS-005 Faz 1 çıkış testi + Windows/Linux build → IS-007 Fable Faz 1 değerlendirmesi → IS-006 kullanıcı doğrulaması → Faz 1 kapanışı (dev → main ff + `faz-1` etiketi).
- Pano: `docs/notes/durum.md`, `docs/surec/backlog.md`, kararlar `docs/surec/kararlar.md` (KR-001..018), geri bildirim GB-01..03, öneri kaydı `docs/surec/oneriler.md`.
- Görsel yön denemesi: `docs/tasarim/kukla-denemesi.html` (tarayıcıda aç; KR-017). claude.ai'daki kopyası: https://claude.ai/artifact/Ca7hGKAEF7Kva1J6ecaofR

## Dallar
- `dev`: çalışma dalı (denetimden geçmiş her şey burada).
- `main`: faz sonu oynanabilir sürüm; şu an yalnız Faz 0 başlangıç commit'lerini taşıyor (Faz 1 kapanışında ff edilecek).
- `wip/US-004`: denetim bekleyen oyuncu karakteri. Kapanış yolu: denetci PASS → `git checkout dev && git merge --no-ff wip/US-004` (ya da commit'i dev'e cherry-pick) → `US-004:` önekli commit kuralına uy → dalı sil.

## Yerelde kurulum (Windows)
1. Repoyu klonla: `git clone https://github.com/mucansu/Insider` → `cd Insider` → `git checkout dev`; `git branch wip/US-004 origin/wip/US-004`. (Bulutta yerel klasör adı `insiders` idi; ajan dosyalarındaki `/home/user/insiders` yollarını kendi klon yoluna çevir.)
2. **Godot 4.7.2-stable** (Windows) indir: https://godotengine.org/download/archive/ → 4.7.2-stable. Editörle projeyi aç (`project.godot`). Oyunu iki pencereyle denemek: Debug → Customize Run Instances.
3. **Testler ve yerel CI** (`tools/ci_local.sh`) şu an Linux'a göre yazıldı: `get_godot.sh` yalnız Linux ikilisini indirir, `net_smoke.py` POSIX süreç gruplarını (`os.killpg`) kullanır. İki yol:
   - **Önerilen: WSL2 (Ubuntu)** içinde klonla ve çalıştır: `tools/ci_local.sh` olduğu gibi çalışır (Godot Linux ikilisini kendisi indirir). Godot editörünü Windows tarafında kullanmaya devam edebilirsin.
   - Ya da **IS-011**'i önce yaptır (backlog'da Hazır): net_smoke'u Windows'ta da çalışır yap, get_godot'a Windows dalı ekle. Bitene kadar Windows'ta yalnız birim testler: `"<godot.exe yolu>" --headless --path . -s res://tests/run_tests.gd`.
4. Uzak CI: repo GitHub'da olduğu için `.github/workflows/ci.yml` her dev/main push'unda Linux'ta tam takımı koşar (ilk koşuyu kontrol et; "kullanıcı doğrulaması bekleyen" maddesiydi).

## Claude Code ile devam (yerel)
- Repo kökünde Claude Code'u aç; `CLAUDE.md` kendiliğinden yüklenir, `.claude/agents/` altındaki 7 ajan (cekirdek, oynanis, seviye, arayuz, altyapi, denetci, tasarim) yerelde **gerçek ajan tipi** olarak görünür (bulutta genel ajanla taklit ediliyordu).
- Bulutta ajanlar `/home/user/...` mutlak yollarıyla çalıştı; ajan dosyalarında proje kökü olarak `/home/user/insiders` yazıyor → yerelde ilk iş bu yolları kendi klon yoluna göre güncelle (ya da "proje kökü = repo kökü" yap). `.claude/settings.json` izinleri bash için yazıldı; Windows PowerShell kullanacaksan Takip'teki gibi PowerShell eşleri ekle.
- Paralel paketler için worktree yolu `/home/user/insiders-wt/<kalem>` → yerelde repo yanına bir `insiders-wt/` dizini.
- `tasarim` ajanı Fable modeliyle tanımlı (`model: fable`); yerel Claude Code sürümünde bu model yoksa `inherit` yap.
- İlk yerel oturum reçetesi: `docs/project-index.md` → `docs/notes/durum.md` → bu dosya → `docs/surec/backlog.md`. Sonra: IS-011 (Windows ise) → US-004 denetimi (denetci + çürütmeli inceleme, `wip/US-004` dalında) → US-005.

## Bulutta kalan, repoya girmeyenler
- Yok. Tüm iş commit'li; ajan raporlarının özü kararlar.md günlüğünde ve backlog'da. Fable'ın OOP değerlendirmesinin özeti KR-018'de.
