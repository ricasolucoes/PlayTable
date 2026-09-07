extends SceneTree

## Sonda: lista TODOS os ScrollContainer de uma cena e testa arrasto de toque
## em cada um (vertical e horizontal).
## Uso: godot --headless --path . --script tools/_probe_scroll_all.gd -- <cena> [w] [h]

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
	var aba: String = argv[3] if argv.size() > 3 else ""
	_rodar(inst, aba)

func _todos(n: Node, saida: Array) -> void:
	if n is ScrollContainer:
		saida.append(n)
	for f in n.get_children():
		_todos(f, saida)

func _caminho(n: Node) -> String:
	return str(n.get_path()).replace("/root/@SubViewport@2/", "")

func _rodar(inst: Node, aba: String) -> void:
	for i in range(30):
		await process_frame
	if aba != "" and inst.has_method("_trocar_aba"):
		inst.call("_trocar_aba", aba)
		for i in range(20):
			await process_frame
	print("touchscreen disponivel = ", DisplayServer.is_touchscreen_available())
	var lista: Array = []
	_todos(inst, lista)
	print("ScrollContainers: ", lista.size())
	for sc in lista:
		await _testar(sc)
	quit(0)

func _testar(sc: ScrollContainer) -> void:
	print("\n--- ", _caminho(sc), " ---")
	print("  rect=", sc.get_global_rect())
	var vb := sc.get_v_scroll_bar()
	var hb := sc.get_h_scroll_bar()
	print("  vbar max=%.0f page=%.0f | hbar max=%.0f page=%.0f" % [vb.max_value, vb.page, hb.max_value, hb.page])
	var vertical: bool = vb.max_value > vb.page
	var horizontal: bool = hb.max_value > hb.page
	print("  rola vertical=%s horizontal=%s" % [vertical, horizontal])
	var p := sc.global_position + sc.size * 0.5
	print("  sob o dedo = ", _sob(p))
	if vertical:
		sc.scroll_vertical = 0
		await process_frame
		await _arrastar(p, Vector2(0, -20), 12)
		print("  arrasto vertical 240px -> scroll_vertical = ", sc.scroll_vertical)
	if horizontal:
		sc.scroll_horizontal = 0
		await process_frame
		await _arrastar(p, Vector2(-20, 0), 12)
		print("  arrasto horizontal 240px -> scroll_horizontal = ", sc.scroll_horizontal)

func _sob(ponto: Vector2) -> String:
	var mm := InputEventMouseMotion.new()
	mm.position = ponto
	mm.global_position = ponto
	sub.push_input(mm)
	var alvo: Control = sub.gui_get_hovered_control()
	if alvo == null:
		return "<nada>"
	return _caminho(alvo) + " [filter=%d]" % alvo.mouse_filter

func _arrastar(p: Vector2, passo: Vector2, n: int) -> void:
	var t := InputEventScreenTouch.new()
	t.index = 0; t.pressed = true; t.position = p
	sub.push_input(t)
	await process_frame
	var atual := p
	for i in range(n):
		atual += passo
		var d := InputEventScreenDrag.new()
		d.index = 0; d.position = atual
		d.relative = passo; d.velocity = passo * 30.0
		sub.push_input(d)
		await process_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = atual
	sub.push_input(up)
	for i in range(5):
		await process_frame
