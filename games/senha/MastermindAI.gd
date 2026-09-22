class_name MastermindAI
extends RefCounted

## A maquina quebrando um codigo.
##
## Guarda o conjunto de codigos ainda possiveis (os consistentes com todo
## feedback recebido) e so palpita dentro dele: nunca joga um palpite que o
## historico ja descartou. O degrau da escada decide COMO escolhe dentro do
## conjunto:
##
##   - 1 a 3: um candidato ao acaso (resolve, mas sem malicia);
##   - 4 a 6: minimax raso -- poucos candidatos testados, orcamento curto;
##   - 7 a 10: minimax a la Knuth restrito aos candidatos, com orcamento maior.
##
## O minimax escolhe o palpite cujo PIOR feedback deixa o menor conjunto. E
## quadratico no numero de candidatos, por isso so entra quando o conjunto ja
## encolheu (`LIMITE_MINIMAX`) e sempre com um teto de milissegundos: a partida
## nao pode travar num telefone com 32768 codigos de 5 pinos e 8 cores.
##
## O estado e um Dictionary plano para poder viajar para um WorkerThreadPool
## (`pensar_em_tarefa`) sem carregar a cena junto.

const LIMITE_MINIMAX := 420
const AMOSTRA_MEDIA := 48
const ORCAMENTO_MS_MEDIO := 30
const ORCAMENTO_MS_ALTO := 120

## Quantos feedbacks distintos cabem em `pretos * 16 + brancos` (5 * 16 + 5).
const BALDES := 96


## Estado novo: todos os codigos da configuracao ainda sao possiveis.
static func novo_estado(posicoes: int, cores: int, repete: bool) -> Dictionary:
	return {
		"posicoes": posicoes,
		"cores": cores,
		"repete": repete,
		"candidatos": MastermindRules.todos_os_codigos(posicoes, cores, repete),
		"palpites": 0,
	}


## Elimina os candidatos que nao dariam este feedback a este palpite.
static func registrar(estado: Dictionary, palpite: Array, feedback: Dictionary) -> void:
	_garantir_candidatos(estado)
	var alvo := int(feedback.get("black", 0)) * 16 + int(feedback.get("white", 0))
	var restantes: Array = []
	for cand in estado["candidatos"]:
		if MastermindRules.avaliar_rapido(cand, palpite) == alvo:
			restantes.append(cand)
	estado["candidatos"] = restantes
	estado["palpites"] = int(estado.get("palpites", 0)) + 1


static func candidatos_restantes(estado: Dictionary) -> int:
	_garantir_candidatos(estado)
	return (estado["candidatos"] as Array).size()


## A abertura classica: pares de cores iguais (0 0 1 1 [2]) quando o codigo
## pode repetir, cores todas diferentes quando nao pode.
static func abertura(posicoes: int, cores: int, repete: bool) -> Array[int]:
	var g: Array[int] = []
	for i in posicoes:
		g.append(((i / 2) if repete else i) % maxi(cores, 1))
	return g


## O proximo palpite, sempre consistente com o que ja foi registrado.
static func proximo_palpite(estado: Dictionary, level: int, rng: RandomNumberGenerator) -> Array[int]:
	_garantir_candidatos(estado)
	var posicoes := int(estado["posicoes"])
	var cores := int(estado["cores"])
	var repete := bool(estado["repete"])
	var cands: Array = estado["candidatos"]
	if cands.is_empty():
		# Feedback contraditorio (so acontece com um codificador humano que
		# errou a conta): nao ha o que deduzir, joga algo valido.
		return abertura(posicoes, cores, repete)
	if cands.size() == 1:
		return _copia(cands[0])
	if int(estado.get("palpites", 0)) == 0:
		return abertura(posicoes, cores, repete)
	if level <= 3 or cands.size() > LIMITE_MINIMAX:
		return _copia(cands[rng.randi_range(0, cands.size() - 1)])
	var amostra := cands.size() if level >= 7 else mini(cands.size(), AMOSTRA_MEDIA)
	var orcamento := ORCAMENTO_MS_ALTO if level >= 7 else ORCAMENTO_MS_MEDIO
	return _minimax(cands, amostra, orcamento, rng)


## Registra o ultimo feedback (se houver) e escolhe o proximo palpite. Feita
## para `WorkerThreadPool.add_task`: recebe so dados planos e devolve o
## palpite em `saida`.
static func pensar_em_tarefa(estado: Dictionary, ultimo_palpite: Array, ultimo_feedback: Dictionary,
		level: int, semente: int, saida: Array) -> void:
	if not ultimo_palpite.is_empty():
		registrar(estado, ultimo_palpite, ultimo_feedback)
	var rng := RandomNumberGenerator.new()
	rng.seed = semente if semente != 0 else 1
	saida.append(proximo_palpite(estado, level, rng))


## Entre os `amostra` candidatos a partir de um ponto ao acaso, o que deixa o
## menor pior-caso. Para na hora quando estoura o orcamento: devolve o melhor
## visto ate ali, que ja e consistente.
static func _minimax(cands: Array, amostra: int, orcamento_ms: int, rng: RandomNumberGenerator) -> Array[int]:
	var t0 := Time.get_ticks_msec()
	var total := cands.size()
	var inicio := rng.randi_range(0, total - 1)
	var melhor: Array = cands[inicio]
	var melhor_pior := total + 1
	var baldes := PackedInt32Array()
	baldes.resize(BALDES)
	for k in amostra:
		var g: Array = cands[(inicio + k) % total]
		baldes.fill(0)
		var pior := 0
		for cand in cands:
			var fb := MastermindRules.avaliar_rapido(cand, g)
			baldes[fb] += 1
			if baldes[fb] > pior:
				pior = baldes[fb]
				if pior >= melhor_pior:
					break
		if pior < melhor_pior:
			melhor_pior = pior
			melhor = g
		if Time.get_ticks_msec() - t0 > orcamento_ms:
			break
	return _copia(melhor)


## O estado pode chegar sem a lista (a cena nao enumera 32768 codigos na linha
## principal): enumera aqui, ja dentro da tarefa.
static func _garantir_candidatos(estado: Dictionary) -> void:
	if estado.has("candidatos"):
		return
	estado["candidatos"] = MastermindRules.todos_os_codigos(
		int(estado.get("posicoes", 4)), int(estado.get("cores", 6)), bool(estado.get("repete", true)))
	if not estado.has("palpites"):
		estado["palpites"] = 0


static func _copia(a: Array) -> Array[int]:
	var s: Array[int] = []
	for v in a:
		s.append(int(v))
	return s
