class_name Quality3D
extends RefCounted

## Quality3D: Nivel de qualidade grafica e preferencia de movimento reduzido.
##
## Um unico lugar decide quanta sombra, particula e detalhe a cena pode gastar.
## Os componentes de shared/3d consultam este arquivo; nenhum jogo decide sozinho.

enum Tier {
	LOW,     ## Telefones modestos: sombra dura e curta, sem particulas ambientais.
	MEDIUM,  ## Padrao movel: sombra suave, particulas contidas.
	HIGH,    ## Desktop / telefones potentes: tudo ligado.
}

const SETTING_TIER := "gfx_quality_tier"
const SETTING_REDUCED_MOTION := "gfx_reduced_motion"

static var _tier: int = -1
static var _reduced_motion: int = -1

## Nivel efetivo. Detecta automaticamente na primeira consulta e guarda em cache.
static func tier() -> int:
	if _tier < 0:
		_tier = _load_tier()
	return _tier

static func set_tier(value: int) -> void:
	var novo := clampi(value, Tier.LOW, Tier.HIGH)
	var mudou := novo != tier()
	_tier = novo
	var save := _save_manager()
	if save:
		save.set_setting(SETTING_TIER, _tier)
	if mudou:
		_invalidate_generated_assets()


## Descarta o que foi gerado com o tier anterior.
##
## MeshBuilder3D guarda malhas construidas com Quality3D.radial_segments() e
## TextureFactory3D guarda texturas, e nenhuma das chaves de cache inclui o
## tier. As tres clear_cache() existiam para isto e ninguem as chamava: trocar a
## qualidade nao mudava nada do que ja tinha sido gerado, pelo resto da sessao.
static func _invalidate_generated_assets() -> void:
	MeshBuilder3D.clear_cache()
	MaterialFactory3D.clear_cache()

## Verdadeiro quando o jogador pediu menos movimento (ou o SO pediu por ele).
## Movimento reduzido encurta e simplifica: nunca remove a informacao da jogada.
static func reduced_motion() -> bool:
	if _reduced_motion < 0:
		var save := _save_manager()
		var stored: Variant = save.get_setting(SETTING_REDUCED_MOTION, null) if save else null
		if stored == null:
			_reduced_motion = 1 if _os_prefers_reduced_motion() else 0
		else:
			_reduced_motion = 1 if bool(stored) else 0
	return _reduced_motion == 1

static func set_reduced_motion(value: bool) -> void:
	_reduced_motion = 1 if value else 0
	var save := _save_manager()
	if save:
		save.set_setting(SETTING_REDUCED_MOTION, value)

## Escala a duracao de uma animacao conforme a preferencia de movimento.
## Retorna 0.0 quando o movimento deve ser suprimido por completo.
static func duration(seconds: float, essential: bool = true) -> float:
	if not reduced_motion():
		return seconds
	return seconds * 0.45 if essential else 0.0

## Quantas particulas a cena pode emitir para um pedido de `desired`.
static func particle_budget(desired: int) -> int:
	if reduced_motion():
		return 0
	match tier():
		Tier.LOW:
			return 0
		Tier.MEDIUM:
			return int(desired * 0.5)
		_:
			return desired

## Resolucao do mapa de sombra direcional.
static func shadow_map_size() -> int:
	match tier():
		Tier.LOW:
			return 1024
		Tier.MEDIUM:
			return 2048
		_:
			return 4096

## Se a cena pode gastar uma segunda luz com sombra.
static func allows_secondary_shadow() -> bool:
	return tier() >= Tier.MEDIUM

## Segmentos radiais para cilindros/esferas de peca.
static func radial_segments(base: int) -> int:
	match tier():
		Tier.LOW:
			return maxi(8, base / 2)
		Tier.MEDIUM:
			return maxi(12, int(base * 0.75))
		_:
			return base

# ---------------------------------------------------------------------------

static func _load_tier() -> int:
	var save := _save_manager()
	if save:
		var stored: Variant = save.get_setting(SETTING_TIER, null)
		if stored != null:
			return clampi(int(stored), Tier.LOW, Tier.HIGH)
	return _detect_tier()

## Heuristica conservadora: o alvo do projeto e movel, entao movel e o padrao.
static func _detect_tier() -> int:
	var os_name: String = OS.get_name()
	if os_name == "Android" or os_name == "iOS":
		var mem: int = int(OS.get_memory_info().get("physical", 0))
		if mem > 0 and mem < 3 * 1024 * 1024 * 1024:
			return Tier.LOW
		return Tier.MEDIUM
	return Tier.HIGH

static func _os_prefers_reduced_motion() -> bool:
	# Godot 4.3 nao expoe a preferencia do sistema; o padrao e movimento normal
	# e o jogador ajusta nas configuracoes. Centralizado aqui para quando expuser.
	return false

static func _save_manager() -> Node:
	var loop := Engine.get_main_loop()
	if loop is SceneTree:
		var root := (loop as SceneTree).root
		if root and root.has_node("SaveManager"):
			return root.get_node("SaveManager")
	return null
