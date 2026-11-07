extends Node
## Screen flow and the current Campaign (doc/02 §5.7).
## Title -> Camp -> Battle -> Results -> Camp ... -> Title when the campaign is complete.

enum Screen { TITLE, CAMP, TOWN, BATTLE, RESULTS }

const SCENES := {
	Screen.TITLE: "res://view/screens/title.tscn",
	Screen.CAMP: "res://view/screens/camp.tscn",
	Screen.TOWN: "res://view/screens/town.tscn",
	Screen.BATTLE: "res://view/battle2d/battle_screen.tscn",
	Screen.RESULTS: "res://view/screens/results.tscn",
}
## Demo content until real chapters exist (step 11).
const CONTENT_DIR := "res://tests/fixtures/"
const FIRST_CHAPTER := "res://tests/fixtures/chapter_01.tres"

signal screen_changed(screen: Screen)

var campaign: Campaign
var battle: BattleState
var last_result: BattleResult
var screen: Screen = Screen.TITLE
## Tests turn this off to drive the flow without loading scenes.
var change_scenes := true

var _play_acc := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	Content.register_dir(CONTENT_DIR)
	Dialogue.register_file(CONTENT_DIR + "dialogue_demo.json")
	_rng.randomize()


func _process(delta: float) -> void:
	if campaign == null:
		return
	_play_acc += delta
	while _play_acc >= 1.0:
		_play_acc -= 1.0
		campaign.play_seconds += 1


func new_game() -> void:
	campaign = Campaign.new_game(load(FIRST_CHAPTER))
	goto(Screen.CAMP)


func continue_game(slot: String) -> bool:
	var c := SaveService.load_slot(slot)
	if c == null:
		return false
	campaign = c
	goto(Screen.TITLE if c.is_complete() else Screen.CAMP)
	return true


func save_to(slot: String) -> Error:
	return SaveService.save_slot(slot, campaign)


func start_battle(seed: int = -1) -> void:
	battle = campaign.start_battle(seed if seed >= 0 else _rng.randi_range(0, 999999))
	goto(Screen.BATTLE)


## Save mid-battle and go to the title screen.
func suspend_battle() -> Error:
	var err := SaveService.save_suspend(campaign, battle)
	if err == OK:
		quit_to_title()
	return err


func resume_battle() -> bool:
	var d := SaveService.load_suspend()
	if d.is_empty():
		return false
	SaveService.clear_suspend()
	campaign = d.campaign
	battle = d.battle
	goto(Screen.BATTLE)
	return true


## Called by the battle screen once the battle has ended.
func finish_battle() -> void:
	last_result = campaign.finish_battle(battle)
	battle = null
	SaveService.save_slot("auto", campaign)
	goto(Screen.RESULTS)


func after_results() -> void:
	if campaign.is_complete():
		quit_to_title()
	else:
		goto(Screen.CAMP)


func quit_to_title() -> void:
	campaign = null
	battle = null
	goto(Screen.TITLE)


func goto(s: Screen) -> void:
	screen = s
	if change_scenes:
		get_tree().change_scene_to_file(SCENES[s])
	screen_changed.emit(s)
