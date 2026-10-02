# Durum (2026-10-02, yerel oturum)

## Aktif faz
Faz 1 — İki kişi bakkalda (EP-01): kod kalemleri bitti, test-1 checkpoint'i hazırlanıyor. Faz 2 — Gizlilik (bakkal) erken başladı (KR-020: faz sonu beklemesi askıda). Yerel geliştirme: `C:\Users\Turkuaz\OneDrive\Desktop\Insider` (Windows 11, Git Bash, Godot 4.7.2 win64, renderer Compatibility). Eşzamanlı ajan sınırı 20.

## Faz 1 (dev)
- Bitti: US-001..US-005 · IS-005 · IS-007 · IS-008..IS-014 · IS-019 · IS-022 · IS-027 · IS-029 sızıntı kapısı · IS-041/IS-042 README Tailscale + test-* Release.
- test-1 öncesi: IS-026 t3 ping (denetimde) · US-026 bağlantı kolaylığı (sürüyor).
- Checkpoint: ikisi → dev → ci_local → main ff + `faz-1` + `test-1` etiketi → push (CI build + Release ön sürümü).
- Kullanıcı doğrulaması (IS-006): test-1 gözlem listesi + anket `docs/tasarim/degerlendirmeler/faz-1.md`.

## Faz 2 (entegrasyon dalı `faz2-int`; plan backlog §2b)
- faz2-int'te Bitti: US-006 · US-007 · IS-023 · US-009 · US-013 · US-014 · US-011d.
- Denetimde: US-012 soygun sonucu (denetci + çürütme) · IS-024 t2 sesler · US-011a t2 sis · US-011c t2 görüş arayüzü · IS-037 fizik sabitleri.
- Sürüyor: US-008 bakkal sahibi · US-033 koliler · IS-038/039 · IS-047 t1b · IS-067 · IS-053 (dev) · IS-052 (denetim IS-053 ile).
- Sırada: US-011b → US-010 → US-016 → IS-028 → IS-015 → test-2 (IS-017).

## Araştırma
- Teknik (`docs/arastirma/teknik/`, arastirmaci, sürekli tur): ag-kodu, operasyon-guvenilirlik, mimari-test, cizim-performans, ses (tur 2 sürüyor); oyun-yz, ajan-sureci (tur 2 bitti).
- Tasarım: `docs/tasarim/arastirma/` (Fable); KR-026 bakkal etkileşim kararları.

## Kullanıcıdan bekleyen
- Test-1 (arkadaşlarla) ve sonuç/video bildirimi.
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları; itch gizli sayfa (test-2).
- KR-019/021/023/026 geçici tasarım kararlarına itiraz (varsa).

## Son kapanış
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
