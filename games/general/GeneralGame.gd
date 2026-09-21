extends BaseGame

## General: cinco dados, tres rolagens por rodada, dez categorias.
##
## A mesa e uma bandeja de dados (`DiceTray3D`) dentro de um copo serigrafado
## no feltro; o toque entra pelo `DragPicker3D` com os proprios dados como
## alvo -- tocar (ou puxar) um dado o segura. A folha de pontos e HUD 2D
## montada aqui: dez botoes numa grade no rodape, cada um com o nome da
## categoria e o que os dados atuais dariam nela; tocar grava e passa a vez.
##
## Toda jogada -- da pessoa, da maquina e do outro aparelho -- passa por
## `_aplicar(cadeira, acao)`. Os valores dos dados viajam DENTRO da acao de
## rolar: os dois aparelhos nao consomem o gerador na mesma ordem, entao a
## semente compartilhada do `MatchSync` sozinha nao bastaria.
##
## Nada aqui usa `await`: os passos da maquina e o aviso adiado sao timers
## ligados por sinal, que morrem sozinhos quando a cena e liberada.

const DICE_SIZE := 0.6
const DICE_SPACING := 0.85
## Quanto o copo sobra em volta dos dados, em unidades de mundo.
const COPO_FOLGA := Vector2(0.5, 0.9)
## Faixa alem da borda de longe do copo onde o rotulo de quem joga se deita.
const ROTULO_FOLGA := 0.32
## O feltro de carteado limita a camera a 56 graus para a carta nao achatar;
## dado le melhor de cima, entao este enquadramento pode deitar mais.
const TILT_MAXIMO := 68.0
## Respiro entre uma marcacao e o aviso de quem joga em seguida.
const PAUSA_ANUNCIO := 1.4
## Ritmo da maquina: segura, mostra, rola.
const PAUSA_IA := 0.7

@onready var shell: GameShell = $GameShell
@onready var pieces_root: Node3D = $PiecesRoot
@onready var ui: Control = $UI

var tray: DiceTray3D = null
var copo: TableZone3D = null
var picker: DragPicker3D = null
var mode_switch: ModoGeneral = null

var table: SeatTable = null
var sync: MatchSync = null

var modo: int = ModoGeneral.Modo.IA
var vs_ai: bool = true
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

## Uma folha (Dictionary categoria -> pontos) por cadeira.
var folhas: Array = []
var vez: int = 0
var rolagem: int = 0
var dados: Array = [1, 2, 3, 4, 5]
## Por cadeira: fez alguma combinacao "de mao" nesta partida.
var de_mao_feito: Array = []
## O `extra` da ultima partida encerrada, para a suite conferir as bandeiras.
var ultimo_resultado: Dictionary = {}

var _rolando: bool = false
## Sobe a cada partida nova; os passos agendados da maquina e o aviso adiado
## conferem antes de agir, e um recomeco no meio da vez nao deixa fantasma.
var _serial: int = 0

# --- HUD
var rodape: VBoxContainer = null
var celulas: Dictionary = {}     # categoria -> {"btn", "nome", "valor"}
var btn_rolar: Button = null
var _espaco_modo: Control = null
var _st_livre: StyleBoxFlat
var _st_livre_apagada: StyleBoxFlat
var _st_usada: StyleBoxFlat
var _st_toque: StyleBoxFlat


## Tres modos, nao dois: o General tem partida solo (bater a meta do degrau)
## alem de contra a maquina e dois no aparelho.
class ModoGeneral extends Button:
	enum Modo { SOLO, IA, VERSUS }

	signal trocou_modo(modo: int)

	const LARGURA := 230.0
	const MARGEM := 24.0
	const RODAPE := 20.0

	var modo: int = Modo.IA
	var vs_ai: bool = true

	## Posicao dinamica abaixo da barra de jogo, que inclui o safe area do iOS.
	## TOPO_BASE=8, ALTURA=88 (UIKit.TOQUE_MIN), mais o inset do notch e folga.
	static func _topo_botao() -> float:
		var vp := Engine.get_main_loop().root if Engine.get_main_loop() is SceneTree else null
		var inset := JogosSafeArea.top(vp) if vp != null else 0.0
		# GameTopBar.TOPO_BASE=8, GameTopBar.ALTURA=UIKit.TOQUE_MIN=88
		return 8.0 + 88.0 + inset + 8.0

	func _init() -> void:
		anchors_preset = Control.PRESET_TOP_RIGHT
		anchor_left = 1.0
		anchor_right = 1.0
		var topo := _topo_botao()
		offset_left = -LARGURA - 24.0
		offset_top = topo
		offset_right = -24.0
		offset_bottom = topo + 56.0
		pressed.connect(_on_pressed)
		_pintar()

	func _on_pressed() -> void:
		if AudioManager:
			AudioManager.play_click()
		definir_modo((modo + 1) % 3)

	## Troca sem passar pelo toque -- para a suite e para quem forca um modo.
	func definir_modo(novo: int) -> void:
		modo = novo
		vs_ai = modo != Modo.VERSUS
		_pintar()
		trocou_modo.emit(modo)

	func _pintar() -> void:
		var chave := "MODE_VS_AI"
		if modo == Modo.SOLO:
			chave = "GENERAL_MODE_SOLO"
		elif modo == Modo.VERSUS:
			chave = "MODE_TWO_PLAYERS"
		text = tr("MODE_LABEL") % tr(chave)


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(restart_game)
	env_3d.apply_theme(GameTheme3D.casino_green())
	_montar_mesa()
	_montar_picker()
	_montar_folha()
	# Antes do fit_table: e HUD ancorada e entra na medicao da faixa de baixo.
	mode_switch = ModoGeneral.new()
	mode_switch.name = "ModeSwitch"
	add_child(mode_switch)
	mode_switch.trocou_modo.connect(_on_modo_trocado)
	# O conteudo e o copo mais a faixa do rotulo na borda de longe; o centro
	# desloca meia faixa para o rotulo nao ficar fora do quadro.
	var copo_size := _tamanho_do_copo()
	fit_table(Vector2(copo_size.x, copo_size.y + ROTULO_FOLGA),
		Vector3(0.0, 0.0, -ROTULO_FOLGA * 0.5), TILT_MAXIMO)
	_start_new_game()
	begin_match(_modo_nome())


# ------------------------------------------------------------------ montagem

func _tamanho_do_copo() -> Vector2:
	return tray.content_size() + COPO_FOLGA


func _montar_mesa() -> void:
	tray = DiceTray3D.new()
	tray.name = "DiceTray3D"
	pieces_root.add_child(tray)
	tray.setup(GeneralRules.DADOS, DICE_SPACING, DICE_SIZE)
	tray.rolled.connect(_on_rolou)
	# O copo: a area do feltro onde os dados vivem, com o nome de quem joga
	# deitado na borda de longe. Nasce com rotulo para o Label3D existir.
	copo = TableZone3D.create(_tamanho_do_copo(), Vector3.ZERO, tr("GAME_GENERAL"),
		env_3d.theme.accent, true)
	copo.name = "Copo"
	pieces_root.add_child(copo)


func _montar_picker() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, DICE_SIZE * 0.5)
	picker.target_tapped.connect(_on_dado_tocado)
	picker.drag_started.connect(_on_dado_puxado)
	_atualizar_alvos()


## Os alvos do toque sao os proprios dados, onde a bandeja os poe.
func _atualizar_alvos() -> void:
	var alvos: Dictionary = {}
	var posicoes := tray.positions()
	for i in posicoes.size():
		alvos[i] = posicoes[i]
	picker.set_targets(alvos)


func _estilo(fundo: Color, borda: Color) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = fundo
	st.border_color = borda
	st.set_border_width_all(1)
	st.set_corner_radius_all(14)
	st.content_margin_left = 16
	st.content_margin_right = 16
	return st


## A folha de pontos e o botao de rolar, ancorados no rodape para a faixa de
## HUD ser medida e a mesa se enquadrar no que sobra.
func _montar_folha() -> void:
	_st_livre = _estilo(UIKit.FUNDO_CARTAO, UIKit.OURO_FRACO)
	_st_toque = _estilo(Color(0.18, 0.19, 0.24, 0.95), UIKit.OURO)
	_st_livre_apagada = _estilo(Color(0.09, 0.10, 0.14, 0.62), Color(0.30, 0.28, 0.22, 0.6))
	_st_usada = _estilo(Color(0.04, 0.05, 0.07, 0.5), Color(0.22, 0.22, 0.22, 0.4))

	rodape = UIKit.vbox(8)
	rodape.name = "Rodape"
	rodape.anchor_left = 0.0
	rodape.anchor_right = 1.0
	rodape.anchor_top = 1.0
	rodape.anchor_bottom = 1.0
	rodape.grow_vertical = Control.GROW_DIRECTION_BEGIN
	rodape.offset_left = ModoGeneral.MARGEM
	rodape.offset_right = -ModoGeneral.MARGEM
	rodape.offset_top = -ModoGeneral.RODAPE
	rodape.offset_bottom = -ModoGeneral.RODAPE
	ui.add_child(rodape)

	var grade := GridContainer.new()
	grade.name = "Tabela"
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 8)
	grade.add_theme_constant_override("v_separation", 6)
	grade.mouse_filter = Control.MOUSE_FILTER_PASS
	rodape.add_child(grade)
	for cat in GeneralRules.CATEGORIAS:
		grade.add_child(_celula(cat))

	# A linha de baixo divide o espaco com o ModeSwitch, que mora no canto
	# esquerdo do rodape: o espacador reserva exatamente o lugar dele.
	var linha := UIKit.hbox(12)
	linha.name = "LinhaRolar"
	rodape.add_child(linha)
	_espaco_modo = Control.new()
	_espaco_modo.name = "EspacoModo"
	_espaco_modo.custom_minimum_size = Vector2(ModoGeneral.LARGURA, UIKit.TOQUE_MIN)
	_espaco_modo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(_espaco_modo)
	btn_rolar = UIKit.botao("", UIKit.FONTE_SECAO)
	btn_rolar.name = "BtnRolar"
	btn_rolar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn_rolar.focus_mode = Control.FOCUS_NONE
	UIKit.conectar_toque(btn_rolar, _on_rolar)
	linha.add_child(btn_rolar)


## Uma celula da folha: o nome a esquerda, o valor a direita, o botao inteiro
## e o alvo do toque.
func _celula(cat: String) -> Button:
	var btn := Button.new()
	btn.name = "Cat_" + cat
	btn.custom_minimum_size = Vector2(0, UIKit.TOQUE_MIN)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _st_livre)
	btn.add_theme_stylebox_override("hover", _st_livre)
	btn.add_theme_stylebox_override("pressed", _st_toque)
	btn.add_theme_stylebox_override("focus", _st_livre)
	btn.add_theme_stylebox_override("disabled", _st_livre_apagada)
	btn.pressed.connect(_on_categoria.bind(cat))

	var linha := UIKit.hbox(8)
	linha.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	linha.offset_left = 16
	linha.offset_right = -16
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(linha)

	var nome := UIKit.rotulo(_nome_categoria(cat), UIKit.FONTE_CORPO)
	nome.mouse_filter = Control.MOUSE_FILTER_IGNORE
	nome.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIKit.expandir(nome)
	linha.add_child(nome)

	var valor := UIKit.rotulo("", UIKit.FONTE_SECAO, UIKit.TEXTO_FRACO)
	valor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	valor.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	valor.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	valor.custom_minimum_size = Vector2(64, 0)
	linha.add_child(valor)

	celulas[cat] = {"btn": btn, "nome": nome, "valor": valor}
	return btn


func _nome_categoria(cat: String) -> String:
	return tr("GENERAL_CAT_" + cat.to_upper())


# ------------------------------------------------------------------- partida

func _start_new_game() -> void:
	_serial += 1
	game_over = false
	_rolando = false
	ultimo_resultado = {}
	ai_level = DifficultyManager.get_level(game_id)

	var cadeiras := 1 if (modo == ModoGeneral.Modo.SOLO and not net_active()) else 2
	table = SeatTable.for_game(self, cadeiras, vs_ai)
	if sync != null:
		sync.stop()
	sync = MatchSync.new(self, table)
	sync.start()
	mode_switch.visible = not table.online()
	_espaco_modo.visible = mode_switch.visible

	folhas = []
	de_mao_feito = []
	for i in cadeiras:
		folhas.append(GeneralRules.nova_folha())
		de_mao_feito.append(false)
	vez = 0
	rolagem = 0
	dados = [1, 2, 3, 4, 5]
	tray.release_all()
	tray.set_values_immediate(dados)
	picker.cancel_drag()
	btn_restart.hide()
	shell.timer.reset()
	shell.timer.start()
	_pintar_nivel()
	_pintar_placar()

	if sync.waiting_for_deal():
		set_status(tr("NET_WAITING_DEAL"))
		copo.set_caption(net_opponent_name())
		_pintar_folha()
		_pintar_botao()
		_pintar_dica_dados()
		return
	_comecar_vez()


func _comecar_vez() -> void:
	rolagem = 0
	tray.release_all()
	copo.set_caption(_nome_da_cadeira(vez))
	set_status(_status_da_vez())
	_pintar_placar()
	_pintar_folha()
	_pintar_botao()
	_pintar_dica_dados()
	# Com a bandeja ainda girando, quem agenda a maquina e o fim do giro.
	if table.ai_runs_here(vez) and not _rolando:
		_agendar(PAUSA_IA, _ia_passo.bind(_serial))


## A unica porta de entrada de jogada: pessoa, maquina e rede. Valida com as
## regras e devolve falso para o que nao vale -- jogada remota ilegal morre
## aqui sem mexer na mesa.
func _aplicar(cadeira: int, acao: Dictionary) -> bool:
	if game_over or cadeira != vez or table == null:
		return false
	match str(acao.get("t", "")):
		"roll":
			return _aplicar_rolagem(acao)
		"score":
			return _aplicar_marcacao(str(acao.get("cat", "")))
	return false


func _aplicar_rolagem(acao: Dictionary) -> bool:
	if not GeneralRules.rolagem_valida(acao, rolagem):
		return false
	var valores: Array = acao["values"]
	var presos: Array = acao.get("held", [])
	for i in GeneralRules.DADOS:
		# Na primeira rolagem nao ha o que segurar: tudo rola.
		var preso := rolagem > 0 and i < presos.size() and bool(presos[i])
		tray.set_held(i, preso)
		if not preso:
			dados[i] = int(valores[i])
	rolagem += 1
	if _vez_da_pessoa():
		set_status(tr("GENERAL_ROLLING"))
	tray.light([])
	# Antes do `roll`: com todos presos a bandeja emite `rolled` na hora.
	_rolando = true
	_pintar_folha()
	_pintar_botao()
	tray.roll(valores)
	return true


func _aplicar_marcacao(cat: String) -> bool:
	if rolagem < 1 or not GeneralRules.pode_marcar(folhas[vez], cat):
		return false
	var folha: Dictionary = folhas[vez]
	var tinha_bonus := GeneralRules.bonus(folha) > 0
	var de_mao := rolagem == 1
	var pontos := GeneralRules.marcar(folha, cat, dados, de_mao)
	if de_mao and GeneralRules.bonus_de_mao(cat, dados):
		de_mao_feito[vez] = true
	if AudioManager:
		AudioManager.play_piece_place()
	var aviso := tr("GENERAL_SCORED") % [_nome_da_cadeira(vez), pontos, _nome_categoria(cat)]
	if not tinha_bonus and GeneralRules.bonus(folha) > 0:
		aviso += "  " + tr("GENERAL_BONUS_HIT")
	_pintar_placar()
	if _todas_completas():
		_pintar_folha()
		_pintar_botao()
		_encerrar()
		return true
	vez = table.next(vez)
	_comecar_vez()
	_anunciar(aviso)
	return true


func _todas_completas() -> bool:
	for f in folhas:
		if not GeneralRules.completa(f):
			return false
	return true


## Chegou o fim do giro. A bandeja exibe o estado da partida, sempre: cobre a
## rolagem que chegou por cima de outra ainda girando e o recomeco no meio.
func _on_rolou(_valores: Array) -> void:
	tray.set_values_immediate(dados)
	if not _rolando:
		return
	_rolando = false
	_apos_rolar()


func _apos_rolar() -> void:
	_pintar_folha()
	_pintar_botao()
	_pintar_dica_dados()
	if game_over:
		return
	if _vez_da_pessoa():
		if rolagem >= GeneralRules.MAX_ROLAGENS:
			set_status(tr("GENERAL_PICK_CAT"))
		elif rolagem == 1 and _tem_combinacao_de_mao():
			set_status(tr("GENERAL_DE_MAO_HINT"))
		else:
			set_status(tr("GENERAL_HOLD_HINT"))
	elif table.ai_runs_here(vez):
		_agendar(PAUSA_IA, _ia_passo.bind(_serial))


func _tem_combinacao_de_mao() -> bool:
	for cat in GeneralRules.COMBINACOES:
		if GeneralRules.esta_livre(folhas[vez], cat) and GeneralRules.bonus_de_mao(cat, dados):
			return true
	return false


func _encerrar() -> void:
	shell.timer.stop()
	var totais: Array = []
	for f in folhas:
		totais.append(GeneralRules.total(f))
	var local := maxi(table.local_index(), 0)
	var minha: Dictionary = folhas[local]
	var meu_total := int(totais[local])

	var flags: Array[String] = []
	if bool(de_mao_feito[local]):
		flags.append("general_de_mao")
	if GeneralRules.tem_general(minha):
		flags.append("general_general")
	if meu_total >= 200:
		flags.append("general_200")
	if GeneralRules.riscadas(minha) == 0:
		flags.append("general_sem_riscar")
	var extra := {
		"score": meu_total,
		"mode": _modo_nome(),
		"time": shell.timer.get_time(),
		"perfect": GeneralRules.tem_general(minha),
		"flags": flags,
	}

	if table.count == 1:
		# Solo: vence quem bate a meta do degrau ou o proprio recorde. O
		# recorde e lido ANTES de publicar, porque a gamificacao o atualiza.
		var meta := GeneralRules.meta_solo(ai_level)
		var recorde := int(PlayerProfile.game_stats(game_id).get("best_score", 0)) if PlayerProfile else 0
		var bateu_meta := meu_total >= meta
		var bateu_recorde := recorde > 0 and meu_total > recorde
		var msg := tr("GENERAL_SOLO_LOSE") % [meu_total, meta]
		if bateu_meta:
			msg = tr("GENERAL_SOLO_WIN") % meu_total
		elif bateu_recorde:
			msg = tr("GENERAL_SOLO_RECORD") % meu_total
		ultimo_resultado = extra
		finish_game(msg, bateu_meta or bateu_recorde, extra)
		return

	var vencedor := GeneralRules.vencedor(totais)
	if vencedor == -1:
		extra["draw"] = true
		ultimo_resultado = extra
		finish_game(tr("DRAW_TITLE"), false, extra)
		return
	var venci := vencedor == local
	var msg := tr("RESULT_YOU_WIN")
	if table.online():
		if not venci:
			msg = tr("NET_OPPONENT_WINS") % net_opponent_name()
	elif table.pass_and_play():
		msg = tr("PLAYER_WINS") % (vencedor + 1)
	elif not venci:
		msg = tr("RESULT_AI_WINS")
	ultimo_resultado = extra
	finish_game(msg, venci, extra)


# -------------------------------------------------------------------- pessoa

func _vez_da_pessoa() -> bool:
	return table != null and table.acts_here(vez) and not table.is_ai(vez)


## A mesa aceita toque da pessoa daqui agora?
func _aberta() -> bool:
	return not game_over and not _rolando and sync != null \
		and not sync.waiting_for_deal() and _vez_da_pessoa()


func _pode_rolar_agora() -> bool:
	return _aberta() and rolagem < GeneralRules.MAX_ROLAGENS


func _pode_marcar_agora() -> bool:
	return _aberta() and rolagem >= 1


func _pode_segurar_agora() -> bool:
	return _aberta() and rolagem >= 1 and rolagem < GeneralRules.MAX_ROLAGENS


func _jogar(cadeira: int, acao: Dictionary) -> void:
	if _aplicar(cadeira, acao):
		sync.send(cadeira, acao)


func _on_rolar() -> void:
	if not _pode_rolar_agora():
		return
	play_click()
	var presos: Array = []
	for h in tray.held:
		presos.append(bool(h))
	_jogar(vez, {
		"t": "roll",
		"values": DiceTray3D.random_values(GeneralRules.DADOS, sync.rng),
		"held": presos,
	})


func _on_dado_tocado(id: Variant) -> void:
	if not (id is int) or not _pode_segurar_agora():
		return
	play_click()
	tray.toggle_held(int(id))
	_pintar_dica_dados()


## Puxar um dado para o lado e o mesmo gesto de segurar: nao ha para onde
## leva-lo, entao o arrasto vira o toque.
func _on_dado_puxado(id: Variant) -> void:
	picker.cancel_drag()
	_on_dado_tocado(id)


func _on_categoria(cat: String) -> void:
	if not _pode_marcar_agora() or not GeneralRules.pode_marcar(folhas[vez], cat):
		return
	play_click()
	_jogar(vez, {"t": "score", "cat": cat})


func _on_modo_trocado(novo_modo: int) -> void:
	modo = novo_modo
	vs_ai = modo != ModoGeneral.Modo.VERSUS
	restart_game()


# ------------------------------------------------------------------- maquina

func _agendar(atraso: float, passo: Callable) -> void:
	var arvore := get_tree()
	if arvore == null:
		return
	arvore.create_timer(atraso).timeout.connect(passo, CONNECT_ONE_SHOT)


func _ia_passo(serial: int) -> void:
	if serial != _serial or game_over or _rolando or not is_inside_tree():
		return
	if table == null or not table.ai_runs_here(vez):
		return
	var folha: Dictionary = folhas[vez]
	if rolagem > 0 and GeneralAI.should_stop(dados, folha, rolagem, ai_level, sync.rng):
		var cat := GeneralAI.choose_category(dados, folha, rolagem == 1, ai_level, sync.rng)
		_jogar(vez, {"t": "score", "cat": cat})
		return
	var presos: Array = []
	presos.resize(GeneralRules.DADOS)
	presos.fill(false)
	if rolagem > 0:
		var escolha := GeneralAI.choose_holds(dados, folha, ai_level, sync.rng)
		for i in escolha.size():
			presos[i] = bool(escolha[i])
	# Mostra o que ela segura por um instante antes de rolar: e assim que se
	# entende a jogada da maquina.
	var mudou := false
	for i in GeneralRules.DADOS:
		if bool(presos[i]) != bool(tray.held[i]):
			mudou = true
		tray.set_held(i, bool(presos[i]))
	_agendar(PAUSA_IA if mudou else 0.05, _ia_rolar.bind(serial, presos))


func _ia_rolar(serial: int, presos: Array) -> void:
	if serial != _serial or game_over or _rolando or not is_inside_tree():
		return
	if not table.ai_runs_here(vez):
		return
	_jogar(vez, {
		"t": "roll",
		"values": DiceTray3D.random_values(GeneralRules.DADOS, sync.rng),
		"held": presos,
	})


# ---------------------------------------------------------------------- rede

func _on_net_move(payload: Dictionary) -> void:
	if sync == null or table == null or not table.online():
		return
	var msg := sync.accept(payload)
	match str(msg.get("t", "")):
		"deal":
			if not game_over:
				_comecar_vez()
		"act":
			_aplicar(int(msg["seat"]), msg["a"])


# ----------------------------------------------------------------------- HUD

func _modo_nome() -> String:
	if net_active():
		return "online"
	match modo:
		ModoGeneral.Modo.SOLO:
			return "solo"
		ModoGeneral.Modo.VERSUS:
			return "versus"
	return "ai"


func _nome_da_cadeira(i: int) -> String:
	if table.pass_and_play():
		return tr("SEAT_PLAYER_N") % (i + 1)
	return table.display_name(i, self)


func _status_da_vez() -> String:
	if table.is_ai(vez):
		return tr("AI_TURN_SHORT")
	if table.is_remote(vez):
		return tr("NET_THEIR_TURN") % net_opponent_name()
	if table.online():
		return tr("NET_YOUR_TURN")
	if table.pass_and_play():
		return tr("TURN_PLAYER") % (vez + 1)
	return tr("GENERAL_YOUR_TURN")


## Mostra o aviso e, passado o respiro, volta ao status de quem joga -- se
## ninguem mexeu na mesa nesse meio tempo.
func _anunciar(texto: String) -> void:
	set_status(texto)
	_agendar(PAUSA_ANUNCIO, _status_da_vez_adiado.bind(_serial, vez, rolagem))


func _status_da_vez_adiado(serial: int, cadeira: int, rol: int) -> void:
	if serial != _serial or game_over or not is_inside_tree():
		return
	if cadeira != vez or rol != rolagem or _rolando:
		return
	set_status(_status_da_vez())


func _pintar_nivel() -> void:
	if table.online():
		shell.set_level(tr("NET_MODE_LABEL") % net_opponent_name())
	elif table.count == 1:
		shell.set_level(tr("GENERAL_META") % GeneralRules.meta_solo(ai_level)
			+ "  •  " + DifficultyManager.label_for(game_id))
	elif table.pass_and_play():
		shell.set_level(tr("MODE_LABEL") % tr("MODE_TWO_PLAYERS"))
	else:
		shell.set_level(DifficultyManager.label_for(game_id))


func _pintar_placar() -> void:
	if table == null or folhas.is_empty():
		return
	if table.count == 1:
		set_counters([
			{"value": GeneralRules.total(folhas[0]), "label": "SCORE_POINTS"},
			{"value": GeneralRules.meta_solo(ai_level), "label": "GENERAL_META_SHORT"},
		])
		return
	var local := maxi(table.local_index(), 0)
	var outro := 1 - local
	var meu := GeneralRules.total(folhas[local])
	var dele := GeneralRules.total(folhas[outro])
	if table.online():
		set_duel_score(meu, dele, "NET_YOU", "NET_OPPONENT")
	elif table.pass_and_play():
		set_duel_score(GeneralRules.total(folhas[0]), GeneralRules.total(folhas[1]),
			"SCORE_PLAYER_1", "SCORE_PLAYER_2")
	else:
		set_duel_score(meu, dele)
	set_active_side(vez == (0 if table.pass_and_play() else local))


## A folha de quem esta jogando: gravado em ouro, riscado apagado, e o que os
## dados de agora dariam em cinza. So a pessoa daqui, com dados rolados, toca.
func _pintar_folha() -> void:
	var folha: Dictionary = folhas[vez] if vez < folhas.size() else {}
	var pode := _pode_marcar_agora()
	for cat in GeneralRules.CATEGORIAS:
		var c: Dictionary = celulas[cat]
		var btn: Button = c["btn"]
		var nome: Label = c["nome"]
		var valor: Label = c["valor"]
		var usada := folha.has(cat)
		btn.disabled = usada or not pode
		btn.add_theme_stylebox_override("disabled", _st_usada if usada else _st_livre_apagada)
		nome.add_theme_color_override("font_color", UIKit.TEXTO_FRACO if usada else UIKit.TEXTO)
		if usada:
			var p := int(folha[cat])
			valor.text = str(p)
			valor.add_theme_color_override("font_color", UIKit.OURO if p > 0 else UIKit.TEXTO_FRACO)
		elif rolagem >= 1:
			valor.text = str(GeneralRules.score_for(cat, dados, rolagem == 1))
			valor.add_theme_color_override("font_color", UIKit.TEXTO_FRACO)
		else:
			valor.text = ""


func _pintar_botao() -> void:
	btn_rolar.text = tr("GENERAL_BTN_ROLL") % mini(rolagem + 1, GeneralRules.MAX_ROLAGENS)
	btn_rolar.disabled = not _pode_rolar_agora()


## Anel verde nos dados que dao para tocar; o dourado do preso e da bandeja.
func _pintar_dica_dados() -> void:
	tray.light(range(GeneralRules.DADOS) if _pode_segurar_agora() else [])
