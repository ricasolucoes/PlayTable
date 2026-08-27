extends Node

## Motor de conquistas orientado a dados.
##
## O catalogo vive em `core/configs/achievements.json` -- 50 conquistas
## cobrindo os 19 jogos, progressao, persistencia, colecao e segredos. Esta
## classe nao sabe o nome de nenhuma delas: le a regra, calcula o valor atual,
## compara com o alvo. Adicionar conquista e editar JSON.
##
## O valor atual tambem e guardado (`achievement_progress`) porque a tela de
## perfil mostra barra de progresso -- "37/50 vitorias" motiva muito mais do
## que um cadeado fechado -- e porque o Play Games precisa do numero para as
## conquistas incrementais.

const CATALOG_PATH := "res://core/configs/achievements.json"

var _defs: Array = []
var _by_id: Dictionary = {}
var _evaluating: bool = false


func _ready() -> void:
	_load_catalog()
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_changed_unary)
		GameEventBus.item_collected.connect(_on_changed_binary)
		GameEventBus.player_leveled_up.connect(_on_changed_int)
		GameEventBus.daily_streak_updated.connect(_on_changed_int)
		GameEventBus.quest_completed.connect(_on_changed_str)
		GameEventBus.mastery_leveled.connect(_on_changed_binary)
	# Um perfil migrado da versao anterior pode ja cumprir conquistas que ainda
	# nao existiam. Avalia uma vez na entrada em vez de esperar a proxima
	# partida.
	_evaluate.call_deferred()


func _load_catalog() -> void:
	if not FileAccess.file_exists(CATALOG_PATH):
		push_error("AchievementEngine: catalogo ausente em %s" % CATALOG_PATH)
		return
	var texto := FileAccess.get_file_as_string(CATALOG_PATH)
	var json := JSON.new()
	if json.parse(texto) != OK:
		push_error("AchievementEngine: catalogo invalido (%s)" % json.get_error_message())
		return
	_defs = json.data.get("achievements", [])
	for d in _defs:
		_by_id[d["id"]] = d


# Adaptadores de assinatura: os sinais do barramento tem aridades diferentes e
# todos levam ao mesmo lugar.
func _on_changed_unary(_a: String, _b: Dictionary) -> void: _evaluate()
func _on_changed_binary(_a: String, _b: Variant) -> void: _evaluate()
func _on_changed_int(_a: int) -> void: _evaluate()
func _on_changed_str(_a: String) -> void: _evaluate()


# ------------------------------------------------------------------- avaliacao

## Reavalia o catalogo inteiro. Barato: 50 comparacoes de inteiro.
##
## A trava de reentrancia existe porque desbloquear paga XP, XP sobe nivel e
## nivel dispara nova avaliacao. Sem ela, `ACH_LEVEL_5` chamaria a si mesma no
## meio da propria concessao.
func _evaluate() -> void:
	if _evaluating or _defs.is_empty():
		return
	_evaluating = true

	var pendentes: Array = []
	for d in _defs:
		var id: String = d["id"]
		if PlayerProfile.unlocked_achievements.has(id):
			continue
		var alvo := _target_of(d)
		var atual := mini(_current_of(d), alvo)
		if atual != int(PlayerProfile.achievement_progress.get(id, -1)):
			PlayerProfile.set_achievement_progress(id, atual)
			if GameEventBus and alvo > 1 and atual > 0:
				GameEventBus.achievement_progressed.emit(id, atual, alvo)
		if atual >= alvo:
			pendentes.append(d)

	_evaluating = false

	for d in pendentes:
		_unlock(d)

	# Desbloquear pode ter mudado nivel, XP e a propria contagem de conquistas
	# (a Platina depende das outras). Uma segunda passada resolve a cascata sem
	# recursao aberta.
	if not pendentes.is_empty():
		_evaluate.call_deferred()


func _unlock(d: Dictionary) -> void:
	var id: String = d["id"]
	if PlayerProfile.unlocked_achievements.has(id):
		return
	PlayerProfile.set_achievement_progress(id, _target_of(d))
	if GameEventBus:
		GameEventBus.achievement_unlocked.emit(id)
	var xp := int(d.get("xp", 0))
	if xp > 0 and RewardSystem:
		RewardSystem.grant_xp(xp, "achievement:" + id)


func _target_of(d: Dictionary) -> int:
	var r: Dictionary = d.get("rule", {})
	match str(r.get("type", "")):
		"stat", "level", "streak", "distinct_games", "mastery":
			return int(r.get("target", 1))
		"all":
			return maxi(1, _defs.size() - 1)
		_:
			return 1


func _current_of(d: Dictionary) -> int:
	var r: Dictionary = d.get("rule", {})
	match str(r.get("type", "")):
		"stat":
			return int(PlayerProfile.get_stat(str(r.get("key", "")), 0))
		"level":
			return PlayerProfile.level
		"streak":
			return PlayerProfile.current_streak
		"distinct_games":
			return PlayerProfile.games_played_count()
		"game_win":
			return 1 if PlayerProfile.has_won(str(r.get("game", ""))) else 0
		"flag":
			return 1 if PlayerProfile.has_flag(str(r.get("key", ""))) else 0
		"mastery":
			return MasteryEngine.highest_mastery() if MasteryEngine else 0
		"all":
			var n := 0
			for id in PlayerProfile.unlocked_achievements:
				if _by_id.has(id) and str(_by_id[id].get("rule", {}).get("type", "")) != "all":
					n += 1
			return n
		_:
			return 0


# ----------------------------------------------------------------- consulta UI

func total_count() -> int:
	return _defs.size()


func unlocked_count() -> int:
	var n := 0
	for id in PlayerProfile.unlocked_achievements:
		if _by_id.has(id):
			n += 1
	return n


func definition(id: String) -> Dictionary:
	return _by_id.get(id, {})


## Catalogo pronto para a tela de perfil, ja com estado do jogador. Ordena
## desbloqueadas primeiro dentro de cada categoria e empurra as ocultas ainda
## fechadas para o fim -- elas aparecem como "???" e nao devem competir com o
## que o jogador consegue perseguir.
func catalog_for_ui() -> Array:
	var saida: Array = []
	for d in _defs:
		var id: String = d["id"]
		var alvo := _target_of(d)
		var desbloqueada: bool = PlayerProfile.unlocked_achievements.has(id)
		var oculta := bool(d.get("hidden", false)) and not desbloqueada
		saida.append({
			"id": id,
			"cat": str(d.get("cat", "geral")),
			"xp": int(d.get("xp", 0)),
			"hidden": oculta,
			"unlocked": desbloqueada,
			"progress": alvo if desbloqueada else mini(int(PlayerProfile.achievement_progress.get(id, 0)), alvo),
			"target": alvo,
			"name_key": id + "_NAME",
			"desc_key": id + "_DESC",
		})
	saida.sort_custom(_ordem_ui)
	return saida


func _ordem_ui(a: Dictionary, b: Dictionary) -> bool:
	if a["hidden"] != b["hidden"]:
		return not a["hidden"]
	if a["unlocked"] != b["unlocked"]:
		return a["unlocked"]
	if a["cat"] != b["cat"]:
		return a["cat"] < b["cat"]
	return a["xp"] < b["xp"]


## Conquistas mais proximas de fechar, para a HUD cutucar o jogador ("faltam 2
## vitorias"). Ignora as ocultas: revelar o alvo mataria a surpresa.
func closest_to_unlock(quantas: int = 3) -> Array:
	var candidatas: Array = []
	for d in _defs:
		var id: String = d["id"]
		if PlayerProfile.unlocked_achievements.has(id) or bool(d.get("hidden", false)):
			continue
		var alvo := _target_of(d)
		if alvo <= 1:
			continue
		var atual := mini(int(PlayerProfile.achievement_progress.get(id, 0)), alvo)
		if atual <= 0:
			continue
		candidatas.append({"id": id, "progress": atual, "target": alvo, "frac": float(atual) / float(alvo)})
	candidatas.sort_custom(func(a, b): return a["frac"] > b["frac"])
	return candidatas.slice(0, quantas)
