extends TestCase
## Step 10: settings, input map, battle log, keyboard/gamepad cursor.


func test_settings_persist() -> void:
	var old := Settings.path
	Settings.path = "user://test_settings.cfg"
	Settings.music_volume = 0.3
	Settings.sfx_volume = 0.6
	Settings.anim_speed_index = 2
	assert_eq(Settings.save_settings(), OK)
	Settings.music_volume = 1.0
	Settings.sfx_volume = 1.0
	Settings.anim_speed_index = 0
	Settings.load_settings()
	assert_near(Settings.music_volume, 0.3, 0.001)
	assert_near(Settings.sfx_volume, 0.6, 0.001)
	assert_eq(Settings.anim_speed(), 0.0, "skip animations")
	Settings.anim_speed_index = 0
	DirAccess.remove_absolute(Settings.path)
	Settings.path = old


func test_input_map_has_keyboard_and_gamepad() -> void:
	Settings.setup_input()
	for action in ["cursor_up", "confirm", "wait", "item", "spell", "continue"]:
		assert_true(InputMap.has_action(action), action)
		var kinds := InputMap.action_get_events(action).map(func(e: InputEvent) -> String: return e.get_class())
		assert_true(kinds.has("InputEventKey") and kinds.has("InputEventJoypadButton"), "%s: %s" % [action, kinds])


func test_battle_log_replays_exactly() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	var b := c.start_battle(77)
	b.start()
	AutoPlay.play_to_end(b)
	var path := "user://logs/test_battle.json"
	assert_eq(BattleLog.write(c, b, path), OK)
	var r := BattleLog.rebuild(BattleLog.read(path))
	assert_eq(Golden.normalize(r.snapshot()), Golden.normalize(b.snapshot()))
	DirAccess.remove_absolute(path)


func test_cursor_and_confirm_move_a_unit() -> void:
	var scr: Control = load("res://view/battle2d/battle_screen.tscn").instantiate()
	scr.auto_start = false
	scr.animate = false
	Engine.get_main_loop().root.add_child(scr)
	scr.start_battle(7)
	var actor: Unit = scr.state.current_actor()
	scr.move_cursor(Vector2i.UP)          # cursor starts on the actor, then moves up one
	var target: Vector2i = actor.pos + Vector2i.UP
	assert_eq(scr._hover, target)
	if scr._reach.has(target) and scr.state.grid.unit_at(target) == null:
		scr.click_tile(scr._hover)
		assert_eq(actor.pos, target)
	scr.free()


func test_settings_screen_builds() -> void:
	var scr: Control = load("res://view/screens/settings.tscn").instantiate()
	Engine.get_main_loop().root.add_child(scr)
	scr._ready()
	assert_true(scr.get_child_count() > 0)
	scr.free()
