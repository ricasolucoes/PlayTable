extends Node

func goto_scene(path: String):
	# Call deferred to safely load during idle time
	call_deferred("_deferred_goto_scene", path)

func _deferred_goto_scene(path: String):
	# Remove current scene
	var current_scene = get_tree().current_scene
	if current_scene:
		current_scene.free()
	
	# Load new scene
	var next_scene = ResourceLoader.load(path)
	if next_scene:
		var instance = next_scene.instantiate()
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance
	else:
		print("Failed to load scene: ", path)
