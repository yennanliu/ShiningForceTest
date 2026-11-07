extends SceneTree
## Compares two PNGs pixel by pixel (UI snapshots, doc/03 step 18). No extra libraries.
##   godot --headless --path . -s res://tools/compare_images.gd -- --a=new.png --b=golden.png [--diff=d.png] [--max=1.0]
## A pixel differs when its RGB channels differ by more than 24 in total. Prints the share of
## differing pixels and exits 1 when it is above --max percent (default 1.0) or sizes differ.


func _initialize() -> void:
	var a_path := ""
	var b_path := ""
	var diff_path := ""
	var max_pct := 1.0
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--a="): a_path = arg.trim_prefix("--a=")
		elif arg.begins_with("--b="): b_path = arg.trim_prefix("--b=")
		elif arg.begins_with("--diff="): diff_path = arg.trim_prefix("--diff=")
		elif arg.begins_with("--max="): max_pct = float(arg.trim_prefix("--max="))
	var a := Image.load_from_file(a_path)
	var b := Image.load_from_file(b_path)
	if a == null or b == null:
		printerr("compare: can't read %s or %s" % [a_path, b_path])
		quit(2)
		return
	if a.get_size() != b.get_size():
		print("compare: size differs %s vs %s" % [a.get_size(), b.get_size()])
		quit(1)
		return
	var w := a.get_width()
	var h := a.get_height()
	var d := Image.create(w, h, false, Image.FORMAT_RGB8)
	var bad := 0
	for y in h:
		for x in w:
			var ca := a.get_pixel(x, y)
			var cb := b.get_pixel(x, y)
			var delta := (absf(ca.r - cb.r) + absf(ca.g - cb.g) + absf(ca.b - cb.b)) * 255.0
			if delta > 24.0:
				bad += 1
				d.set_pixel(x, y, Color(1, 0.2, 0.2))
			else:
				d.set_pixel(x, y, ca.darkened(0.7))
	var pct := 100.0 * bad / (w * h)
	if diff_path != "":
		d.save_png(diff_path)
	print("compare: %.2f%% of pixels differ (max %.2f%%)" % [pct, max_pct])
	quit(0 if pct <= max_pct else 1)
