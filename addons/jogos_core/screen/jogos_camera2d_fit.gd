class_name JogosCamera2DFit
extends Node

## Filho de uma Camera2D: enquadra `content_rect` (mundo) na area util medida
## da HUD, e reenquadra quando a janela muda.
##
## Fonte: VOLTA `src/presentation/camera/game_camera.gd` (frame_to,
## _apply_zoom) + PlayTable `BaseGame.fit_table` (medida da HUD, refit em dois
## quadros). Tirado: seguir o Runner, zoom por % de Claim, clamp na Arena --
## isso e do jogo. Sobra o que todo jogo 2D precisa: medir, encher, recentrar.

## Conteudo (mundo) que precisa caber na tela. Zero = nada a enquadrar.
@export var content_rect: Rect2 = Rect2()

## No cuja subarvore contem a HUD; vazio = a cena atual.
@export var hud_root: NodePath

## Folga ao redor do conteudo (fracao). 0,04 = 4%.
@export_range(0.0, 0.5, 0.005) var slack: float = JogosScreenFit.DEFAULT_SLACK

## Fator sobre o zoom calculado (1 = enche a faixa util). Jogos com zoom
## dinamico animam isto; o fit em si nao muda.
var zoom_multiplier: float = 1.0:
	set(value):
		zoom_multiplier = maxf(value, 0.0001)
		_apply()

var _usable: Rect2 = Rect2()
var _last_fit: Dictionary = {}


func _ready() -> void:
	JogosScreenFit.watch_resize(self, refit)


func camera() -> Camera2D:
	return get_parent() as Camera2D


func set_content(rect: Rect2) -> void:
	content_rect = rect
	refit()


## Mede a HUD e enquadra. Publico para quem mexe na HUD em runtime.
func refit() -> void:
	var cam: Camera2D = camera()
	if cam == null or not is_inside_tree():
		return
	var root: Node = get_node_or_null(hud_root) if not hud_root.is_empty() else get_tree().current_scene
	frame_to(JogosScreenFit.usable_rect(root, get_viewport()))


## Enquadra numa area util dada (viewport). Quem ja mediu chama direto.
func frame_to(usable: Rect2) -> void:
	_usable = usable
	_apply()


func last_fit() -> Dictionary:
	return _last_fit


func _apply() -> void:
	var cam: Camera2D = camera()
	if cam == null or content_rect.size.x <= 0.0 or content_rect.size.y <= 0.0:
		return
	if _usable.size.x <= 0.0 or _usable.size.y <= 0.0:
		return
	_last_fit = JogosScreenFit.fit_camera_2d(cam, content_rect, _usable, slack, zoom_multiplier)
