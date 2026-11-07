class_name Golden
## Golden replays: a recorded battle (seed + commands) and its expected final state.
## Regenerate on purpose after a rules change:
##   godot --headless --path . -s res://tools/make_golden.gd

const DIR := "res://tests/golden/"
const CASES := [7, 21, 99]   # fixture-map seeds


static func path(seed: int) -> String:
	return DIR + "fixture_seed%d.json" % seed


## AI vs AI on the fixture map.
static func record(seed: int) -> Dictionary:
	var b := BattleState.new(Fixtures.map(), Fixtures.party(), seed)
	b.start()
	AutoPlay.play_to_end(b)
	return {
		"map": "fixture_8x8",
		"seed": seed,
		"commands": b.history.map(func(c: Command) -> Dictionary: return c.to_dict()),
		"final": b.snapshot(),
	}


## JSON-normalized text, so ints vs floats and key order never matter.
static func normalize(v: Variant) -> String:
	return JSON.stringify(JSON.parse_string(JSON.stringify(v)), "", true)
