class_name BattleLog
## Writes the current battle (campaign + seed + commands) to user://logs/last_battle.json,
## so any battle — including one that hit a bug — can be replayed exactly.

const PATH := "user://logs/last_battle.json"


static func write(c: Campaign, b: BattleState, path := PATH) -> Error:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify({
		"version": 1,
		"map": String(b.map.id),
		"campaign": c.to_dict(),
		"seed": b.rng.start_seed,
		"commands": b.history.map(func(cmd: Command) -> Dictionary: return cmd.to_dict()),
	}, "  "))
	return OK


static func read(path := PATH) -> Dictionary:
	var json := JSON.new()
	if not FileAccess.file_exists(path) or json.parse(FileAccess.get_file_as_string(path)) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


static func rebuild(log: Dictionary) -> BattleState:
	var c := Campaign.from_dict(log.campaign)
	var b := c.start_battle(int(log.seed))
	b.start()
	for cmd in log.commands:
		b.apply(Command.from_dict(cmd))
	return b
