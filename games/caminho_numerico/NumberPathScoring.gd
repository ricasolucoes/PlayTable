class_name NumberPathScoring
extends RefCounted

## Motor de cálculo de pontuação e gamificação para Caminho Numérico.
##
## Avalia a performance do jogador combinando:
## 1. Tamanho do Grid / Células Jogáveis: grids maiores concedem base maior.
## 2. Quantidade de Dicas: menos dicas requerem maior dedução lógica, aumentando o bônus.
## 3. Estrelas Obrigatórias Coletadas: bônus por cada estrela alcançada (150 pts cada).
## 4. Tempo de Conclusão / Tempo Limite: bônus de velocidade para resolução abaixo do Par Time / tempo restante.
## 5. Precisão: bônus de partida perfeita (sem erros/dicas) e penalidades moderadas.

const BASE_POINTS_PER_CELL := 100
const PAR_SECONDS_PER_CELL := 3.5
const TIME_BONUS_MULTIPLIER := 15.0
const TIME_LIMIT_BONUS_MULTIPLIER := 20.0
const STAR_BONUS := 150
const PERFECT_BONUS := 500
const MISTAKE_PENALTY := 40
const HINT_PENALTY := 80


static func calculate_score(
	grid_w: int,
	grid_h: int,
	clues_count: int,
	elapsed_time: float,
	mistakes: int = 0,
	hints: int = 0,
	stars_collected: int = 0,
	time_limit: float = 0.0
) -> Dictionary:
	var w := maxi(1, grid_w)
	var h := maxi(1, grid_h)
	var total_cells := w * h
	var base_points := total_cells * BASE_POINTS_PER_CELL

	# Bônus por menos dicas (células não reveladas)
	var safe_clues := clampi(clues_count, 1, total_cells)
	var empty_cells := maxi(0, total_cells - safe_clues)
	var clue_bonus := empty_cells * 60

	# Bônus de estrelas coletadas
	var safe_stars := maxi(0, stars_collected)
	var star_bonus := safe_stars * STAR_BONUS

	# Tempo ideal (Par time) ou bônus de tempo restante
	var par_time := float(total_cells) * PAR_SECONDS_PER_CELL
	var is_valid_time: bool = not is_nan(elapsed_time) and not is_inf(elapsed_time) and elapsed_time >= 0.0
	var safe_elapsed: float = elapsed_time if is_valid_time else 0.0
	var time_bonus := 0

	if is_valid_time:
		if time_limit > 0.0 and safe_elapsed < time_limit:
			var remaining_time: float = maxf(0.0, time_limit - safe_elapsed)
			time_bonus = int(remaining_time * TIME_LIMIT_BONUS_MULTIPLIER)
		elif time_limit <= 0.0 and safe_elapsed < par_time:
			time_bonus = int((par_time - safe_elapsed) * TIME_BONUS_MULTIPLIER)

	# Bônus de perfeição (sem erros e sem uso de dicas)
	var safe_mistakes := maxi(0, mistakes)
	var safe_hints := maxi(0, hints)
	var is_perfect := (safe_mistakes == 0 and safe_hints == 0)
	var perfect_bonus := PERFECT_BONUS if is_perfect else 0

	# Penalidades
	var penalty := safe_mistakes * MISTAKE_PENALTY + safe_hints * HINT_PENALTY

	var raw_total := base_points + clue_bonus + star_bonus + time_bonus + perfect_bonus - penalty
	var final_score := maxi(100, raw_total)

	# Rank alfanumérico
	var rank_str := "B"
	if is_perfect and time_bonus > 0:
		rank_str = "S"
	elif final_score >= base_points + clue_bonus + star_bonus:
		rank_str = "A"
	elif final_score >= base_points:
		rank_str = "B"
	else:
		rank_str = "C"

	return {
		"score": final_score,
		"base_points": base_points,
		"clue_bonus": clue_bonus,
		"star_bonus": star_bonus,
		"stars_collected": safe_stars,
		"time_bonus": time_bonus,
		"perfect_bonus": perfect_bonus,
		"penalty": penalty,
		"is_perfect": is_perfect,
		"perfect": is_perfect,
		"time": safe_elapsed,
		"time_limit": time_limit,
		"moves": total_cells + safe_mistakes,
		"grid_size": "%dx%d" % [w, h],
		"clues_count": safe_clues,
		"mistakes": safe_mistakes,
		"hints": safe_hints,
		"rank": rank_str,
	}


static func format_time(seconds: float) -> String:
	if is_nan(seconds) or is_inf(seconds):
		return "00:00"
	var total_secs := int(maxf(0.0, seconds))
	var mins := total_secs / 60
	var secs := total_secs % 60
	return "%02d:%02d" % [mins, secs]
