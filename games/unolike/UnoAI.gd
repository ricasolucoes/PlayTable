class_name UnoAI
extends RefCounted

## A cabeca da IA do Jogo de Cores & Cartas: escolha por prioridade.
##
## O que havia antes era `playable_indices.pick_random()` -- a IA sorteava
## entre as cartas jogaveis. Ela guardava o +2 para o fim quando o jogador
## estava com uma carta so, queimava o curinga tendo carta da cor na mao, e
## descartava as cartas baixas primeiro, ficando com as caras quando o jogador
## batia.
##
## A unica heuristica que existia era a da cor do curinga
## (`UnoRules.pick_best_color_for_hand`), e mesmo essa a cena so passou a
## chamar depois -- ate entao o curinga fixava azul.
##
## As regras de bolso que esta IA segue, em ordem:
##
##   1. **Carta de acao da cor ativa sai na frente.** Nesta implementacao
##      pular, inverter, +2 e +4 todos dao turno extra a quem os joga
##      (`_handle_card_effects_and_advance` liga `skip_next` nos quatro), entao
##      joga-las cedo nao custa nada e ainda faz o outro comprar;
##   2. **Adversario com uma carta so**: ai a ordem entre as cartas de acao
##      inverte -- vale mais a que faz ele comprar (+4, depois +2, depois
##      pular), porque comprar adia a batida dele;
##   3. **Trocar de cor cedo custa caro**: com carta da cor ativa na mao, a
##      carta da cor sai antes do curinga. Curinga guardado e uma jogada legal
##      garantida para quando nada mais encaixar, e o +4 e a ultima de todas
##      porque ele e a carta que sempre cabe;
##   4. **Carta cara sai primeiro**: quem fica com a mao cara paga o dobro se o
##      outro bater. Entre cartas de mesma prioridade, a de maior valor sai.
##
## O degrau (1 a 10) do DifficultyManager vira a chance de largar a prioridade
## e sortear a carta.

## Perfil de cada degrau: chance de sortear entre as jogaveis em vez de seguir
## a prioridade. Um jogo de cartas com informacao escondida nao aceita busca --
## a mao do adversario nao esta na mesa.
const PERFIS := [
	{"erro": 0.88},   # 1
	{"erro": 0.72},   # 2
	{"erro": 0.58},   # 3
	{"erro": 0.45},   # 4
	{"erro": 0.33},   # 5
	{"erro": 0.22},   # 6
	{"erro": 0.14},   # 7
	{"erro": 0.07},   # 8
	{"erro": 0.02},   # 9
	{"erro": 0.0},    # 10
]

## Quando o adversario esta a uma carta de bater, travar o turno dele vale mais
## que qualquer outra coisa.
const PRIORIDADE_TRAVA := 1000

## Carta de acao da cor ativa. Vale mais que numero porque da turno extra: o
## lado que a joga volta a jogar em seguida.
const PRIORIDADE_ACAO := 400

## Numero da cor ativa. O caminho normal.
const PRIORIDADE_NUMERO := 300

## Carta que encaixa pelo numero, trocando a cor. Vale menos que seguir na cor
## que a mao ja tem.
const PRIORIDADE_TROCA_DE_COR := 200

## Curinga: sempre jogavel, entao e a ultima carta que se queima.
const PRIORIDADE_CURINGA := 100

## Curinga +4 vale ainda menos que o curinga simples fora do momento de travar:
## ele e a carta mais forte da mao e queima-lo cedo joga fora a virada.
const PRIORIDADE_CURINGA_4 := 50


## O indice da carta que a IA joga, entre as jogaveis, ou -1 se a mao nao tem
## jogada.
##
## `cartas_do_adversario` faz a IA reconhecer o momento de travar o turno.
static func escolher_carta(mao: Array, topo: Card, cor_ativa: int,
		cartas_do_adversario: int, level: int) -> int:
	var jogaveis := UnoRules.get_playable_cards(mao, cor_ativa, topo)
	if jogaveis.is_empty():
		return -1
	if jogaveis.size() == 1:
		return jogaveis[0]

	var perfil: Dictionary = PERFIS[clampi(level, 1, PERFIS.size()) - 1]
	if randf() < float(perfil["erro"]):
		return jogaveis[randi() % jogaveis.size()]

	var melhores: Array[int] = []
	var melhor_nota := -1
	for i in jogaveis:
		var nota := prioridade(mao[i], cor_ativa, cartas_do_adversario)
		if nota > melhor_nota:
			melhor_nota = nota
			melhores = [i]
		elif nota == melhor_nota:
			melhores.append(i)

	return melhores[randi() % melhores.size()]


## Quanto vale jogar esta carta agora. Maior e melhor.
static func prioridade(carta: Card, cor_ativa: int, cartas_do_adversario: int) -> int:
	if carta == null:
		return -1

	var trava := carta.special_type == Card.SpecialType.SKIP \
		or carta.special_type == Card.SpecialType.DRAW_TWO \
		or carta.special_type == Card.SpecialType.WILD_DRAW_FOUR \
		or carta.special_type == Card.SpecialType.REVERSE

	# Adversario a uma carta de bater: o que importa e ele nao jogar.
	if cartas_do_adversario <= 1 and trava:
		var peso := PRIORIDADE_TRAVA
		if carta.special_type == Card.SpecialType.WILD_DRAW_FOUR:
			peso += 3
		elif carta.special_type == Card.SpecialType.DRAW_TWO:
			peso += 2
		elif carta.special_type == Card.SpecialType.SKIP:
			peso += 1
		return peso

	if carta.color_type == Card.ColorType.WILD:
		if carta.special_type == Card.SpecialType.WILD_DRAW_FOUR:
			return PRIORIDADE_CURINGA_4
		return PRIORIDADE_CURINGA

	if carta.color_type == cor_ativa:
		# Entre cartas da cor, a mais cara sai primeiro: a mao que sobra e a
		# que paga se o adversario bater.
		if trava:
			return PRIORIDADE_ACAO + carta.value
		return PRIORIDADE_NUMERO + carta.value

	# Encaixou pelo numero: troca a cor ativa, o que costuma ajudar o outro.
	return PRIORIDADE_TROCA_DE_COR + carta.value
