extends TestCase
## Step 12: weapon matchups, poison and sleep, Antidote, regeneration ring.

const P := Enums.Faction.PLAYER
const E := Enums.Faction.ENEMY
const W := Enums.WeaponType


func _events(ev: Array[BattleEvent], type: StringName) -> Array:
	return ev.filter(func(e: BattleEvent) -> bool: return e.type == type)


func _weapon(wt: Enums.WeaponType, effect := -1, chance := 1.0) -> ItemData:
	var it := ItemData.new()
	it.id = &"test_weapon"
	it.kind = ItemData.Kind.WEAPON
	it.weapon_type = wt
	it.attack_range = Vector2i(1, 1) if wt != W.BOW else Vector2i(2, 3)
	if effect >= 0:
		it.special = SpecialData.new()
		it.special.effect = effect
		it.special.chance = chance
	return it


func _arm(u: Unit, it: ItemData) -> void:
	u.items.append(it)
	if it.kind == ItemData.Kind.RING:
		u.ring_slot = u.items.size() - 1
	else:
		u.weapon_slot = u.items.size() - 1


## Makes `u` effectively unkillable for the test.
func _tank(u: Unit) -> void:
	u.base.hp = 999
	u.hp = 999


# --- matchups --------------------------------------------------------------

func test_matchup_triangle_and_mounted() -> void:
	var a := Unit.from_data(Fixtures.unit_data("hero"))
	var t := Unit.from_data(Fixtures.unit_data("goblin"), E)
	var cases := [
		[W.SWORD, W.AXE, 1], [W.AXE, W.SPEAR, 1], [W.SPEAR, W.SWORD, 1],
		[W.AXE, W.SWORD, -1], [W.SPEAR, W.AXE, -1], [W.SWORD, W.SPEAR, -1],
		[W.SWORD, W.SWORD, 0], [W.BOW, W.SWORD, 0], [W.STAFF, W.AXE, 0],
	]
	for c: Array in cases:
		a.items.clear()
		t.items.clear()
		_arm(a, _weapon(c[0]))
		_arm(t, _weapon(c[1]))
		assert_eq(Rules.matchup(a, t), c[2], "%s vs %s" % [W.keys()[c[0]], W.keys()[c[1]]])
	# spears and bows beat mounted units, even unarmed ones
	var wolf_class := ClassData.new()
	wolf_class.move_type = Enums.MoveType.MOUNTED
	t.items.clear()
	t.weapon_slot = -1
	t.class_data = wolf_class
	for wt: Enums.WeaponType in [W.SPEAR, W.BOW]:
		a.items.clear()
		_arm(a, _weapon(wt))
		assert_eq(Rules.matchup(a, t), 1, "%s vs mounted" % W.keys()[wt])
	a.items.clear()
	_arm(a, _weapon(W.SWORD))
	assert_eq(Rules.matchup(a, t), 0, "sword vs mounted is even")


func test_advantage_raises_hit_and_crit_and_shows_in_forecast() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var hero := b.living(P)[0]
	var gob := b.living(E)[0]
	gob.base.agi = 40   # keep hit chance away from the 99% cap
	gob.items.clear()
	_arm(gob, _weapon(W.AXE))
	hero.items.clear()
	_arm(hero, _weapon(W.SPEAR))
	var even_hit := Rules.hit_chance(b, hero, gob)  # spear vs axe = disadvantage
	assert_eq(Rules.forecast(b, hero, gob).adv, -1)
	hero.items.clear()
	_arm(hero, _weapon(W.SWORD))
	var fc := Rules.forecast(b, hero, gob)
	assert_eq(fc.adv, 1)
	assert_near(fc.hit - even_hit, 0.2, 0.001, "+10% with the advantage vs -10% without")
	assert_near(fc.crit, Rules.CRIT_CHANCE + Rules.ADV_CRIT, 0.0001)


# --- poison ---------------------------------------------------------------

func test_poison_special_poisons_on_hit() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)])
	var hero := b.living(P)[0]
	var gob := b.living(E)[0]
	_tank(gob)
	_arm(hero, _weapon(W.SWORD, SpecialData.Effect.POISON, 1.0))
	Fixtures.act_as(b, hero)
	var ev := b.apply(AttackCommand.on(hero.id, gob.id))
	var hit: bool = _events(ev, BattleEvent.ATTACKED)[0].data.hit
	assert_eq(gob.status.has(Unit.POISON), hit, "poisoned exactly when the hit lands")
	if hit:
		assert_eq(gob.status[Unit.POISON], Rules.POISON_TURNS)
		assert_eq(_events(ev, BattleEvent.STATUS_ADDED).size(), 1)


func test_poison_ticks_after_turn_then_wears_off() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := b.living(P)[0]
	var out: Array[BattleEvent] = []
	Rules.add_status(hero, Unit.POISON, 3, out)
	var tick := maxi(1, floori(hero.max_hp() * Rules.POISON_FRACTION))
	for turn in 3:
		Fixtures.act_as(b, hero)
		var hp := hero.hp
		var ev := b.apply(WaitCommand.by(hero.id))
		var dmg := _events(ev, BattleEvent.DAMAGED)
		assert_eq(dmg.size(), 1, "one poison tick on turn %d" % turn)
		assert_true(dmg[0].data.get("poison", false))
		assert_eq(hero.hp, hp - tick)
	assert_false(hero.status.has(Unit.POISON), "wears off after 3 turns")
	assert_eq(b.check_invariants(), PackedStringArray())


func test_poison_can_end_the_battle_once() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := b.living(P)[0]   # the leader
	var out: Array[BattleEvent] = []
	Rules.add_status(hero, Unit.POISON, 3, out)
	hero.hp = 1
	Fixtures.act_as(b, hero)
	var ev := b.apply(WaitCommand.by(hero.id))
	assert_false(hero.is_alive())
	assert_eq(b.outcome(), BattleState.Outcome.LOST)
	assert_eq(_events(ev, BattleEvent.BATTLE_ENDED).size(), 1)
	assert_true(BattleEvent.turn_over(ev))


func test_antidote_cures_poison() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := b.living(P)[0]
	var out: Array[BattleEvent] = []
	Rules.add_status(hero, Unit.POISON, 3, out)
	var antidote := ItemData.new()
	antidote.id = &"antidote"
	antidote.kind = ItemData.Kind.CONSUMABLE
	antidote.cures_poison = true
	hero.items.append(antidote)
	Fixtures.act_as(b, hero)
	var ev := b.apply(UseItemCommand.on(hero.id, hero.items.size() - 1, hero.id))
	assert_false(hero.status.has(Unit.POISON))
	assert_eq(_events(ev, BattleEvent.STATUS_ENDED).size(), 1)
	assert_eq(_events(ev, BattleEvent.DAMAGED).size(), 0, "cured before the end-of-turn tick")


# --- sleep -------------------------------------------------------------------

func test_sleeping_unit_skips_two_turns_then_acts() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var gob := b.living(E)[0]
	var out: Array[BattleEvent] = []
	Rules.add_status(gob, Unit.SLEEP, Rules.SLEEP_TURNS, out)
	var skipped := 0
	for i in 60:
		if b.current_actor() == gob:
			break
		for e in _events(b.apply(WaitCommand.by(b.current_actor().id)), BattleEvent.TURN_SKIPPED):
			if e.data.unit_id == gob.id:
				skipped += 1
	assert_eq(skipped, 2)
	assert_eq(b.current_actor(), gob, "acts after waking")
	assert_false(gob.status.has(Unit.SLEEP))


func test_damage_wakes_a_sleeper() -> void:
	for s in 20:
		var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], s)
		var hero := b.living(P)[0]
		var gob := b.living(E)[0]
		_tank(gob)
		var out: Array[BattleEvent] = []
		Rules.add_status(gob, Unit.SLEEP, Rules.SLEEP_TURNS, out)
		Fixtures.act_as(b, hero)
		var ev := b.apply(AttackCommand.on(hero.id, gob.id))
		if not _events(ev, BattleEvent.ATTACKED)[0].data.hit:
			continue
		assert_false(gob.status.has(Unit.SLEEP))
		assert_eq(_events(ev, BattleEvent.STATUS_ENDED).size(), 1)
		return
	fail("no seed landed a hit")


# --- regeneration ring, saves, replays ----------------------------------------

func test_regen_ring_heals_at_end_of_turn_capped() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := b.living(P)[0]
	var band := ItemData.new()
	band.id = &"vigor_band"
	band.kind = ItemData.Kind.RING
	band.regen = 2
	_arm(hero, band)
	hero.hp = hero.max_hp() - 5
	Fixtures.act_as(b, hero)
	b.apply(WaitCommand.by(hero.id))
	assert_eq(hero.hp, hero.max_hp() - 3)
	hero.hp = hero.max_hp() - 1
	Fixtures.act_as(b, hero)
	b.apply(WaitCommand.by(hero.id))
	assert_eq(hero.hp, hero.max_hp(), "capped at max HP")


func test_status_round_trips_through_unit_dict() -> void:
	var u := Unit.from_data(Fixtures.unit_data("hero"))
	assert_false(u.to_dict().has("status"), "healthy units keep the old format")
	u.status = {Unit.POISON: 2, Unit.SLEEP: 1}
	var back := Unit.from_dict(JSON.parse_string(JSON.stringify(u.to_dict())))
	assert_eq(back.status, {Unit.POISON: 2, Unit.SLEEP: 1})


func test_status_battles_replay_identically() -> void:
	for s in [3, 11, 42]:
		var party := Fixtures.party()
		for i in party.size():   # real items: battles copy units by content id
			_arm(party[i], Content.item(&"lull_staff" if i % 2 == 0 else &"venom_bow"))
		var b := BattleState.new(Fixtures.map(), party, s)
		b.start()
		AutoPlay.play_to_end(b)
		var again := BattleState.replay(Fixtures.map(), party, s, b.history)
		assert_eq(Golden.normalize(again.snapshot()), Golden.normalize(b.snapshot()), "seed %d" % s)
		assert_ne(b.outcome(), BattleState.Outcome.ONGOING)


# --- content -------------------------------------------------------------------

func test_slice_content_uses_status_items() -> void:
	var ch2 := Content.chapter(&"ch02")
	var stingers := ch2.battle.enemies.filter(func(e: EnemySpawn) -> bool: return e.unit.id == &"goblin_stinger")
	assert_eq(stingers.size(), 1, "one stinger in chapter 2")
	assert_eq(stingers[0].unit.starting_items[0].special.effect, SpecialData.Effect.POISON)
	assert_true(ch2.shop.has(Content.item(&"antidote")), "antidote sold when poison first appears")
	var ch3 := Content.chapter(&"ch03")
	for id: StringName in [&"antidote", &"lull_staff", &"vigor_band"]:
		assert_true(ch3.shop.has(Content.item(id)), "%s in the chapter 3 shop" % id)
	assert_eq(Content.item(&"vigor_band").regen, 2)
