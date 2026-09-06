class_name ResultPanel
extends CanvasLayer

## O cartao de fim de partida: o que aconteceu e o que fazer em seguida.
##
## Ate aqui a partida terminava num rotulo de status e num botao de reiniciar
## que nem toda cena mostrava. Na Torre de Hanoi a pessoa vencia e a tela nao
## dizia mais nada -- "depois que ganhei nao deu pra fazer mais nada". E a
## escada de dificuldade andava a cada partida sem ninguem ver.
##
## Este cartao e comum aos jogos: `BaseGame.finish_game()` o apresenta com o
## resultado, o degrau em que a partida foi jogada e para onde a escada foi, e
## oferece o proximo passo -- **Proximo nivel** quando a escada subiu, jogar de
## novo caso contrario, e o menu. Tocar fora do cartao o esconde para a pessoa
## olhar a mesa; o botao de reiniciar de cada cena continua la.

signal primary_pressed
signal menu_pressed
signal dismissed

## Quanto a comemoracao da mesa fica sozinha antes de o cartao entrar.
const ATRASO := 0.9
const FADE := 0.25
const LARGURA := 600.0

var _veu: Control = null
var _card: PanelContainer = null
var _titulo: Label = null
var _mensagem: Label = null
var _degrau: Label = null
var _btn_primario: Button = null
var _btn_menu: Button = null

var _pendente: int = 0
var _mostrando: bool = false
var _primario_e_proximo: bool = false


func _ready() -> void:
	layer = 90
	_montar()
	_esconder_agora()


func _montar() -> void:
	_veu = Control.new()
	_veu.name = "Veu"
	_veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veu.mouse_filter = Control.MOUSE_FILTER_STOP
	_veu.gui_input.connect(_on_veu_input)
	add_child(_veu)

	_card = PanelContainer.new()
	_card.name = "Cartao"
	_card.custom_minimum_size = Vector2(LARGURA, 0)
	_card.anchor_left = 0.5
	_card.anchor_right = 0.5
	_card.anchor_top = 0.5
	_card.anchor_bottom = 0.5
	_card.offset_left = -LARGURA * 0.5
	_card.offset_right = LARGURA * 0.5
	_card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_card.grow_vertical = Control.GROW_DIRECTION_BOTH
	# O cartao engole o toque para o veu nao o ler como "tocou fora".
	_card.mouse_filter = Control.MOUSE_FILTER_STOP

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.12, 0.96)
	style.border_color = Color(0.98, 0.82, 0.34, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(22)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	style.shadow_color = Color(0, 0, 0, 0.5)
	style.shadow_size = 16
	_card.add_theme_stylebox_override("panel", style)
	_veu.add_child(_card)

	var col := UIKit.vbox(12)
	_card.add_child(col)

	_titulo = UIKit.rotulo("", UIKit.FONTE_TITULO, UIKit.OURO)
	_titulo.name = "Titulo"
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_titulo)

	_mensagem = UIKit.paragrafo("", UIKit.FONTE_CORPO, UIKit.TEXTO)
	_mensagem.name = "Mensagem"
	_mensagem.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_mensagem)

	_degrau = UIKit.paragrafo("", UIKit.FONTE_MIUDA, UIKit.OURO_FRACO)
	_degrau.name = "Degrau"
	_degrau.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(_degrau)

	var fila := UIKit.hbox(12)
	col.add_child(fila)

	_btn_menu = UIKit.botao(tr("BTN_MENU"), UIKit.FONTE_CORPO)
	_btn_menu.name = "BtnMenu"
	_btn_menu.custom_minimum_size = Vector2(150, UIKit.TOQUE_MIN)
	_btn_menu.pressed.connect(func() -> void: menu_pressed.emit())
	fila.add_child(_btn_menu)

	_btn_primario = UIKit.botao("", UIKit.FONTE_SECAO)
	_btn_primario.name = "BtnPrimario"
	_btn_primario.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_btn_primario.pressed.connect(func() -> void: primary_pressed.emit())
	fila.add_child(_btn_primario)


## Anuncia o fim da partida e, passado `ATRASO`, mostra o cartao.
##
## `level` e o degrau em que a escada ficou e `delta` quanto ela andou (+1, -1
## ou 0). Chamadas repetidas cancelam a anterior: so o ultimo resultado vale.
func present(won: bool, draw: bool, level: int, delta: int, message: String = "") -> void:
	_preencher(won, draw, level, delta, message)
	_pendente += 1
	var minha := _pendente
	if ATRASO > 0.0 and is_inside_tree():
		await get_tree().create_timer(ATRASO).timeout
	if minha != _pendente or not is_inside_tree():
		return
	_revelar()


## O mesmo que `present`, sem espera. Para a suite e para quem ja esperou.
func present_now(won: bool, draw: bool, level: int, delta: int, message: String = "") -> void:
	_pendente += 1
	_preencher(won, draw, level, delta, message)
	_revelar()


func _preencher(won: bool, draw: bool, level: int, delta: int, message: String) -> void:
	if draw:
		_titulo.text = tr("DRAW_TITLE")
	elif won:
		_titulo.text = tr("WIN_TITLE")
	else:
		_titulo.text = tr("RESULT_END_TITLE")

	_mensagem.text = message
	_mensagem.visible = message != ""

	_primario_e_proximo = won and delta > 0
	_btn_primario.text = tr("BTN_NEXT_LEVEL") if _primario_e_proximo else tr("BTN_RESTART")

	if DifficultyManager != null:
		var aviso: String = DifficultyManager.change_notice(level, delta)
		if aviso == "":
			aviso = tr("DIFF_LABEL") % [level, DifficultyManager.MAX_LEVEL, tr(DifficultyManager.tier_name(level))]
		_degrau.text = aviso
		_degrau.visible = true
	else:
		_degrau.visible = false


func _revelar() -> void:
	_mostrando = true
	visible = true
	_veu.visible = true
	_card.modulate.a = 0.0
	_card.scale = Vector2.ONE
	var tw := create_tween()
	tw.tween_property(_card, "modulate:a", 1.0, FADE)


## Esconde o cartao. O botao de reiniciar da cena continua valendo.
func dismiss() -> void:
	if not _mostrando and _pendente == 0:
		return
	_pendente += 1
	_esconder_agora()
	dismissed.emit()


func _esconder_agora() -> void:
	_mostrando = false
	visible = false
	if _veu:
		_veu.visible = false


func _on_veu_input(evento: InputEvent) -> void:
	var toque := evento is InputEventScreenTouch and (evento as InputEventScreenTouch).pressed
	var clique := evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed
	if toque or clique:
		_veu.accept_event()
		dismiss()


# -------------------------------------------------------------- para a suite

func is_showing() -> bool:
	return _mostrando


## Verdadeiro quando o botao principal leva ao proximo degrau.
func offers_next_level() -> bool:
	return _primario_e_proximo


func primary_text() -> String:
	return _btn_primario.text if _btn_primario else ""


func title_text() -> String:
	return _titulo.text if _titulo else ""


func difficulty_text() -> String:
	return _degrau.text if _degrau else ""
