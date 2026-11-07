extends Control
## Camp: choose who to deploy, save, and start the chapter's battle.

var _checks := {}        # data id -> CheckBox
var _status: Label
var _talk: DialogueBox
var _veil: ColorRect
var _queue: Array[StringName] = []   # lines still to show (join lines on arrival)
## Where keyboard / gamepad focus starts (doc/03 step 18).
var default_focus: Control


func _ready() -> void:
	var c: Campaign = Game.campaign
	var col := UI.screen(self, 40)
	UI.center(UI.label(col, "Camp", 64, UI.ACCENT))
	UI.center(UI.label(col, "Next: %s" % c.chapter.title, 32))
	UI.center(UI.label(col, "Gold %d   ·   Battles won %d   ·   Play time %s" % [
		c.inventory.gold, c.battles_won, UI.time_text(c.play_seconds)], 22, Color(1, 1, 1, 0.7)))

	for d in c.chapter.recruits_on_start:
		var key := StringName("met_" + String(d.id))
		if not c.flags.get(key, false):
			c.flags[key] = true
			_queue.append(StringName("join_" + String(d.id)))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 24)
	UI.center(cols)
	col.add_child(cols)
	var box := UI.panel(cols)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 16)
	cols.add_child(right)
	UI.label(box, "Deploy (max %d) — the leader always fights" % Party.MAX_DEPLOY, 24, UI.ACCENT)
	for u in c.party.roster:
		var cb := CheckBox.new()
		cb.text = "%-10s %-10s Lv %-2d  HP %d/%d  XP %d" % [u.display_name(), u.class_data.display_name, u.level, u.hp, u.max_hp(), u.xp]
		cb.add_theme_font_size_override("font_size", 24)
		cb.button_pressed = c.party.deployed.has(u.data.id)
		cb.disabled = u.is_leader
		cb.toggled.connect(func(_on: bool) -> void: _apply_deploy())
		var row := HBoxContainer.new()
		row.add_child(cb)
		var chat := StringName("camp_%s_%s" % [u.data.id, c.chapter.id])
		if Dialogue.has(chat):
			UI.button(row, "Talk", func() -> void:
				_queue.clear()
				_talk.show_line(chat), 120)
		if c.party.can_promote(u):
			for to in u.class_data.promotes_to:
				UI.button(row, "Promote → %s" % to.display_name, func() -> void: _promote(u, to), 300)
		box.add_child(row)
		_checks[u.data.id] = cb

	if not c.chapter.shop.is_empty():
		var shop := UI.panel(right)
		UI.label(shop, "Shop (goes to the first unit with a free slot)", 22, UI.ACCENT)
		for item in c.chapter.shop:
			UI.button(shop, "%s  %dG" % [item.display_name, item.price], func() -> void: _buy(item), 420)

	default_focus = UI.primary_button(right, "Start battle", func() -> void: Game.start_battle(), 420)
	UI.focus(default_focus)
	if c.chapter.town_name != "":
		UI.button(right, "Visit %s" % c.chapter.town_name, func() -> void: Game.goto(Game.Screen.TOWN), 420)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	right.add_child(row)
	for slot in ["slot_1", "slot_2", "slot_3"]:
		UI.button(row, "Save %s" % slot.trim_prefix("slot_"), func() -> void: _save(slot), 98)
	UI.button(row, "Title", Game.quit_to_title, 98)
	_status = UI.center(UI.label(col, "", 22, Color(1, 1, 1, 0.8))) as Label
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD
	_status.custom_minimum_size = Vector2(1500, 0)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	# Portrait dialogue over the header (doc/03 step 14); click it for the next line.
	# A dark band covers the header while someone is talking, so no text peeks out.
	_veil = ColorRect.new()
	_veil.color = UI.BG
	_veil.position = Vector2.ZERO
	_veil.size = Vector2(1920, 245)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
	_talk = DialogueBox.create(self, Vector2(1300, 215))
	_talk.waits = false
	_talk.position = Vector2((1920 - 1300) / 2.0, 15)
	_talk.advanced.connect(_next_line)
	_talk.visibility_changed.connect(func() -> void: _veil.visible = _talk.visible)
	_next_line()
	_veil.visible = _talk.visible


func _next_line() -> void:
	if _queue.is_empty():
		_talk.visible = false
	else:
		_talk.show_line(_queue.pop_front())


func _apply_deploy() -> void:
	var ids: Array[StringName] = []
	for id in _checks:
		if _checks[id].button_pressed:
			ids.append(id)
	if not Game.campaign.party.set_deployed(ids):
		_status.text = "Can't deploy that group."


func _promote(u: Unit, to: ClassData) -> void:
	if Game.campaign.party.promote(u, to):
		get_tree().reload_current_scene()


func _buy(item: ItemData) -> void:
	if Game.campaign.buy(item):
		_status.text = "Bought %s. Gold left: %d" % [item.display_name, Game.campaign.inventory.gold]
	else:
		_status.text = "Not enough gold."


func _save(slot: String) -> void:
	var err := Game.save_to(slot)
	_status.text = "Saved to %s." % slot if err == OK else "Save failed (error %d)." % err
