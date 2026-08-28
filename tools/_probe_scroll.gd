extends SceneTree

## Sonda de rolagem: mede o ScrollContainer de uma cena dentro de um SubViewport
## do tamanho pedido e simula arrasto de toque e roda de mouse.
## Uso: godot --headless --path . --script tools/_probe_scroll.gd -- <cena> [w] [h]

var sub: SubViewport

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	var cena: String = argv[0] if argv.size() > 0 else "res://core/telas/MainMenu.tscn"
	var w: int = int(argv[1]) if argv.size() > 1 else 720
	var h: int = int(argv[2]) if argv.size() > 2 else 1280
	sub = SubViewport.new()
	sub.size = Vector2i(w, h)
	sub.handle_input_locally = true
	Input.set_emulate_touch_from_mouse(true)
	sub.gui_embed_subwindows = false
	root.add_child(sub)
	var ps: PackedScene = load(cena)
	var inst: Node = ps.instantiate()
	sub.add_child(inst)
	_rodar(inst, w, h)

func _achar(n: Node) -> ScrollContainer:
	if n is ScrollContainer:
		return n
	for f in n.get_children():
		var r := _achar(f)
		if r != null:
			return r
	return null

func _sob(vp: Viewport, ponto: Vector2) -> String:
	var alvo := vp.gui_get_hovered_control()
	return str(alvo) if alvo != null else "<nada>"


func _rodar(inst: Node, w: int, h: int) -> void:
	for i in range(30):
		await process_frame
	var sc := _achar(inst)
	if sc == null:
		print("SEM SCROLLCONTAINER"); quit(1); return
	var filho: Control = null
	for f in sc.get_children():
		if f is Control and not (f is ScrollBar):
			filho = f; break
	print("--- %s @ %dx%d ---" % [inst.name, w, h])
	print("raiz.size = ", (inst as Control).size)
	print("scroll.size=%s pos=%s" % [sc.size, sc.global_position])
	print("filho %s size=%s min=%s vflags=%d" % [filho.name, filho.size,
		filho.get_combined_minimum_size(), filho.size_flags_vertical])
	var vb := sc.get_v_scroll_bar()
	print("vbar.visible=%s max=%.1f page=%.1f" % [vb.visible, vb.max_value, vb.page])
	var hb := sc.get_h_scroll_bar()
	print("hbar.visible=%s max=%.1f page=%.1f" % [hb.visible, hb.max_value, hb.page])

	sc.scroll_vertical = 100000
	await process_frame
	print("scroll_vertical=100000 -> ", sc.scroll_vertical)
	sc.scroll_vertical = 0
	await process_frame

	var p := sc.global_position + Vector2(sc.size.x * 0.5, sc.size.y * 0.6)
	var t := InputEventScreenTouch.new()
	t.index = 0; t.pressed = true; t.position = p
	sub.push_input(t)
	await process_frame
	var y := p.y
	for i in range(12):
		var d := InputEventScreenDrag.new()
		d.index = 0; d.position = Vector2(p.x, y - 20)
		d.relative = Vector2(0, -20); d.velocity = Vector2(0, -600)
		y -= 20
		sub.push_input(d)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = Vector2(p.x, y)
	sub.push_input(up)
	for i in range(5):
		await process_frame
	print("arrasto de 240px -> scroll_vertical = ", sc.scroll_vertical)
	print("touchscreen disponivel = ", DisplayServer.is_touchscreen_available())
	print("sob o dedo = ", _sob(sub, p))

	sc.scroll_vertical = 0
	await process_frame
	for i in range(3):
		for pressed in [true, false]:
			var mb := InputEventMouseButton.new()
			mb.button_index = MOUSE_BUTTON_WHEEL_DOWN
			mb.pressed = pressed
			mb.position = p
			mb.global_position = p
			sub.push_input(mb)
		await process_frame
	print("3 cliques de roda -> scroll_vertical = ", sc.scroll_vertical)
	quit(0)
