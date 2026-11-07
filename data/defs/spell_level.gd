class_name SpellLevel
extends Resource
## One level of a spell.

@export var mp_cost := 2
@export var power := 10
@export var spell_range := Vector2i(1, 2)
## Radius around the target tile (0 = single target).
@export var area := 0
