extends CanvasLayer
## Screen transitions (doc/03 step 18): a short fade to dark and back when Game.goto changes
## screens. Skipped in headless runs and when animations are set to skip.

const OUT := 0.12
const IN := 0.16

var _veil := ColorRect.new()


func _init() -> void:   # transparent from the start, even before _ready
	_veil.color = Color("0c1124")
	_veil.modulate.a = 0.0


func _ready() -> void:
	layer = 90
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_veil)


## Fades to dark (await it before swapping the scene).
func cover() -> void:
	if not UI.motion_ok():
		return
	_veil.mouse_filter = Control.MOUSE_FILTER_STOP
	var tw := create_tween()
	tw.tween_property(_veil, "modulate:a", 1.0, OUT / Settings.anim_speed())
	await tw.finished


## Fades back in.
func reveal() -> void:
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not UI.motion_ok():
		_veil.modulate.a = 0.0
		return
	Audio.play_sfx("open")
	var tw := create_tween()
	tw.tween_property(_veil, "modulate:a", 0.0, IN / Settings.anim_speed())


func is_covering() -> bool:
	return _veil.modulate.a > 0.0
