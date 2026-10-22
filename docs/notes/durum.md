# Durum (2026-10-22, KR-047: test-2 test-3 paketiyle birleşti; beklerken dilim 2.5'in teste bağlı olmayan kalemleri sürüyor)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde; tam CI günde bir + test-N öncesi. Model yönlendirme KR-042 (kosucu = Haiku test koşucu; XS kalemler haiku; görsel AC'li Haiku işinde koordinatör kareye bakar). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Pano: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa.

## Aktif faz
Faz 2 — Gizlilik (bakkal). faz2-int **69830ad** (dev'e henüz birleşmedi; dilim-2.2 sonrası tüm iş faz2-int'te). **PROTOCOL_VERSION 10.** Paketler: test-2 `build/Insiders-faz2-eb5989e-windows.zip` (protokol 7, arkadaşlarla test-2 için), test-3 `build/Insiders-faz2-69830ad-windows.zip` (protokol 10; Başla minibüste, harita seçimi + Başka bakkal, skor tablosu, Kalabalık saat, ısı/tanınma, ürün işaretleri, hazırlıkta keşif bedeli). 7936ad5 ve fe56fbc paketleri kullanılmaz. Faz 2 planı KR-044 (Fable `docs/tasarim/danisma/faz2-yeniden-kesim.md`): 2.4 Akış ve harita → 2.5 Ekip ve iletişim → 2.6 Kapanış + keşif ön testi; cila Havuz'da (KR-043).

## Sürüyor / yarım kalan
- **2026-10-22 KR-048/049 (oturumluk: en çok ajan + her adım Fable'dan geçer):** paralel 7 kalem worktree'lerde: US-027, US-025, US-015 (denetci), IS-075, US-031a, US-031b (denetci), US-023a. Sırada: IS-043 (US-027 sonrası), IS-057 (US-015 sonrası, denetci). Paket kesildikten sonra IS-040, IS-064. Ağ testleri ortak kilitle (scratchpad `net.lock`). Her kalem kapanmadan Fable gözden geçirir.
- **2026-10-22 KR-047:** kullanıcı test-2'yi ayrı oynamayacak; arkadaş testi test-3 paketiyle (69830ad), test-2 soruları (K1-K7) orada. Beklerken dilim 2.5: **US-027** bağlantı hataları + build kimliği (cekirdek, worktree, denetci gerekir), **US-025** Ayarlar v0 (arayuz, worktree), **US-031** Lobi v0 kapsamı Fable'a danışıldı (`docs/tasarim/danisma/lobi-v0.md`). Bu birleşmelerden sonra test-3 öncesi tam ci_local + yeni paket.
Çalışan ajan yok; worktree `.claude/worktrees/faz2-int` (+ birleşmiş agent-afc504e12f07f1d6e, silinebilir). Worktree yalnız `.claude/worktrees/faz2-int`.
- Dilim 2.3 Test-2: kullanıcı arkadaşlarla test-2'yi henüz oynamadı (protokol `docs/tasarim/danisma/test-2-protokol.md`).
- Dilim 2.4 Bitti olanlar: US-049 Başla (denetci PASS), US-050 harita seçimi (denetci PASS), US-051 skor tablosu, US-052 ısı/tanınma (denetci PASS), IS-113 Kalabalık saat, US-046 lite, IS-114 BAŞLA minibüste (GB-13, KR-045 + eki). Kalan (test-2'ye bağlı): store_b kararı (K3), IS-097/IS-092/IS-105 (K1/K4).
- **GB-14 → KR-046 → US-053 Bitti** (faz2-int 69830ad, denetci PASS, PROTOCOL 10): hazırlıkta sahibin şüphesi işler, DETECT = tanınma (işe 30'dan), tutma/bağırış yok; raf + ödeme hazırlıkta açık. **Yeni test-3 paketi `build/Insiders-faz2-69830ad-windows.zip`** (fe56fbc paketinin yerine; protokol 10).
- Tam ci_local faz2-int fe56fbc **yeşil** (2026-10-12; 59 net senaryo × 0/150, FAIL 0; net adımı ~80 dk, toplam 83 dk). US-053 sonrası birleşik ağaç denetlenen ağaçla aynı (yalnız mimari.md boş satır) → yeniden koşulmadı.

## Yeni sohbette ilk adımlar
1. US-053 kullanıcı denemesi (2026-10-13, faz2-int 69830ad yerel, kayıt `docs/surec/olcum/20261013-us053-kayit-*.json`): kayıtta hazırlık tanıma 13,9 sn, uyarı hazırlıkta 0, BAŞLA 41,1 sn, ilk görüş 30 ("Sen yine mi?") — kurala uygun; kullanıcının his yorumu bekleniyor.
2. Faz2-int'e yeni kod birleşmeden önce tam ci_local gerekmez (69830ad = denetlenen ağaç); sonraki birleşmelerden sonra test-N öncesi tam CI.
3. Kullanıcı test-2 kayıtlarını getirirse: `python tools/kayit_ozet.py kayit-*.json --md build/ozet.md` (not: hazırlık ofseti nit'i — zamanlar seviye başından) → GB-nn, protokol §5 K1-K7 → 2.4 dalga 3 + IS-018 Fable ara değerlendirmesi + 2.3 kapanışı.
4. 2.4 çıkış kriteri: 3 kişi exe açmadan art arda 3 koşu (≥ 2 harita) — test-3 paketiyle; sonra dilim sonu: faz2-int → dev, `dilim-2.3` + `dilim-2.4`, devir.

## Kullanıcıdan bekleyen
- Test-2: `eb5989e` paketini arkadaşlarla oynamak (Tailscale), kayıt dosyaları + gözlemler. Test-3 (`69830ad`) arkadaşlara gönderilmeden önce koordinatöre haber (tam CI).
- KR-034 ilke kararı test-2 sonrası ("araç para verir, sabır/ekip temizlik verir").
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları.
- Fable değerlendirmesine (test-2 sonrası): mahallelinin yalnız örtüsü bozuk oyuncuyu kovalaması (US-043), tezgâh görüşü/tanık sönümü, KR-034 C hedef kalibrasyonu, B kilidi (6 sn), örtü zamanla dönüş (GB-08 B), şişe fırlatma, arka kapıyı dışarıdan çalma.

## Son kapanış
Dilim 2.2 — 2026-10-05: `dilim-2.2` (dev 69c453b).
Dilim 2.1 — 2026-10-04: `dilim-2.1` (dev 2606959).
Faz 1 — 2026-10-02: `faz-1` + `test-1` etiketi (main = cc9c9e1).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
