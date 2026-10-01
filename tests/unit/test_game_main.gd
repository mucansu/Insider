extends TestCase
## main.gd açılış kipi (US-001 AC7): argümansız açılışta menü varsa menü, yoksa uyarılı menüsüz açılış.
## Sahne ağaca eklenmez (_ready otomasyonu koşmaz); yalnız karar fonksiyonu sınanır.

const MainScript := preload("res://main.gd")


func _main() -> MainScript:
	return autofree((load("res://main.tscn") as PackedScene).instantiate()) as MainScript


func test_menu_path_constant() -> void:
	var m: MainScript = _main()
	eq(MainScript.MAIN_MENU, "res://ui/main_menu.tscn")
	eq(m.menu_scene, MainScript.MAIN_MENU)


func test_start_mode_without_arguments() -> void:
	var m: MainScript = _main()
	m.menu_scene = "res://tests/fixtures/yok_menu.tscn"
	eq(m.start_mode(false, ""), &"none", "menü yoksa menüsüz açılış (uyarı)")
	m.menu_scene = "res://tests/fixtures/empty_level.tscn"  # var olan herhangi bir sahne
	eq(m.start_mode(false, ""), &"menu", "menü varsa menüye geçilir")
	m.menu_scene = MainScript.MAIN_MENU
	eq(m.start_mode(false, ""), &"menu" if ResourceLoader.exists(MainScript.MAIN_MENU) else &"none")


func test_start_mode_with_session_arguments() -> void:
	var m: MainScript = _main()
	eq(m.start_mode(true, ""), &"host")
	eq(m.start_mode(false, "127.0.0.1"), &"join")
	eq(m.start_mode(true, "127.0.0.1"), &"host")
