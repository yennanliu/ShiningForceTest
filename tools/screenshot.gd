extends SceneTree
## Saves a PNG of a screen with demo game state (needs a GPU / window).
##   godot --path . -s res://tools/screenshot.gd -- --screen=camp --out=camp.png
## Screens: title, camp, battle, results, town, settings, scene.  Add --bench to measure FPS.
## scene: the battle close-up (step 16): Aldric strikes the chapter's toughest enemy. --at=<s> picks
## the moment to capture (default 0.85 s = the hit lands); --crit / --miss change the outcome;
## --skip-after=<s> presses skip at that moment and prints how long the scene took to close.
## battle --view=2d|3d (default: the setting, 3D); 3D camera --yaw=0..3 --zoom=0..2 --top-down;
## --report-hidden prints units the camera can't see (should be none) and how many tiles faded.
## battle --auto-wait=<s>: the party keeps waiting while the enemy attacks, with every animation and
## close-up on, for <s> seconds (max ~25); prints how many close-ups played. An end-to-end check.
## --skip-anim: animation speed "skip" (dialogue shows whole lines). --fast-anim: speed "fast".
## --demo-status (battle): poisons the acting unit and puts an enemy to sleep, to check the status badges.


func _initialize() -> void:
	# Watchdog: if a script error stops this tool, quit instead of leaving an empty window open.
	create_timer(30.0).timeout.connect(func() -> void:
		printerr("screenshot: timed out after 30 s")
		quit(2))
	var screen := "title"
	var out := "screenshot.png"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--screen="): screen = a.trim_prefix("--screen=")
		elif a.begins_with("--out="): out = a.trim_prefix("--out=")
	await process_frame
	if "--skip-anim" in OS.get_cmdline_user_args():   # text and moves appear at once
		Settings.anim_speed_index = 2
	if "--fast-anim" in OS.get_cmdline_user_args():   # animation speed "fast"
		Settings.anim_speed_index = 1
	if "--view=2d" in OS.get_cmdline_user_args():
		Settings.battle_view = Settings.View.TWO_D
	if "--view=3d" in OS.get_cmdline_user_args():
		Settings.battle_view = Settings.View.THREE_D
	var game: Node = root.get_node("Game")
	game.change_scenes = false
	game.new_game()
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--chapter="):
			for i in int(a.trim_prefix("--chapter=")) - 1:
				game.campaign._advance_chapter()
	if screen == "results":
		game.last_result = game.campaign.finish_battle(Fixtures.win_battle(game.campaign))
	if screen == "scene":
		await _scene_shot(game, out)
		return
	var screens := {
		"title": "res://view/screens/title.tscn", "camp": "res://view/screens/camp.tscn",
		"results": "res://view/screens/results.tscn", "battle": "res://view/battle2d/battle_screen.tscn",
		"town": "res://view/screens/town.tscn", "settings": "res://view/screens/settings.tscn",
	}
	if not screens.has(screen):   # quit instead of leaving an empty window open
		printerr("screenshot: unknown --screen=%s (use %s)" % [screen, ", ".join(screens.keys())])
		quit(1)
		return
	var path: String = screens[screen]
	if screen == "battle":
		game.battle = game.campaign.start_battle(11)
		if "--demo-status" in OS.get_cmdline_user_args():
			var ev: Array[BattleEvent] = []
			Rules.add_status(game.battle.living(Enums.Faction.PLAYER)[0], Unit.POISON, 3, ev)
			Rules.add_status(game.battle.living(Enums.Faction.ENEMY)[0], Unit.SLEEP, 2, ev)
			Rules.add_status(game.battle.living(Enums.Faction.ENEMY)[0], Unit.POISON, 2, ev)
	var scr: Control = load(path).instantiate()
	root.add_child(scr)
	for i in 30:
		await process_frame
	for a in OS.get_cmdline_user_args():   # 3D camera: --yaw=0..3, --zoom=0..2, --top-down
		if scr.get("_map3d") != null and scr._map3d.visible:
			if a.begins_with("--yaw="): scr._map3d.rotate_view(int(a.trim_prefix("--yaw=")))
			if a.begins_with("--zoom="): scr._map3d.zoom_by(int(a.trim_prefix("--zoom=")))
			if a == "--top-down": scr._map3d.toggle_top_down()
			scr.queue_redraw()
	if scr.get("_map3d") != null and scr._map3d.visible and "--report-hidden" in OS.get_cmdline_user_args():
		for i in 3:
			await process_frame
		print("hidden units: %s, faded tiles: %d" % [scr._map3d.hidden_units(scr.state), scr._map3d.faded.size()])
	for i in 10:
		await process_frame
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--auto-wait=") and screen == "battle":
			await _auto_wait(scr, float(a.trim_prefix("--auto-wait=")))
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


## A close-up of one attack, captured mid-scene (and benchmarked with --bench).
func _scene_shot(game: Node, out: String) -> void:
	var args := OS.get_cmdline_user_args()
	var at := 0.85
	for a in args:
		if a.begins_with("--at="): at = float(a.trim_prefix("--at="))
	var b: BattleState = game.campaign.start_battle(11)
	b.start()
	var hero: Unit = b.living(Enums.Faction.PLAYER)[0]
	var foe: Unit = b.living(Enums.Faction.ENEMY)[0]
	for u in b.living(Enums.Faction.ENEMY):
		if u.is_leader:
			foe = u
	var hit := not ("--miss" in args)
	var dmg := 7 if not ("--crit" in args) else 12
	var ev: Array[BattleEvent] = [
		BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": hero.id, "target_id": foe.id, "hit": hit, "crit": "--crit" in args, "counter": false, "double": false, "special": ""}),
	]
	if hit:
		ev.append(BattleEvent.make(BattleEvent.DAMAGED, {"unit_id": foe.id, "amount": dmg, "hp_after": maxi(0, foe.hp - dmg)}))
	# Loaded at run time: a -s script can't name classes that use autoloads (Audio) at compile time.
	var scene: Control = load("res://view/battle_scene/battle_scene.gd").new()
	root.add_child(scene)
	var bench := "--bench" in args
	var frames := 0
	var t0 := Time.get_ticks_msec()
	scene.play(b, ev, {})
	if bench:
		while Time.get_ticks_msec() - t0 < 3000:
			await process_frame
			frames += 1
			if not scene.visible:
				scene.play(b, ev, {})
		print("bench scene: %.1f fps average over 3 s" % (frames / 3.0))
	elif "--skip-after=" in " ".join(args):
		var after := 0.4
		for a in args:
			if a.begins_with("--skip-after="): after = float(a.trim_prefix("--skip-after="))
		while Time.get_ticks_msec() - t0 < after * 1000.0:
			await process_frame
		var t_skip := Time.get_ticks_msec()
		scene.skip()
		var waited := 0
		while scene.visible and waited < 120:
			await process_frame
			waited += 1
		print("skip: scene closed %d ms (%d frames) after the press" % [Time.get_ticks_msec() - t_skip, waited])
	else:
		while Time.get_ticks_msec() - t0 < at * 1000.0:
			await process_frame
	root.get_viewport().get_texture().get_image().save_png(out)
	print("saved %s" % out)
	quit()


func _auto_wait(scr: Control, seconds: float) -> void:
	var scenes := [0]
	scr._scene.finished.connect(func() -> void: scenes[0] += 1)
	var t0 := Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0 < seconds * 1000.0 and scr.state.outcome() == BattleState.Outcome.ONGOING:
		if scr.state.human_turn() and not scr._busy and not scr._speech.visible:
			scr.wait_turn()
		await process_frame
	print("auto-wait: %d close-ups played, round %d, outcome %d" % [scenes[0], scr.state.round_number(), scr.state.outcome()])
