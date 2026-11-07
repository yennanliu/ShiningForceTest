extends TestCase
## Step 7: Campaign, Party, Inventory.


func _new() -> Campaign:
	return Campaign.new_game(Fixtures.chapter(1))


func test_new_game_recruits_and_deploys() -> void:
	var c := _new()
	assert_eq(c.chapter.id, &"ch01")
	assert_eq(c.party.roster.size(), 4)
	assert_eq(c.party.leader().data.id, &"hero")
	assert_eq(c.party.deployed, [&"hero", &"knight", &"archer", &"scout"])
	assert_eq(c.inventory.gold, 0)


func test_set_deployed_rules() -> void:
	var c := _new()
	var ok: Array[StringName] = [&"knight", &"hero"]
	assert_true(c.party.set_deployed(ok))
	assert_eq(c.party.deployed, [&"hero", &"knight"], "leader moved first")
	var no_leader: Array[StringName] = [&"knight"]
	assert_false(c.party.set_deployed(no_leader))
	var unknown: Array[StringName] = [&"hero", &"dragon"]
	assert_false(c.party.set_deployed(unknown))
	assert_eq(c.party.deployed, [&"hero", &"knight"], "unchanged after a bad request")


func test_battle_uses_copies() -> void:
	var c := _new()
	var b := c.start_battle(1)
	b.start()
	b.units()[0].hp = 1
	b.units()[0].xp = 999
	assert_eq(c.party.leader().hp, 20, "abandoning a battle changes nothing")
	assert_eq(c.party.leader().xp, 0)


func test_win_gives_gold_xp_and_next_chapter() -> void:
	var c := _new()
	var b := Fixtures.win_battle(c)
	var r := c.finish_battle(b)
	assert_true(r.won())
	assert_eq(r.gold, 100)
	assert_eq(c.inventory.gold, 100)
	assert_eq(c.chapter.id, &"ch02")
	assert_eq(c.battles_won, 1)
	var total_xp := 0
	for id in r.xp:
		total_xp += r.xp[id]
		assert_eq(c.party.member(id).xp, r.xp[id])
	assert_true(total_xp > 0, "someone earned XP")
	for u in c.party.roster:
		assert_eq(u.hp, u.max_hp(), "%s healed after battle" % u.data.id)


func test_loss_keeps_xp_and_chapter() -> void:
	var c := _new()
	for s in 200:
		var b := c.start_battle(s)
		b.start()
		if AutoPlay.play_to_end(b) == BattleState.Outcome.LOST:
			var xp_before := c.party.roster.map(func(u: Unit) -> int: return u.xp)
			var r := c.finish_battle(b)
			assert_false(r.won())
			assert_eq(c.chapter.id, &"ch01", "retreat: same chapter")
			assert_eq(c.inventory.gold, 0)
			assert_true(r.fallen.has(&"hero"), "leader fell")
			for u in c.party.roster:
				assert_eq(u.hp, u.max_hp(), "revived and healed")
			return
	fail("no losing seed found")


func test_whole_demo_campaign_completes() -> void:
	var c := _new()
	var seed := 0
	while not c.is_complete() and seed < 2000:
		var b := Fixtures.win_battle(c, seed)
		seed = b.rng.start_seed + 1
		c.finish_battle(b)
	assert_true(c.is_complete())
	assert_eq(c.battles_won, 2)
	assert_eq(c.inventory.gold, 250)


func test_campaign_dict_round_trip() -> void:
	var c := _new()
	c.finish_battle(Fixtures.win_battle(c))
	c.flags["met_merchant"] = true
	c.play_seconds = 321
	c.inventory.storage.append(Fixtures.item("herb"))
	var d := c.to_dict()
	assert_eq(Golden.normalize(Campaign.from_dict(d).to_dict()), Golden.normalize(d))


func test_inventory_buy_and_sell() -> void:
	var inv := Inventory.new()
	inv.gold = 15
	assert_true(inv.buy(Fixtures.item("herb")))
	assert_eq(inv.gold, 5)
	assert_false(inv.buy(Fixtures.item("herb")), "can't afford")
	assert_true(inv.sell(0))
	assert_eq(inv.gold, 10)
	assert_false(inv.sell(0))
