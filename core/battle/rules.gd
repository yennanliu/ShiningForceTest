class_name Rules
## Battle formulas (doc/02 §4.4–4.7). Values marked (tune) are starting points.

const BASE_HIT := 90.0
const MIN_HIT := 10.0
const MAX_HIT := 99.0
const CRIT_CHANCE := 0.04         # (tune)
const CRIT_MULT := 1.5
const COUNTER_CHANCE := 0.08      # (tune)
const DOUBLE_CHANCE := 0.06       # (tune)
const DAMAGE_JITTER := 0.1        # damage x 0.9..1.1
const XP_HIT := 10                # (tune)
const XP_KILL := 48               # (tune)
const XP_HEAL := 12               # (tune)
const BOND_HIT := 2.0             # +% hit per bond tier (tune)
const BOND_CRIT := 0.01           # +crit chance per tier (tune)
const BOND_DMG := 0.02            # x(1 + 0.02 * tier) damage (tune)
const ADV_HIT := 10.0             # +/-% hit for a weapon matchup (tune)
const ADV_CRIT := 0.08            # +crit chance with the advantage (tune)
const ADV_SPECIAL_MULT := 2.0     # special chance x2 with the advantage (tune)
const POISON_TURNS := 3           # (tune)
const POISON_FRACTION := 0.1      # of max HP per turn, min 1 (tune)
const SLEEP_TURNS := 2            # turns skipped at most (tune)
const STATS: Array[String] = ["hp", "mp", "atk", "def", "agi", "luk"]


## Chance to hit, 0..1.
static func hit_chance(s: BattleState, a: Unit, t: Unit) -> float:
	var pct := BASE_HIT + a.stats().luk - t.stats().agi / 2.0 + BOND_HIT * _bond(s, a) + ADV_HIT * matchup(a, t)
	return clampf(pct, MIN_HIT, MAX_HIT) / 100.0


static func crit_chance(s: BattleState, a: Unit, t: Unit = null) -> float:
	var adv := ADV_CRIT if t != null and matchup(a, t) > 0 else 0.0
	return CRIT_CHANCE + BOND_CRIT * _bond(s, a) + adv


## Weapon matchup: +1 = attacker has the advantage ("!"), -1 = disadvantage, 0 = even.
## Sword > axe > spear > sword. Spears and bows beat mounted units; bows beat flyers.
static func matchup(a: Unit, t: Unit) -> int:
	var aw := _wtype(a)
	var tw := _wtype(t)
	if _beats(aw, tw):
		return 1
	if _beats(tw, aw):
		return -1
	var tm := t.move_type()
	if (aw == Enums.WeaponType.SPEAR or aw == Enums.WeaponType.BOW) and tm == Enums.MoveType.MOUNTED:
		return 1
	if aw == Enums.WeaponType.BOW and tm == Enums.MoveType.FLYING:
		return 1
	return 0


static func _wtype(u: Unit) -> Enums.WeaponType:
	var w := u.weapon()
	return w.weapon_type if w != null else Enums.WeaponType.NONE


static func _beats(x: Enums.WeaponType, y: Enums.WeaponType) -> bool:
	var W := Enums.WeaponType
	return (x == W.SWORD and y == W.AXE) or (x == W.AXE and y == W.SPEAR) or (x == W.SPEAR and y == W.SWORD)


## Damage before randomness and crits.
static func raw_damage(s: BattleState, a: Unit, t: Unit) -> float:
	var land := s.grid.land_effect(t.pos)
	return (a.stats().atk - t.stats().def * (1.0 + land)) * (1.0 + BOND_DMG * _bond(s, a))


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
		"crit": crit_chance(s, a, t),
		"counter": can_counter(t, a),
		"adv": matchup(a, t),
	}


## Attack, maybe a double attack, maybe a counter. Appends events.
static func resolve_attack(s: BattleState, a: Unit, t: Unit, out: Array[BattleEvent]) -> void:
	_strike(s, a, t, false, false, out)
	if a.is_alive() and t.is_alive() and s.rng.chance(DOUBLE_CHANCE):
		_strike(s, a, t, false, true, out)
	if a.is_alive() and can_counter(t, a) and s.rng.chance(COUNTER_CHANCE):
		_strike(s, t, a, true, false, out)


## Units affected by a spell centered on `at`.
static func spell_targets(s: BattleState, caster: Unit, spell: SpellData, lv: SpellLevel, at: Vector2i) -> Array[Unit]:
	var out: Array[Unit] = []
	for u in s.living():
		var friendly := u.faction == caster.faction
		if Pathfinder.distance(u.pos, at) <= lv.area and friendly == spell.heals:
			out.append(u)
	return out


static func resolve_spell(s: BattleState, caster: Unit, spell: SpellData, level: int, at: Vector2i, out: Array[BattleEvent]) -> void:
	var lv := spell.levels[level - 1]
	caster.mp -= lv.mp_cost
	out.append(BattleEvent.make(BattleEvent.CAST, {"unit_id": caster.id, "spell_id": spell.id, "level": level, "at": at}))
	var xp := 0
	for t in spell_targets(s, caster, spell, lv, at):
		if spell.heals:
			var before := t.hp
			heal(t, lv.power, out)
			if t.hp > before:
				xp += XP_HEAL
		else:
			var dmg := _dmg(lv.power * s.rng.between(1.0 - DAMAGE_JITTER, 1.0 + DAMAGE_JITTER))
			_damage(s, t, dmg, out)
			xp += xp_for(caster, t, not t.is_alive())
	if caster.faction == Enums.Faction.PLAYER and xp > 0:
		gain_xp(s, caster, mini(xp, 49), out)


static func heal(t: Unit, amount: int, out: Array[BattleEvent]) -> void:
	var gained := mini(amount, t.max_hp() - t.hp)
	t.hp += gained
	out.append(BattleEvent.make(BattleEvent.HEALED, {"unit_id": t.id, "amount": gained, "hp_after": t.hp}))


# --- status effects (poison, sleep) and end-of-turn effects ------------------

static func add_status(t: Unit, status: StringName, turns: int, out: Array[BattleEvent]) -> void:
	t.status[status] = maxi(turns, t.status.get(status, 0))
	out.append(BattleEvent.make(BattleEvent.STATUS_ADDED, {"unit_id": t.id, "status": String(status), "turns": t.status[status]}))


static func end_status(t: Unit, status: StringName, out: Array[BattleEvent]) -> void:
	if t.status.erase(status):
		out.append(BattleEvent.make(BattleEvent.STATUS_ENDED, {"unit_id": t.id, "status": String(status)}))


## Runs when `u`'s turn ends (also a skipped turn): ring regeneration, then poison.
static func end_of_turn(s: BattleState, u: Unit, out: Array[BattleEvent]) -> void:
	if not u.is_alive():
		return
	var r := u.ring()
	if r != null and r.regen > 0 and u.hp < u.max_hp():
		heal(u, r.regen, out)
	if u.status.has(Unit.POISON):
		_damage(s, u, maxi(1, floori(u.max_hp() * POISON_FRACTION)), out, {"poison": true})
		if u.is_alive():
			u.status[Unit.POISON] -= 1
			if u.status[Unit.POISON] <= 0:
				end_status(u, Unit.POISON, out)


static func xp_for(actor: Unit, target: Unit, killed: bool) -> int:
	var base := XP_KILL if killed else XP_HIT
	return clampi(roundi(base * (1.0 + (target.level - actor.level) * 0.15)), 1, 49)


## Adds XP; every 100 XP is a level with growth rolls (doc/02 §4.6).
static func gain_xp(s: BattleState, u: Unit, amount: int, out: Array[BattleEvent]) -> void:
	u.xp += amount
	out.append(BattleEvent.make(BattleEvent.XP_GAINED, {"unit_id": u.id, "amount": amount, "xp_after": u.xp}))
	while u.xp >= Unit.XP_PER_LEVEL:
		u.xp -= Unit.XP_PER_LEVEL
		level_up(s.rng, u, out)


## +1 level. Each stat gains growth/10, plus 1 more with chance (growth % 10)/10.
static func level_up(rng: Rng, u: Unit, out: Array[BattleEvent]) -> void:
	u.level += 1
	var gains := {}
	for stat in STATS:
		var g: int = u.class_data.growth.get(stat) if u.class_data.growth != null else 0
		var gain := g / 10 + (1 if rng.chance((g % 10) / 10.0) else 0)
		if gain > 0:
			u.base.set(stat, u.base.get(stat) + gain)
			gains[stat] = gain
	u.hp += gains.get("hp", 0)
	u.mp += gains.get("mp", 0)
	out.append(BattleEvent.make(BattleEvent.LEVELED_UP, {"unit_id": u.id, "level": u.level, "gains": gains}))


## WON / LOST / ONGOING for the current state.
static func check_outcome(s: BattleState) -> BattleState.Outcome:
	if s.forced_outcome != BattleState.Outcome.ONGOING:
		return s.forced_outcome
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
		Enums.Objective.REACH_AREA:
			for u in players:
				if s.map.objective_area.has_point(u.pos) and (s.map.objective_tag == &"" or u.tag == s.map.objective_tag):
					return BattleState.Outcome.WON
		Enums.Objective.SURVIVE_ROUNDS:
			if s.round_number() > s.map.objective_rounds:
				return BattleState.Outcome.WON
		_:
			if s.living(Enums.Faction.ENEMY).is_empty():
				return BattleState.Outcome.WON
	return BattleState.Outcome.ONGOING


static func _strike(s: BattleState, a: Unit, t: Unit, counter: bool, double: bool, out: Array[BattleEvent]) -> void:
	var hit := s.rng.chance(hit_chance(s, a, t))
	var crit := hit and s.rng.chance(crit_chance(s, a, t))
	var sp := a.weapon().special if a.weapon() != null else null
	var sp_chance := (sp.chance * (ADV_SPECIAL_MULT if matchup(a, t) > 0 else 1.0)) if sp != null else 0.0
	var special := hit and sp != null and s.rng.chance(sp_chance)
	out.append(BattleEvent.make(BattleEvent.ATTACKED, {
		"attacker_id": a.id, "target_id": t.id, "hit": hit, "crit": crit,
		"counter": counter, "double": double, "special": SpecialData.Effect.keys()[sp.effect].to_lower() if special else "",
	}))
	if not hit:
		return
	var mult := s.rng.between(1.0 - DAMAGE_JITTER, 1.0 + DAMAGE_JITTER) * (CRIT_MULT if crit else 1.0)
	var dmg := _dmg(raw_damage(s, a, t) * mult)
	if special and sp.effect == SpecialData.Effect.EXTRA_HIT:
		dmg += _dmg(raw_damage(s, a, t) * 0.5)
	_damage(s, t, dmg, out)
	if special and sp.effect == SpecialData.Effect.DRAIN and a.is_alive():
		heal(a, dmg / 2, out)
	if special and t.is_alive():
		if sp.effect == SpecialData.Effect.POISON:
			add_status(t, Unit.POISON, POISON_TURNS, out)
		elif sp.effect == SpecialData.Effect.SLEEP:
			add_status(t, Unit.SLEEP, SLEEP_TURNS, out)
	if a.faction == Enums.Faction.PLAYER:
		_assist_bonds(s, a, out)
		gain_xp(s, a, xp_for(a, t, not t.is_alive()), out)


static func _damage(s: BattleState, t: Unit, dmg: int, out: Array[BattleEvent], extra := {}) -> void:
	t.hp = maxi(0, t.hp - dmg)
	var d := {"unit_id": t.id, "amount": dmg, "hp_after": t.hp}
	d.merge(extra)
	out.append(BattleEvent.make(BattleEvent.DAMAGED, d))
	if not t.is_alive():
		t.status.clear()
		s.on_unit_died(t, out)
	elif t.status.has(Unit.SLEEP) and not extra.get("poison", false):
		end_status(t, Unit.SLEEP, out)


## Allies standing next to a unit that lands a hit grow closer.
static func _assist_bonds(s: BattleState, a: Unit, out: Array[BattleEvent]) -> void:
	for n in s.grid.neighbors(a.pos):
		var o := s.grid.unit_at(n)
		if o == null or o == a or not o.is_alive() or o.faction != a.faction:
			continue
		var before := s.bonds.tier(a.data.id, o.data.id)
		var after := s.bonds.add(a.data.id, o.data.id, Bonds.ASSIST_POINTS)
		if after > before:
			out.append(BattleEvent.make(BattleEvent.BOND_CHANGED, {"a_id": a.id, "b_id": o.id, "tier": after}))


static func _bond(s: BattleState, a: Unit) -> int:
	return s.bonds.best_adjacent_tier(s, a)


static func _dmg(x: float) -> int:
	return maxi(1, floori(x))
