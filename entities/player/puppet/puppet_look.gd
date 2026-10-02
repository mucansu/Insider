class_name PuppetLook
extends Resource
## Kuklanın görünümü (US-014; GDD §14.1, KR-017): rol silueti başlıktan, oran ve kostüm renkleri. Rol ayrı
## sınıf değil, kozmetik parametredir (mimari S10). Oyuncu kimliği atkı rengindedir ve buradan değil
## `ThemeTokens.PLAYER_COLORS[slot]`'tan gelir; görünüm atkının olup olmadığını söyler (sivil atkısız).
##
## Doku yuvaları: her parça için isteğe bağlı doku (ileride çizilmiş/üretilmiş parça görselleri). Boşsa parça
## kodla çizilir; doluysa Puppet o parçanın çerçevesine dokuyu çizer (çerçeveler Puppet.part_rect()).

enum Gear { NONE, HOOD, BEANIE, CAP, POLICE }

## Başlık (rol silueti).
@export var gear: Gear = Gear.NONE
## Gövde genişlik çarpanı (Muscle geniş, Tech dar).
@export_range(0.5, 1.5, 0.01) var width: float = 1.0
## Atkı (oyuncu kimliği) var mı.
@export var has_scarf: bool = true
## Gövdede rozet (muhafız/polis).
@export var badge: bool = false

@export_group("Renkler")
@export var skin_color: Color = Color.WHITE
@export var hair_color: Color = Color.BLACK
@export var coat_color: Color = Color.BLACK
@export var shoe_color: Color = Color.BLACK
@export var eye_color: Color = Color.BLACK
@export var blush_color: Color = Color.TRANSPARENT
## Başlık ana / koyu / vurgu rengi (kapüşon, bere bandı, kulaklık, siper, rozet).
@export var gear_color: Color = Color.BLACK
@export var gear_dark_color: Color = Color.BLACK
@export var gear_accent_color: Color = Color.WHITE

@export_group("Doku yuvaları")
@export var head_texture: Texture2D = null
@export var headgear_texture: Texture2D = null
@export var body_texture: Texture2D = null
@export var hand_texture: Texture2D = null
