extends BaseGame

## UNO-like card game with 3D card animations and AI opponent.

## UnoLikeGame: Cartas Coloridas 3D com Cartas Físicas, Arremesso no Descarte e Partículas

## Chaves de traducao: a cor ativa aparece no banner da mesa.
const COLOR_NAMES = {
	Card.ColorType.RED: "COLOR_RED",
	Card.ColorType.BLUE: "COLOR_BLUE",
	Card.ColorType.GREEN: "COLOR_GREEN",
	Card.ColorType.YELLOW: "COLOR_YELLOW",
	Card.ColorType.WILD: "COLOR_WILD"
}

var draw_pile: Deck
var discard_pile: CardPile
var player_hand: CardHand
var ai_hand: CardHand

var active_color: Card.ColorType = Card.ColorType.RED
var is_player_turn: bool = true

## Degrau de 1 a 10 do DifficultyManager. Vira a chance de a IA largar a
## prioridade e sortear a carta.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var waiting_color_pick: bool = false
var pending_wild4: bool = false

var discard_cards_3d: Array[Card3D] = []

## A mao da IA, de costas, no alto da mesa. O numero de cartas do adversario e
## a informacao que decide a jogada -- e quem esta com uma carta so leva o
## curinga +4 na cara --, e ate aqui ele existia apenas como um digito de 34 px
## no canto da barra, ao lado do proprio placar e do rotulo de dificuldade.
## Agora e um leque: sete cartas de costas se leem de relance, uma carta so
## grita.
var ai_cards_3d: Array[Card3D] = []

## Onde o leque da IA pousa, e o quanto ele se abre.
const AI_FAN_Z := -1.75
const AI_FAN_LARGURA := 1.9
const AI_FAN_ESCALA := 0.62

## Moldura no feltro em volta do descarte, na cor que esta valendo. Depois de um
## curinga a carta de cima e preta: sem esta marca so o texto do topo diz que
## cor foi escolhida, e ele fica longe de onde a jogada acontece.
var _color_marker: CellHalo3D = null

@onready var cards_root: Node3D = $CardsRoot
@onready var shell: GameShell = $UI/GameShell
@onready var active_color_banner: Label = $UI/ActiveColorBanner
@onready var player_cards_container: HBoxContainer = $UI/PlayerArea/ScrollContainer/CardsContainer
@onready var color_picker_veil: ColorRect = $UI/ColorPickerVeil
@onready var color_picker_modal: PanelContainer = $UI/ColorPickerModal
@onready var color_picker_grid: GridContainer = $UI/ColorPickerModal/VBox/Grid
@onready var btn_draw: Button = $UI/Actions/BtnDraw

func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(_on_restart_pressed)
	active_color_banner.reparent(shell.status_label.get_parent())
	env_3d.set_felt_color(Color(0.12, 0.14, 0.22)) # Feltro Grafite Escuro
	# Sem informar a area util e o tamanho do conteudo, a camera enquadrava as
	# 6x6 unidades padrao para um monte de descarte de uma carta so: a carta da
	# mesa saia do tamanho de uma unha.
	# O leque da IA fica no alto da mesa, entao o retangulo a enquadrar vai do
	# leque ate a beirada de baixo do descarte -- e nao so o descarte.
	fit_table(Vector2(2.6, 3.3), Vector3(0.0, 0.0, -0.85))
	_build_color_marker()
	_ligar_botoes_de_cor()
	player_hand = CardHand.new()
	ai_hand = CardHand.new()
	discard_pile = CardPile.new()
	_start_new_game()


## Liga os quatro botoes do modal a cor que cada um anuncia.
##
## As ligacoes moravam no `.tscn`, com a cor passada como numero cru:
## `binds = [0]` no vermelho, `[1]` no azul, `[2]` no verde, `[3]` no amarelo.
## Em `Card.ColorType` esses numeros sao NONE, RED, BLACK e BLUE -- escolher
## "Vermelho" punha a mesa em "sem cor", e dai em diante nenhuma carta
## combinava e a partida parava. Aqui a cor vem do enum, que e o unico lugar
## onde ela e definida, e o botao ainda ganha a propria cor no fundo em vez de
## um `self_modulate` que o tema come.
const CORES_DO_MODAL := [
	Card.ColorType.RED, Card.ColorType.BLUE,
	Card.ColorType.GREEN, Card.ColorType.YELLOW,
]

func _ligar_botoes_de_cor() -> void:
	var botoes := color_picker_grid.get_children()
	for i in range(mini(botoes.size(), CORES_DO_MODAL.size())):
		var b := botoes[i] as Button
		if b == null:
			continue
		var cor_tipo: int = CORES_DO_MODAL[i]
		var cor := UnoCardArt2D.color_of(UnoCardArt2D.color_key(cor_tipo))
		for estado in ["normal", "hover", "pressed", "focus"]:
			var st := StyleBoxFlat.new()
			st.bg_color = cor.lightened(0.12) if estado == "pressed" else cor
			st.set_corner_radius_all(14)
			st.set_border_width_all(3)
			st.border_color = Color(0.05, 0.05, 0.08, 0.85)
			b.add_theme_stylebox_override(estado, st)
		b.add_theme_color_override("font_color", Color(0.06, 0.06, 0.09))
		b.add_theme_color_override("font_hover_color", Color(0.06, 0.06, 0.09))
		b.add_theme_color_override("font_pressed_color", Color(0.06, 0.06, 0.09))
		b.self_modulate = Color.WHITE
		b.pressed.connect(_on_color_chosen.bind(cor_tipo))


func _build_color_marker() -> void:
	# Anel em volta do descarte, e nao um disco aceso: um disco no tamanho de ler
	# a cor de longe vira um borrao que apaga a propria carta.
	#
	# Era uma moldura RETANGULAR de quatro barras, e a carta do descarte cai com
	# rotacao aleatoria de ate 15 graus -- a moldura ficava sempre torta em
	# relacao a carta. O anel nao tem lado, entao nao tem como ficar torto, e e o
	# mesmo sinal que o resto do aplicativo usa.
	_color_marker = CellHalo3D.new()
	_color_marker.name = "ActiveColorMarker"
	_color_marker.position = Vector3(0.0, 0.0, -0.3)
	cards_root.add_child(_color_marker)
	_color_marker.setup(1, 0.80)
	_color_marker.set_targets([Vector3.ZERO])


func _paint_active_color(col: Color) -> void:
	if _color_marker:
		_color_marker.light(0, col)

func _start_new_game() -> void:
	game_over = false
	waiting_color_pick = false
	pending_wild4 = false
	btn_restart.hide()
	_mostrar_modal_de_cor(false)
	
	# So as cartas: `cards_root.get_children()` levaria junto a marca da cor
	# ativa, que mora no mesmo no e tem de sobreviver entre partidas.
	for c in discard_cards_3d:
		if is_instance_valid(c):
			c.queue_free()
	discard_cards_3d.clear()
	for c in ai_cards_3d:
		if is_instance_valid(c):
			c.queue_free()
	ai_cards_3d.clear()
	
	ai_level = DifficultyManager.get_level(game_id)
	draw_pile = Deck.create_uno_deck()
	draw_pile.shuffle()
	
	player_hand.clear()
	ai_hand.clear()
	discard_pile.clear()
	
	for i in range(7):
		player_hand.add(draw_pile.draw())
		ai_hand.add(draw_pile.draw())
		
	var first_card := draw_pile.draw()
	while first_card != null and first_card.color_type == Card.ColorType.WILD:
		draw_pile.push_front(first_card)
		draw_pile.shuffle()
		first_card = draw_pile.draw()
		
	discard_pile.push(first_card)
	active_color = first_card.color_type
	is_player_turn = true
	
	_spawn_top_discard_3d(first_card)
	set_status(tr("UNO_YOUR_TURN_LONG"))
	_update_ui()
	shell.timer.reset()
	shell.timer.start()

func _spawn_top_discard_3d(card: Card) -> void:
	var c_3d: Card3D = preload("res://shared/3d/Card3D.tscn").instantiate()
	# O baralho aqui e de UNO: as faces saem do UnoCardAtlas3D, nao do atlas
	# frances. Pedir "7 vermelho" ao atlas frances devolvia um 7 de espadas, e a
	# mesa dizia "Cor Ativa: Amarelo" com uma carta de espadas em cima.
	c_3d.atlas = UnoCardAtlas3D
	c_3d.setup(UnoCardArt2D.kind_key(card), UnoCardArt2D.color_key(card.color_type), true)
	
	var rot_y := randf_range(-15.0, 15.0)
	var target_pos := Vector3(0.0, 0.05 + (discard_cards_3d.size() * 0.004), -0.3)
	c_3d.position = target_pos + Vector3(0, 1.8, 0)
	cards_root.add_child(c_3d)
	discard_cards_3d.append(c_3d)
	
	c_3d.deal_to(target_pos, rot_y, 0.35)
	if AudioManager:
		AudioManager.play_card_flip()

func _draw_from_deck() -> Card:
	if draw_pile.is_empty():
		if discard_pile.size() > 1:
			var top := discard_pile.pop()
			draw_pile.recycle_from(discard_pile.get_all())
			discard_pile.clear()
			discard_pile.push(top)
			draw_pile.shuffle()
			set_status(tr("UNO_RECYCLED"))
		else:
			return null
	return draw_pile.draw()

func _update_ui() -> void:
	set_duel_score(player_hand.size(), ai_hand.size(), "SCORE_YOURS", "SCORE_AI_CARDS")
	shell.set_level(DifficultyManager.label_for(game_id))
	
	# A cor sai da propria arte da carta: uma definicao so de "vermelho de UNO"
	# para o banner, a mao, a marca da mesa e a face impressa.
	var col := UnoCardArt2D.color_of(UnoCardArt2D.color_key(active_color))
	var col_name := tr(str(COLOR_NAMES.get(active_color, "COLOR_UNDEFINED")))
	active_color_banner.text = tr("UNO_ACTIVE_COLOR") % col_name
	active_color_banner.add_theme_color_override("font_color", col)
	_paint_active_color(col)
	
	_pintar_mao_da_ia()

	# Mão do jogador
	for c in player_cards_container.get_children(): c.queue_free()
	var top_card := discard_pile.peek()
	
	for i in range(player_hand.size()):
		var card := player_hand.get_card(i)
		var view := UnoCard2D.new()
		view.custom_minimum_size = Vector2(UIKit.TOQUE_MIN + 12.0, 148.0)
		view.setup(card)
		view.playable = is_player_turn and not game_over and not waiting_color_pick \
			and UnoRules.can_play_card(card, top_card, active_color)
		view.pressed.connect(_on_player_card_clicked.bind(i))
		player_cards_container.add_child(view)


func _on_player_card_clicked(idx: int) -> void:
	if not is_player_turn or game_over or waiting_color_pick: return
	
	var card := player_hand.get_card(idx)
	var top_card := discard_pile.peek()
	
	if not UnoRules.can_play_card(card, top_card, active_color): return
	
	player_hand.remove_at(idx)
	discard_pile.push(card)
	_spawn_top_discard_3d(card)
	
	if card.color_type == Card.ColorType.WILD:
		waiting_color_pick = true
		pending_wild4 = (card.special_type == Card.SpecialType.WILD_DRAW_FOUR)
		_mostrar_modal_de_cor(true)
		set_status(tr("UNO_PICK_COLOR"))
		_update_ui()
		return
		
	active_color = card.color_type
	_handle_card_effects_and_advance(card, true)

func _on_color_chosen(col_type: Card.ColorType) -> void:
	if not waiting_color_pick:
		return
	waiting_color_pick = false
	_mostrar_modal_de_cor(false)
	active_color = col_type
	
	var played_card := discard_pile.peek()
	_handle_card_effects_and_advance(played_card, true)

func _handle_card_effects_and_advance(card: Card, was_player: bool) -> void:
	_update_ui()
	
	if was_player and player_hand.size() == 0:
		_end_game(tr("UNO_WIN"), true)
		return
	elif not was_player and ai_hand.size() == 0:
		_end_game(tr("UNO_LOSE"), false)
		return
		
	if was_player and player_hand.size() == 1:
		set_status(tr("UNO_YOU_ONE_CARD"))
	elif not was_player and ai_hand.size() == 1:
		set_status(tr("UNO_AI_ONE_CARD"))
		
	var skip_next: bool = false
	match card.special_type:
		Card.SpecialType.DRAW_TWO:
			if was_player:
				for i in range(2):
					var d: Card = _draw_from_deck()
					if d != null:
						ai_hand.add(d)
				set_status(tr("UNO_AI_DREW_TWO"))
				skip_next = true
			else:
				for i in range(2):
					var d: Card = _draw_from_deck()
					if d != null:
						player_hand.add(d)
				set_status(tr("UNO_YOU_DREW_TWO"))
				skip_next = true
				
		Card.SpecialType.WILD_DRAW_FOUR:
			if was_player:
				for i in range(4):
					var d: Card = _draw_from_deck()
					if d != null:
						ai_hand.add(d)
				set_status(tr("UNO_AI_DREW_FOUR"))
				skip_next = true
			else:
				for i in range(4):
					var d: Card = _draw_from_deck()
					if d != null:
						player_hand.add(d)
				set_status(tr("UNO_YOU_DREW_FOUR"))
				skip_next = true
				
		Card.SpecialType.SKIP, Card.SpecialType.REVERSE:
			skip_next = true
			set_status(tr("UNO_TURN_SKIPPED"))
			
	_update_ui()
	
	if was_player:
		if skip_next:
			is_player_turn = true
			set_status(tr("UNO_YOUR_TURN_AGAIN"))
			_update_ui()
		else:
			is_player_turn = false
			set_status(tr("AI_TURN_SHORT"))
			_update_ui()
			await get_tree().create_timer(0.9).timeout
			_play_ai_turn()
	else:
		if skip_next:
			is_player_turn = false
			set_status(tr("UNO_AI_TURN_AGAIN"))
			_update_ui()
			await get_tree().create_timer(0.9).timeout
			_play_ai_turn()
		else:
			is_player_turn = true
			set_status(tr("UNO_YOUR_TURN"))
			_update_ui()

func _play_ai_turn() -> void:
	var top_card := discard_pile.peek()
	var playable_indices: Array = []
	for i in range(ai_hand.size()):
		var c := ai_hand.get_card(i)
		if UnoRules.can_play_card(c, top_card, active_color):
			playable_indices.append(i)
			
	if playable_indices.is_empty():
		var drawn: Card = _draw_from_deck()
		if drawn != null:
			ai_hand.add(drawn)
			set_status(tr("UNO_AI_DREW"))
			if UnoRules.can_play_card(drawn, top_card, active_color):
				ai_hand.cards.erase(drawn)
				discard_pile.push(drawn)
				_spawn_top_discard_3d(drawn)
				if drawn.color_type == Card.ColorType.WILD:
					active_color = UnoRules.pick_best_color_for_hand(ai_hand.cards)
				else:
					active_color = drawn.color_type
				_handle_card_effects_and_advance(drawn, false)
				return
		is_player_turn = true
		set_status(tr("UNO_YOUR_TURN"))
		_update_ui()
	else:
		var chosen_idx := UnoAI.escolher_carta(ai_hand.cards, top_card, active_color,
			player_hand.size(), ai_level)
		if chosen_idx < 0:
			chosen_idx = playable_indices[0]
		var card := ai_hand.remove_at(chosen_idx)
		discard_pile.push(card)
		_spawn_top_discard_3d(card)
		
		if card.color_type == Card.ColorType.WILD:
			active_color = UnoRules.pick_best_color_for_hand(ai_hand.cards)
		else:
			active_color = card.color_type
			
		_handle_card_effects_and_advance(card, false)

func _on_btn_draw_pressed() -> void:
	if not is_player_turn or game_over or waiting_color_pick: return
	var drawn: Card = _draw_from_deck()
	if drawn != null:
		player_hand.add(drawn)
		set_status(tr("UNO_YOU_DREW"))
		_update_ui()
		
		# Passa a vez
		is_player_turn = false
		set_status(tr("AI_TURN_SHORT"))
		_update_ui()
		await get_tree().create_timer(0.8).timeout
		_play_ai_turn()

func _end_game(msg: String, is_player_win: bool) -> void:
	shell.timer.stop()
	finish_game(msg, is_player_win, {"time": shell.timer.get_time()})


## O veu escurece a mesa junto com o modal: sem ele o modal de 420x340 flutuava
## sobre um tabuleiro que continuava parecendo tocavel, e a mao do jogador
## debaixo dele continuava recebendo o toque.
func _mostrar_modal_de_cor(visivel: bool) -> void:
	color_picker_veil.visible = visivel
	color_picker_modal.visible = visivel


## Redesenha o leque de costas da IA para casar com o tamanho da mao dela.
##
## Cartas entram e saem uma a uma, entao o leque so cresce ou encolhe pela
## ponta: as que ficam apenas deslizam para a nova posicao, e a que entra cai
## do alto como qualquer carta distribuida.
func _pintar_mao_da_ia() -> void:
	var quantas := ai_hand.size()

	while ai_cards_3d.size() > quantas:
		var fora: Card3D = ai_cards_3d.pop_back()
		if is_instance_valid(fora):
			fora.queue_free()

	while ai_cards_3d.size() < quantas:
		var c_3d: Card3D = preload("res://shared/3d/Card3D.tscn").instantiate()
		c_3d.atlas = UnoCardAtlas3D
		c_3d.scale = Vector3.ONE * AI_FAN_ESCALA
		# De costas: e a mao do adversario. O verso e o mesmo do baralho da mesa.
		c_3d.setup(UnoCardArt2D.KINDS[0], UnoCardArt2D.RED, false)
		cards_root.add_child(c_3d)
		ai_cards_3d.append(c_3d)
		c_3d.position = _lugar_no_leque(ai_cards_3d.size() - 1, quantas) + Vector3(0.0, 1.6, 0.0)

	for i in range(ai_cards_3d.size()):
		var carta: Card3D = ai_cards_3d[i]
		if not is_instance_valid(carta):
			continue
		carta.move_to(_lugar_no_leque(i, quantas), Tokens3D.DUR_FAST)


## Onde a i-esima carta do leque da IA pousa. O leque nao passa de
## `AI_FAN_LARGURA`: com dezoito cartas na mao ele aperta em vez de sair da
## mesa, e a pilha densa ainda diz "muita carta" de relance.
func _lugar_no_leque(i: int, total: int) -> Vector3:
	if total <= 1:
		return Vector3(0.0, 0.02, AI_FAN_Z)
	var passo: float = minf(0.30, AI_FAN_LARGURA / float(total - 1))
	var x: float = (float(i) - float(total - 1) * 0.5) * passo
	return Vector3(x, 0.02 + float(i) * 0.002, AI_FAN_Z)
