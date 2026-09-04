extends BaseGame

## MancalaGame: Mancala 3D com Tabuleiro Esculpido em Madeira Nobre e Gemas Preciosas

var pits: Array = []
var is_player_turn: bool = true
var gems_3d: Dictionary = {}

## Degrau de 1 a 10 do DifficultyManager. Vira orcamento de busca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

@onready var board_root: Node3D = $BoardRoot
@onready var gems_root: Node3D = $GemsRoot
@onready var player_pits_container: HBoxContainer = $UI/CenterContainer/VBox/PlayerRow
@onready var shell: GameShell = $UI/GameShell

const PIT_POSITIONS_3D = {
	# Jogador (0 a 5): De -2.0 a +2.0 em X, Z = 0.6
	0: Vector3(-1.9, 0.08, 0.6),
	1: Vector3(-1.14, 0.08, 0.6),
	2: Vector3(-0.38, 0.08, 0.6),
	3: Vector3(0.38, 0.08, 0.6),
	4: Vector3(1.14, 0.08, 0.6),
	5: Vector3(1.9, 0.08, 0.6),
	# Kalah Jogador (6): Direita, Z = 0.0
	6: Vector3(2.8, 0.08, 0.0),
	# IA (7 a 12): Direita para Esquerda, Z = -0.6
	7: Vector3(1.9, 0.08, -0.6),
	8: Vector3(1.14, 0.08, -0.6),
	9: Vector3(0.38, 0.08, -0.6),
	10: Vector3(-0.38, 0.08, -0.6),
	11: Vector3(-1.14, 0.08, -0.6),
	12: Vector3(-1.9, 0.08, -0.6),
	# Kalah IA (13): Esquerda, Z = 0.0
	13: Vector3(-2.8, 0.08, 0.0)
}

const GEM_MATERIALS = ["ruby", "sapphire", "emerald", "amber", "gold"]

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
	_setup_ui_buttons()
	# Sem tema proprio a cena herda o `casino_green`, mesa de carteado, cujo teto de
	# inclinacao de camera e 56 graus para a face da carta nao achatar. Isto aqui e
	# tabuleiro: em retrato quem manda e a largura, a camera quer deitar mais para
	# aproveitar a altura que sobra, e batia nesse teto. Os outros temas herdam os
	# 74 graus do padrao.
	env_3d.apply_theme(GameTheme3D.desert_gold())

	fit_table(Vector2(6.8, 2.4))
	_start_new_game()

func _setup_3d_mancala_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	
	# Base de madeira entalhada
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.6, 0.22, 2.2)
	base.mesh = box
	base.position = Vector3(0, -0.11, 0)
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

func _setup_ui_buttons() -> void:
	for c in player_pits_container.get_children(): c.queue_free()
	for i in range(6):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(UIKit.TOQUE_MIN, UIKit.TOQUE_MIN)
		btn.pressed.connect(_on_player_pit_clicked.bind(i))
		player_pits_container.add_child(btn)

func _start_new_game() -> void:
	game_over = false
	is_player_turn = true
	btn_restart.hide()
	
	ai_level = DifficultyManager.get_level(game_id)
	pits.clear()
	for i in range(14):
		pits.append(0 if (i == 6 or i == 13) else 4)
		
	set_status(tr("MANCALA_YOUR_TURN_LONG"))
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
	set_duel_score(pits[6], pits[13])
	shell.set_level(DifficultyManager.label_for(game_id))

	for i in range(6):
		var btn := player_pits_container.get_child(i) as Button
		var count: int = pits[i]
		btn.text = "%d" % count
		btn.disabled = not is_player_turn or count == 0 or game_over

## Semeia a cova do jogador. A regra e a mesma que a busca da IA usa: semear,
## pular a Kalah do adversario, turno extra e captura moram todos em
## `MancalaAI.semear()`. Enquanto a cena tinha a propria copia -- uma para cada
## lado, alias -- nada garantia que a IA estivesse buscando sobre o jogo que a
## cena de fato jogava.
func _on_player_pit_clicked(pit_idx: int) -> void:
	if game_over or not is_player_turn or pits[pit_idx] == 0: return

	var ganhou := _semear(pit_idx, 0)
	if ganhou["capturou"] > 0:
		set_status(tr("MANCALA_YOU_CAPTURE") % ganhou["capturou"])

	if _check_game_over(): return

	if ganhou["extra"]:
		set_status(tr("MANCALA_FREE_TURN"))
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
		
		if pits[6] > pits[13]:
			finish_game(tr("RESULT_YOU_WIN_SCORE") % [pits[6], pits[13]], true)
		elif pits[13] > pits[6]:
			finish_game(tr("RESULT_AI_WINS_SCORE") % [pits[13], pits[6]])
		else:
			finish_game(tr("RESULT_DRAW_SCORE") % [pits[6], pits[13]])
		return true
	return false
