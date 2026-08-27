extends Node

## Traduz o fim de partida em progresso.
##
## E o unico lugar que le o dicionario de resultado que os jogos publicam.
## As demais engines (conquista, missao, maestria, liga, placar) leem o perfil
## ja normalizado, entao nenhuma delas precisa conhecer o formato de payload de
## nenhum jogo.
##
## Payload aceito em `match_completed` -- tudo opcional menos `win`:
##
##   win        bool    obrigatorio
##   draw       bool    empate: nao conta vitoria nem derrota na streak
##   xp         int     XP proprio do jogo (gamao paga por gamao/backgammon,
##                      hanoi por numero de discos); sem isso vale a tabela
##   time       float   duracao da partida em segundos
##   perfect    bool    partida sem erro (hanoi no numero otimo de jogadas)
##   close_call bool    decidida na ultima jogada
##   mode       String  "pass_play" quando foi humano contra humano
##   score      int     pontuacao que vale placar
##   moves      int     jogadas usadas, para recorde de menor numero
##   flags      Array   fatos proprios do jogo ("hanoi_7", "nim_misere"). O
##                      motor so os grava; quem decide se viram conquista e o
##                      catalogo. Assim o jogo nao precisa conhecer nenhum id
##                      de conquista -- o Nim e a Torre de Hanoi emitiam seis
##                      ids que nao existiam no catalogo e iam parar no perfil
##                      como lixo, e no Play Games como id invalido.
##   xp_scale   float   multiplicador do degrau de dificuldade (DifficultyManager)
##   difficulty int     degrau 1..10 em que a partida terminou

## Tabela padrao de XP por fim de partida.
const XP_VITORIA := 50
const XP_EMPATE := 25
const XP_DERROTA := 15

## Primeira vitoria do dia paga bonus: e o que traz o jogador de volta amanha.
const XP_PRIMEIRA_VITORIA_DO_DIA := 100

## Cada dia de streak agrega XP na vitoria, ate o teto.
const XP_POR_DIA_DE_STREAK := 10
const XP_STREAK_TETO := 200

## Partida vencida abaixo disto conta como "speedrun".
const SEGUNDOS_VITORIA_RAPIDA := 120.0


func _ready() -> void:
	if GameEventBus:
		GameEventBus.match_started.connect(_on_match_started)
		GameEventBus.match_completed.connect(_on_match_completed)
		GameEventBus.item_collected.connect(_on_item_collected)


func _on_match_started(_game_id: String, _mode: String) -> void:
	PlayerProfile.roll_daily_bucket()


func _on_match_completed(game_id: String, result: Dictionary) -> void:
	PlayerProfile.roll_daily_bucket()

	var venceu := bool(result.get("win", false))
	var empatou := bool(result.get("draw", false))

	_registrar_contadores(game_id, venceu, empatou)
	var primeira_do_dia := venceu and int(PlayerProfile.get_stat("wins_today", 0)) == 1
	_registrar_flags(game_id, result, venceu)
	_registrar_recordes(game_id, result)

	# A streak do dia sobe antes do XP: o bonus de sequencia usa o valor de hoje.
	PlayerProfile.update_daily_streak()

	_conceder_xp(result, venceu, empatou, primeira_do_dia)
	PlayerProfile.flush()


func _registrar_contadores(game_id: String, venceu: bool, empatou: bool) -> void:
	PlayerProfile.increment_stat("total_matches")
	PlayerProfile.increment_stat("matches_today")
	PlayerProfile.record_match(game_id, venceu)

	if venceu:
		PlayerProfile.increment_stat("total_wins")
		PlayerProfile.increment_stat("wins_today")
		PlayerProfile.set_stat("loss_streak", 0)
		PlayerProfile.increment_stat("win_streak")
		PlayerProfile.record_max("best_win_streak", int(PlayerProfile.get_stat("win_streak", 0)))
	elif empatou:
		PlayerProfile.increment_stat("total_draws")
	else:
		PlayerProfile.increment_stat("total_losses")
		PlayerProfile.set_stat("win_streak", 0)
		PlayerProfile.increment_stat("loss_streak")


func _registrar_flags(game_id: String, result: Dictionary, venceu: bool) -> void:
	var hora := Time.get_datetime_dict_from_system()["hour"] as int

	if venceu:
		if bool(result.get("perfect", false)):
			PlayerProfile.set_flag("perfect")
		if bool(result.get("close_call", false)):
			PlayerProfile.set_flag("close_call")
		var duracao := float(result.get("time", 0.0))
		if duracao > 0.0 and duracao < SEGUNDOS_VITORIA_RAPIDA:
			PlayerProfile.set_flag("fast_win")
		if hora >= 0 and hora < 5:
			PlayerProfile.set_flag("night_owl")
		elif hora >= 5 and hora < 6:
			PlayerProfile.set_flag("early_bird")

	for fato in result.get("flags", []):
		PlayerProfile.set_flag(str(fato))

	if str(result.get("mode", "")) == "pass_play":
		PlayerProfile.set_flag("pass_play")
	if game_id == "poker" and str(result.get("hand", "")).to_lower().contains("royal"):
		PlayerProfile.set_flag("royal_flush")


func _registrar_recordes(game_id: String, result: Dictionary) -> void:
	var g := PlayerProfile.game_stats(game_id)

	if bool(result.get("win", false)) and result.has("time"):
		var segundos := int(round(float(result["time"])))
		if segundos > 0 and (int(g.get("best_time", 0)) == 0 or segundos < int(g.get("best_time", 0))):
			g["best_time"] = segundos

	if result.has("score"):
		var pontos := int(result["score"])
		if pontos > int(g.get("best_score", 0)):
			g["best_score"] = pontos
		# Placar so recebe pontuacao de partida encerrada, nunca parcial.
		if GameEventBus:
			GameEventBus.emit_score(game_id, pontos)

	if bool(result.get("win", false)) and result.has("moves"):
		var jogadas := int(result["moves"])
		if jogadas > 0 and (int(g.get("best_moves", 0)) == 0 or jogadas < int(g.get("best_moves", 0))):
			g["best_moves"] = jogadas


func _conceder_xp(result: Dictionary, venceu: bool, empatou: bool, primeira_do_dia: bool) -> void:
	# O jogo pode trazer o proprio XP no resultado; sem isso vale a tabela.
	var base := XP_VITORIA if venceu else (XP_EMPATE if empatou else XP_DERROTA)
	var xp := int(result.get("xp", base))

	# O degrau em que a partida foi jogada mexe no XP antes de qualquer bonus:
	# vencer no 10 vale o dobro de vencer no 1. Sem isto o caminho mais rapido
	# para subir de nivel era perder de proposito ate a escada chegar ao fundo.
	xp = int(round(xp * float(result.get("xp_scale", 1.0))))

	if venceu:
		if bool(result.get("perfect", false)):
			xp = int(round(xp * 1.5))
		xp += mini(PlayerProfile.current_streak * XP_POR_DIA_DE_STREAK, XP_STREAK_TETO)
		if primeira_do_dia:
			xp += XP_PRIMEIRA_VITORIA_DO_DIA

	if RewardSystem:
		RewardSystem.grant_xp(xp, "match_win" if venceu else "match_end")


func _on_item_collected(_item_id: String, amount: int) -> void:
	PlayerProfile.increment_stat("total_items_collected", amount)
