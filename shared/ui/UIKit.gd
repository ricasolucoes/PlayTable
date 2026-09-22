class_name UIKit
extends RefCounted

const TAP_BUTTON := preload("res://addons/jogos_core/input/jogos_tap_button.gd")

## Peças de interface repetidas nas telas de progresso.
##
## Nasceu junto com a tela de perfil, que é feita de cinquenta variações de
## "cartão com título, subtítulo e barra de progresso". Sem isto o arquivo da
## tela seria três quartos de `StyleBoxFlat.new()`.
##
## Os tamanhos de fonte respeitam o piso de 14 sp que a régua de layout mede
## (`tests/gdscript/integration/test_layout_mobile.gd`): no viewport de 720 px
## de largura do projeto, 14 sp valem ~26 px. Texto menor que `FONTE_MIUDA`
## não passa.

const FONTE_TITULO := 40
const FONTE_SECAO := 32
const FONTE_CORPO := 27
const FONTE_MIUDA := 26

## Altura mínima de alvo de toque: 48 dp em 720 px de viewport ≈ 88 px.
const TOQUE_MIN := 88.0

## Tokens visuais compartilhados. A tela nao escolhe marrom, raio ou padding
## sozinha: todos os jogos e menus leem a mesma regua.
const SPACE_UNIT := 8.0
const RADIUS_CARD := 18
const RADIUS_BUTTON := 16
const COLOR_SURFACE := Color(0.055, 0.09, 0.16, 0.96)
const COLOR_SURFACE_RAISED := Color(0.10, 0.15, 0.24, 0.98)
const COLOR_SURFACE_MUTED := Color(0.14, 0.20, 0.30, 0.96)
const COLOR_ACCENT := Color(0.34, 0.72, 0.98)
const COLOR_ACCENT_WARM := Color(0.98, 0.74, 0.30)
const COLOR_TEXT := Color(0.94, 0.97, 1.0)
const COLOR_MUTED := Color(0.66, 0.74, 0.84)
const COLOR_SUCCESS := Color(0.34, 0.82, 0.58)
const COLOR_BORDER := Color(0.32, 0.50, 0.68, 0.72)

## Nomes antigos continuam apontando para os tokens novos para nao quebrar
## telas legadas que ainda importam estas constantes.
const OURO := COLOR_ACCENT_WARM
const OURO_FRACO := Color(0.68, 0.78, 0.90)
const TEXTO := COLOR_TEXT
const TEXTO_FRACO := COLOR_MUTED
const FUNDO_CARTAO := COLOR_SURFACE_RAISED
const FUNDO_TRILHO := COLOR_SURFACE_MUTED
const VERDE := COLOR_SUCCESS


static func cartao(preenchido: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	# O cartao e moldura, nao alvo: em `MOUSE_FILTER_STOP` ele engolia o
	# arrasto do dedo e a lista dentro do ScrollContainer nao rolava. Ver
	# `rolavel()` logo abaixo.
	p.mouse_filter = Control.MOUSE_FILTER_PASS
	var st := StyleBoxFlat.new()
	st.bg_color = COLOR_SURFACE_RAISED if preenchido else Color(COLOR_SURFACE, 0.55)
	st.border_color = COLOR_BORDER
	st.set_border_width_all(1)
	st.set_corner_radius_all(RADIUS_CARD)
	st.content_margin_left = SPACE_UNIT * 2.0
	st.content_margin_right = SPACE_UNIT * 2.0
	st.content_margin_top = SPACE_UNIT * 1.5
	st.content_margin_bottom = SPACE_UNIT * 1.5
	p.add_theme_stylebox_override("panel", st)
	return p


## Rótulo de uma linha. NÃO quebra texto de propósito: dentro de uma HBox um
## rótulo sem largura reservada é espremido até o mínimo, e com autowrap ligado
## ele quebra letra por letra — a primeira versão desta tela mostrava "Bronze"
## na vertical, uma letra por linha, ao lado da barra de XP.
static func rotulo(texto: String, tamanho: int = FONTE_CORPO, cor: Color = TEXTO) -> Label:
	var l := Label.new()
	l.text = texto
	l.add_theme_font_size_override("font_size", tamanho)
	l.add_theme_color_override("font_color", cor)
	return l


## Rótulo que quebra em várias linhas. Só para texto corrido — descrição de
## conquista, condição de desbloqueio — e sempre ocupando a largura toda.
static func paragrafo(texto: String, tamanho: int = FONTE_MIUDA, cor: Color = TEXTO_FRACO) -> Label:
	var l := rotulo(texto, tamanho, cor)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l


## Caixas de arrumacao. Nascem em `MOUSE_FILTER_PASS` porque um Container em
## `STOP` -- o padrao do Godot -- e uma parede invisivel no meio do caminho do
## dedo: o `InputEventScreenDrag` sobe do botao (que ja e `PASS`), bate na
## HBox que o segura e morre ali, sem nunca chegar ao ScrollContainer. Foi
## assim que a tira de abas do perfil e a lista da colecao ficaram sem rolagem
## no telefone enquanto a roda do mouse continuava rolando no computador.
static func vbox(separacao: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separacao)
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	return v


static func hbox(separacao: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separacao)
	h.mouse_filter = Control.MOUSE_FILTER_PASS
	return h


## Marca o filho que absorve a folga da HBox. O rótulo que expande também passa
## a poder encolher (`clip_text`): sem isso ele reserva a largura do texto
## inteiro e empurra o valor da direita para fora da linha -- foi assim que a
## coluna de números da tela de perfil apareceu vazia.
static func expandir(c: Control) -> Control:
	c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if c is Label and (c as Label).autowrap_mode == TextServer.AUTOWRAP_OFF:
		(c as Label).clip_text = true
	return c


## Barra de progresso chapada, sem número por cima -- o número vai no rótulo ao
## lado, que dá para ler.
static func barra(valor: int, total: int, cor: Color = OURO, altura: float = 14.0) -> ProgressBar:
	var b := ProgressBar.new()
	# Desenho puro: nao recebe toque nenhum, e sair da frente e o que deixa o
	# dedo alcancar a rolagem por cima dela.
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.max_value = maxf(1.0, float(total))
	b.value = clampf(float(valor), 0.0, b.max_value)
	b.show_percentage = false
	b.custom_minimum_size = Vector2(0, altura)

	var trilho := StyleBoxFlat.new()
	trilho.bg_color = FUNDO_TRILHO
	trilho.set_corner_radius_all(int(altura * 0.5))
	b.add_theme_stylebox_override("background", trilho)

	var preenchido := StyleBoxFlat.new()
	preenchido.bg_color = cor
	preenchido.set_corner_radius_all(int(altura * 0.5))
	b.add_theme_stylebox_override("fill", preenchido)
	return b


## Botão que respeita o mínimo de toque do telefone.
static func botao(texto: String, tamanho: int = FONTE_CORPO) -> Button:
	var b: Button = TAP_BUTTON.new()
	b.text = texto
	b.custom_minimum_size = Vector2(TOQUE_MIN, TOQUE_MIN)
	b.add_theme_font_size_override("font_size", tamanho)
	rolavel(b)
	return b


## Botao curto para filtros/estados; conserva a mesma altura e raio dos botoes
## principais, mudando apenas a cor de destaque.
static func chip(texto: String, cor: Color = COLOR_ACCENT) -> Button:
	var b := botao(texto, FONTE_MIUDA)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(cor, 0.16)
	normal.border_color = Color(cor, 0.72)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(RADIUS_BUTTON)
	b.add_theme_stylebox_override("normal", normal)
	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(cor, 0.30)
	pressed.set_border_width_all(2)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("hover", pressed)
	b.add_theme_stylebox_override("focus", pressed)
	return b


## Icone de chrome: alvo grande, conteudo curto e sem texto hardcoded.
static func icone(simbolo: String, dica: String = "") -> Button:
	var b := botao(simbolo, FONTE_SECAO)
	b.tooltip_text = dica
	b.custom_minimum_size = Vector2(TOQUE_MIN, TOQUE_MIN)
	return b


## Conecta a ação correta para um botão criado pela UIKit. Botões de cena
## continuam usando `pressed`; `JogosTapButton` usa `tapped` para não somar o
## toque explícito do iOS ao clique nativo que a engine ainda pode emitir.
static func conectar_toque(b: Button, acao: Callable) -> void:
	if b.has_signal(&"tapped"):
		b.connect(&"tapped", acao)
	else:
		b.pressed.connect(acao)


## Aplica o contrato de entrada às artes dentro de um botão composto. Labels,
## painéis e texturas são desenho; deixar qualquer um deles em STOP faz o iOS
## entregar o toque ao filho e nunca ao botão que navega.
static func ignorar_toque_dos_filhos(no: Node) -> void:
	for filho in no.get_children():
		if filho is Control:
			(filho as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			ignorar_toque_dos_filhos(filho)


## Deixa o toque atravessar o controle a caminho do ScrollContainer que o
## contém. Sem isto uma lista de botões não rola no dedo.
##
## `Button` nasce em `MOUSE_FILTER_STOP`, e `STOP` interrompe a subida do
## evento pela árvore: o `InputEventScreenTouch` do dedo e os
## `InputEventScreenDrag` que vêm atrás morrem no botão, e o `ScrollContainer`
## — que é quem faz o arrasto virar rolagem — nunca os vê. A roda do mouse
## continua rolando porque o Godot deixa evento de roda subir mesmo por cima de
## um filho que para o resto; foi por isso que o defeito atravessou o
## computador sem aparecer, e só o telefone o mostrou.
##
## `PASS` entrega o evento ao controle *e* segue subindo. O clique continua
## valendo, e um arrasto não vira clique por engano: quando a rolagem passa da
## zona morta, o `ScrollContainer` propaga `NOTIFICATION_SCROLL_BEGIN` e o
## próprio `BaseButton` desarma o toque pendente (medido: com o aviso, `pressed`
## não dispara ao soltar; sem ele, dispara).
##
## Só vale para quem trata o próprio toque sem `accept_event()` — quem aceita o
## evento o consome de qualquer jeito, e aí a rolagem precisa de outra saída.
static func rolavel(c: Control) -> Control:
	c.mouse_filter = Control.MOUSE_FILTER_PASS
	return c


## ScrollContainer que rola no dedo. O da engine so rola na roda do mouse e na
## barra lateral -- ver `DragScroll`, que explica a medicao. Todo lugar que
## rola no PlayTable passa por aqui ou por `DragScroll.attach()`.
static func rolagem(vertical: bool = true, horizontal: bool = false) -> ScrollContainer:
	var r := ScrollContainer.new()
	r.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if vertical \
		else ScrollContainer.SCROLL_MODE_DISABLED
	r.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal \
		else ScrollContainer.SCROLL_MODE_DISABLED
	if vertical:
		r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	DragScroll.attach(r)
	return r


## Linha "rótulo à esquerda, valor à direita" -- o formato de toda estatística.
static func linha_valor(rotulo_txt: String, valor_txt: String) -> HBoxContainer:
	var h := hbox(10)
	h.add_child(expandir(rotulo(rotulo_txt, FONTE_MIUDA, TEXTO_FRACO)))
	var v := rotulo(valor_txt, FONTE_CORPO, OURO)
	v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# O valor manda na própria largura; quem cede espaço é o rótulo à esquerda.
	v.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(v)
	return h
