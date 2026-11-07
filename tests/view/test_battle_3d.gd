extends TestCase
## Step 17: the 3D map view — same battle as 2D and text, no hidden units, camera, picking.


func _screen(mode: int) -> Control:
	var scr: Control = load("res://view/battle2d/battle_screen.tscn").instantiate()
	scr.auto_start = false
	scr.animate = false
	scr.view_mode = mode   # 0 = 3D (forced, even headless), 1 = 2D
	Engine.get_main_loop().root.add_child(scr)
	return scr


func _play_out(scr: Control, chapter: StringName, seed: int) -> Array:
	var b := Campaign.new_game(Content.chapter(chapter)).start_battle(seed)
	scr.begin(b)
	for i in 300:   # the party waits; the enemy AI plays its turns through the screen
		if b.outcome() != BattleState.Outcome.ONGOING:
			break
		scr.wait_turn()
	return [b, b.history.map(func(c: Command) -> Dictionary: return c.to_dict())]


func test_same_battle_in_2d_3d_and_text() -> void:
	for ch: StringName in [&"ch01", &"ch02", &"ch03"]:
		var s3 := _screen(0)
		var r3 := _play_out(s3, ch, 5)
		assert_true(s3.is_3d(), "%s: 3D view on" % ch)
		var s2 := _screen(1)
		var r2 := _play_out(s2, ch, 5)
		assert_false(s2.is_3d())
		var b3: BattleState = r3[0]
		var b2: BattleState = r2[0]
		assert_eq(r3[1], r2[1], "%s: same commands" % ch)
		assert_eq(Golden.normalize(b3.snapshot()), Golden.normalize(b2.snapshot()), "%s: same final state in 2D and 3D" % ch)
		var c := Campaign.new_game(Content.chapter(ch))
		var text := BattleState.replay(c.chapter.battle, c.party.deployed_units(), 5, r3[1], c.bonds)
		assert_eq(Golden.normalize(text.snapshot()), Golden.normalize(b3.snapshot()), "%s: the text/headless replay agrees" % ch)
		s3.free()
		s2.free()


func test_no_unit_is_hidden_at_any_angle_on_any_map() -> void:
	for ch: StringName in [&"ch01", &"ch02", &"ch03"]:
		var scr := _screen(0)
		var b := Campaign.new_game(Content.chapter(ch)).start_battle(1)
		scr.begin(b)
		var m: Map3D = scr._map3d
		for k in 4:
			for top in [false, true]:
				m.top_down = top
				m.rotate_view(0)
				m.sync()
				assert_eq(m.hidden_units(b), [] as Array[int], "%s yaw %d%s" % [ch, k, " top-down" if top else ""])
			m.top_down = false
			m.rotate_view(1)
		scr.free()


func test_wall_fade_happens_when_a_wall_is_in_the_way() -> void:
	var scr := _screen(0)
	var b := Campaign.new_game(Content.chapter(&"ch03")).start_battle(1)   # the chief stands by a wall
	scr.begin(b)
	var m: Map3D = scr._map3d
	var faded_somewhere := false
	for k in 4:
		m.sync()
		faded_somewhere = faded_somewhere or not m.faded.is_empty()
		m.rotate_view(1)
	assert_true(faded_somewhere, "at some angle the chief's wall fades")
	scr.free()


func test_camera_rotate_zoom_top_down_and_picking() -> void:
	var scr := _screen(0)
	scr.begin(Campaign.new_game(Content.chapter(&"ch01")).start_battle(1))
	var m: Map3D = scr._map3d
	var size0 := m.camera().size
	m.cycle_zoom()
	assert_true(m.camera().size < size0, "zoom in")
	m.cycle_zoom()
	m.cycle_zoom()
	assert_near(m.camera().size, size0, 0.001, "three zoom levels, then back")
	var up := m.screen_dir_to_grid(Vector2i.UP)
	m.rotate_view(1)
	assert_ne(m.screen_dir_to_grid(Vector2i.UP), up, "arrow keys turn with the camera")
	m.rotate_view(3)
	assert_eq(m.yaw_index, 0, "four quarter turns")
	m.toggle_top_down()
	assert_true(m.camera().rotation_degrees.x < -80.0, "top-down view")
	m.toggle_top_down()
	for t in [Vector2i(0, 0), Vector2i(5, 4), Vector2i(11, 9), Vector2i(4, 2)]:   # (4,2) is a hill
		var p := m.to_screen(m.tile_world(t) + Vector3(0, 0.01, 0))
		assert_eq(m.pick(p), t, "clicking a tile's center picks %s" % t)
	scr.free()


func test_facing_turns_with_the_camera() -> void:
	var scr := _screen(0)
	scr.begin(Campaign.new_game(Content.chapter(&"ch01")).start_battle(1))
	var m: Map3D = scr._map3d
	var rows := []
	for k in 4:
		rows.append(m.screen_facing(scr.DOWN))
		m.rotate_view(1)
	assert_eq(rows.size(), 4)
	assert_true(rows.count(rows[0]) < 4, "a unit facing grid-down shows different sides as the camera turns")
	scr.free()


func test_battle_view_setting_persists_and_headless_defaults_to_2d() -> void:
	var old := Settings.path
	Settings.path = "user://test_settings_view.cfg"
	Settings.battle_view = Settings.View.TWO_D
	assert_eq(Settings.save_settings(), OK)
	Settings.battle_view = Settings.View.THREE_D
	Settings.load_settings()
	assert_eq(Settings.battle_view, Settings.View.TWO_D)
	Settings.battle_view = Settings.View.THREE_D
	DirAccess.remove_absolute(Settings.path)
	Settings.path = old
	var scr := _screen(-1)   # follow the setting (3D) — but headless falls back to 2D
	scr.begin(Campaign.new_game(Content.chapter(&"ch01")).start_battle(1))
	assert_false(scr.is_3d(), "tests and headless runs draw 2D")
	scr.free()
