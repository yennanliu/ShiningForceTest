class_name ChapterData
extends Resource
## One chapter of the campaign: story, town, battle, rewards.

@export var id: StringName
@export var title: String
@export var intro_dialogue: StringName
## Null = camp only.
@export var town_scene: PackedScene
@export var battle: MapData
@export var recruits_on_start: Array[UnitData] = []
@export var reward_gold := 0
## Null = campaign end.
@export var next: ChapterData
