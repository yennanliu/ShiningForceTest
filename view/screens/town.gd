extends Control
## Town (simplified to a menu): talk to townspeople and search hidden spots.

var _said: Label


func _ready() -> void:
	var c: Campaign = Game.campaign
	var col := UI.screen(self, 80)
	UI.center(UI.label(col, c.chapter.town_name, 64, UI.ACCENT))
	var talk := UI.panel(col)
	UI.center(talk.get_parent())
	UI.label(talk, "Talk", 26, UI.ACCENT)
	for id in c.chapter.town_talk:
		var l := Dialogue.line(id)
		UI.button(talk, "Talk to %s" % l.speaker, func() -> void: _said.text = '%s: "%s"' % [l.speaker, l.text], 560)
	var search := UI.panel(col)
	UI.center(search.get_parent())
	UI.label(search, "Search", 26, UI.ACCENT)
	var spots := ["Barrel", "Crate", "Well", "Haystack"]
	for i in c.chapter.town_finds.size():
		var b := UI.button(search, "Search the %s" % spots[i % spots.size()], func() -> void: _search(i), 560)
		b.disabled = c.flags.get(c.found_key(i), false)
	_said = UI.center(UI.label(col, "", 26)) as Label
	_said.autowrap_mode = TextServer.AUTOWRAP_WORD
	_said.custom_minimum_size = Vector2(1100, 0)
	_said.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.center(UI.button(col, "Back to camp", func() -> void: Game.goto(Game.Screen.CAMP)))


func _search(i: int) -> void:
	var item := Game.campaign.search(i)
	_said.text = "You found %s!" % item.display_name if item else "Nothing here."
	get_tree().create_timer(1.2).timeout.connect(get_tree().reload_current_scene)
