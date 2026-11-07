extends Control
## Results: outcome, XP, gold, who fell. Continue -> camp (or title at the end).


func _ready() -> void:
	var r: BattleResult = Game.last_result
	var col := UI.screen(self, 100)
	UI.center(UI.label(col, "VICTORY" if r.won() else "RETREAT", 96, UI.ACCENT if r.won() else Color("ff7a6a")))
	UI.center(UI.label(col, "%s  ·  %d rounds" % [r.chapter_title, r.rounds], 28))
	var box := UI.panel(col)
	UI.center(box.get_parent())
	if r.won():
		UI.label(box, "Gold +%d" % r.gold, 26, UI.ACCENT)
	else:
		UI.label(box, "Your party fell back to camp. XP is kept — try again!", 24)
	for id in r.xp:
		var u: Unit = Game.campaign.party.member(id)
		var name := u.display_name() if u else String(id)
		var down := "   (fell, revived)" if r.fallen.has(id) else ""
		UI.label(box, "%-10s  XP +%d%s" % [name, r.xp[id], down], 24)
	if r.campaign_complete:
		UI.center(UI.label(col, "You finished the demo campaign. Thanks for playing!", 30, UI.ACCENT))
	UI.center(UI.button(col, "Continue", Game.after_results))
