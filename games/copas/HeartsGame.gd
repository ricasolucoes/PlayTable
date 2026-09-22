extends BaseGame

## Copas (Hearts): quatro cadeiras numa mesa de cartas 3D, contra a maquina
## ou com outro aparelho (mais duas maquinas calculadas em quem abriu a sala).
##
## Toda jogada -- da pessoa daqui, da maquina e do outro aparelho -- entra
## por `_aplicar(seat, acao)`, que valida contra `HeartsRules` e recusa o que
## nao vale. A mesa (`CardTable3D`) nao conhece regra nenhuma: este script diz
## o que fazer com cada toque e manda as cartas de la para ca.
##
## O ritmo da partida e um `Timer` so: cada passo (uma jogada da maquina, o
## fecho de uma vaza, a mao seguinte) agenda o proximo. Sem animacao
## (`sem_animacao()`, na suite) o timer fica parado e quem chama `_passo()`
## dita o ritmo -- assim uma partida inteira roda sem esperar um quadro.
##
## Cadeiras: o indice LOGICO e o do `SeatTable` (0 abriu a sala); o indice de
## VISTA e o da mesa, onde a pessoa deste aparelho fica sempre embaixo (0).
## `_vista()` e `_logico()` traduzem; no convidado a cadeira logica 1 e a
## vista 0.

enum Fase { PASSE, JOGO, FIM_DA_MAO, FIM }

const PLAYERS := HeartsRules.PLAYERS

## Pausas de encenacao, em segundos.
const DELAY_IA := 0.45
const DELAY_VAZA := 0.9
const DELAY_SAIDA := 0.6
const DELAY_MAO := 2.0
const DELAY_PASSE := 0.3

## O centro da mesa como alvo de arrasto: uma grade de amostras, e nao um ponto,
## porque o raio de captura do picker sai da distancia entre as cartas do
## leque -- uns 26 px -- e soltar a carta a 30 px do ponto exato nao contaria.
const CENTRO_RAIO := 0.9
const CENTRO_PASSO_X := 0.3
const CENTRO_PASSO_Z := 0.22

@onready var shell: GameShell = $GameShell
@onready var totals_label: Label = $UI/BottomBar/TotalsLabel
@onready var btn_passar: Button = $UI/BottomBar/BtnPassar

var table: CardTable3D = null
var seats: SeatTable = null
var sync: MatchSync = null

## Degrau de 1 a 10 do DifficultyManager: manda na maquina e no limite.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var limite: int = HeartsRules.LIMIT_LOW

var fase: int = Fase.FIM
var hands: Array = []                  # Array[Array[Card]], por cadeira logica
var totals: Array[int] = [0, 0, 0, 0]  # a partida
var taken: Array[int] = [0, 0, 0, 0]   # a mao em curso
var hand_number: int = 0
var trick: TrickEngine = null
var trick_number: int = 0
var hearts_broken: bool = false
var pass_direction: int = HeartsRules.Pass.NONE
var pending_passes: Dictionary = {}    # cadeira -> Array[Card]
var selected_pass: Array = []          # as cartas que a pessoa daqui marcou
var played: Array = []                 # cartas ja jogadas nesta mao
var moon_attempt: Dictionary = {}      # cadeira -> bool

## Sem animacao o timer nao anda e `_passo()` e chamado de fora (suite).
var animate: bool = true

## A cadeira da pessoa daqui tambem e jogada pela maquina (suite: uma partida
## inteira sem ninguem tocar na tela).
var auto_local: bool = false

## Jogadas da maquina que as regras recusaram. Zero, ou a maquina esta errada.
var ilegais_da_ia: int = 0

## Fatos da partida, para a gamificacao.
var _levou_dama: bool = false
var _atirou_na_lua: bool = false
var _mao_zerada: bool = false

## Aviso que fica na linha de status ate a vez da pessoa daqui ("Voce
## recebeu: ..."), em vez de ser engolido pelo "Vez de IA 2" seguinte.
var _aviso: String = ""

var _timer: Timer = null

## O gerador da maquina e separado do que embaralha: em rede so o anfitriao
## pensa pela maquina, e gastar o gerador da partida com isso desalinharia a
## distribuicao seguinte entre os dois aparelhos.
var _ai_rng := RandomNumberGenerator.new()


func _ready() -> void:
	menu_scene_path = MENU_CARTAS
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(restart_game)
	env_3d.apply_theme(GameTheme3D.casino_green())
	_ai_rng.randomize()

	_timer = Timer.new()
	_timer.name = "Ritmo"
	_timer.one_shot = true
	_timer.timeout.connect(_passo)
	add_child(_timer)

	table = CardTable3D.new()
	table.name = "CardTable"
	add_child(table)
	table.setup(self, PLAYERS, env_3d)
	table.card_tapped.connect(_on_card_tapped)
	table.card_dropped.connect(_on_card_dropped)
	table.set_targets({"center": _amostras_do_centro()})

	btn_passar.pressed.connect(_on_passar_pressed)

	fit_table(table.content_size())
	_start_new_game()
	begin_match("online" if net_active() else "ai")


func _amostras_do_centro() -> Array:
	var pontos: Array = []
	var x := -CENTRO_RAIO
	while x <= CENTRO_RAIO + 0.001:
		var z := -CENTRO_RAIO
		while z <= CENTRO_RAIO + 0.001:
			pontos.append(Vector3(x, CardTable3D.CARD_Y, z))
			z += CENTRO_PASSO_Z
		x += CENTRO_PASSO_X
	return pontos


# ------------------------------------------------------------------ partida

func _start_new_game() -> void:
	game_over = false
	fase = Fase.FIM
	if _timer != null:
		_timer.stop()
	ai_level = DifficultyManager.get_level(game_id)
	limite = HeartsRules.game_limit(ai_level)
	totals = [0, 0, 0, 0]
	taken = [0, 0, 0, 0]
	hand_number = 0
	hands = []
	trick = null
	_levou_dama = false
	_atirou_na_lua = false
	_mao_zerada = false
	_aviso = ""
	selected_pass.clear()
	pending_passes.clear()
	btn_passar.visible = false
	btn_restart.hide()

	seats = SeatTable.for_game(self, PLAYERS, true)
	sync = MatchSync.new(self, seats)
	sync.start()
	_rotular_cadeiras()
	_atualizar_placar()
	shell.timer.reset()
	shell.timer.start()
	if sync.waiting_for_deal():
		table.clear_all()
		set_status(tr("NET_WAITING_DEAL"))
		return
	_nova_mao()


## Distribui e abre a mao: passe, ou direto para a saida do 2 de paus.
func _nova_mao() -> void:
	taken = [0, 0, 0, 0]
	trick_number = 0
	hearts_broken = false
	trick = null
	pending_passes.clear()
	selected_pass.clear()
	played.clear()
	moon_attempt.clear()
	_aviso = ""

	var deck := Deck.create_standard_52()
	sync.shuffle_cards(deck)
	hands = HeartsRules.deal(deck)
	for s in PLAYERS:
		hands[s] = HeartsRules.sort_hand(hands[s])
	_pintar_mesa()
	if AudioManager:
		AudioManager.play_shuffle()

	pass_direction = HeartsRules.pass_direction(hand_number)
	_atualizar_placar()
	if pass_direction == HeartsRules.Pass.NONE:
		set_status(tr("COPAS_NO_PASS"))
		_comecar_jogo()
	else:
		_iniciar_passe()


func _pintar_mesa() -> void:
	table.clear_all()
	for s in PLAYERS:
		var vista := _vista(s)
		for c in hands[s]:
			table.add_card(vista, c, vista == 0)


func _iniciar_passe() -> void:
	fase = Fase.PASSE
	btn_passar.visible = true
	btn_passar.disabled = true
	btn_passar.text = tr("COPAS_BTN_PASS_N") % 0
	set_status(tr("COPAS_PASS_PROMPT") % tr(_chave_da_direcao()))
	table.set_active_seat(0)
	set_active_side(true)
	_continuar(DELAY_PASSE)


func _chave_da_direcao() -> String:
	match pass_direction:
		HeartsRules.Pass.LEFT:
			return "COPAS_DIR_LEFT"
		HeartsRules.Pass.RIGHT:
			return "COPAS_DIR_RIGHT"
	return "COPAS_DIR_ACROSS"


## As quatro cadeiras passaram: as cartas trocam de mao, no modelo e na mesa.
func _resolver_passe() -> void:
	for seat in PLAYERS:
		for c in pending_passes[seat]:
			(hands[seat] as Array).erase(c)
	for seat in PLAYERS:
		var alvo := HeartsRules.pass_target(seat, pass_direction)
		for c in pending_passes[seat]:
			(hands[alvo] as Array).append(c)
	for s in PLAYERS:
		hands[s] = HeartsRules.sort_hand(hands[s])

	for seat in PLAYERS:
		var alvo := HeartsRules.pass_target(seat, pass_direction)
		var de := _vista(seat)
		var para := _vista(alvo)
		for c in pending_passes[seat]:
			var c3d := table.remove_card(de, table.index_of(de, c))
			if c3d != null:
				c3d.select(false)
				table.move_to_hand(c3d, para, para == 0)
	for s in PLAYERS:
		table.reorder(_vista(s), hands[s])

	var eu := _local()
	var recebidas: Array = pending_passes[HeartsRules.pass_source(eu, pass_direction)]
	_aviso = tr("COPAS_PASS_RECEIVED") % _nomes_curtos(recebidas)
	set_status(_aviso)
	for c in recebidas:
		table.set_selected(0, table.index_of(0, c), true)
	selected_pass.clear()
	btn_passar.visible = false
	if AudioManager:
		AudioManager.play_draw()
	_comecar_jogo()


func _nomes_curtos(cards: Array) -> String:
	var partes: PackedStringArray = []
	for c in cards:
		partes.append((c as Card).get_short_name())
	return " ".join(partes)


func _comecar_jogo() -> void:
	fase = Fase.JOGO
	trick_number = 0
	hearts_broken = false
	played.clear()
	for s in PLAYERS:
		moon_attempt[s] = seats.is_ai(s) and HeartsAI.wants_moon(hands[s], ai_level)
	var lider := HeartsRules.holder_of_two_of_clubs(hands)
	trick = HeartsRules.new_trick()
	trick.begin(maxi(lider, 0))
	_anunciar_vez()
	_continuar(DELAY_SAIDA)


## Fecha a vaza: quem levou soma os pontos, as cartas vao para ela, e ela sai
## na proxima -- ou a mao acabou.
func _fechar_vaza() -> void:
	var vencedor := trick.winner()
	var cartas := trick.cards()
	var pontos := HeartsRules.trick_points(cartas)
	taken[vencedor] += pontos
	if seats.is_local(vencedor) and HeartsRules.contains_queen(cartas):
		_levou_dama = true
	table.collect_center(_vista(vencedor))
	var nome := seats.display_name(vencedor, self)
	_aviso = ""
	if pontos > 0:
		set_status(tr("COPAS_TRICK_WON_POINTS") % [nome, pontos])
	else:
		set_status(tr("COPAS_TRICK_WON") % nome)
	trick_number += 1
	_atualizar_placar()
	if trick_number >= HeartsRules.TRICKS_PER_HAND:
		_fim_da_mao()
		return
	trick = HeartsRules.new_trick()
	trick.begin(vencedor)
	_anunciar_vez(false)
	_continuar(DELAY_SAIDA)


func _fim_da_mao() -> void:
	var scores := HeartsRules.hand_scores(taken)
	var lua := HeartsRules.moon_shooter(taken)
	var eu := _local()
	if lua == eu:
		_atirou_na_lua = true
	if scores[eu] == 0:
		_mao_zerada = true
	for s in PLAYERS:
		totals[s] += scores[s]
	hand_number += 1
	fase = Fase.FIM_DA_MAO
	_atualizar_placar()
	table.set_playable(0, [])
	if lua != -1:
		set_status(tr("COPAS_MOON") % seats.display_name(lua, self))
	else:
		set_status(tr("COPAS_HAND_OVER") % scores[eu])
	if HeartsRules.is_game_over(totals, limite):
		_fim_de_partida()
		return
	_continuar(DELAY_MAO)


func _fim_de_partida() -> void:
	fase = Fase.FIM
	shell.timer.stop()
	var eu := _local()
	var vencedores := HeartsRules.winners(totals)
	var venci := vencedores.has(eu)
	var flags: Array[String] = []
	if _atirou_na_lua:
		flags.append("copas_lua")
	if _mao_zerada:
		flags.append("copas_zero")
	if not _levou_dama:
		flags.append("copas_sem_dama")
	var extra := {
		"score": totals[eu],
		"points": totals[eu],
		"mode": "online" if seats.online() else "ai",
		"time": shell.timer.get_time(),
		"perfect": totals[eu] == 0,
		"flags": flags,
	}
	var msg := ""
	if venci:
		msg = tr("COPAS_WIN") % totals[eu]
	else:
		var v: int = vencedores[0]
		msg = tr("COPAS_LOSE") % [seats.display_name(v, self), totals[v]]
	btn_passar.visible = false
	table.set_playable(0, [])
	finish_game(msg, venci, extra)


# --------------------------------------------------------------------- ritmo

## Agenda o proximo passo. Reiniciar o timer descarta o passo que ja estava
## agendado: a pessoa que joga antes de a pausa acabar nao dispara dois.
func _continuar(delay: float) -> void:
	if not animate or game_over or _timer == null or not is_inside_tree():
		return
	var d := Quality3D.duration(delay)
	if d <= 0.0:
		_passo.call_deferred()
		return
	_timer.start(d)


## Para a suite: nada anda sozinho, `_passo()` e chamado de fora.
func sem_animacao() -> void:
	animate = false
	if _timer != null:
		_timer.stop()


## Um passo da partida. Devolve se alguma coisa aconteceu.
func _passo() -> bool:
	if game_over:
		return false
	match fase:
		Fase.PASSE:
			return _passo_do_passe()
		Fase.JOGO:
			return _passo_do_jogo()
		Fase.FIM_DA_MAO:
			_nova_mao()
			return true
	return false


func _passo_do_passe() -> bool:
	var houve := false
	for seat in PLAYERS:
		if fase != Fase.PASSE:
			break
		if pending_passes.has(seat) or not _pensa_aqui(seat):
			continue
		var cartas := HeartsAI.choose_pass(hands[seat], ai_level, _ai_rng)
		var ids: Array = []
		for c in cartas:
			ids.append(c.id)
		var acao := {"t": "pass", "ids": ids}
		if _aplicar(seat, acao):
			sync.send(seat, acao)
			houve = true
		else:
			ilegais_da_ia += 1
	return houve


func _passo_do_jogo() -> bool:
	if trick == null:
		return false
	if trick.is_complete():
		_fechar_vaza()
		return true
	var seat := trick.current_seat()
	if _pensa_aqui(seat):
		var legais := HeartsRules.legal_cards(hands[seat], trick, trick_number == 0, hearts_broken)
		var card := HeartsAI.choose_play(hands[seat], legais, trick, _contexto_ia(seat), ai_level, _ai_rng)
		if card == null:
			ilegais_da_ia += 1
			return false
		var acao := {"t": "play", "id": card.id}
		if _aplicar(seat, acao):
			sync.send(seat, acao)
			return true
		ilegais_da_ia += 1
		return false
	if seats.is_local(seat):
		_preparar_vez_local()
	return false


## A maquina desta cadeira pensa neste aparelho.
func _pensa_aqui(seat: int) -> bool:
	return seats.ai_runs_here(seat) or (auto_local and seats.is_local(seat))


func _contexto_ia(seat: int) -> Dictionary:
	return {
		"seat": seat,
		"taken": taken,
		"played": played,
		"moon": bool(moon_attempt.get(seat, false)),
	}


# ------------------------------------------------------------------- acoes

## A unica porta de entrada de jogada: pessoa, maquina e rede. Recusa o que
## as regras nao aceitam e devolve `false`.
func _aplicar(seat: int, acao: Dictionary) -> bool:
	if game_over or seats == null or seat < 0 or seat >= PLAYERS:
		return false
	match str(acao.get("t", "")):
		"pass":
			return _aplicar_passe(seat, acao.get("ids", []))
		"play":
			return _aplicar_jogada(seat, str(acao.get("id", "")))
	return false


func _aplicar_passe(seat: int, ids: Variant) -> bool:
	if fase != Fase.PASSE or pass_direction == HeartsRules.Pass.NONE or pending_passes.has(seat):
		return false
	if not (ids is Array) or (ids as Array).size() != HeartsRules.PASS_COUNT:
		return false
	var cartas: Array = []
	for id in ids:
		var c := HeartsRules.find_by_id(hands[seat], str(id))
		if c == null or cartas.has(c):
			return false
		cartas.append(c)
	pending_passes[seat] = cartas
	if seats.is_local(seat):
		btn_passar.visible = false
		set_status(tr("COPAS_PASS_WAIT"))
		for c in cartas:
			table.set_selected(0, table.index_of(0, c), true)
	if pending_passes.size() == PLAYERS:
		_resolver_passe()
	return true


func _aplicar_jogada(seat: int, id: String) -> bool:
	if fase != Fase.JOGO or trick == null or trick.is_complete() or trick.current_seat() != seat:
		return false
	var card := HeartsRules.find_by_id(hands[seat], id)
	if card == null:
		return false
	if not HeartsRules.is_legal(hands[seat], card, trick, trick_number == 0, hearts_broken):
		return false
	(hands[seat] as Array).erase(card)
	trick.play(seat, card)
	played.append(card)
	if HeartsRules.is_heart(card) and not hearts_broken:
		hearts_broken = true
		_aviso = tr("COPAS_HEARTS_BROKEN")
		set_status(_aviso)
	var vista := _vista(seat)
	if vista == 0:
		table.set_playable(0, [])
	table.play_to_center(vista, table.index_of(vista, card), true)
	if trick.is_complete():
		table.set_active_seat(-1)
		_continuar(DELAY_VAZA)
	else:
		_anunciar_vez(false)
		_continuar(DELAY_IA)
	return true


## De quem e a vez: acende a cadeira, o lado do placar e, quando e a pessoa
## daqui, levanta as cartas que ela pode jogar.
func _anunciar_vez(escrever: bool = true) -> void:
	if trick == null:
		return
	var seat := trick.current_seat()
	table.set_active_seat(_vista(seat))
	set_active_side(seats.is_local(seat))
	if seats.is_local(seat):
		_aviso = ""
		set_status(tr("COPAS_YOUR_LEAD") if not trick.has_started() else tr("COPAS_YOUR_TURN"))
		_preparar_vez_local()
		return
	table.set_playable(0, [])
	if escrever or _aviso == "":
		set_status(tr("COPAS_TURN_OF") % seats.display_name(seat, self))


func _preparar_vez_local() -> void:
	var eu := _local()
	var legais := HeartsRules.legal_cards(hands[eu], trick, trick_number == 0, hearts_broken)
	var indices: Array = []
	for c in legais:
		var i := table.index_of(0, c)
		if i != -1:
			indices.append(i)
	table.set_playable(0, indices)


# -------------------------------------------------------------------- toque

func _on_card_tapped(_seat: int, index: int, card: Card) -> void:
	if game_over or seats == null:
		return
	var eu := _local()
	match fase:
		Fase.PASSE:
			_marcar_para_passe(index, card)
		Fase.JOGO:
			if trick == null or trick.current_seat() != eu:
				_recusar(index, tr("COPAS_NOT_YOUR_TURN"))
				return
			var motivo := HeartsRules.illegal_reason(hands[eu], card, trick, trick_number == 0, hearts_broken)
			if motivo != "":
				_recusar(index, _texto_do_motivo(motivo))
				return
			_jogar(eu, card)


## Arrastou ate o centro: vale como toque. Fora do centro a mesa ja devolveu
## a carta ao leque.
func _on_card_dropped(seat: int, index: int, card: Card, target: Variant) -> void:
	if target is String and str(target) == "center":
		_on_card_tapped(seat, index, card)


func _marcar_para_passe(index: int, card: Card) -> void:
	if pending_passes.has(_local()):
		return
	if selected_pass.has(card):
		selected_pass.erase(card)
		table.set_selected(0, index, false)
	elif selected_pass.size() < HeartsRules.PASS_COUNT:
		selected_pass.append(card)
		table.set_selected(0, index, true)
	else:
		_recusar(index, tr("COPAS_PASS_FULL"))
		return
	play_click()
	btn_passar.disabled = selected_pass.size() != HeartsRules.PASS_COUNT
	btn_passar.text = tr("COPAS_BTN_PASS_N") % selected_pass.size()


func _on_passar_pressed() -> void:
	if game_over or fase != Fase.PASSE or selected_pass.size() != HeartsRules.PASS_COUNT:
		return
	var ids: Array = []
	for c in selected_pass:
		ids.append((c as Card).id)
	var acao := {"t": "pass", "ids": ids}
	var eu := _local()
	if _aplicar(eu, acao):
		play_click()
		sync.send(eu, acao)


func _jogar(seat: int, card: Card) -> void:
	var acao := {"t": "play", "id": card.id}
	if _aplicar(seat, acao):
		sync.send(seat, acao)


## Recusar calado e o que faz o jogo parecer quebrado: a carta treme e a
## linha de status diz por que.
func _recusar(index: int, texto: String) -> void:
	table.reject(0, index)
	set_status(texto)
	if AudioManager:
		AudioManager.play_error()


func _texto_do_motivo(motivo: String) -> String:
	match motivo:
		HeartsRules.REASON_TWO_OF_CLUBS:
			return tr("COPAS_ILLEGAL_TWO")
		HeartsRules.REASON_HEARTS:
			return tr("COPAS_ILLEGAL_HEARTS")
		HeartsRules.REASON_FIRST_TRICK:
			return tr("COPAS_ILLEGAL_FIRST")
	var naipe := str(Card.SUIT_SYMBOLS.get(trick.led_suit(), "")) if trick != null else ""
	return tr("COPAS_ILLEGAL_FOLLOW") % naipe


# --------------------------------------------------------------------- rede

func _on_net_move(payload: Dictionary) -> void:
	if sync == null:
		return
	var msg := sync.accept(payload)
	match str(msg.get("t", "")):
		"deal":
			_nova_mao()
		"act":
			_aplicar(int(msg.get("seat", -1)), msg.get("a", {}))


# ----------------------------------------------------------------- cadeiras

func _local() -> int:
	return maxi(seats.local_index(), 0) if seats != null else 0


## Cadeira logica -> lugar na mesa (a pessoa daqui sempre embaixo).
func _vista(seat: int) -> int:
	return posmod(seat - _local(), PLAYERS)


func _logico(vista: int) -> int:
	return posmod(vista + _local(), PLAYERS)


func _rotular_cadeiras() -> void:
	for s in PLAYERS:
		table.set_seat_label(_vista(s), seats.display_name(s, self))


# ------------------------------------------------------------------- placar

## Na barra: os seus pontos contra o menor adversario. No pe da tela: os
## quatro totais, com o que cada um ja levou nesta mao.
func _atualizar_placar() -> void:
	if seats == null:
		return
	var eu := _local()
	set_duel_score(totals[eu], HeartsRules.lowest_rival(totals, eu), "SCORE_YOU", "COPAS_SCORE_RIVAL")
	var partes: PackedStringArray = []
	for s in PLAYERS:
		var t := "%s %d" % [seats.display_name(s, self), totals[s]]
		if taken[s] > 0 and fase == Fase.JOGO:
			t += " +%d" % taken[s]
		partes.append(t)
	totals_label.text = "  ·  ".join(partes)
	shell.set_level("%s  ·  %s" % [DifficultyManager.label_for(game_id), tr("COPAS_LIMIT") % limite])
