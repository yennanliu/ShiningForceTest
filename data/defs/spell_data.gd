class_name SpellData
extends Resource
## A spell with 1–4 levels.

@export var id: StringName
@export var display_name: String
@export var element: Enums.Element = Enums.Element.NONE
@export var heals := false
@export var levels: Array[SpellLevel] = []
