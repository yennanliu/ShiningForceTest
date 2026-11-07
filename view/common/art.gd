class_name Art
## Loads art by content id (doc/05 §8). Returns null when a file is missing, so callers
## fall back to the old shapes / a name-only box. Files: tools/make_art.py (placeholders).

const UNITS := "res://assets/textures/units/%s.png"
const PORTRAITS := "res://assets/textures/portraits/%s.png"
const ICONS := "res://assets/textures/icons/head_%s.png"
const BATTLE := "res://assets/textures/battle/%s.png"

static var _cache: Dictionary = {}


## Portrait for a speaker id, in `mood` if that file exists, else neutral. Null if none.
static func portrait(id: StringName, mood := "") -> Texture2D:
	if id == &"":
		return null
	if mood != "" and mood != "neutral":
		var t := _load(PORTRAITS % ("%s_%s" % [id, mood]))
		if t != null:
			return t
	return _load(PORTRAITS % id)


## Map sprite sheet (9 frames x 4 directions of 48x64). Null if none.
static func sprite_sheet(id: StringName) -> Texture2D:
	return _load(UNITS % id)


## Cut-in battle poses (11 frames of 192x192, facing left). Null if none.
static func battle_sheet(id: StringName) -> Texture2D:
	return _load(BATTLE % id)


## Head icon bubble (poison, sleep, adv, bond) or the leader star. Null if none.
static func head_icon(name: String) -> Texture2D:
	return _load(ICONS % name)


static func _load(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]
