extends TestCase
## Step 5: enemy AI.

const P := Enums.Faction.PLAYER
const E := Enums.Faction.ENEMY


func test_attacks_unit_in_range_instead_of_waiting() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var gob := b.living(E)[0]
	Fixtures.act_as(b, gob)
	var plan := AiPlanner.choose(b, gob)
	assert_true(plan[-1] is AttackCommand, "plan: %s" % [plan])


func test_moves_in_to_attack() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(4, 0)])
	var gob := b.living(E)[0]
	Fixtures.act_as(b, gob)
	var plan := AiPlanner.choose(b, gob)
	assert_true(plan[0] is MoveCommand)
	assert_true(plan[1] is AttackCommand)


func test_attacks_lowest_hp_target() -> void:
	# Two adjacent players; the knight has 1 HP. The goblin should attack the knight.
	var b := Fixtures.duel([Vector2i(3, 3), Vector2i(5, 3)], [Vector2i(4, 3)])
	var gob := b.living(E)[0]
	var knight := b.grid.unit_at(Vector2i(5, 3))
	knight.hp = 1
	Fixtures.act_as(b, gob)
	var plan := AiPlanner.choose(b, gob)
	assert_eq(plan.size(), 1, "already in range: no move")
	assert_eq((plan[-1] as AttackCommand).target_id, knight.id)


func test_hold_attacks_only_in_place() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(2, 0)])
	var gob := b.living(E)[0]
	gob.ai = Enums.AiProfile.HOLD
	Fixtures.act_as(b, gob)
	assert_true(AiPlanner.choose(b, gob)[0] is WaitCommand, "target 2 tiles away, sword range 1")


func test_hold_never_moves() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var gob := b.living(E)[0]
	gob.ai = Enums.AiProfile.HOLD
	Fixtures.act_as(b, gob)
	var plan := AiPlanner.choose(b, gob)
	assert_eq(plan.size(), 1)
	assert_true(plan[0] is WaitCommand)


func test_approaches_when_nothing_in_reach() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)], 1, Vector2i(12, 12))
	var gob := b.living(E)[0]
	Fixtures.act_as(b, gob)
	var before := Pathfinder.distance(gob.pos, Vector2i(0, 0))
	AutoPlay.play_turn(b)
	assert_true(Pathfinder.distance(gob.pos, Vector2i(0, 0)) < before, "goblin moved closer")


func test_ai_is_deterministic() -> void:
	for s in [3, 4, 5]:
		var a := BattleState.new(Fixtures.map(), Fixtures.party(), s)
		var b := BattleState.new(Fixtures.map(), Fixtures.party(), s)
		a.start()
		b.start()
		AutoPlay.play_to_end(a)
		AutoPlay.play_to_end(b)
		assert_eq(Golden.normalize(a.history.map(func(c: Command) -> Dictionary: return c.to_dict())),
			Golden.normalize(b.history.map(func(c: Command) -> Dictionary: return c.to_dict())))


func test_ai_is_fast() -> void:
	var b := Fixtures.battle(1)
	var worst := 0.0
	for i in 30:
		if b.outcome() != BattleState.Outcome.ONGOING:
			break
		var t0 := Time.get_ticks_usec()
		AiPlanner.choose(b, b.current_actor())
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
		AutoPlay.play_turn(b)
	assert_true(worst < 100.0, "worst AI think time %.1f ms" % worst)
