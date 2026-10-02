# Tasarım yol haritası: Faz 2-5 ve MVP sonrası (tasarım araştırması, 1. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: öneri, bağlayıcı değil; karar koordinatör/kullanıcıda.
Dayanak: GDD v0.1, backlog §1 faz planı (KR-015), kararlar.md (KR-001..018), benzer-oyunlar.md (bu dizin). Kaynak numaraları benzer-oyunlar.md §3'e gönderir.
Yöntem: her faz için **eğlence hipotezi** (tek cümle, test edilebilir), **en riskli varsayım**, **en ucuz doğrulama deneyi**, **kesilebilir/ertelenebilir**. Kısıt: tek kişi + AI ajanlar + sanatçısız + 3 kişilik online (2 SE, 1 TR, en sık 2 kişi müsait).

## 0. Genel ilkeler (araştırmadan süzülen)
1. Her faz tek bir soruya cevap verir; cevabı ölçmeden sonrakine geçilmez ("find the fun" en kaotik aşamadır, çoğu proje burada ölür) [1].
2. Sayılar GDD'de aralık, `data/*.tres`'te değer; plan "yapışmaz" (Francis) [11]. GDD'yi oyun testinden önce kilitleme.
3. Rastgele ceza yok; baskı deterministik ve oyuncunun tetiklediği saatle gelir (Teardown) [15].
4. Bilgi dijital gösterilir (Schatz): üç durum, ikili ışık, görünür halka [1].
5. 2 kişi birincil kip (grup gerçeği); 3 merkez, 4 bonus. Doğrusal ölçekleme yerine tablo (benzer-oyunlar §2d).

## 1. Faz 2 — Gizlilik (ilk "eğlenceli mi" kapısı)
**Eğlence hipotezi:** Üç arkadaş bakkalı sessiz soymaya çalışırken muhafızın "?"→"!"→tespit geçişini okur, 150 ms'de "beni görmemişti" demez ve yakalanınca güler; 3 koşunun ≥ 2'sinde "bir daha" der.
**En riskli varsayım:** Kademeli şüphe (0-100, 30/60/100) gerçek zamanda ve 150 ms gecikmede **adil hissedilir**. İkinci risk: "yakalanma = iş biter" (GDD §15) 3-5 dk'lık bakkalda bile ani ve sinir bozucu bitiş üretir.
**En ucuz deney:**
- D2.1 Spotting günlüğü: her tespit olayı için (mesafe bandı, kip, ışık, "?"den tespite geçen süre, oyuncu RTT) döküm; 100 bot koşusu (GB-01) + 3 arkadaş koşusu. Kabul: "? görmeden tespit" = 0; bot koşularında tespitlerin ≥ %95'i yakın bant ya da koşma kaynaklı.
- D2.2 Tek soru anketi (koşu sonu): "Yakalandığında adil miydi? (1-5)" ve "Ne yüzünden yakalandın?" — oyuncu nedeni **doğru söylüyorsa** sistem okunur.
- D2.3 Kayıp süresi: koşu başlangıcından yakalanmaya medyan süre < 90 sn ise bitiş çok sert → kefalet/kaçış kuralı (aşağıda) açılır.
**Mekanik öneriler (ucuz, Faz 2):**
- İki bantlı koni + dolum formülü + ikili karanlık (benzer-oyunlar §2a); oyuncu "gizli/açıkta" rozeti (Thief ışık taşı) [20].
- Ses halkaları ekranda (Mark of the Ninja) [22]; "?" anında muhafızın baktığı nokta işaretli.
- Uyarı merdiveni HUD'da sabit 0-5 (Invisible Inc. sayacı) [13]; 0-2 geri döner, sayaç yalnız 3'te başlar.
- Yakalanma kuralı (öneri, karar gereken): yakalanan donar + "kefalet" ödemesi; kalanlar 60 sn içinde kaçarsa iş kısmi başarı; herkes yakalanırsa biter. 2 kişide bu kural olmadan oyun aşırı kırılgan (DRG dersi) [40].
- Bütçelenmiş hata hakkı görünür: sindirilebilecek sivil 1 (tezgâhtar), "düğme" 8 sn gecikmeli (Payday pager mantığı) [7].
**Kesilebilir/ertelenebilir:** replay (girdi günlüğü) → Faz 3; kamera-statik-muhafız → benzinlikle Faz 4'e (algı kodu aynıysa Faz 2'de yalnız sınıf iskeleti); 5-6 SFX yerine 3 (telsiz, "?", alarm); karakter kuklası v0 Faz 2'de yalnız oyuncu + muhafız (tezgâhtar statik).
**Çıkış kriteri notu:** "Koşan oyuncu koni içinde ≤ 1 sn'de tespit" yalnız **yakın bant** için doğru olmalı; uzak bantta koşan 2 sn, sızan 8 sn. Kriteri "yakın bantta koşan ≤ 1 sn, uzak bantta sızan ≥ 6 sn, karanlıkta hiç" diye üçlemek öneririm.

## 2. Faz 3 — Keşif ve plan (ikinci kapı: özgün iddia)
**Eğlence hipotezi:** Ekip 4-8 dk keşif + 2-4 dk masa sonrası soyguna girince plan katmanıyla gerçeğin farkı **gülünür ve konuşulur** bir an üretir; ≥ 2/3 oyuncu "keşif değdi" der ve ikon doğruluğu ikinci koşuda birinciden yüksektir (öğrenme var).
**En riskli varsayım:** Oyuncular hafızaya dayalı keşfi sınav gibi değil oyun gibi yaşar; keşfi atlamaz (bakkalda camdan bakmak yeter, o yüzden Faz 3 testi **benzinlik** üzerinde olmalı — ama benzinlik Faz 4'te; bkz. çelişki 5). İkinci risk: zamansız masa sürüklenir, 10 dk tartışma.
**En ucuz deney:**
- D3.0 (Faz 2 içinde, backlog'da var) "ucuz keşif ön testi": 60 sn gözlem → krokiye ikon; ölçüm: ikon doğruluğu ve **zaman notu doğruluğu ±10 sn**. Kabul: 3 oyuncunun birleşik krokisi tek oyuncudan ≥ %20 doğru (ekip hafızası > bireysel) — değilse asimetri yeniden tasarlanır.
- D3.1 A/B: iş sonu "plan doğruluğu" özeti var/yok, iki oturum; ölçüm: ikinci koşuda doğruluk artışı ve anket "öğretici mi, ezber mi". Açık soru 3 bununla kapanır.
- D3.2 Masa süresi: 3 dk yumuşak sayaç var/yok; ölçüm: masa süresi medyanı ve plan bonusu alma oranı.
**Mekanik öneriler:**
- Asimetri zorunlu: içerideki iç ikonları, dışarıdaki periyotları koyabilir; rota ancak ikisi varken çizilir (Keep Talking) [34].
- Go-kodu: rota düğümü "bekle"; soygunda ping ile serbest (Door Kickers) [27]; tetik zincirinin ucuz hali.
- Plan katmanı: yanlış ikon solmaz (açık soru 7 → **solmaz**; fark oyuncunun); doğruluk yalnız iş sonunda (Hitman ustalık) [17].
- Keşif bedeli kademeli: oyalanan müşteri önce "kapanıyoruz" ile dışarı çıkarılır (Payday 3 eşlik) [9], ikinci ziyarette tanınma sayacı.
**Kesilebilir/ertelenebilir:** fotoğraf (3 kare) → Faz 4; şablon/modül üretici (KR-018 B) → yalnız tohumlu parametreler (kamera yeri, tezgâhtar, polis periyodu) Faz 3'te, modül birleşimi Faz 6; ajan oyun testi düzeneği (GB-01) → Faz 3 sonu, keşif-plan oynanabilir olduktan sonra.

## 3. Faz 4 — Sığınak ve ikinci kademe
**Eğlence hipotezi:** Para → ekipman → "T2 kilit artık açılıyor" kapısı "bir iş daha" isteği yaratır; benzinlikte kamera/DVR/sahte kamera yeni bir karar katmanı ekler ve keşif değeri hissedilir (hangi kamera gerçek).
**En riskli varsayım:** İki kademelik ekonomi ilerleme hissi için yeter (4-6 eşya, 2 iş tipi). Monaco 2 dersi: içerik sığsa "aynı hissediyor" [4]. İkinci risk: ısı sistemi iki kademede görünmez kalır.
**En ucuz deney:**
- D4.1 Ekonomi tablo simülasyonu (kod yok, hesap tablosu + bot koşusu ödeme dağılımı): 6 iş sonunda dükkânın tamamı alınabiliyorsa fiyatlar düşük; ≥ 10 işte alınamıyorsa yüksek. Hedef: 4-6 işte Alet A+B + 1 gadget.
- D4.2 Isı görünürlüğü: ısı > 40'ta muhafız +1 **ve** HUD'da ısı; anket "ısı kararını değiştirdi mi".
**Mekanik öneriler:** sahte kamera keşifte "mercek parıltısı yok" ipucuyla ayırt edilsin (dedektör T5); DVR silme = Tech için ilk gerçek asimetri (yalnız o görür); insider v0 teklifi "DVR odası nerede" (eski olabilir).
**Kesilebilir/ertelenebilir:** perk ağacı v0 → 3×2 düğüm (3×3 yerine); ton altyapısı iskeleti → doğrulayıcı testi yeter, ikinci tema yok; CC0 asset geçişi → yalnız zemin/duvar, karakterler kukla kalır (KR-017).

## 4. Faz 5 — Steam ve MVP paketi
**Eğlence hipotezi:** Davetle ≤ 10 sn'de lobi ve TR↔SE 30 dk kopmasız oturum; arkadaşlar üç oturum sonunda "ne zaman yeni iş?" diye sorar.
**En riskli varsayım:** SteamMultiplayerPeer relay'i TR↔SE'de 150 ms profilinin içinde kalır; Faz 2 Steam spike bunu erken ölçer (zaten planlı). İkinci risk: içerik 2 kademe → "tekrar" isteği Faz 6 kararına kanıt üretmez.
**En ucuz deney:** Faz 2 spike (480 lobisi + 2 kişi) + Faz 5'te 3 oturum yazılı geri bildirim (zaten kriter). Ek: "bir sonraki ne olsun" tek soru → Faz 6 sinyali.
**Kesilebilir:** Steam Cloud profil (JSON yerel yeter); itch gizli build (Steam build yeterli).

## 5. MVP sonrası (Faz 6+): yön seçenekleri ve sinyaller
| Yön | Ne | Sinyal (hangi kanıt bu yöne iter) | Maliyet |
|---|---|---|---|
| A İçerik genişliği | T3 kuyumcu + T4 depo (çift anahtar, devriye rotası, ağır ganimet) | Arkadaşlar bakkal+benzinliği ≥ 6 kez oynayıp "sonraki ne" diyor; Payday 3 "8 soygun" dersi [10] | orta-yüksek |
| B Tohumlu çeşitlilik | Şablon/modül üretici + doğrulayıcı; zamansal parametre çeşitliliği | "Aynı hissediyor" şikâyeti 2 şablonla bile geliyor; Monaco 2 dersi: yerleşim değil davranış değişsin [4] | orta |
| C Rol/ekipman derinliği | Perk 3×6, gadget seti, kılık, hat rolü | Oyuncular hep aynı loadout/rolü alıyor; "Tech sıkıcı" notu | orta |
| D Sosyal kanal | Oyun içi telsiz/yakınlık sesi, insider diyalogları, iş sonu "klip" özeti | Koşu sonrası anlatılan an sayısı düşük; Discord'da konuşunca bilgi kaybı sıfır (Lethal dersi) [30] | yüksek (ses), düşük (telsiz/özet) |
| E Bot yoldaş + solo/2 kişi | Rol botu (takip/taşı/gözetle) | Oturum iptal oranı yüksek (3 kişi nadiren bir arada); 2 kişi koşuları 3'ten belirgin düşük başarı | orta |
| F 3D geçişi | Mantık aynı, görsel katman 3D (KR-003) | Steam sayfası/wishlist'te "görsel" şikâyeti; mekanik beğeni yüksek | yüksek |
| G Rekabetçi mod | — | **Yok**: Monaco PvP'yi sildi [1], Thick as Thieves alanı dolduruyor [41]; ayrışmamız co-op + hafıza | — |

Önerilen sıra (sinyal yoksa varsayılan): **E (küçük) → A → B**, D'nin ucuz kısmı (iş sonu özeti + telsiz) A ile birlikte. Gerekçe: grup gerçeği 2 kişi; içerik olmadan B'nin ölçülecek bir şeyi yok.

## 6. GDD / faz planı ile çelişki ve eksikler (öneri; karar koordinatör/kullanıcıda)
1. **Işık analog mı ikili mi** — GDD §6.1 "karanlık bölge menzili kısar" (analog) ↔ Schatz "ışık VEYA gölge" [1]. Öneri: Faz 2'de ikili karanlık bölge; analog ışık ancak T4 depo (ışık-karanlık mekaniği) gelince.
2. **Ölçekleme formülü** — GDD §11 doğrusal `taban + (oyuncu−3)×k` ↔ DRG parçalı tablo [40]. Öneri: benzer-oyunlar §2d tablosu; 2 kişi birincil kip.
3. **Yakalanma sonucu çelişkisi** — GDD §3.5 "geride kalan yakalanır (kefalet)" ↔ §15 "yakalanma = iş biter". Öneri: §15'i "yakalanan donar + kefalet; kalanlar 60 sn'de kaçarsa kısmi başarı" yap (Faz 2). Karar gereken.
4. **Faz 2 çıkış kriteri "≤ 1 sn tespit"** — GDD 30/60/100 + "?" ≥ 0,5 sn + inceleme ile yalnız yakın bant için tutarlı. Öneri: kriteri bantlara göre üçle (§1).
5. **Keşif testi hangi seviyede** — Faz 3 keşif ölçümü bakkalda anlamsız (GDD §4.7: camdan bakmak yeter) ama benzinlik Faz 4'te. Öneri: Faz 3'e benzinlik **kabuğu** (kamera yerleri tohumlu, DVR yok) alınsın ya da bakkala tohumlu "arka oda kasası yeri + polis periyodu" eklenip keşif değeri yapay yükseltilsin. Karar gereken.
6. **Plan masası zamansız** — GDD §5 ↔ hedef 2-4 dk ve Teardown dersi [15]. Öneri: 3 dk yumuşak sayaç + host uzatır; D3.2 ile ölçülür.
7. **Sesli iletişim GDD'de yok** — Lethal/R.E.P.O. dersi: bilgi kaybı kaos kaynağı [30][31]. Öneri: GDD §11'e "iletişim" alt bölümü: ping + kısa telsiz (MVP), yakınlık sesi (Faz 6 D). Kullanıcı sorusu.
8. **Onboarding yok** — Hitman ilk seviye dersi [18]. Öneri: GDD §15'e "rehberli ilk iş" (insider ipuçlu bakkal) Faz 5; MVP'de arkadaşlara kullanıcı anlatıyor, Steam'de anlatamayacak.
9. **Hata bütçesi görünmez** — Payday pager dersi [7]. Öneri: GDD §6.3'e "iş başına görünür hata hakkı" (sindirme sayısı, bayıltma sayısı) kavramı; Faz 2'de 1-2.
10. **Açık soru 3/7 kapanış önerisi** — doğruluk iş sonunda gösterilir; ikon solmaz (D3.1 ile doğrulanır).
11. **Host göçü (açık soru 8)** — MVP'de "host düşerse iş biter + kefalet yok" yeterli; Faz 6 E ile birlikte ele alınsın.
12. **Fotoğraf (3 kare)** MVP içinde (§15) ama Faz 3 kalemlerinde yok → ya Faz 3'e kalem ya §15'ten çıkar.

## 7. İkinci tur araştırma adayları
- Muhafız durum makinesi emsalleri: Thief/Dishonored/Shadow Tactics "arama" davranışı süreleri (kaç saniye arar, ne zaman vazgeçer) — Faz 2 ayar değerleri için.
- Co-op oyunlarda bağlantı kopması/geri katılma tasarımları (Valheim, DRG, Monaco 2 Remote Play şikâyeti) — Faz 5.
- "Klip anı" tasarımı: Lethal/R.E.P.O./Content Warning'in kaydedip paylaşma mekanikleri; iş sonu özet ekranı emsalleri.
- Ekonomi ve ilerleme hızı: Payday 2 / Deep Rock / Monaco 2 kazanç eğrileri; T1-T2 için fiyat kalibrasyonu (Faz 4).
- Yakınlık sesli sohbet: GodotSteam voice API + 150 ms'de uygulanabilirlik (teknik, koordinatöre).
- Üstten 2D ışık/gölge okunabilirliği: Darkwood, Monaco, Teleglitch örnekleri (sanatçısız görsel yön, Faz 2/4).
