extends SceneTree
## Rasterizes the portrait sources (tools/make_portraits.py) into the PNGs the game loads.
##   godot --headless --path . -s res://tools/render_portraits.gd
## assets/art_src/portraits/<name>.svg (512 viewBox) -> assets/textures/portraits/<name>.png (256x256).

const SRC := "res://assets/art_src/portraits/"
const DST := "res://assets/textures/portraits/"


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DST))
	var n := 0
	for f in DirAccess.get_files_at(SRC):
		if not f.ends_with(".svg"):
			continue
		var img := Image.new()
		var err := img.load_svg_from_string(FileAccess.get_file_as_string(SRC + f), 0.5)
		assert(err == OK, "could not read %s" % f)
		img.save_png(ProjectSettings.globalize_path(DST + f.get_basename() + ".png"))
		n += 1
	print("portraits rendered: %d" % n)
	quit()
