extends SceneTree
## Saves a PNG of a screen with demo game state (needs a GPU / window).
##   godot --path . -s res://tools/screenshot.gd -- --screen=camp --out=camp.png
## Screens: title, camp, battle, results


func _initialize() -> void:
	var screen := "title"
	var out := "screenshot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="): screen = a.trim_prefix("--screen=")
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
	await process_frame
	var game: Node = root.get_node("Game")
	game.change_scenes = false
	game.new_game()
	if screen == "results":
		game.last_result = game.campaign.finish_battle(Fixtures.win_battle(game.campaign))
	var path: String = {
		"title": "res://view/screens/title.tscn", "camp": "res://view/screens/camp.tscn",
		"results": "res://view/screens/results.tscn", "battle": "res://view/battle2d/battle_screen.tscn",
	}[screen]
	if screen == "battle":
		game.battle = game.campaign.start_battle(11)
	root.add_child(load(path).instantiate())
	for i in 30:
		await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved %s" % out)
	quit()
