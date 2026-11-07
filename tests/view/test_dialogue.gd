extends TestCase
## Steps 13–14: art by id with fallbacks, portrait dialogue box, every line has a face.

const NPCS := ["elder", "smith", "mayor", "child", "hunter"]


func _lines() -> Dictionary:
	return JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/slice.json"))


func _box(parent: Node = null) -> DialogueBox:
	var host: Node = parent if parent != null else Engine.get_main_loop().root
	var b := DialogueBox.create(host, Vector2(1100, 210))
	b.instant = true
	return b


# --- content lint ------------------------------------------------------------------

func test_every_line_has_a_speaker_with_a_portrait() -> void:
	var lines := _lines()
	for id: String in lines:
		var l: Dictionary = lines[id]
		var sid: String = l.get("speaker_id", "")
		assert_true(sid != "", "%s has a speaker_id" % id)
		assert_true(sid == "narrator" or sid in NPCS or Content.unit(StringName(sid)) != null,
			"%s: speaker_id '%s' is a unit, a townsperson or narrator" % [id, sid])
		assert_true(Art.portrait(StringName(sid)) != null, "%s: portrait for '%s'" % [id, sid])
		var mood: String = l.get("mood", "")
		if mood != "":
			assert_true(ResourceLoader.exists(Art.PORTRAITS % ("%s_%s" % [sid, mood])), "%s: %s mood file" % [id, mood])
		assert_true(l.get("side", "") in ["", "enemy"], "%s: side is empty or 'enemy'" % id)


func test_every_map_unit_has_a_sprite_sheet_of_the_right_size() -> void:
	for f in DirAccess.get_files_at("res://data/units/"):
		if not f.ends_with(".tres"):
			continue
		var id := StringName(f.get_basename())
		var t := Art.sprite_sheet(id)
		assert_true(t != null, "sprite sheet for %s" % id)
		if t != null:
			assert_eq(t.get_size(), Vector2(432, 256), "%s: 9x4 frames of 48x64" % id)


func test_missing_art_falls_back_to_null() -> void:
	assert_eq(Art.portrait(&"nobody_at_all"), null)
	assert_eq(Art.portrait(&""), null)
	assert_eq(Art.sprite_sheet(&"nobody_at_all"), null)
	assert_true(Art.portrait(&"aldric", "no_such_mood") != null, "unknown mood falls back to neutral")
	assert_ne(Art.portrait(&"aldric", "angry"), Art.portrait(&"aldric"), "mood file is used when present")


# --- the box ----------------------------------------------------------------------

func test_box_shows_portrait_name_and_text() -> void:
	var b := _box()
	b.show_line(&"ch01_intro")
	assert_true(b.visible)
	assert_true(b.has_portrait())
	assert_eq(b.text_shown(), Dialogue.line(&"ch01_intro").text)
	assert_false(b.is_typing(), "instant mode shows the whole line")
	b.free()


func test_enemy_lines_put_the_portrait_on_the_right_mirrored() -> void:
	var b := _box()
	b.show_line(&"chief_intro")
	assert_eq(b._portrait_frame.get_index(), b._row.get_child_count() - 1, "portrait last = right side")
	assert_true(b._portrait.flip_h)
	b.show_line(&"ch01_intro")
	assert_eq(b._portrait_frame.get_index(), 0, "player portrait back on the left")
	assert_false(b._portrait.flip_h)
	b.free()


func test_free_text_without_a_portrait_hides_the_frame() -> void:
	var b := _box()
	b.show_text("Search", "You found Herb!")
	assert_false(b.has_portrait())
	assert_eq(b.text_shown(), "You found Herb!")
	b.free()


func test_confirm_finishes_typing_then_advances() -> void:
	var b := _box()
	var advanced := [0]
	b.advanced.connect(func() -> void: advanced[0] += 1)
	b._typing = true   # as if the text were still typing out
	b.confirm()
	assert_false(b.is_typing(), "first confirm finishes the text")
	assert_eq(advanced[0], 0, "and does not skip the line")
	b.confirm()
	assert_eq(advanced[0], 1, "second confirm advances")
	b.free()


func test_say_returns_at_once_in_instant_mode() -> void:
	var b := _box()
	b.say(&"ch02_intro")   # would wait for input if not instant; returning proves it doesn't
	assert_eq(b.line_id, &"ch02_intro")
	b.free()


# --- screens fit at 1920x1080 ----------------------------------------------------------

func test_camp_and_town_dialogue_fit_on_screen() -> void:
	Game.change_scenes = false
	Game.new_game()   # chapter 1: four join lines, a town
	var camp: Control = load("res://view/screens/camp.tscn").instantiate()
	Engine.get_main_loop().root.add_child(camp)
	camp._ready()
	var talk: DialogueBox = camp._talk
	assert_true(talk.visible, "join lines show on arrival")
	assert_eq(talk.line_id, &"join_aldric")
	assert_true(Rect2(0, 0, 1920, 1080).encloses(Rect2(talk.position, talk.size)))
	talk.confirm()
	assert_eq(talk.line_id, &"join_brina", "click the box for the next join line")
	camp.free()
	var town: Control = load("res://view/screens/town.tscn").instantiate()
	Engine.get_main_loop().root.add_child(town)
	town._ready()
	var col: Control = town._talk.get_parent()
	assert_true(col.position.y + col.get_combined_minimum_size().y <= 1080, "town column (with the box) fits in 1080 px")
	town.free()
	Game.campaign = null
	Game.change_scenes = true
