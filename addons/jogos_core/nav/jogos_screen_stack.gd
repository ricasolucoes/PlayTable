class_name JogosScreenStack
extends Control

## Pilha de telas dentro de uma mesma cena (menu → configurações → créditos).
##
## Fonte: VOLTA `src/ui/navigation/screen_stack.gd`. Tirado: injeção de
## `ThemeService`. Mantido o `MOUSE_FILTER_IGNORE` no `_init`: o stack é um
## contêiner de navegação, não superfície de toque — com o filtro padrão ele
## engolia todo toque em tela cheia e o `InputRouter` nunca era chamado.

signal changed(depth: int)

var _stack: Array[JogosScreen] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func push(screen: JogosScreen, args: Dictionary = {}) -> void:
	if not _stack.is_empty():
		_stack.back().on_focus_lost()
		_stack.back().hide()
	_stack.append(screen)
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.on_pushed(args)
	screen.show()
	screen.on_focus_gained()
	changed.emit(_stack.size())


func replace_root(screen: JogosScreen, args: Dictionary = {}) -> void:
	while not _stack.is_empty():
		_discard(_stack.pop_back())
	push(screen, args)


func pop() -> bool:
	if _stack.size() <= 1:
		return false
	_discard(_stack.pop_back())
	_stack.back().show()
	_stack.back().on_focus_gained()
	changed.emit(_stack.size())
	return true


func can_pop() -> bool:
	return _stack.size() > 1


func depth() -> int:
	return _stack.size()


func current() -> JogosScreen:
	return _stack.back() if not _stack.is_empty() else null


## Voltar: a tela do topo tenta primeiro; senão desempilha; `false` quando
## não há para onde voltar (o SceneManager decide o que fazer com isso).
func handle_back() -> bool:
	var top: JogosScreen = current()
	if top != null and top.handle_back_button():
		return true
	return pop()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and handle_back():
		get_viewport().set_input_as_handled()


func _discard(screen: JogosScreen) -> void:
	screen.on_focus_lost()
	screen.on_popped()
	screen.queue_free()
