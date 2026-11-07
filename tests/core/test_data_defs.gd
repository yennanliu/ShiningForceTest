extends TestCase
## Step 1: data schema and fixtures.


func test_every_fixture_loads_with_its_type() -> void:
	var paths := Fixtures.all_paths()
	assert_true(paths.size() >= 12, "expected >= 12 fixtures, got %d" % paths.size())
	for p in paths:
		var r := load(p)
		assert_true(r != null, "could not load %s" % p)
		var expected := "Resource"
		if p.get_file().begins_with("unit_"): expected = "UnitData"
		elif p.get_file().begins_with("class_"): expected = "ClassData"
		elif p.get_file().begins_with("item_"): expected = "ItemData"
		elif p.get_file().begins_with("map_"): expected = "MapData"
		assert_eq(r.get_script().get_global_name(), StringName(expected), p)


func test_fixture_round_trip_keeps_fields() -> void:
	for p in Fixtures.all_paths():
		var a: Resource = load(p)
		var tmp := "user://roundtrip_%s" % p.get_file()
		assert_eq(ResourceSaver.save(a, tmp), OK, p)
		var b: Resource = ResourceLoader.load(tmp, "", ResourceLoader.CACHE_MODE_IGNORE)
		for prop in a.get_property_list():
			if prop.usage & PROPERTY_USAGE_STORAGE == 0 or prop.name in ["resource_path", "resource_name", "resource_scene_unique_id", "script"]:
				continue
			assert_eq(_plain(b.get(prop.name)), _plain(a.get(prop.name)), "%s.%s" % [p.get_file(), prop.name])
		DirAccess.remove_absolute(tmp)


func test_hero_fixture_values() -> void:
	var hero := Fixtures.unit_data("hero")
	assert_eq(hero.id, &"hero")
	assert_eq(hero.base_stats.hp, 20)
	assert_eq(hero.class_data.id, &"swordsman")
	assert_eq(hero.starting_items[0].id, &"bronze_sword")
	assert_eq(hero.class_data.move_type, Enums.MoveType.FOOT)


func test_terrain_costs() -> void:
	var forest: TerrainData = load("res://data/terrain/forest.tres")
	assert_eq(forest.cost_for(Enums.MoveType.FOOT), 2)
	assert_eq(forest.cost_for(Enums.MoveType.FLYING), 1)
	assert_near(forest.land_effect, 0.15, 0.001)
	var wall: TerrainData = load("res://data/terrain/wall.tres")
	assert_eq(wall.cost_for(Enums.MoveType.FLYING), TerrainData.IMPASSABLE)


func test_fixture_map_is_valid() -> void:
	var m := Fixtures.map()
	assert_eq(Array(m.validate()), [])
	assert_eq(m.terrain_at(Vector2i(3, 3)).id, &"hill")
	assert_eq(m.heights[m.index(Vector2i(3, 3))], 2)


func test_broken_map_reports_errors() -> void:
	var m: MapData = Fixtures.map().duplicate(true)
	m.heights.resize(10)
	m.player_spawns.append(Vector2i(20, 20))
	m.player_spawns.append(m.player_spawns[0])
	var errs := " | ".join(m.validate())
	assert_true(errs.contains("heights has 10 entries"), errs)
	assert_true(errs.contains("out of bounds"), errs)
	assert_true(errs.contains("overlaps"), errs)


## Content lint: every shipped map must validate.
func test_all_game_maps_validate() -> void:
	for f in DirAccess.get_files_at("res://data/maps/"):
		if f.ends_with(".tres"):
			var m: MapData = load("res://data/maps/" + f)
			assert_eq(Array(m.validate()), [], f)


# Resources compare by identity; compare them by their stored fields instead.
func _plain(v: Variant) -> Variant:
	if v is Resource:
		if v.resource_path != "" and not v.resource_path.contains("::"):
			return v.resource_path
		var d := {}
		for prop in v.get_property_list():
			if prop.usage & PROPERTY_USAGE_STORAGE and prop.name not in ["resource_path", "resource_name", "resource_scene_unique_id", "script"]:
				d[prop.name] = _plain(v.get(prop.name))
		return d
	if v is Array:
		return v.map(_plain)
	return v
