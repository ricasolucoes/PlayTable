class_name JogosSpriteSheet
extends RefCounted

## Monta `SpriteFrames` a partir de uma imagem + `*.slices.json` da biblioteca
## central (`Assets/spritesheets/`, ver Assets/README.md §3). O recorte é dado
## pelo JSON, nunca a olho.
##
## Schema aceito (tudo além de `grid` ou `frames` é opcional):
## {
##   "image": "runner_v1.png",              # informativo; o PNG vem por parâmetro
##   "grid": [cols, rows],                   # ou "frame_size": [w, h]
##   "margin": 0, "spacing": 0,
##   "frames": [ {"name": "walk_0", "rect": [x, y, w, h]}, ... ],   # opcional
##   "animations": { "walk": {"frames": ["walk_0", "walk_1"] | [0, 1],
##                            "fps": 8, "loop": true} }             # opcional
## }
## Sem `animations`, os quadros são agrupados pelo prefixo antes do último
## `_<n>` do nome (`walk_0`, `walk_1` → "walk"); sem nome, tudo vira "default".

const DEFAULT_FPS: float = 8.0


static func frames_from_slices(image_path: String, slices_json_path: String) -> SpriteFrames:
	var texture: Texture2D = _load_texture(image_path)
	if texture == null:
		JogosLocator.log("warn", "assets", "sheet_image_missing", {"path": image_path})
		return null
	var content: String = FileAccess.get_file_as_string(slices_json_path)
	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		JogosLocator.log("warn", "assets", "sheet_slices_invalid", {"path": slices_json_path})
		return null
	return frames_from_dict(texture, parsed as Dictionary)


static func frames_from_dict(texture: Texture2D, slices: Dictionary) -> SpriteFrames:
	var rects: Array[Dictionary] = _frame_rects(texture, slices)
	if rects.is_empty():
		return null
	var frames: SpriteFrames = SpriteFrames.new()
	frames.remove_animation("default")
	var groups: Dictionary = _animations(slices, rects)
	for anim_name: Variant in groups.keys():
		var anim: Dictionary = groups[anim_name] as Dictionary
		var name: String = String(anim_name)
		frames.add_animation(name)
		frames.set_animation_speed(name, float(anim.get("fps", DEFAULT_FPS)))
		frames.set_animation_loop(name, bool(anim.get("loop", true)))
		for index: int in (anim["indices"] as Array):
			if index < 0 or index >= rects.size():
				continue
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = rects[index]["rect"] as Rect2
			frames.add_frame(name, atlas)
	return frames


static func _frame_rects(texture: Texture2D, slices: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if slices.has("frames") and slices["frames"] is Array:
		var i: int = 0
		for item: Variant in (slices["frames"] as Array):
			if not (item is Dictionary):
				continue
			var d: Dictionary = item as Dictionary
			var r: Array = d.get("rect", []) as Array
			if r.size() != 4:
				continue
			var rect: Rect2 = Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))
			out.append({"name": String(d.get("name", "frame_%d" % i)), "rect": rect})
			i += 1
		return out
	var size: Vector2 = texture.get_size()
	var margin: float = float(slices.get("margin", 0))
	var spacing: float = float(slices.get("spacing", 0))
	var cols: int = 0
	var rows: int = 0
	var fw: float = 0.0
	var fh: float = 0.0
	if slices.has("grid") and (slices["grid"] as Array).size() == 2:
		cols = int((slices["grid"] as Array)[0])
		rows = int((slices["grid"] as Array)[1])
		fw = (size.x - 2.0 * margin - spacing * float(cols - 1)) / float(cols)
		fh = (size.y - 2.0 * margin - spacing * float(rows - 1)) / float(rows)
	elif slices.has("frame_size") and (slices["frame_size"] as Array).size() == 2:
		fw = float((slices["frame_size"] as Array)[0])
		fh = float((slices["frame_size"] as Array)[1])
		cols = int(floor((size.x - 2.0 * margin + spacing) / (fw + spacing)))
		rows = int(floor((size.y - 2.0 * margin + spacing) / (fh + spacing)))
	if cols <= 0 or rows <= 0 or fw <= 0.0 or fh <= 0.0:
		return out
	var names: Array = slices.get("names", []) as Array
	var i: int = 0
	for row: int in range(rows):
		for col: int in range(cols):
			var rect: Rect2 = Rect2(margin + col * (fw + spacing), margin + row * (fh + spacing), fw, fh)
			var name: String = String(names[i]) if i < names.size() else "frame_%d" % i
			out.append({"name": name, "rect": rect})
			i += 1
	return out


static func _animations(slices: Dictionary, rects: Array[Dictionary]) -> Dictionary:
	var groups: Dictionary = {}
	var by_name: Dictionary = {}
	for i: int in range(rects.size()):
		by_name[String(rects[i]["name"])] = i
	if slices.has("animations") and slices["animations"] is Dictionary:
		for anim_name: Variant in (slices["animations"] as Dictionary).keys():
			var spec: Dictionary = (slices["animations"] as Dictionary)[anim_name] as Dictionary
			var indices: Array = []
			for ref: Variant in (spec.get("frames", []) as Array):
				if ref is float or ref is int:
					indices.append(int(ref))
				elif by_name.has(String(ref)):
					indices.append(int(by_name[String(ref)]))
			groups[String(anim_name)] = {
				"indices": indices, "fps": spec.get("fps", DEFAULT_FPS), "loop": spec.get("loop", true)
			}
		return groups
	for i: int in range(rects.size()):
		var prefix: String = _prefix(String(rects[i]["name"]))
		if not groups.has(prefix):
			groups[prefix] = {"indices": [], "fps": DEFAULT_FPS, "loop": true}
		(groups[prefix]["indices"] as Array).append(i)
	return groups


## "walk_03" → "walk"; "frame_7" → "default"; "idle" → "idle".
static func _prefix(name: String) -> String:
	if name.begins_with("frame_"):
		return "default"
	var us: int = name.rfind("_")
	if us > 0 and name.substr(us + 1).is_valid_int():
		return name.substr(0, us)
	return name


static func _load_texture(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return ResourceLoader.load(path, "Texture2D") as Texture2D
	if FileAccess.file_exists(path):
		var img: Image = Image.load_from_file(path)
		if img != null:
			return ImageTexture.create_from_image(img)
	return null
