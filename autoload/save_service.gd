extends Node
## Reads, writes and migrates save files (doc/02 §4.12, §8.2).
## Writes are atomic: temp file + rename, so a crash never leaves a half-written save.

const CURRENT_VERSION := 1
const SLOTS: Array[String] = ["slot_1", "slot_2", "slot_3", "auto"]

var dir := "user://saves/"
## Test hook: stop after writing the temp file, as if the game crashed mid-save.
var crash_before_rename := false


func save_slot(slot: String, c: Campaign) -> Error:
	DirAccess.make_dir_recursive_absolute(dir)
	var data := c.to_dict()
	data["version"] = CURRENT_VERSION
	data["saved_at"] = Time.get_datetime_string_from_system(true)
	var path := _path(slot)
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_string(JSON.stringify(data, "  "))
	f.close()
	if crash_before_rename:
		return ERR_CANT_CREATE
	return DirAccess.rename_absolute(tmp, path)


## Null if missing, damaged, or from a newer version of the game.
func load_slot(slot: String) -> Campaign:
	var d := _read(slot)
	if d.is_empty() or int(d.get("version", 0)) > CURRENT_VERSION:
		return null
	return Campaign.from_dict(migrate(d))


## {slot, exists, damaged, chapter_title, play_seconds, saved_at}
func slot_info(slot: String) -> Dictionary:
	var info := {"slot": slot, "exists": FileAccess.file_exists(_path(slot)), "damaged": false}
	if not info.exists:
		return info
	var d := _read(slot)
	if d.is_empty() or int(d.get("version", 0)) > CURRENT_VERSION:
		info.damaged = true
		return info
	info.chapter_title = d.get("chapter_title", "?")
	info.play_seconds = int(d.get("play_seconds", 0))
	info.saved_at = d.get("saved_at", "")
	return info


func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in SLOTS:
		out.append(slot_info(s))
	return out


func delete_slot(slot: String) -> void:
	DirAccess.remove_absolute(_path(slot))


func has_any_save() -> bool:
	for s in SLOTS:
		var i := slot_info(s)
		if i.exists and not i.damaged:
			return true
	return false


## Upgrades an old save dict step by step to CURRENT_VERSION.
static func migrate(d: Dictionary) -> Dictionary:
	var v := int(d.get("version", 0))
	while v < CURRENT_VERSION:
		match v:
			0:  # v0 kept gold at the top level as "money"
				var inv: Dictionary = d.get("inventory", {})
				inv["gold"] = d.get("money", 0)
				d["inventory"] = inv
				d.erase("money")
		v += 1
		d["version"] = v
	return d


func _read(slot: String) -> Dictionary:
	var f := FileAccess.open(_path(slot), FileAccess.READ)
	if f == null:
		return {}
	var json := JSON.new()
	if json.parse(f.get_as_text()) != OK:
		return {}
	return json.data if json.data is Dictionary else {}


func _path(slot: String) -> String:
	return dir.path_join(slot + ".json")
