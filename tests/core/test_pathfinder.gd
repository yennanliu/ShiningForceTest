extends TestCase
## Step 3: pathfinding.


func test_open_map_diamond_of_61_tiles() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(15, 15)))
	var u := Fixtures.unit_on(g, Vector2i(7, 7))   # foot, MOV 5
	var r := Pathfinder.reachable(g, u)
	assert_eq(r.size(), 61)
	assert_eq(r[Vector2i(7, 7)], 0)
	assert_eq(r[Vector2i(7, 2)], 5)
	assert_false(r.has(Vector2i(7, 1)))


func test_forest_costs_two_for_foot() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(10, 1), {Vector2i(1, 0): [1, 0]}))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	var r := Pathfinder.reachable(g, u)
	assert_eq(r[Vector2i(1, 0)], 2)
	assert_eq(r[Vector2i(4, 0)], 5)
	assert_false(r.has(Vector2i(5, 0)))


func test_forest_costs_one_for_flying() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(10, 1), {Vector2i(1, 0): [1, 0]}))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	u.class_data = u.class_data.duplicate()
	u.class_data.move_type = Enums.MoveType.FLYING
	var r := Pathfinder.reachable(g, u)
	assert_eq(r[Vector2i(1, 0)], 1)
	assert_eq(r[Vector2i(5, 0)], 5)


func test_wall_is_impassable() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(5, 1), {Vector2i(1, 0): [3, 0]}))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	assert_eq(Pathfinder.reachable(g, u).size(), 1)


func test_height_limits_jump() -> void:
	# A 3-high block at x=1 blocks jump 2 but not jump 3.
	var g := Grid.new(Fixtures.open_map(Vector2i(4, 1), {Vector2i(1, 0): [0, 3]}))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	assert_false(Pathfinder.reachable(g, u).has(Vector2i(1, 0)), "jump 2 blocked")
	u.class_data = u.class_data.duplicate()
	u.class_data.jump = 3
	var r := Pathfinder.reachable(g, u)
	assert_true(r.has(Vector2i(1, 0)), "jump 3 can climb")
	assert_true(r.has(Vector2i(2, 0)), "and drop back down")


func test_pass_through_ally_but_not_stop() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(6, 1)))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	Fixtures.unit_on(g, Vector2i(1, 0))   # ally
	var r := Pathfinder.reachable(g, u)
	assert_false(r.has(Vector2i(1, 0)), "can't stop on ally")
	assert_true(r.has(Vector2i(2, 0)), "can pass through ally")


func test_enemy_blocks() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(6, 1)))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	Fixtures.unit_on(g, Vector2i(1, 0), Enums.Faction.ENEMY, "goblin")
	assert_eq(Pathfinder.reachable(g, u).size(), 1)


func test_dead_units_do_not_block() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(6, 1)))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	var e := Fixtures.unit_on(g, Vector2i(1, 0), Enums.Faction.ENEMY, "goblin")
	e.hp = 0
	assert_true(Pathfinder.reachable(g, u).has(Vector2i(1, 0)))


func test_path_is_contiguous_and_cost_matches() -> void:
	var m := Fixtures.map()
	var g := Grid.new(m)
	var u := Fixtures.unit_on(g, Vector2i(0, 7))
	var r := Pathfinder.reachable(g, u)
	for to: Vector2i in r:
		var path := Pathfinder.path_to(g, u, to)
		assert_eq(path[0], u.pos)
		assert_eq(path[-1], to)
		var cost := 0
		for i in range(1, path.size()):
			assert_eq(Pathfinder.distance(path[i - 1], path[i]), 1, "step %s->%s" % [path[i - 1], path[i]])
			cost += g.move_cost(path[i], u.move_type())
		assert_eq(cost, r[to], "cost to %s" % to)


func test_path_to_unreachable_is_empty() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(15, 15)))
	var u := Fixtures.unit_on(g, Vector2i(0, 0))
	assert_eq(Pathfinder.path_to(g, u, Vector2i(14, 14)).size(), 0)


func test_bow_ring_excludes_adjacent() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(9, 9)))
	var tiles := Pathfinder.attack_tiles(g, Vector2i(4, 4), Vector2i(2, 3))
	assert_false(tiles.has(Vector2i(4, 5)), "adjacent excluded")
	assert_false(tiles.has(Vector2i(4, 4)))
	assert_true(tiles.has(Vector2i(4, 6)))
	assert_true(tiles.has(Vector2i(5, 6)))
	assert_eq(tiles.size(), 8 + 12)   # ring 2 has 8 tiles, ring 3 has 12


func test_melee_ring_is_four_tiles() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(9, 9)))
	assert_eq(Pathfinder.attack_tiles(g, Vector2i(4, 4), Vector2i(1, 1)).size(), 4)
	assert_eq(Pathfinder.attack_tiles(g, Vector2i(0, 0), Vector2i(1, 1)).size(), 2)


func test_reachable_is_fast_on_32x32() -> void:
	var g := Grid.new(Fixtures.open_map(Vector2i(32, 32)))
	var u := Fixtures.unit_on(g, Vector2i(16, 16))
	u.class_data = u.class_data.duplicate()
	u.class_data.mov = 6   # the largest MOV we plan to use
	var times: Array[int] = []
	for i in 100:
		var t0 := Time.get_ticks_usec()
		Pathfinder.reachable(g, u)
		times.append(Time.get_ticks_usec() - t0)
	times.sort()
	var median_ms := times[50] / 1000.0
	assert_true(median_ms < 2.0, "median %.3f ms" % median_ms)
	print("        reachable 32x32 MOV 6: median %.3f ms" % median_ms)
