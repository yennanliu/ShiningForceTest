extends Node
## Music and sound effects (placeholder chiptune from tools/make_audio.py).
## play_music(name) loops a track; play_sfx(name) plays a one-shot. Volumes come from Settings.
##
## Muted while debugging (owner's request, 2026-11-07): every debug run is silent — running from
## source, tools (screenshots, sims), tests. Exported release builds play sound.
##   godot --path . -- --sound     hear it anyway in a debug run
##   ... -- --mute  or  BANNER_MUTE=1   silence any build

const DIR := "res://assets/audio/"

var _music := AudioStreamPlayer.new()
var _sfx: Array[AudioStreamPlayer] = []
var _current := ""
var _cache := {}
## True = nothing plays (the chosen track is still remembered, so screens and tests behave the same).
var muted := false


func _ready() -> void:
	muted = should_mute(OS.is_debug_build(), OS.get_cmdline_user_args(), OS.get_environment("BANNER_MUTE"))
	add_child(_music)
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)


func play_music(name: String) -> void:
	if name == _current or not _music.is_inside_tree():
		return
	_current = name
	var s := _stream("music_" + name)
	if s == null:
		return
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_end = s.data.size() / 2   # 16-bit mono: frames = bytes / 2
	_music.stream = s
	_music.volume_db = linear_to_db(maxf(Settings.music_volume, 0.0001))
	if not muted:
		_music.play()


func play_sfx(name: String) -> void:
	if muted or not _music.is_inside_tree():
		return
	var s := _stream("sfx_" + name)
	if s == null:
		return
	for p in _sfx:
		if not p.playing:
			p.stream = s
			p.volume_db = linear_to_db(maxf(Settings.sfx_volume, 0.0001))
			p.play()
			return


static func should_mute(debug_build: bool, user_args: PackedStringArray, env: String) -> bool:
	if "--mute" in user_args or env == "1":
		return true
	if "--sound" in user_args:
		return false
	return debug_build


## Re-applies volume after the settings change.
func refresh_volume() -> void:
	_music.volume_db = linear_to_db(maxf(Settings.music_volume, 0.0001))


func current_music() -> String:
	return _current


func _stream(key: String) -> AudioStream:
	if not _cache.has(key):
		var path := DIR + key + ".wav"
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]
