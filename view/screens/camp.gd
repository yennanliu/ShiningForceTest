extends Control
## Camp: choose who to deploy, save, and start the chapter's battle.

var _checks := {}        # data id -> CheckBox
var _status: Label


func _ready() -> void:
	var c: Campaign = Game.campaign
	var col := UI.screen(self, 60)
	UI.center(UI.label(col, "Camp", 64, UI.ACCENT))
	UI.center(UI.label(col, "Next: %s" % c.chapter.title, 32))
	UI.center(UI.label(col, "Gold %d   ·   Battles won %d   ·   Play time %s" % [
		c.inventory.gold, c.battles_won, UI.time_text(c.play_seconds)], 22, Color(1, 1, 1, 0.7)))

	var box := UI.panel(col)
	UI.center(box.get_parent())
	UI.label(box, "Deploy (max %d) — the leader always fights" % Party.MAX_DEPLOY, 24, UI.ACCENT)
	for u in c.party.roster:
		var cb := CheckBox.new()
		cb.text = "%-10s %-10s Lv %-2d  HP %d/%d  XP %d" % [u.display_name(), u.class_data.display_name, u.level, u.hp, u.max_hp(), u.xp]
		cb.add_theme_font_size_override("font_size", 24)
		cb.button_pressed = c.party.deployed.has(u.data.id)
		cb.disabled = u.is_leader
		cb.toggled.connect(func(_on: bool) -> void: _apply_deploy())
		box.add_child(cb)
		_checks[u.data.id] = cb

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	UI.center(row)
	col.add_child(row)
	UI.button(row, "Start battle", func() -> void: Game.start_battle(), 300)
	for slot in ["slot_1", "slot_2", "slot_3"]:
		UI.button(row, "Save %s" % slot.trim_prefix("slot_"), func() -> void: _save(slot), 160)
	UI.button(row, "Title", Game.quit_to_title, 160)
	_status = UI.center(UI.label(col, "", 22, Color(1, 1, 1, 0.7))) as Label


func _apply_deploy() -> void:
	var ids: Array[StringName] = []
	for id in _checks:
		if _checks[id].button_pressed:
			ids.append(id)
	if not Game.campaign.party.set_deployed(ids):
		_status.text = "Can't deploy that group."


func _save(slot: String) -> void:
	var err := Game.save_to(slot)
	_status.text = "Saved to %s." % slot if err == OK else "Save failed (error %d)." % err
