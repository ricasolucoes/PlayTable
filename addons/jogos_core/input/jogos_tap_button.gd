class_name JogosTapButton
extends Button

signal tapped

## Button de interface que trata o toque cru do iOS.
##
## Em alguns runtimes iOS o toque chega como `InputEventScreenTouch`, mas o
## `BaseButton` só conclui o clique depois da ponte de mouse emulada. Essa
## ponte é útil no desktop, porém não é uma base segura para a navegação do
## aplicativo. Este botão aceita as duas famílias de evento e emite `tapped`
## e `pressed` uma única vez.
##
## O filtro continua em PASS para não impedir o `DragScroll` do pai. Um toque
## que passa da zona morta é cancelado; portanto arrastar a lista não abre um
## jogo ao levantar o dedo.

const ZONA_MORTA := 24.0

var _dedo := -1
var _origem := Vector2.ZERO
var _cancelado := false
var _mouse_pressionado := false
var _toque_visto := false
var _apertado_visualmente := false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	# O sinal pressed e a navegação serão emitidos pelo caminho explícito abaixo.
	# Desligar a máscara nativa evita que o mouse emulado do mesmo dedo dispare
	# duas vezes.
	button_mask = 0


func _ready() -> void:
	if not gui_input.is_connected(_on_gui_input):
		gui_input.connect(_on_gui_input)


func _notification(what: int) -> void:
	if what == NOTIFICATION_SCROLL_BEGIN or what == NOTIFICATION_APPLICATION_PAUSED:
		_cancelar()


func _on_gui_input(evento: InputEvent) -> void:
	if evento is InputEventScreenTouch:
		_toque_visto = true
		var toque := evento as InputEventScreenTouch
		if toque.pressed and _dedo == -1:
			_dedo = toque.index
			_origem = toque.position
			_cancelado = false
			_definir_apertado(true)
		elif not toque.pressed and toque.index == _dedo:
			_definir_apertado(false)
			if not _cancelado and Rect2(Vector2.ZERO, size).has_point(toque.position):
				_emitir_tapped()
			_dedo = -1
			if is_inside_tree():
				await get_tree().process_frame
			_toque_visto = false
		return

	if evento is InputEventScreenDrag:
		var arrasto := evento as InputEventScreenDrag
		if arrasto.index == _dedo and arrasto.position.distance_to(_origem) >= ZONA_MORTA:
			_cancelado = true
			_definir_apertado(false)
		return

	# Quando o iOS fornece o toque cru, o mouse que pode vir logo depois é
	# apenas a emulação da mesma ação. O caminho explícito acima já tratou dele.
	if evento is InputEventMouseButton:
		if _toque_visto:
			return
		var mouse := evento as InputEventMouseButton
		if mouse.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse.pressed:
			_mouse_pressionado = true
			_origem = mouse.position
			_cancelado = false
			_definir_apertado(true)
		elif _mouse_pressionado:
			_definir_apertado(false)
			if not _cancelado and Rect2(Vector2.ZERO, size).has_point(mouse.position):
				_emitir_tapped()
			_mouse_pressionado = false
		return

	if evento is InputEventMouseMotion and _mouse_pressionado:
		var movimento := evento as InputEventMouseMotion
		if movimento.position.distance_to(_origem) >= ZONA_MORTA:
			_cancelado = true
			_definir_apertado(false)


func _definir_apertado(apertado: bool) -> void:
	if _apertado_visualmente == apertado:
		return
	_apertado_visualmente = apertado
	if apertado:
		button_down.emit()
	else:
		button_up.emit()


func _emitir_tapped() -> void:
	tapped.emit()


func _cancelar() -> void:
	_definir_apertado(false)
	_dedo = -1
	_mouse_pressionado = false
	_cancelado = true
	_toque_visto = false
