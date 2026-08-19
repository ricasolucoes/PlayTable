extends Control

## MemoryGame: Jogo da Memória 3D com Cartas Reais em Feltro Azul Royal e Virada 3D Tridimensional

const CardScript = preload("res://shared/core_engine/cards/Card.gd")
const DeckScript = preload("res://shared/core_engine/cards/Deck.gd")
const MemoryRulesScript = preload("res://games/memoria/MemoryRules.gd")

var deck: Deck
var cards_grid: Array[Card] = []
var cards_3d: Array[Card3D] = []

var first_idx: int = -1
var second_idx: int = -1
var pairs_found: int = 0
var total_pairs: int = 8
var is_animating: bool = false

@onready var env_3d: TabletopEnvironment3D = $TabletopEnvironment3D
@onready var cards_root: Node3D = $CardsRoot
@onready var status = $UI/VBoxContainer/Status
@onready var btn_restart = $UI/VBoxContainer/BtnRestart
@onready var touch_grid = $UI/CenterContainer/TouchGrid

const GRID_COLS: int = 4
const GRID_ROWS: int = 4
const CARD_SPACING_X: float = 0.85
const CARD_SPACING_Z: float = 1.15

func _ready():
	env_3d.set_felt_color(Color(0.1, 0.2, 0.45)) # Feltro Azul Royal
	_setup_touch_grid()
	_start_new_game()

func _setup_touch_grid():
	for c in touch_grid.get_children(): c.queue_free()
	for i in range(16):
		var btn = Button.new()
		btn.custom_minimum_size = Vector2(75, 105)
		btn.flat = true
		btn.pressed.connect(_on_card_pressed.bind(i))
		touch_grid.add_child(btn)

func _start_new_game():
	pairs_found = 0
	is_animating = false
	first_idx = -1
	second_idx = -1
	btn_restart.hide()
	
	for c in cards_root.get_children(): c.queue_free()
	cards_3d.clear()
	
	deck = Deck.create_memory_deck()
	deck.shuffle()
	cards_grid = deck.cards.duplicate()
	total_pairs = cards_grid.size() / 2
	
	var total_w = GRID_COLS * CARD_SPACING_X
	var total_h = GRID_ROWS * CARD_SPACING_Z
	var start_x = -(total_w * 0.5) + (CARD_SPACING_X * 0.5)
	var start_z = -(total_h * 0.5) + (CARD_SPACING_Z * 0.5)
	
	for i in range(cards_grid.size()):
		var r = i / GRID_COLS
		var c = i % GRID_COLS
		var card = cards_grid[i]
		
		var card_3d = preload("res://shared/3d/Card3D.tscn").instantiate()
		card_3d.setup(card.get_display_value(), card.get_suit_symbol(), false)
		
		var target_pos = Vector3(start_x + (c * CARD_SPACING_X), 0.05, start_z + (r * CARD_SPACING_Z))
		card_3d.position = target_pos + Vector3(0, 3.0, 0)
		cards_root.add_child(card_3d)
		cards_3d.append(card_3d)
		
		card_3d.deal_to(target_pos, 0.0, 0.4 + (i * 0.03))
		
	status.text = "Pares Encontrados: 0 / %d" % total_pairs

func _on_card_pressed(idx: int):
	if is_animating or idx == first_idx or cards_3d[idx].is_face_up: return
	
	var card_3d = cards_3d[idx]
	card_3d.flip(true, 0.35)
	
	if first_idx == -1:
		first_idx = idx
	else:
		second_idx = idx
		is_animating = true
		get_tree().create_timer(0.6).timeout.connect(_check_match)

func _check_match():
	var c1 = cards_grid[first_idx]
	var c2 = cards_grid[second_idx]
	var c3d_1 = cards_3d[first_idx]
	var c3d_2 = cards_3d[second_idx]
	
	if MemoryRules.is_match(c1, c2):
		pairs_found += 1
		status.text = "✨ Par Encontrado! (%d / %d)" % [pairs_found, total_pairs]
		
		# Eleva e faz o par desaparecer com brilho
		var tween1 = create_tween().set_parallel(true)
		tween1.tween_property(c3d_1, "position:y", c3d_1.position.y + 0.8, 0.4)
		tween1.tween_property(c3d_1, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
		
		var tween2 = create_tween().set_parallel(true)
		tween2.tween_property(c3d_2, "position:y", c3d_2.position.y + 0.8, 0.4)
		tween2.tween_property(c3d_2, "scale", Vector3(0.01, 0.01, 0.01), 0.4)
		
		first_idx = -1
		second_idx = -1
		is_animating = false
		
		if pairs_found >= total_pairs:
			_end_game()
	else:
		# Não foi par: vira de volta
		c3d_1.flip(false, 0.35)
		c3d_2.flip(false, 0.35)
		await get_tree().create_timer(0.35).timeout
		first_idx = -1
		second_idx = -1
		is_animating = false
		status.text = "Pares Encontrados: %d / %d" % [pairs_found, total_pairs]

func _end_game():
	status.text = "🏆 Incrível! Você completou toda a memória 3D!"
	btn_restart.show()
	env_3d.celebrate_win()

func _on_btn_restart_pressed():
	_start_new_game()

func _on_btn_back_pressed():
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")
