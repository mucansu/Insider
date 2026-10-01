# Durum (2026-10-01)

## Aktif faz
Faz 1 — İki kişi bakkalda (EP-01). Hedef: online his — bağlan, yürü, kasayı boşalt. Faz 0 Bitti (IS-001..004).

## Kalemler
- Sürüyor (paralel, worktree /home/user/insiders-wt/<kalem>): US-001 ağ çekirdeği (cekirdek) — 2026-10-01
- Denetimde: US-003 menü+HUD+tema (arayuz, t1)
- Bitti: US-002 bakkal v0 (denetci PASS t2, d8ab983)
- Sırada: US-004 oyuncu (oynanis; US-001+US-002 sonrası) → US-005 etkileşim (oynanis) → IS-005 çıkış testi + build (altyapi) → IS-006 kullanıcı doğrulaması

## Kullanıcıdan bekleyen
- GitHub'da `insiders` reposunu açması (Claude entegrasyonu repo oluşturamadı, 403). Açılana kadar iş yerelde: /home/user/insiders.
- KR-013 (oyun adı), KR-014 (Steamworks) — Faz 5'te sorulacak.

## Ortam
- Godot 4.7.2 headless: /home/user/tools/godot (bu konteyner) ya da tools/get_godot.sh → .tools/godot.
- Branch: dev (çalışma), main (faz sonu). Paralel paketler wt/<kalem> branch'lerinde.

## Son kapanış
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti; ci_local yeşil (11 sn).
