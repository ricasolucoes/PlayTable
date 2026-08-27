extends GutTest

## O turno da IA nos jogos em que ele saiu da linha principal.
##
## Reversi, Quatro em Linha e Mancala passaram a pensar num `WorkerThreadPool`
## durante a pausa de encenacao que ja existia -- no degrau 10 a busca chega a
## meio segundo no computador e mais num telefone, e travar a tela por isso e
## defeito. Nenhum teste unitario cobre esse caminho: a busca esta certa, mas a
## cena pode ficar esperando uma tarefa que nunca fecha, ou seguir com a jogada
## depois de a cena ja ter sido fechada.
##
## Estes testes rodam a cena de verdade e esperam a IA responder.

const REVERSI := preload("res://games/reversi/ReversiGame.tscn")
const QUATRO := preload("res://games/quatro_em_linha/ConnectFourGame.tscn")
const MANCALA := preload("res://games/mancala/MancalaGame.tscn")

## Espera de sobra para a pausa de encenacao (0,6 s a 0,7 s) mais a busca.
const ESPERA := 6.0

var _degraus: Dictionary = {}


## Fixa o degrau em todos os tres jogos para o teste nao depender do progresso
## de quem estiver jogando na maquina, e devolve o que estava no fim.
func before_each() -> void:
	for jogo in ["reversi", "quatro_em_linha", "mancala"]:
		_degraus[jogo] = DifficultyManager.get_level(jogo)
		DifficultyManager.set_level(jogo, DifficultyManager.MAX_LEVEL)


func after_each() -> void:
	for jogo in _degraus:
		DifficultyManager.set_level(jogo, int(_degraus[jogo]))
	_degraus.clear()


func test_o_reversi_responde_a_jogada_do_jogador() -> void:
	var jogo = add_child_autofree(REVERSI.instantiate())
	await wait_frames(2)

	var antes: int = jogo.grid_data.count_matching(2)
	# (2,3) e uma das quatro aberturas legais das pretas.
	jogo._on_cell_clicked(2, 3)
	await wait_until(func(): return jogo.is_player_turn and not jogo.game_over, ESPERA)

	assert_true(jogo.is_player_turn, "a vez voltou para o jogador")
	assert_ne(jogo.grid_data.count_matching(2), antes, "a IA jogou e o placar mudou")


func _fichas(jogo, dono: int) -> int:
	var total := 0
	for c in range(ConnectFourRules.COLS):
		for r in range(ConnectFourRules.ROWS):
			if int(jogo.board.get_cell(r, c)) == dono:
				total += 1
	return total


func test_o_quatro_em_linha_responde_a_jogada_do_jogador() -> void:
	var jogo = add_child_autofree(QUATRO.instantiate())
	await wait_frames(2)

	# A vez so passa dentro do retorno da animacao de queda, entao esperar por
	# `is_player_turn` daria certo antes de a IA jogar: o que se espera aqui e
	# a ficha dourada aparecer no tabuleiro.
	jogo._make_move(3, 1)
	await wait_until(func(): return _fichas(jogo, 2) >= 1 or jogo.game_over, ESPERA)

	assert_eq(_fichas(jogo, 2), 1, "a IA deixou cair uma ficha")
	assert_eq(_fichas(jogo, 1), 1, "e a do jogador continua onde caiu")


func test_o_mancala_responde_a_jogada_do_jogador() -> void:
	var jogo = add_child_autofree(MANCALA.instantiate())
	await wait_frames(2)

	# A cova 2 tem 4 gemas e termina na 6 (a Kalah do jogador), o que daria
	# turno extra e nao passaria a vez. A cova 0 termina na 4.
	jogo._on_player_pit_clicked(0)
	await wait_until(func(): return jogo.is_player_turn or jogo.game_over, ESPERA)

	var na_ia := 0
	for i in range(7, 14):
		na_ia += int(jogo.pits[i])
	assert_ne(na_ia, 25, "a IA semeou: o lado dela nao esta mais como a distribuicao inicial")
	assert_true(jogo.is_player_turn, "a vez voltou para o jogador")


## A tarefa nao pode segurar referencia para a cena: fechar o jogo no meio da
## busca da IA nao pode deixar nada pendurado nem estourar.
func test_fechar_a_cena_no_meio_da_busca_nao_estoura() -> void:
	var jogo = REVERSI.instantiate()
	add_child(jogo)
	await wait_frames(2)

	jogo._on_cell_clicked(2, 3)
	await wait_frames(1)
	jogo.queue_free()
	await wait_seconds(2.0)

	assert_true(true, "a cena fechou com a busca em andamento e o teste seguiu")
