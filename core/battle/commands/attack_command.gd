class_name AttackCommand
extends Command
## Attack a hostile unit within weapon range. Ends the turn.

var target_id := 0


static func on(p_unit_id: int, p_target_id: int) -> AttackCommand:
	var c := AttackCommand.new()
	c.unit_id = p_unit_id
	c.target_id = p_target_id
	return c


func is_valid(s: BattleState) -> bool:
	var a := s.unit(unit_id)
	var t := s.unit(target_id)
	if t == null or not t.is_alive() or t.faction == a.faction:
		return false
	var d := Pathfinder.distance(a.pos, t.pos)
	var r := a.attack_range()
	return d >= r.x and d <= r.y


func execute(s: BattleState, out: Array[BattleEvent]) -> void:
	Rules.resolve_attack(s, s.unit(unit_id), s.unit(target_id), out)


func type_name() -> String:
	return "Attack"


func to_dict() -> Dictionary:
	var d := super.to_dict()
	d.target_id = target_id
	return d
