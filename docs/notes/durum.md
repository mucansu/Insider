# Durum (2026-10-11 akşam, dilim 2.3 Test-2 açık + dilim 2.4 test-2'den bağımsız kalemleri Bitti)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Dilim kuralı KR-033 (her dilim sonu durma noktası). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal). **Dilim 2.2 Hazırlık Bitti** (`dilim-2.2`, dev 69c453b = faz2-int 58aaaa4 + pano). **Dilim 2.3 Test-2 sürüyor** (2026-10-06; backlog §1a: IS-017, IS-082 (2.6'dan çekildi, IS-028 önkoşulu), IS-028, IS-032, IS-092, IS-097, IS-018 ara değerlendirme). **PROTOCOL_VERSION 9** (faz2-int; test-2 paketi eb5989e = 7; US-049 → 8, US-052 → 9). Unit 926 yeşil; tam CI 2026-10-05: import/unit/tools yeşil, ağ 49 senaryo × 0/150 ms (düzeltme sonrası store_b_brain_shout PASS; store_b_smoke 0 ms'de nadir döküm yarışı, nit).
**Test-2 paketi (yeni, 2026-10-06):** `build/Insiders-faz2-eb5989e-windows.zip` (debug, 35,2 MB, protokol 7; duman PASS host + katılan INSIDERS_READY). İçinde: ortam sesi v0 (US-047), KR-041 örtü/sorgu (US-048), tutuldu/yakalandı göstergesi (IS-110). 58aaaa4 ve öncesi artık bağlanamaz.

Dilim 2.2'de biten: IS-102 (`level_started {run}` + `--log-on-exit`), IS-106 (harita başına ayar `Level.tuning_overrides` + VenueTuning, MapGrid türetmeleri, side_zone), IS-107 (ikinci deneme haritası store_b + ezmeler + brain senaryoları; ölçüm `docs/surec/olcum/20261004-2330-is107-store-a-vs-b.md`), US-045 (gerçek alışveriş v0: sakız/ekmek/kola/damacana, harçlık 50, damacana GÖNDER'in yerine, +20 koşullu, örtü yalnız görülünce + seen_by, witness kökü: geç katılana örtü yeniden gönderimi; denetci PASS), IS-108 (yaylı arka kapı, GB-11; komşu kapalı kapıyı açar). Kararlar: KR-038 (alışveriş v0 + örtü A), KR-039 (yaylı arka kapı, kullanıcı onayı). Fable danışması: `docs/tasarim/danisma/us-045-store-b.md`.

## Sürüyor / yarım kalan
**Dilim 2.3 Test-2 açık** — kullanıcı test-2'yi `build/Insiders-faz2-eb5989e-windows.zip` (protokol 7) ile oynayacak (öneri: temiz ölçüm için eski paket). **Dilim 2.4 Akış ve harita** (KR-044): test-2'den bağımsız kalemler Bitti → faz2-int 7936ad5 (kosucu birleşik doğrulama: ci_local import unit tools + 12 senaryo × 0/150 = 24/24 PASS): US-049 Başla (denetci PASS, PROTOCOL 8), US-050 harita seçimi + Başka bakkal (denetci PASS), US-051 skor tablosu, US-052 ısı/tanınma (denetci PASS, PROTOCOL 9), IS-113 Kalabalık saat (Haiku), US-046 lite ürün okunurluğu (Haiku + 1 düzeltme).
- **Test-3 paketi:** `build/Insiders-faz2-fe56fbc-windows.zip` (debug, 35,2 MB, protokol 9; duman PASS) — GB-13 düzeltmesi (IS-114, KR-045) dahil. 7936ad5 paketi KULLANILMAZ (BAŞLA bulunamıyor).
- 2.4 kalan (test-2'ye bağlı, dalga 3): store_b kararı (protokol §5 K3), IS-097 / IS-092 / IS-105 (K1/K4). 2.4 çıkış kriteri: 3 kişi exe açmadan art arda 3 koşu (≥ 2 harita) — test-3 paketiyle oynanınca sağlanır.
- KR-042 Haiku pilotu 5/5 tamam (1 dönüş: görsel yargı → görsel AC'li Haiku işinde koordinatör kare kontrolü). Ders (birleşme): çakışma çözümünde regex `=======` yorum satırıyla karıştı; elle çözülen birleşmeden sonra her zaman import + `grep -n '^=======$'`.
- Çalışan ajan yok. Worktree: yalnız faz2-int. dev'e birleşme dilim sonunda (2.3 + 2.4 birlikte kapanabilir).

## Yeni sohbette ilk adımlar
1. Kullanıcı test-2 kayıtlarını getirirse: `python tools/kayit_ozet.py kayit-*.json --md build/ozet.md` → GB-nn (`docs/surec/geri-bildirim.md`), protokol §5 karar kuralları (K1-K7) → 2.4 dalga 3 (store_b, IS-097/092/105) + IS-018 Fable ara değerlendirmesi + 2.3 kapanışı.
2. Test-3 (yeni paketle): Başla, harita seçimi, skor tablosu, Kalabalık saat, ısı/tanınma — 2.4 çıkış kriteri.
3. Dilim sonu: faz2-int → dev, `dilim-2.3` + `dilim-2.4` etiketleri, devir, kapanış mesajı.

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
