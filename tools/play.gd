extends SceneTree
## Play a battle in the terminal. No GPU needed.
##   godot --headless --path . -s res://tools/play.gd [-- --seed=7]
##   tools/docker.sh play


func _initialize() -> void:
	var seed := int(Time.get_unix_time_from_system())
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed = int(a.trim_prefix("--seed="))
	var state := BattleState.new(Fixtures.map(), Fixtures.party(), seed)
	var game := TerminalGame.new(state, func() -> String: return OS.read_string_from_stdin(), func(t: String) -> void: print(t))
	game.run()
	quit()
