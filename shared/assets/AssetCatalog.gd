class_name AssetCatalog
extends RefCounted

## Acesso central as texturas de `shared/assets/`.
##
## Duas familias. A arte GERADA por jogo (`get_game_art`) mora em
## `shared/assets/<jogo>/<nome>.png`, o caminho que `tools/gen_art.py` grava
## a partir dos manifestos de `tools/art/`. E os tres PNG legados que o Memoria
## ainda carrega (`get_card_back`, `get_gem`), unicos sobreviventes de um lote
## de 32 do qual 29 nunca foram lidos por cena nenhuma.
##
## Arquivo que nao existe devolve `null`, de proposito: quem consome tem um
## fallback procedural, e a cena nao pode depender de a cota do Gemini ter
## liberado a imagem naquele dia.

const ROOT := "res://shared/assets/"
const CARDS_DIR := ROOT + "cards/"
const REWARDS_DIR := ROOT + "rewards/"

## draw_texture_rect guarda o RID, nao uma referencia forte ao Resource.
## Sem este cache a textura local de MemoryCard._draw() morre antes do render
## e as cartas viram retangulos brancos, mesmo com o PNG presente.
static var _textures: Dictionary = {}


## A arte gerada de um jogo: `get_game_art("damas", "peca_escura")`.
static func get_game_art(game_id: String, key: String) -> Texture2D:
	return _load_texture(game_art_path(game_id, key))


## O mesmo, pela chave composta "<jogo>/<nome>" que `Token3D.art_by_material`
## e `MaterialFactory3D.get_textured()` carregam.
static func get_game_art_by_key(art_key: String) -> Texture2D:
	var partes := art_key.split("/", false)
	if partes.size() != 2:
		return null
	return get_game_art(partes[0], partes[1])


static func has_game_art(game_id: String, key: String) -> bool:
	return ResourceLoader.exists(game_art_path(game_id, key))


static func game_art_path(game_id: String, key: String) -> String:
	return ROOT + game_id + "/" + key + ".png"


# --- Legado do Memoria ---

static func get_card_back(color: String = "blue") -> Texture2D:
	var filename := "card_back_%s.png" % color.to_lower()
	return _load_texture(CARDS_DIR + filename)


static func get_gem(gem_type: String = "ruby") -> Texture2D:
	var filename := "gem_%s.png" % gem_type.to_lower()
	return _load_texture(REWARDS_DIR + filename)


static func _load_texture(path: String) -> Texture2D:
	if _textures.has(path):
		return _textures[path] as Texture2D
	if ResourceLoader.exists(path):
		var texture := load(path) as Texture2D
		_textures[path] = texture
		return texture
	return null
