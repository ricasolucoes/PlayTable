extends Node

## Autoload `AssetLoader`: cache de recursos + catálogo JSON + spritesheets da
## biblioteca central, sem `class_name`. Raiz padrão `res://assets`, que é para
## onde `tools/sync_assets.sh` de cada jogo copia a biblioteca central.

var cache: JogosAssetCache = JogosAssetCache.new()
var catalog: JogosJsonCatalog = JogosJsonCatalog.new()

var asset_root: String = "res://assets":
	set(value):
		asset_root = value
		cache.asset_root = value


func texture(path: String) -> Texture2D:
	return cache.texture(path)


func get_resource(path: String, type_hint: String = "") -> Resource:
	return cache.get_resource(path, type_hint)


func load_async(path: String, type_hint: String = "") -> Resource:
	var res: Resource = await cache.load_async(path, type_hint)
	return res


func preload_many(paths: Array[String]) -> int:
	return cache.preload_many(paths)


func clear_cache() -> void:
	cache.clear_cache()


func exists(path: String) -> bool:
	return cache.exists(path)


func catalog_scan(dir: String, override_dir: String = "user://game-data") -> int:
	return catalog.scan(cache.resolve(dir), override_dir)


func catalog_entry(category: String, id: String) -> Dictionary:
	return catalog.get_entry(category, id)


func catalog_ids(category: String) -> PackedStringArray:
	return catalog.list_ids(category)


func sprite_frames(image_path: String, slices_json_path: String) -> SpriteFrames:
	return JogosSpriteSheet.frames_from_slices(cache.resolve(image_path), cache.resolve(slices_json_path))
