extends Node

## Recordes pessoais e o valor que cada jogo manda para o placar.
##
## Nem todo jogo pontua igual: no Campo Minado e no Hanoi *menor* e melhor
## (tempo, jogadas), no Poker e maior (fichas), no Resta Um e menor (pecas que
## sobraram). O Play Games ordena pelo que o placar declara, entao o valor tem
## que sair daqui ja no formato certo -- mandar segundos cru para um placar
## configurado como "maior vence" poe o pior jogador no topo.
##
## O recorde local vale por si: o jogador ve seu melhor tempo na tela de perfil
## mesmo sem Play Games, sem login e sem rede.

## Metrica de placar por jogo. `invert` marca os placares onde menor e melhor.
const METRICAS := {
	"campo_minado": {"campo": "time",  "key": "LB_MINESWEEPER_TIME", "invert": true,  "escala": 1000},
	"memoria":      {"campo": "moves", "key": "LB_MEMORY_MOVES",     "invert": true,  "escala": 1},
	"hanoi":        {"campo": "moves", "key": "LB_HANOI_MOVES",      "invert": true,  "escala": 1},
	"solitario":        {"campo": "pegs",  "key": "LB_SOLITAIRE_PEGS",   "invert": true,  "escala": 1},
	"poker":            {"campo": "score", "key": "LB_POKER_BANKROLL",   "invert": false, "escala": 1},
	"caminho_numerico": {"campo": "score", "key": "LB_NUMBER_PATH_SCORE", "invert": false, "escala": 1},
}


func _ready() -> void:
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)


func _on_match_completed(game_id: String, result: Dictionary) -> void:
	if not METRICAS.has(game_id):
		return
	var m: Dictionary = METRICAS[game_id]

	# Metrica de "menor e melhor" so vale em vitoria: perder rapido nao e recorde.
	if bool(m["invert"]) and not bool(result.get("win", false)):
		return
	if not result.has(str(m["campo"])):
		return

	var bruto := float(result[str(m["campo"])])
	if bruto <= 0.0:
		return
	var valor := int(round(bruto * float(m["escala"])))

	var chave_local := "record_" + game_id
	var novo_recorde := PlayerProfile.record_min(chave_local, valor) if bool(m["invert"]) \
		else PlayerProfile.record_max(chave_local, valor)

	if novo_recorde and PlayGamesManager:
		PlayGamesManager.submit_score(str(m["key"]), valor)


## Recorde pessoal de um jogo, ja formatado para leitura. Vazio quando ainda
## nao ha recorde.
func personal_best(game_id: String) -> String:
	if not METRICAS.has(game_id):
		return ""
	var valor := int(PlayerProfile.get_stat("record_" + game_id, 0))
	if valor <= 0:
		return ""
	var m: Dictionary = METRICAS[game_id]
	match str(m["campo"]):
		"time":
			var segundos := int(valor / int(m["escala"]))
			return "%d:%02d" % [segundos / 60, segundos % 60]
		"moves":
			return tr("RECORD_MOVES") % valor
		"pegs":
			return tr("RECORD_PEGS") % valor
		_:
			return str(valor)


func has_leaderboard(game_id: String) -> bool:
	return METRICAS.has(game_id)
