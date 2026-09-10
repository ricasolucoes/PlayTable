class_name JogosGameDefinition
extends Resource

## Uma entrada do catálogo de jogos: o que aparece no menu e onde a cena
## mora. Fonte: PlayTable `core/configs/GameDefinition.gd`. Generalizado:
## modos como strings (`solo`, `ai`, `versus`, `online`) em vez de bandeira
## int, `min/max_players`, `tags`, `duration_sec`, `preview` (o `game.json`
## do SuperTuxParty), e o nome vem do LocaleManager quando ele existe.

const MODE_SOLO: String = "solo"
const MODE_AI: String = "ai"
const MODE_VERSUS: String = "versus"
const MODE_ONLINE: String = "online"

@export var id: String = ""
## Chave de tradução; `display_name()` resolve. `title` sozinho não é rótulo.
@export var title_key: String = ""
@export var description_key: String = ""
@export var icon: String = ""
@export var scene_path: String = ""
@export var category: StringName = &""
@export var genre_key: String = ""
@export var min_players: int = 1
@export var max_players: int = 1
@export var modes: Array[String] = []
@export var tags: Array[String] = []
@export var duration_sec: int = 0
@export var preview: String = ""
## Nível mínimo para destravar; 1 = sempre aberto.
@export var unlock_level: int = 1
@export var is_implemented: bool = true


static func create(p_id: String, p_title_key: String, p_scene_path: String,
		p_category: StringName = &"", p_icon: String = "") -> JogosGameDefinition:
	var def := JogosGameDefinition.new()
	def.id = p_id
	def.title_key = p_title_key
	def.scene_path = p_scene_path
	def.category = p_category
	def.icon = p_icon
	return def


func tagged(p_genre_key: String, p_modes: Array[String]) -> JogosGameDefinition:
	genre_key = p_genre_key
	modes = p_modes.duplicate()
	return self


func locked_until(level: int) -> JogosGameDefinition:
	unlock_level = level
	return self


func players(p_min: int, p_max: int) -> JogosGameDefinition:
	min_players = p_min
	max_players = p_max
	return self


func has_mode(mode: String) -> bool:
	return modes.has(mode)


func has_tag(tag: String) -> bool:
	return tags.has(tag)


func supports_players(count: int) -> bool:
	return count >= min_players and count <= max_players


func is_unlocked(level: int) -> bool:
	return level >= unlock_level


func display_name() -> String:
	return _translate(title_key)


func display_description() -> String:
	return _translate(description_key) if description_key != "" else ""


func display_genre() -> String:
	return _translate(genre_key) if genre_key != "" else ""


## `TranslationServer.translate` e não `tr()`: Resource não é Node. Quando o
## LocaleManager da lib existe, ele cobre também os dicionários JSON.
func _translate(key: String) -> String:
	if key == "":
		return ""
	var locale: Node = JogosLocator.autoload(&"LocaleManager")
	if locale != null and locale.has_method("t"):
		return str(locale.call("t", key))
	return TranslationServer.translate(key)


func to_dict() -> Dictionary:
	return {
		"id": id, "title_key": title_key, "description_key": description_key,
		"icon": icon, "scene_path": scene_path, "category": String(category),
		"genre_key": genre_key, "min_players": min_players,
		"max_players": max_players, "modes": modes.duplicate(),
		"tags": tags.duplicate(), "duration_sec": duration_sec,
		"preview": preview, "unlock_level": unlock_level,
		"is_implemented": is_implemented,
	}


## Lê o `game.json`. `base_dir` resolve `scene_path`/`preview` relativos
## (`"scene": "main.tscn"` → `res://games/x/main.tscn`).
static func from_dict(d: Dictionary, base_dir: String = "") -> JogosGameDefinition:
	var def := JogosGameDefinition.new()
	def.id = str(d.get("id", base_dir.get_file() if base_dir != "" else ""))
	def.title_key = str(d.get("title_key", d.get("title", "")))
	def.description_key = str(d.get("description_key", d.get("description", "")))
	def.icon = str(d.get("icon", ""))
	def.scene_path = _resolve(str(d.get("scene_path", d.get("scene", ""))), base_dir)
	def.category = StringName(str(d.get("category", "")))
	def.genre_key = str(d.get("genre_key", d.get("genre", "")))
	def.min_players = int(d.get("min_players", 1))
	def.max_players = int(d.get("max_players", maxi(def.min_players, 1)))
	for m: Variant in d.get("modes", []):
		def.modes.append(str(m))
	for t: Variant in d.get("tags", []):
		def.tags.append(str(t))
	def.duration_sec = int(d.get("duration_sec", d.get("duration_seconds", 0)))
	def.preview = _resolve(str(d.get("preview", d.get("preview_image", ""))), base_dir)
	def.unlock_level = int(d.get("unlock_level", 1))
	def.is_implemented = bool(d.get("is_implemented", true))
	return def


static func _resolve(path: String, base_dir: String) -> String:
	if path == "" or path.begins_with("res://") or path.begins_with("user://") or base_dir == "":
		return path
	return base_dir.path_join(path)
