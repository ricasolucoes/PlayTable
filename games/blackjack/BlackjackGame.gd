extends BaseGame

## BlackjackGame: 21 / Blackjack 3D com Cartas Físicas em Mesa de Cassino e Animação de Distribuição

var deck: Deck
var player_hand: CardHand
var dealer_hand: CardHand

var player_cards_3d: Array = []
var dealer_cards_3d: Array = []

## Onde cada lado da mesa fica, e quanto as cartas se sobrepoem na fileira.
const DEALER_Z := -1.30
const PLAYER_Z := 1.30
const CARD_PITCH := 0.52
const ZONE_SIZE := Vector2(3.15, 1.45)

@onready var cards_root: Node3D = $CardsRoot
@onready var btn_hit: Button = $UI/Buttons/BtnHit
@onready var btn_stand: Button = $UI/Buttons/BtnStand

func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	env_3d = $TabletopEnvironment3D
	status_label = $UI/VBoxContainer/Status
	btn_restart = $UI/Buttons/BtnRestart
	env_3d.set_felt_color(Color(0.06, 0.32, 0.18)) # Verde cassino clássico
	# A HUD come 210 px em cima e os botoes 120 embaixo; a mesa ocupa o resto.
	# Sem isto a camera usava o enquadramento padrao de 6x6 unidades e as cartas
	# -- que juntas nao passam de 3,5 -- ficavam do tamanho de um selo.
	fit_table(Vector2(ZONE_SIZE.x + 0.30, (PLAYER_Z - DEALER_Z) + ZONE_SIZE.y + 0.45))
	_build_table_zones()
	player_hand = CardHand.new()
	dealer_hand = CardHand.new()
	_start_new_game()


## Marca no feltro de quem e cada fileira. Duas fileiras de cartas iguais no
## meio do verde nao dizem qual e a mao de quem.
func _build_table_zones() -> void:
	cards_root.add_child(TableZone3D.create(ZONE_SIZE, Vector3(0.0, 0.0, DEALER_Z),
		"MESA · CARTEADOR", Color(0.96, 0.80, 0.36), true))
	cards_root.add_child(TableZone3D.create(ZONE_SIZE, Vector3(0.0, 0.0, PLAYER_Z),
		"SUA MÃO", Color(0.52, 0.86, 1.0)))

func _start_new_game() -> void:
	game_over = false
	player_hand.clear()
	dealer_hand.clear()

	for c in player_cards_3d: c.queue_free()
	for c in dealer_cards_3d: c.queue_free()
	player_cards_3d.clear()
	dealer_cards_3d.clear()
	
	btn_hit.disabled = false
	btn_stand.disabled = false
	btn_restart.hide()
	
	deck = Deck.create_standard_52()
	deck.shuffle()
	
	# Distribuição inicial em 3D
	var p_c1 := deck.draw()
	var d_c1 := deck.draw() # Carta oculta do dealer
	var p_c2 := deck.draw()
	var d_c2 := deck.draw()
	
	player_hand.add(p_c1)
	dealer_hand.add(d_c1)
	player_hand.add(p_c2)
	dealer_hand.add(d_c2)
	
	_spawn_card_3d(p_c1, true, 0, true)
	_spawn_card_3d(d_c1, false, 0, false) # Oculta
	_spawn_card_3d(p_c2, true, 1, true)
	_spawn_card_3d(d_c2, false, 1, true) # Visível
	
	_update_labels(false)
	set_status("Sua vez! Pedir carta ou parar?")
	
	if BlackjackRules.is_blackjack(player_hand.get_all()):
		_reveal_dealer_and_end("🏆 Blackjack Natural! Você Venceu!", true)

func _spawn_card_3d(card: Card, is_player: bool, index: int, face_up: bool) -> Card3D:
	var c_3d := preload("res://shared/3d/Card3D.tscn").instantiate()
	var disp_val := card.get_display_value()
	var suit_sym := card.get_suit_symbol()
	c_3d.setup(disp_val, suit_sym, face_up)
	
	# A carta sai do sabot, no canto da mesa, e viaja ate o lugar dela.
	c_3d.position = Vector3(2.6, 0.4, -2.2)
	cards_root.add_child(c_3d)

	if is_player:
		player_cards_3d.append(c_3d)
	else:
		dealer_cards_3d.append(c_3d)

	_relayout_hand(is_player, index)
	return c_3d


## Recentra a fileira de um lado da mesa.
##
## A versao anterior punha a primeira carta sempre em x = -1.2 e ia somando: com
## duas cartas a mao ficava torta a esquerda, e com cinco vazava a zona pela
## direita. Aqui a fileira e sempre centrada na zona, seja qual for o tamanho.
func _relayout_hand(is_player: bool, animate_from: int = -1) -> void:
	var cards: Array = player_cards_3d if is_player else dealer_cards_3d
	if cards.is_empty():
		return
	var z: float = PLAYER_Z if is_player else DEALER_Z
	# Com muitas cartas a fileira aperta em vez de sair da zona.
	var pitch: float = minf(CARD_PITCH, (ZONE_SIZE.x - Tokens3D.CARD_WIDTH - 0.2)
		/ maxf(float(cards.size() - 1), 1.0))
	var start_x: float = -pitch * float(cards.size() - 1) * 0.5

	for i in cards.size():
		var card: Card3D = cards[i]
		var target := Vector3(start_x + float(i) * pitch, 0.05 + float(i) * 0.004, z)
		if i == animate_from:
			card.deal_to(target, 0.0, 0.45)
		else:
			card.move_to(target)

func _update_labels(show_dealer: bool) -> void:
	var p_score := BlackjackRules.calculate_hand_value(player_hand.get_all())
	# A carta virada da mesa continua virada no placar: "14+" e nao um numero
	# fechado, senao a barra entrega o que a mesa esta escondendo.
	var mesa := ""
	if show_dealer or game_over:
		mesa = str(BlackjackRules.calculate_hand_value(dealer_hand.get_all()))
	else:
		mesa = "%d+" % BlackjackRules.calculate_hand_value(dealer_hand.get_all().slice(1))
	set_duel_score(p_score, mesa, "sua mão", "mesa")

func _on_btn_hit_pressed() -> void:
	if game_over: return
	
	var card := deck.draw()
	player_hand.add(card)
	_spawn_card_3d(card, true, player_hand.size() - 1, true)
	_update_labels(false)
	
	if BlackjackRules.is_busted(player_hand.get_all()):
		_reveal_dealer_and_end("Estourou! Você ultrapassou 21.", false)

func _on_btn_stand_pressed() -> void:
	if game_over: return
	
	btn_hit.disabled = true
	btn_stand.disabled = true
	set_status("Vez do Dealer...")
	
	# Vira a carta oculta do dealer em 3D
	if dealer_cards_3d.size() > 0:
		dealer_cards_3d[0].flip(true, 0.4)
		
	await get_tree().create_timer(0.6).timeout
	_update_labels(true)
	
	# Dealer joga até 17+
	while BlackjackRules.should_dealer_hit(dealer_hand.get_all()):
		await get_tree().create_timer(0.6).timeout
		var card := deck.draw()
		dealer_hand.add(card)
		_spawn_card_3d(card, false, dealer_hand.size() - 1, true)
		_update_labels(true)
		
	var outcome := BlackjackRules.determine_winner(player_hand.get_all(), dealer_hand.get_all())
	var d_score := BlackjackRules.calculate_hand_value(dealer_hand.get_all())
	
	if outcome == BlackjackRules.Winner.PLAYER:
		if d_score > 21:
			_end_game("🏆 Dealer estourou (%d)! Você Venceu!" % d_score, true)
		else:
			_end_game("🏆 Você Venceu a rodada!", true)
	elif outcome == BlackjackRules.Winner.DEALER:
		_end_game("Dealer Venceu (%d pontos)." % d_score, false)
	else:
		_end_game("Empate (Push)! As apostas retornam.", false)

func _reveal_dealer_and_end(msg: String, is_player_win: bool) -> void:
	if dealer_cards_3d.size() > 0:
		dealer_cards_3d[0].flip(true, 0.4)
	_update_labels(true)
	_end_game(msg, is_player_win)

func _end_game(msg: String, is_player_win: bool) -> void:
	finish_game(msg, is_player_win)
	btn_hit.disabled = true
	btn_stand.disabled = true
