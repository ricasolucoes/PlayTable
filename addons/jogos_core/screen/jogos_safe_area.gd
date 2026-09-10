class_name JogosSafeArea
extends RefCounted

## Recorte seguro da tela (notch, barra de status, barra de gestos) em unidades
## da viewport, que e o espaco em que todo Control trabalha.
##
## Fonte: VOLTA `src/ui/design_system/safe_area.gd`. Tirado: nada.
##
## `DisplayServer.get_display_safe_area()` engana de duas formas:
## 1. Unidade: devolve pixels do sistema; a UI vive na viewport base e o
##    aparelho renderiza numa janela de outro tamanho.
## 2. Origem: em desktop devolve a AREA DE TRABALHO em coordenadas de tela.
##    Num Mac com dois monitores mediu `[P: (2940, 1292), S: (5120, 2100)]` e
##    1292 virou "altura do notch", empurrando a HUD para o meio da tela.
## So e recorte de verdade quando cabe dentro da janela; fora disso e zero.


## Devolve (esquerda, topo, direita, baixo) em unidades da viewport.
static func insets(viewport: Viewport) -> Vector4:
	if viewport == null:
		return Vector4.ZERO
	var window: Vector2i = DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		return Vector4.ZERO
	var safe: Rect2i = DisplayServer.get_display_safe_area()
	return insets_from(safe, window, viewport.get_visible_rect().size)


## Conta pura, para teste sem tela: converte o recorte do sistema para a
## viewport e rejeita o que nao cabe na janela.
static func insets_from(safe: Rect2i, window: Vector2i, visible: Vector2) -> Vector4:
	if window.x <= 0 or window.y <= 0:
		return Vector4.ZERO
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector4.ZERO
	if safe.size.x > window.x or safe.size.y > window.y:
		return Vector4.ZERO
	if safe.position.x < 0 or safe.position.y < 0:
		return Vector4.ZERO
	if safe.position.x + safe.size.x > window.x or safe.position.y + safe.size.y > window.y:
		return Vector4.ZERO
	var scale_x: float = visible.x / float(window.x)
	var scale_y: float = visible.y / float(window.y)
	return Vector4(
		float(safe.position.x) * scale_x,
		float(safe.position.y) * scale_y,
		float(window.x - (safe.position.x + safe.size.x)) * scale_x,
		float(window.y - (safe.position.y + safe.size.y)) * scale_y
	)


static func top(viewport: Viewport) -> float:
	return insets(viewport).y


static func bottom(viewport: Viewport) -> float:
	return insets(viewport).w
