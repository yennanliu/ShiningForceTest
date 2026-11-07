extends SceneTree
## Generates the terrain set (data/terrain/) and test fixtures (tests/fixtures/)
## as .tres files. Re-run after changing a schema:
##   godot --headless --path . -s res://tools/make_fixtures.gd

const F := "res://tests/fixtures/"
const T := "res://data/terrain/"


func _initialize() -> void:
	var terrain := _terrain()
	var spells := _spells()
	var c := _classes(spells)
	var items := _items()
	var units := _units(c, items)
	var m1 := _map(terrain, units)
	var m2 := _boss_map(m1, units)
	_chapters(m1, m2, units, items)
	print("fixtures written")
	quit()


func _save(res: Resource, path: String) -> Resource:
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "could not save %s" % path)
	res.take_over_path(path)  # later saves reference this file instead of embedding it
	return res


func _t(id: StringName, land: float, costs: Array) -> TerrainData:
	var t := TerrainData.new()
	t.id = id
	t.land_effect = land
	t.move_cost = PackedInt32Array(costs)
	return _save(t, T + "%s.tres" % id)


# Costs per move type:         FOOT ARMOR MOUNT FLY AQUA
func _terrain() -> Dictionary:
	return {
		"plain": _t(&"plain", 0.0, [1, 1, 1, 1, 3]),
		"forest": _t(&"forest", 0.15, [2, 3, 3, 1, 3]),
		"hill": _t(&"hill", 0.30, [2, 3, 2, 1, 3]),
		"sand": _t(&"sand", 0.0, [2, 2, 3, 1, 3]),
		"shallow": _t(&"shallow", 0.0, [3, -1, -1, 1, 1]),
		"deep": _t(&"deep", 0.0, [-1, -1, -1, 1, 1]),
		"wall": _t(&"wall", 0.0, [-1, -1, -1, -1, -1]),
	}


func _class(id: StringName, weapon: Enums.WeaponType, growth: Stats, promotes: Array[ClassData] = [],
		spells: Array[SpellData] = [], mov := 5) -> ClassData:
	var c := ClassData.new()
	c.promotes_to = promotes
	c.spells = spells
	c.id = id
	c.display_name = String(id).capitalize()
	c.move_type = Enums.MoveType.FOOT
	c.mov = mov
	c.jump = 2
	c.weapon_types = [weapon]
	c.growth = growth
	return _save(c, F + "class_%s.tres" % id)


func _spell(id: StringName, heals: bool, levels: Array) -> SpellData:
	var sp := SpellData.new()
	sp.id = id
	sp.display_name = String(id).capitalize()
	sp.heals = heals
	for l in levels:
		var lv := SpellLevel.new()
		lv.mp_cost = l[0]
		lv.power = l[1]
		lv.spell_range = l[2]
		lv.area = l[3]
		sp.levels.append(lv)
	return _save(sp, F + "spell_%s.tres" % id)


func _spells() -> Dictionary:
	return {
		# [mp, power, range, area]
		"heal": _spell(&"heal", true, [[3, 12, Vector2i(0, 1), 0], [6, 20, Vector2i(0, 2), 1]]),
		"blaze": _spell(&"blaze", false, [[4, 9, Vector2i(1, 2), 0], [8, 12, Vector2i(1, 2), 1]]),
	}


func _classes(sp: Dictionary) -> Dictionary:
	var master := _class(&"swordmaster", Enums.WeaponType.SWORD, Stats.make(35, 0, 28, 22, 18, 12), [], [], 6)
	var sniper := _class(&"sniper", Enums.WeaponType.BOW, Stats.make(30, 0, 27, 15, 19, 14), [], [], 6)
	var heal_blaze: Array[SpellData] = [sp.heal, sp.blaze]
	return {
		"swordsman": _class(&"swordsman", Enums.WeaponType.SWORD, Stats.make(30, 0, 24, 18, 15, 10), [master]),
		"archer": _class(&"archer", Enums.WeaponType.BOW, Stats.make(25, 0, 22, 12, 16, 12), [sniper]),
		"cleric": _class(&"cleric", Enums.WeaponType.STAFF, Stats.make(22, 25, 10, 10, 12, 15), [], heal_blaze),
	}


func _item(id: StringName, kind: ItemData.Kind, wt: Enums.WeaponType, bonus: Stats,
		rng: Vector2i, heal: int, price: int) -> ItemData:
	var i := ItemData.new()
	i.id = id
	i.display_name = String(id).capitalize()
	i.kind = kind
	i.weapon_type = wt
	i.bonus = bonus
	i.attack_range = rng
	i.heal_amount = heal
	i.price = price
	return _save(i, F + "item_%s.tres" % id)


func _items() -> Dictionary:
	var W := ItemData.Kind.WEAPON
	return {
		"bronze_sword": _item(&"bronze_sword", W, Enums.WeaponType.SWORD, Stats.make(0, 0, 5, 0, 0, 0), Vector2i(1, 1), 0, 100),
		"wooden_bow": _item(&"wooden_bow", W, Enums.WeaponType.BOW, Stats.make(0, 0, 4, 0, 0, 0), Vector2i(2, 3), 0, 120),
		"herb": _item(&"herb", ItemData.Kind.CONSUMABLE, Enums.WeaponType.NONE, null, Vector2i(1, 1), 10, 10),
		"wooden_staff": _item(&"wooden_staff", W, Enums.WeaponType.STAFF, Stats.make(0, 0, 2, 0, 0, 0), Vector2i(1, 1), 0, 60),
		"steel_sword": _steel_sword(),
	}


## A sword with a weapon special (extra hit).
func _steel_sword() -> ItemData:
	var i := ItemData.new()
	i.id = &"steel_sword"
	i.display_name = "Steel Sword"
	i.kind = ItemData.Kind.WEAPON
	i.weapon_type = Enums.WeaponType.SWORD
	i.bonus = Stats.make(0, 0, 8, 0, 0, 0)
	i.price = 300
	var sp := SpecialData.new()
	sp.effect = SpecialData.Effect.EXTRA_HIT
	sp.chance = 0.15
	i.special = sp
	return _save(i, F + "item_steel_sword.tres")


func _unit(id: StringName, cls: ClassData, stats: Stats, items: Array[ItemData]) -> UnitData:
	var u := UnitData.new()
	u.id = id
	u.display_name = String(id).capitalize()
	u.class_data = cls
	u.base_level = 1
	u.base_stats = stats
	u.starting_items = items
	return _save(u, F + "unit_%s.tres" % id)


func _units(c: Dictionary, i: Dictionary) -> Dictionary:
	var sword: Array[ItemData] = [i.bronze_sword, i.herb]
	var bow: Array[ItemData] = [i.wooden_bow]
	var staff: Array[ItemData] = [i.wooden_staff, i.herb]
	return {
		"hero": _unit(&"hero", c.swordsman, Stats.make(20, 0, 10, 6, 8, 5), sword),
		"knight": _unit(&"knight", c.swordsman, Stats.make(22, 0, 9, 7, 6, 4), sword),
		"archer": _unit(&"archer", c.archer, Stats.make(16, 0, 9, 4, 7, 5), bow),
		"scout": _unit(&"scout", c.archer, Stats.make(15, 0, 8, 4, 9, 6), bow),
		"priest": _unit(&"priest", c.cleric, Stats.make(14, 16, 5, 4, 6, 8), staff),
		"goblin": _unit(&"goblin", c.swordsman, Stats.make(14, 0, 8, 4, 6, 3), sword),
		"goblin_archer": _unit(&"goblin_archer", c.archer, Stats.make(12, 0, 7, 3, 6, 3), bow),
	}


func _spawn(u: UnitData, at: Vector2i, tag: StringName = &"") -> EnemySpawn:
	var e := EnemySpawn.new()
	e.unit = u
	e.level = 1
	e.at = at
	e.tag = tag
	return e


## 8x8 test map. Legend: . plain  f forest  h hill (height 2)
##   y0  . . . . . . . .      enemies top-right, players bottom-left
##   y2  . . . . . f . .
##   y3  . . . h h . . .
##   y4  . . . h h . . .
##   y5  . . f . . . . .
func _map(t: Dictionary, u: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = &"fixture_8x8"
	m.size = Vector2i(8, 8)
	m.terrain_types = [t.plain, t.forest, t.hill]
	m.heights = PackedByteArray()
	m.terrain_ids = PackedByteArray()
	m.heights.resize(64)
	m.terrain_ids.resize(64)
	for y in 8:
		for x in 8:
			var i := y * 8 + x
			if x in [3, 4] and y in [3, 4]:
				m.terrain_ids[i] = 2
				m.heights[i] = 2
			elif Vector2i(x, y) in [Vector2i(5, 2), Vector2i(2, 5)]:
				m.terrain_ids[i] = 1
	m.player_spawns = [Vector2i(0, 6), Vector2i(1, 7), Vector2i(0, 7), Vector2i(1, 6)]
	m.enemies = [
		_spawn(u.goblin, Vector2i(7, 1), &"boss"),
		_spawn(u.goblin, Vector2i(6, 0)),
		_spawn(u.goblin_archer, Vector2i(7, 0)),
		_spawn(u.goblin_archer, Vector2i(6, 1)),
	]
	m.enemies[0].is_leader = true
	m.objective = Enums.Objective.ROUT
	return _save(m, F + "map_8x8.tres")


## Same terrain, five enemies; win by defeating the boss.
func _boss_map(base: MapData, u: Dictionary) -> MapData:
	var m := MapData.new()
	m.id = &"fixture_boss"
	m.size = base.size
	m.terrain_types = base.terrain_types
	m.heights = base.heights
	m.terrain_ids = base.terrain_ids
	m.player_spawns = base.player_spawns
	var boss := _spawn(u.goblin, Vector2i(7, 0), &"boss")
	boss.level = 3
	boss.ai = Enums.AiProfile.HOLD
	m.enemies = [
		boss,
		_spawn(u.goblin, Vector2i(5, 1)),
		_spawn(u.goblin, Vector2i(6, 2)),
		_spawn(u.goblin_archer, Vector2i(6, 0)),
		_spawn(u.goblin_archer, Vector2i(7, 1)),
	]
	m.objective = Enums.Objective.DEFEAT_BOSS
	m.objective_tag = &"boss"
	return _save(m, F + "map_boss.tres")


func _chapters(m1: MapData, m2: MapData, u: Dictionary, i: Dictionary) -> void:
	var c2 := ChapterData.new()
	c2.id = &"ch02"
	c2.title = "Chapter 2: The Goblin Chief"
	c2.battle = m2
	c2.reward_gold = 150
	c2.recruits_on_start = [u.priest]
	c2.shop = [i.herb, i.steel_sword, i.wooden_bow]
	_save(c2, F + "chapter_02.tres")
	var c1 := ChapterData.new()
	c1.id = &"ch01"
	c1.title = "Chapter 1: The Border Road"
	c1.battle = m1
	c1.recruits_on_start = [u.hero, u.knight, u.archer, u.scout]
	c1.reward_gold = 100
	c1.shop = [i.herb, i.bronze_sword, i.wooden_bow]
	c1.next = c2
	_save(c1, F + "chapter_01.tres")
