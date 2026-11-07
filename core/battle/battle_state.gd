class_name BattleState
extends RefCounted
## One battle. apply(cmd) is the ONLY way to change it (doc/02 §2).
## Same map + party + seed + commands = same result, every time.

enum Outcome { ONGOING, WON, LOST }

var map: MapData
var grid: Grid
var rng: Rng
var queue := TurnQueue.new()
var flags: Dictionary = {}
var history: Array[Command] = []      # every applied command, for replays
var bonds := Bonds.new()              # a copy of the campaign's bonds; merged back after

var _units: Array[Unit] = []
var _actor: Unit
var _moved := false
var _outcome := Outcome.ONGOING
var _next_id := 1


## party: player units (copied, so the caller's roster is never changed).
func _init(p_map: MapData, party: Array[Unit], p_seed: int) -> void:
	map = p_map
	grid = Grid.new(p_map)
	rng = Rng.new(p_seed)
	var n := mini(party.size(), p_map.player_spawns.size())
	for i in n:
		var u := party[i].copy()
		u.faction = Enums.Faction.PLAYER
		_add(u, p_map.player_spawns[i])
	for e in p_map.enemies:
		spawn_enemy(e)


## Rebuilds a battle by replaying commands (suspend saves, golden tests, bug reports).
static func replay(p_map: MapData, party: Array[Unit], p_seed: int, cmds: Array, p_bonds: Bonds = null) -> BattleState:
	var b := BattleState.new(p_map, party, p_seed)
	if p_bonds != null:
		b.bonds = p_bonds.copy()
	b.start()
	for c in cmds:
		var cmd: Command = c if c is Command else Command.from_dict(c)
		b.apply(cmd)
	return b


## Starts round 1. Returns the opening events.
func start() -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	_next_turn(out)
	return out


## THE entry point. Returns what happened, in order. Empty = command rejected.
func apply(cmd: Command) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	if not _accepts(cmd):
		print_verbose("BattleState: rejected %s" % cmd)
		return out
	cmd.execute(self, out)
	history.append(cmd)
	_outcome = Rules.check_outcome(self)
	if _outcome != Outcome.ONGOING:
		out.append(BattleEvent.make(BattleEvent.BATTLE_ENDED, {"outcome": _outcome}))
		_actor = null
		return out
	if cmd.ends_turn() or not _actor.is_alive():
		out.append(BattleEvent.make(BattleEvent.TURN_ENDED, {"unit_id": _actor.id}))
		_next_turn(out)
	return out


## Every command the unit could legally issue right now (for the HUD and AI).
func legal_commands(u: Unit) -> Array[Command]:
	var out: Array[Command] = []
	if u != _actor or _outcome != Outcome.ONGOING:
		return out
	if not _moved:
		for t: Vector2i in Pathfinder.reachable(grid, u):
			if t != u.pos:
				out.append(MoveCommand.to_tile(u.id, t))
	for t in living():
		var c := AttackCommand.on(u.id, t.id)
		if c.is_valid(self):
			out.append(c)
	for sp in u.class_data.spells:
		for lv in sp.levels.size():
			for t in living():
				var cast := CastCommand.at_tile(u.id, sp.id, lv + 1, t.pos)
				if cast.is_valid(self):
					out.append(cast)
	for i in u.items.size():
		var eq := EquipCommand.slot_of(u.id, i)
		if eq.is_valid(self):
			out.append(eq)
		for ally in living(u.faction):
			var use := UseItemCommand.on(u.id, i, ally.id)
			if use.is_valid(self):
				out.append(use)
	out.append(WaitCommand.by(u.id))
	return out


func spawn_enemy(e: EnemySpawn) -> Unit:
	var u := Unit.from_data(e.unit, Enums.Faction.ENEMY)
	u.level = e.level
	u.ai = e.ai
	u.tag = e.tag
	u.is_leader = e.is_leader
	_add(u, e.at)
	return u


func outcome() -> Outcome:
	return _outcome


func units() -> Array[Unit]:
	return _units


func living(faction: int = -1) -> Array[Unit]:
	return _units.filter(func(u: Unit) -> bool: return u.is_alive() and (faction < 0 or u.faction == faction))


func unit(id: int) -> Unit:
	for u in _units:
		if u.id == id:
			return u
	return null


func current_actor() -> Unit:
	return _actor


func has_moved() -> bool:
	return _moved


func round_number() -> int:
	return queue.round_number


## Called by commands only.
func mark_moved() -> void:
	_moved = true


## Called by Rules when a unit's HP reaches 0.
func on_unit_died(u: Unit, out: Array[BattleEvent]) -> void:
	grid.vacate(u.pos)
	out.append(BattleEvent.make(BattleEvent.DIED, {"unit_id": u.id}))


## Plain-data picture of the whole battle (for tests and golden files).
func snapshot() -> Dictionary:
	return {
		"round": round_number(),
		"actor": _actor.id if _actor != null else 0,
		"moved": _moved,
		"outcome": _outcome,
		"flags": flags.duplicate(),
		"bonds": bonds.to_dict(),
		"units": _units.map(func(u: Unit) -> Dictionary: return u.to_dict()),
	}


## Debug/test helper: returns broken invariants (empty = all good).
func check_invariants() -> PackedStringArray:
	var errs := PackedStringArray()
	var seen := {}
	for u in _units:
		if u.hp < 0 or u.hp > u.max_hp():
			errs.append("unit %d hp %d out of 0..%d" % [u.id, u.hp, u.max_hp()])
		if u.mp < 0 or u.mp > u.max_mp():
			errs.append("unit %d mp %d out of 0..%d" % [u.id, u.mp, u.max_mp()])
		if not u.is_alive():
			if grid.unit_at(u.pos) == u:
				errs.append("dead unit %d still on the grid" % u.id)
			continue
		if not grid.in_bounds(u.pos):
			errs.append("unit %d out of bounds at %s" % [u.id, u.pos])
		if seen.has(u.pos):
			errs.append("units %d and %d share %s" % [seen[u.pos], u.id, u.pos])
		seen[u.pos] = u.id
		if grid.unit_at(u.pos) != u:
			errs.append("grid does not know unit %d at %s" % [u.id, u.pos])
	if _outcome == Outcome.ONGOING and (_actor == null or not _actor.is_alive()):
		errs.append("no living actor while the battle is ongoing")
	return errs


func _accepts(cmd: Command) -> bool:
	if cmd == null or _outcome != Outcome.ONGOING or _actor == null:
		return false
	if cmd.unit_id != _actor.id:
		return false
	return cmd.is_valid(self)


func _next_turn(out: Array[BattleEvent]) -> void:
	_moved = false
	_actor = queue.next()
	if _actor == null:
		queue.start_round(_units, rng)
		out.append(BattleEvent.make(BattleEvent.ROUND_STARTED, {"round": queue.round_number}))
		_actor = queue.next()
	out.append(BattleEvent.make(BattleEvent.TURN_STARTED, {"unit_id": _actor.id}))


func _add(u: Unit, at: Vector2i) -> void:
	u.id = _next_id
	_next_id += 1
	_units.append(u)
	grid.place(u, at)
