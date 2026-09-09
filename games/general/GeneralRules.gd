class_name GeneralRules
extends RefCounted

## Regras puras do General: o Yahtzee brasileiro, com a tabela de dez
## categorias. Sem no, sem tr(): a cena e a IA perguntam aqui quanto vale uma
## mao e o que ainda esta livre na folha.
##
## A folha de um jogador e um Dictionary `categoria -> pontos`. Categoria
## ausente esta livre; presente com zero foi riscada. A partida acaba quando
## as dez estao preenchidas -- dez rodadas por jogador, uma marcacao por
## rodada, sem excecao.
##
## Tabela (normal / "de mao", que e na PRIMEIRA rolagem da rodada):
##   Uns..Seis      soma dos dados com aquele numero; bonus de 30 quando a
##                  soma dos seis chega a 60
##   Sequencia      1-2-3-4-5 ou 2-3-4-5-6: 20 / 25
##   Full House     trinca + par de outro valor: 30 / 35
##   Quadra         quatro (ou cinco) iguais: 40 / 45
##   General        cinco iguais: 50 / 100

const DADOS := 5
const MAX_ROLAGENS := 3
const TURNOS := 10

const CATEGORIAS: Array[String] = [
	"um", "dois", "tres", "quatro", "cinco", "seis",
	"sequencia", "full", "quadra", "general",
]
const NUMEROS: Array[String] = ["um", "dois", "tres", "quatro", "cinco", "seis"]
const COMBINACOES: Array[String] = ["sequencia", "full", "quadra", "general"]

## Pontos das combinacoes: [normal, de mao].
const PONTOS := {
	"sequencia": [20, 25],
	"full": [30, 35],
	"quadra": [40, 45],
	"general": [50, 100],
}

const BONUS := 30
const BONUS_LIMIAR := 60

## Ordem de preferencia quando duas categorias rendem o mesmo: a combinacao
## rara antes do numero, o numero alto antes do baixo.
const PRIORIDADE: Array[String] = [
	"general", "quadra", "full", "sequencia",
	"seis", "cinco", "quatro", "tres", "dois", "um",
]

## O que se risca primeiro quando a rodada nao rendeu: o que vale menos e o
## que e mais dificil de vir. Os Uns custam no maximo 5 pontos; o General
## quase nunca aparece; a Quadra e os Seis ficam por ultimo.
const ORDEM_RISCAR: Array[String] = [
	"um", "dois", "general", "tres", "sequencia", "quatro", "full", "cinco", "quadra", "seis",
]


static func nova_folha() -> Dictionary:
	return {}


## Quantos dados de cada valor: indice 1..6 (o 0 fica vazio).
static func contagem(dados: Array) -> Array[int]:
	var c: Array[int] = [0, 0, 0, 0, 0, 0, 0]
	for d in dados:
		var v := int(d)
		if v >= 1 and v <= 6:
			c[v] += 1
	return c


## O numero de uma categoria de numero ("tres" -> 3), ou 0 para combinacao.
static func numero_de(cat: String) -> int:
	var i := NUMEROS.find(cat)
	return i + 1 if i >= 0 else 0


static func maior_repeticao(dados: Array) -> int:
	var c := contagem(dados)
	var m := 0
	for v in range(1, 7):
		m = maxi(m, c[v])
	return m


static func e_sequencia(dados: Array) -> bool:
	if dados.size() != DADOS:
		return false
	var ordenados: Array = dados.duplicate()
	ordenados.sort()
	return ordenados == [1, 2, 3, 4, 5] or ordenados == [2, 3, 4, 5, 6]


static func e_full(dados: Array) -> bool:
	var c := contagem(dados)
	var tem_trinca := false
	var tem_par := false
	for v in range(1, 7):
		if c[v] == 3:
			tem_trinca = true
		elif c[v] == 2:
			tem_par = true
	return tem_trinca and tem_par


static func e_quadra(dados: Array) -> bool:
	return maior_repeticao(dados) >= 4


static func e_general(dados: Array) -> bool:
	return dados.size() == DADOS and maior_repeticao(dados) == 5


## Quanto `dados` renderiam em `cat`. `de_mao` e a primeira rolagem da rodada.
static func score_for(cat: String, dados: Array, de_mao: bool = false) -> int:
	var n := numero_de(cat)
	if n > 0:
		return contagem(dados)[n] * n
	var feito := false
	match cat:
		"sequencia": feito = e_sequencia(dados)
		"full": feito = e_full(dados)
		"quadra": feito = e_quadra(dados)
		"general": feito = e_general(dados)
		_: return 0
	if not feito:
		return 0
	var tabela: Array = PONTOS[cat]
	return int(tabela[1] if de_mao else tabela[0])


## Verdadeiro quando a marcacao "de mao" rendeu o bonus: combinacao feita na
## primeira rolagem. Numero de mao nao tem bonus, e combinacao zerada tambem nao.
static func bonus_de_mao(cat: String, dados: Array) -> bool:
	return cat in COMBINACOES and score_for(cat, dados, true) > 0


static func esta_livre(folha: Dictionary, cat: String) -> bool:
	return cat in CATEGORIAS and not folha.has(cat)


static func pode_marcar(folha: Dictionary, cat: String) -> bool:
	return esta_livre(folha, cat)


static func categorias_livres(folha: Dictionary) -> Array[String]:
	var livres: Array[String] = []
	for cat in CATEGORIAS:
		if not folha.has(cat):
			livres.append(cat)
	return livres


## Grava `cat` na folha com o que os dados rendem (zero = riscou). Devolve os
## pontos, ou -1 quando a categoria nao esta livre.
static func marcar(folha: Dictionary, cat: String, dados: Array, de_mao: bool = false) -> int:
	if not pode_marcar(folha, cat):
		return -1
	var pontos := score_for(cat, dados, de_mao)
	folha[cat] = pontos
	return pontos


static func soma_numeros(folha: Dictionary) -> int:
	var soma := 0
	for cat in NUMEROS:
		soma += int(folha.get(cat, 0))
	return soma


static func bonus(folha: Dictionary) -> int:
	return BONUS if soma_numeros(folha) >= BONUS_LIMIAR else 0


static func total(folha: Dictionary) -> int:
	var soma := 0
	for cat in CATEGORIAS:
		soma += int(folha.get(cat, 0))
	return soma + bonus(folha)


static func turnos_jogados(folha: Dictionary) -> int:
	var n := 0
	for cat in CATEGORIAS:
		if folha.has(cat):
			n += 1
	return n


static func completa(folha: Dictionary) -> bool:
	return turnos_jogados(folha) >= TURNOS


## Quantas categorias foram riscadas (gravadas com zero).
static func riscadas(folha: Dictionary) -> int:
	var n := 0
	for cat in CATEGORIAS:
		if folha.has(cat) and int(folha[cat]) == 0:
			n += 1
	return n


static func tem_general(folha: Dictionary) -> bool:
	return int(folha.get("general", 0)) > 0


## A categoria livre que mais rende com estes dados; empate vai para a
## combinacao rara e depois para o numero alto. Quando nada rende, a que se
## deve riscar. Vazio so com a folha completa.
static func best_category(dados: Array, folha: Dictionary, de_mao: bool = false) -> String:
	var melhor := ""
	var melhor_pontos := 0
	for cat in PRIORIDADE:
		if not esta_livre(folha, cat):
			continue
		var p := score_for(cat, dados, de_mao)
		if p > melhor_pontos:
			melhor_pontos = p
			melhor = cat
	if melhor_pontos > 0:
		return melhor
	return categoria_para_riscar(folha)


static func categoria_para_riscar(folha: Dictionary) -> String:
	for cat in ORDEM_RISCAR:
		if esta_livre(folha, cat):
			return cat
	return ""


## Indice do maior total, ou -1 quando o maior esta empatado.
static func vencedor(totais: Array) -> int:
	var melhor := -1
	var melhor_total := -1
	var empatado := false
	for i in totais.size():
		var t := int(totais[i])
		if t > melhor_total:
			melhor_total = t
			melhor = i
			empatado = false
		elif t == melhor_total:
			empatado = true
	return -1 if empatado else melhor


## Meta da partida solo por degrau da escada: 105 no primeiro, 240 no decimo.
static func meta_solo(nivel: int) -> int:
	return 90 + 15 * clampi(nivel, 1, 10)


## Uma acao de rolagem e legal neste ponto da rodada?
static func rolagem_valida(acao: Dictionary, rolagem: int) -> bool:
	if rolagem >= MAX_ROLAGENS:
		return false
	var valores: Variant = acao.get("values", null)
	if not (valores is Array) or (valores as Array).size() != DADOS:
		return false
	for v in valores:
		if not (v is int or v is float) or int(v) < 1 or int(v) > 6:
			return false
	var presos: Variant = acao.get("held", [])
	return presos is Array
