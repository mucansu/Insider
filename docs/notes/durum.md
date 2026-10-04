# Durum (2026-10-04, dilim 2.1 sürüyor — yeni oturum)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Reçeteler `.claude/skills/` (devir dahil), ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal) · **aktif dilim 2.1 Denge** (KR-033: her dilim sonu durma noktası; dilim listesi backlog §1a), entegrasyon dalı `faz2-int` = **2d5802e** (worktree `.claude/worktrees/faz2-int`, GitHub'da güncel). PROTOCOL_VERSION 5. Birim 733 yeşil; tam ağ seti 70/70 iki kez yeşil (IS-095 ajanı, 2026-10-03; net adımı ~33 dk). Deneme paketi: `build/Insiders-faz2-7a6e233-windows.zip` (debug, 33,5 MB; duman PASS) — kullanıcı arkadaşlarına gönderecek (Tailscale gerekli). Yerel geliştirme: Windows 11, Git Bash, Godot 4.7.2.

Bugün biten (faz2-int): US-011b, US-016, US-039, US-038, IS-085, IS-086, US-040, US-041, US-042, IS-087, US-010, IS-091, IS-094, US-043, US-044, IS-090, IS-095, IS-093 · 2026-10-04: US-037, IS-015a, GDD v0.5, IS-096, GDD v0.6, IS-015b, IS-098, IS-058b · dev: IS-088 (skill'ler, AGENTS.md), IS-089 (Utility AI araştırması), KR-028/029/030.

## Sürüyor / yarım kalan
Önceki ajanlara erişim yok (yeni oturum) → aynı WIP dallarından yeni ajanlar başladı (2026-10-04).
- **IS-100** Bitti (faz2-int fabd7e2, push edildi).
- **IS-081** Bitti (faz2-int 2d5802e, push). Kararı: koşu ayrımı (b) `level_started` → IS-102 (dilim 2.2).
- **IS-015 ölçümü** bitti: `docs/surec/olcum/20261004-104356-is015.md` + `-113648-is015-human.md`. Tutan: distract 40, window 67, buy 77. Tutmayan: send 100 (+human 70), bag 100, team+bag 2 = 0 vs team 3 = 45. → Fable'a danışıldı (bekleniyor).
- **IS-101** Bitti (faz2-int 80ea0e4 + f0ba1f1).
- **IS-099** Bitti (faz2-int a8e80cd, push edildi).
- Sonra: IS-100 + IS-101 birleşince `python tools/heist_stats.py --seeds 1-50 --cell team:2,3:1-20 --cell team+bag:2:1-20 --jobs 8` + `--strategies bag,send+bag,distract+bag,window+bag --players 1`; hedefler KR-032 → IS-015 kapanış.
- Not: GDD (v0.6) ve mimari.md'nin güncel kopyası faz2-int'te (dev geride; faz kapanışında gelir).

## Yeni sohbette ilk adımlar
1. Kullanıcının deneme geri bildirimi gelirse `GB-nn` olarak `docs/surec/geri-bildirim.md`'ye yaz, kalemlere bağla (blocker önce).
2. Test-2 (IS-017): kullanıcı arkadaşlarla paketle oynar; istenirse `test-2` etiketi → CI Release. Öncesinde tam CI zaten yeşil.
3. Sıradaki Faz 2 kalemleri: IS-015 oyun testi botları + strateji istatistiği (tek kişi kolay geçiyor mu), US-037 NPC teması (KR-027), IS-092 küçük GDD bedelleri, IS-081 (GB-04/05 sonrası kalan sahip tepkisi), nit havuzundan dosyası dokunulanlar.

## Kullanıcıdan bekleyen
- Tailscale kurulumu ve arkadaşları tailnet'e davet (internet testi için); deneme paketinin paylaşımı.
- Test-1 sonuçları (varsa).
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları.
- Fable değerlendirmesine (test-2 sonrası): mahallelinin yalnız örtüsü bozuk oyuncuyu kovalaması (US-043), tezgâh görüşü/tanık sönümü (nit havuzu).

## Son kapanış
Faz 1 — 2026-10-02: `faz-1` + `test-1` etiketi (main = cc9c9e1).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
