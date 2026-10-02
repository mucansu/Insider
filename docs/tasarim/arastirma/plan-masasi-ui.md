# Plan masası arayüzü: emsaller, ortak kroki modeli, gamepad, Faz 3 kalemleri (tasarım araştırması, 4. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; sayılar `data/plan_tuning.tres` başlangıç adayıdır, kodsuz keşif testi (`kesif-on-testi.md`) ve Faz 3 oyun testiyle ayarlanır.
Dayanak: GDD v0.4 §4.2 (hafıza kuralı), §5 (plan masası), §6.5 (katmanlar), §12 (plan masası host'ta, son yazan kazanır), §16 soru 2-3-7; KR-004 (kırmızı çizgi: otomatik işleme yok), KR-022/023; `kesif-on-testi.md` §2 (işbirlikli ketleme, "çift iddia"), §6 (E1-E7 eşikleri); `benzer-oyunlar.md` §2b; `yol-haritasi.md` §2; `okunabilirlik-2d.md` (ikon dili); `t2-benzinlik.md` §2 (kroki kaynağı).
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım · **[hesap]** bizim sayılarımızdan türetilmiş.

## 1. Emsaller

| Oyun / sistem | Olgu | Bize ders [görüş] |
|---|---|---|
| Door Kickers 2 [1][2] | Üstten harita; her birime rota çizilir, bakış yönü ve go-kodu atanır; co-op'ta taktik haritaya **çizim** ile plan paylaşılır; hareket halindeyken birimi seçip sürükleyerek rota değişir; 2 kişi ekibi paylaşır. | Rota = oyuncu başına renkli çizgi; go-kodu = rotada "bekle" düğümü, soygunda ping ile serbest. Soygun içinde yeniden çizim yok (Masterplan tuzağı); yalnız ping. |
| Payday 2 ön planlama [3][4] | Harita üstünde satın alınabilir varlıklar (mühimmat, gözetleme noktası, 20 sn alarm gecikmesi, kasa anahtarı); nakit + "iyilik" bütçesi (Bank Heist 8); PD3 oyuncuları geri istiyor. | Gadget ön yerleşimi (GDD §5, MVP sonrası) bütçeli olmalı; MVP'de masada **satın alma yok**, yalnız iddia. Varlık ikonları "hazır bilgi" sayılır → KR-004'e aykırı; bizde varlık ≠ bilgi. |
| GTA Online planlama panosu [5] | Lider roller atar, pay yüzdesi belirler, kurulum masrafını öder; pano apartmanda. | Rol ataması = kroki kenarında kart; pay değişimi MVP dışı (ekonomi-kefalet §2). |
| Rainbow Six Siege hazırlık fazı [6] | Saldıranlar 45 sn boyunca dronla keşif yapar, hedefi ve savunmayı bulur; süre sabit, herkes aynı anda. | Zaman kutulu keşif → planın hammaddesi; bizde keşif 4-8 dk ama **masa** 3 dk yumuşak sayaçla kutulanır (Teardown dersi). |
| Ready or Not tablet [7] | Tab ile tablet; basılı tutunca yakınlaştırma; harita sekmesi oda düzeni + mobilya. | Soygunda plan katmanı "tablet" değil yarı saydam dünya katmanı (GDD §5); ama **basılı tut = büyüt** kalıbı plan katmanını geçici öne almak için uygun (ek ekran yok). |
| Shadows of Doubt mantar pano [8] | Kanıt iğnelenir, iple bağlanır, not yazılır; bariz bağlantıları oyun çizer, çıkarımı oyuncu yapar; bazı şeyler hafızada kalır. | Üç araç yeter: ikon, çizgi, not. Otomasyon sınırı: yapı hazır, güvenlik asla. |
| Invisible, Inc. [9] | Tam bilgi, sıra tabanlı; plan oyunun kendisi. | Bizim tersimiz: bilgi eksik, plan iddia. Alarm merdiveni HUD'da sabit (benzer-oyunlar). |
| Excalidraw eşzamanlı düzenleme [10][11] | Öğe dizisi tam yayınlanır; her öğede `version` (artar) + `versionNonce` (rastgele; eşitlikte düşük kazanır); silme = `isDeleted` mezar taşı; birleşim = iki kümenin birliği; CRDT'siz, merkezi koordinasyon yok. Genel desen: konumda son yazan kazanır. | Bizde host zaten yetkili (GDD §12): öğe listesi + sürüm; istemci "op" gönderir, host sıralar, 10 Hz delta yayar. "Son yazan kazanır" **öğe başına**, tüm masa değil; silme mezar taşı → geri alma bedava. |
| Keep Talking (kesif-on-testi §2) | Asimetri + konuşma; 30-45 sn **sessiz bireysel** aşama işbirlikli ketlemeyi azaltır (psikoloji). | Masa iki aşamalı olabilir: bireysel katman → ortak katman (E1 eşiğine göre). |

## 2. Masa tasarımı (öneri)

**Ekran düzeni (1280×720, tek sahne):** ortada kroki (hazır duvar + kapı boşluğu çizgileri, `UNKNOWN` tonunda; GDD §6.5 bilinmeyen katmanıyla aynı çizim — soygunda "kroki" ile "sis" aynı dilde) · solda **palet** (dikey, ≤ 10 ikon) · sağda **kartlar** (oyuncu başına: ad/atkı rengi, giriş noktası, rol etiketi, hazır durumu; altta kaçış noktası) · altta durum şeridi (yumuşak sayaç, "masayı kapat" host düğmesi, fotoğraf kareleri Faz 4+). Fare: sol tık yerleştir/seç, sürükle taşı, sağ tık sil, tekerlek yakınlaştır (1-2×), orta tuş kaydır. Herkes aynı anda, imleçler atkı renginde (10 Hz, güvenilmez kanal).

**Üç araç:**
1. **İKON** (iddia): kamera sabit · kamera dönen · gözlemci (sahip/görevli/bekçi) · kasa · DVR · alarm düğmesi · kapı (kilitli/açık) · sivil yoğunluğu · "?" (emin değilim, ikon köşesine işaret) · zaman notu. Kart taşıyan, sensör T4+ ile gelir. Karo merkezine kenetlenir (32 px); sahibinin rengi çerçeve; yönlü ikonlar (kamera, gözlemci) döndürülebilir (8 yön).
2. **ÇİZGİ**: rota (oyuncu rengi, 4 px, en fazla 24 düğüm, karo kenetli), devriye rotası (gri kesikli, iddia), "bekle" düğümü (go-kodu: içi boş halka).
3. **NOT**: zaman notu = ikon + ön tanımlı metin ("kurye", "vardiya", "dönüş", "sigara", "devriye", "tur") + sayı (sn ya da saat; gamepad için ±5 sn çark); serbest metin ≤ 24 karakter (klavye varsa).

**"Çift iddia" kuralı (kesif-on-testi E2):** aynı karoya (ya da komşu karoya) iki farklı ikon konursa ikisi de **yarım boy yan yana** kalır, oyun seçtirmez, uyarı vermez; soygunda plan katmanı ikisini de çizer. Aynı ikon aynı karoya ikinci kez: tek ikon, iki renk çerçeve (iki kişi aynı şeyi hatırladı = güven işareti; ölçülür: "çift onaylı ikon doğruluğu" iş sonu özetinde). Silme: herkes her ikonu silebilir (arkadaş oyunu), silinen ikon 5 sn hayalet kalır ve sahibi geri alabilir (Ctrl+Z / gamepad LB: **yalnız kendi** eylemlerini geri alır, GDD §5).

**Ortak gerçek zamanlı model (host yetkili, GDD §12):** `PlanElement {id, type, cell, dir, owner, version, nonce, deleted, text, points[]}`; istemci op gönderir (`add/move/rotate/delete/text`, güvenilir kanal), host uygular (öğe başına son yazan kazanır; eşitlikte düşük nonce — Excalidraw kuralı), **10 Hz delta** yayar; rota çizimi sürerken noktalar 10 Hz güvenilmez kanalda "taslak" (başkaları soluk görür), bırakınca güvenilir "kesin". 150 ms'de iki kişinin aynı ikonu taşıması: ikisi de kendi sürüklemesini anında görür, bırakınca host sırası kazanır, kaybeden ikon 0,15 sn'de hedefe kayar ("pop" yok). Geç katılan tam listeyi alır. Plan JSON'u koşu kaydına yazılır (plan doğruluğu ölçümü §3).

**Kararlar (GDD §5):** giriş noktası = oyuncu kartını kroki üstündeki giriş işaretine (F/B/W…) sürükle (oyuncu başına ayrı); rol etiketi Faz 3'te yalnız isim (Ghost/Tech/Muscle; loadout Faz 4); kaçış = tek işaret (E/Y) ekip ortak; insider anlaşması Faz 4 (iş panosunda). Gadget ön yerleşimi ve tetik zinciri yok; go-kodu var (ucuz tetik).

**Hazır ve süre:** masa zamansız (GDD) ama **yumuşak sayaç 3:00** görünür; 2:00'de "1 dakika" ses; aşımda aracı plan bonusu her 30 sn −%1 (en fazla −%5; benzer-oyunlar §2b); host "+2 dk" bir kez. Herkes hazır → 5 sn geri sayım → soygun; host "masayı kapat" ile zorlar. Ölçüm D3.2: medyan masa süresi ve bonus alma oranı.

**Sessiz bireysel aşama (opsiyonel, host kuralı; kesif-on-testi E1 sonucuna göre varsayılan):** ilk 30-45 sn herkes **kendi** katmanına çizer (başkalarınınki görünmez), süre bitince katmanlar birleşir (çift iddia kuralı devreye girer) ve konuşarak düzenleme başlar. Masa süresine dahil.

**Plan bonusu kontrol listesi (GDD §5 +%5-10):** ≥ 1 rota · her oyuncunun giriş noktası · ≥ 3 ikon · ≥ 1 zaman notu · kaçış işareti → +%5; soygunda rota düğümlerinin ≥ %60'ından geçildiyse +%5 daha (host ölçer; "plan tutturuldu"). Yanlış ikon ceza **değildir**; doğruluk yalnız iş sonunda (GDD §16 soru 3 → D3.1 A/B; soru 7 → ikon solmaz).

**Soygunda plan katmanı:** ikon/rota yarı saydam (α 0,45, atkı rengi), `UNKNOWN` sisin üstünde, görünen katmanda nesneyle çakışsa da **solmaz**; "bekle" düğümü: oraya varan oyuncuda küçük halka titrer, herhangi bir ekip arkadaşının pingi (Faz 2 ping, S-HUD) halkayı "git"e çevirir (go-kodu); Tab/Y basılı = plan katmanı tam opak + yakınlaştırma (Ready or Not). Keşif-soygun değişimi (GDD §4.6) plan katmanına dokunmaz.

## 3. Gamepad ile kullanılabilirlik

| Girdi | Masa | Not [görüş] |
|---|---|---|
| Sol çubuk | İmleç 600 px/sn, 0,25 sn ivme, ölü bölge 0,2; **karo kenetleme** (imleç karo merkezine çekilir) + var olan ikona 12 px manyetik yakalama | Hassas çizim gerekmiyor; karo ızgarası fareyle eşit koşul sağlar |
| Sağ çubuk | Kroki kaydır; RT/LT yakınlaştır (1-2×) | Benzinlik 40×25 karo = 1280×800 px, 720p'de kaydırma gerekir |
| A / B | Yerleştir-seç-sürükle / iptal-sil | Basılı tut A = sürükle; B basılı 0,5 sn = sil |
| X | Palet radyal menüsü (8 dilim + "daha" dilimi; sol çubukla seç, bırakınca yerleşir) | 10 ikon → 8 + 2 ikinci sayfa; en sık 8 öne |
| Y | Not çarkı (ön tanımlı metin → sayı ±5 sn) | Klavyesiz zaman notu 3 saniyede yazılır |
| LB / RB | Geri al (kendi) / ikon döndür (45°) | |
| D-pad | Kart sekmeleri (giriş, rol, kaçış); yukarı = "hazır" | |
| Start | Host: masayı kapat / +2 dk | |

Kabul: gamepad ile 5 ikon + 1 rota + 1 zaman notu ≤ 60 sn (fareyle ≤ 40 sn); bakış şüphesi ve diğer oyun eylemleri masada yok. UI girdi haritası S5'e (`plan_place`, `plan_delete`, `plan_palette`, `plan_note`, `plan_undo`, `plan_rotate`, `plan_ready`) US-011d kalıbıyla.

## 4. Ölçüm (headless + oyun testi)

- **Plan doğruluğu** (seviye cevap anahtarı = tohumun güvenlik yerleşimi): ikon doğru tür + doğru oda = 1, doğru tür yanlış oda = 0,5, hayalet −0,5; zaman notu ±10 sn = 1 (kesif-on-testi §5 ile aynı puanlama); "?" işaretli ikonların doğruluk oranı ayrı. İş sonu özetinde gösterilip gösterilmeyeceği D3.1 A/B; ölçüm her halükârda koşu JSON'unda.
- **Masa davranışı:** süre, geri alma sayısı, çift iddia sayısı ve çözümü (silindi / kaldı), kim kaç ikon koydu, sessiz aşama varsa bireysel-ortak doğruluk farkı (E1/E2), en uzun sessizlik (Discord kaydı, gözlemci).
- **Faz 3 çıkış kriteri bağı (backlog EP-03):** keşif → plan → soygun → kaçış ≤ 15 dk (masa ≤ 4 dk) · ikon doğruluğu ölçülüyor · ≥ 2/3 "keşif değdi".

## 5. Faz 3 kalem taslakları (AC'li; sahipler öneri)

**US-P1 — Plan verisi ve senkron** (cekirdek; yeni sözleşme S12 "PlanModel"; bağımlılık: US-001/IS-013). AC1 `core/plan_model.gd`: `PlanElement` şeması, op türleri, öğe başına sürüm/nonce, mezar taşı silme, geri alma = sahibinin son 10 op'unun tersi. AC2 Host yetkili: op kuyruğu, 10 Hz delta, geç katılana tam liste; taslak rota noktaları güvenilmez kanal. AC3 Senaryo `plan_sync.json` (0/150 ms, 3 peer): 60 sn'de 120 op (ekle/taşı/sil/metin, ikisi aynı öğeye eşzamanlı) → üç peer'da birebir aynı liste; çakışmada kaybeden istemcinin düzeltme kayması ≤ 0,2 sn; bant genişliği ≤ 2 KB/sn/peer. AC4 Plan JSON'u koşu kaydına; `test_plan_model` birim: LWW/nonce belirlenimciliği, geri alma yalnız sahibinin.

**US-P2 — Masa arayüzü** (arayuz; S5/S9; bağımlılık: US-P1, US-P4). AC1 Kroki + palet + kartlar + durum şeridi tek sahne; tema token'ları ve i18n anahtarları (sabit metin 0). AC2 Üç araç (§2) fare ve gamepad (§3 tablosu); karo kenetleme; ikon ≥ 24 px; oyuncu rengi çerçeve; "?" köşe işareti; çift iddia yarım boy; silme hayaleti 5 sn. AC3 Yumuşak sayaç 3:00 / +2 dk / "masayı kapat" / hazır → 5 sn; sessiz bireysel aşama host kuralı (varsayılan açık 30 sn, lobide ayar). AC4 Headless ekran görüntüsünde (IS-022) 3 oyuncunun 6 ikon + 2 rota + 1 çift iddia tek karede ayırt edilir. AC5 Gamepad kabulü: 5 ikon + 1 rota + 1 not ≤ 60 sn (bot girdisi).

**US-P3 — Soygunda plan katmanı + go-kodu** (arayuz + oynanis; bağımlılık: US-P1, US-011a/c). AC1 Katman α 0,45, sisin üstünde, solmaz; Tab/Y basılı = opak + yakınlaştırma. AC2 "Bekle" düğümü: varan oyuncuda halka; herhangi bir ekip arkadaşının pingi → "git"; host `plan_node_reached(peer, node)` olayı. AC3 Plan tutturma ölçümü (rota düğümlerinin %60'ı) ve kontrol listesi → `Economy` bonus girdisi (Faz 4'te ödenir; Faz 3'te yalnız iş sonu metni). AC4 Senaryo: 150 ms'de ping → halka değişimi ≤ RTT + 100 ms.

**US-P4 — Kroki üretimi ve cevap anahtarı** (seviye; S4). AC1 `build_levels.gd` düzenden **kroki** üretir: yalnız duvar ve kapı boşluğu çizgileri (`UNKNOWN` tonu), oda bölgeleri (puanlama için "oda" kimliği), giriş/kaçış işaretleri. AC2 Tohumlu güvenlik yerleşimi (`cam_fake_index`, DVR odası, görevli ajandası, devriye periyodu) → `answer_key.json` (tür, oda, zaman); plan doğruluğu bu anahtara göre puanlanır. AC3 Bakkal ve benzinlik (Faz 4'te) için üretim deterministik; `test_levels` kroki-düzen tutarlılığını denetler (duvar sayısı, kapı boşlukları).

**US-P5 — Plan doğruluğu ve iş sonu özeti** (oynanis + arayuz; bağımlılık: US-P4, US-012 iş sonu). AC1 Puanlama (§4) host'ta, koşu JSON'una; AC2 İş sonu "plan doğruluğu" paneli **host ayarıyla** açılır/kapanır (D3.1 A/B); "çift onaylı ikon doğruluğu" ayrı satır; AC3 Birim: 6 örnek plan → beklenen puanlar.

**IS-P6 — Faz 3 oyun testi protokolü** (tasarim; dosya `docs/tasarim/degerlendirmeler/`). Kodsuz keşif testi (E1-E7) sonuçlarına göre varsayılanlar (sessiz aşama, sayaç, doğruluk gösterimi) kesinleşir; Faz 3 testinde D3.0/D3.1/D3.2 ölçümleri, anket (kesif-on-testi §5), gözlem listesi.

## 6. Riskler ve karar gereken

Riskler: masa arayüzü oyunun kendisi olursa (Masterplan tuzağı) → üç araç tavanı, satın alma yok · "son yazan kazanır" sinir bozar → öğe başına, 0,15 sn kayma, hayalet geri alma · gamepad imleci yavaş hissedilir → ivme/kenetleme ayarı veriden · sessiz aşama tartışmayı soğutur → host kuralı, E1'e göre varsayılan · kroki sis diliyle aynı olmazsa "iki harita" hissi → US-P4 `UNKNOWN` token'ı paylaşır.
Karar gereken: (a) Sessiz bireysel aşama varsayılan açık mı (öneri: kodsuz test E1 geçmezse açık, geçerse kapalı)? (b) Herkes her ikonu silebilsin mi (öneri evet, hayaletle) yoksa yalnız sahibi mi? (c) Yumuşak sayaç cezası aracı bonusundan (öneri) mı, hiç ceza yok yalnız ses mi? (d) Plan doğruluğu iş sonunda gösterilsin mi — D3.1 A/B'ye bırakılsın (öneri) yoksa GDD'de şimdi kesinleşsin mi?

## Kaynaklar
[1] Door Kickers 2 inceleme (rota çizimi, co-op çizim) — https://boilingsteam.com/door-kickers-2-review/ · https://www.jumpdashroll.com/article/door-kickers-2-task-force-north-review
[2] Door Kickers 2 co-op duyurusu — https://www.co-optimus.com/article/16662/door-kickers-2-task-force-north-hits-early-access.html
[3] Payday 2 ön planlama (Big Bank) — https://pcinvasion.com/?p=80446 · https://payday.fandom.com/wiki/Bank_Heist
[4] Payday 3 "ön planlamayı geri getirin" — https://payday3.featureupvote.com/suggestions/495103/bring-back-preplanning
[5] GTA Online heist panosu — https://www.sportskeeda.com/gta/how-heists-gta-5
[6] Rainbow Six Siege hazırlık fazı (45 sn dron) — https://guildorder.com/games/r6/wiki/drones-and-intel · https://rainbowsix.fandom.com/wiki/Drone
[7] Ready or Not tablet — https://xboxplay.games/ready-or-not/how-to-use-tablet-in-ready-or-not-48556
[8] Shadows of Doubt mantar pano devblog — https://colepowered.com/?p=33958
[9] Invisible, Inc. tasarım — https://80.lv/articles/invisible-inc-interview/
[10] Excalidraw P2P işbirliği (version/versionNonce, mezar taşı) — https://plus.excalidraw.com/blog/building-excalidraw-p2p-collaboration-feature
[11] Eşzamanlı beyaz tahta tasarımı (LWW, çakışma çözümü) — https://techinterview.org/system-design-collaborative-whiteboard/ · https://development.liveblocks.io/docs/guides/how-conflict-resolution-works-in-liveblocks-sync.md
