class_name JogosSafeAreaContainer
extends MarginContainer

## Wrapper de tela que aplica o recorte seguro como margem.
##
## Fonte: VOLTA `src/ui/components/safe_area_container.gd`. Tirado: nada.
## As margens saem de `JogosSafeArea`, que ignora o que em desktop e area de
## trabalho e nao notch -- usar o numero cru punha 1292 unidades de margem no
## topo num Mac.


func _ready() -> void:
	var root: Window = get_tree().get_root()
	if root != null and not root.size_changed.is_connected(_apply_safe_area):
		root.size_changed.connect(_apply_safe_area)
	_apply_safe_area()


func _apply_safe_area() -> void:
	var insets: Vector4 = JogosSafeArea.insets(get_viewport())
	add_theme_constant_override("margin_left", int(insets.x))
	add_theme_constant_override("margin_top", int(insets.y))
	add_theme_constant_override("margin_right", int(insets.z))
	add_theme_constant_override("margin_bottom", int(insets.w))
