# Durum (2026-10-11, dilim 2.3 Test-2 açık + dilim 2.4 Akış ve harita sürüyor)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Dilim kuralı KR-033 (her dilim sonu durma noktası). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal). **Dilim 2.2 Hazırlık Bitti** (`dilim-2.2`, dev 69c453b = faz2-int 58aaaa4 + pano). **Dilim 2.3 Test-2 sürüyor** (2026-10-06; backlog §1a: IS-017, IS-082 (2.6'dan çekildi, IS-028 önkoşulu), IS-028, IS-032, IS-092, IS-097, IS-018 ara değerlendirme). **PROTOCOL_VERSION 7** (US-048; eski paketler bağlanamaz). Unit 926 yeşil; tam CI 2026-10-05: import/unit/tools yeşil, ağ 49 senaryo × 0/150 ms (düzeltme sonrası store_b_brain_shout PASS; store_b_smoke 0 ms'de nadir döküm yarışı, nit).
**Test-2 paketi (yeni, 2026-10-06):** `build/Insiders-faz2-eb5989e-windows.zip` (debug, 35,2 MB, protokol 7; duman PASS host + katılan INSIDERS_READY). İçinde: ortam sesi v0 (US-047), KR-041 örtü/sorgu (US-048), tutuldu/yakalandı göstergesi (IS-110). 58aaaa4 ve öncesi artık bağlanamaz.

Dilim 2.2'de biten: IS-102 (`level_started {run}` + `--log-on-exit`), IS-106 (harita başına ayar `Level.tuning_overrides` + VenueTuning, MapGrid türetmeleri, side_zone), IS-107 (ikinci deneme haritası store_b + ezmeler + brain senaryoları; ölçüm `docs/surec/olcum/20261004-2330-is107-store-a-vs-b.md`), US-045 (gerçek alışveriş v0: sakız/ekmek/kola/damacana, harçlık 50, damacana GÖNDER'in yerine, +20 koşullu, örtü yalnız görülünce + seen_by, witness kökü: geç katılana örtü yeniden gönderimi; denetci PASS), IS-108 (yaylı arka kapı, GB-11; komşu kapalı kapıyı açar). Kararlar: KR-038 (alışveriş v0 + örtü A), KR-039 (yaylı arka kapı, kullanıcı onayı). Fable danışması: `docs/tasarim/danisma/us-045-store-b.md`.

## Sürüyor / yarım kalan
**Dilim 2.3 Test-2 açık** (kullanıcı test-2'yi oynayacak; paket `build/Insiders-faz2-eb5989e-windows.zip`, protokol 7). **Dilim 2.4 Akış ve harita da başladı** (KR-044, kullanıcı: "Fable'ın planını aynen uygula", dışarıdayken başlasın; plan `docs/tasarim/danisma/faz2-yeniden-kesim.md`). İki dilim paralel: test-2'ye bağlı 2.4 kalemleri (store_b kararı, IS-097/092/105) test-2 sonrasına.
- 2.4 dalga 1 (2026-10-11, ajan worktree'leri faz2-int 000e367 tabanlı): US-049 iş-içi Başla (cekirdek; ağ → denetci), US-051 oturum skor tablosu (Bitti → faz2-int 7ab1d0c), IS-113 "Kalabalık saat" (Bitti → faz2-int 76b3f16, Haiku pilot 2 başarılı; faz2-int push'u US-049 birleşip doğrulanınca).
- 2.4 dalga 2 (dalga 1 birleşince): US-050 harita seçimi + "Başka bakkal" (arayuz + cekirdek; US-049 sonrası, game.gd çakışması), US-052 ısı/tanınma etkisi (oynanis), US-046 lite (seviye/arayuz, Haiku adayı). Dalga 3 (test-2 sonrası): store_b kararı (K3), IS-097/092/105 (K1/K4).
- Birleşme doğrulamaları kosucu (Haiku) ile (KR-042). CPU ağırlıklı koşular aynı anda tek; YÜK işaretli FAIL bir kez yeniden.
- Bitti (2026-10-06..11): US-047 ortam sesi, US-048 örtü/sorgu (denetci PASS, PROTOCOL 7), IS-110 tutma göstergesi, IS-082 + IS-028 görüş A/B, IS-111 kayıt özeti, IS-112 YÜK uyarısı; tam CI eb5989e yeşil (yük altında kararsızlar yeniden koşuda PASS).
- KR-043 cila kalemleri Havuz'da (US-021, US-022, US-024, IS-060 kalanı, IS-061, US-028, US-030; US-023 ve IS-033'ün okunurluk alt kümeleri 2.5'te).

## Yeni sohbette ilk adımlar
1. Çalışan ajan var mı bak (bu oturumda 3 ajan çalışıyordu; worktree'leri `.claude/worktrees/agent-*`). Bitenleri KR-028'e göre kapat (US-049 denetci; diğerleri koordinatör diff okuması + kosucu doğrulaması), faz2-int'e birleştir.
2. Dalga 2'yi başlat (yukarıda).
3. Kullanıcı test-2 kayıtlarını getirirse: `python tools/kayit_ozet.py kayit-*.json --md build/ozet.md` → GB-nn (`docs/surec/geri-bildirim.md`), protokol §5 karar kuralları (K1-K7) → dalga 3 + IS-018 Fable ara değerlendirmesi.
4. 2.4 çıkış kriteri: 3 kişi exe'yi yeniden açmadan art arda 3 koşu (≥ 2 harita/varyant) + test-3 paketi. Dilim sonu: faz2-int → dev, `dilim-2.4` (2.3 de kapanmış olmalı; değilse 2.3'ü test-2 sonrası kapat).

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
