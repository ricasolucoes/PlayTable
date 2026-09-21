class_name MobileHudMetrics
extends RefCounted

## Métricas 2D compartilhadas pelo chrome e pelo conteúdo de um jogo mobile.
##
## Todos os retângulos vivem no espaço da viewport do Control. O topo seguro é
## somado à altura do chrome; o trilho inferior começa antes do inset de gesto e
## o conteúdo fica estritamente entre as duas bandas.

var viewport_size: Vector2 = Vector2.ZERO
var safe_insets: Vector4 = Vector4.ZERO
var chrome_rect: Rect2 = Rect2()
var content_rect: Rect2 = Rect2()
var bottom_rect: Rect2 = Rect2()


static func calculate(size: Vector2, insets: Vector4, chrome_height: float,
		bottom_height: float) -> MobileHudMetrics:
	var result := MobileHudMetrics.new()
	result.viewport_size = size
	result.safe_insets = insets

	var usable_left := clampf(insets.x, 0.0, size.x)
	var usable_right := clampf(size.x - insets.z, usable_left, size.x)
	var safe_top := maxf(0.0, insets.y)
	var safe_bottom := maxf(0.0, insets.w)
	var chrome_bottom := minf(size.y, safe_top + maxf(0.0, chrome_height))
	var bottom_top := maxf(chrome_bottom,
		size.y - safe_bottom - maxf(0.0, bottom_height))
	var usable_width := maxf(0.0, usable_right - usable_left)

	result.chrome_rect = Rect2(usable_left, safe_top, usable_width,
		maxf(0.0, chrome_bottom - safe_top))
	result.content_rect = Rect2(usable_left, chrome_bottom, usable_width,
		maxf(0.0, bottom_top - chrome_bottom))
	result.bottom_rect = Rect2(usable_left, bottom_top, usable_width,
		maxf(0.0, size.y - safe_bottom - bottom_top))
	return result


func resized(size: Vector2, insets: Vector4) -> MobileHudMetrics:
	return calculate(size, insets, chrome_rect.size.y, bottom_rect.size.y)


func rect_is_inside_viewport(rect: Rect2) -> bool:
	return rect.position.x >= safe_insets.x \
		and rect.position.y >= safe_insets.y \
		and rect.end.x <= viewport_size.x - safe_insets.z \
		and rect.end.y <= viewport_size.y - safe_insets.w
