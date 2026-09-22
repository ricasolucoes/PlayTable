class_name JogosAssetCache
extends RefCounted

## Cache de recursos por caminho, com carregamento em thread.
##
## Fonte: PlayTable/shared/assets/AssetCatalog.gd (cache estático de texturas:
## `draw_texture_rect` guarda só o RID, e sem referência forte a textura
## morria antes do render). Tirado: as famílias `get_game_art`/`get_card_back`
## do PlayTable — aqui a raiz é configurável e o caminho é relativo a ela.
## Arquivo ausente devolve `null` de propósito: quem consome tem fallback
## procedural e a cena não pode depender de a cota do Gemini ter liberado a
## imagem naquele dia.

var asset_root: String = "res://assets"
var _cache: Dictionary = {}


func resolve(path: String) -> String:
	if path.begins_with("res://") or path.begins_with("user://") or path.is_absolute_path():
		return path
	return asset_root.path_join(path)


func has(path: String) -> bool:
	return _cache.has(resolve(path))


func exists(path: String) -> bool:
	var full: String = resolve(path)
	return ResourceLoader.exists(full) or FileAccess.file_exists(full)


func get_resource(path: String, type_hint: String = "") -> Resource:
	var full: String = resolve(path)
	if _cache.has(full):
		return _cache[full] as Resource
	var res: Resource = null
	if ResourceLoader.exists(full):
		res = ResourceLoader.load(full, type_hint)
	elif full.begins_with("user://") and _is_image(full):
		res = _image_texture(full)
	if res != null:
		_cache[full] = res
	return res


func texture(path: String) -> Texture2D:
	return get_resource(path, "Texture2D") as Texture2D


## Carrega em thread e devolve quando pronto (`await`). Cache hit volta
## imediato.
func load_async(path: String, type_hint: String = "") -> Resource:
	var full: String = resolve(path)
	if _cache.has(full):
		return _cache[full] as Resource
	if not ResourceLoader.exists(full):
		return get_resource(path, type_hint)
	if ResourceLoader.load_threaded_request(full, type_hint) != OK:
		return null
	var loop: MainLoop = Engine.get_main_loop()
	var done: bool = false
	var result: Resource = null
	while not done:
		var status: ResourceLoader.ThreadLoadStatus = ResourceLoader.load_threaded_get_status(full)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			if loop is SceneTree:
				await (loop as SceneTree).process_frame
			else:
				OS.delay_msec(2)
		elif status == ResourceLoader.THREAD_LOAD_LOADED:
			result = ResourceLoader.load_threaded_get(full)
			done = true
		else:
			done = true
	if result != null:
		_cache[full] = result
	return result


func preload_many(paths: Array[String]) -> int:
	var loaded: int = 0
	for p: String in paths:
		if get_resource(p) != null:
			loaded += 1
	return loaded


func put(path: String, res: Resource) -> void:
	_cache[resolve(path)] = res


func clear_cache() -> void:
	_cache.clear()


func size() -> int:
	return _cache.size()


func _is_image(path: String) -> bool:
	var ext: String = path.get_extension().to_lower()
	return ext == "png" or ext == "jpg" or ext == "jpeg" or ext == "webp"


func _image_texture(path: String) -> Texture2D:
	var img: Image = Image.load_from_file(path)
	if img == null:
		return null
	return ImageTexture.create_from_image(img)
