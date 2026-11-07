extends TestCase
## Step 11: the vertical-slice content in res://data/.

const P := Enums.Faction.PLAYER


func _chapter(n: int) -> ChapterData:
	return load("res://data/chapters/ch%02d.tres" % n)


func _campaign_at(n: int) -> Campaign:
	var c := Campaign.new_game(_chapter(1))
	for i in n - 1:
		c._advance_chapter()
	return c


func test_slice_scope() -> void:
	var units := {}
	for n in [1, 2, 3]:
		for d in _chapter(n).recruits_on_start:
			units[d.id] = d
	assert_eq(units.size(), 8, "8 recruitable units")
	for d: UnitData in units.values():
		assert_eq(d.class_data.promotes_to.size(), 1, "%s has 2 classes" % d.id)
	assert_true(_chapter(1).town_name != "", "a town")


func test_every_data_map_is_valid_and_lines_exist() -> void:
	for f in DirAccess.get_files_at("res://data/maps/"):
		if not f.ends_with(".tres"):
			continue
		var m: MapData = load("res://data/maps/" + f)
		assert_eq(Array(m.validate()), [], f)
		for t in m.triggers:
			for a in t.actions:
				if a.kind == TriggerAction.Kind.SAY:
					assert_true(Dialogue.has(a.key), "%s: line %s" % [f, a.key])
	for n in [1, 2, 3]:
		var ch := _chapter(n)
		for id in ch.town_talk:
			assert_true(Dialogue.has(id), "town line %s" % id)
		for d in ch.recruits_on_start:
			assert_true(Dialogue.has(StringName("join_" + String(d.id))), "join line for %s" % d.id)


func test_chests_give_items_until_looted() -> void:
	var b := _campaign_at(1).start_battle(1)
	b.start()
	var chests := MapScript.open_chests(b)
	assert_eq(chests.size(), 3)
	var hero := b.living(P)[0]
	b.grid.move(hero, chests[0])     # step onto a chest (test shortcut)
	var ev := b.apply(WaitCommand.by(b.current_actor().id)) if b.current_actor() != hero else b.apply(WaitCommand.by(hero.id))
	var found := ev.filter(func(e: BattleEvent) -> bool: return e.type == BattleEvent.ITEM_FOUND)
	assert_eq(found.size(), 1)
	assert_eq(MapScript.open_chests(b).size(), 2)
	b.flags[&"looted"] = true
	assert_eq(MapScript.open_chests(b).size(), 0, "raiders took the rest")


func test_villager_flees_and_its_death_loses() -> void:
	var b := _campaign_at(2).start_battle(1)
	b.start()
	var v: Unit = b.units().filter(func(u: Unit) -> bool: return u.tag == &"villager")[0]
	assert_true(v.ai_controlled and v.faction == P)
	v.hp = 0
	b.grid.vacate(v.pos)
	var actor := b.current_actor()
	b.apply(WaitCommand.by(actor.id))
	assert_eq(b.outcome(), BattleState.Outcome.LOST)


func test_chief_charges_when_hurt() -> void:
	var b := _campaign_at(3).start_battle(1)
	b.start()
	var chief: Unit = b.units().filter(func(u: Unit) -> bool: return u.tag == &"chief")[0]
	assert_eq(chief.ai, Enums.AiProfile.HOLD)
	var before := b.units().size()
	chief.hp = 5
	b.apply(WaitCommand.by(b.current_actor().id))
	assert_eq(chief.ai, Enums.AiProfile.AGGRESSIVE, "phase 2")
	assert_eq(b.units().size(), before + 2, "guards called")


func test_whole_slice_campaign_completes() -> void:
	var c := Campaign.new_game(_chapter(1))
	var seed := 0
	while not c.is_complete() and seed < 3000:
		var won := false
		for s in range(seed, seed + 300):
			var b := c.start_battle(s)
			b.start()
			if AutoPlay.play_to_end(b) == BattleState.Outcome.WON:
				c.finish_battle(b)
				seed = s + 1
				won = true
				break
		if not won:
			fail("could not win %s" % c.chapter.id)
			return
	assert_true(c.is_complete())
	assert_eq(c.party.roster.size(), 8)
	assert_eq(c.inventory.gold, 550)
