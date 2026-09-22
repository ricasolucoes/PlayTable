extends "res://addons/jogos_core/nav/scene_manager_autoload.gd"

## Manages scene transitions with overlay.
## Herda do SceneManager canônico de jogos_core.

const DEVICE_SHOTS := preload("res://core/debug/DeviceShots.gd")


func _ready() -> void:
	super._ready()
	if DEVICE_SHOTS.pedido():
		add_child.call_deferred(DEVICE_SHOTS.new())
