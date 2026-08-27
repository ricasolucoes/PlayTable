extends Node

## Escada de dificuldade de 1 a 10, uma para cada jogo.
##
## Regra unica: venceu sobe um degrau, perdeu desce um, empatou fica onde
## estava. Nada de "so desce depois de duas derrotas" -- a escada tem de
## responder na mesma partida, senao ela nao acompanha quem esta jogando.
##
## O degrau serve a dois donos:
##
##   - a IA do jogo, que le `get_level()` para decidir quanto pensar antes de
##     jogar (as Damas viram profundidade de busca, o Jogo da Velha vira
##     minimax e quem abre a partida);
##   - a gamificacao, que le `xp_scale()`: vencer no degrau 10 paga mais que
##     vencer no degrau 1, e perder no degrau 1 paga menos que perder no 10.
##     Sem isso o jogador maximiza XP ficando de proposito no facil.
##
## Fica gravado por jogo. Sem persistir, a escada zerava toda vez que a tela
## era reaberta e a mesma abertura vencia de novo, para sempre.

signal difficulty_changed(game_id: String, level: int, delta: int)

const MIN_LEVEL := 1
const MAX_LEVEL := 10

## Degrau de entrada. Nem o mais facil (que nao ensina nada) nem o do meio
## (que espanta quem nunca jogou): tres degraus dao margem para cair.
const DEFAULT_LEVEL := 3

const SAVE_KEY := "difficulty_levels"

## Quanto o degrau mexe no XP da partida. Linear entre as duas pontas: no
## degrau 1 a partida paga 60% da tabela, no 10 paga o dobro.
const XP_SCALE_MIN := 0.6
const XP_SCALE_MAX := 2.0

var _levels: Dictionary = {}


func _ready() -> void:
	reload()


## Relê os degraus do disco, descartando o que estiver em memoria.
##
## O autoload guarda os degraus numa copia viva, e e ela que `_persist()`
## escreve. Quem devolve o SaveManager ao estado anterior -- a suite de testes
## faz isso -- precisa avisar aqui, senao a copia velha volta para o disco na
## proxima gravacao e o degrau do jogador muda sozinho.
func reload() -> void:
	_levels.clear()
	var gravado: Variant = SaveManager.get_setting(SAVE_KEY, {}) if SaveManager else {}
	if typeof(gravado) == TYPE_DICTIONARY:
		for chave in gravado:
			_levels[str(chave)] = _clamp_level(int(gravado[chave]))


## O degrau atual do jogo. Jogo que nunca foi jogado comeca no DEFAULT_LEVEL.
func get_level(game_id: String) -> int:
	return _clamp_level(int(_levels.get(game_id, DEFAULT_LEVEL)))


func set_level(game_id: String, level: int) -> void:
	var novo := _clamp_level(level)
	if _levels.get(game_id, -1) == novo:
		return
	_levels[game_id] = novo
	_persist()


## Fecha a partida na escada e devolve quanto o degrau andou (+1, -1 ou 0).
##
## Devolve 0 tambem quando o jogador venceu ja no 10 ou perdeu ja no 1: o
## resultado conta, mas nao ha degrau para onde ir.
func register_result(game_id: String, won: bool, draw: bool = false) -> int:
	var atual := get_level(game_id)
	var alvo := atual
	if draw:
		alvo = atual
	elif won:
		alvo = atual + 1
	else:
		alvo = atual - 1

	alvo = _clamp_level(alvo)
	var delta := alvo - atual
	if delta != 0:
		_levels[game_id] = alvo
		_persist()
	elif not _levels.has(game_id):
		_levels[game_id] = alvo
		_persist()

	difficulty_changed.emit(game_id, alvo, delta)
	return delta


## Multiplicador de XP do degrau. A gamificacao le isto pelo payload da partida.
func xp_scale(level: int) -> float:
	var t := float(_clamp_level(level) - MIN_LEVEL) / float(MAX_LEVEL - MIN_LEVEL)
	return lerpf(XP_SCALE_MIN, XP_SCALE_MAX, t)


## Chave de traducao da faixa do degrau. Cinco faixas de dois degraus: o numero
## sozinho ("7/10") nao diz nada a quem abriu o jogo agora.
func tier_name(level: int) -> String:
	match int(ceil(_clamp_level(level) / 2.0)):
		1: return "DIFF_TIER_INICIANTE"
		2: return "DIFF_TIER_CASUAL"
		3: return "DIFF_TIER_DESAFIO"
		4: return "DIFF_TIER_DIFICIL"
		_: return "DIFF_TIER_MESTRE"


## Texto pronto para a HUD: "Dificuldade 7/10 — Difícil".
func label_for(game_id: String) -> String:
	var nivel := get_level(game_id)
	return tr("DIFF_LABEL") % [nivel, MAX_LEVEL, tr(tier_name(nivel))]


## Aviso de mudanca de degrau para o fim de partida, ou "" quando nao mudou.
func change_notice(level: int, delta: int) -> String:
	if delta > 0:
		return tr("DIFF_UP") % [level, MAX_LEVEL]
	if delta < 0:
		return tr("DIFF_DOWN") % [level, MAX_LEVEL]
	return ""


func _clamp_level(level: int) -> int:
	return clampi(level, MIN_LEVEL, MAX_LEVEL)


func _persist() -> void:
	if SaveManager:
		SaveManager.set_setting(SAVE_KEY, _levels.duplicate())
