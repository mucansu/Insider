# Durum (2026-10-05 04:10, dilim 2.2 kapandı — DURMA NOKTASI, sıradaki dilim 2.3 Test-2)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Dilim kuralı KR-033 (her dilim sonu durma noktası). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal). **Dilim 2.2 Hazırlık Bitti** (`dilim-2.2`, dev 69c453b = faz2-int 58aaaa4 + pano). Sıradaki: **dilim 2.3 Test-2** (backlog §1a: IS-017, IS-028, IS-032, IS-092, IS-097, IS-018 ara değerlendirme). **PROTOCOL_VERSION 6** (eski paketler bağlanamaz). Unit 926 yeşil; tam CI 2026-10-05: import/unit/tools yeşil, ağ 49 senaryo × 0/150 ms (düzeltme sonrası store_b_brain_shout PASS; store_b_smoke 0 ms'de nadir döküm yarışı, nit).
**Test-2 paketi:** `build/Insiders-faz2-58aaaa4-windows.zip` (debug, 33,7 MB; duman PASS: host + katılan INSIDERS_READY; `--log-on-exit=kayit.json` exe yanına yazıyor). Eski a01ac86 paketi artık kullanılmaz.

Dilim 2.2'de biten: IS-102 (`level_started {run}` + `--log-on-exit`), IS-106 (harita başına ayar `Level.tuning_overrides` + VenueTuning, MapGrid türetmeleri, side_zone), IS-107 (ikinci deneme haritası store_b + ezmeler + brain senaryoları; ölçüm `docs/surec/olcum/20261004-2330-is107-store-a-vs-b.md`), US-045 (gerçek alışveriş v0: sakız/ekmek/kola/damacana, harçlık 50, damacana GÖNDER'in yerine, +20 koşullu, örtü yalnız görülünce + seen_by, witness kökü: geç katılana örtü yeniden gönderimi; denetci PASS), IS-108 (yaylı arka kapı, GB-11; komşu kapalı kapıyı açar). Kararlar: KR-038 (alışveriş v0 + örtü A), KR-039 (yaylı arka kapı, kullanıcı onayı). Fable danışması: `docs/tasarim/danisma/us-045-store-b.md`.

## Sürüyor / yarım kalan
Yok. Çalışan ajan yok. Birleşmiş ajan worktree'leri silinebilir (agent-a3a31ef3878065f62, agent-a35daf60e77c7b16c, agent-a8262bafb2bf4fc59, agent-a4a49e8684e6de98a, agent-abf0f2ddef17ead21); `.claude/worktrees/faz2-int` kalır.

## Yeni sohbette ilk adımlar
1. Dilim 2.3 Test-2 başı mesajı (surec §5b): kalemler + çıkış kriteri. Kullanıcıya test-2 nasıl oynanır: paketi paylaş, Tailscale, oyunu `Insiders.exe -- --log-on-exit=kayit-<ad>.json` ile açıp kayıt dosyasını geri göndermek (oyunu-ac skill'i).
2. Test-2 gözlem formu: Fable'ın F satırları (`docs/tasarim/danisma/us-045-store-b.md` §F) + önceki satırlar (vuruş-kaç / pencere bekleme, geri sayım, arka kapı zili ve yaylı kapı okunuyor mu). store_b seçilebilir: `--level=res://levels/store_b.tscn` (host).
3. Gelen geri bildirimler `GB-nn` → `docs/surec/geri-bildirim.md`; KR-034 ilke kararı ve denge hedefleri test-2 gözlemiyle (Fable); store_b'nin zorluğu (team 3 %0 temiz) bakkal büyütme kararına veri.
4. Nit havuzundan dokunulan dosyalarınkiler; IS-109 (game.gd HeistTuning/VisionTuning → VenueTuning) havuzda.

## Kullanıcıdan bekleyen
- Test-2: yeni paketi (58aaaa4) arkadaşlarla paylaşmak + Tailscale kurulumu/daveti; gözlemler + kayıt dosyaları.
- KR-034 ilke kararı test-2 sonrası ("araç para verir, sabır/ekip temizlik verir").
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları.
- Fable değerlendirmesine (test-2 sonrası): mahallelinin yalnız örtüsü bozuk oyuncuyu kovalaması (US-043), tezgâh görüşü/tanık sönümü, KR-034 C hedef kalibrasyonu, B kilidi (6 sn), örtü zamanla dönüş (GB-08 B), şişe fırlatma, arka kapıyı dışarıdan çalma.

## Son kapanış
Dilim 2.2 — 2026-10-05: `dilim-2.2` (dev 69c453b).
Dilim 2.1 — 2026-10-04: `dilim-2.1` (dev 2606959).
Faz 1 — 2026-10-02: `faz-1` + `test-1` etiketi (main = cc9c9e1).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
