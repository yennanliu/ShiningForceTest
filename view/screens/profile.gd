extends Control
## Character profile (doc/03 step 19, the owner's "role profile"): a large framed portrait,
## class and promotion path, XP, the join quote and bio, stats with growth per level,
## equipment with icons, and bonds with every ally. Q / E (LB / RB) page through the roster.

const STAT_SCALE := 60.0   # a bar is full at this value
const RIGHT_W := 1080.0
const GROWTH_STATS := ["hp", "mp", "atk", "def", "agi", "luk"]

## Where keyboard / gamepad focus starts (doc/03 step 18).
var default_focus: Control
var unit: Unit
var _portrait: TextureRect


func _ready() -> void:
	var c: Campaign = Game.campaign
	unit = c.party.member(Game.profile_id) if Game.profile_id != &"" else null
	if unit == null:
		unit = c.party.leader()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = UI.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var row := HBoxContainer.new()
	row.position = Vector2(90, 60)
	row.size = Vector2(1740, 960)
	row.add_theme_constant_override("separation", 56)
	add_child(row)
	_left(row, c)
	_right(row, c)


func _left(row: HBoxContainer, c: Campaign) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	row.add_child(col)
	var card := PanelContainer.new()
	card.theme_type_variation = &"BannerCard"
	card.custom_minimum_size = Vector2(600, 640)
	col.add_child(card)
	UI.pennant(card)
	var team := Color("3b6fd8")
	card.draw.connect(func() -> void: card.draw_rect(Rect2(-2, 26, 9, card.size.y - 52), team))   # the team ribbon
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_portrait.texture = Art.portrait(unit.data.id)
	_portrait.mouse_filter = Control.MOUSE_FILTER_STOP
	_portrait.tooltip_text = unit.data.look
	_portrait.mouse_entered.connect(func() -> void: _portrait.texture = Art.portrait(unit.data.id, "happy"))
	_portrait.mouse_exited.connect(func() -> void: _portrait.texture = Art.portrait(unit.data.id))
	card.add_child(_portrait)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 12)
	col.add_child(chips)
	if unit.is_leader:
		_chip(chips, "★ Leader", UI.ACCENT)
	_chip(chips, "Deployed" if c.party.deployed.has(unit.data.id) else "In reserve", Color("9fd0ff"))
	if c.party.can_promote(unit):
		_chip(chips, "Promotion ready", UI.ACCENT)
	# paging through the roster
	var nav := HBoxContainer.new()
	nav.add_theme_constant_override("separation", 12)
	col.add_child(nav)
	var roster := c.party.roster
	var i := roster.find(unit)
	var prev := roster[posmod(i - 1, roster.size())]
	var next := roster[posmod(i + 1, roster.size())]
	UI.button(nav, "◀  %s" % prev.display_name(), func() -> void: _show(prev), 230)
	var count := UI.label(nav, "%d / %d" % [i + 1, roster.size()], 22, Color(1, 1, 1, 0.6))
	count.custom_minimum_size = Vector2(110, 0)
	count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UI.button(nav, "%s  ▶" % next.display_name(), func() -> void: _show(next), 230)


func _right(row: HBoxContainer, c: Campaign) -> void:
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 20)
	col.custom_minimum_size = Vector2(RIGHT_W, 0)   # fixed: wrapping text and the bond row stay on screen
	row.add_child(col)
	UI.label(col, unit.display_name(), 76, Color("fff1c4"))
	UI.label(col, _class_line(c), 28, BannerTheme.TEXT_DIM)
	var xp_row := HBoxContainer.new()
	xp_row.add_theme_constant_override("separation", 14)
	col.add_child(xp_row)
	UI.label(xp_row, "XP", 22, BannerTheme.GOLD)
	var xp := ProgressBar.new()
	xp.theme_type_variation = &"XpBar"
	xp.custom_minimum_size = Vector2(420, 14)
	xp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	xp.max_value = Unit.XP_PER_LEVEL
	xp.value = unit.xp
	xp.show_percentage = false
	xp_row.add_child(xp)
	UI.label(xp_row, "%d / %d" % [unit.xp, Unit.XP_PER_LEVEL], 22, BannerTheme.TEXT_DIM)

	var quote := UI.panel(col)
	var join := StringName("join_" + String(unit.data.id))
	var q := UI.label(quote, "“%s”" % Dialogue.line(join).text if Dialogue.has(join) else "", 26)
	q.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	q.custom_minimum_size = Vector2(RIGHT_W - 60, 0)
	if unit.data.bio != "":
		var bio := UI.label(quote, unit.data.bio, 22, BannerTheme.TEXT_DIM)
		bio.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bio.custom_minimum_size = Vector2(RIGHT_W - 60, 0)

	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 20)
	col.add_child(grid)
	_stats(grid)
	var side := VBoxContainer.new()
	side.add_theme_constant_override("separation", 20)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(side)
	_equipment(side)
	_bonds(side, c)

	var back_row := HBoxContainer.new()
	back_row.alignment = BoxContainer.ALIGNMENT_END
	col.add_child(back_row)
	default_focus = UI.button(back_row, "Back to camp", _back, 300)
	UI.focus(default_focus)


func _class_line(c: Campaign) -> String:
	var s := "%s  ·  Lv %d" % [unit.class_data.display_name, unit.level]
	if unit.class_data.promotes_to.is_empty():
		return s + "  ·  final class"
	var to: ClassData = unit.class_data.promotes_to[0]
	if c.party.can_promote(unit):
		return s + "  ·  can become %s now" % to.display_name
	return s + "  →  %s at Lv 20" % to.display_name


func _stats(grid: HBoxContainer) -> void:
	var box := UI.panel(grid)
	box.custom_minimum_size = Vector2(480, 0)
	UI.label(box, "STATS  ·  GROWTH PER LEVEL", 18, BannerTheme.GOLD)
	var st := unit.stats()
	for k: String in GROWTH_STATS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		box.add_child(r)
		var tag := UI.label(r, k.to_upper(), 22)
		tag.custom_minimum_size = Vector2(56, 0)
		var bar := ProgressBar.new()
		bar.theme_type_variation = &"HpHigh" if k == "hp" else &"XpBar"
		bar.custom_minimum_size = Vector2(230, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.show_percentage = false
		bar.max_value = STAT_SCALE
		bar.value = minf(st.get(k), STAT_SCALE)
		r.add_child(bar)
		var v := UI.label(r, str(st.get(k)), 24)
		v.custom_minimum_size = Vector2(44, 0)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		var g: int = unit.class_data.growth.get(k) if unit.class_data.growth != null else 0
		UI.label(r, "+%.1f" % (g / 10.0), 20, Color(1, 1, 1, 0.55))
	var types := PackedStringArray()
	for w in unit.class_data.weapon_types:
		types.append(String(Enums.WeaponType.keys()[w]).capitalize())
	UI.label(box, "MOV %d   ·   %s   ·   %s" % [unit.mov(), String(Enums.MoveType.keys()[unit.move_type()]).capitalize(), ", ".join(types)], 20, BannerTheme.TEXT_DIM)


func _equipment(side: VBoxContainer) -> void:
	var box := UI.panel(side)
	UI.label(box, "EQUIPMENT  ·  %d SLOTS" % Unit.MAX_ITEMS, 18, BannerTheme.GOLD)
	for i in Unit.MAX_ITEMS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 12)
		box.add_child(r)
		if i >= unit.items.size():
			UI.label(r, "—  empty slot", 22, Color(1, 1, 1, 0.4))
			continue
		var it := unit.items[i]
		var icon := TextureRect.new()
		icon.texture = Art.item_icon(it.id)
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.custom_minimum_size = Vector2(36, 36)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.add_child(icon)
		var eq := "   (equipped)" if i == unit.weapon_slot or i == unit.ring_slot else ""
		UI.label(r, it.display_name + eq, 22)


func _bonds(side: VBoxContainer, c: Campaign) -> void:
	var box := UI.panel(side)
	UI.label(box, "BONDS  ·  FIGHT SIDE BY SIDE", 18, BannerTheme.GOLD)
	var r := HFlowContainer.new()   # wraps onto a second line when there are many bonds
	r.add_theme_constant_override("h_separation", 12)
	r.add_theme_constant_override("v_separation", 8)
	r.custom_minimum_size = Vector2(RIGHT_W - 480 - 20 - 50, 0)
	box.add_child(r)
	var any := false
	for o in c.party.roster:
		if o == unit:
			continue
		var t := c.bonds.tier(unit.data.id, o.data.id)
		if t <= 0:
			continue
		any = true
		var cell := VBoxContainer.new()
		r.add_child(cell)
		var frame := PanelContainer.new()
		frame.theme_type_variation = &"PortraitFrame"
		frame.custom_minimum_size = Vector2(68, 68)
		cell.add_child(frame)
		var tr := TextureRect.new()
		tr.texture = Art.portrait(o.data.id)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		tr.tooltip_text = o.display_name()
		frame.add_child(tr)
		var hearts := UI.label(cell, "♥".repeat(t), 18, Color("e86a8a"))
		hearts.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if not any:
		var none := UI.label(box, "No bonds yet. Allies standing next to each other in battle grow closer.", 20, BannerTheme.TEXT_DIM)
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.custom_minimum_size = Vector2(RIGHT_W - 480 - 20 - 50, 0)


func _chip(parent: Node, text: String, color: Color) -> void:
	var p := PanelContainer.new()
	p.theme_type_variation = &"BannerChip"
	parent.add_child(p)
	UI.label(p, text, 20, color)


func _show(u: Unit) -> void:
	Game.profile_id = u.data.id
	Game.goto(Game.Screen.PROFILE)


func _back() -> void:
	Audio.play_sfx("cancel")
	Game.goto(Game.Screen.CAMP)


func _unhandled_input(event: InputEvent) -> void:
	if not event.is_pressed() or event.is_echo():
		return
	var roster: Array[Unit] = Game.campaign.party.roster
	var i := roster.find(unit)
	if event.is_action("rotate_left"):
		_show(roster[posmod(i - 1, roster.size())])
	elif event.is_action("rotate_right"):
		_show(roster[posmod(i + 1, roster.size())])
	elif event.is_action("ui_cancel"):
		_back()
