extends TestCase
## Step 7: saves and the whole Title -> Camp -> Battle -> Results flow, headless.

var _old_dir := ""


func before_each() -> void:
	_old_dir = SaveService.dir
	SaveService.dir = "user://test_saves/"
	SaveService.crash_before_rename = false
	DirAccess.make_dir_recursive_absolute(SaveService.dir)
	for f in DirAccess.get_files_at(SaveService.dir):
		DirAccess.remove_absolute(SaveService.dir.path_join(f))
	Game.change_scenes = false


func _cleanup() -> void:
	SaveService.dir = _old_dir
	SaveService.crash_before_rename = false
	Game.campaign = null
	Game.battle = null


func test_new_game_battle_results_save_load() -> void:
	Game.new_game()
	assert_eq(Game.screen, Game.Screen.CAMP)
	Game.start_battle(5)
	assert_eq(Game.screen, Game.Screen.BATTLE)
	Game.battle.start()
	AutoPlay.play_to_end(Game.battle)
	Game.finish_battle()
	assert_eq(Game.screen, Game.Screen.RESULTS)
	assert_true(SaveService.slot_info("auto").exists, "autosaved after battle")
	assert_eq(SaveService.save_slot("slot_1", Game.campaign), OK)
	var loaded := SaveService.load_slot("slot_1")
	assert_eq(Golden.normalize(loaded.to_dict()), Golden.normalize(Game.campaign.to_dict()))
	Game.after_results()
	assert_true(Game.screen in [Game.Screen.CAMP, Game.Screen.TITLE])
	_cleanup()


func test_crash_during_save_keeps_previous_save() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	assert_eq(SaveService.save_slot("slot_1", c), OK)
	c.inventory.gold = 999
	SaveService.crash_before_rename = true
	assert_ne(SaveService.save_slot("slot_1", c), OK)
	SaveService.crash_before_rename = false
	var loaded := SaveService.load_slot("slot_1")
	assert_true(loaded != null, "old save still loads")
	assert_eq(loaded.inventory.gold, 0, "and it is the old one")
	_cleanup()


func test_damaged_slot_does_not_affect_others() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	SaveService.save_slot("slot_1", c)
	SaveService.save_slot("slot_3", c)
	var f := FileAccess.open(SaveService.dir.path_join("slot_2.json"), FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	assert_true(SaveService.slot_info("slot_2").damaged)
	assert_true(SaveService.load_slot("slot_2") == null)
	assert_true(SaveService.load_slot("slot_1") != null)
	assert_true(SaveService.load_slot("slot_3") != null)
	_cleanup()


func test_v0_save_migrates() -> void:
	var src := FileAccess.get_file_as_string("res://tests/fixtures/save_v0.json")
	DirAccess.make_dir_recursive_absolute(SaveService.dir)
	var f := FileAccess.open(SaveService.dir.path_join("slot_1.json"), FileAccess.WRITE)
	f.store_string(src)
	f.close()
	var c := SaveService.load_slot("slot_1")
	assert_true(c != null)
	assert_eq(c.inventory.gold, 77, "money -> inventory.gold")
	assert_eq(c.party.leader().level, 2)
	assert_eq(c.chapter.id, &"fx01")
	_cleanup()


func test_newer_save_is_refused() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	var d := c.to_dict()
	d["version"] = SaveService.CURRENT_VERSION + 1
	DirAccess.make_dir_recursive_absolute(SaveService.dir)
	var f := FileAccess.open(SaveService.dir.path_join("slot_1.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify(d))
	f.close()
	assert_true(SaveService.load_slot("slot_1") == null)
	assert_true(SaveService.slot_info("slot_1").damaged)
	_cleanup()


func test_screens_build_without_errors() -> void:
	Game.new_game()
	Game.last_result = Game.campaign.finish_battle(Fixtures.win_battle(Game.campaign))
	Game.campaign.chapter = Fixtures.chapter(1)   # chapter 1 has a town
	for path in ["res://view/screens/title.tscn", "res://view/screens/camp.tscn", "res://view/screens/results.tscn", "res://view/screens/town.tscn"]:
		var scr: Control = load(path).instantiate()
		Engine.get_main_loop().root.add_child(scr)
		scr._ready()
		assert_true(scr.get_child_count() > 0, "%s built its UI" % path)
		scr.free()
	_cleanup()
