class_name BattleshipAI
extends RefCounted

## A cabeca da IA da Batalha Naval: mapa de densidade de probabilidade.
##
## O que havia antes era pior do que parecia. `BattleshipRules.get_ai_shot()`
## tinha duas sobrecargas num parametro sem tipo -- uma recebia a grade e
## sorteava casa, a outra recebia pilha de caca e disparados e fazia caca com
## paridade. A cena passava a grade. **A IA boa existia, era testada, e nunca
## era chamada**: a IA de verdade sorteava casa entre as nao atiradas e
## precisava de perto de 96 tiros para afundar cinco navios, quando o jogador
## precisa de uns 45. Perder era quase impossivel.
##
## Esta versao nao tem sobrecarga: a IA carrega um estado explicito, so sabe o
## que os proprios tiros revelaram e nunca enxerga a grade do jogador.
##
## O metodo e o mapa de densidade, que resolve cacar e perseguir de uma vez so:
## para cada navio que ainda flutua, conta-se em quantas posicoes legais ele
## caberia passando por cada casa. A casa com mais posicoes e a mais provavel.
## Quando ha acerto ainda nao resolvido, as posicoes que passam por ele valem
## muito mais -- e a IA persegue o navio ferido sem precisar de uma segunda
## regra so para isso. O padrao de paridade que a caca antiga fazia a mao sai
## de graca: casa que nao cabe navio nenhum tem densidade zero.
##
## O degrau (1 a 10) do DifficultyManager vira chance de tiro ao acaso e, nos
## dois primeiros, desliga a perseguicao: no degrau 1 a IA acerta e esquece.

const GRID := 10
const CASAS := GRID * GRID

## Tamanhos da frota, na ordem em que `BattleshipRules.SHIP_DEFS` os cria.
const FROTA := [5, 4, 3, 3, 2]

## Quanto uma posicao que cobre um acerto ainda nao resolvido vale a mais que
## uma posicao qualquer. Alto de proposito: enquanto houver navio ferido no
## mapa, terminar de afunda-lo vale mais que abrir casa nova em qualquer lugar.
const PESO_ACERTO := 60

## Perfil de cada degrau. `erro` e a chance de largar o mapa e sortear casa;
## `cacar` diz se a IA persegue o proprio acerto.
const PERFIS := [
	{"erro": 0.92, "cacar": false},   # 1
	{"erro": 0.78, "cacar": false},   # 2
	{"erro": 0.62, "cacar": true},    # 3
	{"erro": 0.48, "cacar": true},    # 4
	{"erro": 0.34, "cacar": true},    # 5
	{"erro": 0.24, "cacar": true},    # 6
	{"erro": 0.15, "cacar": true},    # 7
	{"erro": 0.08, "cacar": true},    # 8
	{"erro": 0.03, "cacar": true},    # 9
	{"erro": 0.0, "cacar": true},     # 10
]


## Memoria de uma partida. A IA nao guarda referencia para a cena nem para a
## grade do jogador: so o que os proprios tiros contaram.
##
##   tiros     casa -> true, toda casa ja atacada
##   errados   casa -> true, tiro na agua (navio nenhum passa por ali)
##   feridos   casa -> true, acerto cujo navio ainda nao afundou
##   afundadas casa -> true, casa de navio ja afundado
##   restantes tamanhos dos navios que ainda flutuam
static func nova_memoria() -> Dictionary:
	return {
		"tiros": {},
		"errados": {},
		"feridos": {},
		"afundadas": {},
		"restantes": FROTA.duplicate(),
	}


## Fecha o tiro na memoria.
##
## `celulas_afundadas` vem vazio quando o tiro nao afundou nada; quando afunda,
## traz as casas do navio para que a densidade pare de conta-lo e para que os
## acertos dele deixem de ser perseguidos.
static func registrar(memoria: Dictionary, pos: Vector2i, acertou: bool,
		celulas_afundadas: Array = []) -> void:
	memoria["tiros"][pos] = true
	if acertou:
		memoria["feridos"][pos] = true
	else:
		memoria["errados"][pos] = true

	if celulas_afundadas.is_empty():
		return

	for c in celulas_afundadas:
		memoria["afundadas"][c] = true
		memoria["feridos"].erase(c)

	var i: int = memoria["restantes"].find(celulas_afundadas.size())
	if i != -1:
		memoria["restantes"].remove_at(i)


## A casa que a IA ataca no degrau pedido, ou (-1, -1) se nao ha casa livre.
static func escolher_tiro(memoria: Dictionary, level: int) -> Vector2i:
	var livres := _casas_livres(memoria)
	if livres.is_empty():
		return Vector2i(-1, -1)

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	if randf() < float(perfil["erro"]):
		return livres[randi() % livres.size()]

	var mapa := densidade(memoria, bool(perfil["cacar"]))
	var melhor := -1
	var candidatas: Array[Vector2i] = []
	for pos in livres:
		var d: int = mapa[pos.x * GRID + pos.y]
		if d > melhor:
			melhor = d
			candidatas = [pos]
		elif d == melhor:
			candidatas.append(pos)

	# Toda casa livre com densidade zero: nenhum navio restante cabe em lugar
	# nenhum que a IA ainda nao tenha atacado. Nao deve acontecer com a frota
	# inteira em jogo, mas sortear e melhor que travar.
	if candidatas.is_empty():
		return livres[randi() % livres.size()]
	return candidatas[randi() % candidatas.size()]


## Mapa de densidade: em quantas posicoes legais um navio restante passaria por
## cada casa. Publico porque o teste le o mapa direto -- e mais barato provar
## que a caca funciona olhando o mapa do que jogando mil partidas.
static func densidade(memoria: Dictionary, cacar: bool = true) -> PackedInt32Array:
	var mapa := PackedInt32Array()
	mapa.resize(CASAS)

	var errados: Dictionary = memoria["errados"]
	var afundadas: Dictionary = memoria["afundadas"]
	var feridos: Dictionary = memoria["feridos"]
	var tiros: Dictionary = memoria["tiros"]

	for tamanho in memoria["restantes"]:
		for r in range(GRID):
			for c in range(GRID):
				for horizontal in [true, false]:
					var fim_r: int = r if horizontal else r + tamanho - 1
					var fim_c: int = c + tamanho - 1 if horizontal else c
					if fim_r >= GRID or fim_c >= GRID:
						continue

					# Navio de uma casa so nao existe nesta frota; sem o corte,
					# cada posicao vertical de tamanho 1 entraria duas vezes.
					if tamanho == 1 and not horizontal:
						continue

					var cabe := true
					var cobre := 0
					var casas: Array[Vector2i] = []
					for i in range(tamanho):
						var p := Vector2i(r, c + i) if horizontal else Vector2i(r + i, c)
						if errados.has(p) or afundadas.has(p):
							cabe = false
							break
						if feridos.has(p):
							cobre += 1
						casas.append(p)
					if not cabe:
						continue

					var peso := 1 + (cobre * PESO_ACERTO if cacar else 0)
					for p in casas:
						if not tiros.has(p):
							mapa[p.x * GRID + p.y] += peso

	return mapa


static func _casas_livres(memoria: Dictionary) -> Array[Vector2i]:
	var livres: Array[Vector2i] = []
	var tiros: Dictionary = memoria["tiros"]
	for r in range(GRID):
		for c in range(GRID):
			var p := Vector2i(r, c)
			if not tiros.has(p):
				livres.append(p)
	return livres
