extends SceneTree

func _init():
	print("Generating...")
	var data = SudokuGenerator.generate_board(1)
	var puzzle = data["puzzle"]
	var clues = data["clues"]
	
	print("Clues: ", clues)
	for r in range(9):
		var line = ""
		for c in range(9):
			line += str(puzzle[r][c]) + " "
		print(line)
		
	quit()
