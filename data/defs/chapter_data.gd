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
## Town visited from camp (empty name = no town).
@export var town_name := ""
## One dialogue line id per townsperson.
@export var town_talk: Array[StringName] = []
## Hidden items in the town; each can be found once.
@export var town_finds: Array[ItemData] = []
## Items for sale at camp before this chapter's battle.
@export var shop: Array[ItemData] = []
## Null = campaign end.
@export var next: ChapterData
