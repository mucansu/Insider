# Insiders — proje dizini (2026-10-01)

## Amaç
Steam'de arkadaş davetiyle oynanan, 3 kişilik (2-4) online co-op, 2D üstten soygun oyunu. Ekip önce hedefi keşfeder (gördükleri haritaya işlenmez, hafızada kalır), sığınakta kroki üzerinde plan yapar, sonra soygun planın bozulmasıyla kaosa döner. Bakkaldan merkez bankasına 10 kademe, ekipmanla tanımlanan karakter gelişimi. Godot 4.7.2 + GDScript. Geliştirme: tek kullanıcı + Claude Code koordinatör + uzman ajanlar.

## Dosya haritası (sadece gerekeni oku)
| Dosya | Ne zaman oku |
|---|---|
| tasarim/oyun-tasarimi.md | Oynanış, keşif, plan, gizlilik, ekonomi, kademeler, MVP kapsamı; tasarım sorusu olan her kalemde ilgili bölüm |
| notes/mimari.md | Teknik mimari, dizin yapısı, sözleşmeler S1-S9, test katmanları; her kod kaleminde |
| ../AGENTS.md, ../.claude/skills/ | Araçtan bağımsız giriş ve "nasıl yapılır" reçeteleri (test, ağ senaryosu, NPC, seviye, metin/tema, kalem kapatma, oyunu açma) |
| notes/ajanlar.md | Ajan sahiplikleri, ortak kurallar, kalite katmanları, karar yetkisi, rapor formatı; ajan çalıştırmadan önce |
| arastirma/ | Geliştirme dışı araştırmalar (Steam yayın, pazarlama/satış, yöntem, tuzaklar); faz planı ve Faz 5 hazırlığında |
| tasarim/arastirma/ | Fable'ın tasarım ve yol haritası araştırmaları (benzer oyunlar, mekanikler, Faz 3-5 yönü); faz planı hazırlarken |
| tasarim/kukla-denemesi.html | KR-017 animasyon stili denemesi (tarayıcıda aç) |
| notes/durum.md | Her oturum başında: aktif faz, Sürüyor/Denetimde kalemler, kullanıcıdan bekleyenler |
| surec/surec.md | Yaşam döngüsü, DoR/DoD, faz kapanışı/yayın, worktree, kırmızı çizgiler (§9), koordinatör reçetesi (§10) |
| surec/backlog.md | Fazlar ve çıkış kriterleri, kalemler, görev paketleri |
| surec/kararlar.md | Karar vermeden önce (verilmiş mi?), kullanıcıya soru göndermeden önce (Bekleyen) |
| surec/gecmis.md | Faz kapanışı, ölçütler, retro |
| surec/geri-bildirim.md | Kullanıcı/oyun testi geri bildirimi geldiğinde |
| surec/oneriler.md | Fable tasarım önerileri (ON); faz planı hazırlarken |
| tasarim/degerlendirmeler/ | Fable'ın faz değerlendirme raporları |
| notes/assetler.md | dış asset kaynakları, lisansları ve yer tutucu durumu (IS-024'ten beri; ses kataloğu `data/sfx_catalog.tres`) |

## Ortak kararlar (ayrıntı kararlar.md)
- Konsept KR-001 · Steam online, 3 kişi, 2 İsveç + 1 Türkiye KR-002 · 2D önce KR-003 · hafızaya dayalı keşif KR-004 · noir ton + kozmetik ton seçimi KR-005 · minimal çatışma KR-006 · Godot 4.7.2 + GDScript KR-007 · host yetkili ağ KR-008 · test yöntemi KR-009 · süreç KR-010 · faz planı KR-015.
