class_name TriggerAction
extends Resource
## What a map trigger does.

enum Kind { SPAWN, SAY, SET_FLAG, SET_OBJECTIVE, RECRUIT, WIN, LOSE, GIVE, SET_AI }

@export var kind: Kind = Kind.SAY
## SPAWN: the enemy to add.
@export var spawn: EnemySpawn
## SAY: dialogue line id. SET_FLAG: flag name.
@export var key: StringName
@export var value := true
## GIVE: the item handed to the unit that set off the trigger (or the first player unit).
@export var item: ItemData
## SET_AI: new behavior for every unit whose tag is `key`.
@export var ai: Enums.AiProfile = Enums.AiProfile.AGGRESSIVE
