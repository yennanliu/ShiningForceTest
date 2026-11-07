extends SceneTree
## Saves a PNG of a screen with demo game state (needs a GPU / window).
##   godot --path . -s res://tools/screenshot.gd -- --screen=camp --out=camp.png
## Screens: title, camp, battle, results, town, settings.  Add --bench to measure FPS.


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
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapter="):
			for i in int(a.trim_prefix("--chapter=")) - 1:
				game.campaign._advance_chapter()
	if screen == "results":
		game.last_result = game.campaign.finish_battle(Fixtures.win_battle(game.campaign))
	var path: String = {
		"title": "res://view/screens/title.tscn", "camp": "res://view/screens/camp.tscn",
		"results": "res://view/screens/results.tscn", "battle": "res://view/battle2d/battle_screen.tscn",
		"town": "res://view/screens/town.tscn", "settings": "res://view/screens/settings.tscn",
	}[screen]
	if screen == "battle":
		game.battle = game.campaign.start_battle(11)
	root.add_child(load(path).instantiate())
	for i in 30:
		await process_frame
	if "--bench" in OS.get_cmdline_user_args():
		var frames := 0
		var t0 := Time.get_ticks_msec()
		while Time.get_ticks_msec() - t0 < 3000:
			await process_frame
			frames += 1
		print("bench %s: %.1f fps average over 3 s" % [screen, frames / 3.0])
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved %s" % out)
	quit()
