extends TestCase
## Step 6: the 2D battle screen, driven headless through its public methods.


func _screen(seed := 7) -> Control:
	var scr: Control = load("res://view/battle2d/battle_screen.tscn").instantiate()
	scr.auto_start = false
	scr.animate = false
	Engine.get_main_loop().root.add_child(scr)
	scr.start_battle(seed)
	return scr


func test_starts_on_a_player_turn() -> void:
	var scr := _screen()
	assert_eq(scr.state.current_actor().faction, Enums.Faction.PLAYER)
	assert_false(scr._reach.is_empty(), "move range shown")
	scr.free()


func test_click_moves_the_acting_unit() -> void:
	var scr := _screen()
	var actor: Unit = scr.state.current_actor()
	var target := Vector2i(-1, -1)
	for t: Vector2i in scr._reach:
		if t != actor.pos:
			target = t
			break
	scr.click_tile(target)
	assert_eq(actor.pos, target)
	assert_true(scr.state.has_moved())
	assert_true(scr._reach.is_empty(), "no second move")
	scr.free()


func test_clicking_a_bad_tile_does_nothing() -> void:
	var scr := _screen()
	var before: Dictionary = scr.state.snapshot()
	scr.click_tile(Vector2i(7, 7))   # far away, not reachable
	assert_eq(scr.state.snapshot(), before)
	scr.free()


func test_waiting_plays_the_battle_to_the_end() -> void:
	var scr := _screen()
	for i in 300:
		if scr.state.outcome() != BattleState.Outcome.ONGOING:
			break
		scr.wait_turn()
	assert_ne(scr.state.outcome(), BattleState.Outcome.ONGOING)
	assert_true(scr._banner.visible, "victory/defeat banner shown")
	assert_eq(Array(scr.state.check_invariants()), [])
	scr.free()
