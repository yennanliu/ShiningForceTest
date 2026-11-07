class_name Content
## Looks up content Resources by their `id`, so saves and replays store ids, not file paths.
## Scans res://data/ by default; tests add res://tests/fixtures/ with register_dir().

const DEFAULT_DIRS := ["res://data/units/", "res://data/classes/", "res://data/items/", "res://data/spells/"]

static var _by_kind: Dictionary = {}   # "UnitData" -> {id: Resource}
static var _scanned := false
static var _dirs: Dictionary = {}


static func register_dir(dir: String) -> void:
	_ensure_scanned()
	_scan(dir)


static func unit(id: StringName) -> UnitData:
	return _lookup("UnitData", id)


static func class_data(id: StringName) -> ClassData:
	return _lookup("ClassData", id)


static func item(id: StringName) -> ItemData:
	return _lookup("ItemData", id)


static func spell(id: StringName) -> SpellData:
	return _lookup("SpellData", id)


static func _lookup(kind: String, id: StringName) -> Resource:
	_ensure_scanned()
	var r: Resource = _by_kind.get(kind, {}).get(id)
	if r == null:
		push_warning("Content: unknown %s id '%s'" % [kind, id])
	return r


static func _ensure_scanned() -> void:
	if _scanned:
		return
	_scanned = true
	for d in DEFAULT_DIRS:
		_scan(d)


static func _scan(dir: String) -> void:
	if _dirs.has(dir) or not DirAccess.dir_exists_absolute(dir):
		return
	_dirs[dir] = true
	for f in DirAccess.get_files_at(dir):
		if not f.ends_with(".tres"):
			continue
		var r := load(dir.path_join(f))
		if r == null or r.get_script() == null or not ("id" in r):
			continue
		var kind: String = r.get_script().get_global_name()
		if not _by_kind.has(kind):
			_by_kind[kind] = {}
		_by_kind[kind][r.id] = r
