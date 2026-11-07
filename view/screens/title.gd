extends Control
## Title screen: New Game, Continue (pick a save slot), Quit.

var _slots_box: VBoxContainer


func _ready() -> void:
	var col := UI.screen(self, 180)
	UI.center(UI.label(col, "BANNER", 120, UI.ACCENT))
	UI.center(UI.label(col, "a tactics RPG  ·  demo", 28, Color(1, 1, 1, 0.6)))
	col.add_child(_spacer(40))
	UI.center(UI.button(col, "New Game", Game.new_game))
	var cont := UI.center(UI.button(col, "Continue", _toggle_slots)) as Button
	cont.disabled = not SaveService.has_any_save()
	_slots_box = VBoxContainer.new()
	_slots_box.visible = false
	UI.center(_slots_box)
	col.add_child(_slots_box)
	UI.center(UI.button(col, "Quit", func() -> void: get_tree().quit()))


func _toggle_slots() -> void:
	_slots_box.visible = not _slots_box.visible
	for c in _slots_box.get_children():
		c.queue_free()
	for info in SaveService.list_slots():
		var text: String
		if not info.exists:
			text = "%s — empty" % info.slot
		elif info.damaged:
			text = "%s — Damaged" % info.slot
		else:
			text = "%s — %s  (%s)" % [info.slot, info.chapter_title, UI.time_text(info.play_seconds)]
		var b := UI.button(_slots_box, text, func() -> void: Game.continue_game(info.slot), 620)
		b.disabled = not info.exists or info.damaged


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c
