extends TestCase
## Step 6 (no-GPU): text renderer, command parser, and the terminal game loop.


func test_render_shows_map_units_and_reach() -> void:
	var b := Fixtures.battle(1)
	var text := TextView.render(b)
	assert_true(text.contains("== Round 1 =="), text)
	assert_true(text.contains(" 7  "), "has row 7")
	assert_true(text.contains("Hero (H)"), "unit table")
	assert_true(text.contains("Goblin (g)"), "enemy lower-case")
	assert_true(text.contains("^"), "hill drawn")
	if b.current_actor().faction == Enums.Faction.PLAYER:
		assert_true(text.contains("+"), "move range drawn on player turn")


func test_parse_commands() -> void:
	var b := Fixtures.battle(1)
	var id := b.current_actor().id
	assert_true(TextView.parse("m 2 3", b) is MoveCommand)
	assert_eq((TextView.parse("move 2 3", b) as MoveCommand).to, Vector2i(2, 3))
	assert_eq((TextView.parse("a 5", b) as AttackCommand).target_id, 5)
	assert_true(TextView.parse("w", b) is WaitCommand)
	assert_true(TextView.parse("i 1 2", b) is UseItemCommand)
	assert_true(TextView.parse("e 0", b) is EquipCommand)
	assert_eq((TextView.parse("W", b) as Command).unit_id, id)


func test_parse_errors_and_info() -> void:
	var b := Fixtures.battle(1)
	assert_eq(TextView.parse("m 2", b), "usage: m x y")
	assert_eq(TextView.parse("a x", b), "usage: a ID")
	assert_true(String(TextView.parse("dance", b)).begins_with("unknown command"))
	assert_true(String(TextView.parse("h", b)).contains("Commands"))
	assert_true(String(TextView.parse("u 1", b)).contains("Lv 1"))
	assert_true(String(TextView.parse("f 5", b)).contains("Forecast"))


func test_every_event_has_text() -> void:
	var b := Fixtures.battle(3)
	AutoPlay.play_to_end(b)
	var r := BattleState.new(Fixtures.map(), Fixtures.party(), 3)
	var all: Array[BattleEvent] = r.start()
	for c in b.history:
		all.append_array(r.apply(c))
	var seen := {}
	for e in all:
		var t := TextView.describe(e, r)
		seen[e.type] = true
		assert_false(t.begins_with("{"), "no raw dict for %s" % e.type)
	assert_true(seen.has(BattleEvent.ATTACKED) and seen.has(BattleEvent.BATTLE_ENDED))


func _run_script(lines: Array, seed := 1) -> Dictionary:
	var out: PackedStringArray = []
	var queue := lines.duplicate()
	var state := BattleState.new(Fixtures.map(), Fixtures.party(), seed)
	var game := TerminalGame.new(state,
		func() -> String: return queue.pop_front() if not queue.is_empty() else "",
		func(t: String) -> void: out.append(t))
	var outcome := game.run()
	return {"outcome": outcome, "text": "\n".join(out), "state": state}


func test_game_loop_plays_to_the_end() -> void:
	# The player only waits; the enemy plays. The battle must end.
	var waits := []
	for i in 400:
		waits.append("w")
	var r := _run_script(waits)
	assert_ne(r.outcome, BattleState.Outcome.ONGOING)
	assert_true(r.text.contains("***"), "shows the result")


func test_game_loop_survives_bad_input() -> void:
	var r := _run_script(["dance", "m 99 99", "a 1", "h", "q"])
	assert_true(r.text.contains("unknown command"))
	assert_true(r.text.contains("Can't do that"))
	assert_true(r.text.contains("Bye."))
	assert_eq(Array(r.state.check_invariants()), [])
