# Durum (2026-10-04 20:50, dilim 2.2 Hazırlık sürüyor)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Dilim kuralı KR-033 (her dilim sonu durma noktası). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal). **Dilim 2.2 Hazırlık sürüyor** (2026-10-04 20:50 başladı). Önceki: **Dilim 2.1 Denge Bitti** (`dilim-2.1`, dev = faz2-int = 2606959; kod faz2-int a01ac86 ile aynı). Dilim 2.2 kalemleri: IS-102, US-045, IS-106, IS-107 + yeni test-2 paketi (backlog §1a); sonra 2.3 Test-2. PROTOCOL_VERSION 5. Unit ~870 yeşil; **tam ci_local 2026-10-04: import/unit/tools + ağ 86/86** (level_change 150 ms kararsızlığı düzeltildi).
Deneme paketi (test-2 için): `build/Insiders-faz2-a01ac86-windows.zip` (debug, 33,6 MB; duman PASS: host + katılan INSIDERS_READY). Herkes aynı paketi kullanmalı (eski 7a6e233 paketi aynı protokol ama eski denge).

Dilim 2.1'de biten: IS-099 (ayrılan oyuncu "Ayrıldı"), IS-100 (dönüşte kasa kontrolü, sent 7/listen 6, GÖNDER +20), IS-101 (bot takım sırası, bag, +human), IS-081 (sahip olay günlüğü `owner.log[]`, geç yakalanma hatası), IS-103 (kaçış 3 sn geri sayımı "Minibüs kalkıyor"), IS-104 (arka kapı zili), IS-015 (ölçüm: `docs/surec/olcum/`), heist_stats `.gdignore`, bot `wait` adımı, level_change kararlılığı. Kararlar: KR-034 (denge ilkesi test-2 sonrası; geri sayım + zil), KR-035 (bilgi bölünmesi / zorunlu ekip iletişimi tasarım hedefi).

## Sürüyor / yarım kalan
- **US-045** — Fable danışması bitti → KR-038 (rapor `docs/tasarim/danisma/us-045-store-b.md`). Uygulama oynanis'e IS-106 birleşince (ürünler, damacana, örtü A, metinler; ShopItem1/2 işaretleri store_a'ya).
- **IS-107** — seviye, ajan worktree'si, aşama 1 (store_b.txt/.tscn + props + kısa net senaryosu + ekran görüntüsü). Aşama 2 (store_b ayar ezmeleri + bot/heist_stats) IS-106 sonrası.
- **IS-102** — cekirdek, ajan worktree'si (`level_started {run}` + restart'ta olay geçmişi korunur + `--log-on-exit`).
- **IS-106** — oynanis, ajan worktree'si (denetim tablosu, harita başına alan bazlı ayar ezme, bot işaret tabanlı, store_a ayna fikstürüyle kanıt).
- Sırada: US-045 uygulama, IS-107 aşama 2, sonra yeni test-2 paketi (tam ci_local + duman).

## Yeni sohbette ilk adımlar
1. Sürüyor listesindeki ajan raporlarını al (kalem-kapat), sıradakileri başlat.
2. Kullanıcı test-2'yi oynarsa geri bildirimleri `GB-nn` olarak `docs/surec/geri-bildirim.md`'ye yaz; KR-034 ilke kararı (fark edildiği an = shouted; IS-105 kasa sesi → kasaya bak) ve denge hedeflerinin yeniden yazımı test-2 gözlemiyle (Fable).
3. Test-2 gözlem formuna satır (Fable): oyuncular vuruş-kaç mı yapıyor, pencere mi bekliyor; geri sayım ve arka kapı zili okunuyor mu.
4. Nit havuzundan dokunulan dosyalarınkiler (IS-095 near kalıbı uyarısı, IS-104 discovery_cash payı).

## Kullanıcıdan bekleyen
- Test-2: paketi arkadaşlarla paylaşmak + Tailscale kurulumu/daveti; gözlemler.
- KR-034 ilke kararı test-2 sonrası ("araç para verir, sabır/ekip temizlik verir").
- Bekleyen KR: KR-013 ad (öneri Mapless), KR-014 Steamworks (sona), KR-024 AI ses hesabı, KR-025 Türkçe ses satırları.
- Fable değerlendirmesine (test-2 sonrası): mahallelinin yalnız örtüsü bozuk oyuncuyu kovalaması (US-043), tezgâh görüşü/tanık sönümü, KR-034 C hedef kalibrasyonu, B kilidi (6 sn).

## Son kapanış
Dilim 2.1 — 2026-10-04: `dilim-2.1` (dev 2606959).
Faz 1 — 2026-10-02: `faz-1` + `test-1` etiketi (main = cc9c9e1).
Faz 0 — 2026-10-01: IS-001..IS-004 Bitti.
