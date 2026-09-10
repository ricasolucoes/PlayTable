class_name JogosAdaptiveMusic
extends Node

## Controlador de música adaptativa em camadas verticais sincronizadas.
## Crossfade contínuo entre camadas (ex.: base, ritmo, tensão, clímax) dirigido
## por intensidade de jogo (0.0 a 1.0).
## Generalizado de volta/apps/mobile/src/presentation/audio/adaptive_music.gd.

signal intensity_changed(new_intensity: float)

@export var fade_speed: float = 2.0

var intensity: float = 0.0:
	set(value):
		var clamped: float = clampf(value, 0.0, 1.0)
		if not is_equal_approx(intensity, clamped):
			intensity = clamped
			intensity_changed.emit(intensity)

var _layers: Dictionary = {} # name -> {player: AudioStreamPlayer, min_intensity: float, max_intensity: float, target_db: float}


func add_layer(
	layer_name: String,
	stream: AudioStream,
	min_intensity: float = 0.0,
	max_intensity: float = 1.0,
	base_db: float = 0.0,
	bus: String = "Music"
) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = AudioStreamPlayer.new()
	player.name = "Layer_" + layer_name
	player.stream = stream
	player.bus = bus
	player.volume_db = -80.0
	add_child(player)

	_layers[layer_name] = {
		"player": player,
		"min_intensity": min_intensity,
		"max_intensity": max_intensity,
		"base_db": base_db,
		"target_db": -80.0
	}
	return player


func play_all(from_position: float = 0.0) -> void:
	for name: String in _layers:
		var entry: Dictionary = _layers[name]
		var p: AudioStreamPlayer = entry["player"]
		if not p.playing:
			p.play(from_position)


func stop_all() -> void:
	for name: String in _layers:
		var entry: Dictionary = _layers[name]
		var p: AudioStreamPlayer = entry["player"]
		p.stop()


func _process(delta: float) -> void:
	if _layers.is_empty():
		return

	for name: String in _layers:
		var entry: Dictionary = _layers[name]
		var min_i: float = float(entry["min_intensity"])
		var max_i: float = float(entry["max_intensity"])
		var base_db: float = float(entry["base_db"])
		var p: AudioStreamPlayer = entry["player"]

		# Calcula volume alvo
		var target: float = -80.0
		if intensity >= min_i and intensity <= max_i:
			target = base_db
		elif intensity < min_i and min_i > 0.0:
			var ratio: float = clampf(1.0 - (min_i - intensity) * 4.0, 0.0, 1.0)
			target = lerpf(-80.0, base_db, ratio)
		elif intensity > max_i and max_i < 1.0:
			var ratio: float = clampf(1.0 - (intensity - max_i) * 4.0, 0.0, 1.0)
			target = lerpf(-80.0, base_db, ratio)

		p.volume_db = lerpf(p.volume_db, target, clampf(delta * fade_speed, 0.0, 1.0))
