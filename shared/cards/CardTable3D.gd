class_name CardTable3D
extends Node3D

## A mesa de cartas de N assentos: os leques, o centro, o monte e o descarte.
##
## Blackjack, Poker e UNO montavam cada um a propria fileira de cartas. Com
## oito jogos de cartas de dois a quatro assentos chegando de uma vez, o que e
## igual em todos mora aqui:
##
##   - a cadeira 0 e a de BAIXO, a da pessoa deste aparelho, com as cartas
##     viradas e no tamanho de ler; as outras ficam em volta, de costas e
##     menores -- o que importa nelas e QUANTAS cartas ha;
##   - o toque e o arrasto entram por `DragPicker3D`, projetando o centro de
##     cada carta da mao: o toque vai para a carta MAIS PROXIMA do dedo, e nao
##     para a que estiver exatamente embaixo (regra da casa);
##   - a carta tocada e uma carta do MODELO (`Card`), guardada em
##     `Card3D.custom_data["card"]`, para o jogo nao traduzir indice;
##   - o centro da mesa e uma casa por assento, para vazas; e um monte e um
##     descarte, para os jogos de comprar e largar.
##
## A mesa nao conhece regra nenhuma. O jogo diz o que fazer com cada toque
## (`card_tapped`, `card_dropped`, `target_tapped`) e manda as cartas de la
## para ca (`add_card`, `play_to_center`, `discard`, `collect_center`).
##
## Uso, no `_ready()`:
##
##     table = CardTable3D.new()
##     add_child(table)
##     table.setup(self, 4, env_3d)
##     table.card_tapped.connect(_on_carta)
##     fit_table(table.content_size())

## Tocou uma carta da mao tocavel (a de baixo).
signal card_tapped(seat: int, index: int, card: Card)

## Arrastou uma carta e soltou sobre `target` (um id de `set_targets`, ou
## `null` fora de tudo). A carta ja voltou ao leque; o jogo decide.
signal card_dropped(seat: int, index: int, card: Card, target: Variant)

## Tocou um alvo extra da mesa (monte, descarte, centro...).
signal target_tapped(id: Variant)

const CARD_SCENE := preload("res://shared/3d/Card3D.tscn")

## A area que a mesa ocupa, para `BaseGame.fit_table()`.
const SIZE := Vector2(5.6, 6.2)

const LOCAL_SCALE := 1.0
const OTHER_SCALE := 0.62
const FAN_WIDTH_LOCAL := 4.4
const FAN_WIDTH_OTHER := 1.9
const PITCH_LOCAL := 0.50
const PITCH_OTHER := 0.30
const CARD_Y := 0.05
const STACK_STEP := 0.004
const RADIUS := 2.35
const CENTER_RADIUS := 0.85

const STOCK_POS := Vector3(-0.55, CARD_Y, 0.0)
const DISCARD_POS := Vector3(0.55, CARD_Y, 0.0)

var seats: int = 2
var hands: Array = []          # Array[Array[Card3D]]
var center: Array = []         # Array[Card3D], em vazas: uma por assento
var discard_pile: Array = []   # Array[Card3D]
var stock_pile: Array = []     # Array[Card3D], so os versos que ilustram o monte
var picker: DragPicker3D = null

## A cadeira cujas cartas recebem toque. Normalmente a 0.
var tappable_seat: int = 0

var _env: TabletopEnvironment3D = null
var _labels: Dictionary = {}       # seat -> Label3D
var _extra_targets: Dictionary = {}
var _drag_index: int = -1
var _drag_from: Vector3 = Vector3.ZERO


## Monta a mesa. `game` e a cena (um `Control`) onde o picker se pendura; sem
## `game` a mesa fica so visual (suite, capturas).
func setup(game: Control, p_seats: int, env: TabletopEnvironment3D) -> void:
	seats = maxi(p_seats, 1)
	_env = env
	hands.clear()
	for i in seats:
		hands.append([])
	if game != null and picker == null:
		picker = DragPicker3D.new()
		game.add_child(picker)
		picker.attach(env, CARD_Y)
		picker.target_tapped.connect(_on_target_tapped)
		picker.drag_started.connect(_on_drag_started)
		picker.drag_moved.connect(_on_drag_moved)
		picker.drag_ended.connect(_on_drag_ended)
	refresh_targets()


func content_size() -> Vector2:
	if seats <= 2:
		return Vector2(SIZE.x - 0.6, SIZE.y)
	return SIZE


# ------------------------------------------------------------------ lugares

## Onde a cadeira fica: `{"pos": Vector3, "rot": graus em Y}`. A 0 embaixo;
## duas cadeiras ficam frente a frente; quatro, uma em cada lado; mais que
## isso, as outras se espalham num arco do lado de la.
func seat_anchor(seat: int) -> Dictionary:
	if seat == 0:
		return {"pos": Vector3(0.0, 0.0, RADIUS), "rot": 0.0}
	var n := seats - 1
	var angulo := 0.0
	if seats == 2:
		angulo = 180.0
	elif seats == 4:
		# Sentido horario visto de cima: baixo, esquerda, cima, direita.
		angulo = [270.0, 180.0, 90.0][seat - 1]
	elif seats == 3:
		angulo = [240.0, 120.0][seat - 1]
	else:
		# Da esquerda (285 graus) a direita (75), pelo lado de la da mesa.
		angulo = 285.0 - (285.0 - 75.0) * float(seat - 1) / float(maxi(n - 1, 1))
	var rad := deg_to_rad(angulo)
	var raio := RADIUS if seats <= 4 else RADIUS + 0.15
	return {"pos": Vector3(sin(rad) * raio, 0.0, cos(rad) * raio), "rot": angulo}


func seat_scale(seat: int) -> float:
	return LOCAL_SCALE if seat == tappable_seat else OTHER_SCALE


## A posicao da i-esima carta de um leque de `total`, na cadeira.
func slot(seat: int, i: int, total: int) -> Vector3:
	var anc := seat_anchor(seat)
	var local := seat == tappable_seat
	var largura := FAN_WIDTH_LOCAL if local else FAN_WIDTH_OTHER
	var passo := PITCH_LOCAL if local else PITCH_OTHER
	if total > 1:
		passo = minf(passo, largura / float(total - 1))
	var x := (float(i) - float(total - 1) * 0.5) * passo
	var deslocado := Vector3(x, 0.0, 0.0).rotated(Vector3.UP, deg_to_rad(float(anc["rot"])))
	return Vector3(anc["pos"]) + deslocado + Vector3(0.0, CARD_Y + float(i) * STACK_STEP, 0.0)


## A casa do centro da mesa que fica do lado de cada cadeira (vazas).
func center_slot(seat: int) -> Vector3:
	var anc := seat_anchor(seat)
	var p: Vector3 = Vector3(anc["pos"]).normalized() * CENTER_RADIUS
	return Vector3(p.x, CARD_Y, p.z)


func stock_position() -> Vector3:
	return STOCK_POS


func discard_position() -> Vector3:
	return DISCARD_POS + Vector3(0.0, float(discard_pile.size()) * STACK_STEP, 0.0)


# ------------------------------------------------------------------- cartas

## Rank e naipe como o atlas de faces os conhece: `["A", "H"]`.
static func face_of(card: Card) -> Array:
	var rank := "A"
	if card.value >= 2 and card.value <= 13:
		rank = CardArt2D.RANKS[card.value - 1]
	var suit := CardArt2D.SUIT_SPADE
	match card.suit:
		Card.Suit.HEARTS:
			suit = CardArt2D.SUIT_HEART
		Card.Suit.DIAMONDS:
			suit = CardArt2D.SUIT_DIAMOND
		Card.Suit.CLUBS:
			suit = CardArt2D.SUIT_CLUB
	return [rank, suit]


func _spawn(card: Card, face_up: bool, from: Vector3, escala: float) -> Card3D:
	var c3d: Card3D = CARD_SCENE.instantiate()
	var face := face_of(card)
	c3d.setup(face[0], face[1], face_up)
	c3d.custom_data["card"] = card
	c3d.scale = Vector3.ONE * escala
	c3d.position = from
	add_child(c3d)
	return c3d


## Da uma carta a cadeira. Ela viaja de `from` (o monte, por padrao) ate o
## lugar dela no leque.
func add_card(seat: int, card: Card, face_up: bool = true, from: Vector3 = Vector3(0.0, 0.4, 0.0)) -> Card3D:
	var mao: Array = hands[seat]
	var c3d := _spawn(card, face_up, from, seat_scale(seat))
	mao.append(c3d)
	relayout(seat, mao.size() - 1)
	return c3d


## Tira a carta do leque (continua na mesa, sob controle de quem chamou).
func remove_card(seat: int, index: int) -> Card3D:
	var mao: Array = hands[seat]
	if index < 0 or index >= mao.size():
		return null
	var c3d: Card3D = mao.pop_at(index)
	relayout(seat)
	return c3d


## Localiza a carta do modelo no leque; -1 se nao esta la.
func index_of(seat: int, card: Card) -> int:
	var mao: Array = hands[seat]
	for i in mao.size():
		if (mao[i] as Card3D).custom_data.get("card") == card:
			return i
	return -1


func card_at(seat: int, index: int) -> Card3D:
	var mao: Array = hands[seat]
	if index < 0 or index >= mao.size():
		return null
	return mao[index]


func model_at(seat: int, index: int) -> Card:
	var c3d := card_at(seat, index)
	return c3d.custom_data.get("card") if c3d != null else null


func hand_size(seat: int) -> int:
	return (hands[seat] as Array).size()


## Reordena o leque conforme `order` (cartas do modelo, na ordem nova).
func reorder(seat: int, order: Array) -> void:
	var mao: Array = hands[seat]
	var nova: Array = []
	for card in order:
		var i := index_of(seat, card)
		if i != -1:
			nova.append(mao[i])
	for c3d in mao:
		if not nova.has(c3d):
			nova.append(c3d)
	hands[seat] = nova
	relayout(seat)


## Recentra o leque. `animate_index` e a carta que acabou de chegar: ela cai
## em arco, as outras so deslizam.
func relayout(seat: int, animate_index: int = -1) -> void:
	var mao: Array = hands[seat]
	var total := mao.size()
	var rot := float(seat_anchor(seat)["rot"])
	for i in total:
		var c3d: Card3D = mao[i]
		if not is_instance_valid(c3d):
			continue
		c3d.scale = Vector3.ONE * seat_scale(seat)
		var alvo := slot(seat, i, total)
		if i == animate_index:
			c3d.deal_to(alvo, rot, Tokens3D.DUR_SLOW)
		else:
			c3d.move_to(alvo, Tokens3D.DUR_FAST)
			c3d.rotation_degrees.y = rot
	if seat == tappable_seat:
		refresh_targets()


## Vira as cartas de uma cadeira (mostrar a mao da maquina no fim).
func set_face_up(seat: int, up: bool) -> void:
	for c3d in hands[seat]:
		(c3d as Card3D).flip(up)


## Levanta as cartas jogaveis e assenta as outras. Indices da mao.
func set_playable(seat: int, indices: Array) -> void:
	var mao: Array = hands[seat]
	for i in mao.size():
		var c3d: Card3D = mao[i]
		c3d.set_lift(Tokens3D.LIFT_HOVER if indices.has(i) else 0.0)


func set_selected(seat: int, index: int, on: bool) -> void:
	var c3d := card_at(seat, index)
	if c3d != null:
		c3d.select(on)
		c3d.set_lift(Tokens3D.LIFT_SELECTED if on else 0.0)


## Recusa visivel: a carta treme no lugar.
func reject(seat: int, index: int) -> void:
	var c3d := card_at(seat, index)
	if c3d != null:
		c3d.reject()


# ------------------------------------------------------------------- centro

## Joga a carta `index` da cadeira no centro, na casa dela (vaza).
func play_to_center(seat: int, index: int, face_up: bool = true) -> Card3D:
	var c3d := remove_card(seat, index)
	if c3d == null:
		return null
	c3d.scale = Vector3.ONE
	c3d.set_lift(0.0)
	var alvo := center_slot(seat) + Vector3(0.0, float(center.size()) * STACK_STEP, 0.0)
	c3d.deal_to(alvo, float(seat_anchor(seat)["rot"]), Tokens3D.DUR_NORMAL)
	if face_up and not c3d.is_face_up:
		c3d.flip(true)
	center.append(c3d)
	if AudioManager:
		AudioManager.play_card_flip()
	return c3d


## Poe no centro uma carta que nao veio de mao nenhuma (a virada da mesa).
func place_center(card: Card, seat: int, face_up: bool = true) -> Card3D:
	var c3d := _spawn(card, face_up, Vector3(0.0, 0.4, 0.0), 1.0)
	var alvo := center_slot(seat) + Vector3(0.0, float(center.size()) * STACK_STEP, 0.0)
	c3d.deal_to(alvo, float(seat_anchor(seat)["rot"]), Tokens3D.DUR_NORMAL)
	center.append(c3d)
	return c3d


## As cartas do centro vao para quem levou a vaza e somem.
func collect_center(to_seat: int) -> void:
	var destino := Vector3(seat_anchor(to_seat)["pos"]) * 1.15 + Vector3(0.0, CARD_Y, 0.0)
	for c3d in center:
		if not is_instance_valid(c3d):
			continue
		(c3d as Card3D).move_to(destino, Tokens3D.DUR_NORMAL)
		(c3d as Card3D).vanish(true)
	center.clear()
	if AudioManager:
		AudioManager.play_capture()


func clear_center() -> void:
	for c3d in center:
		if is_instance_valid(c3d):
			c3d.queue_free()
	center.clear()


# --------------------------------------------------------- monte e descarte

## Larga a carta `index` da cadeira no descarte, virada para cima e um pouco torta.
func discard(seat: int, index: int) -> Card3D:
	var c3d := remove_card(seat, index)
	if c3d == null:
		return null
	discard_card3d(c3d)
	return c3d


## Poe no descarte uma carta ja existente na mesa.
func discard_card3d(c3d: Card3D) -> void:
	c3d.scale = Vector3.ONE
	c3d.set_lift(0.0)
	c3d.deal_to(discard_position(), randf_range(-12.0, 12.0), Tokens3D.DUR_NORMAL)
	if not c3d.is_face_up:
		c3d.flip(true)
	discard_pile.append(c3d)
	if AudioManager:
		AudioManager.play_card_flip()
	refresh_targets()


## Poe no descarte uma carta do modelo que nao estava na mesa.
func place_discard(card: Card) -> Card3D:
	var c3d := _spawn(card, true, Vector3(0.0, 0.4, 0.0), 1.0)
	discard_card3d(c3d)
	return c3d


## Tira a carta de cima do descarte (quem comprou do lixo).
func take_discard() -> Card3D:
	if discard_pile.is_empty():
		return null
	var c3d: Card3D = discard_pile.pop_back()
	refresh_targets()
	return c3d


func top_discard() -> Card:
	if discard_pile.is_empty():
		return null
	return (discard_pile.back() as Card3D).custom_data.get("card")


func clear_discard() -> void:
	for c3d in discard_pile:
		if is_instance_valid(c3d):
			c3d.queue_free()
	discard_pile.clear()


## Ilustra o monte com `count` versos empilhados (ate 6: e sinal, nao contagem).
func show_stock(count: int) -> void:
	var quantos := clampi(count, 0, 6)
	while stock_pile.size() > quantos:
		var fora: Card3D = stock_pile.pop_back()
		if is_instance_valid(fora):
			fora.queue_free()
	while stock_pile.size() < quantos:
		var c3d := _spawn(Card.new(1, Card.Suit.SPADES), false,
			STOCK_POS + Vector3(0.0, float(stock_pile.size()) * STACK_STEP, 0.0), 1.0)
		stock_pile.append(c3d)
	refresh_targets()


## Move uma carta ja existente para o leque de uma cadeira (comprou do lixo,
## roubou o monte do outro).
func move_to_hand(c3d: Card3D, seat: int, face_up: bool = true) -> void:
	var mao: Array = hands[seat]
	if face_up != c3d.is_face_up:
		c3d.flip(face_up)
	mao.append(c3d)
	relayout(seat, mao.size() - 1)


# ------------------------------------------------------------------ rotulos

## Nome da cadeira serigrafado no feltro, fora do leque.
func set_seat_label(seat: int, text: String, color: Color = Color(0.98, 0.84, 0.42)) -> void:
	var lbl: Label3D = _labels.get(seat)
	if lbl == null:
		lbl = Label3D.new()
		lbl.font_size = 44
		lbl.pixel_size = 0.0032
		lbl.outline_size = 14
		lbl.outline_modulate = Color(0.0, 0.0, 0.0, 0.75)
		lbl.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		lbl.shaded = false
		lbl.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
		add_child(lbl)
		_labels[seat] = lbl
	lbl.text = text
	lbl.modulate = color
	var anc := seat_anchor(seat)
	var p: Vector3 = Vector3(anc["pos"])
	var fora := p.normalized() * (Tokens3D.CARD_LENGTH * 0.5 * seat_scale(seat) + 0.22)
	lbl.position = Vector3(p.x + fora.x, 0.03, p.z + fora.z)


## Acende ou apaga o rotulo de quem esta na vez.
func set_active_seat(seat: int) -> void:
	for s in _labels:
		var lbl: Label3D = _labels[s]
		lbl.modulate.a = 1.0 if s == seat else 0.55


# ------------------------------------------------------------------- limpar

func clear_hands() -> void:
	for mao in hands:
		for c3d in mao:
			if is_instance_valid(c3d):
				c3d.queue_free()
		(mao as Array).clear()
	refresh_targets()


func clear_all() -> void:
	clear_hands()
	clear_center()
	clear_discard()
	for c3d in stock_pile:
		if is_instance_valid(c3d):
			c3d.queue_free()
	stock_pile.clear()


# -------------------------------------------------------------------- toque

## Alvos extras da mesa, `{id: Vector3}`: o monte, o descarte, uma casa do
## centro. Somam-se as cartas da mao tocavel.
func set_targets(targets: Dictionary) -> void:
	_extra_targets = targets.duplicate()
	refresh_targets()


func refresh_targets() -> void:
	if picker == null:
		return
	var alvos := _extra_targets.duplicate()
	var mao: Array = hands[tappable_seat] if tappable_seat < hands.size() else []
	for i in mao.size():
		alvos["h:%d" % i] = slot(tappable_seat, i, mao.size())
	picker.set_targets(alvos)


func set_touch_enabled(on: bool) -> void:
	if picker != null:
		picker.enabled = on


func _hand_index(id: Variant) -> int:
	if id is String and str(id).begins_with("h:"):
		return int(str(id).substr(2))
	return -1


func _on_target_tapped(id: Variant) -> void:
	var i := _hand_index(id)
	if i == -1:
		target_tapped.emit(id)
		return
	var card := model_at(tappable_seat, i)
	if card != null:
		card_tapped.emit(tappable_seat, i, card)


func _on_drag_started(id: Variant) -> void:
	var i := _hand_index(id)
	if i == -1:
		picker.cancel_drag()
		_on_target_tapped(id)
		return
	var c3d := card_at(tappable_seat, i)
	if c3d == null:
		picker.cancel_drag()
		return
	_drag_index = i
	_drag_from = c3d.position
	c3d.set_lift(Tokens3D.LIFT_DRAG)


func _on_drag_moved(_from: Variant, _over: Variant, world: Vector3) -> void:
	if _drag_index < 0 or world == Vector3.INF:
		return
	var c3d := card_at(tappable_seat, _drag_index)
	if c3d != null:
		c3d.position = Vector3(world.x, c3d.position.y, world.z)


func _on_drag_ended(_from: Variant, to: Variant) -> void:
	var i := _drag_index
	_drag_index = -1
	if i < 0:
		return
	var c3d := card_at(tappable_seat, i)
	if c3d != null:
		c3d.set_lift(0.0)
		c3d.move_to(_drag_from, Tokens3D.DUR_FAST)
	var card := model_at(tappable_seat, i)
	if card == null:
		return
	# Soltar em cima de outra carta da propria mao e reordenar, nao jogar.
	var alvo: Variant = null if _hand_index(to) != -1 else to
	card_dropped.emit(tappable_seat, i, card, alvo)
