extends TestCase
## Step 2: Rng, Unit, Grid, TurnQueue, BattleState construction.


# --- Rng ---------------------------------------------------------------

func test_rng_same_seed_same_sequence() -> void:
	var a := Rng.new(42)
	var b := Rng.new(42)
	for i in 1000:
		if a.between(0.0, 1.0) != b.between(0.0, 1.0):
			fail("diverged at %d" % i)
			return


func test_rng_different_seeds_differ() -> void:
	var a := Rng.new(1)
	var b := Rng.new(2)
	var same := 0
	for i in 100:
		if a.roll(0, 1000) == b.roll(0, 1000):
			same += 1
	assert_true(same < 10, "too many equal rolls: %d" % same)


func test_rng_bounds() -> void:
	var r := Rng.new(7)
	for i in 1000:
		assert_between(r.between(0.875, 1.125), 0.875, 1.125)
		assert_between(r.roll(1, 6), 1, 6)


# --- Unit --------------------------------------------------------------

func test_unit_from_data_equips_weapon() -> void:
	var u := Unit.from_data(Fixtures.unit_data("hero"))
	assert_eq(u.hp, 20)
	assert_eq(u.weapon().id, &"bronze_sword")
	assert_eq(u.stats().atk, 15, "base 10 + sword 5")
	assert_eq(u.attack_range(), Vector2i(1, 1))
	var archer := Unit.from_data(Fixtures.unit_data("archer"))
	assert_eq(archer.attack_range(), Vector2i(2, 3))


func test_unit_dict_round_trip() -> void:
	Fixtures.map()  # registers fixture content
	var u := Unit.from_data(Fixtures.unit_data("hero"))
	u.id = 3
	u.pos = Vector2i(2, 5)
	u.hp = 7
	u.xp = 55
	var d := u.to_dict()
	assert_eq(Unit.from_dict(d).to_dict(), d)


func test_unit_copy_is_independent() -> void:
	Fixtures.map()
	var u := Unit.from_data(Fixtures.unit_data("hero"))
	var c := u.copy()
	c.hp = 1
	c.base.atk = 99
	assert_eq(u.hp, 20)
	assert_eq(u.base.atk, 10)


# --- Grid --------------------------------------------------------------

func test_grid_lookups() -> void:
	var g := Grid.new(Fixtures.map())
	assert_true(g.in_bounds(Vector2i(7, 7)))
	assert_false(g.in_bounds(Vector2i(8, 0)))
	assert_false(g.in_bounds(Vector2i(-1, 0)))
	assert_eq(g.height(Vector2i(3, 3)), 2)
	assert_eq(g.height(Vector2i(0, 0)), 0)
	assert_eq(g.terrain(Vector2i(2, 5)).id, &"forest")
	assert_eq(g.move_cost(Vector2i(2, 5), Enums.MoveType.FOOT), 2)
	assert_near(g.land_effect(Vector2i(3, 4)), 0.30, 0.001)


func test_grid_neighbors() -> void:
	var g := Grid.new(Fixtures.map())
	assert_eq(g.neighbors(Vector2i(0, 0)).size(), 2)
	assert_eq(g.neighbors(Vector2i(0, 3)).size(), 3)
	assert_eq(g.neighbors(Vector2i(3, 3)).size(), 4)


func test_grid_occupancy() -> void:
	var g := Grid.new(Fixtures.map())
	var u := Unit.from_data(Fixtures.unit_data("hero"))
	g.place(u, Vector2i(2, 2))
	assert_true(g.unit_at(Vector2i(2, 2)) == u)
	assert_eq(u.pos, Vector2i(2, 2))
	g.move(u, Vector2i(2, 3))
	assert_true(g.unit_at(Vector2i(2, 2)) == null)
	assert_true(g.unit_at(Vector2i(2, 3)) == u)
	g.vacate(Vector2i(2, 3))
	assert_true(g.unit_at(Vector2i(2, 3)) == null)


# --- TurnQueue ---------------------------------------------------------

func _two_units(agi_a: int, agi_b: int) -> Array[Unit]:
	var a := Unit.from_data(Fixtures.unit_data("hero"))
	var b := Unit.from_data(Fixtures.unit_data("goblin"), Enums.Faction.ENEMY)
	a.id = 1
	b.id = 2
	a.base.agi = agi_a
	b.base.agi = agi_b
	return [a, b]


func test_turn_order_is_deterministic() -> void:
	var b1 := Fixtures.battle(99)
	var b2 := Fixtures.battle(99)
	var ids1 := b1.queue.peek(10).map(func(u: Unit) -> int: return u.id)
	var ids2 := b2.queue.peek(10).map(func(u: Unit) -> int: return u.id)
	assert_eq(ids1, ids2)
	assert_eq(b1.current_actor().id, b2.current_actor().id)


func test_turn_order_favors_agility() -> void:
	var units := _two_units(10, 8)
	var first_a := 0
	for s in 1000:
		var q := TurnQueue.new()
		q.start_round(units, Rng.new(s))
		if q.next().id == 1:
			first_a += 1
	assert_true(first_a > 900, "faster unit first in %d/1000" % first_a)


func test_turn_order_skips_dead_and_ends_round() -> void:
	var units := _two_units(10, 8)
	var q := TurnQueue.new()
	q.start_round(units, Rng.new(1))
	units[1].hp = 0
	assert_eq(q.next().id, 1)
	assert_true(q.next() == null, "dead unit skipped, round over")
	assert_eq(q.round_number, 1)


func test_turn_order_tie_goes_to_player() -> void:
	var units := _two_units(0, 0)  # both roll 0 initiative
	units[0].id = 5                 # player has the higher id
	var q := TurnQueue.new()
	q.start_round(units, Rng.new(1))
	assert_eq(q.next().faction, Enums.Faction.PLAYER)


# --- BattleState -------------------------------------------------------

func test_battle_builds_from_map() -> void:
	var b := Fixtures.battle(1)
	assert_eq(b.units().size(), 8)
	assert_eq(b.living(Enums.Faction.PLAYER).size(), 4)
	assert_eq(b.living(Enums.Faction.ENEMY).size(), 4)
	var map := Fixtures.map()
	for i in 4:
		assert_true(b.grid.unit_at(map.player_spawns[i]).faction == Enums.Faction.PLAYER)
	for e in map.enemies:
		assert_true(b.grid.unit_at(e.at).faction == Enums.Faction.ENEMY)
	assert_eq(b.round_number(), 1)
	assert_true(b.current_actor() != null)
	assert_eq(Array(b.check_invariants()), [])


func test_battle_ids_unique_and_boss_tagged() -> void:
	var b := Fixtures.battle(1)
	var ids := {}
	for u in b.units():
		ids[u.id] = true
	assert_eq(ids.size(), 8)
	var bosses := b.units().filter(func(u: Unit) -> bool: return u.tag == &"boss")
	assert_eq(bosses.size(), 1)
	assert_true(bosses[0].is_leader)


func test_battle_does_not_change_callers_party() -> void:
	var party := Fixtures.party()
	var b := BattleState.new(Fixtures.map(), party, 1)
	b.units()[0].hp = 1
	assert_eq(party[0].hp, 20)
	assert_eq(party[0].id, 0)
