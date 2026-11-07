class_name Map3D
extends SubViewportContainer
## 3D isometric battle map with sprite billboards (doc/03 step 17, doc/05 §2).
## A renderer only: the battle screen still owns input, HUD and event playback, and this view
## reads the same unit positions / facings / poses it animates (`screen._unit_px`, `_facing`, ...).
## The map is boxes per tile (height you can see) with pixel-art tops; units are Sprite3D
## billboards standing on a faction base. Camera: 4 rotations, 3 zooms, top-down toggle.
## Any tile that would hide a unit from the camera is faded (wall fade).

const H_STEP := 0.5          # world height per map height level
const WALL_TOP := 1.6
const WATER_TOP := {&"shallow": -0.08, &"deep": -0.16}
const BASE_Y := -0.7         # bottom of every tile box
const SPRITE_H := 1.15       # in tiles (doc/05 §7)
const ZOOMS := [1.0, 0.72, 0.5]
const PITCH := -35.0
const TOP_PITCH := -88.0
const FADE_ALPHA := 0.28
const COLORS := {
	&"plain": Color("7cb35a"), &"forest": Color("3f7f3a"), &"hill": Color("b08e5c"),
	&"sand": Color("d9c48a"), &"shallow": Color("5aa0d8"), &"deep": Color("2f5f9e"), &"wall": Color("6b6b6b"),
}

var screen: Node             # the battle screen
var yaw_index := 0           # 0..3, 90 degrees each
var zoom_index := 0
var top_down := false
var faded: Dictionary = {}   # tile -> true while faded

var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _size := Vector2i(1, 1)
var _top := {}               # tile -> top height
var _boxes := {}             # tile -> AABB (for picking and fading)
var _side_mats := {}         # tile -> its side material (fades with the top)
var _top_mats := {}
var _units := {}             # unit id -> {sprite, base, shadow}
var _marks: Array[MeshInstance3D] = []
var _ring: MeshInstance3D
var _chests: Array[MeshInstance3D] = []
var _mat_cache := {}


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE   # the battle screen handles the mouse
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	add_child(_vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("161a24")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 1, 1)
	env.environment.ambient_light_energy = 0.55
	_vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 0.9
	_vp.add_child(sun)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.far = 200.0
	_vp.add_child(_cam)
	_root = Node3D.new()
	_vp.add_child(_root)


## Builds the tiles and decorations for `state.map` (once per battle).
func build(state: BattleState) -> void:
	for c in _root.get_children():
		c.free()
	_units.clear()
	_marks.clear()
	_chests.clear()
	_top.clear()
	_boxes.clear()
	_side_mats.clear()
	_top_mats.clear()
	faded.clear()
	var g := state.grid
	_size = g.size
	for y in g.size.y:
		for x in g.size.x:
			_build_tile(g, Vector2i(x, y))
	_ring = _mesh(_torus(0.36, 0.46), _flat(Color("ffd34a")))
	_ring.visible = false
	_update_camera()


func _build_tile(g: Grid, t: Vector2i) -> void:
	var id := g.terrain(t).id
	var top: float = WALL_TOP if id == &"wall" else WATER_TOP.get(id, g.height(t) * H_STEP)
	_top[t] = top
	var col: Color = COLORS.get(id, Color.MAGENTA)
	var side := StandardMaterial3D.new()
	side.albedo_color = col.darkened(0.35)
	_side_mats[t] = side
	var box := BoxMesh.new()
	box.size = Vector3(1, top - BASE_Y, 1)
	var bi := _mesh(box, side)
	bi.position = Vector3(t.x, (top + BASE_Y) / 2.0, t.y)
	_boxes[t] = AABB(Vector3(t.x - 0.5, BASE_Y, t.y - 0.5), Vector3(1, top - BASE_Y, 1))
	var lid := StandardMaterial3D.new()
	var tex_path := "res://assets/textures/tiles/%s.png" % id
	if ResourceLoader.exists(tex_path):
		lid.albedo_texture = load(tex_path)
		lid.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	else:
		lid.albedo_color = col
	if (t.x + t.y) % 2 == 1:   # a faint checker so the grid reads at a glance
		lid.albedo_color = Color(0.93, 0.93, 0.93)
	_top_mats[t] = lid
	var plane := PlaneMesh.new()
	plane.size = Vector2(1, 1)
	var pi := _mesh(plane, lid)
	pi.position = Vector3(t.x, top + 0.002, t.y)
	pi.set_meta("tile", t)
	bi.set_meta("tile", t)
	if id == &"forest":   # three small trees, deterministic spots
		for k in 3:
			var off := Vector2(((t.x * 7 + t.y * 3 + k * 5) % 5 - 2) * 0.13, (k - 1) * 0.28)
			var tree := CylinderMesh.new()
			tree.top_radius = 0.0
			tree.bottom_radius = 0.17
			tree.height = 0.55
			var ti := _mesh(tree, _shaded(Color("2f6a33")))
			ti.position = Vector3(t.x + off.x, top + 0.3, t.y + off.y)
			ti.set_meta("tile", t)


## Re-reads everything the battle screen animates. Called whenever it redraws.
func sync() -> void:
	if screen == null or screen.state == null:
		return
	var state: BattleState = screen.state
	_update_camera()
	var actor := state.current_actor()
	_ring.visible = false
	for u in state.units():
		var parts: Dictionary = _units.get(u.id, {})
		if parts.is_empty():
			parts = _make_unit(u)
			_units[u.id] = parts
		var alive := u.is_alive()
		for k in parts:
			(parts[k] as Node3D).visible = alive
		if not alive:
			continue
		var w := world_of_px(screen._unit_px.get(u.id, Vector2.ZERO), u.pos)
		(parts.base as Node3D).position = w + Vector3(0, 0.02, 0)
		(parts.shadow as Node3D).position = w + Vector3(0, 0.01, 0)
		var spr: Sprite3D = parts.sprite
		spr.position = w
		# Upright billboards in the angled view; facing the camera fully from above (top-down).
		spr.billboard = BaseMaterial3D.BILLBOARD_ENABLED if top_down else BaseMaterial3D.BILLBOARD_FIXED_Y
		if top_down:   # from above the sprite would lie flat on its base: lift it over the base
			spr.position = w + Vector3(0, 0.5, 0)
		if spr.texture != null:
			var row := screen_facing(screen._facing.get(u.id, 0))
			spr.region_rect = screen.frame_rect(row, screen._frame(u))
		spr.modulate = Color(1, 0.5, 0.5) if screen._hurt.has(u.id) else Color.WHITE
		if u == actor:
			_ring.visible = true
			_ring.position = w + Vector3(0, 0.03, 0)
	_sync_marks(state)
	_fade(state)


## Grid facing (battle screen DOWN/LEFT/RIGHT/UP) -> sheet row as seen from the camera.
func screen_facing(facing: int) -> int:
	var f: Vector2 = [Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)][facing]
	var right := Vector2(_cam.basis.x.x, _cam.basis.x.z)
	var back := Vector2(_cam.basis.z.x, _cam.basis.z.z)
	return screen.facing_toward(Vector2(f.dot(right), f.dot(back)), facing)


## A unit's animated pixel position (2D layout) -> its feet in the 3D world.
func world_of_px(px: Vector2, fallback: Vector2i) -> Vector3:
	var gx := fallback.x as float
	var gy := fallback.y as float
	if screen.TILE > 0 and px != Vector2.ZERO:
		var g: Vector2 = (px - screen.MAP_ORIGIN) / screen.TILE - Vector2(0.5, 0.5)
		gx = g.x
		gy = g.y
	var t := Vector2i(clampi(roundi(gx), 0, _size.x - 1), clampi(roundi(gy), 0, _size.y - 1))
	return Vector3(gx, maxf(_top.get(t, 0.0), 0.0), gy)


## Top of a unit's head, seen from the camera (straight up, or "screen up" when top-down).
func head_of(feet: Vector3) -> Vector3:
	var up := _cam.basis.y if top_down else Vector3.UP
	return feet + up * SPRITE_H * 0.85


func tile_world(t: Vector2i) -> Vector3:
	return Vector3(t.x, maxf(_top.get(t, 0.0), 0.0), t.y)


## World point -> battle-screen pixel (for HP bars, icons, popups drawn over the 3D view).
## Orthographic projection done by hand (same as Godot's, keep-height), so it also works in
## headless tests where the camera isn't in a running scene tree.
func to_screen(w: Vector3) -> Vector2:
	var l := _cam.transform.affine_inverse() * w
	var view := _view_size()
	var h := _cam.size
	var wd := h * view.x / view.y
	return position + Vector2((l.x / wd + 0.5) * view.x, (-l.y / h + 0.5) * view.y)


func _view_size() -> Vector2:
	return size if size.x > 0 and size.y > 0 else Vector2(1040, 960)


## Screen pixels per world unit at the current zoom (the "tile size" for the HUD).
func px_per_unit() -> float:
	return _view_size().y / _cam.size if _cam.size > 0 else 48.0


## Battle-screen pixel -> the tile under it (nearest tile box the camera ray hits).
func pick(screen_px: Vector2) -> Vector2i:
	var view := _view_size()
	var local := screen_px - position
	var h := _cam.size
	var wd := h * view.x / view.y
	var cam_local := Vector3((local.x / view.x - 0.5) * wd, -(local.y / view.y - 0.5) * h, 0.0)
	var from := _cam.transform * cam_local
	var dir := -_cam.basis.z
	var best := Vector2i(-1, -1)
	var best_d := INF
	for t: Vector2i in _boxes:
		var hit: Variant = (_boxes[t] as AABB).intersects_ray(from, dir)
		if hit != null:
			var d := from.distance_to(hit)
			if d < best_d:
				best_d = d
				best = t
	return best


func rotate_view(step: int) -> void:
	yaw_index = posmod(yaw_index + step, 4)
	_update_camera()


func cycle_zoom() -> void:
	zoom_index = (zoom_index + 1) % ZOOMS.size()
	_update_camera()


func zoom_by(step: int) -> void:
	zoom_index = clampi(zoom_index + step, 0, ZOOMS.size() - 1)
	_update_camera()


func toggle_top_down() -> void:
	top_down = not top_down
	_update_camera()


## Arrow keys move the cursor in screen directions: turn them with the camera. Picks the grid
## direction that looks most like `dir` on screen (a 10° bias breaks the 45° tie the same way
## at every angle, so the mapping turns with the camera).
func screen_dir_to_grid(dir: Vector2i) -> Vector2i:
	var want := Vector2(dir).rotated(deg_to_rad(10.0))
	var origin := to_screen(Vector3.ZERO)
	var best := Vector2i.ZERO
	var best_dot := -INF
	for g: Vector2i in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
		var on_screen := (to_screen(Vector3(g.x, 0, g.y)) - origin).normalized()
		var d := on_screen.dot(want)
		if d > best_dot:
			best_dot = d
			best = g
	return best


## Units the camera can't see (a tile box in the way that isn't faded). Empty = all visible.
func hidden_units(state: BattleState) -> Array[int]:
	var out: Array[int] = []
	for u in state.living():
		if not _occluders(u.pos, tile_world(u.pos), true).is_empty():
			out.append(u.id)
	return out


func camera() -> Camera3D:
	return _cam


# --- internals -----------------------------------------------------------------------------

func _update_camera() -> void:
	var yaw := (0.0 if top_down else 45.0) + 90.0 * yaw_index   # top-down lines up with the grid, like 2D
	_cam.rotation_degrees = Vector3(TOP_PITCH if top_down else PITCH, yaw, 0)
	# Fit: the whole map (all box corners) inside the view at this angle, with a margin.
	var basis := _cam.basis
	var inv := basis.inverse()
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var top := 0.0
	for t in _top:
		top = maxf(top, _top[t])
	for x in [-0.5, _size.x - 0.5]:
		for z in [-0.5, _size.y - 0.5]:
			for y in [BASE_Y, top + SPRITE_H]:
				var l := inv * Vector3(x, y, z)
				lo = Vector2(minf(lo.x, l.x), minf(lo.y, l.y))
				hi = Vector2(maxf(hi.x, l.x), maxf(hi.y, l.y))
	var aspect := _view_size().x / _view_size().y
	var fit := maxf(hi.y - lo.y, (hi.x - lo.x) / aspect) * 1.04
	var mid := (lo + hi) / 2.0
	var center := basis * Vector3(mid.x, mid.y, 0.0)
	if zoom_index > 0 and screen != null and screen.state != null and screen.state.grid.in_bounds(screen._hover):
		var focus := tile_world(screen._hover)
		var f := inv * focus
		center = center.lerp(basis * Vector3(f.x, f.y, 0.0), 0.7)
	_cam.size = fit * ZOOMS[zoom_index]
	_cam.position = center + basis.z * 40.0


func _make_unit(u: Unit) -> Dictionary:
	var player := u.faction == Enums.Faction.PLAYER
	var shadow := _mesh(_disc(0.4, 24), _flat(Color(0, 0, 0, 0.35)))
	# Faction base (doc/05 §7): light round ring for players, dark diamond for enemies.
	var base: MeshInstance3D
	if player:
		base = _mesh(_torus(0.26, 0.37), _flat(Color("3b6fd8").lightened(0.5)))
	else:
		base = _mesh(_disc(0.44, 4), _flat(Color("c8423a").darkened(0.35)))
	var spr := Sprite3D.new()
	var tex := Art.sprite_sheet(u.data.id)
	if tex != null:
		spr.texture = tex
		spr.region_enabled = true
		spr.region_rect = Rect2(0, 0, 48, 64)
		spr.pixel_size = SPRITE_H / 64.0
		spr.offset = Vector2(0, 28)   # feet (row 60 of 64) on the node's origin
	else:   # no sheet: a plain team-colored card
		var img := Image.create(8, 12, false, Image.FORMAT_RGBA8)
		img.fill(Color("3b6fd8") if player else Color("c8423a"))
		spr.texture = ImageTexture.create_from_image(img)
		spr.pixel_size = SPRITE_H / 12.0
		spr.offset = Vector2(0, 6)
	spr.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	spr.shaded = false
	spr.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	spr.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	_root.add_child(spr)
	return {"sprite": spr, "base": base, "shadow": shadow}


func _sync_marks(state: BattleState) -> void:
	var want: Array = []   # [tile, color]
	for t: Vector2i in screen._reach:
		if state.grid.unit_at(t) == null:
			want.append([t, Color(0.35, 0.65, 1.0, 0.5)])
	for id in screen._targets:
		want.append([state.unit(id).pos, Color(1.0, 0.25, 0.2, 0.55)])
	if state.grid.in_bounds(screen._hover):
		want.append([screen._hover, Color(1, 1, 1, 0.45)])
	while _marks.size() < want.size():
		var plane := PlaneMesh.new()
		plane.size = Vector2(0.94, 0.94)
		_marks.append(_mesh(plane, _flat(Color.WHITE)))
	for i in _marks.size():
		var m := _marks[i]
		m.visible = i < want.size()
		if m.visible:
			var t: Vector2i = want[i][0]
			m.position = Vector3(t.x, _top.get(t, 0.0) + 0.012 + i * 0.0001, t.y)
			(m.material_override as StandardMaterial3D).albedo_color = want[i][1]
	var chests := MapScript.open_chests(state)
	while _chests.size() < chests.size():
		var box := BoxMesh.new()
		box.size = Vector3(0.36, 0.26, 0.26)
		_chests.append(_mesh(box, _shaded(Color("8a5a2b"))))
	for i in _chests.size():
		_chests[i].visible = i < chests.size()
		if _chests[i].visible:
			var t: Vector2i = chests[i]
			_chests[i].position = Vector3(t.x, _top.get(t, 0.0) + 0.13, t.y)


## Wall fade: any tile between a unit and the camera turns see-through.
func _fade(state: BattleState) -> void:
	var now := {}
	for u in state.living():
		for t in _occluders(u.pos, world_of_px(screen._unit_px.get(u.id, Vector2.ZERO), u.pos), false):
			now[t] = true
	for t in faded.keys():
		if not now.has(t):
			_set_alpha(t, 1.0)
	for t in now:
		if not faded.has(t):
			_set_alpha(t, FADE_ALPHA)
	faded = now


## Tiles whose boxes cross the line from a unit (feet, middle, head) toward the camera.
func _occluders(own: Vector2i, feet: Vector3, skip_faded: bool) -> Array[Vector2i]:
	var back := _cam.basis.z.normalized()
	var out: Array[Vector2i] = []
	for h in [0.15, SPRITE_H * 0.5, SPRITE_H * 0.9]:
		var p := feet + Vector3(0, h, 0)
		for t: Vector2i in _boxes:
			if t == own or out.has(t) or (skip_faded and faded.has(t)):
				continue
			if (_boxes[t] as AABB).intersects_segment(p, p + back * 60.0):
				out.append(t)
	return out


func _set_alpha(t: Vector2i, a: float) -> void:
	for m: StandardMaterial3D in [_side_mats[t], _top_mats[t]]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if a < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color.a = a
	for c in _root.get_children():   # trees on that tile fade too
		if c is MeshInstance3D and c.get_meta("tile", Vector2i(-1, -1)) == t and c.mesh is CylinderMesh:
			c.visible = a >= 1.0


func _mesh(m: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_root.add_child(mi)
	return mi


func _flat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _shaded(c: Color) -> StandardMaterial3D:
	if not _mat_cache.has(c):
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		_mat_cache[c] = m
	return _mat_cache[c]


static func _disc(r: float, segments: int) -> CylinderMesh:
	var d := CylinderMesh.new()
	d.top_radius = r
	d.bottom_radius = r
	d.height = 0.02
	d.radial_segments = segments
	return d


static func _torus(inner: float, outer: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = inner
	t.outer_radius = outer
	t.rings = 24
	t.ring_segments = 6
	return t
