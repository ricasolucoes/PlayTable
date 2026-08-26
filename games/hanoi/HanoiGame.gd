class_name HanoiGame
extends BaseGame

## HanoiGame: Torres de Hanói 3D imersivo com física visual suave,
## seleção de 3 a 8 discos, solver automático demonstrativo, histórico de desfazer,
## sistema de 3 estrelas e integração total com o ecossistema PlayTable.

const Rules = preload("res://games/hanoi/HanoiRules.gd")

const PEG_SPACING: float = 1.9
const DISK_HEIGHT: float = 0.18
const BASE_Y: float = 0.12
const LIFT_Y: float = 2.4

var disk_count: int = 3
var pegs: Array[Array] = []
var disk_nodes: Dictionary = {}
var peg_halos: Array[MeshInstance3D] = []

var selected_peg: int = -1
var selected_disk_node: Node3D = null
var is_animating: bool = false
var move_history: Array[Dictionary] = []

var move_count: int = 0
var elapsed_time: float = 0.0
var is_timer_running: bool = false

var is_auto_solving: bool = false
var auto_solution_steps: Array[Dictionary] = []
var auto_step_index: int = 0

@onready var board_root: Node3D = $BoardRoot
@onready var pegs_root: Node3D = $PegsRoot
@onready var disks_root: Node3D = $DisksRoot
@onready var halos_root: Node3D = $HalosRoot

@onready var title_label: Label = $UI/VBoxContainer/TopBar/Title
@onready var moves_label: Label = $UI/VBoxContainer/InfoCards/MovesCard/VBox/MovesValue
@onready var min_moves_label: Label = $UI/VBoxContainer/InfoCards/MinMovesCard/VBox/MinMovesValue
@onready var time_label: Label = $UI/VBoxContainer/InfoCards/TimeCard/VBox/TimeValue
@onready var stars_label: Label = $UI/VBoxContainer/InfoCards/StarsCard/VBox/StarsValue

@onready var btn_undo: Button = $UI/Actions/BtnUndo
@onready var btn_hint: Button = $UI/Actions/BtnHint
@onready var btn_auto_solve: Button = $UI/Actions/BtnAutoSolve
@onready var diff_buttons_container: HBoxContainer = $UI/VBoxContainer/DifficultyBar/Buttons

@onready var win_modal: Control = $WinModal
@onready var win_title: Label = $WinModal/Panel/VBox/WinTitle
@onready var win_stars: Label = $WinModal/Panel/VBox/WinStars
@onready var win_details: Label = $WinModal/Panel/VBox/WinDetails
@onready var win_xp_label: Label = $WinModal/Panel/VBox/WinXP
@onready var btn_next_level: Button = $WinModal/Panel/VBox/BtnNextLevel


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	btn_restart = $UI/Actions/BtnRestart
	menu_scene_path = BaseGame.MENU_TABULEIRO
	win_modal.visible = false
	
	_setup_difficulty_buttons()
	_setup_3d_tabletop()
	_start_new_game()


func _process(delta: float) -> void:
	if is_timer_running and not game_over:
		elapsed_time += delta
		_update_time_display()


# ---------------------------------------------------------------------------
# Configuração 3D do Tabuleiro, Pinos e Discos
# ---------------------------------------------------------------------------

func _setup_3d_tabletop() -> void:
	for c in board_root.get_children(): c.queue_free()
	for c in pegs_root.get_children(): c.queue_free()
	for c in halos_root.get_children(): c.queue_free()
	peg_halos.clear()
	
	# Base de Madeira Nobre Chanfrada
	var base_mesh: ArrayMesh = MeshBuilder3D.board_slab(6.2, 2.6, 0.22)
	var base_instance := MeshInstance3D.new()
	base_instance.mesh = base_mesh
	base_instance.position = Vector3(0.0, 0.0, 0.0)
	base_instance.material_override = MaterialFactory3D.get_wood_walnut()
	board_root.add_child(base_instance)
	
	# Moldura externa em Mogno
	var rim_mesh: ArrayMesh = MeshBuilder3D.board_slab(6.4, 2.8, 0.08)
	var rim_instance := MeshInstance3D.new()
	rim_instance.mesh = rim_mesh
	rim_instance.position = Vector3(0.0, -0.09, 0.0)
	rim_instance.material_override = MaterialFactory3D.get_wood_mahogany()
	board_root.add_child(rim_instance)
	
	# 3 Pinos Verticais e Anéis de Estação
	for i in range(3):
		var peg_pos := _get_peg_base_pos(i)
		
		# Anel / Prato metálico da estação na base
		var plate := MeshInstance3D.new()
		var plate_cyl := CylinderMesh.new()
		plate_cyl.top_radius = 0.78
		plate_cyl.bottom_radius = 0.82
		plate_cyl.height = 0.03
		plate_cyl.radial_segments = 36
		plate.mesh = plate_cyl
		plate.position = Vector3(peg_pos.x, 0.115, peg_pos.z)
		plate.material_override = MaterialFactory3D.get_gold()
		board_root.add_child(plate)
		
		# Anel de Halo luminoso (usado para Dica e Seleção)
		var halo := MeshInstance3D.new()
		var halo_mesh := TorusMesh.new()
		halo_mesh.inner_radius = 0.80
		halo_mesh.outer_radius = 0.90
		halo_mesh.rings = 24
		halo_mesh.ring_segments = 24
		halo.mesh = halo_mesh
		halo.position = Vector3(peg_pos.x, 0.125, peg_pos.z)
		halo.material_override = MaterialFactory3D.get_state_overlay(Color(0.2, 0.85, 1.0), 0.8)
		halo.visible = false
		halos_root.add_child(halo)
		peg_halos.append(halo)
		
		# Fuso / Haste vertical de Ouro polido
		var spindle := MeshInstance3D.new()
		var spindle_cyl := CylinderMesh.new()
		spindle_cyl.top_radius = 0.075
		spindle_cyl.bottom_radius = 0.078
		spindle_cyl.height = 1.95
		spindle_cyl.radial_segments = 24
		spindle.mesh = spindle_cyl
		spindle.position = Vector3(peg_pos.x, 1.08, peg_pos.z)
		spindle.material_override = MaterialFactory3D.get_gold()
		pegs_root.add_child(spindle)
		
		# Ponteira superior esférica
		var cap := MeshInstance3D.new()
		var cap_sphere := SphereMesh.new()
		cap_sphere.radius = 0.10
		cap_sphere.height = 0.20
		cap.mesh = cap_sphere
		cap.position = Vector3(peg_pos.x, 2.05, peg_pos.z)
		cap.material_override = MaterialFactory3D.get_gold()
		pegs_root.add_child(cap)
		
	# Enquadra a câmera na área do jogo
	if env_3d:
		env_3d.frame_content(Vector2(6.8, 4.0), Vector3(0, 0.8, 0))


func _setup_difficulty_buttons() -> void:
	for child in diff_buttons_container.get_children():
		child.queue_free()
		
	for d in range(Rules.MIN_DISKS, Rules.MAX_DISKS + 1):
		var btn := Button.new()
		btn.text = "%d Discos" % d
		btn.custom_minimum_size = Vector2(85, 42)
		btn.focus_mode = Control.FOCUS_NONE
		btn.pressed.connect(_on_difficulty_selected.bind(d))
		diff_buttons_container.add_child(btn)


func _on_difficulty_selected(new_disk_count: int) -> void:
	play_click()
	if is_animating or is_auto_solving:
		_cancel_auto_solver()
	disk_count = new_disk_count
	_start_new_game()


# ---------------------------------------------------------------------------
# Ciclo da Partida
# ---------------------------------------------------------------------------

func _start_new_game() -> void:
	game_over = false
	is_animating = false
	is_auto_solving = false
	selected_peg = -1
	selected_disk_node = null
	move_history.clear()
	move_count = 0
	elapsed_time = 0.0
	is_timer_running = false
	
	if btn_restart != null:
		btn_restart.hide()
	win_modal.visible = false
	_hide_all_halos()
	
	pegs = Rules.create_initial_pegs(disk_count)
	_build_3d_disks()
	_update_ui_stats()
	_highlight_active_difficulty_button()
	
	set_status("Toque no Pino A (Origem) para erguer o primeiro disco!")
	
	var bus := _get_event_bus()
	if bus:
		bus.emit_game_started("hanoi")
		if bus.has_signal("match_started"):
			bus.match_started.emit("hanoi", "%d_disks" % disk_count)


func _build_3d_disks() -> void:
	for c in disks_root.get_children(): c.queue_free()
	disk_nodes.clear()
	
	for d in range(1, disk_count + 1):
		var disk_node := _create_disk_node(d, disk_count)
		disks_root.add_child(disk_node)
		disk_nodes[d] = disk_node
		
	_sync_disks_position_instant()


func _create_disk_node(disk_size: int, total_disks: int) -> Node3D:
	var root := Node3D.new()
	root.name = "Disk_%d" % disk_size
	
	# Raio proporcional ao tamanho do disco
	var r_min: float = 0.32
	var r_max: float = 0.82
	var t: float = float(disk_size - 1) / float(maxi(total_disks - 1, 1))
	var radius: float = lerpf(r_min, r_max, t)
	
	# Malha chanfrada de disco nobre via MeshBuilder3D
	var mesh_inst := MeshInstance3D.new()
	var mesh: ArrayMesh = MeshBuilder3D.disc_token(radius, DISK_HEIGHT)
	mesh_inst.mesh = mesh
	mesh_inst.position = Vector3(0.0, DISK_HEIGHT * 0.5, 0.0)
	mesh_inst.material_override = _get_disk_material(disk_size)
	root.add_child(mesh_inst)
	
	# Orifício / Anel central em latão dourado para o fuso
	var hole_ring := MeshInstance3D.new()
	var hole_cyl := CylinderMesh.new()
	hole_cyl.top_radius = 0.11
	hole_cyl.bottom_radius = 0.11
	hole_cyl.height = DISK_HEIGHT + 0.01
	hole_cyl.radial_segments = 24
	hole_ring.mesh = hole_cyl
	hole_ring.position = Vector3(0.0, DISK_HEIGHT * 0.5, 0.0)
	hole_ring.material_override = MaterialFactory3D.get_gold()
	root.add_child(hole_ring)
	
	# Orifício interno em obsidiana (ilusão de furo profundo)
	var hole_inner := MeshInstance3D.new()
	var inner_cyl := CylinderMesh.new()
	inner_cyl.top_radius = 0.088
	inner_cyl.bottom_radius = 0.088
	inner_cyl.height = DISK_HEIGHT + 0.02
	inner_cyl.radial_segments = 24
	hole_inner.mesh = inner_cyl
	hole_inner.position = Vector3(0.0, DISK_HEIGHT * 0.5, 0.0)
	hole_inner.material_override = MaterialFactory3D.get_obsidian()
	root.add_child(hole_inner)
	
	# Sombra de contato suave na base do disco
	var shadow := MeshInstance3D.new()
	var shadow_plane := PlaneMesh.new()
	shadow_plane.size = Vector2(radius * 2.2, radius * 2.2)
	shadow.mesh = shadow_plane
	shadow.position = Vector3(0.0, 0.005, 0.0)
	shadow.material_override = MaterialFactory3D.get_contact_shadow()
	root.add_child(shadow)
	
	return root


func _get_disk_material(size: int) -> StandardMaterial3D:
	match size:
		1: return MaterialFactory3D.get_gemstone(Color(0.92, 0.16, 0.22)) # Rubi Carmesim
		2: return MaterialFactory3D.get_gemstone(Color(0.98, 0.58, 0.10)) # Topázio Âmbar
		3: return MaterialFactory3D.get_gold()                           # Ouro Nobre
		4: return MaterialFactory3D.get_gemstone(Color(0.12, 0.82, 0.38)) # Esmeralda
		5: return MaterialFactory3D.get_gemstone(Color(0.12, 0.76, 0.80)) # Turquesa
		6: return MaterialFactory3D.get_gemstone(Color(0.16, 0.38, 0.95)) # Safira
		7: return MaterialFactory3D.get_gemstone(Color(0.72, 0.22, 0.90)) # Ametista
		8: return MaterialFactory3D.get_obsidian()                        # Obsidiana Imperial
		_: return MaterialFactory3D.get_gemstone(Color(0.85, 0.40, 0.20))


func _get_peg_base_pos(peg_idx: int) -> Vector3:
	var x_offset: float = (float(peg_idx) - 1.0) * PEG_SPACING
	return Vector3(x_offset, 0.0, 0.0)


func _get_disk_stack_pos(peg_idx: int, stack_index: int) -> Vector3:
	var base := _get_peg_base_pos(peg_idx)
	var y: float = BASE_Y + (float(stack_index) * DISK_HEIGHT)
	return Vector3(base.x, y, base.z)


func _sync_disks_position_instant() -> void:
	for peg_idx in range(3):
		var peg_array: Array = pegs[peg_idx]
		for stack_idx in range(peg_array.size()):
			var disk_val: int = peg_array[stack_idx]
			var node: Node3D = disk_nodes.get(disk_val)
			if node:
				node.position = _get_disk_stack_pos(peg_idx, stack_idx)
				node.rotation_degrees = Vector3.ZERO


# ---------------------------------------------------------------------------
# Interação e Movimentação 3D
# ---------------------------------------------------------------------------

func _on_peg_pressed(peg_idx: int) -> void:
	if game_over or is_animating or is_auto_solving:
		return
		
	if not is_timer_running:
		is_timer_running = true
		
	_hide_all_halos()
	
	# Se nenhum pino estiver selecionado -> Seleciona o pino de origem
	if selected_peg == -1:
		if pegs[peg_idx].is_empty():
			set_status("Pino %s está vazio! Escolha um pino com discos." % _get_peg_name(peg_idx))
			_play_error_buzz()
			return
			
		selected_peg = peg_idx
		var top_disk_size: int = Rules.get_top_disk(pegs[peg_idx])
		selected_disk_node = disk_nodes.get(top_disk_size)
		_animate_disk_lift(selected_disk_node, peg_idx)
		_show_peg_halo(peg_idx, Color(1.0, 0.85, 0.2))
		set_status("Disco %d erguido! Toque no pino de destino." % top_disk_size)
		return
		
	# Se o mesmo pino for tocado novamente -> Pousa o disco de volta
	if selected_peg == peg_idx:
		var current_peg: int = selected_peg
		selected_peg = -1
		var node: Node3D = selected_disk_node
		selected_disk_node = null
		_animate_disk_lower(node, current_peg, pegs[current_peg].size() - 1)
		set_status("Disco mantido no Pino %s." % _get_peg_name(current_peg))
		return
		
	# Pino de destino selecionado -> Valida e move
	var from_peg: int = selected_peg
	var to_peg: int = peg_idx
	
	if Rules.can_move_disk(pegs, from_peg, to_peg):
		selected_peg = -1
		var moving_node: Node3D = selected_disk_node
		selected_disk_node = null
		_execute_move_with_animation(from_peg, to_peg, moving_node)
	else:
		var moving_disk: int = Rules.get_top_disk(pegs[from_peg])
		var target_disk: int = Rules.get_top_disk(pegs[to_peg])
		set_status("Inválido! Disco %d não cabe sobre o disco %d." % [moving_disk, target_disk])
		_play_error_buzz()
		_animate_invalid_move(selected_disk_node, from_peg, to_peg)


func _animate_disk_lift(disk_node: Node3D, _peg_idx: int) -> void:
	if not disk_node: return
	_play_place_sound()
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(disk_node, "position:y", LIFT_Y, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(disk_node, "rotation_degrees:y", disk_node.rotation_degrees.y + 20.0, 0.22)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)


func _animate_disk_lower(disk_node: Node3D, peg_idx: int, stack_idx: int) -> void:
	if not disk_node: return
	var target_pos := _get_disk_stack_pos(peg_idx, stack_idx)
	
	var tw := create_tween().set_parallel(true)
	tw.tween_property(disk_node, "position", target_pos, 0.20)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(disk_node, "rotation_degrees:y", 0.0, 0.20)


func _execute_move_with_animation(from_peg: int, to_peg: int, disk_node: Node3D,
		is_undo: bool = false, custom_duration: float = 0.35) -> void:
	is_animating = true
	var res: Dictionary = Rules.execute_move(pegs, from_peg, to_peg)
	
	if not is_undo:
		move_history.append(res)
		move_count += 1
	_update_ui_stats()
	
	var target_stack_idx: int = pegs[to_peg].size() - 1
	var target_pos := _get_disk_stack_pos(to_peg, target_stack_idx)
	var peak_pos := Vector3((_get_peg_base_pos(from_peg).x + _get_peg_base_pos(to_peg).x) * 0.5, LIFT_Y + 0.3, 0.0)
	var above_target := Vector3(target_pos.x, LIFT_Y, target_pos.z)
	
	var tw := create_tween()
	# 1. Arco horizontal de translação no ar
	tw.tween_property(disk_node, "position", peak_pos, custom_duration * 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(disk_node, "position", above_target, custom_duration * 0.45)\
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	# 2. Deslizar verticalmente pelo pino com amortecimento elástico
	tw.tween_property(disk_node, "position", target_pos, custom_duration * 0.45)\
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		
	tw.tween_callback(func():
		_play_place_sound()
		is_animating = false
		_check_game_over()
	)


func _animate_invalid_move(disk_node: Node3D, from_peg: int, to_peg: int) -> void:
	if not disk_node: return
	is_animating = true
	
	var target_base := _get_peg_base_pos(to_peg)
	var return_stack_idx: int = pegs[from_peg].size() - 1
	var return_pos := _get_disk_stack_pos(from_peg, return_stack_idx)
	
	var tw := create_tween()
	tw.tween_property(disk_node, "position:x", target_base.x * 0.5 + disk_node.position.x * 0.5, 0.14)
	tw.tween_property(disk_node, "position:x", disk_node.position.x + 0.15, 0.05)
	tw.tween_property(disk_node, "position:x", disk_node.position.x - 0.15, 0.05)
	tw.tween_property(disk_node, "position:x", disk_node.position.x + 0.10, 0.05)
	tw.tween_property(disk_node, "position", return_pos, 0.22)\
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		
	tw.tween_callback(func():
		selected_peg = -1
		selected_disk_node = null
		is_animating = false
	)


# ---------------------------------------------------------------------------
# Recursos Auxiliares: Desfazer, Dica e Solver
# ---------------------------------------------------------------------------

func _on_btn_undo_pressed() -> void:
	if is_animating or is_auto_solving or game_over or move_history.is_empty():
		return
	play_click()
	
	if selected_peg != -1 and selected_disk_node:
		var curr_peg: int = selected_peg
		selected_peg = -1
		var node: Node3D = selected_disk_node
		selected_disk_node = null
		_animate_disk_lower(node, curr_peg, pegs[curr_peg].size() - 1)
		return
		
	var last_move: Dictionary = move_history.pop_back()
	var from_peg: int = last_move["from"]
	var to_peg: int = last_move["to"]
	var disk_val: int = last_move["disk"]
	
	var disk_node: Node3D = disk_nodes.get(disk_val)
	if disk_node:
		Rules.undo_move(pegs, last_move)
		move_count = maxi(0, move_count - 1)
		_update_ui_stats()
		
		var target_stack_idx: int = pegs[from_peg].size() - 1
		var target_pos := _get_disk_stack_pos(from_peg, target_stack_idx)
		
		is_animating = true
		var tw := create_tween()
		tw.tween_property(disk_node, "position:y", LIFT_Y, 0.15)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(disk_node, "position", Vector3(target_pos.x, LIFT_Y, target_pos.z), 0.18)
		tw.tween_property(disk_node, "position", target_pos, 0.16)\
			.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		tw.tween_callback(func():
			_play_place_sound()
			is_animating = false
		)
		set_status("Jogada desfeita!")


func _on_btn_hint_pressed() -> void:
	if is_animating or is_auto_solving or game_over:
		return
	play_click()
	
	var hint: Dictionary = Rules.get_next_hint(pegs, disk_count, Rules.PEG_DESTINO)
	if hint.is_empty():
		set_status("Nenhuma dica disponível para a posição atual.")
		return
		
	var f: int = hint["from"]
	var t: int = hint["to"]
	var disk_val: int = Rules.get_top_disk(pegs[f])
	
	_show_peg_halo(f, Color(1.0, 0.85, 0.2))
	_show_peg_halo(t, Color(0.2, 1.0, 0.4))
	set_status("💡 Dica: Mova o Disco %d do Pino %s para o Pino %s!" % [disk_val, _get_peg_name(f), _get_peg_name(t)])


func _on_btn_auto_solve_pressed() -> void:
	if is_animating or game_over:
		return
	play_click()
	
	if is_auto_solving:
		_cancel_auto_solver()
		return
		
	_start_new_game()
	is_auto_solving = true
	btn_auto_solve.text = "⏹ Parar"
	auto_solution_steps = Rules.generate_optimal_solution(disk_count)
	auto_step_index = 0
	set_status("🤖 Solução Automática em andamento (%d passos)..." % auto_solution_steps.size())
	_run_next_auto_step()


func _run_next_auto_step() -> void:
	if not is_auto_solving or game_over:
		return
	if auto_step_index >= auto_solution_steps.size():
		_cancel_auto_solver()
		return
		
	var step: Dictionary = auto_solution_steps[auto_step_index]
	auto_step_index += 1
	var f: int = step["from"]
	var t: int = step["to"]
	
	var disk_val: int = Rules.get_top_disk(pegs[f])
	var disk_node: Node3D = disk_nodes.get(disk_val)
	
	_execute_move_with_animation(f, t, disk_node, false, 0.28)
	
	await get_tree().create_timer(0.32).timeout
	if is_auto_solving:
		_run_next_auto_step()


func _cancel_auto_solver() -> void:
	is_auto_solving = false
	btn_auto_solve.text = "🤖 Auto"
	set_status("Solução automática interrompida.")


# ---------------------------------------------------------------------------
# Verificação de Vitória e Gamificação
# ---------------------------------------------------------------------------

func _check_game_over() -> void:
	if Rules.is_won(pegs, disk_count, Rules.PEG_DESTINO):
		_handle_game_won()


func _handle_game_won() -> void:
	game_over = true
	is_timer_running = false
	_hide_all_halos()
	
	var optimal: int = Rules.get_optimal_moves(disk_count)
	var stars: int = Rules.calculate_stars(move_count, disk_count)
	var is_perfect: bool = (move_count == optimal)
	
	var base_xp: int = disk_count * 100
	var stars_bonus: int = stars * 50
	var perfect_bonus: int = 200 if is_perfect else 0
	var total_xp: int = base_xp + stars_bonus + perfect_bonus
	
	var bus := _get_event_bus()
	if bus:
		var result: Dictionary = {
			"win": true,
			"perfect": is_perfect,
			"disks": disk_count,
			"moves": move_count,
			"optimal_moves": optimal,
			"stars": stars,
			"time": elapsed_time
		}
		bus.emit_match_completed("hanoi", result)
		bus.emit_xp_gained(total_xp, "hanoi_win")
		
		if is_perfect and disk_count >= 3:
			bus.achievement_unlocked.emit("ACH_HANOI_3_PERFECT")
		if disk_count >= 5:
			bus.achievement_unlocked.emit("ACH_HANOI_5_SOLVED")
		if disk_count >= 7:
			bus.achievement_unlocked.emit("ACH_HANOI_MASTER")
			
	var profile := _get_player_profile()
	if profile:
		profile.increment_stat("hanoi_wins")
		var best_moves: int = profile.get_stat("hanoi_best_moves_%d" % disk_count, 99999)
		if move_count < best_moves:
			profile.stats["hanoi_best_moves_%d" % disk_count] = move_count
		var best_stars: int = profile.get_stat("hanoi_stars_%d" % disk_count, 0)
		if stars > best_stars:
			profile.stats["hanoi_stars_%d" % disk_count] = stars
		profile.save_profile()
		
	win_stars.text = _get_stars_string(stars)
	win_details.text = "Jogadas: %d (Mínimo: %d)\nTempo: %s" % [
		move_count, optimal, _format_time(elapsed_time)
	]
	win_xp_label.text = "+%d XP Ganho!" % total_xp
	
	if disk_count < Rules.MAX_DISKS:
		btn_next_level.visible = true
		btn_next_level.text = "▶ Próximo Nível (%d Discos)" % (disk_count + 1)
	else:
		btn_next_level.visible = false
		
	var audio := _get_audio_mgr()
	if audio:
		audio.play_win()
		
	finish_game("🏆 Incrível! Você completou a Torre de %d Discos!" % disk_count, true)
	reveal_result_modal(win_modal, 0.4)


func _on_btn_next_level_pressed() -> void:
	play_click()
	if disk_count < Rules.MAX_DISKS:
		disk_count += 1
		_start_new_game()


# ---------------------------------------------------------------------------
# Auxiliares Visuais e de Texto
# ---------------------------------------------------------------------------

func _get_peg_name(peg_idx: int) -> String:
	match peg_idx:
		0: return "A (Origem)"
		1: return "B (Auxiliar)"
		2: return "C (Destino)"
		_: return "Desconhecido"


func _update_ui_stats() -> void:
	var optimal: int = Rules.get_optimal_moves(disk_count)
	moves_label.text = str(move_count)
	min_moves_label.text = str(optimal)
	var stars: int = Rules.calculate_stars(move_count, disk_count)
	stars_label.text = _get_stars_string(stars)
	title_label.text = "Torres de Hanói (%d Discos)" % disk_count


func _update_time_display() -> void:
	time_label.text = _format_time(elapsed_time)


func _format_time(seconds: float) -> String:
	var s: int = int(seconds)
	var m: int = s / 60
	var rem_s: int = s % 60
	return "%02d:%02d" % [m, rem_s]


func _get_stars_string(stars: int) -> String:
	match stars:
		3: return "⭐⭐⭐"
		2: return "⭐⭐☆"
		1: return "⭐☆☆"
		_: return "☆☆☆"


func _show_peg_halo(peg_idx: int, color: Color) -> void:
	if peg_idx >= 0 and peg_idx < peg_halos.size():
		var h := peg_halos[peg_idx]
		h.material_override = MaterialFactory3D.get_state_overlay(color, 0.9)
		h.visible = true


func _hide_all_halos() -> void:
	for h in peg_halos:
		h.visible = false


func _highlight_active_difficulty_button() -> void:
	for btn: Button in diff_buttons_container.get_children():
		var is_active: bool = (btn.text.begins_with(str(disk_count)))
		btn.modulate = Color(1.0, 1.0, 1.0, 1.0) if is_active else Color(0.7, 0.7, 0.7, 0.7)


func _play_error_buzz() -> void:
	var audio := _get_audio_mgr()
	if audio:
		audio.play_draw()


func _play_place_sound() -> void:
	var audio := _get_audio_mgr()
	if audio:
		audio.play_piece_place()


func _get_event_bus() -> Node:
	return get_node_or_null("/root/GameEventBus")


func _get_player_profile() -> Node:
	return get_node_or_null("/root/PlayerProfile")


func _get_audio_mgr() -> Node:
	return get_node_or_null("/root/AudioManager")
