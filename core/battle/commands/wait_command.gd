class_name WaitCommand
extends Command
## End the turn without acting.


static func by(p_unit_id: int) -> WaitCommand:
	var c := WaitCommand.new()
	c.unit_id = p_unit_id
	return c


func is_valid(_s: BattleState) -> bool:
	return true


func type_name() -> String:
	return "Wait"
