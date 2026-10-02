class_name PuppetTuning
extends Resource
## Karakter kuklası ayarları (US-014; GDD §14.1 zamanlama tablosu, KR-017; mimari S10 ayar dosyası kalıbı).
## Değerlerin tek kaynağı `data/puppet_tuning.tres` (başlangıç değerleri docs/tasarim/kukla-denemesi.html
## varsayılanları; kullanıcının kaydırıcı denemesiyle ayarlanır). Buradaki varsayılanlar nötrdür.
## Hesap PuppetRig'de (düğümsüz), çizim Puppet'ta. Birimler: kukla geometrisi, sekme, sıçrama, atkı ve toz
## "kukla birimi"dir (× `puppet_scale` = px; deneme sahnesi ölçek 2 ile çizildiği için oradaki px = 2 birim);
## hareket hızları, adım boyları, ışınlanma mesafesi ve işaret bağlantı yüksekliği dünya px'idir.
## Yay aralıkları kararlılık için sınırlı (PuppetSpring ayrıca alt adımla korur).

@export_group("Yay (ezilme / eğilme)")
## Gövde yayının frekansı (Hz; 1,5-10: düşük = salınımlı, yüksek = çevik).
@export_range(1.5, 10.0, 0.1, "suffix:Hz") var spring_frequency: float = 0.0
## Ezilme-esneme yayının sönümü.
@export_range(0.05, 1.0, 0.01) var squash_damping: float = 0.0
## Eğilme yayının sönümü.
@export_range(0.05, 1.0, 0.01) var lean_damping: float = 0.0
## Eğilme yayı frekansı = spring_frequency × bu oran.
@export_range(0.25, 1.5, 0.01) var lean_frequency_ratio: float = 0.0

@export_group("Çarpanlar (kaydırıcılar)")
## Sekme çarpanı (0-2): adım sekmesi ve adım inişi ezilme darbesi.
@export_range(0.0, 2.0, 0.1) var bounce: float = 0.0
## Abartı çarpanı (0-2): eğilme, kalkış çökmesi ve ezilme-esneme.
@export_range(0.0, 2.0, 0.1) var exaggeration: float = 0.0

@export_group("Yumuşatma")
## Görsel hızın gözlenen hıza yaklaşması (üstel, 1/sn): hareket varken ve dururken.
@export_range(0.0, 50.0, 0.1) var speed_smoothing_start: float = 0.0
@export_range(0.0, 50.0, 0.1) var speed_smoothing_stop: float = 0.0
## İvme ölçümünün yumuşatması (1/sn).
@export_range(0.0, 50.0, 0.1) var accel_smoothing: float = 0.0
## Yön dönüşü (gövde ve bakış birlikte; 1/sn).
@export_range(0.0, 50.0, 0.1) var turn_smoothing: float = 0.0
## Bu hızda (px/sn) "tam hareket" sayılır; altında poz beklemeye karışır.
@export_range(1.0, 500.0, 1.0, "suffix:px/s") var moving_reference_speed: float = 0.0

@export_group("Kipler (sız / yürü / koş)")
## Kip başına değerler Vector3 olarak: x = sız, y = yürü, z = koş.
## Adım boyu (px; kadans = hız ÷ adım boyu).
@export var stride: Vector3 = Vector3.ZERO
## Sekme genliği (kukla birimi).
@export var bob_amplitude: Vector3 = Vector3.ZERO
## Gövde (siluet) ölçeği; sızma çömelmiş ve alçak okunmalı.
@export var body_scale: Vector3 = Vector3.ZERO
## Adım inişi ezilme darbesi kip çarpanı.
@export var footfall_factor: Vector3 = Vector3.ZERO
## Ayak salınım genliği (kukla birimi).
@export var foot_swing: Vector3 = Vector3.ZERO
## Etkileşimde gövde ölçeği.
@export_range(0.0, 2.0, 0.01) var interact_scale: float = 0.0
## Adım inişi ezilme darbesi (yay hızına eklenir).
@export_range(0.0, 10.0, 0.05) var footfall_impulse: float = 0.0
## Adım sayılması için en düşük görsel hız (px/sn).
@export_range(0.0, 200.0, 1.0, "suffix:px/s") var footfall_min_speed: float = 0.0

@export_group("Eğilme")
## Eğilme = hız.x / lean_reference_speed × lean_gain (rad); koşuda × lean_sprint_factor; tavan ± lean_max.
@export_range(0.0, 1.0, 0.01, "suffix:rad") var lean_gain: float = 0.0
@export_range(1.0, 1000.0, 1.0, "suffix:px/s") var lean_reference_speed: float = 0.0
@export_range(0.0, 3.0, 0.05) var lean_sprint_factor: float = 0.0
@export_range(0.0, 1.0, 0.01, "suffix:rad") var lean_max: float = 0.0
## İvmede ek öne taşma / duruşta öne taşıp yaylanma (rad / (px/sn²)).
@export var lean_accel_gain: float = 0.0
## Kalkış çökmesi: öne ivmenin ezilme hedefinden düşülen payı (1 / (px/sn²)).
@export var squash_accel_gain: float = 0.0

@export_group("Bekleme")
## Nefes periyodu (sn) ve ölçek genliği (yalnız beklerken).
@export_range(0.0, 10.0, 0.01, "suffix:s") var breath_period: float = 0.0
@export_range(0.0, 0.2, 0.001) var breath_amount: float = 0.0
## Göz kırpma süresi ve aralığı (sn).
@export_range(0.0, 1.0, 0.01, "suffix:s") var blink_duration: float = 0.0
@export var blink_interval: Vector2 = Vector2.ZERO
## Bakınma aralığı (sn), açı aralığı (± rad) ve yeniden ileri bakma olasılığı.
@export var look_interval: Vector2 = Vector2.ZERO
@export_range(0.0, 3.14, 0.01, "suffix:rad") var look_range: float = 0.0
@export_range(0.0, 1.0, 0.01) var look_forward_chance: float = 0.0
## Bakınmada ekip arkadaşına bakma olasılığı (arkadaş biliniyorsa; ileri bakılmadığında).
@export_range(0.0, 1.0, 0.01) var look_friend_chance: float = 0.0

@export_group("Tepki")
## Balon pop süresi (easeOutBack) ve "!" titreme süresi (sn).
@export_range(0.0, 2.0, 0.01, "suffix:s") var bubble_pop_time: float = 0.0
@export_range(0.0, 2.0, 0.01, "suffix:s") var alert_shake_time: float = 0.0
## "!" titreme genliği (px, başta; süre boyunca söner).
@export_range(0.0, 20.0, 0.1, "suffix:px") var alert_shake_amplitude: float = 0.0
## Fark edilince sıçrama (birim/sn) ve yerçekimi (birim/sn²; havada ~2 × hız / yerçekimi sn); inişte ezilme
## darbesi.
@export_range(0.0, 1000.0, 1.0, "suffix:u/s") var jump_speed: float = 0.0
@export_range(0.0, 5000.0, 1.0, "suffix:u/s²") var gravity: float = 0.0
@export_range(0.0, 10.0, 0.05) var land_impulse: float = 0.0
## Fark edilince göz büyümesi (göz ölçeği yayına eklenen hız).
@export_range(0.0, 20.0, 0.1) var alert_eye_impulse: float = 0.0

@export_group("Atkı ve toz")
@export_range(2, 12, 1) var scarf_segments: int = 0
@export_range(0.0, 1.0, 0.01) var scarf_damping: float = 0.0
## Atkı yerçekimi (birim/sn²).
@export_range(0.0, 10000.0, 10.0, "suffix:u/s²") var scarf_gravity: float = 0.0
## Atkı parça boyu (kukla birimi).
@export_range(0.0, 20.0, 0.1) var scarf_segment_length: float = 0.0
## Koşu adımında toz parçacığı sayısı ve ömrü (sn).
@export_range(0, 10, 1) var dust_per_step: int = 0
@export var dust_life: Vector2 = Vector2.ZERO

@export_group("Ölçek ve bağlantı")
## Kukla birimi → px (GDD: toplam ~44 birim × kukla ölçeği).
@export_range(0.1, 4.0, 0.05) var puppet_scale: float = 0.0
## Tek karede bundan uzun konum sıçraması ışınlanma sayılır: animasyon sessizce yeniden kurulur (px).
@export_range(1.0, 1000.0, 1.0, "suffix:px") var teleport_distance: float = 0.0
## Oyun bilgisi işaretlerinin (ad etiketi, balon, etkileşim rozeti) sabit bağlantı yüksekliği (px, gövde
## merkezinden yukarı); animasyon bunu oynatmaz.
@export_range(0.0, 200.0, 1.0, "suffix:px") var marker_anchor_height: float = 0.0

@export_group("Görünüm")
## Oyuncu kuklalarının görünümü, katılım yuvası sırasıyla (rol/loadout gelene kadar yer tutucu).
@export var player_looks: Array[PuppetLook] = []
