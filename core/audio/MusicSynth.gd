class_name MusicSynth
extends RefCounted

## Musica de fundo gerada aqui dentro, sem um unico arquivo de audio.
##
## O pedido era "musicas livres, bem baixinhas, de fundo". Livre de verdade e
## a que nasce no proprio aplicativo: nao ha licenca, autor nem arquivo de
## megabytes no APK -- so esta partitura e o sintetizador que a toca. Cada
## "clima" e um loop de oito compassos, escrito como acordes, uma escala e um
## sorteio de arpejo com semente fixa, para a mesma musica tocar sempre igual
## e o fim emendar no comeco sem costura.
##
## Tres vozes: um colchao (duas senoides desafinadas por nota do acorde, ataque
## lento), um dedilhado (senoide com dois harmonicos e decaimento curto) e um
## baixo (senoide duas oitavas abaixo da fundamental). Tudo a 16 kHz e em mono:
## e musica de fundo a -21 dB, nao trilha de cinema, e o telefone renderiza os
## ~27 s do loop numa thread em poucos segundos.

const RATE := 16000

## Os climas. `menu` nas telas, `tabuleiro` nos jogos contra alguem, `cartas`
## na mesa de carteado e `quebra_cabeca` nos jogos solitarios.
const MOODS: PackedStringArray = ["menu", "tabuleiro", "cartas", "quebra_cabeca"]

## Semitons a partir de C4 (MIDI 60), por nome, para a partitura ficar legivel.
const NOTA := {
	"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6,
	"G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
}

## Cada clima: andamento, acordes (dois compassos cada, quatro por loop),
## escala do dedilhado (semitons na oitava), densidade do arpejo (0..1),
## oitava do dedilhado, semente e balanco (atraso das colcheias fracas, em
## fracao de tempo).
const PARTITURAS := {
	"menu": {
		"bpm": 80, "chords": [["C", "E", "G"], ["G", "B", "D"], ["A", "C", "E"], ["F", "A", "C"]],
		"scale": [0, 2, 4, 7, 9], "density": 0.42, "octave": 1, "seed": 11, "swing": 0.0,
		"pad": 0.26, "pluck": 0.30, "bass": 0.22,
	},
	"tabuleiro": {
		"bpm": 66, "chords": [["D", "F#", "A"], ["B", "D", "F#"], ["G", "B", "D"], ["A", "C#", "E"]],
		"scale": [2, 4, 6, 9, 11], "density": 0.48, "octave": 0, "seed": 23, "swing": 0.0,
		"pad": 0.30, "pluck": 0.28, "bass": 0.26,
	},
	"cartas": {
		"bpm": 76, "chords": [["A", "C", "E", "G"], ["D", "F", "A", "C"], ["G", "B", "D", "F"], ["C", "E", "G", "B"]],
		"scale": [0, 2, 4, 5, 7, 9], "density": 0.52, "octave": 0, "seed": 37, "swing": 0.12,
		"pad": 0.24, "pluck": 0.30, "bass": 0.28,
	},
	"quebra_cabeca": {
		"bpm": 60, "chords": [["E", "G", "B"], ["C", "E", "G"], ["G", "B", "D"], ["D", "F#", "A"]],
		"scale": [4, 7, 9, 11, 2], "density": 0.30, "octave": 1, "seed": 53, "swing": 0.0,
		"pad": 0.32, "pluck": 0.24, "bass": 0.20,
	},
}

const COMPASSOS := 8
const TEMPOS_POR_COMPASSO := 4


static func is_mood(mood: String) -> bool:
	return PARTITURAS.has(mood)


## Frequencia de um semitom relativo a C4, deslocado `octave` oitavas.
static func freq(semitone: int, octave: int = 0) -> float:
	return 261.6256 * pow(2.0, float(semitone + 12 * octave) / 12.0)


## Quantas amostras tem o loop de um clima, para `bars` compassos.
static func loop_samples(mood: String, bars: int = COMPASSOS, rate: int = RATE) -> int:
	var p: Dictionary = PARTITURAS[mood]
	var tempo := 60.0 / float(p["bpm"])
	return int(round(tempo * TEMPOS_POR_COMPASSO * bars * rate))


## Renderiza o loop de um clima em mono, valores em -1..1.
##
## Toda nota que passa do fim do loop continua no comeco (`% total`): e isso
## que faz a emenda desaparecer -- o compasso 8 ja carrega as caudas que o
## compasso 1 vai ouvir.
static func render(mood: String, bars: int = COMPASSOS, rate: int = RATE) -> PackedFloat32Array:
	var p: Dictionary = PARTITURAS[mood]
	var tempo := 60.0 / float(p["bpm"])
	var total := loop_samples(mood, bars, rate)
	var buffer := PackedFloat32Array()
	buffer.resize(total)
	buffer.fill(0.0)

	var chords: Array = p["chords"]
	var compasso_len := tempo * TEMPOS_POR_COMPASSO
	var rng := RandomNumberGenerator.new()
	rng.seed = int(p["seed"])

	for bar in range(bars):
		var chord: Array = chords[(bar / 2) % chords.size()]
		var inicio := bar * compasso_len
		if bar % 2 == 0:
			# Colchao por dois compassos, com ataque e soltura longos.
			var dur := compasso_len * 2.0
			for nome in chord:
				var st: int = NOTA[nome]
				_pad(buffer, rate, inicio, dur, freq(st, -1 if st > 7 else 0), float(p["pad"]) / float(chord.size()))
			# Baixo na fundamental, duas oitavas abaixo, um por compasso.
		var raiz: int = NOTA[chord[0]]
		_bass(buffer, rate, inicio, compasso_len * 0.9, freq(raiz, -2), float(p["bass"]))
		if bar % 2 == 1 and chord.size() >= 3:
			# No segundo compasso do acorde o baixo passeia para a quinta.
			var quinta: int = NOTA[chord[2]]
			_bass(buffer, rate, inicio + compasso_len * 0.5, compasso_len * 0.45, freq(quinta, -2), float(p["bass"]) * 0.7)

		# Dedilhado em colcheias sorteadas dentro da escala, com preferencia
		# pelas notas do acorde.
		var scale: Array = p["scale"]
		for colcheia in range(TEMPOS_POR_COMPASSO * 2):
			if rng.randf() > float(p["density"]):
				continue
			var t := inicio + colcheia * tempo * 0.5
			if colcheia % 2 == 1:
				t += tempo * float(p["swing"])
			var semitom: int
			if rng.randf() < 0.6:
				semitom = NOTA[chord[rng.randi_range(0, chord.size() - 1)]]
			else:
				semitom = int(scale[rng.randi_range(0, scale.size() - 1)])
			var oitava := int(p["octave"]) + (1 if rng.randf() < 0.3 else 0)
			var vel := float(p["pluck"]) * rng.randf_range(0.55, 1.0)
			_pluck(buffer, rate, t, freq(semitom, oitava), vel, rng.randf_range(0.5, 0.9))

	# Compressao suave: tanh curva o pico sem estalar.
	for i in range(total):
		buffer[i] = tanh(buffer[i] * 1.15) * 0.92
	return buffer


## Duas senoides desafinadas em 0,4% e um sopro de segundo harmonico, com
## ataque de 1,4 s e soltura de 1,6 s: o colchao.
static func _pad(buffer: PackedFloat32Array, rate: int, inicio_s: float, dur_s: float, f: float, amp: float) -> void:
	var total := buffer.size()
	var n := int((dur_s + 1.6) * rate)
	var s0 := int(inicio_s * rate)
	var w1 := TAU * f * 0.998
	var w2 := TAU * f * 1.002
	var w3 := TAU * f * 2.0
	for i in range(n):
		var t := float(i) / float(rate)
		var env := minf(t / 1.4, 1.0)
		if t > dur_s:
			env *= maxf(0.0, 1.0 - (t - dur_s) / 1.6)
		# Um tremolo lento da respiracao ao acorde parado.
		env *= 0.85 + 0.15 * sin(TAU * 0.23 * t)
		var v := (sin(w1 * t) + sin(w2 * t)) * 0.5 + 0.12 * sin(w3 * t)
		buffer[(s0 + i) % total] += v * env * amp


## Senoide com dois harmonicos, ataque de 4 ms e decaimento exponencial.
static func _pluck(buffer: PackedFloat32Array, rate: int, inicio_s: float, f: float, amp: float, tau: float) -> void:
	var total := buffer.size()
	var n := int(tau * 4.5 * rate)
	var s0 := int(inicio_s * rate)
	var w := TAU * f
	for i in range(n):
		var t := float(i) / float(rate)
		var env := exp(-t / tau) * (1.0 - exp(-t / 0.004))
		var v := sin(w * t) + 0.35 * sin(2.0 * w * t) * exp(-t / (tau * 0.5)) + 0.10 * sin(3.0 * w * t) * exp(-t / (tau * 0.3))
		buffer[(s0 + i) % total] += v * env * amp


## Baixo redondo: senoide e um pouco de segundo harmonico, ataque de 30 ms.
static func _bass(buffer: PackedFloat32Array, rate: int, inicio_s: float, dur_s: float, f: float, amp: float) -> void:
	var total := buffer.size()
	var n := int((dur_s + 0.4) * rate)
	var s0 := int(inicio_s * rate)
	var w := TAU * f
	for i in range(n):
		var t := float(i) / float(rate)
		var env := minf(t / 0.03, 1.0)
		if t > dur_s:
			env *= maxf(0.0, 1.0 - (t - dur_s) / 0.4)
		var v := sin(w * t) + 0.25 * sin(2.0 * w * t)
		buffer[(s0 + i) % total] += v * env * amp


## Empacota o loop num AudioStreamWAV de 16 bits que repete sem emenda.
static func to_stream(samples: PackedFloat32Array, rate: int = RATE) -> AudioStreamWAV:
	var bytes := PackedByteArray()
	bytes.resize(samples.size() * 2)
	for i in range(samples.size()):
		var v := int(clampf(samples[i], -1.0, 1.0) * 32767.0)
		bytes.encode_s16(i * 2, v)
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = rate
	wav.stereo = false
	wav.data = bytes
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = samples.size()
	return wav
