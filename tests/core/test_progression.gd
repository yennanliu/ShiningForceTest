extends TestCase
## Step 8: XP and levels, promotion, bonds, spells, double attacks, specials, shop.

const P := Enums.Faction.PLAYER
const E := Enums.Faction.ENEMY


func _events(ev: Array[BattleEvent], type: StringName) -> Array:
	return ev.filter(func(e: BattleEvent) -> bool: return e.type == type)


# --- XP and levels -------------------------------------------------------

func test_level_up_every_100_xp() -> void:
	var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(7, 7)])
	var hero := b.living(P)[0]
	var out: Array[BattleEvent] = []
	var hp_before := hero.max_hp()
	Rules.gain_xp(b, hero, 150, out)
	assert_eq(hero.level, 2)
	assert_eq(hero.xp, 50)
	var ups := _events(out, BattleEvent.LEVELED_UP)
	assert_eq(ups.size(), 1)
	assert_true(hero.max_hp() >= hp_before + 3, "swordsman HP growth 3.0/level")
	assert_eq(hero.total_xp(), 250)


func test_growth_average_matches_class() -> void:
	var rng := Rng.new(1)
	var u := Unit.from_data(Fixtures.unit_data("hero"))   # swordsman: atk 24 = +2.4/level
	var start := u.base.atk
	var n := 10000
	var out: Array[BattleEvent] = []
	for i in n:
		Rules.level_up(rng, u, out)
	var avg := float(u.base.atk - start) / n
	assert_near(avg, 2.4, 2.4 * 0.02, "average atk gain")


# --- promotion -------------------------------------------------------------

func test_promotion_rules() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	var hero := c.party.leader()
	var master := Fixtures.class_data("swordmaster")
	assert_false(c.party.can_promote(hero), "level 1 can't promote")
	assert_false(c.party.promote(hero, master))
	hero.level = 20
	var atk := hero.base.atk
	assert_true(c.party.can_promote(hero))
	assert_false(c.party.promote(hero, Fixtures.class_data("sniper")), "wrong branch")
	assert_true(c.party.promote(hero, master))
	assert_eq(hero.class_data.id, &"swordmaster")
	assert_eq(hero.level, 1)
	assert_eq(hero.base.atk, atk, "stats kept")
	assert_eq(hero.mov(), 6)


# --- bonds -----------------------------------------------------------------

func test_bond_tiers_and_death() -> void:
	var bonds := Bonds.new()
	assert_eq(bonds.add(&"hero", &"knight", 39), 0)
	assert_eq(bonds.add(&"knight", &"hero", 1), 1, "order doesn't matter; 40 = tier 1")
	assert_eq(bonds.add(&"hero", &"knight", 80), 2, "120 = tier 2")
	bonds.drop_tier_on_death(&"knight")
	assert_eq(bonds.tier(&"hero", &"knight"), 1)
	assert_eq(bonds.get_points(&"hero", &"knight"), 40)


func test_adjacent_ally_earns_bond_points() -> void:
	var b := Fixtures.duel([Vector2i(2, 2), Vector2i(2, 3)], [Vector2i(3, 2)])
	var hero := b.grid.unit_at(Vector2i(2, 2))
	var gob := b.living(E)[0]
	Fixtures.act_as(b, hero)
	hero.base.luk = 500
	gob.base.def = -100   # survive check irrelevant; guarantees a hit lands
	gob.hp = 999
	b.apply(AttackCommand.on(hero.id, gob.id))
	assert_eq(b.bonds.get_points(&"hero", &"knight"), Bonds.ASSIST_POINTS)


func test_bond_bonus_raises_hit_and_damage() -> void:
	var b := Fixtures.duel([Vector2i(2, 2), Vector2i(2, 3)], [Vector2i(3, 2)])
	var hero := b.grid.unit_at(Vector2i(2, 2))
	var gob := b.living(E)[0]
	var hit0 := Rules.hit_chance(b, hero, gob)
	var raw0 := Rules.raw_damage(b, hero, gob)
	b.bonds.add(&"hero", &"knight", 260)   # tier 3
	assert_near(Rules.hit_chance(b, hero, gob), minf(hit0 + 0.06, 0.99), 0.0001)
	assert_near(Rules.raw_damage(b, hero, gob), raw0 * 1.06, 0.0001)


func test_campaign_keeps_bonds_and_applies_death_penalty() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	c.bonds.add(&"hero", &"scout", 130)
	var b := c.start_battle(1)
	assert_eq(b.bonds.get_points(&"hero", &"scout"), 130, "battle gets a copy")
	b.start()
	b.unit(4).hp = 0   # scout falls
	var r := c.finish_battle(b)
	assert_true(r.fallen.has(&"scout"))
	assert_eq(c.bonds.tier(&"hero", &"scout"), 1, "dropped from tier 2 to 1")
	assert_eq(Golden.normalize(Campaign.from_dict(c.to_dict()).bonds.to_dict()), Golden.normalize(c.bonds.to_dict()))


# --- spells ----------------------------------------------------------------

func _priest_battle() -> BattleState:
	var roster: Array[Unit] = [Unit.from_data(Fixtures.unit_data("hero")), Unit.from_data(Fixtures.unit_data("priest"))]
	roster[0].is_leader = true
	return Fixtures.duel([Vector2i(2, 2), Vector2i(2, 3)], [Vector2i(3, 3), Vector2i(4, 3)], 1, Vector2i(8, 8), {}, roster)


func test_heal_spell_restores_hp_and_costs_mp() -> void:
	var b := _priest_battle()
	var priest := b.grid.unit_at(Vector2i(2, 3))
	var hero := b.grid.unit_at(Vector2i(2, 2))
	Fixtures.act_as(b, priest)
	hero.hp = 5
	var ev := b.apply(CastCommand.at_tile(priest.id, &"heal", 1, hero.pos))
	assert_eq(_events(ev, BattleEvent.CAST).size(), 1)
	assert_eq(hero.hp, 17)
	assert_eq(priest.mp, 13)
	assert_true(_events(ev, BattleEvent.XP_GAINED).size() == 1, "healer earns XP")


func test_area_blaze_hits_everyone_in_radius() -> void:
	var b := _priest_battle()
	var priest := b.grid.unit_at(Vector2i(2, 3))
	Fixtures.act_as(b, priest)
	priest.class_data = priest.class_data.duplicate()
	var ev := b.apply(CastCommand.at_tile(priest.id, &"blaze", 2, Vector2i(4, 3)))
	var hit_ids := _events(ev, BattleEvent.DAMAGED).map(func(e: BattleEvent) -> int: return e.data.unit_id)
	assert_eq(hit_ids.size(), 2, "both goblins within radius 1 of (4,3)")
	assert_eq(priest.mp, 8)


func test_cannot_cast_without_mp_or_out_of_range() -> void:
	var b := _priest_battle()
	var priest := b.grid.unit_at(Vector2i(2, 3))
	Fixtures.act_as(b, priest)
	assert_false(CastCommand.at_tile(priest.id, &"blaze", 1, Vector2i(7, 7)).is_valid(b), "out of range / no target")
	priest.mp = 2
	assert_false(CastCommand.at_tile(priest.id, &"blaze", 1, Vector2i(3, 3)).is_valid(b), "not enough MP")
	assert_false(CastCommand.at_tile(b.grid.unit_at(Vector2i(2, 2)).id, &"heal", 1, Vector2i(2, 2)).is_valid(b), "hero knows no spells")
	var c := CastCommand.at_tile(3, &"heal", 2, Vector2i(1, 2))
	assert_eq(Command.from_dict(c.to_dict()).to_dict(), c.to_dict())


# --- double attacks and specials ------------------------------------------------

func test_double_attacks_and_specials_happen() -> void:
	var doubles := 0
	var specials := 0
	for s in 400:
		var b := Fixtures.duel([Vector2i(0, 0)], [Vector2i(1, 0)], s)
		var hero := b.living(P)[0]
		var gob := b.living(E)[0]
		hero.items.append(Fixtures.item("steel_sword"))
		hero.weapon_slot = hero.items.size() - 1
		gob.hp = 999
		gob.base.hp = 999
		Fixtures.act_as(b, hero)
		for e in _events(b.apply(AttackCommand.on(hero.id, gob.id)), BattleEvent.ATTACKED):
			if e.data.double: doubles += 1
			if e.data.special == "extra_hit": specials += 1
	assert_between(doubles, 8, 45, "about 6% of 400")
	assert_between(specials, 30, 100, "about 15% of hits")


# --- shop -------------------------------------------------------------------

func test_shop_buy_goes_to_a_unit() -> void:
	var c := Campaign.new_game(Fixtures.chapter(1))
	c.inventory.gold = 30
	assert_true(c.buy(Fixtures.item("herb")))
	assert_eq(c.inventory.gold, 20)
	assert_eq(c.party.leader().items.size(), 3, "hero had 2 items, now 3")
	assert_false(c.buy(Fixtures.item("bronze_sword")), "not enough gold")
