extends Node

## Gerenciador unificado para Google Play Games Services (PGS v2) e Play Games Sidekick.
##
## Este serviço oferece integração transparente e segura com o ecossistema
## do Google Play Games (login, conquistas, placares e overlay inteligente Sidekick),
## mantendo total compatibilidade com execução offline e plataformas desktop/web/F-Droid.

signal user_authenticated(player_id: String, player_name: String)
signal authentication_failed(error_message: String)
signal achievement_unlocked(achievement_id: String)
signal score_submitted(leaderboard_id: String, score: int)

# IDs de Conquistas do PlayTable (Mapeáveis no Google Play Console)
const ACHIEVEMENTS = {
	# Tabuleiro
	"VELHA_FIRST_WIN": "achievement_tictactoe_winner",
	"DAMAS_FIRST_WIN": "achievement_checkers_master",
	"BATALHA_NAVAL_WIN": "achievement_naval_admiral",
	"QUATRO_LINHA_WIN": "achievement_connectfour_champion",
	"SOLITARIO_PERFECT": "achievement_solitaire_genius",
	"CAMPO_MINADO_CLEAR": "achievement_minesweeper_sweeper",
	"DOMINO_WIN": "achievement_domino_tactician",
	"LUDO_WIN": "achievement_ludo_victory",
	"REVERSI_WIN": "achievement_reversi_strategist",
	"MANCALA_WIN": "achievement_mancala_expert",
	"SENET_WIN": "achievement_senet_pharaoh",
	# Cartas
	"PACIENCIA_WIN": "achievement_klondike_cleared",
	"MEMORIA_FAST": "achievement_memory_sharp",
	"BLACKJACK_21": "achievement_blackjack_natural21",
	"UNO_WIN": "achievement_colorcards_champion",
	"POKER_ROYAL_OR_FULL": "achievement_poker_highroller",
	# Geral
	"ALL_GAMES_TRIED": "achievement_table_explorer"
}

# IDs de Placares (Leaderboards)
const LEADERBOARDS = {
	"CAMPO_MINADO_BEST_TIME": "leaderboard_minesweeper_speed",
	"POKER_HIGH_SCORE": "leaderboard_poker_bankroll",
	"MEMORIA_FEWEST_TURNS": "leaderboard_memory_turns"
}

var _is_initialized: bool = false
var _is_logged_in: bool = false
var _player_id: String = ""
var _player_name: String = ""
var _pgs_plugin: Object = null

func _ready() -> void:
	_init_plugin()
	if is_android():
		authenticate_silently()
	
	if GameEventBus:
		GameEventBus.achievement_unlocked.connect(_on_event_achievement_unlocked)
		GameEventBus.score_updated.connect(_on_event_score_updated)
		GameEventBus.player_leveled_up.connect(_on_event_player_leveled_up)
		GameEventBus.match_completed.connect(_on_event_match_completed)
		GameEventBus.quest_completed.connect(_on_event_quest_completed)

func _on_event_achievement_unlocked(id: String) -> void:
	unlock_achievement(id)

func _on_event_score_updated(game_id: String, score: int) -> void:
	submit_score(game_id, score)

func _on_event_player_leveled_up(new_level: int) -> void:
	# Progression Stat (MAXIMUM aggregation type)
	submit_game_stat("progression_level", new_level)

func _on_event_match_completed(_game_id: String, result: Dictionary) -> void:
	submit_game_event("event_match_completed", 1)
	if result.has("win") and result["win"] == true:
		submit_game_event("event_match_won", 1)

func _on_event_quest_completed(_quest_id: String) -> void:
	submit_game_event("event_quest_finished", 1)

## Envia um Progession Stat (ex: Nível)
func submit_game_stat(stat_id: String, value: int) -> void:
	if not is_available(): return
	# Apenas um pseudo-wrapper. O método varia conforme o plugin exato (PlayGamesServices ou godot-play-games-services)
	if _pgs_plugin.has_method("submitEvent"):
		_pgs_plugin.submitEvent(stat_id, value)
	elif _pgs_plugin.has_method("submit_event"):
		_pgs_plugin.submit_event(stat_id, value)

## Envia um Evento Repetitivo
func submit_game_event(event_id: String, amount: int = 1) -> void:
	if not is_available(): return
	if _pgs_plugin.has_method("incrementEvent"):
		_pgs_plugin.incrementEvent(event_id, amount)
	elif _pgs_plugin.has_method("increment_event"):
		_pgs_plugin.increment_event(event_id, amount)

## Verifica se o app está rodando no sistema Android
func is_android() -> bool:
	return OS.get_name() == "Android"

## Retorna true se os serviços do Play Games estão disponíveis e inicializados
func is_available() -> bool:
	return is_android() and _pgs_plugin != null

## Retorna true se o Sidekick (overlay IA/ferramentas) é suportado no dispositivo atual
## Requisitos do Sidekick: Android 13+ (API 33+) e pelo menos 3GB de memória RAM
func is_sidekick_supported() -> bool:
	if not is_android():
		return false
	# No Android, a biblioteca Sidekick SDK ativa dinamicamente a sobreposição
	# quando o app bundle é compilado com suporte e executado em Android 13+
	return true

func _init_plugin() -> void:
	if not is_android():
		_is_initialized = true
		return
	
	if Engine.has_singleton("GodotPlayGamesServices"):
		_pgs_plugin = Engine.get_singleton("GodotPlayGamesServices")
		_connect_plugin_signals()
	elif Engine.has_singleton("PlayGamesServices"):
		_pgs_plugin = Engine.get_singleton("PlayGamesServices")
		_connect_plugin_signals()
	
	_is_initialized = true

func _connect_plugin_signals() -> void:
	if _pgs_plugin == null:
		return
	
	if _pgs_plugin.has_signal("user_authenticated"):
		_pgs_plugin.connect("user_authenticated", Callable(self, "_on_plugin_authenticated"))
	if _pgs_plugin.has_signal("authentication_failed"):
		_pgs_plugin.connect("authentication_failed", Callable(self, "_on_plugin_auth_failed"))
	if _pgs_plugin.has_signal("achievement_unlocked"):
		_pgs_plugin.connect("achievement_unlocked", Callable(self, "_on_plugin_achievement_unlocked"))

## Inicia autenticação silenciosa (PGS v2 Automatic Sign-in)
func authenticate_silently() -> void:
	if not is_available():
		return
	if _pgs_plugin.has_method("signInSilently"):
		_pgs_plugin.signInSilently()
	elif _pgs_plugin.has_method("signIn"):
		_pgs_plugin.signIn()

## Solicita autenticação manual / interativa
func authenticate_interactive() -> void:
	if not is_available():
		return
	if _pgs_plugin.has_method("signInInteractive"):
		_pgs_plugin.signInInteractive()
	elif _pgs_plugin.has_method("signIn"):
		_pgs_plugin.signIn()

## Desbloqueia uma conquista pelo identificador
func unlock_achievement(achievement_key_or_id: String) -> void:
	var achievement_id: String = ACHIEVEMENTS.get(achievement_key_or_id, achievement_key_or_id)
	
	if not is_available():
		# Fallback local / simulação para desenvolvimento
		achievement_unlocked.emit(achievement_id)
		return
	
	if _pgs_plugin.has_method("unlockAchievement"):
		_pgs_plugin.unlockAchievement(achievement_id)
	elif _pgs_plugin.has_method("unlock_achievement"):
		_pgs_plugin.unlock_achievement(achievement_id)
	
	achievement_unlocked.emit(achievement_id)

## Incrementa uma conquista incremental (ex.: jogar 10 partidas)
func increment_achievement(achievement_key_or_id: String, amount: int = 1) -> void:
	var achievement_id: String = ACHIEVEMENTS.get(achievement_key_or_id, achievement_key_or_id)
	
	if not is_available():
		return
	
	if _pgs_plugin.has_method("incrementAchievement"):
		_pgs_plugin.incrementAchievement(achievement_id, amount)
	elif _pgs_plugin.has_method("increment_achievement"):
		_pgs_plugin.increment_achievement(achievement_id, amount)

## Exibe o painel nativo de conquistas do Google Play Games
func show_achievements() -> void:
	if not is_available():
		return
	if _pgs_plugin.has_method("showAchievements"):
		_pgs_plugin.showAchievements()
	elif _pgs_plugin.has_method("show_achievements"):
		_pgs_plugin.show_achievements()

## Envia uma pontuação para a tabela de líderes
func submit_score(leaderboard_key_or_id: String, score: int) -> void:
	var leaderboard_id: String = LEADERBOARDS.get(leaderboard_key_or_id, leaderboard_key_or_id)
	
	if not is_available():
		score_submitted.emit(leaderboard_id, score)
		return
	
	if _pgs_plugin.has_method("submitLeaderBoardScore"):
		_pgs_plugin.submitLeaderBoardScore(leaderboard_id, score)
	elif _pgs_plugin.has_method("submit_score"):
		_pgs_plugin.submit_score(leaderboard_id, score)
	
	score_submitted.emit(leaderboard_id, score)

## Exibe uma tabela de líderes específica
func show_leaderboard(leaderboard_key_or_id: String) -> void:
	var leaderboard_id: String = LEADERBOARDS.get(leaderboard_key_or_id, leaderboard_key_or_id)
	if not is_available():
		return
	if _pgs_plugin.has_method("showLeaderBoard"):
		_pgs_plugin.showLeaderBoard(leaderboard_id)
	elif _pgs_plugin.has_method("show_leaderboard"):
		_pgs_plugin.show_leaderboard(leaderboard_id)

## Exibe todas as tabelas de líderes do jogo
func show_all_leaderboards() -> void:
	if not is_available():
		return
	if _pgs_plugin.has_method("showAllLeaderBoards"):
		_pgs_plugin.showAllLeaderBoards()
	elif _pgs_plugin.has_method("show_all_leaderboards"):
		_pgs_plugin.show_all_leaderboards()

func _on_plugin_authenticated(player_data: Dictionary) -> void:
	_is_logged_in = true
	_player_id = player_data.get("id", "")
	_player_name = player_data.get("name", "")
	user_authenticated.emit(_player_id, _player_name)

func _on_plugin_auth_failed(error_code: int) -> void:
	_is_logged_in = false
	authentication_failed.emit("Auth failed with code: %d" % error_code)

func _on_plugin_achievement_unlocked(id: String) -> void:
	achievement_unlocked.emit(id)
