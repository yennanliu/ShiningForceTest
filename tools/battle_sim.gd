extends SceneTree
## Balance tool: AI plays both sides many times and reports stats.
##   godot --headless --path . -s res://tools/battle_sim.gd -- --runs=200 [--map=res://data/maps/m01.tres]
## Without --map it uses the 8x8 test fixture and the fixture party.


func _initialize() -> void:
	var runs := 100
	var map_path := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--runs="):
			runs = int(a.trim_prefix("--runs="))
		elif a.begins_with("--map="):
			map_path = a.trim_prefix("--map=")
	Content.register_dir("res://tests/fixtures/")
	var map: MapData = load(map_path) if map_path != "" else load("res://tests/fixtures/map_8x8.tres")

	var wins := 0
	var rounds := 0
	var player_deaths := 0
	var unfinished := 0
	var max_ai_ms := 0.0
	for seed in runs:
		var party: Array[Unit] = []
		for id in ["hero", "knight", "archer", "scout"]:
			party.append(Unit.from_data(load("res://tests/fixtures/unit_%s.tres" % id)))
		party[0].is_leader = true
		var b := BattleState.new(map, party, seed)
		b.start()
		for turn in 200 * b.units().size():
			if b.outcome() != BattleState.Outcome.ONGOING or b.round_number() > 200:
				break
			var t0 := Time.get_ticks_usec()
			AiPlanner.choose(b, b.current_actor())
			max_ai_ms = maxf(max_ai_ms, (Time.get_ticks_usec() - t0) / 1000.0)
			AutoPlay.play_turn(b)
		match b.outcome():
			BattleState.Outcome.WON: wins += 1
			BattleState.Outcome.ONGOING: unfinished += 1
		rounds += b.round_number()
		player_deaths += b.units().filter(func(u: Unit) -> bool: return u.faction == Enums.Faction.PLAYER and not u.is_alive()).size()

	print("map:            %s" % map.id)
	print("runs:           %d" % runs)
	print("player win rate: %.0f%%" % (100.0 * wins / runs))
	print("unfinished:     %d" % unfinished)
	print("avg rounds:     %.1f" % (float(rounds) / runs))
	print("avg deaths:     %.2f player units" % (float(player_deaths) / runs))
	print("max AI think:   %.1f ms" % max_ai_ms)
	quit()
