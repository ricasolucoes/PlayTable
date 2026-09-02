class_name NumberPathScoring
extends RefCounted

## Motor de cálculo de pontuação e gamificação para Caminho Numérico.
##
## Avalia a performance do jogador combinando:
## 1. Tamanho do Grid: grids maiores (ex: 5x5=2500, 6x6=3600) concedem base maior.
## 2. Quantidade de Dicas: menos dicas requerem maior dedução lógica, aumentando o bônus.
## 3. Tempo de Conclusão: bônus de velocidade para resolução abaixo do Par Time.
## 4. Precisão: bônus de partida perfeita (sem erros/dicas) e penalidades moderadas.

const BASE_POINTS_PER_CELL := 100
const PAR_SECONDS_PER_CELL := 3.5
const TIME_BONUS_MULTIPLIER := 15.0
const PERFECT_BONUS := 500
const MISTAKE_PENALTY := 40
const HINT_PENALTY := 80


static func calculate_score(
	grid_w: int,
	grid_h: int,
	clues_count: int,
	elapsed_time: float,
	mistakes: int = 0,
	hints: int = 0
) -> Dictionary:
	var total_cells := grid_w * grid_h
	var base_points := total_cells * BASE_POINTS_PER_CELL

	# Bônus por menos dicas (células não reveladas)
	var empty_cells := maxi(0, total_cells - clues_count)
	var clue_bonus := empty_cells * 60

	# Tempo ideal (Par time) proporcional à quantidade de células
	var par_time := total_cells * PAR_SECONDS_PER_CELL
	var time_bonus := 0
	if elapsed_time > 0.0 and elapsed_time < par_time:
		time_bonus = int((par_time - elapsed_time) * TIME_BONUS_MULTIPLIER)

	# Bônus de perfeição (sem erros e sem uso de dicas)
	var is_perfect := (mistakes == 0 and hints == 0)
	var perfect_bonus := PERFECT_BONUS if is_perfect else 0

	# Penalidades
	var penalty := mistakes * MISTAKE_PENALTY + hints * HINT_PENALTY

	var raw_total := base_points + clue_bonus + time_bonus + perfect_bonus - penalty
	var final_score := maxi(100, raw_total)

	# Rank alfanumérico
	var rank_str := "B"
	if is_perfect and time_bonus > 0:
		rank_str = "S"
	elif final_score >= base_points + clue_bonus:
		rank_str = "A"
	elif final_score >= base_points:
		rank_str = "B"
	else:
		rank_str = "C"

	return {
		"score": final_score,
		"base_points": base_points,
		"clue_bonus": clue_bonus,
		"time_bonus": time_bonus,
		"perfect_bonus": perfect_bonus,
		"penalty": penalty,
		"is_perfect": is_perfect,
		"perfect": is_perfect,
		"time": elapsed_time,
		"moves": total_cells + mistakes,
		"grid_size": "%dx%d" % [grid_w, grid_h],
		"clues_count": clues_count,
		"mistakes": mistakes,
		"hints": hints,
		"rank": rank_str,
	}


static func format_time(seconds: float) -> String:
	var total_secs := int(maxf(0.0, seconds))
	var mins := total_secs / 60
	var secs := total_secs % 60
	return "%02d:%02d" % [mins, secs]
