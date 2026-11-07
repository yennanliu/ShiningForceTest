class_name Settings
## Player settings in user://settings.cfg, plus the input map (keyboard + gamepad).

const PATH := "user://settings.cfg"
const SPEEDS := [1.0, 2.0, 0.0]   # 0 = skip animations

static var music_volume := 0.8
static var sfx_volume := 0.8
static var fullscreen := false
static var anim_speed_index := 0
static var path := PATH


static func anim_speed() -> float:
	return SPEEDS[anim_speed_index]


static func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	music_volume = cfg.get_value("audio", "music", music_volume)
	sfx_volume = cfg.get_value("audio", "sfx", sfx_volume)
	fullscreen = cfg.get_value("video", "fullscreen", fullscreen)
	anim_speed_index = clampi(cfg.get_value("game", "anim_speed", anim_speed_index), 0, SPEEDS.size() - 1)


static func save_settings() -> Error:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("video", "fullscreen", fullscreen)
	cfg.set_value("game", "anim_speed", anim_speed_index)
	return cfg.save(path)


static func apply() -> void:
	if DisplayServer.get_name() == "headless":
		return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)


## Actions used by the battle screen. Added in code so they're easy to read and change.
static func setup_input() -> void:
	var map := {
		"cursor_up": [KEY_UP, JOY_BUTTON_DPAD_UP],
		"cursor_down": [KEY_DOWN, JOY_BUTTON_DPAD_DOWN],
		"cursor_left": [KEY_LEFT, JOY_BUTTON_DPAD_LEFT],
		"cursor_right": [KEY_RIGHT, JOY_BUTTON_DPAD_RIGHT],
		"confirm": [KEY_SPACE, JOY_BUTTON_A],
		"wait": [KEY_W, JOY_BUTTON_B],
		"item": [KEY_I, JOY_BUTTON_X],
		"spell": [KEY_S, JOY_BUTTON_Y],
		"continue": [KEY_ENTER, JOY_BUTTON_START],
	}
	for action: String in map:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		var key := InputEventKey.new()
		key.physical_keycode = map[action][0]
		InputMap.action_add_event(action, key)
		var pad := InputEventJoypadButton.new()
		pad.button_index = map[action][1]
		InputMap.action_add_event(action, pad)
