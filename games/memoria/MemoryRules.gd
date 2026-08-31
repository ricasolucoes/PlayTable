class_name MemoryRules
extends RefCounted

## Regras do Jogo da Memória.
##
## Falava de `Card` e de `custom_data["pair_id"]`, um modelo que `MemoryGame`
## nunca usou: a cena monta os próprios `Control` com `symbol_type: int` e
## comparava os dois símbolos inline. A regra ficava sem chamador e o jogo sem
## regra. `Deck.create_memory_deck()`, que existia só para alimentar aquele
## modelo, saiu junto — nada além de um teste a chamava.

## Quantos pares uma partida tem.
const TOTAL_PAIRS := 8

## Cada vitoria fecha a partida no DifficultyManager e a proxima leitura usa
## um tabuleiro maior. O nivel 3 e a abertura atual (4x4), para que quem ja
## joga Memoria nao encontre uma mesa diferente sem ter vencido antes.
## O Vector2i e (colunas, fileiras). Todos os produtos sao pares, entao cada
## carta sempre tem exatamente uma companheira.
const BOARD_BY_LEVEL := {
	1: Vector2i(3, 4),   # 6 pares
	2: Vector2i(4, 4),   # 8 pares
	3: Vector2i(4, 4),   # abertura atual
	4: Vector2i(4, 5),   # 10 pares
	5: Vector2i(4, 6),   # 12 pares
	6: Vector2i(5, 6),   # 15 pares
	7: Vector2i(6, 6),   # 18 pares
	8: Vector2i(6, 7),   # 21 pares
	9: Vector2i(6, 8),   # 24 pares
	10: Vector2i(7, 8),  # 28 pares
}


static func board_size_for_level(level: int) -> Vector2i:
	var nivel := clampi(level, 1, 10)
	return BOARD_BY_LEVEL.get(nivel, BOARD_BY_LEVEL[3])


static func total_pairs_for_level(level: int) -> int:
	var board := board_size_for_level(level)
	return board.x * board.y / 2


## Monta o baralho por identificador de simbolo. Os oito primeiros continuam
## sendo os simbolos desenhados originalmente; os seguintes usam as variacoes
## geometricas da carta, permitindo chegar aos 28 pares sem repetir uma figura.
static func symbol_pool_for_pairs(total_pairs: int) -> Array[int]:
	var pool: Array[int] = []
	for symbol in range(maxi(total_pairs, 0)):
		pool.append(symbol)
		pool.append(symbol)
	return pool


## Duas cartas viradas formam par quando mostram o mesmo símbolo.
static func symbols_match(first_symbol: int, second_symbol: int) -> bool:
	return first_symbol == second_symbol


## A partida acaba quando todos os pares saíram.
##
## O `>=` não é preciosismo: `MemoryGame` comparava com `==`, e um par contado
## duas vezes por um clique duplo deixaria a partida sem fim.
static func is_game_won(pairs_found: int, total_pairs: int = TOTAL_PAIRS) -> bool:
	return pairs_found >= total_pairs and total_pairs > 0


## Retorna 1, 2 ou 0 para empate. Usado pelo modo local, que transforma os
## pares encontrados em uma disputa sem alterar a regra das cartas.
static func winner_for_scores(player_one_score: int, player_two_score: int) -> int:
	if player_one_score > player_two_score:
		return 1
	if player_two_score > player_one_score:
		return 2
	return 0
