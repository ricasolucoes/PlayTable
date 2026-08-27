extends SceneTree

## Igual ao shot.gd, mas chama metodos na cena antes de capturar.
## Usage: Godot --path <proj> --script tools/shot_call.gd -- <scene> <out.png> <frames> <w> <h> <metodo>[,<metodo>...]

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var scene_path: String = argv[0]
	var out_path: String = argv[1]
	var frames: int = int(argv[2])
	var w: int = int(argv[3])
	var h: int = int(argv[4])
	var calls: PackedStringArray = argv[5].split(",") if argv.size() > 5 else PackedStringArray()

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(w, h)
	root.size = Vector2i(w, h)

	var inst := (load(scene_path) as PackedScene).instantiate()
	root.add_child(inst)

	for i in range(30):
		await process_frame
	for c in calls:
		if c.strip_edges() == "":
			continue
		var parts := c.strip_edges().split("|")
		var args: Array = []
		for i in range(1, parts.size()):
			var a := parts[i]
			if a == "null":
				args.append(null)
			elif a.is_valid_int():
				args.append(int(a))
			else:
				args.append(a)
		inst.callv(parts[0], args)
		for i in range(20):
			await process_frame

	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(out_path)
	print("SHOT_OK %s" % out_path)
	quit(0)
