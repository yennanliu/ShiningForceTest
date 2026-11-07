class_name AutoPlay
## Lets the AI play turns, for either side. Used by tests, the battle sim, and
## (from step 6) the view for enemy turns.


## Plays the current actor's whole turn. Always ends the turn. Returns all events.
static func play_turn(s: BattleState) -> Array[BattleEvent]:
	var out: Array[BattleEvent] = []
	var u := s.current_actor()
	if u == null:
		return out
	for cmd in AiPlanner.choose(s, u):
		var ev := s.apply(cmd)
		out.append_array(ev)
		if BattleEvent.turn_over(ev):
			return out
	# Plan was invalid or did not end the turn (should not happen): end it safely.
	if s.outcome() == BattleState.Outcome.ONGOING:
		push_warning("AutoPlay: plan for unit %d did not end its turn" % u.id)
		out.append_array(s.apply(WaitCommand.by(u.id)))
	return out


## Plays until the battle ends or max_rounds pass. Returns the outcome.
static func play_to_end(s: BattleState, max_rounds := 200) -> BattleState.Outcome:
	var max_turns := max_rounds * maxi(1, s.units().size())
	for i in max_turns:
		if s.outcome() != BattleState.Outcome.ONGOING or s.round_number() > max_rounds:
			break
		play_turn(s)
	return s.outcome()
