class_name NimGame
extends BaseGame

## NimGame: Jogo Matemático de Nim 3D (Normal e Misère Marienbad).
##
## Apresenta tabuleiro nobre em nogueira e mogno, canaletas aveludadas para
## as pilhas, fichas chanfradas com gemas lapidadas em PBR, animações fluidas
## de elevação e voo em arco até a cesta de descarte, IA adaptativa com
## Teorema de Bouton e integração completa com gamificação.

const Rules = preload("res://games/nim/NimRules.gd")

const TOKEN_RADIUS: float = 0.30
const TOKEN_HEIGHT: float = 0.12
const TOKEN_SPACING: float = 0.28
const LIFT_Y: float = 0.85
const DISCARD_POS: Vector3 = Vector3(3.2, 0.15, 0.0)

# Estado do Jogo
var preset_name: String = "classic_3"
var is_misere: bool = true
var is_vs_ai: bool = true
## Degrau de 1 a 10 do DifficultyManager, o mesmo dos outros jogos.
##
## Antes eram tres botoes -- Facil, Medio, Mestre -- num campo proprio que
## nascia sempre em "Mestre" e sumia ao fechar a cena, enquanto a escada do
## jogo andava em paralelo mexendo so no XP.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var current_turn: int = 1 # 1: Jogador 1 (ou Humano), 2: Jogador 2 (ou IA)
var heaps: Array[int] = []
var selected_heap: int = -1
var selected_take_count: int = 1
var is_animating: bool = false
var move_history: Array[Dictionary] = [] # [{heap, take, player}]
var turn_count: int = 0

# Estruturas 3D
var heap_roots: Array[Node3D] = []
var piece_nodes: Array[Array] = [] # Array de Array[Node3D] para cada pilha
var heap_halos: Array[MeshInstance3D] = []
var discard_tray: Node3D = null

## Carimbo da partida corrente. Todo callback agendado por timer guarda o valor
## que leu e desiste se ele mudou -- e o que impede a jogada da IA de cair sobre
## o tabuleiro de outra partida.
var _geracao: int = 0

## Pecas ainda voando para a cesta. Precisa ser campo do no: o `tween_callback`
## e uma lambda, e lambda em GDScript captura variavel local POR VALOR -- cada
## copia contava 1 e o total nunca era atingido com duas pecas ou mais.
var _tweens_pendentes: int = 0

# Referências de Nós UI

@onready var heap_buttons_container: HBoxContainer = $UI/HeapControls/HeapButtons
@onready var take_controls_container: HBoxContainer = $UI/TakeControls
@onready var take_label: Label = $UI/TakeControls/TakeLabel
@onready var btn_take_1: Button = $UI/TakeControls/BtnTake1
@onready var btn_take_2: Button = $UI/TakeControls/BtnTake2
@onready var btn_take_3: Button = $UI/TakeControls/BtnTake3
@onready var btn_take_all: Button = $UI/TakeControls/BtnTakeAll
@onready var btn_confirm_move: Button = $UI/TakeControls/BtnConfirm

@onready var btn_undo: Button = $UI/Actions/BtnUndo
@onready var btn_hint: Button = $UI/Actions/BtnHint
@onready var btn_mode_toggle: Button = $UI/Actions/BtnModeToggle
@onready var btn_rule_toggle: Button = $UI/Actions/BtnRuleToggle
@onready var preset_buttons_container: HBoxContainer = $UI/Presets/PresetButtons
@onready var diff_buttons_container: HBoxContainer = $UI/DiffContainer/DiffButtons
@onready var shell: GameShell = $UI/GameShell
@onready var btn_restart_actions: Button = $UI/Actions/BtnRestart



func _ready() -> void:
	env_3d = get_node_or_null("TabletopEnvironment3D") as TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	menu_scene_path = BaseGame.MENU_TABULEIRO
	shell.restart_requested.connect(_on_btn_rematch_pressed)
	
	_setup_ui_events()
	_setup_3d_tabletop()
	# Sem tema proprio a cena herda o `casino_green`, mesa de carteado, cujo teto de
	# inclinacao de camera e 56 graus para a face da carta nao achatar. Isto aqui e
	# tabuleiro: em retrato quem manda e a largura, a camera quer deitar mais para
	# aproveitar a altura que sobra, e batia nesse teto. Os outros temas herdam os
	# 74 graus do padrao.
	env_3d.apply_theme(GameTheme3D.parlour_walnut())

	fit_table(Vector2(7.3, 4.9))
	_start_new_game()




# ---------------------------------------------------------------------------
# Configuração e Ciclo de Partida
# ---------------------------------------------------------------------------

func _setup_ui_events() -> void:
	btn_confirm_move.pressed.connect(_on_btn_confirm_move_pressed)
	btn_undo.pressed.connect(_on_btn_undo_pressed)
	btn_hint.pressed.connect(_on_btn_hint_pressed)
	btn_mode_toggle.pressed.connect(_on_btn_mode_toggle_pressed)
	btn_rule_toggle.pressed.connect(_on_btn_rule_toggle_pressed)

	# O botao de reiniciar da barra de acoes nao tinha ligacao nenhuma, nem aqui
	# nem no .tscn: era um alvo de 88 px que nao fazia nada.
	btn_restart_actions.pressed.connect(_on_btn_rematch_pressed)

	# Botões de retirada rápida
	btn_take_1.pressed.connect(func(): _set_take_count(1))
	btn_take_2.pressed.connect(func(): _set_take_count(2))
	btn_take_3.pressed.connect(func(): _set_take_count(3))
	btn_take_all.pressed.connect(func():
		if selected_heap >= 0 and selected_heap < heaps.size():
			_set_take_count(heaps[selected_heap])
	)
	
	# Presets
	var preset_keys := ["simple_3", "classic_3", "pyramid_4", "wide_5"]
	var preset_names := ["NIM_PRESET_SIMPLE", "NIM_PRESET_CLASSIC", "NIM_PRESET_PYRAMID", "NIM_PRESET_WIDE"]
	for i in range(preset_keys.size()):
		var p_key: String = preset_keys[i]
		var btn := Button.new()
		btn.text = tr(preset_names[i])
		# A chave fica no nó: o realce comparava as três primeiras letras do texto
		# com as do id ("cla" contra "Clássico"), e já errava dois dos quatro
		# presets em português. Com o nome traduzido erraria em todo idioma.
		btn.set_meta("preset", p_key)
		btn.custom_minimum_size = Vector2(100, UIKit.TOQUE_MIN)
		UIKit.rolavel(btn)
		btn.pressed.connect(func(): _on_preset_selected(p_key))
		preset_buttons_container.add_child(btn)
		
	# Dificuldades: uma parada por faixa da escada do DifficultyManager.
	for degrau in DEGRAUS_DO_BOTAO:
		var d: int = degrau
		var btn := Button.new()
		btn.text = tr(DifficultyManager.tier_name(d))
		btn.custom_minimum_size = Vector2(78, UIKit.TOQUE_MIN)
		UIKit.rolavel(btn)
		btn.pressed.connect(func(): _on_difficulty_selected(d))
		diff_buttons_container.add_child(btn)


func _setup_3d_tabletop() -> void:
	# Criação da base e bandeja de recolhimento
	var board_root: Node3D = $TabletopEnvironment3D/BoardRoot
	for c in board_root.get_children():
		c.queue_free()
		
	# Base de madeira nogueira com friso em mogno
	var board_slab := MeshInstance3D.new()
	var mesh: ArrayMesh = MeshBuilder3D.board_slab(6.8, 4.4, 0.22)
	board_slab.mesh = mesh
	board_slab.position = Vector3(0.0, -0.11, 0.0)
	board_slab.material_override = MaterialFactory3D.get_wood_walnut()
	board_root.add_child(board_slab)
	
	# Borda exterior em mogno nobre
	var rim := MeshInstance3D.new()
	var rim_box := BoxMesh.new()
	rim_box.size = Vector3(7.1, 0.12, 4.7)
	rim.mesh = rim_box
	rim.position = Vector3(0.0, -0.16, 0.0)
	rim.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(rim)
	
	# Cesta de Descarte lateral em latão escovado
	discard_tray = Node3D.new()
	discard_tray.name = "DiscardTray"
	discard_tray.position = DISCARD_POS
	
	var tray_mesh := MeshInstance3D.new()
	var tray_cyl := CylinderMesh.new()
	tray_cyl.top_radius = 0.75
	tray_cyl.bottom_radius = 0.65
	tray_cyl.height = 0.24
	tray_cyl.radial_segments = 32
	tray_mesh.mesh = tray_cyl
	tray_mesh.position = Vector3(0.0, 0.12, 0.0)
	tray_mesh.material_override = MaterialFactory3D.get_gold()
	discard_tray.add_child(tray_mesh)
	
	var tray_inside := MeshInstance3D.new()
	var tray_inside_cyl := CylinderMesh.new()
	tray_inside_cyl.top_radius = 0.68
	tray_inside_cyl.bottom_radius = 0.60
	tray_inside_cyl.height = 0.24
	tray_inside_cyl.radial_segments = 32
	tray_inside.mesh = tray_inside_cyl
	tray_inside.position = Vector3(0.0, 0.13, 0.0)
	tray_inside.material_override = MaterialFactory3D.get_felt_casino(Color(0.32, 0.05, 0.08))
	discard_tray.add_child(tray_inside)
	
	board_root.add_child(discard_tray)


func _start_new_game() -> void:
	game_over = false
	current_turn = Rules.PLAYER_HUMAN
	ai_level = DifficultyManager.get_level(game_id)
	heaps = Rules.create_heaps(preset_name)
	move_history.clear()
	turn_count = 0
	is_animating = false
	selected_heap = -1
	selected_take_count = 1

	# Toda partida nova invalida os callbacks com timer da anterior: a IA agenda
	# a jogada dela para 0,45 s adiante, e nesse intervalo o jogador pode trocar
	# o preset. Sem esta marca, o callback antigo indexava `heap_roots` com o
	# indice de um tabuleiro que ja nao existe.
	_geracao += 1

	shell.timer.reset()
	shell.timer.start()

	if btn_restart:
		btn_restart.hide()
	
	_build_3d_heaps_and_tokens()
	_rebuild_heap_ui_buttons()
	_update_hud_stats()
	_highlight_active_settings_buttons()
	
	if is_misere:
		set_status(tr("NIM_TURN_MISERE"))
	else:
		set_status(tr("NIM_TURN_NORMAL"))
		
	var bus := _get_event_bus()
	if bus:
		bus.emit_game_started("nim")
		if bus.has_signal("match_started"):
			bus.match_started.emit("nim", "%s_%s" % [preset_name, "misere" if is_misere else "normal"])


# ---------------------------------------------------------------------------
# Construção 3D dos Tokens e Canaletas
# ---------------------------------------------------------------------------

func _build_3d_heaps_and_tokens() -> void:
	var heaps_parent: Node3D = $TabletopEnvironment3D/BoardRoot/HeapsParent
	if not heaps_parent:
		heaps_parent = Node3D.new()
		heaps_parent.name = "HeapsParent"
		$TabletopEnvironment3D/BoardRoot.add_child(heaps_parent)
		
	for c in heaps_parent.get_children():
		c.queue_free()
		
	heap_roots.clear()
	piece_nodes.clear()
	heap_halos.clear()
	
	var num_heaps: int = heaps.size()
	var total_span_x: float = float(num_heaps - 1) * 1.35
	var start_x: float = -total_span_x * 0.5 - 0.35 # leve deslocamento para a esquerda da cesta
	
	for h in range(num_heaps):
		var h_count: int = heaps[h]
		var heap_node := Node3D.new()
		heap_node.name = "Heap_%d" % h
		var heap_x: float = start_x + float(h) * 1.35
		heap_node.position = Vector3(heap_x, 0.0, 0.0)
		heaps_parent.add_child(heap_node)
		heap_roots.append(heap_node)
		
		# Canaleta aveludada esculpida na mesa
		var channel := MeshInstance3D.new()
		var max_pieces: int = maxi(h_count, 7)
		var channel_length: float = float(max_pieces) * TOKEN_SPACING + 0.4
		var channel_box := BoxMesh.new()
		channel_box.size = Vector3(0.72, 0.015, channel_length)
		channel.mesh = channel_box
		channel.position = Vector3(0.0, 0.008, 0.0)
		channel.material_override = MaterialFactory3D.get_felt_casino(Color(0.32, 0.05, 0.08))
		heap_node.add_child(channel)
		
		# Halo de seleção ao redor da pilha
		var halo := MeshInstance3D.new()
		var halo_box := BoxMesh.new()
		halo_box.size = Vector3(0.80, 0.02, channel_length + 0.1)
		halo.mesh = halo_box
		halo.position = Vector3(0.0, 0.009, 0.0)
		halo.material_override = MaterialFactory3D.get_state_overlay(Color(1.0, 0.85, 0.2, 0.6), 0.8)
		halo.visible = false
		heap_node.add_child(halo)
		heap_halos.append(halo)
		
		# Cria as peças 3D da pilha
		var current_heap_pieces: Array[Node3D] = []
		for p in range(h_count):
			var piece := _create_piece_node(h, p, h_count)
			var z_pos := _get_piece_z_pos(p, h_count)
			piece.position = Vector3(0.0, TOKEN_HEIGHT * 0.5, z_pos)
			heap_node.add_child(piece)
			current_heap_pieces.append(piece)
			
		piece_nodes.append(current_heap_pieces)


func _create_piece_node(heap_idx: int, piece_idx: int, _total_in_heap: int) -> Node3D:
	var piece_root := Node3D.new()
	piece_root.name = "Piece_%d_%d" % [heap_idx, piece_idx]
	
	# Malha chanfrada de disco de moeda / gema
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = MeshBuilder3D.disc_token(TOKEN_RADIUS, TOKEN_HEIGHT)
	mesh_inst.material_override = _get_heap_material(heap_idx)
	piece_root.add_child(mesh_inst)
	
	# Anel dourado externo
	var rim := MeshInstance3D.new()
	var rim_cyl := CylinderMesh.new()
	rim_cyl.top_radius = TOKEN_RADIUS * 0.95
	rim_cyl.bottom_radius = TOKEN_RADIUS * 0.95
	rim_cyl.height = TOKEN_HEIGHT + 0.005
	rim_cyl.radial_segments = 24
	rim.mesh = rim_cyl
	rim.material_override = MaterialFactory3D.get_gold()
	piece_root.add_child(rim)
	
	# Sombra de contato
	var shadow := MeshInstance3D.new()
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2(TOKEN_RADIUS * 2.2, TOKEN_RADIUS * 2.2)
	shadow.mesh = shadow_plane
	shadow.position = Vector3(0.0, -TOKEN_HEIGHT * 0.48, 0.0)
	shadow.material_override = MaterialFactory3D.get_contact_shadow()
	piece_root.add_child(shadow)
	
	return piece_root


func _get_piece_z_pos(p_idx: int, total_in_heap: int) -> float:
	var start_z: float = -float(total_in_heap - 1) * TOKEN_SPACING * 0.5
	return start_z + float(p_idx) * TOKEN_SPACING


func _get_heap_material(heap_idx: int) -> StandardMaterial3D:
	match heap_idx % 5:
		0: return MaterialFactory3D.get_gemstone(Color(0.92, 0.18, 0.24)) # Rubi Carmesim
		1: return MaterialFactory3D.get_gemstone(Color(0.15, 0.85, 0.40)) # Esmeralda Nobre
		2: return MaterialFactory3D.get_gemstone(Color(0.18, 0.45, 0.96)) # Safira Azul
		3: return MaterialFactory3D.get_gemstone(Color(0.98, 0.65, 0.12)) # Âmbar Dourado
		4: return MaterialFactory3D.get_gemstone(Color(0.75, 0.25, 0.95)) # Ametista Imperial
		_: return MaterialFactory3D.get_gold()


# ---------------------------------------------------------------------------
# Interface do Usuário e Seleção de Jogadas
# ---------------------------------------------------------------------------

func _rebuild_heap_ui_buttons() -> void:
	for c in heap_buttons_container.get_children():
		c.queue_free()
		
	for h in range(heaps.size()):
		var heap_idx: int = h
		var count: int = heaps[h]
		var btn := Button.new()
		btn.name = "BtnHeap_%d" % h
		btn.text = tr("NIM_HEAP_COUNT") % [65 + h, count]
		btn.custom_minimum_size = Vector2(110, UIKit.TOQUE_MIN)
		btn.disabled = (count <= 0)
		UIKit.rolavel(btn)
		btn.pressed.connect(func(): _on_heap_selected(heap_idx))
		heap_buttons_container.add_child(btn)
		
	take_controls_container.visible = (selected_heap != -1)


func _on_heap_selected(heap_idx: int) -> void:
	if is_animating or game_over:
		return
	if is_vs_ai and current_turn == Rules.PLAYER_AI:
		return
	if heap_idx < 0 or heap_idx >= heaps.size() or heaps[heap_idx] <= 0:
		return
		
	play_click()
	
	# Se já estava selecionado, desce as peças antes de trocar
	if selected_heap != -1 and selected_heap != heap_idx:
		_lower_pieces_in_heap(selected_heap)
		
	selected_heap = heap_idx
	var max_available: int = heaps[heap_idx]
	selected_take_count = clampi(selected_take_count, 1, max_available)
	
	_update_take_buttons_state()
	_lift_selected_pieces()
	_update_heap_halos()
	
	take_controls_container.visible = true
	set_status(tr("NIM_HEAP_PICKED") % (65 + heap_idx))


func _set_take_count(count: int) -> void:
	if selected_heap == -1 or is_animating or game_over:
		return
	var max_available: int = heaps[selected_heap]
	selected_take_count = clampi(count, 1, max_available)
	play_click()
	_update_take_buttons_state()
	_lift_selected_pieces()


func _update_take_buttons_state() -> void:
	if selected_heap == -1 or selected_heap >= heaps.size():
		take_controls_container.visible = false
		return
		
	var available: int = heaps[selected_heap]
	take_label.text = tr("NIM_TAKE_COUNT") % selected_take_count
	
	btn_take_1.disabled = (available < 1)
	btn_take_2.disabled = (available < 2)
	btn_take_3.disabled = (available < 3)
	btn_take_all.text = tr("NIM_TAKE_ALL") % available
	
	# Destaca o botão da quantidade selecionada
	btn_take_1.modulate = Color(1.2, 1.2, 1.2) if selected_take_count == 1 else Color(0.8, 0.8, 0.8)
	btn_take_2.modulate = Color(1.2, 1.2, 1.2) if selected_take_count == 2 else Color(0.8, 0.8, 0.8)
	btn_take_3.modulate = Color(1.2, 1.2, 1.2) if selected_take_count == 3 else Color(0.8, 0.8, 0.8)
	btn_take_all.modulate = Color(1.2, 1.2, 1.2) if selected_take_count == available and selected_take_count > 3 else Color(0.8, 0.8, 0.8)


func _lift_selected_pieces() -> void:
	if selected_heap < 0 or selected_heap >= piece_nodes.size():
		return
		
	var pieces: Array = piece_nodes[selected_heap]
	var total: int = pieces.size()
	
	for i in range(total):
		var piece: Node3D = pieces[i]
		var is_picked: bool = (i >= total - selected_take_count)
		var target_y: float = LIFT_Y if is_picked else TOKEN_HEIGHT * 0.5
		
		var tw := create_tween().set_parallel(true)
		tw.tween_property(piece, "position:y", target_y, 0.18)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		if is_picked:
			tw.tween_property(piece, "rotation_degrees:y", piece.rotation_degrees.y + 15.0, 0.18)


func _lower_pieces_in_heap(heap_idx: int) -> void:
	if heap_idx < 0 or heap_idx >= piece_nodes.size():
		return
	var pieces: Array = piece_nodes[heap_idx]
	for piece: Node3D in pieces:
		var tw := create_tween()
		tw.tween_property(piece, "position:y", TOKEN_HEIGHT * 0.5, 0.16)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _update_heap_halos() -> void:
	for h in range(heap_halos.size()):
		heap_halos[h].visible = (h == selected_heap)


# ---------------------------------------------------------------------------
# Execução de Movimento e Animações em Arco
# ---------------------------------------------------------------------------

func _on_btn_confirm_move_pressed() -> void:
	if is_animating or game_over or selected_heap == -1:
		return
	if is_vs_ai and current_turn == Rules.PLAYER_AI:
		return
		
	if not Rules.is_valid_move(heaps, selected_heap, selected_take_count):
		_play_error_buzz()
		return
		
	play_click()
	_execute_move_animated(selected_heap, selected_take_count, current_turn)


func _execute_move_animated(heap_idx: int, take_count: int, player: int) -> void:
	# A jogada da IA chega por timer: entre o agendamento e aqui o jogador pode
	# ter trocado o preset, e a pilha de indice `heap_idx` pode nao existir mais.
	if heap_idx < 0 or heap_idx >= piece_nodes.size():
		return

	is_animating = true
	var pieces_array: Array = piece_nodes[heap_idx]

	# Salva no histórico
	move_history.append({"heap": heap_idx, "take": take_count, "player": player})
	Rules.apply_move_inplace(heaps, heap_idx, take_count)
	turn_count += 1
	
	# Seleciona as peças do topo para remoção
	var moving_pieces: Array[Node3D] = []
	for i in range(take_count):
		if not pieces_array.is_empty():
			moving_pieces.append(pieces_array.pop_back())
			
	take_controls_container.visible = false
	selected_heap = -1
	_update_heap_halos()
	_update_hud_stats()
	
	# Animação em arco para a cesta de descarte
	var total_tweens: int = moving_pieces.size()
	_tweens_pendentes = total_tweens

	# Pilha vazia nao gera tween nenhum, e sem este atalho `is_animating` ficaria
	# ligado para sempre pelo mesmo caminho da contagem que nunca fecha.
	if total_tweens == 0:
		_on_move_animation_finished(player)
		return

	_play_place_sound()

	for idx in range(total_tweens):
		var piece: Node3D = moving_pieces[idx]
		# Reparenta temporariamente para o BoardRoot para movimentação global
		var glob_pos: Vector3 = piece.global_position
		piece.get_parent().remove_child(piece)
		$TabletopEnvironment3D/BoardRoot.add_child(piece)
		piece.global_position = glob_pos
		
		# Destino na cesta com leve espalhamento aleatório
		var dest_offset := Vector3(randf_range(-0.35, 0.35), float(idx) * 0.04, randf_range(-0.35, 0.35))
		var final_dest := DISCARD_POS + dest_offset
		var mid_point := (piece.position + final_dest) * 0.5 + Vector3(0.0, 1.4, 0.0)
		
		var delay: float = float(idx) * 0.08
		var tw := create_tween()
		tw.tween_interval(delay)
		# Arco parabólico
		tw.tween_property(piece, "position", mid_point, 0.24)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(piece, "position", final_dest, 0.22)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(piece, "rotation_degrees", Vector3(randf_range(-20, 20), randf_range(-180, 180), randf_range(-20, 20)), 0.46)
		
		tw.tween_callback(func():
			_tweens_pendentes -= 1
			_play_place_sound()
			if _tweens_pendentes <= 0:
				_on_move_animation_finished(player)
		)


func _on_move_animation_finished(last_player: int) -> void:
	is_animating = false
	_rebuild_heap_ui_buttons()
	
	# Verifica fim de jogo
	if Rules.is_game_over(heaps):
		_handle_game_over(last_player)
		return
		
	# Passa o turno
	current_turn = 3 - current_turn
	_update_hud_stats()
	
	if is_vs_ai and current_turn == Rules.PLAYER_AI:
		set_status(tr("NIM_AI_THINKING"))
		_trigger_ai_turn()
	else:
		if is_vs_ai:
			set_status(tr("NIM_YOUR_TURN"))
		else:
			set_status(tr("NIM_PLAYER_TURN") % current_turn)


# ---------------------------------------------------------------------------
# Turno e Raciocínio da IA
# ---------------------------------------------------------------------------

func _trigger_ai_turn() -> void:
	# Pequeno timer antes de agir para sensação orgânica de tomada de decisão
	var geracao := _geracao
	var timer := get_tree().create_timer(0.65)
	timer.timeout.connect(func():
		if geracao != _geracao or game_over or not is_vs_ai or current_turn != Rules.PLAYER_AI:
			return
		_execute_ai_decision()
	)


func _execute_ai_decision() -> void:
	var ai_move := Rules.get_move(heaps, is_misere, ai_level)
	var h_idx: int = ai_move["heap"]
	var take: int = ai_move["take"]
	
	if h_idx == -1 or take <= 0 or not Rules.is_valid_move(heaps, h_idx, take):
		# Fallback de segurança
		var all := Rules.get_all_valid_moves(heaps)
		if not all.is_empty():
			h_idx = all[0]["heap"]
			take = all[0]["take"]
		else:
			return
			
	# Realça a pilha que a IA escolheu. O clamp e o que impede `_lift_selected_pieces`
	# de marcar a pilha inteira quando a busca devolve mais do que ha nela.
	selected_heap = h_idx
	selected_take_count = clampi(take, 1, maxi(1, heaps[h_idx] if h_idx < heaps.size() else 1))
	_update_heap_halos()
	_lift_selected_pieces()
	
	set_status(tr("NIM_AI_TOOK") % [take, 65 + h_idx])
	
	# Anima a retirada após breve destaque. A geracao e conferida porque nestes
	# 0,45 s o jogador pode trocar o preset e refazer as pilhas.
	var geracao := _geracao
	var timer := get_tree().create_timer(0.45)
	timer.timeout.connect(func():
		if geracao != _geracao or game_over:
			return
		_execute_move_animated(h_idx, take, Rules.PLAYER_AI)
	)


# ---------------------------------------------------------------------------
# Vitória, Derrota e Gamificação
# ---------------------------------------------------------------------------

func _handle_game_over(last_player: int) -> void:
	game_over = true
	shell.timer.stop()
	take_controls_container.visible = false
	
	var winner: int = Rules.get_winner(last_player, is_misere)
	var human_won: bool = (winner == Rules.PLAYER_HUMAN)
	var elapsed = shell.timer.get_time()

	var fatos: Array[String] = []
	if human_won:
		if is_misere and ai_level >= DifficultyManager.MAX_LEVEL - 1:
			fatos.append("nim_misere")
		if preset_name == "pyramid_4":
			fatos.append("nim_pyramid")

	var result: Dictionary = {
		"turns": turn_count,
		"misere": is_misere,
		"preset": preset_name,
		"time": elapsed,
		"flags": fatos,
		"mode": "solo" if is_vs_ai else "pass_play"
	}

	var audio := _get_audio_mgr()
	if audio:
		if human_won:
			audio.play_win()
		else:
			audio.play_draw()
			
	if is_vs_ai:
		if human_won:
			finish_game(tr("NIM_WIN"), true, result)
		else:
			finish_game(tr("NIM_LOSE"), false, result)
	else:
		finish_game(tr("NIM_LOCAL_WIN") % winner, true, result)


# ---------------------------------------------------------------------------
# Ações do Jogador e Botões Utilitários
# ---------------------------------------------------------------------------

func _on_btn_undo_pressed() -> void:
	if is_animating or game_over or move_history.is_empty():
		return
	if is_vs_ai and current_turn == Rules.PLAYER_AI:
		return
		
	play_click()
	
	# No modo Vs IA, desfaz 2 jogadas (da IA e do jogador) para voltar à vez do jogador
	var undo_steps: int = 2 if (is_vs_ai and move_history.size() >= 2) else 1
	for _s in range(undo_steps):
		if move_history.is_empty(): break
		var last_move: Dictionary = move_history.pop_back()
		var h_idx: int = last_move["heap"]
		var count: int = last_move["take"]
		Rules.undo_move_inplace(heaps, h_idx, count)
		turn_count = maxi(0, turn_count - 1)
		
	current_turn = Rules.PLAYER_HUMAN
	selected_heap = -1
	take_controls_container.visible = false
	
	# Reconstrói a mesa 3D instantaneamente
	_build_3d_heaps_and_tokens()
	_rebuild_heap_ui_buttons()
	_update_hud_stats()
	set_status(tr("NIM_UNDONE"))


func _on_btn_hint_pressed() -> void:
	if is_animating or game_over:
		return
	play_click()
	
	var best_move := Rules.get_best_ai_move(heaps, is_misere, "hard")
	if best_move["heap"] != -1:
		var h: int = best_move["heap"]
		var t: int = best_move["take"]
		_on_heap_selected(h)
		_set_take_count(t)
		set_status(tr("NIM_HINT") % [t, 65 + h])
	else:
		var nim_s := Rules.calculate_nim_sum(heaps)
		set_status(tr("NIM_HINT_BALANCED") % nim_s)


func _on_btn_mode_toggle_pressed() -> void:
	play_click()
	is_vs_ai = not is_vs_ai
	btn_mode_toggle.text = tr("NIM_BTN_VS_AI") if is_vs_ai else tr("NIM_BTN_TWO_PLAYERS")
	_start_new_game()


func _on_btn_rule_toggle_pressed() -> void:
	play_click()
	is_misere = not is_misere
	btn_rule_toggle.text = tr("NIM_BTN_MISERE") if is_misere else tr("NIM_BTN_NORMAL")
	_start_new_game()


func _on_preset_selected(p_key: String) -> void:
	play_click()
	preset_name = p_key
	_start_new_game()


## Degraus em que os botoes param. Um por faixa de
## `DifficultyManager.tier_name()`.
const DEGRAUS_DO_BOTAO := [2, 4, 6, 8, 10]


## O botao empurra a escada. Quem grava e o DifficultyManager, entao a escolha
## sobrevive a fechar a cena -- coisa que o campo `ai_difficulty` nunca fez.
func _on_difficulty_selected(degrau: int) -> void:
	play_click()
	DifficultyManager.set_level(game_id, degrau)
	ai_level = DifficultyManager.get_level(game_id)
	_highlight_active_settings_buttons()
	set_status(tr("DIFF_SET") % DifficultyManager.label_for(game_id))


func _on_btn_rematch_pressed() -> void:
	play_click()
	_start_new_game()


# ---------------------------------------------------------------------------
# Auxiliares Visuais e de Texto
# ---------------------------------------------------------------------------

func _update_hud_stats() -> void:
	var restam := 0
	for pilha in heaps:
		restam += pilha
	set_counter(restam, "SCORE_PIECES")


func _highlight_active_settings_buttons() -> void:
	for btn: Button in preset_buttons_container.get_children():
		var is_active: bool = str(btn.get_meta("preset", "")) == preset_name
		btn.modulate = Color(1.0, 1.0, 1.0) if is_active else Color(0.7, 0.7, 0.7)
		
	for btn: Button in diff_buttons_container.get_children():
		var is_active: bool = (btn.text == tr(DifficultyManager.tier_name(ai_level)))
		btn.modulate = Color(1.0, 1.0, 1.0) if is_active else Color(0.7, 0.7, 0.7)





func _play_place_sound() -> void:
	var audio := _get_audio_mgr()
	if audio:
		audio.play_piece_place()


func _play_error_buzz() -> void:
	var audio := _get_audio_mgr()
	if audio:
		audio.play_draw()


func _get_event_bus() -> Node:
	return get_node_or_null("/root/GameEventBus")


func _get_audio_mgr() -> Node:
	return get_node_or_null("/root/AudioManager")
