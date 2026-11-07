class_name TerrainData
extends Resource
## A terrain type: defense bonus and move cost per movement type.

const IMPASSABLE := -1

@export var id: StringName
## Defense bonus, e.g. 0.15 = +15%.
@export var land_effect := 0.0
## Indexed by Enums.MoveType (FOOT, ARMORED, MOUNTED, FLYING, AQUATIC). -1 = impassable.
@export var move_cost := PackedInt32Array([1, 1, 1, 1, 3])


func cost_for(move_type: Enums.MoveType) -> int:
	if move_type < 0 or move_type >= move_cost.size():
		return IMPASSABLE
	return move_cost[move_type]
