extends GutTest

## Escada de dificuldade — exercita o autoload DifficultyManager.
##
## A escada e a mesma para os 19 jogos: venceu sobe um degrau, perdeu desce um,
## empatou fica. Ela decide duas coisas de uma vez -- quanto a IA pensa e quanto
## a partida paga de XP -- entao um degrau que anda errado estraga os dois.

const JOGO := "jogo_de_teste_da_escada"

var _backup: Dictionary = {}


func before_each() -> void:
	_backup = SaveManager.settings.duplicate(true)
	DifficultyManager.set_level(JOGO, DifficultyManager.DEFAULT_LEVEL)


func after_each() -> void:
	SaveManager.settings = _backup
	SaveManager.save_data()


func test_jogo_novo_comeca_no_degrau_padrao() -> void:
	assert_eq(DifficultyManager.get_level("jogo_que_nunca_foi_jogado"),
		DifficultyManager.DEFAULT_LEVEL, "entra no degrau de entrada")


func test_vitoria_sobe_derrota_desce_empate_fica() -> void:
	var inicio := DifficultyManager.get_level(JOGO)

	assert_eq(DifficultyManager.register_result(JOGO, true), 1, "vencer sobe um")
	assert_eq(DifficultyManager.get_level(JOGO), inicio + 1)

	assert_eq(DifficultyManager.register_result(JOGO, false), -1, "perder desce um")
	assert_eq(DifficultyManager.get_level(JOGO), inicio)

	assert_eq(DifficultyManager.register_result(JOGO, false, true), 0, "empate nao anda")
	assert_eq(DifficultyManager.get_level(JOGO), inicio)


## Perder uma vez tem de tirar o degrau na mesma partida. O Jogo da Velha
## exigia duas derrotas seguidas para descer, e quem estava travado num degrau
## dificil demais ficava la.
func test_uma_derrota_ja_derruba_o_degrau() -> void:
	DifficultyManager.set_level(JOGO, 7)
	DifficultyManager.register_result(JOGO, false)
	assert_eq(DifficultyManager.get_level(JOGO), 6, "desceu na primeira derrota")


func test_a_escada_para_nas_duas_pontas() -> void:
	DifficultyManager.set_level(JOGO, DifficultyManager.MAX_LEVEL)
	assert_eq(DifficultyManager.register_result(JOGO, true), 0, "no topo nao ha para onde subir")
	assert_eq(DifficultyManager.get_level(JOGO), DifficultyManager.MAX_LEVEL)

	DifficultyManager.set_level(JOGO, DifficultyManager.MIN_LEVEL)
	assert_eq(DifficultyManager.register_result(JOGO, false), 0, "no fundo nao ha para onde descer")
	assert_eq(DifficultyManager.get_level(JOGO), DifficultyManager.MIN_LEVEL)


func test_cada_jogo_tem_a_propria_escada() -> void:
	DifficultyManager.set_level("damas", 9)
	DifficultyManager.set_level("jogo_da_velha", 2)
	assert_eq(DifficultyManager.get_level("damas"), 9)
	assert_eq(DifficultyManager.get_level("jogo_da_velha"), 2)


func test_o_degrau_sobrevive_a_um_boot() -> void:
	DifficultyManager.set_level(JOGO, 8)
	var gravado: Dictionary = SaveManager.get_setting(DifficultyManager.SAVE_KEY, {})
	assert_eq(int(gravado.get(JOGO, -1)), 8, "o degrau foi para o disco")


## Sem isto o jogador maximiza XP ficando de proposito no degrau 1.
func test_o_xp_cresce_com_o_degrau() -> void:
	var baixo := DifficultyManager.xp_scale(DifficultyManager.MIN_LEVEL)
	var alto := DifficultyManager.xp_scale(DifficultyManager.MAX_LEVEL)
	assert_almost_eq(baixo, DifficultyManager.XP_SCALE_MIN, 0.001, "ponta de baixo")
	assert_almost_eq(alto, DifficultyManager.XP_SCALE_MAX, 0.001, "ponta de cima")
	var anterior := 0.0
	for nivel in range(DifficultyManager.MIN_LEVEL, DifficultyManager.MAX_LEVEL + 1):
		var escala: float = DifficultyManager.xp_scale(nivel)
		assert_gt(escala, anterior, "degrau %d paga mais que o anterior" % nivel)
		anterior = escala


func test_a_faixa_tem_nome_traduzido_em_todos_os_degraus() -> void:
	for nivel in range(DifficultyManager.MIN_LEVEL, DifficultyManager.MAX_LEVEL + 1):
		var chave := DifficultyManager.tier_name(nivel)
		assert_true(chave.begins_with("DIFF_TIER_"), "degrau %d tem faixa" % nivel)
		assert_ne(tr(chave), chave, "a chave %s existe no CSV" % chave)


func test_o_aviso_so_aparece_quando_o_degrau_anda() -> void:
	assert_eq(DifficultyManager.change_notice(5, 0), "", "parado nao avisa")
	assert_ne(DifficultyManager.change_notice(5, 1), "", "subiu avisa")
	assert_ne(DifficultyManager.change_notice(5, -1), "", "desceu avisa")


# --------------------------------------------------------- ligacao com o jogo

## A escada so serve para alguma coisa se o fim de partida a mover sozinho. O
## contrato e do BaseGame: nenhum dos 19 jogos precisa conhecer o
## DifficultyManager para andar nela.
func test_o_fim_de_partida_move_a_escada_sem_o_jogo_pedir() -> void:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	var antes := DifficultyManager.get_level(jogo.game_id)

	var recebido: Array = []
	var ouvinte := func(_id: String, r: Dictionary): recebido.append(r)
	GameEventBus.match_completed.connect(ouvinte)
	jogo.finish_game("venceu", true)
	GameEventBus.match_completed.disconnect(ouvinte)

	assert_eq(recebido.size(), 1, "a partida foi publicada uma vez")
	assert_eq(DifficultyManager.get_level(jogo.game_id), mini(antes + 1, DifficultyManager.MAX_LEVEL),
		"vencer subiu o degrau")


## O XP tem de ser pago pelo degrau em que a partida foi JOGADA, nao pelo que
## ela deixou. Vencendo no 5 o jogador vai para o 6, e pagar como 6 seria pagar
## por uma dificuldade que ele ainda nao enfrentou.
func test_o_xp_paga_o_degrau_em_que_a_partida_foi_jogada() -> void:
	var jogo := BaseGame.new()
	add_child_autofree(jogo)
	DifficultyManager.set_level(jogo.game_id, 5)

	var recebido: Array = []
	var ouvinte := func(_id: String, r: Dictionary): recebido.append(r)
	GameEventBus.match_completed.connect(ouvinte)
	jogo.finish_game("venceu", true)
	GameEventBus.match_completed.disconnect(ouvinte)

	var payload: Dictionary = recebido[0]
	assert_eq(int(payload.get("difficulty", -1)), 6, "o degrau publicado ja e o novo")
	assert_eq(int(payload.get("difficulty_delta", 0)), 1, "subiu um")
	assert_almost_eq(float(payload.get("xp_scale", 0.0)), DifficultyManager.xp_scale(5), 0.001,
		"mas o XP e o do degrau 5, onde a partida aconteceu")


## O multiplicador so vale se a gamificacao o aplicar de fato.
func test_a_gamificacao_multiplica_o_xp_pelo_degrau() -> void:
	var ganhos: Array[int] = []
	var ouvinte := func(qtd: int, _fonte: String): ganhos.append(qtd)
	GameEventBus.xp_gained.connect(ouvinte)

	GameEventBus.emit_match_completed("jogo_de_teste_xp", {"win": false, "xp": 100, "xp_scale": 1.0})
	GameEventBus.emit_match_completed("jogo_de_teste_xp", {"win": false, "xp": 100, "xp_scale": 2.0})
	GameEventBus.xp_gained.disconnect(ouvinte)

	assert_eq(ganhos.size(), 2, "dois pagamentos")
	assert_eq(ganhos[1], ganhos[0] * 2, "o dobro do degrau paga o dobro de XP")
