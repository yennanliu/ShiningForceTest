class_name BannerTheme
## The UI kit (doc/05 §6, doc/03 step 18): one Theme for every screen.
## The Banner frame is a 9-slice texture from tools/make_art.py (gold rim, dark line, navy field,
## inner shadow); fonts are Cinzel (display) and Inter (body), both SIL OFL, in assets/fonts/.
## Generated into assets/ui/banner_theme.tres by tools/make_theme.gd; Game loads that file.
##
## Type variations a screen can pick with `theme_type_variation`:
##   PanelContainer: (default = panel) · "BannerCard" (portraits, cards) · "PortraitFrame" (thin
##   padding) · "PlateCard" (room for a team stripe on the left) · "BannerChip" (tags)
##   Label: "DisplayLabel" (Cinzel titles and names)
##   Button: "PrimaryButton" (the one gold action per screen)
##   ProgressBar: "HpHigh" · "HpMid" · "HpLow" · "XpBar"

const PATH := "res://assets/ui/banner_theme.tres"
const UI_DIR := "res://assets/ui/"
const TEXT := Color("f3ecd8")
const TEXT_DIM := Color("c9cde0")
const GOLD := Color("e2cd8e")
const FOCUS := Color("ffd34a")
const INK := Color("1a1406")
const HP_HIGH := Color("5ad65a")
const HP_MID := Color("e8c440")
const HP_LOW := Color("e04a3a")


## The theme to use: the generated file if present, else built now.
static func load_or_build() -> Theme:
	if ResourceLoader.exists(PATH):
		var t: Theme = load(PATH)
		if t != null:
			return t
	return build()


static func build() -> Theme:
	var t := Theme.new()
	var body := _font("res://assets/fonts/Inter-Variable.ttf", 500)
	var body_bold := _font("res://assets/fonts/Inter-Variable.ttf", 650)
	var display := _font("res://assets/fonts/Cinzel-Variable.ttf", 700)
	if body != null:
		t.default_font = body
	t.default_font_size = 24

	# Panels and cards: the Banner frame.
	t.set_stylebox("panel", "PanelContainer", _frame("frame_panel", 12, 22))
	t.set_stylebox("panel", "Panel", _frame("frame_panel", 12, 22))
	_variation(t, "BannerCard", "PanelContainer")
	t.set_stylebox("panel", "BannerCard", _frame("frame_card", 12, 16))
	_variation(t, "PortraitFrame", "PanelContainer")
	t.set_stylebox("panel", "PortraitFrame", _frame("frame_card", 12, 7))
	_variation(t, "PlateCard", "PanelContainer")
	var plate := _frame("frame_card", 12, 16)
	plate.content_margin_left = 30
	t.set_stylebox("panel", "PlateCard", plate)
	_variation(t, "BannerChip", "PanelContainer")
	t.set_stylebox("panel", "BannerChip", _frame("frame_chip", 9, 6, Vector2(14, 5)))
	t.set_stylebox("panel", "PopupMenu", _frame("frame_panel", 12, 10))
	t.set_stylebox("panel", "TooltipPanel", _frame("frame_chip", 9, 6, Vector2(12, 6)))

	# Labels.
	t.set_color("font_color", "Label", TEXT)
	t.set_color("font_outline_color", "Label", Color(0, 0, 0, 0.6))
	_variation(t, "DisplayLabel", "Label")
	if display != null:
		t.set_font("font", "DisplayLabel", display)
	t.set_color("font_color", "DisplayLabel", Color("fff1c4"))
	t.set_color("default_color", "RichTextLabel", TEXT)

	# Buttons (and everything built on Button: OptionButton, CheckBox, MenuButton).
	for type in ["Button", "OptionButton", "MenuButton"]:
		t.set_stylebox("normal", type, _frame("button_normal", 9, 10, Vector2(16, 8)))
		t.set_stylebox("hover", type, _frame("button_hover", 9, 10, Vector2(16, 8)))
		t.set_stylebox("pressed", type, _frame("button_pressed", 9, 10, Vector2(16, 8)))
		t.set_stylebox("hover_pressed", type, _frame("button_pressed", 9, 10, Vector2(16, 8)))
		t.set_stylebox("disabled", type, _frame("button_disabled", 9, 10, Vector2(16, 8)))
		t.set_stylebox("focus", type, _focus_ring(9))
		t.set_color("font_color", type, TEXT)
		t.set_color("font_hover_color", type, FOCUS)
		t.set_color("font_focus_color", type, TEXT)
		t.set_color("font_pressed_color", type, Color("fff1c4"))
		t.set_color("font_hover_pressed_color", type, Color("fff1c4"))
		t.set_color("font_disabled_color", type, Color(1, 1, 1, 0.32))
		if body_bold != null:
			t.set_font("font", type, body_bold)
	_variation(t, "PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", _frame("button_primary", 9, 10, Vector2(18, 10)))
	t.set_stylebox("hover", "PrimaryButton", _frame("button_primary_hover", 9, 10, Vector2(18, 10)))
	t.set_stylebox("pressed", "PrimaryButton", _frame("button_primary", 9, 10, Vector2(18, 10)))
	t.set_stylebox("focus", "PrimaryButton", _focus_ring(10))
	for k in ["font_color", "font_hover_color", "font_focus_color", "font_pressed_color", "font_hover_pressed_color"]:
		t.set_color(k, "PrimaryButton", INK)
	if display != null:
		t.set_font("font", "PrimaryButton", display)
	# Check boxes: no frame, just the focus ring.
	t.set_stylebox("normal", "CheckBox", _empty(Vector2(8, 6)))
	t.set_stylebox("hover", "CheckBox", _empty(Vector2(8, 6)))
	t.set_stylebox("pressed", "CheckBox", _empty(Vector2(8, 6)))
	t.set_stylebox("hover_pressed", "CheckBox", _empty(Vector2(8, 6)))
	t.set_stylebox("focus", "CheckBox", _focus_ring(8))
	t.set_color("font_hover_color", "CheckBox", FOCUS)

	# Sliders.
	t.set_stylebox("slider", "HSlider", _bar(Color("2a3260"), 5, 5))   # the track needs height to show
	t.set_stylebox("grabber_area", "HSlider", _bar(GOLD, 5, 5))
	t.set_stylebox("grabber_area_highlight", "HSlider", _bar(FOCUS, 5, 5))
	t.set_stylebox("focus", "HSlider", _focus_ring(6))

	# Bars: HP colors match the map (doc/05).
	t.set_stylebox("background", "ProgressBar", _bar(Color(0.04, 0.07, 0.19, 0.9), 5))
	t.set_stylebox("fill", "ProgressBar", _bar(HP_HIGH, 5))
	for v in [["HpHigh", HP_HIGH], ["HpMid", HP_MID], ["HpLow", HP_LOW], ["XpBar", Color("7fa2ff")]]:
		_variation(t, v[0], "ProgressBar")
		t.set_stylebox("fill", v[0], _bar(v[1], 5))
	t.set_color("font_color", "ProgressBar", TEXT)

	# Scrollbars, popups, tooltips.
	t.set_stylebox("grabber", "VScrollBar", _bar(GOLD.darkened(0.2), 4))
	t.set_stylebox("grabber_highlight", "VScrollBar", _bar(GOLD, 4))
	t.set_stylebox("scroll", "VScrollBar", _bar(Color(0, 0, 0, 0.3), 4))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", FOCUS)
	t.set_stylebox("hover", "PopupMenu", _bar(Color("2d45a0"), 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	return t


## The HP bar variation for a fraction of max HP (same thresholds as the map).
static func hp_variation(frac: float) -> StringName:
	return &"HpHigh" if frac > 0.5 else (&"HpMid" if frac > 0.25 else &"HpLow")


static func _variation(t: Theme, name: StringName, base: StringName) -> void:
	t.add_type(name)
	t.set_type_variation(name, base)


static func _frame(file: String, margin: int, content: int, content_xy := Vector2(-1, -1)) -> StyleBox:
	var path := UI_DIR + file + ".png"
	if not ResourceLoader.exists(path):   # no art: a plain fallback so screens still work
		var f := StyleBoxFlat.new()
		f.bg_color = Color("1c2f6e")
		f.border_color = GOLD
		f.set_border_width_all(2)
		f.set_corner_radius_all(8)
		f.set_content_margin_all(content)
		return f
	var sb := StyleBoxTexture.new()
	sb.texture = load(path)
	sb.texture_margin_left = margin
	sb.texture_margin_right = margin
	sb.texture_margin_top = margin
	sb.texture_margin_bottom = margin
	if content_xy.x >= 0:
		sb.content_margin_left = content_xy.x
		sb.content_margin_right = content_xy.x
		sb.content_margin_top = content_xy.y
		sb.content_margin_bottom = content_xy.y
	else:
		sb.set_content_margin_all(content)
	return sb


static func _focus_ring(radius: int) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.draw_center = false
	f.border_color = FOCUS
	f.set_border_width_all(3)
	f.set_corner_radius_all(radius + 3)
	f.set_expand_margin_all(4)
	return f


static func _bar(c: Color, radius: int, height_margin := 0) -> StyleBoxFlat:
	var f := StyleBoxFlat.new()
	f.bg_color = c
	f.set_corner_radius_all(radius)
	if height_margin > 0:
		f.content_margin_top = height_margin
		f.content_margin_bottom = height_margin
	return f


static func _empty(margin: Vector2) -> StyleBoxEmpty:
	var e := StyleBoxEmpty.new()
	e.content_margin_left = margin.x
	e.content_margin_right = margin.x
	e.content_margin_top = margin.y
	e.content_margin_bottom = margin.y
	return e


static func _font(path: String, weight: int) -> Font:
	if not ResourceLoader.exists(path):
		return null
	var v := FontVariation.new()
	v.base_font = load(path)
	v.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"): weight}
	return v
