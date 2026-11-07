extends SceneTree
## Generates the UI kit theme (doc/03 step 18) into res://assets/ui/banner_theme.tres.
##   godot --headless --path . -s res://tools/make_theme.gd
## Run after tools/make_art.py (the theme uses its frame textures) and an import.


func _initialize() -> void:
	var t := BannerTheme.build()
	_stable_ids(t)
	var err := ResourceSaver.save(t, BannerTheme.PATH)
	assert(err == OK, "could not save the theme")
	print("theme written: %s" % BannerTheme.PATH)
	quit()


## Names every style and font after its theme slot, so the saved file is identical on every run
## (otherwise Godot picks random ids for them, and check_generated sees a diff).
func _stable_ids(t: Theme) -> void:
	for type in t.get_type_list():
		for n in t.get_stylebox_list(type):
			t.get_stylebox(n, type).resource_scene_unique_id = _id("sb", type, n)
		for n in t.get_font_list(type):
			t.get_font(n, type).resource_scene_unique_id = _id("font", type, n)
	if t.default_font != null:
		t.default_font.resource_scene_unique_id = "font_default"


func _id(kind: String, type: StringName, n: StringName) -> String:
	return ("%s_%s_%s" % [kind, type, n]).replace(" ", "_")
