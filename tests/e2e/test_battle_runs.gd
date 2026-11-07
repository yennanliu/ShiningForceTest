extends TestCase
## Step 5: whole battles, headless, AI on both sides.


func _maps() -> Array[MapData]:
	var out: Array[MapData] = [Fixtures.map()]
	for f in DirAccess.get_files_at("res://data/maps/"):
		if f.ends_with(".tres"):
			out.append(load("res://data/maps/" + f))
	return out


func test_every_map_finishes_for_50_seeds() -> void:
	for m in _maps():
		for s in 50:
			var b := BattleState.new(m, Fixtures.party(), s)
			b.start()
			var outcome := AutoPlay.play_to_end(b, 200)
			if outcome == BattleState.Outcome.ONGOING:
				fail("%s seed %d did not finish in 200 rounds" % [m.id, s])
				return
			var errs := b.check_invariants()
			if not errs.is_empty():
				fail("%s seed %d: %s" % [m.id, s, errs])
				return


func test_random_play_invariants_500_seeds() -> void:
	for s in 500:
		var b := Fixtures.battle(s)
		var picker := RandomNumberGenerator.new()
		picker.seed = s
		for i in 25:
			if b.outcome() != BattleState.Outcome.ONGOING:
				break
			var options := b.legal_commands(b.current_actor())
			b.apply(options[picker.randi_range(0, options.size() - 1)])
			var errs := b.check_invariants()
			if not errs.is_empty():
				fail("seed %d step %d: %s" % [s, i, errs])
				return


func test_golden_replays_match() -> void:
	for seed in Golden.CASES:
		var f := FileAccess.open(Golden.path(seed), FileAccess.READ)
		assert_true(f != null, "missing %s; run tools/make_golden.gd" % Golden.path(seed))
		if f == null:
			continue
		var g: Dictionary = JSON.parse_string(f.get_as_text())
		var b := BattleState.replay(Fixtures.map(), Fixtures.party(), int(g.seed), g.commands)
		assert_eq(Golden.normalize(b.snapshot()), Golden.normalize(g.final), "golden seed %d" % seed)
