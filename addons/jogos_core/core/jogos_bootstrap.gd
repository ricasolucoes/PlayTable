class_name JogosBootstrap
extends Node

## Sequência de boot: passos ordenados → registro de serviços → primeira cena.
##
## Extraído de VOLTA `src/core/bootstrap.gd`. Generalização: a lista de passos
## do VOLTA (`_default_steps`, com config/tema/carteira do jogo) saiu; o jogo
## chama `configure_steps()` ou preenche `steps` na cena. Cada passo é
## `{"name": String, "factory": Callable, "essential": bool}`. Passo essencial
## que devolve `null` aborta o boot e emite `boot_failed`; não essencial só
## avisa. Nós criados entram como filhos deste, para terem `_process`.
##
## A troca de cena passa pelo `SceneManager` quando ele existe (carregamento
## em thread e fade) e cai em `change_scene_to_file` quando não.

signal boot_completed(registry: JogosServiceRegistry)
signal boot_failed(service_name: String, reason: String)

@export var first_scene: String = ""
@export var auto_boot: bool = true

var registry: JogosServiceRegistry = JogosServiceRegistry.new()
var boot_order: Array[String] = []
var _steps: Array[Dictionary] = []
var _booted: bool = false


func _ready() -> void:
	if auto_boot:
		boot()


func configure_steps(steps: Array[Dictionary]) -> void:
	_steps = steps


func add_step(service_name: String, factory: Callable, essential: bool = true) -> void:
	_steps.append({"name": service_name, "factory": factory, "essential": essential})


func boot() -> bool:
	if _booted:
		return true
	boot_order.clear()
	for step: Dictionary in _steps:
		var service_name: String = str(step.get("name", ""))
		var essential: bool = bool(step.get("essential", true))
		var factory: Callable = step.get("factory", Callable())
		var instance: Object = factory.call() if factory.is_valid() else null
		if instance == null:
			var reason: String = "boot step '%s' retornou null" % service_name
			JogosLocator.log("error" if essential else "warn", "boot", "boot_step_failed", {"service": service_name, "essential": essential})
			boot_failed.emit(service_name, reason)
			if essential:
				return false
			continue
		if instance is Node and not (instance as Node).is_inside_tree():
			add_child(instance as Node)
		registry.register(service_name, instance)
		boot_order.append(service_name)
		JogosLocator.log("info", "boot", "boot_step_ok", {"service": service_name})
	_booted = true
	boot_completed.emit(registry)
	_load_first_scene()
	return true


func _load_first_scene() -> void:
	if first_scene.is_empty() or not is_inside_tree():
		return
	# Este nó pode existir antes da cena principal configurada; a comparação
	# fica diferida para não carregar a mesma cena duas vezes por lançamento.
	_change_to_first_scene.call_deferred()


func _change_to_first_scene() -> void:
	if first_scene.is_empty() or not is_inside_tree():
		return
	var current: Node = get_tree().current_scene
	if current != null and current.scene_file_path == first_scene:
		return
	var scene_manager: Node = JogosLocator.autoload(&"SceneManager")
	if scene_manager != null and scene_manager.has_method("goto_scene"):
		scene_manager.call("goto_scene", first_scene)
		return
	get_tree().change_scene_to_file(first_scene)
