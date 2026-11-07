class_name Dialogue
## Dialogue lines by id, loaded from JSON files: {"line_id": {"speaker": "...", "text": "..."}}.
## Scans res://data/dialogue/; tests and the demo add res://tests/fixtures/dialogue_demo.json.

const DEFAULT_DIR := "res://data/dialogue/"

static var _lines: Dictionary = {}
static var _loaded: Dictionary = {}


static func register_file(path: String) -> void:
	if _loaded.has(path):
		return
	_loaded[path] = true
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK or not (json.data is Dictionary):
		push_warning("Dialogue: can't read %s" % path)
		return
	for k in json.data:
		_lines[StringName(k)] = json.data[k]


static func has(id: StringName) -> bool:
	_ensure()
	return _lines.has(id)


## {speaker, text}; a placeholder if the id is unknown.
static func line(id: StringName) -> Dictionary:
	_ensure()
	return _lines.get(id, {"speaker": "?", "text": "[missing line %s]" % id})


static func _ensure() -> void:
	if _loaded.has(DEFAULT_DIR):
		return
	_loaded[DEFAULT_DIR] = true
	if DirAccess.dir_exists_absolute(DEFAULT_DIR):
		for f in DirAccess.get_files_at(DEFAULT_DIR):
			if f.ends_with(".json"):
				register_file(DEFAULT_DIR.path_join(f))
