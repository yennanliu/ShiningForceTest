class_name UnitData
extends Resource
## A character definition. Runtime state lives in core/battle/unit.gd.

## Stable id, used in saves and triggers.
@export var id: StringName
@export var display_name: String
@export var portrait: Texture2D
@export var model: PackedScene
@export var class_data: ClassData
@export var base_level := 1
@export var base_stats: Stats
@export var starting_items: Array[ItemData] = []
