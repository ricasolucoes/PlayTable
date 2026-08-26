class_name BackgammonRules
extends RefCounted

## BackgammonRules: Motor de Regras Oficiais, Validação e IA de Gamão.
##
## Implementa todas as regras internacionais de Gamão:
## - 24 pontos (1 a 24), barra central e bandejas de recolhimento (bear-off).
## - Peças Brancas (Jogador 1 / Marfim): movem de 24 para 1, recolhem em 1..6.
## - Peças Pretas (Jogador 2 / IA / Obsidiana): movem de 1 para 24, recolhem em 19..24.
## - Rolagem de dados (1 a 6) e regras de duplas (4 movimentos).
## - Captura de blots (peças solitárias) para a Barra.
## - Reentrada obrigatória da Barra antes de mover peças do tabuleiro.
## - Bloqueio de pontos com 2 ou mais peças inimigas.
## - Fase de recolhimento (Bear-off) e cálculo de Pip Count em tempo real.
## - IA heurística tática com múltiplos níveis de dificuldade.

const PLAYER_NONE: int = 0
const PLAYER_WHITE: int = 1 # Humano / P1 (move de 24 -> 1)
const PLAYER_BLACK: int = 2 # IA / P2 (move de 1 -> 24)

const TOTAL_POINTS: int = 24
const CHECKERS_PER_PLAYER: int = 15

# Identificador especial para a Barra
const BAR_POS: int = 0
# Identificador especial para a bandeja de recolhimento (Bear-off)
const BEAR_OFF_POS: int = 25


## Cria e retorna o estado inicial padrão de um jogo de Gamão.
## board: Array de 25 inteiros (índices 1 a 24 representam os pontos).
## Valores positivos = peças Brancas; Valores negativos = peças Pretas.
static func create_initial_state() -> Dictionary:
	var board: Array[int] = []
	board.resize(25)
	for i in range(25):
		board[i] = 0

	# Posição inicial clássica internacional de Gamão:
	# Brancas (P1, positivas):
	board[24] = 2
	board[13] = 5
	board[8] = 3
	board[6] = 5

	# Pretas (P2, negativas):
	board[1] = -2
	board[12] = -5
	board[17] = -3
	board[19] = -5

	return {
		"board": board,
		"bar_white": 0,
		"bar_black": 0,
		"borne_white": 0,
		"borne_black": 0
	}


## Clona profundamente o estado da partida.
static func clone_state(state: Dictionary) -> Dictionary:
	var new_board: Array[int] = []
	new_board.resize(25)
	for i in range(25):
		new_board[i] = int(state["board"][i])

	return {
		"board": new_board,
		"bar_white": int(state.get("bar_white", 0)),
		"bar_black": int(state.get("bar_black", 0)),
		"borne_white": int(state.get("borne_white", 0)),
		"borne_black": int(state.get("borne_black", 0))
	}


## Rola dois dados aleatórios de 1 a 6 e retorna a lista de movimentos disponíveis.
## Se os dados forem iguais (duplas), retorna 4 instâncias do valor.
static func roll_dice() -> Dictionary:
	var d1: int = (randi() % 6) + 1
	var d2: int = (randi() % 6) + 1
	var moves: Array[int] = []
	if d1 == d2:
		moves = [d1, d1, d1, d1]
	else:
		moves = [d1, d2]
	return {
		"d1": d1,
		"d2": d2,
		"is_double": (d1 == d2),
		"moves": moves
	}


## Verifica se um jogador possui peças na Barra.
static func has_checkers_on_bar(state: Dictionary, player: int) -> bool:
	if player == PLAYER_WHITE:
		return int(state.get("bar_white", 0)) > 0
	else:
		return int(state.get("bar_black", 0)) > 0


## Obtém a quantidade de peças na Barra para o jogador.
static func get_bar_count(state: Dictionary, player: int) -> int:
	if player == PLAYER_WHITE:
		return int(state.get("bar_white", 0))
	else:
		return int(state.get("bar_black", 0))


## Obtém a quantidade de peças recolhidas (borne off) para o jogador.
static func get_borne_count(state: Dictionary, player: int) -> int:
	if player == PLAYER_WHITE:
		return int(state.get("borne_white", 0))
	else:
		return int(state.get("borne_black", 0))


## Verifica se o jogador está apto a recolher peças (Bear-off).
## Todos os 15 checkers devem estar no quadrante final (Home Board) ou já recolhidos.
## Brancas: Home Board = pontos 1..6.
## Pretas: Home Board = pontos 19..24.
static func can_bear_off(state: Dictionary, player: int) -> bool:
	if has_checkers_on_bar(state, player):
		return false

	var board: Array = state["board"]
	if player == PLAYER_WHITE:
		# Verifica se há peças brancas fora do quadrante 1..6
		for pt in range(7, 25):
			if int(board[pt]) > 0:
				return false
		return true
	else:
		# Verifica se há peças pretas fora do quadrante 19..24
		for pt in range(1, 19):
			if int(board[pt]) < 0:
				return false
		return true


## Retorna se o ponto de destino está aberto para o jogador (<= 1 peça inimiga).
static func is_point_open(state: Dictionary, target_pt: int, player: int) -> bool:
	if target_pt < 1 or target_pt > 24:
		return false
	var val: int = int(state["board"][target_pt])
	if player == PLAYER_WHITE:
		# Aberto se vazio (0), com peças brancas (> 0) ou no máximo 1 peça preta (-1)
		return val >= -1
	else:
		# Aberto se vazio (0), com peças pretas (< 0) ou no máximo 1 peça branca (1)
		return val <= 1


## Retorna se a casa contém um blot inimigo (exatamente 1 peça inimiga).
static func is_enemy_blot(state: Dictionary, target_pt: int, player: int) -> bool:
	if target_pt < 1 or target_pt > 24:
		return false
	var val: int = int(state["board"][target_pt])
	if player == PLAYER_WHITE:
		return val == -1
	else:
		return val == 1


## Retorna a lista de jogadas válidas a partir de uma origem específica para um dado 'die'.
## 'from_pos' pode ser BAR_POS (0) ou um ponto de 1 a 24.
## Retorna Dictionary {"valid": bool, "to": int, "is_hit": bool, "is_bear_off": bool}
static func validate_single_move(state: Dictionary, player: int, from_pos: int, die: int) -> Dictionary:
	var invalid_res := {"valid": false, "to": -1, "is_hit": false, "is_bear_off": false}
	if die <= 0:
		return invalid_res

	var board: Array = state["board"]

	# Caso 1: Movimento a partir da Barra
	if from_pos == BAR_POS:
		if not has_checkers_on_bar(state, player):
			return invalid_res
		var target_pt: int = (25 - die) if player == PLAYER_WHITE else die
		if is_point_open(state, target_pt, player):
			var is_hit: bool = is_enemy_blot(state, target_pt, player)
			return {"valid": true, "to": target_pt, "is_hit": is_hit, "is_bear_off": false}
		return invalid_res

	# Se houver peças na Barra, é OBRIGATÓRIO mover primeiro da Barra
	if has_checkers_on_bar(state, player):
		return invalid_res

	if from_pos < 1 or from_pos > 24:
		return invalid_res

	# Verifica se o jogador possui peças na posição de origem
	var count_at_from: int = int(board[from_pos])
	if player == PLAYER_WHITE and count_at_from <= 0:
		return invalid_res
	if player == PLAYER_BLACK and count_at_from >= 0:
		return invalid_res

	# Caso 2: Movimento regular ou Bear-Off
	if player == PLAYER_WHITE:
		var target_pt: int = from_pos - die
		if target_pt >= 1:
			if is_point_open(state, target_pt, player):
				var is_hit: bool = is_enemy_blot(state, target_pt, player)
				return {"valid": true, "to": target_pt, "is_hit": is_hit, "is_bear_off": false}
			return invalid_res
		else:
			# Tentativa de Bear-Off (target_pt <= 0)
			if not can_bear_off(state, player):
				return invalid_res
			# Se o lance for exato (from_pos == die)
			if from_pos == die:
				return {"valid": true, "to": BEAR_OFF_POS, "is_hit": false, "is_bear_off": true}
			# Se o dado for maior que a posição (die > from_pos), só vale se não houver
			# peças em pontos maiores (mais distantes do fim)
			if die > from_pos:
				for p in range(from_pos + 1, 7):
					if int(board[p]) > 0:
						return invalid_res
				return {"valid": true, "to": BEAR_OFF_POS, "is_hit": false, "is_bear_off": true}
			return invalid_res
	else:
		# Jogador 2 (Pretas, movem de 1 para 24)
		var target_pt: int = from_pos + die
		if target_pt <= 24:
			if is_point_open(state, target_pt, player):
				var is_hit: bool = is_enemy_blot(state, target_pt, player)
				return {"valid": true, "to": target_pt, "is_hit": is_hit, "is_bear_off": false}
			return invalid_res
		else:
			# Tentativa de Bear-Off (target_pt >= 25)
			if not can_bear_off(state, player):
				return invalid_res
			# Se o lance for exato (25 - from_pos == die)
			if (25 - from_pos) == die:
				return {"valid": true, "to": BEAR_OFF_POS, "is_hit": false, "is_bear_off": true}
			# Se o dado for maior, só vale se não houver peças em pontos menores (mais distantes)
			if die > (25 - from_pos):
				for p in range(19, from_pos):
					if int(board[p]) < 0:
						return invalid_res
				return {"valid": true, "to": BEAR_OFF_POS, "is_hit": false, "is_bear_off": true}
			return invalid_res


## Aplica uma jogada válida no estado fornecido (modificação in-place).
static func apply_move_inplace(state: Dictionary, player: int, from_pos: int, die: int) -> bool:
	var move_check := validate_single_move(state, player, from_pos, die)
	if not move_check["valid"]:
		return false

	var to_pos: int = int(move_check["to"])
	var board: Array = state["board"]

	# 1. Remove da origem
	if from_pos == BAR_POS:
		if player == PLAYER_WHITE:
			state["bar_white"] = maxi(0, int(state["bar_white"]) - 1)
		else:
			state["bar_black"] = maxi(0, int(state["bar_black"]) - 1)
	else:
		if player == PLAYER_WHITE:
			board[from_pos] = int(board[from_pos]) - 1
		else:
			board[from_pos] = int(board[from_pos]) + 1

	# 2. Adiciona ao destino
	if to_pos == BEAR_OFF_POS:
		if player == PLAYER_WHITE:
			state["borne_white"] = int(state["borne_white"]) + 1
		else:
			state["borne_black"] = int(state["borne_black"]) + 1
	else:
		var target_val: int = int(board[to_pos])
		if player == PLAYER_WHITE:
			if target_val == -1:
				# Capturou blot preto -> envia para a barra preta
				board[to_pos] = 1
				state["bar_black"] = int(state["bar_black"]) + 1
			else:
				board[to_pos] = target_val + 1
		else:
			if target_val == 1:
				# Capturou blot branco -> envia para a barra branca
				board[to_pos] = -1
				state["bar_white"] = int(state["bar_white"]) + 1
			else:
				board[to_pos] = target_val - 1

	return true


## Obtém todas as jogadas legais individuais que podem ser feitas dado o estado e a lista de dados disponíveis.
## Retorna lista de Dictionaries: [{"from": int, "die": int, "to": int, "is_hit": bool, "is_bear_off": bool}]
static func get_all_legal_single_moves(state: Dictionary, player: int, available_dice: Array) -> Array[Dictionary]:
	var moves: Array[Dictionary] = []
	if available_dice.is_empty():
		return moves

	# Extrai valores únicos de dados para não duplicar verificações
	var unique_dice: Array[int] = []
	for d in available_dice:
		var val: int = int(d)
		if not unique_dice.has(val):
			unique_dice.append(val)

	# Se houver peças na barra, só podemos mover da barra
	if has_checkers_on_bar(state, player):
		for d in unique_dice:
			var res := validate_single_move(state, player, BAR_POS, d)
			if res["valid"]:
				moves.append({
					"from": BAR_POS,
					"die": d,
					"to": res["to"],
					"is_hit": res["is_hit"],
					"is_bear_off": res["is_bear_off"]
				})
		return moves

	# Movimentos a partir dos 24 pontos
	var board: Array = state["board"]
	for pt in range(1, 25):
		var count: int = int(board[pt])
		if (player == PLAYER_WHITE and count > 0) or (player == PLAYER_BLACK and count < 0):
			for d in unique_dice:
				var res := validate_single_move(state, player, pt, d)
				if res["valid"]:
					moves.append({
						"from": pt,
						"die": d,
						"to": res["to"],
						"is_hit": res["is_hit"],
						"is_bear_off": res["is_bear_off"]
					})

	return moves


## Retorna os destinos válidos para uma peça selecionada em 'from_pos'.
## Retorna lista de Dictionaries com {"die": int, "to": int, "is_hit": bool, "is_bear_off": bool}
static func get_valid_moves_for_position(state: Dictionary, player: int, from_pos: int, available_dice: Array) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var seen_targets: Array[int] = []

	var unique_dice: Array[int] = []
	for d in available_dice:
		var val: int = int(d)
		if not unique_dice.has(val):
			unique_dice.append(val)

	for d in unique_dice:
		var res := validate_single_move(state, player, from_pos, d)
		if res["valid"]:
			var to_pos: int = int(res["to"])
			# Se o destino já foi visto com outro dado de mesmo resultado, mantém o dado correto
			if not seen_targets.has(to_pos):
				seen_targets.append(to_pos)
				results.append({
					"die": d,
					"to": to_pos,
					"is_hit": res["is_hit"],
					"is_bear_off": res["is_bear_off"]
				})
	return results


## Calcula o Pip Count de um jogador (distância restante acumulada de todas as peças).
static func calculate_pip_count(state: Dictionary, player: int) -> int:
	var pips: int = 0
	var board: Array = state["board"]

	if player == PLAYER_WHITE:
		pips += int(state.get("bar_white", 0)) * 25
		for pt in range(1, 25):
			var val: int = int(board[pt])
			if val > 0:
				pips += val * pt
	else:
		pips += int(state.get("bar_black", 0)) * 25
		for pt in range(1, 25):
			var val: int = int(board[pt])
			if val < 0:
				pips += (-val) * (25 - pt)

	return pips


## Verifica se o jogo terminou (algum jogador recolheu todos os 15 checkers).
static func is_game_over(state: Dictionary) -> bool:
	return int(state.get("borne_white", 0)) >= CHECKERS_PER_PLAYER or int(state.get("borne_black", 0)) >= CHECKERS_PER_PLAYER


## Determina o vencedor (1 para Brancas, 2 para Pretas, 0 se ainda não terminou).
static func get_winner(state: Dictionary) -> int:
	if int(state.get("borne_white", 0)) >= CHECKERS_PER_PLAYER:
		return PLAYER_WHITE
	if int(state.get("borne_black", 0)) >= CHECKERS_PER_PLAYER:
		return PLAYER_BLACK
	return PLAYER_NONE


## Avalia a categoria de vitória: "single" (1x), "gammon" (2x), "backgammon" (3x).
static func get_win_type(state: Dictionary, winner: int) -> String:
	if winner == PLAYER_NONE:
		return "none"

	var loser: int = 3 - winner
	var loser_borne: int = get_borne_count(state, loser)

	if loser_borne > 0:
		return "single"

	# O perdedor não recolheu nenhuma peça -> pelo menos Gammon
	var loser_has_bar: bool = has_checkers_on_bar(state, loser)
	var board: Array = state["board"]
	var loser_in_winner_home: bool = false

	if winner == PLAYER_WHITE:
		# Home das brancas é 1..6; verifica se pretas têm peças em 1..6
		for pt in range(1, 7):
			if int(board[pt]) < 0:
				loser_in_winner_home = true
				break
	else:
		# Home das pretas é 19..24; verifica se brancas têm peças em 19..24
		for pt in range(19, 25):
			if int(board[pt]) > 0:
				loser_in_winner_home = true
				break

	if loser_has_bar or loser_in_winner_home:
		return "backgammon"
	return "gammon"


# ---------------------------------------------------------------------------
# Motor de Decisão e Heurística da IA
# ---------------------------------------------------------------------------

## Função de avaliação heurística de estado sob a perspectiva do jogador especificado.
static func evaluate_board(state: Dictionary, player: int) -> float:
	if get_winner(state) == player:
		return 10000.0
	var opponent: int = 3 - player
	if get_winner(state) == opponent:
		return -10000.0

	var my_borne: int = get_borne_count(state, player)
	var opp_borne: int = get_borne_count(state, opponent)
	var my_bar: int = get_bar_count(state, player)
	var opp_bar: int = get_bar_count(state, opponent)

	var my_pip: int = calculate_pip_count(state, player)
	var opp_pip: int = calculate_pip_count(state, opponent)

	# Diferença de corrida (pip count)
	var score: float = float(opp_pip - my_pip) * 1.8
	score += float(my_borne) * 35.0
	score -= float(opp_borne) * 35.0
	score -= float(my_bar) * 22.0
	score += float(opp_bar) * 22.0

	var board: Array = state["board"]
	var my_blots: int = 0
	var my_anchors: int = 0
	var my_home_anchors: int = 0

	for pt in range(1, 25):
		var val: int = int(board[pt])
		if player == PLAYER_WHITE:
			if val == 1:
				my_blots += 1
			elif val >= 2:
				my_anchors += 1
				if pt <= 6:
					my_home_anchors += 1
		else:
			if val == -1:
				my_blots += 1
			elif val <= -2:
				my_anchors += 1
				if pt >= 19:
					my_home_anchors += 1

	score -= float(my_blots) * 7.5
	score += float(my_anchors) * 6.0
	score += float(my_home_anchors) * 10.0

	return score


## Gera recursivamente todas as sequências possíveis de jogadas completas para o turno.
static func find_all_turn_sequences(state: Dictionary, player: int, available_dice: Array) -> Array[Array]:
	var results: Array[Array] = []
	_search_sequences(state, player, available_dice, [], results)
	return results


static func _search_sequences(curr_state: Dictionary, player: int, remaining_dice: Array, current_seq: Array, out_results: Array[Array]) -> void:
	var legal_moves := get_all_legal_single_moves(curr_state, player, remaining_dice)
	if legal_moves.is_empty():
		if not current_seq.is_empty():
			out_results.append(current_seq.duplicate())
		return

	for mv in legal_moves:
		var next_state := clone_state(curr_state)
		apply_move_inplace(next_state, player, mv["from"], mv["die"])

		var next_dice := remaining_dice.duplicate()
		var die_idx: int = next_dice.find(mv["die"])
		if die_idx != -1:
			next_dice.remove_at(die_idx)

		var next_seq := current_seq.duplicate()
		next_seq.append(mv)

		if next_dice.is_empty() or is_game_over(next_state):
			out_results.append(next_seq)
		else:
			_search_sequences(next_state, player, next_dice, next_seq, out_results)


## Obtém a melhor sequência de jogadas para a IA baseada na dificuldade.
static func get_best_ai_turn(state: Dictionary, player: int, available_dice: Array, difficulty: String = "hard") -> Array[Dictionary]:
	var sequences := find_all_turn_sequences(state, player, available_dice)
	if sequences.is_empty():
		return []

	# Filtra para manter sequências de tamanho máximo (regra: usar o máximo de dados possível)
	var max_len: int = 0
	for seq in sequences:
		if seq.size() > max_len:
			max_len = seq.size()

	var max_sequences: Array[Array] = []
	for seq in sequences:
		if seq.size() == max_len:
			max_sequences.append(seq)

	if max_sequences.is_empty():
		return []

	if difficulty == "easy" and randf() < 0.45:
		var chosen_seq: Array = max_sequences[randi() % max_sequences.size()]
		var typed_seq: Array[Dictionary] = []
		for item in chosen_seq:
			typed_seq.append(item as Dictionary)
		return typed_seq

	# Avalia os estados resultantes
	var best_score: float = -999999.0
	var scored_sequences: Array[Dictionary] = []

	for seq in max_sequences:
		var sim_state := clone_state(state)
		for mv in seq:
			apply_move_inplace(sim_state, player, mv["from"], mv["die"])
		var score := evaluate_board(sim_state, player)
		scored_sequences.append({"seq": seq, "score": score})
		if score > best_score:
			best_score = score

	# Ordena por score decrescente
	scored_sequences.sort_custom(func(a, b): return a["score"] > b["score"])

	if difficulty == "medium" and scored_sequences.size() > 1:
		var pick_idx: int = randi() % mini(3, scored_sequences.size())
		var chosen_seq: Array = scored_sequences[pick_idx]["seq"]
		var typed_seq: Array[Dictionary] = []
		for item in chosen_seq:
			typed_seq.append(item as Dictionary)
		return typed_seq

	var best_seq: Array = scored_sequences[0]["seq"]
	var typed_seq: Array[Dictionary] = []
	for item in best_seq:
		typed_seq.append(item as Dictionary)
	return typed_seq
