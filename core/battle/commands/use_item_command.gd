class_name UseItemCommand
extends Command
## Use a consumable on yourself or an adjacent ally. Ends the turn.

var slot := 0
var target_id := 0


static func on(p_unit_id: int, p_slot: int, p_target_id: int) -> UseItemCommand:
	var c := UseItemCommand.new()
	c.unit_id = p_unit_id
	c.slot = p_slot
	c.target_id = p_target_id
	return c


func is_valid(s: BattleState) -> bool:
	var u := s.unit(unit_id)
	var t := s.unit(target_id)
	if slot < 0 or slot >= u.items.size() or u.items[slot].kind != ItemData.Kind.CONSUMABLE:
		return false
	if t == null or not t.is_alive() or t.faction != u.faction:
		return false
	return Pathfinder.distance(u.pos, t.pos) <= 1


func execute(s: BattleState, out: Array[BattleEvent]) -> void:
	var u := s.unit(unit_id)
	var t := s.unit(target_id)
	var it := u.items[slot]
	u.remove_item(slot)
	out.append(BattleEvent.make(BattleEvent.ITEM_USED, {"unit_id": unit_id, "item_id": it.id, "target_id": target_id}))
	if it.heal_amount > 0:
		Rules.heal(t, it.heal_amount, out)
	if it.cures_poison:
		Rules.end_status(t, Unit.POISON, out)


func type_name() -> String:
	return "UseItem"


func to_dict() -> Dictionary:
	var d := super.to_dict()
	d.slot = slot
	d.target_id = target_id
	return d
