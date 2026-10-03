# Durum (2026-10-03 22:50)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Reçeteler `.claude/skills/` (devir dahil), ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal), entegrasyon dalı `faz2-int` = **c741981** (worktree `.claude/worktrees/faz2-int`, GitHub'da güncel). PROTOCOL_VERSION 5. Birim 733 yeşil; tam ağ seti 70/70 iki kez yeşil (IS-095 ajanı, 2026-10-03; net adımı ~33 dk). Deneme paketi: `build/Insiders-faz2-7a6e233-windows.zip` (debug, 33,5 MB; duman PASS) — kullanıcı arkadaşlarına gönderecek (Tailscale gerekli). Yerel geliştirme: Windows 11, Git Bash, Godot 4.7.2.

Bugün biten (faz2-int): US-011b, US-016, US-039, US-038, IS-085, IS-086, US-040, US-041, US-042, IS-087, US-010, IS-091, IS-094, US-043, US-044, IS-090, IS-095, IS-093 · dev: IS-088 (skill'ler, AGENTS.md), IS-089 (Utility AI araştırması), KR-028/029/030.

## Sürüyor / yarım kalan
Yok — çalışan ajan yok, tüm işler birleşik (IS-093 son, faz2-int c741981, push edildi). Deneme paketi 7a6e233'te kaldı; IS-093 yalnız yorum, yeni paket gerekmez.

## Yeni sohbette ilk adımlar
1. Kullanıcının deneme geri bildirimi gelirse `GB-nn` olarak `docs/surec/geri-bildirim.md`'ye yaz, kalemlere bağla (blocker önce).
2. Test-2 (IS-017): kullanıcı arkadaşlarla paketle oynar; istenirse `test-2` etiketi → CI Release. Öncesinde tam CI zaten yeşil.
3. Sıradaki Faz 2 kalemleri: IS-015 oyun testi botları + strateji istatistiği (tek kişi kolay geçiyor mu), US-037 NPC teması (KR-027), IS-092 küçük GDD bedelleri, IS-081 (GB-04/05 sonrası kalan sahip tepkisi), nit havuzundan dosyası dokunulanlar.
4. Temizlik: ~35 birleşmiş ajan worktree'si (`git worktree list`) — kullanıcı izniyle `git worktree remove`.

## Kullanıcıdan bekleyen
- Tailscale kurulumu ve arkadaşları tailnet'e davet (internet testi için); deneme paketinin paylaşımı.
- Test-1 sonuçları (varsa).
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları.
- Fable değerlendirmesine (test-2 sonrası): mahallelinin yalnız örtüsü bozuk oyuncuyu kovalaması (US-043), tezgâh görüşü/tanık sönümü (nit havuzu).

## Son kapanış
Faz 1 — 2026-10-02: `faz-1` + `test-1` etiketi (main = cc9c9e1).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
