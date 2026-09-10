class_name JogosSceneLoader
extends Node

## Carrega uma cena em thread e avisa o progresso.
##
## Nenhum dos três jogos tinha isto: o PlayTable chama `ResourceLoader.load`
## síncrono dentro do fade (a tela trava o tempo que a cena demorar) e o
## VOLTA tem um `BackgroundResourceLoader` que é mock. Aqui a requisição vai
## para `ResourceLoader.load_threaded_request` e o `_process` só pergunta o
## status — o quadro continua a 60 fps enquanto a mesa 3D sobe.

signal progress(path: String, ratio: float)
signal loaded(path: String, scene: PackedScene)
signal failed(path: String, error: int)

var _pending: Dictionary = {}
var _done: Dictionary = {}


func is_loading(path: String = "") -> bool:
	return not _pending.is_empty() if path == "" else _pending.has(path)


## Começa a carga. Devolve `false` se o caminho não existe ou já está em
## andamento. `use_sub_threads` fica `false` por padrão: em Android com
## poucos núcleos os sub-threads brigam com o renderizador.
func load_scene(path: String, use_sub_threads: bool = false) -> bool:
	if _pending.has(path):
		return false
	if not ResourceLoader.exists(path):
		failed.emit(path, ERR_FILE_NOT_FOUND)
		return false
	var err: int = ResourceLoader.load_threaded_request(path, "PackedScene", use_sub_threads)
	if err != OK:
		failed.emit(path, err)
		return false
	_pending[path] = 0.0
	set_process(true)
	return true


## Versão `await`: devolve a cena ou `null` em falha.
func load_async(path: String) -> PackedScene:
	if not load_scene(path):
		if _pending.has(path):
			return await _wait_for(path)
		return null
	return await _wait_for(path)


func _wait_for(path: String) -> PackedScene:
	while _pending.has(path):
		await get_tree().process_frame
	var scene: PackedScene = _done.get(path, null) as PackedScene
	_done.erase(path)
	return scene


func _process(_delta: float) -> void:
	if _pending.is_empty():
		set_process(false)
		return
	for path: String in _pending.keys():
		var info: Array = []
		var status: int = ResourceLoader.load_threaded_get_status(path, info)
		match status:
			ResourceLoader.THREAD_LOAD_IN_PROGRESS:
				var ratio: float = float(info[0]) if not info.is_empty() else 0.0
				if ratio != float(_pending[path]):
					_pending[path] = ratio
					progress.emit(path, ratio)
			ResourceLoader.THREAD_LOAD_LOADED:
				var res: Resource = ResourceLoader.load_threaded_get(path)
				_pending.erase(path)
				var scene: PackedScene = res as PackedScene
				if scene == null:
					_done[path] = null
					failed.emit(path, ERR_INVALID_DATA)
				else:
					_done[path] = scene
					progress.emit(path, 1.0)
					loaded.emit(path, scene)
			_:
				_pending.erase(path)
				_done[path] = null
				failed.emit(path, ERR_CANT_OPEN if status == ResourceLoader.THREAD_LOAD_FAILED else ERR_INVALID_PARAMETER)
