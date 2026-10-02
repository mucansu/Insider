# Oyun hissi (game feel / "juice") tasarımı: ilkeler, olay tablosu, yerel tahmin, kamera dili (tasarım araştırması, 4. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil (kullanıcı isteği: oynanış güzelliği ve rahatlık). Oyun oynanmadı; tüm değerler başlangıç değeridir, `data/` altında kalır ve test-2'de ayarlanır.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım. Dayanak: GDD §6 (algı, eşikler "?" 30 / "!" 100, tepki penceresi ≥ 0,5 sn), §6.5 (görüş kipleri, hayalet, kenar oku, "görüldü" ikonu), §9.3 (sahip zinciri, tutma 6 sn / ÇEK 1 sn, çanta, kaçış, klip anları), §12 (host yetkili; istemci kendi hareketinde yetkili; "tut" ilerlemesi yerelde, host onaylar, iptalde ceza yok), §14.1 (kukla ilkeleri, kural 2: işaretler sabit bağlantı noktasında ≥ 22 px; kural 5: hareket azaltma); okunabilirlik-2d §2 (iki kanal, tek uyarı vurgusu), ses-ve-sfx §1 (ses ve görsel aynı sinyalden), oyun-testi-ve-klip §1 (görünür neden + görünür sonuç + 2 sn gecikme); faz-1.md S2/S5 (kasa sonucu geç, yerel oyuncu vurgusu; ON-02/06); mevcut uygulama: US-014 kukla (sekme, eğilme, toz, balon, sıçrama), US-009 halka, US-013 merdiven + iş sonu, IS-027 zoom 1,5 + kenetleme, 150 ms ağ.

## 1. İlkeler: gizlilik oyununda juice'un ölçüsü

Emsaller [olgu]: Vlambeer "Juice it or lose it" / "Art of Screenshake" (sarsıntı, ezilme-esneme, parçacık, ses katmanı; hepsi aksiyon oyunu ölçeğinde) · Swink "Game Feel": his = gerçek zamanlı kontrol (girdi → tepki ≤ 100 ms) + simüle uzay (çarpışma, ağırlık) + cila (animasyon, ses, kamera); cila mantığı değiştirmez · Mark of the Ninja: her efekt bir bilgi (halka = yarıçap) · Hades: hitstop/sarsıntı yoğun ama her vuruş okunur · Overcooked: kaosta bile her nesne durumu bir bakışta · Lethal Company / R.E.P.O.: komedi fiziksel beceriksizlikten ve geç gelen sonuçtan.

[görüş] Kurallar:
1. **Her efekt bir soruyu cevaplar.** "Oldu mu?", "gördü mü?", "nerede?", "kim?". Cevap vermeyen efekt çıkar. Gizlilikte juice vuruş değil **onay**dır.
2. **Vlambeer ×0,3.** Sarsıntı tavanı 3 px / 0,2 sn (1280×720'de), zoom darbesi ≤ %8, tam ekran flash yok, hitstop yok (çok oyunculu: mantık ve ağ hiç durmaz; yalnız kukla 60-80 ms "mikro-donma" yapar). Noir: koyu dünya sakin kalır, hareket karakterde ve işaretlerde.
3. **Gerilim sessizlikten, abartı tek vuruştan.** Uyarı 0-1'de dünya küçük hareketlerle nefes alır (sahip raf düzeltir, zil, buzdolabı); 2-3'te (bağırış, mahalleli, polis) sahne başına **tek** büyük vuruş: bağırışta sarsıntı, yakalanmada stinger + donma, polis gelişinde vinyet. İki büyük vuruş üst üste binmez (0,5 sn kilidi).
4. **Üç kanal, tek sinyal.** Oyun bilgisi taşıyan olay görsel + ses (+ HUD) üretir, hepsi aynı sinyalden (NoiseBus halkası, NPC durum sinyali, S7 etkileşim sinyali, S3 kademe). Biri olmadan diğeri yok; hiçbir bilgi yalnız sesle ya da yalnız renkle değil.
5. **Yerel oyuncu merkezde.** Yerel oyuncunun olayları tam şiddet; ekip arkadaşının olayları ×0,5 görsel (sarsıntı yok, ses mesafeyle); NPC olayları yalnız görüş hattında (sis kuralı). Ekran kalabalığı sınırı: aynı anda ≤ 4 halka, ≤ 3 parçacık sistemi, ≤ 2 balon pop.
6. **Niyet anında, sonuç onayla.** Tuşa basınca ≤ 1 kare görsel tepki (kukla, istem, çubuk); dünya durumu (nakit, kapı, çanta sahipliği, tutuldu) yalnız host'tan. Red "ceza" gibi görünmez: ALERT değil MUTED gri sönme, ses kısık tık (GDD §12).
7. **Hareket azaltma = ayrı efekt seti, eksik oyun değil.** Kapanan: sarsıntı, zoom darbesi, look-ahead ×0,5, balon pop (anında görünür), halka genişlemesi, toz, sekme/eğilme. Kalan: renk/ikon/çubuk/ses/vinyet. Hiçbir bilgi kaybolmaz.
8. **Kukla ağa bakmaz.** Uzak kopya ara değerlenmiş durumdan aynı animasyonu üretir; tampon sıfırlanınca "pop" yok (§14.1 kural 6). Hiçbir efekt kök konumu oynatmaz (kural 3: aşma ≤ 6 px).

## 2. Olay tablosu

Sütunlar: görsel (kukla / parçacık / ekran) · kamera (sarsıntı px / süre; zoom; hepsi hareket azaltmayla kapanır) · ses (IS-024 katalog anahtarı; yoksa eklenir, ses-ve-sfx §2 kaynakları) · HUD · süre/şiddet · **Y** = yerel tahmin: **A** anında istemcide, **O** host onayıyla, **A→O** niyet anında, sonuç onayla (§3).

| Olay | Görsel | Kamera | Ses | HUD | Süre / şiddet | Y |
|---|---|---|---|---|---|---|
| Yürüme ↔ koşu ↔ sızma geçişi | Kukla kip silueti (§14.1: ölçek 0,84/1,00/1,07, eğilme); koşuya geçişte 1 kare çökme + ilk adımda 3 toz parçacığı; sızmaya geçişte 0,12 sn çömelme | Look-ahead hedefi değişir (§4); sarsıntı yok | koşu: `sfx_run_step` her 0,35 sn (halka 120 px, S8); sızma/yürüme sessiz | kip ikonu yok (siluet yeter); yönlü kipte rozet değişmez | geçiş 0,10-0,16 sn mantık, kukla 0,23-0,30 | A |
| Kapı aç | Kukla eli uzanır (0,08 sn) + kapı 15° ön-aralanma anında; tam açılış host'tan 0,15 sn easeOut; halka 160 px | — | `sfx_door_open` (halka ile aynı olay) | istem "[E] Aç" → kaybolur | 0,25 sn toplam | A→O |
| Kapı kapa / birinin üstüne | Aynı; kapanışta 1 kare "tok" ezilme kapı çizgisinde; engelliyse (`blocked`) kapı 0,15 sn geri yaylanır | — | `sfx_door_close` / engelde kısık `sfx_ui_deny` | engelde istem gri 0,4 sn | 0,25 / 0,4 | A→O |
| Kapı kilitli (T1 kilit, 6 sn tut) | Kapı tokmağında 2 kare "sarsılma" (±2 px) ilk basışta; maymuncukta kukla eğilir, el kapıda; her 1 sn küçük tıkırtı kıvılcımı yok (noir) — yalnız ses | — | `sfx_door_locked` (ilk basış) · `sfx_lockpick_loop` · açılınca `sfx_lockpick_click` | çubuk 6 sn; "Kilitli" etiketi | 6 sn | A (çubuk) → O (açıldı) |
| Kasa tut (başla) | Kukla tezgâha eğilir (ölçek 0,95), eller çekmecede; kasa üstünde 22 px etkileşim halkası ALERT değil FG | — | `sfx_register_loop` (döngü, 90 px halka yalnız tamamlandığında) | çubuk 3 sn, etiket "Kasayı boşalt" | 3 sn | A |
| Kasa ilerleme / yerel dolum (ON-02 aşama 1) | Çubuk dolunca **yeşile** (CASH) döner, kukla 1 kare doğrulur, çekmece 4 px dışarı | — | `sfx_register_done` (klik) | çubuk yeşil, "…" (onay bekleniyor, yazısız) | 0 → host onayına kadar (≤ 1 sn) | A |
| Kasa boşaldı (ON-02 aşama 2, host) | Kasa görseli "boş" (çekmece açık, iç MUTED); 3-5 banknot parçacığı kuklaya uçar (0,4 sn); ekip arkadaşında ×0,5 | yok | `sfx_cash_count` (0,4 sn tıkırtı) | nakit sayaç 0,4 sn'de sayarak artar + flash (mevcut CASH_FLASH) | 0,4 sn | O |
| Kasa reddi / onay gelmedi (1 sn) | Çubuk gri sönüm 0,3 sn; kukla doğrulur; kasa değişmez | — | kısık `sfx_ui_deny` | "İptal" MUTED (mevcut) | 0,3 sn | O |
| Çanta al (2 sn tut) | Kukla eğilir; dolunca çanta ikonu kuklanın sırtında (siluet değişir: hafif kambur, koşu eğilmesi ×1,2) | — | `sfx_bag_take` (fermuar) | çubuk; oyuncu listesinde çanta ikonu (FG) | 2 sn + 0,2 | A (çubuk) → O (çanta) |
| Çantayla koşuya geçiş (uyarı) | Çanta 0,3 sn sallanır (verlet genliği ×2) — "düşebilir" ipucu; düşme host kararı (%50) | — | `sfx_bag_rattle` | — | 0,3 sn | A |
| Çanta düşür (host) | Çanta yere kayar 0,25 sn, 1 kare ezilme; halka 160 px; kukla 1 kare "ah" (eller açık) | yerel taşıyıcıda 1 px / 0,1 sn; başkasında yok | `sfx_bag_drop` (halka ile aynı) | listede çanta ikonu düşer | 0,3 sn | O |
| Çanta devret (0,3 sn el sıkışma) | İki kuklanın elleri birbirine uzanır (A, niyet); 0,3 sn sonra çanta sırt değiştirir (O); el sıkışma kilidi görünür: iki kukla arasında 2 px çizgi | — | `sfx_bag_handoff` | iki listede ikon yer değiştirir | 0,3 sn | A→O |
| Sahip "?" (şüphe 30) | Sahip kuklası durur, baş oyuncuya döner, "?" easeOutBack pop 0,2 sn (24 px, FG); baktığı noktaya 12 px nokta + ince çizgi (okunabilirlik-2d §4) | yok | `vo_clerk_question` ("Hı?") 160 px | hedef oyuncuda "görüldü" rozeti FG→ALERT | pop 0,2, balon ≥ 0,5 sn | ON-04: istemcide eşikten (15 Hz çoğaltma) |
| Sahip SORGU (60) | Sahip yürür (110 px/sn), 64 px'te durur, "Ne yapıyorsun orada?" balonu; hedef oyuncu kuklası 1 kare donar (eller kalkar); diğer oyunculara balon ×0,5 | **hedef oyuncuda** zoom +%5, 0,25 sn in / 0,6 sn out | `vo_clerk_interrogate` | merdiven 1 pop | 3 sn bekleme | O (balon metni host) |
| Sahip "!" + bağırış (100) | "!" 28 px ALERT 0,4 sn titreme; sahip kuklası sıçrar (260 px/sn, §14.1), kolları yukarı; halka 320 px kesikli; oyuncu kuklaları 320 px içinde "ürkme" (0,08 sn ölçek 1,1) | 320 px içindeki her oyuncuda 2 px / 0,15 sn × (1 − mesafe/320) | `vo_clerk_shout` + halka; müzik (Faz 4) kesilmez, nabız katmanı | merdiven 2 pop + `sfx_alert_up` | 0,4 sn | O |
| Mahalleli çıktı | `NeighbourSpawn`'da 0,3 sn "kapı açıldı" ışık dikdörtgeni (FG α 0,2) + terlikli kukla; ekran dışıysa kenarda ALERT ok 2 sn (ekip okunun ALERT hali) | yok | `sfx_bell` + `sfx_neighbor_steps` (120 px; duvar arkasından duyulur, görülmez) | merdiven 3 pop (ilk mahalleli içeri girince) + sayaç 60 başlar | 2 sn | O |
| Tutuldun (sahip, 6 sn pencere) | Kukla donar, sahibin eli omzunda (iki kukla 28 px'te bağlı çizim); kukla 60 ms mikro-donma; 6 sn boyunca kuklanın üstünde geri sayım yayı (ALERT, 26 px) | zoom +%5 0,25 sn; sarsıntı 3 px / 0,2 sn (yalnız tutulan) | `sfx_held_grab` + kısa stinger 0,3 sn | HUD "TUTULDUN — [E] ÇEK (arkadaş)" ALERT; ekip arkadaşında ok ALERT | 6 sn | O (ON-03 ileri tahminli) |
| ÇEK ile kurtarıldın | 1 sn çekişme: iki kukla karşı yöne eğilir; dolunca ikisi 1 kare geri sıçrar, sahip 2 sn sendeler (yalpalama animasyonu); toz 3 parçacık | kurtarılan + kurtaran: 2 px / 0,12 sn | `sfx_pull_free` | ALERT yazı kaybolur; kurtarana "görüldü" rozeti ALERT | 1 sn + 0,3 | A (çubuk) → O |
| Yakalandın (mahalleli, kalıcı) | Kukla oturur (siluet alçalır, baş öne), mahalleli yanında; MUTED'a solar 0,5 sn; vinyet ALERT α 0,12 0,3 sn | sarsıntı 3 px / 0,2 sn; zoom +%8 0,25 sn, geri 1,0 sn | `sfx_captured_stinger` 0,6 sn; müzik kesme ≤ 0,3 sn | listede kelepçe ikonu; "YAKALANDI" toast | 0,6 sn | O |
| Polis sayacı (uyarı 3, 60 sn) | — (dünyada görsel yok) | yok | son 10 sn `sfx_timer_tick` her sn; son 3 sn çift tik | sayaç yalnız 3'te, ALERT; son 10 sn 0,5 Hz pulse | 60 sn | O |
| Kaçış bölgesine giriş | Bölge çizgisi 0,2 sn FG parlar; giren kuklanın üstünde 16 px onay işareti (CASH) 1 sn | yok | `sfx_escape_in` (kısa olumlu) | listede CASH ok ikonu; "Kaçtı: 2/3" sayacı | 1 sn | A (çizgi) → O (sayaç) |
| İş bitti — kazanç | 0,5 sn dünyada hiçbir şey (sessizlik), sonra iş sonu ekranı 0,3 sn fade; nakit sayaç sayarak | yok | `sfx_result_win` (kısa jingle) | US-013 ekranı | 0,8 sn | O |
| İş bitti — kayıp | 0,8 sn dünya görünür kalır (komik sonucu izlet: mahalleli, oturan kuklalar), sonra ekran | yok | `sfx_result_loss` | başlık ALERT, kalan FG | 1,1 sn | O |
| Ekip arkadaşı görüldü (şüphe ≥ 30) | Üstünde 16 px göz ikonu ALERT (US-011c), 0,2 sn pop; ekran dışındaysa kenar oku ALERT | yok | kısık `sfx_mate_seen` (yalnız ilk kez, 10 sn kilit) | — | sürdüğü kadar | O (10 Hz özet) |
| Ping / işaret (yeni, §5 #6) | Dünyada 3 sn: oyuncu renginde 24 px halka + 1 px dikey çizgi, 0,2 sn pop; ekran dışındaysa kenarda ok; sis üstünde | yok | `sfx_ping` (mesafesiz, UI busı) | — | 3 sn, aynı oyuncu ≤ 1 ping/sn | A (yerel) + güvenilir RPC |

## 3. Yerel tahmin: anında, onaylı, geri alma

[görüş] Sınıflandırma kuralı: **dünya durumunu değiştirmeyen** her tepki anında (kukla pozu, istem, çubuk, yerel halka, ping görseli, kaçış çizgisi); **dünya durumu** (nakit, kapı açık/kapalı, çanta sahipliği, tutuldu/yakalandı, kademe, sonuç) yalnız host'tan. Arada "niyet" katmanı: ≤ 0,3 sn süren, kalıcı iz bırakmayan ön-animasyon (kapı 15° aralanma, el uzanma, çanta sallanma). 150 ms RTT'de onay ≈ 220-320 ms (faz-1.md S2); niyet katmanı bu boşluğu maskeler, 1 sn'de onay gelmezse sıfırlanır (ON-02).

Zarif geri alma (host reddederse):
- Kapı: ön-aralanma 0,15 sn geri yaylanır, kısık `sfx_ui_deny`; istem 0,4 sn gri; ALERT yok. Oyuncu "takıldı" okur, "cezalandırıldım" değil.
- Kasa/kilit/çanta çubuğu: yeşil çubuk gri sönüm 0,3 sn + "İptal" MUTED (mevcut US-013 davranışı); kukla doğrulur; parçacık ve nakit hiç çizilmemiş olur (zaten O).
- Devir: eller geri çekilir 0,15 sn; çanta hiç yer değiştirmemiştir.
- Tutulma/yakalanma: host kararı; istemci asla "tutuldum" varsaymaz. ON-03 ileri tahmin host'ta; istemcide tek ek ipucu: sahip 40 px'e girince kukla ürkmesi (görsel, sonuçsuz).
- Konum: istemci yetkili, geri ışınlama yok (KR-008). Uzak oyuncu için tampon sıfırlanınca kukla sessizce yeniden kurulur.
- Balonlar (ON-04): 15 Hz güvenilmez çoğaltmadan istemcide eşik; kayıp karede 66 ms geç, kabul. "!" ile uyarı kademesi (güvenilir) 1 kare farklı gelebilir: balon önce, merdiven sonra — doğal sıra, sorun değil.
- Sayaç ve kademe: host zamanı; istemci sayaç çizerken host'tan gelen değeri 0,2 sn'de yumuşatır (sıçrama yok).

Kabul kriteri (headless, 150 ms + jitter): niyet → onay gecikmesi p95 ≤ 400 ms; red oranı < %3 (yoksa tolerans paylarına bak); hiçbir A efekti sonuç verisi (nakit, çanta, kademe) çizmez (tarama testi: ui/ ve görsel katman yalnız S3/S7 sinyallerinden okur).

## 4. Kamera dili (Camera2D, yerel; `data/camera_tuning.tres`)

- **Takip yumuşatma:** `position_smoothing_speed` 10/sn (≈ %95'e 0,30 sn, kukla kalkış k=10 ile aynı) — mantık ivmesi 0,10 sn'yken kamera 0,30'da gelir: ağırlık hissi kuklayla uyumlu, girdi tepkisi kuklada anında görünür. Ölü bölge yok (gizlilikte hassas konum). Harita kenetleme (IS-027) korunur.
- **Look-ahead (bakış kayması):** hedef = oyuncu + hareket yönü × (hız/220 × 40 px) [sızma 13 / yürüme 25 / koşu 40] + yönlü kipte bakış yönü × 48 px; toplam tavan 80 px (ekranın %9'u, 853×480 görüşte). Kayma hedefi 4/sn ile yumuşatılır (ani yön değişiminde salınım yok). Çevresel kipte yalnız hareket bileşeni. Kenetleme sınırında kayma kendiliğinden sıfıra iner (limit kazanır). Neden: koşarken önü görmek (mahalleli köşeden), yönlü kipte konin ekranda kalır. Risk: 80 px'te kukla merkezden uzaklaşır, "kameram kaydı" hissi — test-2'de 0 / 40 / 80 denenir.
- **Kritik an odak:** zoom darbesi 1,5 → 1,575 (+%5) 0,25 sn easeOut, geri 0,6 sn (sorgu, tutulma); yakalanma/polis +%8, geri 1,0 sn. Yalnız yerel oyuncuya dokunan olaylar. **Zaman yavaşlatma yok** (host simülasyonu ve ağ sürer; tek oyuncuya yavaşlık diğerlerine adaletsizlik). "Ağır an" hissi kukla mikro-donması (60-80 ms, yalnız görsel) + stinger + 0,5 sn ses boşluğuyla verilir.
- **Sarsıntı:** trauma modeli (Nystrom): trauma ∈ [0,1], ofset = trauma² × 3 px × gürültü (Perlin, 25 Hz), 0,2 sn'de söner; `Camera2D.offset` ile uygulanır (kenetleme bozulmaz, kenarda BG token görünür — gri değil). Tetikler: yalnız §2 tablosundakiler; tavan 3 px; ≤ 1 px'e düşen tetik atlanır; 0,5 sn içinde ikinci tetik birikmez (max alınır). Uzak olaylar mesafeyle (1 − d/320).
- **Vinyet:** ALERT α 0,12, 0,3 sn, yalnız tutulma/yakalanma/polis; tam ekran flash yok (tek vurgu kuralı).
- **Hareket azaltma:** sarsıntı 0, zoom darbesi 0, look-ahead ×0,5, smoothing 14/sn (daha sıkı); vinyet kalır (hareket değil).
- **Kabul:** 60 fps'de girdi → kukla tepkisi ≤ 2 kare; kamera 150 ms ağda uzak oyuncuyu etkilemez (yerel); headless: sarsıntı sayısı/dk ≤ 4 (bakkal botları), ofset asla 3 px'i aşmaz (birim test).

## 5. Uygulama önerisi: ucuz ve yüksek getirili ilk 8 iş

Hepsi görsel/ses katmanı; mantık ve ağ sözleşmesi değişmez (S2/S3/S7/S8). Sahip tek ajan, kalem başına ayrı worktree; sıralama: #1, #2, #4 hemen (test-2 öncesi), #3 US-008/US-014 birleştikten sonra, #5-#8 2b.

| # | Kalem taslağı | Sahip | Büyüklük | Kabul kriteri (özet) | Neden / risk |
|---|---|---|---|---|---|
| 1 | **His turu v1 — etkileşim ve kasa:** ON-02 iki aşama (yeşil çubuk + klik → nakit sayarak + parçacık), menzildeki hedefe 22 px FG halka (ON-06), kapı 15° ön-aralanma + geri yaylanma, red = gri sönüm | oynanis + arayuz | S | Headless 150 ms: dolum anında klik, nakit ≤ RTT+200'de; 1 sn onaysızda sıfır; birim: halka yalnız menzilde; tarama: HUD sonuç verisini yalnız S3'ten | "Oldu mu?" sorusunu öldürür (faz-1 S2) / yeşil çubuğun sonra gri olması nadir kafa karıştırır |
| 2 | **Kamera dili v1:** `camera_tuning.tres` (smoothing, look-ahead, zoom darbesi, trauma sarsıntı, vinyet), hareket azaltma kapısı; `--camera-feel=0` ile kapatılabilir | oynanis | S | Birim: ofset ≤ 3 px, look-ahead ≤ 80 px, kenetleme korunur; IS-022 görüntüsünde koşan oyuncu önü görür; hareket azaltmada ofset 0 | Koşu/kovalama okunurluğu + ağırlık hissi / 80 px kayma yönlü kipte fazla gelebilir (A/B) |
| 3 | **Tepki kuklası (US-014 + US-008 bağlama):** ürkme, sorgu donması, tutulma bağı + geri sayım yayı, ÇEK çekişmesi, sendeleme, yakalanma oturuşu, çanta sırtı + sallanma, sahip sıçrama/bağırış pozu, mikro-donma | oynanis (görsel) | M | Her poz NPC/oyuncu durum sinyalinden; kök konum oynamaz (≤ 6 px); headless görüntüde tutulan/kurtarılan/yakalanan üç siluet ayırt edilir; hareket azaltmada pozlar kalır, sekme/toz yok | Klip anlarının (§9.3) görünür nedeni / çizim maliyeti (US-014 t2 notu) |
| 4 | **Olay → ses-görsel bağlama (IS-024 eki):** §2 anahtarları kataloğa; her ses aynı sinyalden; stinger + müzik kesme kancası (müzik Faz 4, kanca şimdi); `sfx_mate_seen` 10 sn kilidi; UI busı mesafesiz | arayuz | S | Birim: sahte sinyal → anahtar; eksik anahtar push_warning; ≥ 2× yarıçapta duyulmaz; `assetler.md` satırları | Ses yokken his yarım (Ninja kuralı) / CC0 yer tutucular ton tutmayabilir (IS-030) |
| 5 | **HUD tepkileri v1:** nakit sayarak artış 0,4 sn, çanta ikonu, "Kaçtı n/3", TUTULDUN/ÇEK istemi ALERT, sayaç son 10 sn pulse + tik, "görüldü" rozeti pop | arayuz | S | 1280×720 ve 1920×1080 taşmasız; her öğe renk + şekil; FakeGame ile birim; metin ≥ 18 px | Ekip "ortak tehlike"yi HUD'dan okur / HUD kalabalığı (sınır: aynı anda ≤ 1 ALERT metin) |
| 6 | **Ping / işaret v0:** `ping` eylemi (S5), dünyada 3 sn işaret + ses + kenar oku, ≤ 1/sn, güvenilir RPC (S3 eki `ping_placed(peer, pos)`), koşu JSON `ping{pos}` | oynanis + arayuz + cekirdek (RPC) | S | 150 ms'de diğerlerinde ≤ RTT+100; spam sınırı; sis üstünde çizilir | Discord dışı en ucuz koordinasyon ("şimdi!") / yeni girdi eylemi + RPC (küçük sözleşme eki) |
| 7 | **Hareket azaltma ayarı + efekt bütçesi:** ayarlar menüsünde seçenek (kalıcı, `user://`), tüm efektler tek kapıdan (`FeelSettings.reduced`), bütçe sayaçları (halka ≤ 4, parçacık ≤ 3, balon pop ≤ 2) | altyapi + arayuz | XS | Birim: kapı kapalıyken sarsıntı/zoom/pop/toz 0; bütçe aşımında en eski düşer; headless görüntü iki kipte | Hareket hastalığı + okunurluk güvencesi / ayar menüsü henüz yok (asgari tek onay kutusu) |
| 8 | **His ölçüm eki (koşu JSON + form):** `feel: {ack_ms: {p50,p95}, rejects, shakes_per_min, max_offset_px, mate_seen_count}`; gözlem formuna "H" sütunu (§6) | cekirdek | XS | JSON alanları her koşuda; ci senaryosu eşikleri (§3/§4 kabulleri) kontrol eder | His tartışması sayıya bağlanır / yok |

## 6. Ölçüm: oyun testinde his nasıl gözlenir

Gözlem formu eki (yontem.md §9 K/G/P/S/Ö/T türlerine ek **H** türü, zaman damgalı):
- **H-oldu-mu:** oyuncu "oldu mu?" / "aldım mı?" / "açıldı mı?" dedi → hangi olay (kasa/kapı/çanta). Hedef: 3. koşuda 0.
- **H-gördü-mü:** "beni gördü mü?" / "kim bağırdı?" → hangi işaret eksikti ("?" noktası, rozet, ok). Hedef: koşu başına ≤ 1.
- **H-nerede:** "mahalleli nerede?" / "sen neredesin?" → ses halkası / kenar oku okunmadı. Hedef: ≤ 1.
- **H-ağır:** "lag var" / "geç geldi" (faz-1 H3 ile aynı) ↔ JSON `feel.ack_ms`; şikâyet anındaki p95'i yaz.
- **H-fazla:** "ekran sallandı" / "gözüm yoruldu" / "ne oldu şimdi?" (efekt okunurluğu bozdu) → o anda hangi efektler üst üsteydi. Hedef: 0; ≥ 1 ise bütçe (#7) sıkılır.
- **Kahkaha ↔ olay** (oyun-testi-ve-klip §2): klip anlarının ≥ %70'i §2 tablosunun bağırış / düşürme / ÇEK / sorgu satırlarından.
- Video (60 fps kayıt): girdi → kukla tepkisi kare sayımı ≤ 2 kare; kasa dolum → yeşil ≤ 1 kare; yeşil → nakit ≤ 20 kare (333 ms) temiz ağda.
- Anket (2 soru, faz-1 anketine ek): "Yaptığın şeyin olduğunu ne kadar çabuk anladın?" (Anında / Kısa gecikme / Emin olamadım) · "Ekran hareketi (kamera, sarsıntı) nasıldı?" (Hiç fark etmedim / Hoş / Fazla / Rahatsız etti). Hedef: ≥ 2/3 "Anında", 0 "Rahatsız etti".
- A/B (test-2, aynı tohum): kamera look-ahead 0 / 40 / 80 px; zoom darbesi açık/kapalı. Karar kuralı: tercih ≥ 2/3 ve "H-fazla" 0.

## 7. Riskler

- **R1 Aşırı efekt okunurluğu bozar.** Bağırış sarsıntısı + "!" titreme + halka + mahalleli oku aynı 0,4 sn'de: tek vurgu kilidi (0,5 sn) ve bütçe (#7) olmadan bakkalın en önemli anı karmaşaya döner. Önlem: §1 kural 3 ve 5; headless "altı durum" görüntüsüne bağırış anı eklenir.
- **R2 Hareket hastalığı.** Üstten 2D'de sarsıntı + zoom + look-ahead birleşimi bazı oyuncularda 10 dk'da bulantı; 3 px / %5 / 80 px tavanları başlangıç, hareket azaltma ilk testten önce (#7 XS) şart. Yakın görüş (zoom 1,5) sarsıntıyı büyütür: px değerleri **ekran** pikselidir, dünya değil.
- **R3 Ağ: niyet efekti yanlış söz verir.** Kapı ön-aralanma + red = "kapı açıldı sandım"; red oranı > %3 olursa niyet katmanı kapatılır, yalnız istem gri kalır. Çanta düşürme host kararıyken yerel sallanma "düşecek" sinyali verir ama %50 düşmez: oyuncu "sallandı ama düşmedi" okur — istenen belirsizlik, abartılmaz.
- **R4 Uzak kukla pozları gecikir.** Tutulma bağı (28 px) uzak oyuncuda tamponla 100 ms geç çizilir; bağ çizgisi host konumundan değil **çizilen** konumlardan (iki kukla arası) alınır, aksi halde çizgi havada kalır.
- **R5 Ses yer tutucuları tonu bozar.** Kenney "confirm" bakkalda oyuncak gibi durabilir; klik sesleri kısık (−18 LUFS) ve kısa (≤ 150 ms) seçilir; IS-030 değiştirir.
- **R6 Juice mantığa sızar.** "Mikro-donma" bir gün `process_mode`'a dokunursa host/istemci sapar; kural: görsel katman yalnız kendi `_process`'inde zaman ölçekler, `Engine.time_scale` yasak (tarama testi adayı).
- **R7 Ping spam ve gürültü.** Ping sesi gürültü değildir (NPC duymaz) — oyuncu yanlış öğrenebilir; ping görseli halka değil "işaret" şeklinde (çizgi + nokta), halkalarla karışmaz.

Karar gereken: (1) Ping/işaret (#6) 2b'ye girsin mi, yoksa Discord'a mı bırakılsın (benzer-oyunlar §2c "telsiz" sorusuyla birlikte)? Öneri: v0 girsin, ucuz. (2) Zoom darbesi (+%5/%8) noir tona uygun mu, yoksa yalnız sarsıntı + vinyet mi? Öneri: test-2 A/B.
