class_name TriggerAction
extends Resource
## What a map trigger does.

enum Kind { SPAWN, SAY, SET_FLAG, SET_OBJECTIVE, RECRUIT, WIN, LOSE }

@export var kind: Kind = Kind.SAY
## SPAWN: the enemy to add.
@export var spawn: EnemySpawn
## SAY: dialogue line id. SET_FLAG: flag name.
@export var key: StringName
@export var value := true
