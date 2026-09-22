class_name JogosHaptics
extends RefCounted

## Vibração do aparelho respeitando a preferência `haptics` do jogador.
##
## Extraído de VOLTA `src/presentation/haptics/haptic_service.gd`.
## Generalização: virou estático e por "tipo" de toque (`tap`, `light`,
## `medium`, `heavy`, `success`, `failure`) em vez de `play_seal/play_break`
## do jogo; o modo (`off`/`light`/`full`) vem de `AppSettings` quando existe.
## Só vibra em aparelho móvel; no editor e no desktop é silencioso.

const DURATIONS_MS: Dictionary = {
	"tap": 20,
	"light": 50,
	"medium": 100,
	"heavy": 200,
	"success": 120,
	"failure": 300,
}
const MODES: PackedStringArray = ["off", "light", "full"]


static func vibrate(kind: String = "tap") -> void:
	var ms: int = duration_for(kind, current_mode())
	if ms <= 0:
		return
	if JogosBuild.is_mobile():
		Input.vibrate_handheld(ms)


## Puro, para teste: `light` corta a duração pela metade, `off` zera.
static func duration_for(kind: String, mode: String) -> int:
	if mode == "off":
		return 0
	var base: int = int(DURATIONS_MS.get(kind, DURATIONS_MS["tap"]))
	if mode == "light":
		return int(base * 0.5)
	return base


static func current_mode() -> String:
	var settings: Node = JogosLocator.autoload(&"AppSettings")
	if settings != null and settings.has_method("haptics"):
		var mode: String = str(settings.call("haptics"))
		if MODES.has(mode):
			return mode
	return "full"
