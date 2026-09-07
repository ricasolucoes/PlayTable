extends GutTest

## Rolar listas com o dedo.
##
## O ScrollContainer da engine rola na roda do mouse e na barra lateral, mas
## nao no arrasto de toque -- medido no 4.7.2 com evento sintetico fiel, o
## `scroll_vertical` fica em zero e `scroll_started` nunca sai. Num telefone o
## arrasto e o UNICO gesto que existe: sem ele a colecao do perfil, a lista de
## jogos e a mao cheia do UNO ficam presas na primeira tela. Quem rola e o
## `DragScroll`, e sao estes testes que dizem se ele ainda rola.

const PERFIL := "res://core/telas/PerfilScreen.tscn"
const MENU_TABULEIRO := "res://core/telas/MenuTabuleiro.tscn"
const MENU_CARTAS := "res://core/telas/MenuCartas.tscn"
const MENU_PRINCIPAL := "res://core/telas/MainMenu.tscn"
const LOBBY := "res://core/telas/LobbyScreen.tscn"
const UNO := "res://games/unolike/UnoLikeGame.tscn"


## Uma tela de telefone so para o teste: 720x1280, com o toque entrando por
## ela. Um SubViewport proprio e nao o viewport do runner porque o painel do
## GUT ocupa parte da janela e roubaria o toque de quem esta sendo medido.
var _tela: SubViewport = null


func before_each() -> void:
	_tela = SubViewport.new()
	_tela.size = Vector2i(720, 1280)
	_tela.handle_input_locally = true
	_tela.gui_embed_subwindows = false
	add_child_autofree(_tela)


func _dentro(no: Node) -> Node:
	_tela.add_child(no)
	return no


func _montar(caminho: String) -> Node:
	var tela: Node = _dentro((load(caminho) as PackedScene).instantiate())
	await wait_process_frames(3)
	return tela


func _rolagens(no: Node, saida: Array) -> Array:
	if no is ScrollContainer:
		saida.append(no)
	for filho in no.get_children():
		_rolagens(filho, saida)
	return saida


## Um arrasto de dedo de verdade, do jeito que ele chega no Android: com
## `emulate_mouse_from_touch` ligado -- o padrao do projeto -- o mesmo dedo
## entra DUAS vezes, primeiro como toque cru e logo atras como mouse emulado.
## E por isso que o `DragScroll` precisa ignorar o mouse depois de ver o
## primeiro toque: sem essa trava a lista rolaria o dobro.
func _toque(ponto: Vector2, apertado: bool) -> void:
	var toque := InputEventScreenTouch.new()
	toque.index = 0
	toque.pressed = apertado
	toque.position = ponto
	_tela.push_input(toque)
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = apertado
	mouse.position = ponto
	mouse.global_position = ponto
	_tela.push_input(mouse)


func _arrastar(ponto: Vector2, passo: Vector2, passos: int = 12) -> void:
	_toque(ponto, true)
	await wait_process_frames(1)
	var atual := ponto
	for i in range(passos):
		atual += passo
		var anda := InputEventScreenDrag.new()
		anda.index = 0
		anda.position = atual
		anda.relative = passo
		anda.velocity = passo * 30.0
		_tela.push_input(anda)
		var move := InputEventMouseMotion.new()
		move.position = atual
		move.global_position = atual
		move.relative = passo
		move.velocity = passo * 30.0
		move.button_mask = MOUSE_BUTTON_MASK_LEFT
		_tela.push_input(move)
		await wait_process_frames(1)
	_toque(atual, false)
	await wait_process_frames(1)


# ------------------------------------------------------------ o proprio motor

func test_o_arrasto_rola_a_lista_e_nao_aperta_o_botao() -> void:
	var rolagem := UIKit.rolagem()
	rolagem.size = Vector2(600, 500)
	rolagem.position = Vector2(20, 20)
	_dentro(rolagem)
	var coluna := UIKit.vbox(0)
	# Sem expandir, a coluna fica com a largura minima do texto e o dedo do
	# teste cai no ScrollContainer em vez de cair num botao -- e ai o teste
	# passaria sem nunca ter encostado num botao.
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(coluna)
	var apertos := [0]
	for i in range(30):
		var b := UIKit.botao("linha %d" % i)
		b.pressed.connect(func() -> void: apertos[0] += 1)
		coluna.add_child(b)
	await wait_process_frames(3)

	await _arrastar(Vector2(320, 270), Vector2(0, -20))
	assert_gt(rolagem.scroll_vertical, 100, "o dedo levou a lista para cima")
	assert_eq(apertos[0], 0, "e nenhum botao foi apertado no caminho")


func test_um_toque_curto_continua_apertando_o_botao() -> void:
	var rolagem := UIKit.rolagem()
	rolagem.size = Vector2(600, 500)
	rolagem.position = Vector2(20, 20)
	_dentro(rolagem)
	var coluna := UIKit.vbox(0)
	# Sem expandir, a coluna fica com a largura minima do texto e o dedo do
	# teste cai no ScrollContainer em vez de cair num botao -- e ai o teste
	# passaria sem nunca ter encostado num botao.
	coluna.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(coluna)
	var apertos := [0]
	for i in range(30):
		var b := UIKit.botao("linha %d" % i)
		b.pressed.connect(func() -> void: apertos[0] += 1)
		coluna.add_child(b)
	await wait_process_frames(3)

	await _arrastar(Vector2(320, 270), Vector2(0, -1), 2)
	assert_eq(rolagem.scroll_vertical, 0, "dois pixels de tremor nao rolam nada")
	assert_eq(apertos[0], 1, "e o botao sob o dedo foi apertado")


func test_o_eixo_travado_nao_engole_o_gesto() -> void:
	# A tira de abas do perfil so rola na horizontal. Se ela reagisse ao
	# arrasto vertical, a lista atras dela ficaria presa.
	var rolagem := UIKit.rolagem(false, true)
	rolagem.size = Vector2(400, 100)
	_dentro(rolagem)
	var linha := UIKit.hbox(0)
	rolagem.add_child(linha)
	for i in range(10):
		linha.add_child(UIKit.botao("aba %d" % i))
	await wait_process_frames(3)
	await _arrastar(Vector2(200, 50), Vector2(0, -20))
	assert_eq(rolagem.scroll_vertical, 0, "o eixo travado ficou parado")


# ------------------------------------------------------- as telas de verdade

func test_toda_rolagem_das_telas_tem_o_arrasto_ligado() -> void:
	for caminho in [PERFIL, MENU_TABULEIRO, MENU_CARTAS, MENU_PRINCIPAL, LOBBY, UNO]:
		var tela := await _montar(caminho)
		var achadas: Array = _rolagens(tela, [])
		assert_gt(achadas.size(), 0, "%s tem pelo menos uma rolagem" % caminho)
		for sc in achadas:
			assert_not_null((sc as ScrollContainer).get_node_or_null("DragScroll"),
				"%s: %s rola no dedo" % [caminho, sc.name])


func test_a_colecao_do_perfil_rola_no_dedo() -> void:
	var tela := await _montar(PERFIL)
	tela._trocar_aba("collection")
	await wait_process_frames(3)
	var achadas: Array = _rolagens(tela, [])
	var conteudo: ScrollContainer = null
	for sc in achadas:
		if (sc as ScrollContainer).vertical_scroll_mode != ScrollContainer.SCROLL_MODE_DISABLED:
			conteudo = sc
			break
	assert_not_null(conteudo, "a aba de colecao tem uma lista que rola")
	if conteudo == null:
		return
	var barra := conteudo.get_v_scroll_bar()
	assert_gt(barra.max_value, barra.page, "a lista passa da tela")
	await _arrastar(conteudo.global_position + conteudo.size * 0.5, Vector2(0, -20))
	assert_gt(conteudo.scroll_vertical, 100, "e o dedo a leva para baixo")


func test_a_mao_cheia_do_uno_rola_de_lado() -> void:
	var jogo := await _montar(UNO)
	for i in range(8):
		jogo.player_hand.add(jogo.draw_pile.draw())
	jogo._update_ui()
	await wait_process_frames(3)
	var rolagem: ScrollContainer = jogo.get_node("UI/PlayerArea/ScrollContainer")
	var barra := rolagem.get_h_scroll_bar()
	assert_gt(barra.max_value, barra.page, "a mao nao cabe na largura da tela")
	var antes: int = jogo.player_hand.size()
	await _arrastar(rolagem.global_position + rolagem.size * 0.5, Vector2(-22, 0))
	assert_gt(rolagem.scroll_horizontal, 100, "o dedo corre a mao para o lado")
	assert_eq(jogo.player_hand.size(), antes, "e nao joga a carta por onde passou")


func test_o_painel_de_regras_rola_no_dedo() -> void:
	# A regra do gamao nao cabe numa tela de telefone, e cortar a regra pela
	# metade e pior do que nao te-la.
	var jogo := await _montar("res://games/gamao/BackgammonGame.tscn")
	jogo.show_rules()
	await wait_process_frames(3)
	var rolagem: ScrollContainer = null
	for sc in _rolagens(jogo.rules_panel, []):
		rolagem = sc
		break
	assert_not_null(rolagem, "o painel de regras tem uma lista que rola")
	if rolagem == null:
		return
	var barra := rolagem.get_v_scroll_bar()
	assert_gt(barra.max_value, barra.page, "a regra do gamao passa da tela")
	# O quanto ela desce depende de quanto texto sobra; o que importa e que o
	# arrasto de 240 px leva a lista ao fim, e nao que ela fique parada.
	var fim: int = int(barra.max_value - barra.page)
	await _arrastar(rolagem.global_position + rolagem.size * 0.5, Vector2(0, -20))
	assert_gt(rolagem.scroll_vertical, mini(100, fim) - 1, "e o dedo desce por ela")
