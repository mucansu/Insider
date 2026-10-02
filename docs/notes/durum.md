# Durum (2026-10-02, yerel oturum)

## Aktif faz
Faz 1 — İki kişi bakkalda (EP-01). Yerel geliştirme: `C:\Users\Turkuaz\OneDrive\Desktop\Insider` (Windows 11, Git Bash, Godot 4.7.2 win64); buluttan devir tamamlandı (devir.md silindi).

## Kalemler
- Bitti (Faz 1): US-001 ağ çekirdeği · US-002 bakkal · US-003 menü/HUD/tema · IS-008 · IS-009 · IS-010 (KR-018) · IS-011 Windows yerel geliştirme (8124e82) · US-004 oyuncu karakteri (a88d9c1) · US-005 etkileşim + kasa + kapı (e32adf7)
- Bitti: IS-012 (918d0cd) · IS-014 (0d215b5) — push bekliyor
- Bitti: IS-013 Faz 1 çıkış senaryoları (afe5b6b; push bekliyor). Faz 1 checkpoint (test-1) bekleyen: IS-026 ping, IS-027 görünüm cilası · IS-007 (A) Bitti (a30c69c; GDD v0.2)
- Bitti: IS-005 build (9594144; push bekliyor) · Bitti: IS-019 renderer Compatibility (b985e8b; push bekliyor) · IS-014 Bitti (0d215b5; push bekliyor)
- Sırada: IS-007 (B) Fable Faz 1 değerlendirmesi → IS-006 kullanıcı doğrulaması → Faz 1 kapanışı
- KR-020 (kullanıcı): öncelik aramızda oynanabilir MVP; test checkpoint'leri main + `test-N`; bakkalda güvenlik yok (polis/muhafız/düğme/silah yok; sahibi bağırır, mahalleli gelir) → IS-021 Fable bakkal/kademe revizyonu; Steam işleri sona.
- KR-021 (geçici): bakkal tasarımı GDD v0.3 (sahip ajandası, sorgu/bağırış/mahalleli, tutma+ÇEK, müşteri/yoldan geçen nüfusu); Faz 2 kalemleri §2b; entegrasyon dalı `faz2-int`.
- Faz 2 (erken başlangıç, worktree): Denetimde US-006 algı çekirdeği · Bitti US-007 (dal faz2/US-007) · Sürüyor (worktree) US-009 gürültü, US-014 kukla, IS-022 ekran görüntüsü, IS-019 renderer · IS-021 Fable bakkal/kademe revizyonu; plan backlog §2b, kararlar KR-019 (geçici)
- Paralellik (kullanıcı 2026-10-02): ajan sınırı yok; koordinatör makine yüküne göre ~4-5 paralel kod paketi, her biri worktree'de.

## Kullanıcıdan bekleyen
- (Tamam) GitHub reposu: https://github.com/mucansu/Insider (private). Uzak CI'ın IS-011 sonrası Linux'ta yeşil olduğu kullanıcı tarafından Actions'ta kontrol edilecek (yerelde `gh` yok).
- (Tamam) Yerel kurulum: Godot 4.7.2 win64 `C:\Users\Turkuaz\OneDrive\Desktop\godot` (yerel `GODOT`: `.claude/settings.local.json`).
- KR-013 (oyun adı), KR-014 (Steamworks) — Faz 5'te.
- Animasyon denemesi geri bildirimi (kaydırıcı değerleri) → Faz 2 karakter kuklası.

## Son kapanış
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
