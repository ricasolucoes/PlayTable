class_name JogosLoadingOverlay
extends CanvasLayer

## Véu de transição: escurece, bloqueia o toque durante a troca de cena e
## mostra o progresso da carga em thread.
##
## Fonte: o overlay do PlayTable `core/navegacao/SceneManager.gd` (ColorRect
## em CanvasLayer, `mouse_filter` alternando STOP/IGNORE). Acrescentado: a
## barra de progresso e o respeito a `reduced_motion` (fade instantâneo).
## Montado em código para o jogo não precisar de um `.tscn` da lib.

const LAYER: int = 128

var veil: ColorRect
var bar: ProgressBar
var _tween: Tween


func _init() -> void:
	layer = LAYER
	veil = ColorRect.new()
	veil.name = "Veil"
	veil.color = Color(0, 0, 0, 0)
	veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	bar = ProgressBar.new()
	bar.name = "Progress"
	bar.min_value = 0.0
	bar.max_value = 1.0
	bar.value = 0.0
	bar.show_percentage = false
	bar.visible = false
	bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	bar.offset_left = -160.0
	bar.offset_right = 160.0
	bar.offset_top = -80.0
	bar.offset_bottom = -68.0
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veil.add_child(bar)


func block_input(block: bool) -> void:
	veil.mouse_filter = Control.MOUSE_FILTER_STOP if block else Control.MOUSE_FILTER_IGNORE


func set_progress(ratio: float) -> void:
	bar.value = clampf(ratio, 0.0, 1.0)


func show_progress(show: bool) -> void:
	bar.visible = show
	if show:
		bar.value = 0.0


func is_opaque() -> bool:
	return veil.color.a >= 0.999


## Escurece. `duration <= 0` é imediato (reduced motion ou teste headless).
func fade_in(duration: float) -> void:
	await _fade_to(1.0, duration)


func fade_out(duration: float) -> void:
	await _fade_to(0.0, duration)
	show_progress(false)


func _fade_to(alpha: float, duration: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	if duration <= 0.0 or not is_inside_tree():
		veil.color.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(veil, "color:a", alpha, duration)
	await _tween.finished
