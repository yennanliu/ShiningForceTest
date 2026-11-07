class_name BattleEvent
extends RefCounted
## Something that happened in a battle. The core returns these from apply();
## the view plays them in order. Kept generic on purpose: a type + a data dict.

const ROUND_STARTED := &"round_started"   # {round}
const TURN_STARTED := &"turn_started"     # {unit_id}
const MOVED := &"moved"                   # {unit_id, path: Array[Vector2i]}
const ATTACKED := &"attacked"             # {attacker_id, target_id, hit, crit, counter, double, special}
const DAMAGED := &"damaged"               # {unit_id, amount, hp_after}
const HEALED := &"healed"                 # {unit_id, amount, hp_after}
const DIED := &"died"                     # {unit_id}
const XP_GAINED := &"xp_gained"           # {unit_id, amount, xp_after}
const LEVELED_UP := &"leveled_up"         # {unit_id, level, gains: {stat: n}}
const BOND_CHANGED := &"bond_changed"     # {a_id, b_id, tier}
const CAST := &"cast"                     # {unit_id, spell_id, level, at}
const SPAWNED := &"spawned"               # {unit_id, at}
const SAID := &"said"                     # {line_id}
const EQUIPPED := &"equipped"             # {unit_id, item_id}
const ITEM_USED := &"item_used"           # {unit_id, item_id, target_id}
const TURN_ENDED := &"turn_ended"         # {unit_id}
const BATTLE_ENDED := &"battle_ended"     # {outcome}

var type: StringName
var data: Dictionary


static func make(p_type: StringName, p_data: Dictionary = {}) -> BattleEvent:
	var e := BattleEvent.new()
	e.type = p_type
	e.data = p_data
	return e


## True if these events end the acting unit's turn (or the battle).
## Don't compare actors instead: the same unit can act twice in a row across a round change.
static func turn_over(events: Array[BattleEvent]) -> bool:
	for e in events:
		if e.type == TURN_ENDED or e.type == BATTLE_ENDED:
			return true
	return false


func to_dict() -> Dictionary:
	var d := {"type": String(type)}
	for k in data:
		d[k] = _plain(data[k])
	return d


func _to_string() -> String:
	return str(to_dict())


static func _plain(v: Variant) -> Variant:
	if v is Vector2i:
		return [v.x, v.y]
	if v is Array:
		return v.map(_plain)
	return v
