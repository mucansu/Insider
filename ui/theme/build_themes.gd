extends SceneTree
## Generates the tone themes (S9): ThemeBuilder.build(tone) -> ui/theme/<id>.tres for each tone.
##   godot --headless --path . -s res://ui/theme/build_themes.gd
## Run after ThemeTokens constants or ThemeBuilder change; test_ui_theme.gd checks freshness. Exit code: 0 all saved, 1 at least one save error.


func _initialize() -> void:
	var code: int = 0
	for tone: Tone in ThemeTokens.available_tones():
		var path: String = ThemeTokens.theme_path(tone.id)
		# Keep the existing file's UID (so scenes can also reference the theme by UID).
		var uid: int = ResourceLoader.get_resource_uid(path) if ResourceLoader.exists(path) else ResourceUID.INVALID_ID
		if uid == ResourceUID.INVALID_ID:
			uid = ResourceUID.create_id()
		var err: Error = ResourceSaver.save(ThemeBuilder.build(tone), path)
		if err == OK:
			err = ResourceSaver.set_uid(path, uid)
		if err == OK:
			print("tema yazıldı: %s" % path)
		else:
			push_error("tema yazılamadı: %s (%s)" % [path, error_string(err)])
			code = 1
	quit(code)
