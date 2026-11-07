extends TestCase
## Step 18: one UI kit (Banner frame theme), fonts, focus on every screen, motion rules, UI sounds.

const SCREENS := ["res://view/screens/title.tscn", "res://view/screens/camp.tscn", "res://view/screens/results.tscn",
	"res://view/screens/town.tscn", "res://view/screens/settings.tscn"]


func test_one_kit_no_local_styleboxes() -> void:
	for dir in ["res://view/screens/", "res://view/battle2d/", "res://view/dialogue/", "res://view/battle_scene/"]:
		for f in DirAccess.get_files_at(dir):
			if f.ends_with(".gd"):
				var src := FileAccess.get_file_as_string(dir + f)
				assert_false(src.contains("StyleBoxFlat"), "%s%s builds its own StyleBoxFlat (use the theme)" % [dir, f])


func test_theme_has_fonts_frames_and_variations() -> void:
	var t := BannerTheme.load_or_build()
	assert_true(t.default_font != null, "body font set")
	assert_true((t.default_font as FontVariation).base_font.resource_path.ends_with("Inter-Variable.ttf"))
	var display := t.get_font("font", "DisplayLabel") as FontVariation
	assert_true(display != null and display.base_font.resource_path.ends_with("Cinzel-Variable.ttf"), "display font")
	assert_true(t.get_stylebox("panel", "PanelContainer") is StyleBoxTexture, "panels use the Banner frame texture")
	for v in ["BannerCard", "PortraitFrame", "PlateCard", "BannerChip", "DisplayLabel", "PrimaryButton", "HpHigh", "HpMid", "HpLow", "XpBar"]:
		assert_true(t.get_type_variation_base(v) != &"", "variation %s" % v)
	var ring := t.get_stylebox("focus", "Button") as StyleBoxFlat
	assert_true(ring != null and not ring.draw_center and ring.border_width_top >= 3, "a visible focus ring")
	assert_eq(t.get_color("font_color", "PrimaryButton"), BannerTheme.INK)


func test_fonts_ship_with_their_licenses() -> void:
	for f in ["Cinzel-Variable.ttf", "Cinzel-OFL.txt", "Inter-Variable.ttf", "Inter-OFL.txt"]:
		assert_true(FileAccess.file_exists("res://assets/fonts/" + f), f)
	for f in ["Cinzel-OFL.txt", "Inter-OFL.txt"]:
		assert_true(FileAccess.get_file_as_string("res://assets/fonts/" + f).contains("SIL Open Font License"), f)


func test_hp_bar_colors_follow_the_map_thresholds() -> void:
	assert_eq(BannerTheme.hp_variation(1.0), &"HpHigh")
	assert_eq(BannerTheme.hp_variation(0.5), &"HpMid")
	assert_eq(BannerTheme.hp_variation(0.26), &"HpMid")
	assert_eq(BannerTheme.hp_variation(0.25), &"HpLow")


func test_every_screen_has_a_default_focus() -> void:
	Game.change_scenes = false
	Game.new_game()
	Game.last_result = Game.campaign.finish_battle(Fixtures.win_battle(Game.campaign))
	Game.campaign.chapter = Content.chapter(&"ch01")   # has a town
	for path in SCREENS:
		var scr: Control = load(path).instantiate()
		Engine.get_main_loop().root.add_child(scr)
		scr._ready()
		var f: Control = scr.get("default_focus")
		assert_true(f != null, "%s has a default focus" % path)
		if f != null:
			assert_eq(f.focus_mode, Control.FOCUS_ALL, "%s: focus can land on it" % path)
			assert_false(f is BaseButton and (f as BaseButton).disabled, "%s: not a disabled button" % path)
		scr.free()
	Game.campaign = null
	Game.change_scenes = true


func test_motion_and_transitions_are_off_headless() -> void:
	assert_false(UI.motion_ok(), "no tweens in headless runs and tests")
	Transition.cover()   # returns at once
	assert_false(Transition.is_covering())


func test_ui_sounds_exist() -> void:
	for s in ["hover", "confirm", "cancel", "open"]:
		assert_true(ResourceLoader.exists("res://assets/audio/sfx_%s.wav" % s), s)


func test_primary_button_and_panel_helpers() -> void:
	var host := VBoxContainer.new()
	Engine.get_main_loop().root.add_child(host)
	var b := UI.primary_button(host, "Go", func() -> void: pass)
	assert_eq(b.theme_type_variation, &"PrimaryButton")
	var col := UI.panel(host, &"BannerCard")
	assert_eq((col.get_parent() as Control).theme_type_variation, &"BannerCard")
	assert_eq(col.get_parent().get_child_count(), 1, "the pennant is drawn, not a child the container would stretch")
	assert_eq(UI.label(host, "Title", 40).theme_type_variation, &"DisplayLabel")
	assert_eq(UI.label(host, "body", 24).theme_type_variation, &"")
	host.free()
