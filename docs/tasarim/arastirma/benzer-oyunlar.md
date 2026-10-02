# Benzer oyunlar: mekanik analizi (tasarım araştırması, 1. tur)

Tarih: 2026-10-02 · Yazan: tasarim (Fable) · Durum: bağlayıcı değil; koordinatör ON/kaleme çevirir.
İşaretler: **[olgu]** kaynakta doğrudan yazan bilgi · **[görüş]** benim çıkarımım · **[oyuncu]** oyuncu yorumlarında yinelenen tema (vaporlens özetleri, Steam tartışmaları).
Kapsam: soygun / gizlilik / co-op / plan-keşif oyunları; her biri için bize ders (≤3) ve tuzak (≤2). Sonda dört odak sentezi: (a) 2D üstten okunabilirlik, (b) hafıza + plan masası emsalleri, (c) "plan bozulunca kaos" tasarımı, (d) 2 ve 4 oyuncu dengesi. Kaynaklar en sonda numaralı.

## 1. Oyun oyun

### Monaco: What's Yours Is Mine (2013) [1][2][3]
- [olgu] Üstten, yalnız görüş hattı görünür; 4 kişiye kadar co-op; sınıf başına tek yetenek. Schatz'ın tasarım yazısı: oyuncuya sunulan bilgi ve seçimler **durum tabanlı (dijital)** olmalı; "ışık VEYA gölge" iyi, kademeli ışık değeri kötü; ilk beşte bir ceza değil kaçışı öğretir; "polis-hırsız" PvP modu denge bozduğu için silindi.
- [olgu] PopMatters: 4 kişide oyun aksiyona kayar ("ölmek sorun değil", canlandırma var), solo'da gizliliğe; seviye tasarımı her sınıfın tıkandığı yerde alternatif rota (havalandırma, gizli geçit, üst kat) verir.
- Ders 1: Algı sinyallerini dijitalleştir. Şüphe ölçeri içeride 0-100 olabilir, ama oyuncuya üç durum olarak göster ("?", "!", tespit) ve ışığı "karanlık bölge: evet/hayır" yap (GDD §6.1'deki "ışık menzili kısar" yerine).
- Ders 2: Her tıkanma noktasında ≥1 alternatif rota garantisi (GDD §10 zaten söylüyor; Faz 2 bakkalında bile ön/arka kapı + pencere üçlemesi).
- Ders 3: Kaçış mekaniğini ilk seviyede öğret; bakkalda kaybetmek "polis geldi" değil "kaç" olmalı.
- Tuzak: Canlandırma yoksa 4 kişi aksiyona kayamaz, bir hata = herkes için bitiş → GDD §15 "yakalanma = iş biter" ile birleşince Faz 2 kapısı sertleşir (bkz. yol haritası çelişki 3).

### Monaco 2 (2025) [4][5][6]
- [olgu] İzometrik 3D, prosedürel seviyeler, 4 kişi online. Eleştirmen ortalaması 73; "temelde değişen az, grafik yenilenmiş"; prosedürel seviyeler "her koşu aynı hissettiriyor"; günlük soygun modunun oyun sonuna kilitlenmesi hata sayılmış.
- [oyuncu] Co-op övgüsü baskın (ağırlık 0,88); olumsuz: çökme/performans, Steam Remote Play'in kaldırılması, paket fiyatı olmaması.
- Ders 1: "Rastgele seviye" tek başına tekrar değeri yaratmıyor; GDD §10'daki "elle şablon + tohumla parametre" doğru yön. Tekrar değeri **zamansal/davranışsal** değişkenlikten gelmeli (devriye periyodu, kurye saati), yerleşimden değil.
- Ders 2: Arkadaş grubu ürünü için "arkadaşım satın almasın da oynasın" yolu (Remote Play, misafir slotu, 2+1 paket) satın alma kararını belirliyor → Faz 5/6 Steam sayfası kararı.
- Tuzak: Görsel yenileme > mekanik yenilik olduğunda "aynı oyun" algısı; bizde 3D geçişi (KR-003) mekanik değişiklikle birlikte gelmeli.

### Payday 2 (2013) [7][8]
- [olgu] Gizlilik ikili: tespit = tam gürültülü. Bedel kaynakları: 4 çağrı cihazı (pager) sınırı, ECM jammer, ceset torbası; tespit ölçeri gizlenme istatistiğiyle dolar. [oyuncu] "Kitaplığı bir metre oynatınca FBI çağıran bekçi" türü şikâyetler: tespit kuralları keyfi hissediliyor.
- Ders 1: Bütçelenmiş sarf kaynağı (4 pager) gizliliğe "kaç hata hakkım var" netliği veriyor; bizde eşdeğeri: iş başına N "bayıltma + telsiz cevabı" hakkı, ya da sindirilen sivil sayısı. Faz 2'de sayı küçük ve görünür olmalı (ör. 2).
- Ders 2: Tespit tetikleyicisi oyuncunun gördüğü nedene bağlanmalı ("kapıyı açık bıraktın" görünür bir ikon olmalı).
- Tuzak: İkili gizlilik + uzun soygun = tek hatayla 20 dk'nın çöpe gitmesi; GDD §6.2 kademeli uyarı bunun panzehiri, Faz 2'de 1-2 kademelerinin **geri dönüşü** mutlaka oynanabilir olmalı.

### Payday 3 (2023) [9][10]
- [olgu] Maskesiz "casing" kipinde kilit açma/eşya alma; özel alanda yakalanan maskesiz oyuncu bekçi eşliğinde dışarı çıkarılır (anında bitiş yok); tutuklanırsa bekçiler "arama" durumuna geçer; sadece 8 soygunla çıktı. [oyuncu] Gizlilik "daha mantıklı" diye övülüyor; baskın duygu hayal kırıklığı (%49) + bıkkınlık (%39): içerik azlığı, sunucu zorunluluğu.
- Ders 1: Kademeli sonuç ("dışarı çıkarılma" = ceza ama bitiş değil) oyuncuda "adil" algısı yaratıyor; bizde keşif fazı için birebir: oyalanan müşteriye "buyurun, kapanıyoruz" → dışarı; ikinci kez tanınma sayacı.
- Ders 2: Sağlam mekanik + az içerik = kötü lansman. MVP (2 kademe) arkadaş testi için yeter, Steam yayını için yetmez → yol haritası Faz 6 "içerik genişliği" sinyali.
- Tuzak: Çevrimiçi zorunluluk/sunucu bağımlılığı; bizde P2P host (KR-008) bu riski taşımıyor, korunmalı.

### Heat Signature / Tom Francis (2017; tasarım blogu 2014) [11][12]
- [olgu] "Non-stick plan": tasarım planı sözleşme değil pusula; kurulan sistem oynanınca teori değişir; belirsiz kısımları şablonlara böl ("hack'lenebilen = elektrikli ve bir şeye bağlı her şey"). Heat Signature'da durdur-plan yap-devam et ritmi; plan bozulunca araçlarla doğaçlama.
- Ders 1: Oyun içi plan da "yapışmaz" olmalı: plan katmanı iddia, gerçek farklı → fark anı oyun tarafından **cezalandırılmaz**, doğaçlama kaynağı olur (GDD §5 ile uyumlu).
- Ders 2: Doğaçlama için elde her an en az bir "kaçış aracı" (duman, ses yemi, pencere) olmalı; aksi halde plan bozulması = kayıp.
- Tuzak: Süreç dersi: GDD'yi fazla ayrıntılandırıp Faz 2-3 oyun testinden önce sayıları kilitlemek; sayılar data/*.tres'te kalsın, GDD aralık versin.

### Invisible, Inc. (2015) [13][14]
- [olgu] Sıra tabanlı prosedürel gizlilik; görünür alarm sayacı her birkaç turda kademe atlar, kademe geri dönmez; bilgi büyük ölçüde açık (görüş konileri, devriye yolu), gerilim bilgi eksikliğinden değil saat baskısından gelir.
- Ders 1: Küresel uyarı kademesi HUD'da **herkesin gördüğü tek sayaç** olmalı; bizde GDD §6.2'nin 0-5 merdiveni ekranda sabit bir "merdiven" olarak dursun; 3+ geri dönmez kuralı korunur.
- Ders 2: Prosedürel içerik "garanti"lerle ayakta durur (çıkış var, anahtar var); GDD §10 doğrulayıcı listesi doğru, Faz 3'te en az "gizli rota + zamansal bilgi" garantisi şart.
- Tuzak: Gerçek zamanda sürekli ilerleyen sayaç oyuncuyu acele ettirip keşif/gizliliği öldürür; bizde sayaç yalnız 3. kademede (sessiz alarm) başlamalı, 0-2'de yok.

### Teardown (2020) [15][16]
- [olgu] İki faz: sınırsız hazırlık (yıkım, köprü, araç), ilk hedef alınınca 60 sn alarm. Bir yıl prototip; "kaynak sınırı eğlenceli değil", "helikopter kovalamacası rastgelelik getirir, planlamayı caydırır" diye reddedildi; sayacı "oyuncunun kararıyla başlayan saat" olarak savunuyor; hazırlıkta tek kayıt slotu, alarmda kayıt yok.
- Ders 1: Saati **oyuncu başlatır**: bizde "masayı kapat" + ilk gürültü/ilk ganimet = saat; Faz 2 bakkalda "kasayı açmak" sayaç başlatıcı olabilir (tezgâhtar düğmesi).
- Ders 2: Rastgele ceza yerine deterministik baskı (GDD ilke 3 ile aynı); doğaçlama rastgelelikten değil eşzamanlı taleplerden doğmalı.
- Tuzak: Hazırlık fazı zamansızsa oyuncu "mükemmel plan"ı kurup gerilimi öldürür; bizde plan masası zamansız (GDD §5) → yumuşak sayaç önerisi (yol haritası).

### Hitman: World of Assassination (2016-2021) [17][18][19]
- [olgu] Tekrar oynayarak ustalaşma; "Mission Stories/Opportunities" sandbox içinde rehberli yol; kalıcı kısayollar (ikinci oynayışta açık kalan kapı/merdiven); ustalık seviyesi yeni başlangıç noktası/ekipman açar. GDC Europe 2016 konuşması: ilk seviyenin yeni oyuncu için **fazla zor** olması tutorial ve doğrusal rehberlik sorununu doğurdu.
- Ders 1: Keşfin ödülü kalıcı olabilir: aynı hedefi ikinci kez soyarken "bilinen kısayol" (insider ya da önceki keşif) → Faz 6 "tekrar iş" fikri; ısı/tanınma ile dengelenir.
- Ders 2: Bakkal = öğretmen; rehberli ilk iş ("insider sana söyler: arka kapı, 2 kamera yok") Faz 4/5'te gerekli.
- Tuzak: Rehberli fırsatlar sandbox'ı "tarif takip"e indirger; plan masası rehber değil boş kroki kalmalı (KR-004 kırmızı çizgi).

### Thief: The Dark Project (1998) [20][21]
- [olgu] Geliştirme 1,5 yıl sonra bile çalışmıyordu; oyuncular ne zaman gizli olduklarını anlamıyordu; çözüm **ışık taşı** (kendi görünürlüğünü gösteren UI + ses bileşeni). Muhafızlar çok kademeli farkındalık (şüphe, arama, kovalama) ve birbirine haber verme.
- Ders 1: Oyuncunun **kendi** görünürlük durumu her an okunmalı: karakter üstünde "gizli / açıkta" ikili rozet (karanlıkta + görüş hattı dışında = gizli). Faz 2'ye düşük maliyetli.
- Ders 2: Muhafız durumu sesle de taşınsın (homurdanma, "kim var orada?", telsiz) — 5-6 SFX listesine bu üçü girsin.
- Tuzak: Algı sistemini "gerçekçi" yapmaya çalışmak (Thief'in 5+ koni) oyuncunun modelleyemeyeceği bulanıklık üretir; bizde tek koni + mesafe bandı yeter.

### Mark of the Ninja (2012) [22][23][24]
- [olgu] Ses halkaları ekranda (çap = şiddet; halka içindeki duyar, dışındaki duymaz); ışık sert kenarlı; muhafız görüş konisi ve durum ikonu görünür; "tam bilgiyle anlık karar" felsefesi. Critpoints analizi: neredeyse ikili sistem, kısmi görülme konumu işaretler, muhafız bakar-vazgeçer.
- Ders 1: NoiseBus olaylarını **yarıçap halkası** olarak çiz (koşma adımı, kasa, kapı: S8 90/160 değerleri görünür hale gelsin); duvar azaltması halkayı kırpar.
- Ders 2: Kısmi görülme ("?") muhafızın baktığı noktayı dünyada işaretlesin (görüş çizgisi/soru işareti konumu) ki ekip "seni gördü mü" tartışmasına girmesin.
- Tuzak: Tam bilgi gizliliği bulmacaya çevirir, co-op'ta sohbet azalır; bizde bilgiyi **ekip görüşü paylaşımıyla** sınırlı tut (sadece görüş hattındaki halkalar görünür).

### GTFO (2019) [25][26]
- [olgu] "Herkese yapılan hiç kimseye" felsefesi; uyuyanlar ışık/hareket/gürültü eşiğiyle uyanır (ikili); gerçek koordinasyon zorunlu, çok sert.
- Ders 1: Kimlik netliği: bizim kimlik "arkadaşlarla planı bozulan soygun komedisi"; GTFO sertliği hedef kitle (25-45, akşam oturumu) ile çelişir → zorluk ayarı "arkadaşla ilk 3 koşuda en az biri başarılı" olmalı.
- Tuzak: Zorunlu koordinasyon + sert ceza = dar kitle; GTFO'nun bilinçli tercihi, bizim değil.

### Door Kickers (2014) / Ready or Not (2023) [27][28][29]
- [olgu] Door Kickers: duraklat-planla (rota çizimi, bakış yönü, go-kodları); co-op'ta oyun başlayınca yeniden duraklatılamaz → ya başta tam plan ya gerçek zaman. Ready or Not: tablet üzerinden planlama/komuta.
- Ders 1: "Go-kodu" fikri plan masasına ucuz ve güçlü: rotada bir düğüm "işaretle bekle" olur, soygunda host/herkes ping ile tetikler (GDD §5 tetik zinciri MVP sonrası; go-kodu daha basit, Faz 3 adayı).
- Ders 2: Co-op'ta oyun içi duraklama yok; plan ancak masa başında, sonrası ping/çizim. GDD ile uyumlu.
- Tuzak: Planlama arayüzü oyunun kendisi olursa (Masterplan tuzağı) doğrudan kontrol hissi kaybolur.

### Lethal Company (2023) / R.E.P.O. (2025) [30][31][32][33]
- [olgu] Lethal: yakınlık sesli sohbet; bilgi kayboluyor/yanlış anlaşılıyor → komedi; "sessizlik = kötü işaret"; organik yayılım, 10 milyon kopya. R.E.P.O.: fizikle taşınan kırılgan değerli eşya; "canavar köşeyi dönerken vazoyu düşüren arkadaş" = korku ve komedi aynı kaynaktan; 96% olumlu, 266 bin eşzamanlı.
- Ders 1: Kaos anı = **bilgi kaybı + fiziksel beceriksizlik**; bizde: çanta devri (0,3 sn el sıkışma), ağır/kırılgan ganimet, telsiz menzili. Faz 2'de çanta taşıma hız cezası + düşürme bile "klip" üretir.
- Ders 2: Kendi sesli sohbetimiz yoksa Discord'da konuşurlar ve bilgi kaybı sıfır olur → yakınlık sesi ya da "telsiz" mekaniği (gürültüde parazit) ayırt edici bir kaldıraç; kullanıcıya sorulacak.
- Tuzak: Fizik tabanlı komediye özenip ağ üzerinde fizik senkronuna girmek (host yetkili + 150 ms'de fizik nesneleri zor); çanta "durum" olarak kalsın, fizik değil.

### Keep Talking and Nobody Explodes (2015) [34][35]
- [olgu] Bilgi asimetrisi: biri bombayı görür, diğerleri kılavuzu; doğal dil tek koordinasyon kanalı; zorluk modül öğrenme + verimli konuşma dili geliştirme.
- Ders 1: Asimetri **tamamlamak için zorunlu** olmalı: Tech kamera döngü sayacını yalnız kendi görür, Ghost kapıda yalnız kendi geçebilir → biri söylemeden diğeri yapamaz (GDD §7.2 çift anahtar anı = bunun mekanik hali; T1'de bile hafif bir örnek olmalı).
- Tuzak: Asimetri aşırıysa "benim ekranımda hiçbir şey yok" sıkıntısı; herkesin her an bir işi olmalı (GDD §4.1 "kimse boş beklemez").

### Shadows of Doubt (2023) [36][37]
- [olgu] Mantar pano: oyuncu kanıtı iğneler, çizgiyle bağlar, not yazar; "bariz bağlantıları" (kurban-adres) oyun otomatik çizer; suçlama zinciri otomatik hesaplanır; bazı şeyler oyuncu hafızasında kalır.
- Ders 1: Plan masasında otomasyon sınırı: **yapısal** şeyler hazır (duvar, kapı boşluğu), **güvenlik** asla; küçük kolaylıklar (ikon odaya yapışır, aynı ikon ikinci kez konursa "çift mi?" sormaz) kabul.
- Tuzak: Pano arayüzü zorlaşınca oyuncu panoyu bırakıp kafasında tutar; masa çizimi 3 araçtan fazla olmasın (ikon, çizgi, not).

### The Masterplan (2015) [38][39]
- [olgu] Üstten 70'ler soygun; yavaşlat + komut ver; karışık eleştiri: "point-and-click komuta mekaniği sürükleyiciliği öldürdü"; ortalama oynama ~3 saat.
- Ders: Doğrudan kontrol vazgeçilmez; planı kurma ile uygulama farklı ekranlarda (masa / soygun) olmalı, soygun içinde komut arayüzü olmamalı.
- Tuzak: Üstten soygun türünün tek örneklerinden biri "sığ içerik" ile unutuldu; tür boşluğu var ama içerik derinliği şart.

### Deep Rock Galactic (2018) — ölçekleme emsali [40]
- [olgu] Düşman sayısı çarpanı (Hazard 5): 1 oyuncu 0,85 · 2 → 0,85 · 3 → 1,25 · 4 → 1,50; solo-2 arası artış küçük (bot Bosco'nun yokluğunu telafi için). [oyuncu] 2 kişide biri düşünce ekibin %50'si gidiyor → daha cezalandırıcı.
- Ders: Ölçekleme **doğrusal değil** parçalı: 2 kişi = 3 kişiden belirgin hafif (talep −1, pencereler ×1,5), 4 kişi = +1 talep değil +1 eşzamanlı akış. GDD §11'deki doğrusal formül yerine tablo (bkz. sentez d).

### Thick as Thieves (2026, OtherSide/Spector) — ufuktaki komşu [41][42]
- [olgu] 4 oyunculu "çok oyunculu immersive sim", kısa tekrar oynanabilir soygunlar, oyuncular aynı dünyada rakip hırsızlar (PvPvE), masaüstü RPG doğaçlama hissi hedefi.
- Ders: Rekabetçi hırsız alanı dolacak; bizim ayrışma co-op + hafıza + plan masası; "rekabetçi mod" fikrine hayır demenin bir nedeni daha.

## 2. Odak sentezleri

### (a) 2D üstten gizlilikte görüş/ses okunabilirliği
Olgu tabanı: Monaco (yalnız görüş hattı), MGS1 (radar üstüne koni), Volume (1:1 koni, belirsizlik yok), Shadow Tactics (üç bölgeli koni: yakın = anında, uzak = çömelirsen gizli, noktalı = sığınak), Mark of the Ninja (ses halkası), Thief (ışık taşı) [1][22][24][20].
[görüş] Faz 2 için önerilen paket (hepsi ucuz, görsel katman):
1. Koni iki bantlı: **yakın bant** (0-3 karo, 96 px): dolum ×2; **uzak bant** (3-8 karo): ×1; 8+ karo görmez. Bantlar farklı saydamlıkta çizilir.
2. Dolum formülü (öneri, data/*.tres): `dolum/sn = 25 × bant × durum`; durum: koşma 2,0 · yürüme 1,0 · sızma 0,5 · karanlık bölge 0 (ikili, Schatz) · çanta +0,5. Örnek: koşan oyuncu yakın bantta 100/sn → 1 sn'de tespit (Faz 2 çıkış kriteri ile uyumlu); sızan uzak bantta 12,5/sn → 8 sn. Boşalma 20/sn (görüş dışı).
3. Eşikler 30/60/100 üç ikona: "?" (bakar, 0,5 sn pencere), "!" (inceler, yürür), tespit (telsiz). "?" anında muhafızın baktığı nokta dünyada işaretlenir.
4. Ses: her NoiseBus olayı halka (çap = yarıçap, 0,4 sn sönümlenir); duvar halkayı kırpar; sadece ekip görüşündeki halkalar çizilir.
5. Oyuncu rozeti: "gizli/açıkta" ikili (karanlık ∧ görüş hattı dışı).
6. Kabul kriteri (otomatik): 100 bot koşusunda "tespit edildi ama hiç '?' görmedim" olayı 0; tespitlerin ≥ %95'i yakın bant ya da koşma kaynaklı.

### (b) Hafızaya dayalı keşif ve ortak plan masasının emsalleri
Olgu tabanı: doğrudan emsal **yok** (bu iyi haber: boşluk). Yakın akrabalar: Keep Talking (asimetri + konuşma), Shadows of Doubt (pano, otomasyon sınırı), Door Kickers (rota + go-kodu), Hitman (tekrarla ustalaşma, kalıcı kısayol), GTA V (hazırlık görevleri anticipation yaratıyor) [34][36][27][17][43].
[görüş] Çıkarımlar:
- Hafıza oyunu "sınav" gibi hissetmemeli: ikon yanlışsa ceza yok, sadece plan bonusu düşer; iş sonu "plan doğruluğu" özeti öğretir (Hitman ustalık mantığı) → açık soru 3'e öneri: **göster, ama yalnız iş sonunda**.
- Değerli bilgi zamansal: ikon paletinde "zaman notu" birincil araç olmalı; Faz 3 ölçütü "ikon doğruluğu" yanına "zaman notu doğruluğu ±10 sn" eklensin.
- Asimetri tasarımla zorunlu: içerideki yalnız iç yerleşimi, dışarıdaki yalnız dış periyotları görür; plan masasında ikisi birleşmeden rota çizilemez.
- Go-kodu (Door Kickers): rotada "bekle" düğümü + soygunda ping ile serbest bırakma; tetik zincirinin %20 maliyetli %80 faydalı hali.
- Masa süresi: Teardown dersi (zamansız hazırlık gerilimi öldürür) ↔ GDD "zamansız" → yumuşak sayaç: 3 dk görünür, aşınca aracı bonusu −%1/30 sn; host uzatabilir.

### (c) "Plan bozulunca kaos" anlarını tasarlamak
Olgu tabanı: Lethal Company (bilgi kaybı), R.E.P.O. (fiziksel beceriksizlik), Monaco (sınıf tıkanması → alternatif rota), Heat Signature (araçla doğaçlama), Teardown (saati oyuncu başlatır, rastgele ceza yok), Payday 3 (kademeli sonuç) [30][31][2][11][15][9].
[görüş] Kaos "tasarlanır": rastgele değil, **eşzamanlı talep + bilgi kaybı + geri dönüşlü ceza** üçlüsü. Faz 2 bakkal için üç tetik:
1. Tezgâhtar düğmesi: sindirilmezse 8 sn sonra basar → sessiz alarm sayacı (90 sn) — saat oyuncunun ihmaliyle başlar.
2. Devriye polisi periyodu (ör. 75 sn ± 10) keşifte öğrenilebilir tek zamansal bilgi; soygunda arka kapıdan çıkanı yakalar.
3. Çanta: taşıyan sızamaz/koşarsa düşürür (gürültü halkası 160), devir 0,3 sn — fiziksiz "fumble".
Kaybetme komik olsun: yakalanan oyuncu donar ve "kefalet" olarak iş sonu ekranında görünür; diğerleri 60 sn içinde kaçarsa iş kısmi başarı (GDD §3.5 ile uyumlu, §15 ile çelişiyor — yol haritası çelişki 3).
Ses: Discord dışı bir kanal yoksa bilgi kaybı olmaz → "telsiz" (oyun içi kısa sohbet/ping; gürültüde parazit) ya da yakınlık sesi kullanıcı sorusu.

### (d) 2 ve 4 oyuncuda dengeleme
Olgu tabanı: DRG çarpan tablosu (1≈2 < 3 < 4; solo bot telafisi), Overcooked (2 kişide bazı seviyeler haksız), Monaco (4 kişi aksiyon, solo gizlilik) [40][44][2].
[görüş] Gerçek grup 2 İsveç + 1 Türkiye: en sık **2 kişi** oynanacak (saat farkı, müsaitlik). Bu yüzden 2 kişi "düşürülmüş 3" değil birincil kip olmalı. Öneri tablosu (GDD §11 doğrusal formül yerine):

| Oyuncu | Muhafız/kamera | Çift anahtar | Pencereler | Çanta/ganimet | Keşif rolü |
|---|---|---|---|---|---|
| 2 | taban −1 | sıralı (ardışık 2 işlem) | ×1,5 | ×0,8 | içerideki + dışarıdaki |
| 3 | taban | eşzamanlı | ×1,0 | ×1,0 | + hat (MVP sonrası) |
| 4 | taban +1 **ve** +1 talep akışı | eşzamanlı + üçüncü el | ×0,9 | ×1,25 | ikinci içerideki (tanınma riski paylaşımı) |

Ödeme kişi başı: 2 kişide toplam ×0,8 ama kişi başı daha yüksek (teşvik); 4 kişide toplam ×1,25, kişi başı hafif düşük. Bot yoldaş (MVP sonrası) 2 kişide üçüncü eli doldurunca tablo 3'e döner. Kabul kriteri: otomatik bot koşularında 2/3/4 kişide temiz tamamlama oranı birbirinden ≤ 15 puan sapar.

## 3. Kaynaklar
[1] https://www.gamedeveloper.com/business/doing-stealth-the-i-monaco-i-way (Schatz, 2012)
[2] https://popmatters.com/172043-monaco-2495751898.html
[3] https://en.wikipedia.org/wiki/Monaco:_What%27s_Yours_Is_Mine
[4] https://www.slantmagazine.com/games/monaco-2-review/
[5] https://opencritic.com/game/18260/monaco-2
[6] https://vaporlens.app/app/1063030/monaco_2.md (oyuncu yorumu temaları)
[7] https://payday.fandom.com/wiki/Chameleon · https://payday.fandom.com/wiki/Social_Stealth
[8] https://steamcommunity.com/app/218620/discussions/8/1457328392108596521
[9] https://gamesradar.com/payday-3-hands-on
[10] https://vaporlens.app/app/1272080/payday_3/stats
[11] https://pentadact.com/2014-01-25-game-design-the-non-stick-plan
[12] https://affectionatediscourse.substack.com/p/heat-signature-the-definitive-review
[13] https://gdcvault.com/play/1021919/Designing-Procedural-Stealth-for-Invisible (Lantz, GDC 2015; içerik üye kilitli, özet ikincil kaynaklardan)
[14] https://80.lv/articles/invisible-inc-interview/
[15] https://blog.voxagon.se/2020/11/05/teardown-design-notes.html
[16] https://get-teardown.readthedocs.io/en/latest/gameplay/heist-basics.html
[17] https://pcgamer.com/hitman-3-review
[18] https://gamedeveloper.com/business/gdc-europe-2016-debuts-i-hitman-i-daglow-as-first-sessions
[19] https://gdcvault.com/play/1025879/Level-Design-Workshop-Hitman-Levels (GDC 2019)
[20] https://www.gamedeveloper.com/design/building-the-original-i-thief-s-i-revolutionary-stealth-system
[21] https://en.wikipedia.org/wiki/Thief:_The_Dark_Project
[22] https://popmatters.com/166432-mark-of-the-ninja-2495791612.html
[23] https://gdcvault.com/play/1017791/Of-Choice-and-Breaking-New (Anderson, GDC 2013)
[24] https://critpoints.net/2015/03/30/stealth-game-spotting-deconstruction/
[25] https://primagames.com/featured/gtfo-developers-warn-their-hardcore-co-op-shooter-isnt-for-everyone
[26] https://www.nme.com/reviews/gtfo-review-3122718
[27] https://en.wikipedia.org/wiki/Door_Kickers
[28] https://steamcommunity.com/app/248610/discussions/0/1489992080505135811/?ctp=2
[29] https://readyornot.wiki.gg/wiki/Ready_or_Not
[30] https://gameindustrylibrary.com/documents/pushtotalk-how-lethal-company-sold-10-million-copies
[31] https://cogconnected.com/feature/what-makes-lethal-company-so-good/
[32] https://yourstory.com/2025/03/everyones-playing-repo-addictive-indie
[33] https://www.purexbox.com/news/2025/03/repo-explodes-in-popularity-on-pc-leading-to-calls-for-an-xbox-version
[34] https://igf.com/content/keep-talking-and-nobody-explodes
[35] https://arxiv.org/pdf/2606.28514 (asimetri ve dil üzerine kıyaslama çalışması)
[36] https://colepowered.com/?p=33958 (DevBlog #4: Case Folders & Cork Boards)
[37] https://gamingtrend.com/shadows-of-doubt-early-access-preview-shining-a-light-on-the-truth
[38] https://www.gamespot.com/reviews/the-masterplan-review/1900-6416170/
[39] https://rawg.io/games/the-masterplan
[40] https://deeprockgalactic.wiki.gg/wiki/Hazard_Level (ölçekleme tablosu)
[41] https://gamingbolt.com/thick-as-thieves-interview-replayability-immersive-sims-co-op-design-and-more
[42] https://gamesbeat.com/warren-spectors-otherside-entertainment-unveils-thick-as-thieves/
[43] https://gta.fandom.com/wiki/Heist_Setups
[44] https://steamcommunity.com/app/448510/discussions/0/353916184355403084 (Overcooked 2 kişi dengesi)
[45] https://www.pcgamer.com/uk/volume-duping-guards-in-a-tense-tactical-sneak-em-up
[46] https://amara.org/v/C3BDw (School of Stealth Part 1: muhafız görme/duyma; Shadow Tactics üç bölgeli koni)
