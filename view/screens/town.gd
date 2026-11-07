extends Control
## Town (simplified to a menu): talk to townspeople and search hidden spots.

var _talk: DialogueBox
## Where keyboard / gamepad focus starts (doc/03 step 18).
var default_focus: Control


func _ready() -> void:
	var c: Campaign = Game.campaign
	var col := UI.screen(self, 80)
	UI.center(UI.label(col, c.chapter.town_name, 64, UI.ACCENT))
	var talk := UI.panel(col)
	UI.center(talk.get_parent())
	UI.label(talk, "Talk", 26, UI.ACCENT)
	for id in c.chapter.town_talk:
		var l := Dialogue.line(id)
		UI.button(talk, "Talk to %s" % l.speaker, func() -> void:
			_talk.modulate.a = 1.0
			_talk.show_line(id), 560)
	var search := UI.panel(col)
	UI.center(search.get_parent())
	UI.label(search, "Search", 26, UI.ACCENT)
	var spots := ["Barrel", "Crate", "Well", "Haystack"]
	for i in c.chapter.town_finds.size():
		var b := UI.button(search, "Search the %s" % spots[i % spots.size()], func() -> void: _search(i), 560)
		b.disabled = c.flags.get(c.found_key(i), false)
	var back := UI.center(UI.button(col, "Back to camp", func() -> void:
		Audio.play_sfx("cancel")
		Game.goto(Game.Screen.CAMP))) as Button
	default_focus = back
	# Portrait dialogue (doc/03 step 14) under everything, so nothing gets pushed off screen.
	_talk = DialogueBox.create(col, Vector2(1100, 210))
	_talk.waits = false
	UI.center(_talk)
	_talk.visible = true          # keeps its space so the buttons never jump
	_talk.modulate.a = 0.0        # invisible until someone talks or searches
	_talk.advanced.connect(func() -> void: _talk.modulate.a = 0.0)
	for b in talk.get_children():   # start on the first person to talk to
		if b is Button:
			default_focus = b
			break
	UI.focus(default_focus)


func _search(i: int) -> void:
	var item := Game.campaign.search(i)
	_talk.modulate.a = 1.0
	_talk.show_text("Search", "You found %s!" % item.display_name if item else "Nothing here.")
	get_tree().create_timer(1.2).timeout.connect(get_tree().reload_current_scene)
