# Tasarım önerileri (tasarim ajanı / Fable)

Fable'ın tasarım değerlendirmelerinden çıkan öneriler `ON-nn` kimliğiyle burada yaşar (KR-016). Önerileri uygulamak zorunlu değildir; kullanıcı faz plan mesajında hangilerinin kaleme dönüşeceğine karar verir. Yalnız koordinatör yazar; değerlendirme raporlarının tam metni `docs/tasarim/degerlendirmeler/`.

Türler: **Sapma** (yapılan iş tasarımın ya da oyun zevkinin gerisinde) · **Mekanik** (mevcut mekaniğin iyileştirmesi) · **Özellik** (yeni eklenti/feature; temel döngü kurulduktan sonra, Faz 2 kapanışından itibaren) · **Süreç** (geliştirme biçimi).
Durumlar: Yeni → Kullanıcıda (plan mesajında soruldu) → Kabul (→ US-/IS-) / Ertelendi / Reddedildi (tek satır gerekçe).

| ON | Tarih | Değerlendirme | Tür | Öneri (tek cümle) | Etki / maliyet | Durum | Bağlandığı |
|---|---|---|---|---|---|---|---|
| ON-01 | 2026-10-02 | faz-1 | Sapma | Kamera yakınlaştırma 1,5 (ayarlanabilir) + harita sınırına kenetleme; oyuncu/kasa ≥ 22 px okunur | orta / düşük | Kabul (koordinatör, test-1 öncesi) | IS-027 |
| ON-02 | 2026-10-02 | faz-1 | Mekanik | Kasa iki aşamalı geri bildirim: yerel dolumda klik + yeşil çubuk, host onayında nakit; 1 sn onay yoksa sıfırla | orta / düşük | Kabul (2a) | US-013 / IS-024 |
| ON-03 | 2026-10-02 | faz-1 | Mekanik | Yakalama/tutma kararında oyuncu lehine ileri tahmin (velocity × min(RTT/2, 0,1 sn); 28 px bu konumla) | yüksek / düşük | Kabul (2a) | US-008 AC |
| ON-04 | 2026-10-02 | faz-1 | Mekanik | Şüphe ölçeri sürekli durum olarak 15 Hz güvenilmez çoğaltılsın, "?"/"!" istemcide eşikten türesin; yalnız sonuç güvenilir RPC | yüksek / düşük-orta | Kabul (2a) | US-008 |
| ON-05 | 2026-10-02 | faz-1 | Sapma | HUD ping'i güvenilir olana kadar gizle ya da "~" ile göster | düşük / düşük | Kabul (test-1 öncesi) | IS-026 |
| ON-06 | 2026-10-02 | faz-1 | Mekanik | Yerel oyuncuya ince dış halka, menzildeki kasa/kapıya 22 px halka, ekip paneli harita dışına | orta / düşük | Kabul (2a) | US-014 / US-013 |
| ON-07 | 2026-10-02 | faz-1 | Sapma | Viewport temizleme rengi BG token'ı (gri değil) | düşük / çok düşük | Kabul (test-1 öncesi) | IS-027 |
| ON-08 | 2026-10-02 | faz-1 | Mekanik | Hızlar test-1'e kadar sabit; kabul: koşan oyuncu 10 karoda chaser'dan ≥ 1 karo açar (hesap 0,9 → chaser 190 adayı) | orta / sıfır | Kabul (US-008 ayarı) | US-008 |
| ON-09 | 2026-10-02 | faz-1 | Süreç | Sert ağ profili Faz 2 çıkış kriterine (≥ 8/10 koşu, < 48 px; US-015 uyarlanır tampon) | orta / orta | Kabul (2b, yumuşak kriter) | US-015 |
