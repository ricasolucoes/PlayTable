extends SceneTree
## Renderiza o atlas de cartas em PNG para conferencia visual.
func _initialize() -> void:
	var holder := Node.new()
	root.add_child(holder)
	await CardAtlas3D.ensure_built(holder)
	var img := CardAtlas3D._atlas.get_image()
	var out: String = OS.get_cmdline_user_args()[0]
	img.save_png(out)
	print("ATLAS_OK %s %dx%d" % [out, img.get_width(), img.get_height()])
	quit(0)
