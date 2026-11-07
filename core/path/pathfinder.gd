class_name Pathfinder
## Movement and attack ranges on a Grid.
## Rules (doc/02 §4.3): Dijkstra over terrain move cost, limited by MOV;
## a step may climb or drop at most `jump` height; allies can be passed but not
## stopped on; enemies block.


## Tiles the unit can end its move on -> total move cost. Includes its own tile (cost 0).
static func reachable(g: Grid, u: Unit) -> Dictionary:
	var best: Dictionary = _search(g, u)[0]
	var out := {}
	for t in best:
		var occ := g.unit_at(t)
		if occ == null or occ == u or not occ.is_alive():
			out[t] = best[t]
	return out


## Path from the unit's tile to `to`, both included. Empty if `to` can't be reached.
static func path_to(g: Grid, u: Unit, to: Vector2i) -> Array[Vector2i]:
	var res := _search(g, u)
	var best: Dictionary = res[0]
	var came: Dictionary = res[1]
	var path: Array[Vector2i] = []
	if not best.has(to):
		return path
	var occ := g.unit_at(to)
	if occ != null and occ != u and occ.is_alive():
		return path
	var t := to
	path.append(t)
	while t != u.pos:
		t = came[t]
		path.push_front(t)
	return path


## Tiles at Manhattan distance reach.x..reach.y from `from` (inside the map).
static func attack_tiles(g: Grid, from: Vector2i, reach: Vector2i) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for dy in range(-reach.y, reach.y + 1):
		for dx in range(-reach.y, reach.y + 1):
			var d := absi(dx) + absi(dy)
			var t := from + Vector2i(dx, dy)
			if d >= reach.x and d <= reach.y and g.in_bounds(t):
				out.append(t)
	return out


static func distance(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


## Bucket-queue Dijkstra (move costs are small ints). Returns [best_cost, came_from].
static func _search(g: Grid, u: Unit) -> Array:
	var mov := u.mov()
	var mt := u.move_type()
	var jump := u.jump()
	var best := {u.pos: 0}
	var came := {}
	var buckets: Array = [[u.pos]]
	var c := 0
	while c < buckets.size():
		for t: Vector2i in buckets[c]:
			if best[t] != c:
				continue
			for n in g.neighbors(t):
				var step := g.move_cost(n, mt)
				if step < 0 or absi(g.height(n) - g.height(t)) > jump:
					continue
				var occ := g.unit_at(n)
				if occ != null and occ.is_alive() and occ.faction != u.faction:
					continue
				var nc := c + step
				if nc > mov or nc >= best.get(n, 1 << 30):
					continue
				best[n] = nc
				came[n] = t
				while buckets.size() <= nc:
					buckets.append([])
				buckets[nc].append(n)
		c += 1
	return [best, came]
