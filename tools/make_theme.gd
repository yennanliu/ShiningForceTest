extends SceneTree
## Generates the UI kit theme (doc/03 step 18) into res://assets/ui/banner_theme.tres.
##   godot --headless --path . -s res://tools/make_theme.gd
## Run after tools/make_art.py (the theme uses its frame textures) and an import.


func _initialize() -> void:
	var t := BannerTheme.build()
	var err := ResourceSaver.save(t, BannerTheme.PATH)
	assert(err == OK, "could not save the theme")
	print("theme written: %s" % BannerTheme.PATH)
	quit()
