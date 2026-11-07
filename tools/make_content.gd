extends SceneTree
## Generates the vertical-slice content into res://data/ (doc/03 step 11).
## Maps are written as ASCII grids below, so they're easy to read and edit.
##   godot --headless --path . -s res://tools/make_content.gd
##
## Map legend:  . plain  f forest  ^ hill (h1)  H hill (h2)  : sand  ~ shallow  w deep  # wall
##              P player spawn (reading order)   $ treasure chest (on plain)
##              enemies: g goblin  a goblin archer  v goblin venomer (poison bow)  l wolf  b bandit  B goblin chief (boss)
##              V villager (computer-controlled ally to protect)

const D := "res://data/"

var T := {}   # terrain
var S := {}   # spells
var C := {}   # classes
var I := {}   # items
var U := {}   # units


func _initialize() -> void:
	_terrain()
	_spells()
	_classes()
	_items()
	_units()
	var m1 := _map_ruins()
	var m2 := _map_millford()
	var m3 := _map_chief()
	_chapters(m1, m2, m3)
	print("content written")
	quit()


func _save(res: Resource, path: String) -> Resource:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var err := ResourceSaver.save(res, path)
	assert(err == OK, "could not save %s" % path)
	res.take_over_path(path)
	return res


# --- terrain, spells, classes, items, units ---------------------------------

func _terrain() -> void:
	for id in ["plain", "forest", "hill", "sand", "shallow", "deep", "wall"]:
		T[id] = load(D + "terrain/%s.tres" % id)


func _spell(id: StringName, heals: bool, levels: Array) -> void:
	var sp := SpellData.new()
	sp.id = id
	sp.display_name = String(id).capitalize()
	sp.heals = heals
	for l in levels:   # [mp, power, range, area]
		var lv := SpellLevel.new()
		lv.mp_cost = l[0]
		lv.power = l[1]
		lv.spell_range = l[2]
		lv.area = l[3]
		sp.levels.append(lv)
	S[id] = _save(sp, D + "spells/%s.tres" % id)


func _spells() -> void:
	_spell(&"heal", true, [[3, 12, Vector2i(0, 1), 0], [6, 20, Vector2i(0, 2), 0]])
	_spell(&"aura", true, [[7, 14, Vector2i(0, 2), 1], [12, 22, Vector2i(0, 3), 2]])
	_spell(&"blaze", false, [[4, 10, Vector2i(1, 2), 0], [8, 14, Vector2i(1, 2), 1]])
	_spell(&"freeze", false, [[5, 12, Vector2i(1, 2), 0], [9, 17, Vector2i(1, 3), 1]])


## growth in tenths per level: [hp, mp, atk, def, agi, luk]
func _class(id: StringName, mt: Enums.MoveType, mov: int, weapon: Enums.WeaponType, g: Array,
		spells: Array = [], promotes: Array = []) -> ClassData:
	var c := ClassData.new()
	c.id = id
	c.display_name = String(id).capitalize()
	c.move_type = mt
	c.mov = mov
	c.jump = 2
	c.weapon_types = [weapon]
	c.growth = Stats.make(g[0], g[1], g[2], g[3], g[4], g[5])
	for sp in spells:
		c.spells.append(S[sp])
	for p in promotes:
		c.promotes_to.append(C[p])
	C[id] = _save(c, D + "classes/%s.tres" % id)
	return c


func _classes() -> void:
	var F := Enums.MoveType.FOOT
	var W := Enums.WeaponType
	# promoted classes first, so the base classes can point at them
	_class(&"swordmaster", F, 6, W.SWORD, [35, 0, 28, 22, 18, 12])
	_class(&"paladin", Enums.MoveType.MOUNTED, 6, W.SPEAR, [38, 0, 25, 28, 14, 10])
	_class(&"sniper", F, 6, W.BOW, [30, 0, 27, 15, 19, 14])
	_class(&"bishop", F, 5, W.STAFF, [26, 30, 12, 12, 14, 16], [&"heal", &"aura"])
	_class(&"wizard", F, 5, W.STAFF, [23, 35, 10, 10, 15, 13], [&"blaze", &"freeze"])
	_class(&"berserker", F, 5, W.AXE, [40, 0, 31, 18, 14, 9])
	_class(&"swordsman", F, 5, W.SWORD, [30, 0, 24, 18, 15, 10], [], [&"swordmaster"])
	_class(&"knight", Enums.MoveType.ARMORED, 4, W.SPEAR, [35, 0, 20, 25, 10, 8], [], [&"paladin"])
	_class(&"archer", F, 5, W.BOW, [25, 0, 22, 12, 16, 12], [], [&"sniper"])
	_class(&"cleric", F, 5, W.STAFF, [22, 25, 10, 10, 12, 15], [&"heal"], [&"bishop"])
	_class(&"mage", F, 5, W.STAFF, [20, 30, 8, 8, 13, 12], [&"blaze"], [&"wizard"])
	_class(&"warrior", F, 5, W.AXE, [35, 0, 26, 15, 12, 8], [], [&"berserker"])
	_class(&"beast", Enums.MoveType.MOUNTED, 7, W.NONE, [30, 0, 22, 10, 18, 8])
	_class(&"civilian", F, 4, W.NONE, [10, 0, 2, 5, 5, 5])


func _item(id: StringName, kind: ItemData.Kind, wt: Enums.WeaponType, bonus: Array, rng: Vector2i,
		heal: int, price: int, special: SpecialData = null, cures_poison := false, regen := 0) -> void:
	var i := ItemData.new()
	i.id = id
	i.display_name = String(id).capitalize()
	i.kind = kind
	i.weapon_type = wt
	if not bonus.is_empty():
		i.bonus = Stats.make(0, 0, bonus[0], bonus[1], 0, 0)
	i.attack_range = rng
	i.heal_amount = heal
	i.price = price
	i.special = special
	i.cures_poison = cures_poison
	i.regen = regen
	I[id] = _save(i, D + "items/%s.tres" % id)


func _items() -> void:
	var K := ItemData.Kind
	var W := Enums.WeaponType
	var one := Vector2i(1, 1)
	var bow := Vector2i(2, 3)
	var extra := SpecialData.new()
	extra.effect = SpecialData.Effect.EXTRA_HIT
	extra.chance = 0.15
	var drain := SpecialData.new()
	drain.effect = SpecialData.Effect.DRAIN
	drain.chance = 0.12
	var poison := SpecialData.new()
	poison.effect = SpecialData.Effect.POISON
	poison.chance = 0.2
	var sleep := SpecialData.new()
	sleep.effect = SpecialData.Effect.SLEEP
	sleep.chance = 0.2
	_item(&"bronze_sword", K.WEAPON, W.SWORD, [5, 0], one, 0, 100)
	_item(&"steel_sword", K.WEAPON, W.SWORD, [8, 0], one, 0, 300, extra)
	_item(&"bronze_spear", K.WEAPON, W.SPEAR, [5, 0], one, 0, 110)
	_item(&"hand_axe", K.WEAPON, W.AXE, [6, 0], one, 0, 120)
	_item(&"wooden_bow", K.WEAPON, W.BOW, [4, 0], bow, 0, 120)
	_item(&"long_bow", K.WEAPON, W.BOW, [7, 0], bow, 0, 280, drain)
	_item(&"wooden_staff", K.WEAPON, W.STAFF, [2, 0], one, 0, 60)
	_item(&"herb", K.CONSUMABLE, W.NONE, [], one, 10, 10)
	_item(&"healing_seed", K.CONSUMABLE, W.NONE, [], one, 20, 30)
	_item(&"power_ring", K.RING, W.NONE, [2, 1], one, 0, 400)
	# step 12: status effects and regeneration
	_item(&"venom_bow", K.WEAPON, W.BOW, [5, 0], bow, 0, 260, poison)
	_item(&"lull_staff", K.WEAPON, W.STAFF, [3, 0], one, 0, 240, sleep)
	_item(&"antidote", K.CONSUMABLE, W.NONE, [], one, 0, 20, null, true)
	_item(&"vigor_band", K.RING, W.NONE, [0, 2], one, 0, 450, null, false, 2)


## base stats: [hp, mp, atk, def, agi, luk]
func _unit(id: StringName, name: String, cls: StringName, st: Array, items: Array) -> void:
	var u := UnitData.new()
	u.id = id
	u.display_name = name
	u.class_data = C[cls]
	u.base_stats = Stats.make(st[0], st[1], st[2], st[3], st[4], st[5])
	for it in items:
		u.starting_items.append(I[it])
	U[id] = _save(u, D + "units/%s.tres" % id)


func _units() -> void:
	# the party (8 recruits)
	_unit(&"aldric", "Aldric", &"swordsman", [20, 0, 10, 6, 8, 5], [&"bronze_sword", &"herb"])
	_unit(&"brina", "Brina", &"knight", [24, 0, 9, 9, 5, 4], [&"bronze_spear"])
	_unit(&"corin", "Corin", &"archer", [16, 0, 9, 4, 7, 5], [&"wooden_bow"])
	_unit(&"dara", "Dara", &"cleric", [15, 14, 5, 4, 6, 8], [&"wooden_staff", &"herb"])
	_unit(&"eamon", "Eamon", &"mage", [14, 16, 4, 3, 6, 6], [&"wooden_staff"])
	_unit(&"fiora", "Fiora", &"swordsman", [18, 0, 9, 5, 10, 7], [&"bronze_sword"])
	_unit(&"garret", "Garret", &"warrior", [24, 0, 11, 6, 5, 4], [&"hand_axe", &"herb"])
	_unit(&"hale", "Hale", &"archer", [16, 0, 8, 4, 9, 8], [&"wooden_bow", &"herb"])
	# enemies and guests
	_unit(&"goblin", "Goblin", &"swordsman", [14, 0, 8, 4, 6, 3], [&"bronze_sword"])
	_unit(&"goblin_archer", "Goblin Archer", &"archer", [12, 0, 7, 3, 6, 3], [&"wooden_bow"])
	_unit(&"goblin_venomer", "Goblin Venomer", &"archer", [12, 0, 6, 3, 6, 3], [&"venom_bow"])
	_unit(&"wolf", "Wolf", &"beast", [13, 0, 9, 3, 9, 3], [])
	_unit(&"bandit", "Bandit", &"warrior", [16, 0, 9, 4, 7, 4], [&"hand_axe"])
	_unit(&"goblin_chief", "Goblin Chief", &"swordsman", [34, 0, 13, 7, 7, 5], [&"steel_sword"])
	_unit(&"villager", "Villager", &"civilian", [20, 0, 1, 5, 6, 5], [])


# --- maps ---------------------------------------------------------------------

const ENEMY_LETTERS := {"g": &"goblin", "a": &"goblin_archer", "v": &"goblin_venomer", "l": &"wolf", "b": &"bandit", "B": &"goblin_chief"}


## Builds a MapData from an ASCII grid (tokens separated by spaces).
func _grid(id: StringName, rows: Array) -> Dictionary:
	var m := MapData.new()
	m.id = id
	var h := rows.size()
	var w: int = rows[0].split(" ", false).size()
	m.size = Vector2i(w, h)
	m.terrain_types = [T.plain, T.forest, T.hill, T.sand, T.shallow, T.deep, T.wall]
	var tid := {".": 0, "f": 1, "^": 2, "H": 2, ":": 3, "~": 4, "w": 5, "#": 6}
	m.heights.resize(w * h)
	m.terrain_ids.resize(w * h)
	var chests: Array[Vector2i] = []
	var extra := {}
	for y in h:
		var cells: PackedStringArray = rows[y].split(" ", false)
		assert(cells.size() == w, "%s row %d has %d cells, expected %d" % [id, y, cells.size(), w])
		for x in w:
			var c := cells[x]
			var t := Vector2i(x, y)
			m.terrain_ids[y * w + x] = tid.get(c, 0)
			m.heights[y * w + x] = 2 if c == "H" else (1 if c == "^" else 0)
			if c == "P":
				m.player_spawns.append(t)
			elif c == "$":
				chests.append(t)
			elif ENEMY_LETTERS.has(c):
				m.enemies.append(_spawn(ENEMY_LETTERS[c], t))
			elif c == "V":
				var v := _spawn(&"villager", t, &"villager", Enums.AiProfile.FLEE)
				m.allies.append(v)
	return {"map": m, "chests": chests}


func _spawn(unit: StringName, at: Vector2i, tag: StringName = &"", ai := Enums.AiProfile.AGGRESSIVE, level := 1) -> EnemySpawn:
	var e := EnemySpawn.new()
	e.unit = U[unit]
	e.at = at
	e.tag = tag
	e.ai = ai
	e.level = level
	return e


func _trigger(when: TriggerData.When, actions: Array, opts := {}) -> TriggerData:
	var t := TriggerData.new()
	t.when = when
	t.on_round = opts.get("round", 1)
	t.tag = opts.get("tag", &"")
	t.hp_percent = opts.get("hp", 50)
	t.area = opts.get("area", Rect2i())
	t.unless_flag = opts.get("unless", &"")
	for a in actions:
		t.actions.append(a)
	return t


func _act(kind: TriggerAction.Kind, opts := {}) -> TriggerAction:
	var a := TriggerAction.new()
	a.kind = kind
	a.key = opts.get("key", &"")
	a.spawn = opts.get("spawn", null)
	a.item = opts.get("item", null)
	a.ai = opts.get("ai", Enums.AiProfile.AGGRESSIVE)
	return a


func _say(key: StringName) -> TriggerAction:
	return _act(TriggerAction.Kind.SAY, {"key": key})


## Battle 1 — loot race: open three chests before the raiders loot them (round 6).
func _map_ruins() -> MapData:
	var g := _grid(&"m01_ruins_road", [
		". . f . . . . . f . . .",
		". $ . . ^ ^ . . . . g .",
		". . . . ^ H . . f . . .",
		". f . . . ^ . . . g . $",
		". . . . . . . . . . . .",
		". . . # # . . f . . . .",
		". . . # $ . . . . a . .",
		". P . . . . f . . . . .",
		"P P . . f . . . . . . .",
		". P . . . . . . . . . .",
	])
	var m: MapData = g.map
	var loot := [I.healing_seed, I.power_ring, I.steel_sword]
	m.triggers.append(_trigger(TriggerData.When.ROUND_START, [_say(&"ch01_intro"), _say(&"ch01_chests")]))
	for i in g.chests.size():
		m.triggers.append(_trigger(TriggerData.When.UNIT_ENTERS, [_act(TriggerAction.Kind.GIVE, {"item": loot[i]})],
			{"area": Rect2i(g.chests[i], Vector2i.ONE), "unless": &"looted"}))
	m.triggers.append(_trigger(TriggerData.When.ROUND_START,
		[_act(TriggerAction.Kind.SET_FLAG, {"key": &"looted"}), _say(&"ch01_looted")], {"round": 6}))
	m.objective = Enums.Objective.ROUT
	return _save(m, D + "maps/m01_ruins_road.tres")


## Battle 2 — protect the villager (who flees on its own); wolves join on round 3.
func _map_millford() -> MapData:
	var g := _grid(&"m02_millford", [
		". . . . f f . . . . l .",
		". # # . . . . . . . . .",
		". # . . . f . . l . . .",
		". . . V . . . . . . . g",
		". # . . . . ^ . . . . .",
		". # # . . . ^ . . g . .",
		". . . . f . . . . . . l",
		"P P . . . . . . f . . .",
		"P P . . f . . . . . v .",
		"P P . . . . . . . . . .",
	])
	var m: MapData = g.map
	m.triggers.append(_trigger(TriggerData.When.ROUND_START, [_say(&"ch02_intro"), _say(&"ch02_villager")]))
	m.triggers.append(_trigger(TriggerData.When.ROUND_START, [
		_say(&"ch02_wolves"),
		_act(TriggerAction.Kind.SPAWN, {"spawn": _spawn(&"wolf", Vector2i(11, 0))}),
		_act(TriggerAction.Kind.SPAWN, {"spawn": _spawn(&"wolf", Vector2i(11, 9))}),
	], {"round": 3}))
	m.triggers.append(_trigger(TriggerData.When.UNIT_DIES, [_say(&"ch02_villager_down"), _act(TriggerAction.Kind.LOSE)], {"tag": &"villager"}))
	m.objective = Enums.Objective.ROUT
	return _save(m, D + "maps/m02_millford.tres")


## Battle 3 — the chief holds until hurt, then charges and calls guards.
func _map_chief() -> MapData:
	var g := _grid(&"m03_chief_camp", [
		". . . . . f f . . . . .",
		". . a . . . . . # # # .",
		". . . . ^ . . . # B . .",
		". f . . ^ . b . . . . .",
		". . . . . . . . . . g .",
		". . g . f . . ^ ^ . . .",
		". . . . . . . ^ H . v .",
		"P P . . . f . . . . . .",
		"P P . . . . . . f . . .",
		"P P P P . . . . . . . .",
	])
	var m: MapData = g.map
	for e in m.enemies:
		if e.unit.id == &"goblin_chief":
			e.tag = &"chief"
			e.level = 3
			e.ai = Enums.AiProfile.HOLD
			e.is_leader = true
	m.triggers.append(_trigger(TriggerData.When.ROUND_START, [_say(&"ch03_intro"), _say(&"chief_intro")]))
	m.triggers.append(_trigger(TriggerData.When.HP_BELOW, [
		_say(&"chief_phase2"),
		_act(TriggerAction.Kind.SET_AI, {"key": &"chief", "ai": Enums.AiProfile.AGGRESSIVE}),
		_act(TriggerAction.Kind.SPAWN, {"spawn": _spawn(&"goblin", Vector2i(11, 1))}),
		_act(TriggerAction.Kind.SPAWN, {"spawn": _spawn(&"goblin_archer", Vector2i(10, 3))}),
	], {"tag": &"chief", "hp": 50}))
	m.triggers.append(_trigger(TriggerData.When.UNIT_DIES, [_say(&"chief_defeated")], {"tag": &"chief"}))
	m.objective = Enums.Objective.DEFEAT_BOSS
	m.objective_tag = &"chief"
	return _save(m, D + "maps/m03_chief_camp.tres")


# --- chapters -------------------------------------------------------------------

func _chapters(m1: MapData, m2: MapData, m3: MapData) -> void:
	var c3 := ChapterData.new()
	c3.id = &"ch03"
	c3.title = "Chapter 3: The Chief's Camp"
	c3.battle = m3
	c3.recruits_on_start = [U.garret, U.hale]
	c3.reward_gold = 300
	c3.shop = [I.herb, I.antidote, I.healing_seed, I.long_bow, I.lull_staff, I.power_ring, I.vigor_band]
	_save(c3, D + "chapters/ch03.tres")
	var c2 := ChapterData.new()
	c2.id = &"ch02"
	c2.title = "Chapter 2: Wolves at Millford"
	c2.battle = m2
	c2.recruits_on_start = [U.eamon, U.fiora]
	c2.reward_gold = 150
	c2.shop = [I.herb, I.antidote, I.healing_seed, I.hand_axe, I.steel_sword]
	c2.town_name = "Millford"
	c2.town_talk = [&"town_mayor", &"town_child", &"town_hunter"]
	c2.town_finds = [I.herb, I.long_bow]
	c2.next = c3
	_save(c2, D + "chapters/ch02.tres")
	var c1 := ChapterData.new()
	c1.id = &"ch01"
	c1.title = "Chapter 1: The Ruins Road"
	c1.battle = m1
	c1.recruits_on_start = [U.aldric, U.brina, U.corin, U.dara]
	c1.reward_gold = 100
	c1.shop = [I.herb, I.bronze_sword, I.bronze_spear, I.wooden_bow]
	c1.town_name = "Riverside"
	c1.town_talk = [&"town_elder", &"town_smith"]
	c1.town_finds = [I.healing_seed]
	c1.next = c2
	_save(c1, D + "chapters/ch01.tres")
