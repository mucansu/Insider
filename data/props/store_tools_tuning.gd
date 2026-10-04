class_name StoreToolsTuning
extends Resource
## Grocery interaction tuning (US-010; GDD §9.3 "Player tools", KR-026; mimari.md S10 tuning-file pattern). Single source is `data/props/store_tools.tres`; defaults here are neutral.
## Read by the counter (BUY / SEND TO BACK ROOM), talking to the owner (STALL = OYALA) and the shelf end (DISTRACT: knock-over + phone); the owner's brain takes the distraction kinds and the "again?" cost from here.

const PATH := "res://data/props/store_tools.tres"
## Distraction sound kinds (S8; StringNames sent over NoiseBus). The owner answers them with LISTEN and counts them.
const KIND_TOPPLE := &"topple"
const KIND_CELLPHONE := &"cellphone"
## US-045 (KR-038): a dropped glass bottle breaks (ShopProduct.drop_kind of the cola); the dropper is the one in charge
## (NoiseBus.dispatching_peer, "again?" rule).
const KIND_BOTTLE := &"bottle"
const DISTRACTION_KINDS: Array[StringName] = [KIND_TOPPLE, KIND_CELLPHONE, KIND_BOTTLE]

@export_group("Tezgâh")
## BUY cost (gum, KR-038: the counter's E with empty hands; from team cash, refused with "Para yetmiyor" if cash is short).
@export_range(0, 1000) var buy_price: int = 0

@export_group("Alışveriş (US-045)")
## Shelf item points (KR-037/KR-038): the level's `ShopItem<n>` marker sells product `shop_items[n - 1]` (ShopProduct id,
## `data/props/products/<id>.tres`); markers without an entry are skipped. Per-map overridable (VenueTuning).
@export var shop_items: Array[StringName] = []
## Product the owner fetches from the back room on the counter's Q order (GÖNDER -> "Damacana iste", KR-036).
@export var order_product: StringName = &""
## After the owner puts the ordered product on the counter: paid by the asker within this many seconds -> no return cost and
## suspicion 0; not paid -> `OwnerTuning.send_return_suspicion` at this second (s; KR-038).
@export_range(0.0, 120.0, 0.5, "suffix:s") var order_pay_sec: float = 0.0

@export_group("Oyala")
## Talking: longest duration (hold; the owner ends the talk when full) and range (from the owner, px).
@export_range(0.0, 60.0, 0.5, "suffix:s") var talk_max_sec: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var talk_range: float = 0.0
## STALL (OYALA) soothes an owner who is questioning/looking (GDD §9.3): by the player's n-th soothe, suspicion removed
## (1st 40, 2nd 20, then 0 = "never again"). The counter is read when the talk starts.
@export var talk_soothe_steps: Array[float] = []

@export_group("Dikkat dağıt")
## Shelf knock-over noise (px; KR-026: 320, same class as a shout).
@export_range(0.0, 2048.0, 1.0, "suffix:px") var topple_radius: float = 0.0
## Phone: ring delay after planting (s), noise (px), ring interval (s) and max ring count;
## the owner finds it when this close (px).
@export_range(0.0, 30.0, 0.1, "suffix:s") var phone_delay_sec: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var phone_radius: float = 0.0
@export_range(0.1, 30.0, 0.1, "suffix:s") var phone_ring_interval_sec: float = 1.0
@export_range(1, 100) var phone_ring_max: int = 1
@export_range(0.0, 256.0, 1.0, "suffix:px") var phone_find_px: float = 0.0
## The owner's suspicion of the one in charge on the second (and later) distraction ("again?").
@export_range(0.0, 100.0, 1.0) var again_suspicion: float = 0.0

@export_group("Yönlendir")
## MISDIRECT "he ran that way!" (US-043): lowest alert tier, hold (s), range to the owner/neighbour (px), distance of affected neighbours from the speaker (px),
## wrong-way run time (s) and distance (px), suspicion at the owner against the speaker.
@export_range(0, 5) var misdirect_min_alert: int = 2
@export_range(0.0, 10.0, 0.1, "suffix:s") var misdirect_hold_sec: float = 0.0
@export_range(0.0, 256.0, 1.0, "suffix:px") var misdirect_range: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var misdirect_radius: float = 0.0
@export_range(0.0, 60.0, 0.5, "suffix:s") var misdirect_run_sec: float = 0.0
@export_range(0.0, 2048.0, 1.0, "suffix:px") var misdirect_run_px: float = 0.0
@export_range(0.0, 100.0, 1.0) var misdirect_suspicion: float = 0.0

static var _default: StoreToolsTuning = null


## `data/props/store_tools.tres` (loaded once per process).
static func load_default() -> StoreToolsTuning:
	if _default == null:
		_default = load(PATH) as StoreToolsTuning
		if _default == null:
			push_error("StoreToolsTuning: %s yüklenemedi" % PATH)
			_default = StoreToolsTuning.new()
	return _default
