class_name TurnQueue
extends RefCounted
## Who acts next. Each round every living unit rolls initiative = AGI x 0.875..1.125.
## Highest goes first; ties go to the player side, then the lower id.

var round_number := 0
var _order: Array[Unit] = []


func start_round(units: Array[Unit], rng: Rng) -> void:
	round_number += 1
	var rolled: Array = []
	var by_id := units.duplicate()
	by_id.sort_custom(func(a: Unit, b: Unit) -> bool: return a.id < b.id)
	for u: Unit in by_id:
		if u.is_alive():
			rolled.append([u, u.stats().agi * rng.between(0.875, 1.125)])
	rolled.sort_custom(_before)
	_order.clear()
	for r in rolled:
		_order.append(r[0])


## Next living unit this round, or null when the round is over.
func next() -> Unit:
	while not _order.is_empty():
		var u: Unit = _order.pop_front()
		if u.is_alive():
			return u
	return null


## Upcoming living units this round (for the turn bar).
func peek(n: int) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in _order:
		if u.is_alive():
			out.append(u)
			if out.size() == n:
				break
	return out


static func _before(a: Array, b: Array) -> bool:
	if not is_equal_approx(a[1], b[1]):
		return a[1] > b[1]
	var ua: Unit = a[0]
	var ub: Unit = b[0]
	if ua.faction != ub.faction:
		return ua.faction == Enums.Faction.PLAYER
	return ua.id < ub.id
