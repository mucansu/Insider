# Fable danışması — GB-12 (bağırıştan sonra örtüsü sağlam müşteri; tutma/yakalanma okunurluğu)

2026-10-06, tasarim ajanı (Fable). Kaynak: GB-12 satırı, `docs/surec/olcum/20261006-gb12-kayit-{host,c1}.json`, `core/civilian_rules.gd`, `data/npc/{civilian,owner,chaser}_tuning.tres`, `ui/hud.gd`, `ui/escape_panel.gd`, `entities/player/player_status.gd`, GDD §9.1 T1 / §9.3, KR-034, KR-038, US-042, US-043. Öneri bağlayıcı değildir; karar koordinatör/kullanıcıda.

**Dökümden okunan zincir (varsayımlar dahil):** 108,4 sn kasa boş keşfi → 110 sn bağırış (uyarı 2); sahibin hedefi yok (`target 0`, "hedef kayıp → ARA"). c1 müşteri bölgesinde, `cover_intact` true, oyalanma 102 sn. 128,7 sn'de sahip c1'i 66 px'te görüyor: ALARM çarpanı 2,5 ile 30→100 **0,63 sn** (≈ 111 birim/sn; yani taban×bant ≈ 44/sn, oyalanma 0,25 ile ≈ 11/sn olurdu). Tutma 130,3, yakalanma 136,3; host çantayla 147,0'da personel bölgesinde 14 px'te 100 → tutma 147,5 → yakalanma 153,5. İki kukla aynı noktada, görsel fark yok.

## 1. Bağırıştan sonra sahip örtüsü sağlam müşteriyi tutabilmeli mi? — Öneri: **(c) sorgu, tutma yok**

| | (a) bugünkü: herkese ALARM | (b) örtüsü sağlama yalnız normal kurallar | (c) sorgu + şüphe tavanı, tutma yalnız kanıtla |
|---|---|---|---|
| Ekip oyunu | Müşteri rolü bağırışla biter: ÇEK kurtarma ve YÖNLENDİR'i yapacak kişi ilk görülen oluyor | Müşteri yaşar ama oyalanma 0,25 ile ~6 sn görüşte yine 100 → "sadece bekledim" şikâyeti geri gelir | Müşteri sorgulanır, tanınır, serbest kalır; kurtarmaya giderse örtüsü (görülen ÇEK) bozulur → o da hedef: GDD klip (4) işler |
| Tutarlılık | US-043 mahalleli örtüsü sağlamı kovalamaz, US-042 polis serbest bırakır — ama sahip 0,6 sn'de tutar. **US-043 YÖNLENDİR sahibe karşı fiilen kullanılamaz:** 64 px'te 1,5 sn tutmak gerekir, sahip 0,6 sn'de 100'e çıkarır | Tutarlı | Tutarlı; US-044 "sorgular, bağırmaz, 90'da durur" kalıbının içerisi |
| Sömürü | Yok | "Müşteri kılığında sonsuz güvenlik" kısmen | Aynı risk, bedeli var: tanınma +1, 90 tavanı → tek sürçme (koşma, personel tarafı, ÇEK) anında 100 |
| Okunurluk | "Hiçbir şey yapmadım, yakaladı" | "?" sonra 6 sn'de kovalama; neden belli değil | "Sen de buradaydın, kim aldı?" balonu: sebep ekranda |

**(c) sayıları:**
- ALARM satırı (çarpan 2,5, `alarm_level` 2) yalnız **örtüsü bozuk** oyuncuya uygulanır (`Context`'e örtü bilgisi; teknik yol koordinatörde). Örtüsü sağlam oyuncuya alarm hâlinde de normal satırlar: oyalanma > 60 sn 0,25, aksi 0. Örtü bozucu her davranış (koşma, sızma, personel tarafı, çanta, kasa, görülen ÇEK/devir) örtüyü bozar → ALARM → bugünkü tutma zinciri aynen.
- Sahip alarmdayken (SHOUT/CHASE/SEARCH/STAGGER) örtüsü sağlam oyuncunun şüphesi **90'da durur** (`outside_stare_cap` 90 ile aynı kalıp). 60'ta **SORGU-2**: sahip SEARCH'ten o oyuncuya yürür (110 px/sn), 64 px'te durur, balon "Sen de buradaydın! Kim aldı?" (3 sn), SEARCH'e döner; sorgulanan `recognized` +1 (iş başına 1 kez), aynı oyuncuya 20 sn yeniden sorgu yok. Sorgu örtüyü bozmaz. HUD olay metni "Bakkal seni sorguladı."
- Kayıtla kontrol: c1 128,7'de 30 → ~131,4'te 60 → sorgu ~134,4'e kadar → 90 tavanı; host 147,0'da tutulur → c1 6 sn içinde ÇEK (1 sn) → ikisi serbest, sahip 2 sn sendeler, c1'in örtüsü bozulur → ikisi kapıya.
- Kabul: (1) bağırıştan sonra örtüsü sağlam, müşteri bölgesinde duran oyuncu sahibin görüşünde 30 sn kalsa da tutulmaz, `recognized` 1; (2) aynı oyuncu koşarsa ≤ 1,0 sn'de "!" ve tutma; (3) YÖNLENDİR sahibe 64 px'te 1,5 sn tutulabiliyor; (4) IS-015 botu: 3 kişilik takımda "boşta müşteri" varyantının temiz oranı normal 3 kişilikten ≤ 10 puan yüksek (sömürü sınırı).
- Neden: örtü üç kalemde (US-042/043, KR-038) oyunun ana sosyal kaynağı; bağırış onu sıfırlarsa müşteri rolü ve ÇEK/YÖNLENDİR araçları boşa düşer. Risk: sahip "tek başına bakkalda bir müşteri varken soyuldum" durumunda birini tutamaz (gerçekçilik); 90 tavanı ayarla gelen "elle tutulur kanıt" yorumu test-2 gözlemine muhtaç.

## 2. "İkimizi birden yakaladı": ardışık tutmalar okunmuyor — asgari gösterim

Bugün: tutma = HUD kayan metni "X tutuldu! Kurtarın." + sahip balonu "Yakaladım seni!"; yakalanma = "X yakalandı." Kukla, ekip listesi ve işaretçiler durumu göstermiyor (`status_changed`'ı dinleyen UI yok), geri sayım yok; tutulan ve yakalanan kukla aynı görünüyor. Asgari paket (küçükten büyüğe):
1. **Ekip listesi durumu (XS):** ada ek rozet — "tutuldu 4" (uyarı rengi, saniye sayar `hold_left`), "yakalandı" (sönük), "kaçtı". Herkes görür, sisin içinden de.
2. **Kayan metin sözleri (XS):** "X tutuldu! 6 sn — yanına git, ÇEK (E)" / ikinci tutma "3 sn"; "X yakalandı — kurtarılamaz." Mevcut `EVENT_PLAYER_*` anahtarları.
3. **Kukla (S):** HELD: tutulanın başında küçülen halka (6→0 / 3→0) + uyarı rengi kenar; CAUGHT: kukla çömelir/oturur, gri ton, baş üstü "×" glifi — ikinci tutma aynı yerde olsa da ayrışır. Tutulanın kendi ekranında ortada "TUTULDUN — n" + "arkadaşın ÇEK'sin".
4. **Yön işareti (S, `team_markers`):** tutulan arkadaş ekran dışındaysa kenar oku + geri sayım; ÇEK ipucu 32 px'te `INTERACT_RESCUE` zaten var.
5. Ses (US-047 ile, XS): tutma "yakaladım" + yakalanma ayrı kısa SFX.
Kabul: tutma anından yakalanmaya kadar her saniye en az bir yerde (liste ya da kukla) kalan süre görünür; yakalanan kukla tutulandan 1 bakışta ayrışır (farklı poz + ton).

## 3. Zamanlama — **1 ve 2.1–2.2 test-2'den önce (engel düzeyinde), 2.3–2.5 test-2 sonrası / dilim 2.4**

Gerekçe: test-2 protokolü 3 kişilik tur ve müşteri rolünü ölçecek; bugünkü kuralla her bağırışta görülen müşteri 1 sn'de tutulur, YÖNLENDİR sahibe karşı kullanılamaz, ÇEK neredeyse hiç denenmez → test-2'nin örtü/sosyal araç gözlemleri boşa gider ve aynı şikâyet iki arkadaştan da gelir. Kural değişikliği `civilian_rules` + tavan: XS; SORGU-2 balonu S — süre darsa yalnız çarpan + tavan test-2'ye girsin, sorgu balonu sonrası. Risk: test-2 paketi kullanıcıda; yeni paket gerektirir.

## Karar gereken
- (Kullanıcı) Bağırıştan sonra sahip, örtüsü sağlam müşteriyi tutamaz; yalnız sorgular ve tanır — (c) kabul mü? KR-034'teki "sabır/ekip temizlik verir" ilkesiyle aynı aile.
- (Kullanıcı) Düzeltme test-2 öncesine mi (yeni paket)?
- (Koordinatör) 90 tavanı ve sorguda `recognized` +1 bedeli; SORGU-2 balonu test-2 öncesi mi sonrası mı; okunurluk 2.1–2.2 hangi kaleme.
