class_name JogosBuild
extends RefCounted

## Fatos sobre a build: debug ou release, versão, ambiente, commit.
##
## Extraído de VOLTA `src/core/build.gd` + `build_flags.gd`. Generalização: o
## Resource `build_flags.tres` do VOLTA virou duas ProjectSettings opcionais
## (`jogos/build/debug_tools_enabled`, `jogos/build/commit_sha`) que o pipeline
## de export pode sobrescrever, e o nome da variável de ambiente
## (`VOLTA_ENV`) virou `env_var_name`, padrão `JOGOS_ENV`.
##
## `is_debug()` exige as duas coisas: build de debug do Godot E ferramentas
## habilitadas. Assim um APK de debug enviado a um testador pode desligar o
## overlay sem recompilar.

const SETTING_DEBUG_TOOLS: String = "jogos/build/debug_tools_enabled"
const SETTING_COMMIT: String = "jogos/build/commit_sha"

static var env_var_name: String = "JOGOS_ENV"
## Override em memória (testes e pipeline); `null` = ler da ProjectSettings.
static var debug_tools_override: Variant = null


static func is_debug() -> bool:
	return OS.is_debug_build() and debug_tools_enabled()


static func debug_tools_enabled() -> bool:
	if debug_tools_override != null:
		return bool(debug_tools_override)
	return bool(ProjectSettings.get_setting(SETTING_DEBUG_TOOLS, true))


static func version() -> String:
	var val: Variant = ProjectSettings.get_setting("application/config/version", "0.0.0")
	var s: String = str(val) if val != null else ""
	return "0.0.0" if s.is_empty() else s


static func commit() -> String:
	return str(ProjectSettings.get_setting(SETTING_COMMIT, "dev"))


static func env() -> String:
	if OS.has_environment(env_var_name):
		return OS.get_environment(env_var_name)
	return "development"


static func is_mobile() -> bool:
	return OS.has_feature("mobile")
