# Nit havuzu

KR-028 (hafif kontrol kipi): blocker olmayan bulgular burada toplanır; ayrı IS kalemi açılmaz. İlgili dosyaya dokunan sonraki kalemde ya da cila döneminde toplu çözülür; çözülen satır silinir.

| Tarih | Kaynak | Dosya | Bulgu |
|---|---|---|---|
| 2026-10-03 | US-011b t2 (oynanis) | entities/npc/components/npc_visual.gd, core/sight_gate.gd | İstemcide seviye yüklenip yerel oyuncu doğana kadar (~1 RTT) sis yok → NPC tam çizilir; sis bağlanınca görünmeyen NPC 0,2 sn tutma + 1,5 sn hayalet. Sis ilk bağlanınca/gözlemci değişince kapı `reset()` (yalnız istemci; host'ta yok) |
