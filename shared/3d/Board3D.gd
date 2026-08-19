class_name Board3D
extends Node3D

## Board3D: Gerenciador de Tabuleiros 3D com malhas elegantes, moldura em madeira nobre e mapeamento de coordenadas

signal cell_clicked(row: int, col: int)

@export var rows: int = 8
@export var cols: int = 8
@export var cell_size: float = 0.8
@export var board_style: String = "wood_checkered" # "wood_checkered", "felt_grid", "slate_grid", "reversi_green", "ocean_radar"

@onready var frame_mesh: MeshInstance3D = $FrameMesh
@onready var cells_root: Node3D = $CellsRoot
@onready var hover_marker: MeshInstance3D = $HoverMarker

var cell_meshes: Array = []
var selected_coord: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	setup_board(rows, cols, cell_size, board_style)

func setup_board(p_rows: int, p_cols: int, p_cell_size: float = 0.8, p_style: String = "wood_checkered") -> void:
	rows = p_rows
	cols = p_cols
	cell_size = p_cell_size
	board_style = p_style
	
	for c in cells_root.get_children():
		c.queue_free()
	cell_meshes.clear()
	
	var total_w = cols * cell_size
	var total_h = rows * cell_size
	
	# Moldura de madeira nobre ao redor do tabuleiro
	if frame_mesh:
		var b_mesh = BoxMesh.new()
		b_mesh.size = Vector3(total_w + 0.5, 0.18, total_h + 0.5)
		frame_mesh.mesh = b_mesh
		frame_mesh.position = Vector3(0, -0.09, 0)
		frame_mesh.material_override = MaterialFactory3D.get_wood_mahogany()
		
	var start_x = -(total_w * 0.5) + (cell_size * 0.5)
	var start_z = -(total_h * 0.5) + (cell_size * 0.5)
	
	for r in range(rows):
		var row_arr = []
		for c in range(cols):
			var tile = MeshInstance3D.new()
			var tile_mesh = BoxMesh.new()
			tile_mesh.size = Vector3(cell_size * 0.95, 0.05, cell_size * 0.95)
			tile.mesh = tile_mesh
			
			var pos_x = start_x + (c * cell_size)
			var pos_z = start_z + (r * cell_size)
			tile.position = Vector3(pos_x, 0.025, pos_z)
			
			_apply_tile_material(tile, r, c)
			cells_root.add_child(tile)
			row_arr.append(tile)
		cell_meshes.append(row_arr)

func _apply_tile_material(tile: MeshInstance3D, r: int, c: int) -> void:
	match board_style:
		"wood_checkered":
			var is_dark = (r + c) % 2 == 1
			tile.material_override = MaterialFactory3D.get_wood_walnut() if is_dark else MaterialFactory3D.get_wood_maple()
		"reversi_green":
			tile.material_override = MaterialFactory3D.get_felt_casino(Color(0.08, 0.4, 0.22))
		"slate_grid":
			var is_alt = (r + c) % 2 == 1
			var col = Color(0.18, 0.2, 0.24) if is_alt else Color(0.24, 0.27, 0.32)
			tile.material_override = MaterialFactory3D.get_plastic(col, false)
		"ocean_radar":
			tile.material_override = MaterialFactory3D.get_felt_casino(Color(0.05, 0.15, 0.28))
		_:
			tile.material_override = MaterialFactory3D.get_wood_maple()

func get_cell_position_3d(r: int, c: int, height_offset: float = 0.08) -> Vector3:
	var total_w = cols * cell_size
	var total_h = rows * cell_size
	var start_x = -(total_w * 0.5) + (cell_size * 0.5)
	var start_z = -(total_h * 0.5) + (cell_size * 0.5)
	return Vector3(start_x + (c * cell_size), height_offset, start_z + (r * cell_size))

func highlight_cell(r: int, c: int, color: Color = Color(0.2, 0.85, 0.4)) -> void:
	if r >= 0 and r < rows and c >= 0 and c < cols:
		var tile = cell_meshes[r][c]
		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
		mat.roughness = 0.3
		tile.material_override = mat

func reset_cell_material(r: int, c: int) -> void:
	if r >= 0 and r < rows and c >= 0 and c < cols:
		var tile = cell_meshes[r][c]
		_apply_tile_material(tile, r, c)
