class_name GameTheme3D
extends Resource

## GameTheme3D: A direcao de arte de um jogo, em dados.
##
## A cena 3D e a mesma para todos os jogos; o que muda e este recurso. Assim
## Damas parece um tabuleiro de salao e Senet parece uma peca de museu egipcio
## sem que exista uma cena, uma iluminacao ou um material duplicado.
##
## Adicionar um jogo novo = escrever um GameTheme3D, nao copiar arquivos.

## Superficie de jogo (o pano/madeira logo abaixo das pecas).
@export var surface: StringName = &"felt"
@export var surface_color: Color = Color(0.07, 0.31, 0.19)

## Movel em volta (a mesa propriamente dita).
@export var table_material: StringName = &"wood_mahogany"

## Luz principal: da o volume e projeta a sombra.
@export var key_color: Color = Color(1.0, 0.96, 0.90)
@export var key_energy: float = 1.15
@export var key_angle_deg: Vector2 = Vector2(-52.0, -38.0)

## Preenchimento: levanta a sombra para que ela nunca fique preta.
@export var fill_color: Color = Color(0.62, 0.72, 0.92)
@export var fill_energy: float = 0.34

## Contraluz: separa a peca do fundo pela borda.
@export var rim_color: Color = Color(1.0, 0.90, 0.76)
@export var rim_energy: float = 0.45

## Luz ambiente do ceu.
@export var ambient_color: Color = Color(0.30, 0.33, 0.40)
@export var ambient_energy: float = 0.55

## Cor de acento do jogo (destaques, particulas de vitoria, HUD 3D).
@export var accent: Color = Color(0.96, 0.78, 0.32)

## Inclinacao preferida da camera.
@export var camera_tilt: float = Tokens3D.CAM_TILT_BOARD

## Intensidade do brilho geral. Contido: brilho nao e acabamento.
@export var glow_strength: float = 0.18

# ---------------------------------------------------------------------------
# Presets. Cada um e um ponto de partida com identidade propria; os jogos
# ajustam o que precisarem depois.
# ---------------------------------------------------------------------------

## Mesa de carteado: feltro verde, luz quente baixa, madeira escura.
static func casino_green() -> GameTheme3D:
	var t := GameTheme3D.new()
	t.surface = &"felt"
	t.surface_color = Color(0.055, 0.29, 0.175)
	t.table_material = &"wood_mahogany"
	t.key_color = Color(1.0, 0.94, 0.84)
	t.key_energy = 1.20
	t.fill_color = Color(0.55, 0.68, 0.90)
	t.fill_energy = 0.30
	t.rim_color = Color(1.0, 0.88, 0.70)
	t.rim_energy = 0.50
	t.ambient_color = Color(0.26, 0.30, 0.36)
	t.ambient_energy = 0.50
	t.accent = Color(0.96, 0.80, 0.34)
	t.camera_tilt = Tokens3D.CAM_TILT_CARDS
	return t

## Salao de jogos: nogueira, marfim, luz de abajur.
static func parlour_walnut() -> GameTheme3D:
	var t := GameTheme3D.new()
	t.surface = &"wood_walnut"
	t.surface_color = Color(0.20, 0.13, 0.09)
	t.table_material = &"leather"
	t.key_color = Color(1.0, 0.95, 0.87)
	t.key_energy = 1.25
	t.fill_color = Color(0.60, 0.70, 0.92)
	t.fill_energy = 0.32
	t.rim_color = Color(1.0, 0.92, 0.78)
	t.rim_energy = 0.52
	t.ambient_color = Color(0.30, 0.32, 0.38)
	t.ambient_energy = 0.56
	t.accent = Color(0.94, 0.76, 0.32)
	t.camera_tilt = Tokens3D.CAM_TILT_BOARD
	return t

## Pedra e cal: mesa clara, luz neutra, para pecas escuras.
static func stone_gallery() -> GameTheme3D:
	var t := GameTheme3D.new()
	t.surface = &"marble_white"
	t.surface_color = Color(0.88, 0.87, 0.84)
	t.table_material = &"slate"
	t.key_color = Color(1.0, 0.98, 0.95)
	t.key_energy = 1.05
	t.fill_color = Color(0.70, 0.78, 0.92)
	t.fill_energy = 0.38
	t.rim_color = Color(0.92, 0.94, 1.0)
	t.rim_energy = 0.40
	t.ambient_color = Color(0.38, 0.40, 0.45)
	t.ambient_energy = 0.68
	t.accent = Color(0.34, 0.52, 0.86)
	t.camera_tilt = Tokens3D.CAM_TILT_BOARD
	return t

## Areia e ouro: paleta egipcia para Senet.
static func desert_gold() -> GameTheme3D:
	var t := GameTheme3D.new()
	t.surface = &"wood_olive"
	t.surface_color = Color(0.55, 0.45, 0.26)
	t.table_material = &"slate"
	t.key_color = Color(1.0, 0.90, 0.72)
	t.key_energy = 1.30
	t.fill_color = Color(0.72, 0.66, 0.86)
	t.fill_energy = 0.30
	t.rim_color = Color(1.0, 0.84, 0.56)
	t.rim_energy = 0.55
	t.ambient_color = Color(0.36, 0.32, 0.28)
	t.ambient_energy = 0.58
	t.accent = Color(0.95, 0.74, 0.26)
	t.camera_tilt = Tokens3D.CAM_TILT_TRACK
	return t

## Aco e vidro: paleta fria e tecnica para Batalha Naval e Campo Minado.
static func steel_blue() -> GameTheme3D:
	var t := GameTheme3D.new()
	t.surface = &"slate"
	t.surface_color = Color(0.16, 0.20, 0.26)
	t.table_material = &"slate"
	t.key_color = Color(0.94, 0.97, 1.0)
	t.key_energy = 1.10
	t.fill_color = Color(0.52, 0.70, 0.95)
	t.fill_energy = 0.40
	t.rim_color = Color(0.70, 0.86, 1.0)
	t.rim_energy = 0.48
	t.ambient_color = Color(0.26, 0.31, 0.40)
	t.ambient_energy = 0.60
	t.accent = Color(0.36, 0.74, 0.96)
	t.camera_tilt = Tokens3D.CAM_TILT_TRACK
	return t

## Madeira clara e cor forte: jogos de familia (Ludo, Quatro em Linha).
static func bright_playroom() -> GameTheme3D:
	var t := GameTheme3D.new()
	t.surface = &"wood_maple"
	t.surface_color = Color(0.82, 0.70, 0.52)
	t.table_material = &"wood_walnut"
	t.key_color = Color(1.0, 0.98, 0.94)
	t.key_energy = 1.20
	t.fill_color = Color(0.66, 0.76, 0.94)
	t.fill_energy = 0.42
	t.rim_color = Color(1.0, 0.94, 0.84)
	t.rim_energy = 0.42
	t.ambient_color = Color(0.38, 0.40, 0.44)
	t.ambient_energy = 0.70
	t.accent = Color(0.94, 0.44, 0.24)
	t.camera_tilt = Tokens3D.CAM_TILT_BOARD
	return t

## Retorna o material da superficie de jogo ja resolvido.
func build_surface_material() -> StandardMaterial3D:
	match surface:
		&"felt":
			return MaterialFactory3D.get_felt_casino(surface_color)
		&"leather":
			return MaterialFactory3D.get_leather(surface_color)
		_:
			return MaterialFactory3D.by_name(String(surface))

func build_table_material() -> StandardMaterial3D:
	if table_material == &"leather":
		return MaterialFactory3D.get_leather()
	return MaterialFactory3D.by_name(String(table_material))
