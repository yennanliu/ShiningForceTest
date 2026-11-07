class_name Party
extends RefCounted
## The roster of recruited units and who is deployed. Units are matched by data id.

const MAX_DEPLOY := 12

var roster: Array[Unit] = []
var deployed: Array[StringName] = []   # data ids, in deploy order; the leader is always first


func recruit(d: UnitData) -> Unit:
	var existing := member(d.id)
	if existing != null:
		return existing
	var u := Unit.from_data(d)
	u.is_leader = roster.is_empty()
	roster.append(u)
	if deployed.size() < MAX_DEPLOY:
		deployed.append(d.id)
	return u


func leader() -> Unit:
	for u in roster:
		if u.is_leader:
			return u
	return null


func member(id: StringName) -> Unit:
	for u in roster:
		if u.data.id == id:
			return u
	return null


func deployed_units() -> Array[Unit]:
	var out: Array[Unit] = []
	for id in deployed:
		var u := member(id)
		if u != null:
			out.append(u)
	return out


## Must include the leader, at most MAX_DEPLOY, all recruited. Leader is moved first.
func set_deployed(ids: Array[StringName]) -> bool:
	var lead := leader()
	if ids.is_empty() or ids.size() > MAX_DEPLOY or lead == null or not ids.has(lead.data.id):
		return false
	for id in ids:
		if member(id) == null:
			return false
	deployed.assign(ids)
	deployed.erase(lead.data.id)
	deployed.push_front(lead.data.id)
	return true


func to_dict() -> Dictionary:
	return {
		"roster": roster.map(func(u: Unit) -> Dictionary: return u.to_dict()),
		"deployed": deployed.map(func(id: StringName) -> String: return String(id)),
	}


static func from_dict(d: Dictionary) -> Party:
	var p := Party.new()
	for ud in d.get("roster", []):
		var u := Unit.from_dict(ud)
		if u.data != null:
			p.roster.append(u)
	for id in d.get("deployed", []):
		if p.member(StringName(id)) != null:
			p.deployed.append(StringName(id))
	return p
