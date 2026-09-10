class_name JogosQuality
extends RefCounted

## Degraus de qualidade gráfica e detecção do aparelho.
##
## Extraído de TWFS `client/scripts/performance/quality_preset_manager.gd`
## (tabela de presets, `detect_device_preset`) e VOLTA
## `src/presentation/quality_service.gd` (`scaling_3d_scale`, `Engine.max_fps`).
## Generalização: três degraus (`low`/`medium`/`high`) mais `auto`, como o
## CONTRACTS §4.4 pede — o `ultra` do TWFS não tem alvo em telefone. Estático
## e sem estado; quem persiste é `AppSettings.quality_tier`.

const TIERS: PackedStringArray = ["low", "medium", "high"]
const AUTO: String = "auto"
const DEFAULT_TIER: String = "medium"

const CONFIGS: Dictionary = {
	"low": {
		"target_fps": 30,
		"scaling_3d": 0.75,
		"msaa_3d": Viewport.MSAA_DISABLED,
		"shadows_enabled": false,
		"particle_density": 0.3,
	},
	"medium": {
		"target_fps": 60,
		"scaling_3d": 1.0,
		"msaa_3d": Viewport.MSAA_DISABLED,
		"shadows_enabled": true,
		"particle_density": 0.6,
	},
	"high": {
		"target_fps": 60,
		"scaling_3d": 1.0,
		"msaa_3d": Viewport.MSAA_2X,
		"shadows_enabled": true,
		"particle_density": 1.0,
	},
}


static func is_valid(tier: String) -> bool:
	return tier == AUTO or TIERS.has(tier)


static func config_for(tier: String) -> Dictionary:
	var resolved: String = resolve(tier)
	return (CONFIGS.get(resolved, CONFIGS[DEFAULT_TIER]) as Dictionary).duplicate()


## `auto` vira um degrau concreto pelo hardware; degrau inválido vira o padrão.
static func resolve(tier: String) -> String:
	if tier == AUTO:
		return auto_detect()
	return tier if TIERS.has(tier) else DEFAULT_TIER


static func auto_detect() -> String:
	var ram_mb: int = int(OS.get_memory_info().get("physical", 0) / (1024 * 1024))
	return detect_tier(ram_mb, OS.get_processor_count())


## Puro, para teste. RAM desconhecida (0) não rebaixa: decide só pelos núcleos.
static func detect_tier(ram_mb: int, processor_count: int) -> String:
	if processor_count <= 4 or (ram_mb > 0 and ram_mb < 3072):
		return "low"
	if processor_count <= 6 or (ram_mb > 0 and ram_mb < 5120):
		return "medium"
	return "high"


## Aplica o degrau ao motor e ao viewport dado (nulo = só `Engine`). Devolve a
## configuração aplicada para o jogo ajustar o que é dele (partículas, sombras).
static func apply(tier: String, viewport: Viewport = null) -> Dictionary:
	var config: Dictionary = config_for(tier)
	Engine.max_fps = int(config["target_fps"])
	if viewport != null:
		viewport.scaling_3d_scale = float(config["scaling_3d"])
		viewport.msaa_3d = int(config["msaa_3d"]) as Viewport.MSAA
	return config
