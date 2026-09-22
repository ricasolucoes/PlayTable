class_name JogosAudioService
extends Node

## Serviço de áudio: buses garantidos, limitador de vozes, SFX registrados,
## música com crossfade por contexto e ducking, pausa em segundo plano.
##
## Fonte: the-war-for-survival/client/scripts/audio/audio_manager.gd (buses,
## limitador 24 vozes / 3 por som, pitch ±5%, pausa/retoma) e
## adaptive_music_controller.gd (troca de contexto com crossfade + ducking).
## Tirado: leitura direta do autoload `Settings` do TWFS (aqui é `AppSettings`
## via JogosLocator, nulo → padrões), camadas verticais de combate e tiers do
## Haven (regra do TWFS), modo "música externa".

signal context_changed(from_context: String, to_context: String)

const BUS_NAMES: Array[String] = ["Master", "Music", "SFX", "Voice", "Notification"]
const MAX_CONCURRENT_VOICES: int = 24
const MAX_INSTANCES_PER_SOUND: int = 3
const PITCH_VARIATION_RANGE: float = 0.05
const DEFAULT_MUSIC_FADE: float = 0.5
## Buses que `sound_enabled=false` silencia; Music obedece a `music_enabled`.
const SFX_BUSES: Array[String] = ["SFX", "Voice", "Notification"]

var _bus_volumes: Dictionary = {
	"Master": 1.0, "Music": 0.8, "SFX": 1.0, "Voice": 1.0, "Notification": 1.0
}
var _sound_enabled: bool = true
var _music_enabled: bool = true
var _active_players: Array[AudioStreamPlayer] = []
var _sound_instance_counts: Dictionary = {}
var _is_paused_for_background: bool = false
var _sfx_library: Dictionary = {}
var _music_library: Dictionary = {}
var _music_current: AudioStreamPlayer = null
var _music_fading_out: AudioStreamPlayer = null
var _current_context: String = ""
var _duck_factor: float = 1.0


func _ready() -> void:
	_ensure_audio_buses()
	_load_from_settings()
	_apply_all_buses()
	var settings: Node = _settings()
	if settings != null and settings.has_signal("changed"):
		settings.connect("changed", _on_setting_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_APPLICATION_PAUSED:
		pause_all_for_background()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_APPLICATION_RESUMED:
		resume_all_from_background()


# ------------------------------------------------------------------ buses


func _ensure_audio_buses() -> void:
	for bus: String in BUS_NAMES:
		if bus == "Master":
			continue
		if AudioServer.get_bus_index(bus) < 0:
			var bus_idx: int = AudioServer.bus_count
			AudioServer.add_bus(bus_idx)
			AudioServer.set_bus_name(bus_idx, bus)
			AudioServer.set_bus_send(bus_idx, "Master")


func set_bus_volume(bus_name: String, volume_linear: float) -> void:
	if not BUS_NAMES.has(bus_name):
		return
	var clamped: float = clampf(volume_linear, 0.0, 1.0)
	_bus_volumes[bus_name] = clamped
	_write_setting("volume_" + bus_name.to_lower(), clamped)
	_apply_bus(bus_name)


func get_bus_volume(bus_name: String) -> float:
	return float(_bus_volumes.get(bus_name, 1.0))


func set_sound_enabled(enabled: bool) -> void:
	_sound_enabled = enabled
	_write_setting("sound_enabled", enabled)
	_apply_all_buses()


func set_music_enabled(enabled: bool) -> void:
	_music_enabled = enabled
	_write_setting("music_enabled", enabled)
	_apply_all_buses()


var sound_enabled: bool:
	get: return _sound_enabled
	set(v): set_sound_enabled(v)

var music_enabled: bool:
	get: return _music_enabled
	set(v): set_music_enabled(v)


func is_sound_enabled() -> bool:
	return _sound_enabled


func is_music_enabled() -> bool:
	return _music_enabled


func _apply_all_buses() -> void:
	for bus: String in BUS_NAMES:
		_apply_bus(bus)


func _apply_bus(bus_name: String) -> void:
	var bus_idx: int = AudioServer.get_bus_index(bus_name)
	if bus_idx < 0:
		return
	var linear: float = get_bus_volume(bus_name)
	var muted: bool = linear <= 0.0001
	if bus_name == "Music" and not _music_enabled:
		muted = true
	if SFX_BUSES.has(bus_name) and not _sound_enabled:
		muted = true
	AudioServer.set_bus_volume_db(bus_idx, linear_to_db(maxf(0.0001, linear)))
	AudioServer.set_bus_mute(bus_idx, muted)


# ------------------------------------------------------------------ SFX


func register_sfx(name: String, stream: AudioStream) -> void:
	_sfx_library[name] = stream


func has_sfx(name: String) -> bool:
	return _sfx_library.has(name)


func has_sound(name: String) -> bool:
	return has_sfx(name)


func play_sound(sound: Variant, opts: Dictionary = {}) -> AudioStreamPlayer:
	return play_sfx(sound, opts)


func play_click() -> AudioStreamPlayer:
	return play_sfx("click")


## `sound` é o nome registrado em `register_sfx` ou um AudioStream direto.
## `opts`: `bus` (String), `db` (float), `pitch` (float; ausente = ±5%
## aleatório), `randomize_pitch` (bool).
func play_sfx(sound: Variant, opts: Dictionary = {}) -> AudioStreamPlayer:
	var sound_id: String = ""
	var stream: AudioStream = null
	if sound is String:
		sound_id = String(sound)
		stream = _sfx_library.get(sound_id, null) as AudioStream
	elif sound is AudioStream:
		stream = sound as AudioStream
		sound_id = stream.resource_path if not stream.resource_path.is_empty() else str(stream.get_instance_id())
	else:
		return null

	_clean_finished_players()
	if _active_players.size() >= MAX_CONCURRENT_VOICES:
		# A voz mais antiga cede: ruído de 25 tiros ninguém distingue, um
		# clique de UI sumindo o jogador percebe.
		var oldest: AudioStreamPlayer = _active_players.pop_front()
		if oldest != null and is_instance_valid(oldest):
			_decrement_sound_count(str(oldest.get_meta("sound_id", "")))
			oldest.stop()
			oldest.queue_free()

	var current_instances: int = int(_sound_instance_counts.get(sound_id, 0))
	if current_instances >= MAX_INSTANCES_PER_SOUND:
		return null

	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	var bus: String = String(opts.get("bus", "SFX"))
	player.bus = bus if BUS_NAMES.has(bus) else "SFX"
	player.stream = stream
	player.volume_db = float(opts.get("db", 0.0))
	player.set_meta("sound_id", sound_id)
	if opts.has("pitch"):
		player.pitch_scale = float(opts["pitch"])
	elif bool(opts.get("randomize_pitch", true)):
		player.pitch_scale = 1.0 + randf_range(-PITCH_VARIATION_RANGE, PITCH_VARIATION_RANGE)
	else:
		player.pitch_scale = 1.0

	add_child(player)
	_active_players.append(player)
	_sound_instance_counts[sound_id] = current_instances + 1
	player.finished.connect(func() -> void: _on_player_finished(player, sound_id))
	if stream != null and not _is_paused_for_background:
		player.play()
	return player


func _on_player_finished(player: AudioStreamPlayer, sound_id: String) -> void:
	_decrement_sound_count(sound_id)
	_active_players.erase(player)
	if is_instance_valid(player):
		player.queue_free()


func _decrement_sound_count(sound_id: String) -> void:
	if sound_id.is_empty():
		return
	var count: int = int(_sound_instance_counts.get(sound_id, 0))
	if count <= 1:
		_sound_instance_counts.erase(sound_id)
	else:
		_sound_instance_counts[sound_id] = count - 1


func _clean_finished_players() -> void:
	var valid_players: Array[AudioStreamPlayer] = []
	for p: AudioStreamPlayer in _active_players:
		if is_instance_valid(p) and p.is_inside_tree():
			valid_players.append(p)
		elif is_instance_valid(p):
			_decrement_sound_count(str(p.get_meta("sound_id", "")))
			p.queue_free()
	_active_players = valid_players


func stop_all_sfx() -> void:
	for p: AudioStreamPlayer in _active_players:
		if is_instance_valid(p):
			p.stop()
			p.queue_free()
	_active_players.clear()
	_sound_instance_counts.clear()


func get_active_voice_count() -> int:
	_clean_finished_players()
	return _active_players.size()


func get_instance_count(sound_id: String) -> int:
	return int(_sound_instance_counts.get(sound_id, 0))


# ------------------------------------------------------------------ música


func register_music(context: String, stream: AudioStream) -> void:
	_music_library[context] = stream


func play_music(stream: AudioStream, fade: float = DEFAULT_MUSIC_FADE) -> void:
	if stream == null:
		stop_music(fade)
		return
	if _music_current != null and is_instance_valid(_music_current) and _music_current.stream == stream:
		return
	var incoming: AudioStreamPlayer = AudioStreamPlayer.new()
	incoming.bus = "Music"
	incoming.stream = stream
	add_child(incoming)
	var outgoing: AudioStreamPlayer = _music_current
	_music_current = incoming
	_fade_player(incoming, -60.0, _music_target_db(), fade, false)
	if not _is_paused_for_background:
		incoming.play()
	if outgoing != null and is_instance_valid(outgoing):
		_fade_player(outgoing, outgoing.volume_db, -60.0, fade, true)


func stop_music(fade: float = DEFAULT_MUSIC_FADE) -> void:
	if _music_current == null or not is_instance_valid(_music_current):
		return
	_fade_player(_music_current, _music_current.volume_db, -60.0, fade, true)
	_music_current = null
	_current_context = ""


func is_music_playing() -> bool:
	return _music_current != null and is_instance_valid(_music_current) and _music_current.playing


## Troca para a música registrada no contexto, com crossfade. Contexto igual
## ou não registrado: nada muda (uma cena que pede "menu" duas vezes não
## reinicia a faixa).
func set_context(context: String, fade: float = 1.0) -> void:
	if context == _current_context:
		return
	if not _music_library.has(context):
		return
	var from_context: String = _current_context
	_current_context = context
	play_music(_music_library[context] as AudioStream, fade)
	context_changed.emit(from_context, context)


func get_current_context() -> String:
	return _current_context


## Abaixa a música por baixo de voz/notificação; `factor` 0..1, 1 = sem duck.
func set_ducking(ducked: bool, factor: float = 0.3, fade: float = 0.2) -> void:
	_duck_factor = clampf(factor, 0.0, 1.0) if ducked else 1.0
	if _music_current != null and is_instance_valid(_music_current):
		_fade_player(_music_current, _music_current.volume_db, _music_target_db(), fade, false)


func get_duck_factor() -> float:
	return _duck_factor


func _music_target_db() -> float:
	return linear_to_db(maxf(0.0001, _duck_factor))


func _fade_player(player: AudioStreamPlayer, from_db: float, to_db: float, seconds: float, free_after: bool) -> void:
	if seconds <= 0.0 or not is_inside_tree():
		player.volume_db = to_db
		if free_after:
			player.stop()
			player.queue_free()
		return
	player.volume_db = from_db
	var tween: Tween = create_tween()
	tween.tween_property(player, "volume_db", to_db, seconds)
	if free_after:
		tween.tween_callback(func() -> void:
			if is_instance_valid(player):
				player.stop()
				player.queue_free())


# ------------------------------------------------------------------ segundo plano


func pause_all_for_background() -> void:
	_is_paused_for_background = true
	for p: AudioStreamPlayer in _active_players:
		if is_instance_valid(p) and p.playing:
			p.stream_paused = true
	if _music_current != null and is_instance_valid(_music_current) and _music_current.playing:
		_music_current.stream_paused = true


func resume_all_from_background() -> void:
	_is_paused_for_background = false
	for p: AudioStreamPlayer in _active_players:
		if is_instance_valid(p) and p.stream_paused:
			p.stream_paused = false
	if _music_current != null and is_instance_valid(_music_current) and _music_current.stream_paused:
		_music_current.stream_paused = false


func is_paused_for_background() -> bool:
	return _is_paused_for_background


# ------------------------------------------------------------------ settings


func _settings() -> Node:
	var node: Node = JogosLocator.autoload(&"AppSettings")
	if node != null and node.has_method("get_value") and node.has_method("set_value"):
		return node
	return null


func _load_from_settings() -> void:
	var settings: Node = _settings()
	if settings == null:
		return
	for bus: String in BUS_NAMES:
		var saved: Variant = settings.call("get_value", "volume_" + bus.to_lower())
		if saved is float or saved is int:
			_bus_volumes[bus] = clampf(float(saved), 0.0, 1.0)
	var sound: Variant = settings.call("get_value", "sound_enabled")
	if sound is bool:
		_sound_enabled = bool(sound)
	var music: Variant = settings.call("get_value", "music_enabled")
	if music is bool:
		_music_enabled = bool(music)


func _write_setting(key: String, value: Variant) -> void:
	var settings: Node = _settings()
	if settings != null:
		settings.call("set_value", key, value)


func _on_setting_changed(key: String, value: Variant) -> void:
	if key == "sound_enabled" and value is bool:
		_sound_enabled = bool(value)
		_apply_all_buses()
	elif key == "music_enabled" and value is bool:
		_music_enabled = bool(value)
		_apply_all_buses()
	elif key.begins_with("volume_") and (value is float or value is int):
		var bus: String = key.trim_prefix("volume_").capitalize()
		if bus == "Sfx":
			bus = "SFX"
		if BUS_NAMES.has(bus):
			_bus_volumes[bus] = clampf(float(value), 0.0, 1.0)
			_apply_bus(bus)
