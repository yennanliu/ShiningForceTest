class_name Command
extends RefCounted
## A player or AI decision. BattleState.apply() checks is_valid(), then execute().
## Subclasses live next to this file.

var unit_id := 0


## Pure check against the current state. Must not change anything.
func is_valid(_s: BattleState) -> bool:
	return false


## Changes the state and appends events to `out`.
func execute(_s: BattleState, _out: Array[BattleEvent]) -> void:
	pass


## Move and Equip do not end the turn; everything else does.
func ends_turn() -> bool:
	return true


func type_name() -> String:
	return "Command"


func to_dict() -> Dictionary:
	return {"type": type_name(), "unit_id": unit_id}


static func from_dict(d: Dictionary) -> Command:
	var c: Command
	match d.get("type", ""):
		"Move":
			c = MoveCommand.to_tile(0, Vector2i(d.to[0], d.to[1]))
		"Attack":
			c = AttackCommand.on(0, d.target_id)
		"Equip":
			c = EquipCommand.slot_of(0, d.slot)
		"UseItem":
			c = UseItemCommand.on(0, d.slot, d.target_id)
		"Wait":
			c = WaitCommand.new()
		_:
			push_warning("Command.from_dict: unknown type %s" % d.get("type"))
			return null
	c.unit_id = d.unit_id
	return c


func _to_string() -> String:
	return str(to_dict())
