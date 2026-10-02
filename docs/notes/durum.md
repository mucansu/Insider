# Durum (2026-10-03, yerel oturum — kullanıcı "müsait yerde dur" dedi; devir noktası)

## Aktif faz
Faz 1 bitti ve test-1 checkpoint'i alındı; Faz 2 — Gizlilik (bakkal) `faz2-int` dalında sürüyor (KR-020: faz sonu beklemesi askıda). Yerel geliştirme: `C:\Users\Turkuaz\OneDrive\Desktop\Insider` (Windows 11, Git Bash, Godot 4.7.2 win64, renderer Compatibility). Oturum izin modu Auto. Kullanım sınırı nedeniyle ajan sayısı normal (≤ 3 yapım + denetimler); effort: high denetci/cekirdek/oynanis/tasarim, medium seviye/arayuz/altyapi/arastirmaci.

## Faz 1 (dev = main)
- Bitti: US-001..US-005, US-026 · IS-005, IS-007..IS-014, IS-019, IS-022, IS-026, IS-027, IS-029, IS-041, IS-042, IS-046, IS-052, IS-053 (ajan hook'ları canlı), IS-076.
- test-1: main = cc9c9e1, etiketler `faz-1`, `test-1` (CI Release ön sürümü, debug build). Kullanıcı arkadaşlarla test edecek; gözlem listesi + anket `docs/tasarim/degerlendirmeler/faz-1.md`.

## Faz 2 (`faz2-int`, GitHub'a yedekli; plan backlog §2b)
- Bitti (faz2-int): US-006, US-007, IS-023, US-009, US-013, US-014, US-011a, US-011c, US-011d, US-012, US-033, US-008 · IS-024, IS-037, IS-038, IS-039, IS-047, IS-067. Son tam CI yeşil (500 birim, 34 ağ koşusu).
- IS-078 Bitti (faz2-int eac9088, dev birleşik; tam CI yeşil 578 birim + 46 ağ koşusu).
- Denetimde: US-011b (worktree agent-ad9e586829b322a27, taban faz2-int 5ff9c28; rapor: tam CI yeşil 1065 sn; denetci + çürütmeli inceleme).
- IS-080 Bitti (faz2-int 22e9392).
- Kullanıcı faz2-int'i yerelde denedi → GB-04 → IS-080 (HUD olay metinleri), IS-081 (sahip tepkisi), US-038 (kaçış okunurluğu), IS-079 (nit).
- Önceki: US-008 Bitti (faz2-int 5ff9c28; faz1_full/heist_full/late_join_real sahipsiz `store_a_quiet` fikstüründe — sahipli uçtan uca IS-015'te). faz2-int GitHub'da güncel, 544 birim yeşil.

## Yeni sohbette ilk adımlar (sırayla; 2026-10-03 durma noktası)
1. US-011b Denetimde (worktree `.claude/worktrees/agent-ad9e586829b322a27`, dal `worktree-agent-ad9e586829b322a27`, taban faz2-int 5ff9c28, commit yok). denetci raporu durma anında bekleniyordu (gelmediyse yeniden koş). Çürütmeli inceleme bulguları — düzeltme turu (t2, oynanis; ajan bağlamı kayboldu → yeni paket):
   - should-fix: `game.gd` `_vision_attach_fog` sisi `default_mode` (çevresel) + varsayılan look RIGHT ile ilk `update_now()` yapıyor, oturum kipi sonra veriliyor → yönlü kipte doğuşta arka 288 px hafızaya yazılır, arkadaki NPC 0,1 sn görünür + 1,5 sn hayalet. Düzeltme: attach sonrası `set_mode` + `set_look_dir(me.look_dir)` + `reset_memory()` + `update_now()` (ya da attach_fog parametresi) + ağ testi iddiası "yönlü kipte doğuşta arkadaki karo MEMORY değil".
   - nit: `core/vision_rules.gd` Session `_history` ayrılan peer'ı silmiyor.
   - nit/kural: eşitleyici paket düzeni değişti, `PROTOCOL_VERSION` (game.gd:53) artırılmadı → bu kalemde 2'ye çıkar; mimari.md'ye "kablo düzeni değişince sürüm artar" kuralı.
   Sonra denetci t2 → worktree'de `US-011b:` commit → faz2-int'e `--no-ff` (faz2-int artık 22e9392: IS-078 dev birleşimi + IS-080; game.gd döküm anahtarları ve texts.csv çakışabilir, iki taraf korunur) → import + unit → push.
2. Sıradaki Faz 2: US-037 NPC teması (KR-027) → US-010 bakkal etkileşimleri (KR-026) → US-016 mekân nüfusu → IS-082 (net_smoke `args`) → IS-028 → US-038 kaçış okunurluğu (GB-04, test-2 öncesi P1) → IS-081 sahip tepkisi araştırması → IS-015 botlar → test-2 (IS-017).
3. Açık nit/kalem adayları backlog'da: IS-057..IS-077, IS-079 (IS-078/080 nit), IS-083 (US-011b nit), IS-064/IS-058, IS-020, IS-077.
4. Temizlik: 14 eski ajan worktree'si (birleşmiş, temiz) silinemedi (oto mod izni); kullanıcı ya da izinle `git worktree remove`.

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
