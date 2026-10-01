extends SceneTree
## Ton temalarını üretir (S9): her ton için ThemeBuilder.build(ton) → ui/theme/<id>.tres.
##   godot --headless --path . -s res://ui/theme/build_themes.gd
## ThemeTokens sabitleri ya da ThemeBuilder değişince çalıştırılır; test_ui_theme.gd güncelliği doğrular.
## Çıkış kodu: 0 hepsi kaydedildi, 1 en az bir kayıt hatası.


func _initialize() -> void:
	var code: int = 0
	for tone: Tone in ThemeTokens.available_tones():
		var path: String = ThemeTokens.theme_path(tone.id)
		# Var olan dosyanın UID'si korunur (sahneler temaya UID ile de bağlanabilsin).
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
