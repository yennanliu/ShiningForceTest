extends Control
## Settings: volumes, fullscreen, animation speed. Saved immediately.


func _ready() -> void:
	var col := UI.screen(self, 120)
	UI.center(UI.label(col, "Settings", 64, UI.ACCENT))
	var box := UI.panel(col)
	UI.center(box.get_parent())
	_slider(box, "Music volume", Settings.music_volume, func(v: float) -> void:
		Settings.music_volume = v
		Audio.refresh_volume())
	_slider(box, "Sound volume", Settings.sfx_volume, func(v: float) -> void: Settings.sfx_volume = v)
	var fs := CheckBox.new()
	fs.text = "Fullscreen"
	fs.add_theme_font_size_override("font_size", 26)
	fs.button_pressed = Settings.fullscreen
	fs.toggled.connect(func(on: bool) -> void:
		Settings.fullscreen = on
		Settings.apply()
		Settings.save_settings())
	box.add_child(fs)
	var speed := OptionButton.new()
	speed.add_theme_font_size_override("font_size", 26)
	for t in ["Animations: normal", "Animations: fast", "Animations: skip"]:
		speed.add_item(t)
	speed.selected = Settings.anim_speed_index
	speed.item_selected.connect(func(i: int) -> void:
		Settings.anim_speed_index = i
		Settings.save_settings())
	box.add_child(speed)
	UI.center(UI.button(col, "Back", func() -> void: Game.goto(Game.Screen.TITLE)))


func _slider(parent: Node, text: String, value: float, on_change: Callable) -> void:
	UI.label(parent, text, 24)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(500, 32)
	s.value_changed.connect(func(v: float) -> void:
		on_change.call(v)
		Settings.save_settings())
	parent.add_child(s)
