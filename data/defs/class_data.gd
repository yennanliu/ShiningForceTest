class_name ClassData
extends Resource
## A unit class (Swordsman, Archer...): movement, weapons, growth, promotion.

@export var id: StringName
@export var display_name: String
@export var move_type: Enums.MoveType = Enums.MoveType.FOOT
@export var mov := 5
@export var jump := 2
@export var weapon_types: Array[Enums.WeaponType] = []
## Average gain per level in TENTHS of a point (atk 24 = +2.4 per level).
@export var growth: Stats
@export var spells: Array[SpellData] = []
## Empty = cannot promote.
@export var promotes_to: Array[ClassData] = []
