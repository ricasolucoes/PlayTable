class_name MastermindRules
extends RefCounted

## Regras da Senha (Mastermind), puras: sem no, sem tr().
##
## O codigo secreto tem N posicoes escolhidas entre C cores. Cada palpite
## recebe pinos pretos (cor E posicao certas) e brancos (cor certa em posicao
## errada), contados do jeito classico: cada pino do codigo responde a no
## maximo um pino do palpite, e o preto tem prioridade sobre o branco.
##
## O tamanho do codigo e a paleta saem do degrau da escada do DifficultyManager
## (`config_do_degrau`): a Senha nao tem adversario no modo solo, entao mais
## posicoes e mais cores sao a dificuldade.

const MAX_TENTATIVAS := 10
const MAX_CORES := 8
const MAX_POSICOES := 5

## Bonus de tempo da pontuacao: um ponto por segundo que sobrou ate este teto.
const BONUS_TEMPO := 300

## As 8 cores, na ordem dos indices 0..7. Escolhidas para se separarem sobre a
## ardosia escura da grade; a leitura nunca depende so delas (ver SIMBOLOS).
const PALETA := [
	Color(0.86, 0.17, 0.16),   # 0 vermelho
	Color(0.16, 0.46, 0.90),   # 1 azul
	Color(0.96, 0.82, 0.14),   # 2 amarelo
	Color(0.16, 0.70, 0.34),   # 3 verde
	Color(0.95, 0.52, 0.12),   # 4 laranja
	Color(0.58, 0.28, 0.86),   # 5 roxo
	Color(0.16, 0.80, 0.84),   # 6 ciano
	Color(0.94, 0.92, 0.86),   # 7 marfim
]

## Simbolo de cada cor, deitado sobre o pino e escrito no botao da paleta.
## Regra da casa (daltonismo): a cor nunca e a unica pista.
const SIMBOLOS := ["●", "■", "▲", "◆", "★", "✚", "♥", "♦"]

## Forma da peca de cada cor (`Token3D.token_type`): a terceira pista, que
## le ate em silhueta.
const FORMAS := ["sphere", "cylinder", "pawn", "sphere", "cylinder", "pawn", "sphere", "cylinder"]

## O que cada degrau da escada monta: [posicoes, cores, repete cor].
## Degraus 1-2 sao o jogo de entrada (sem cor repetida no codigo); do 3 ao 5 o
## codigo pode repetir; do 6 ao 8 entram as oito cores; 9 e 10 tem cinco pinos.
const DEGRAUS := [
	[4, 6, false],
	[4, 6, false],
	[4, 6, true],
	[4, 6, true],
	[4, 6, true],
	[4, 8, true],
	[4, 8, true],
	[4, 8, true],
	[5, 8, true],
	[5, 8, true],
]


## {"posicoes": N, "cores": C, "repete": bool} do degrau (1..10).
static func config_do_degrau(level: int) -> Dictionary:
	var d: Array = DEGRAUS[clampi(level, 1, DEGRAUS.size()) - 1]
	return {"posicoes": int(d[0]), "cores": int(d[1]), "repete": bool(d[2])}


static func posicoes_do_degrau(level: int) -> int:
	return int(config_do_degrau(level)["posicoes"])


static func cores_do_degrau(level: int) -> int:
	return int(config_do_degrau(level)["cores"])


static func repete_no_degrau(level: int) -> bool:
	return bool(config_do_degrau(level)["repete"])


static func cor(indice: int) -> Color:
	return PALETA[clampi(indice, 0, PALETA.size() - 1)]


static func simbolo(indice: int) -> String:
	return str(SIMBOLOS[clampi(indice, 0, SIMBOLOS.size() - 1)])


static func forma(indice: int) -> String:
	return str(FORMAS[clampi(indice, 0, FORMAS.size() - 1)])


## Cor do simbolo escrito sobre a cor `indice`: escuro sobre as claras, claro
## sobre as escuras. A luminancia decide, nao a lista.
static func cor_do_texto(indice: int) -> Color:
	var c := cor(indice)
	var luminancia := 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
	return Color(0.08, 0.08, 0.10) if luminancia > 0.55 else Color(0.98, 0.98, 0.98)


## Sorteia um codigo. O gerador vem de fora (`MatchSync.rng`) para os dois
## aparelhos de uma partida em rede chegarem ao mesmo codigo sem trafega-lo.
static func gerar_codigo(rng: RandomNumberGenerator, posicoes: int, cores: int, repete: bool) -> Array[int]:
	var saida: Array[int] = []
	posicoes = clampi(posicoes, 1, MAX_POSICOES)
	cores = clampi(cores, 1, MAX_CORES)
	if repete or cores < posicoes:
		for i in posicoes:
			saida.append(rng.randi_range(0, cores - 1))
		return saida
	# Sem repeticao: Fisher-Yates sobre a bolsa de cores e as N primeiras.
	var bolsa: Array[int] = []
	for c in cores:
		bolsa.append(c)
	for i in range(bolsa.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp := bolsa[i]
		bolsa[i] = bolsa[j]
		bolsa[j] = tmp
	for i in posicoes:
		saida.append(bolsa[i])
	return saida


## Um codigo (o secreto) e valido para a configuracao? Sem repeticao quando o
## degrau proibe, cores dentro da paleta, tamanho certo.
static func codigo_valido(codigo: Array, posicoes: int, cores: int, repete: bool) -> bool:
	if codigo.size() != posicoes:
		return false
	var vistos := {}
	for v in codigo:
		if not (v is int or v is float):
			return false
		var c := int(v)
		if c < 0 or c >= cores:
			return false
		if not repete and vistos.has(c):
			return false
		vistos[c] = true
	return true


## Um palpite pode repetir cor mesmo quando o codigo nao pode: e uma jogada
## legitima (e util) do quebrador.
static func palpite_valido(palpite: Array, posicoes: int, cores: int) -> bool:
	return codigo_valido(palpite, posicoes, cores, true)


## Pretos e brancos empacotados em `pretos * 16 + brancos`, sem alocar nada.
## E o que a IA chama dezenas de milhares de vezes por palpite.
static func avaliar_rapido(codigo: Array, palpite: Array) -> int:
	var n := mini(codigo.size(), palpite.size())
	var pretos := 0
	var usado_c := 0
	var usado_p := 0
	for i in n:
		if int(codigo[i]) == int(palpite[i]):
			pretos += 1
			usado_c |= 1 << i
			usado_p |= 1 << i
	var brancos := 0
	for i in n:
		if usado_p & (1 << i):
			continue
		var cor_p := int(palpite[i])
		for j in n:
			if usado_c & (1 << j):
				continue
			if int(codigo[j]) == cor_p:
				brancos += 1
				usado_c |= 1 << j
				break
	return pretos * 16 + brancos


## O feedback classico: {"black": pretos, "white": brancos}.
static func avaliar(codigo: Array, palpite: Array) -> Dictionary:
	var r := avaliar_rapido(codigo, palpite)
	return {"black": r >> 4, "white": r & 15}


static func acertou(feedback: Dictionary, posicoes: int) -> bool:
	return int(feedback.get("black", 0)) == posicoes


## Feedback plausivel para um codigo de N posicoes: e o que se confere no que
## chega pela rede antes de aplicar.
static func feedback_valido(feedback: Dictionary, posicoes: int) -> bool:
	var b := int(feedback.get("black", -1))
	var w := int(feedback.get("white", -1))
	if b < 0 or w < 0 or b + w > posicoes:
		return false
	# N-1 pretos e 1 branco e impossivel: o branco nao teria onde estar.
	if b == posicoes - 1 and w == 1:
		return false
	return true


## Pontuacao do quebrador: (11 - tentativas) * 100 mais o bonus de tempo.
## Falhar (mais de 10) vale zero.
static func pontuacao(tentativas: int, tempo_s: float) -> int:
	if tentativas < 1 or tentativas > MAX_TENTATIVAS:
		return 0
	return (MAX_TENTATIVAS + 1 - tentativas) * 100 + bonus_de_tempo(tempo_s)


static func bonus_de_tempo(tempo_s: float) -> int:
	return clampi(BONUS_TEMPO - int(tempo_s), 0, BONUS_TEMPO)


## Todos os codigos possiveis da configuracao, na ordem do odometro. E o
## espaco que a IA vai eliminando; 6^4 = 1296, 8^5 = 32768.
static func todos_os_codigos(posicoes: int, cores: int, repete: bool) -> Array:
	var saida: Array = []
	posicoes = clampi(posicoes, 1, MAX_POSICOES)
	cores = clampi(cores, 1, MAX_CORES)
	var atual: Array[int] = []
	atual.resize(posicoes)
	atual.fill(0)
	while true:
		if repete or _sem_repeticao(atual):
			saida.append(atual.duplicate())
		var i := posicoes - 1
		while i >= 0:
			atual[i] += 1
			if atual[i] < cores:
				break
			atual[i] = 0
			i -= 1
		if i < 0:
			break
	return saida


static func _sem_repeticao(codigo: Array) -> bool:
	var mascara := 0
	for v in codigo:
		var bit := 1 << int(v)
		if mascara & bit:
			return false
		mascara |= bit
	return true
