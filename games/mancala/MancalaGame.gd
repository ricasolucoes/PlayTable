extends BaseGame

## MancalaGame: Mancala 3D com Tabuleiro Esculpido em Madeira Nobre e Gemas Preciosas

var pits: Array = []
var is_player_turn: bool = true
var gems_3d: Dictionary = {}

## Degrau de 1 a 10 do DifficultyManager. Vira orcamento de busca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

## Dois no mesmo aparelho: as seis covas de cima deixam de ser da maquina e
## passam a ser da pessoa do outro lado da mesa. O tabuleiro ja e simetrico --
## o que faltava era o toque e o anel chegarem la.
var vs_ai: bool = true
var mode_switch: ModeSwitch = null

## O lado da vez na mesa compartilhada: 0 e quem tem as covas 0..5, 1 e quem
## tem as 7..12. Contra a maquina e sempre 0.
var _lado_local: int = 0

## As doze covas que se semeiam, na ordem dos aneis. As duas Kalahs (6 e 13)
## ficam de fora: ninguem semeia a partir do proprio deposito.
const COVAS := [0, 1, 2, 3, 4, 5, 7, 8, 9, 10, 11, 12]

@onready var board_root: Node3D = $BoardRoot
@onready var gems_root: Node3D = $GemsRoot
@onready var shell: GameShell = $UI/GameShell

## Anel sob as covas que dão para semear. O Mancala não tinha afordância nenhuma
## no tabuleiro: o número no botão dizia QUANTAS sementes havia, e nada dizia
## quais covas eram suas nem quais estavam jogáveis.
var halos: CellHalo3D = null

## O toque nas seis covas do jogador, projetado da propria mesa. Era uma fileira
## de seis botoes no pe da tela -- uma grade 2D ancorada sobre um tabuleiro 3D,
## que nunca coincide com ele, e que com o tabuleiro de pe nem faria sentido.
var picker: DragPicker3D = null

## Quantas sementes ha em cada cova, escrito na mesa ao lado dela. Era o texto
## do botao; a cova de cima nem tinha numero.
var count_labels: Array[Label3D] = []

## Em retrato o tabuleiro fica DE PE. Deitado ele era 6,8 x 2,4 -- quase tres
## vezes mais largo que fundo -- e ocupava um terco da altura da tela com a
## cova a 68 px; de pe cabe na altura inteira e a cova passa de 90 px. As covas
## do jogador descem pela coluna da esquerda, a Kalah dele e a de baixo (perto
## de quem joga), as da IA sobem pela coluna da direita e a Kalah da IA e a de
## cima. E a mesma semeadura anti-horaria de sempre, vista de pe.
const PIT_POSITIONS_3D = {
	# Jogador (0 a 5): coluna da esquerda, de cima para baixo
	0: Vector3(-0.8, 0.08, -1.9),
	1: Vector3(-0.8, 0.08, -1.14),
	2: Vector3(-0.8, 0.08, -0.38),
	3: Vector3(-0.8, 0.08, 0.38),
	4: Vector3(-0.8, 0.08, 1.14),
	5: Vector3(-0.8, 0.08, 1.9),
	# Kalah do jogador (6): embaixo
	6: Vector3(0.0, 0.08, 2.8),
	# IA (7 a 12): coluna da direita, de baixo para cima
	7: Vector3(0.8, 0.08, 1.9),
	8: Vector3(0.8, 0.08, 1.14),
	9: Vector3(0.8, 0.08, 0.38),
	10: Vector3(0.8, 0.08, -0.38),
	11: Vector3(0.8, 0.08, -1.14),
	12: Vector3(0.8, 0.08, -1.9),
	# Kalah da IA (13): em cima
	13: Vector3(0.0, 0.08, -2.8)
}

## Base de madeira: larga o bastante para os numeros ao lado das covas.
const BASE_SIZE := Vector3(3.2, 0.22, 6.8)

const GEM_MATERIALS = ["ruby", "sapphire", "emerald", "amber", "gold"]

## A arte gerada das sementes (`tools/art/mancala.json`), por material. Rubi e
## ouro nao tem manifesto e ficam procedurais.
const ART_SEMENTES := {
	"amber": "mancala/semente_ambar",
	"emerald": "mancala/semente_esmeralda",
	"sapphire": "mancala/semente_safira",
}

## Raio da semente. O padrao do Token3D e 0,36 -- diametro 0,72 numa cova de
## 0,52 de largura util: uma semente ja transbordava, e seis viravam uma bola.
const GEM_RADIUS := 0.11

## Quantas sementes uma cova chega a desenhar. Acima disso o numero no botao e
## que conta, porque vinte esferas numa cova nao se distinguem de dezoito.
const GEM_MAX_VISIVEL := 12

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	ai_level = DifficultyManager.get_level(game_id)
	_setup_3d_mancala_board()
	_setup_count_labels()
	_setup_picker()
	mode_switch = ModeSwitch.montar(self, vs_ai)
	mode_switch.trocou.connect(_on_modo_trocado)

	halos = CellHalo3D.new()
	$BoardRoot.add_child(halos)
	# As doze covas ganham anel, mas so acendem as de quem joga agora -- contra a
	# maquina, as seis de baixo; na mesa compartilhada, as seis do lado da vez.
	# Anel onde nao se pode tocar continua sendo ruido, e por isso quem decide e
	# `light_only`, nao a montagem.
	halos.setup(COVAS.size(), 0.30)
	var alvos: Array[Vector3] = []
	for i in COVAS:
		alvos.append(PIT_POSITIONS_3D[i])
	halos.set_targets(alvos)
	# Sem tema proprio a cena herda o `casino_green`, mesa de carteado, cujo teto de
	# inclinacao de camera e 56 graus para a face da carta nao achatar. Isto aqui e
	# tabuleiro: em retrato quem manda e a largura, a camera quer deitar mais para
	# aproveitar a altura que sobra, e batia nesse teto. Os outros temas herdam os
	# 74 graus do padrao.
	env_3d.apply_theme(GameTheme3D.desert_gold())

	fit_table(Vector2(BASE_SIZE.x + 0.2, BASE_SIZE.z + 0.2))
	_start_new_game()

func _setup_3d_mancala_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	
	# Base de madeira entalhada. O topo fica 3 cm ACIMA da mesa: com o topo em
	# y=0, o mesmo y do tampo do ambiente, os dois planos disputavam o pixel e
	# a madeira clara da mesa aparecia em listras sobre o mogno -- o mesmo
	# defeito dos "entalhes" do Resta Um.
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = BASE_SIZE
	base.mesh = box
	base.position = Vector3(0, -BASE_SIZE.y * 0.5 + 0.03, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# Cavidades / Covas escavadas
	for idx in PIT_POSITIONS_3D.keys():
		var pit_mesh := MeshInstance3D.new()
		var cyl := CylinderMesh.new()
		var is_store = (idx == 6 or idx == 13)
		cyl.top_radius = 0.45 if is_store else 0.32
		cyl.bottom_radius = 0.38 if is_store else 0.28
		cyl.height = 0.06
		pit_mesh.mesh = cyl
		pit_mesh.position = PIT_POSITIONS_3D[idx] - Vector3(0, 0.02, 0)
		pit_mesh.material_override = MaterialFactory3D.get_wood_walnut()
		board_root.add_child(pit_mesh)

## Um numero deitado na mesa ao lado de cada cova, do lado de fora da coluna
## -- nunca sobre as sementes, que foi o defeito que levou o numero para o
## botao. As Kalahs levam o numero ao lado, na direcao do centro da mesa.
func _setup_count_labels() -> void:
	count_labels.clear()
	for idx in range(14):
		var lbl := Label3D.new()
		lbl.font_size = 64
		lbl.pixel_size = 0.005
		lbl.modulate = Color(0.97, 0.93, 0.82)
		lbl.outline_size = 12
		lbl.outline_modulate = Color(0.12, 0.07, 0.03, 0.9)
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lbl.shaded = false
		lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = _count_label_pos(idx)
		board_root.add_child(lbl)
		count_labels.append(lbl)


func _count_label_pos(idx: int) -> Vector3:
	var pos: Vector3 = PIT_POSITIONS_3D[idx]
	if idx == 6:
		return Vector3(0.95, 0.1, pos.z)
	if idx == 13:
		return Vector3(-0.95, 0.1, pos.z)
	var lado: float = -1.0 if idx <= 5 else 1.0
	return Vector3(lado * 1.36, 0.1, pos.z)


## Semear e um toque; o `DragPicker3D` entra pelo alvo mais proximo dentro do
## raio, e nao pela casa exatamente sob o dedo. Um dedo que tremeu ao soltar
## sobre a mesma cova continua sendo um toque.
func _setup_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, 0.08)
	var alvos: Dictionary = {}
	for i in COVAS:
		alvos[i] = board_root.to_global(PIT_POSITIONS_3D[i])
	picker.set_targets(alvos)
	picker.target_tapped.connect(func(id: Variant) -> void: _on_player_pit_clicked(int(id)))
	picker.drag_ended.connect(func(de: Variant, ate: Variant) -> void:
		if ate != null and ate == de:
			_on_player_pit_clicked(int(de)))

## De quem sao as covas que o toque semeia agora.
func _lado() -> int:
	return 0 if vs_ai else _lado_local


## A cova pertence ao lado? As de 0 a 5 sao do primeiro, as de 7 a 12 do segundo.
static func _dono_da_cova(cova: int) -> int:
	return 0 if cova <= 5 else 1


## O jogador trocou o modo: a partida recomeca.
func _on_modo_trocado(novo_vs_ai: bool) -> void:
	vs_ai = novo_vs_ai
	restart_game()


func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	_lado_local = 0
	btn_restart.hide()
	
	ai_level = DifficultyManager.get_level(game_id)
	pits.clear()
	for i in range(14):
		pits.append(0 if (i == 6 or i == 13) else 4)
		
	set_status(tr("MANCALA_YOUR_TURN_LONG") if vs_ai else tr("TURN_PLAYER") % 1)
	_sync_gems_3d()
	_update_ui()

func _sync_gems_3d() -> void:
	for g in gems_root.get_children(): g.queue_free()
	gems_3d.clear()
	
	for pit_idx in range(14):
		var count: int = mini(pits[pit_idx], GEM_MAX_VISIVEL)
		var pit_pos = PIT_POSITIONS_3D[pit_idx]
		var gem_list: Array = []
		for g_i in range(count):
			var gem := preload("res://shared/3d/Token3D.tscn").instantiate()
			gem.token_type = "sphere"
			gem.material_name = GEM_MATERIALS[g_i % GEM_MATERIALS.size()]
			gem.art_by_material = ART_SEMENTES

			
			# Espalhar em espiral de angulo aureo, e nao empilhar: com passo de 0,04
			# contra esferas de ~0,62 de diametro as sementes se atravessavam e a
			# cova virava uma bola so. A semente tambem encolheu, senao seis delas
			# nao cabem numa cova.
			gem.token_radius = GEM_RADIUS
			var kalah := pit_idx == 6 or pit_idx == 13
			var raio: float = (0.46 if kalah else 0.26) * sqrt((float(g_i) + 0.5) / maxf(float(count), 1.0))
			var theta := float(g_i) * 2.39996
			var camada := floori(float(g_i) / 8.0)
			gem.position = pit_pos + Vector3(
				cos(theta) * raio,
				0.05 + float(camada) * (GEM_RADIUS * 1.6),
				sin(theta) * raio)
			
			gems_root.add_child(gem)
			gem_list.append(gem)
		gems_3d[pit_idx] = gem_list

func _update_ui() -> void:
	if vs_ai:
		set_duel_score(pits[6], pits[13])
		shell.set_level(DifficultyManager.label_for(game_id))
	else:
		set_duel_score(pits[6], pits[13], "SCORE_PLAYER_1", "SCORE_PLAYER_2")
		shell.set_level(tr("MODE_LABEL") % tr("MODE_TWO_PLAYERS"))

	for i in range(mini(14, count_labels.size())):
		count_labels[i].text = "%d" % int(pits[i])

	# So acendem as covas de quem joga agora: e o anel que diz de quem e a vez.
	var jogaveis: Array = []
	for indice in range(COVAS.size()):
		var cova: int = COVAS[indice]
		if _dono_da_cova(cova) != _lado():
			continue
		if is_player_turn and int(pits[cova]) > 0 and not game_over:
			jogaveis.append(indice)
	if halos:
		halos.light_only(jogaveis)
	if picker:
		picker.enabled = is_player_turn and not game_over

## Semeia a cova do jogador. A regra e a mesma que a busca da IA usa: semear,
## pular a Kalah do adversario, turno extra e captura moram todos em
## `MancalaAI.semear()`. Enquanto a cena tinha a propria copia -- uma para cada
## lado, alias -- nada garantia que a IA estivesse buscando sobre o jogo que a
## cena de fato jogava.
func _on_player_pit_clicked(pit_idx: int) -> void:
	if game_over or not is_player_turn or pits[pit_idx] == 0: return
	# A cova tem de ser de quem joga agora. Contra a maquina isso quer dizer as
	# seis de baixo; na mesa compartilhada, as do lado da vez.
	var lado := _lado()
	if _dono_da_cova(pit_idx) != lado: return

	var ganhou := _semear(pit_idx, lado)
	if ganhou["capturou"] > 0:
		set_status(tr("MANCALA_YOU_CAPTURE") % ganhou["capturou"])
		if AudioManager:
			AudioManager.play_capture()

	if _check_game_over(): return

	if ganhou["extra"]:
		set_status(tr("MANCALA_FREE_TURN"))
		_update_ui()
		return

	# Mesa compartilhada: a vez atravessa o tabuleiro e os aneis mudam de lado.
	if not vs_ai:
		_lado_local = 1 - _lado_local
		set_status(tr("TURN_PLAYER") % (_lado_local + 1))
		_update_ui()
		return

	is_player_turn = false
	set_status(tr("AI_TURN_SHORT"))
	_update_ui()
	await get_tree().create_timer(0.7).timeout
	_play_ai_turn()


## Aplica a semeadura e redesenha. Devolve `{extra, capturou}` -- quantas gemas
## a captura levou, para a cena ter o que dizer.
func _semear(cova: int, lado: int) -> Dictionary:
	var kalah := MancalaAI.KALAH_JOGADOR if lado == 0 else MancalaAI.KALAH_IA
	var plano := MancalaAI.achatar(pits)
	var antes: int = plano[kalah]
	var extra := MancalaAI.semear(plano, cova, lado)
	for i in range(14):
		pits[i] = plano[i]

	# Semeadura normal poe no maximo uma gema na propria Kalah; o que passar
	# disso veio de captura.
	var ganho: int = plano[kalah] - antes
	var capturou: int = ganho if ganho > 1 else 0

	_sync_gems_3d()
	_update_ui()
	return {"extra": extra, "capturou": capturou}

## Pensa fora da linha principal, durante a pausa de encenacao que ja existia.
func _play_ai_turn() -> void:
	var plano := MancalaAI.achatar(pits)
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(
		MancalaAI.pensar_em_tarefa.bind(plano, 1, ai_level, saida))
	# A arvore fica guardada antes do laco: quando o jogador sai da cena com a
	# busca em andamento, `get_tree()` passa a devolver `null` no quadro
	# seguinte, e `await null.process_frame` estoura. A tarefa nao segura
	# referencia para a cena, entao esperar por ela aqui e seguro.
	var arvore := get_tree()
	while not WorkerThreadPool.is_task_completed(tarefa):
		if arvore == null:
			break
		await arvore.process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)
	if not is_inside_tree() or game_over:
		return

	var cova: int = int(saida[0]) if not saida.is_empty() else -1
	if cova < 0:
		_check_game_over()
		return

	var ganhou := _semear(cova, 1)
	if ganhou["capturou"] > 0:
		set_status(tr("MANCALA_AI_CAPTURE") % ganhou["capturou"])

	if _check_game_over(): return

	if ganhou["extra"]:
		set_status(tr("MANCALA_AI_FREE_TURN"))
		await get_tree().create_timer(0.7).timeout
		_play_ai_turn()
		return
		
	is_player_turn = true
	set_status(tr("MANCALA_YOUR_TURN"))
	_update_ui()

func _check_game_over() -> bool:
	var player_empty: bool = true
	for i in range(6):
		if pits[i] > 0: player_empty = false; break
		
	var ai_empty: bool = true
	for i in range(7, 13):
		if pits[i] > 0: ai_empty = false; break
		
	if player_empty or ai_empty:
		# Coleta sementes restantes
		for i in range(6): pits[6] += pits[i]; pits[i] = 0
		for i in range(7, 13): pits[13] += pits[i]; pits[i] = 0
		_sync_gems_3d()
		_update_ui()
		
		if not vs_ai:
			# Os dois estao na mesma mesa: o cartao anuncia o lado, nao "voce".
			if pits[6] > pits[13]:
				finish_game(tr("PLAYER_WINS") % 1, true, {"mode": "versus"})
			elif pits[13] > pits[6]:
				finish_game(tr("PLAYER_WINS") % 2, false, {"mode": "versus"})
			else:
				finish_game(tr("RESULT_DRAW_SCORE") % [pits[6], pits[13]], false, {"draw": true, "mode": "versus"})
			return true
		if pits[6] > pits[13]:
			finish_game(tr("RESULT_YOU_WIN_SCORE") % [pits[6], pits[13]], true)
		elif pits[13] > pits[6]:
			finish_game(tr("RESULT_AI_WINS_SCORE") % [pits[13], pits[6]])
		else:
			finish_game(tr("RESULT_DRAW_SCORE") % [pits[6], pits[13]])
		return true
	return false
