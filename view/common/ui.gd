class_name UI
## Small helpers for building screens in code. The look comes from BannerTheme (doc/05 §6).

const BG := Color("161a24")
const ACCENT := Color("ffd34a")
const PANEL_BG := Color("1c2f6e")
const PANEL_BORDER := Color("cbb98a")


## A label. 30 px and up uses the display font (Cinzel); white text follows the theme.
static func label(parent: Node, text: String, size := 24, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	if size >= 30:
		l.theme_type_variation = &"DisplayLabel"
	if color != Color.WHITE:
		l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


## A themed button with UI sounds and hover / press motion.
static func button(parent: Node, text: String, cb: Callable, width := 360) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(width, 64)
	b.pressed.connect(func() -> void: Audio.play_sfx("confirm"))
	b.pressed.connect(cb)
	parent.add_child(b)
	animate(b)
	return b


## The one gold action of a screen (doc/05 §6: one primary action per screen).
static func primary_button(parent: Node, text: String, cb: Callable, width := 360) -> Button:
	var b := button(parent, text, cb, width)
	b.theme_type_variation = &"PrimaryButton"
	b.custom_minimum_size.y = 76
	return b


## A Banner-frame panel (with the pennant notch). Returns the column inside it.
static func panel(parent: Node, variation := &"") -> VBoxContainer:
	var card := PanelContainer.new()
	card.theme_type_variation = variation
	parent.add_child(card)
	pennant(card)
	ease_in(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	return v


## The pennant notch on the top edge of a frame (our motif). Drawn on the frame itself, not
## added as a child: a container would stretch a child over its whole area.
static func pennant(frame: Control) -> void:
	var path := "res://assets/ui/pennant.png"
	if not ResourceLoader.exists(path):
		return
	var tex: Texture2D = load(path)
	frame.draw.connect(func() -> void:
		frame.draw_texture(tex, Vector2(roundf(frame.size.x / 2.0 - tex.get_width() / 2.0), -2.0)))
	frame.queue_redraw()


## True when the UI may animate (not in headless runs; not with animations set to skip).
static func motion_ok() -> bool:
	return DisplayServer.get_name() != "headless" and Settings.anim_speed() > 0.0


## Hover / focus lifts a button a little; pressing squashes it (doc/03 step 18).
static func animate(b: Button) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	var to := func(s: float) -> void:
		if not motion_ok() or not b.is_inside_tree():
			b.scale = Vector2.ONE
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(s, s), 0.08 / Settings.anim_speed())
	b.mouse_entered.connect(func() -> void:
		if not b.disabled:
			Audio.play_sfx("hover")
			to.call(1.04))
	b.focus_entered.connect(func() -> void: to.call(1.04))
	b.mouse_exited.connect(func() -> void: to.call(1.0))
	b.focus_exited.connect(func() -> void: to.call(1.0))
	b.button_down.connect(func() -> void: to.call(0.96))
	b.button_up.connect(func() -> void: to.call(1.04 if b.is_hovered() or b.has_focus() else 1.0))


## Panels fade and rise in when they appear.
static func ease_in(c: Control) -> void:
	if not motion_ok():
		return
	c.modulate.a = 0.0
	c.ready.connect(func() -> void:
		var tw := c.create_tween()
		tw.tween_property(c, "modulate:a", 1.0, 0.18 / Settings.anim_speed()))


## Gives `c` keyboard / gamepad focus once it's on screen.
static func focus(c: Control) -> void:
	c.call_deferred("grab_focus")


## Full-screen dark background + a centered column. Returns the column.
static func screen(root: Control, top := 80) -> VBoxContainer:
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(bg)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	col.position = Vector2(0, top)
	col.size = Vector2(1920, 1080 - top)
	col.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(col)
	return col


static func center(node: Control) -> Control:
	node.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return node


static func time_text(seconds: int) -> String:
	return "%d:%02d" % [seconds / 3600, (seconds / 60) % 60]
