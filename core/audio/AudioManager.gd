extends Node

## Som do aplicativo: efeitos sintetizados e musica de fundo gerada.
##
## Nao ha um unico arquivo de audio neste repositorio. Os efeitos sao
## sintetizados aqui no boot (dez a quinze sons curtos, em 16 bits), e a musica
## de fundo e renderizada por `MusicSynth` numa thread quando a tela pede um
## clima -- livre de licenca porque nasce no proprio aplicativo, e bem baixa
## (`MUSIC_DB`) porque e fundo, nao trilha.
##
## Som e musica tem chaves proprias, gravadas no SaveManager: a pessoa que
## desliga a musica quer os efeitos, e vice-versa.

const POOL_SIZE := 8

## Volume da musica de fundo. -21 dB e "bem baixinho": presente numa sala em
## silencio, inaudivel por cima de uma conversa.
const MUSIC_DB := -21.0
const MUSIC_FADE := 1.2

const CHAVE_SOM := "sound_enabled"
const CHAVE_MUSICA := "music_enabled"

## Audio em arquivo, opcional (ver core/audio/AUDIO_LICENSES.md). Quando o
## arquivo existe e esta importado ele substitui a sintese de mesmo nome; quando
## nao existe, nada muda. `load()` em tempo de execucao, nunca `preload()`: o
## preload de um arquivo ausente derruba a compilacao do autoload inteiro.
const MUSICA_ARQUIVO := "res://core/audio/music.mp3"
const EFEITOS_ARQUIVO := {
	"click": "res://core/audio/click.mp3",
	"chip_drop": "res://core/audio/chip_place.mp3",
	"piece_place": "res://core/audio/piece_place.mp3",
	"card_flip": "res://core/audio/card_flip.mp3",
	"win": "res://core/audio/win.mp3",
	"lose": "res://core/audio/lose.mp3",
	"explosion": "res://core/audio/explosion.mp3",
	"splash": "res://core/audio/splash.mp3",
	"capture": "res://core/audio/capture.mp3",
	"shuffle": "res://core/audio/shuffle.mp3",
	"error": "res://core/audio/error.mp3",
	"flag": "res://core/audio/flag.mp3",
}
## Alguns arquivos sao series (26 s de viradas de carta, 16 s de respingos);
## no jogo so o primeiro evento interessa. Em segundos.
const DURACAO_MAXIMA := {
	"card_flip": 0.5, "splash": 1.3, "error": 0.7, "flag": 0.6, "shuffle": 1.2,
}

var sfx_players: Array[AudioStreamPlayer] = []

var sound_enabled: bool = true:
	set(v):
		sound_enabled = v
		_gravar(CHAVE_SOM, v)

var music_enabled: bool = true:
	set(v):
		music_enabled = v
		_gravar(CHAVE_MUSICA, v)
		if v:
			if _mood_pedido != "":
				play_music(_mood_pedido)
		else:
			_parar_musica_agora()

var _cached_sounds: Dictionary = {}

## Musica: um player, um clima por vez, e os loops ja renderizados por clima.
var _music_player: AudioStreamPlayer = null
var _music_cache: Dictionary = {}          # mood -> AudioStreamWAV
var _mood_tocando: String = ""
var _mood_pedido: String = ""
var _thread: Thread = null
var _thread_mood: String = ""
var _fade: Tween = null

signal music_changed(mood: String)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(POOL_SIZE):
		var p := AudioStreamPlayer.new()
		add_child(p)
		sfx_players.append(p)

	_music_player = AudioStreamPlayer.new()
	_music_player.name = "Music"
	_music_player.volume_db = MUSIC_DB
	add_child(_music_player)

	_carregar_preferencias()
	_generate_all_sounds()
	# A primeira tela nao passa pelo SceneManager; quando ela existir, pede o
	# clima dela.
	_musica_da_cena_inicial.call_deferred()


func _musica_da_cena_inicial() -> void:
	if not is_inside_tree():
		return
	var cena := get_tree().current_scene
	if cena != null:
		play_music_for_scene(cena)


func _exit_tree() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
		_thread = null


# ------------------------------------------------------------------ ajustes

func _carregar_preferencias() -> void:
	if SaveManager == null:
		return
	sound_enabled = bool(SaveManager.get_setting(CHAVE_SOM, true))
	music_enabled = bool(SaveManager.get_setting(CHAVE_MUSICA, true))


func _gravar(chave: String, valor: bool) -> void:
	if SaveManager != null and is_inside_tree():
		SaveManager.set_setting(chave, valor)


# ------------------------------------------------------------------- efeitos

func _get_free_player() -> AudioStreamPlayer:
	for p in sfx_players:
		if not p.playing:
			return p
	return sfx_players[0]


func play_sound(name: String, volume_db: float = 0.0, pitch_scale: float = 1.0) -> void:
	if not sound_enabled or not _cached_sounds.has(name):
		return
	var player := _get_free_player()
	player.stream = _cached_sounds[name]
	player.volume_db = volume_db
	player.pitch_scale = pitch_scale
	player.play()
	if DURACAO_MAXIMA.has(name) and is_file_backed(name) and is_inside_tree():
		var stream: AudioStream = player.stream
		get_tree().create_timer(float(DURACAO_MAXIMA[name])).timeout.connect(func() -> void:
			if is_instance_valid(player) and player.stream == stream:
				player.stop())


func has_sound(name: String) -> bool:
	return _cached_sounds.has(name)


func play_click() -> void:
	play_sound("click", -8.0, randf_range(0.96, 1.04))

func play_chip_drop() -> void:
	play_sound("chip_drop", -3.0, randf_range(0.9, 1.1))

func play_piece_place() -> void:
	play_sound("piece_place", -3.0, randf_range(0.95, 1.05))

func play_card_flip() -> void:
	play_sound("card_flip", -5.0, randf_range(0.9, 1.1))

func play_card_match() -> void:
	play_sound("card_match", -1.0, 1.0)

func play_win() -> void:
	play_sound("win", 0.0, 1.0)

## Fim de partida perdida: dois tons que descem, curtos e sem drama.
func play_lose() -> void:
	play_sound("lose", -3.0, 1.0)

## A escada subiu: arpejo rapido para cima, distinto da fanfarra da vitoria.
func play_level_up() -> void:
	play_sound("level_up", -2.0, 1.0)

func play_explosion() -> void:
	play_sound("explosion", 0.0, randf_range(0.92, 1.08))

func play_splash() -> void:
	play_sound("splash", -4.0, randf_range(0.92, 1.08))

func play_capture() -> void:
	play_sound("capture", -2.0, randf_range(0.96, 1.04))

func play_draw() -> void:
	play_sound("draw", -2.0, 1.0)

## Dados rolando: tres a cinco batidas secas.
func play_dice() -> void:
	play_sound("dice", -4.0, randf_range(0.9, 1.1))

## Baralho embaralhado: rajada de viradas.
func play_shuffle() -> void:
	play_sound("shuffle", -6.0, randf_range(0.95, 1.05))

## Jogada recusada: zumbido grave e curto.
func play_error() -> void:
	play_sound("error", -6.0, 1.0)

## Bandeira ou marca posta: "plim" agudo e curto.
func play_flag() -> void:
	play_sound("flag", -6.0, randf_range(0.97, 1.03))


# -------------------------------------------------------------------- musica

## Pede um clima (`MusicSynth.MOODS`). Se o loop ja foi renderizado, troca com
## fade; senao renderiza numa thread e comeca quando ficar pronto. Nao faz nada
## em modo headless: nao ha saida de audio e a suite nao precisa da thread.
func play_music(mood: String) -> void:
	if not MusicSynth.is_mood(mood):
		return
	_mood_pedido = mood
	if not music_enabled or DisplayServer.get_name() == "headless":
		return
	if _mood_tocando == mood and _music_player.playing:
		return
	if _music_cache.has(mood):
		_tocar(mood)
		return
	# A faixa em arquivo, quando existe e esta importada, vale para todos os
	# climas; sem ela, o clima e sintetizado.
	var faixa := _carregar_faixa()
	if faixa != null:
		_music_cache[mood] = faixa
		_tocar(mood)
		return
	_renderizar(mood)


## A musica de fundo em arquivo (`MUSICA_ARQUIVO`), ou null quando o arquivo
## nao existe ou ainda nao foi importado. `load()` e nao `preload()`: o preload
## de um arquivo ausente ou nao importado e erro de compilacao do script
## inteiro, e o AudioManager e autoload -- o aplicativo abriria sem som nenhum.
func _carregar_faixa() -> AudioStream:
	if _music_cache.has("__arquivo"):
		return _music_cache["__arquivo"]
	var stream: AudioStream = null
	if ResourceLoader.exists(MUSICA_ARQUIVO):
		var carregado := load(MUSICA_ARQUIVO)
		if carregado is AudioStream:
			stream = carregado
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = true
			elif stream is AudioStreamOggVorbis:
				(stream as AudioStreamOggVorbis).loop = true
	_music_cache["__arquivo"] = stream
	return stream


func stop_music() -> void:
	_mood_pedido = ""
	if _music_player == null or not _music_player.playing:
		return
	_matar_fade()
	_fade = create_tween()
	_fade.tween_property(_music_player, "volume_db", -60.0, MUSIC_FADE)
	_fade.tween_callback(_parar_musica_agora)


## O clima certo para uma cena: `menu` fora dos jogos, e nos jogos o que o
## catalogo diz -- cartas na mesa de carteado, quebra-cabeca no jogo solitario,
## tabuleiro no resto.
func play_music_for_scene(scene: Node) -> void:
	play_music(mood_for_scene(scene))


func mood_for_scene(scene: Node) -> String:
	if scene is BaseGame:
		return mood_for_game((scene as BaseGame).game_id)
	return "menu"


func mood_for_game(game_id: String) -> String:
	var def := GameCatalog.find_by_id(game_id)
	if def == null:
		return "tabuleiro"
	if def.category == &"cards":
		return "cartas"
	if def.modes != 0 and def.modes == GameDefinition.Mode.SOLO:
		return "quebra_cabeca"
	return "tabuleiro"


func current_mood() -> String:
	return _mood_tocando


func is_music_playing() -> bool:
	return _music_player != null and _music_player.playing


func _renderizar(mood: String) -> void:
	if _thread != null:
		if _thread.is_started() and not _thread.is_alive():
			_colher_thread()
		elif _thread.is_started():
			return  # a thread em curso chama play_music de novo ao terminar
	_thread = Thread.new()
	_thread_mood = mood
	_thread.start(_render_em_thread.bind(mood))


func _render_em_thread(mood: String) -> void:
	var amostras := MusicSynth.render(mood)
	var stream := MusicSynth.to_stream(amostras)
	call_deferred("_on_loop_pronto", mood, stream)


func _on_loop_pronto(mood: String, stream: AudioStreamWAV) -> void:
	_colher_thread()
	_music_cache[mood] = stream
	if _mood_pedido == mood and music_enabled:
		_tocar(mood)
	elif _mood_pedido != "" and not _music_cache.has(_mood_pedido):
		_renderizar(_mood_pedido)


func _colher_thread() -> void:
	if _thread != null and _thread.is_started():
		_thread.wait_to_finish()
	_thread = null
	_thread_mood = ""


func _tocar(mood: String) -> void:
	_matar_fade()
	_music_player.stream = _music_cache[mood]
	_music_player.volume_db = -60.0
	_music_player.play()
	_mood_tocando = mood
	_fade = create_tween()
	_fade.tween_property(_music_player, "volume_db", MUSIC_DB, MUSIC_FADE)
	music_changed.emit(mood)


func _parar_musica_agora() -> void:
	_matar_fade()
	if _music_player:
		_music_player.stop()
		_music_player.volume_db = MUSIC_DB
	_mood_tocando = ""


func _matar_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null


# ==============================================================================
## Sintese dos efeitos
# ==============================================================================

func _generate_all_sounds() -> void:
	_cached_sounds["click"] = _gen_click_sound()
	_cached_sounds["chip_drop"] = _gen_chip_drop_sound()
	_cached_sounds["piece_place"] = _gen_piece_place_sound()
	_cached_sounds["card_flip"] = _gen_card_flip_sound()
	_cached_sounds["card_match"] = _gen_card_match_sound()
	_cached_sounds["win"] = _gen_win_sound()
	_cached_sounds["lose"] = _gen_lose_sound()
	_cached_sounds["level_up"] = _gen_level_up_sound()
	_cached_sounds["draw"] = _gen_draw_sound()
	_cached_sounds["explosion"] = _gen_explosion_sound()
	_cached_sounds["splash"] = _gen_splash_sound()
	_cached_sounds["capture"] = _gen_capture_sound()
	_cached_sounds["dice"] = _gen_dice_sound()
	_cached_sounds["shuffle"] = _gen_shuffle_sound()
	_cached_sounds["error"] = _gen_error_sound()
	_cached_sounds["flag"] = _gen_flag_sound()
	_carregar_efeitos_em_arquivo()


## Os efeitos gravados substituem a sintese de mesmo nome quando existem.
func _carregar_efeitos_em_arquivo() -> void:
	for nome in EFEITOS_ARQUIVO:
		var caminho: String = EFEITOS_ARQUIVO[nome]
		if not ResourceLoader.exists(caminho):
			continue
		var stream := load(caminho)
		if stream is AudioStream:
			if stream is AudioStreamMP3:
				(stream as AudioStreamMP3).loop = false
			_cached_sounds[nome] = stream


## Verdadeiro quando o efeito vem de um arquivo, e nao da sintese.
func is_file_backed(name: String) -> bool:
	return _cached_sounds.has(name) and not (_cached_sounds[name] is AudioStreamWAV)


## Grava em 16 bits. Os efeitos nasceram em 8 bits e o piso de ruido de 8 bits
## e audivel no silencio entre dois sons -- e um chiado que "melhorar o som"
## comeca por tirar.
func _create_wav_from_floats(samples: Array[float], sample_rate: int = 22050) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var s := clampf(samples[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(s * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = sample_rate
	wav.stereo = false
	wav.data = bytes
	return wav


func _buffer(rate: int, seconds: float) -> Array[float]:
	var samples: Array[float] = []
	samples.resize(int(rate * seconds))
	samples.fill(0.0)
	return samples


## Toque de interface: um "tic" curto, com o corpo de uma tecla e nao um bipe.
func _gen_click_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.035)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var freq := lerpf(1400.0, 500.0, float(i) / float(samples.size()))
		var env := exp(-t / 0.007)
		var estalo := (randf() * 2.0 - 1.0) * exp(-t / 0.002) * 0.35
		samples[i] = sin(TAU * freq * t) * env * 0.6 + estalo
	return _create_wav_from_floats(samples, rate)


func _gen_chip_drop_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.14)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var freq := lerpf(620.0, 240.0, float(i) / float(samples.size()))
		var env := exp(-t / 0.03)
		var noise := (randf() * 2.0 - 1.0) * exp(-t / 0.006) * 0.3
		var tone := (sin(TAU * freq * t) + 0.3 * sin(TAU * freq * 2.1 * t) + 0.15 * sin(TAU * freq * 3.3 * t)) * env * 0.7
		samples[i] = tone + noise
	return _create_wav_from_floats(samples, rate)


## Peca pousando na madeira: batida grave com o estalo do contato e um corpo
## que ressoa por um instante.
func _gen_piece_place_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.11)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var freq := lerpf(300.0, 115.0, float(i) / float(samples.size()))
		var env := exp(-t / 0.024)
		var corpo := sin(TAU * freq * t) * 0.7 + sin(TAU * freq * 2.4 * t) * 0.2 * exp(-t / 0.01)
		var click := (randf() * 2.0 - 1.0) * exp(-t / 0.004) * 0.45
		samples[i] = corpo * env + click
	return _create_wav_from_floats(samples, rate)


func _gen_card_flip_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.08)
	var prev := 0.0
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := sin(float(i) / float(samples.size()) * PI)
		var white := randf() * 2.0 - 1.0
		var filtered := prev + 0.28 * (white - prev)
		prev = filtered
		# O "snap" da carta que verga e solta.
		var snap := (randf() * 2.0 - 1.0) * exp(-absf(t - 0.03) / 0.003) * 0.5
		samples[i] = filtered * env * 0.6 + snap
	return _create_wav_from_floats(samples, rate)


func _gen_card_match_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.4)
	var chord := [523.25, 659.25, 783.99, 1046.50] # C5, E5, G5, C6
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var sum := 0.0
		for k in range(chord.size()):
			var note_start := float(k) * 0.05
			if t >= note_start:
				var note_t := t - note_start
				var env := exp(-note_t / 0.14)
				sum += (sin(TAU * chord[k] * note_t) + 0.2 * sin(TAU * chord[k] * 2.0 * note_t)) * env * 0.22
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)


## Fanfarra da vitoria: arpejo que sobe, com um acorde sustentado por baixo e a
## cauda mais longa que a de antes -- a vitoria merece um segundo de som.
func _gen_win_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 1.1)
	var notes := [523.25, 659.25, 783.99, 1046.50, 1318.5] # C5, E5, G5, C6, E6
	var pad := [261.63, 329.63, 392.0] # C4, E4, G4
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var sum := 0.0
		for k in range(notes.size()):
			var note_start := float(k) * 0.08
			if t >= note_start:
				var note_t := t - note_start
				var env := exp(-note_t / 0.28)
				sum += (sin(TAU * notes[k] * note_t) + 0.25 * sin(TAU * notes[k] * 2.0 * note_t)) * env * 0.16
		var pad_env := minf(t / 0.12, 1.0) * exp(-maxf(t - 0.4, 0.0) / 0.35)
		for f in pad:
			sum += (sin(TAU * f * t) + sin(TAU * f * 1.003 * t)) * 0.06 * pad_env
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)


func _gen_lose_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.75)
	var notes := [329.63, 261.63, 220.0] # E4, C4, A3
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var sum := 0.0
		for k in range(notes.size()):
			var note_start := float(k) * 0.18
			if t >= note_start:
				var note_t := t - note_start
				var env := exp(-note_t / 0.22)
				sum += (sin(TAU * notes[k] * note_t) + 0.15 * sin(TAU * notes[k] * 2.0 * note_t)) * env * 0.3
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)


func _gen_level_up_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.7)
	var notes := [587.33, 739.99, 880.0, 1174.66] # D5, F#5, A5, D6
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var sum := 0.0
		for k in range(notes.size()):
			var note_start := float(k) * 0.06
			if t >= note_start:
				var note_t := t - note_start
				var env := exp(-note_t / 0.2)
				sum += (sin(TAU * notes[k] * note_t) + 0.3 * sin(TAU * notes[k] * 3.0 * note_t) * exp(-note_t / 0.05)) * env * 0.2
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)


func _gen_draw_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.3)
	var notes := [392.0, 329.63] # G4, E4
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var sum := 0.0
		for k in range(notes.size()):
			var note_start := float(k) * 0.12
			if t >= note_start:
				var note_t := t - note_start
				var env := exp(-note_t / 0.15)
				sum += sin(TAU * notes[k] * note_t) * env * 0.4
		samples[i] = sum
	return _create_wav_from_floats(samples, rate)


## Estouro do casco atingido na Batalha Naval: ruido de banda larga com corte
## que desce -- o "grave que abre" -- somado a um sub de 70 Hz que cai para 40.
func _gen_explosion_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.55)
	var low := 0.0
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var prog := float(i) / float(samples.size())
		var corte := lerpf(0.55, 0.05, prog * prog)
		low += (randf() * 2.0 - 1.0 - low) * corte
		var env := exp(-t / 0.16)
		var sub := sin(TAU * lerpf(70.0, 40.0, prog) * t) * exp(-t / 0.10) * 0.55
		samples[i] = clampf(low * 1.5 * env + sub, -1.0, 1.0)
	return _create_wav_from_floats(samples, rate)


func _gen_splash_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.22)
	var low := 0.0
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		low += (randf() * 2.0 - 1.0 - low) * 0.30
		samples[i] = low * exp(-t / 0.055) * 0.85
	return _create_wav_from_floats(samples, rate)


func _gen_capture_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.26)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var freq := 660.0 if t < 0.09 else 440.0
		var env := exp(-fmod(t, 0.09) / 0.035)
		samples[i] = sin(TAU * freq * t) * env * 0.55
	return _create_wav_from_floats(samples, rate)


func _gen_dice_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.42)
	var batidas := [0.0, 0.07, 0.16, 0.23, 0.33]
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var v := 0.0
		for b in batidas:
			var dt: float = t - float(b)
			if dt >= 0.0 and dt < 0.05:
				var freq := lerpf(900.0, 300.0, dt / 0.05)
				v += sin(TAU * freq * dt) * exp(-dt / 0.012) * 0.45
				v += (randf() * 2.0 - 1.0) * exp(-dt / 0.004) * 0.4
		samples[i] = v
	return _create_wav_from_floats(samples, rate)


func _gen_shuffle_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.45)
	var prev := 0.0
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var white := randf() * 2.0 - 1.0
		prev += 0.3 * (white - prev)
		# Oito viradas em rajada, cada uma com o seu envelope.
		var fase := fmod(t, 0.055) / 0.055
		var env := sin(fase * PI) * (1.0 - t / 0.45)
		samples[i] = prev * env * 0.7
	return _create_wav_from_floats(samples, rate)


func _gen_error_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.26)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var quad := 1.0 if sin(TAU * 110.0 * t) > 0.0 else -1.0
		var trem := 0.6 + 0.4 * sin(TAU * 14.0 * t)
		var env := minf(t / 0.01, 1.0) * (1.0 - t / 0.26)
		samples[i] = (quad * 0.25 + sin(TAU * 110.0 * t) * 0.35) * trem * env
	return _create_wav_from_floats(samples, rate)


func _gen_flag_sound() -> AudioStreamWAV:
	var rate := 22050
	var samples := _buffer(rate, 0.14)
	for i in range(samples.size()):
		var t := float(i) / float(rate)
		var env := exp(-t / 0.04) * (1.0 - exp(-t / 0.002))
		samples[i] = (sin(TAU * 1046.5 * t) + 0.3 * sin(TAU * 2093.0 * t)) * env * 0.5
	return _create_wav_from_floats(samples, rate)
