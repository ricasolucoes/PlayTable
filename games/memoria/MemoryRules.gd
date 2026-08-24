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


## Duas cartas viradas formam par quando mostram o mesmo símbolo.
static func symbols_match(first_symbol: int, second_symbol: int) -> bool:
	return first_symbol == second_symbol


## A partida acaba quando todos os pares saíram.
##
## O `>=` não é preciosismo: `MemoryGame` comparava com `==`, e um par contado
## duas vezes por um clique duplo deixaria a partida sem fim.
static func is_game_won(pairs_found: int, total_pairs: int = TOTAL_PAIRS) -> bool:
	return pairs_found >= total_pairs and total_pairs > 0
