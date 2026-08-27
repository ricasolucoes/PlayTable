extends Node

## Colecao de itens cosmeticos e o que os desbloqueia.
##
## Sem isto o progresso nao tinha destino: o jogador subia de nivel e nada
## mudava na mesa. Aqui cada faixa de nivel, liga e maestria libera um item
## visivel -- feltro da mesa, verso de carta, moldura de avatar --, e a tela de
## perfil mostra quanto falta para o proximo.
##
## Os itens sao declarativos de proposito: acrescentar um verso de carta novo e
## acrescentar uma linha, sem mexer em regra nenhuma.

const ITENS := [
	{"id": "felt_green",    "kind": "table",  "rule": {"type": "default"}},
	{"id": "felt_burgundy", "kind": "table",  "rule": {"type": "level", "value": 3}},
	{"id": "felt_navy",     "kind": "table",  "rule": {"type": "level", "value": 6}},
	{"id": "felt_slate",    "kind": "table",  "rule": {"type": "level", "value": 10}},
	{"id": "felt_amber",    "kind": "table",  "rule": {"type": "level", "value": 15}},
	{"id": "wood_oak",      "kind": "table",  "rule": {"type": "mastery", "value": 3}},
	{"id": "wood_walnut",   "kind": "table",  "rule": {"type": "mastery", "value": 6}},
	{"id": "marble_white",  "kind": "table",  "rule": {"type": "league", "value": "gold"}},
	{"id": "marble_black",  "kind": "table",  "rule": {"type": "league", "value": "diamond"}},

	{"id": "back_classic",  "kind": "card",   "rule": {"type": "default"}},
	{"id": "back_ornate",   "kind": "card",   "rule": {"type": "level", "value": 4}},
	{"id": "back_geometry", "kind": "card",   "rule": {"type": "level", "value": 8}},
	{"id": "back_gilded",   "kind": "card",   "rule": {"type": "achievement", "value": "ACH_POKER_WIN"}},

	{"id": "frame_bronze",  "kind": "avatar", "rule": {"type": "league", "value": "bronze"}},
	{"id": "frame_silver",  "kind": "avatar", "rule": {"type": "league", "value": "silver"}},
	{"id": "frame_gold",    "kind": "avatar", "rule": {"type": "league", "value": "gold"}},
	{"id": "frame_legend",  "kind": "avatar", "rule": {"type": "league", "value": "legend"}},
	{"id": "frame_streak",  "kind": "avatar", "rule": {"type": "streak", "value": 7}},
	{"id": "frame_platina", "kind": "avatar", "rule": {"type": "achievement", "value": "ACH_100_PERCENT"}},
]

var unlocked_items: Array = []


func _ready() -> void:
	unlocked_items = PlayerProfile.get_stat("collections_unlocked", [])
	if GameEventBus:
		GameEventBus.player_leveled_up.connect(_on_progress_int)
		GameEventBus.league_changed.connect(_on_league_changed)
		GameEventBus.mastery_leveled.connect(_on_mastery)
		GameEventBus.achievement_unlocked.connect(_on_progress_str)
		GameEventBus.daily_streak_updated.connect(_on_progress_int)
	evaluate_unlocks.call_deferred()


func _on_progress_int(_v: int) -> void: evaluate_unlocks()
func _on_progress_str(_v: String) -> void: evaluate_unlocks()
func _on_mastery(_a: String, _b: int) -> void: evaluate_unlocks()
func _on_league_changed(_a: String, _b: bool) -> void: evaluate_unlocks()


## Libera tudo que o jogador ja cumpriu e ainda nao tem. Roda inteiro em vez de
## reagir so ao evento que chegou: e barato (19 comparacoes) e cobre o perfil
## que veio da nuvem ja adiantado.
func evaluate_unlocks() -> void:
	for item in ITENS:
		if unlocked_items.has(item["id"]):
			continue
		if _cumpre(item["rule"]):
			unlock_item(str(item["id"]))


func _cumpre(rule: Dictionary) -> bool:
	match str(rule.get("type", "")):
		"default":
			return true
		"level":
			return PlayerProfile.level >= int(rule.get("value", 1))
		"streak":
			return PlayerProfile.current_streak >= int(rule.get("value", 1))
		"mastery":
			return MasteryEngine != null and MasteryEngine.highest_mastery() >= int(rule.get("value", 1))
		"achievement":
			return PlayerProfile.unlocked_achievements.has(str(rule.get("value", "")))
		"league":
			if LeagueSystem == null:
				return false
			return LeagueSystem._index_of(str(LeagueSystem.get_current_league()["id"])) \
				>= LeagueSystem._index_of(str(rule.get("value", "bronze")))
		_:
			return false


func unlock_item(item_id: String) -> bool:
	if unlocked_items.has(item_id):
		return false

	unlocked_items.append(item_id)
	PlayerProfile.set_stat("collections_unlocked", unlocked_items)
	PlayerProfile.set_stat("collection_items", unlocked_items.size())

	if GameEventBus:
		GameEventBus.reward_granted.emit(item_id, _kind_of(item_id))
	if PlayGamesManager:
		PlayGamesManager.submit_event("EV_ITEM_COLLECTED", 1)
	return true


func has_item(item_id: String) -> bool:
	return unlocked_items.has(item_id)


func equip(item_id: String) -> bool:
	if not has_item(item_id):
		return false
	var kind := _kind_of(item_id)
	if str(PlayerProfile.get_stat("equipped_" + kind, "")) == item_id:
		return false
	PlayerProfile.set_stat("equipped_" + kind, item_id)
	if kind == "table":
		PlayerProfile.set_flag("custom_board")
	return true


func equipped(kind: String) -> String:
	return str(PlayerProfile.get_stat("equipped_" + kind, _default_of(kind)))


func _kind_of(item_id: String) -> String:
	for item in ITENS:
		if item["id"] == item_id:
			return str(item["kind"])
	return "generic"


func _default_of(kind: String) -> String:
	for item in ITENS:
		if item["kind"] == kind and str(item["rule"].get("type", "")) == "default":
			return str(item["id"])
	return ""


func total_count() -> int:
	return ITENS.size()


func get_completion_percentage() -> float:
	return (float(unlocked_items.size()) / float(maxi(1, ITENS.size()))) * 100.0


## Colecao inteira com estado, para a tela de perfil: o que falta aparece
## bloqueado com a condicao a vista, nao escondido.
func collection_for_ui(kind: String = "") -> Array:
	var saida: Array = []
	for item in ITENS:
		if kind != "" and str(item["kind"]) != kind:
			continue
		saida.append({
			"id": str(item["id"]),
			"kind": str(item["kind"]),
			"unlocked": unlocked_items.has(item["id"]),
			"equipped": equipped(str(item["kind"])) == str(item["id"]),
			"rule": item["rule"],
			"name_key": "ITEM_" + str(item["id"]).to_upper(),
		})
	return saida
