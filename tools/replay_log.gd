extends SceneTree
## Replays user://logs/last_battle.json (or --file=...) and prints the final state.
## Attach that file to bug reports: the battle can be rebuilt exactly.
##   godot --headless --path . -s res://tools/replay_log.gd [-- --file=path]


func _initialize() -> void:
	var path := "user://logs/last_battle.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--file="):
			path = a.trim_prefix("--file=")
	var log := BattleLog.read(path)
	if log.is_empty():
		print("no battle log at %s" % path)
		quit(1)
		return
	var b := BattleLog.rebuild(log)
	print("map %s, seed %d, %d commands -> round %d, outcome %s" % [
		log.map, log.seed, log.commands.size(), b.round_number(), BattleState.Outcome.keys()[b.outcome()]])
	quit()
