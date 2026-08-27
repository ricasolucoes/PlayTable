class_name NimRules
extends RefCounted

## NimRules: Motor de Regras Matemáticas e IA do Jogo de Nim.
##
## Implementa a teoria dos jogos combinatórios e o Teorema de Bouton para o cálculo
## exato de Nim-Sum (XOR), posições P (perdedoras para quem joga) e N (vencedoras),
## suportando os modos Normal Play e Misère (Marienbad).

const PRESETS: Dictionary = {
	"classic_3": [3, 4, 5],
	"pyramid_4": [1, 3, 5, 7],
	"simple_3": [1, 2, 3],
	"wide_5": [1, 2, 3, 4, 5]
}

const PLAYER_HUMAN: int = 1
const PLAYER_AI: int = 2
const PLAYER_2: int = 2


## Devolve uma cópia fresca das pilhas para o preset especificado.
static func create_heaps(preset_key: String = "classic_3") -> Array[int]:
	var template: Array = PRESETS.get(preset_key, [3, 4, 5])
	var result: Array[int] = []
	for count: int in template:
		result.append(count)
	return result


## Calcula o Nim-Sum (XOR de todas as quantidades das pilhas).
static func calculate_nim_sum(heaps: Array) -> int:
	var xor_sum: int = 0
	for count in heaps:
		xor_sum ^= int(count)
	return xor_sum


## Valida se a retirada é legal.
static func is_valid_move(heaps: Array, heap_idx: int, take_count: int) -> bool:
	if heap_idx < 0 or heap_idx >= heaps.size():
		return false
	if take_count < 1:
		return false
	var current_count: int = int(heaps[heap_idx])
	return take_count <= current_count


## Aplica a retirada e devolve uma nova cópia do array de pilhas.
static func apply_move(heaps: Array, heap_idx: int, take_count: int) -> Array[int]:
	var new_heaps: Array[int] = []
	for i in range(heaps.size()):
		var c: int = int(heaps[i])
		if i == heap_idx:
			c = maxi(0, c - take_count)
		new_heaps.append(c)
	return new_heaps


## Aplica a retirada in-place no array existente.
static func apply_move_inplace(heaps: Array, heap_idx: int, take_count: int) -> void:
	if heap_idx >= 0 and heap_idx < heaps.size():
		heaps[heap_idx] = maxi(0, int(heaps[heap_idx]) - take_count)


## Reverte uma jogada in-place adicionando as peças de volta.
static func undo_move_inplace(heaps: Array, heap_idx: int, take_count: int) -> void:
	if heap_idx >= 0 and heap_idx < heaps.size():
		heaps[heap_idx] = int(heaps[heap_idx]) + take_count


## Verifica se todas as pilhas estão vazias.
static func is_game_over(heaps: Array) -> bool:
	for count in heaps:
		if int(count) > 0:
			return false
	return true


## Conta o total de peças restantes no tabuleiro.
static func count_total_pieces(heaps: Array) -> int:
	var total: int = 0
	for count in heaps:
		total += int(count)
	return total


## Determina o vencedor da partida.
## last_player: O jogador que acabou de fazer o lance que zerou a mesa.
## is_misere: Se true, quem retirou a última peça perde.
static func get_winner(last_player: int, is_misere: bool) -> int:
	if is_misere:
		# No modo Misère, quem pega a última peça perde (o outro vence)
		return 3 - last_player # 1 -> 2, 2 -> 1
	else:
		# No modo Normal, quem pega a última peça vence
		return last_player


## Gera todas as jogadas legais possíveis a partir da posição atual.
## Retorna lista de Dictionaries com {"heap": int, "take": int}.
static func get_all_valid_moves(heaps: Array) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	for h in range(heaps.size()):
		var count: int = int(heaps[h])
		for t in range(1, count + 1):
			moves.append({"heap": h, "take": t})
	return moves


## Chance de jogar a jogada matematicamente otima, por degrau da escada do
## DifficultyManager.
##
## O Nim andava por tres botoes -- Facil (30%), Medio (75%), Mestre (100%) --
## num campo proprio que nascia sempre em "Mestre" e sumia ao fechar a cena,
## enquanto a escada do jogo andava em paralelo mexendo so no XP.
const CHANCE_OTIMA := [0.15, 0.28, 0.40, 0.52, 0.64, 0.74, 0.84, 0.92, 0.98, 1.0]


## A jogada da IA no degrau pedido. O degrau vira a chance de jogar a jogada
## matematicamente perfeita (Teorema de Bouton); no resto das vezes ela joga
## uma jogada legal qualquer.
static func get_move(heaps: Array, is_misere: bool, level: int) -> Dictionary:
	var lvl := clampi(level, 1, CHANCE_OTIMA.size())
	return _jogar(heaps, is_misere, float(CHANCE_OTIMA[lvl - 1]))


## IA com Teorema de Bouton e estratégia de Nim-Sum ótimo para Normal e Misère.
## difficulty: "easy" (30% ótimo), "medium" (75% ótimo), "hard" (100% ótimo).
static func get_best_ai_move(heaps: Array, is_misere: bool = true, difficulty: String = "hard") -> Dictionary:
	var optimal_chance: float = 1.0
	match difficulty:
		"easy":
			optimal_chance = 0.30
		"medium":
			optimal_chance = 0.75
	return _jogar(heaps, is_misere, optimal_chance)


static func _jogar(heaps: Array, is_misere: bool, optimal_chance: float) -> Dictionary:
	var all_moves := get_all_valid_moves(heaps)
	if all_moves.is_empty():
		return {"heap": -1, "take": 0}

	if randf() > optimal_chance:
		# Jogada aleatória (casual)
		return all_moves[randi() % all_moves.size()]

	# Cálculo da jogada matematicamente ótima
	var optimal_move := _calculate_optimal_move(heaps, is_misere)
	if optimal_move["heap"] != -1:
		return optimal_move

	# Se já estiver em P-position (Nim-Sum = 0), faz a jogada mais defensiva
	return _get_defensive_move(heaps)


## Calcula a jogada matematicamente perfeita (Teorema de Bouton).
static func _calculate_optimal_move(heaps: Array, is_misere: bool) -> Dictionary:
	# Caso especial no Misère: se após a jogada apenas pilhas de tamanho <= 1 restarem
	if is_misere:
		var big_heaps: Array[int] = []
		var count_ones: int = 0
		for i in range(heaps.size()):
			var c: int = int(heaps[i])
			if c > 1:
				big_heaps.append(i)
			elif c == 1:
				count_ones += 1

		# Se há exatamente 1 pilha com mais de 1 peça:
		if big_heaps.size() == 1:
			var heap_idx: int = big_heaps[0]
			var heap_size: int = int(heaps[heap_idx])
			# Queremos deixar um número ímpar de pilhas com 1 peça
			if count_ones % 2 == 0:
				# Número atual de '1's é par -> reduz a pilha grande para 1 (sobra ímpar)
				return {"heap": heap_idx, "take": heap_size - 1}
			else:
				# Número atual de '1's é ímpar -> esvazia a pilha grande (sobra ímpar)
				return {"heap": heap_idx, "take": heap_size}

	# Estratégia padrão baseada no Nim-Sum
	var nim_sum := calculate_nim_sum(heaps)
	if nim_sum != 0:
		for i in range(heaps.size()):
			var c: int = int(heaps[i])
			var target: int = c ^ nim_sum
			if target < c:
				var take: int = c - target
				return {"heap": i, "take": take}

	# Nenhuma jogada converte para Nim-Sum = 0 (posição já é P-position)
	return {"heap": -1, "take": 0}


## Jogada defensiva quando o jogador já está em P-position (tenta retirar 1 da maior pilha).
static func _get_defensive_move(heaps: Array) -> Dictionary:
	var max_heap_idx: int = -1
	var max_count: int = 0
	for i in range(heaps.size()):
		var c: int = int(heaps[i])
		if c > max_count:
			max_count = c
			max_heap_idx = i

	if max_heap_idx != -1 and max_count > 0:
		return {"heap": max_heap_idx, "take": 1}

	var all := get_all_valid_moves(heaps)
	if not all.is_empty():
		return all[0]
	return {"heap": -1, "take": 0}
