# Insiders — geliştirici ve yapay zekâ ajanı girişi

Bu dosya, projeye hangi araçla (Claude Code, Codex, Cursor, başka bir ajan ya da elle) katkı verirsen ver ortak giriş noktasıdır. Claude Code'a özgü koordinatör kuralları `CLAUDE.md`'dedir; buradakiler herkes için geçerlidir.

## Proje
Steam'de 3 kişilik (2-4) online co-op, 2D üstten soygun oyunu. Godot 4.7.2, GDScript (katı statik tipleme), host yetkili ağ (ENet). Belgeler Türkçe.

## Önce oku
1. `docs/project-index.md` — dosya haritası (yalnız gerekeni aç).
2. `docs/notes/mimari.md` — dizin yapısı, sözleşmeler S1-S11, test katmanları.
3. `docs/surec/surec.md` §9 — kırmızı çizgiler (aşağıda özet).
4. Yaptığın işin `docs/surec/backlog.md` satırı (kalem kimliği US-/IS-, kabul kriterleri).
Tasarımın tek kaynağı `docs/tasarim/oyun-tasarimi.md`; kararlar `docs/surec/kararlar.md` (KR-).

## Görev reçeteleri (skill'ler)
`.claude/skills/<ad>/SKILL.md` — her biri tek bir "nasıl yapılır". Claude Code bunları otomatik yükler; başka araç kullanıyorsan ilgili dosyayı oku:
| Skill | Ne zaman |
|---|---|
| `test-yaz` | birim test, sözleşme satırı, sahte Game, NpcStage |
| `ag-senaryosu` | ağ davranışı: `tests/net/*.json` + bot, 0/150 ms |
| `npc-ekle` | NPC/davranış: beyin, bileşenler, host'ta çalışma, çoğaltma |
| `seviye-duzeni` | harita: ASCII düzen, build_levels, korunan düğümler |
| `metin-ve-tema` | oyuncuya görünen metin (i18n) ve renk token'ı |
| `kalem-kapat` | bitirme, CI, commit biçimi, birleştirme, PROTOCOL_VERSION |
| `oyunu-ac` | denemek için açma, arkadaşlara paket, Tailscale |

## Kırmızı çizgiler (surec.md §9)
- İstemci yalnız kendi hareketinde yetkili; diğer her oyun sonucu host'ta karar verilir (S2).
- Oyuncuya görünen sabit dize yok (`tr()` + `i18n/texts.csv`); renk tema token'ından (S9).
- Ağ davranışı testsiz birleşmez: en az bir `tests/net` senaryosu 0 ve 150 ms'de yeşil.
- Statik tiplemesiz GDScript yok; import uyarı/hatası yok.
- Lisansı belirsiz asset yok (CC0 / açıkça izinli; `docs/notes/assetler.md`).
- `main`'e yalnız faz kapanışında fast-forward; `--force` yok.

## Çalışma düzeni
- Dallar: `dev` (süreç/pano + birleşik), faz entegrasyon dalı (şu an `faz2-int`); `main` = son faz sürümü.
- Commit öneki: `US-nnn:` / `IS-nnn:`; yalnız süreç dosyaları `pano:`.
- Push öncesi en az `bash tools/ci_local.sh import unit tools` + dokunduğun ağ senaryoları (KR-028); tam `tools/ci_local.sh` günde bir.
- Godot yolu: `GODOT` ortam değişkeni ya da `tools/get_godot.sh`. Windows'ta Git Bash + Python ≥ 3.10.
- Kendi ajan düzenini kullanıyorsan: ajanların commit atmasın, pano dosyalarına (`docs/notes/durum.md`, `docs/surec/{backlog,kararlar,gecmis}.md`) dokunmasın; kapsam dışı bulguyu ve kararları raporla. Bu projedeki Claude ajan tanımları örnek olarak `.claude/agents/`, bekçi hook `.claude/hooks/agent_guard.py`.
