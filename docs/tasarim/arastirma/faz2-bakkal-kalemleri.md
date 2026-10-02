# Faz 2 kalem revizyonu: bakkal (T1) tehdit modeline göre kart taslakları (IS-021)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri; pano (backlog/kararlar) koordinatörün. Dayanak: GDD v0.3 §6.1 (sivil çarpan tablosu), §9.1-9.3; KR-020; KR-019 (K1, K3, K5, algı sayıları); mimari S11; muhafiz-davranisi.md (FSM/adalet ilkeleri); oyun-testi-ve-klip.md (US-012/US-013).
Sayılar başlangıç değeridir (`data/` altında), oyun testiyle ayarlanır. Kimlikler öneri: US-016 ve IS-022 koordinatörce verilir.

## 1. 2a "çirkin dilim" güncellenmiş listesi (sıra = oynanabilirliğe en kısa yol)

| Sıra | Kalem | Durum / değişiklik | Neden 2a |
|---|---|---|---|
| 1 | US-006 Algı çekirdeği | Denetimde; **dokunulmaz**. Sivil çarpanı US-008'de `Perception`'a `factor_query: Callable` (dark_query kalıbı) ile eklenir | Muhafız profili T4+'ta aynen kullanılacak |
| 2 | US-007 Bakkal v1 | Denetimde; **dokunulmaz**. İşaret eklemeleri IS-022'de | PASS'i geciktirmemek |
| 3 | IS-022 Bakkal v1 nüfus işaretleri (seviye, XS) | Yeni | US-008/US-016 işaretleri olmadan yazılamaz |
| 4 | US-008 Bakkal sahibi v0 | Yeniden yazıldı (§2) | Tek gözlemci + kazanma/kaybetme omurgası |
| 5 | US-009 Gürültü v0 + T1 kilit | AC değişiklikleri (§6) | Bağırış, kapı sesi, dikkat dağıtma gürültüsü |
| 6 | US-010 Bakkal etkileşimleri | Yeniden yazıldı (§4) | Sahibi yönetmeden bakkal "bekle-koş"tan ibaret kalır |
| 7 | US-012 Soygun sonucu | AC değişiklikleri (§6) | Kazan/kaybet + ödeme |
| 8 | US-016 Mekân nüfusu v0 | Yeni (§3); 2a, kayarsa 2b (`population` aralığı 0 → kapalı, test US-008 ile yapılır) | Tanık/örtü/dikkat olmadan sahip döngüsü tek boyutlu |
| 9 | US-013 İş sonu + HUD (asgari) | AC değişiklikleri (§6) | Test için gerekli |
| 10 | 5-6 SFX (yer tutucu; sahibi: arayuz ya da oynanis, Karar) | Aynı | Bağırış/zil/"?" duyulmalı |
| → | IS-017a oyun testi (2-3 kişi) | Aynı | |

**2b:** US-011 sis + okunabilirlik (AC ekleri §6), US-014 kukla v0 (sahip/müşteri/mahalleli başlıkları GDD §14), IS-015 botlar, US-015 uyarlanır tampon, raf değerlileri (US-010 eki), SATIN AL bedeli (Faz 4 ekonomi).
**Çıkarılan / ileri kademeye:** muhafız FSM (`brain_guard`, devriye, telsiz, arama) → Faz 4 benzinlik yerine **T4 depo** (benzinlikte görevli yok; benzinlik çalışanı `brain_owner`'ın "düğmeli" varyantı); kamera iskeleti → Faz 4 (T2); sindirme/düğme → Faz 4 (T2); `PolicePatrol` devriyesi → kaldırıldı (yeniden adlandırma IS-022); IS-016 Steam spike → Faz 5 (KR-020); `SearchSpot*` → T4.

## 2. US-008 — Bakkal sahibi v0 (gözlemci + ajanda + tutma + mahalleli dalgası)

EP-02 · P1 · M · Sahip: oynanis · Sözleşme: S2, S3 (uyarı eki), S6, S7, S8, S11 · Bağımlılık: US-006, US-007, IS-022 · 2a
**Hikâye:** Oyuncu olarak bakkal sahibinin o an ne yaptığını (tezgâh, raf, arka oda, telefon) okuyup kasayı onun dikkati başka yerdeyken boşaltmak istiyorum; beni fark edince önce sorgulasın, sonra bağırsın ve sokaktan gelenler beni kovalasın; tutulursam arkadaşım beni çekip kurtarabilsin.
**Kabul kriterleri** (sayılar GDD §9.3; ayarlar `data/npc/{civilian,owner,chaser}_tuning.tres`, S10):
- AC1 `entities/npc/owner/` sahnesi: CharacterBody2D (npcs; players'ı itmez), US-006 `Perception` + `Suspicion` (sivil çarpan tablosu GDD §6.1: `Perception.factor_query` Callable → `core/civilian_rules.gd` çarpanı oyuncunun bölgesi (`Zones`: CustomerArea/StaffArea/Backroom), kipi, `busy_by` etkileşimi ve çanta durumundan hesaplar; muhafız profili değişmez), `Hearing` (S8), yeni `Agenda` bileşeni (`entities/npc/components/agenda.gd`: {işaret, süre aralığı, bakış yönü, koni daralması} listesi, tohumlu RNG, `task_changed(name)` sinyali, kesme/geri alma API'si), `core/fsm.gd` + `brain_owner.gd`. Durumlar: AJANDA{TEZGÂH, RAF, ARKA_ODA, TELEFON} → kesmeler ZİL (1 sn) / MÜŞTERİ (6 sn, US-016 çağırır) / GÖNDERİLDİ (10 sn, US-010) / DİNLE (8 sn, gürültü) → BAK (30) → SORGU (60) → BAĞIR (100) → TUT → SENDELE (2 sn) → (30 sn görüş yok) AJANDA. Yalnız host; konum/yön/durum/görev 15 Hz çoğaltılır.
- AC2 Ajanda tohumla belirlenimci: 300 sn headless ölçümde `Register` görüş hattı dışı toplam 60-120 sn, ≥ 4 pencere (her ≥ 10 sn), ardışık pencereler arası ≥ 15 sn TEZGÂH; aynı tohum → aynı görev dizisi (I6).
- AC3 Çarpan birim testleri (sabit adım): kasa tutarken yakın bant "!" 1,0 sn (0,2 + 0,8; ±1 kare), uzak 1,8 sn; müşteri bölgesinde yürüyen 60 sn hiç dolmaz, 61. sn'den 0,25; personel tarafı 1,5 sn; sızma 4,2 sn; "?" her satırda tespitten ≥ 0,5 sn önce; görünüp masumken boşalma 10/sn, görünmeyince 20/sn; raf arkası hiç.
- AC4 Sorgu: 60'ta oyuncuya yürür (110 px/sn), 64 px'te durur, `owner_question` olayı + balon metni anahtarı; 3 sn içinde < 60 → `owner_shrug`, ajandaya döner; ≥ 100 → BAĞIR. `Suspicion.apply_delta(peer, delta)` host API'si (US-010 OYALA bunu çağırır; bu kalemde API + test).
- AC5 Bağırma: `owner_shout` + NoiseBus 320 px + uyarı 2 (Game S3 eki `alert_level_changed(level)`, bakkal eşlemesi 0-3 + 5; koordinatör mimari.md'ye yazar); her 5 sn yineler; 30 sn görüş yoksa 2 → 1 ve ajanda; arka oda nakdi alınmışsa 60 sn sonra yeniden bağırır (+1 komşu).
- AC6 Mahalleli dalgası: `entities/npc/chaser/` + `brain_chaser` (200 px/sn, navigasyon; hedef = en yakın görünen oyuncu, görüş yoksa son görülen konum 15 sn, sonra ön kapıda bekler); bağırıştan 8 sn sonra `NeighbourSpawn`'da komşu üretilir (MultiplayerSpawner, host); ilk chaser `FrontDoor`/`BackDoor` bölgesine girince uyarı 3 + 60 sn `alert_timer` (çoğaltılır) → `police_arrived` → US-012. Yoldan geçen dönüşümü US-016'da.
- AC7 Tutma/yakalama: sahip TUT 120 px/sn, 28 px + 0,5 sn temas → `player_held(peer)`: oyuncu donar, girdi kesilir, 6 sn sayaç (aynı oyuncuda 2. kez 3 sn), sayaç bitince `player_caught`. Chaser 28 px + 0,5 sn → `player_caught(peer)` (K3, kurtarma yok). ÇEK: oyuncu üzerinde `Interactable` (yalnız `held` iken etkin, 32 px, 1 sn tut, ekip arkadaşı) → ikisi serbest, sahip SENDELE 2 sn, kurtarana şüphe 100.
- AC8 Adalet (S2, GDD §12): aleyhte kararlar eşitleyici konumuyla, lehte 0,2 sn; dökümde `detections` (muhafiz-davranisi §4 alanları + `behaviour`), histerezis koni 50°/224 → 53°/238 px.
- AC9 Testler: FSM değişmezleri I1-I7 (I4 bakkal kümesi {0→1, 1→2, 2→3, 3→5, 2→1, 1→0}); `tests/net/owner_detect.json` (0/150 ms): bot personel tarafına yürür → "?" → sorgu → bağır tüm peer'larda aynı sırada ve uyarı 2; bot raf arkasında bekler → 0; `owner_window.json`: bot RAF penceresinde kasayı boşaltır → team_cash 150, uyarı 0; `rescue.json`: tutulan bot 6 sn içinde çekilir → serbest, çeken şüphe 100.
- AC10 SFX/görsel olay adları sinyal: `owner_question`, `owner_shrug`, `owner_shout`, `owner_held`, `owner_stagger`, `chaser_spawn`, `police_arrived`.
**Dokunulacak:** entities/npc/** (owner, chaser, components/agenda.gd, components'e yalnız ekleme), core/fsm.gd, core/civilian_rules.gd, data/npc/{civilian,owner,chaser}_tuning.tres, autoload/game.gd (yalnız uyarı kademesi + sayaç S3 eki), entities/player/** (yalnız held/caught durumu, girdi kesme, ÇEK Interactable), levels/store_a.tscn (yalnız NPCs altı), tests/unit/test_{owner,chaser,agenda,fsm,civilian}*.gd, tests/net/{owner_detect,owner_window,rescue}.json, tests/net/bots/**, i18n/texts.csv (satır ekleme)
**Dokunulmayacak:** autoload/{net,args}.gd, ui/**, levels/ (NPCs dışı; işaretler IS-022), project.godot, tools/**, entities/props/** (US-010), core/{perception,suspicion,interaction_rules}.gd
**Oku:** GDD §6.1-6.2, §9.1-9.3, §12 · mimari S2, S3, S7, S8, S11 · muhafiz-davranisi §3-5 · KR-019, KR-020
**Karar gereken (ön):** kesme önceliği GÖNDERİLDİ > MÜŞTERİ > DİNLE > ZİL (öneri); NPC'nin kapalı kapıyı açması: sahip ve chaser her kapıyı açar (Interactable host API), `door_link.enabled` kapıyla bağlanır.

## 3. US-016 — Mekân nüfusu v0: müşteri akışı + yoldan geçenler

EP-02 · P1 · M · Sahip: oynanis · Sözleşme: S2, S3, S6, S10, S11 · Bağımlılık: US-008 (Agenda, chaser, civilian tuning), IS-022 · 2a (kayarsa 2b)
**Hikâye:** Oyuncu olarak bakkala arada müşterilerin girip raflara bakmasını, kasaya gelmesini ve sokaktan geçenlerin camdan içeri bakmasını istiyorum; beni görürlerse sahibe söylesinler ya da bağırsınlar, ama kalabalık beni biraz da gizlesin.
**Kabul kriterleri:**
- AC1 `data/levels/store_a_population.tres` (`PopulationDef`, S10): müşteri aralığı 35 ± 15 sn, aynı anda ≤ 2, kalış 25-45 sn; yoldan geçen 20 ± 8 sn, sokakta ≤ 2, bakış olasılığı 0,3 / 2 sn; komşu 1 / 8 sn; `seed`. `entities/npc/population.gd` (seviye NPCs altında, host): üretim/silme MultiplayerSpawner ile; üst sınır 6 NPC; aralık 0 = kapalı.
- AC2 `brain_customer` + Agenda: ön kapı → 1-2 `ShopSpot*` (8-12 sn, rafa döner) → `QueueSpot*` → sahip `serve()` (6 sn; sahip yoksa 20 sn bekle, çık) → ön kapı. NPC-oyuncu çarpışması yok (npcs katmanı players maskesi kapalı; birim test). Kuyruk doluysa raf noktasında bekler.
- AC3 Müşteri tanıklığı: sivil çarpan tablosu, koni 50°/160 px; 100 → `tell_owner`: sahibe yürür, ≤ 5 sn'de `Suspicion.apply_delta(+60)`; sahip görünmüyorsa `customer_flee` (ön kapıdan çıkar). Örtü: içeride ≥ 1 müşteri varken sahibin müşteri bölgesi satırlarına dolumu ×0,5 (`factor_query` içinde; personel tarafı/kasa satırları etkilenmez).
- AC4 `brain_passerby`: `StreetRoute1..6` (110 px/sn), `WindowLook*` noktalarında tohumla %30 / 2 sn bakış (koni 40°/192 px, `see_through`); 100 → `passerby_shout` (gürültü 240) + sahibe +60 + %50 chaser'a dönüşür / %50 kaçar (tohum). Sahip bağırınca 320 px içindeki yoldan geçenler chaser olur (US-008 `brain_chaser`).
- AC5 Determinizm ve sınır: aynı tohum → aynı üretim zamanları ve rotalar (I6); NPC ≤ 6; döküm `population: {customers_in, customers_served, passersby, looks, tells, shouts}`.
- AC6 `tests/net/population.json` (0/150 ms): 120 sn'de ≥ 2 müşteri girip çıkar, tüm peer'larda NPC kümesi eşit; müşteri kuyruktayken kasa boşaltan bot → `tell_owner` → sorgu; yoldan geçen `WindowLook` bakışında kasa → `passerby_shout`; müşteri bölgesinde yürüyen bot 100 sn hiç "?" almaz.
- AC7 SFX olay adları: `customer_enter` (zil), `customer_tell`, `customer_flee`, `passerby_shout`.
**Dokunulacak:** entities/npc/{customer,passerby}/**, entities/npc/population.gd, entities/npc/components (yalnız ekleme), data/levels/*_population.tres, data/npc/{customer,passerby}_tuning.tres, levels/store_a.tscn (yalnız NPCs altı), tests/unit/test_population*.gd, tests/net/population.json, tests/net/bots/**, i18n/texts.csv
**Dokunulmayacak:** autoload/**, ui/**, core/** (yeni dosya gerekiyorsa Karar), entities/player/**, entities/props/**, project.godot, tools/**
**Performans/ağ notu:** algı 6 NPC × 3 oyuncu × 15 Hz ≈ 270 ışın/sn; çoğaltma 6 × 15 Hz × (konum + yön + durum + görev) ≈ 2 KB/sn; müşteri rotası host'ta navigasyonla, istemcide yumuşatma.

## 4. US-010 — Bakkal etkileşimleri: sahibi yönetme araçları

EP-02 · P1 · M · Sahip: oynanis · Sözleşme: S2, S7, S8, S10 · Bağımlılık: US-008, IS-022 (US-016 isteğe bağlı) · 2a
**Hikâye:** Oyuncu olarak bakkal sahibini oyalayıp, arka odaya gönderip, dikkatini dağıtıp ya da bir şey satın alıp arkadaşıma pencere açmak istiyorum; her aracın bedeli olsun.
**Kabul kriterleri** (tablo GDD §9.3 "Oyuncunun araçları"):
- AC1 SATIN AL: `Counter` prop'una müşteri tarafı `Interactable` (2 sn tut, `side = customer`); host: oyalanma sayacı sıfırlanır, `owner.serve_player(peer)` 6 sn (sahip tezgâhta değilse ≤ 20 sn içinde gelir), ekip nakdinden 10 (yoksa bedava; Faz 4 ekonomi). Satın alan oyuncuya şüphe 0, diğerlerine değişmez.
- AC2 OYALA: sahip üzerinde `Interactable` (64 px, 1,5 sn tut); yalnız sahibin o oyuncuya şüphesi 30-99 iken etkin (requirement host'ta); etki `apply_delta` -40 / -20 / 0 (oyuncu başına sayaç), sahip 2 sn daha durur; bağırıştan sonra (100) işlemez.
- AC3 ARKA ODAYA GÖNDER: `Counter` alt eylem (2 sn tut, müşteri tarafı), iş başına 1; sahip GÖNDERİLDİ görevi (arka odaya gider, 10 sn arar, "yok" balonu, döner); dönüşte soran oyuncuya +20; headless ölçümde kasa penceresi ≥ 12 sn.
- AC4 DİKKAT DAĞIT: `ShelfProp1..3` (raf uçları; `PropDef`, anında, tek kullanımlık) → NoiseBus 120 px → sahip DİNLE 8 sn (sese bakar, yürür); o noktadan 2 sn içinde koşarak uzaklaşan oyuncuya +15; müşteriler de 2 sn bakar (US-016 varsa).
- AC5 Oyalanma sayacı: oyuncu başına dükkân içi süre; 60 sn'den sonra çarpan 0,25; SATIN AL ve dükkândan çıkış sıfırlar; dökümde `loiter_s`.
- AC6 Testler: birim (OYALA sayacı 40/20/0; GÖNDER iş başına 1; SATIN AL sahip yokken bekleme); `tests/net/bakkal_tools.json` (0/150 ms): bot A GÖNDER → bot B kasayı boşaltır → team_cash 150, uyarı 0; bot A SATIN AL sırasında bot B arka oda nakdini alır → uyarı 0; OYALA 3 kez → şüphe 60 → 20 → 40 → 60 → 60; istemci kendi başına sonuç üretemez (S2).
**Dokunulacak:** entities/props/{counter,shelf_prop}*, entities/npc/owner/** (yalnız `serve_player`, GÖNDERİLDİ görevi, OYALA Interactable), data/props/{counter,shelf_prop}.tres, core/interaction_rules.gd (yalnız gerekirse), tests/unit/test_bakkal_tools*.gd, tests/net/bakkal_tools.json, bots, i18n/texts.csv
**Dokunulmayacak:** autoload/**, ui/**, levels/** (ShelfProp konumları IS-022 Markers'tan), project.godot, entities/player/** (ÇEK US-008'de), US-012 çanta dosyaları
**2b eki:** raf değerlileri (3 × 30, 1 sn alma, çarpan 1,5).

## 5. IS-022 — Bakkal v1 nüfus işaretleri (seviye, XS; US-007 PASS'inden sonra, US-007'yi yeniden açmaz)

- `PolicePatrol1..6` → `StreetRoute1..6` (yoldan geçen + chaser yaklaşma yolu; `marker_sequence("StreetRoute")`); `NeighbourSpawn` (yan sokak, arka kapı ile cadde arası; ör. sütun 24 satır 8); `WindowLook1..3` (kaldırımda ön cam parçalarının ve yan camın önü); `ShopSpot1..5` (raf koridoru ağızları ve raf önleri, müşteri); `QueueSpot1..2` (tezgâhın müşteri tarafı, sütun 16 satır 10-11); `RestockSpot1..3` (sahip raf düzeltme: batı rafları, sütun 3-4 satır 5/7/9); `PhoneSpot` (tezgâh arkası doğu duvarı, sütun 21 satır 11); `BackroomSpot` (arka oda, sütun 18 satır 5); `ShelfProp1..3` (raf uçları; Props altına US-010 yerleştirir); bölgeler `= ` satırıyla `CustomerArea`, `StaffArea`, `Backroom` (Zones, triggers katmanı).
- test_levels: işaretler tam, hiçbiri duvar/raf içinde değil, `StreetRoute` sırası ön camlar → ön kapı → köşe → yan camlar → yan sokak → arka kapı; `RestockSpot`'lardan `Register`'a görüş hattı raf/duvarla kesik (BFS/ray yerine düzen kuralı: aralarında ≥ 1 raf karosu).
- Dokunulacak: levels/layouts/store_a.txt, levels/tools/build_levels.gd (yalnız gerekirse), levels/*.tscn (yeniden üretim), tests/unit/test_levels*.gd. Dokunulmayacak: entities/**, core/**, autoload/**, ui/**, Props altı.

## 6. Diğer kalemlerin AC değişiklikleri

**US-009 Gürültü v0 + T1 kilit:** "dinleyici muhafız" → `Hearing` sahip/müşteri/chaser'da; türler: koşma 120, kapı 160, kasa 90, bağırış 320, yoldan geçen bağırışı 240, raf devirme 120, arka kapı kilidi 60 (6 sn tut, dışarıdan, T1 maymuncuk gereksinimi `InteractionRequirement.min_tier`); ses görüş hattı olmadan +30 ("?") ve DİNLE; chaser sese yönelir; halka görseli noir FG. Senaryo: `noise_t1.json` — bot arka kapıyı açarken sahip arka odadaysa "?" alır, tezgâhtaysa almaz.
**US-011 Sis + okunabilirlik (2b):** ekip görüşü dışındaki NPC (müşteri, yoldan geçen) çizilmez; sahibin **görev ikonu** (tezgâh/raf/arka oda/telefon) ve koni her zaman; yoldan geçen konisi yalnız bakarken; chaser üstünde "!" halkası; tutulan oyuncuda 6 sn halka; "?"/"!" balonları müşteri ve yoldan geçende de. Kabul: headless ekran görüntüsünde sahip görevi 22 px'te ayırt edilir.
**US-012 Soygun sonucu:** `heist_finished` outcome ∈ {clean (uyarı ≤ 1), shouted (2), hot (3), caught_all, police}; oran 0-1 %85 (+%5 "kimse bağırmadı"), 2 %85 + ısı +5, 3 %70; `police_arrived` → içeride kalan herkes caught; kazanma = yakalanmamış herkes `EscapeZone`'da; held ≠ caught (held süresi dolunca caught); çanta (`BackroomCash` → `Bag`: 2 sn alma, koşarken her sn %25 düşürme + gürültü 160, devir 0,3 sn); yakalananın payı 0; `heist_full.json` kazanma (temiz ve bağırışlı) + kaybetme (police, caught_all) yolları.
**US-013 İş sonu + HUD:** uyarı merdiveni metinleri mekân eşlemesinden (`ALERT_T1_0..5` anahtarları: Sakin / Şüphe / Bağırdı / Mahalle geldi / — / Polis), sayaç yalnız 3'te; notlar (oyun-testi-ve-klip §4.4) + "Bakkalın gözdesi" (en çok satın alan), "Terlik yedi" (chaser'a yakalanan), "Çekti kurtardı"; sahip görev ikonu HUD'da değil dünyada (US-011).
**IS-015 Botlar:** bot repertuvarı: müşteri kılığında bekle, pencereyi bekle (sahip görevi RAF/ARKA_ODA/TELEFON ise kasaya git), GÖNDER + kasa, kaç; 2 ve 3 botla 200 koşu, temiz oranı farkı ≤ 15 puan; yakalanma ≥ %70 ise chaser hızı/komşu süresi gevşer.

## 7. EP-02 çıkış kriterleri önerisi (bakkala göre, ölçülebilir)

1. Algı (otomatik): kasa tutarken sahip yakın bantta ≤ 1,0 sn, uzak bantta ≤ 1,8 sn "!"; müşteri bölgesinde yürüyen oyuncu 60 sn hiç tespit edilmiyor; raf arkası hiç; "?" her tespitten ≥ 0,5 sn önce.
2. Sahip döngüsü: 300 sn ajandada ≥ 4 kasa penceresi (her ≥ 10 sn); botla temiz tamamlama 3 kişide ≥ %30, yakalanma ≤ %70 (IS-015, 200 koşu).
3. Zincir görünür: "?" → sorgu → bağırış → mahalleli → polis sayacı; kazanma (temiz, bağırışlı) ve kaybetme (polis, herkes yakalandı) yolları senaryoda; iş sonu ekranı ödeme hesabıyla.
4. Ağ: 150 ms'de 20 dk tutarsızlık 0, NPC ≤ 6, "beni görmemişti" `net_flag` 0 (bot ve insan koşularında).
5. İnsan testi: 3 arkadaş ≥ 3 koşu; oturumların ≥ 2'sinde kendiliğinden "bir daha"; koşu başına ≥ 1 klip/plan bozulma anı (gözlem formu); ölü zaman ≤ %15; anket S4 "Bazen/Hiç" ≤ 1 kişi; 2 kişilik en az 1 koşu.
6. (Kaldırıldı) Steam spike → EP-05.
