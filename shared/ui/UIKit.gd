class_name UIKit
extends RefCounted

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

const OURO := Color(0.99, 0.84, 0.40)
const OURO_FRACO := Color(0.72, 0.62, 0.36)
const TEXTO := Color(0.93, 0.91, 0.86)
const TEXTO_FRACO := Color(0.70, 0.68, 0.64)
const FUNDO_CARTAO := Color(0.09, 0.10, 0.14, 0.92)
const FUNDO_TRILHO := Color(0.18, 0.19, 0.24, 1.0)
const VERDE := Color(0.42, 0.82, 0.52)


static func cartao(preenchido: bool = true) -> PanelContainer:
	var p := PanelContainer.new()
	var st := StyleBoxFlat.new()
	st.bg_color = FUNDO_CARTAO if preenchido else Color(0.09, 0.10, 0.14, 0.55)
	st.border_color = Color(0.30, 0.28, 0.22, 0.85)
	st.set_border_width_all(1)
	st.set_corner_radius_all(16)
	st.content_margin_left = 18
	st.content_margin_right = 18
	st.content_margin_top = 14
	st.content_margin_bottom = 14
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


static func vbox(separacao: int = 8) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", separacao)
	return v


static func hbox(separacao: int = 12) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", separacao)
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
	var b := Button.new()
	b.text = texto
	b.custom_minimum_size = Vector2(0, TOQUE_MIN)
	b.add_theme_font_size_override("font_size", tamanho)
	return b


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
