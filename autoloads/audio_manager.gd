extends Node
## Audio singleton: music crossfade, spatial SFX pool, volume control.
## Uses 3 audio buses: Music, SFX, Ambient.
## Falls back to procedural audio when WAV/OGG files are missing.

const CROSSFADE_DURATION := 2.0
const SFX_POOL_SIZE := 8
const FOOTSTEP_INTERVAL := 0.35

# Music tracks (loaded on demand, procedural fallback)
var _music_paths := {
	"calm": "res://assets/audio/music/office_calm.ogg",
	"busy": "res://assets/audio/music/office_busy.ogg",
	"menu": "res://assets/audio/music/menu_theme.ogg",
}

# SFX paths (file-based, with procedural fallback)
var _sfx_paths := {
	"footstep_1": "res://assets/audio/sfx/footstep_1.wav",
	"footstep_2": "res://assets/audio/sfx/footstep_2.wav",
	"ui_click": "res://assets/audio/sfx/ui_click.wav",
	"notification": "res://assets/audio/sfx/notification.wav",
	"conversation_start": "res://assets/audio/sfx/conversation_start.wav",
	"conversation_murmur": "res://assets/audio/sfx/conversation_murmur.wav",
	"conversation_end": "res://assets/audio/sfx/conversation_end.wav",
	"coffee_pour": "res://assets/audio/sfx/coffee_pour.wav",
	"typing": "res://assets/audio/sfx/typing.wav",
	"book_flip": "res://assets/audio/sfx/book_flip.wav",
	"death_sad": "res://assets/audio/sfx/death_sad.wav",
	"romance_chime": "res://assets/audio/sfx/romance_chime.wav",
	"group_formed": "res://assets/audio/sfx/group_formed.wav",
	"achievement": "res://assets/audio/sfx/achievement.wav",
	"heartbreak": "res://assets/audio/sfx/heartbreak.wav",
}

var _music_player_a: AudioStreamPlayer = null
var _music_player_b: AudioStreamPlayer = null
var _active_music_player: AudioStreamPlayer = null
var _current_track: String = ""
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_idx: int = 0
var _sfx_cache: Dictionary = {}  # name -> AudioStream
var _music_cache: Dictionary = {}
var _procedural_sfx: Dictionary = {}  # name -> AudioStreamWAV
var _procedural_music: Dictionary = {}  # name -> AudioStreamWAV


func _ready() -> void:
	_setup_buses()
	_apply_saved_volumes()
	_setup_music_players()
	_setup_sfx_pool()
	_generate_procedural_fallbacks()
	_connect_signals()


func play_music(track_name: String, fade: bool = true) -> void:
	if track_name == _current_track:
		return

	var stream: AudioStream = _get_music_stream(track_name)
	if not stream:
		return

	_current_track = track_name

	if fade and _active_music_player and _active_music_player.playing:
		# Crossfade
		var old_player := _active_music_player
		var new_player := _music_player_b if _active_music_player == _music_player_a else _music_player_a
		_active_music_player = new_player
		new_player.stream = stream
		new_player.volume_db = -40.0
		new_player.play()

		var tween := create_tween()
		tween.set_parallel(true)
		tween.tween_property(old_player, "volume_db", -40.0, CROSSFADE_DURATION)
		tween.tween_property(new_player, "volume_db", 0.0, CROSSFADE_DURATION)
		tween.set_parallel(false)
		tween.tween_callback(func() -> void: old_player.stop())
	else:
		_active_music_player.stream = stream
		_active_music_player.volume_db = 0.0
		_active_music_player.play()


func stop_music(fade: bool = true) -> void:
	_current_track = ""
	if not _active_music_player or not _active_music_player.playing:
		return
	if fade:
		var tween := create_tween()
		var player := _active_music_player
		tween.tween_property(player, "volume_db", -40.0, CROSSFADE_DURATION)
		tween.tween_callback(func() -> void: player.stop())
	else:
		_active_music_player.stop()


func play_sfx(sfx_name: String, volume_db: float = 0.0) -> void:
	var stream: AudioStream = _get_sfx_stream(sfx_name)
	if not stream:
		return
	var player := _sfx_pool[_sfx_pool_idx]
	player.stream = stream
	player.volume_db = volume_db
	player.play()
	_sfx_pool_idx = (_sfx_pool_idx + 1) % SFX_POOL_SIZE


func _get_sfx_stream(sfx_name: String) -> AudioStream:
	# Check cache first
	if _sfx_cache.has(sfx_name):
		return _sfx_cache[sfx_name]
	# Try file-based
	var path: String = _sfx_paths.get(sfx_name, "")
	if path != "" and ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			_sfx_cache[sfx_name] = stream
			return stream
	# Fall back to procedural
	if _procedural_sfx.has(sfx_name):
		_sfx_cache[sfx_name] = _procedural_sfx[sfx_name]
		return _procedural_sfx[sfx_name]
	return null


func _get_music_stream(track_name: String) -> AudioStream:
	if _music_cache.has(track_name):
		return _music_cache[track_name]
	var path: String = _music_paths.get(track_name, "")
	if path != "" and ResourceLoader.exists(path):
		var stream := load(path) as AudioStream
		if stream:
			_music_cache[track_name] = stream
			return stream
	# Procedural fallback
	if _procedural_music.has(track_name):
		_music_cache[track_name] = _procedural_music[track_name]
		return _procedural_music[track_name]
	return null


func _generate_procedural_fallbacks() -> void:
	_procedural_sfx = AudioGenerator.generate_all_sfx()
	_procedural_music["calm"] = AudioGenerator.generate_music_calm()
	# Reuse calm for other tracks (they'll be replaced with real files later)
	_procedural_music["busy"] = _procedural_music["calm"]
	_procedural_music["menu"] = _procedural_music["calm"]


func _apply_saved_volumes() -> void:
	var master: float = SettingsManager.master_volume
	var music: float = SettingsManager.music_volume
	var sfx: float = SettingsManager.sfx_volume
	_set_bus_volume_linear("Master", master)
	_set_bus_volume_linear("Music", music)
	_set_bus_volume_linear("SFX", sfx)


func _set_bus_volume_linear(bus_name: String, linear: float) -> void:
	var idx: int = AudioServer.get_bus_index(bus_name)
	if idx == -1:
		return
	if linear <= 0.01:
		AudioServer.set_bus_mute(idx, true)
	else:
		AudioServer.set_bus_mute(idx, false)
		AudioServer.set_bus_volume_db(idx, linear_to_db(linear))


func _setup_buses() -> void:
	if AudioServer.get_bus_index("Music") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Music")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Music"), "Master")
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "SFX")
		AudioServer.set_bus_send(AudioServer.get_bus_index("SFX"), "Master")
	if AudioServer.get_bus_index("Ambient") == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, "Ambient")
		AudioServer.set_bus_send(AudioServer.get_bus_index("Ambient"), "Master")


func _setup_music_players() -> void:
	_music_player_a = AudioStreamPlayer.new()
	_music_player_a.bus = "Music"
	add_child(_music_player_a)

	_music_player_b = AudioStreamPlayer.new()
	_music_player_b.bus = "Music"
	add_child(_music_player_b)

	_active_music_player = _music_player_a


func _setup_sfx_pool() -> void:
	for i in range(SFX_POOL_SIZE):
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_sfx_pool.append(player)


func _connect_signals() -> void:
	EventBus.conversation_started.connect(func(_a: String, _b: String) -> void:
		play_sfx("conversation_start", -6.0)
	)
	EventBus.conversation_ended.connect(func(_a: String, _b: String) -> void:
		play_sfx("conversation_end", -8.0)
	)
	EventBus.agent_died.connect(func(_name: String, _cause: String) -> void:
		play_sfx("death_sad", -3.0)
	)
	EventBus.confession_made.connect(func(_a: String, _b: String, accepted: bool) -> void:
		if accepted:
			play_sfx("romance_chime", -3.0)
		else:
			play_sfx("heartbreak", -3.0)
	)
	EventBus.group_formed.connect(func(_g: RefCounted) -> void:
		play_sfx("group_formed", -6.0)
	)
	EventBus.object_occupied.connect(func(obj: Node2D, _agent: Node2D) -> void:
		var obj_type: String = obj.get("object_type") if obj.get("object_type") else ""
		match obj_type:
			"coffee_machine": play_sfx("coffee_pour", -6.0)
			"desk": play_sfx("typing", -8.0)
			"bookshelf": play_sfx("book_flip", -6.0)
	)
	EventBus.game_ready.connect(func() -> void:
		play_music("calm")
	)
