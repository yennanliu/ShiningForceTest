extends TestCase
## Step 9: map triggers, objectives, dialogue, suspend, town.

const P := Enums.Faction.PLAYER


func _types(ev: Array[BattleEvent]) -> Array:
	return ev.map(func(e: BattleEvent) -> String: return String(e.type))


func _boss_battle(seed := 1) -> Array:
	Fixtures.map()
	var b := BattleState.new(load("res://tests/fixtures/map_boss.tres"), Fixtures.party(), seed)
	var ev := b.start()
	return [b, ev]


func _boss(b: BattleState) -> Unit:
	return b.units().filter(func(u: Unit) -> bool: return u.tag == &"boss")[0]


func test_round_one_intro_line() -> void:
	var r := _boss_battle()
	var said := (r[1] as Array[BattleEvent]).filter(func(e: BattleEvent) -> bool: return e.type == BattleEvent.SAID)
	assert_eq(said.size(), 1)
	assert_eq(said[0].data.line_id, &"boss_intro")


func test_boss_below_half_calls_guard_once() -> void:
	var b: BattleState = _boss_battle()[0]
	var boss := _boss(b)
	boss.hp = 1
	var ev := b.apply(WaitCommand.by(b.current_actor().id))
	var t := _types(ev)
	assert_true(t.has("said") and t.has("spawned"), str(t))
	assert_true(b.grid.unit_at(Vector2i(7, 3)) != null, "guard spawned")
	var count := b.units().size()
	ev = b.apply(WaitCommand.by(b.current_actor().id))
	assert_false(_types(ev).has("spawned"), "fires once")
	assert_eq(b.units().size(), count)


func test_boss_death_line_then_victory() -> void:
	var b: BattleState = _boss_battle()[0]
	var boss := _boss(b)
	var out: Array[BattleEvent] = []
	boss.hp = 0
	b.grid.vacate(boss.pos)
	var ev := b.apply(WaitCommand.by(b.current_actor().id))
	var t := _types(ev)
	assert_true(t.find("said") >= 0 and t.find("said") < t.find("battle_ended"), str(t))
	assert_eq(b.outcome(), BattleState.Outcome.WON)


func test_reach_area_objective() -> void:
	var m := Fixtures.open_map(Vector2i(8, 8))
	m.player_spawns = [Vector2i(0, 0)]
	m.objective = Enums.Objective.REACH_AREA
	m.objective_area = Rect2i(3, 0, 1, 1)
	var b := BattleState.new(m, Fixtures.party(), 1)
	b.start()
	var hero := b.living(P)[0]
	b.apply(MoveCommand.to_tile(hero.id, Vector2i(3, 0)))
	assert_eq(b.outcome(), BattleState.Outcome.WON)


func test_survive_rounds_objective() -> void:
	var m := Fixtures.open_map(Vector2i(8, 8))
	m.player_spawns = [Vector2i(0, 0)]
	m.objective = Enums.Objective.SURVIVE_ROUNDS
	m.objective_rounds = 3
	var b := BattleState.new(m, Fixtures.party(), 1)
	b.start()
	for i in 10:
		if b.outcome() != BattleState.Outcome.ONGOING:
			break
		b.apply(WaitCommand.by(b.current_actor().id))
	assert_eq(b.outcome(), BattleState.Outcome.WON)
	assert_eq(b.round_number(), 4, "won as round 4 begins")


func test_flag_and_lose_actions() -> void:
	var m := Fixtures.open_map(Vector2i(8, 8))
	m.player_spawns = [Vector2i(0, 0)]
	var t := TriggerData.new()
	t.when = TriggerData.When.ROUND_START
	t.on_round = 2
	var flag := TriggerAction.new()
	flag.kind = TriggerAction.Kind.SET_FLAG
	flag.key = &"storm"
	var lose := TriggerAction.new()
	lose.kind = TriggerAction.Kind.LOSE
	t.actions = [flag, lose]
	m.triggers = [t]
	m.objective = Enums.Objective.SURVIVE_ROUNDS   # no enemies: don't win by rout
	m.objective_rounds = 99
	var b := BattleState.new(m, Fixtures.party(), 1)
	b.start()
	b.apply(WaitCommand.by(b.current_actor().id))
	assert_eq(b.flags.get(&"storm"), true)
	assert_eq(b.outcome(), BattleState.Outcome.LOST)


func test_triggers_replay_deterministically() -> void:
	for s in [1, 2, 3]:
		var b: BattleState = _boss_battle(s)[0]
		AutoPlay.play_to_end(b)
		var r := BattleState.replay(b.map, Fixtures.party(), s, b.history.map(func(c: Command) -> Dictionary: return c.to_dict()))
		assert_eq(Golden.normalize(r.snapshot()), Golden.normalize(b.snapshot()), "seed %d" % s)


## Content lint: every line a trigger or town uses must exist.
func test_every_dialogue_line_exists() -> void:
	Fixtures.map()
	var maps: Array = [load("res://tests/fixtures/map_boss.tres"), Fixtures.map()]
	for f in DirAccess.get_files_at("res://data/maps/"):
		if f.ends_with(".tres"):
			maps.append(load("res://data/maps/" + f))
	for m: MapData in maps:
		for t in m.triggers:
			for a in t.actions:
				if a.kind == TriggerAction.Kind.SAY:
					assert_true(Dialogue.has(a.key), "%s: missing line %s" % [m.id, a.key])
	for ch in [Fixtures.chapter(1), Fixtures.chapter(2)]:
		for id in ch.town_talk:
			assert_true(Dialogue.has(id), "%s: missing town line %s" % [ch.id, id])


func test_suspend_and_resume_is_identical() -> void:
	var old := SaveService.dir
	SaveService.dir = "user://test_saves/"
	var c := Campaign.new_game(Fixtures.chapter(1))
	var b := c.start_battle(42)
	b.start()
	while b.round_number() < 4 and b.outcome() == BattleState.Outcome.ONGOING:
		AutoPlay.play_turn(b)
	assert_eq(SaveService.save_suspend(c, b), OK)
	assert_true(SaveService.has_suspend())
	var d := SaveService.load_suspend()
	assert_eq(Golden.normalize((d.battle as BattleState).snapshot()), Golden.normalize(b.snapshot()))
	SaveService.clear_suspend()
	assert_false(SaveService.has_suspend())
	SaveService.dir = old


func test_town_search_gives_item_once() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	var items_before := c.party.leader().items.size()
	var found := c.search(1)
	assert_eq(found.id, &"steel_sword")
	assert_eq(c.party.leader().items.size(), items_before + 1)
	assert_true(c.search(1) == null, "only once")
	assert_true(c.search(9) == null, "no such spot")
	var again := Campaign.from_dict(c.to_dict())
	assert_true(again.search(1) == null, "remembered in the save")
