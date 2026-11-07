class_name BattleState
extends RefCounted
## One battle. Holds all battle state. From step 4 on, apply(cmd) is the only way to change it.

enum Outcome { ONGOING, WON, LOST }

var map: MapData
var grid: Grid
var rng: Rng
var queue := TurnQueue.new()
var flags: Dictionary = {}

var _units: Array[Unit] = []
var _actor: Unit
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


func spawn_enemy(e: EnemySpawn) -> Unit:
	var u := Unit.from_data(e.unit, Enums.Faction.ENEMY)
	u.level = e.level
	u.ai = e.ai
	u.tag = e.tag
	u.is_leader = e.is_leader
	_add(u, e.at)
	return u


## Starts round 1 and picks the first actor.
func start() -> void:
	_start_round()


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


func round_number() -> int:
	return queue.round_number


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
			continue
		if not grid.in_bounds(u.pos):
			errs.append("unit %d out of bounds at %s" % [u.id, u.pos])
		if seen.has(u.pos):
			errs.append("units %d and %d share %s" % [seen[u.pos], u.id, u.pos])
		seen[u.pos] = u.id
		if grid.unit_at(u.pos) != u:
			errs.append("grid does not know unit %d at %s" % [u.id, u.pos])
	if _actor != null and not _actor.is_alive():
		errs.append("current actor %d is dead" % _actor.id)
	return errs


func _add(u: Unit, at: Vector2i) -> void:
	u.id = _next_id
	_next_id += 1
	_units.append(u)
	grid.place(u, at)


func _start_round() -> void:
	queue.start_round(_units, rng)
	_actor = queue.next()
