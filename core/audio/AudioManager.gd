extends Node

var sfx_players: Array[AudioStreamPlayer] = []
const POOL_SIZE = 8
var sound_enabled: bool = true

var _cached_sounds: Dictionary = {}

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p = AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)
	
	_generate_all_sounds()

func _get_free_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]

func play_sound(name: String, volume_db: float = 0.0, pitch_scale: float = 1.0):
	if not sound_enabled or not _cached_sounds.has(name):
		return
	var player = _get_free_player()
	player.stream = _cached_sounds[name]
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()

func play_click():
	play_sound("click", -6.0, randf_range(0.95, 1.05))

func play_chip_drop():
	play_sound("chip_drop", -2.0, randf_range(0.9, 1.1))

func play_piece_place():
	play_sound("piece_place", -3.0, randf_range(0.95, 1.05))

func play_card_flip():
	play_sound("card_flip", -4.0, randf_range(0.9, 1.1))

func play_card_match():
	play_sound("card_match", 0.0, 1.0)

func play_win():
	play_sound("win", 2.0, 1.0)

func play_draw():
	play_sound("draw", -2.0, 1.0)

func _generate_all_sounds():
	_cached_sounds["click"] = _gen_click_sound()
	_cached_sounds["chip_drop"] = _gen_chip_drop_sound()
	_cached_sounds["piece_place"] = _gen_piece_place_sound()
	_cached_sounds["card_flip"] = _gen_card_flip_sound()
	_cached_sounds["card_match"] = _gen_card_match_sound()
	_cached_sounds["win"] = _gen_win_sound()
	_cached_sounds["draw"] = _gen_draw_sound()

func _create_wav_from_floats(samples: Array[float], sample_rate: int = 22050) -> AudioStreamWAV:
	var bytes = PackedByteArray()
	bytes.resize(samples.size())
	for i in range(samples.size()):
		var s = clampf(samples[i], -1.0, 1.0)
		var val = int((s * 127.0) + 128.0)
		bytes[i] = clampi(val, 0, 255)
	
	var wav = AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_8_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav

func _gen_click_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.03) # 30ms
	var samples: Array[float] = []
	samples.resize(length)
	for i in range(length):
		var t = float(i) / float(rate)
		var freq = lerpf(900.0, 250.0, float(i) / float(length))
		var env = exp(-float(i) / (float(rate) * 0.008))
		samples[i] = sin(TAU * freq * t) * env * 0.8
	return _create_wav_from_floats(samples, rate)

func _gen_chip_drop_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.12) # 120ms
	var samples: Array[float] = []
	samples.resize(length)
	for i in range(length):
		var t = float(i) / float(rate)
		var freq = lerpf(550.0, 220.0, float(i) / float(length))
		var env = exp(-float(i) / (float(rate) * 0.025))
		var noise = (randf() * 2.0 - 1.0) * exp(-float(i) / (float(rate) * 0.008)) * 0.3
		var tone = (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.1 * t)) * env * 0.7
		samples[i] = tone + noise
	return _create_wav_from_floats(samples, rate)

func _gen_piece_place_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.09) # 90ms
	var samples: Array[float] = []
	samples.resize(length)
	for i in range(length):
		var t = float(i) / float(rate)
		var freq = lerpf(280.0, 110.0, float(i) / float(length))
		var env = exp(-float(i) / (float(rate) * 0.02))
		var click = (randf() * 2.0 - 1.0) * exp(-float(i) / (float(rate) * 0.005)) * 0.4
		samples[i] = (sin(TAU * freq * t) * env * 0.7) + click
	return _create_wav_from_floats(samples, rate)

func _gen_card_flip_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.07) # 70ms
	var samples: Array[float] = []
	samples.resize(length)
	var prev = 0.0
	for i in range(length):
		var env = sin(float(i) / float(length) * PI)
		var white = randf() * 2.0 - 1.0
		var filtered = prev + 0.25 * (white - prev)
		prev = filtered
		samples[i] = filtered * env * 0.6
	return _create_wav_from_floats(samples, rate)

func _gen_card_match_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.35) # 350ms
	var samples: Array[float] = []
	samples.resize(length)
	var chord = [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
	for i in range(length):
		var t = float(i) / float(rate)
		var sum = 0.0
		for k in range(chord.size()):
			var note_start = float(k) * 0.05
			if t >= note_start:
				var note_t = t - note_start
				var env = exp(-note_t / 0.12)
				sum += sin(TAU * chord[k] * note_t) * env * 0.25
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)

func _gen_win_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.6) # 600ms
	var samples: Array[float] = []
	samples.resize(length)
	var notes = [523.25, 659.25, 783.99, 1046.50, 1318.5] # C5, E5, G5, C6, E6
	for i in range(length):
		var t = float(i) / float(rate)
		var sum = 0.0
		for k in range(notes.size()):
			var note_start = float(k) * 0.08
			if t >= note_start:
				var note_t = t - note_start
				var env = exp(-note_t / 0.2)
				sum += (sin(TAU * notes[k] * note_t) + 0.2 * sin(TAU * notes[k] * 2.0 * note_t)) * env * 0.2
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)

func _gen_draw_sound() -> AudioStreamWAV:
	var rate = 22050
	var length = int(rate * 0.3)
	var samples: Array[float] = []
	samples.resize(length)
	var notes = [392.0, 329.63] # G4, E4
	for i in range(length):
		var t = float(i) / float(rate)
		var sum = 0.0
		for k in range(notes.size()):
			var note_start = float(k) * 0.12
			if t >= note_start:
				var note_t = t - note_start
				var env = exp(-note_t / 0.15)
				sum += sin(TAU * notes[k] * note_t) * env * 0.4
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)
