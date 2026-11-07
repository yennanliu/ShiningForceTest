class_name AiPlanner
## Picks a plan for a unit: [Move?, Attack] or [Move?, Wait] (doc/02 §4.9).
## Simple utility AI. Deterministic: no RNG, fixed iteration order, strict ">" for ties.
## Works for either side, so AI-vs-AI battles can run in tests.

const W_DAMAGE := 1.0
const W_KILL := 30.0
const W_LEADER := 8.0
const W_LAND := 10.0
const GUARD_RADIUS := 6


static func choose(s: BattleState, u: Unit) -> Array[Command]:
	var plan: Array[Command] = []
	var stay := u.ai == Enums.AiProfile.HOLD or (u.ai == Enums.AiProfile.GUARD and not _enemy_near(s, u))
	var tiles: Array[Vector2i] = [u.pos]
	if not stay and not s.has_moved():
		tiles = _sorted(Pathfinder.reachable(s.grid, u).keys())

	var best_score := -INF
	var best_tile := u.pos
	var best_target: Unit = null
	for t in tiles:
		for target in _hostiles(s, u):
			if not _in_range(u, t, target):
				continue
			var sc := score_attack(s, u, t, target)
			if sc > best_score:
				best_score = sc
				best_tile = t
				best_target = target

	if best_target == null and not stay and not s.has_moved():
		best_tile = _approach_tile(s, u, tiles)

	if best_tile != u.pos:
		plan.append(MoveCommand.to_tile(u.id, best_tile))
	if best_target != null:
		plan.append(AttackCommand.on(u.id, best_target.id))
	else:
		plan.append(WaitCommand.by(u.id))
	return plan


## Value of attacking `target` from tile `from`.
static func score_attack(s: BattleState, u: Unit, from: Vector2i, target: Unit) -> float:
	var fc := Rules.forecast(s, u, target)
	var dmg: Vector2i = fc.dmg
	var hit: float = fc.hit
	var avg: float = (dmg.x + dmg.y) / 2.0
	var kill := 0.0
	if dmg.x >= target.hp:
		kill = hit
	elif dmg.y >= target.hp:
		kill = hit * 0.5
	var sc: float = W_DAMAGE * hit * minf(avg, target.hp) + W_KILL * kill + W_LAND * s.grid.land_effect(from)
	if target.is_leader:
		sc += W_LEADER * (3.0 if u.ai == Enums.AiProfile.HUNT_LEADER else 1.0)
	return sc


static func _hostiles(s: BattleState, u: Unit) -> Array[Unit]:
	return s.living().filter(func(o: Unit) -> bool: return o.faction != u.faction)


static func _in_range(u: Unit, from: Vector2i, target: Unit) -> bool:
	var d := Pathfinder.distance(from, target.pos)
	var r := u.attack_range()
	return d >= r.x and d <= r.y


static func _enemy_near(s: BattleState, u: Unit) -> bool:
	for o in _hostiles(s, u):
		if Pathfinder.distance(u.pos, o.pos) <= GUARD_RADIUS:
			return true
	return false


## The reachable tile closest (by real move cost) to attacking range of any hostile.
static func _approach_tile(s: BattleState, u: Unit, tiles: Array[Vector2i]) -> Vector2i:
	var field := _distance_field(s, u)
	var best := u.pos
	var best_d: int = field.get(u.pos, 1 << 30)
	for t in tiles:
		var d: int = field.get(t, 1 << 30)
		if d < best_d:
			best_d = d
			best = t
	return best


## Move cost from each tile to the nearest tile adjacent to a hostile
## (multi-source Dijkstra using the unit's terrain costs; other units ignored).
static func _distance_field(s: BattleState, u: Unit) -> Dictionary:
	var g := s.grid
	var mt := u.move_type()
	var dist := {}
	var buckets: Array = [[]]
	for o in _hostiles(s, u):
		for n in g.neighbors(o.pos):
			if g.move_cost(n, mt) >= 0 and not dist.has(n):
				dist[n] = 0
				buckets[0].append(n)
	var c := 0
	while c < buckets.size():
		for t: Vector2i in buckets[c]:
			if dist[t] != c:
				continue
			var step_here := g.move_cost(t, mt)
			for n in g.neighbors(t):
				if g.move_cost(n, mt) < 0 or absi(g.height(n) - g.height(t)) > u.jump():
					continue
				var nc := c + step_here
				if nc >= dist.get(n, 1 << 30):
					continue
				dist[n] = nc
				while buckets.size() <= nc:
					buckets.append([])
				buckets[nc].append(n)
		c += 1
	return dist


static func _sorted(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(tiles)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out
