class_name JogosDesignUnits
extends RefCounted

## Converte dp (unidade fisica) em unidades da viewport base do projeto.
##
## Fonte: VOLTA `src/ui/design_system/tokens/design_units.gd`. Tirado: nada;
## so o nome. A viewport base varia por jogo (720, 1080...) e sai do
## `project.godot`; o telefone de referencia tem 390 dp de largura. Escrever
## `font_size = 16` num Control da 5,8 dp numa base de 1080 -- ilegivel a meio
## metro do rosto. Toda medida de UI passa por aqui.

const REFERENCE_WIDTH_DP: float = 390.0
const FALLBACK_VIEWPORT_WIDTH: float = 720.0


static func base_viewport_width() -> float:
	var configured: float = float(ProjectSettings.get_setting("display/window/size/viewport_width", 0))
	if configured <= 0.0:
		return FALLBACK_VIEWPORT_WIDTH
	return configured


static func units_per_dp() -> float:
	return base_viewport_width() / REFERENCE_WIDTH_DP


static func to_units(dp: float) -> float:
	return dp * units_per_dp()


static func to_int_units(dp: float) -> int:
	return int(round(to_units(dp)))


static func to_size(dp_x: float, dp_y: float) -> Vector2:
	return Vector2(to_units(dp_x), to_units(dp_y))
