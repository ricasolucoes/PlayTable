extends SceneTree

func _init():
	print("Testing SudokuGenerator...")
	var board = SudokuGenerator.generate_board(1)
	print("Easy Board Generated: ", board["clues"], " clues")
	
	print("Testing SudokuGame scene...")
	var scene = load("res://games/sudoku/SudokuGame.tscn")
	var instance = scene.instantiate()
	if instance != null:
		print("Scene instantiated successfully.")
	else:
		print("Failed to instantiate scene.")
		
	quit()
