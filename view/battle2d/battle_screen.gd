extends Control
## 2D top-down battle screen. Draws the map with simple shapes (no art yet) and
## takes mouse/keyboard input. A View-layer client of the core: it sends Commands
## and plays the BattleEvents that come back (doc/02 §2).
##
## Run:        godot --path .                       (main scene)
## Screenshot: godot --path . -- --screenshot=out.png --demo-turns=6 --seed=7

const TILE := 96
const MAP_ORIGIN := Vector2(60, 140)
const TERRAIN_COLOR := {
	&"plain": Color("7cb35a"), &"forest": Color("3f7f3a"), &"hill": Color("b08e5c"),
	&"sand": Color("d9c48a"), &"shallow": Color("5aa0d8"), &"deep": Color("2f5f9e"), &"wall": Color("6b6b6b"),
}
const PLAYER_COLOR := Color("3b6fd8")
const ENEMY_COLOR := Color("c8423a")
const REACH_COLOR := Color(0.35, 0.65, 1.0, 0.40)
const TARGET_COLOR := Color(1.0, 0.25, 0.2)
const STEP_TIME := 0.07
const BEAT := 0.25

## Off in tests: everything runs instantly, no tweens or timers.
var animate := true
var auto_start := true
var state: BattleState

var _seed := 1
var _unit_px := {}        # unit id -> Vector2 (drawn center, animated)
var _popups: Array = []   # [{text, pos, color, age}]
var _hover := Vector2i(-1, -1)
var _busy := false
var _reach := {}          # tiles the acting player unit can move to
var _targets: Array[int] = []  # enemy ids it can attack right now

var _font: Font
var _turn_label: Label
var _name_label: Label
var _hp_bar: ProgressBar
var _hp_label: Label
var _stats_label: Label
var _land_label: Label
var _forecast_label: Label
var _help_label: Label
var _log: RichTextLabel
var _wait_btn: Button
var _item_btn: Button
var _continue_btn: Button
var _banner: Label


func _ready() -> void:
	_ensure_ui()
	var shot := ""
	var demo_turns := 0
	_seed = int(Time.get_unix_time_from_system()) % 100000
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): _seed = int(a.trim_prefix("--seed="))
		elif a.begins_with("--screenshot="): shot = a.trim_prefix("--screenshot=")
		elif a.begins_with("--demo-turns="): demo_turns = int(a.trim_prefix("--demo-turns="))
	if not auto_start:
		return
	if shot != "":
		animate = false
	if Game.battle != null and shot == "":
		begin(Game.battle)
	else:
		start_battle(_seed)
	if shot != "":
		_take_screenshot(shot, demo_turns)


## Starts a stand-alone demo battle (no campaign).
func start_battle(p_seed: int) -> void:
	_seed = p_seed
	await begin(BattleState.new(Fixtures.map(), Fixtures.party(), p_seed))


## Plays the given (not yet started) battle.
func begin(s: BattleState) -> void:
	_ensure_ui()
	state = s
	_popups.clear()
	_log.clear()
	_banner.visible = false
	_continue_btn.visible = false
	_sync_positions()
	var goal := "Defeat the boss" if s.map.objective == Enums.Objective.DEFEAT_BOSS else "Defeat all enemies"
	var title: String = Game.campaign.chapter.title if Game.campaign != null and Game.campaign.chapter != null else "Demo battle"
	_log_line("[b]%s[/b] — %s; keep the Hero alive." % [title, goal])
	await _play(state.start())
	await _advance()


## After the battle: back to the campaign, or a new demo battle.
func continue_after_battle() -> void:
	if state.outcome() == BattleState.Outcome.ONGOING:
		return
	if Game.campaign != null and Game.battle == state:
		Game.finish_battle()
	else:
		start_battle(_seed + 1)


## Player clicked a map tile.
func click_tile(t: Vector2i) -> void:
	if _busy or not _player_turn():
		return
	var actor := state.current_actor()
	var occ := state.grid.unit_at(t)
	if occ != null and occ.id in _targets:
		await _do(AttackCommand.on(actor.id, occ.id))
	elif _reach.has(t) and t != actor.pos:
		await _do(MoveCommand.to_tile(actor.id, t))


func wait_turn() -> void:
	if not _busy and _player_turn():
		await _do(WaitCommand.by(state.current_actor().id))


## Uses the first consumable on the acting unit.
func use_item() -> void:
	if _busy or not _player_turn():
		return
	var actor := state.current_actor()
	for i in actor.items.size():
		var c := UseItemCommand.on(actor.id, i, actor.id)
		if c.is_valid(state):
			await _do(c)
			return
	_log_line("[color=gray]No usable item.[/color]")


# --- turn flow ----------------------------------------------------------

func _do(cmd: Command) -> void:
	var actor := state.current_actor()
	var ev := state.apply(cmd)
	if ev.is_empty():
		return
	_busy = true
	await _play(ev)
	if state.current_actor() != actor or state.outcome() != BattleState.Outcome.ONGOING:
		await _advance()
	else:
		_busy = false
		_refresh()


## Plays enemy turns until it's the player's turn or the battle ends.
func _advance() -> void:
	while state.outcome() == BattleState.Outcome.ONGOING and not _player_turn():
		_busy = true
		var u := state.current_actor()
		_refresh()
		for cmd in AiPlanner.choose(state, u):
			await _play(state.apply(cmd))
			if state.current_actor() != u:
				break
		if state.outcome() == BattleState.Outcome.ONGOING and state.current_actor() == u:
			await _play(state.apply(WaitCommand.by(u.id)))
	_busy = false
	_refresh()


func _player_turn() -> bool:
	var a := state.current_actor()
	return a != null and a.faction == Enums.Faction.PLAYER and state.outcome() == BattleState.Outcome.ONGOING


func _refresh() -> void:
	_reach = {}
	_targets.clear()
	if _player_turn():
		var actor := state.current_actor()
		if not state.has_moved():
			_reach = Pathfinder.reachable(state.grid, actor)
		for u in state.living(Enums.Faction.ENEMY):
			if AttackCommand.on(actor.id, u.id).is_valid(state):
				_targets.append(u.id)
	_update_panel()
	queue_redraw()


# --- events -> animation -------------------------------------------------

func _play(events: Array[BattleEvent]) -> void:
	for e in events:
		var line := TextView.describe(e, state)
		if line != "":
			_log_line(line)
		match e.type:
			BattleEvent.MOVED:
				await _animate_move(e.data.unit_id, e.data.path)
			BattleEvent.DAMAGED:
				_popup("-%d" % e.data.amount, e.data.unit_id, Color("ff5a4a"))
				await _pause(BEAT)
			BattleEvent.HEALED:
				_popup("+%d" % e.data.amount, e.data.unit_id, Color("6dff7a"))
				await _pause(BEAT)
			BattleEvent.ATTACKED:
				if not e.data.hit:
					_popup("miss", e.data.target_id, Color.WHITE)
				await _pause(BEAT * 0.6)
			BattleEvent.BATTLE_ENDED:
				_show_banner(e.data.outcome)
		queue_redraw()


func _animate_move(id: int, path: Array) -> void:
	if not animate or path.size() < 2:
		_unit_px[id] = _center(path[-1])
		return
	var tw := create_tween()
	for i in range(1, path.size()):
		tw.tween_method(func(v: Vector2) -> void:
			_unit_px[id] = v
			queue_redraw(), _center(path[i - 1]), _center(path[i]), STEP_TIME)
	await tw.finished


func _pause(seconds: float) -> void:
	if animate:
		await get_tree().create_timer(seconds).timeout


func _popup(text: String, unit_id: int, color: Color) -> void:
	_popups.append({"text": text, "pos": _unit_px.get(unit_id, Vector2.ZERO), "color": color, "age": 0.0})


func _process(delta: float) -> void:
	if _popups.is_empty():
		return
	for p in _popups:
		p.age += delta
	_popups = _popups.filter(func(p: Dictionary) -> bool: return p.age < 0.9)
	queue_redraw()


# --- input ----------------------------------------------------------------

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var t := _tile_at(event.position)
		if t != _hover:
			_hover = t
			_update_panel()
			queue_redraw()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var t := _tile_at(event.position)
		if state.grid.in_bounds(t):
			click_tile(t)


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed):
		return
	match event.keycode:
		KEY_W: wait_turn()
		KEY_I: use_item()
		KEY_R, KEY_ENTER: continue_after_battle()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("161a24"))
	if state == null:
		return
	var g := state.grid
	for y in g.size.y:
		for x in g.size.x:
			_draw_tile(Vector2i(x, y))
	for t: Vector2i in _reach:
		if g.unit_at(t) == null:
			draw_rect(_tile_rect(t).grow(-3), REACH_COLOR)
	for id in _targets:
		draw_rect(_tile_rect(state.unit(id).pos).grow(-3), TARGET_COLOR, false, 5.0)
	if g.in_bounds(_hover):
		draw_rect(_tile_rect(_hover).grow(-1), Color(1, 1, 1, 0.9), false, 2.0)
	for u in state.units():
		if u.is_alive():
			_draw_unit(u)
	for x in g.size.x:
		draw_string(_font, MAP_ORIGIN + Vector2(x * TILE + TILE / 2.0 - 6, -10), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
	for y in g.size.y:
		draw_string(_font, MAP_ORIGIN + Vector2(-30, y * TILE + TILE / 2.0 + 7), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
	for p in _popups:
		var pos: Vector2 = p.pos + Vector2(-20, -50 - p.age * 40)
		var c: Color = p.color
		c.a = 1.0 - p.age / 0.9
		draw_string(_font, pos, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)


func _draw_tile(t: Vector2i) -> void:
	var g := state.grid
	var r := _tile_rect(t)
	var h := g.height(t)
	var id := g.terrain(t).id
	var base: Color = TERRAIN_COLOR.get(id, Color.MAGENTA)
	draw_rect(r, base.lightened(h * 0.08))
	draw_rect(r, base.darkened(0.35), false, 1.0)
	var c := r.get_center()
	if id == &"forest":
		for off in [Vector2(-18, -10), Vector2(16, -14), Vector2(0, 14)]:
			draw_circle(c + off, 15, base.darkened(0.3))
	elif id == &"hill":
		draw_colored_polygon(PackedVector2Array([c + Vector2(-28, 22), c + Vector2(0, -24), c + Vector2(28, 22)]), base.darkened(0.25))
	elif id == &"wall":
		draw_rect(r.grow(-10), base.darkened(0.3))
	if h > 0:
		draw_string(_font, r.position + Vector2(6, TILE - 8), "h%d" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.55))


func _draw_unit(u: Unit) -> void:
	var c: Vector2 = _unit_px.get(u.id, _center(u.pos))
	var col := PLAYER_COLOR if u.faction == Enums.Faction.PLAYER else ENEMY_COLOR
	var rad := TILE * 0.34
	draw_circle(c + Vector2(3, 4), rad, Color(0, 0, 0, 0.35))
	draw_circle(c, rad, col)
	draw_arc(c, rad, 0, TAU, 40, col.lightened(0.4), 2.0)
	if u == state.current_actor():
		draw_arc(c, rad + 6, 0, TAU, 40, Color("ffd34a"), 4.0)
	if u.is_leader:
		draw_string(_font, c + Vector2(-8, -rad - 4), "★", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("ffd34a"))
	var letter := TextView._letter(u).to_upper()
	draw_string(_font, c + Vector2(-rad, 11), letter, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 32, Color.WHITE)
	var w := TILE * 0.7
	var bar := Rect2(c + Vector2(-w / 2, rad + 6), Vector2(w, 7))
	draw_rect(bar, Color(0, 0, 0, 0.6))
	var frac := float(u.hp) / u.max_hp()
	var hp_col := Color("5ad65a") if frac > 0.5 else (Color("e8c440") if frac > 0.25 else Color("e04a3a"))
	draw_rect(Rect2(bar.position, Vector2(w * frac, 7)), hp_col)


func _tile_rect(t: Vector2i) -> Rect2:
	return Rect2(MAP_ORIGIN + Vector2(t) * TILE, Vector2(TILE, TILE))


func _center(t: Variant) -> Vector2:
	var v := t as Vector2i if t is Vector2i else Vector2i(t[0], t[1])
	return MAP_ORIGIN + Vector2(v) * TILE + Vector2(TILE, TILE) / 2.0


func _tile_at(p: Vector2) -> Vector2i:
	var local := (p - MAP_ORIGIN) / TILE
	return Vector2i(floori(local.x), floori(local.y))


func _sync_positions() -> void:
	_unit_px.clear()
	for u in state.units():
		_unit_px[u.id] = _center(u.pos)


# --- side panel --------------------------------------------------------------

func _ensure_ui() -> void:
	if _log == null:
		_font = ThemeDB.fallback_font
		_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var map_w := 8 * TILE
	var panel := VBoxContainer.new()
	panel.position = Vector2(MAP_ORIGIN.x + map_w + 60, 40)
	panel.size = Vector2(1920 - panel.position.x - 60, 1000)
	panel.add_theme_constant_override("separation", 14)
	add_child(panel)

	_turn_label = _label(panel, 34)

	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("1c2f6e")
	sb.border_color = Color("cbb98a")
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(18)
	card.add_theme_stylebox_override("panel", sb)
	panel.add_child(card)
	var cv := VBoxContainer.new()
	card.add_child(cv)
	_name_label = _label(cv, 30)
	var hp_row := HBoxContainer.new()
	cv.add_child(hp_row)
	var hp_tag := _label(hp_row, 24)
	hp_tag.text = "HP"
	_hp_bar = ProgressBar.new()
	_hp_bar.custom_minimum_size = Vector2(360, 26)
	_hp_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("5ad65a")
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.5)
	bg.set_corner_radius_all(4)
	_hp_bar.add_theme_stylebox_override("fill", fill)
	_hp_bar.add_theme_stylebox_override("background", bg)
	hp_row.add_child(_hp_bar)
	_hp_label = _label(hp_row, 24)
	_stats_label = _label(cv, 22)
	_land_label = _label(cv, 22)

	_forecast_label = _label(panel, 24)
	_forecast_label.add_theme_color_override("font_color", Color("ffb0a0"))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	panel.add_child(buttons)
	_wait_btn = _button(buttons, "Wait  [W]", wait_turn)
	_item_btn = _button(buttons, "Use Herb  [I]", use_item)
	_continue_btn = _button(buttons, "Continue  [Enter]", continue_after_battle)
	_continue_btn.visible = false

	_help_label = _label(panel, 20)
	_help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_help_label.custom_minimum_size = Vector2(panel.size.x, 0)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(panel.size.x, 380)
	_log.add_theme_font_size_override("normal_font_size", 20)
	_log.add_theme_font_size_override("bold_font_size", 20)
	panel.add_child(_log)

	_banner = Label.new()
	_banner.add_theme_font_size_override("font_size", 96)
	_banner.add_theme_color_override("font_outline_color", Color.BLACK)
	_banner.add_theme_constant_override("outline_size", 16)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.position = MAP_ORIGIN + Vector2(0, map_w / 2.0 - 90)
	_banner.size = Vector2(map_w, 200)
	_banner.visible = false
	add_child(_banner)


func _update_panel() -> void:
	if state == null:
		return
	var actor := state.current_actor()
	if state.outcome() != BattleState.Outcome.ONGOING:
		_turn_label.text = "Round %d — battle over" % state.round_number()
	elif actor != null:
		var whose := "Your turn" if actor.faction == Enums.Faction.PLAYER else "Enemy turn"
		_turn_label.text = "Round %d — %s: %s" % [state.round_number(), whose, actor.display_name()]
	var shown := actor
	var hovered := state.grid.unit_at(_hover) if state.grid.in_bounds(_hover) else null
	if hovered != null:
		shown = hovered
	if shown != null:
		var st := shown.stats()
		_name_label.text = "%s   %s   Lv %d" % [shown.display_name(), shown.class_data.display_name, shown.level]
		_name_label.add_theme_color_override("font_color", Color("9fd0ff") if shown.faction == Enums.Faction.PLAYER else Color("ff9f9f"))
		_hp_bar.max_value = shown.max_hp()
		_hp_bar.value = shown.hp
		_hp_label.text = "  %d / %d" % [shown.hp, shown.max_hp()]
		var w := shown.weapon()
		_stats_label.text = "ATK %d   DEF %d   AGI %d   MOV %d   %s" % [st.atk, st.def, st.agi, shown.mov(), w.display_name if w else "-"]
		_land_label.text = "Land effect: %d%%" % roundi(state.grid.land_effect(shown.pos) * 100)
	_forecast_label.text = ""
	if hovered != null and hovered.id in _targets:
		var fc := Rules.forecast(state, actor, hovered)
		_forecast_label.text = "Attack %s: hit %d%%, damage %d–%d%s" % [
			hovered.display_name(), roundi(fc.hit * 100), fc.dmg.x, fc.dmg.y, ", may counter" if fc.counter else ""]
	var mine := _player_turn() and not _busy
	_wait_btn.disabled = not mine
	_item_btn.disabled = not mine
	if state.outcome() != BattleState.Outcome.ONGOING:
		_help_label.text = "Battle over. Press Continue (Enter)."
	elif mine:
		_help_label.text = "Click a blue tile to move, then click a red-outlined enemy to attack. Hover an enemy for the forecast. W = wait."
	else:
		_help_label.text = "Enemy is moving…"


func _show_banner(outcome: int) -> void:
	_banner.text = "VICTORY" if outcome == BattleState.Outcome.WON else "DEFEAT"
	_banner.add_theme_color_override("font_color", Color("ffd34a") if outcome == BattleState.Outcome.WON else Color("ff5a4a"))
	_banner.visible = true
	_continue_btn.visible = true


func _log_line(text: String) -> void:
	_log.append_text(text + "\n")


func _label(parent: Node, font_size: int) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 24)
	b.custom_minimum_size = Vector2(200, 56)
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _take_screenshot(path: String, demo_turns: int) -> void:
	for i in demo_turns:
		if state.outcome() != BattleState.Outcome.ONGOING:
			break
		AutoPlay.play_turn(state)
	_sync_positions()
	_refresh()
	for i in 4:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(path)
	print("screenshot saved: %s" % path)
	get_tree().quit()
