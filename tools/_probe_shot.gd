extends SceneTree

## Sonda de captura com estado: instancia a cena, aplica um "modo" e captura.
## Usage: Godot --path <proj> --script tools/_probe_shot.gd -- <scene> <out.png> <modo>

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var scene_path: String = argv[0]
	var out_path: String = argv[1]
	var modo: String = argv[2] if argv.size() > 2 else ""
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(540, 960)
	root.size = Vector2i(540, 960)
	var inst := (load(scene_path) as PackedScene).instantiate()
	root.add_child(inst)
	for i in range(30):
		await process_frame
	match modo:
		"peg_select":
			inst._select(Vector2i(3, 1))
		"peg_sem_esferas":
			inst.marbles_root.visible = false
		"peg_sem_base":
			inst.board_root.get_child(0).visible = false
		"peg_sem_friso":
			inst.board_root.get_child(1).visible = false
		"peg_sem_halos":
			inst.halos.visible = false
		"peg_sem_mesa":
			for c in inst.env_3d.get_children():
				print("env filho: ", c.name, " ", c.get_class())
				if c is MeshInstance3D:
					c.visible = false
		"peg_so_base":
			inst.marbles_root.visible = false
			for i in range(1, inst.board_root.get_child_count()):
				inst.board_root.get_child(i).visible = false
		"peg_sem_sombra_contato":
			for m in inst.marbles_root.get_children():
				m.contact_shadow.visible = false
		"peg_sem_sombra_luz":
			inst.env_3d.key_light.shadow_enabled = false
		"nim_select":
			inst._on_heap_selected(1)
		"hanoi_select":
			inst._on_peg_pressed(0)
		"gamao_roll":
			inst._on_btn_roll_dice_pressed()
			for i in range(300):
				await process_frame
				if inst.has_rolled_dice and not inst.is_animating:
					break
			var legais: Array = BackgammonRules.get_all_legal_single_moves(inst.game_state, inst.current_player, inst.available_moves)
			if not legais.is_empty():
				inst._on_position_touched(int(legais[0]["from"]))
			print("halos visiveis: ", inst.point_halos.multimesh.visible_instance_count,
				" selecionado=", inst.selected_pos, " cor=", inst.point_halos.color_of(inst.selected_pos - 1),
				" alvo=", inst.point_halos.position_of(inst.selected_pos - 1),
				" global=", inst.point_halos.global_position, " visivel=", inst.point_halos.is_visible_in_tree())
		"domino_jogada":
			inst.board_chain.append({"a": 6, "b": 3})
			inst.board_chain.append({"a": 3, "b": 1})
			inst.right_end = 1
			inst._render_table_tiles_3d()
			inst._update_ui()
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("SHOT_OK %s" % out_path)
	quit(0)
