class_name CastCommand
extends Command
## Cast a known spell at a tile. Heals affect allies, other spells hurt hostiles,
## within `area` tiles of the target. Ends the turn.

var spell_id: StringName
var level := 1
var at := Vector2i.ZERO


static func at_tile(p_unit_id: int, p_spell: StringName, p_level: int, p_at: Vector2i) -> CastCommand:
	var c := CastCommand.new()
	c.unit_id = p_unit_id
	c.spell_id = p_spell
	c.level = p_level
	c.at = p_at
	return c


func is_valid(s: BattleState) -> bool:
	var u := s.unit(unit_id)
	var spell := u.spell(spell_id)
	if spell == null or level < 1 or level > spell.levels.size() or not s.grid.in_bounds(at):
		return false
	var lv := spell.levels[level - 1]
	var d := Pathfinder.distance(u.pos, at)
	if u.mp < lv.mp_cost or d < lv.spell_range.x or d > lv.spell_range.y:
		return false
	return not Rules.spell_targets(s, u, spell, lv, at).is_empty()


func execute(s: BattleState, out: Array[BattleEvent]) -> void:
	var u := s.unit(unit_id)
	Rules.resolve_spell(s, u, u.spell(spell_id), level, at, out)


func type_name() -> String:
	return "Cast"


func to_dict() -> Dictionary:
	var d := super.to_dict()
	d.spell_id = String(spell_id)
	d.level = level
	d.at = [at.x, at.y]
	return d
