class_name JogosSplitScreen
extends Control

## Tela dividida: 1 a 4 SubViewports em layout automatico, mesma cena de
## jogo, uma camera por jogador.
##
## Padrao do SuperTuxParty (viewport por jogador + compositor). Nao havia
## equivalente nos jogos da casa. A cena de jogo nao sabe o layout: chama
## `set_player_count(n)` e pendura a camera do jogador `i` em
## `get_camera_slot(i)`. Os SubViewports compartilham o mundo do pai
## (`own_world_3d = false`), entao um tabuleiro so e visto de N cameras.

signal layout_changed(count: int)

var _containers: Array[SubViewportContainer] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if not resized.is_connected(_relayout):
		resized.connect(_relayout)


func player_count() -> int:
	return _containers.size()


func set_player_count(count: int) -> void:
	count = clampi(count, 1, 4)
	while _containers.size() > count:
		var last: SubViewportContainer = _containers.pop_back()
		last.queue_free()
	while _containers.size() < count:
		var idx: int = _containers.size()
		var c: SubViewportContainer = SubViewportContainer.new()
		c.name = "Player%d" % (idx + 1)
		c.stretch = true
		var vp: SubViewport = SubViewport.new()
		vp.name = "Viewport"
		vp.handle_input_locally = false
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		c.add_child(vp)
		add_child(c)
		_containers.append(c)
	_relayout()
	layout_changed.emit(count)


## Jogador 1..N.
func get_viewport_for(player: int) -> SubViewport:
	var idx: int = player - 1
	if idx < 0 or idx >= _containers.size():
		return null
	return _containers[idx].get_node_or_null("Viewport") as SubViewport


## Onde a camera do jogador entra (o proprio SubViewport).
func get_camera_slot(player: int) -> Node:
	return get_viewport_for(player)


func _relayout() -> void:
	var rects: Array[Rect2] = layout_rects(_containers.size(), size)
	for i: int in _containers.size():
		_containers[i].position = rects[i].position
		_containers[i].size = rects[i].size


## Conta pura: retangulos para `count` jogadores num espaco `total`.
## 1 = tudo; 2 = lado a lado em paisagem, empilhado em retrato; 3 = dois em
## cima e um embaixo inteiro (grade 2x2 com a ultima linha unida); 4 = 2x2.
static func layout_rects(count: int, total: Vector2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	count = clampi(count, 1, 4)
	var w: float = total.x
	var h: float = total.y
	match count:
		1:
			out.append(Rect2(Vector2.ZERO, total))
		2:
			if w >= h:
				out.append(Rect2(0.0, 0.0, w * 0.5, h))
				out.append(Rect2(w * 0.5, 0.0, w * 0.5, h))
			else:
				out.append(Rect2(0.0, 0.0, w, h * 0.5))
				out.append(Rect2(0.0, h * 0.5, w, h * 0.5))
		3:
			out.append(Rect2(0.0, 0.0, w * 0.5, h * 0.5))
			out.append(Rect2(w * 0.5, 0.0, w * 0.5, h * 0.5))
			out.append(Rect2(0.0, h * 0.5, w, h * 0.5))
		_:
			out.append(Rect2(0.0, 0.0, w * 0.5, h * 0.5))
			out.append(Rect2(w * 0.5, 0.0, w * 0.5, h * 0.5))
			out.append(Rect2(0.0, h * 0.5, w * 0.5, h * 0.5))
			out.append(Rect2(w * 0.5, h * 0.5, w * 0.5, h * 0.5))
	return out
