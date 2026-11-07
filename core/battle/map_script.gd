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
				_do(s, a, out)


static func _met(s: BattleState, t: TriggerData) -> bool:
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


static func _do(s: BattleState, a: TriggerAction, out: Array[BattleEvent]) -> void:
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
		_:
			push_warning("MapScript: action %s not supported yet" % a.kind)
