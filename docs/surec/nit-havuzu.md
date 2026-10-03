# Nit havuzu

KR-028 (hafif kontrol kipi): blocker olmayan bulgular burada toplanır; ayrı IS kalemi açılmaz. İlgili dosyaya dokunan sonraki kalemde ya da cila döneminde toplu çözülür; çözülen satır silinir.

| Tarih | Kaynak | Dosya | Bulgu |
|---|---|---|---|
| 2026-10-03 | US-011b t2 (oynanis) | entities/npc/components/npc_visual.gd, core/sight_gate.gd | İstemcide seviye yüklenip yerel oyuncu doğana kadar (~1 RTT) sis yok → NPC tam çizilir; sis bağlanınca görünmeyen NPC 0,2 sn tutma + 1,5 sn hayalet. Sis ilk bağlanınca/gözlemci değişince kapı `reset()` (yalnız istemci; host'ta yok) |
| 2026-10-03 | US-038 (arayuz) | core/heist_rules.gd, ui/heist_end.gd | Geç katılan session_event görmediği için yakalanma nedenini bilmez (genel "Yakalandı"); öneri `build_result` oyuncu kaydına `caught_by` (sözlük alanı, protokol değişmez) |
| 2026-10-03 | US-038 (arayuz) | entities/fx/escape_marker.gd | Zemin katmanı seviye kökünde sonra çizildiği için bölgeden geçen NPC'nin üstüne yarı saydam biner (z sırası) |
| 2026-10-03 | US-038 (arayuz) | ui/escape_arrow.gd, ui/team_markers.gd | Kaçış oku ekip okuyla aynı kenar noktasına düşebilir |
| 2026-10-03 | US-038 (arayuz) | levels/tools/build_levels.gd | EscapeMarker kök düğümünün seviye yeniden üretiminde korunduğu denenmedi |
| 2026-10-03 | US-016 (oynanis) | entities/npc/owner, data/sfx_catalog.tres | Keşif stinger'ı bağlı değil (sahip sesleri hiç bağlı değil; IS-033) |
| 2026-10-03 | US-016 (oynanis) | entities/npc/civilian | Her sivil algıyı her karede koşuyor (en kötü ~720 ışın/sn; GDD ~270); IS-066 örneklemesi sivillere de |
| 2026-10-03 | US-016 (oynanis) | core/civilian_rules.gd | Tanığın +60'ı sahip oyuncuyu görmezse 20/sn sönüyor (sahip omuz silker) — Fable değerlendirsin |
| 2026-10-03 | US-016 (oynanis) | tests/fixtures/population_{busy,late}.tres | Ana population.tres kopyaları; kayabilir |
| 2026-10-03 | US-016 (oynanis) | core/civilian_rules.gd, S4 | Tezgâh görüş engeli → kuyruktaki müşteri kasayı göremez; 'ikisi satış katında ise sahibi görür' gevşetmesi var. Tezgâh siviller için alçak sayılsın mı — Fable |
| 2026-10-03 | US-016 (oynanis) | entities/npc/civilian | AC dışı eklenen davranışlar: uyarı ≥ 2'de müşteriler kaçar; yoldan geçen koniyle hep görür (yalnız bakış penceresinde değil) — oyun testinde gözle |
| 2026-10-03 | IS-085 (oynanis) | entities/props/bag_carry.gd | Dikey yürüyüşte sarkaç tetiklenmiyor; önde (z+1) çanta üst üste binen başka oyuncunun da üstünde; etkileşimde ayrı taşıma pozu yok; devir alanı/döküm CARRY_OFFSET'te (çizimden ~15 px) |
