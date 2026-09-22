class_name JogosMatchResult
extends RefCounted

## Resultado de uma partida — o contrato entre o jogo e a camada de
## recompensa (XP, streak, conquistas, placar).
##
## Fonte: PlayTable `core/services/GamificationManager.gd` L10-30 (as chaves
## que o motor de gamificação lê) e VOLTA `src/gameplay/match_result.gd`
## (vencedor, colocações, causa). `to_dict()` produz exatamente as chaves do
## PlayTable, e só as que foram preenchidas: o motor de lá trata `xp`,
## `time`, `score` e `moves` com `has()` — emitir `moves: 0` numa partida que
## não conta jogadas viraria "recorde de zero jogadas".

const BASE_KEYS: PackedStringArray = [
	"win", "draw", "xp", "time", "perfect", "close_call", "mode", "score",
	"moves", "flags", "xp_scale", "difficulty", "difficulty_delta",
]
const EXTRA_KEYS: PackedStringArray = ["winner_id", "placements", "scores", "cause"]
const MODES: PackedStringArray = ["solo", "pass_play", "online"]

var win: bool = false
var draw: bool = false
var perfect: bool = false
var close_call: bool = false
var mode: String = ""
var flags: Array[String] = []

var xp: int = 0:
	set(value):
		xp = value
		_set["xp"] = true
var time: float = 0.0:
	set(value):
		time = value
		_set["time"] = true
var score: int = 0:
	set(value):
		score = value
		_set["score"] = true
var moves: int = 0:
	set(value):
		moves = value
		_set["moves"] = true
var xp_scale: float = 1.0:
	set(value):
		xp_scale = value
		_set["xp_scale"] = true
var difficulty: int = 0:
	set(value):
		difficulty = value
		_set["difficulty"] = true
var difficulty_delta: int = 0:
	set(value):
		difficulty_delta = value
		_set["difficulty_delta"] = true

## Multiplayer (opcional): índice do vencedor, ordem de chegada, pontuação
## por jogador e por que a partida acabou ("time", "abandon"...).
var winner_id: int = -1
var placements: Array[int] = []
var scores: Array[int] = []
var cause: String = ""

var _set: Dictionary = {}


static func won(p_mode: String = "solo") -> JogosMatchResult:
	var r := JogosMatchResult.new()
	r.win = true
	r.mode = p_mode
	return r


static func lost(p_mode: String = "solo") -> JogosMatchResult:
	var r := JogosMatchResult.new()
	r.mode = p_mode
	return r


static func drawn(p_mode: String = "solo") -> JogosMatchResult:
	var r := JogosMatchResult.new()
	r.draw = true
	r.mode = p_mode
	return r


func has_value(key: String) -> bool:
	return _set.has(key)


func to_dict() -> Dictionary:
	var d: Dictionary = {"win": win, "draw": draw, "perfect": perfect, "close_call": close_call}
	if mode != "":
		d["mode"] = mode
	if not flags.is_empty():
		d["flags"] = flags.duplicate()
	if _set.has("xp"):
		d["xp"] = xp
	if _set.has("time"):
		d["time"] = time
	if _set.has("score"):
		d["score"] = score
	if _set.has("moves"):
		d["moves"] = moves
	if _set.has("xp_scale"):
		d["xp_scale"] = xp_scale
	if _set.has("difficulty"):
		d["difficulty"] = difficulty
	if _set.has("difficulty_delta"):
		d["difficulty_delta"] = difficulty_delta
	if winner_id >= 0:
		d["winner_id"] = winner_id
	if not placements.is_empty():
		d["placements"] = placements.duplicate()
	if not scores.is_empty():
		d["scores"] = scores.duplicate()
	if cause != "":
		d["cause"] = cause
	return d


static func from_dict(d: Dictionary) -> JogosMatchResult:
	var r := JogosMatchResult.new()
	r.win = bool(d.get("win", false))
	r.draw = bool(d.get("draw", false))
	r.perfect = bool(d.get("perfect", false))
	r.close_call = bool(d.get("close_call", false))
	r.mode = str(d.get("mode", ""))
	for f: Variant in d.get("flags", []):
		r.flags.append(str(f))
	if d.has("xp"):
		r.xp = int(d["xp"])
	if d.has("time"):
		r.time = float(d["time"])
	if d.has("score"):
		r.score = int(d["score"])
	if d.has("moves"):
		r.moves = int(d["moves"])
	if d.has("xp_scale"):
		r.xp_scale = float(d["xp_scale"])
	if d.has("difficulty"):
		r.difficulty = int(d["difficulty"])
	if d.has("difficulty_delta"):
		r.difficulty_delta = int(d["difficulty_delta"])
	r.winner_id = int(d.get("winner_id", -1))
	for p: Variant in d.get("placements", []):
		r.placements.append(int(p))
	for s: Variant in d.get("scores", []):
		r.scores.append(int(s))
	r.cause = str(d.get("cause", ""))
	return r


## Lista de problemas; vazia quando o resultado é consistente.
func validate() -> PackedStringArray:
	var errors: PackedStringArray = []
	if win and draw:
		errors.append("win e draw ao mesmo tempo")
	if mode != "" and not MODES.has(mode):
		errors.append("mode desconhecido: " + mode)
	if _set.has("time") and time < 0.0:
		errors.append("time negativo")
	if _set.has("moves") and moves < 0:
		errors.append("moves negativo")
	if _set.has("xp_scale") and xp_scale <= 0.0:
		errors.append("xp_scale deve ser > 0")
	if _set.has("difficulty") and (difficulty < 1 or difficulty > 10):
		errors.append("difficulty fora de 1..10")
	if not placements.is_empty():
		if winner_id >= 0 and placements[0] != winner_id:
			errors.append("winner_id não é o primeiro de placements")
		if not scores.is_empty() and scores.size() != placements.size():
			errors.append("scores e placements com tamanhos diferentes")
	return errors


func is_valid() -> bool:
	return validate().is_empty()
