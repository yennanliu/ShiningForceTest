class_name Stats
extends Resource
## A bundle of the six unit stats. Also used for item bonuses and class growth.

@export var hp := 0
@export var mp := 0
@export var atk := 0
@export var def := 0
@export var agi := 0
@export var luk := 0


static func make(p_hp: int, p_mp: int, p_atk: int, p_def: int, p_agi: int, p_luk: int) -> Stats:
	var s := Stats.new()
	s.hp = p_hp
	s.mp = p_mp
	s.atk = p_atk
	s.def = p_def
	s.agi = p_agi
	s.luk = p_luk
	return s


func plus(o: Stats) -> Stats:
	if o == null:
		return copy()
	return Stats.make(hp + o.hp, mp + o.mp, atk + o.atk, def + o.def, agi + o.agi, luk + o.luk)


func copy() -> Stats:
	return Stats.make(hp, mp, atk, def, agi, luk)


func to_dict() -> Dictionary:
	return {"hp": hp, "mp": mp, "atk": atk, "def": def, "agi": agi, "luk": luk}


static func from_dict(d: Dictionary) -> Stats:
	return Stats.make(d.get("hp", 0), d.get("mp", 0), d.get("atk", 0), d.get("def", 0), d.get("agi", 0), d.get("luk", 0))
