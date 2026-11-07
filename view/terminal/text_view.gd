class_name TextView
## Draws a battle as text and turns typed lines into Commands.
## No GPU, no window: works in any terminal, over SSH, and in Docker.

const TERRAIN_CHAR := {
	&"plain": ".", &"forest": "f", &"hill": "^", &"sand": ":",
	&"shallow": "~", &"deep": "w", &"wall": "#",
}
const HELP := """Commands (x y = column row, ID = unit id):
  m x y      move            a ID       attack
  i SLOT ID  use item        e SLOT     equip
  w          wait (end turn) f ID       forecast an attack
  u ID       unit details    r          redraw the map
  h          help            q          quit"""


## The whole screen for the current turn.
static func render(s: BattleState) -> String:
	var lines: PackedStringArray = []
	var actor := s.current_actor()
	lines.append("== Round %d ==  Turn: %s" % [s.round_number(), _label(actor) if actor else "-"])
	lines.append("")
	lines.append_array(_map_lines(s))
	lines.append("")
	lines.append("  .plain f forest ^hill #wall   UPPER = you, lower = enemy, + = can move, * = acting")
	lines.append("")
	lines.append_array(_unit_lines(s))
	return "\n".join(lines)


## One readable line per event (empty string = not worth showing).
static func describe(e: BattleEvent, s: BattleState) -> String:
	var d := e.data
	match e.type:
		BattleEvent.ROUND_STARTED:
			return "-- Round %d --" % d.round
		BattleEvent.TURN_STARTED:
			return ""
		BattleEvent.MOVED:
			var path: Array = d.path
			return "%s moves to %s" % [_name(s, d.unit_id), _xy(path[-1])]
		BattleEvent.ATTACKED:
			var verb := "counters" if d.counter else "attacks"
			var how := "misses" if not d.hit else ("CRITICAL hit" if d.crit else "hits")
			return "%s %s %s: %s" % [_name(s, d.attacker_id), verb, _name(s, d.target_id), how]
		BattleEvent.DAMAGED:
			return "  %s takes %d damage (HP %d)" % [_name(s, d.unit_id), d.amount, d.hp_after]
		BattleEvent.HEALED:
			return "  %s recovers %d HP (HP %d)" % [_name(s, d.unit_id), d.amount, d.hp_after]
		BattleEvent.DIED:
			return "  %s is defeated!" % _name(s, d.unit_id)
		BattleEvent.XP_GAINED:
			return "  %s gains %d XP" % [_name(s, d.unit_id), d.amount]
		BattleEvent.EQUIPPED:
			return "%s equips %s" % [_name(s, d.unit_id), d.item_id]
		BattleEvent.ITEM_USED:
			return "%s uses %s on %s" % [_name(s, d.unit_id), d.item_id, _name(s, d.target_id)]
		BattleEvent.TURN_ENDED:
			return ""
		BattleEvent.BATTLE_ENDED:
			return "*** VICTORY ***" if d.outcome == BattleState.Outcome.WON else "*** DEFEAT ***"
	return str(e.to_dict())


## A Command, or a String with an error / info message to show.
static func parse(line: String, s: BattleState) -> Variant:
	var w := line.strip_edges().to_lower().split(" ", false)
	var actor := s.current_actor()
	if w.is_empty():
		return render(s)
	match w[0]:
		"m", "move":
			if w.size() != 3 or not w[1].is_valid_int() or not w[2].is_valid_int():
				return "usage: m x y"
			return MoveCommand.to_tile(actor.id, Vector2i(int(w[1]), int(w[2])))
		"a", "attack":
			if w.size() != 2 or not w[1].is_valid_int():
				return "usage: a ID"
			return AttackCommand.on(actor.id, int(w[1]))
		"i", "item":
			if w.size() != 3 or not w[1].is_valid_int() or not w[2].is_valid_int():
				return "usage: i SLOT ID"
			return UseItemCommand.on(actor.id, int(w[1]), int(w[2]))
		"e", "equip":
			if w.size() != 2 or not w[1].is_valid_int():
				return "usage: e SLOT"
			return EquipCommand.slot_of(actor.id, int(w[1]))
		"w", "wait":
			return WaitCommand.by(actor.id)
		"f", "forecast":
			if w.size() != 2 or not w[1].is_valid_int() or s.unit(int(w[1])) == null:
				return "usage: f ID"
			var t := s.unit(int(w[1]))
			var fc := Rules.forecast(s, actor, t)
			return "Forecast vs %s: hit %d%%, damage %d-%d, crit %d%%, counter: %s" % [
				_label(t), roundi(fc.hit * 100), fc.dmg.x, fc.dmg.y, roundi(fc.crit * 100), "possible" if fc.counter else "no"]
		"u", "unit":
			if w.size() != 2 or not w[1].is_valid_int() or s.unit(int(w[1])) == null:
				return "usage: u ID"
			return _details(s.unit(int(w[1])))
		"r", "redraw":
			return render(s)
		"h", "help", "?":
			return HELP
	return "unknown command '%s' (h for help)" % w[0]


static func _map_lines(s: BattleState) -> PackedStringArray:
	var out: PackedStringArray = []
	var g := s.grid
	var actor := s.current_actor()
	var reach := {}
	if actor != null and actor.faction == Enums.Faction.PLAYER and not s.has_moved():
		reach = Pathfinder.reachable(g, actor)
	var header := "    "
	for x in g.size.x:
		header += "%-2d" % x
	out.append(header)
	for y in g.size.y:
		var row := "%2d  " % y
		for x in g.size.x:
			var t := Vector2i(x, y)
			var u := g.unit_at(t)
			var c: String
			if u != null:
				c = "*" if u == actor else _letter(u)
			elif reach.has(t):
				c = "+"
			else:
				c = TERRAIN_CHAR.get(g.terrain(t).id, "?")
			row += c + " "
		out.append(row)
	return out


static func _unit_lines(s: BattleState) -> PackedStringArray:
	var out: PackedStringArray = ["  ID  Unit                Side    HP     Pos     Weapon"]
	for u in s.units():
		if not u.is_alive():
			continue
		var side := "you" if u.faction == Enums.Faction.PLAYER else "enemy"
		var w := u.weapon()
		out.append("  %-3d %-19s %-7s %2d/%-3d %-7s %s" % [
			u.id, "%s (%s)" % [u.display_name(), _letter(u)], side, u.hp, u.max_hp(), _xy(u.pos), w.display_name if w else "-"])
	return out


static func _details(u: Unit) -> String:
	var st := u.stats()
	var items := PackedStringArray()
	for i in u.items.size():
		var mark := " (equipped)" if i == u.weapon_slot or i == u.ring_slot else ""
		items.append("%d:%s%s" % [i, u.items[i].display_name, mark])
	return "%s  Lv %d %s  HP %d/%d  ATK %d DEF %d AGI %d LUK %d  MOV %d  XP %d\n  items: %s" % [
		_label(u), u.level, u.class_data.display_name, u.hp, u.max_hp(), st.atk, st.def, st.agi, st.luk,
		u.mov(), u.xp, ", ".join(items) if not items.is_empty() else "-"]


## First letter of the last word: Goblin -> g, Goblin Archer -> a.
static func _letter(u: Unit) -> String:
	var words := u.display_name().split(" ", false)
	var c := words[-1].substr(0, 1)
	return c.to_upper() if u.faction == Enums.Faction.PLAYER else c.to_lower()


static func _label(u: Unit) -> String:
	return "%s #%d" % [u.display_name(), u.id]


static func _name(s: BattleState, id: int) -> String:
	var u := s.unit(id)
	return u.display_name() if u else "#%d" % id


static func _xy(v: Variant) -> String:
	if v is Vector2i:
		return "(%d,%d)" % [v.x, v.y]
	return "(%d,%d)" % [v[0], v[1]]
