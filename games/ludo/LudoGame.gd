extends BaseGame

## LudoGame: Ludo 3D com Tabuleiro em Cruz Colorido, Peões Esculpidos e Dado 3D Físico

const PLAYER_NAMES = ["LUDO_P_RED", "LUDO_P_BLUE", "LUDO_P_GREEN", "LUDO_P_YELLOW"]
const PLAYER_MAT_NAMES = ["plastic_red", "plastic_blue", "plastic_green", "plastic_yellow"]
const START_OFFSETS = [0, 7, 14, 21]

## Cor de cada base. O codigo pintava os quatro quadrantes de cinza enquanto o
## comentario dizia "Vermelho/Azul/Verde/Amarelo": sem cor, quem joga nao acha
## a propria base nem entende de onde os peoes saem.
const QUAD_COLORS := [
	Color(0.72, 0.18, 0.16),
	Color(0.16, 0.36, 0.72),
	Color(0.18, 0.56, 0.28),
	Color(0.86, 0.70, 0.14),
]
const TRACK_LENGTH = 28
const PAWNS_PER_PLAYER = 4

## Quantas vezes se rola o dado quando TODOS os peoes estao na base. E a regra
## oficial, e nao um favor: sair da base exige 6, entao com uma tirada so o
## jogador via "sem jogadas" em 5 de 6 rodadas de abertura e o tabuleiro nao se
## mexia -- que foi exatamente o defeito relatado.
const TENTATIVAS_NA_BASE = 3

var players_pawns = [
	[-1, -1, -1, -1], # Jogador
	[-1, -1, -1, -1], # IA Azul
	[-1, -1, -1, -1], # IA Verde
	[-1, -1, -1, -1]  # IA Amarelo
]

## Tiradas que ainda restam nesta vez, para a regra das tentativas na base.
var tentativas_restantes: int = 1

var current_turn: int = 0
var last_roll: int = 0
var can_roll: bool = true

## Degrau de 1 a 10 do DifficultyManager, o mesmo para as tres IAs.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var pawns_3d = [[], [], [], []]

## Anel na casa de destino de cada peao que pode andar, e o arrasto do peao
## ate la. Levantar o peao dizia QUAL pode andar; nada dizia para ONDE, e a
## unica maneira de escolher era uma tira de botoes "Peao 1".."Peao 4" no pe da
## tela -- um rotulo que nao aponta para peao nenhum do tabuleiro, e que obriga
## a olhar para baixo no meio da jogada. Os botoes sairam: escolhe-se o peao
## tocando NELE, ou no anel da casa de destino, ou arrastando um ate o outro.
## O anel e o mesmo do Board3D; o arrasto e o mesmo `DragPicker3D` das Damas e
## do Gamao.
var halos: CellHalo3D = null
var picker: DragPicker3D = null

## Os peoes do jogador que podem andar com a tirada corrente (vazio fora da
## escolha), e o que esta na mao.
var _movable_atual: Array = []
var _drag_idx: int = -1

## Altura do topo das casas da pista (disco de 0,03 em y=0,04): onde o anel pousa.
const ALTURA_DA_CASA := 0.055

@onready var board_root: Node3D = $BoardRoot
@onready var pawns_root: Node3D = $PawnsRoot
@onready var dice_3d: Dice3D = $Dice3D
@onready var btn_dice: Button = $UI/DiceArea/BtnDice
@onready var shell: GameShell = $GameShell

func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(_on_btn_restart_pressed)
	ai_level = DifficultyManager.get_level(game_id)
	_setup_3d_ludo_board()
	_setup_3d_pawns()
	halos = CellHalo3D.new()
	board_root.add_child(halos)
	halos.setup(PAWNS_PER_PLAYER, 0.30)
	_setup_picker()
	dice_3d.roll_finished.connect(_on_dice_roll_finished)
	# O tabuleiro tem 6,5 unidades; sem isto a camera usava as 6x6 padrao com a
	# area util errada e sobrava meia tela de feltro vazio.
	# Sem tema proprio a cena herda o `casino_green`, mesa de carteado, cujo teto de
	# inclinacao de camera e 56 graus para a face da carta nao achatar. Isto aqui e
	# tabuleiro: em retrato quem manda e a largura, a camera quer deitar mais para
	# aproveitar a altura que sobra, e batia nesse teto. Os outros temas herdam os
	# 74 graus do padrao.
	env_3d.apply_theme(GameTheme3D.bright_playroom())

	fit_table(Vector2(6.7, 6.7))
	_start_new_game()

func _setup_3d_ludo_board() -> void:
	for c in board_root.get_children(): c.queue_free()
	
	# Base de madeira nobre
	var base := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(6.5, 0.15, 6.5)
	base.mesh = box
	base.position = Vector3(0, -0.075, 0)
	base.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(base)
	
	# 4 Quadrantes coloridos das bases
	var quad_offsets = [
		Vector3(-1.8, 0.01, 1.8),   # Vermelho (Canto inf-esq)
		Vector3(-1.8, 0.01, -1.8),  # Azul (Canto sup-esq)
		Vector3(1.8, 0.01, -1.8),   # Verde (Canto sup-dir)
		Vector3(1.8, 0.01, 1.8)     # Amarelo (Canto inf-dir)
	]
	for p in range(4):
		var q_mesh := MeshInstance3D.new()
		var q_box := BoxMesh.new()
		q_box.size = Vector3(2.4, 0.02, 2.4)
		q_mesh.mesh = q_box
		# 0,01 acima da base nao basta: os dois planos brigam em z e o quadrante
		# sai com listras. Sobe para 0,03, que ja e o suficiente e continua
		# rente a mesa.
		q_mesh.position = quad_offsets[p] + Vector3(0.0, 0.02, 0.0)
		q_mesh.material_override = MaterialFactory3D.get_plastic(QUAD_COLORS[p], false)
		board_root.add_child(q_mesh)

	_desenhar_pista()


## As vinte e oito casas do percurso, mais as quatro retas finais.
##
## O traçado sempre existiu -- é um círculo de raio 2,4 que
## `_get_track_position_3d()` calcula --, mas nada dele era desenhado: quem
## olhava o tabuleiro via quatro quadrados coloridos e uma cruz de madeira, e
## não tinha como saber por onde o peão anda nem onde ele entra.
func _desenhar_pista() -> void:
	var casa := MeshBuilder3D.disc_token(0.30, 0.03)

	# A casa de largada de cada cor recebe a cor dela; o resto é marfim. É assim
	# que se vê de onde cada lado sai e para onde ele volta.
	var largadas: Dictionary = {}
	for p in range(4):
		largadas[int(START_OFFSETS[p]) % TRACK_LENGTH] = QUAD_COLORS[p]

	for i in range(TRACK_LENGTH):
		var ang := (float(i) / float(TRACK_LENGTH)) * TAU
		var no := MeshInstance3D.new()
		no.mesh = casa
		no.position = Vector3(cos(ang) * 2.4, 0.04, sin(ang) * 2.4)
		if largadas.has(i):
			no.material_override = MaterialFactory3D.get_plastic(largadas[i], true)
		else:
			no.material_override = MaterialFactory3D.get_ivory()
		board_root.add_child(no)

	# Retas finais: da borda até o centro, na cor de cada lado.
	for p in range(4):
		for passo in range(1, 5):
			var dist := float(32 - (28 + passo - 1)) * 0.45
			var pos := Vector3.ZERO
			match p:
				0: pos = Vector3(0.0, 0.04, dist)
				1: pos = Vector3(-dist, 0.04, 0.0)
				2: pos = Vector3(0.0, 0.04, -dist)
				3: pos = Vector3(dist, 0.04, 0.0)
			var no := MeshInstance3D.new()
			no.mesh = casa
			no.position = pos
			no.material_override = MaterialFactory3D.get_plastic(QUAD_COLORS[p], false)
			board_root.add_child(no)

	# A casa do meio, que é a chegada.
	var centro := MeshInstance3D.new()
	centro.mesh = MeshBuilder3D.disc_token(0.52, 0.04)
	centro.position = Vector3(0.0, 0.05, 0.0)
	centro.material_override = MaterialFactory3D.get_gold()
	board_root.add_child(centro)

func _setup_3d_pawns() -> void:
	for c in pawns_root.get_children(): c.queue_free()
	pawns_3d = [[], [], [], []]
	
	for p in range(4):
		for idx in range(PAWNS_PER_PLAYER):
			var pawn := preload("res://shared/3d/Token3D.tscn").instantiate()
			pawn.token_type = "pawn"
			pawn.material_name = PLAYER_MAT_NAMES[p]
			pawns_root.add_child(pawn)
			pawns_3d[p].append(pawn)

## Os alvos do toque, projetados da propria mesa: os quatro peoes do jogador
## onde estao, e a casa de destino de cada um que pode andar (`"dest_N"`).
## `PawnsRoot` e `BoardRoot` ficam na origem sem giro, entao a posicao local
## de um peao e a sua posicao no mundo.
func _setup_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, ALTURA_DA_CASA)
	picker.target_tapped.connect(_on_peao_tocado)
	picker.drag_started.connect(_on_peao_pego)
	picker.drag_moved.connect(_on_peao_movido)
	picker.drag_ended.connect(_on_peao_solto)
	_refresh_picker_targets()


func _refresh_picker_targets() -> void:
	if picker == null:
		return
	var alvos: Dictionary = {}
	for idx in range(PAWNS_PER_PLAYER):
		alvos[idx] = _get_track_position_3d(0, players_pawns[0][idx], idx)
	for idx in _movable_atual:
		alvos["dest_%d" % int(idx)] = _destino_do_peao(int(idx), last_roll)
	# O proprio dado rola quando e a vez de rolar: e o objeto da mesa que
	# corresponde ao gesto, e nao so a barra de 320 px no pe da tela.
	if can_roll and current_turn == 0 and not game_over:
		alvos["dado"] = dice_3d.position
	picker.set_targets(alvos)


## Onde o peao do jogador para com esta tirada: da base entra na casa 0, na
## pista anda o valor do dado.
func _destino_do_peao(idx: int, roll: int) -> Vector3:
	var pos: int = int(players_pawns[0][idx])
	var passo: int = 0 if pos == -1 else pos + roll
	return _get_track_position_3d(0, passo, idx)


## Tocou alguma coisa da mesa. Tres alvos valem: o peao levantado, o anel da
## casa onde ele pararia, e o dado quando e a vez de rolar.
func _on_peao_tocado(id: Variant) -> void:
	if id is int and int(id) in _movable_atual:
		_on_pawn_choice_selected(int(id), last_roll)
		return
	if id is String:
		var texto := str(id)
		if texto == "dado":
			_on_btn_dice_pressed()
		elif texto.begins_with("dest_"):
			var idx := int(texto.substr(5))
			if idx in _movable_atual:
				_on_pawn_choice_selected(idx, last_roll)


func _on_peao_pego(id: Variant) -> void:
	if id is String and str(id) == "dado":
		picker.cancel_drag()
		_on_btn_dice_pressed()
		return
	if not (id is int) or not (int(id) in _movable_atual):
		picker.cancel_drag()
		return
	_drag_idx = int(id)
	var pawn = pawns_3d[0][_drag_idx]
	if pawn and pawn.has_method("set_lift"):
		pawn.set_lift(Tokens3D.LIFT_DRAG)


func _on_peao_movido(_from: Variant, _over: Variant, world: Vector3) -> void:
	if _drag_idx < 0 or world == Vector3.INF:
		return
	var pawn: Node3D = pawns_3d[0][_drag_idx]
	pawn.position = Vector3(world.x, pawn.position.y, world.z)


func _on_peao_solto(_from: Variant, to: Variant) -> void:
	var idx: int = _drag_idx
	_drag_idx = -1
	if idx < 0:
		return
	if to is String and to == "dest_%d" % idx and idx in _movable_atual:
		_on_pawn_choice_selected(idx, last_roll)
		return
	# Soltou fora do destino: o peao volta para a casa, continua levantado e a
	# escolha fica de pe, para quem prefere o botao ou um toque.
	var pawn = pawns_3d[0][idx]
	pawn.jump_to(_get_track_position_3d(0, players_pawns[0][idx], idx), 0.3, 0.2)
	if pawn.has_method("set_lift"):
		pawn.set_lift(Tokens3D.LIFT_SELECTED)


func _get_track_position_3d(p: int, step_val: int, pawn_idx: int) -> Vector3:
	if step_val == -1: # Na base
		var base_centers = [
			Vector3(-1.8, 0.2, 1.8),
			Vector3(-1.8, 0.2, -1.8),
			Vector3(1.8, 0.2, -1.8),
			Vector3(1.8, 0.2, 1.8)
		]
		var col := pawn_idx % 2
		var lin := pawn_idx / 2
		var offset := Vector3(-0.42 + float(col) * 0.84, 0.0, -0.42 + float(lin) * 0.84)
		return base_centers[p] + offset
	elif step_val >= 32: # No centro (Vitória)
		var center_offsets = [
			Vector3(-0.34, 0.2, 0.34),
			Vector3(-0.34, 0.2, -0.34),
			Vector3(0.34, 0.2, -0.34),
			Vector3(0.34, 0.2, 0.34)
		]
		var leque := Vector3(float(pawn_idx % 2) * 0.20 - 0.10, float(pawn_idx) * 0.05,
			float(pawn_idx / 2) * 0.20 - 0.10)
		return center_offsets[p] + leque
	elif step_val >= 28: # Reta final até o centro
		var dist := (32 - step_val) * 0.45
		match p:
			0: return Vector3(0, 0.2, dist)
			1: return Vector3(-dist, 0.2, 0)
			2: return Vector3(0, 0.2, -dist)
			3: return Vector3(dist, 0.2, 0)
	else:
		# Pista externa (28 casas circulares)
		var abs_idx = (step_val + START_OFFSETS[p]) % TRACK_LENGTH
		var angle := (float(abs_idx) / float(TRACK_LENGTH)) * TAU
		var radius := 2.4
		return Vector3(cos(angle) * radius, 0.2, sin(angle) * radius)
	return Vector3.ZERO

func _start_new_game() -> void:
	game_over = false
	current_turn = 0
	last_roll = 0
	can_roll = true
	ai_level = DifficultyManager.get_level(game_id)
	btn_restart.hide()
	shell.timer.reset()
	shell.timer.start()
	
	players_pawns = [
		[-1, -1, -1, -1],
		[-1, -1, -1, -1],
		[-1, -1, -1, -1],
		[-1, -1, -1, -1]
	]
	tentativas_restantes = TENTATIVAS_NA_BASE
	_movable_atual = []
	_drag_idx = -1
	if halos:
		halos.clear()
	
	dice_3d.position = Vector3(0, 0.35, 0)
	dice_3d.set_value_immediate(6)
	btn_dice.text = tr("LUDO_BTN_ROLL")
	btn_dice.disabled = false
	set_status(tr("LUDO_YOUR_TURN"))
	_sync_pawns_positions(true)
	_refresh_picker_targets()

## Peoes que chegaram ao centro, o unico placar que o Ludo tem -- e o unico
## jogo da casa que nao mostrava numero nenhum na tela ate agora. Sao quatro
## cores, mas a barra tem dois lados: do outro vai a cor da IA que esta na
## frente, que e com quem o jogador esta perdendo ou ganhando.
func _pintar_placar() -> void:
	var em_casa := func(p: int) -> int:
		var n := 0
		for idx in range(PAWNS_PER_PLAYER):
			if players_pawns[p][idx] >= 32:
				n += 1
		return n
	var melhor_ia := 0
	for p in range(1, 4):
		melhor_ia = maxi(melhor_ia, em_casa.call(p))
	set_duel_score("%d/%d" % [em_casa.call(0), PAWNS_PER_PLAYER],
		"%d/%d" % [melhor_ia, PAWNS_PER_PLAYER])
	
	var time_str := "%02d:%02d" % [shell.timer.get_time() / 60, shell.timer.get_time() % 60]
	shell.set_level(DifficultyManager.label_for(game_id) + "  •  " + time_str)

func _sync_pawns_positions(immediate: bool = false) -> void:
	_pintar_placar()
	for p in range(4):
		for idx in range(PAWNS_PER_PLAYER):
			var step_val = players_pawns[p][idx]
			var target_pos := _get_track_position_3d(p, step_val, idx)
			var pawn = pawns_3d[p][idx]
			if immediate:
				pawn.position = target_pos
			else:
				pawn.jump_to(target_pos, 0.4, 0.3)
	_refresh_picker_targets()

func _on_btn_dice_pressed() -> void:
	if not can_roll or game_over or current_turn != 0: return
	can_roll = false
	btn_dice.disabled = true
	_refresh_picker_targets()
	
	var rolled := randi_range(1, 6)
	set_status(tr("LUDO_ROLLING"))
	dice_3d.roll(rolled, 0.75)

func _on_dice_roll_finished(val: int) -> void:
	last_roll = val
	btn_dice.text = tr("LUDO_DICE_VALUE") % last_roll
	
	if current_turn == 0:
		_handle_player_roll(last_roll)
	else:
		_handle_ai_roll(last_roll)

## Peoes do jogador que podem andar com este dado. Base so sai no 6, e o peao
## que ja anda nao pode passar da casa 32.
func _movable_pawns(p: int, roll: int) -> Array:
	var movable: Array = []
	for idx in range(PAWNS_PER_PLAYER):
		var pos = players_pawns[p][idx]
		if pos == -1 and roll == 6: movable.append(idx)
		elif pos >= 0 and pos + roll <= 32: movable.append(idx)
	return movable


## Verdadeiro quando os quatro peoes do lado ainda estao na base -- e so nesse
## caso a regra das tres tiradas vale.
func _todos_na_base(p: int) -> bool:
	for idx in range(PAWNS_PER_PLAYER):
		if players_pawns[p][idx] != -1:
			return false
	return true


func _handle_player_roll(roll: int) -> void:
	last_roll = roll
	var movable: Array = _movable_pawns(0, roll)

	if movable.is_empty():
		# Tudo na base e o dado nao deu 6: a regra oficial da mais uma tirada,
		# ate tres. Sem isto a abertura travava rodada apos rodada sem que nada
		# se mexesse na tela.
		tentativas_restantes -= 1
		if _todos_na_base(0) and tentativas_restantes > 0:
			set_status(tr("LUDO_TRY_AGAIN") % [roll, tentativas_restantes])
			can_roll = true
			btn_dice.disabled = false
			_refresh_picker_targets()
			return
		set_status(tr("NO_MOVES_WITH") % roll)
		await get_tree().create_timer(0.9).timeout
		_next_turn()
	elif movable.size() == 1:
		_move_player_pawn(movable[0], roll)
	else:
		set_status(tr("LUDO_PICK_PAWN"))
		# Quem pode andar levanta e acende o anel na casa de destino: e o
		# tabuleiro que faz a pergunta, e a resposta e um toque nele.
		_levantar_peoes(movable)

## Levanta os peoes do jogador que podem andar e baixa o resto; acende o anel
## na casa onde cada um deles pararia, e poe essas casas entre os alvos do
## arrasto.
func _levantar_peoes(indices: Array) -> void:
	_movable_atual = indices.duplicate()
	for idx in range(PAWNS_PER_PLAYER):
		var pawn = pawns_3d[0][idx]
		if pawn and pawn.has_method("set_lift"):
			pawn.set_lift(Tokens3D.LIFT_SELECTED if idx in indices else 0.0)
		if halos == null:
			continue
		if idx in indices:
			var casa := _destino_do_peao(idx, last_roll)
			halos.move_target(idx, Vector3(casa.x, ALTURA_DA_CASA, casa.z))
			halos.light(idx, Tokens3D.COLOR_VALID)
		else:
			halos.light(idx, Color.TRANSPARENT)
	_refresh_picker_targets()

func _on_pawn_choice_selected(pawn_idx: int, roll: int) -> void:
	_levantar_peoes([])
	_move_player_pawn(pawn_idx, roll)

func _move_player_pawn(idx: int, roll: int) -> void:
	var pos = players_pawns[0][idx]
	if pos == -1: players_pawns[0][idx] = 0
	else: players_pawns[0][idx] += roll
	
	_sync_pawns_positions()
	if AudioManager:
		AudioManager.play_piece_place()
	_check_captures(0, idx)
	
	if _check_win(0): return
	
	if roll == 6:
		set_status(tr("LUDO_ROLLED_SIX"))
		can_roll = true
		btn_dice.disabled = false
		_refresh_picker_targets()
	else:
		_next_turn()

func _next_turn() -> void:
	current_turn = (current_turn + 1) % 4
	if current_turn == 0:
		set_status(tr("LUDO_YOUR_TURN"))
		tentativas_restantes = TENTATIVAS_NA_BASE
		can_roll = true
		btn_dice.disabled = false
		_refresh_picker_targets()
	else:
		set_status(tr("LUDO_TURN_OF") % tr(PLAYER_NAMES[current_turn]))
		can_roll = false
		btn_dice.disabled = true
		await get_tree().create_timer(0.6).timeout
		var ai_roll := randi_range(1, 6)
		dice_3d.roll(ai_roll, 0.6)

func _handle_ai_roll(roll: int) -> void:
	var p := current_turn
	var chosen := LudoAI.choose_pawn(players_pawns, p, roll, START_OFFSETS, ai_level)

	if chosen >= 0:
		if players_pawns[p][chosen] == -1: players_pawns[p][chosen] = 0
		else: players_pawns[p][chosen] += roll
		_sync_pawns_positions()
		_check_captures(p, chosen)
		
	if _check_win(p): return
	
	if roll == 6:
		set_status(tr("LUDO_ROLLED_SIX_AGAIN") % tr(PLAYER_NAMES[p]))
		await get_tree().create_timer(0.6).timeout
		var ai_roll := randi_range(1, 6)
		dice_3d.roll(ai_roll, 0.6)
	else:
		_next_turn()

func _check_captures(active_p: int, active_idx: int) -> void:
	var active_pos = players_pawns[active_p][active_idx]
	if active_pos < 0 or active_pos >= 28: return
	
	var active_abs = (active_pos + START_OFFSETS[active_p]) % TRACK_LENGTH
	
	for other_p in range(4):
		if other_p == active_p: continue
		for other_idx in range(PAWNS_PER_PLAYER):
			var other_pos = players_pawns[other_p][other_idx]
			if other_pos >= 0 and other_pos < 28:
				var other_abs = (other_pos + START_OFFSETS[other_p]) % TRACK_LENGTH
				if active_abs == other_abs:
					# Captura! Peão adversário volta para a base
					players_pawns[other_p][other_idx] = -1
					set_status(tr("LUDO_CAPTURED"))
					if AudioManager:
						AudioManager.play_capture()
					_sync_pawns_positions()

func _check_win(p: int) -> bool:
	var all_finished: bool = true
	for idx in range(PAWNS_PER_PLAYER):
		if players_pawns[p][idx] < 32:
			all_finished = false
			break
	if all_finished:
		shell.timer.stop()
		if p == 0:
			finish_game(tr("LUDO_WIN"), true, {"time": shell.timer.get_time(), "xp": 100})
		else:
			finish_game(tr("LUDO_LOSE") % tr(PLAYER_NAMES[p]))
		return true
	return false
