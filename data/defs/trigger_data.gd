class_name TriggerData
extends Resource
## A map event: when <condition> then <actions>.

enum When { ROUND_START, UNIT_ENTERS, UNIT_DIES, HP_BELOW }

@export var when: When = When.ROUND_START
## ROUND_START: the round number.
@export var on_round := 1
## UNIT_ENTERS: the area. Any player unit counts unless tag is set.
@export var area := Rect2i()
## UNIT_DIES / HP_BELOW / UNIT_ENTERS: the unit tag.
@export var tag: StringName
## HP_BELOW: threshold in percent.
@export var hp_percent := 50
@export var actions: Array[TriggerAction] = []
@export var repeat := false
