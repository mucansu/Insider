# Durum (2026-10-04 akşam, dilim 2.1 kapandı — DURMA NOKTASI, sıradaki dilim 2.2 Test-2)

**Kontrol kipi: KR-028 hafif** — denetci yalnız ağ/yetki/kablo kaleminde (hafif), çürütme kapalı, t2 yalnız blocker, nit'ler `docs/surec/nit-havuzu.md`, tam CI günde bir + test-N öncesi. Ajan tanımları/skill'ler İngilizce, raporlar Türkçe (KR-030). Dilim kuralı KR-033 (her dilim sonu durma noktası). Reçeteler `.claude/skills/`, ortak giriş `AGENTS.md`. Kullanıcının durum panosu: https://claude.ai/artifact/8scTa6h86mFhGjxg2txoJa (her geçişte ArtifactData ile güncelle).

## Aktif faz
Faz 2 — Gizlilik (bakkal). **Dilim 2.1 Denge Bitti** (`dilim-2.1`, dev = faz2-int = 2606959; kod faz2-int a01ac86 ile aynı). Sıradaki: **dilim 2.2 Test-2** (backlog §1a: IS-102, IS-017, IS-028, IS-032, IS-092, IS-097, IS-018). PROTOCOL_VERSION 5. Unit ~870 yeşil; **tam ci_local 2026-10-04: import/unit/tools + ağ 86/86** (level_change 150 ms kararsızlığı düzeltildi).
Deneme paketi (test-2 için): `build/Insiders-faz2-a01ac86-windows.zip` (debug, 33,6 MB; duman PASS: host + katılan INSIDERS_READY). Herkes aynı paketi kullanmalı (eski 7a6e233 paketi aynı protokol ama eski denge).

Dilim 2.1'de biten: IS-099 (ayrılan oyuncu "Ayrıldı"), IS-100 (dönüşte kasa kontrolü, sent 7/listen 6, GÖNDER +20), IS-101 (bot takım sırası, bag, +human), IS-081 (sahip olay günlüğü `owner.log[]`, geç yakalanma hatası), IS-103 (kaçış 3 sn geri sayımı "Minibüs kalkıyor"), IS-104 (arka kapı zili), IS-015 (ölçüm: `docs/surec/olcum/`), heist_stats `.gdignore`, bot `wait` adımı, level_change kararlılığı. Kararlar: KR-034 (denge ilkesi test-2 sonrası; geri sayım + zil), KR-035 (bilgi bölünmesi / zorunlu ekip iletişimi tasarım hedefi).

## Sürüyor / yarım kalan
Yok. Çalışan ajan yok; açık ajan worktree'si yok (yalnız `.claude/worktrees/faz2-int`).

## Yeni sohbette ilk adımlar
1. Dilim 2.2 başı mesajı (surec §5b): kalemler + çıkış kriteri ("test-2 oynandı; GB'ler kaleme/KR'ye bağlı; blocker yok"). Paralel başla: **US-045** önce Fable danışması (KR-036 damacana siparişi, istemde arka oda yazmaz; GB-08 örtü yalnız görülünce mi bozulsun) → oynanis + arayuz; ve **IS-102** (cekirdek, XS): `level_started {run}` oturum olayı + `--log-on-exit=<yol>` (otomasyon sayılmayan, tohum/FPS normal; GB-04a tekrarı için) — test-2 paketinden önce; ikisi bitince yeni test-2 paketi (mevcut a01ac86 paketi eski GÖNDER'li).
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
