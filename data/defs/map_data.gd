class_name MapData
extends Resource
## A battle map as data: the tile grid, spawns, triggers and objective.
## The 3D scene that draws it is `scene` (optional for tests).

@export var id: StringName
@export var size := Vector2i(8, 8)
## Row-major (index = y * size.x + x). Values 0–8.
@export var heights := PackedByteArray()
## Row-major indices into terrain_types.
@export var terrain_ids := PackedByteArray()
@export var terrain_types: Array[TerrainData] = []
@export var player_spawns: Array[Vector2i] = []
@export var enemies: Array[EnemySpawn] = []
## Units on the player's side that the computer controls (e.g. a villager to protect).
@export var allies: Array[EnemySpawn] = []
@export var triggers: Array[TriggerData] = []
@export var objective: Enums.Objective = Enums.Objective.ROUT
## DEFEAT_BOSS: boss tag.
@export var objective_tag: StringName
## REACH_AREA: target area (if objective_tag is set, only that unit counts).
@export var objective_area := Rect2i()
## SURVIVE_ROUNDS: number of rounds.
@export var objective_rounds := 0
@export var scene: PackedScene


func index(t: Vector2i) -> int:
	return t.y * size.x + t.x


func in_bounds(t: Vector2i) -> bool:
	return t.x >= 0 and t.y >= 0 and t.x < size.x and t.y < size.y


func terrain_at(t: Vector2i) -> TerrainData:
	return terrain_types[terrain_ids[index(t)]]


## Returns a list of problems; empty means valid.
func validate() -> PackedStringArray:
	var errs := PackedStringArray()
	var n := size.x * size.y
	if size.x <= 0 or size.y <= 0:
		errs.append("size must be positive")
		return errs
	if heights.size() != n:
		errs.append("heights has %d entries, expected %d" % [heights.size(), n])
	if terrain_ids.size() != n:
		errs.append("terrain_ids has %d entries, expected %d" % [terrain_ids.size(), n])
		return errs
	for i in n:
		if terrain_ids[i] >= terrain_types.size():
			errs.append("terrain id %d at index %d has no terrain type" % [terrain_ids[i], i])
			return errs
	if player_spawns.is_empty():
		errs.append("no player spawns")
	var used := {}
	for t in player_spawns:
		_check_spawn(t, Enums.MoveType.FOOT, "player spawn", used, errs)
	for e in enemies:
		if e.unit == null:
			errs.append("enemy at %s has no unit" % e.at)
			continue
		_check_spawn(e.at, e.unit.class_data.move_type, "enemy %s" % e.unit.id, used, errs)
	return errs


func _check_spawn(t: Vector2i, mt: Enums.MoveType, what: String, used: Dictionary, errs: PackedStringArray) -> void:
	if not in_bounds(t):
		errs.append("%s at %s is out of bounds" % [what, t])
		return
	if terrain_at(t).cost_for(mt) == TerrainData.IMPASSABLE:
		errs.append("%s at %s is on impassable terrain" % [what, t])
	if used.has(t):
		errs.append("%s at %s overlaps another spawn" % [what, t])
	used[t] = true
