# Durum (2026-10-02, yerel oturum)

## Aktif faz
Faz 1 — İki kişi bakkalda (EP-01): kod kalemleri bitti, test-1 checkpoint'i hazırlanıyor. Faz 2 — Gizlilik (bakkal) erken başladı (KR-020: faz sonu beklemesi askıda). Yerel geliştirme: `C:\Users\Turkuaz\OneDrive\Desktop\Insider` (Windows 11, Git Bash, Godot 4.7.2 win64, renderer Compatibility).

## Faz 1
- Bitti: US-001..US-005 · IS-005 build · IS-007 (A GDD v0.2/v0.3, B faz-1 değerlendirmesi) · IS-008..IS-014 · IS-019 renderer · IS-013 çıkış senaryoları (afe5b6b).
- test-1 öncesi: IS-026 yerel ping ölçümü (cekirdek, worktree) · IS-027 kamera yakınlaştırma/sınır + arka plan (oynanis, worktree).
- Checkpoint: IS-026 + IS-027 → dev → ci_local → main ff + `faz-1` + `test-1` etiketi → push (CI main'de Windows/Linux build).
- Kullanıcı doğrulaması (IS-006): test-1 gözlem listesi + anket `docs/tasarim/degerlendirmeler/faz-1.md`.

## Faz 2 (entegrasyon dalı `faz2-int`; plan backlog §2b, KR-019/020/021)
- faz2-int'te: US-007 bakkal v1 · IS-023 nüfus işaretleri.
- Denetimde: US-006 t2 algı çekirdeği · US-013 iş sonu + uyarı HUD.
- Sürüyor (worktree): US-009 gürültü · US-014 kukla v0 · IS-022 t2 ekran görüntüsü aracı.
- Sırada (2a): US-008 bakkal sahibi (US-006 sonrası) → US-010 → US-012 → US-016 → IS-024 SFX → IS-017 oyun testi (test-2).

## Araştırma
- `docs/arastirma/`: steam-yayin, pazarlama-satis, yontem, tuzaklar, steam-ag, ad-adaylari (öneri Mapless, yedek Heistmind).
- `docs/tasarim/arastirma/`: Fable 1-3. tur + faz2-bakkal-kalemleri.

## Kullanıcıdan bekleyen
- Test-1 (arkadaşlarla) ve sonuç/video bildirimi.
- KR-019/KR-021 geçici tasarım kararlarına itiraz (varsa); ad seçimi (Mapless/Heistmind).
- İsteğe bağlı: kodsuz keşif ön testi (`docs/tasarim/arastirma/kesif-on-testi.md`).
- KR-014 Steamworks — sona kaydı (KR-020).

## Son kapanış
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
