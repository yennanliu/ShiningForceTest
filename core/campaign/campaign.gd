class_name Campaign
extends RefCounted
## The whole saved game: current chapter, party, inventory, flags, play time (doc/02 §4.11).
## Battles get COPIES of the deployed units; finish_battle() merges results back.

var chapter: ChapterData          # null = campaign complete
var party := Party.new()
var inventory := Inventory.new()
var bonds := Bonds.new()
var flags: Dictionary = {}
var play_seconds := 0
var battles_won := 0


static func new_game(first: ChapterData) -> Campaign:
	var c := Campaign.new()
	c.chapter = first
	for d in first.recruits_on_start:
		c.party.recruit(d)
	return c


func is_complete() -> bool:
	return chapter == null


func start_battle(seed: int) -> BattleState:
	var b := BattleState.new(chapter.battle, party.deployed_units(), seed)
	b.bonds = bonds.copy()
	return b


## Merge a finished battle back into the campaign. Win: reward + next chapter.
## Loss: retreat with XP kept. Everyone is healed and revived after a battle.
func finish_battle(s: BattleState) -> BattleResult:
	var r := BattleResult.new()
	r.outcome = s.outcome()
	r.chapter_title = chapter.title
	r.rounds = s.round_number()
	for bu in s.units():
		if bu.faction != Enums.Faction.PLAYER:
			continue
		var u := party.member(bu.data.id)
		if u == null:
			continue
		r.xp[u.data.id] = bu.total_xp() - u.total_xp()
		if bu.level > u.level:
			r.level_ups.append(u.data.id)
		u.xp = bu.xp
		u.level = bu.level
		u.base = bu.base.copy()
		u.items = bu.items.duplicate()
		u.weapon_slot = bu.weapon_slot
		u.ring_slot = bu.ring_slot
		if not bu.is_alive():
			r.fallen.append(u.data.id)
		u.hp = u.max_hp()
		u.mp = u.max_mp()
	bonds = s.bonds.copy()
	for id in r.fallen:
		bonds.drop_tier_on_death(id)
	if r.won():
		battles_won += 1
		r.gold = chapter.reward_gold
		inventory.gold += r.gold
		_advance_chapter()
	r.campaign_complete = is_complete()
	return r


## Buys a shop item: it goes to the first deployed unit with a free slot, else storage.
func buy(item: ItemData) -> bool:
	if not inventory.buy(item):
		return false
	inventory.storage.pop_back()
	give(item)
	return true


func found_key(i: int) -> String:
	return "found_%s_%d" % [chapter.id, i]


## Searches hidden spot i in this chapter's town. Returns the item found, or null.
func search(i: int) -> ItemData:
	if i < 0 or i >= chapter.town_finds.size() or flags.get(found_key(i), false):
		return null
	flags[found_key(i)] = true
	var item := chapter.town_finds[i]
	give(item)
	return item


## Gives an item to the first deployed unit with a free slot, else storage.
func give(item: ItemData) -> void:
	for u in party.deployed_units():
		if u.items.size() < Unit.MAX_ITEMS:
			u.items.append(item)
			if item.kind == ItemData.Kind.WEAPON and u.weapon_slot < 0 and item.weapon_type in u.class_data.weapon_types:
				u.weapon_slot = u.items.size() - 1
			return
	inventory.storage.append(item)


func _advance_chapter() -> void:
	chapter = chapter.next
	if chapter != null:
		for d in chapter.recruits_on_start:
			party.recruit(d)


func to_dict() -> Dictionary:
	return {
		"chapter": String(chapter.id) if chapter != null else "",
		"chapter_title": chapter.title if chapter != null else "The End",
		"party": party.to_dict(),
		"inventory": inventory.to_dict(),
		"bonds": bonds.to_dict(),
		"flags": flags.duplicate(),
		"play_seconds": play_seconds,
		"battles_won": battles_won,
	}


static func from_dict(d: Dictionary) -> Campaign:
	var c := Campaign.new()
	var ch: String = d.get("chapter", "")
	c.chapter = Content.chapter(StringName(ch)) if ch != "" else null
	c.party = Party.from_dict(d.get("party", {}))
	c.inventory = Inventory.from_dict(d.get("inventory", {}))
	c.bonds = Bonds.from_dict(d.get("bonds", {}))
	c.flags = d.get("flags", {})
	c.play_seconds = int(d.get("play_seconds", 0))
	c.battles_won = int(d.get("battles_won", 0))
	return c
