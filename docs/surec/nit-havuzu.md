# Nit havuzu

KR-028 (hafif kontrol kipi): blocker olmayan bulgular burada toplanır; ayrı IS kalemi açılmaz. İlgili dosyaya dokunan sonraki kalemde ya da cila döneminde toplu çözülür; çözülen satır silinir.

| Tarih | Kaynak | Dosya | Bulgu |
|---|---|---|---|
| 2026-10-03 | US-011b t2 (oynanis) | entities/npc/components/npc_visual.gd, core/sight_gate.gd | İstemcide seviye yüklenip yerel oyuncu doğana kadar (~1 RTT) sis yok → NPC tam çizilir; sis bağlanınca görünmeyen NPC 0,2 sn tutma + 1,5 sn hayalet. Sis ilk bağlanınca/gözlemci değişince kapı `reset()` (yalnız istemci; host'ta yok) |
| 2026-10-03 | US-038 (arayuz) | core/heist_rules.gd, ui/heist_end.gd | Geç katılan session_event görmediği için yakalanma nedenini bilmez (genel "Yakalandı"); öneri `build_result` oyuncu kaydına `caught_by` (sözlük alanı, protokol değişmez) |
| 2026-10-03 | US-038 (arayuz) | ui/escape_panel.gd | Herkes bölgede ama ganimet 0 → iş bitmez, HUD ipucu yok |
| 2026-10-03 | US-038 (arayuz) | entities/fx/escape_marker.gd | Zemin katmanı seviye kökünde sonra çizildiği için bölgeden geçen NPC'nin üstüne yarı saydam biner (z sırası) |
| 2026-10-03 | US-038 (arayuz) | ui/escape_arrow.gd, ui/team_markers.gd | Kaçış oku ekip okuyla aynı kenar noktasına düşebilir |
| 2026-10-03 | US-038 (arayuz) | levels/tools/build_levels.gd | EscapeMarker kök düğümünün seviye yeniden üretiminde korunduğu denenmedi |
