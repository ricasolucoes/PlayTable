class_name MeshBuilder3D
extends RefCounted

## MeshBuilder3D: Construtor procedural de geometrias 3D elegantes para jogos de mesa

# --- Fichas e Discos 3D (Damas, Reversi, Quatro em Linha, Resta Um) ---

static func create_cylinder_token(radius: float = 0.4, height: float = 0.12, radial_segments: int = 32) -> CylinderMesh:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = radial_segments
	return mesh

static func create_sphere_token(radius: float = 0.35, rings: int = 16, radial_segments: int = 32) -> SphereMesh:
	var mesh = SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.rings = rings
	mesh.radial_segments = radial_segments
	return mesh

# --- Pedras de Dominó 3D ---

static func create_domino_tile(length: float = 1.0, width: float = 0.5, thickness: float = 0.12) -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	return mesh

# --- Cartas de Baralho 3D ---

static func create_card_mesh(width: float = 0.7, length: float = 1.0, thickness: float = 0.006) -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(width, thickness, length)
	return mesh

# --- Dados 3D ---

static func create_dice_cube(size: float = 0.5) -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size, size, size)
	return mesh

# --- Peões / Cones 3D (Ludo, Senet) ---

static func create_pawn_meeple(height: float = 0.7, base_radius: float = 0.22, top_radius: float = 0.1) -> CylinderMesh:
	var mesh = CylinderMesh.new()
	mesh.bottom_radius = base_radius
	mesh.top_radius = top_radius
	mesh.height = height
	mesh.radial_segments = 24
	return mesh

# --- Pinos / Marcadores Navais 3D (Batalha Naval) ---

static func create_peg_pin(height: float = 0.4, radius: float = 0.08) -> CylinderMesh:
	var mesh = CylinderMesh.new()
	mesh.top_radius = radius * 1.5
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 16
	return mesh

# --- Blocos / Caixas de Tabuleiro com Moldura 3D ---

static func create_board_slab(size_x: float, size_z: float, thickness: float = 0.15) -> BoxMesh:
	var mesh = BoxMesh.new()
	mesh.size = Vector3(size_x, thickness, size_z)
	return mesh
