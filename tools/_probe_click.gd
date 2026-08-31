extends SceneTree

## Com o cartao em MOUSE_FILTER_PASS, soltar o dedo depois de arrastar abre o
## jogo? O ScrollContainer avisa os filhos com NOTIFICATION_SCROLL_BEGIN quando
## passa da zona morta; a pergunta e se o Button cancela o clique ao receber.

var sub: SubViewport
var disparou := false

func _initialize() -> void:
	sub = SubViewport.new()
	sub.size = Vector2i(720, 1280)
	sub.handle_input_locally = true
	root.add_child(sub)
	_rodar()

func _rodar() -> void:
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sub.add_child(sc)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(vb)
	var alvo: Button = null
	for i in range(20):
		var b := Button.new()
		b.text = "item %d" % i
		b.mouse_filter = Control.MOUSE_FILTER_PASS
		b.custom_minimum_size = Vector2(0, 200)
		vb.add_child(b)
		if i == 3:
			alvo = b
	alvo.pressed.connect(func() -> void: disparou = true)
	for i in range(20):
		await process_frame

	var p := alvo.global_position + alvo.size * 0.5
	print("NOTIFICATION_SCROLL_BEGIN = ", Control.NOTIFICATION_SCROLL_BEGIN)

	# 1) toque e solta sem arrastar -> tem de abrir o jogo
	await _toque(p, false)
	print("toque simples          -> pressed disparou? ", disparou)

	# 2) toque, o rolo avisa que comecou a rolar, e solta -> nao pode abrir
	disparou = false
	await _toque(p, true, sc)
	print("toque com rolagem      -> pressed disparou? ", disparou)
	quit(0)

func _toque(p: Vector2, rolando: bool, sc: ScrollContainer = null) -> void:
	var d := InputEventMouseButton.new()
	d.button_index = MOUSE_BUTTON_LEFT
	d.pressed = true
	d.position = p
	d.global_position = p
	sub.push_input(d)
	await process_frame
	if rolando:
		sc.propagate_notification(Control.NOTIFICATION_SCROLL_BEGIN)
		await process_frame
	var u := InputEventMouseButton.new()
	u.button_index = MOUSE_BUTTON_LEFT
	u.pressed = false
	u.position = p
	u.global_position = p
	sub.push_input(u)
	for i in range(3):
		await process_frame
