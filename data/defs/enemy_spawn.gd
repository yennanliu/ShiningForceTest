class_name EnemySpawn
extends Resource
## One enemy placed on a map (at start or by a trigger).

@export var unit: UnitData
@export var level := 1
@export var at := Vector2i.ZERO
@export var ai: Enums.AiProfile = Enums.AiProfile.AGGRESSIVE
## Referenced by triggers and objectives, e.g. &"boss".
@export var tag: StringName
@export var is_leader := false
