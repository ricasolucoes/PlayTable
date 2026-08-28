extends Node

## Missoes diarias e semanais.
##
## O problema da versao anterior era simples e fatal: as missoes so eram
## sorteadas quando o dicionario salvo estava vazio. Assim que as tres
## primeiras ficavam `completed`, ficavam completas para sempre -- o jogador
## via "3/3 concluidas" no segundo dia e nunca mais ganhava nada por elas.
##
## Agora cada lote carrega a *janela* a que pertence (a data, para as diarias;
## o indice da semana, para as semanais). Ao abrir o app, missao de janela
## vencida e trocada por um lote novo.
##
## O sorteio e deterministico a partir da janela: fechar e reabrir o app no
## mesmo dia devolve exatamente as mesmas missoes. Sem isso o jogador reabriria
## o app ate cair uma missao facil.

const POOL_PATH := "res://core/configs/quests.json"

var _pool: Dictionary = {}
var quests: Dictionary = {}


func _ready() -> void:
	_load_pool()
	quests = PlayerProfile.get_active_quests()
	_migrar_formato_antigo()
	_roll_if_needed()

	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)
		GameEventBus.item_collected.connect(_on_item_collected)
		GameEventBus.mastery_leveled.connect(_on_mastery_leveled)


func _load_pool() -> void:
	if not FileAccess.file_exists(POOL_PATH):
		push_error("QuestEngine: pool ausente em %s" % POOL_PATH)
		return
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(POOL_PATH)) != OK:
		push_error("QuestEngine: pool invalido (%s)" % json.get_error_message())
		return
	_pool = json.data


## Missoes salvas pelo formato v1 nao tinham janela nem escopo. Descarta: sao
## no maximo tres missoes de um dia que ja passou.
func _migrar_formato_antigo() -> void:
	for id in quests.keys():
		if not quests[id].has("window"):
			quests = {}
			return


# ----------------------------------------------------------------- janelas

static func daily_window() -> String:
	return Time.get_date_string_from_system()


## Indice da semana contado em blocos de 7 dias desde a epoca, ancorado numa
## segunda-feira (1970-01-01 foi quinta; o deslocamento de 4 dias alinha).
static func weekly_window() -> String:
	var dias := int(Time.get_unix_time_from_system() / 86400.0)
	return "W%d" % int(floor((dias + 4) / 7.0))


func _roll_if_needed() -> void:
	var mudou := false
	mudou = _roll_scope("daily", daily_window()) or mudou
	if LiveOpsManager == null or LiveOpsManager.is_feature_enabled("weekly_quests", true):
		mudou = _roll_scope("weekly", weekly_window()) or mudou
	if mudou:
		_persist()


func _roll_scope(scope: String, window: String) -> bool:
	for id in quests.keys():
		if str(quests[id].get("scope", "")) == scope and str(quests[id].get("window", "")) == window:
			return false  # o lote desta janela ja existe

	for id in quests.keys().duplicate():
		if str(quests[id].get("scope", "")) == scope:
			quests.erase(id)

	var pool: Array = _pool.get(scope, [])
	if pool.is_empty():
		return false
	var quantas := int(_pool.get(scope + "_count", 3))

	for modelo in _sortear(pool, quantas, window):
		var qid := "%s:%s:%s" % [scope, window, modelo["id"]]
		quests[qid] = {
			"template": modelo["id"],
			"scope": scope,
			"window": window,
			"type": str(modelo["type"]),
			"category": str(modelo.get("category", "")),
			"target": int(modelo["target"]),
			"xp": int(modelo["xp"]),
			"progress": 0,
			"seen": [],
			"completed": false,
		}

	if GameEventBus:
		GameEventBus.quests_rolled.emit(scope)
	return true


## Sorteio estavel: a mesma janela sempre produz o mesmo lote.
func _sortear(pool: Array, quantas: int, window: String) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(window)
	var indices := range(pool.size())
	# Fisher-Yates com o RNG semeado -- `Array.shuffle()` usa o gerador global.
	for i in range(indices.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = indices[i]
		indices[i] = indices[j]
		indices[j] = tmp
	# No maximo uma missao de cada tipo por lote: sortear "jogue 2 jogos
	# diferentes" junto com "jogue 3 jogos diferentes" da ao jogador duas
	# missoes que ele fecha com a mesma acao, e o lote parece menor do que e.
	var saida: Array = []
	var tipos_usados := {}
	for i in indices:
		if saida.size() >= quantas:
			break
		var modelo: Dictionary = pool[i]
		var assinatura := str(modelo["type"]) + ":" + str(modelo.get("category", ""))
		if tipos_usados.has(assinatura):
			continue
		tipos_usados[assinatura] = true
		saida.append(modelo)
	return saida


# ---------------------------------------------------------------- progresso

func _on_match_completed(game_id: String, result: Dictionary) -> void:
	_roll_if_needed()

	var venceu := bool(result.get("win", false))
	var categoria := _categoria_de(game_id)

	_progredir("play", 1, game_id)
	if venceu:
		_progredir("win", 1, game_id)
		_progredir("win_category", 1, game_id, categoria)
		if bool(result.get("perfect", false)):
			_progredir("perfect", 1, game_id)
		var duracao := float(result.get("time", 0.0))
		if duracao > 0.0 and duracao < GamificationManager.SEGUNDOS_VITORIA_RAPIDA:
			_progredir("fast_win", 1, game_id)
	_progredir("distinct_games", 1, game_id)


func _on_item_collected(_item_id: String, amount: int) -> void:
	_progredir("collect", amount, "")


func _on_mastery_leveled(game_id: String, _new_level: int) -> void:
	_progredir("mastery_xp", 1, game_id)


func _categoria_de(game_id: String) -> String:
	return str(GameCatalog.categoria(game_id))


## `distinct_games` conta jogos diferentes, entao guarda quais ja apareceram
## nesta missao em vez de somar. Cada missao carrega a propria lista: assim a
## diaria e a semanal contam janelas diferentes sem estado global.
func _progredir(tipo: String, quanto: int, game_id: String, categoria: String = "") -> void:
	var mudou := false
	for qid in quests.keys():
		var q: Dictionary = quests[qid]
		if q["completed"] or str(q["type"]) != tipo:
			continue
		if tipo == "win_category" and str(q.get("category", "")) != categoria:
			continue

		if tipo == "distinct_games":
			if game_id == "" or q["seen"].has(game_id):
				continue
			q["seen"].append(game_id)
			q["progress"] = q["seen"].size()
		else:
			q["progress"] = int(q["progress"]) + quanto

		mudou = true
		if GameEventBus:
			GameEventBus.quest_progressed.emit(qid, int(q["progress"]), int(q["target"]))

		if int(q["progress"]) >= int(q["target"]):
			q["progress"] = int(q["target"])
			q["completed"] = true
			_concluir(qid, q)

	if mudou:
		_persist()


func _concluir(qid: String, q: Dictionary) -> void:
	PlayerProfile.increment_stat("quests_completed")
	if GameEventBus:
		GameEventBus.quest_completed.emit(qid)
	if RewardSystem:
		RewardSystem.grant_xp(int(q["xp"]), "quest:" + str(q["template"]))


func _persist() -> void:
	PlayerProfile.save_active_quests(quests)


# ---------------------------------------------------------------- consulta UI

## Missoes de um escopo, em ordem de leitura: pendentes antes das concluidas.
func quests_for_ui(scope: String = "") -> Array:
	var saida: Array = []
	for qid in quests.keys():
		var q: Dictionary = quests[qid]
		if scope != "" and str(q.get("scope", "")) != scope:
			continue
		saida.append({
			"id": qid,
			"scope": str(q.get("scope", "daily")),
			"template": str(q.get("template", "")),
			"type": str(q.get("type", "")),
			"progress": int(q.get("progress", 0)),
			"target": int(q.get("target", 1)),
			"xp": int(q.get("xp", 0)),
			"completed": bool(q.get("completed", false)),
			"name_key": "QUEST_" + str(q.get("template", "")).to_upper(),
		})
	saida.sort_custom(func(a, b):
		if a["completed"] != b["completed"]:
			return not a["completed"]
		return a["target"] < b["target"])
	return saida


func pending_count(scope: String = "") -> int:
	var n := 0
	for q in quests_for_ui(scope):
		if not q["completed"]:
			n += 1
	return n
