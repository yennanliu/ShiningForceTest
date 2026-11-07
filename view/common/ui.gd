class_name UI
## Small helpers for building simple screens in code (no art yet).

const BG := Color("161a24")
const ACCENT := Color("ffd34a")
const PANEL_BG := Color("1c2f6e")
const PANEL_BORDER := Color("cbb98a")


static func label(parent: Node, text: String, size := 24, color := Color.WHITE) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


static func button(parent: Node, text: String, cb: Callable, width := 360) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 28)
	b.custom_minimum_size = Vector2(width, 64)
	b.pressed.connect(func() -> void: Audio.play_sfx("select"))
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


static func panel(parent: Node) -> VBoxContainer:
	var card := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", sb)
	parent.add_child(card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	card.add_child(v)
	return v


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


## The game's look: dark-blue panels and buttons with a gold edge.
static func make_theme() -> Theme:
	var t := Theme.new()
	t.set_stylebox("normal", "Button", _box(Color("22357a"), PANEL_BORDER.darkened(0.3)))
	t.set_stylebox("hover", "Button", _box(Color("2d45a0"), ACCENT))
	t.set_stylebox("pressed", "Button", _box(Color("17245a"), ACCENT))
	t.set_stylebox("disabled", "Button", _box(Color("1a2040"), Color(1, 1, 1, 0.1)))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color(1, 1, 1, 0.35))
	t.set_color("font_hover_color", "Button", ACCENT)
	return t


static func _box(bg: Color, border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(10)
	return sb
