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

## Emitido quando safe area, viewport ou prioridade dos badges altera a
## composição disponível para o jogo.
signal layout_changed(metrics: MobileHudMetrics)

## O jogador trocou entre jogar contra a maquina e dois no mesmo aparelho.
## `vs_ai` ja vem com o valor novo. So os jogos que oferecem os dois modos
## mostram o botao -- os outros nem sabem que ele existe.
signal mode_pressed(vs_ai: bool)

## Margem lateral -- a mesma de `MenuTabuleiro.tscn`, para a barra do jogo e a
## do menu alinharem quando uma vira a outra.
const MARGEM := UIKit.SPACE_UNIT * 3.0


## Altura da faixa de conteúdo: o alvo de toque mínimo, e nada menos.
const ALTURA := UIKit.TOQUE_MIN

## Respiro do topo antes da barra começar. É o espaço ABAIXO do safe area inset
## (notch/Dynamic Island); o próprio inset já vem de JogosSafeArea. TOPO_BASE é
## o mínimo de respiração mesmo quando o safe area é zero (desktop/Android).
const TOPO_BASE := 12.0

## Padding efetivo calculado em _ready() e atualizado ao mudar o viewport.
## Inclui o safe area inset do topo.
var _topo_real: float = TOPO_BASE

## O que `BaseGame.measure_hud_bands()` vai ler como banda de HUD de topo.
## Precisa ser uma propriedade dinâmica (não const) porque muda com o notch.
const BANDA_BASE := ALTURA  ## Só a altura do conteúdo; o topo é adicionado em _ready().
var BANDA: float = TOPO_BASE + ALTURA

## Até onde o véu escurece a mesa. Passa da barra de propósito: o degradê tem de
## acabar em nada, senão vira uma régua de chrome colada sobre o feltro.
const VEU := 168.0

## Separação entre voltar, nome e placar.
const RESPIRO := int(UIKit.SPACE_UNIT * 2.0)

## O respiro quando o botao de modo entra na fila: com cinco itens, 16 px entre
## eles custam o nome do jogo.
const RESPIRO_APERTADO := int(UIKit.SPACE_UNIT)

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
const VEU_COR := UIKit.COLOR_SURFACE

var _titulo := ""
var _celulas: Array[Dictionary] = []
var _duelo := false
var _venceu := false

## Lado que está jogando: 0 é o seu, 1 é o do adversário, -1 é ninguém.
var _lado_ativo := -1

var _label_titulo: Label = null
var _caixa_badges: HBoxContainer = null
var _caixa_placar: HBoxContainer = null
var _btn_ajuda: Button = null
var _btn_modo: Button = null

var mobile_metrics: MobileHudMetrics = null
var content_top_px: float = 0.0
var content_bottom_px: float = 0.0
var _badges: Array[Dictionary] = []
var _badge_controls: Dictionary = {}

## O modo em que a partida esta, quando o jogo oferece os dois.
var _vs_ai := true

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
	_atualizar_safe_area()
	# Atualiza quando o viewport muda (rotação, mudança de resolução).
	var vp := get_viewport()
	if vp and not vp.size_changed.is_connected(_atualizar_safe_area):
		vp.size_changed.connect(_atualizar_safe_area)

	_montar_veu()
	_montar_linha()
	_refazer_placar()
	_reaplicar_badges()
	_atualizar_badge_prioridades()


## Recalcula o padding do topo com base no safe area atual (notch, Dynamic Island).
## Chamado em _ready() e quando o viewport muda de tamanho.
func _atualizar_safe_area() -> void:
	var vp := get_viewport()
	var insets := JogosSafeArea.insets(vp)
	var inset := insets.y
	_topo_real = TOPO_BASE + inset
	BANDA = _topo_real + ALTURA
	offset_bottom = BANDA
	var viewport_size := vp.get_visible_rect().size if vp != null else Vector2.ZERO
	mobile_metrics = MobileHudMetrics.calculate(viewport_size, insets, ALTURA, 0.0)
	content_top_px = BANDA
	content_bottom_px = viewport_size.y - insets.w
	# Reposiciona a linha de botões se já foi montada.
	var linha := get_node_or_null("Linha")
	if linha is Control:
		linha.offset_top = _topo_real
	_atualizar_badge_prioridades()
	if mobile_metrics != null:
		layout_changed.emit(mobile_metrics)


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
	veu.set_meta("allow_overlay", true)
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
	linha.offset_top = _topo_real
	linha.offset_right = -MARGEM
	linha.offset_bottom = 0.0
	add_child(linha)

	var btn := UIKit.botao(tr("BTN_BACK"))
	btn.name = "BtnBack"
	btn.custom_minimum_size = Vector2(LARGURA_VOLTAR, ALTURA)
	UIKit.conectar_toque(btn, func() -> void: back_pressed.emit())
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

	_caixa_badges = UIKit.hbox(RESPIRO_APERTADO)
	_caixa_badges.name = "Badges"
	_caixa_badges.alignment = BoxContainer.ALIGNMENT_END
	_caixa_badges.size_flags_horizontal = Control.SIZE_SHRINK_END
	linha.add_child(_caixa_badges)

	_caixa_placar = UIKit.hbox(14)
	_caixa_placar.name = "Placar"
	_caixa_placar.alignment = BoxContainer.ALIGNMENT_END
	_caixa_placar.size_flags_horizontal = Control.SIZE_SHRINK_END
	linha.add_child(_caixa_placar)

	# O modo mora aqui, e nao num botao solto na cena, por falta de lugar: em
	# cima o texto de status atravessa a tela, embaixo cada jogo tem a sua fila
	# (o dado do Ludo, as varetas do Senet). A barra e a unica faixa que ja e de
	# todos os jogos -- e, por ser faixa que ja existe, o botao nao custa um
	# milimetro de mesa.
	_btn_modo = UIKit.icone(tr("MODE_ICON_AI"), tr("MODE_LABEL"))
	_btn_modo.name = "BtnMode"
	_btn_modo.custom_minimum_size = Vector2(LARGURA_AJUDA, ALTURA)
	_btn_modo.visible = false
	UIKit.conectar_toque(_btn_modo, _on_modo_tocado)
	linha.add_child(_btn_modo)

	_btn_ajuda = UIKit.icone(tr("BTN_RULES_ICON"), tr("RULES_TITLE"))
	_btn_ajuda.name = "BtnRules"
	_btn_ajuda.custom_minimum_size = Vector2(LARGURA_AJUDA, ALTURA)
	_btn_ajuda.tooltip_text = tr("RULES_TITLE")
	_btn_ajuda.visible = false
	UIKit.conectar_toque(_btn_ajuda, func() -> void: help_pressed.emit())
	linha.add_child(_btn_ajuda)


## Poe o botao de modo na barra. Chamado pelos jogos que sabem jogar de dois;
## quem nao chama nao ganha botao nenhum.
func oferecer_modo(vs_ai: bool) -> void:
	_vs_ai = vs_ai
	if _btn_modo == null:
		return
	_btn_modo.visible = true
	# Um botao a mais na fila tira 88 px de quem cede espaco, que e o nome do
	# jogo: "Mancala" saia "Mancal". O respiro entre os itens encolhe SO nestes
	# jogos -- os outros continuam com a barra folgada de sempre.
	var linha := get_node_or_null("Linha") as HBoxContainer
	if linha != null:
		linha.add_theme_constant_override("separation", RESPIRO_APERTADO)
	_pintar_modo()


## Tira o botao da barra -- em partida de rede nao ha modo para escolher.
func esconder_modo() -> void:
	if _btn_modo != null:
		_btn_modo.visible = false
	_atualizar_badge_prioridades()


## Badges contextuais compactos para turno, conexão, jogadas ou estado da mesa.
## A barra mantém no máximo o que cabe; a prioridade maior permanece visível.
func set_context_badges(badges: Array[Dictionary]) -> void:
	_badges.clear()
	for badge in badges:
		var id := str(badge.get("id", ""))
		if id == "":
			continue
		_badges.append({
			"id": id,
			"icon": str(badge.get("icon", "•")),
			"priority": int(badge.get("priority", 0)),
			"tooltip": str(badge.get("tooltip", "")),
		})
	_badges.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("priority", 0)) > int(b.get("priority", 0)))
	_reaplicar_badges()
	_atualizar_badge_prioridades()


func has_badge(id: String) -> bool:
	for badge in _badges:
		if str(badge.get("id", "")) == id:
			return true
	return false


func visible_badge_count() -> int:
	var total := 0
	for control in _badge_controls.values():
		if is_instance_valid(control) and (control as Control).visible:
			total += 1
	return total


func get_badge(id: String) -> Control:
	return _badge_controls.get(id) as Control


func _reaplicar_badges() -> void:
	if _caixa_badges == null:
		return
	for child in _caixa_badges.get_children():
		_caixa_badges.remove_child(child)
		child.queue_free()
	_badge_controls.clear()
	for badge in _badges:
		var id := str(badge.get("id", ""))
		var button := UIKit.icone(str(badge.get("icon", "•")),
			str(badge.get("tooltip", "")))
		button.name = "Badge_%s" % id
		button.custom_minimum_size = Vector2(LARGURA_AJUDA, ALTURA)
		button.tooltip_text = str(badge.get("tooltip", ""))
		_caixa_badges.add_child(button)
		_badge_controls[id] = button


func _atualizar_badge_prioridades() -> void:
	if _caixa_badges == null:
		return
	var largura := get_viewport_rect().size.x if get_viewport() != null else size.x
	var maximo := 1 if largura < 640.0 else 2
	var mostrados := 0
	for badge in _badges:
		var id := str(badge.get("id", ""))
		var control := _badge_controls.get(id) as Control
		if control == null:
			continue
		control.visible = mostrados < maximo
		if control.visible:
			mostrados += 1


func _on_modo_tocado() -> void:
	_vs_ai = not _vs_ai
	_pintar_modo()
	mode_pressed.emit(_vs_ai)


func _pintar_modo() -> void:
	if _btn_modo == null:
		return
	_btn_modo.text = tr("MODE_ICON_AI") if _vs_ai else tr("MODE_ICON_VERSUS")
	# Sem tooltip no telefone, quem diz o modo por extenso e a linha do degrau
	# de cada jogo; o icone aqui e o interruptor.
	_btn_modo.tooltip_text = tr("MODE_LABEL") % tr("MODE_VS_AI" if _vs_ai else "MODE_TWO_PLAYERS")


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
	# Dois degraus, e nao um: com o botao de modo na barra o "Mancala" saia
	# "Mancal" -- sem reticencias sequer, que e pior que um nome pequeno.
	var tamanho := UIKit.FONTE_SECAO
	var preciso := 0.0
	for candidato in [UIKit.FONTE_SECAO, UIKit.FONTE_CORPO, UIKit.FONTE_MIUDA]:
		tamanho = candidato
		preciso = fonte.get_string_size(_titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, tamanho).x
		if preciso <= largura:
			break

	# Quando nem no menor corpo cabe metade do nome, o rotulo some. "Ludo" virado
	# em "Lu" nao e o nome do jogo -- e um toco, e um toco ocupa o lugar que o
	# placar e os botoes usariam melhor. Quem chegou aqui acabou de tocar no
	# cartao do jogo: o nome ja foi dito.
	_label_titulo.visible = preciso <= largura or largura >= preciso * 0.6

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
