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


func test_prefers_the_kill() -> void:
	# Two adjacent players; the knight has 1 HP. The goblin should finish the knight.
	var b := Fixtures.duel([Vector2i(3, 3), Vector2i(5, 3)], [Vector2i(4, 3)])
	var gob := b.living(E)[0]
	var knight := b.grid.unit_at(Vector2i(5, 3))
	knight.hp = 1
	Fixtures.act_as(b, gob)
	gob.ai = Enums.AiProfile.HOLD   # don't let movement muddy the test
	var plan := AiPlanner.choose(b, gob)
	assert_eq((plan[-1] as AttackCommand).target_id, knight.id)


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


func test_goes_around_walls() -> void:
	# A wall column at x=3 with one gap at y=7. Straight-line distance would get stuck.
	var walls := {}
	for y in 7:
		walls[Vector2i(3, y)] = [3, 0]
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(6, 0)], 1, Vector2i(8, 8), walls)
	var gob := b.living(E)[0]
	var hero := b.living(P)[0]
	hero.ai = Enums.AiProfile.HOLD
	for i in 20:
		if b.outcome() != BattleState.Outcome.ONGOING:
			break
		AutoPlay.play_turn(b)
	assert_true(b.outcome() != BattleState.Outcome.ONGOING or Pathfinder.distance(gob.pos, hero.pos) <= 1,
		"goblin found the gap (at %s)" % gob.pos)


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
