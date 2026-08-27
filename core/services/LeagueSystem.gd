extends Node

## Ligas e temporadas.
##
## Da uma segunda moeda de progresso ao lado do nivel: o nivel so sobe, a liga
## sobe e desce. Isso mantem a vitoria valendo alguma coisa depois que o
## jogador ja viu todas as conquistas.
##
## O ELO nunca cai abaixo do piso da liga conquistada na temporada -- despencar
## tres ligas depois de uma noite ruim faz o jogador fechar o app e nao voltar.

const LEAGUES := [
	{"id": "bronze",   "min_elo": 0},
	{"id": "silver",   "min_elo": 1000},
	{"id": "gold",     "min_elo": 2000},
	{"id": "platinum", "min_elo": 3500},
	{"id": "diamond",  "min_elo": 5000},
	{"id": "master",   "min_elo": 7000},
	{"id": "legend",   "min_elo": 10000},
]

const ELO_VITORIA := 25
const ELO_EMPATE := 5
const ELO_DERROTA := -15
const XP_PROMOCAO := 1000

var current_elo: int = 0
var season: String = ""


func _ready() -> void:
	current_elo = int(PlayerProfile.get_stat("competitive_elo", 0))
	season = LiveOpsManager.get_active_season() if LiveOpsManager else "default_season"
	_check_season_reset()
	if GameEventBus:
		GameEventBus.match_completed.connect(_on_match_completed)


## Temporada nova zera o ELO para metade do valor anterior (soft reset): quem
## era Diamante comeca Ouro, nao Bronze.
func _check_season_reset() -> void:
	var salva := str(PlayerProfile.get_stat("elo_season", ""))
	if salva == season:
		return
	if salva != "":
		current_elo = int(current_elo / 2.0)
		PlayerProfile.set_stat("competitive_elo", current_elo)
	PlayerProfile.set_stat("elo_season", season)
	PlayerProfile.set_stat("league_floor", 0)


func _on_match_completed(_game_id: String, result: Dictionary) -> void:
	var delta := ELO_DERROTA
	if bool(result.get("win", false)):
		delta = ELO_VITORIA
	elif bool(result.get("draw", false)):
		delta = ELO_EMPATE

	var piso := int(PlayerProfile.get_stat("league_floor", 0))
	current_elo = maxi(piso, current_elo + delta)
	PlayerProfile.set_stat("competitive_elo", current_elo)
	_evaluate_promotion()


func get_current_league() -> Dictionary:
	var atual: Dictionary = LEAGUES[0]
	for liga in LEAGUES:
		if current_elo >= int(liga["min_elo"]):
			atual = liga
	return atual


func next_league() -> Dictionary:
	var atual := get_current_league()
	var i := LEAGUES.find(atual)
	return LEAGUES[i + 1] if i >= 0 and i + 1 < LEAGUES.size() else {}


## Progresso dentro da liga atual, para a barra da tela de perfil.
func league_progress() -> Vector2i:
	var atual := get_current_league()
	var proxima := next_league()
	if proxima.is_empty():
		return Vector2i(1, 1)
	var base := int(atual["min_elo"])
	return Vector2i(current_elo - base, int(proxima["min_elo"]) - base)


func _evaluate_promotion() -> void:
	var liga := get_current_league()
	var anterior := str(PlayerProfile.get_stat("last_league_id", "bronze"))
	if liga["id"] == anterior:
		return

	var subiu := _index_of(str(liga["id"])) > _index_of(anterior)
	PlayerProfile.set_stat("last_league_id", liga["id"])

	if subiu:
		# Piso: a liga recem-conquistada nao se perde nesta temporada.
		PlayerProfile.set_stat("league_floor", int(liga["min_elo"]))
		if RewardSystem:
			RewardSystem.grant_xp(XP_PROMOCAO, "league:" + str(liga["id"]))

	if GameEventBus:
		GameEventBus.league_changed.emit(str(liga["id"]), subiu)


func _index_of(league_id: String) -> int:
	for i in LEAGUES.size():
		if LEAGUES[i]["id"] == league_id:
			return i
	return 0
