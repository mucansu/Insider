class_name MapEntry
extends Resource
## A playable map of the map registry (US-050; data/map_registry.tres): level scene path + player-visible name key.

## Level scene (`res://levels/<file>.tscn`, root `Level`, S4).
@export_file("*.tscn") var level_path: String = ""
## Name text key `MAP_<FILE NAME>` (i18n/texts.csv). Same key the session score table derives from the path
## (SessionScores.map_key; test_map_registry checks they match).
@export var name_key: String = ""
