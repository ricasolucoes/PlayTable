extends BaseGame

## PokerGame: Video Poker 3D com Cartas Reais em Cassino, Seleção de Reter e Animações de Troca

var deck: Deck
var player_hand: CardHand
var held_cards = [false, false, false, false, false]
var cards_3d: Array[Card3D] = []

## Ficha "RETER" por carta retida, indexada pelo lugar na mao.
var _hold_markers: Dictionary = {}

var chips: int = 100
var current_bet: int = 5
var game_phase: String = "bet" # "bet", "hold", "result"

@onready var cards_root: Node3D = $CardsRoot
@onready var chips_label: Label = $UI/VBoxContainer/Header/ChipsLabel
@onready var bet_label: Label = $UI/VBoxContainer/Header/BetLabel
@onready var payout_table_label: Label = $UI/VBoxContainer/PayoutTableContainer/PayoutLabel
@onready var btn_action: Button = $UI/Controls/BtnAction
@onready var btn_bet_minus: Button = $UI/Controls/BtnBetMinus
@onready var btn_bet_plus: Button = $UI/Controls/BtnBetPlus

const CARD_SPACING_X: float = 0.75

## Zona da mao no feltro, e onde ela fica.
const ZONE_SIZE := Vector2(4.05, 1.95)
const HAND_Z := 0.15

## A zona nasce um pouco atras da fileira: a faixa que sobra no fundo e onde as
## fichas RETER cabem sem encostar na carta nem no rotulo da borda de baixo.
const ZONE_Z := HAND_Z - 0.20

func _ready() -> void:
	# Video poker nao tem fim de partida nem botao reiniciar: das rodadas cuida
	# o game_phase abaixo, e de BaseGame vem so a navegacao de volta.
	menu_scene_path = MENU_CARTAS
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/StatusLabel
	env_3d.set_felt_color(Color(0.2, 0.08, 0.28)) # Feltro Púrpura Imperial
	# A HUD come 250 px em cima e os controles 120 embaixo. Sem informar isso a
	# camera usava o enquadramento padrao de 6x6 para uma mao que nao passa de
	# 3,8: as cartas ficavam pequenas demais para ler o naipe.
	fit_table(Vector2(ZONE_SIZE.x + 0.10, ZONE_SIZE.y + 0.55), Vector3(0.0, 0.0, ZONE_Z))
	cards_root.add_child(TableZone3D.create(ZONE_SIZE, Vector3(0.0, 0.0, ZONE_Z),
		"SUA MÃO", Color(0.98, 0.84, 0.42)))
	player_hand = CardHand.new()
	_update_payout_table()
	_reset_to_bet_phase()


## Posicao de repouso da carta `i` na fileira da mao.
func _card_slot(i: int) -> Vector3:
	var start_x := -CARD_SPACING_X * 2.0
	return Vector3(start_x + float(i) * CARD_SPACING_X, 0.05, HAND_Z)

func _update_payout_table() -> void:
	payout_table_label.text = "Royal Flush (800x) | Straight Flush (50x) | Quadra (25x) | Full House (9x)\nFlush (6x) | Sequência (4x) | Trinca (3x) | Dois Pares (2x) | Par J+ (1x)"

## Nova rodada: destrava o resultado para a mao seguinte tambem ser contada.
## O Video Poker nao passa por `restart_game()`, que e quem normalmente
## destrava, porque nao tem botao de reiniciar -- a rodada recomeca sozinha.
func _reset_to_bet_phase() -> void:
	_result_reported = false
	begin_match()
	game_phase = "bet"
	if chips <= 0:
		chips = 50
		set_status("Recarga grátis de 50 fichas!")
	else:
		set_status("Ajuste sua aposta e clique em 'DAR CARTAS'!")
		
	held_cards = [false, false, false, false, false]
	_clear_cards()
	
	btn_bet_minus.disabled = false
	btn_bet_plus.disabled = false
	btn_action.text = "🃏 DAR CARTAS"
	_update_chips_ui()

func _update_chips_ui() -> void:
	chips_label.text = "💰 Fichas: %d" % chips
	bet_label.text = "Aposta: %d" % current_bet

func _on_btn_action_pressed() -> void:
	if game_phase == "bet":
		if chips < current_bet:
			set_status("Fichas insuficientes para esta aposta!")
			return
		chips -= current_bet
		_update_chips_ui()
		
		deck = Deck.create_standard_52(true)
		deck.shuffle()
		player_hand.clear()
		
		_clear_cards()

		for i in range(5):
			var card := deck.draw()
			player_hand.add(card)
			_spawn_card(card, i, 0.4 + float(i) * 0.05)

		btn_bet_minus.disabled = true
		btn_bet_plus.disabled = true
		btn_action.text = "🔄 TROCAR CARTAS"
		game_phase = "hold"
		set_status("Toque nas cartas que deseja RETER (HOLD)!")
		
	elif game_phase == "hold":
		# Troca as cartas não retidas
		for i in range(5):
			if not held_cards[i]:
				var new_card := deck.draw()
				player_hand.cards[i] = new_card
				cards_3d[i].queue_free()
				cards_3d[i] = null
				_spawn_card(new_card, i, 0.4)
			else:
				_set_hold_marker(i, false)

		game_phase = "result"
		_evaluate_poker_hand()


## Cria a carta `i` da mao, saindo do sabot no canto da mesa.
func _spawn_card(card: Card, i: int, delay: float) -> void:
	var c_3d: Card3D = preload("res://shared/3d/Card3D.tscn").instantiate()
	c_3d.setup(card.get_display_value(), card.get_suit_symbol(), true)
	c_3d.position = Vector3(2.5, 0.4, -1.8)
	# O toque entra pela propria carta. Havia cinco botoes opacos de 75x120
	# ancorados no centro da tela, sempre por cima das cartas: era essa a mancha
	# escura que escondia a mao inteira.
	c_3d.card_clicked.connect(_on_card_clicked.bind(i))
	cards_root.add_child(c_3d)
	if i < cards_3d.size():
		cards_3d[i] = c_3d
	else:
		cards_3d.append(c_3d)
	c_3d.deal_to(_card_slot(i), 0.0, delay)


func _clear_cards() -> void:
	# Nao pode ser `cards_root.get_children()`: a zona serigrafada no feltro
	# tambem mora ai e some junto.
	for c in cards_3d:
		if is_instance_valid(c):
			c.queue_free()
	cards_3d.clear()
	for m in _hold_markers.values():
		if is_instance_valid(m):
			m.queue_free()
	_hold_markers.clear()


func _on_card_clicked(_card: Card3D, idx: int) -> void:
	if game_phase != "hold": return
	held_cards[idx] = not held_cards[idx]
	cards_3d[idx].select(held_cards[idx])
	_set_hold_marker(idx, held_cards[idx])
	play_click()


## Ficha "RETER" no feltro, acima da carta retida -- do lado de dentro da zona,
## para nao esbarrar no rotulo SUA MAO que fica na borda de baixo.
func _set_hold_marker(idx: int, on: bool) -> void:
	if _hold_markers.has(idx):
		var old: Node = _hold_markers[idx]
		if is_instance_valid(old):
			old.queue_free()
		_hold_markers.erase(idx)
	if not on:
		return
	var lbl := Label3D.new()
	lbl.text = "RETER"
	lbl.font_size = 48
	lbl.pixel_size = 0.0026
	lbl.modulate = Color(0.99, 0.86, 0.36)
	lbl.outline_size = 14
	lbl.outline_modulate = Color(0, 0, 0, 0.8)
	lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	lbl.shaded = false
	lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	var slot := _card_slot(idx)
	lbl.position = Vector3(slot.x, 0.03, slot.z - Tokens3D.CARD_LENGTH * 0.5 - 0.22)
	cards_root.add_child(lbl)
	_hold_markers[idx] = lbl

func _evaluate_poker_hand() -> void:
	var result := PokerEvaluator.evaluate(player_hand.get_all())
	var hand_name = result["name"]
	var mult = result["multiplier"]
	var win_amount = current_bet * mult

	# Cada mao e uma partida. O Poker nunca reportou nenhuma: nao dava XP, nao
	# contava para o placar de fichas e o Royal Flush -- a conquista mais cara
	# do catalogo -- era impossivel de tirar. `hand` leva o nome da mao para o
	# GamificationManager reconhecer o royal flush sem conhecer o poker.
	report_match_result(mult > 0, {
		"score": chips + win_amount,
		"hand": str(hand_name),
		"bet": current_bet,
		"perfect": mult >= 50,
	})

	if mult > 0:
		chips += win_amount
		set_status("🏆 %s! Você ganhou %d fichas!" % [hand_name, win_amount])
		env_3d.celebrate_win()
	else:
		set_status("%s. Nenhuma combinação premiada." % hand_name)
		
	for i in range(5):
		_set_hold_marker(i, false)
	_update_chips_ui()
	btn_action.text = "🃏 NOVA RODADA"
	btn_bet_minus.disabled = false
	btn_bet_plus.disabled = false
	game_phase = "bet"

func _on_btn_bet_minus_pressed() -> void:
	if game_phase != "bet": return
	current_bet = max(5, current_bet - 5)
	_update_chips_ui()

func _on_btn_bet_plus_pressed() -> void:
	if game_phase != "bet": return
	current_bet = min(chips, current_bet + 5)
	_update_chips_ui()
