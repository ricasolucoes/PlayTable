extends SceneTree

## Onde o toque morre: um ScrollContainer que anuncia tudo o que chega ao seu
## `_gui_input`, com a lista montada de tres jeitos.
##   rotulos  -> filhos MOUSE_FILTER_IGNORE (controle)
##   botoes   -> filhos Button, o padrao (MOUSE_FILTER_STOP)
##   botoes+  -> os mesmos Button com MOUSE_FILTER_PASS

class Espiao extends ScrollContainer:
	var visto: Array[String] = []
	func _gui_input(e: InputEvent) -> void:
		visto.append(e.get_class())

var raiz: Control
var sub: SubViewport

func _initialize() -> void:
	Input.set_emulate_touch_from_mouse(true)
	sub = SubViewport.new()
	sub.size = Vector2i(720, 1280)
	sub.handle_input_locally = true
	root.add_child(sub)
	raiz = Control.new()
	raiz.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.size = Vector2(720, 1280)
	sub.add_child(raiz)
	_rodar()

func _montar(modo: String) -> Espiao:
	for f in raiz.get_children():
		raiz.remove_child(f)
		f.queue_free()
	var sc := Espiao.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	raiz.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	for i in range(20):
		var c: Control
		if modo == "rotulos":
			var l := Label.new()
			l.text = "item %d" % i
			c = l
		else:
			var b := Button.new()
			b.text = "item %d" % i
			if modo == "botoes+":
				b.mouse_filter = Control.MOUSE_FILTER_PASS
			c = b
		c.custom_minimum_size = Vector2(0, 200)
		vb.add_child(c)
	return sc

func _arrastar(sc: Espiao) -> void:
	sc.set("deadzone", 0)
	var p := sc.global_position + sc.size * 0.5
	var t := InputEventScreenTouch.new()
	t.index = 0; t.pressed = true; t.position = p
	sub.push_input(t)
	await process_frame
	await physics_frame
	var y := p.y
	for i in range(15):
		var d := InputEventScreenDrag.new()
		d.index = 0
		d.position = Vector2(p.x, y - 24)
		d.relative = Vector2(0, -24)
		d.velocity = Vector2(0, -900)
		y -= 24
		sub.push_input(d)
		if i == 7:
			print("   (no meio do arrasto: scroll_vertical=%d)" % sc.scroll_vertical)
		await process_frame
		await physics_frame
	var up := InputEventScreenTouch.new()
	up.index = 0; up.pressed = false; up.position = Vector2(p.x, y)
	sub.push_input(up)
	for i in range(5):
		await process_frame
		await physics_frame

func _rodar() -> void:
	print("touchscreen = ", DisplayServer.is_touchscreen_available(),
		"  emula mouse do toque = ", Input.is_emulating_mouse_from_touch())
	for modo in ["rotulos", "botoes", "botoes+"]:
		var sc := _montar(modo)
		for i in range(20):
			await process_frame
		sc.visto.clear()
		await _arrastar(sc)
		var tipos := {}
		for t in sc.visto:
			tipos[t] = int(tipos.get(t, 0)) + 1
		var por_toque := sc.scroll_vertical
		sc.scroll_vertical = 0
		sc.visto.clear()
		var pw := sc.global_position + sc.size * 0.5
		for i in range(3):
			for pressed in [true, false]:
				var mb := InputEventMouseButton.new()
				mb.button_index = MOUSE_BUTTON_WHEEL_DOWN
				mb.pressed = pressed
				mb.position = pw
				mb.global_position = pw
				sub.push_input(mb)
			await process_frame
		var tipos_roda := {}
		for t2 in sc.visto:
			tipos_roda[t2] = int(tipos_roda.get(t2, 0)) + 1
		print("%-9s toque -> %-5d %s | roda -> %-5d %s" % [
			modo, por_toque, tipos, sc.scroll_vertical, tipos_roda])
	quit(0)
