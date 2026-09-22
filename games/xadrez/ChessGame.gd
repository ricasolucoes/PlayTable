extends BaseGame

## ChessGame: xadrez sobre a mesa 3D de marmore.
##
## As brancas ficam embaixo, do lado de quem segura o aparelho. Em rede quem
## abriu a sala joga de brancas; o convidado ve o tabuleiro virado, com as
## pretas dele embaixo -- as mesmas coordenadas, so a mesa gira.
##
## Toda jogada -- da pessoa, da IA e do outro aparelho -- passa por
## `_aplicar()`. A regra e de `ChessRules`; a cena so anima e pergunta.
## A rede usa o padrao direto do Reversi (`net_send` + `_on_net_move`): o
## xadrez nao sorteia nada, entao nao precisa da semente do `MatchSync`.

const CELL := 0.75
## Pausa de encenacao antes de a IA responder. A busca corre durante ela.
const PAUSA_IA := 0.35

var estado: Dictionary = {}
## Peca 3D por casa (indice 0..63).
var pieces_3d: Dictionary = {}
var selected: int = -1
var valid_moves: Array[Dictionary] = []
## "A vez deste aparelho": na mesa compartilhada e sempre verdadeiro.
var is_player_turn: bool = true
var vs_ai: bool = true
var em_rede: bool = false
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var picker: DragPicker3D = null
var promo_modal: Control = null

var _drag_piece: Token3D = null
var _drag_from: int = -1
## Estados antes de cada lance, para o desfazer contra a maquina.
var _historico: Array[Dictionary] = []
var _pensando: bool = false
## Sobe a cada partida nova: a busca que estava no ar descobre que o lance
## dela e de outro tabuleiro.
var _geracao: int = 0
var _lances_locais: int = 0
var _perdi_peca: bool = false
var _fatos: Dictionary = {}
var _promo_pendente: Dictionary = {}
## A posicao antes do ultimo lance: e nela que se mede o "por um triz".
var _estado_anterior: Dictionary = {}

@onready var board_3d: Board3D = $Board3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var shell: GameShell = $GameShell
@onready var rodape: Control = $UI/Rodape
@onready var btn_undo: Button = $UI/Rodape/BtnUndo


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(restart_game)
	btn_undo.pressed.connect(_desfazer)
	env_3d.apply_theme(GameTheme3D.stone_gallery())
	board_3d.setup_board(8, 8, CELL, "marble_checkered")
	board_3d.cell_clicked.connect(_on_cell_clicked)
	# HUD ancorada antes do enquadramento, para `measure_hud_bands()` medi-la.
	if top_bar != null:
		top_bar.oferecer_modo(vs_ai)
		top_bar.mode_pressed.connect(_on_modo_trocado)
	_montar_promocao()
	_setup_picker()
	fit_table(board_3d.content_size())
	_start_new_game()
	begin_match(_modo())


func _start_new_game() -> void:
	_geracao += 1
	game_over = false
	_pensando = false
	em_rede = net_active()
	selected = -1
	valid_moves.clear()
	_historico.clear()
	_promo_pendente.clear()
	_estado_anterior = {}
	_lances_locais = 0
	_perdi_peca = false
	_fatos.clear()
	if promo_modal != null:
		promo_modal.hide()
	if picker != null:
		picker.cancel_drag()
	btn_restart.hide()
	btn_undo.disabled = false
	ai_level = DifficultyManager.get_level(game_id)
	if top_bar != null:
		# Com dois aparelhos na mesa nao ha modo para escolher.
		if not em_rede:
			top_bar.oferecer_modo(vs_ai)
		else:
			top_bar.esconder_modo()
	rodape.visible = vs_ai and not em_rede
	estado = ChessRules.new_game()
	_orientar()
	_sync_pieces()
	is_player_turn = _vez_e_local()
	_pintar_nivel()
	_pintar_status()
	_update_score()
	shell.timer.reset()
	shell.timer.start()
	# O rodape entra e sai com o modo: a mesa se reenquadra.
	fit_table(board_3d.content_size())


func _modo() -> String:
	if em_rede:
		return "online"
	return "ai" if vs_ai else "versus"


## O lado que este aparelho controla: o assento da sala em rede, as brancas
## contra a maquina, e o lado da vez na mesa compartilhada.
func _meu() -> int:
	if em_rede:
		return ChessRules.WHITE if net_seat() == 1 else ChessRules.BLACK
	if vs_ai:
		return ChessRules.WHITE
	return int(estado["turn"])


## O lado e jogado por uma pessoa neste aparelho?
func _lado_e_local(side: int) -> bool:
	if em_rede or vs_ai:
		return side == _meu()
	return true


func _vez_e_local() -> bool:
	return _lado_e_local(int(estado["turn"]))


func _pode_tocar() -> bool:
	return not game_over and not _pensando and _promo_pendente.is_empty() and _vez_e_local()


## O jogador trocou o modo: a partida recomeca, porque meia partida contra a
## maquina nao vira meia partida entre duas pessoas.
func _on_modo_trocado(novo_vs_ai: bool) -> void:
	vs_ai = novo_vs_ai
	restart_game()


# --------------------------------------------------------------- mesa

## Em rede o convidado joga de pretas: a mesa gira meia volta para as pecas
## dele ficarem embaixo. Tabuleiro e pecas giram juntos, e os alvos do toque
## sao reprojetados da mesa girada.
func _orientar() -> void:
	var giro := PI if (em_rede and _meu() == ChessRules.BLACK) else 0.0
	board_3d.rotation.y = giro
	pieces_root.rotation.y = giro
	_setup_targets()


func _cell(idx: int) -> Vector2i:
	return Vector2i(idx >> 3, idx & 7)


## Altura de apoio da peca: o topo da casa, nunca um valor solto.
func _cell_pos(idx: int) -> Vector3:
	return board_3d.get_cell_position_3d(idx >> 3, idx & 7, Tokens3D.TILE_THICKNESS)


func _sync_pieces() -> void:
	for p in pieces_root.get_children():
		p.queue_free()
	pieces_3d.clear()
	var b: PackedInt32Array = estado["b"]
	for idx in 64:
		if b[idx] != 0:
			pieces_3d[idx] = _criar_peca(idx, b[idx])
	board_3d.clear_states()
	_marcar_xeque()


func _criar_peca(idx: int, peca: int) -> Token3D:
	var tok := ChessPieces3D.criar(absi(peca), signi(peca))
	tok.position = _cell_pos(idx)
	pieces_root.add_child(tok)
	ChessPieces3D.vestir(tok, absi(peca))
	return tok


## O rei em xeque fica marcado em vermelho enquanto o xeque durar.
func _marcar_xeque() -> void:
	if not ChessRules.is_in_check(estado):
		return
	var k := ChessRules.king_square(estado["b"], int(estado["turn"]))
	if k >= 0:
		board_3d.set_cells_state([_cell(k)], Board3D.CellState.INVALID)


func _update_score() -> void:
	var b: PackedInt32Array = estado["b"]
	var brancas := ChessRules.captured_value(b, ChessRules.WHITE)
	var pretas := ChessRules.captured_value(b, ChessRules.BLACK)
	if em_rede:
		var sou_branco := _meu() == ChessRules.WHITE
		set_duel_score(brancas if sou_branco else pretas, pretas if sou_branco else brancas, "NET_YOU", "NET_OPPONENT")
	elif not vs_ai:
		set_duel_score(brancas, pretas, "SCORE_PLAYER_1", "SCORE_PLAYER_2")
	else:
		set_duel_score(brancas, pretas)


func _pintar_nivel() -> void:
	if em_rede:
		shell.set_level(tr("NET_MODE_LABEL") % net_opponent_name())
	elif not vs_ai:
		shell.set_level(tr("MODE_LABEL") % tr("MODE_TWO_PLAYERS"))
	else:
		shell.set_level(DifficultyManager.label_for(game_id))


func _pintar_status() -> void:
	var texto := ""
	if em_rede:
		texto = tr("NET_YOUR_TURN") if is_player_turn else tr("NET_THEIR_TURN") % net_opponent_name()
	elif not vs_ai:
		texto = tr("XADREZ_TURN_WHITE") if int(estado["turn"]) == ChessRules.WHITE else tr("XADREZ_TURN_BLACK")
	else:
		texto = tr("XADREZ_YOUR_TURN") if is_player_turn else tr("XADREZ_AI_TURN")
	if ChessRules.is_in_check(estado):
		texto = "%s %s" % [tr("XADREZ_CHECK"), texto]
	set_status(texto)
	if em_rede or vs_ai:
		set_active_side(is_player_turn)
	else:
		set_active_side(int(estado["turn"]) == ChessRules.WHITE)


# --------------------------------------------------------------- toque

## O picker fica por cima do picking fisico do Board3D e passa a ser a porta
## do toque: o toque simples cai em `_on_cell_clicked`, o arrasto nos tres
## sinais abaixo.
func _setup_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, Tokens3D.TILE_THICKNESS)
	_setup_targets()
	picker.target_tapped.connect(func(id: Variant) -> void:
		var idx := int(id)
		_on_cell_clicked(idx >> 3, idx & 7))
	picker.drag_started.connect(_on_peca_pega)
	picker.drag_moved.connect(_on_peca_movida)
	picker.drag_ended.connect(_on_peca_solta)


func _setup_targets() -> void:
	if picker == null or not board_3d.is_inside_tree():
		return
	var alvos: Dictionary = {}
	for idx in 64:
		alvos[idx] = board_3d.to_global(_cell_pos(idx))
	picker.set_targets(alvos)


func _on_cell_clicked(r: int, c: int) -> void:
	if not _pode_tocar():
		return
	var idx := r * 8 + c
	for vm in valid_moves:
		if int(vm["to"]) == idx:
			_jogar_humano(vm)
			return
	var b: PackedInt32Array = estado["b"]
	var p := b[idx]
	if p != 0 and signi(p) == int(estado["turn"]):
		_selecionar(idx)
	else:
		# Tocar fora das proprias pecas desfaz a selecao.
		_limpar_selecao()


func _selecionar(idx: int) -> void:
	selected = idx
	valid_moves = ChessRules.legal_moves(estado, idx)
	_mostrar_selecao()
	if valid_moves.is_empty():
		# Recusar calado e o que faz o jogo parecer quebrado: a peca treme.
		var tok: Token3D = pieces_3d.get(idx)
		if tok != null:
			tok.reject()
		if AudioManager:
			AudioManager.play_error()


## Marca a origem, levanta a peca e aponta cada destino. A ultima jogada e o
## xeque continuam marcados: sao informacao, nao selecao.
func _mostrar_selecao() -> void:
	board_3d.clear_states(Board3D.CellState.LAST_MOVE)
	_marcar_xeque()
	if selected < 0:
		return
	board_3d.set_cells_state([_cell(selected)], Board3D.CellState.SELECTED)
	var destinos: Array = []
	for vm in valid_moves:
		destinos.append(_cell(int(vm["to"])))
	board_3d.set_cells_state(destinos, Board3D.CellState.VALID)
	_baixar_pecas()
	var tok: Token3D = pieces_3d.get(selected)
	if tok != null:
		tok.select(true)


func _limpar_selecao() -> void:
	selected = -1
	valid_moves.clear()
	board_3d.clear_states(Board3D.CellState.LAST_MOVE)
	_marcar_xeque()
	_baixar_pecas()


func _baixar_pecas() -> void:
	for tok in pieces_3d.values():
		tok.select(false)


func _on_peca_pega(id: Variant) -> void:
	var origem := int(id)
	var b: PackedInt32Array = estado["b"]
	if not _pode_tocar() or b[origem] == 0 or signi(b[origem]) != int(estado["turn"]):
		picker.cancel_drag()
		return
	var tok: Token3D = pieces_3d.get(origem)
	if tok == null:
		picker.cancel_drag()
		return
	_selecionar(origem)
	_drag_piece = tok
	_drag_from = origem
	tok.set_lift(Tokens3D.LIFT_DRAG)


func _on_peca_movida(_from_id: Variant, _over: Variant, world: Vector3) -> void:
	if _drag_piece == null or world == Vector3.INF:
		return
	# Acompanha o dedo sem tween: tween aqui atrasaria a peca em relacao ao
	# ponto tocado, e o gesto pareceria emperrado.
	var local: Vector3 = pieces_root.to_local(world)
	_drag_piece.position = Vector3(local.x, Tokens3D.TILE_THICKNESS, local.z)


func _on_peca_solta(_from_id: Variant, to: Variant) -> void:
	var tok := _drag_piece
	var origem := _drag_from
	_drag_piece = null
	_drag_from = -1
	if tok == null:
		return
	tok.set_lift(0.0)
	if to != null:
		var destino := int(to)
		for vm in valid_moves:
			if int(vm["to"]) == destino:
				if int(vm["promo"]) != 0:
					# A escolha da peca vem antes do lance: o peao espera na
					# casa dele enquanto o modal esta aberto.
					tok.slide_to(_cell_pos(origem))
				_jogar_humano(vm)
				return
	# Soltou fora de um destino: a peca volta. A selecao continua de pe para
	# quem prefere jogar com dois toques.
	tok.slide_to(_cell_pos(origem))
	tok.select(true)


# --------------------------------------------------------------- lances

func _jogar_humano(m: Dictionary) -> void:
	if int(m["promo"]) != 0:
		_promo_pendente = m
		_abrir_promocao()
		return
	_confirmar_humano(m)


func _confirmar_humano(m: Dictionary) -> void:
	_historico.append(estado)
	if em_rede:
		net_send({"from": int(m["from"]), "to": int(m["to"]), "promo": ChessRules.promo_letter(int(m["promo"]))})
	_aplicar(m)
	_depois_do_lance()


## Executa o lance na mesa e no estado. E o mesmo caminho para a pessoa, a
## IA e o outro aparelho: a mesa nao sabe quem jogou.
func _aplicar(m: Dictionary) -> void:
	var b: PackedInt32Array = estado["b"]
	var side := int(estado["turn"])
	var from := int(m["from"])
	var to := int(m["to"])
	var local := _lado_e_local(side)
	_estado_anterior = estado

	var comida := -1
	if bool(m["ep"]):
		comida = to + (8 if side > 0 else -8)
	elif b[to] != 0:
		comida = to
	if comida >= 0:
		var vitima: Token3D = pieces_3d.get(comida)
		if vitima != null:
			vitima.vanish()
		pieces_3d.erase(comida)
		if (em_rede or vs_ai) and -side == _meu():
			_perdi_peca = true

	var tok: Token3D = pieces_3d.get(from)
	pieces_3d.erase(from)
	if tok != null:
		pieces_3d[to] = tok
		tok.select(false)
		# O cavalo salta por cima; a captura tambem chega por cima da vitima.
		if absi(b[from]) == ChessRules.KNIGHT or comida >= 0:
			tok.jump_to(_cell_pos(to), Tokens3D.ARC_LONG if comida >= 0 else Tokens3D.ARC_SHORT)
		else:
			tok.slide_to(_cell_pos(to))

	if bool(m["castle"]):
		var linha := to & ~7
		var lado_rei := (to & 7) == 6
		var torre_de := linha + 7 if lado_rei else linha
		var torre_para := linha + 5 if lado_rei else linha + 3
		var torre: Token3D = pieces_3d.get(torre_de)
		pieces_3d.erase(torre_de)
		if torre != null:
			pieces_3d[torre_para] = torre
			torre.slide_to(_cell_pos(torre_para))

	estado = ChessRules.apply_move(estado, m)
	var promo := int(m["promo"])
	if promo != 0:
		_promover_visual(to, promo * side)

	if local:
		_lances_locais += 1
		if bool(m["castle"]):
			_fatos["xadrez_roque"] = true
		if bool(m["ep"]):
			_fatos["xadrez_en_passant"] = true
		if promo != 0:
			_fatos["xadrez_promocao"] = true

	selected = -1
	valid_moves.clear()
	board_3d.clear_states()
	board_3d.set_cells_state([_cell(from), _cell(to)], Board3D.CellState.LAST_MOVE)
	_marcar_xeque()
	_baixar_pecas()
	if AudioManager:
		if comida >= 0:
			AudioManager.play_capture()
		else:
			AudioManager.play_piece_place()
	_update_score()


## A peca promovida aparece quando o peao chega a casa, nao antes.
func _promover_visual(casa: int, peca: int) -> void:
	var tw := create_tween()
	tw.tween_interval(maxf(Quality3D.duration(Tokens3D.DUR_NORMAL), 0.001))
	tw.tween_callback(_trocar_peca.bind(casa, peca))


func _trocar_peca(casa: int, peca: int) -> void:
	var b: PackedInt32Array = estado["b"]
	# A partida pode ter recomecado, ou o lance sido desfeito, no meio do
	# deslize: so troca se a peca ainda e a promovida.
	if b[casa] != peca:
		return
	var velha: Token3D = pieces_3d.get(casa)
	if velha != null:
		velha.queue_free()
	pieces_3d[casa] = _criar_peca(casa, peca)
	if AudioManager:
		AudioManager.play_card_match()


func _depois_do_lance() -> void:
	var resultado := ChessRules.game_state(estado)
	if resultado != ChessRules.Result.PLAYING:
		_terminar(resultado)
		return
	is_player_turn = _vez_e_local()
	_pintar_status()
	if vs_ai and not em_rede and int(estado["turn"]) == ChessRules.BLACK:
		_vez_da_ia()


## Pensa fora da linha principal, durante a pausa de encenacao. A tarefa
## recebe copias planas do estado, nunca a cena: a cena pode ser fechada com
## a busca ainda rodando.
func _vez_da_ia() -> void:
	is_player_turn = false
	_pensando = true
	btn_undo.disabled = true
	_pintar_status()
	var geracao := _geracao
	var b: PackedInt32Array = (estado["b"] as PackedInt32Array).duplicate()
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(ChessAI.pensar_em_tarefa.bind(
		b, int(estado["turn"]), int(estado["castle"]), int(estado["ep"]), ai_level, saida))
	# A arvore fica guardada antes do laco: quando o jogador sai da cena com a
	# busca em andamento, `get_tree()` passa a devolver `null` no quadro
	# seguinte, e `await null.process_frame` estoura.
	var arvore := get_tree()
	if arvore != null:
		await arvore.create_timer(PAUSA_IA).timeout
	while not WorkerThreadPool.is_task_completed(tarefa):
		if arvore == null:
			break
		await arvore.process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)
	if not is_inside_tree() or geracao != _geracao:
		return
	_pensando = false
	btn_undo.disabled = false
	if game_over or saida.is_empty() or int(saida[0]) < 0:
		return
	_historico.append(estado)
	_aplicar(ChessRules.decode(int(saida[0]), estado["b"]))
	_depois_do_lance()


## Desfaz o par de lances -- a resposta da maquina e o lance da pessoa. So
## contra a maquina: entre duas pessoas ou dois aparelhos nao se volta atras.
func _desfazer() -> void:
	if not vs_ai or em_rede or game_over or _pensando or _historico.is_empty():
		return
	play_click()
	var alvo: Dictionary = _historico.pop_back()
	if int(alvo["turn"]) == ChessRules.BLACK and not _historico.is_empty():
		alvo = _historico.pop_back()
	estado = alvo
	_promo_pendente.clear()
	promo_modal.hide()
	_lances_locais = maxi(0, _lances_locais - 1)
	selected = -1
	valid_moves.clear()
	_sync_pieces()
	is_player_turn = _vez_e_local()
	_pintar_status()
	_update_score()


# --------------------------------------------------------------- rede

## A jogada do outro aparelho. So na vez dele, e so se for legal aqui tambem.
func _on_net_move(payload: Dictionary) -> void:
	if not em_rede or game_over or int(estado["turn"]) == _meu():
		return
	var from := int(payload.get("from", -1))
	var to := int(payload.get("to", -1))
	if from < 0 or from > 63 or to < 0 or to > 63:
		return
	var m := ChessRules.find_move(estado, from, to, ChessRules.promo_code(str(payload.get("promo", ""))))
	if m < 0:
		return
	_historico.append(estado)
	_aplicar(ChessRules.decode(m, estado["b"]))
	_depois_do_lance()


# --------------------------------------------------------------- promocao

## O modal de promocao: quatro botoes grandes sobre um veu. Fica escondido e
## so aparece quando um peao da pessoa chega a ultima fileira.
func _montar_promocao() -> void:
	promo_modal = Control.new()
	promo_modal.name = "PromoModal"
	promo_modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	promo_modal.mouse_filter = Control.MOUSE_FILTER_STOP
	promo_modal.visible = false
	var veu := ColorRect.new()
	veu.color = Color(0.0, 0.0, 0.0, 0.55)
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	promo_modal.add_child(veu)
	var cartao := UIKit.cartao()
	cartao.set_anchors_preset(Control.PRESET_CENTER)
	cartao.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cartao.grow_vertical = Control.GROW_DIRECTION_BOTH
	var caixa := UIKit.vbox(12)
	caixa.add_child(UIKit.rotulo(tr("XADREZ_PROMOTE_TITLE"), UIKit.FONTE_SECAO, UIKit.OURO))
	var opcoes := [
		[ChessRules.QUEEN, "XADREZ_PROMO_QUEEN"],
		[ChessRules.ROOK, "XADREZ_PROMO_ROOK"],
		[ChessRules.BISHOP, "XADREZ_PROMO_BISHOP"],
		[ChessRules.KNIGHT, "XADREZ_PROMO_KNIGHT"],
	]
	for par in opcoes:
		var botao := UIKit.botao(tr(par[1]), UIKit.FONTE_SECAO)
		botao.custom_minimum_size = Vector2(320.0, UIKit.TOQUE_MIN)
		botao.focus_mode = Control.FOCUS_NONE
		UIKit.conectar_toque(botao, _on_promo_escolhida.bind(int(par[0])))
		caixa.add_child(botao)
	cartao.add_child(caixa)
	promo_modal.add_child(cartao)
	add_child(promo_modal)


func _abrir_promocao() -> void:
	if promo_modal != null:
		promo_modal.show()


func _on_promo_escolhida(peca: int) -> void:
	promo_modal.hide()
	if _promo_pendente.is_empty():
		return
	var from := int(_promo_pendente["from"])
	var to := int(_promo_pendente["to"])
	_promo_pendente = {}
	play_click()
	var m := ChessRules.find_move(estado, from, to, peca)
	if m < 0:
		return
	_confirmar_humano(ChessRules.decode(m, estado["b"]))


# --------------------------------------------------------------- fim

func _motivo(resultado: int) -> String:
	match resultado:
		ChessRules.Result.CHECKMATE:
			return tr("XADREZ_CHECKMATE")
		ChessRules.Result.STALEMATE:
			return tr("XADREZ_STALEMATE")
		ChessRules.Result.DRAW_MATERIAL:
			return tr("XADREZ_DRAW_MATERIAL")
		ChessRules.Result.DRAW_50:
			return tr("XADREZ_DRAW_50")
		ChessRules.Result.DRAW_REPETITION:
			return tr("XADREZ_DRAW_REPETITION")
		_:
			return ""


func _terminar(resultado: int) -> void:
	shell.timer.stop()
	_baixar_pecas()
	var vencedor := 0
	if resultado == ChessRules.Result.CHECKMATE:
		vencedor = -int(estado["turn"])
	var motivo := _motivo(resultado)
	var flags: Array = _fatos.keys()
	if resultado == ChessRules.Result.STALEMATE:
		flags.append("xadrez_afogamento")
	var extra := {
		"mode": _modo(),
		"moves": _lances_locais,
		"time": float(shell.timer.get_time()),
		"flags": flags,
	}
	if not vs_ai and not em_rede:
		# Os dois estao na mesma mesa: o cartao anuncia o lado, nao "voce".
		if vencedor == 0:
			extra["draw"] = true
			finish_game("%s — %s" % [tr("DRAW_TITLE"), motivo], false, extra)
		else:
			var numero := 1 if vencedor == ChessRules.WHITE else 2
			finish_game("%s — %s" % [motivo, tr("PLAYER_WINS") % numero], numero == 1, extra)
		return
	var meu := _meu()
	if vencedor == meu:
		extra["perfect"] = not _perdi_peca
		extra["close_call"] = not _estado_anterior.is_empty() \
			and ChessRules.has_mate_in_one(_estado_anterior, -meu)
		flags.append("xadrez_mate")
		finish_game("%s — %s" % [motivo, tr("RESULT_YOU_WIN")], true, extra)
	elif vencedor == -meu:
		var msg := tr("NET_OPPONENT_WINS") % net_opponent_name() if em_rede else tr("RESULT_AI_WINS")
		finish_game("%s — %s" % [motivo, msg], false, extra)
	else:
		extra["draw"] = true
		finish_game("%s — %s" % [tr("DRAW_TITLE"), motivo], false, extra)
	# `finish_game` move o degrau; o rotulo so pode ser repintado depois.
	_pintar_nivel()
