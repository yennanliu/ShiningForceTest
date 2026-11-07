class_name Unit
extends RefCounted
## A unit's runtime state in a battle or in the party roster.

const MAX_ITEMS := 4

var id := 0                     # unique within a battle
var data: UnitData
var faction: Enums.Faction = Enums.Faction.PLAYER
var class_data: ClassData
var level := 1
var xp := 0
var base: Stats                 # stats without equipment
var hp := 0
var mp := 0
var pos := Vector2i.ZERO
var items: Array[ItemData] = []
var weapon_slot := -1
var ring_slot := -1
var ai: Enums.AiProfile = Enums.AiProfile.AGGRESSIVE
var tag: StringName
var is_leader := false


static func from_data(d: UnitData, p_faction: Enums.Faction = Enums.Faction.PLAYER) -> Unit:
	var u := Unit.new()
	u.data = d
	u.faction = p_faction
	u.class_data = d.class_data
	u.level = d.base_level
	u.base = d.base_stats.copy()
	u.hp = u.base.hp
	u.mp = u.base.mp
	u.items = d.starting_items.duplicate()
	u.weapon_slot = u._first_slot(ItemData.Kind.WEAPON)
	u.ring_slot = u._first_slot(ItemData.Kind.RING)
	return u


func is_alive() -> bool:
	return hp > 0


## Base stats plus equipped weapon and ring bonuses.
func stats() -> Stats:
	var s := base.copy()
	var w := weapon()
	if w != null:
		s = s.plus(w.bonus)
	var r := ring()
	if r != null:
		s = s.plus(r.bonus)
	return s


func max_hp() -> int:
	return base.hp


func max_mp() -> int:
	return base.mp


func weapon() -> ItemData:
	return items[weapon_slot] if weapon_slot >= 0 and weapon_slot < items.size() else null


func ring() -> ItemData:
	return items[ring_slot] if ring_slot >= 0 and ring_slot < items.size() else null


func attack_range() -> Vector2i:
	var w := weapon()
	return w.attack_range if w != null else Vector2i(1, 1)


func move_type() -> Enums.MoveType:
	return class_data.move_type


func mov() -> int:
	return class_data.mov


func jump() -> int:
	return class_data.jump


func display_name() -> String:
	return data.display_name


func copy() -> Unit:
	return Unit.from_dict(to_dict())


func to_dict() -> Dictionary:
	return {
		"id": id,
		"data": String(data.id),
		"faction": faction,
		"class": String(class_data.id),
		"level": level,
		"xp": xp,
		"base": base.to_dict(),
		"hp": hp,
		"mp": mp,
		"pos": [pos.x, pos.y],
		"items": items.map(func(i: ItemData) -> String: return String(i.id)),
		"weapon_slot": weapon_slot,
		"ring_slot": ring_slot,
		"ai": ai,
		"tag": String(tag),
		"is_leader": is_leader,
	}


static func from_dict(d: Dictionary) -> Unit:
	var u := Unit.new()
	u.id = d.get("id", 0)
	u.data = Content.unit(StringName(d["data"]))
	u.faction = d.get("faction", Enums.Faction.PLAYER)
	u.class_data = Content.class_data(StringName(d["class"]))
	u.level = d.get("level", 1)
	u.xp = d.get("xp", 0)
	u.base = Stats.from_dict(d["base"])
	u.hp = d.get("hp", u.base.hp)
	u.mp = d.get("mp", u.base.mp)
	var p: Array = d.get("pos", [0, 0])
	u.pos = Vector2i(p[0], p[1])
	for item_id in d.get("items", []):
		var it := Content.item(StringName(item_id))
		if it != null:
			u.items.append(it)
	u.weapon_slot = d.get("weapon_slot", -1)
	u.ring_slot = d.get("ring_slot", -1)
	u.ai = d.get("ai", Enums.AiProfile.AGGRESSIVE)
	u.tag = StringName(d.get("tag", ""))
	u.is_leader = d.get("is_leader", false)
	return u


func _first_slot(kind: ItemData.Kind) -> int:
	for i in items.size():
		if items[i].kind == kind:
			return i
	return -1
