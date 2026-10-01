# Durum (2026-10-01)

## Aktif faz
Faz 1 — İki kişi bakkalda (EP-01). Hedef: online his — bağlan, yürü, kasayı boşalt. Faz 0 Bitti (IS-001..004).

## Kalemler
- Bitti: US-001 ağ çekirdeği (denetci PASS t2 + inceleme, bc49aef)
- Bitti: IS-010 OOP (A) uygulaması (denetci PASS, f6bd55c)
- Denetimde: US-004 oyuncu karakteri (oynanis, t1; denetci + çürütmeli inceleme)
- Bitti: US-003 menü+HUD+tema (denetci PASS t1, 7b34286)
- Bitti: IS-008 LEVEL_* token'ları (denetci PASS, f0f027f)
- Bitti: IS-009 girdi + nit'ler (denetci PASS t2, 332fb08)
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
