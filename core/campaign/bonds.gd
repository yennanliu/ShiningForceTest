class_name Bonds
extends RefCounted
## Bond points between pairs of player units (doc/02 §4.7, simplified).
## Earned when an ally stands next to a unit that lands a hit. Higher tiers give
## small combat bonuses to the attacker. A unit that falls loses a tier with everyone.

const TIERS: Array[int] = [0, 40, 120, 260, 500]   # tier 0..4 thresholds (tune)
const ASSIST_POINTS := 4                           # (tune)

var points: Dictionary = {}   # "a|b" (sorted ids) -> int


static func key(a: StringName, b: StringName) -> String:
	return "%s|%s" % [a, b] if String(a) < String(b) else "%s|%s" % [b, a]


func get_points(a: StringName, b: StringName) -> int:
	return points.get(key(a, b), 0)


func tier(a: StringName, b: StringName) -> int:
	return tier_for(get_points(a, b))


static func tier_for(p: int) -> int:
	var t := 0
	for i in TIERS.size():
		if p >= TIERS[i]:
			t = i
	return t


## Adds points; returns the new tier.
func add(a: StringName, b: StringName, pts: int) -> int:
	var k := key(a, b)
	points[k] = points.get(k, 0) + pts
	return tier_for(points[k])


## Highest tier between `u` and any living ally next to it (players only).
func best_adjacent_tier(s: BattleState, u: Unit) -> int:
	if u.faction != Enums.Faction.PLAYER:
		return 0
	var best := 0
	for n in s.grid.neighbors(u.pos):
		var o := s.grid.unit_at(n)
		if o != null and o != u and o.is_alive() and o.faction == u.faction:
			best = maxi(best, tier(u.data.id, o.data.id))
	return best


## A fallen unit drops one tier with every partner (points fall to that tier's threshold).
func drop_tier_on_death(id: StringName) -> void:
	for k: String in points.keys():
		if id in k.split("|"):
			var t := tier_for(points[k])
			if t > 0:
				points[k] = TIERS[t - 1]


func copy() -> Bonds:
	var b := Bonds.new()
	b.points = points.duplicate()
	return b


func to_dict() -> Dictionary:
	return points.duplicate()


static func from_dict(d: Dictionary) -> Bonds:
	var b := Bonds.new()
	for k in d:
		b.points[k] = int(d[k])
	return b
