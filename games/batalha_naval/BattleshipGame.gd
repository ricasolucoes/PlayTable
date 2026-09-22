extends BaseGame

## BattleshipGame: Batalha Naval 3D com os dois mapas na mesa ao mesmo tempo.
##
## Antes havia UM tabuleiro e duas abas -- "Radar" e "Frota Aliada" -- que
## redesenhavam o mesmo tabuleiro com conteudo diferente. Batalha naval e um
## jogo de comparar dois mapas: escondendo um deles atras de um botao, o jogador
## nunca via o tiro que levou junto do tiro que deu. Agora os dois mapas ficam
## na mesa, o de ataque grande em cima e a frota aliada menor embaixo.

## Tamanho da casa em cada mapa. O de ataque recebe o toque, entao precisa de
## casa grande; o da frota so e consultado -- mas e consultado: e nele que o
## jogador ve o tiro que levou, e com 0,33 a casa saia com ~33 px e o pino da
## IA era um ponto. Os dois mapas empilhados sao mais fundos que largos, entao
## em retrato e a ALTURA que manda no enquadramento: cada decimo que a frota
## ganha e um decimo que o radar perde. 0,56 e 0,40 e o ponto em que o pino da
## frota se le sem o radar cair abaixo de ~50 px.
const RADAR_CELL := 0.56
const FLEET_CELL := 0.40
const GRID := 10

## Folga entre os dois mapas: cabe o rotulo do de baixo.
const BOARD_GAP := 0.5

## Altura do casco sobre a casa.
const HULL_HEIGHT := 0.22

## Ate onde a camera pode inclinar no posicionamento. O tabuleiro sozinho e
## quadrado e a tela e de retrato: sem levantar o teto do tema, sobra um terco
## da altura util em branco.
const TETO_POSICIONANDO := 84.0

## Nome do asset gerado de cada classe (`tools/art/batalha_naval.json`): a
## silhueta vista de cima que se deita sobre o conves do casco procedural.
const ART_NAVIOS := {
	"SHIP_CARRIER": "encouracado",
	"SHIP_BATTLESHIP": "couracado",
	"SHIP_CRUISER": "cruzador",
	"SHIP_SUBMARINE": "submarino",
	"SHIP_DESTROYER": "destroier",
}

var player_grid: Grid2D
var ai_grid: Grid2D
var player_ships: Array = []
var ai_ships: Array = []
var is_player_turn: bool = true

## Em que ponto da partida estamos.
##
## Ate aqui nao havia ponto nenhum: `_start_new_game()` sorteava a frota do
## jogador junto com a da IA e a partida ja comecava com os cinco navios
## postos. Metade de uma batalha naval e esconder a frota onde o adversario nao
## procura -- sem a escolha, o jogador so aperta casas do mapa de cima.
enum Fase { POSICIONANDO, BATALHA }
var fase: int = Fase.POSICIONANDO

## Qual navio de `BattleshipRules.SHIP_DEFS` esta na mao agora, e como ele deita.
var _navio_atual: int = 0
var _vertical: bool = false

## Preview da casa sob o dedo/ponteiro durante o posicionamento.
var _preview: Array = []

## O casco fantasma da previa: o navio que vai cair, translucido, no lugar em
## que vai cair. Antes a previa era so o tom das casas -- verde ou vermelho --,
## e o jogador so via a FORMA do navio depois de solta-lo.
var _fantasma: MeshInstance3D
var _fleet_ghost: Node3D

## O gesto de posicionar, do aperto ao soltar.
##
## Por um navio e um gesto de SOLTAR, e nao de apertar: e arrastando que se ve
## onde ele cai antes de largar. `_celula_aperto` guarda onde o dedo desceu e
## `_pegou_no_aperto` diz se aquele aperto recolheu um navio ja posto -- o par
## e o que separa o toque simples (recolhe e espera o segundo toque) do arrasto
## (recolhe, acompanha o dedo e larga onde ele subir).
var _celula_aperto := Vector2i(-1, -1)
var _pegou_no_aperto := false

## A ultima casa que o dedo/ponteiro visitou no mapa da frota.
##
## O Board3D so avisa quando a casa MUDA: depois de escolher outro navio -- pela
## ficha ou recolhendo um ja posto -- a previa some e so voltaria quando o dedo
## andasse para uma casa diferente. Guardando a casa, a previa do navio novo
## nasce onde o dedo ja esta.
var _ultima_casa := Vector2i(-1, -1)

## Os rotulos dos dois mapas. Guardados porque saem de cena no posicionamento:
## la a camera desce sobre a frota, e um rotulo de tamanho fixo em unidades de
## mundo viraria uma faixa atravessada na tela.
var _caption_radar: Label3D
var _caption_fleet: Label3D


## O retangulo que a camera enquadra. Guardado porque a barra de posicionar
## some quando a batalha comeca, e a faixa util cresce com ela.
var _conteudo_da_mesa: Vector2 = Vector2.ZERO

@onready var setup_bar: VBoxContainer = $SetupBar
@onready var frota_bar: HBoxContainer = $SetupBar/Frota
@onready var btn_rotate: Button = $SetupBar/Botoes/BtnRotate
@onready var btn_random: Button = $SetupBar/Botoes/BtnRandom
@onready var btn_start: Button = $SetupBar/Botoes/BtnStart

## Uma ficha por navio de `SHIP_DEFS`, na ordem da lista. E o unico lugar onde
## o jogador ve a frota inteira de uma vez: o que ja esta na agua, o que esta
## na mao e o que falta -- e o tamanho de cada um, em quadradinhos, que e a
## informacao que ele realmente usa para escolher onde esconder.
var _fichas: Array[Button] = []
var _pips: Array = []                     # indice do navio -> Array[ColorRect]

## Degrau de 1 a 10 do DifficultyManager. Vira a chance de a IA largar o mapa
## de densidade e sortear casa.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

## O que a IA sabe da frota do jogador -- so o que os proprios tiros contaram.
## Ela nunca le `player_grid`.
var ai_memoria: Dictionary = {}

@onready var radar_board: Board3D = $Board3D
@onready var fleet_board: Board3D = $FleetBoard
@onready var game_shell: GameShell = $GameShell
@onready var level_label: Label = game_shell.level_label

## Pinos e cascos de cada mapa, para limpar entre partidas.
var _radar_marks: Node3D
var _radar_wrecks: Node3D
var _fleet_marks: Node3D
var _fleet_hulls: Node3D
var _player_hull_nodes: Dictionary = {}   # indice do navio -> MeshInstance3D


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = game_shell.status_label
	btn_restart = game_shell.btn_restart
	game_shell.restart_requested.connect(_on_btn_restart_pressed)
	env_3d.apply_theme(GameTheme3D.steel_blue())
	ai_level = DifficultyManager.get_level(game_id)

	radar_board.setup_board(GRID, GRID, RADAR_CELL, "ocean_radar")
	fleet_board.setup_board(GRID, GRID, FLEET_CELL, "ocean_radar")
	_place_boards()

	_radar_marks = _child_root(radar_board, "Marks")
	_radar_wrecks = _child_root(radar_board, "Wrecks")
	_fleet_marks = _child_root(fleet_board, "Marks")
	_fleet_hulls = _child_root(fleet_board, "Hulls")
	_fleet_ghost = _child_root(fleet_board, "Ghost")

	_montar_fichas_da_frota()

	# O toque entra pelo proprio tabuleiro: a casa tocada e a casa desenhada.
	radar_board.cell_clicked.connect(_on_radar_cell_clicked)
	fleet_board.cell_clicked.connect(_on_fleet_cell_clicked)
	# No computador o ponteiro passeia antes de clicar, e o navio acompanha; no
	# telefone o `emulate_mouse_from_touch` faz o dedo arrastando gerar o mesmo
	# movimento, entao arrastar tambem mostra onde o navio vai cair.
	fleet_board.cell_hovered.connect(_on_fleet_cell_hovered)
	# O navio cai onde o dedo SOBE, e nao onde ele desceu: e isso que faz o
	# arrasto valer alguma coisa aqui.
	fleet_board.cell_released.connect(_on_fleet_cell_released)

	_start_new_game()


## Empilha os dois mapas na mesa e enquadra os dois juntos.
##
## A camera do PlayTable so precisa saber o retangulo que tem de caber; quando a
## largura manda -- e em retrato manda sempre -- ela mesma inclina mais para
## aproveitar a altura que sobraria. E o que faz os dois mapas caberem sem que
## nenhum deles vire um selo.
func _place_boards() -> void:
	var radar_size := radar_board.content_size()
	var fleet_size := fleet_board.content_size()
	var total_depth: float = radar_size.y + BOARD_GAP + fleet_size.y

	var z0: float = -total_depth * 0.5
	radar_board.position = Vector3(0.0, 0.0, z0 + radar_size.y * 0.5)
	fleet_board.position = Vector3(0.0, 0.0, z0 + radar_size.y + BOARD_GAP + fleet_size.y * 0.5)

	_caption_radar = _board_caption(radar_board, tr("BATTLESHIP_ENEMY_FLEET"),
		Color(1.0, 0.47, 0.38), radar_size)
	_caption_fleet = _board_caption(fleet_board, tr("BATTLESHIP_YOUR_FLEET"),
		Color(0.52, 0.86, 1.0), fleet_size)

	# A HUD ocupa os 230 px de cima; a camera enquadra a faixa que sobra.
	_conteudo_da_mesa = Vector2(maxf(radar_size.x, fleet_size.x) + 0.45, total_depth + 0.45)
	_enquadrar_a_fase()


## Enquadra o que a fase pede.
##
## No posicionamento o mapa de ataque nao serve para nada: ele esta vazio, nao
## aceita toque e ainda assim ficava com metade da tela enquanto o jogador
## tentava acertar casas de ~34 px no mapa de baixo -- justo a fase em que a
## precisao do dedo mais importa. Fora de cena, a frota fica com a tela toda e
## a casa quase dobra de tamanho. Na batalha os dois voltam, porque ai o jogo e
## comparar um mapa com o outro.
func _enquadrar_a_fase() -> void:
	var posicionando := fase == Fase.POSICIONANDO
	radar_board.visible = not posicionando
	if _caption_radar != null:
		_caption_radar.visible = not posicionando
	# O rotulo tem tamanho fixo em unidades de mundo: com a camera em cima da
	# frota ele viraria uma faixa atravessada na tela.
	if _caption_fleet != null:
		_caption_fleet.visible = not posicionando

	if posicionando:
		# Sem os rotulos na mesa nao ha o que caber em volta do tabuleiro: a
		# folga cai para o minimo que separa a borda da tela.
		#
		# E o tabuleiro sozinho e QUADRADO: num telefone em retrato o quadrado
		# cabe pela largura e deixa a altura sobrando. A saida e a que a camera
		# ja preve -- inclinar mais --, so que o teto de 74 graus do tema serve
		# a uma mesa com pecas de pe. Uma grade de batalha naval aceita quase de
		# cima, e e olhando de cima que se compara linha com coluna.
		fit_table(fleet_board.content_size() + Vector2(0.12, 0.12),
			fleet_board.position, TETO_POSICIONANDO)
	elif _conteudo_da_mesa != Vector2.ZERO:
		# Na batalha os dois mapas empilhados ja sao mais fundos que largos: a
		# profundidade manda, e o teto do tema basta.
		fit_table(_conteudo_da_mesa)


func _board_caption(board: Board3D, text: String, color: Color, board_size: Vector2) -> Label3D:
	var lbl := Label3D.new()
	lbl.text = text
	lbl.font_size = 64
	# O rotulo do mapa menor nao pode encolher junto com o mapa: ele e lido na
	# mesma tela, a mesma distancia. Por isso o tamanho e fixo em unidades de
	# mundo, e nao proporcional ao tabuleiro.
	lbl.pixel_size = 0.0042
	lbl.modulate = color
	lbl.outline_size = 12
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.shaded = false
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	lbl.position = Vector3(0.0, 0.02, -board_size.y * 0.5 - 0.26)
	board.add_child(lbl)
	return lbl


func _child_root(parent: Node3D, name_: String) -> Node3D:
	var node := Node3D.new()
	node.name = name_
	parent.add_child(node)
	return node


## Carimbo da partida corrente. O turno da IA e agendado por `await`, e sem esta
## marca a jogada de uma partida antiga caia sobre o tabuleiro da nova.
var _geracao: int = 0

func _start_new_game() -> void:
	_geracao += 1
	game_over = false
	is_player_turn = true
	btn_restart.hide()

	player_grid = Grid2D.new(GRID, GRID, 0)
	ai_grid = Grid2D.new(GRID, GRID, 0)
	player_ships = []
	ai_ships = BattleshipRules.place_all_ships_random(ai_grid)
	ai_level = DifficultyManager.get_level(game_id)
	ai_memoria = BattleshipAI.nova_memoria()

	for root in [_radar_marks, _radar_wrecks, _fleet_marks, _fleet_hulls]:
		for c in root.get_children():
			c.queue_free()
	_player_hull_nodes.clear()

	radar_board.clear_states()
	fleet_board.clear_states()

	fase = Fase.POSICIONANDO
	_navio_atual = 0
	_preview = []
	_celula_aperto = Vector2i(-1, -1)
	_ultima_casa = Vector2i(-1, -1)
	_pegou_no_aperto = false
	_limpar_fantasma()
	setup_bar.visible = true
	_enquadrar_a_fase()
	_pintar_botao_de_giro()
	_update_fleet_status_labels()
	_anunciar_posicionamento()


# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

## Crava o pino na coordenada. Ele cai de cima e assenta com um recuo curto;
## o de acerto ainda pulsa uma vez.
func _spawn_peg(board: Board3D, root: Node3D, r: int, c: int, is_hit: bool) -> void:
	var scale_ref: float = board.cell_size / RADAR_CELL
	var peg := MeshInstance3D.new()
	peg.mesh = MeshBuilder3D.create_peg_pin(0.35 * scale_ref, 0.1 * scale_ref)
	var target := board.get_cell_position_3d(r, c, 0.18 * scale_ref)
	peg.position = target
	if is_hit:
		peg.material_override = MaterialFactory3D.get_glow(Color(1.0, 0.25, 0.1), 2.5)
	else:
		peg.material_override = MaterialFactory3D.get_silver()
	root.add_child(peg)

	var d := Quality3D.duration(Tokens3D.DUR_NORMAL)
	if d <= 0.0:
		return
	peg.position = target + Vector3(0.0, 0.6, 0.0)
	peg.scale = Vector3(0.6, 0.6, 0.6)
	var tw := peg.create_tween()
	tw.set_parallel(true)
	tw.tween_property(peg, "position", target, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(peg, "scale", Vector3.ONE, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if is_hit:
		var pulso := Quality3D.duration(Tokens3D.DUR_FAST)
		tw.chain().tween_property(peg, "scale", Vector3(1.3, 1.3, 1.3), pulso * 0.5)
		tw.chain().tween_property(peg, "scale", Vector3.ONE, pulso * 0.5)


## Geometria do casco a partir das casas que o navio ocupa.
## Devolve `{size, center}` em coordenadas locais do tabuleiro.
func _hull_geometry(board: Board3D, ship: Dictionary) -> Dictionary:
	var cells: Array = ship["cells"]
	var primeira: Vector2i = cells[0]
	var ultima: Vector2i = cells[cells.size() - 1]
	var is_vert: bool = primeira.x != ultima.x
	var cell := board.cell_size
	var ao_longo: float = float(cells.size()) * cell * 0.92
	# A boca do casco: 74% da casa. Abaixo disso o navio vira um risco visto de
	# cima -- e no posicionamento a camera olha quase de cima --, e acima ele
	# encosta no navio da fileira vizinha e some a folga que separa um do outro.
	var atraves: float = cell * 0.74
	var a := board.get_cell_position_3d(primeira.x, primeira.y, 0.0)
	var b := board.get_cell_position_3d(ultima.x, ultima.y, 0.0)
	var center := (a + b) * 0.5
	var height: float = HULL_HEIGHT * (cell / RADAR_CELL)
	center.y = Tokens3D.TILE_THICKNESS + height * 0.5
	return {
		"size": Vector3(atraves if is_vert else ao_longo, height, ao_longo if is_vert else atraves),
		"center": center,
		"length": ao_longo,
		"beam": atraves,
		"height": height,
		# O casco e modelado com a proa em +X; navio vertical no tabuleiro so
		# precisa girar 90 graus em Y.
		"yaw": PI * 0.5 if is_vert else 0.0,
	}


## O casco em si, ja com a silhueta e a rotacao certas.
##
## Os cinco navios eram a MESMA caixa retangular, mudando so o comprimento:
## porta-avioes e destroier ficavam indistinguiveis, e nada aquilo parecia um
## navio. Mesma quantidade de geometria, agora com proa afilada e torre.
func _montar_casco(geo: Dictionary, material: StandardMaterial3D, ship_name: String = "") -> MeshInstance3D:
	var no := MeshInstance3D.new()
	no.mesh = MeshBuilder3D.ship_hull(
		float(geo["length"]), float(geo["beam"]), float(geo["height"]))
	no.material_override = material
	no.rotation.y = float(geo["yaw"])
	_deitar_arte_no_conves(no, geo, ship_name)
	return no


## A arte gerada da classe, deitada sobre o conves. O casco continua sendo a
## malha -- e ela que da a sombra, a borda e o destroco --; a imagem so entra
## por cima quando o PNG existe em `shared/assets/batalha_naval/`.
##
## O sprite fica no espaco do casco, entao herda o `yaw`: a proa da imagem
## aponta para +X como a proa da malha, e o navio vertical gira os dois juntos.
func _deitar_arte_no_conves(casco: MeshInstance3D, geo: Dictionary, ship_name: String) -> void:
	var chave: String = str(ART_NAVIOS.get(ship_name, ""))
	if chave == "":
		return
	var tex: Texture2D = AssetCatalog.get_game_art("batalha_naval", chave)
	if tex == null:
		return

	# So o pedaco desenhado do PNG entra: o gerador entrega o navio centrado num
	# quadrado com ~74% de transparencia em volta, e escalar pelo QUADRADO fazia
	# o desenho sair na medida do lado maior.
	var recorte := _recorte_desenhado(chave, tex)
	if recorte.size.x <= 0.0 or recorte.size.y <= 0.0:
		return

	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.region_enabled = true
	sprite.region_rect = recorte
	sprite.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.shaded = true

	# Tres sprites foram gerados com a proa para cima. Girar no plano local
	# alinha o comprimento da imagem ao +X do casco, sem alterar a malha.
	var de_pe := chave in ["couracado", "cruzador", "destroier"]
	var giro := 90.0 if de_pe else 0.0
	# Pixels do desenho ao longo do casco e atravessados nele, ja considerando
	# o giro: o lado longo do desenho e o comprimento do navio.
	var px_ao_longo: float = recorte.size.y if de_pe else recorte.size.x
	var px_atraves: float = recorte.size.x if de_pe else recorte.size.y

	sprite.pixel_size = float(geo["length"]) / maxf(px_ao_longo, 1.0)
	sprite.rotation_degrees = Vector3(-90.0, giro, 0.0)
	sprite.position = Vector3(0.0, float(geo["height"]) * 0.5 + 0.012, 0.0)

	# O desenho vem numa proporcao de ~3,8:1, sempre a mesma; o casco vai de 3:1
	# (Destroier, duas casas) a 7,4:1 (Porta-Avioes, cinco). Sem estreitar, o
	# porta-avioes saia com o DOBRO da boca do casco: ele encobria a fileira
	# vizinha e mentia sobre a propria pegada -- e a pegada e o jogo inteiro
	# numa batalha naval. Estreitar so o eixo transversal mantem o comprimento.
	var boca_desenhada: float = px_atraves * sprite.pixel_size
	var aperto: float = float(geo["beam"]) * 0.96 / maxf(boca_desenhada, 0.0001)
	if de_pe:
		sprite.scale = Vector3(minf(aperto, 1.0), 1.0, 1.0)
	else:
		sprite.scale = Vector3(1.0, minf(aperto, 1.0), 1.0)

	casco.add_child(sprite)


## Onde o navio esta desenhado dentro do PNG, em pixels.
##
## Medido uma vez por arquivo: `get_image()` desce a textura para a CPU, e cada
## partida monta ate dez cascos com os mesmos cinco PNGs. Ler do arquivo em vez
## de anotar as medidas a mao e o que faz a arte poder ser regerada sem que
## ninguem lembre de acertar numeros no codigo.
static var _recorte_por_arte: Dictionary = {}

static func _recorte_desenhado(chave: String, tex: Texture2D) -> Rect2:
	if _recorte_por_arte.has(chave):
		return _recorte_por_arte[chave]
	var caixa := Rect2(Vector2.ZERO, Vector2(tex.get_width(), tex.get_height()))
	var img := tex.get_image()
	if img != null:
		if img.is_compressed():
			img.decompress()
		var usado := img.get_used_rect()
		if usado.size.x > 0 and usado.size.y > 0:
			caixa = Rect2(usado.position, usado.size)
	_recorte_por_arte[chave] = caixa
	return caixa


func _render_player_hull(ship: Dictionary, index: int) -> void:
	if (ship["cells"] as Array).is_empty():
		return
	var geo := _hull_geometry(fleet_board, ship)
	var hull := _montar_casco(geo, MaterialFactory3D.get_plastic(Color(0.78, 0.81, 0.84), true),
		str(ship.get("name", "")))
	hull.position = geo["center"]
	_fleet_hulls.add_child(hull)
	_player_hull_nodes[index] = hull

	var d := Quality3D.duration(Tokens3D.DUR_SLOW)
	if d <= 0.0:
		return
	hull.position = geo["center"] - Vector3(0.0, 0.5, 0.0)
	var tw := hull.create_tween()
	tw.tween_interval(float(index) * 0.06)
	tw.tween_property(hull, "position", geo["center"], d) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


## O navio inimigo afundado aparece inteiro no mapa de ataque.
##
## Ate aqui o jogador so ficava com os pinos vermelhos espalhados e nunca via o
## que tinha derrubado. O casco sobe do fundo no lugar exato das casas, ja em
## tom de destroco, e estoura em volta.
func _reveal_enemy_wreck(ship: Dictionary) -> void:
	if (ship["cells"] as Array).is_empty():
		return
	var geo := _hull_geometry(radar_board, ship)
	var center: Vector3 = geo["center"]

	var wreck := _montar_casco(geo, MaterialFactory3D.get_plastic(Color(0.26, 0.23, 0.21), false),
		str(ship.get("name", "")))

	wreck.position = center
	_radar_wrecks.add_child(wreck)

	_explode_around(_radar_wrecks, center, geo["size"])

	var d := Quality3D.duration(Tokens3D.DUR_SLOW)
	if d <= 0.0:
		return
	wreck.position = center - Vector3(0.0, 0.45, 0.0)
	wreck.create_tween().tween_property(wreck, "position", center, d) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## O navio aliado afundado queima no lugar onde estava.
func _burn_player_hull(ship: Dictionary) -> void:
	var index := player_ships.find(ship)
	var geo := _hull_geometry(fleet_board, ship)
	if _player_hull_nodes.has(index):
		var hull: MeshInstance3D = _player_hull_nodes[index]
		if is_instance_valid(hull):
			hull.material_override = MaterialFactory3D.get_plastic(Color(0.28, 0.24, 0.22), false)
	_explode_around(_fleet_hulls, geo["center"], geo["size"])


func _explode_around(parent: Node3D, center: Vector3, size: Vector3) -> void:
	# Meias-medidas: o estouro parte do contorno do casco, nao de um ponto no
	# meio dele -- e o que faz o fogo abrir EM VOLTA do navio.
	Explosion3D.burst(parent, center, size * 0.5)
	if env_3d:
		env_3d.focus_on(parent.to_global(center))


func _update_fleet_status_labels() -> void:
	var ai_sunk := BattleshipRules.count_sunk_ships(ai_ships)
	var player_sunk := BattleshipRules.count_sunk_ships(player_ships)
	set_duel_score("%d/5" % ai_sunk, "%d/5" % player_sunk, "SCORE_SUNK", "SCORE_LOST")
	level_label.text = DifficultyManager.label_for(game_id)


# ---------------------------------------------------------------------------
# Posicionamento da frota
# ---------------------------------------------------------------------------

## O navio que esta na mao agora, ou `{}` quando os cinco ja estao na agua.
func _def_do_navio_atual() -> Dictionary:
	if _navio_atual < 0 or _navio_atual >= BattleshipRules.SHIP_DEFS.size():
		return {}
	return BattleshipRules.SHIP_DEFS[_navio_atual]


## As casas que o navio da mao ocuparia se o dedo largasse em (r, c).
func _casas_da_previa(r: int, c: int) -> Array:
	var def := _def_do_navio_atual()
	if def.is_empty():
		return []
	var tamanho := int(def["size"])
	var ancora := BattleshipRules.anchor_for(r, c, tamanho, _vertical)
	return BattleshipRules.cells_for(ancora.x, ancora.y, tamanho, _vertical)


## Acende no mapa da frota onde o navio vai cair: verde se cabe, vermelho se
## nao. Sem isto o jogador so descobre a posicao depois de o casco aparecer.
func _mostrar_previa(r: int, c: int) -> void:
	var casas := _casas_da_previa(r, c)
	if casas == _preview:
		return
	_preview = casas
	fleet_board.clear_states()
	_limpar_fantasma()
	if casas.is_empty():
		return
	var cabe := BattleshipRules.can_place(player_grid, casas)
	fleet_board.set_cells_state(casas,
		Board3D.CellState.VALID if cabe else Board3D.CellState.INVALID)
	_desenhar_fantasma(casas, cabe)


## O casco translucido no lugar em que o navio vai cair.
##
## O tom da casa diz SE cabe; o fantasma diz O QUE cabe. Sao coisas diferentes:
## com cinco navios de tamanhos parecidos, ver o contorno da proa no lugar
## evita o "eu queria o de tres, nao o de quatro" que so aparecia depois de
## soltar. E o mesmo casco da frota, sem a arte por cima -- silhueta, e nao
## navio pintado, para ninguem confundir fantasma com navio posto.
func _desenhar_fantasma(casas: Array, cabe: bool) -> void:
	var def := _def_do_navio_atual()
	if def.is_empty() or casas.is_empty():
		return
	var geo := _hull_geometry(fleet_board, {"cells": casas})
	var cor := Color(0.45, 0.95, 0.60, 0.42) if cabe else Color(1.0, 0.35, 0.30, 0.42)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = cor
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	# Sem isto o fantasma some dentro do tabuleiro em vez de flutuar sobre ele.
	mat.no_depth_test = true
	_fantasma = _montar_casco(geo, mat)
	_fantasma.position = geo["center"]
	_fleet_ghost.add_child(_fantasma)


func _limpar_fantasma() -> void:
	if _fantasma != null and is_instance_valid(_fantasma):
		# Sai da cena AGORA, e nao no fim do quadro: num arrasto a previa se
		# refaz varias vezes por quadro, e com `queue_free()` dois ou tres
		# fantasmas ficariam pendurados juntos na mesma imagem. Liberar na hora
		# e seguro porque o fantasma nao tem retorno de chamada nenhum -- e uma
		# malha muda, sem tween, sem sinal.
		_fleet_ghost.remove_child(_fantasma)
		_fantasma.free()
	_fantasma = null


## Poe o navio da mao no mapa.
##
## Chamado ao SOLTAR, e nao ao apertar: quem recolhe um navio ja posto e o
## aperto (`_on_fleet_cell_clicked`), e entre um e outro o dedo pode arrastar.
func _posicionar_em(r: int, c: int) -> void:
	var def := _def_do_navio_atual()
	if def.is_empty():
		set_status(tr("BATTLESHIP_PLACE_DONE"))
		return

	var casas := _casas_da_previa(r, c)
	if not BattleshipRules.can_place(player_grid, casas):
		set_status(tr("BATTLESHIP_PLACE_BLOCKED"))
		if AudioManager:
			AudioManager.play_error()
		return

	for cell in casas:
		var v: Vector2i = cell
		player_grid.set_cell(v.x, v.y, 1)
	var navio := {
		"name": def["name"],
		"size": int(def["size"]),
		"cells": casas,
		"hits": 0,
		"sunk": false,
	}
	player_ships.append(navio)
	_render_player_hull(navio, player_ships.size() - 1)
	if AudioManager:
		AudioManager.play_piece_place()

	# O proximo da mao e sempre o primeiro que FALTA, e nao o seguinte na lista:
	# depois de recolher o Cruzador e repo-lo, "o seguinte" seria o Submarino,
	# que ja estava na agua -- e ele acabava posto duas vezes.
	_navio_atual = _primeiro_faltando()
	_preview = []
	fleet_board.clear_states()
	_limpar_fantasma()
	_anunciar_posicionamento()


## O indice do navio do jogador que ocupa esta casa, ou -1.
func _navio_em(r: int, c: int) -> int:
	var alvo := Vector2i(r, c)
	for i in range(player_ships.size()):
		if alvo in player_ships[i]["cells"]:
			return i
	return -1


## Tira o navio do mapa e o devolve para a mao.
func _recolher_navio(indice: int) -> void:
	var navio: Dictionary = player_ships[indice]
	for cell in navio["cells"]:
		var v: Vector2i = cell
		player_grid.set_cell(v.x, v.y, 0)
	player_ships.remove_at(indice)
	_redesenhar_frota()
	# O navio recolhido volta para a mao: o proximo a posicionar e ELE, e nao o
	# primeiro da lista que estiver faltando. Sem isto, recolher o Destroier
	# punha o Porta-Avioes na mao e o jogador via a previa do navio errado.
	_navio_atual = _indice_da_definicao(str(navio["name"]))
	_repor_previa()
	if AudioManager:
		AudioManager.play_click()
	set_status(tr("BATTLESHIP_PLACE_PICKUP") % tr(str(navio["name"])))
	_atualizar_botoes_de_posicionar()


## O indice em `SHIP_DEFS` do navio com este nome, ou o primeiro que faltar.
func _indice_da_definicao(nome: String) -> int:
	for i in range(BattleshipRules.SHIP_DEFS.size()):
		if str(BattleshipRules.SHIP_DEFS[i]["name"]) == nome:
			return i
	return _primeiro_faltando()


## O primeiro navio de `SHIP_DEFS` que ainda nao esta na agua.
func _primeiro_faltando() -> int:
	for i in range(BattleshipRules.SHIP_DEFS.size()):
		if not _navio_posto(str(BattleshipRules.SHIP_DEFS[i]["name"])):
			return i
	return BattleshipRules.SHIP_DEFS.size()


func _redesenhar_frota() -> void:
	for c in _fleet_hulls.get_children():
		c.queue_free()
	_player_hull_nodes.clear()
	for i in range(player_ships.size()):
		_render_player_hull(player_ships[i], i)


## A barra da frota: uma ficha por navio, com o tamanho dele em quadradinhos.
##
## Ate aqui o jogador so sabia da propria frota o que a linha de status dizia,
## uma frase por vez: "Posicione o Cruzador (3 casas)". Nao dava para saber
## quantos faltavam, quais ja estavam na agua, nem escolher qual por primeiro
## -- e corrigir UM navio exigia achar o casco no mapa e adivinhar que tocar
## nele o devolvia para a mao. A ficha responde as tres perguntas de uma vez e
## e o atalho para pegar o navio que se quer, sem mexer nos outros.
##
## O tamanho vai em quadradinhos e nao em numero porque e assim que o jogador
## pensa a decisao: ele nao procura "um de quatro", procura onde cabe uma peca
## deste comprimento.
func _montar_fichas_da_frota() -> void:
	for i in range(BattleshipRules.SHIP_DEFS.size()):
		var def: Dictionary = BattleshipRules.SHIP_DEFS[i]
		var tamanho := int(def["size"])

		var ficha := Button.new()
		ficha.custom_minimum_size = Vector2(0.0, UIKit.TOQUE_MIN)
		ficha.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ficha.tooltip_text = "%s (%d)" % [tr(str(def["name"])), tamanho]
		ficha.pressed.connect(_on_ficha_pressed.bind(i))
		frota_bar.add_child(ficha)

		# Os quadradinhos moram DENTRO do botao e nao recebem toque: o alvo do
		# dedo continua sendo a ficha inteira, do tamanho minimo de toque.
		var linha := HBoxContainer.new()
		linha.set_anchors_preset(Control.PRESET_FULL_RECT)
		linha.alignment = BoxContainer.ALIGNMENT_CENTER
		linha.add_theme_constant_override("separation", 3)
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ficha.add_child(linha)

		var quadrados: Array[ColorRect] = []
		for _q in range(tamanho):
			var pip := ColorRect.new()
			pip.custom_minimum_size = Vector2(13.0, 26.0)
			pip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			linha.add_child(pip)
			quadrados.append(pip)

		_fichas.append(ficha)
		_pips.append(quadrados)


## Pinta as fichas com o estado de cada navio.
func _atualizar_fichas() -> void:
	for i in range(_fichas.size()):
		var nome: String = str(BattleshipRules.SHIP_DEFS[i]["name"])
		var na_agua := _navio_posto(nome)
		var na_mao := i == _navio_atual and not na_agua
		var cor := UIKit.TEXTO_FRACO
		if na_agua:
			cor = UIKit.VERDE
		elif na_mao:
			cor = UIKit.OURO
		for pip in _pips[i]:
			(pip as ColorRect).color = cor
		# A ficha na mao e a unica em brilho cheio: o jogador acha num relance
		# qual navio o dedo esta carregando.
		_fichas[i].modulate = Color(1.0, 1.0, 1.0, 1.0 if na_mao else 0.55)


func _navio_posto(nome: String) -> bool:
	for navio in player_ships:
		if str(navio["name"]) == nome:
			return true
	return false


## Tocar a ficha escolhe o navio: o que ainda falta vai para a mao, e o que ja
## esta na agua e recolhido de volta para ela.
func _on_ficha_pressed(indice: int) -> void:
	if fase != Fase.POSICIONANDO or game_over:
		return
	play_click()
	var nome: String = str(BattleshipRules.SHIP_DEFS[indice]["name"])
	for i in range(player_ships.size()):
		if str(player_ships[i]["name"]) == nome:
			_recolher_navio(i)
			return
	_navio_atual = indice
	_repor_previa()
	_anunciar_posicionamento()


## Redesenha a previa do navio que esta na mao, na casa em que o dedo esta.
func _repor_previa() -> void:
	var onde := _celula_da_previa()
	_preview = []
	fleet_board.clear_states()
	_limpar_fantasma()
	if onde.x >= 0:
		_mostrar_previa(onde.x, onde.y)


func _anunciar_posicionamento() -> void:
	_atualizar_botoes_de_posicionar()
	var def := _def_do_navio_atual()
	if def.is_empty():
		set_status(tr("BATTLESHIP_PLACE_DONE"))
		return
	set_status(tr("BATTLESHIP_PLACE_SHIP") % [tr(str(def["name"])), int(def["size"])])


func _atualizar_botoes_de_posicionar() -> void:
	var completa := player_ships.size() >= BattleshipRules.SHIP_DEFS.size()
	btn_start.disabled = not completa
	_pintar_botao_de_giro()
	_atualizar_fichas()


func _pintar_botao_de_giro() -> void:
	btn_rotate.text = tr("BATTLESHIP_BTN_ROTATE_V" if _vertical else "BATTLESHIP_BTN_ROTATE_H")


func _on_btn_rotate_pressed() -> void:
	_vertical = not _vertical
	_pintar_botao_de_giro()
	play_click()
	# Girar apagava a previa e deixava o jogador sem saber como o navio ficou:
	# ele tinha de mover o dedo de novo so para ver o resultado do proprio
	# botao. Redesenha na mesma casa, ja na nova orientacao.
	_repor_previa()


## A casa em que a previa esta agora -- a do meio do navio --, ou a ultima que
## o dedo visitou quando nao ha previa. E de onde a previa renasce depois de
## girar ou de trocar o navio da mao.
func _celula_da_previa() -> Vector2i:
	if _preview.is_empty():
		return _ultima_casa
	return _preview[_preview.size() / 2]


func _on_btn_random_pressed() -> void:
	play_click()
	player_grid.fill(0)
	player_ships = BattleshipRules.place_all_ships_random(player_grid)
	_redesenhar_frota()
	_navio_atual = _primeiro_faltando()
	_preview = []
	fleet_board.clear_states()
	_limpar_fantasma()
	_anunciar_posicionamento()


## Fecha o posicionamento e comeca a batalha.
func _on_btn_start_pressed() -> void:
	if player_ships.size() < BattleshipRules.SHIP_DEFS.size():
		return
	play_click()
	_comecar_batalha()


func _comecar_batalha() -> void:
	fase = Fase.BATALHA
	_preview = []
	fleet_board.clear_states()
	_limpar_fantasma()
	setup_bar.visible = false
	# O mapa de ataque volta a cena e a barra some: a faixa util cresce dos dois
	# lados, e os dois mapas reenquadram sozinhos.
	_enquadrar_a_fase()
	is_player_turn = true
	_update_fleet_status_labels()
	set_status(tr("BATTLESHIP_YOUR_TURN"))
	begin_match("solo")


# ---------------------------------------------------------------------------
# Turnos
# ---------------------------------------------------------------------------

## O dedo desceu no mapa da frota.
##
## Aqui o navio nao e posto -- ele e POSTO AO SOLTAR. O aperto so recolhe um
## navio ja posto (com a mao vazia), para que o mesmo gesto continue arrastando
## o navio recolhido ate o lugar novo.
func _on_fleet_cell_clicked(r: int, c: int) -> void:
	if game_over:
		return
	if fase != Fase.POSICIONANDO:
		set_status(tr("BATTLESHIP_WRONG_BOARD"))
		return

	_celula_aperto = Vector2i(r, c)
	_ultima_casa = _celula_aperto
	_pegou_no_aperto = false

	# Com um navio na mao o aperto e sempre uma tentativa de POR, nunca de
	# tirar: pegar um segundo navio deixaria dois na mao e ninguem saberia qual
	# esta indo.
	if _def_do_navio_atual().is_empty():
		var posto := _navio_em(r, c)
		if posto >= 0:
			_recolher_navio(posto)
			_pegou_no_aperto = true
		else:
			set_status(tr("BATTLESHIP_PLACE_DONE"))
			return
	_mostrar_previa(r, c)


## O dedo subiu no mapa da frota: e aqui que o navio cai.
##
## Dois gestos, um caminho so. Arrastar: o aperto recolhe (ou ja havia navio na
## mao), a previa acompanha o dedo e o navio cai onde ele sobe. Dois toques: o
## primeiro toque recolhe o navio e ele FICA na mao -- por isso o toque simples
## sobre o navio que se acabou de pegar nao o repoe --, e o segundo toque diz
## onde ele vai. Sem essa distincao, so quem arrastasse conseguiria mover um
## navio ja posto.
func _on_fleet_cell_released(r: int, c: int) -> void:
	if game_over or fase != Fase.POSICIONANDO:
		return
	var mesmo_lugar := Vector2i(r, c) == _celula_aperto
	var so_pegou := _pegou_no_aperto and mesmo_lugar
	_pegou_no_aperto = false
	_celula_aperto = Vector2i(-1, -1)
	if so_pegou:
		return
	_posicionar_em(r, c)


func _on_fleet_cell_hovered(r: int, c: int) -> void:
	if fase != Fase.POSICIONANDO or game_over:
		return
	_ultima_casa = Vector2i(r, c)
	_mostrar_previa(r, c)


func _on_radar_cell_clicked(r: int, c: int) -> void:
	if game_over:
		return
	if fase == Fase.POSICIONANDO:
		set_status(tr("BATTLESHIP_PLACE_WAIT"))
		return
	if not is_player_turn:
		return
	var cell_val: int = ai_grid.get_cell(r, c)
	if cell_val == 2 or cell_val == 3:
		set_status(tr("BATTLESHIP_ALREADY_SHOT"))
		return

	var is_hit: bool = cell_val == 1
	ai_grid.set_cell(r, c, 3 if is_hit else 2)
	_spawn_peg(radar_board, _radar_marks, r, c, is_hit)
	# O som chega antes de o texto ser lido: acerto estoura, agua chapinha.
	if AudioManager:
		if is_hit:
			AudioManager.play_explosion()
		else:
			AudioManager.play_splash()

	if is_hit:
		var sunk_ship := BattleshipRules.check_ship_sunk(ai_ships, ai_grid, r, c)
		if sunk_ship.size() > 0:
			set_status(tr("BATTLESHIP_YOU_SANK") % tr(str(sunk_ship["name"])))
			_reveal_enemy_wreck(sunk_ship)
		else:
			set_status(tr("BATTLESHIP_HIT"))
	else:
		set_status(tr("BATTLESHIP_MISS"))

	_update_fleet_status_labels()

	if BattleshipRules.check_all_sunk(ai_ships):
		_end_game(true)
		return

	is_player_turn = false
	var geracao: int = _geracao
	await get_tree().create_timer(0.6).timeout
	if geracao != _geracao or game_over or not is_inside_tree():
		return
	_play_ai_turn()


func _play_ai_turn() -> void:
	var ai_target := BattleshipAI.escolher_tiro(ai_memoria, ai_level)
	if ai_target.x < 0:
		is_player_turn = true
		return
	var r := ai_target.x
	var c := ai_target.y

	var is_hit: bool = int(player_grid.get_cell(r, c)) == 1
	player_grid.set_cell(r, c, 3 if is_hit else 2)
	_spawn_peg(fleet_board, _fleet_marks, r, c, is_hit)
	if AudioManager:
		if is_hit:
			AudioManager.play_explosion()
		else:
			AudioManager.play_splash()

	# A IA so fica sabendo o que o tiro revelou -- acerto, erro e, quando
	# afunda, as casas do navio. E dai que sai o mapa do proximo tiro.
	var afundadas: Array = []
	if is_hit:
		var sunk := BattleshipRules.check_ship_sunk(player_ships, player_grid, r, c)
		if sunk.size() > 0:
			afundadas = sunk["cells"]
			set_status(tr("BATTLESHIP_AI_SANK") % tr(str(sunk["name"])))
			_burn_player_hull(sunk)
		else:
			set_status(tr("BATTLESHIP_AI_HIT"))
	else:
		set_status(tr("BATTLESHIP_AI_MISS"))
	BattleshipAI.registrar(ai_memoria, ai_target, is_hit, afundadas)

	_update_fleet_status_labels()

	if BattleshipRules.check_all_sunk(player_ships):
		_end_game(false)
		return

	is_player_turn = true


func _end_game(is_player_win: bool) -> void:
	if is_player_win:
		finish_game(tr("BATTLESHIP_WIN"), true)
	else:
		finish_game(tr("BATTLESHIP_LOSE"))
