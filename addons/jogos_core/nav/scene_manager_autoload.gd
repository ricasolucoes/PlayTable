extends Node

## Navegação entre cenas: fade, carga em thread com progresso, Voltar do
## Android, pausa ao perder o foco.
##
## Fonte: PlayTable `core/navegacao/SceneManager.gd` (fade, guarda
## `_navegando`, `set_quit_on_go_back(false)`, foco → pausa) mais
## `JogosSceneLoader` (novo) e `JogosLoadingOverlay`. Tirado:
## `AudioManager.play_music_for_scene` — música por cena é decisão do jogo,
## que escuta `scene_changed`.
##
## `goto_scene(path, opts)`; opts: `fade: float` (0.2), `progress: bool`
## (true), `args: Dictionary` (entregue a `on_scene_args(args)` da cena nova,
## se existir).

signal scene_changing(path: String)
signal load_progress(ratio: float)
signal scene_changed(path: String)
signal scene_failed(path: String, error: int)
signal back_requested
signal app_paused
signal app_resumed

const DEFAULT_FADE: float = 0.2

## Sem ninguém escutando `back_requested` e sem a cena tratar o Voltar, o
## aplicativo sai — é o que o Android espera no topo da pilha.
var quit_when_back_unhandled: bool = true

## Como a cena nova entra na árvore. Troca em testes (a suite roda dentro de
## uma cena que não pode ser destruída) e em quem hospeda jogos num nó
## próprio em vez de `current_scene`.
var scene_swapper: Callable = Callable()

var overlay: JogosLoadingOverlay
var loader: JogosSceneLoader
var current_path: String = ""

var _navigating: bool = false


func _ready() -> void:
	overlay = JogosLoadingOverlay.new()
	overlay.name = "LoadingOverlay"
	add_child(overlay)
	loader = JogosSceneLoader.new()
	loader.name = "SceneLoader"
	loader.progress.connect(_on_load_progress)
	add_child(loader)
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	# O Voltar fechava o aplicativo inteiro de qualquer tela. Fica aqui, e não
	# no project.godot, porque este é o autoload que manda na navegação.
	get_tree().set_quit_on_go_back(false)


func is_navigating() -> bool:
	return _navigating


func goto_scene(path: String, opts: Dictionary = {}) -> void:
	if _navigating:
		return
	_navigating = true
	scene_changing.emit(path)
	var fade: float = _fade_duration(opts)
	overlay.block_input(true)
	overlay.show_progress(bool(opts.get("progress", true)))
	await overlay.fade_in(fade)
	var scene: PackedScene = await loader.load_async(path)
	if scene == null:
		scene_failed.emit(path, ERR_CANT_OPEN)
		JogosLocator.log("error", "nav", "scene_load_failed", {"path": path})
		await _finish(fade)
		return
	_swap(scene, path, opts.get("args", {}))
	await _finish(fade)


func goto_packed(scene: PackedScene, opts: Dictionary = {}) -> void:
	if _navigating or scene == null:
		return
	_navigating = true
	var path: String = scene.resource_path
	scene_changing.emit(path)
	var fade: float = _fade_duration(opts)
	overlay.block_input(true)
	await overlay.fade_in(fade)
	_swap(scene, path, opts.get("args", {}))
	await _finish(fade)


func _finish(fade: float) -> void:
	await overlay.fade_out(fade)
	overlay.block_input(false)
	_navigating = false


func _swap(scene: PackedScene, path: String, args: Dictionary) -> void:
	var instance: Node = scene.instantiate()
	if instance.has_method("on_scene_args"):
		instance.call("on_scene_args", args)
	if scene_swapper.is_valid():
		scene_swapper.call(instance)
	else:
		var tree: SceneTree = get_tree()
		var old: Node = tree.current_scene
		if old != null:
			old.free()
		tree.root.add_child(instance)
		tree.current_scene = instance
	current_path = path
	scene_changed.emit(path)


func _fade_duration(opts: Dictionary) -> float:
	var fade: float = float(opts.get("fade", DEFAULT_FADE))
	var settings: Node = JogosLocator.autoload(&"AppSettings")
	if settings != null and settings.has_method("get_value") \
			and bool(settings.call("get_value", "reduced_motion")):
		return 0.0
	return fade


func _on_load_progress(_path: String, ratio: float) -> void:
	overlay.set_progress(ratio)
	load_progress.emit(ratio)


func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			go_back()
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			# O OS pode notificar foco antes de o autoload entrar na árvore;
			# `is_inside_tree()` e não `get_tree() == null`, que já imprime erro.
			if is_inside_tree():
				get_tree().paused = true
				app_paused.emit()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if is_inside_tree():
				get_tree().paused = false
				app_resumed.emit()


## O Voltar do aparelho: a cena atual decide (`handle_back()` ou o alias do
## PlayTable `voltar_do_aparelho()`); senão `back_requested`; sem ninguém
## escutando, o aplicativo sai. Devolve `true` quando alguém tratou.
func go_back() -> bool:
	if _navigating:
		return true
	var scene: Node = get_tree().current_scene if is_inside_tree() else null
	if scene_swapper.is_valid():
		scene = null
	if scene != null:
		for method: String in ["handle_back", "voltar_do_aparelho"]:
			if scene.has_method(method) and bool(scene.call(method)):
				return true
	if back_requested.get_connections().is_empty():
		if quit_when_back_unhandled and is_inside_tree():
			get_tree().quit()
		return false
	back_requested.emit()
	return true
