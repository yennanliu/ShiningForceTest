extends Node
## Music and sound effects (placeholder chiptune from tools/make_audio.py).
## play_music(name) loops a track; play_sfx(name) plays a one-shot. Volumes come from Settings.

const DIR := "res://assets/audio/"

var _music := AudioStreamPlayer.new()
var _sfx: Array[AudioStreamPlayer] = []
var _current := ""
var _cache := {}


func _ready() -> void:
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
	_music.play()


func play_sfx(name: String) -> void:
	if not _music.is_inside_tree():
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
