class_name Grid
extends RefCounted
## The battle map's tiles: height, terrain and who stands where.

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var map: MapData
var size: Vector2i
var _occupant: Dictionary = {}   # Vector2i -> Unit


func _init(p_map: MapData) -> void:
	map = p_map
	size = p_map.size


func in_bounds(t: Vector2i) -> bool:
	return map.in_bounds(t)


func height(t: Vector2i) -> int:
	return map.heights[map.index(t)]


func terrain(t: Vector2i) -> TerrainData:
	return map.terrain_at(t)


## -1 = impassable.
func move_cost(t: Vector2i, mt: Enums.MoveType) -> int:
	return terrain(t).cost_for(mt)


func land_effect(t: Vector2i) -> float:
	return terrain(t).land_effect


func neighbors(t: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		if in_bounds(t + d):
			out.append(t + d)
	return out


## Null if the tile is empty.
func unit_at(t: Vector2i) -> Unit:
	return _occupant.get(t)


func place(u: Unit, t: Vector2i) -> void:
	_occupant[t] = u
	u.pos = t


func vacate(t: Vector2i) -> void:
	_occupant.erase(t)


func move(u: Unit, to: Vector2i) -> void:
	vacate(u.pos)
	place(u, to)
