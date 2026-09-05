class_name RulesPanel
extends CanvasLayer

## O painel de "como se joga", o mesmo nos jogos que têm regras escritas.
##
## Montado pelo `BaseGame`: nenhuma cena precisa carregá-lo nem conhecê-lo.
##
## É um `CanvasLayer`, e não um `Control` filho do jogo, por um motivo concreto:
## `BaseGame._scan_hud()` pula `CanvasLayer`, mas desceria num overlay `Control`
## até o `PanelContainer` ancorado no topo e o leria como faixa de HUD -- com a
## altura inteira do painel. O tabuleiro seria reenquadrado toda vez que a ajuda
## abrisse, e voltaria ao fechar.
##
## Fica na camada 90, abaixo do `RewardToast` (100): o aviso de recompensa tem de
## aparecer por cima de tudo, inclusive das regras.
##
## Cuidado ao mexer: `CanvasLayer` não é `CanvasItem`, então `visible` dele NÃO
## entra em `Control.is_visible_in_tree()`. Quem abre e fecha é o `Control` raiz
## interno -- se fosse o CanvasLayer, o teste de layout mediria um painel fechado
## como se estivesse na tela.

signal closed(era_automatico: bool)

const CAMADA := 90
const VEU_COR := Color(0, 0, 0, 0.62)

var _raiz: Control = null
var _conteudo: VBoxContainer = null
var _titulo: Label = null
var _montado_para: String = ""


func _init() -> void:
	layer = CAMADA


## Desenha as regras de `game_id`. Não faz nada se o jogo não tem entrada em
## `rules.json` -- e é assim que um jogo opta por não ter ajuda.
func build(game_id: String, titulo: String) -> void:
	if _montado_para == game_id:
		return
	_montado_para = game_id
	for c in get_children():
		c.queue_free()
	_raiz = null
	if not RulesCatalog.has(game_id):
		return

	_raiz = Control.new()
	_raiz.name = "Raiz"
	_raiz.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_raiz.visible = false
	add_child(_raiz)

	var veu := ColorRect.new()
	veu.name = "Veu"
	veu.color = VEU_COR
	veu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	veu.gui_input.connect(_on_veu_input)
	_raiz.add_child(veu)

	var painel := UIKit.cartao()
	painel.name = "Painel"
	painel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	painel.offset_left = 20.0
	painel.offset_top = GameTopBar.BANDA + 12.0
	painel.offset_right = -20.0
	painel.offset_bottom = -20.0
	painel.mouse_filter = Control.MOUSE_FILTER_STOP
	_raiz.add_child(painel)

	var caixa := UIKit.vbox(14)
	painel.add_child(caixa)

	_titulo = UIKit.rotulo(titulo, UIKit.FONTE_TITULO, UIKit.OURO)
	_titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caixa.add_child(_titulo)

	# Rolagem porque regra de gamão não cabe numa tela de telefone, e cortar a
	# regra pela metade é pior do que não tê-la.
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	UIKit.rolavel(rolagem)
	caixa.add_child(rolagem)

	_conteudo = UIKit.vbox(12)
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_conteudo)

	_preencher(game_id)

	var fechar := UIKit.botao(tr("RULES_CLOSE"))
	fechar.pressed.connect(close)
	caixa.add_child(fechar)


func _preencher(game_id: String) -> void:
	var objetivo := RulesCatalog.goal_of(game_id)
	if objetivo != "":
		_conteudo.add_child(_cabecalho(tr("RULES_GOAL")))
		_conteudo.add_child(_paragrafo(tr(objetivo), UIKit.TEXTO))

	for secao in RulesCatalog.sections_of(game_id):
		var titulo := str(secao.get("title", ""))
		if titulo != "":
			_conteudo.add_child(_cabecalho(tr(titulo)))
		for item in secao.get("items", []):
			_conteudo.add_child(_item(tr(str(item))))

	var dica := RulesCatalog.tip_of(game_id)
	if dica != "":
		var cartao := UIKit.cartao(false)
		var vb := UIKit.vbox(6)
		cartao.add_child(vb)
		vb.add_child(_cabecalho(tr("RULES_TIP"), UIKit.VERDE))
		vb.add_child(_paragrafo(tr(dica), UIKit.TEXTO))
		_conteudo.add_child(cartao)


func _cabecalho(texto: String, cor: Color = UIKit.OURO_FRACO) -> Label:
	var l := UIKit.rotulo(texto.to_upper(), UIKit.FONTE_SECAO, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _paragrafo(texto: String, cor: Color) -> Label:
	var l := UIKit.paragrafo(texto, UIKit.FONTE_CORPO, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Um item de lista. O marcador entra na própria linha, com recuo, porque um
## `HBoxContainer` por item faria o texto medir errado ao quebrar.
func _item(texto: String) -> Label:
	var l := _paragrafo("•   " + texto, UIKit.TEXTO_FRACO)
	l.add_theme_constant_override("line_spacing", 4)
	return l


## Verdadeiro se este jogo chegou a montar painel.
func has_content() -> bool:
	return _raiz != null


func is_open() -> bool:
	return _raiz != null and _raiz.visible


func open() -> void:
	if _raiz == null:
		return
	_raiz.visible = true
	_raiz.modulate.a = 0.0
	create_tween().tween_property(_raiz, "modulate:a", 1.0, 0.18)


func close() -> void:
	if _raiz == null or not _raiz.visible:
		return
	_raiz.visible = false
	closed.emit(_automatico)
	_automatico = false


## Marca a abertura da primeira partida, a única que grava a bandeira e paga XP.
var _automatico: bool = false

func open_automatic() -> void:
	_automatico = true
	open()


func _on_veu_input(event: InputEvent) -> void:
	var fecha := false
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		fecha = mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT
	elif event is InputEventScreenTouch:
		fecha = (event as InputEventScreenTouch).pressed
	if fecha:
		close()
