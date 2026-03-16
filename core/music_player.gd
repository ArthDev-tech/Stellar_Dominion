extends Node
## Background music player. Scans assets/music (and subfolders) for .ogg/.mp3,
## plays through the list. UI lives in game_scene; use play(), pause(), next_track() and playback_state_changed.

signal playback_state_changed(playing: bool)

const MUSIC_DIR := "res://assets/music/"

var _stream_player: AudioStreamPlayer
var _playlist: PackedStringArray = PackedStringArray()
var _current_index: int = -1


func _ready() -> void:
	_build_playlist()
	_stream_player = AudioStreamPlayer.new()
	_stream_player.finished.connect(_on_track_finished)
	add_child(_stream_player)
	set_volume_linear(0.15)  # Default ~15% volume
	play()  # Auto-start on game load (e.g. main menu)


func is_playing() -> bool:
	return _stream_player != null and _stream_player.playing and not _stream_player.stream_paused


func set_volume_linear(linear: float) -> void:
	if _stream_player != null:
		_stream_player.volume_db = linear_to_db(clampf(linear, 0.0, 1.0))


func get_volume_linear() -> float:
	if _stream_player == null:
		return 0.15
	return clampf(db_to_linear(_stream_player.volume_db), 0.0, 1.0)


func _build_playlist() -> void:
	var list: PackedStringArray = _collect_audio_paths(MUSIC_DIR)
	list.sort()
	_playlist = list
	_current_index = -1


func _collect_audio_paths(dir_path: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	var dir: DirAccess = DirAccess.open(dir_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var name: String = dir.get_next()
	while name != "":
		if name.begins_with("."):
			name = dir.get_next()
			continue
		var full: String = dir_path.path_join(name)
		if dir.current_is_dir():
			var sub: PackedStringArray = _collect_audio_paths(full)
			for p in sub:
				out.append(p)
		elif name.get_extension().to_lower() in ["ogg", "mp3"]:
			out.append(full)
		name = dir.get_next()
	dir.list_dir_end()
	return out


func _on_track_finished() -> void:
	_advance_and_play()


func _advance_and_play() -> void:
	if _playlist.is_empty():
		return
	_current_index = (_current_index + 1) % _playlist.size()
	_play_track_at(_current_index)


func _play_track_at(index: int) -> void:
	if index < 0 or index >= _playlist.size():
		return
	var path: String = _playlist[index]
	var stream: AudioStream = load(path) as AudioStream
	if stream == null:
		_advance_and_play()
		return
	_stream_player.stream = stream
	_stream_player.play()
	_current_index = index
	playback_state_changed.emit(true)


func play() -> void:
	if _playlist.is_empty():
		return
	_stream_player.stream_paused = false
	if _stream_player.playing:
		playback_state_changed.emit(true)
		return
	if _current_index < 0 or _current_index >= _playlist.size():
		_current_index = 0
	_play_track_at(_current_index)


func pause() -> void:
	_stream_player.stream_paused = true
	playback_state_changed.emit(false)


func resume() -> void:
	_stream_player.stream_paused = false
	playback_state_changed.emit(true)


func next_track() -> void:
	if _playlist.is_empty():
		return
	_advance_and_play()
