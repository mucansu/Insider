# Ekip iletişimi: bağlamsal ping, hızlı mesaj, el işaretleri, "orada biri var" (tasarım araştırması, 5. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; kalem taslakları koordinatörün kararıyla backlog'a girer. Kullanıcı isteği 2026-10-02.
Dayanak: KR-022/KR-023 (ekip görüşü paylaşılmaz; arkadaş kuklası her zaman görünür + bakış yayı + "görüldü" ikonu, GDD §6.5), KR-004 (hafıza kuralı), GDD §2.1/§2.7/§2.9, §4-5 (keşif, plan masası: "ping" zaten listede), §9.3 (roller Müşteri/Kasacı/Arka odacı; klip anları), §11-12 (co-op, 0,2 sn oyuncu lehine, host yetkili), §14 (okunabilirlik ≥ 22 px, tek uyarı vurgusu), §16 açık soru "ses/telsiz"; benzer-oyunlar.md (Lethal/R.E.P.O., Keep Talking, Door Kickers go-kodu), yol-haritasi.md §6.7 ve D yönü, pazarlama-satis.md (bölünmüş bilgi klip üretir; yakınlık sesi friendslop ortak öğesi), kesif-on-testi.md, gorus-sis-hafiza.md, okunabilirlik-2d.md.
İşaretler: **[olgu]** kaynakta/belgede yazan · **[görüş]** çıkarım · **[varsayım]** oynanmadan yargı.
Gerçekçi varsayım: üç arkadaş Discord sesli sohbetteyken oynar; sözlü bilgi kaybı sıfıra yakın. Soru "Discord'un yerine ne koyarız" değil, "Discord'un yanında oyun içi araç ne iş görür" sorusudur.

## 1. İlkeler

| # | İlke | Neden | Neyi riske atar |
|---|---|---|---|
| 1 | **Ping işaret parmağıdır, bilgi kaynağı değil.** Oyun içi araç yalnız oyuncunun zaten sahip olduğu bilgiyi gösterir: gördüğün NPC'ye kesin ping, görmediğine yalnız "son görülen" iddiası; ping NPC'ye yapışmaz, **anlık görüntüdür**. | KR-022 arka kapıdan delinmesin: ping canlı takip olsaydı "arkadaşının gördüğü sahip" dolaylı yoldan paylaşılırdı. Apex'te de "düşman burada" ile "burada biri vardı" ayrı eylemdir [1][2]. | "Ping işe yaramıyor, sahip gitti" hissi → §8 R1. |
| 2 | **Discord'u tamamlar: uzamsal belirsizliği ve senkronu çözer.** "Arka kapı" derken hangi kapı, "şimdi" derken hangi an. Sözlü "şimdi!" Discord gecikmesi (~100-200 ms) + tepki süresi taşır; oyun içi "ŞİMDİ!" host damgalı tek pakettir (≤ RTT/2 ≈ 45-75 ms fark). | Keep Talking dersi: dil tek kanalsa koordinasyon dili gelişir ama uzamsal hata artar [olgu, benzer-oyunlar §1]. | Oyuncu ping'i hiç kullanmaz (Discord yeter) → §4 "sessiz tur" testi ölçer. |
| 3 | **Yanlış hatırlama kaosu korunur.** "Son görülen" ping'i ve plan masası ikonu **iddia**dır; oyun doğrulamaz, solmaz, uyarmaz (GDD §5, §16/7). Hafıza ping'i de keşif → plan geçişinde silinir (KR-004). | "Kim yanlış hatırladı" bölünmüş bilginin klip makinesidir (pazarlama §104). | Yok; kolaylık yalnız görünen hedefte verilir. |
| 4 | **Ping sessizdir; yalnız seçilen iki mesaj gürültüdür.** Ping ve tekerlek NPC'ye görünmez/duyulmaz (sivil çarpanı 0). Tekerlekte "KAÇ!" ve "YARDIM!" avatarı **bağırtır**: NoiseBus 200 px, sahip duyarsa "?" (çarpan 1, koşma satırı). | İletişim cezalandırılırsa kullanılmaz; ama Lethal Company'de sesin canavarı çekmesi oyunun en iyi anlarını üretir [3][4] — bunu iki "pahalı" mesaja indirgiyoruz: bedel görünür ve seçilmiş. | Acil anda yanlışlıkla bağırma → tekerlekte gürültü ikonu + ayrı dilim (§3). |
| 5 | **Her işaret görsel iz bırakır.** Video izleyen Discord'u duymaz, ping'i görür; HUD mesaj günlüğü klibe altyazıdır. | Klip = görünür neden + sonuç (oyun-testi-ve-klip.md). | Ekran kalabalığı → sınırlar (§2). |
| 6 | **Sayılar `data/comm_tuning.tres`'te, oyun testiyle ayarlanır.** Süreler/yarıçaplar aşağıda başlangıç değeridir. | yontem: plan yapışmaz. | — |

## 2. Bağlamsal ping (tek tuş; hedef imleç/bakış yönünden çözülür)

Hedef çözümleme (istemcide): fare → imleç altındaki 32 px karo; gamepad/klavye → bakış yönünde 24-160 px koridorda en yakın aday. Öncelik: görünen NPC > hayalet (son görülen) > prop (kasa, çanta, raf değerlisi) > kapı > ekip arkadaşı > zemin. Hiçbiri yoksa "yer" ping'i.

| Hedef | Koşul | İşaret (dünya, sis üstünde, atkı rengi) | Süre | Anlam / metin anahtarı |
|---|---|---|---|---|
| Yer (zemin, bilinmeyen karo dahil) | her zaman | 24 px halka + nokta; rota planı için sisli alana da konur | 6 sn | `PING_HERE` "Buraya" |
| Kapı | hafıza ya da görünen | kapı ikonu + **ping atanın gördüğü durum** (açık/kapalı/kilitli; hafızadaysa son görülen durum, kesikli çerçeve) | 8 sn | `PING_DOOR_OPEN/CLOSED/LOCKED` |
| Kasa / çanta / raf değerlisi | görünen ∨ hafıza | prop ikonu ("$", çanta); hafızada kesikli | 10 sn | `PING_LOOT` "Ganimet burada" |
| NPC **görünen** (sahip, müşteri, yoldan geçen, mahalleli) | NPC karo = görünen ∧ görüş hattı (istemci iddiası; host yalnız mesafe ≤ 320 px doğrular, §2.9 oyuncu lehine) | başlık silueti ikonu (kim: önlük = sahip, terlik = mahalleli) + dolu halka; **NPC'yi takip etmez**: 3 sn dolu, sonra 5 sn kesikli "son görülen" tonuna (MUTED α 0,5) döner | 3 + 5 sn | `PING_NPC_<TYPE>` "Sahip burada" (yalnız işaret gider, NPC gitmez — §6.5) |
| NPC **hayalet / hafıza** (görünmüyor) | hayalet üstüne ya da son görülen karoya ping | doğrudan kesikli "son görülen" ikonu; "?" **kullanılmaz** (şüphe balonuyla çakışır), kesikli çember = iddia | 8 sn | `PING_NPC_LAST` "Sahibi en son burada gördüm" |
| Ekip arkadaşı | her zaman | kuklasının üstünde atkı rengi ok 2 sn + ona özel balon | 2 sn | `PING_MATE` "Sana geliyorum" (tekerlek açıksa mesaj ona hitap eder) |
| Kendi ping'in | ping'e tekrar bas | siler | — | `PING_CLEAR` |

Görünürlük: ping **herkese** gider, görüş hattı ve sis bakılmaz (ekip kuklası kuralıyla aynı; §6.5); ekran dışındaysa kenarda atkı renginde ok + hedef ikonu (mesafe sayısı yok: ölçek vermek bilgi yaratır). Ping'in kendisi NPC'ye görünmez, duyulmaz (ilke 4).
Sınırlar (spam): oyuncu başına **3 aktif** (4. en eskiyi siler) · 0,5 sn tekrar aralığı · aynı karoya 2 sn · aynı hedef türüne 1 sn. Aşımda host sessizce reddeder, istemci istem gri (ceza yok, GDD §12). Ping süresi dolmadan hedef görüşe girip durum değişirse (kapı açıldı) işaret **güncellenmez** — ping o anın iddiasıdır.
Hile notu [görüş]: NPC görünürlük iddiası istemciden; host görünürlük kararı vermez (§6.5 kuralı). Arkadaş oyunu; Faz 5+ ilgi yönetimi gelirse host zaten yalnız görünen NPC'yi gönderir.

## 3. Hızlı mesaj tekerleği (8 dilim; basılı tut → tekerlek; TR/EN `i18n/texts.csv`)

| Dilim | TR | EN | Tür | Etki |
|---|---|---|---|---|
| 1 | Bekle | Hold | sessiz | balon 2 sn + günlük |
| 2 | **Şimdi!** | **Go!** | sessiz, **go-kodu** | herkeste 1 sn büyük yazı (≥ 24 px, FG) + iki tonlu SFX; host damgalı; plan masası "bekle" düğümünü serbest bırakır (§5) |
| 3 | Gel | Come | sessiz | balon + ping atanın konumuna 4 sn yer işareti |
| 4 | Yol temiz | Clear | sessiz | balon |
| 5 | Sahibi kaybettim | Lost the owner | sessiz | balon + kendi son görülen hayaletine otomatik "son görülen" ping (varsa) — "nereye gitti" sorusunu başlatır |
| 6 | Çık! | Get out! | sessiz, acil | balon ALERT çerçeve + 0,4 sn titreme (renk + hareket, P2 turuncu çatışması için şekil) |
| 7 | **Kaç!** | **Run!** | **gürültülü** (200 px bağırış) | tüm ekrana 1 sn + avatar bağırır (NoiseBus `player_shout`) → sahip/müşteri duyar; dilimde gürültü halkası ikonu |
| 8 | Benim hatam | My bad | sessiz, sosyal | balon + kukla el-başa jesti (KR-017 tepki balonu kalıbı) — komedi anı altyazısı |

Mesaj görünümü: gönderen kuklasının üstünde balon 2 sn (metin ≥ 18 px, atkı rengi çerçeve) + HUD sağ üstte son 3 satır günlüğü (ad + metin, 6 sn, atkı rengi). Tekerlek açıkken hareket **sürer** (menü değil; `UiInput` engeli uygulanmaz), bakış girdisi 0,5 sn dondurulur (gamepad sağ çubuk tekerleği seçer). Tekrar aralığı 1 sn; "Kaç!" 4 sn (bağırış spam'i gürültü istismarı olmasın).
Otomatik durum işaretleri (el işareti gerektirmez; çoğu zaten KR-023'te): "görüldü" göz ikonu (şüphe ≥ 30) · tutuldu 6 sn halkası · çanta ikonu · **meşgul** (etkileşim sürüyor: `busy_by` → kuklanın üstünde ince ilerleme yayı, ekip "kasayı boşaltıyor" diye sormaz) · **hazır** (plan masası/lobide el kaldırma). Kukla el işareti: tekerlek mesajı seçilince kukla 0,4 sn kolunu kaldırır (kozmetik; sivil çarpanı 0; "tuhaf davranış" çarpanı **önerilmez** — çarpan tablosu davranış bazlı kalsın, §6.5 bakış kararıyla aynı gerekçe).

## 4. Yakınlık sesi / telsiz

**MVP'de yok** [öneri]. Gerekçe: (a) hedef grup Discord'da; oyun Discord'u kısamaz, ikinci bir ses kanalı yalnız kafa karıştırır; (b) 2D üstten bakışta yakınlık sesinin birinci şahıs "yüz yüze" komedisi zayıf (pazarlama §51); (c) maliyet: mikrofon yakalama (`AudioStreamMicrophone` + `AudioEffectCapture`, 32-bit float stereo), kodlama (ENet yolu: godot-opus GDExtension; Steam yolu: GodotSteam `getVoice/decompressVoice`, 48 kHz [5][6]), ayrı unreliable kanal + 60-100 ms jitter tamponu + `AudioStreamGenerator` çalma, ayarlar (bas-konuş/açık mikrofon, düzey), **headless testi yok** (yalnız paket akışı sınanır) → tek kişi + ajanla 1-2 hafta ve iki taşıma için iki uygulama [varsayım]; (d) 150 ms RTT + tampon ≈ 300 ms gecikme Discord'dan kötü.
Ne zaman anlamlı (Faz 6 D yönü, yol-haritasi §5): yakınlık sesi **ancak ses gürültüyse** değer taşır — Lethal Company'de konuşma ve telsiz canavarı çeker [3][4]; bizde sesli sohbet NoiseBus'a girer (konuşma 96-160 px, bağırma 240), telsiz = elde tutulan araç (çanta taşırken konuşamazsın: "eller dolu = sessiz" komedisi), menzil dışı = parazit. Önkoşul: arkadaşlar Discord'u kapatmayı **kabul etmeli** — Steam Playtest'teki yabancı ekipler için asıl değer orada. Sinyal: koşu sonrası anlatılan an sayısı düşükse ve "kim nerede" kaosu Discord'la sönüyorsa.
Ucuz ara deney (test-2, kod yok): bir tur **"Discord sessiz turu"** — yalnız ping + tekerlek; gözlemci "nerede?" / yanlış kapı / "şimdi" kaçırma sayısını iki turda karşılaştırır. Ping'in Discord'la birlikte kullanım oranı da sayılır (ping/dk). Kabul: sessiz turda temiz oran Discord turunun ≥ %60'ı ise araçlar yeterli, yakınlık sesi öncelik değil.

## 5. Keşif ve plan fazına uzantı (Faz 3)

- Keşifte ping aynı kurallarla çalışır (içerideki tezgâh arkasındaki arka kapıyı ping'ler, dışarıdaki camdan görür); ping **krokiye işlenmez** ve faz sonunda hafızayla birlikte silinir (KR-004). Keşifteki NPC ping'i fotoğraf değildir (ikon üretmez).
- Plan masası ping'i: masada geçici işaret 5 sn, atkı rengi ("şuraya bak"); kalıcı olan ikon/rota/not (GDD §5, en fazla 3 araç). Ping'den ikon üretme kısayolu **yok** (ikon bilinçli yerleştirilir; Shadows of Doubt otomasyon sınırı).
- **Go-kodu düğümü** (Door Kickers): rota üzerine "BEKLE" düğümü; soygunda plan katmanında kesikli; herhangi bir oyuncunun "Şimdi!" mesajı en yakın bekleyen düğümü (ping atanın 160 px içinde ya da onun rotasındaki) dolu çizer → tetik zincirinin %20 maliyetli hali (benzer-oyunlar §2b). Plan bonusu için "düğüm serbest bırakılmadan ilerleyen oyuncu" kontrol listesi maddesi.
- Plan katmanındaki "sahip burada olacak" ikonu ile soygundaki canlı "Sahip burada" ping'i çakışırsa oyun **hiçbir şey yapmaz**; farkı oyuncu görür (§16/7 "solmaz" önerisiyle tutarlı); iş sonu "plan doğruluğu" özeti D3.1 A/B'sine bağlı.

## 6. Arayüz: girdi, görsel dil, ses

- Girdi (S5 eki, altyapi): `ping` = fare orta tuş + **Z** (klavye-yalnız) + gamepad **LB**; tek bas = bağlamsal ping, **0,25 sn basılı** = tekerlek (fare/sağ çubuk yönü seçer, bırakınca gönderir; yön yoksa iptal). Q `intimidate` ve E `interact` dokunulmaz. `--bot` adımı `{"t":2.0,"ping":[x,y]}` ve `{"t":3.0,"say":"go"}` (S6 eki, cekirdek).
- Görsel dil (okunabilirlik-2d §2 ile): her işaret **renk + şekil**: atkı rengi (kim) + hedef ikonu (ne) + dolu/kesikli halka (gördüm/iddia). ≥ 22 px, 2 px çizgi, sabit bağlantı noktası, sis ve hafıza tonu üstünde (kontrast ≥ 3:1 testi US-011 AC10 genişler). "?" ve "!" şekilleri ping'de **kullanılmaz** (şüphe/tespit balonlarına ayrılmış). ALERT yalnız "Çık!"/"Kaç!" çerçevesinde. Hareket azaltma: pop/titreme kapalı, işaret anında.
- Token'lar (arayuz, S9): `GAMEPLAY_PING_ALPHA` 0,9 → 0,3 sönüm son 1 sn; `GAMEPLAY_PING_CLAIM` = MUTED α 0,5 kesikli; metinler `PING_*`, `SAY_*` anahtarları, TR/EN.
- Ses (ses-ve-sfx §2'ye ek, ton setinde): ping = yumuşak tık (UI bus; mesafeyle kısılmaz, yalnız ekip duyar) · "Şimdi!" = iki ton 0,3 sn · "Çık!" = kısa sert tık · "Kaç!" = oyuncu bağırışı (dünya sesi, halka ile aynı olaydan; Kenney Voiceover CC0 ya da kullanıcı kaydı) · mesaj balonu = yok (günlük yeter). Hiçbir bilgi yalnız sesle verilmez.

## 7. Uygulama kalemleri (taslak; kimlikler ve sıra koordinatörün — US-017+ / IS-031+ boş görünüyor)

| Taslak | Başlık | Sahip | Büyüklük | Kabul kriterleri (özet) | Ağ notu |
|---|---|---|---|---|---|
| US-017 | Bağlamsal ping çekirdeği (hedef çözümleme, kurallar, çoğaltma, döküm) | oynanis (core kuralları düğümsüz `core/comm_rules.gd`) | M | AC1 hedef önceliği §2 tablosu (birim: görünen NPC > hayalet > prop > kapı > mate > yer) · AC2 NPC ping'i NPC'yi takip etmez, 3 sn sonra iddia tonuna döner · AC3 sınırlar (3 aktif, 0,5/2/1 sn) host'ta uygulanır, aşım sessiz red · AC4 `data/comm_tuning.tres` · AC5 döküm `"comm"` = `{pings:[{peer,kind,pos,claim,t}], says:[…], rejected:int}` · AC6 senaryo `tests/net/comm_split.json` 0/150 ms: c1 arka odada ping'ler, host sokakta işareti görür, NPC görmez; kayıpta işaret ≤ RTT+200 ms | S2: istemci `request_ping(seq, kind, pos, target_id, claim)` reliable → host doğrular (gönderen, varlık, mesafe ≤ 320 px, sınırlar; görünürlük iddiası doğrulanmaz) → `ping_shown(peer, id, kind, pos, claim, ttl)` authority call_local reliable; `ping_cleared(id)`. "Şimdi!" host zaman damgalı; istemci alınca anında gösterir. |
| US-018 | Ping ve mesaj görselleri + HUD günlüğü | arayuz | S | AC1 işaretler yalnız token'dan, ≥ 22 px, sis üstünde, kenar oku · AC2 dolu/kesikli ayrımı %50 küçültülmüş karede okunur (ekran görüntüsü) · AC3 günlük 3 satır/6 sn, balon 2 sn, metin ≥ 18 px · AC4 hareket azaltma · AC5 kontrast testi genişler · AC6 i18n `PING_*`/`SAY_*` TR+EN, sabit dize 0 | yalnız sinyal okur (`ping_shown`, `say_shown`) |
| US-019 | Hızlı mesaj tekerleği + go-kodu + gürültülü mesaj | arayuz (tekerlek) + oynanis (`player_shout` NoiseBus bağı) + altyapi XS (`ping` eylemi, bot `ping/say` adımı) | S | AC1 8 dilim, basılı tut 0,25 sn, bırakınca gönder, hareket sürer · AC2 "Kaç!"/"Yardım!" → `NoiseBus.emit_noise(pos, 200, &"player_shout")` host'ta; sahip 200 px içindeyse "?" (senaryo) · AC3 tekrar aralıkları · AC4 gamepad sağ çubuk tekerlekte bakışı 0,5 sn dondurur · AC5 "Şimdi!" herkeste ≤ RTT/2 + kare | `request_say(seq, id)` reliable; `say_shown(peer, id, t_host)` |
| IS-031 | İletişim SFX (tık, iki ton, bağırış) `sound_set.tres` + assetler.md satırları | arayuz/altyapi | XS | ses ve görsel aynı olaydan; UI bus / dünya sesi ayrımı; lisans satırları | — |
| IS-032 | Test-2 "Discord sessiz turu" protokolü + ölçüm (ping/dk, "nerede?" sayısı, yanlış kapı, go kaçırma) | koordinatör + tasarim | S (kod yok) | iki tur aynı tohum; kabul §4 (≥ %60) | — |
| US-020 (Faz 3) | Plan masası ping + "BEKLE" go-kodu düğümü + plan katmanı serbest bırakma | arayuz + oynanis | M | §5; keşif ping'i faz sonunda silinir (birim) | plan masası host'ta (GDD §12) |

Sıra önerisi: US-017 → US-018/US-019 paralel (ayrık dosyalar) → IS-031; test-2'den önce bitmesi istenirse 2b başı; IS-032 test-2 içinde; US-020 Faz 3.

## 8. Riskler

- **R1 "Ping işe yaramıyor"**: NPC'ye yapışmayan ping 3 sn'de bayatlar; oyuncu canlı takip bekler. Emniyet: iddia tonu geçişi görünür ve tekrar ping 1 sn; test-2'de "sahip ping'i yararlı mı" anketi; yapışma yine de **önerilmez** (KR-022).
- **R2 Discord varken kullanılmaz**: ping/dk ≈ 0 çıkabilir. Değer o zaman klip ve senkron ("Şimdi!") ile sınırlı; IS-032 ölçer, düşükse Faz 3 go-kodu dışındaki genişletmeler durur.
- **R3 Ekran kalabalığı**: 3 oyuncu × 3 ping + balon + halka + koni. Sınırlar ve kısa süreler; US-011 AC8 ekran görüntüsüne ping eklenir; 1280×720'de okunurluk kabul.
- **R4 Gürültülü mesaj sinir bozar**: yanlışlıkla "Kaç!" → sahip "?". Tekerlekte gürültü ikonu + ayrı dilim + 4 sn aralık; testte şikâyet gelirse gürültü 200 → 120 px (ayar).
- **R5 Gamepad çakışması**: sağ çubuk hem bakış hem tekerlek. 0,5 sn dondurma; alternatif tekerlek yalnız D-pad (karar gereken değil, test).
- **R6 Keşifte ping = bedava fotoğraf** [görüş]: ping 8 sn'de silinir, ikon üretmez; yine de "ping'le-hatırla" kasına izin verilir (kâğıt-kalem gibi, KR-004 engellemez).
- **R7 Ağ**: reliable kanalda etkileşim RPC'leriyle sıraya girer; ping küçük (~20 B), sorun beklenmez [varsayım]; kayıpta işaret gecikir, kaybolmaz.

## Karar gereken (kullanıcıya; en fazla 2)
1. "Kaç!" ve "Yardım!" mesajları gürültü üretsin mi (sahip duyar; **öneri evet**, bedel seçilmiş ve görünür) yoksa tüm iletişim sessiz mi?
2. Yakınlık sesi/telsiz: MVP dışı, Faz 6 adayı ve test-2'de "Discord sessiz turu" ile ihtiyaç ölçülsün (**öneri**) — kabul mü?

## Kaynaklar
[1] Apex Legends ping sistemi (UX analizi) — https://uxdesign.cc/apex-legends-ping-system-gaming-ux-done-right-4661cd94954c
[2] Apex ping tekerleği (7 seçenek; "burada biri vardı" ayrı) — https://apexlegends.wiki.gg/wiki/Ping
[3] Lethal Company telsiz ve yakınlık sesi (bilgi kaybı → komedi; telsiz el ister) — https://windowscentral.com/gaming/lethal-company-was-2023-best-indie-game-surprise-so-brilliant-cant-stop-playing
[4] Lethal Company: konuşma ve telsiz Eyeless Dog'u çeker — https://steamcommunity.com/app/1966720/discussions/0/4032472803479560478
[5] GodotSteam ses eğitimi (getVoice/decompressVoice, 48 kHz) — https://godotsteam.com/tutorials/voice/
[6] Godot `AudioEffectCapture` (mikrofon yakalama) — https://docs.godotengine.org/en/4.2/classes/class_audioeffectcapture.html · Godot-Opus GDExtension — https://www.godotengine.org/asset-library/asset/edit/3712
[7] Deep Rock Galactic lazer işaretçi (bağlamsal, ses satırı, duvar arkası çerçeve) — https://deeprockgalactic.wiki.gg/wiki/Laser_Pointer
[8] GTFO Bio Tracker (işaretleme 60 sn, 8,5 sn bekleme) — https://gtfo.wiki.gg/wiki/Bio_Tracker · Payday 3 "mark/shout ile ping ayrılsın" geri bildirimi — https://payday3.featureupvote.com/suggestions/468887/feedback-split-markshout-and-ping
[9] Monaco co-op: sesle bile online plan koordinasyonu zor — https://www.expertreviews.co.uk/technology/gaming/monaco-whats-yours-is-mine-review
Keep Talking, Door Kickers go-kodu, Hitman keşif: benzer-oyunlar.md §1 ve kesif-on-testi.md kaynakları.
