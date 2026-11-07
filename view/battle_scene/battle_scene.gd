class_name BattleScene
extends Control
## Close-up battle scene (doc/03 step 16, owner's image B): side view of the two fighters
## over a backdrop of the defender's terrain, with name / level / HP plates in the corners.
## Driven only by the BattleEvents of one apply(): it never touches the core or the RNG.
## Player-side units stand on the right (facing left), enemies on the left (mirrored).
## Confirm / continue / Esc / click skips straight to the result.
##
##   var steps := BattleScene.build_steps(group)        # pure, tested
##   await scene.play(state, group, hp_before)          # shows it, then hides

signal finished
signal _woke   # ends the current beat early (its timer, or a skip)

const FRAME := 192.0               # battle pose frame (doc/05 §8)
const SCALE := 2.0                 # drawn at 384 px
const FEET_IN_FRAME := 180.0       # feet row inside a frame
const IDLE := [0, 1]
const WINDUP := [2, 3]
const STRIKE := [4, 5]
const CASTING := [6, 7, 8]
const HURT := 9
const DODGE := 10
const LEFT_X := 640.0
const RIGHT_X := 1280.0
const FEET_Y := 830.0              # above the bottom-left plate
const LUNGE := 170.0
## Seconds per beat at normal speed; divided by the animation speed (tune).
const T := {"intro": 0.3, "windup": 0.16, "lunge": 0.12, "impact": 0.34, "back": 0.12,
	"cast": 0.42, "die": 0.4, "text": 0.45, "level": 0.55, "outro": 0.28}
const BACKDROP_FOR := {&"plain": "plain", &"forest": "forest", &"hill": "hill", &"sand": "sand",
	&"shallow": "shallow", &"deep": "shallow", &"wall": "ruins"}
const COMBAT := [BattleEvent.ATTACKED, BattleEvent.DAMAGED, BattleEvent.HEALED, BattleEvent.CAST,
	BattleEvent.DIED, BattleEvent.XP_GAINED, BattleEvent.LEVELED_UP, BattleEvent.STATUS_ADDED,
	BattleEvent.STATUS_ENDED, BattleEvent.BOND_CHANGED]
const SPECIAL_TEXT := {"extra_hit": "Extra hit!", "drain": "Drain!", "poison": "Poison sting!", "sleep": "Lullaby strike!"}

## Tests: no waiting at all.
var instant := false
## Steps actually played, in order (tests check them against the events).
var shown: Array[Dictionary] = []

var _state: BattleState
var _side := {}          # unit id -> "L" / "R"
var _fighter := {}       # "L" / "R" -> Unit
var _hp := {}            # unit id -> HP as shown on its plate
var _pose := {"L": 0, "R": 0}
var _offset := {"L": 0.0, "R": 0.0}
var _alpha := {"L": 1.0, "R": 1.0}
var _backdrop: Texture2D
var _numbers: Array = []  # {text, pos, color, font_px, age}
var _fx: Array = []       # {kind, from, to, age, dur}
var _flash := 0.0
var _banner: Label
var _plates := {}         # "L" / "R" -> {panel, name, bar, hp}
var _tweens: Array[Tween] = []
var _skipping := false
var _beat_id := 0
var _font: Font


static func is_start(e: BattleEvent) -> bool:
	return e.type == BattleEvent.ATTACKED or e.type == BattleEvent.CAST


## Index just past the combat events that start at `start` (an ATTACKED or CAST).
## Stops at anything that isn't combat, or at a poison tick (that belongs to the turn's end).
static func group_end(events: Array[BattleEvent], start: int) -> int:
	var i := start + 1
	while i < events.size():
		var e := events[i]
		if not (e.type in COMBAT) or (e.type == BattleEvent.DAMAGED and e.data.get("poison", false)):
			break
		i += 1
	return i


## Events -> steps. Each DAMAGED/HEALED is attached to the strike or spell before it.
static func build_steps(events: Array[BattleEvent]) -> Array[Dictionary]:
	var steps: Array[Dictionary] = []
	var last_strike := -1
	var casting := false
	for e in events:
		var d := e.data
		match e.type:
			BattleEvent.ATTACKED:
				steps.append({"kind": "strike", "by": d.attacker_id, "on": d.target_id, "hit": d.hit, "crit": d.crit,
					"counter": d.counter, "double": d.get("double", false), "special": d.get("special", ""), "dmg": -1, "hp_after": -1})
				last_strike = steps.size() - 1
				casting = false
			BattleEvent.CAST:
				steps.append({"kind": "cast", "by": d.unit_id, "spell": String(d.spell_id), "level": d.level})
				casting = true
				last_strike = -1
			BattleEvent.DAMAGED:
				if casting:
					steps.append({"kind": "spell_hit", "on": d.unit_id, "amount": d.amount, "hp_after": d.hp_after})
				elif last_strike >= 0 and steps[last_strike].on == d.unit_id and steps[last_strike].dmg < 0:
					steps[last_strike].dmg = d.amount
					steps[last_strike].hp_after = d.hp_after
				else:
					steps.append({"kind": "spell_hit", "on": d.unit_id, "amount": d.amount, "hp_after": d.hp_after})
			BattleEvent.HEALED:
				steps.append({"kind": "heal", "on": d.unit_id, "amount": d.amount, "hp_after": d.hp_after})
			BattleEvent.DIED:
				steps.append({"kind": "die", "on": d.unit_id})
			BattleEvent.STATUS_ADDED:
				steps.append({"kind": "status", "on": d.unit_id, "status": d.status})
			BattleEvent.LEVELED_UP:
				steps.append({"kind": "level_up", "on": d.unit_id, "level": d.level, "hp_gain": d.gains.get("hp", 0)})
			BattleEvent.XP_GAINED:
				steps.append({"kind": "xp", "on": d.unit_id, "amount": d.amount})
	return steps


## Seconds the scene lasts at `speed` (1 = normal, 2 = fast).
static func duration(steps: Array[Dictionary], speed: float) -> float:
	var t: float = T.intro + T.outro
	for st in steps:
		match st.kind:
			"strike":
				t += T.windup * 2 + T.lunge + T.impact + T.back
				if st.counter or st.double or st.special != "" or st.crit:
					t += 0.0   # shown in the banner during the strike, no extra time
			"cast":
				t += T.cast
			"spell_hit", "heal":
				t += T.impact * 0.6
			"die":
				t += T.die
			"status":
				t += T.text
			"level_up":
				t += T.level
	return t / maxf(speed, 0.01)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_STOP
	visible = false
	_font = ThemeDB.fallback_font
	_banner = UI.label(self, "", 44, UI.ACCENT)
	_banner.position = Vector2(0, 150)
	_banner.size = Vector2(1920, 60)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_banner.add_theme_constant_override("outline_size", 8)
	_plates["R"] = _plate(Vector2(1920 - 560 - 40, 40))
	_plates["L"] = _plate(Vector2(40, 1080 - 150 - 40))


## Shows the close-up for one group of combat events, then hides. `hp_before`: unit id ->
## HP as the map showed it before these events.
func play(state: BattleState, events: Array[BattleEvent], hp_before: Dictionary) -> void:
	if _banner == null:
		_ready()
	_state = state
	shown.clear()
	_skipping = false
	var steps := build_steps(events)
	if steps.is_empty():
		return
	_setup(steps, hp_before)
	visible = true
	queue_redraw()
	await _beat("intro")
	for st in steps:
		await _do(st)
		shown.append(st)
	await _beat("outro")
	_end()


## Jumps to the result at once: the current beat ends now and the rest play with no waiting.
func skip() -> void:
	_skipping = true
	for tw in _tweens:
		if tw.is_valid():
			tw.kill()
	_tweens.clear()
	for s in _fighter:   # bars caught mid-drain jump to the HP they're heading for
		var u: Unit = _fighter[s]
		(_plates[s].bar as ProgressBar).value = _hp.get(u.id, u.hp)
	_woke.emit()


func shown_hp(unit_id: int) -> int:
	return _hp.get(unit_id, -1)


func fighter(side: String) -> Unit:
	return _fighter.get(side)


# --- setup -----------------------------------------------------------------------

func _setup(steps: Array[Dictionary], hp_before: Dictionary) -> void:
	_side.clear()
	_fighter.clear()
	_hp.clear()
	_numbers.clear()
	_fx.clear()
	_flash = 0.0
	_banner.text = ""
	_pose = {"L": IDLE[0], "R": IDLE[0]}
	_offset = {"L": 0.0, "R": 0.0}
	_alpha = {"L": 1.0, "R": 1.0}
	var first := steps[0]
	var a := _state.unit(first.by)
	var t: Unit = null
	for st in steps:   # the opponent: the strike's target, or the first unit a spell touches
		if st.has("on") and st.on != first.by and st.kind in ["strike", "spell_hit", "heal"]:
			t = _state.unit(st.on)
			break
	var player_a := a.faction == Enums.Faction.PLAYER
	if t == null:
		_place(a, "R" if player_a else "L")
	elif player_a == (t.faction == Enums.Faction.PLAYER):
		_place(a, "R")    # same side (a heal): caster right, ally left
		_place(t, "L")
	else:
		_place(a, "R" if player_a else "L")
		_place(t, "L" if player_a else "R")
	for id in _side:
		var u := _state.unit(id)
		_hp[id] = hp_before.get(id, u.hp)
	var defender := t if t != null else a
	var terrain: StringName = _state.grid.terrain(defender.pos).id
	_backdrop = load("res://assets/textures/backdrops/%s.png" % BACKDROP_FOR.get(terrain, "plain")) \
		if ResourceLoader.exists("res://assets/textures/backdrops/%s.png" % BACKDROP_FOR.get(terrain, "plain")) else null
	for s in ["L", "R"]:
		_plates[s].panel.visible = _fighter.has(s)
		if _fighter.has(s):
			_fill_plate(s)


func _place(u: Unit, s: String) -> void:
	_side[u.id] = s
	_fighter[s] = u


# --- steps -------------------------------------------------------------------------

func _do(st: Dictionary) -> void:
	match st.kind:
		"strike":
			await _strike(st)
		"cast":
			var s: String = _side.get(st.by, "")
			_banner.text = "%s %d" % [String(st.spell).capitalize(), st.level]
			if s != "":
				_pose[s] = CASTING[0]
				queue_redraw()
				await _beat("cast", 0.4)
				_pose[s] = CASTING[1]
				queue_redraw()
				await _beat("cast", 0.3)
				_pose[s] = CASTING[2]
				queue_redraw()
				await _beat("cast", 0.3)
				_pose[s] = IDLE[0]
			else:
				await _beat("cast")
		"spell_hit":
			_hit_number(st.on, "-%d" % st.amount, Color("ff6a50"), 60)
			_add_fx("fire", st.on)
			if _side.has(st.on):
				_pose[_side[st.on]] = HURT
			_set_hp(st.on, st.hp_after)
			Audio.play_sfx("hit")
			await _beat("impact", 0.6)
			if _side.has(st.on):
				_pose[_side[st.on]] = IDLE[0]
		"heal":
			_hit_number(st.on, "+%d" % st.amount, Color("6dff7a"), 56)
			_add_fx("heal", st.on)
			_set_hp(st.on, st.hp_after)
			Audio.play_sfx("heal")
			await _beat("impact", 0.6)
		"die":
			if _side.has(st.on):
				var s: String = _side[st.on]
				_tween_to(func(v: float) -> void: _alpha[s] = v, 1.0, 0.0, T.die)
				await _beat("die")
				_alpha[s] = 0.0
		"status":
			_banner.text = "%s is %s!" % [_state.unit(st.on).display_name(), "poisoned" if st.status == Unit.POISON else "asleep"]
			await _beat("text")
		"level_up":
			_banner.text = "LEVEL UP!  %s reached Lv %d" % [_state.unit(st.on).display_name(), st.level]
			Audio.play_sfx("level_up")
			if _side.has(st.on):
				_hp[st.on] = _hp[st.on] + st.hp_gain
				_fill_plate(_side[st.on])
			await _beat("level")
		"xp":
			_hit_number(st.on, "+%d XP" % st.amount, Color("9fd0ff"), 30, Vector2(0, 60))
	queue_redraw()


func _strike(st: Dictionary) -> void:
	var a: String = _side.get(st.by, "")
	var t: String = _side.get(st.on, "")
	if a == "" or t == "":
		return
	var label := ""
	if st.counter:
		label = "Counter!"
	elif st.double:
		label = "Again!"
	_banner.text = label
	var ranged: bool = (_fighter[a] as Unit).attack_range().y > 1
	var toward := 1.0 if a == "L" else -1.0
	_pose[a] = WINDUP[0]
	queue_redraw()
	await _beat("windup")
	_pose[a] = WINDUP[1]
	queue_redraw()
	await _beat("windup")
	if not ranged:
		_tween_to(func(v: float) -> void: _offset[a] = v, 0.0, LUNGE * toward, T.lunge)
	_pose[a] = STRIKE[0]
	queue_redraw()
	await _beat("lunge")
	_pose[a] = STRIKE[1]
	if ranged:
		_add_fx("arrow", st.on, st.by)
	if st.hit:
		_add_fx("slash" if not ranged else "spark", st.on)
		_pose[t] = HURT
		var big := 76 if st.crit else 58
		_hit_number(st.on, "-%d" % maxi(st.dmg, 0), Color("ff5a4a") if not st.crit else Color("ffd34a"), big)
		if st.crit:
			_flash = 0.6
			_banner.text = "Critical!" if label == "" else label + "  Critical!"
		if st.special != "":
			_banner.text = (_banner.text + "  " if _banner.text != "" else "") + SPECIAL_TEXT.get(st.special, String(st.special).capitalize() + "!")
		if st.hp_after >= 0:
			_set_hp(st.on, st.hp_after)
		Audio.play_sfx("crit" if st.crit else "hit")
	else:
		_pose[t] = DODGE
		_tween_to(func(v: float) -> void: _offset[t] = v, 0.0, -50.0 * toward, T.lunge)
		_hit_number(st.on, "miss", Color.WHITE, 48)
		Audio.play_sfx("miss")
	queue_redraw()
	await _beat("impact")
	_pose[a] = IDLE[0]
	if _alpha.get(t, 1.0) > 0.0:
		_pose[t] = IDLE[0]
	_tween_to(func(v: float) -> void: _offset[a] = v, _offset[a], 0.0, T.back)
	_tween_to(func(v: float) -> void: _offset[t] = v, _offset[t], 0.0, T.back)
	await _beat("back")
	_offset[a] = 0.0
	_offset[t] = 0.0


func _end() -> void:
	visible = false
	_numbers.clear()
	_fx.clear()
	finished.emit()


# --- helpers ---------------------------------------------------------------------------

func _beat(name: String, part := 1.0) -> void:
	if instant or _skipping or not is_inside_tree():
		return
	var spd := Settings.anim_speed()
	if spd <= 0.0:
		return
	_beat_id += 1
	var my_id := _beat_id
	get_tree().create_timer(T[name] * part / spd).timeout.connect(func() -> void:
		if _beat_id == my_id:
			_woke.emit())
	await _woke


func _tween_to(setter: Callable, from: float, to: float, secs: float) -> void:
	if instant or _skipping or not is_inside_tree() or Settings.anim_speed() <= 0.0:
		setter.call(to)
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void:
		setter.call(v)
		queue_redraw(), from, to, secs / Settings.anim_speed())
	_tweens.append(tw)


func _set_hp(unit_id: int, hp: int) -> void:
	if not _side.has(unit_id):
		return
	_hp[unit_id] = hp
	var p: Dictionary = _plates[_side[unit_id]]
	var bar: ProgressBar = p.bar
	if instant or _skipping or not is_inside_tree():
		bar.value = hp
	else:
		var tw := create_tween()
		tw.tween_property(bar, "value", float(hp), 0.3 / maxf(Settings.anim_speed(), 0.01))
		_tweens.append(tw)
	p.hp.text = "%d / %d" % [hp, _state.unit(unit_id).max_hp()]
	_color_bar(bar, float(hp) / _state.unit(unit_id).max_hp())


func _fill_plate(s: String) -> void:
	var u: Unit = _fighter[s]
	var p: Dictionary = _plates[s]
	p.title.text = "%s    Lv %d" % [u.display_name(), u.level]
	var bar: ProgressBar = p.bar
	bar.max_value = u.max_hp()
	bar.value = _hp[u.id]
	p.hp.text = "%d / %d" % [_hp[u.id], u.max_hp()]
	_color_bar(bar, float(_hp[u.id]) / u.max_hp())
	p.stripe.color = Color("3b6fd8") if u.faction == Enums.Faction.PLAYER else Color("c8423a")


## Same HP colors as the map (doc/05): green > 50%, yellow > 25%, red below.
static func _color_bar(bar: ProgressBar, frac: float) -> void:
	var fill: StyleBoxFlat = bar.get_theme_stylebox("fill")
	fill.bg_color = Color("5ad65a") if frac > 0.5 else (Color("e8c440") if frac > 0.25 else Color("e04a3a"))


## A name / level / HP plate: our flat navy + gold frame, with a team-color stripe on the left.
func _plate(at: Vector2) -> Dictionary:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.PANEL_BG
	sb.border_color = UI.PANEL_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(16)
	sb.content_margin_left = 30
	panel.add_theme_stylebox_override("panel", sb)
	panel.position = at
	panel.custom_minimum_size = Vector2(560, 150)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(panel)
	var stripe := ColorRect.new()
	stripe.custom_minimum_size = Vector2(10, 0)
	stripe.position = at + Vector2(6, 10)
	stripe.size = Vector2(10, 130)
	stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stripe)
	var v := VBoxContainer.new()
	panel.add_child(v)
	var title := UI.label(v, "", 36, Color.WHITE)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	v.add_child(row)
	UI.label(row, "HP", 30, UI.ACCENT)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(260, 28)
	bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("5ad65a")
	fill.set_corner_radius_all(4)
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	bar.add_theme_stylebox_override("background", bg)
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var hp := UI.label(row, "", 34, Color.WHITE)
	return {"panel": panel, "title": title, "bar": bar, "hp": hp, "stripe": stripe}


func _x(s: String) -> float:
	return (LEFT_X if s == "L" else RIGHT_X) + _offset[s]


func _anchor(unit_id: int) -> Vector2:
	var s: String = _side.get(unit_id, "")
	if s == "":
		return Vector2(960, 560)
	return Vector2(_x(s), FEET_Y - 330)   # just above the head


func _hit_number(unit_id: int, text: String, color: Color, font_px: int, nudge := Vector2.ZERO) -> void:
	_numbers.append({"text": text, "pos": _anchor(unit_id) + nudge, "color": color, "font_px": font_px, "age": 0.0})


func _add_fx(kind: String, on_id: int, from_id := -1) -> void:
	_fx.append({"kind": kind, "to": _anchor(on_id), "from": _anchor(from_id) if from_id >= 0 else Vector2.ZERO, "age": 0.0, "dur": 0.35})


func _process(delta: float) -> void:
	if not visible:
		return
	var spd := maxf(Settings.anim_speed(), 1.0)
	for n in _numbers:
		n.age += delta * spd
	for f in _fx:
		f.age += delta * spd
	_numbers = _numbers.filter(func(n: Dictionary) -> bool: return n.age < 0.9)
	_fx = _fx.filter(func(f: Dictionary) -> bool: return f.age < f.dur)
	_flash = maxf(0.0, _flash - delta * 3.0)
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action("confirm") or event.is_action("continue") or event.is_action("ui_cancel"):
		skip()
		get_viewport().set_input_as_handled()


# --- drawing ---------------------------------------------------------------------------

func _draw() -> void:
	if not visible:
		return
	if _backdrop != null:
		draw_texture_rect(_backdrop, Rect2(0, 0, 1920, 1080), false)
	else:
		draw_rect(Rect2(0, 0, 1920, 1080), Color("6fa8dc"))
		draw_rect(Rect2(0, 760, 1920, 320), Color("7cb35a"))
	for s in ["L", "R"]:
		if _fighter.has(s):
			_draw_fighter(s)
	for f in _fx:
		_draw_fx(f)
	for n in _numbers:
		var c: Color = n.color
		c.a = 1.0 - maxf(0.0, n.age - 0.5) / 0.4
		var p: Vector2 = n.pos + Vector2(-60, -n.age * 70)
		draw_string_outline(_font, p, n.text, HORIZONTAL_ALIGNMENT_CENTER, 120, n.font_px, 10, Color(0, 0, 0, c.a))
		draw_string(_font, p, n.text, HORIZONTAL_ALIGNMENT_CENTER, 120, n.font_px, c)
	if _flash > 0.0:
		draw_rect(Rect2(0, 0, 1920, 1080), Color(1, 1, 1, _flash * 0.6))


func _draw_fighter(s: String) -> void:
	var u: Unit = _fighter[s]
	var x := _x(s)
	var a: float = _alpha[s]
	draw_set_transform(Vector2(x, FEET_Y), 0.0, Vector2(1.0, 0.25))
	draw_circle(Vector2.ZERO, 110, Color(0, 0, 0, 0.35 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var px := FRAME * SCALE
	var tex := Art.battle_sheet(u.data.id)
	var tint := Color(1, 1, 1, a)
	if _pose[s] == HURT:
		tint = Color(1, 0.55, 0.55, a)
	if tex == null:   # no pose sheet: a simple silhouette with the unit's letter
		var col := Color("3b6fd8") if u.faction == Enums.Faction.PLAYER else Color("c8423a")
		draw_rect(Rect2(x - 70, FEET_Y - 260, 140, 260), Color(col, a))
		draw_string(_font, Vector2(x - 70, FEET_Y - 110), TextView._letter(u).to_upper(), HORIZONTAL_ALIGNMENT_CENTER, 140, 96, tint)
		return
	var src := Rect2(_pose[s] * FRAME, 0, FRAME, FRAME)
	# Sheets face left (right side); the left side is mirrored to face right.
	var flip := -1.0 if s == "L" else 1.0
	draw_set_transform(Vector2(x, FEET_Y - FEET_IN_FRAME * SCALE), 0.0, Vector2(flip, 1.0))
	draw_texture_rect_region(tex, Rect2(-px / 2.0, 0, px, px), src, tint)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_fx(f: Dictionary) -> void:
	var k: float = f.age / f.dur
	var to: Vector2 = f.to
	match f.kind:
		"slash":
			draw_arc(to + Vector2(0, -20), 90, -2.4 + k * 1.2, -0.6 + k * 1.2, 16, Color(1, 1, 1, 1.0 - k), 10.0)
		"spark":
			for i in 6:
				var ang := i * TAU / 6
				draw_line(to + Vector2.from_angle(ang) * 20, to + Vector2.from_angle(ang) * (40 + 60 * k), Color(1, 0.95, 0.7, 1.0 - k), 5.0)
		"arrow":
			var from: Vector2 = f.from
			var p := from.lerp(to, minf(1.0, k * 1.6))
			draw_line(p - (to - from).normalized() * 70, p, Color("e8e0cc"), 6.0)
		"fire":
			for i in 5:
				var off := Vector2((i - 2) * 34, -k * 80 - (i % 2) * 30)
				draw_circle(to + off, 34 * (1.0 - k) + 8, Color(1.0, 0.45 + i * 0.08, 0.1, 0.85 * (1.0 - k)))
		"heal":
			for i in 6:
				var p := to + Vector2((i - 2.5) * 40, -k * 140 - (i % 3) * 30)
				var c := Color(0.45, 1.0, 0.55, 1.0 - k)
				draw_line(p + Vector2(-12, 0), p + Vector2(12, 0), c, 6.0)
				draw_line(p + Vector2(0, -12), p + Vector2(0, 12), c, 6.0)
