extends Node

## Manages scene transitions with a fade-to-black overlay.

var overlay: ColorRect

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	
	# Garante que o Godot vai escutar o lifecycle do OS para não perder estado quando o Sidekick abrir
	get_tree().set_auto_accept_quit(false)

func _notification(what: int) -> void:
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	# O OS pode notificar foco antes de este autoload entrar na SceneTree.
	# Nessa janela nao ha arvore para pausar ainda.
	var scene_tree := get_tree()
	if scene_tree == null:
		return
	scene_tree.paused = what == NOTIFICATION_APPLICATION_FOCUS_OUT

func goto_scene(path: String) -> void:
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.2)
	tween.tween_callback(_deferred_goto_scene.bind(path))
	tween.tween_property(overlay, "color:a", 0.0, 0.2)
	tween.tween_callback(func(): overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _deferred_goto_scene(path: String) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		current_scene.free()
	
	var next_scene: Resource = ResourceLoader.load(path)
	if next_scene:
		var instance: Node = next_scene.instantiate()
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance
	else:
		push_error("SceneManager: Failed to load scene: %s" % path)
