class_name EquipCommand
extends Command
## Equip a weapon or ring from the unit's items. Does not end the turn.

var slot := 0


static func slot_of(p_unit_id: int, p_slot: int) -> EquipCommand:
	var c := EquipCommand.new()
	c.unit_id = p_unit_id
	c.slot = p_slot
	return c


func is_valid(s: BattleState) -> bool:
	var u := s.unit(unit_id)
	if slot < 0 or slot >= u.items.size() or slot == u.weapon_slot or slot == u.ring_slot:
		return false
	var it := u.items[slot]
	if it.kind == ItemData.Kind.RING:
		return true
	return it.kind == ItemData.Kind.WEAPON and it.weapon_type in u.class_data.weapon_types


func execute(s: BattleState, out: Array[BattleEvent]) -> void:
	var u := s.unit(unit_id)
	var it := u.items[slot]
	if it.kind == ItemData.Kind.WEAPON:
		u.weapon_slot = slot
	else:
		u.ring_slot = slot
	out.append(BattleEvent.make(BattleEvent.EQUIPPED, {"unit_id": unit_id, "item_id": it.id}))


func ends_turn() -> bool:
	return false


func type_name() -> String:
	return "Equip"


func to_dict() -> Dictionary:
	var d := super.to_dict()
	d.slot = slot
	return d
