class_name MoveCommand
extends Command
## Move the acting unit to a reachable tile. Once per turn; does not end the turn.

var to := Vector2i.ZERO


static func to_tile(p_unit_id: int, p_to: Vector2i) -> MoveCommand:
	var c := MoveCommand.new()
	c.unit_id = p_unit_id
	c.to = p_to
	return c


func is_valid(s: BattleState) -> bool:
	var u := s.unit(unit_id)
	if s.has_moved() or to == u.pos:
		return false
	return Pathfinder.reachable(s.grid, u).has(to)


func execute(s: BattleState, out: Array[BattleEvent]) -> void:
	var u := s.unit(unit_id)
	var path := Pathfinder.path_to(s.grid, u, to)
	s.grid.move(u, to)
	s.mark_moved()
	out.append(BattleEvent.make(BattleEvent.MOVED, {"unit_id": unit_id, "path": path}))


func ends_turn() -> bool:
	return false


func type_name() -> String:
	return "Move"


func to_dict() -> Dictionary:
	var d := super.to_dict()
	d.to = [to.x, to.y]
	return d
