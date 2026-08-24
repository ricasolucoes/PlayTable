extends SceneTree

## Headless-ish screenshot harness.
## Usage: Godot --path <proj> --script tools/shot.gd -- <scene.tscn> <out.png> [frames] [w] [h]

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() < 2:
		push_error("usage: -- <scene> <out.png> [frames] [w] [h]")
		quit(1)
		return
	var scene_path: String = argv[0]
	var out_path: String = argv[1]
	var frames: int = int(argv[2]) if argv.size() > 2 else 45
	var w: int = int(argv[3]) if argv.size() > 3 else 720
	var h: int = int(argv[4]) if argv.size() > 4 else 1280

	var win := root
	win.size = Vector2i(w, h)
	win.content_scale_size = Vector2i(720, 1280)

	var ps: PackedScene = load(scene_path)
	if ps == null:
		push_error("could not load %s" % scene_path)
		quit(2)
		return
	var inst := ps.instantiate()
	root.add_child(inst)

	_capture(out_path, frames)

func _capture(out_path: String, frames: int) -> void:
	for i in range(frames):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	var dir := out_path.get_base_dir()
	if dir != "" and not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	img.save_png(out_path)
	print("SHOT_OK %s %dx%d" % [out_path, img.get_width(), img.get_height()])
	quit(0)
