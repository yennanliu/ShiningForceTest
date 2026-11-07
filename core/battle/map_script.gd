class_name MapScript
## Runs a map's triggers (doc/02 §4.8). Called by BattleState after every command
## and at the start of every round, so triggers are deterministic and replayable.
## A trigger fires once; with `repeat` it may fire again, at most once per round.


static func run(s: BattleState, out: Array[BattleEvent]) -> void:
	for i in s.map.triggers.size():
		var t := s.map.triggers[i]
		var last: int = s.fired.get(i, -1)
		if last >= 0 and (not t.repeat or last == s.round_number()):
			continue
		if _met(s, t):
			s.fired[i] = s.round_number()
			for a in t.actions:
				_do(s, t, a, out)


## Tiles of chests (GIVE-on-enter triggers) that can still be opened, for the views.
static func open_chests(s: BattleState) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for i in s.map.triggers.size():
		var t := s.map.triggers[i]
		if t.when != TriggerData.When.UNIT_ENTERS or s.fired.has(i):
			continue
		if t.unless_flag != &"" and s.flags.get(t.unless_flag, false):
			continue
		for a in t.actions:
			if a.kind == TriggerAction.Kind.GIVE:
				out.append(t.area.position)
	return out


static func _met(s: BattleState, t: TriggerData) -> bool:
	if t.unless_flag != &"" and s.flags.get(t.unless_flag, false):
		return false
	match t.when:
		TriggerData.When.ROUND_START:
			return s.round_number() >= t.on_round
		TriggerData.When.UNIT_ENTERS:
			for u in s.living(Enums.Faction.PLAYER):
				if t.area.has_point(u.pos) and (t.tag == &"" or u.tag == t.tag or u.data.id == t.tag):
					return true
		TriggerData.When.UNIT_DIES:
			for u in s.units():
				if u.tag == t.tag and not u.is_alive():
					return true
		TriggerData.When.HP_BELOW:
			for u in s.units():
				if u.tag == t.tag and u.is_alive() and u.hp * 100 < u.max_hp() * t.hp_percent:
					return true
	return false


## The player unit inside the trigger's area (for GIVE), else the first living player unit.
static func _who(s: BattleState, t: TriggerData) -> Unit:
	var players := s.living(Enums.Faction.PLAYER)
	for u in players:
		if t.when == TriggerData.When.UNIT_ENTERS and t.area.has_point(u.pos):
			return u
	return players[0] if not players.is_empty() else null


static func _do(s: BattleState, t: TriggerData, a: TriggerAction, out: Array[BattleEvent]) -> void:
	match a.kind:
		TriggerAction.Kind.SPAWN:
			if a.spawn != null and s.grid.unit_at(a.spawn.at) == null:
				var u := s.spawn_enemy(a.spawn)
				out.append(BattleEvent.make(BattleEvent.SPAWNED, {"unit_id": u.id, "at": u.pos}))
		TriggerAction.Kind.SAY:
			out.append(BattleEvent.make(BattleEvent.SAID, {"line_id": a.key}))
		TriggerAction.Kind.SET_FLAG:
			s.flags[a.key] = a.value
		TriggerAction.Kind.WIN:
			s.forced_outcome = BattleState.Outcome.WON
		TriggerAction.Kind.LOSE:
			s.forced_outcome = BattleState.Outcome.LOST
		TriggerAction.Kind.GIVE:
			var u := _who(s, t)
			if u != null and a.item != null:
				if u.items.size() < Unit.MAX_ITEMS:
					u.items.append(a.item)
				else:
					s.flags[&"overflow_" + String(a.item.id)] = true
				out.append(BattleEvent.make(BattleEvent.ITEM_FOUND, {"unit_id": u.id, "item_id": a.item.id}))
		TriggerAction.Kind.SET_AI:
			for u in s.living():
				if u.tag == a.key:
					u.ai = a.ai
		_:
			push_warning("MapScript: action %s not supported yet" % a.kind)
