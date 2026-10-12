extends Node

const SFX_BUS := "SFX"
const MUSIC_BUS := "Music"

var _music_player: AudioStreamPlayer
var _sfx_streams: Dictionary = {}
var _music_streams: Dictionary = {}


func _ready() -> void:
	_music_player = AudioStreamPlayer.new()
	_music_player.bus = MUSIC_BUS
	add_child(_music_player)
	_apply_volume_settings()


func play_sfx(name: String) -> void:
	var stream: AudioStream = _sfx_streams.get(name)
	if stream == null:
		stream = _try_load_stream("res://assets/audio/sfx/%s.ogg" % name)
		if stream == null:
			stream = _try_load_stream("res://assets/audio/sfx/%s.wav" % name)
		if stream != null:
			_sfx_streams[name] = stream

	if stream == null:
		return

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = SFX_BUS
	player.volume_db = _get_bus_volume_db(SFX_BUS)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()


func play_music(name: String) -> void:
	var stream: AudioStream = _music_streams.get(name)
	if stream == null:
		stream = _try_load_stream("res://assets/audio/music/%s.ogg" % name)
		if stream == null:
			stream = _try_load_stream("res://assets/audio/music/%s.wav" % name)
		if stream != null:
			_music_streams[name] = stream

	if stream == null:
		return

	_music_player.stream = stream
	_music_player.volume_db = _get_bus_volume_db(MUSIC_BUS)
	_music_player.play()


func stop_music() -> void:
	if _music_player.playing:
		_music_player.stop()


func _apply_volume_settings() -> void:
	if not SaveManager or SaveManager.data == null:
		return

	_set_bus_volume(SFX_BUS, SaveManager.data.sfx_volume)
	_set_bus_volume(MUSIC_BUS, SaveManager.data.music_volume)


func _set_bus_volume(bus_name: String, linear_volume: float) -> void:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return
	AudioServer.set_bus_volume_db(bus_index, linear_to_db(clampf(linear_volume, 0.0, 1.0)))


func _get_bus_volume_db(bus_name: String) -> float:
	var bus_index := AudioServer.get_bus_index(bus_name)
	if bus_index < 0:
		return 0.0
	return AudioServer.get_bus_volume_db(bus_index)


func _try_load_stream(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path) as AudioStream
