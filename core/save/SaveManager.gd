extends "res://addons/jogos_core/save/save_manager_autoload.gd"

## Manages persistent user settings and unified save pipeline.
## Herda do SaveManager canônico de jogos_core mantendo compatibilidade legada.

const SAVE_PATH = "user://save_data.cfg"
const LEGACY_JSON_PATH = "user://config.save"
const LEGACY_PROFILE_PATH = "user://player_profile.cfg"
