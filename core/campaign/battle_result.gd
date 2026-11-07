class_name BattleResult
extends RefCounted
## What a finished battle changed in the campaign (shown on the Results screen).

var outcome: BattleState.Outcome = BattleState.Outcome.ONGOING
var chapter_title := ""
var xp: Dictionary = {}                 # data id -> XP gained
var level_ups: Array[StringName] = []   # units that gained at least one level
var fallen: Array[StringName] = []      # units that went down (revived after battle)
var gold := 0
var rounds := 0
var campaign_complete := false


func won() -> bool:
	return outcome == BattleState.Outcome.WON
