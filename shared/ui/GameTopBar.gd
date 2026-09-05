class_name GameTopBar
extends Control

## A barra de cima, a mesma nos 19 jogos: voltar, nome do jogo e placar.
##
## Antes cada `.tscn` desenhava a sua. Eram duas grafias do mesmo botão
## ("⬅ Voltar" em 13 telas, "‹ Voltar" em 6), quatro tamanhos de título (24, 26,
## 30 e 32 px), quatro alturas de botão (44, 48, 50 e 54 px) -- nenhuma chegando
## ao alvo de toque de 48 dp -- e o placar ora numa linha solta, ora em cartões
## de 12 px, ora em lugar nenhum, como no Ludo.
##
## Quem monta é o `BaseGame`: nenhuma cena precisa conhecer esta classe nem
## carregar um nó de cabeçalho. O jogo só diz o placar, e são duas formas:
##
##     set_duel_score(minhas, da_ia)                        # dois lados
##     set_counters([{"value": "14", "label": "SCORE_PLAYS"}])  # jogo solo
##
## O placar são células "número sobre rótulo", no máximo duas: com três, o nome
## do jogo não cabe mais nos 720 px do viewport lógico.

## Emitido pelo botão voltar. Quem leva ao menu é o `BaseGame`.
signal back_pressed

## Emitido pelo "?". Quem abre as regras e o `BaseGame`.
signal help_pressed

## Margem lateral -- a mesma de `MenuTabuleiro.tscn`, para a barra do jogo e a
## do menu alinharem quando uma vira a outra.
const MARGEM := 24.0

## Respiro do topo antes da barra começar.
const TOPO := 36.0

## Altura da faixa de conteúdo: o alvo de toque mínimo, e nada menos.
const ALTURA := UIKit.TOQUE_MIN

## O que `BaseGame.measure_hud_bands()` vai ler como banda de HUD de topo.
const BANDA := TOPO + ALTURA

## Até onde o véu escurece a mesa. Passa da barra de propósito: o degradê tem de
## acabar em nada, senão vira uma régua de chrome colada sobre o feltro.
const VEU := 168.0

## Separação entre voltar, nome e placar.
const RESPIRO := 16

## Largura do botão voltar. Cabe "‹ Voltar", "‹ Back" e "‹ Volver".
const LARGURA_VOLTAR := 150.0

## Lado do botao de ajuda. Quadrado, no alvo minimo de toque.
const LARGURA_AJUDA := UIKit.TOQUE_MIN

## Corpo do número do placar. Acima de `FONTE_SECAO` porque é o que o jogador
## procura de relance, e o rótulo embaixo já segura o piso de 14 sp.
const FONTE_VALOR := 34

## Fonte do ponto que separa os dois lados de um duelo.
const FONTE_PONTO := 30

## Largura mínima de uma célula, para o placar não dançar quando 9 vira 10.
const LARGURA_CELULA := 72.0

## Rótulos do placar, em chave de tradução. Eram "você" e "ia" escritos aqui,
## e o placar dos dezenove jogos continuava em português com o aplicativo em
## inglês -- junto com "jogadas", "fichas", "minas" e os outros que cada jogo
## passa. Quem traduz é `_refazer_placar`, num lugar só.
const ROTULO_VOCE := "SCORE_YOU"
const ROTULO_IA := "SCORE_AI"

## Cor do véu: o preto mais quente da mesa, não preto puro.
const VEU_COR := Color(0.031, 0.024, 0.016)

var _titulo := ""
var _celulas: Array[Dictionary] = []
var _duelo := false
var _venceu := false

## Lado que está jogando: 0 é o seu, 1 é o do adversário, -1 é ninguém.
var _lado_ativo := -1

var _label_titulo: Label = null
var _caixa_placar: HBoxContainer = null
var _btn_ajuda: Button = null

## Formato desenhado agora ("duelo:2"), para saber quando dá para só reescrever.
var _assinatura := ""
var _nos: Array[VBoxContainer] = []


## Nome do jogo. Vem do `GameCatalog`, não de texto escrito na cena.
var game_title: String:
	get:
		return _titulo
	set(value):
		_titulo = value
		if _label_titulo != null:
			_label_titulo.text = value


func _ready() -> void:
	# A barra inteira deixa o toque passar; quem recebe é o botão, filho dela.
	# Sem isto a faixa de 124 px come o clique de quem entra pelo picking 3D.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.0
	anchor_top = 0.0
	anchor_right = 1.0
	anchor_bottom = 0.0
	offset_left = 0.0
	offset_top = 0.0
	offset_right = 0.0
	offset_bottom = BANDA

	_montar_veu()
	_montar_linha()
	_refazer_placar()


## Degradê que escurece a mesa atrás do texto. Um `TextureRect` e não um
## `ColorRect` chapado: sobre feltro claro um véu de opacidade única ou não
## segura o nome ou vira uma tarja preta atravessada na mesa.
func _montar_veu() -> void:
	var grad := Gradient.new()
	grad.set_color(0, Color(VEU_COR, 0.80))
	grad.set_color(1, Color(VEU_COR, 0.0))
	grad.add_point(0.58, Color(VEU_COR, 0.62))

	var tex := GradientTexture2D.new()
	tex.gradient = grad
	tex.width = 4
	tex.height = 256
	tex.fill_from = Vector2(0.0, 0.0)
	tex.fill_to = Vector2(0.0, 1.0)

	var veu := TextureRect.new()
	veu.name = "Veu"
	veu.texture = tex
	veu.stretch_mode = TextureRect.STRETCH_SCALE
	veu.mouse_filter = Control.MOUSE_FILTER_IGNORE
	veu.anchor_left = 0.0
	veu.anchor_top = 0.0
	veu.anchor_right = 1.0
	veu.anchor_bottom = 0.0
	veu.offset_bottom = VEU
	add_child(veu)


func _montar_linha() -> void:
	var linha := UIKit.hbox(RESPIRO)
	linha.name = "Linha"
	linha.anchor_left = 0.0
	linha.anchor_top = 0.0
	linha.anchor_right = 1.0
	linha.anchor_bottom = 1.0
	linha.offset_left = MARGEM
	linha.offset_top = TOPO
	linha.offset_right = -MARGEM
	linha.offset_bottom = 0.0
	add_child(linha)

	var btn := UIKit.botao(tr("BTN_BACK"))
	btn.name = "BtnBack"
	btn.custom_minimum_size = Vector2(LARGURA_VOLTAR, ALTURA)
	btn.pressed.connect(func() -> void: back_pressed.emit())
	linha.add_child(btn)

	_label_titulo = UIKit.rotulo(_titulo, UIKit.FONTE_SECAO, UIKit.TEXTO)
	_label_titulo.name = "Titulo"
	_label_titulo.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# O nome é quem cede espaço: corta com reticências para o placar, que é
	# número e não sobrevive a corte nenhum, nunca encolher.
	_label_titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# A largura sobra do que o placar deixa, e o placar muda de tamanho durante a
	# partida: quem sabe se o nome ainda cabe e o proprio rotulo, quando redimensiona.
	_label_titulo.resized.connect(_ajustar_fonte_do_nome)
	linha.add_child(UIKit.expandir(_label_titulo))

	_caixa_placar = UIKit.hbox(14)
	_caixa_placar.name = "Placar"
	_caixa_placar.alignment = BoxContainer.ALIGNMENT_END
	_caixa_placar.size_flags_horizontal = Control.SIZE_SHRINK_END
	linha.add_child(_caixa_placar)

	_btn_ajuda = UIKit.botao(tr("BTN_RULES_ICON"), UIKit.FONTE_TITULO)
	_btn_ajuda.name = "BtnRules"
	_btn_ajuda.custom_minimum_size = Vector2(LARGURA_AJUDA, ALTURA)
	_btn_ajuda.tooltip_text = tr("RULES_TITLE")
	_btn_ajuda.visible = false
	_btn_ajuda.pressed.connect(func() -> void: help_pressed.emit())
	linha.add_child(_btn_ajuda)


## Um degrau de fonte antes das reticencias.
##
## "Jogo de Cores & Cartas" e o titulo mais comprido do catalogo e nao cabe em
## 32 px ao lado do placar de duelo -- saia "Jogo de Cores & C...", que nao e
## nome de jogo nenhum. Encurtar o titulo a mao criaria um segundo nome para o
## mesmo jogo, que e exatamente o que esta barra veio desfazer; entao quem cede
## e o corpo da letra, e so no jogo que precisa.
func _ajustar_fonte_do_nome() -> void:
	if _label_titulo == null or _titulo == "":
		return
	var largura := _label_titulo.size.x
	if largura <= 0.0:
		return
	var fonte := _label_titulo.get_theme_font("font")
	if fonte == null:
		return
	var tamanho := UIKit.FONTE_SECAO
	if fonte.get_string_size(_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x > largura:
		tamanho = UIKit.FONTE_CORPO
	if _label_titulo.get_theme_font_size("font_size") != tamanho:
		_label_titulo.add_theme_font_size_override("font_size", tamanho)


# ------------------------------------------------------------------- placar

## Placar de dois lados: o seu número em ouro, o do adversário em claro, com um
## ponto no meio. É a forma de doze dos dezenove jogos.
func set_duel_score(mine: Variant, theirs: Variant, mine_label: String = ROTULO_VOCE, theirs_label: String = ROTULO_IA) -> void:
	_duelo = true
	_celulas = [
		{"value": str(mine), "label": mine_label},
		{"value": str(theirs), "label": theirs_label},
	]
	_refazer_placar()


## Placar de jogo solo: uma ou duas células rotuladas -- jogadas, tempo, minas.
## A terceira não entra; o nome do jogo perde a largura dela.
func set_counters(cells: Array) -> void:
	_duelo = false
	_celulas = []
	for c in cells:
		if _celulas.size() >= 2:
			break
		var d := c as Dictionary
		if d == null:
			continue
		_celulas.append({"value": str(d.get("value", "")), "label": str(d.get("label", ""))})
	_refazer_placar()


## Atalho para o jogo que só tem um número a mostrar.
func set_counter(value: Variant, label: String) -> void:
	set_counters([{"value": value, "label": label}])


## De quem é a vez, no duelo: o lado que espera fica meio apagado. É o realce
## que o Jogo da Velha e o Quatro em Linha faziam nos cartões de placar que a
## barra recolheu -- sem isto o jogo perderia a pista de vez que já tinha.
func set_active_side(mine: bool) -> void:
	_lado_ativo = 0 if mine else 1
	_refazer_placar()


## Fim de partida: o seu número vira verde na vitória e volta ao ouro no
## reinício. Nada mais na barra se mexe.
func mark_win(won: bool) -> void:
	_venceu = won
	_refazer_placar()


## Repinta o placar. Enquanto o formato não muda -- mesma quantidade de células,
## mesmo duelo -- só troca o texto dos rótulos que já existem: o cronômetro do
## Campo Minado chama isto a cada segundo, e refazer os nós toda vez seria criar
## e destruir meia dúzia de `Label` por segundo para escrever um número.
func _refazer_placar() -> void:
	if _caixa_placar == null:
		return
	var assinatura := "%s:%d" % [_duelo, _celulas.size()]
	if assinatura != _assinatura:
		_assinatura = assinatura
		_nos.clear()
		for filho in _caixa_placar.get_children():
			_caixa_placar.remove_child(filho)
			filho.queue_free()
		for i in _celulas.size():
			if _duelo and i > 0:
				_caixa_placar.add_child(_ponto())
			var celula := _celula()
			_caixa_placar.add_child(celula)
			_nos.append(celula)

	for i in _celulas.size():
		var cor := UIKit.TEXTO
		if i == 0:
			cor = UIKit.VERDE if _venceu else UIKit.OURO
		var valor := _nos[i].get_child(0) as Label
		var rotulo := _nos[i].get_child(1) as Label
		valor.text = str(_celulas[i]["value"])
		valor.add_theme_color_override("font_color", cor)
		# `tr` de chave desconhecida devolve a própria entrada, então um jogo que
		# ainda passe texto pronto continua aparecendo igual.
		rotulo.text = tr(str(_celulas[i]["label"]))
		var esperando := _duelo and _lado_ativo >= 0 and _lado_ativo != i
		_nos[i].modulate = Color(0.6, 0.6, 0.6, 0.7) if esperando else Color(1.0, 1.0, 1.0, 1.0)


## Célula vazia: número em cima, rótulo embaixo. Quem escreve é `_refazer_placar`.
func _celula() -> VBoxContainer:
	var v := UIKit.vbox(2)
	v.custom_minimum_size = Vector2(LARGURA_CELULA, 0)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var num := UIKit.rotulo("", FONTE_VALOR, UIKit.OURO)
	num.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(num)

	var lbl := UIKit.rotulo("", UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(lbl)
	return v


## O ponto vai numa célula igual às outras, com o rótulo vazio: assim ele alinha
## com os números sem ninguém calcular deslocamento.
func _ponto() -> VBoxContainer:
	var v := UIKit.vbox(2)
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	var p := UIKit.rotulo("·", FONTE_PONTO, UIKit.OURO_FRACO)
	p.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(p)

	v.add_child(UIKit.rotulo("", UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	return v


## Mostra ou esconde o "?". Fica escondido no jogo que nao tem regras escritas,
## porque botao que abre painel vazio e pior do que botao nenhum.
func set_help_available(disponivel: bool) -> void:
	if _btn_ajuda:
		_btn_ajuda.visible = disponivel
