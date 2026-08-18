extends Node

var overlay: ColorRect

func _ready():
	var canvas = CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)

func goto_scene(path: String):
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween = get_tree().create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.2)
	tween.tween_callback(_deferred_goto_scene.bind(path))
	tween.tween_property(overlay, "color:a", 0.0, 0.2)
	tween.tween_callback(func(): overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)

func _deferred_goto_scene(path: String):
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.free()
	
	var next_scene = ResourceLoader.load(path)
	if next_scene:
		var instance = next_scene.instantiate()
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance
	else:
		print("Failed to load scene: ", path)
