class_name PuppetLook
extends Resource
## Puppet look (US-014; GDD §14.1, KR-017): role silhouette from the headgear, proportions and costume colours. Role is a cosmetic parameter,
## not a separate class (S10). Player identity is the scarf colour from `ThemeTokens.PLAYER_COLORS[slot]`, not from here; the look
## says whether there is a scarf (civilians have none).
## Texture slots: optional texture per part (hand-drawn/generated part art later). If empty the part is drawn in code; if set, Puppet draws
## the texture into the part's frame (frames from Puppet.part_rect()).

enum Gear { NONE, HOOD, BEANIE, CAP, POLICE }

## Headgear (role silhouette).
@export var gear: Gear = Gear.NONE
## Body width multiplier (Muscle wide, Tech narrow).
@export_range(0.5, 1.5, 0.01) var width: float = 1.0
## Whether there is a scarf (player identity).
@export var has_scarf: bool = true
## Body badge (guard/police).
@export var badge: bool = false

@export_group("Renkler")
@export var skin_color: Color = Color.WHITE
@export var hair_color: Color = Color.BLACK
@export var coat_color: Color = Color.BLACK
@export var shoe_color: Color = Color.BLACK
@export var eye_color: Color = Color.BLACK
@export var blush_color: Color = Color.TRANSPARENT
## Headgear main / dark / accent colour (hood, beanie band, headphones, visor, badge).
@export var gear_color: Color = Color.BLACK
@export var gear_dark_color: Color = Color.BLACK
@export var gear_accent_color: Color = Color.WHITE

@export_group("Doku yuvaları")
@export var head_texture: Texture2D = null
@export var headgear_texture: Texture2D = null
@export var body_texture: Texture2D = null
@export var hand_texture: Texture2D = null
