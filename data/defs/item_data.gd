class_name ItemData
extends Resource
## Weapons, rings, consumables and key items.

enum Kind { WEAPON, RING, CONSUMABLE, KEY }

@export var id: StringName
@export var display_name: String
@export var kind: Kind = Kind.CONSUMABLE
@export var weapon_type: Enums.WeaponType = Enums.WeaponType.NONE
## Stat bonuses while equipped (weapons, rings).
@export var bonus: Stats
## Min and max attack distance (weapons).
@export var attack_range := Vector2i(1, 1)
## Null = no special.
@export var special: SpecialData
## HP restored (consumables).
@export var heal_amount := 0
@export var price := 0
