extends GutTest

## Aparencia no telefone — a regua que mede M1, M3, M4 e M6 do plano.
##
## Os 349 testes anteriores exercitam regras, ciclo de vida e instanciacao.
## Nenhum le tamanho, posicao ou pixel, e foi por isso que a camera fixa em 15
## dos 16 jogos, os alvos de toque pela metade do minimo e a tipografia sem
## escala passaram despercebidos por toda a v0.4.0.
##
## Cada cena e instanciada sob um SubViewport de tamanho controlado, para que
## o layout e o enquadramento da camera aconteçam na proporcao que o teste
## pede, e nao na da janela do runner.
##
## Livro-razao de defeitos abertos. Enquanto o ID esta em ABERTOS, o teste
## correspondente mede, imprime a medicao e marca pending com os numeros — a
## suite segue verde e a CI continua enxergando qualquer outra regressao. Cada
## correcao remove o seu ID daqui; a partir dai o teste e uma assercao dura e
## reprova se o defeito voltar.
##
## M6 nao estava no plano: a propria regua o achou na primeira rodada. Em 3:4 o
## Jogo da Memoria nao cabe na altura — a VBoxContainer e ancorada de ponta a
## ponta com grow_vertical = 2, e quando o conteudo (grade de cartas de 75x120
## mais o cabecalho) passa dos 960 px ela cresce para os dois lados e empurra
## BtnBack, Title e BtnRestart para y = -20, acima da borda da tela.
const ABERTOS: Array[String] = ["M1", "M3", "M4", "M6"]


# ------------------------------------------------------------------ a regua

## Aparelho de referencia: 1080x2400, ~393 dp de largura. O viewport do projeto
## mapeia sua largura no lado curto da tela (stretch canvas_items + expand),
## entao 1 px de viewport vale REFERENCE_DP_WIDTH / viewport_width dp. Em outras
## densidades o numero muda, mas nenhum alvo medido chega perto de 48 dp em
## nenhuma densidade comum.
const REFERENCE_DP_WIDTH := 393.0

## Minimos de acessibilidade em telefone: alvo de toque de 48 dp (Material e
## WCAG 2.5.8 AAA) e corpo de texto de 14 sp.
const MIN_TOUCH_DP := 48.0
const MIN_TEXT_SP := 14.0

## Proporcoes de tela: telefone comum, telefone alto e tablet em retrato. A
## largura fica em 720 porque e o lado curto que o stretch amarra.
const PROPORCOES := {
	"9:16": Vector2i(720, 1280),
	"20:9": Vector2i(720, 1600),
	"3:4":  Vector2i(720, 960),
}

const JOGOS := [
	"res://games/jogo_da_velha/TicTacToeGame.tscn",
	"res://games/damas/CheckersGame.tscn",
	"res://games/batalha_naval/BattleshipGame.tscn",
	"res://games/quatro_em_linha/ConnectFourGame.tscn",
	"res://games/solitario/PegSolitaireGame.tscn",
	"res://games/campo_minado/MinesweeperGame.tscn",
	"res://games/domino/DominoGame.tscn",
	"res://games/ludo/LudoGame.tscn",
	"res://games/reversi/ReversiGame.tscn",
	"res://games/mancala/MancalaGame.tscn",
	"res://games/senet/SenetGame.tscn",
	"res://games/paciencia/KlondikeGame.tscn",
	"res://games/memoria/MemoryGame.tscn",
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/unolike/UnoLikeGame.tscn",
	"res://games/poker/PokerGame.tscn",
]

const MENUS := [
	"res://core/telas/MainMenu.tscn",
	"res://core/telas/MenuTabuleiro.tscn",
	"res://core/telas/MenuCartas.tscn",
]

## Os cinco jogos que montam o tabuleiro com Board3D.setup_board(): sao os que a
## camera consegue medir hoje, porque Board3D.content_size() diz quanto o
## tabuleiro ocupa. Os outros onze — inclusive o Resta Um, que constroi a
## propria malha — definem o conteudo por codigo e so entram no teste de
## enquadramento quando M1 lhes der um tamanho para informar.
const JOGOS_COM_TABULEIRO_3D := [
	"res://games/damas/CheckersGame.tscn",
	"res://games/batalha_naval/BattleshipGame.tscn",
	"res://games/campo_minado/MinesweeperGame.tscn",
	"res://games/reversi/ReversiGame.tscn",
	"res://games/senet/SenetGame.tscn",
]

var _dp_por_px: float


func before_all() -> void:
	var largura: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	_dp_por_px = REFERENCE_DP_WIDTH / float(largura) if largura > 0 else 0.0


# --------------------------------------------------------------- utilitarios

func _aberto(id: String) -> bool:
	return id in ABERTOS


## Assercao dura quando o defeito esta fechado; pending com a medicao quando
## ainda esta no livro-razao. So uma das duas acontece, nunca as duas.
func _regua(id: String, violacoes: Array[String], resumo: String) -> void:
	if violacoes.is_empty():
		pass_test("%s: %s" % [id, resumo])
		return
	var texto := "%s: %d violacao(oes). %s" % [id, violacoes.size(), resumo]
	for v in violacoes.slice(0, 6):
		texto += "\n      " + v
	if violacoes.size() > 6:
		texto += "\n      ... e mais %d" % (violacoes.size() - 6)
	if _aberto(id):
		pending(texto)
	else:
		fail_test(texto)


func _nome_curto(caminho: String) -> String:
	return caminho.get_file().get_basename()


## Instancia a cena dentro de um SubViewport do tamanho pedido e espera o
## layout e o enquadramento acontecerem. Devolve a raiz da cena.
func _montar(caminho: String, tamanho: Vector2i) -> Node:
	var vp := SubViewport.new()
	vp.size = tamanho
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(vp)
	var cena := load(caminho) as PackedScene
	assert_not_null(cena, "%s carrega" % caminho)
	if cena == null:
		return null
	var no := cena.instantiate()
	vp.add_child(no)
	await wait_process_frames(3)
	return no


func _controles(raiz: Node, tipo: String) -> Array[Control]:
	var achados: Array[Control] = []
	var fila: Array[Node] = [raiz]
	while not fila.is_empty():
		var n: Node = fila.pop_back()
		if n is Control and n.is_class(tipo) and (n as Control).is_visible_in_tree():
			achados.append(n)
		fila.append_array(n.get_children())
	return achados


func _px_para_dp(px: float) -> float:
	return px * _dp_por_px


func _fmt_dp(px: float) -> String:
	return "%.0f px (%.0f dp)" % [px, _px_para_dp(px)]


# ------------------------------------------------------------ M1: camera

## Os quatro cantos do tabuleiro no plano da mesa, em coordenadas de mundo.
func _cantos_do_tabuleiro(board: Board3D) -> Array[Vector3]:
	var meio := board.content_size() * 0.5
	var c := board.global_position
	return [
		c + Vector3(-meio.x, 0.0, -meio.y), c + Vector3(meio.x, 0.0, -meio.y),
		c + Vector3(-meio.x, 0.0, meio.y),  c + Vector3(meio.x, 0.0, meio.y),
	]


## A faixa da tela que a camera considera util: entre a HUD de cima e a de
## baixo. Sao os mesmos numeros que o CameraRig3D usa para enquadrar.
func _faixa_util(camera: CameraRig3D, tamanho: Vector2i) -> Rect2:
	return Rect2(0.0, camera.safe_top_px,
		float(tamanho.x), float(tamanho.y) - camera.safe_top_px - camera.safe_bottom_px)


func test_o_tabuleiro_cabe_no_quadro_em_tres_proporcoes() -> void:
	var violacoes: Array[String] = []
	for caminho in JOGOS_COM_TABULEIRO_3D:
		for rotulo in PROPORCOES:
			var tamanho: Vector2i = PROPORCOES[rotulo]
			var jogo := await _montar(caminho, tamanho)
			if jogo == null:
				continue
			var board: Board3D = jogo.get_node_or_null("Board3D")
			var env: TabletopEnvironment3D = jogo.get_node_or_null("TabletopEnvironment3D")
			if board == null or env == null or env.camera == null:
				violacoes.append("%s: sem Board3D ou camera" % _nome_curto(caminho))
				continue
			var faixa := _faixa_util(env.camera, tamanho)
			var fora: Array[String] = []
			for canto in _cantos_do_tabuleiro(board):
				if env.camera.is_position_behind(canto):
					fora.append("atras da camera")
					continue
				var p := env.camera.unproject_position(canto)
				if not faixa.has_point(p):
					fora.append("(%.0f, %.0f)" % [p.x, p.y])
			if not fora.is_empty():
				violacoes.append("%s em %s: %d canto(s) fora da faixa util %s — %s" % [
					_nome_curto(caminho), rotulo, fora.size(), faixa, ", ".join(fora)])
	_regua("M1", violacoes,
		"tabuleiro dentro da faixa util em %d jogos x %d proporcoes" % [
			JOGOS_COM_TABULEIRO_3D.size(), PROPORCOES.size()])


func test_a_camera_conhece_o_tamanho_real_do_tabuleiro() -> void:
	var violacoes: Array[String] = []
	for caminho in JOGOS_COM_TABULEIRO_3D:
		var jogo := await _montar(caminho, PROPORCOES["9:16"])
		if jogo == null:
			continue
		var board: Board3D = jogo.get_node_or_null("Board3D")
		var env: TabletopEnvironment3D = jogo.get_node_or_null("TabletopEnvironment3D")
		if board == null or env == null or env.camera == null:
			continue
		var real := board.content_size()
		var informado := env.camera.content_size
		if not informado.is_equal_approx(real):
			violacoes.append("%s: camera enquadra %s, tabuleiro mede %s" % [
				_nome_curto(caminho), informado, real])
	_regua("M1", violacoes, "camera informada do tamanho do tabuleiro nos %d jogos" % JOGOS_COM_TABULEIRO_3D.size())


# --------------------------------------------------------- M3: alvos de toque

func test_todo_alvo_de_toque_tem_ao_menos_48dp() -> void:
	var minimo_px := MIN_TOUCH_DP / _dp_por_px
	var violacoes: Array[String] = []
	var total := 0
	var pior := INF
	for caminho in JOGOS + MENUS:
		var raiz := await _montar(caminho, PROPORCOES["9:16"])
		if raiz == null:
			continue
		var botoes := _controles(raiz, "BaseButton")
		# Grades de toque repetem o mesmo botao dezenas de vezes: conta uma vez
		# por pai, com a menor medida entre os irmaos.
		var por_pai := {}
		for b in botoes:
			var chave := b.get_parent().get_path()
			var lado := minf(b.size.x, b.size.y)
			if lado <= 0.0:
				lado = minf(b.custom_minimum_size.x, b.custom_minimum_size.y)
			if not por_pai.has(chave) or lado < por_pai[chave]["lado"]:
				por_pai[chave] = {"lado": lado, "nome": b.name, "quantos": 0}
			por_pai[chave]["quantos"] += 1
		for chave in por_pai:
			total += 1
			var lado: float = por_pai[chave]["lado"]
			pior = minf(pior, lado)
			if lado < minimo_px:
				var quantos: int = por_pai[chave]["quantos"]
				violacoes.append("%s › %s%s: %s" % [
					_nome_curto(caminho), por_pai[chave]["nome"],
					(" (x%d)" % quantos) if quantos > 1 else "", _fmt_dp(lado)])
	_regua("M3", violacoes, "%d grupo(s) de botoes medidos, minimo %s, pior %s" % [
		total, _fmt_dp(minimo_px), _fmt_dp(pior) if pior < INF else "—"])


# ---------------------------------------------------------- M4: tipografia

func test_todo_texto_tem_ao_menos_14sp() -> void:
	var minimo_px := MIN_TEXT_SP / _dp_por_px
	var violacoes: Array[String] = []
	var total := 0
	var pior := INF
	for caminho in JOGOS + MENUS:
		var raiz := await _montar(caminho, PROPORCOES["9:16"])
		if raiz == null:
			continue
		var por_tamanho := {}
		for c in _controles(raiz, "Label") + _controles(raiz, "Button"):
			var px := float(c.get_theme_font_size("font_size"))
			total += 1
			pior = minf(pior, px)
			if px < minimo_px:
				if not por_tamanho.has(px):
					por_tamanho[px] = []
				por_tamanho[px].append(c.name)
		for px in por_tamanho:
			var nomes: Array = por_tamanho[px]
			violacoes.append("%s: %d texto(s) em %s — %s" % [
				_nome_curto(caminho), nomes.size(), _fmt_dp(px),
				", ".join(nomes.slice(0, 4)) + (", ..." if nomes.size() > 4 else "")])
	_regua("M4", violacoes, "%d texto(s) medidos, minimo %s, pior %s" % [
		total, _fmt_dp(minimo_px), _fmt_dp(pior) if pior < INF else "—"])


func test_os_tamanhos_de_fonte_vivem_no_tema() -> void:
	var violacoes: Array[String] = []
	for caminho in JOGOS + MENUS:
		var raiz := await _montar(caminho, PROPORCOES["9:16"])
		if raiz == null:
			continue
		var fixados := 0
		for c in _controles(raiz, "Control"):
			if c.has_theme_font_size_override("font_size"):
				fixados += 1
		if fixados > 0:
			violacoes.append("%s: %d no(s) fixam font_size fora do tema" % [_nome_curto(caminho), fixados])
	_regua("M4", violacoes, "nenhuma cena fixa tamanho de fonte fora do tema")


# ------------------------------------------------- guardas da propria regua

func test_a_regua_deriva_do_viewport_do_projeto() -> void:
	# Se alguem mudar o viewport, a conversao para dp muda junto e este teste
	# denuncia antes que os outros passem a medir errado sem avisar.
	var largura: int = ProjectSettings.get_setting("display/window/size/viewport_width", 0)
	assert_eq(largura, 720, "viewport de 720 px de largura, como na v0.4.0")
	assert_almost_eq(_dp_por_px, 0.546, 0.005, "1 px de viewport ≈ 0,55 dp no aparelho de referencia")
	assert_eq(ProjectSettings.get_setting("display/window/stretch/mode", ""), "canvas_items",
		"stretch canvas_items: a largura do viewport casa com o lado curto da tela")


## Um controle dentro de um ScrollContainer pode estar fora da tela de
## proposito: e para isso que a rolagem existe. O que precisa caber e o proprio
## ScrollContainer. Sem esta regra, os tres ultimos jogos do MenuTabuleiro em
## 3:4 apareciam como violacao — e sao alcancaveis com um gesto.
func _alvo_de_medida(c: Control) -> Control:
	var n: Node = c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return n
		n = n.get_parent()
	return c


func test_nada_da_interface_sai_da_tela() -> void:
	var violacoes: Array[String] = []
	for caminho in JOGOS + MENUS:
		for rotulo in PROPORCOES:
			var tamanho: Vector2i = PROPORCOES[rotulo]
			var raiz := await _montar(caminho, tamanho)
			if raiz == null:
				continue
			var tela := Rect2(Vector2.ZERO, Vector2(tamanho))
			var vistos := {}
			for c in _controles(raiz, "Label") + _controles(raiz, "BaseButton"):
				var alvo := _alvo_de_medida(c)
				var chave := alvo.get_path()
				if vistos.has(chave):
					continue
				vistos[chave] = true
				var r := alvo.get_global_rect()
				if r.size.x <= 0.0 or r.size.y <= 0.0:
					continue
				if not tela.encloses(r):
					violacoes.append("%s em %s: %s em %s" % [_nome_curto(caminho), rotulo, alvo.name, r])
	_regua("M6", violacoes,
		"todo rotulo e botao, ou a area de rolagem que o contem, dentro da tela nas %d proporcoes" % PROPORCOES.size())
