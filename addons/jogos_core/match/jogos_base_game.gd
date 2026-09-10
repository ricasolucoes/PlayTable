class_name JogosBaseGame
extends Node

## Base de qualquer cena de partida: começar, pausar, terminar, reiniciar,
## voltar — e publicar o resultado no barramento sem conhecer XP, conquista
## nem placar.
##
## Fonte: PlayTable `shared/BaseGame.gd` (ciclo `begin_match /
## report_match_result / restart_game / go_back_to_menu / voltar_do_aparelho`
## e a trava `_result_reported`) sobre o ciclo de estados do VOLTA
## (`JogosMatchFlow`). Tirado do PlayTable: barra de cima, painel de regras,
## cartão de resultado, toast, rede, escada de dificuldade e `DragScroll` —
## cada jogo pendura o que tem. O que ficou é só o que era idêntico em todos.
##
## Quem herda sobrescreve os ganchos `_on_match_*`. `finish_match()` é
## idempotente: vários jogos chegam ao fim por mais de um caminho.

## Identificador do jogo no barramento e no perfil. Vazio = derivado da
## pasta da cena (`res://games/gamao/Game.tscn` -> `gamao`).
@export var game_id: String = ""

## Cena para onde `go_back_to_menu()` leva. Vazio = só emite `back_requested`
## no SceneManager, e quem escuta decide.
@export var menu_scene_path: String = ""

## Pausar a `SceneTree` inteira ao pausar a partida. Jogo de tabuleiro por
## turnos prefere `false` para a HUD continuar animando.
@export var pause_tree_on_pause: bool = true

## Enquadramento. A lib de tela (`JogosScreenFit`) é de outro módulo e o
## jogo pode nem tê-la: quem quer enquadrar injeta aqui um Callable
## `(bounds: Variant) -> void`. Sem nada injetado, `fit_content()` tenta a
## classe pelo nome e, se não existir, não faz nada.
var fit_callback: Callable = Callable()

var flow: JogosMatchFlow = JogosMatchFlow.new()
var current_mode: String = "solo"
var last_result: JogosMatchResult = null
var match_started_at_msec: int = 0

var _result_reported: bool = false


func _enter_tree() -> void:
	if game_id == "":
		game_id = derive_game_id(scene_file_path)


func _process(delta: float) -> void:
	flow.tick(delta)


# ------------------------------------------------------------------ ciclo

func begin_match(mode: String = "solo") -> void:
	current_mode = mode
	_result_reported = false
	last_result = null
	match_started_at_msec = Time.get_ticks_msec()
	if flow.is_in(JogosMatchFlow.Id.BOOT) or flow.is_in(JogosMatchFlow.Id.MENU) \
			or flow.is_in(JogosMatchFlow.Id.RESULTS):
		flow.request(JogosMatchFlow.Id.LOADING)
	if flow.is_in(JogosMatchFlow.Id.LOADING) or flow.is_in(JogosMatchFlow.Id.COUNTDOWN):
		flow.request(JogosMatchFlow.Id.PLAYING)
	var bus: Node = JogosLocator.autoload(&"GameEventBus")
	if bus != null and bus.has_method("emit_match_started"):
		bus.call("emit_match_started", game_id, mode)
	_on_match_started()


func is_playing() -> bool:
	return flow.is_in(JogosMatchFlow.Id.PLAYING)


func is_paused() -> bool:
	return flow.is_in(JogosMatchFlow.Id.PAUSED)


func is_over() -> bool:
	return flow.is_in(JogosMatchFlow.Id.RESULTS)


func elapsed_sec() -> float:
	if match_started_at_msec == 0:
		return 0.0
	return float(Time.get_ticks_msec() - match_started_at_msec) / 1000.0


func pause_match() -> void:
	if not flow.request(JogosMatchFlow.Id.PAUSED):
		return
	if pause_tree_on_pause and is_inside_tree():
		get_tree().paused = true
	_on_match_paused()


func resume_match() -> void:
	if not flow.is_in(JogosMatchFlow.Id.PAUSED):
		return
	if pause_tree_on_pause and is_inside_tree():
		get_tree().paused = false
	flow.request(JogosMatchFlow.Id.PLAYING)
	_on_match_resumed()


## Fecha a partida e publica o resultado. Chamadas repetidas na mesma
## partida são ignoradas; quem destrava é `begin_match()`/`restart_match()`.
func finish_match(result: JogosMatchResult) -> void:
	if _result_reported:
		return
	_result_reported = true
	if pause_tree_on_pause and is_inside_tree() and get_tree().paused:
		get_tree().paused = false
	if result.mode == "":
		result.mode = current_mode
	if not result.has_value("time") and match_started_at_msec > 0:
		result.time = elapsed_sec()
	last_result = result
	flow.request(JogosMatchFlow.Id.RESULTS)
	var problems: PackedStringArray = result.validate()
	if not problems.is_empty():
		JogosLocator.log("warn", "match", "result_invalid", {"game_id": game_id, "problems": problems})
	var bus: Node = JogosLocator.autoload(&"GameEventBus")
	if bus != null and bus.has_method("emit_match_completed"):
		bus.call("emit_match_completed", game_id, result.to_dict())
	_on_match_finished(result)


func restart_match() -> void:
	if pause_tree_on_pause and is_inside_tree() and get_tree().paused:
		get_tree().paused = false
	if flow.is_in(JogosMatchFlow.Id.PLAYING) or flow.is_in(JogosMatchFlow.Id.PAUSED):
		flow.request(JogosMatchFlow.Id.MENU)
	_on_match_restart()
	begin_match(current_mode)


func go_back_to_menu() -> void:
	if pause_tree_on_pause and is_inside_tree() and get_tree().paused:
		get_tree().paused = false
	var nav: Node = JogosLocator.autoload(&"SceneManager")
	if menu_scene_path != "" and nav != null and nav.has_method("goto_scene"):
		nav.call("goto_scene", menu_scene_path)
	elif nav != null and nav.has_signal("back_requested"):
		nav.emit_signal("back_requested")


## O Voltar do aparelho dentro de uma partida: nunca fecha o aplicativo.
## Jogo com painel aberto sobrescreve, fecha o painel e devolve `true`.
func handle_back() -> bool:
	go_back_to_menu()
	return true


## Alias do PlayTable, para as cenas de lá continuarem funcionando.
func voltar_do_aparelho() -> bool:
	return handle_back()


# ------------------------------------------------------- enquadramento

func fit_content(bounds: Variant) -> void:
	if fit_callback.is_valid():
		fit_callback.call(bounds)
		return
	var fit_class: String = "JogosScreenFit"
	if not ClassDB.class_exists(fit_class) and not _script_class_exists(fit_class):
		return
	var path: String = _script_class_path(fit_class)
	if path == "":
		return
	var script: Script = load(path)
	if script != null and script.has_method("fit_node"):
		script.call("fit_node", self, bounds)


func _script_class_exists(name: String) -> bool:
	return _script_class_path(name) != ""


func _script_class_path(name: String) -> String:
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.get("class", "")) == name:
			return str(entry.get("path", ""))
	return ""


# ------------------------------------------------------------- ganchos

func _on_match_started() -> void:
	pass


func _on_match_paused() -> void:
	pass


func _on_match_resumed() -> void:
	pass


func _on_match_finished(_result: JogosMatchResult) -> void:
	pass


func _on_match_restart() -> void:
	pass


# ------------------------------------------------------------- estático

static func derive_game_id(path: String) -> String:
	if path.begins_with("res://games/"):
		var parts: PackedStringArray = path.split("/")
		if parts.size() >= 4 and parts[3] != "":
			return parts[3]
	if path == "":
		return ""
	return path.get_file().get_basename().to_snake_case()
