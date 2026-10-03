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
| 2026-10-03 | US-040/041 (oynanis) | ui/theme, ui/hud.gd | Eksi kasa AlertLabel ile 24 → 18 px küçülüyor; temada DebtLabel (başlık boyu + uyarı rengi) |
| 2026-10-03 | US-040/041 (oynanis) | ui/escape_panel.gd | Kasayı boşaltan sonradan yakalanırsa istemci geri sayımı göstermez (host kararı doğru); 150 ms'de istemci sayacı ~0,2 sn "0"da bekler |
| 2026-10-03 | US-040/041 (oynanis) | ui/heist_end.gd | aborted sonucu başarı jingle'ını çalıyor |
| 2026-10-03 | IS-086 (seviye) | entities/npc/owner | DİNLE sırasında sahip balonu yok (GDD "?") — IS-087'de |
| 2026-10-03 | US-042 (oynanis) | core/heist_rules.gd | `Tracker.note_social` hazır, bağlı değil — US-010 SATIN AL/OYALA/GÖNDER çağırmalı (US-010 paketine iletilecek) |
| 2026-10-03 | US-042 (oynanis) | entities/npc/components/perception.gd | Sahibin görüş hattını tezgâh kesiyor (hemen önünü görmüyor) |
| 2026-10-03 | US-042 (oynanis) | core/heist_rules.gd | 'İşaretli' için yalnız bağırış/tutma sayılıyor, owner_question sayılmıyor; kaçış paneli örtü satırı yüzünden hep görünür |
| 2026-10-03 | koordinatör | docs/notes/mimari.md | S3 eki tek uzun satır → her birleşmede çakışıyor; maddelere bölünmeli |
| 2026-10-03 | Explore | autoload/game.gd:53 | PROTOCOL_VERSION üstündeki yorum '2: US-011b' diyor, değer 3 (US-016) |
| 2026-10-03 | US-043 (oynanis) | entities/npc/chaser | Mahalleli sonradan oluşunca örtüyü sahibin duyusundan okur; sahipsiz seviyede herkesi kovalar. Geç katılan istemcide `cover` etiketi eksik olabilir (yalnız istem; host doğrular) |
| 2026-10-03 | IS-093 (arayuz) | levels/store_a.tscn | build_levels.gd yeniden üretince Props altındaki 4 düğümde (Counter, ShelfProp1-3) `unique_id=` farkı çıkıyor; commit'li .tscn üretici çıktısından sapmış |
| 2026-10-03 | IS-093 (altyapi) | tools/perf_dump.bat | `rem` yorumları Türkçe kaldı (ASCII, CRLF; export.sh build'e kopyalar) |
| 2026-10-03 | IS-093 (altyapi) | tools/net_smoke.py | 3 docstring'de yorum içi kod örneği girintisi sadeleşti (ör. `expand_bot_loop`) |
| 2026-10-04 | US-037 (oynanis) | entities/player/player_status.gd | Omuzla ÇEK, Rescue bileşeninin `completed` sinyalini dışarıdan yayarak tetikleniyor; temiz yol `PlayerStatus.host_rescue(rescuer)` API'si |
| 2026-10-04 | US-037 (oynanis) | tests/net | Omuzla kurtarma (TUT'ta ekip arkadaşının omzu) yalnız birim testte; net senaryosu yok |
| 2026-10-04 | US-037 (denetci) | entities/npc/components/npc_contact.gd:233, player.gd:318 | Kızışmışta host +8 px pay kullanıyor, istemci tahmini kullanmıyor → 24-32 px'te iten yerel yavaşlamayı uygulamaz (his farkı) |
| 2026-10-04 | IS-015a (oynanis) | core/bot_rules.gd | Tezgâh/kasa durma noktaları store_a geometrisine göre; katı karakter listesi LevelLayout lejantının kopyası |
| 2026-10-04 | IS-015a (oynanis) | autoload/game.gd | `--quit-on-heist-end` döküm yazımı main.gd'deki ~6 satırın kopyası; main.gd'ye taşınabilir |
| 2026-10-04 | IS-015a (oynanis) | entities/npc/chaser | Takım koşusunda iş bittikten sonra kaçış bölgesindeki oyunculara chaser `player_caught` olayları düşüyor (sonuç yine escaped) — IS-081 AC3 (5 player_caught) ile birlikte bakılmalı |
| 2026-10-04 | IS-096 (oynanis) | entities/npc/owner/task_glyph.gd | Glif rozeti 8 px yarıçap (`BADGE_RADIUS`); oyun testinde büyütmek gerekebilir |
| 2026-10-04 | IS-096 (oynanis) | entities/npc/components/npc_visual.gd | Koni duvara göre kırpılmıyor, sisin üstüne taşıyor; "konide" kararı yalnız geometri (karanlık bölge kuralı yok) |
| 2026-10-04 | IS-015b (cekirdek) | tools/heist_stats.py | `--brain-loop` / `brain.runs[]` (IS-058b) satırlara açılmıyor; şema gelince küçük ek |
| 2026-10-04 | IS-015b (cekirdek) | tests/net/brain_disconnect.json | Her gecikmede ~153 sn → tam ci_local'a ~5 dk ekler |
| 2026-10-04 | IS-098 (oynanis) | entities/npc/components/perception.gd, levels/fog/fog_layer.gd | `SEE_THROUGH_GROUP` sabitleri artık yalnız test_physics_layers için duruyor |
| 2026-10-04 | IS-098 (oynanis) | entities/npc/civilian/civilian_senses.gd | `_sees_owner` "tezgâh alçak, satış alanı içi her zaman görür" kısayolu artık gereksiz (IS-098 sınıf kuralı) |
| 2026-10-04 | IS-058b (oynanis) | entities/player/bot_brain.gd | Adil kipte window/distract/buy çoğunlukla bekleme zaman aşımıyla gidiyor (ön kaldırım/raf ucundan sahip görülmüyor) — bekleme noktası seçimi; prop durumları (kasa/çanta) hâlâ her şeyi bilen kipte; çevresel silüet görüşü sayılmıyor |
