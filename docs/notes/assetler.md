# Dış varlıklar ve lisanslar (2026-10-02, IS-024 ile açıldı)

Kural: oyuna giren her dış dosya burada bir satırdır; paket lisans metninin kopyası `assets/licenses/<kaynak>.txt`. Satırı olmayan `assets/sfx/` dosyası birim testte hatadır (`tests/unit/test_assets_registry.gd`). Yalnız CC0 ya da açıkça ticari kullanıma izinli kaynak; BY-SA, NC ve lisans metni olmayan "royalty-free" yasak (araştırma: `docs/tasarim/arastirma/ses-ve-sfx.md` §3).

## Yer tutucu sesler

- Bugünkü bütün sesler **geçici yer tutucudur** (kullanıcı kararı, 2026-10-02): CC0 paketlerden indirildi, ileride üretilecek seslerle (yapay zekâ ya da kayıt) değişecek. Katalogda her girdi `placeholder = true` taşır; kalan yer tutucu sayısı `SfxCatalog.placeholder_events()` ile okunur (birim test raporlar).
- **Değiştirme yolu:** kod sesi yalnız olay adıyla çalar (`data/sfx_catalog.tres` → olay adı → dosya). Yeni ses = aynı adla `assets/sfx/<olay>.ogg` dosyasının üzerine yazmak (ya da katalog girdisinde `stream`'i yeni dosyaya çevirmek); ses düzeyi/perde aynı girdide. Kod değişmez. Sonra: o girdide `placeholder = false`, bu tablodaki satır yeni kaynakla güncellenir, eski paket artık kullanılmıyorsa lisans kopyası kaldırılır.
- **Yapay zekâ üretimi** ses gelirse satırda "AI üretimi mi" = `evet (araç, tarih)` ve "Steam bildirimi" = `evet`; ayrıca aşağıdaki "Yapay zekâ üretimi" listesine girer (Faz 5 Steam içerik anketi buradan yazılır).
- Türkçe NPC ünlemleri ("Hı?", "Hey!", "Hırsız var!") bugün İngilizce/sözsüz yer tutucudur; kullanıcı kaydı ya da üretimle değişecek (ses-ve-sfx §2 #4-#5).

## SFX

Ortak alanlar (aşağıdaki her satır için aynı): yazar **Kenney (kenney.nl)** · lisans **CC0 1.0** · indirme tarihi **2026-10-02** · atıf gerekli mi **hayır** (Kenney takdir edilir, zorunlu değil) · değişiklik **yok** (dosya olduğu gibi; ses düzeyi/perde yalnız katalogda) · AI üretimi mi **hayır** · Steam bildirimi **hayır** · durum **yer tutucu — üretimle değiştirilecek**.

| id | dosya | olay / kullanım | kaynak paket (URL) · paket içi dosya | lisans kopyası | durum |
|---|---|---|---|---|---|
| sfx_door_open | assets/sfx/door_open.ogg | `door_open` · kapı açıldı (door.gd) | https://kenney.nl/assets/rpg-audio · `doorOpen_1.ogg` | assets/licenses/kenney_rpg-audio.txt | yer tutucu — üretimle değiştirilecek |
| sfx_door_close | assets/sfx/door_close.ogg | `door_close` · kapı kapandı (door.gd) | https://kenney.nl/assets/rpg-audio · `doorClose_2.ogg` | assets/licenses/kenney_rpg-audio.txt | yer tutucu — üretimle değiştirilecek |
| sfx_register_tick | assets/sfx/register_tick.ogg | `register_tick` · kasa boşaltılırken tekrar (register.gd) | https://kenney.nl/assets/rpg-audio · `handleCoins2.ogg` | assets/licenses/kenney_rpg-audio.txt | yer tutucu — üretimle değiştirilecek |
| sfx_register_done | assets/sfx/register_done.ogg | `register_done` · kasa boşaldı "çın" (register.gd) | https://kenney.nl/assets/impact-sounds · `impactBell_heavy_004.ogg` | assets/licenses/kenney_impact-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_ui_click | assets/sfx/ui_click.ogg | `ui_click` · düğmeye basma (ui/) | https://kenney.nl/assets/interface-sounds · `click_002.ogg` | assets/licenses/kenney_interface-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_ui_focus | assets/sfx/ui_focus.ogg | `ui_focus` · düğme odağı (ui/) | https://kenney.nl/assets/interface-sounds · `tick_001.ogg` | assets/licenses/kenney_interface-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_alert_step | assets/sfx/alert_step.ogg | `alert_step` · uyarı kademesi 1-2 (alert_ladder.gd) | https://kenney.nl/assets/interface-sounds · `select_003.ogg` | assets/licenses/kenney_interface-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_alert_high | assets/sfx/alert_high.ogg | `alert_high` · uyarı kademesi 3+ (alert_ladder.gd) | https://kenney.nl/assets/music-jingles · `Hit jingles/jingles_HIT00.ogg` | assets/licenses/kenney_music-jingles.txt | yer tutucu — üretimle değiştirilecek |
| sfx_stinger_success | assets/sfx/stinger_success.ogg | `stinger_success` · iş sonu (kaçış) (heist_end.gd) | https://kenney.nl/assets/music-jingles · `Sax jingles/jingles_SAX10.ogg` | assets/licenses/kenney_music-jingles.txt | yer tutucu — üretimle değiştirilecek |
| sfx_stinger_caught | assets/sfx/stinger_caught.ogg | `stinger_caught` · iş sonu (yakalanma/polis) (heist_end.gd) | https://kenney.nl/assets/music-jingles · `Hit jingles/jingles_HIT04.ogg` | assets/licenses/kenney_music-jingles.txt | yer tutucu — üretimle değiştirilecek |
| sfx_clerk_question | assets/sfx/clerk_question.ogg | `clerk_question` · bakkal sahibi "Hı?" (sözsüz; bağlama US-008) | https://kenney.nl/assets/interface-sounds · `question_001.ogg` | assets/licenses/kenney_interface-sounds.txt | yer tutucu — TR kayıt/üretimle değiştirilecek |
| vo_clerk_interrogate | assets/sfx/clerk_interrogate.ogg | `clerk_interrogate` · bakkal sahibi "Hey!" (EN "Hold!"; bağlama US-008) | https://kenney.nl/assets/voiceover-pack · `Male/hold.ogg` (seslendirme: Jeffrey M. Smith) | assets/licenses/kenney_voiceover-pack.txt, kenney_voiceover-pack_credits.txt | yer tutucu — TR kayıt/üretimle değiştirilecek |
| vo_clerk_shout | assets/sfx/clerk_shout.ogg | `clerk_shout` · "Hırsız var!" (EN "Look out!"; bağlama US-008) | https://kenney.nl/assets/voiceover-pack · `Male/war_look_out.ogg` (seslendirme: Jeffrey M. Smith) | assets/licenses/kenney_voiceover-pack.txt, kenney_voiceover-pack_credits.txt | yer tutucu — TR kayıt/üretimle değiştirilecek |
| sfx_run_step | assets/sfx/run_step.ogg | `run_step` · koşu adımı (bağlama US-009) | https://kenney.nl/assets/impact-sounds · `footstep_concrete_000.ogg` | assets/licenses/kenney_impact-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_walk_step_1 | assets/sfx/walk_step_1.ogg | `walk_step` · yürüme adımı varyant 1 (US-047; footstep_emitter.gd) | https://kenney.nl/assets/impact-sounds · `footstep_carpet_000.ogg` (**değişiklik:** stereo → mono, indirme 2026-10-06) | assets/licenses/kenney_impact-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_walk_step_2 | assets/sfx/walk_step_2.ogg | `walk_step` · yürüme adımı varyant 2 (US-047; footstep_emitter.gd) | https://kenney.nl/assets/impact-sounds · `footstep_carpet_001.ogg` (**değişiklik:** stereo → mono, indirme 2026-10-06) | assets/licenses/kenney_impact-sounds.txt | yer tutucu — üretimle değiştirilecek |
| sfx_walk_step_3 | assets/sfx/walk_step_3.ogg | `walk_step` · yürüme adımı varyant 3 (US-047; footstep_emitter.gd) | https://kenney.nl/assets/impact-sounds · `footstep_carpet_002.ogg` (**değişiklik:** stereo → mono, indirme 2026-10-06) | assets/licenses/kenney_impact-sounds.txt | yer tutucu — üretimle değiştirilecek |

Paket lisansları (indirme anında okundu, 2026-10-02): altı Kenney paketinin `License.txt`'i "Creative Commons Zero, CC0" yazıyor; kenney.nl sayfaları da "Creative Commons CC0". İndirilip kullanılmayan paket: Kenney UI Audio (https://kenney.nl/assets/ui-audio, CC0) — depoya dosya girmedi. Arşivler depo dışında indirildi; depoya yalnız seçilen `.ogg` dosyaları ve lisans metinleri girdi.

## Ses satırları (ton başına)

Henüz yok (yer tutucular yukarıda SFX tablosunda; kullanıcı kaydı/üretim gelince buraya `assets/vo/<ton>/` satırları).

## Ortam ve müzik (US-047, 2026-10-06)

Ortak alanlar: lisans **CC0 1.0** (kaynak sayfada okundu, 2026-10-06; tam metin `assets/licenses/cc0-1.0_legalcode.txt`, kaynak dökümü `assets/licenses/cc0_sources_us047.txt`) · atıf gerekli mi **hayır** · AI üretimi mi **hayır** · Steam bildirimi **hayır** · **değişiklik:** kesit alındı, 44,1 kHz'e örneklendi, RMS −20 dBFS'e normalize, baş-son eşit güç çapraz geçişle dikişsiz döngü yapıldı, OGG Vorbis (içe aktarmada `loop=true`). Düzeyler yalnız `data/sfx_catalog.tres` `loops` altında. Freesound özgün dosyaları giriş ister; aynı CC0 sesin herkese açık HQ önizlemesi (128 kbps MP3) kaynak alındı.

| id | dosya | olay / kullanım | kaynak (URL) · yazar · kesit | lisans kopyası | durum |
|---|---|---|---|---|---|
| amb_street | assets/ambience/amb_street.ogg | `amb_street` · dışarıda sokak döngüsü (uzak trafik + kuş), Ambience bus (soundscape.gd) | https://freesound.org/people/Alex_hears_things/sounds/339904/ · Alex_hears_things · 2:00'dan 48 sn, mono | assets/licenses/cc0_sources_us047.txt, cc0-1.0_legalcode.txt | yer tutucu — üretimle değiştirilecek |
| amb_room | assets/ambience/amb_room.ogg | `amb_room` · dükkân içi oda tonu (içecek dolabı uğultusu), Ambience bus | https://opengameart.org/content/the-shop · LEGIT Audio · `TheShopCollection_convenience_store_drinks_fridge_drone.wav` 0:00.3'ten 10 sn, mono | assets/licenses/cc0_sources_us047.txt, cc0-1.0_legalcode.txt | yer tutucu — üretimle değiştirilecek |
| amb_murmur | assets/ambience/amb_murmur.ogg | `amb_murmur` · müşteri mırıltısı (küçük grup, anlaşılmaz dil), Ambience bus | https://freesound.org/people/IENBA/sounds/653920/ · IENBA · 0:01.5'ten 18 sn, mono | assets/licenses/cc0_sources_us047.txt, cc0-1.0_legalcode.txt | yer tutucu — üretimle değiştirilecek |
| music_calm | assets/music/music_calm.ogg | `music_calm` · sakin caz/blues döngüsü, Music bus (MusicRules) | https://freesound.org/people/Drumartist/sounds/512674/ · Drumartist · ilk 66 sn, stereo | assets/licenses/cc0_sources_us047.txt, cc0-1.0_legalcode.txt | yer tutucu — üretimle değiştirilecek |

## Yazı tipi · İkon

Henüz yok (Faz 4; CC-BY ikon seti seçilirse "atıf metni" sütunu eklenir ve Faz 5 kredilerine kopyalanır).

## Yapay zekâ üretimi

Henüz yok. Her satır: dosya · araç · tarih · istem özeti · Steam bildirimi (evet).
