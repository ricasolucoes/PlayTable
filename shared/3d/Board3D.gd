class_name Board3D
extends Node3D

## Board3D: Tabuleiro em grade, com moldura, rebaixo e estados de casa.
##
## Desenho: as casas nao sao um MeshInstance3D cada. Um tabuleiro 10x10 assim
## custaria 100 nos e 100 draw calls. Aqui existem dois MultiMesh (casas claras
## e casas escuras) e um terceiro para os marcadores de estado -- tres draw
## calls, independente do tamanho da grade.
##
## O toque tambem nao usa 100 colisores: um unico BoxShape3D cobre o tabuleiro
## e a casa sai da posicao local do ponto atingido.

signal cell_clicked(row: int, col: int)
signal cell_hovered(row: int, col: int)

enum CellState {
	NORMAL,     ## Casa em repouso.
	VALID,      ## Destino possivel da jogada atual.
	SELECTED,   ## Origem escolhida.
	LAST_MOVE,  ## Participou da jogada anterior.
	INVALID,    ## Recusada agora ha pouco.
	DISABLED,   ## Fora do jogo (buracos, casas mortas).
	HIGHLIGHT,  ## Destaque neutro definido pelo jogo.
}

@export var rows: int = 8
@export var cols: int = 8
@export var cell_size: float = 0.8
@export var board_style: String = "wood_checkered"

## Quando falso, o tabuleiro nao desenha moldura (trilhas, grades soltas).
@export var show_frame: bool = true

@onready var frame_mesh: MeshInstance3D = $FrameMesh
@onready var inlay_mesh: MeshInstance3D = $InlayMesh
@onready var cells_root: Node3D = $CellsRoot
@onready var picker: Area3D = $Picker
@onready var picker_shape: CollisionShape3D = $Picker/CollisionShape3D

var _mm_light: MultiMeshInstance3D
var _mm_dark: MultiMeshInstance3D
var _mm_marker: MultiMeshInstance3D

var _base_colors: PackedColorArray = PackedColorArray()
var _states: Array[int] = []
var _disabled: Dictionary = {}
var _hover_cell: Vector2i = Vector2i(-1, -1)

func _ready() -> void:
	if cells_root.get_child_count() == 0:
		setup_board(rows, cols, cell_size, board_style)

# ---------------------------------------------------------------------------
# Montagem
# ---------------------------------------------------------------------------

func setup_board(p_rows: int, p_cols: int, p_cell_size: float = 0.8, p_style: String = "wood_checkered") -> void:
	rows = maxi(p_rows, 1)
	cols = maxi(p_cols, 1)
	cell_size = p_cell_size
	board_style = p_style

	for child in cells_root.get_children():
		child.queue_free()
	_mm_light = null
	_mm_dark = null
	_mm_marker = null
	_disabled.clear()

	_states.clear()
	_states.resize(rows * cols)
	_states.fill(CellState.NORMAL)
	_base_colors.resize(rows * cols)

	_build_tiles()
	_build_markers()
	_build_frame()
	_build_picker()
	_refresh_all_instances()

func _build_tiles() -> void:
	# Uma casa e um bloco baixo, nao um plano: a espessura e o que faz a grade
	# ter sombra propria entre as casas.
	var tile := BoxMesh.new()
	tile.size = Vector3(cell_size * 0.985, Tokens3D.TILE_THICKNESS, cell_size * 0.985)

	var pair := _style_materials()
	_mm_light = _make_multimesh(tile, pair[0])
	_mm_dark = _make_multimesh(tile, pair[1])
	cells_root.add_child(_mm_light)
	cells_root.add_child(_mm_dark)

	var light_count := 0
	var dark_count := 0
	for r in rows:
		for c in cols:
			if _is_dark_cell(r, c):
				dark_count += 1
			else:
				light_count += 1

	_mm_light.multimesh.instance_count = light_count
	_mm_dark.multimesh.instance_count = dark_count

func _make_multimesh(mesh: Mesh, material: StandardMaterial3D) -> MultiMeshInstance3D:
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mmi.multimesh = mm
	# O material precisa ler a cor por instancia, senao o estado da casa nao
	# aparece e voltamos a precisar de um material por casa.
	var mat := material.duplicate() as StandardMaterial3D
	mat.vertex_color_use_as_albedo = true
	mmi.material_override = mat
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return mmi

func _build_markers() -> void:
	# Marcador de estado: um anel baixo que pousa sobre a casa. E uma FORMA,
	# nao so uma cor -- exigencia de acessibilidade.
	var ring := TorusMesh.new()
	ring.inner_radius = cell_size * 0.26
	ring.outer_radius = cell_size * 0.34
	ring.rings = 4
	ring.ring_segments = Quality3D.radial_segments(20)

	_mm_marker = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = ring
	mm.instance_count = rows * cols
	mm.visible_instance_count = 0
	_mm_marker.multimesh = mm
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.albedo_color = Color.WHITE
	mat.emission_enabled = true
	mat.emission = Color.WHITE
	mat.emission_energy_multiplier = 0.7
	mat.roughness = 0.45
	_mm_marker.material_override = mat
	_mm_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	cells_root.add_child(_mm_marker)

func _build_frame() -> void:
	var total_w := cols * cell_size
	var total_h := rows * cell_size

	if not show_frame:
		if frame_mesh:
			frame_mesh.visible = false
		if inlay_mesh:
			inlay_mesh.visible = false
		return

	# Moldura: bloco maior por baixo, com o rebaixo escuro entre ela e as casas.
	if frame_mesh:
		frame_mesh.visible = true
		var slab := BoxMesh.new()
		var fw := Tokens3D.BOARD_FRAME_WIDTH
		slab.size = Vector3(total_w + fw * 2.0, Tokens3D.BOARD_SLAB_THICKNESS, total_h + fw * 2.0)
		frame_mesh.mesh = slab
		frame_mesh.position = Vector3(0.0, -Tokens3D.BOARD_SLAB_THICKNESS * 0.5, 0.0)
		frame_mesh.material_override = _frame_material()

	# Rebaixo: uma placa fina e escura logo abaixo das casas. E ela que da a
	# linha de sombra entre a moldura e a area de jogo.
	if inlay_mesh:
		inlay_mesh.visible = true
		var inlay := BoxMesh.new()
		inlay.size = Vector3(total_w + 0.06, 0.05, total_h + 0.06)
		inlay_mesh.mesh = inlay
		inlay_mesh.position = Vector3(0.0, -0.012, 0.0)
		inlay_mesh.material_override = MaterialFactory3D.get_wood_ebony()
		inlay_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _build_picker() -> void:
	if picker_shape == null:
		return
	var box := BoxShape3D.new()
	box.size = Vector3(cols * cell_size, 0.12, rows * cell_size)
	picker_shape.shape = box
	picker_shape.position = Vector3(0.0, 0.02, 0.0)

# ---------------------------------------------------------------------------
# Estilos
# ---------------------------------------------------------------------------

func _is_dark_cell(r: int, c: int) -> bool:
	match board_style:
		"wood_checkered", "marble_checkered", "slate_grid":
			return (r + c) % 2 == 1
		_:
			# Grades uniformes ainda alternam de leve para nao virar um bloco
			# chapado, mas com contraste muito baixo.
			return (r + c) % 2 == 1

func _style_materials() -> Array[StandardMaterial3D]:
	match board_style:
		"wood_checkered":
			return [MaterialFactory3D.get_wood_maple(), MaterialFactory3D.get_wood_walnut()]
		"marble_checkered":
			return [MaterialFactory3D.get_marble_white(), MaterialFactory3D.get_marble_black()]
		"reversi_green", "felt_grid":
			var felt := MaterialFactory3D.get_felt_casino(Color(0.07, 0.33, 0.20))
			return [felt, felt]
		"slate_grid":
			return [MaterialFactory3D.get_slate(), MaterialFactory3D.get_slate()]
		"ocean_radar":
			var deep := MaterialFactory3D.get_plastic(Color(0.10, 0.20, 0.34), false)
			return [deep, deep]
		"sand_track":
			return [MaterialFactory3D.get_wood_olive(), MaterialFactory3D.get_wood_olive()]
		_:
			return [MaterialFactory3D.get_wood_maple(), MaterialFactory3D.get_wood_walnut()]

func _frame_material() -> StandardMaterial3D:
	match board_style:
		"marble_checkered", "slate_grid":
			return MaterialFactory3D.get_slate()
		"ocean_radar":
			return MaterialFactory3D.get_plastic(Color(0.16, 0.19, 0.24), false)
		"sand_track":
			return MaterialFactory3D.get_wood_ebony()
		_:
			return MaterialFactory3D.get_wood_mahogany()

## Tom base da casa antes de qualquer estado. Grades uniformes recebem uma
## alternancia muito sutil para a leitura de linha/coluna nao se perder.
func _base_color(r: int, c: int) -> Color:
	var dark := _is_dark_cell(r, c)
	match board_style:
		"reversi_green", "felt_grid":
			return Color(0.94, 0.94, 0.94) if dark else Color(1.02, 1.02, 1.02)
		"ocean_radar":
			return Color(0.92, 0.94, 0.98) if dark else Color(1.04, 1.06, 1.10)
		"slate_grid":
			return Color(0.88, 0.90, 0.94) if dark else Color(1.06, 1.08, 1.12)
		"sand_track":
			return Color(0.92, 0.90, 0.86) if dark else Color(1.05, 1.03, 0.99)
		_:
			return Color.WHITE

# ---------------------------------------------------------------------------
# Coordenadas
# ---------------------------------------------------------------------------

## Tamanho total ocupado pelo tabuleiro, para o enquadramento da camera.
func content_size() -> Vector2:
	var frame := (Tokens3D.BOARD_FRAME_WIDTH * 2.0) if show_frame else 0.0
	return Vector2(cols * cell_size + frame, rows * cell_size + frame)

func get_cell_position_3d(r: int, c: int, height_offset: float = 0.06) -> Vector3:
	var start_x := -(cols * cell_size * 0.5) + (cell_size * 0.5)
	var start_z := -(rows * cell_size * 0.5) + (cell_size * 0.5)
	return Vector3(start_x + (c * cell_size), height_offset, start_z + (r * cell_size))

## Converte um ponto do mundo na casa correspondente, ou (-1,-1) fora da grade.
func world_to_cell(world_point: Vector3) -> Vector2i:
	var local := to_local(world_point)
	var c := int(floor((local.x + cols * cell_size * 0.5) / cell_size))
	var r := int(floor((local.z + rows * cell_size * 0.5) / cell_size))
	if r < 0 or r >= rows or c < 0 or c >= cols:
		return Vector2i(-1, -1)
	return Vector2i(r, c)

func is_valid_cell(r: int, c: int) -> bool:
	return r >= 0 and r < rows and c >= 0 and c < cols

# ---------------------------------------------------------------------------
# Estados de casa
# ---------------------------------------------------------------------------

func set_cell_state(r: int, c: int, state: int) -> void:
	if not is_valid_cell(r, c):
		return
	_states[r * cols + c] = state
	_refresh_all_instances()

## Limpa todos os estados de uma vez. Uma unica reconstrucao dos buffers,
## em vez de uma por casa.
func clear_states(except: int = -1) -> void:
	for i in _states.size():
		if except >= 0 and _states[i] == except:
			continue
		_states[i] = CellState.NORMAL
	_refresh_all_instances()

## Aplica um estado a varias casas de uma vez.
func set_cells_state(cells: Array, state: int) -> void:
	for cell in cells:
		var v: Vector2i = cell
		if is_valid_cell(v.x, v.y):
			_states[v.x * cols + v.y] = state
	_refresh_all_instances()

## Marca uma casa como fora de jogo (buraco de Resta Um, cova vazia).
func set_cell_disabled(r: int, c: int, disabled: bool) -> void:
	if not is_valid_cell(r, c):
		return
	if disabled:
		_disabled[Vector2i(r, c)] = true
		_states[r * cols + c] = CellState.DISABLED
	else:
		_disabled.erase(Vector2i(r, c))
		_states[r * cols + c] = CellState.NORMAL
	_refresh_all_instances()

## Compatibilidade com a API antiga.
func highlight_cell(r: int, c: int, color: Color = Tokens3D.COLOR_VALID) -> void:
	var state := CellState.HIGHLIGHT
	if color.is_equal_approx(Tokens3D.COLOR_SELECTED):
		state = CellState.SELECTED
	elif color.is_equal_approx(Tokens3D.COLOR_VALID):
		state = CellState.VALID
	set_cell_state(r, c, state)

func reset_cell_material(r: int, c: int) -> void:
	set_cell_state(r, c, CellState.NORMAL)

func _state_tint(state: int) -> Color:
	match state:
		CellState.VALID:
			return Tokens3D.COLOR_VALID.lerp(Color.WHITE, 0.35)
		CellState.SELECTED:
			return Tokens3D.COLOR_SELECTED.lerp(Color.WHITE, 0.25)
		CellState.LAST_MOVE:
			return Tokens3D.COLOR_LAST_MOVE.lerp(Color.WHITE, 0.55)
		CellState.INVALID:
			return Tokens3D.COLOR_INVALID.lerp(Color.WHITE, 0.30)
		CellState.HIGHLIGHT:
			return Tokens3D.COLOR_HINT.lerp(Color.WHITE, 0.40)
		CellState.DISABLED:
			return Color(0.42, 0.42, 0.44)
		_:
			return Color.WHITE

## Estados que ganham um anel visivel alem do tom. Sem isso a unica pista seria
## a cor, o que exclui quem nao distingue verde de vermelho.
func _state_marker_color(state: int) -> Color:
	match state:
		CellState.VALID:
			return Tokens3D.COLOR_VALID
		CellState.SELECTED:
			return Tokens3D.COLOR_SELECTED
		CellState.LAST_MOVE:
			return Tokens3D.COLOR_LAST_MOVE
		CellState.INVALID:
			return Tokens3D.COLOR_INVALID
		_:
			return Color.TRANSPARENT

func _refresh_all_instances() -> void:
	if _mm_light == null or _mm_dark == null or _mm_marker == null:
		return

	var light_i := 0
	var dark_i := 0
	var marker_i := 0
	var half_tile := Tokens3D.TILE_THICKNESS * 0.5

	for r in rows:
		for c in cols:
			var idx := r * cols + c
			var state: int = _states[idx]
			var pos := get_cell_position_3d(r, c, half_tile)
			var xform := Transform3D(Basis.IDENTITY, pos)
			var tint := _base_color(r, c) * _state_tint(state)

			if _is_dark_cell(r, c):
				_mm_dark.multimesh.set_instance_transform(dark_i, xform)
				_mm_dark.multimesh.set_instance_color(dark_i, tint)
				dark_i += 1
			else:
				_mm_light.multimesh.set_instance_transform(light_i, xform)
				_mm_light.multimesh.set_instance_color(light_i, tint)
				light_i += 1

			var marker_col := _state_marker_color(state)
			if marker_col.a > 0.0:
				var m_pos := get_cell_position_3d(r, c, Tokens3D.TILE_THICKNESS + 0.012)
				_mm_marker.multimesh.set_instance_transform(
					marker_i, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0, 0.5, 1.0)), m_pos))
				_mm_marker.multimesh.set_instance_color(marker_i, marker_col)
				marker_i += 1

	_mm_marker.multimesh.visible_instance_count = marker_i

# ---------------------------------------------------------------------------
# Toque / clique
# ---------------------------------------------------------------------------

## Com input_devices/pointing/emulate_mouse_from_touch ligado — o padrao, e o
## que o projeto usa — cada toque chega duas vezes: como InputEventScreenTouch
## e de novo como InputEventMouseButton emulado. Tratar as duas familias
## disparava cell_clicked duas vezes por toque. Com a emulacao ligada so o
## mouse conta; o toque cru so entra quando ela esta desligada.
var _touch_emulates_mouse: bool = ProjectSettings.get_setting(
	"input_devices/pointing/emulate_mouse_from_touch", true)


func _on_picker_input_event(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			_emit_cell_clicked(event_position)
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed and not _touch_emulates_mouse:
			_emit_cell_clicked(event_position)
	elif event is InputEventMouseMotion:
		var cell := world_to_cell(event_position)
		if cell != _hover_cell:
			_hover_cell = cell
			if cell.x >= 0:
				cell_hovered.emit(cell.x, cell.y)


func _emit_cell_clicked(world_point: Vector3) -> void:
	var cell := world_to_cell(world_point)
	if cell.x >= 0:
		cell_clicked.emit(cell.x, cell.y)

func _on_picker_mouse_exited() -> void:
	_hover_cell = Vector2i(-1, -1)
