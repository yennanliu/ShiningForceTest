class_name AiPlanner
## Simple rule-based logic for computer-controlled units (doc/02 §4.9).
##   0. FLEE units never attack; they move as far from hostiles as possible.
##   1. HOLD units never move; they attack only what is already in range.
##   2. If any hostile can be attacked this turn, attack the one with the lowest HP
##      (ties: the leader, then the lowest id). Prefer attacking without moving.
##   3. Otherwise move to the reachable tile closest to the nearest hostile.
##   4. Otherwise wait.
## No randomness, fixed order: the same state always gives the same plan.


static func choose(s: BattleState, u: Unit) -> Array[Command]:
	var plan: Array[Command] = []
	var can_move := u.ai != Enums.AiProfile.HOLD and not s.has_moved()
	var tiles: Array[Vector2i] = [u.pos]
	if can_move:
		tiles.append_array(_sorted(Pathfinder.reachable(s.grid, u).keys()))

	# FLEE units (e.g. villagers) never attack: they move as far from hostiles as they can.
	if u.ai == Enums.AiProfile.FLEE:
		if can_move:
			var far := u.pos
			for t in tiles:
				if _dist_to_nearest(s, u, t) > _dist_to_nearest(s, u, far):
					far = t
			if far != u.pos:
				plan.append(MoveCommand.to_tile(u.id, far))
		plan.append(WaitCommand.by(u.id))
		return plan

	# Rule 2: attack the weakest hostile we can reach.
	for target in _targets(s, u):
		for t in tiles:
			if _in_range(u, t, target):
				if t != u.pos:
					plan.append(MoveCommand.to_tile(u.id, t))
				plan.append(AttackCommand.on(u.id, target.id))
				return plan

	# Rule 3: walk toward the nearest hostile.
	if can_move:
		var t := _closest_tile(s, u, tiles)
		if t != u.pos:
			plan.append(MoveCommand.to_tile(u.id, t))

	# Rule 4.
	plan.append(WaitCommand.by(u.id))
	return plan


## Living hostiles, weakest first.
static func _targets(s: BattleState, u: Unit) -> Array[Unit]:
	var out := s.living().filter(func(o: Unit) -> bool: return o.faction != u.faction)
	out.sort_custom(func(a: Unit, b: Unit) -> bool:
		if a.hp != b.hp:
			return a.hp < b.hp
		if a.is_leader != b.is_leader:
			return a.is_leader
		return a.id < b.id)
	return out


static func _in_range(u: Unit, from: Vector2i, target: Unit) -> bool:
	var d := Pathfinder.distance(from, target.pos)
	var r := u.attack_range()
	return d >= r.x and d <= r.y


static func _closest_tile(s: BattleState, u: Unit, tiles: Array[Vector2i]) -> Vector2i:
	var best := u.pos
	var best_d := _dist_to_nearest(s, u, u.pos)
	for t in tiles:
		var d := _dist_to_nearest(s, u, t)
		if d < best_d:
			best_d = d
			best = t
	return best


static func _dist_to_nearest(s: BattleState, u: Unit, from: Vector2i) -> int:
	var best := 1 << 30
	for o in s.living():
		if o.faction != u.faction:
			best = mini(best, Pathfinder.distance(from, o.pos))
	return best


static func _sorted(tiles: Array) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(tiles)
	out.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.y < b.y or (a.y == b.y and a.x < b.x))
	return out
