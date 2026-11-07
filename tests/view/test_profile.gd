extends TestCase
## Step 19: portraits v2 (15 speakers x 5 moods), item icons, bios, and the character profile screen.

const MOODS := ["", "_happy", "_angry", "_hurt", "_determined"]
const RECRUITS := [&"aldric", &"brina", &"corin", &"dara", &"eamon", &"fiora", &"garret", &"hale"]


func _profile(id: StringName) -> Control:
	Game.profile_id = id
	var scr: Control = load("res://view/screens/profile.tscn").instantiate()
	Engine.get_main_loop().root.add_child(scr)
	scr._ready()
	return scr


func _labels(n: Node, out: PackedStringArray) -> PackedStringArray:
	if n is Label:
		out.append((n as Label).text)
	for c in n.get_children():
		_labels(c, out)
	return out


func test_every_speaker_has_five_moods_at_256() -> void:
	var speakers := {}
	var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dialogue/slice.json"))
	for k in lines:
		speakers[lines[k].speaker_id] = true
	for sid: String in speakers:
		for m: String in MOODS:
			var path := "res://assets/textures/portraits/%s%s.png" % [sid, m]
			assert_true(ResourceLoader.exists(path), path)
			if ResourceLoader.exists(path):
				assert_eq((load(path) as Texture2D).get_size(), Vector2(256, 256), path)


func test_recruits_have_a_bio_and_a_look() -> void:
	for id: StringName in RECRUITS:
		var d := Content.unit(id)
		assert_true(d.bio.length() > 40, "%s has a bio" % id)
		assert_true(d.look.length() > 30, "%s has a look line" % id)


func test_every_item_has_an_icon() -> void:
	for f in DirAccess.get_files_at("res://data/items/"):
		if f.ends_with(".tres"):
			assert_true(Art.item_icon(StringName(f.get_basename())) != null, "icon for %s" % f)


func test_profile_opens_for_every_recruit_with_all_fields() -> void:
	Game.change_scenes = false
	Game.new_game()
	for ch in [&"ch02", &"ch03"]:   # recruit everyone
		Game.campaign.chapter = Content.chapter(ch)
		for d in Game.campaign.chapter.recruits_on_start:
			Game.campaign.party.recruit(d)
	Game.campaign.bonds.add(&"aldric", &"brina", 130)
	for u: Unit in Game.campaign.party.roster:
		var scr := _profile(u.data.id)
		assert_eq(scr.unit, u)
		var text := " | ".join(_labels(scr, PackedStringArray()))
		assert_true(text.contains(u.display_name()), "%s: name" % u.data.id)
		assert_true(text.contains(u.class_data.display_name), "%s: class" % u.data.id)
		assert_true(text.contains(u.data.bio), "%s: bio" % u.data.id)
		assert_true(text.contains("ATK") and text.contains("EQUIPMENT") and text.contains("BONDS"), "%s: stats, equipment, bonds" % u.data.id)
		assert_true(scr._portrait.texture != null, "%s: portrait" % u.data.id)
		assert_true(scr.default_focus != null, "%s: focus" % u.data.id)
		scr.free()
	var aldric := _profile(&"aldric")
	assert_true(" ".join(_labels(aldric, PackedStringArray())).contains("♥♥"), "a tier-2 bond shows two hearts")
	aldric.free()
	Game.campaign = null
	Game.change_scenes = true


func test_q_and_e_page_through_the_roster() -> void:
	Game.change_scenes = false
	Game.new_game()
	var roster: Array[Unit] = Game.campaign.party.roster
	var scr := _profile(roster[0].data.id)
	var e := InputEventAction.new()
	e.action = &"rotate_right"
	e.pressed = true
	scr._unhandled_input(e)
	assert_eq(Game.profile_id, roster[1].data.id, "E / RB: next")
	e.action = &"rotate_left"
	scr._unhandled_input(e)
	assert_eq(Game.profile_id, roster[roster.size() - 1].data.id, "Q / LB from the first wraps to the last")
	scr.free()
	Game.campaign = null
	Game.change_scenes = true
