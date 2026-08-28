extends Control

## Tela inicial: onde você está, o que dá para fechar hoje, o que falta provar.
##
## A tela anterior era um cartaz. Título, subtítulo e quatro botões — dois
## deles configuração — e, no meio, um cartão de perfil de uma linha. Dos
## dezenove jogos não aparecia nenhum; das três missões sorteadas para o dia,
## nenhuma; do progresso, só um "🎯 faltam 2" espremido. A primeira decisão que
## a tela pedia ao jogador era "tabuleiro ou cartas?", que é justamente a
## pergunta que ele menos quer responder ao abrir o app.
##
## Agora a tela responde três coisas, de cima para baixo:
##
##   barra superior     onde você está — nível, XP, sequência e pontos de liga
##   desafios de hoje   o que dá para fechar antes de o dia virar
##   novos para você    os jogos que você ainda não abriu nenhuma vez
##
## As categorias continuam ali embaixo, para quem já sabe o que quer, e som e
## idioma viraram uma linha discreta no rodapé: são ajuste, não navegação, e
## ocupavam o meio da tela.
##
## Montada em código porque quase tudo muda a cada abertura — nível, XP,
## sequência, as missões do dia e a lista de jogos nunca tocados. Em `.tscn`
## seria uma árvore escrita à mão que o `_ready` teria de reescrever inteira.

const PERFIL := "res://core/telas/PerfilScreen.tscn"
const MENU_TABULEIRO := "res://core/telas/MenuTabuleiro.tscn"
const MENU_CARTAS := "res://core/telas/MenuCartas.tscn"

## Margem lateral. A mesma de `MenuTabuleiro.tscn` e da barra dos jogos, para
## uma tela virar a outra sem o conteúdo escorregar de lado.
const MARGEM := 24

## Respiro acima da barra. O aplicativo exporta com `screen/immersive_mode=true`,
## então não há barra de status do Android para desviar — é o mesmo respiro que
## a barra de cima dos jogos usa.
const TOPO := 36
const RODAPE_BARRA := 20

const ANEL := 96.0
const ANEL_GROSSURA := 9.0

## 36 de respiro + 96 do anel + 20 embaixo.
const ALTURA_BARRA := 152.0

## Três cartões de 216 px e dois vãos de 12 fecham exatamente os 672 px úteis
## da linha. É por isso que são três e não quatro: o quarto sairia cortado, e
## cartão cortado numa fileira que não rola é defeito, não afordância.
const NOVOS_NA_TELA := 3
const LARGURA_NOVO := 216.0
const ALTURA_NOVO := 248.0
const ALTURA_ARTE := 112.0

const ALTURA_CATEGORIA := 200.0
const RAIO_CARTAO := 24

## Corpo do número dentro do anel e do emoji das categorias. Os demais tamanhos
## saem do `UIKit`, que já respeita o piso de 14 sp da régua de layout.
const FONTE_ANEL := 36
const FONTE_EMOJI := 52

## Paleta dos cartões de jogo. Repete a do `GameMenu` de propósito e por ora:
## lá ela é um método de instância (`_game_accent`), que uma tela sem instância
## de menu não alcança. Quando a reescrita do menu de categorias assentar, as
## duas viram uma só — de preferência dentro do `GameCatalog`, que é onde a
## informação do jogo nasce.
const ACENTOS := {
	"quatro_em_linha": "#1f66b8",
	"jogo_da_velha": "#203b66",
	"reversi": "#25864f",
	"batalha_naval": "#183149",
	"damas": "#552d32",
	"mancala": "#8d4d22",
}
const ACENTO_PADRAO := "#263b56"
const ACENTO_TABULEIRO := "#1f3a5f"
const ACENTO_CARTAS := "#5a2f38"

var _corpo: VBoxContainer
var _barra: Button


func _ready() -> void:
	_montar()
	if LocaleManager and LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_on_mudou_idioma)
	# O bônus de abertura é concedido em `call_deferred`, ou seja, depois deste
	# `_ready`. Sem escutar, o jogador que sobe de nível ao abrir o app vê a
	# barra com o número de ontem até sair da tela e voltar.
	if GameEventBus:
		GameEventBus.xp_gained.connect(_on_mudou_xp)
		GameEventBus.quest_progressed.connect(_on_mudou_quest)
		GameEventBus.quests_rolled.connect(_on_mudou_escopo)
		GameEventBus.daily_streak_updated.connect(_on_mudou_int)
		GameEventBus.league_changed.connect(_on_mudou_liga)


func _on_mudou_idioma(_locale: String) -> void: _remontar()
func _on_mudou_xp(_amount: int, _source: String) -> void: _remontar()
func _on_mudou_quest(_id: String, _atual: int, _alvo: int) -> void: _remontar()
func _on_mudou_escopo(_scope: String) -> void: _remontar()
func _on_mudou_int(_valor: int) -> void: _remontar()
func _on_mudou_liga(_id: String, _subiu: bool) -> void: _remontar()


# ------------------------------------------------------------------ estrutura

func _montar() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	add_child(preload("res://shared/ui/TabletopBackground.tscn").instantiate())

	var coluna := VBoxContainer.new()
	coluna.set_anchors_preset(Control.PRESET_FULL_RECT)
	coluna.add_theme_constant_override("separation", 0)
	add_child(coluna)

	_barra = _montar_barra()
	coluna.add_child(_barra)

	# O corpo rola e a barra não. Em 3:4 (720x960) o conteúdo passa da tela, e
	# é a régua de layout que cobra isso: fora de um ScrollContainer, um rótulo
	# abaixo da dobra conta como interface fora da tela.
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)

	# `SIZE_EXPAND_FILL` dentro de um ScrollContainer nao e enfeite: sem ele o
	# conteudo fica com a altura minima, e num perfil que ja jogou tudo (sem a
	# secao de novos) sobravam 200 px de mesa vazia embaixo do rodape.
	var margem := MarginContainer.new()
	margem.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	margem.add_theme_constant_override("margin_left", MARGEM)
	margem.add_theme_constant_override("margin_right", MARGEM)
	margem.add_theme_constant_override("margin_top", 22)
	margem.add_theme_constant_override("margin_bottom", 24)
	rolagem.add_child(margem)

	_corpo = UIKit.vbox(24)
	_corpo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margem.add_child(_corpo)

	_preencher_corpo()


func _remontar() -> void:
	if _barra == null or not is_inside_tree():
		return
	_pintar_barra()
	for filho in _corpo.get_children():
		_corpo.remove_child(filho)
		filho.queue_free()
	_preencher_corpo()


func _preencher_corpo() -> void:
	var desafios := _secao_desafios()
	if desafios != null:
		_corpo.add_child(desafios)

	var novos := _secao_novos()
	if novos != null:
		_corpo.add_child(novos)

	_corpo.add_child(_secao_categorias())

	# A folga fica aqui, entre as categorias e os ajustes: quando a tela tem
	# conteudo de sobra ela vale zero, e quando falta empurra ajustes e rodape
	# para o pe da tela em vez de deixar um vazio no fim.
	var folga := Control.new()
	folga.size_flags_vertical = Control.SIZE_EXPAND_FILL
	folga.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_corpo.add_child(folga)

	_corpo.add_child(_secao_ajustes())


# ------------------------------------------------------------- barra superior

## A faixa inteira é um só botão, como já era o cartão de perfil: tocar no
## progresso leva ao progresso, que é para onde o dedo ia de qualquer jeito.
func _montar_barra() -> Button:
	var b := Button.new()
	b.name = "BarraSuperior"
	b.custom_minimum_size = Vector2(0, ALTURA_BARRA)
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_stylebox_override("normal", _estilo_barra(false))
	b.add_theme_stylebox_override("hover", _estilo_barra(false))
	b.add_theme_stylebox_override("focus", _estilo_barra(false))
	b.add_theme_stylebox_override("pressed", _estilo_barra(true))
	b.pressed.connect(_on_pontos_pressed)
	_sem_texto(b)

	var margem := MarginContainer.new()
	margem.name = "Conteudo"
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", MARGEM)
	margem.add_theme_constant_override("margin_right", MARGEM)
	margem.add_theme_constant_override("margin_top", TOPO)
	margem.add_theme_constant_override("margin_bottom", RODAPE_BARRA)
	# Nenhum filho pode interceptar o toque, senão a faixa deixa de ser botão.
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(margem)

	_pintar_barra_em(margem)
	return b


func _pintar_barra() -> void:
	var margem: MarginContainer = _barra.get_node_or_null("Conteudo")
	if margem == null:
		return
	for filho in margem.get_children():
		margem.remove_child(filho)
		filho.queue_free()
	_pintar_barra_em(margem)


func _pintar_barra_em(margem: MarginContainer) -> void:
	var r: Dictionary = EngagementManager.resumo() if EngagementManager else {}
	if r.is_empty():
		return

	var linha := UIKit.hbox(14)
	linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(linha)

	var proximo := maxi(1, int(r["xp_next"]))
	var anel := AnelNivel.new()
	anel.fracao = clampf(float(r["xp"]) / float(proximo), 0.0, 1.0)
	anel.custom_minimum_size = Vector2(ANEL, ANEL)
	anel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	linha.add_child(anel)

	var numero := UIKit.rotulo(str(r["level"]), FONTE_ANEL, UIKit.OURO)
	numero.set_anchors_preset(Control.PRESET_FULL_RECT)
	numero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	numero.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	numero.mouse_filter = Control.MOUSE_FILTER_IGNORE
	anel.add_child(numero)

	var meio := UIKit.vbox(7)
	meio.mouse_filter = Control.MOUSE_FILTER_IGNORE
	meio.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meio.add_child(UIKit.rotulo(tr("PROFILE_LEVEL") % r["level"], UIKit.FONTE_CORPO, UIKit.TEXTO))
	meio.add_child(UIKit.barra(int(r["xp"]), proximo, UIKit.OURO, 12.0))
	meio.add_child(UIKit.rotulo(tr("PROFILE_XP") % [r["xp"], proximo], UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	linha.add_child(UIKit.expandir(meio))

	# A sequência some quando é zero em vez de mostrar "🔥 0": a chama apagada
	# ocupa o mesmo espaço e não diz nada. A folga vai para a barra de XP.
	var streak := int(r["streak"])
	if streak > 0:
		var pilha := UIKit.vbox(2)
		pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilha.alignment = BoxContainer.ALIGNMENT_CENTER
		var chama := UIKit.rotulo("🔥", 30)
		chama.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pilha.add_child(chama)
		var dias := UIKit.rotulo(str(streak), UIKit.FONTE_MIUDA, UIKit.OURO)
		dias.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		pilha.add_child(dias)
		linha.add_child(_pilula(pilha, false))

	# Os "pontos" do pedido são os da liga (`PROFILE_ELO` já diz "%d pontos"),
	# não o XP: XP é a barra do meio. A pílula usa a borda de destaque do tema
	# para ser a peça mais acesa da faixa — é ela que o dedo procura.
	var pontos := UIKit.vbox(4)
	pontos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pontos.alignment = BoxContainer.ALIGNMENT_CENTER
	var liga := UIKit.rotulo(tr("LEAGUE_" + str(r["league"]).to_upper()), UIKit.FONTE_MIUDA, UIKit.OURO)
	liga.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pontos.add_child(liga)
	var elo := UIKit.rotulo(tr("PROFILE_ELO") % r["elo"], UIKit.FONTE_CORPO, UIKit.TEXTO)
	elo.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pontos.add_child(elo)
	linha.add_child(_pilula(pontos, true))

	# Sem a seta ninguém descobre que a faixa abre uma tela.
	var seta := UIKit.rotulo("›", UIKit.FONTE_TITULO, UIKit.OURO_FRACO)
	seta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	seta.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	linha.add_child(seta)


func _estilo_barra(pressionada: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.14, 0.08, 0.05, 0.96) if pressionada else Color(0.09, 0.055, 0.04, 0.94)
	st.border_width_bottom = 2
	st.border_color = Color(0.80, 0.62, 0.28, 0.8) if pressionada else Color(0.55, 0.42, 0.22, 0.5)
	st.shadow_color = Color(0, 0, 0, 0.55)
	st.shadow_size = 0 if pressionada else 12
	st.shadow_offset = Vector2(0, 6)
	return st


func _pilula(conteudo: Control, destaque: bool) -> PanelContainer:
	var p := PanelContainer.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(0.20, 0.12, 0.08, 0.92)
	st.set_border_width_all(2)
	st.border_color = Color(0.92, 0.76, 0.36, 0.9) if destaque else Color(0.65, 0.50, 0.25, 0.6)
	st.set_corner_radius_all(14)
	st.content_margin_left = 16
	st.content_margin_right = 16
	st.content_margin_top = 10
	st.content_margin_bottom = 10
	if destaque:
		st.shadow_color = Color(0.92, 0.76, 0.36, 0.18)
		st.shadow_size = 8
	p.add_theme_stylebox_override("panel", st)
	p.add_child(conteudo)
	return p


func _on_pontos_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene(PERFIL)


## Anel de XP em volta do número do nível. Desenhado em vez de montado porque
## `ProgressBar` é reta e `TextureProgressBar` radial pediria duas texturas só
## para fazer um círculo.
class AnelNivel extends Control:
	var fracao := 0.0

	func _draw() -> void:
		var centro := size * 0.5
		var raio := minf(size.x, size.y) * 0.5 - ANEL_GROSSURA * 0.5
		if raio <= 0.0:
			return
		draw_circle(centro, raio - ANEL_GROSSURA * 0.5, Color(0.14, 0.08, 0.05, 1.0))
		draw_arc(centro, raio, 0.0, TAU, 64, UIKit.FUNDO_TRILHO, ANEL_GROSSURA, true)
		if fracao > 0.0:
			# Começa no topo e anda no sentido do relógio, como todo mostrador.
			draw_arc(centro, raio, -PI * 0.5, -PI * 0.5 + TAU * fracao, 64,
				UIKit.OURO, ANEL_GROSSURA, true)


# ------------------------------------------------------------------- desafios

func _secao_desafios() -> Control:
	if QuestEngine == null:
		return null
	var missoes: Array = QuestEngine.quests_for_ui("daily")
	if missoes.is_empty():
		return null

	var feitas := 0
	var xp_em_aberto := 0
	for q in missoes:
		if bool(q["completed"]):
			feitas += 1
		else:
			xp_em_aberto += int(q["xp"])

	var recado := tr("MENU_QUESTS_ALL_DONE") if feitas == missoes.size() \
		else tr("MENU_QUESTS_SUMMARY") % [feitas, missoes.size(), xp_em_aberto]
	var cor := UIKit.VERDE if feitas == missoes.size() else UIKit.TEXTO_FRACO

	var coluna := UIKit.vbox(10)
	coluna.add_child(_cabecalho_secao(tr("MENU_TODAY_QUESTS"), recado, cor))

	var cartao := UIKit.cartao()
	var lista := UIKit.vbox(14)
	for q in missoes:
		lista.add_child(_linha_missao(q))
	cartao.add_child(lista)
	coluna.add_child(cartao)
	return coluna


## Uma missão. Não é botão de propósito: não há nada para tocar aqui, e um
## botão de 71 px de altura ficaria abaixo do alvo mínimo de toque só para
## abrir a tela que a barra de cima já abre.
func _linha_missao(q: Dictionary) -> HBoxContainer:
	var feito: bool = q["completed"]
	var cor := UIKit.VERDE if feito else UIKit.OURO

	var linha := UIKit.hbox(14)

	var selo := PanelContainer.new()
	selo.custom_minimum_size = Vector2(48, 48)
	selo.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var st := StyleBoxFlat.new()
	st.bg_color = Color(cor, 0.12)
	st.set_border_width_all(1)
	st.border_color = Color(cor, 0.55)
	st.set_corner_radius_all(12)
	selo.add_theme_stylebox_override("panel", st)
	var icone := UIKit.rotulo("✅" if feito else _icone_missao(str(q.get("type", ""))), UIKit.FONTE_MIUDA)
	icone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	icone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	selo.add_child(icone)
	linha.add_child(selo)

	var col := UIKit.vbox(8)

	var topo := UIKit.hbox(10)
	topo.add_child(UIKit.expandir(UIKit.rotulo(tr(str(q["name_key"])),
		UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO if feito else UIKit.TEXTO)))
	var xp := UIKit.rotulo("+%d XP" % q["xp"], UIKit.FONTE_MIUDA, cor)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	xp.size_flags_horizontal = Control.SIZE_SHRINK_END
	topo.add_child(xp)
	col.add_child(topo)

	var baixo := UIKit.hbox(12)
	var barra := UIKit.barra(int(q["progress"]), int(q["target"]), cor, 10.0)
	barra.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	baixo.add_child(UIKit.expandir(barra))
	var conta := UIKit.rotulo(
		tr("PROFILE_QUEST_DONE") if feito else "%d / %d" % [q["progress"], q["target"]],
		UIKit.FONTE_MIUDA, cor if feito else UIKit.TEXTO_FRACO)
	conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	conta.size_flags_horizontal = Control.SIZE_SHRINK_END
	baixo.add_child(conta)
	col.add_child(baixo)

	linha.add_child(UIKit.expandir(col))
	return linha


## Um emoji por tipo de missão, com a mesma gramática que o resto do app já
## usa (🏆 vitória, 🎯 alvo, 🔥 sequência). O tipo vem do `QuestEngine`, e não
## de adivinhação sobre o nome do modelo.
func _icone_missao(tipo: String) -> String:
	match tipo:
		"win", "win_game": return "🏆"
		"win_category": return "♟️"
		"play", "play_game": return "🎲"
		"distinct_games": return "🎯"
		"fast_win": return "⏱️"
		"perfect": return "✨"
		"mastery_xp": return "📈"
		"collect": return "💎"
		_: return "🎯"


# -------------------------------------------------------------- novos para você

## Jogo "novo" é o que este jogador nunca abriu — não o que foi lançado por
## último. É a definição que o app já sabe responder sem metadado novo, e é a
## que casa com as missões de "jogue N jogos diferentes".
func _nunca_jogados() -> Array[GameDefinition]:
	var saida: Array[GameDefinition] = []
	if PlayerProfile == null:
		return saida
	for def: GameDefinition in GameCatalog.get_all_games():
		if not def.is_implemented:
			continue
		# Lê `per_game` direto: `PlayerProfile.game_stats()` cria a entrada do
		# jogo quando ela não existe, e a tela inicial gravaria estatística
		# zerada dos dezenove jogos só por ter sido aberta.
		var id := GameCatalog.game_id_of(def)
		if int(PlayerProfile.per_game.get(id, {}).get("matches", 0)) > 0:
			continue
		saida.append(def)
	return saida


func _secao_novos() -> Control:
	var faltando := _nunca_jogados()
	if faltando.is_empty():
		return null

	var total := GameCatalog.get_all_games().size()
	var coluna := UIKit.vbox(10)
	coluna.add_child(_cabecalho_secao(tr("MENU_NEW_FOR_YOU"),
		tr("MENU_UNPLAYED_SUMMARY") % [faltando.size(), total], UIKit.TEXTO_FRACO))

	var fila := UIKit.hbox(12)
	for i in mini(NOVOS_NA_TELA, faltando.size()):
		fila.add_child(_cartao_novo(faltando[i]))
	coluna.add_child(fila)
	return coluna


func _cartao_novo(def: GameDefinition) -> Button:
	var acento := _acento(def)

	var b := Button.new()
	b.custom_minimum_size = Vector2(LARGURA_NOVO, ALTURA_NOVO)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	UIKit.rolavel(b)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado,
			_estilo_cartao(acento, estado == "hover" or estado == "focus"))
	b.pressed.connect(_on_jogo_pressed.bind(def))
	_sem_texto(b)

	# A arte sangra até a borda, e quem arredonda os cantos de cima dela é o
	# recorte deste painel: `clip_contents` no botão recortaria num retângulo e
	# deixaria dois cantos quadrados por cima da moldura.
	var fundo := Panel.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.offset_left = 2.0
	fundo.offset_top = 2.0
	fundo.offset_right = -2.0
	fundo.offset_bottom = -2.0
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var st := StyleBoxFlat.new()
	st.bg_color = Color(acento, 0.92)
	st.set_corner_radius_all(RAIO_CARTAO - 2)
	fundo.add_theme_stylebox_override("panel", st)
	b.add_child(fundo)

	var pilha := UIKit.vbox(0)
	pilha.set_anchors_preset(Control.PRESET_FULL_RECT)
	pilha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(pilha)

	var arte_path := GameMenu.get_game_intro_path(def)
	if arte_path != "":
		var arte := TextureRect.new()
		arte.texture = load(arte_path)
		arte.custom_minimum_size = Vector2(0, ALTURA_ARTE)
		arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		arte.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilha.add_child(arte)
	else:
		var emoji := UIKit.rotulo(def.icon, FONTE_EMOJI)
		emoji.custom_minimum_size = Vector2(0, ALTURA_ARTE)
		emoji.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		emoji.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		emoji.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pilha.add_child(emoji)

	var textos := MarginContainer.new()
	textos.size_flags_vertical = Control.SIZE_EXPAND_FILL
	textos.add_theme_constant_override("margin_left", 10)
	textos.add_theme_constant_override("margin_right", 10)
	textos.add_theme_constant_override("margin_top", 8)
	textos.add_theme_constant_override("margin_bottom", 8)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pilha.add_child(textos)

	var col := UIKit.vbox(4)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(col)

	# Duas linhas, e reticencias na terceira. Com `clip_text` num rotulo
	# centralizado o corte come os dois lados: "Quatro em Linha" virava
	# "uatro em Linh".
	var titulo := UIKit.rotulo(def.display_name(), UIKit.FONTE_CORPO, Color(0.98, 0.98, 1.0))
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	titulo.max_lines_visible = 2
	titulo.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	col.add_child(titulo)

	var tag := UIKit.rotulo(tr(def.genre) if def.genre != "" else "", UIKit.FONTE_MIUDA,
		Color(0.82, 0.72, 0.52, 0.9))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.clip_text = true
	col.add_child(tag)

	return b


func _acento(def: GameDefinition) -> Color:
	var id := GameCatalog.game_id_of(def)
	return Color(str(ACENTOS.get(id, ACENTO_PADRAO)))


func _estilo_cartao(acento: Color, destacado: bool) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = Color(acento, 0.88)
	st.border_color = Color(acento.lightened(0.28 if destacado else 0.08), 0.98)
	st.set_border_width_all(3 if destacado else 2)
	st.set_corner_radius_all(RAIO_CARTAO)
	st.shadow_color = Color(acento, 0.32 if destacado else 0.22)
	st.shadow_size = 14 if destacado else 9
	st.shadow_offset = Vector2(0, 5)
	return st


func _on_jogo_pressed(def: GameDefinition) -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene(def.scene_path)


# ----------------------------------------------------------------- categorias

func _secao_categorias() -> HBoxContainer:
	var fila := UIKit.hbox(16)
	fila.add_child(_cartao_categoria("♟️", tr("MENU_CAT_BOARD"),
		GameCatalog.get_board_games().size(), Color(ACENTO_TABULEIRO), MENU_TABULEIRO))
	fila.add_child(_cartao_categoria("🃏", tr("MENU_CAT_CARDS"),
		GameCatalog.get_card_games().size(), Color(ACENTO_CARTAS), MENU_CARTAS))
	return fila


func _cartao_categoria(emoji: String, nome: String, quantos: int, acento: Color, destino: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(0, ALTURA_CATEGORIA)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.focus_mode = Control.FOCUS_NONE
	UIKit.rolavel(b)
	for estado in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(estado,
			_estilo_cartao(acento, estado == "hover" or estado == "focus"))
	b.pressed.connect(_on_categoria_pressed.bind(destino))
	_sem_texto(b)

	var col := UIKit.vbox(6)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(col)

	var ico := UIKit.rotulo(emoji, FONTE_EMOJI)
	ico.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(ico)

	var tit := UIKit.rotulo(nome, UIKit.FONTE_SECAO, Color(0.96, 0.93, 0.86))
	tit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(tit)

	# `FILTER_COUNT` nasceu no menu de categorias, para a contagem da lista
	# filtrada. É a mesma frase, e duas chaves para "%d jogos" apodrecem.
	var conta := UIKit.rotulo(
		tr("FILTER_COUNT_ONE") if quantos == 1 else tr("FILTER_COUNT") % quantos,
		UIKit.FONTE_MIUDA, Color(0.82, 0.72, 0.52, 0.9))
	conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(conta)
	return b


func _on_categoria_pressed(destino: String) -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene(destino)


# -------------------------------------------------------------------- ajustes

func _secao_ajustes() -> VBoxContainer:
	var coluna := UIKit.vbox(12)

	var fila := UIKit.hbox(16)
	var som := UIKit.botao(_rotulo_som(), UIKit.FONTE_MIUDA)
	som.name = "BtnSom"
	som.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	som.clip_text = true
	som.pressed.connect(_on_som_pressed)
	fila.add_child(som)

	var idioma := UIKit.botao(tr("BTN_LANGUAGE"), UIKit.FONTE_MIUDA)
	idioma.name = "BtnIdioma"
	idioma.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	idioma.clip_text = true
	idioma.pressed.connect(_on_idioma_pressed)
	fila.add_child(idioma)
	coluna.add_child(fila)

	var rodape := UIKit.rotulo(tr("FOOTER_OFFLINE_PROMISE"), UIKit.FONTE_MIUDA, Color(0.65, 0.60, 0.52))
	rodape.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coluna.add_child(rodape)
	return coluna


func _rotulo_som() -> String:
	if AudioManager == null:
		return tr("SOUND_ON")
	return tr("SOUND_ON") if AudioManager.sound_enabled else tr("SOUND_OFF")


func _on_som_pressed() -> void:
	if AudioManager == null:
		return
	AudioManager.sound_enabled = not AudioManager.sound_enabled
	if AudioManager.sound_enabled:
		AudioManager.play_click()
	var b: Button = _corpo.find_child("BtnSom", true, false)
	if b != null:
		b.text = _rotulo_som()


func _on_idioma_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if LocaleManager:
		LocaleManager.cycle_locale()


# ------------------------------------------------------------------- comuns

## Os botoes desta tela nao tem texto proprio -- quem escreve sao os rotulos
## filhos. Ainda assim levam um tamanho de fonte: a regua de layout mede todo
## `Button`, com ou sem texto, e sem isto os tres apareceriam como texto de
## 16 px, que e o padrao do tema. Nada muda na tela.
func _sem_texto(b: Button) -> Button:
	b.add_theme_font_size_override("font_size", UIKit.FONTE_MIUDA)
	return b


func _cabecalho_secao(titulo: String, recado: String, cor: Color) -> HBoxContainer:
	var linha := UIKit.hbox(12)
	linha.add_child(UIKit.expandir(UIKit.rotulo(titulo, UIKit.FONTE_SECAO, UIKit.OURO)))
	if recado != "":
		var m := UIKit.rotulo(recado, UIKit.FONTE_MIUDA, cor)
		m.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		m.size_flags_horizontal = Control.SIZE_SHRINK_END
		linha.add_child(m)
	return linha
