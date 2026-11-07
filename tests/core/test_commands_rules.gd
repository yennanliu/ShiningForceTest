extends TestCase
## Step 4: commands, events, combat rules.

const P := Enums.Faction.PLAYER
const E := Enums.Faction.ENEMY


func _hero(b: BattleState) -> Unit:
	return b.living(P)[0]


func _goblin(b: BattleState) -> Unit:
	return b.living(E)[0]


func _types(events: Array[BattleEvent]) -> Array:
	return events.map(func(e: BattleEvent) -> String: return String(e.type))


# --- the contract ------------------------------------------------------

func test_invalid_commands_are_rejected_without_changes() -> void:
	var b := Fixtures.duel([Vector2i(0, 0), Vector2i(0, 1)], [Vector2i(7, 7)])
	var hero := _hero(b)
	var gob := _goblin(b)
	Fixtures.act_as(b, hero)
	var before := b.snapshot()
	var bad: Array[Command] = [
		WaitCommand.by(gob.id),                             # not your turn
		AttackCommand.on(hero.id, gob.id),                  # out of range
		AttackCommand.on(hero.id, b.living(P)[1].id),       # ally
		MoveCommand.to_tile(hero.id, Vector2i(7, 0)),       # too far
		MoveCommand.to_tile(hero.id, hero.pos),             # not a move
		EquipCommand.slot_of(hero.id, 9),                   # no such slot
		null,
	]
	for c in bad:
		assert_eq(b.apply(c).size(), 0, "should reject %s" % c)
	assert_eq(b.snapshot(), before)
	assert_eq(b.history.size(), 0, "rejected commands are not recorded")


func test_turn_shape_move_then_act() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(3, 0)])
	var hero := _hero(b)
	var gob := _goblin(b)
	Fixtures.act_as(b, hero)
	var ev := b.apply(MoveCommand.to_tile(hero.id, Vector2i(2, 0)))
	assert_eq(_types(ev), ["moved"])
	assert_eq(b.current_actor(), hero, "move does not end the turn")
	assert_eq(b.apply(MoveCommand.to_tile(hero.id, Vector2i(1, 0))).size(), 0, "only one move")
	ev = b.apply(AttackCommand.on(hero.id, gob.id))
	assert_true(_types(ev).has("attacked"))
	assert_ne(b.current_actor(), hero, "attack ends the turn")


func test_wait_ends_turn() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var actor := b.current_actor()
	var ev := b.apply(WaitCommand.by(actor.id))
	assert_eq(_types(ev)[0], "turn_ended")
	assert_eq(_types(ev)[-1], "turn_started")
	assert_ne(b.current_actor(), actor)


func test_rounds_advance() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	b.apply(WaitCommand.by(b.current_actor().id))
	var ev := b.apply(WaitCommand.by(b.current_actor().id))
	assert_true(_types(ev).has("round_started"))
	assert_eq(b.round_number(), 2)


# --- formulas ----------------------------------------------------------

func test_hit_chance_is_clamped() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var hero := _hero(b)
	var gob := _goblin(b)
	hero.base.luk = 0
	gob.base.agi = 500
	assert_near(Rules.hit_chance(b, hero, gob), 0.10, 0.0001)
	hero.base.luk = 500
	assert_near(Rules.hit_chance(b, hero, gob), 0.99, 0.0001)
	hero.base.luk = 5
	gob.base.agi = 6
	assert_near(Rules.hit_chance(b, hero, gob), 0.92, 0.0001, "90 + 5 - 3")


func test_damage_range_and_minimum() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var hero := _hero(b)   # atk 10 + sword 5 = 15
	var gob := _goblin(b)  # def 4
	assert_eq(Rules.damage_range(b, hero, gob), Vector2i(9, 12), "raw 11 x 0.9..1.1")
	gob.base.def = 100
	assert_eq(Rules.damage_range(b, hero, gob), Vector2i(1, 1), "minimum 1")


func test_land_effect_lowers_damage() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], 1, Vector2i(8, 8), {Vector2i(1, 0): [2, 0]})
	var hero := _hero(b)
	var gob := _goblin(b)
	assert_near(Rules.raw_damage(b, hero, gob), 15 - 4 * 1.3, 0.001, "hill +30% defense")


func test_forecast_contains_actual_damage() -> void:
	var seen := 0
	for s in 1000:
		var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], s)
		var hero := _hero(b)
		var gob := _goblin(b)
		Fixtures.act_as(b, hero)
		var fc := Rules.forecast(b, hero, gob)
		var ev := b.apply(AttackCommand.on(hero.id, gob.id))
		var normal_hit := false
		for e in ev:
			if e.type == BattleEvent.ATTACKED and not e.data.counter:
				normal_hit = e.data.hit and not e.data.crit
			if e.type == BattleEvent.DAMAGED and e.data.unit_id == gob.id and normal_hit:
				seen += 1
				if e.data.amount < fc.dmg.x or e.data.amount > fc.dmg.y:
					fail("seed %d: %d outside %s" % [s, e.data.amount, fc.dmg])
					return
	assert_true(seen > 800, "only %d normal hits checked" % seen)


func test_forecast_does_not_touch_rng() -> void:
	var b1 := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], 5)
	var b2 := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], 5)
	for i in 10:
		Rules.forecast(b1, _hero(b1), _goblin(b1))
	assert_eq(b1.rng.between(0, 1), b2.rng.between(0, 1))


func test_xp_formula() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var hero := _hero(b)
	var gob := _goblin(b)
	assert_eq(Rules.xp_for(hero, gob, false), 10)
	assert_eq(Rules.xp_for(hero, gob, true), 48)
	gob.level = 5
	assert_eq(Rules.xp_for(hero, gob, true), 49, "clamped")
	gob.level = 1
	hero.level = 10
	assert_eq(Rules.xp_for(hero, gob, false), 1, "clamped low")


# --- events ------------------------------------------------------------

func test_killing_blow_event_order() -> void:
	for s in 50:
		var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0), Vector2i(7, 7)], s)
		var hero := _hero(b)
		var gob := b.grid.unit_at(Vector2i(1, 0))
		Fixtures.act_as(b, hero)
		gob.hp = 1
		var t := _types(b.apply(AttackCommand.on(hero.id, gob.id)))
		if t[1] != "damaged":
			continue   # missed with this seed, try the next
		assert_eq(t.slice(0, 4), ["attacked", "damaged", "died", "xp_gained"])
		assert_eq(t[4], "turn_ended")
		assert_true(b.grid.unit_at(Vector2i(1, 0)) == null, "dead unit leaves the grid")
		assert_eq(hero.xp, 48)
		return
	fail("never hit in 50 seeds")


func test_use_item_heals_and_consumes() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := _hero(b)
	Fixtures.act_as(b, hero)
	hero.hp = 5
	var herb := hero.items.find(Fixtures.item("herb"))
	assert_true(herb >= 0)
	var t := _types(b.apply(UseItemCommand.on(hero.id, herb, hero.id)))
	assert_eq(t.slice(0, 2), ["item_used", "healed"])
	assert_eq(hero.hp, 15)
	assert_eq(hero.items.size(), 1)
	assert_eq(hero.weapon().id, &"bronze_sword", "weapon slot still right")


func test_equip_does_not_end_turn() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := _hero(b)
	Fixtures.act_as(b, hero)
	hero.items.append(Fixtures.item("bronze_sword"))
	assert_eq(_types(b.apply(EquipCommand.slot_of(hero.id, 2))), ["equipped"])
	assert_eq(hero.weapon_slot, 2)
	assert_eq(b.current_actor(), hero)
	hero.items.append(Fixtures.item("wooden_bow"))
	assert_eq(b.apply(EquipCommand.slot_of(hero.id, 3)).size(), 0, "swordsman can't use a bow")


# --- outcome -----------------------------------------------------------

func test_win_when_all_enemies_die() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var hero := _hero(b)
	Fixtures.act_as(b, hero)
	_goblin(b).hp = 1
	hero.base.luk = 500
	var t := _types(b.apply(AttackCommand.on(hero.id, _goblin(b).id)))
	assert_eq(t[-1], "battle_ended")
	assert_eq(b.outcome(), BattleState.Outcome.WON)
	assert_eq(b.apply(WaitCommand.by(hero.id)).size(), 0, "no commands after the end")


func test_lose_when_leader_dies() -> void:
	var b := Fixtures.duel([Vector2i(0, 0), Vector2i(5, 5)], [Vector2i(1, 0), Vector2i(7, 7)])
	var hero := _hero(b)
	var gob := b.grid.unit_at(Vector2i(1, 0))
	Fixtures.act_as(b, gob)
	hero.hp = 1
	gob.base.luk = 500
	b.apply(AttackCommand.on(gob.id, hero.id))
	assert_eq(b.outcome(), BattleState.Outcome.LOST)


# --- replay, serialization, invariants --------------------------------

func test_command_dict_round_trip() -> void:
	var cmds: Array[Command] = [
		MoveCommand.to_tile(3, Vector2i(4, 5)), AttackCommand.on(3, 7), EquipCommand.slot_of(3, 1),
		UseItemCommand.on(3, 0, 4), WaitCommand.by(3),
	]
	for c in cmds:
		assert_eq(Command.from_dict(c.to_dict()).to_dict(), c.to_dict())


func test_random_play_keeps_invariants_and_replays() -> void:
	for s in 20:
		var b := Fixtures.battle(s)
		var picker := RandomNumberGenerator.new()
		picker.seed = s
		for i in 60:
			if b.outcome() != BattleState.Outcome.ONGOING:
				break
			var options := b.legal_commands(b.current_actor())
			var c: Command = options[picker.randi_range(0, options.size() - 1)]
			assert_true(b.apply(c).size() > 0, "legal command rejected: %s" % c)
			var errs := b.check_invariants()
			if not errs.is_empty():
				fail("seed %d step %d: %s" % [s, i, errs])
				return
		var dicts := b.history.map(func(c: Command) -> Dictionary: return c.to_dict())
		var r := BattleState.replay(Fixtures.map(), Fixtures.party(), s, dicts)
		assert_eq(r.snapshot(), b.snapshot(), "replay of seed %d" % s)
