# Ad adayları — KR-013 ön taraması

Tarih damgası: 2026-10-02 · Kapsam: "Insiders" yerine kalıcı İngilizce ad (KR-013) · Yazan: araştırma ajanı (kod yok)

> **Hukuki görüş değildir.** Bu belge otomatik sorgu ve web aramasına dayanan bir ön elemedir. Benzerlik analizi (fonetik/görsel benzerlik, şekil markalar, tanınmış marka koruması) yapılmadı. Ad kesinleşmeden önce marka vekili/avukatıyla resmî araştırma gerekir.

## Özet

- "Insiders" elendi: Steam'de app 1488860 (2021) var; ayrıca USPTO'da 30, TMview'da 43 canlı kayıt var, 14'ü 9/28/41 sınıflarında (FR, BX ve US'de oyun/yazılım/eğlence).
- 30+ ad tarandı. Steam, itch.io, USPTO ve TMview'da (AB + TR + SE dahil) temiz çıkan ve kancayı taşıyanlar: **Mapless**, **Heistmind**, **Plan to Panic**, **Heist by Heart**, **Stringpullers**, **Sketchjob**.
- Öneri sırası: **1. Mapless** · **2. Heistmind** · **3. Plan to Panic** (yedek: Heist by Heart).

## Yöntem

| Kontrol | Nasıl | Sınır |
|---|---|---|
| Steam | `store.steampowered.com/api/storesearch` + `search/results?json=1` (ad ve boşluklu/bitişik yazım) | Mağazada görünmeyen/çıkmamış sayfalar ve SteamDB'deki gizli uygulamalar kapsanmadı |
| itch.io | `itch.io/search?q=` ilk sayfa başlıkları | Yalnız ilk sayfa |
| ABD marka | USPTO tmsearch arka uç API'si, kelime markası tam ifade; yalnız canlı kayıtlar; sınıf 9/28/41 süzgeci | Yalnız kelime; benzer yazımlar aranmadı |
| AB + ulusal (TR, SE dahil) | TMview (tmdn.org) arama API'si; EUIPO (EM), TÜRKPATENT (TR), PRV (SE) ve diğer ofis verileri | TMview kapsamı ofisin veri aktarımına bağlı |
| TÜRKPATENT doğrudan | **Kontrol edilemedi** (e-Devlet girişi gerekiyor); TR verisi yalnız TMview üzerinden | Resmî TR araştırması gerekli |
| Alan adı | .com: Verisign RDAP · .games: Identity Digital RDAP (404 = kayıtsız) · .gg: whois.gg | GoDaddy aracının sonuçları güvenilir değildi (kayıtlı .com'lara "müsait" dedi), kullanılmadı. Kayıtsız alan adı premium fiyatlı olabilir |
| Aranabilirlik | Web araması (ABD tabanlı motor, Google değil) ilk sayfa: ad tırnak içinde + "game" | Google TR/SE sonuçları farklı olabilir |

## Aday tablosu

Steam / itch: aynı ya da çok benzer adlı oyun. Marka: 9/28/41'de canlı kayıt (US = USPTO, TMv = TMview). Alan adı: .com / .gg / .games (✓ = kayıtsız, ✗ = kayıtlı). Arama: ilk sayfa doluluğu (boş = iyi).

| # | Ad | Çağrışım | Steam | itch.io | Marka (9/28/41) | .com/.gg/.games | Arama 1. sayfa |
|---|---|---|---|---|---|---|---|
| 1 | **Mapless** | "Harita yok" kancası | yok | 4 küçük proje (Godot jam oyunu dahil) | yok (US, TMv) | ✗/✓/✓ (maplessgame.com ✓) | Az dolu: jam oyunu, Valheim modu, iPhone navigasyon uygulaması |
| 2 | **Heistmind** | soygun + hafıza/zekâ | yok | yok | yok | ✗/✓/✓ (heistmindgame.com ✓) | Boş ("heist masterminds" sonuçları) |
| 3 | **Plan to Panic** | plan → kaos döngüsü | yok | yok | yok | ✓/✓/✓ | Boş |
| 4 | **Heist by Heart** | ezbere soygun (hafıza) | yok | yok | yok | ✓/✓/✓ | Romantik roman adları ("Heist of Hearts") |
| 5 | **Stringpullers** | kukla + perde arkası insider | yok | yok | yok | ✗/✓/✓ | Boş |
| 6 | **Sketchjob** | kroki + iş | yok | yok | yok | ✗/✓/✓ | Boş |
| 7 | Puppet Heist | kukla + soygun | yok | yok | yok | ✗/✓/✓ | Boş, ama ad betimleyici/jenerik |
| 8 | Unmapped | harita yok | yok | 6 küçük proje | yalnız AU (41, başvuru) | ✗/✓/✓ | Sözlük kelimesi, dolu |
| 9 | Heist Recall | hafıza | yok | yok | yok | ✓ (.com) | Boş |
| 10 | No Map Heist | harita yok | yok | yok | yok | ✓/✓/✓ | Boş; ad hantal |
| 11 | Casing Crew | "keşif yapan ekip" deyimi | yok | yok | yok | ✓/✓/✓ | Petrol kuyusu "casing crew" ile dolu |
| 12 | Hushjob | sessiz iş | yok | yok | yok | ✗/✓/✓ | Boş; "-job" bileşiği argo çağrışım riski |
| 13 | Heistory | heist + history | yok | 1 ("Cultural Heistory") | yok | ✗/✓/✓ | Arama "history"ye düzeltiyor |
| 14 | Velvet Crew | noir | yok | yok | yok | ✗/✓/✓ | 2026 filmi ("Velvet Gang") ve dizilerle dolu |
| 15 | Velvet Job | noir | yok | yok | US VELVETJOBS (41) | ✗/✓/✓ | Boş |
| 16 | Crookbook | dolandırıcı defteri | yok | yok | yok (ölü kayıt 1) | ✗/✓/✓ | Hapishane yemek kitabı |
| 17 | Blueprint Crew | plan + ekip | yok | yok | yok | ✓/✓/✓ | "Blueprint" çok kullanılan kelime |
| 18 | Kroki | TR "kroki", SE "kroki" (croquis) | yok | 2 benzer | **TR (41) KROKI APP**, DE (41), SK (41) | ✗/✓/✓ | Kropki oyunu vb. |
| 19 | Vaultmind | kasa + zihin | yok | yok | **EM, GB, BX (9)** | ✗/✓/✓ | — |
| 20 | Tipoff | insider ihbarı | yok | 1 aynı ad | **US TIPOFF (9, oyun şirketi), EM (9/41)** | ✗/✗/✓ | — |
| 21 | Chalkline | tebeşir kroki, noir | yok | 1 aynı ad | **US (9)** | ✗/✓/✗ | — |
| 22 | Off the Map | harita yok | yok | 3 | **FR (9/28/41), US/GB/AU (41)** | ✗/✓/✗ | Dolu |
| 23 | Stakeout | gözetleme | yok | 5 | **US/AU (9), US (41)** | ✗/✗/✓ | — |
| 24 | Three Shadows | 3 kişilik ekip | yok | yok | CN (41) | ✗/✓/✓ | Jenerik |
| 25 | Inside Job | insider | **var (4736090)** | 10+ | **Netflix (41), EM/GB/CA** | — | Netflix dizisi |
| 26 | Dead Drop | casus/noir | **var (587970)** | 10+ | — | — | — |
| 27 | Clean Getaway | soygun | **var (3747920)** | 4 | US (9) | — | — |
| 28 | Blindspot | kör nokta | **5+ oyun** | 10+ | **KRAFTON (9/41), Warner Bros.** | — | — |
| 29 | Mind Palace | hafıza sarayı | **var (2660570)** | 10+ | US/EM/CN (9/41) | — | — |
| 30 | Floorplan / Casebook / Lookout / Marionettes / Second Story / Last Look | çeşitli | **çok sayıda** | çok | — | — | Elendi |

## İlk 8 puanlama

1-5 ölçeği; "Çakışma" sütununda 5 = risk en düşük. Toplam en fazla 20.

| Sıra | Ad | Çağrışım | Akılda kalıcılık | Aranabilirlik | Çakışma | Toplam | Not |
|---|---|---|---|---|---|---|---|
| 1 | Heistmind | 4 | 4 | 5 | 5 | **18** | Hiçbir kaynakta kaydı yok; tür adın içinde. TR'de "heist" okunuşu ("hayst") Payday oyuncularına tanıdık |
| 2 | Mapless | 5 | 5 | 3 | 4 | **17** | Kanca birebir: "Harita yok." Küçük bir jam oyunu ve Valheim modu aynı adı taşıyor; markası yok |
| 3 | Plan to Panic | 4 | 4 | 4 | 5 | **17** | Döngüyü anlatıyor (plan → kaos), .com dahil hepsi boş. Ton noirdan çok komedi; 3 kelime |
| 4 | Heist by Heart | 4 | 3 | 4 | 5 | **16** | "By heart" = ezbere, keşif-hafıza mekaniğine tam oturuyor; "heart" romantik roman sonuçları getiriyor |
| 5 | Stringpullers | 4 | 3 | 4 | 5 | **16** | Kukla görseli + insider ("ipleri elinde tutan"). TR'de "string" iç çamaşırı çağrışımı yapıyor; 13 harf |
| 6 | Sketchjob | 4 | 3 | 4 | 5 | **16** | Kroki üzerinde plan. TR'de "skeç" komedi çağrışımı; İngilizcede "sketchy" (şüpheli) yan anlamı var, bu belki artı |
| 7 | Puppet Heist | 3 | 3 | 3 | 5 | **14** | Temiz ama betimleyici; marka gücü zayıf |
| 8 | Unmapped | 4 | 3 | 2 | 4 | **13** | Sözlük kelimesi, aranması zor; itch'te birkaç aynı ad var |

## 3 öneri

1. **Mapless.** Pazarlama kancasıyla aynı cümleyi söylüyor ("Harita yok. Sadece hatırladıklarınız var."), 7 harf, TR ve SE'de okunuşu sorunsuz. Steam'de oyun yok, USPTO ve TMview'da (EM/TR/SE dahil) kayıt yok. Risk: itch.io'da 2021 Godot jam oyunu "Mapless" ve bir Valheim modu var. İkisi de ticari değil, ama aramada rekabet ederler. mapless.com başkasına kayıtlı; .gg, .games ve maplessgame.com boş. Mağazada "Mapless" tek başına kullanılabilir; aranabilirlik için alt başlıklı bir sürüm de düşünülebilir.
2. **Heistmind.** Taranan adlar arasında en temizi: Steam, itch, USPTO, TMview ve web aramasında sıfır sonuç. Ad türü ("heist") ve hafıza/zekâyı birlikte veriyor; uydurma tek kelime olduğu için aranabilirliği en yüksek ve marka tescili en kolay olan bu. Zayıf yanı: kanca cümlesini Mapless kadar doğrudan söylemiyor. .com kayıtlı; .gg, .games ve heistmindgame.com boş.
3. **Plan to Panic.** "Planınız kusursuzdu. Kamera hariç." kancasının adı gibi; oyunun iki evresini (masada plan, sahada kaos) anlatıyor. .com, .gg ve .games üçü de boş; hiçbir kaynakta çakışma yok. Zayıf yanı: noir tondan çok komedi tonu taşıyor ve 3 kelime. Ton noirda kalacaksa yedek **Heist by Heart** (aynı temizlik, .com boş, hafıza kancası).

Karar gereken: adın tonu. Kanca/hafıza için Mapless, marka temizliği için Heistmind, komedi-kaos için Plan to Panic. Bu kullanıcı kararıdır (KR-013).

## Sonraki adımlar

1. Kullanıcı 1-2 ad seçer (KR-013). Seçimden önce TR ve SE arkadaş grubuyla 5 dakikalık okuma/hatırlama testi yapılabilir: adı bir kez söyle, ertesi gün sor.
2. **Resmî marka araştırması** (kullanıcı kararı ve parası): seçilen ad için TÜRKPATENT (doğrudan, e-Devlet ile), EUIPO ve USPTO'da benzerlik araştırması; marka vekili önerilir. Tescil başvurusu sınıf 9 (yazılım/oyun) ve 41 (eğlence hizmeti); önce TR + EUIPO (SE'yi kapsar), ABD sonra.
3. **Alan adı alımı** (kullanıcı parası): seçilen ad için en az bir .com türevi (ör. maplessgame.com / heistmindgame.com) ve .gg; fiyatları kayıt firmasında doğrula (.games premium olabilir).
4. Sosyal hesap ve kullanıcı adı kontrolü (X, YouTube, TikTok, Discord vanity, Reddit, Steam topluluk URL'si) yapılmadı; seçimden sonra aynı gün hepsi alınmalı.
5. Steamworks'te AppID açılmadan ve Coming Soon sayfasından en az 2 ay önce ad kesinleşmeli (steam-yayin.md Ö2). Mapless seçilirse itch'teki jam oyunu geliştiricisine nezaket bildirimi düşünülebilir (zorunlu değil).

## Kaynaklar

- Steam "Insiders": https://store.steampowered.com/app/1488860/
- Steam mağaza arama API'si: https://store.steampowered.com/api/storesearch/?term=Mapless&l=english&cc=US
- itch.io arama: https://itch.io/search?q=mapless · Mapless (jam oyunu): https://xalyndragon.itch.io/mapless
- Mapless Valheim modu: https://thunderstore.io/c/valheim/p/kidneybone/Mapless/
- Mapless iPhone uygulaması: https://www.iphone-ticker.de/mapless-und-nebel-der-welt-alternative-fussgaenger-navigation-175030/
- USPTO Trademark Search: https://tmsearch.uspto.gov/
- TMview (EUIPO/TMDN): https://www.tmdn.org/tmview/
- TÜRKPATENT marka araştırma: https://www.turkpatent.gov.tr/ (kontrol edilemedi)
- RDAP: https://rdap.verisign.com/com/v1/domain/ · https://rdap.identitydigital.services/rdap/domain/ · IANA RDAP listesi: https://data.iana.org/rdap/dns.json
- Çakışan oyunlar: Inside Job https://store.steampowered.com/app/4736090/ · Dead Drop https://store.steampowered.com/app/587970/ · Clean Getaway https://store.steampowered.com/app/3747920/ · Mind Palace https://store.steampowered.com/app/2660570/
- Proje bağlamı: docs/arastirma/tuzaklar.md, docs/arastirma/steam-yayin.md, docs/arastirma/pazarlama-satis.md
