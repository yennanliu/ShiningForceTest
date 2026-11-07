class_name TerminalGame
extends RefCounted
## The text-mode game loop: you type commands for your units; the enemy plays itself.
## Input and output are injected, so tests can drive it with scripted lines.

var state: BattleState
var _read: Callable    # () -> String   (one line; "" at end of input)
var _write: Callable   # (String) -> void


func _init(p_state: BattleState, read: Callable, write: Callable) -> void:
	state = p_state
	_read = read
	_write = write


## Runs until the battle ends or the player quits. Returns the outcome.
func run() -> BattleState.Outcome:
	_write.call("Welcome to Banner (text mode). Type h for help.\n")
	_show(state.start())
	var empty_reads := 0
	while state.outcome() == BattleState.Outcome.ONGOING:
		var actor := state.current_actor()
		if actor.faction != Enums.Faction.PLAYER:
			_show(AutoPlay.play_turn(state))
			continue
		_write.call("\n" + TextView.render(state))
		var acted := false
		while not acted:
			_write.call("%s> " % actor.display_name())
			var line: String = _read.call()
			if line.strip_edges() == "":
				empty_reads += 1
				if empty_reads > 20:   # input closed
					return state.outcome()
				continue
			empty_reads = 0
			var w := line.strip_edges().to_lower()
			if w == "q" or w == "quit":
				_write.call("Bye.")
				return state.outcome()
			var result: Variant = TextView.parse(line, state)
			if result is String:
				_write.call(result)
				continue
			var events := state.apply(result)
			if events.is_empty():
				_write.call("Can't do that. (h for help)")
				continue
			_show(events)
			acted = BattleEvent.turn_over(events)
			if not acted:
				_write.call("\n" + TextView.render(state))
	return state.outcome()


func _show(events: Array[BattleEvent]) -> void:
	for e in events:
		var text := TextView.describe(e, state)
		if text != "":
			_write.call(text)
