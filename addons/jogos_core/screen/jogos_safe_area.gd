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
	var win_w := float(window.x)
	var win_h := float(window.y)

	# No mobile, se window for zero ou menor que safe (pixels vs points no iOS),
	# tenta a resolucao real de tela do DisplayServer.
	if win_w <= 0.0 or win_h <= 0.0 or float(safe.size.x) > win_w or float(safe.size.y) > win_h:
		var screen: Vector2i = DisplayServer.screen_get_size()
		if screen.x > 0 and screen.y > 0 and float(safe.size.x) <= float(screen.x) and float(safe.size.y) <= float(screen.y):
			win_w = float(screen.x)
			win_h = float(screen.y)
		elif win_w > 0.0 and float(safe.size.x) > win_w:
			var densidade := float(safe.size.x) / win_w
			if densidade >= 1.5 and densidade <= 4.0:
				win_w *= densidade
				win_h *= densidade

	var top_inset: float = 0.0
	var bottom_inset: float = 0.0
	var left_inset: float = 0.0
	var right_inset: float = 0.0

	var valido := win_w > 0.0 and win_h > 0.0 \
		and safe.size.x > 0 and safe.size.y > 0 \
		and safe.position.x >= 0 and safe.position.y >= 0 \
		and float(safe.size.x) <= win_w and float(safe.size.y) <= win_h \
		and float(safe.position.x + safe.size.x) <= win_w * 1.05 \
		and float(safe.position.y + safe.size.y) <= win_h * 1.05

	if valido:
		var scale_x: float = visible.x / win_w
		var scale_y: float = visible.y / win_h
		left_inset = float(safe.position.x) * scale_x
		top_inset = float(safe.position.y) * scale_y
		right_inset = float(win_w - (safe.position.x + safe.size.x)) * scale_x
		bottom_inset = float(win_h - (safe.position.y + safe.size.y)) * scale_y
		# A folga de 5% acima pode deixar a borda direita/inferior negativa.
		right_inset = maxf(right_inset, 0.0)
		bottom_inset = maxf(bottom_inset, 0.0)

	# Garantia de seguranca para iPhone (iOS em retrato):
	# Em aparelhos com notch/Dynamic Island, o topo nunca e menor que ~44pt (68px em 720p)
	# e a barra inferior de gestos nunca e menor que ~34pt (38px em 720p).
	# Isso protege a interface mesmo durante o _ready() inicial antes do iOS reportar insets.
	if OS.get_name() == "iOS" and visible.y > visible.x:
		var scale_ref: float = visible.x / 720.0 if visible.x > 0.0 else 1.0
		top_inset = maxf(top_inset, 68.0 * scale_ref)
		bottom_inset = maxf(bottom_inset, 38.0 * scale_ref)

	return Vector4(left_inset, top_inset, right_inset, bottom_inset)


static func top(viewport: Viewport) -> float:
	return insets(viewport).y


static func bottom(viewport: Viewport) -> float:
	return insets(viewport).w
