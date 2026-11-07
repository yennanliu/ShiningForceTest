extends TestCase
## Step 15: sprites on the 2D map — facing, frames, head icons, poses driven only by events.

const BS := preload("res://view/battle2d/battle_screen.gd")


func _screen(seed := 7) -> Control:
	var scr: Control = load("res://view/battle2d/battle_screen.tscn").instantiate()
	scr.auto_start = false
	scr.animate = false
	Engine.get_main_loop().root.add_child(scr)
	scr.start_battle(seed)
	return scr


func test_facing_follows_the_larger_axis() -> void:
	assert_eq(BS.facing_toward(Vector2(3, 1)), BS.RIGHT)
	assert_eq(BS.facing_toward(Vector2(-2, 1)), BS.LEFT)
	assert_eq(BS.facing_toward(Vector2(1, 4)), BS.DOWN)
	assert_eq(BS.facing_toward(Vector2(0, -1)), BS.UP)
	assert_eq(BS.facing_toward(Vector2.ZERO, BS.LEFT), BS.LEFT, "no direction keeps the old facing")


func test_frame_rect_matches_the_sheet_layout() -> void:
	assert_eq(BS.frame_rect(BS.DOWN, 0), Rect2(0, 0, 48, 64))
	assert_eq(BS.frame_rect(BS.RIGHT, 7), Rect2(336, 128, 48, 64))
	assert_eq(BS.frame_rect(BS.UP, BS.HURT_FRAME), Rect2(384, 192, 48, 64))


func test_every_unit_in_the_slice_has_a_sprite() -> void:
	var scr := _screen()
	for u: Unit in scr.state.units():
		assert_true(Art.sprite_sheet(u.data.id) != null, "%s has a sheet" % u.data.id)
	scr.free()


func test_both_sides_start_facing_each_other() -> void:
	var scr := _screen()   # chapter 1: party bottom-left, enemies top-right
	for u: Unit in scr.state.units():
		var f: int = scr._facing[u.id]
		if u.faction == Enums.Faction.PLAYER:
			assert_true(f == BS.UP or f == BS.RIGHT, "%s faces the enemy" % u.display_name())
		else:
			assert_true(f == BS.DOWN or f == BS.LEFT, "%s faces the party" % u.display_name())
	scr.free()


func test_moving_turns_the_unit_toward_its_last_step() -> void:
	var scr := _screen()
	var actor: Unit = scr.state.current_actor()
	var target := actor.pos + Vector2i(1, 0)
	if not scr._reach.has(target):
		target = actor.pos + Vector2i(0, -1)
	var want := BS.RIGHT if target.x > actor.pos.x else BS.UP
	scr.click_tile(target)
	assert_eq(actor.pos, target)
	assert_eq(scr._facing[actor.id], want)
	assert_true(scr._pose.is_empty(), "walk frames end with the move")
	scr.free()


func test_attack_and_hurt_poses_clear_after_their_events() -> void:
	var scr := _screen()
	var a: Unit = scr.state.living(Enums.Faction.PLAYER)[0]
	var t: Unit = scr.state.living(Enums.Faction.ENEMY)[0]
	var ev: Array[BattleEvent] = [
		BattleEvent.make(BattleEvent.ATTACKED, {"attacker_id": a.id, "target_id": t.id, "hit": true, "crit": false, "counter": false, "double": false, "special": ""}),
		BattleEvent.make(BattleEvent.DAMAGED, {"unit_id": t.id, "amount": 0, "hp_after": t.hp}),
	]
	scr._play(ev)   # animations off: runs straight through
	assert_eq(scr._facing[a.id], BS.facing_toward(Vector2(t.pos - a.pos)))
	assert_eq(scr._facing[t.id], BS.facing_toward(Vector2(a.pos - t.pos)))
	assert_true(scr._pose.is_empty() and scr._hurt.is_empty(), "back to idle afterwards")
	scr.free()


func test_head_icon_priority() -> void:
	var scr := _screen()
	var actor: Unit = scr.state.current_actor()
	var buddy: Unit = null
	for u: Unit in scr.state.living(Enums.Faction.PLAYER):
		if Pathfinder.distance(u.pos, actor.pos) == 1:
			buddy = u
	assert_true(buddy != null, "chapter 1 starts with an ally next to the actor")
	assert_eq(scr.head_icon(buddy), "", "no bond yet")
	scr.state.bonds.add(actor.data.id, buddy.data.id, 100)
	assert_eq(scr.head_icon(buddy), "bond")
	buddy.status[Unit.POISON] = 2
	assert_eq(scr.head_icon(buddy), "poison", "status beats bond")
	buddy.status[Unit.SLEEP] = 1
	assert_eq(scr.head_icon(buddy), "sleep", "sleep beats poison")
	for name in ["poison", "sleep", "adv", "bond", "leader"]:
		assert_true(Art.head_icon(name) != null, "icon file for %s" % name)
	scr.free()
