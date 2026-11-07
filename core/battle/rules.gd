class_name Rules
## Battle formulas (doc/02 §4.4, §4.6). Values marked (tune) are starting points.

const BASE_HIT := 90.0
const MIN_HIT := 10.0
const MAX_HIT := 99.0
const CRIT_CHANCE := 0.04         # (tune)
const CRIT_MULT := 1.5
const COUNTER_CHANCE := 0.08      # (tune)
const DAMAGE_JITTER := 0.1        # damage x 0.9..1.1
const XP_HIT := 10                # (tune)
const XP_KILL := 48               # (tune)


## Chance to hit, 0..1.
static func hit_chance(_s: BattleState, a: Unit, t: Unit) -> float:
	var pct := BASE_HIT + a.stats().luk - t.stats().agi / 2.0
	return clampf(pct, MIN_HIT, MAX_HIT) / 100.0


## Damage before randomness and crits.
static func raw_damage(s: BattleState, a: Unit, t: Unit) -> float:
	var land := s.grid.land_effect(t.pos)
	return a.stats().atk - t.stats().def * (1.0 + land)


## Possible damage on a normal (non-crit) hit: (min, max).
static func damage_range(s: BattleState, a: Unit, t: Unit) -> Vector2i:
	var raw := raw_damage(s, a, t)
	return Vector2i(_dmg(raw * (1.0 - DAMAGE_JITTER)), _dmg(raw * (1.0 + DAMAGE_JITTER)))


static func can_counter(t: Unit, a: Unit) -> bool:
	if not t.is_alive():
		return false
	var d := Pathfinder.distance(a.pos, t.pos)
	var r := t.attack_range()
	return d >= r.x and d <= r.y


## Preview for the HUD. Never touches the RNG.
static func forecast(s: BattleState, a: Unit, t: Unit) -> Dictionary:
	return {
		"hit": hit_chance(s, a, t),
		"dmg": damage_range(s, a, t),
		"crit": CRIT_CHANCE,
		"counter": can_counter(t, a),
	}


## Attack + possible counter. Appends events.
static func resolve_attack(s: BattleState, a: Unit, t: Unit, out: Array[BattleEvent]) -> void:
	_strike(s, a, t, false, out)
	if a.is_alive() and can_counter(t, a) and s.rng.chance(COUNTER_CHANCE):
		_strike(s, t, a, true, out)


static func heal(t: Unit, amount: int, out: Array[BattleEvent]) -> void:
	var gained := mini(amount, t.max_hp() - t.hp)
	t.hp += gained
	out.append(BattleEvent.make(BattleEvent.HEALED, {"unit_id": t.id, "amount": gained, "hp_after": t.hp}))


static func xp_for(actor: Unit, target: Unit, killed: bool) -> int:
	var base := XP_KILL if killed else XP_HIT
	return clampi(roundi(base * (1.0 + (target.level - actor.level) * 0.15)), 1, 49)


## WON / LOST / ONGOING for the current state.
static func check_outcome(s: BattleState) -> BattleState.Outcome:
	var players := s.living(Enums.Faction.PLAYER)
	if players.is_empty():
		return BattleState.Outcome.LOST
	for u in s.units():
		if u.faction == Enums.Faction.PLAYER and u.is_leader and not u.is_alive():
			return BattleState.Outcome.LOST
	match s.map.objective:
		Enums.Objective.DEFEAT_BOSS:
			for u in s.units():
				if u.tag == s.map.objective_tag and not u.is_alive():
					return BattleState.Outcome.WON
		_:
			if s.living(Enums.Faction.ENEMY).is_empty():
				return BattleState.Outcome.WON
	return BattleState.Outcome.ONGOING


static func _strike(s: BattleState, a: Unit, t: Unit, counter: bool, out: Array[BattleEvent]) -> void:
	var hit := s.rng.chance(hit_chance(s, a, t))
	var crit := hit and s.rng.chance(CRIT_CHANCE)
	out.append(BattleEvent.make(BattleEvent.ATTACKED, {
		"attacker_id": a.id, "target_id": t.id, "hit": hit, "crit": crit, "counter": counter,
	}))
	if not hit:
		return
	var mult := s.rng.between(1.0 - DAMAGE_JITTER, 1.0 + DAMAGE_JITTER) * (CRIT_MULT if crit else 1.0)
	var dmg := _dmg(raw_damage(s, a, t) * mult)
	t.hp = maxi(0, t.hp - dmg)
	out.append(BattleEvent.make(BattleEvent.DAMAGED, {"unit_id": t.id, "amount": dmg, "hp_after": t.hp}))
	var killed := not t.is_alive()
	if killed:
		s.on_unit_died(t, out)
	if a.faction == Enums.Faction.PLAYER:
		var xp := xp_for(a, t, killed)
		a.xp += xp
		out.append(BattleEvent.make(BattleEvent.XP_GAINED, {"unit_id": a.id, "amount": xp, "xp_after": a.xp}))


static func _dmg(x: float) -> int:
	return maxi(1, floori(x))
