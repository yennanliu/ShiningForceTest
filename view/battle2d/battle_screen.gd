extends Control
## 2D top-down battle screen. Draws the map, pixel-art units (doc/05, step 15) and
## takes mouse/keyboard input. A View-layer client of the core: it sends Commands
## and plays the BattleEvents that come back (doc/02 §2).
##
## Run:        godot --path .                       (main scene)
## Screenshot: godot --path . -- --screenshot=out.png --demo-turns=6 --seed=7

const MAX_TILE := 96
const MAP_AREA := Vector2(1040, 900)   # room for the map on the left
const MAP_ORIGIN := Vector2(60, 140)
const TERRAIN_COLOR := {
	&"plain": Color("7cb35a"), &"forest": Color("3f7f3a"), &"hill": Color("b08e5c"),
	&"sand": Color("d9c48a"), &"shallow": Color("5aa0d8"), &"deep": Color("2f5f9e"), &"wall": Color("6b6b6b"),
}
const PLAYER_COLOR := Color("3b6fd8")
const ENEMY_COLOR := Color("c8423a")
const STATUS_COLORS := {Unit.POISON: Color("8be36b"), Unit.SLEEP: Color("8fb8ff")}
const REACH_COLOR := Color(0.35, 0.65, 1.0, 0.40)
const TARGET_COLOR := Color(1.0, 0.25, 0.2)
const STEP_TIME := 0.07
const BEAT := 0.25
## Sprite sheet layout (doc/05 §8): rows = facing, columns = frames.
const FRAME := Vector2(48, 64)
const DOWN := 0
const LEFT := 1
const RIGHT := 2
const UP := 3
const IDLE_FRAMES := [0, 1]
const WALK_FRAMES := [2, 3, 4, 5]
const ATTACK_FRAMES := [6, 7]
const HURT_FRAME := 8
const SPRITE_HEIGHT := 1.15   # x TILE (doc/05 §7)
const FEET := 0.22            # feet sit 0.22 x TILE below the tile center (72% down the tile)

## Off in tests: everything runs instantly, no tweens or timers.
var animate := true
var auto_start := true
var state: BattleState

var _seed := 1
var TILE := MAX_TILE                 # recomputed per map so it always fits
var _panel: VBoxContainer
var _unit_px := {}        # unit id -> Vector2 (drawn center, animated)
var _facing := {}         # unit id -> DOWN / LEFT / RIGHT / UP (from moves and attacks)
var _pose := {}           # unit id -> sheet column while walking / attacking / hurt
var _hurt := {}           # unit id -> true while flashing
var _idle := 0            # 0/1, the idle frame everyone shows (2 fps)
var _units_layer: Control # sprites, rings, HP bars, head icons (Nearest filter for pixel art)
var _overlay: Control     # cursor, coordinates, popups (always on top of sprites)
var _scene: BattleScene   # close-up battle scene (step 16), on top of everything
var _hp_seen := {}        # unit id -> HP as last shown (the scene's plates start from it)
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
var _spell_btn: Button
var _continue_btn: Button
var _suspend_btn: Button
var _banner: Label
var _speech: DialogueBox


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
	if shot != "" or Settings.anim_speed() == 0.0:
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
	await begin(Campaign.new_game(load(Game.FIRST_CHAPTER)).start_battle(p_seed))


## Plays the given (not yet started) battle.
func begin(s: BattleState) -> void:
	_ensure_ui()
	state = s
	_layout()
	_popups.clear()
	_log.clear()
	_banner.visible = false
	_continue_btn.visible = false
	_speech.visible = false
	_sync_positions()
	var goal := "Defeat the boss" if s.map.objective == Enums.Objective.DEFEAT_BOSS else "Defeat all enemies"
	var title: String = Game.campaign.chapter.title if Game.campaign != null and Game.campaign.chapter != null else "Demo battle"
	_log_line("[b]%s[/b] — %s; keep the Hero alive." % [title, goal])
	if state.round_number() == 0:
		var opening := state.start()
		_update_panel()   # show the first unit while the opening lines play (was blank before)
		await _play(opening)
	else:
		_log_line("(resumed)")
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
## Casts the most useful spell: heal the most hurt ally, else hit the weakest enemy.
func cast_spell() -> void:
	if _busy or not _player_turn():
		return
	var actor := state.current_actor()
	var best: CastCommand = null
	var best_score := -INF
	for c in state.legal_commands(actor):
		if not (c is CastCommand):
			continue
		var target := state.grid.unit_at(c.at)
		var score := 0.0
		if target != null:
			score = (target.max_hp() - target.hp) if target.faction == actor.faction else (100.0 - target.hp)
		score -= c.level * 0.1
		if score > best_score:
			best_score = score
			best = c
	if best == null:
		_log_line("[color=gray]No spell to cast.[/color]")
		return
	await _do(best)


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
	var ev := state.apply(cmd)
	if ev.is_empty():
		return
	_busy = true
	await _play(ev)
	if BattleEvent.turn_over(ev):
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
		var ended := false
		for cmd in AiPlanner.choose(state, u):
			var ev := state.apply(cmd)
			await _play(ev)
			if BattleEvent.turn_over(ev):
				ended = true
				break
		if not ended and state.outcome() == BattleState.Outcome.ONGOING:
			await _play(state.apply(WaitCommand.by(u.id)))
	_busy = false
	_refresh()


func _player_turn() -> bool:
	return state.human_turn()


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
	var i := 0
	while i < events.size():
		var e := events[i]
		if BattleScene.is_start(e) and _scene_wanted(e):
			# One attack or spell (with its counter, deaths, XP...) plays as a close-up.
			var end := BattleScene.group_end(events, i)
			var group := events.slice(i, end)
			for g in group:
				_log_event(g)
				if g.type == BattleEvent.ATTACKED:
					_face_each_other(g.data.attacker_id, g.data.target_id)
			await _scene.play(state, group, _hp_seen.duplicate())
			_note_hp(group)
			queue_redraw()
			i = end
			continue
		await _play_one(e)
		i += 1


## Close-ups follow Settings → Battle scenes, and never run with animations off or skipped.
func _scene_wanted(e: BattleEvent) -> bool:
	if _scene == null or not animate or Settings.anim_speed() <= 0.0 or Settings.battle_scenes == Settings.Scenes.OFF:
		return false
	var u := state.unit(e.data.attacker_id if e.type == BattleEvent.ATTACKED else e.data.unit_id)
	return Settings.battle_scenes == Settings.Scenes.ON or (u != null and u.faction == Enums.Faction.PLAYER)


func _log_event(e: BattleEvent) -> void:
	var line := TextView.describe(e, state)
	if line != "":
		_log_line(line)


## Keeps `_hp_seen` in step with what the player has been shown.
func _note_hp(events: Array) -> void:
	for e: BattleEvent in events:
		match e.type:
			BattleEvent.DAMAGED, BattleEvent.HEALED:
				_hp_seen[e.data.unit_id] = e.data.hp_after
			BattleEvent.LEVELED_UP:
				_hp_seen[e.data.unit_id] = _hp_seen.get(e.data.unit_id, 0) + e.data.gains.get("hp", 0)
			BattleEvent.SPAWNED:
				var u := state.unit(e.data.unit_id)
				if u != null:
					_hp_seen[u.id] = u.hp


func _play_one(e: BattleEvent) -> void:
	_log_event(e)
	_note_hp([e])
	match e.type:
		BattleEvent.MOVED:
			await _animate_move(e.data.unit_id, e.data.path)
		BattleEvent.DAMAGED:
			_popup("-%d" % e.data.amount, e.data.unit_id, Color("ff5a4a"))
			_pose[e.data.unit_id] = HURT_FRAME
			_hurt[e.data.unit_id] = true
			queue_redraw()
			await _pause(BEAT)
			_pose.erase(e.data.unit_id)
			_hurt.erase(e.data.unit_id)
		BattleEvent.HEALED:
			Audio.play_sfx("heal")
			_popup("+%d" % e.data.amount, e.data.unit_id, Color("6dff7a"))
			await _pause(BEAT)
		BattleEvent.ATTACKED:
			var a_id: int = e.data.attacker_id
			_face_each_other(a_id, e.data.target_id)
			_pose[a_id] = ATTACK_FRAMES[0]
			queue_redraw()
			await _pause(BEAT * 0.25)
			_pose[a_id] = ATTACK_FRAMES[1]
			queue_redraw()
			Audio.play_sfx("miss" if not e.data.hit else ("crit" if e.data.crit else "hit"))
			if not e.data.hit:
				_popup("miss", e.data.target_id, Color.WHITE)
			await _pause(BEAT * 0.6)
			_pose.erase(a_id)
		BattleEvent.CAST:
			var caster := state.unit(e.data.unit_id)
			if caster != null:
				_facing[caster.id] = facing_toward(Vector2(_v(e.data.at) - caster.pos), _facing.get(caster.id, DOWN))
				_pose[caster.id] = ATTACK_FRAMES[0]
				queue_redraw()
				await _pause(BEAT * 0.4)
				_pose.erase(caster.id)
		BattleEvent.SPAWNED:
			_unit_px[e.data.unit_id] = _center(e.data.at)
			_facing[e.data.unit_id] = _initial_facing(state.unit(e.data.unit_id))
			_popup("!", e.data.unit_id, Color("ffd34a"))
			await _pause(BEAT * 2)
		BattleEvent.ITEM_FOUND:
			Audio.play_sfx("chest")
			_popup("+item", e.data.unit_id, Color("ffd34a"))
			await _pause(BEAT * 2)
		BattleEvent.SAID:
			_speech.instant = not animate
			await _speech.say(e.data.line_id)
		BattleEvent.STATUS_ADDED:
			_popup("POISON" if e.data.status == Unit.POISON else "SLEEP", e.data.unit_id, STATUS_COLORS[e.data.status])
			await _pause(BEAT)
		BattleEvent.TURN_SKIPPED:
			_popup("zzz", e.data.unit_id, STATUS_COLORS[Unit.SLEEP])
			await _pause(BEAT)
		BattleEvent.LEVELED_UP:
			Audio.play_sfx("level_up")
			_popup("LEVEL UP", e.data.unit_id, Color("ffd34a"))
			await _pause(BEAT * 2)
		BattleEvent.BATTLE_ENDED:
			Audio.play_sfx("victory" if e.data.outcome == BattleState.Outcome.WON else "defeat")
			_show_banner(e.data.outcome)
	queue_redraw()


func _animate_move(id: int, path: Array) -> void:
	if path.size() >= 2:
		_facing[id] = facing_toward(Vector2(_v(path[-1]) - _v(path[-2])), _facing.get(id, DOWN))
	if not animate or path.size() < 2:
		_unit_px[id] = _center(path[-1])
		return
	var tw := create_tween()
	for i in range(1, path.size()):
		var step := Vector2(_v(path[i]) - _v(path[i - 1]))
		tw.tween_callback(func() -> void: _facing[id] = facing_toward(step, _facing.get(id, DOWN)))
		tw.tween_method(func(v: Vector2) -> void:
			_unit_px[id] = v
			_pose[id] = WALK_FRAMES[(Time.get_ticks_msec() / 90) % WALK_FRAMES.size()]
			queue_redraw(), _center(path[i - 1]), _center(path[i]), STEP_TIME / Settings.anim_speed())
	await tw.finished
	_pose.erase(id)
	queue_redraw()


## Facing for a direction: the larger axis wins; `fallback` when there's no direction.
static func facing_toward(d: Vector2, fallback: int = DOWN) -> int:
	if d == Vector2.ZERO:
		return fallback
	if absf(d.x) > absf(d.y):
		return RIGHT if d.x > 0 else LEFT
	return DOWN if d.y > 0 else UP


## Source rect of a frame in a sprite sheet.
static func frame_rect(facing: int, column: int) -> Rect2:
	return Rect2(Vector2(column, facing) * FRAME, FRAME)


func _face_each_other(a_id: int, t_id: int) -> void:
	var a := state.unit(a_id)
	var t := state.unit(t_id)
	if a == null or t == null:
		return
	_facing[a_id] = facing_toward(Vector2(t.pos - a.pos), _facing.get(a_id, DOWN))
	_facing[t_id] = facing_toward(Vector2(a.pos - t.pos), _facing.get(t_id, DOWN))


## At the start, everyone looks toward the other side's center.
func _initial_facing(u: Unit) -> int:
	if u == null:
		return DOWN
	var sum := Vector2.ZERO
	var n := 0
	for o in state.living():
		if (o.faction == Enums.Faction.PLAYER) != (u.faction == Enums.Faction.PLAYER):
			sum += Vector2(o.pos)
			n += 1
	return facing_toward(sum / n - Vector2(u.pos), DOWN) if n > 0 else DOWN


static func _v(t: Variant) -> Vector2i:
	return t as Vector2i if t is Vector2i else Vector2i(t[0], t[1])


func _pause(seconds: float) -> void:
	if animate:
		await get_tree().create_timer(seconds / Settings.anim_speed()).timeout


func _popup(text: String, unit_id: int, color: Color) -> void:
	_popups.append({"text": text, "pos": _unit_px.get(unit_id, Vector2.ZERO), "color": color, "age": 0.0})


func _process(delta: float) -> void:
	var idle := 0
	if animate and Settings.anim_speed() > 0.0:
		idle = (Time.get_ticks_msec() / 500) % IDLE_FRAMES.size()
	if idle != _idle and _units_layer != null:
		_idle = idle
		_units_layer.queue_redraw()
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


func _unhandled_input(event: InputEvent) -> void:
	if state == null or not event.is_pressed() or event.is_echo():
		return
	var moves := {"cursor_up": Vector2i.UP, "cursor_down": Vector2i.DOWN, "cursor_left": Vector2i.LEFT, "cursor_right": Vector2i.RIGHT}
	for a: String in moves:
		if event.is_action(a):
			move_cursor(moves[a])
			return
	if event.is_action("confirm"):
		click_tile(_hover)
	elif event.is_action("wait"):
		wait_turn()
	elif event.is_action("item"):
		use_item()
	elif event.is_action("spell"):
		cast_spell()
	elif event.is_action("continue"):
		continue_after_battle()


## Keyboard / gamepad cursor. Starts on the acting unit.
func move_cursor(dir: Vector2i) -> void:
	if not state.grid.in_bounds(_hover):
		var a := state.current_actor()
		_hover = a.pos if a != null else Vector2i.ZERO
	var t := _hover + dir
	if state.grid.in_bounds(t):
		_hover = t
		_update_panel()
		queue_redraw()


# --- drawing ---------------------------------------------------------------

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("161a24"))
	if state == null:
		return
	var g := state.grid
	for y in g.size.y:
		for x in g.size.x:
			_draw_tile(Vector2i(x, y))
	for t in MapScript.open_chests(state):
		var r := _tile_rect(t).grow(-26)
		draw_rect(r, Color("8a5a2b"))
		draw_rect(r, Color("ffd34a"), false, 3.0)
		draw_line(r.position + Vector2(0, r.size.y * 0.4), r.position + Vector2(r.size.x, r.size.y * 0.4), Color("ffd34a"), 2.0)
	for t: Vector2i in _reach:
		if g.unit_at(t) == null:
			draw_rect(_tile_rect(t).grow(-3), REACH_COLOR)
	for id in _targets:
		draw_rect(_tile_rect(state.unit(id).pos).grow(-3), TARGET_COLOR, false, 5.0)
	# Units and the overlay are child layers, drawn on top of this one.
	_units_layer.queue_redraw()
	_overlay.queue_redraw()


## Cursor, coordinates and popups: always above the sprites (doc/05 §7).
func _draw_overlay(ci: CanvasItem) -> void:
	if state == null:
		return
	var g := state.grid
	if g.in_bounds(_hover):
		ci.draw_rect(_tile_rect(_hover).grow(-1), Color(1, 1, 1, 0.9), false, 2.0)
	for x in g.size.x:
		ci.draw_string(_font, MAP_ORIGIN + Vector2(x * TILE + TILE / 2.0 - 6, -10), str(x), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
	for y in g.size.y:
		ci.draw_string(_font, MAP_ORIGIN + Vector2(-30, y * TILE + TILE / 2.0 + 7), str(y), HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 1, 1, 0.5))
	for p in _popups:
		var pos: Vector2 = p.pos + Vector2(-20, -50 - p.age * 40)
		var c: Color = p.color
		c.a = 1.0 - p.age / 0.9
		ci.draw_string(_font, pos, p.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 34, c)


## Units back to front, then every HP bar / icon on top, so a sprite never hides them.
func _draw_units(ci: CanvasItem) -> void:
	if state == null:
		return
	var alive := state.units().filter(func(u: Unit) -> bool: return u.is_alive())
	alive.sort_custom(func(a: Unit, b: Unit) -> bool:
		var ya: float = _unit_px.get(a.id, _center(a.pos)).y
		var yb: float = _unit_px.get(b.id, _center(b.pos)).y
		return ya < yb or (ya == yb and a.id < b.id))
	for u: Unit in alive:
		_draw_unit_body(ci, u)
	for u: Unit in alive:
		_draw_unit_hud(ci, u)


func _draw_tile(t: Vector2i) -> void:
	var g := state.grid
	var r := _tile_rect(t)
	var h := g.height(t)
	var id := g.terrain(t).id
	var base: Color = TERRAIN_COLOR.get(id, Color.MAGENTA)
	draw_rect(r, base.lightened(h * 0.08))
	draw_rect(r, base.darkened(0.35), false, 1.0)
	var c := r.get_center()
	var seed := t.x * 73 + t.y * 151
	if id == &"plain":
		for k in 5:
			var p := r.position + Vector2((seed * (k + 3) * 37) % (TILE - 12) + 6, (seed * (k + 5) * 53) % (TILE - 12) + 6)
			draw_line(p, p + Vector2(2, -6), base.darkened(0.2), 2.0)
	elif id == &"sand":
		for k in 8:
			draw_circle(r.position + Vector2((seed * (k + 2) * 41) % TILE, (seed * (k + 7) * 29) % TILE), 1.5, base.darkened(0.2))
	elif id == &"shallow" or id == &"deep":
		for k in 3:
			var y := r.position.y + 20 + k * 26
			draw_arc(Vector2(r.position.x + 30 + (k % 2) * 30, y), 10, PI * 1.1, PI * 1.9, 8, base.lightened(0.3), 2.0)
	if id == &"forest":
		for off in [Vector2(-18, -10), Vector2(16, -14), Vector2(0, 14)]:
			draw_circle(c + off, 15, base.darkened(0.3))
	elif id == &"hill":
		draw_colored_polygon(PackedVector2Array([c + Vector2(-28, 22), c + Vector2(0, -24), c + Vector2(28, 22)]), base.darkened(0.25))
	elif id == &"wall":
		for row in 4:
			var y := r.position.y + row * TILE / 4.0
			draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), base.darkened(0.4), 2.0)
			var off := (TILE / 4.0) if row % 2 == 0 else 0.0
			for col in 3:
				var x := r.position.x + off + col * TILE / 2.0
				draw_line(Vector2(x, y), Vector2(x, y + TILE / 4.0), base.darkened(0.4), 2.0)
	if h > 0:
		draw_string(_font, r.position + Vector2(6, TILE - 8), "h%d" % h, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(0, 0, 0, 0.55))


## Foot ring (solid = player, notched = enemy), gold ring for the actor, then the sprite.
func _draw_unit_body(ci: CanvasItem, u: Unit) -> void:
	var c: Vector2 = _unit_px.get(u.id, _center(u.pos))
	var col := PLAYER_COLOR if u.faction == Enums.Faction.PLAYER else ENEMY_COLOR
	var feet := c + Vector2(0, TILE * FEET)
	var rr := TILE * 0.36
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.42))
	ci.draw_circle(Vector2.ZERO, rr + 3, Color(0, 0, 0, 0.35))
	# Faction base (doc/05 §7): players a LIGHT ROUND ring, enemies a DARK DIAMOND,
	# so shape and brightness both differ and the read survives grayscale.
	if u.faction == Enums.Faction.PLAYER:
		ci.draw_circle(Vector2.ZERO, rr, Color(col.lightened(0.25), 0.6))
		ci.draw_arc(Vector2.ZERO, rr, 0, TAU, 40, col.lightened(0.6), 6.0)
	else:
		var d := rr * 1.2
		var pts := PackedVector2Array([Vector2(d, 0), Vector2(0, d), Vector2(-d, 0), Vector2(0, -d)])
		ci.draw_colored_polygon(pts, Color(col.darkened(0.45), 0.75))
		pts.append(pts[0])
		ci.draw_polyline(pts, col.darkened(0.15), 5.0)
	if u == state.current_actor():
		ci.draw_arc(Vector2.ZERO, rr + 9, 0, TAU, 48, Color("ffd34a"), 5.0)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var tex := Art.sprite_sheet(u.data.id)
	if tex == null:
		_draw_token(ci, u, c)
		return
	var h := TILE * SPRITE_HEIGHT
	var w := h * FRAME.x / FRAME.y
	var dest := Rect2(feet.x - w / 2.0, feet.y - h * 60.0 / FRAME.y, w, h)
	var tint := Color(1, 0.5, 0.5) if _hurt.has(u.id) else Color.WHITE
	ci.draw_texture_rect_region(tex, dest, frame_rect(_facing.get(u.id, DOWN), _frame(u)), tint)


func _frame(u: Unit) -> int:
	return _pose.get(u.id, IDLE_FRAMES[_idle])


## HP bar under the feet, leader star beside it, one head bubble above the head.
func _draw_unit_hud(ci: CanvasItem, u: Unit) -> void:
	var c: Vector2 = _unit_px.get(u.id, _center(u.pos))
	var w := TILE * 0.7
	var bar := Rect2(c + Vector2(-w / 2, TILE * 0.39), Vector2(w, 7))
	ci.draw_rect(bar.grow(1), Color(0, 0, 0, 0.7))
	var frac := float(u.hp) / u.max_hp()
	var hp_col := Color("5ad65a") if frac > 0.5 else (Color("e8c440") if frac > 0.25 else Color("e04a3a"))
	ci.draw_rect(Rect2(bar.position, Vector2(w * frac, 7)), hp_col)
	var star := TILE * 0.3
	if u.is_leader:
		_draw_icon(ci, "leader", Rect2(bar.position + Vector2(-star - 2, 3.5 - star / 2), Vector2(star, star)))
	var icon := head_icon(u)
	if icon != "":
		var s := maxf(24.0, TILE * 0.4)
		var head_top := c.y + TILE * FEET - TILE * SPRITE_HEIGHT * 50.0 / FRAME.y
		if Art.sprite_sheet(u.data.id) == null:
			head_top = c.y - TILE * 0.36
		_draw_icon(ci, icon, Rect2(c.x - s / 2, head_top - s + 2, s, s))


## One bubble per unit, most important first (doc/03 step 15):
## sleep > poison > "!" (hovered target you're strong against) > ♥ (bonded ally next to the actor).
func head_icon(u: Unit) -> String:
	if u.status.has(Unit.SLEEP):
		return "sleep"
	if u.status.has(Unit.POISON):
		return "poison"
	var actor := state.current_actor() if state != null else null
	if actor == null or not _player_turn():
		return ""
	if u.id in _targets and state.grid.in_bounds(_hover) and state.grid.unit_at(_hover) == u and Rules.matchup(actor, u) > 0:
		return "adv"
	if u != actor and u.faction == actor.faction and Pathfinder.distance(u.pos, actor.pos) == 1 \
			and state.bonds.tier(actor.data.id, u.data.id) > 0:
		return "bond"
	return ""


func _draw_icon(ci: CanvasItem, name: String, r: Rect2) -> void:
	var tex := Art.head_icon(name)
	if tex != null:
		ci.draw_texture_rect(tex, r, false)
	else:   # no icon file: a letter in a dark circle
		ci.draw_circle(r.get_center(), r.size.x / 2, Color(0.05, 0.05, 0.08, 0.9))
		ci.draw_string(_font, r.position + Vector2(0, r.size.y * 0.75), name.substr(0, 1).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, int(r.size.y * 0.7), Color.WHITE)


## Fallback when a unit has no sprite sheet: the step 6 token (circle + letter).
func _draw_token(ci: CanvasItem, u: Unit, c: Vector2) -> void:
	var col := PLAYER_COLOR if u.faction == Enums.Faction.PLAYER else ENEMY_COLOR
	var rad := TILE * 0.34
	ci.draw_circle(c, rad, col)
	ci.draw_arc(c, rad, 0, TAU, 40, col.lightened(0.4), 2.0)
	var letter := TextView._letter(u).to_upper()
	ci.draw_string(_font, c + Vector2(-rad, 11), letter, HORIZONTAL_ALIGNMENT_CENTER, rad * 2, 32, Color.WHITE)


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
	_pose.clear()
	_hurt.clear()
	for u in state.units():
		_unit_px[u.id] = _center(u.pos)
		_hp_seen[u.id] = u.hp
		if not _facing.has(u.id) or state.round_number() == 0:
			_facing[u.id] = _initial_facing(u)


# --- side panel --------------------------------------------------------------

## Picks a tile size that fits the map, then places the side panel and banner.
func _layout() -> void:
	var sz := state.map.size
	TILE = mini(MAX_TILE, floori(minf(MAP_AREA.x / sz.x, MAP_AREA.y / sz.y)))
	var map_px := Vector2(sz) * TILE
	var x := MAP_ORIGIN.x + map_px.x + 50
	var w := 1920 - x - 50
	for c in [_help_label, _log, _speech]:   # shrink children first, or the panel can't shrink
		c.custom_minimum_size.x = w
	_panel.position = Vector2(x, 40)
	_panel.size = Vector2(w, 1000)
	_banner.position = MAP_ORIGIN + Vector2(0, map_px.y / 2.0 - 90)
	_banner.size = Vector2(map_px.x, 200)


func _add_scene() -> void:
	if _scene == null:
		_scene = BattleScene.new()
		add_child(_scene)


func _layer(painter: Callable) -> Control:
	var c := Control.new()
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(c)
	c.draw.connect(func() -> void: painter.call(c))
	return c


func _ensure_ui() -> void:
	if _log == null:
		_font = ThemeDB.fallback_font
		_build_ui()


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_units_layer = _layer(_draw_units)
	_units_layer.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST   # crisp pixel art
	_overlay = _layer(_draw_overlay)
	call_deferred("_add_scene")   # last child, so the close-up covers the map and the side panel
	var map_w := 8 * TILE
	var panel := VBoxContainer.new()
	_panel = panel
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
	_hp_bar.custom_minimum_size = Vector2(300, 26)
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
	buttons.add_theme_constant_override("separation", 8)
	panel.add_child(buttons)
	_wait_btn = _button(buttons, "Wait  [W]", wait_turn)
	_item_btn = _button(buttons, "Use Herb  [I]", use_item)
	_spell_btn = _button(buttons, "Spell  [S]", cast_spell)
	_suspend_btn = _button(buttons, "Suspend", func() -> void:
		if Game.campaign != null and Game.battle == state and not _busy:
			Game.suspend_battle())
	_continue_btn = _button(buttons, "Continue  [Enter]", continue_after_battle)
	_continue_btn.visible = false

	_help_label = _label(panel, 20)
	_help_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	_help_label.autowrap_mode = TextServer.AUTOWRAP_WORD
	_help_label.custom_minimum_size = Vector2(panel.size.x, 0)

	_speech = DialogueBox.create(panel, Vector2(panel.size.x, 210))

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.custom_minimum_size = Vector2(panel.size.x, 340)
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
		_stats_label.text = "MP %d/%d   ATK %d   DEF %d   AGI %d   MOV %d   %s" % [shown.mp, shown.max_mp(), st.atk, st.def, st.agi, shown.mov(), w.display_name if w else "-"]
		_land_label.text = "Land effect: %d%%" % roundi(state.grid.land_effect(shown.pos) * 100)
		if not shown.status.is_empty():
			_land_label.text += "   Status: %s" % TextView.status_text(shown)
	_forecast_label.text = ""
	if hovered != null and hovered.id in _targets:
		var fc := Rules.forecast(state, actor, hovered)
		var adv := ""
		if fc.adv > 0:
			adv = "  ! weapon advantage"
		elif fc.adv < 0:
			adv = "  ▼ weapon disadvantage"
		_forecast_label.text = "Attack %s: hit %d%%, damage %d–%d%s%s" % [
			hovered.display_name(), roundi(fc.hit * 100), fc.dmg.x, fc.dmg.y, ", may counter" if fc.counter else "", adv]
	var mine := _player_turn() and not _busy
	_wait_btn.disabled = not mine
	_item_btn.disabled = not mine
	_suspend_btn.visible = Game.campaign != null and Game.battle == state
	_suspend_btn.disabled = not mine
	_spell_btn.visible = actor != null and not actor.class_data.spells.is_empty()
	_spell_btn.disabled = not mine
	if state.outcome() != BattleState.Outcome.ONGOING:
		_help_label.text = "Battle over. Press Continue (Enter)."
	elif mine:
		_help_label.text = "Click a blue tile to move, then a red-outlined enemy to attack (or arrows/D-pad + Space/A). Hover an enemy for the forecast. W/B = wait."
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
	b.add_theme_font_size_override("font_size", 22)
	b.custom_minimum_size = Vector2(150, 52)
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
