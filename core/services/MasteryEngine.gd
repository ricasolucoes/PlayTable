extends Node

## Trilha de proficiencia por jogo.
##
## O nivel do perfil mede o tempo total na coleção; a maestria mede quanto o
## jogador domina *aquele* jogo. Sao eixos diferentes de proposito: quem so
## joga Campo Minado sobe maestria rapido ali e continua no comeco dos outros
## 18, e a tela de perfil mostra os dois.
##
## A maestria nao paga XP de perfil a cada partida -- isso seria pagar duas
## vezes pela mesma vitoria. Paga so quando sobe de nivel de maestria.

const XP_PARTIDA := 10
const XP_VITORIA := 50
const XP_PERFEITA := 100
const XP_POR_NIVEL := 500
const XP_RECOMPENSA_NIVEL := 200
const NIVEL_MAXIMO := 50

var _mastery: Dictionary = {}


func _ready() -> void:
	_load()
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)


func _load() -> void:
	_mastery = PlayerProfile.get_stat("game_mastery", {})


func _save() -> void:
	PlayerProfile.set_stat("game_mastery", _mastery)


func _track(game_id: String) -> Dictionary:
	if not _mastery.has(game_id):
		_mastery[game_id] = {"level": 1, "xp": 0}
	return _mastery[game_id]


func get_mastery_level(game_id: String) -> int:
	return int(_track(game_id).get("level", 1))


func get_mastery_xp(game_id: String) -> int:
	return int(_track(game_id).get("xp", 0))


## XP necessario para sair do nivel atual daquele jogo.
func xp_for_next(game_id: String) -> int:
	return get_mastery_level(game_id) * XP_POR_NIVEL


func highest_mastery() -> int:
	var maior := 0
	for id in _mastery.keys():
		maior = maxi(maior, int(_mastery[id].get("level", 1)))
	return maior


func _on_match_completed(game_id: String, result: Dictionary) -> void:
	var t := _track(game_id)
	var ganho := XP_PARTIDA
	if bool(result.get("win", false)):
		ganho = XP_VITORIA
		if bool(result.get("perfect", false)):
			ganho += XP_PERFEITA

	t["xp"] = int(t.get("xp", 0)) + ganho
	_subir_niveis(game_id, t)
	_save()


func _subir_niveis(game_id: String, t: Dictionary) -> void:
	var subiu := 0
	while int(t["level"]) < NIVEL_MAXIMO and int(t["xp"]) >= int(t["level"]) * XP_POR_NIVEL:
		t["xp"] = int(t["xp"]) - int(t["level"]) * XP_POR_NIVEL
		t["level"] = int(t["level"]) + 1
		subiu += 1

	if subiu <= 0:
		return

	if GameEventBus:
		GameEventBus.mastery_leveled.emit(game_id, int(t["level"]))
	if RewardSystem:
		RewardSystem.grant_xp(XP_RECOMPENSA_NIVEL * subiu, "mastery:" + game_id)


## Maestria de todos os jogos ja tocados, para a tela de perfil.
func mastery_for_ui() -> Array:
	var saida: Array = []
	for def in GameCatalog.get_all_games():
		var id := GameCatalog.game_id_of(def)
		var g: Dictionary = PlayerProfile.per_game.get(id, {})
		if int(g.get("matches", 0)) <= 0:
			continue
		saida.append({
			"id": id,
			"title": def.display_name(),
			"icon": def.icon,
			"level": get_mastery_level(id),
			"xp": get_mastery_xp(id),
			"xp_next": xp_for_next(id),
			"matches": int(g.get("matches", 0)),
			"wins": int(g.get("wins", 0)),
			"best_time": int(g.get("best_time", 0)),
		})
	saida.sort_custom(func(a, b):
		if a["level"] != b["level"]:
			return a["level"] > b["level"]
		return a["xp"] > b["xp"])
	return saida
