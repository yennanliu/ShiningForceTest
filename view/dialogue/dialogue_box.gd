class_name DialogueBox
extends Control
## A spoken line: framed portrait + name tab + text that types out (doc/05 §6, doc/03 step 14).
## Players' portraits sit on the left; enemies (line "side": "enemy") on the right, mirrored.
## Confirm / continue / click finishes the text, then advances. Never waits in tests (instant).
##
##   var box := DialogueBox.create(self, Vector2(1100, 220))
##   await box.say(&"ch01_intro")

signal advanced

const PORTRAIT_PX := 184
const CHARS_PER_SEC := 60.0
## How long a finished line waits before moving on by itself, per animation speed (tune).
const AUTO_ADVANCE := {1.0: 8.0, 2.0: 1.5, 0.0: 0.6}

## Tests / headless: show the whole line and return at once.
var instant := false
## False = camp/town: the box stays up until the next line replaces it.
var waits := true

var line_id: StringName
var _portrait_frame: PanelContainer
var _portrait: TextureRect
var _name: Label
var _text: Label
var _more: Label
var _row: HBoxContainer
var _typing := false
var _tween: Tween
var _seq := 0   # which line is up; stale auto-advance timers check it


static func create(parent: Node, box_size: Vector2) -> DialogueBox:
	var b := DialogueBox.new()
	b.custom_minimum_size = box_size
	b.size = box_size
	parent.add_child(b)
	b._build()
	b.visible = false
	return b


## Shows a line and (if `waits`) waits for the player or the auto-advance time.
func say(id: StringName) -> void:
	show_line(id)
	if instant or not waits:
		return
	var speed := Settings.anim_speed()
	var limit: float = AUTO_ADVANCE.get(speed, 8.0)
	var my_seq := _seq
	var timer := get_tree().create_timer(limit + (0.0 if speed == 0.0 else _text.text.length() / (CHARS_PER_SEC * speed)))
	timer.timeout.connect(func() -> void:
		if _seq == my_seq and visible:
			advanced.emit())
	await advanced
	visible = false


## Fills the box for line `id` and starts typing.
func show_line(id: StringName) -> void:
	line_id = id
	_show(Dialogue.line(id))


## Free text with no line id (e.g. "You found a Herb!"), name-only unless `speaker_id` has a portrait.
func show_text(speaker: String, text: String, speaker_id := &"") -> void:
	line_id = &""
	_show({"speaker": speaker, "speaker_id": speaker_id, "text": text})


func _show(l: Dictionary) -> void:
	_seq += 1
	var enemy: bool = l.get("side", "") == "enemy"
	var tex := Art.portrait(StringName(l.get("speaker_id", "")), l.get("mood", ""))
	_portrait.texture = tex
	_portrait.flip_h = enemy
	_portrait_frame.visible = tex != null
	_row.move_child(_portrait_frame, _row.get_child_count() - 1 if enemy else 0)
	_name.text = l.speaker
	_more.text = "▶ next  (click / Enter)" if waits else "▶ click to continue"
	_name.add_theme_color_override("font_color", Color("ff9f9f") if enemy else UI.ACCENT)
	_text.text = l.text
	visible = true
	if _tween != null:
		_tween.kill()
	var speed := Settings.anim_speed()
	if instant or speed == 0.0 or not is_inside_tree():
		_text.visible_ratio = 1.0
		_typing = false
		_more.visible = true
		return
	_text.visible_ratio = 0.0
	_typing = true
	_more.visible = false
	_tween = create_tween()
	_tween.tween_property(_text, "visible_ratio", 1.0, _text.text.length() / (CHARS_PER_SEC * speed))
	_tween.finished.connect(func() -> void:
		_typing = false
		_more.visible = true)


## Confirm: finish typing first, then advance.
func confirm() -> void:
	if _typing:
		if _tween != null:
			_tween.kill()
		_text.visible_ratio = 1.0
		_typing = false
		_more.visible = true
	else:
		advanced.emit()


func is_typing() -> bool:
	return _typing


func text_shown() -> String:
	return _text.text


func has_portrait() -> bool:
	return _portrait_frame.visible


## Battle (`waits`): keyboard / gamepad / any click advance, and the map doesn't see them.
func _input(event: InputEvent) -> void:
	if not visible or not waits or not event.is_pressed() or event.is_echo():
		return
	var click := event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT
	if click or event.is_action("confirm") or event.is_action("continue"):
		confirm()
		get_viewport().set_input_as_handled()


## Camp / town: clicking the box itself advances; the rest of the screen stays usable.
func _gui_input(event: InputEvent) -> void:
	if waits or not (event is InputEventMouseButton) or not event.is_pressed():
		return
	if (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		confirm()
		accept_event()


func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_row = HBoxContainer.new()
	_row.add_theme_constant_override("separation", 14)
	_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_row)
	_row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_portrait_frame = _framed(_row)
	_portrait_frame.custom_minimum_size = Vector2(PORTRAIT_PX, PORTRAIT_PX)
	_portrait = TextureRect.new()
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR   # portraits are x4 pixel art; smooth when scaled down
	_portrait.custom_minimum_size = Vector2(PORTRAIT_PX - 12, PORTRAIT_PX - 12)
	_portrait_frame.add_child(_portrait)
	var text_panel := _framed(_row)
	text_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	text_panel.add_child(v)
	_name = UI.label(v, "", 26, UI.ACCENT)
	_text = UI.label(v, "", 28)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_text.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_more = UI.label(v, "", 18, Color(1, 1, 1, 0.55))
	_more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT


static func _framed(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = UI.PANEL_BG
	sb.border_color = UI.PANEL_BORDER
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(10)
	sb.set_content_margin_all(6 if parent.get_child_count() == 0 else 18)
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	return p
