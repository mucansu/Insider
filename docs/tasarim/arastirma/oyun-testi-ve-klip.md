# Faz 2a oyun testi ölçümleri, koşu JSON'u, klip anı ve iş sonu ekranı (tasarım araştırması, 2. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil.
İşaretler: **[olgu]** kaynakta yazan · **[görüş]** çıkarım. Bu not docs/arastirma/yontem.md §2 (ölçüler) ve §9 (protokol, gözlem formu, anket) üzerine kurulur; oradakiler tekrar edilmez. Dayanak: GDD §3.5-3.6, §6.3, §8, §14; KR-019 K3; backlog US-012/US-013/IS-015/IS-017.

## 1. Emsaller: klip anı ve iş sonu

| Oyun | Ne yapıyor [olgu] | Bize ders [görüş] |
|---|---|---|
| Lethal Company [1][2] | Gün sonu "performans raporu": harf notu + hurda değeri + çalışan **notları** ("en paranoyak" = en çok kamera döndüren; birden çok not; ölüler de alır; notların oyuna etkisi yok). Verimli oyun ayrılmak (daha çok eşya) → grup dağılır. | İş sonu ekranına istatistikten üretilen 1-3 kuru "not": ucuz, komik, konuşturur. Ayrılma teşviki bizde de var (kasa / arka oda / gözcü) → ortak tehlike sayılarla görünür olmalı. |
| Content Warning [3][4] | Kamera 90 sn film; görüntü çıkarma kutusunda diske yazılır, gemide TV'de **birlikte izlenir**; 3 günlük koşu; izlenme = para; canavarı güvenli mesafeden çekmek en çok izlenme. | "Klip" oyunun kendi döngüsünde: kayıt → birlikte izleme → ödül. Bizde eşdeğeri: iş sonu "olay şeridi" + tek tuşla paylaşılabilir özet kartı (video değil). |
| R.E.P.O. [5][6] | Fizik tabanlı taşıma + yakınlık sesi; "köşeyi dönerken vazoyu düşüren arkadaş" = korku ve komedi aynı kaynaktan; 230 bin eşzamanlı. | Fizik senkronuna girmeden "fumble": çanta devri 0,3 sn, çantayla koşunca düşürme (halka 160), kapıya sıkışma. |
| PEAK (GDC 2026 incelemesi) [7] | İkinci en yüksek tırmanıcıdan 160 m öne geçen oyuncuyu "Scoutmaster" yakalar: 25 hasar + geriye fırlatma (ayrılma cezası diegetik). Stamina çubuğu "hikâye motoru": her eylem tırmanma gücünü keser. Kamp heykeli: ölüleri dirilt **ya da** gizemli eşya (ekip kararı). Çekirdek 3 dakikada anlatılır; kalanı arkadaşın hatasını izleyerek öğrenilir ("dikkat et!"). | Ayrılmayı kuralla değil **bedelle** cezalandır: yakalanan oyuncunun payı ekibin ödemesinden düşer (K3 ile uyumlu). "3 dakikada anlatılır" = 2a brifing ölçütü. Ekip kararı anı: "kefaleti ödeyip onu kurtar mı, parayı al mı" (Faz 4 ekonomi). |
| Payday 2 sonuç ekranı [8] | Süre, oyuncu başına öldürme/düşme/sivil ölümü; nakit ve XP'nin nasıl hesaplandığı adım adım; bonuslar; kart çekme. | Ödeme **hesabı görünür** olsun (ganimet × aracı × plan bonusu − kefalet): oyuncu nedenini okur. Kart/loot çekilişi Faz 4+. |
| Deep Rock Galactic [9] | Başarısız görev %25 ödül; görev sonunda bulunan herkes eşit kopya ödül alır. | Kısmi başarı normal (K3); "kaçan" ve "yakalanan" ayrımı ödülde görünür. |

Klip anı formülü [görüş] (benzer-oyunlar §2c'nin devamı): **görünür neden + görünür sonuç + 2 sn gecikme**. Oyuncu hatayı yaparken ekip görür (koşu halkası, cam önü), sonucu 0,5-2 sn sonra yaşar ("?" → "!"), kayıp komik ölçekte (kefalet, pay düşer; iş bitmez). Faz 2a'da üç doğal klip tetikleyicisi: (1) kasa boşaltırken polisin vitrine gelmesi, (2) çantayla koşup düşürme, (3) arka kapıdan çıkarken devriyeye denk gelme.

## 2. Faz 2a testinde ölçülecek davranışlar (yontem.md §2 tablosuna ek, gizliliğe özgü)

| Ölçü | Nasıl ölçülür (JSON alanı §3) | Eşik / hipotez |
|---|---|---|
| "?" okunuyor mu | "?" olayından sonra 1 sn içinde o oyuncunun kip değişimi (koşu→yürü/sız) ya da yön tersine dönmesi | ≥ %60 (ilk koşuda), ≥ %80 (3. koşu) → okunabilirlik yeter |
| Neden bilgisi | Tespit nedeni dağılımı (koşu / cam önü / kapı sesi / çanta) ↔ anket S4 ("nedenini anladın mı") | Oyuncunun söylediği neden ile günlük nedeni ≥ %70 eşleşir |
| "Beni görmemişti" | Koşu başına şikâyet sayısı (gözlemci) ↔ günlükte `net_flag` (bkz. muhafiz-davranisi §4) | 0 hedef; ≥ 1 ise ağ payı büyür |
| Birlikte / ayrı | Ortalama ikili mesafe; "hepsi 160 px içinde" süresi oranı; aynı anda farklı odada geçen süre | Tahmin: %70 ayrı; "ortak tehlike" hissi için iş sonu ekranı ekip payını gösterir |
| Kaçış kararı | Tespit → kaçış bölgesine varış süresi; tespit → "kalanlar kasayı bırakıp kaçtı" oranı | Medyan ≤ 20 sn; yakalanma ≥ %50 ise kovalama hızı (240) düşer |
| Ölü zaman (gizlilik türevi) | Bir oyuncu ≥ 30 sn: hareketsiz **ve** etkileşimsiz **ve** koni dışında | Koşunun ≤ %15'i (yontem kapısı); kasa 3 sn tutma sırasında diğerlerinin ne yaptığı |
| Kahkaha ↔ sistem olayı | Gözlemci "G" zaman damgası ile günlükteki en yakın olay türü (±5 sn) | Klip anlarının ≥ %70'i §1 üç tetikleyiciden → tasarlanmış kaos çalışıyor |
| Risk iştahı | Çanta alındıktan sonra arka oda nakdine gitme oranı; sessiz alarm (3) sonrası kalma süresi | "Bir tur daha" ile korelasyon: iştah yüksek → tekrar isteği yüksek (hipotez) |
| 2 kişi | 2 ve 3 kişilik koşularda temiz tamamlama oranı farkı | ≤ 15 puan (benzer-oyunlar §2d) |

Gözlem formuna (yontem §9) tek ek sütun: **"kim gördü"** (hatayı yapan dışında kaç oyuncu o anı ekranında gördü) — klip anının paylaşılırlığı buna bağlı [görüş].

## 3. Host koşu JSON'u (öneri; mevcut dökümün `peers/players/team_cash/events/host_lost` anahtarlarına ek, cekirdek IS-015 kalemi)

```
run: { build, seed, level, started_at, duration_s, players: [{peer, name, slot, rtt_ms_median, rtt_ms_p95}] }
result: { outcome: clean|silent|loud|caught_all|aborted, loot: {bags, backroom_cash}, payout: {gross, rate, bail, per_player}, max_alert, escaped: [peer], caught: [peer] }
timeline: [ { t, kind, peer?, guard?, pos?, data? } ]   # tek kronoloji; türler aşağıda
  kind ∈ mode_changed{mode} · noise{kind, radius} · question{guard, band, mode, lit, dist_px} · investigate{guard, lkp}
         · detected{guard, band, mode, lit, dist_px, t_question, rtt_ms, net_flag} · lost{guard} · search_end{guard, found}
         · alert_changed{from, to, cause} · interaction{action, target, start|done|cancel, reason} · bag{take|drop|handoff, peer_to}
         · caught{guard} · escaped · ping{pos} · disconnect/reconnect
per_player: { peer: { dist_px: {sneak, walk, run}, t_in_cone_s, t_visible_s, t_idle_30s, detections, questions, bags_carried, pings } }
team: { mean_pair_dist_px, t_all_within_160px_s, t_split_rooms_s, first_noise_t, first_question_t, first_detect_t }
observer: { laughs: [t], confusion: [t], plan_break: [t], repeat_request: {who, after_run} }   # kullanıcı elle doldurur (yontem §9 formu)
```
İlkeler [görüş]: tek `timeline` + türetilmiş özetler (özetler sonradan yeniden hesaplanabilir); konum yalnız olay anında (sürekli iz yok; dosya küçük kalır); `net_flag` tespitte gecikme kaynaklı şüpheyi işaretler; dosya adı `runs/<tarih>_<seed>_<n>.json`, GB satırları buna atıf verir.

## 4. İş sonu ekranı (US-013) — asgari 2a sürümü ve sonrası

**2a (asgari, arayuz; US-012 sözleşmesi `heist_finished(result: Dictionary)`):**
1. Başlık = sonuç: TEMİZ / SESSİZ ALARM / GÜRÜLTÜLÜ / YAKALANDI (GDD §6.3 üçlüsü + kayıp); süre; en yüksek uyarı kademesi (0-3 merdiven ikonu, HUD ile aynı).
2. Ödeme hesabı satır satır: ganimet (çanta × değer + arka oda) × aracı oranı (%85 / %70 / %45) − kefalet (yakalanan başına, Faz 2'de sabit 0 ama satır görünür) = ekip ödemesi; kişi başı pay; yakalananın payı düşük (K3) ve görünür.
3. Oyuncu satırları (slot rengi + ad): kaçtı/yakalandı; çanta sayısı; tespit sayısı; koşu mesafesi oranı.
4. **Notlar** (Lethal): istatistikten 1-3 kuru başlık, metin anahtarlı (`NOTE_*`): "Gölge" (koni içinde en az süre), "Vitrin yıldızı" (cam önünde en uzun), "Maratoncu" (en çok koşu), "Kefalet" (yakalanan), "Hamal" (en çok çanta), "Kapı çarpan" (en gürültülü). Kural: her not tek kişiye, aynı kişiye en fazla 2; hiç tespit yoksa "Hayalet ekip" (ekip notu). Oyuna etkisi yok.
5. Düğmeler: "Bir daha" (aynı seviye, host) · "Sığınak" (Faz 4'e kadar ana menü). Kayıp ekranı aynı sahnenin "YAKALANDI" hali; ayrı sahne yok.
6. Kurallar: tüm metin `tr()`; sayılar `heist_finished` sözlüğünden, ekran hesap yapmaz; 1280×720'de tek ekran, kaydırma yok; sonuç başlığı ve ödeme ≥ FONT_SIZE_HEADING; gamepad odak sırası.

**Sonraki (test bulgusuna göre):** olay şeridi (0-N sn yatay çizgi; "?", "!", uyarı değişimi, çanta, kaçış ikonları; tıklanınca kim/neden) — Faz 2b/3, telemetri `timeline`'dan okunur · "plan doğruluğu" satırı (GDD açık soru 3; Faz 3 D3.1) · özet kartı PNG dışa aktarma (Discord'a atılır; Content Warning "izleme" ritüelinin ucuz hali) — Faz 3 · kart/eşya çekilişi (Payday) — Faz 4 · yakalanan için "kefalet öde / bırak" ekip kararı (PEAK heykel dersi) — Faz 4.

## 5. US-012 / US-013 için AC önerileri ve karar gereken

US-012 (soygun sonucu): (a) `heist_finished` sözlüğü §4.2-4.3 alanlarını taşır ve tüm peer'larda aynıdır; (b) yakalanan donar, kalanlar ≥ 1 çantayla kaçış bölgesine girince iş biter (K3), herkes yakalanınca "YAKALANDI"; (c) aracı oranı en yüksek uyarı kademesine bağlı (0-1 %85, 2 %85, 3 %70; 4-5 Faz 2'de yok); (d) çantayla koşmak = düşürme + gürültü 160 (fumble), devir 0,3 sn kilitli el sıkışma; (e) senaryo `heist_full.json` (0/150 ms): kazanma ve kaybetme yolu, ödeme eşit; (f) host koşu JSON'u §3 (IS-015 ile paylaşımlı; en azından `result` + `timeline`).
US-013: (g) §4.1-4.6; (h) birim: sahte `heist_finished` ile notların üretim kuralı (tek kişi, en fazla 2, boş istatistikte "Hayalet ekip"); (i) uyarı merdiveni HUD'da sabit, kademe sayısı yazılı (yalnız renk değil), sayaç yalnız 3'te; (j) headless ekran görüntüsü: kazanma ve kaybetme ekranı 1280×720 ve 1920×1080'de taşmasız.

Karar gereken: (1) Notlar 2a'ya girsin mi (ucuz, komik; risk: ilk testte dikkat dağıtır) — öneri: 3 not türüyle girsin. (2) Koşu JSON'u otomatik dosyaya mı yazılır, yoksa yalnız `--dump` ile mi? Öneri: dev build'de her koşu otomatik. (3) Gözlemci alanları (kahkaha vb.) JSON'a elle mi, ayrı CSV mi? Öneri: ayrı CSV, zaman damgasıyla birleştirilir.

## Kaynaklar
[1] https://dotesports.com/indies/news/lethal-companys-employee-notes-explained
[2] https://gameindustrylibrary.com/documents/pushtotalk-how-lethal-company-sold-10-million-copies
[3] https://contentwarning.wiki.gg/wiki/Camera
[4] https://www.vodafone.de/featured/article/content-warning-die-besten-tipps-im-guide-197439 · https://www.landfall.se/content-warning-press-kit
[5] https://80.lv/articles/this-indie-co-op-horror-goes-viral-seeing-over-230k-concurrent-players/
[6] https://www.gfinityesports.com/article/5-reasons-to-play-repo-if-you-love-lethal-company
[7] Millman, "Is This Peak?", GDC 2026 Game Narrative Review — https://media.gdcvault.com/gdc2026/GNR/Papers/Zac+Millman+-+GDCReview_2026_Peak_Millman.pdf
[8] https://payday.fandom.com/wiki/Payday_(results_screen)
[9] https://deeprockgalactic.wiki.gg/wiki/Mission
[10] Telemetri genel çerçeve — https://www.gamedeveloper.com/design/telemetry-supported-game-design
