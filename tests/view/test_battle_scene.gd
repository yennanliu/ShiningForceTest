extends TestCase
## Step 16: the battle close-up shows exactly what the events say; length; skip; settings; mute.

const P := Enums.Faction.PLAYER
const E := Enums.Faction.ENEMY


func _scene() -> BattleScene:
	var sc := BattleScene.new()
	sc.instant = true
	Engine.get_main_loop().root.add_child(sc)
	return sc


func _hp_map(b: BattleState) -> Dictionary:
	var d := {}
	for u in b.units():
		d[u.id] = u.hp
	return d


func _count(ev: Array, type: StringName) -> int:
	return ev.filter(func(e: BattleEvent) -> bool: return e.type == type).size()


func test_scene_matches_the_events_for_200_seeded_attacks() -> void:
	var sc := _scene()
	var seen := {"miss": 0, "crit": 0, "counter": 0, "double": 0, "death": 0}
	for s in 200:
		var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], s)
		var hero := b.living(P)[0]
		var gob := b.living(E)[0]
		if s % 4 == 0:
			gob.hp = 3   # some attacks should kill
		Fixtures.act_as(b, hero)
		var before := _hp_map(b)
		var ev := b.apply(AttackCommand.on(hero.id, gob.id))
		var group := ev.slice(0, BattleScene.group_end(ev, 0))
		sc.play(b, group, before)
		var strikes := sc.shown.filter(func(st: Dictionary) -> bool: return st.kind == "strike")
		var attacks := group.filter(func(e: BattleEvent) -> bool: return e.type == BattleEvent.ATTACKED)
		assert_eq(strikes.size(), attacks.size(), "seed %d: one strike per ATTACKED" % s)
		for i in attacks.size():
			var e: BattleEvent = attacks[i]
			var st: Dictionary = strikes[i]
			assert_eq([st.by, st.on, st.hit, st.crit, st.counter], [e.data.attacker_id, e.data.target_id, e.data.hit, e.data.crit, e.data.counter], "seed %d strike %d" % [s, i])
			if e.data.hit:
				var dmg: BattleEvent = group[group.find(e) + 1]
				assert_eq(dmg.type, BattleEvent.DAMAGED)
				assert_eq(st.dmg, dmg.data.amount, "seed %d: damage shown = damage dealt" % s)
			seen.miss += 0 if e.data.hit else 1
			seen.crit += 1 if e.data.crit else 0
			seen.counter += 1 if e.data.counter else 0
			seen.double += 1 if e.data.get("double", false) else 0
		var deaths := sc.shown.filter(func(st: Dictionary) -> bool: return st.kind == "die").size()
		assert_eq(deaths, _count(group, BattleEvent.DIED), "seed %d: deaths" % s)
		seen.death += deaths
		for u in [hero, gob]:
			assert_eq(sc.shown_hp(u.id), u.hp, "seed %d: %s's plate ends at its real HP" % [s, u.display_name()])
	for k in seen:
		assert_true(seen[k] > 0, "200 seeds cover at least one %s" % k)
	sc.free()


func test_group_stops_at_turn_end_and_poison_ticks() -> void:
	var ev: Array[BattleEvent] = [
		BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": 1, "target_id": 2, "hit": true, "crit": false, "counter": false}),
		BattleEvent.make(BattleEvent.DAMAGED, {"unit_id": 2, "amount": 4, "hp_after": 6}),
		BattleEvent.make(BattleEvent.XP_GAINED, {"unit_id": 1, "amount": 10, "xp_after": 10}),
		BattleEvent.make(BattleEvent.DAMAGED, {"unit_id": 1, "amount": 2, "hp_after": 18, "poison": true}),
		BattleEvent.make(BattleEvent.TURN_ENDED, {"unit_id": 1}),
	]
	assert_eq(BattleScene.group_end(ev, 0), 3, "the poison tick belongs to the turn's end, not the scene")
	ev.remove_at(3)
	assert_eq(BattleScene.group_end(ev, 0), 3, "stops at TURN_ENDED")


func test_length_per_attack() -> void:
	var one := BattleScene.build_steps([
		BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": 1, "target_id": 2, "hit": true, "crit": false, "counter": false}),
		BattleEvent.make(BattleEvent.DAMAGED, {"unit_id": 2, "amount": 4, "hp_after": 6}),
	])
	assert_true(BattleScene.duration(one, 1.0) <= 3.0, "normal: %.2f s" % BattleScene.duration(one, 1.0))
	assert_true(BattleScene.duration(one, 2.0) <= 1.0, "fast: %.2f s" % BattleScene.duration(one, 2.0))
	var with_counter := one.duplicate()
	with_counter.append_array(BattleScene.build_steps([
		BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": 2, "target_id": 1, "hit": true, "crit": false, "counter": true}),
	]))
	assert_true(BattleScene.duration(with_counter, 1.0) <= 3.0, "attack + counter, normal: %.2f s" % BattleScene.duration(with_counter, 1.0))


func test_skip_snaps_to_the_result() -> void:
	# Real-time skipping needs a running window: tools/screenshot.gd --screen=scene --skip-after=0.4
	# measures it. Here: skip() stops the waiting and puts every bar on its final HP.
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], 3)
	var hero := b.living(P)[0]
	var gob := b.living(E)[0]
	Fixtures.act_as(b, hero)
	var before := _hp_map(b)
	var ev := b.apply(AttackCommand.on(hero.id, gob.id))
	var sc := _scene()
	sc.play(b, ev.slice(0, BattleScene.group_end(ev, 0)), before)
	var side := "L"
	for s in ["L", "R"]:
		if sc.fighter(s) == gob:
			side = s
	var bar: ProgressBar = sc._plates[side].bar
	bar.value = gob.max_hp()   # as if the drain were still running
	sc.skip()
	assert_true(sc._skipping)
	assert_eq(int(bar.value), gob.hp, "the bar jumps to the final HP")
	sc.free()


func test_settings_choose_when_scenes_play() -> void:
	var scr: Control = load("res://view/battle2d/battle_screen.tscn").instantiate()
	scr.auto_start = false
	scr.animate = false
	Engine.get_main_loop().root.add_child(scr)
	scr.start_battle(7)
	scr._add_scene()
	var p: Unit = scr.state.living(P)[0]
	var e: Unit = scr.state.living(E)[0]
	var by_player := BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": p.id, "target_id": e.id})
	var by_enemy := BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": e.id, "target_id": p.id})
	var old_mode := Settings.battle_scenes
	var old_speed := Settings.anim_speed_index
	Settings.anim_speed_index = 0
	assert_false(scr._scene_wanted(by_player), "never with animations off (tests, AI-vs-AI)")
	scr.animate = true
	Settings.battle_scenes = Settings.Scenes.ON
	assert_true(scr._scene_wanted(by_player) and scr._scene_wanted(by_enemy))
	Settings.battle_scenes = Settings.Scenes.PLAYER_ONLY
	assert_true(scr._scene_wanted(by_player))
	assert_false(scr._scene_wanted(by_enemy))
	Settings.battle_scenes = Settings.Scenes.OFF
	assert_false(scr._scene_wanted(by_player))
	Settings.battle_scenes = Settings.Scenes.ON
	Settings.anim_speed_index = 2
	assert_false(scr._scene_wanted(by_player), "animation speed 'skip' turns scenes off")
	Settings.battle_scenes = old_mode
	Settings.anim_speed_index = old_speed
	scr.free()


func test_battle_scene_setting_persists() -> void:
	var old_path := Settings.path
	Settings.path = "user://test_settings_scenes.cfg"
	Settings.battle_scenes = Settings.Scenes.PLAYER_ONLY
	assert_eq(Settings.save_settings(), OK)
	Settings.battle_scenes = Settings.Scenes.ON
	Settings.load_settings()
	assert_eq(Settings.battle_scenes, Settings.Scenes.PLAYER_ONLY)
	Settings.battle_scenes = Settings.Scenes.ON
	DirAccess.remove_absolute(Settings.path)
	Settings.path = old_path


func test_debug_runs_are_muted() -> void:
	var none := PackedStringArray()
	assert_true(Audio.should_mute(true, none, ""), "debug build: silent")
	assert_false(Audio.should_mute(false, none, ""), "release build: sound")
	assert_false(Audio.should_mute(true, PackedStringArray(["--sound"]), ""), "--sound turns it back on")
	assert_true(Audio.should_mute(false, PackedStringArray(["--mute"]), ""), "--mute silences any build")
	assert_true(Audio.should_mute(false, none, "1"), "BANNER_MUTE=1 too")


func test_every_slice_unit_has_battle_poses_and_every_terrain_a_backdrop() -> void:
	for f in DirAccess.get_files_at("res://data/units/"):
		if f.ends_with(".tres"):
			var t := Art.battle_sheet(StringName(f.get_basename()))
			assert_true(t != null, "battle poses for %s" % f)
			if t != null:
				assert_eq(t.get_size(), Vector2(192 * 11, 192))
	for k: String in BattleScene.BACKDROP_FOR.values():
		assert_true(ResourceLoader.exists("res://assets/textures/backdrops/%s.png" % k), "backdrop %s" % k)
