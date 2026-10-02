# Durum (2026-10-02, yerel oturum — yeni sohbete devir)

## Aktif faz
Faz 1 bitti ve test-1 checkpoint'i alındı; Faz 2 — Gizlilik (bakkal) `faz2-int` dalında sürüyor (KR-020: faz sonu beklemesi askıda). Yerel geliştirme: `C:\Users\Turkuaz\OneDrive\Desktop\Insider` (Windows 11, Git Bash, Godot 4.7.2 win64, renderer Compatibility). Oturum izin modu Auto. Kullanım sınırı nedeniyle ajan sayısı normal (≤ 3 yapım + denetimler); effort: high denetci/cekirdek/oynanis/tasarim, medium seviye/arayuz/altyapi/arastirmaci.

## Faz 1 (dev = main)
- Bitti: US-001..US-005, US-026 · IS-005, IS-007..IS-014, IS-019, IS-022, IS-026, IS-027, IS-029, IS-041, IS-042, IS-046, IS-052, IS-053 (ajan hook'ları canlı), IS-076.
- test-1: main = cc9c9e1, etiketler `faz-1`, `test-1` (CI Release ön sürümü, debug build). Kullanıcı arkadaşlarla test edecek; gözlem listesi + anket `docs/tasarim/degerlendirmeler/faz-1.md`.

## Faz 2 (`faz2-int`, GitHub'a yedekli; plan backlog §2b)
- Bitti (faz2-int): US-006, US-007, IS-023, US-009, US-013, US-014, US-011a, US-011c, US-011d, US-012, US-033 · IS-024, IS-037, IS-038, IS-039, IS-047, IS-067. Son tam CI yeşil (500 birim, 34 ağ koşusu).
- Sürüyor: US-008 bakkal sahibi — t2 denetci PASS; ajan (worktree `.claude/worktrees/agent-aad82679a5ece5354`) güncel faz2-int'e taşıyor (stash/reset/apply; game.gd heist bağlaması, PhysicsLayers, contracts.gd alert üyeleri, AC2 pencere ölçümü engellerle).

## Yeni sohbette ilk adımlar (sırayla)
1. US-008 taşıma raporu: worktree'de `git status`/`git diff` ve `bash tools/ci_local.sh` (net dahil) yeşilse kısa denetci doğrulaması → commit (`US-008: …`) → faz2-int'e `--no-ff` → faz2-int CI → `git push origin faz2-int`. Ajan raporu gelmediyse worktree'yi kontrol et; yarım taşıma varsa aynı talimatla yeni oynanis ajanı.
2. dev → faz2-int birleştir (IS-026 `get_ping_info` → `tests/contracts.gd` Net listesine ekle; IS-046 koşucu, IS-053, IS-076).
3. Sıradaki Faz 2: US-011b (bakış + NPC görünürlük kapısı; `Level.attach_fog` Game'den bağlanır) → US-037 NPC teması (KR-027) → US-010 bakkal etkileşimleri (KR-026) → US-016 mekân nüfusu → IS-028 → IS-015 botlar → test-2 (IS-017).
4. Açık nit/kalem adayları backlog'da: IS-057..IS-077 (araştırma turlarından), IS-064/IS-058 (US-008 kalanları), IS-020 (level_change kararsızlığı), IS-077 (sert ağ auth ERROR'u).

## Araştırma
- Teknik: `docs/arastirma/teknik/` (ag-kodu, operasyon-guvenilirlik, mimari-test, cizim-performans, ses, oyun-yz, ajan-sureci — her biri 2 tur). Yeni tur kullanım sınırı rahatlayınca.
- Tasarım: `docs/tasarim/arastirma/` (Fable); KR-026 bakkal etkileşimleri, KR-027 NPC teması/itme + ajanda süreleri + chaser 190.

## Kullanıcıdan bekleyen
- Test-1 sonuçları (video olabilir); Releases'te test-1 zip'inin görünüp görünmediği.
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı (ElevenLabs Starter 1 ay önerisi), KR-025 Türkçe ses satırları (kullanıcı kaydı önerisi); itch gizli sayfa (test-2).
- KR-019/021/023/026/027 geçici tasarım kararlarına itiraz (varsa).

## Son kapanış
Faz 1 — 2026-10-02: kod kalemleri Bitti, `faz-1` + `test-1` etiketi (kullanıcı doğrulaması test-1 ile).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
