# Durum (2026-10-12, dilim 2.3 Test-2 açık + dilim 2.4 Akış ve harita: test-2'den bağımsız 7 kalem Bitti; GB-14 kararı bekliyor — DEVİR NOKTASI)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde; tam CI günde bir + test-N öncesi. Model yönlendirme KR-042 (kosucu = Haiku test koşucu; XS kalemler haiku; görsel AC'li Haiku işinde koordinatör kareye bakar). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Pano: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa.

## Aktif faz
Faz 2 — Gizlilik (bakkal). faz2-int **fe56fbc** (dev'e henüz birleşmedi; dilim-2.2 sonrası tüm iş faz2-int'te). **PROTOCOL_VERSION 9.** Paketler: test-2 `build/Insiders-faz2-eb5989e-windows.zip` (protokol 7, arkadaşlarla test-2 için), test-3 `build/Insiders-faz2-fe56fbc-windows.zip` (protokol 9; Başla minibüste, harita seçimi + Başka bakkal, skor tablosu, Kalabalık saat, ısı/tanınma, ürün işaretleri). 7936ad5 paketi kullanılmaz. Faz 2 planı KR-044 (Fable `docs/tasarim/danisma/faz2-yeniden-kesim.md`): 2.4 Akış ve harita → 2.5 Ekip ve iletişim → 2.6 Kapanış + keşif ön testi; cila Havuz'da (KR-043).

## Sürüyor / yarım kalan
Çalışan ajan yok; worktree yalnız `.claude/worktrees/faz2-int`.
- Dilim 2.3 Test-2: kullanıcı arkadaşlarla test-2'yi henüz oynamadı (protokol `docs/tasarim/danisma/test-2-protokol.md`).
- Dilim 2.4 Bitti olanlar: US-049 Başla (denetci PASS), US-050 harita seçimi (denetci PASS), US-051 skor tablosu, US-052 ısı/tanınma (denetci PASS), IS-113 Kalabalık saat, US-046 lite, IS-114 BAŞLA minibüste (GB-13, KR-045 + eki). Kalan (test-2'ye bağlı): store_b kararı (K3), IS-097/IS-092/IS-105 (K1/K4).
- **GB-14 (karar bekliyor, kullanıcı "düzeltme yapma, yeni sohbette" dedi):** hazırlıkta içeride serbestçe takılınıp yanlış hareket cezasız — US-049 tasarımı, kullanıcı bozukluk olarak yaşadı. Seçenekler (a) hazırlıkta dükkân kapısı kilitli, (b) hazırlıkta şüphe işler ama tutma yok, (c) hazırlık yalnız minibüste toplanma. Fable'a danış → kullanıcıya sor → kalem.
- Bugünkü birleşmelerden sonra **tam ci_local koşulmadı** (test-3 arkadaşlarla oynanmadan önce şart, KR-028).

## Yeni sohbette ilk adımlar
1. GB-14: tasarim (Fable) kısa danışma (seçenekler a/b/c, keşif ön testi ve KR-034 ile ilişkisi) → kullanıcıya tek soru → kalem (oynanis/cekirdek; ağ değişirse denetci).
2. Tam `tools/ci_local.sh` (kosucu, Haiku; tek seferde, CPU ağır iş başka yokken) faz2-int üzerinde; kararsızlar YÜK kuralıyla.
3. Kullanıcı test-2 kayıtlarını getirirse: `python tools/kayit_ozet.py kayit-*.json --md build/ozet.md` (not: hazırlık ofseti nit'i — zamanlar seviye başından) → GB-nn, protokol §5 K1-K7 → 2.4 dalga 3 + IS-018 Fable ara değerlendirmesi + 2.3 kapanışı.
4. 2.4 çıkış kriteri: 3 kişi exe açmadan art arda 3 koşu (≥ 2 harita) — test-3 paketiyle; sonra dilim sonu: faz2-int → dev, `dilim-2.3` + `dilim-2.4`, devir.

## Kullanıcıdan bekleyen
- GB-14 kararı (hazırlıkta içeride serbest/cezasız mı? a/b/c) — yeni sohbette Fable danışmasından sonra.
- Test-2: `eb5989e` paketini arkadaşlarla oynamak (Tailscale), kayıt dosyaları + gözlemler. Test-3 (`fe56fbc`) arkadaşlara gönderilmeden önce koordinatöre haber (tam CI).
- KR-034 ilke kararı test-2 sonrası ("araç para verir, sabır/ekip temizlik verir").
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları.
- Fable değerlendirmesine (test-2 sonrası): mahallelinin yalnız örtüsü bozuk oyuncuyu kovalaması (US-043), tezgâh görüşü/tanık sönümü, KR-034 C hedef kalibrasyonu, B kilidi (6 sn), örtü zamanla dönüş (GB-08 B), şişe fırlatma, arka kapıyı dışarıdan çalma.

## Son kapanış
Dilim 2.2 — 2026-10-05: `dilim-2.2` (dev 69c453b).
Dilim 2.1 — 2026-10-04: `dilim-2.1` (dev 2606959).
Faz 1 — 2026-10-02: `faz-1` + `test-1` etiketi (main = cc9c9e1).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
