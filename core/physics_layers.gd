class_name PhysicsLayers
extends RefCounted
## Fizik katmanı bitleri, maskeler ve oyun grubu adları için tek kaynak (IS-037; mimari.md §4, S4/S7/S8/S11 ekleri).
## Yalnız sabit; düğümsüz (KR-003). Katman bitleri project.godot `layer_names/2d_physics/layer_N` adlarıyla
## eşleşir: sabit adı = katman adının büyük harfi, değer = 1 << (N - 1) (tests/unit/test_smoke.gd denetler).
## Başka betikler katman sayısı ya da grup adı dizesi yazmaz, buradan alır (tests/unit/test_physics_layers.gd
## tarar). Sahne dosyalarındaki (.tscn) katman değerleri veri olarak kalır; testleri ayrıca denetler.

## Katman bitleri (§4).
const WORLD := 1
const PLAYERS := 2
const NPCS := 4
const INTERACTABLES := 8
const TRIGGERS := 16
const VISION_BLOCK := 32

## Görüş hattını ve sesi kesen katmanlar: world + vision_block (S11 Faz 2 eki, S8). Oyuncu ve NPC gövdeleri yok.
const SIGHT_MASK := WORLD | VISION_BLOCK

## Görüşü (ve sesi) geçiren gövdelerin grubu (S4/S11 eki; US-007 camları, her `Window*` ayrı gövde).
const SEE_THROUGH_GROUP := &"see_through"
## Etkileşim bileşenlerinin (Interactable) grubu (S7).
const INTERACTABLES_GROUP := &"interactables"
## Etkileşebilen aktörlerin grubu (S7; oyuncu kendini ekler, `interaction_position()` sunar).
const ACTORS_GROUP := &"interaction_actors"
## Gürültü dinleyicilerinin grubu (S8; NoiseBus `hear_noise` çağırır).
const NOISE_LISTENER_GROUP := &"noise_listener"
