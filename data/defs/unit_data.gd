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
## One-line bio for the profile screen (recruits; step 19).
@export_multiline var bio: String
## The character's look in words: hair, eyes, outfit, one signature item (doc/05 §5, doc/06).
@export var look: String
