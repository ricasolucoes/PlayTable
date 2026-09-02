class_name SudokuCell
extends Button

signal cell_clicked(row: int, col: int)

var row: int
var col: int
var is_fixed: bool = false
var value: int = 0
var notes: Array = []

@onready var notes_label = $Notes

func _ready() -> void:
	pressed.connect(_on_pressed)
	# Garante que o label de notas não intercepte o clique
	notes_label.mouse_filter = Control.MOUSE_FILTER_IGNORE

func setup(r: int, c: int) -> void:
	row = r
	col = c

func set_fixed_value(v: int) -> void:
	is_fixed = true
	value = v
	text = str(v)
	add_theme_color_override("font_color", Color.WHITE)
	disabled = true
	notes_label.text = ""

func set_user_value(v: int) -> void:
	if is_fixed:
		return
	value = v
	if v == 0:
		text = ""
		_update_notes_display()
	else:
		text = str(v)
		# Cor para os números inseridos pelo usuário (ex: amarelo/dourado para combinar com PlayTable)
		add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))
		notes_label.text = ""

func toggle_note(n: int) -> void:
	if is_fixed or value != 0:
		return
	if notes.has(n):
		notes.erase(n)
	else:
		notes.append(n)
	notes.sort()
	_update_notes_display()

func highlight(active: bool, is_error: bool = false) -> void:
	if is_error:
		add_theme_color_override("font_color", Color.RED)
		return
		
	if active:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 1, 1, 0.2)
		add_theme_stylebox_override("normal", style)
		add_theme_stylebox_override("disabled", style)
	else:
		remove_theme_stylebox_override("normal")
		remove_theme_stylebox_override("disabled")
		if is_fixed:
			add_theme_color_override("font_color", Color.WHITE)
		elif value != 0:
			add_theme_color_override("font_color", Color(1.0, 0.85, 0.25))

func _update_notes_display() -> void:
	if value != 0:
		notes_label.text = ""
		return
		
	if notes.is_empty():
		notes_label.text = ""
		return
		
	var s = ""
	for i in range(1, 10):
		if notes.has(i):
			s += str(i) + " "
		else:
			s += "  "
		if i % 3 == 0 and i != 9:
			s += "\n"
	notes_label.text = s

func _on_pressed() -> void:
	if not is_fixed:
		cell_clicked.emit(row, col)
