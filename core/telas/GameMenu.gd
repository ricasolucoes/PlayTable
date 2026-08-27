class_name GameMenu
extends Control

## Tela que lista os jogos de uma categoria a partir do GameCatalog.
##
## MenuTabuleiro e MenuCartas eram o mesmo arquivo com duas linhas trocadas: a
## consulta ao catálogo e o caminho gravado para o placeholder saber de onde o
## jogador veio. Todo o resto — montar os botões, tocar o clique, decidir entre
## a cena do jogo e a tela de "em breve", voltar ao menu principal — era cópia.
##
## Um jogo por linha, e não dois por linha: em duas colunas a arte de cada jogo
## ficava com 320x145 px de viewport, e num telefone a meio metro do rosto isso
## é um selo. A linha inteira dá 672 px de largura para a mesma arte, o título
## sobe de 20 para 38 px e a tag de 13 para 27 — acima do piso de 14 sp que a
## régua de layout mede.
##
## Contrato para quem herda: responder `list_games()` e apontar
## `menu_scene_path` para a própria cena.

const GENERIC_GAME := "res://shared/GenericGame.tscn"
const MAIN_MENU := "res://core/telas/MainMenu.tscn"

## Altura de um cartão. Três cabem na área de rolagem em 9:16 e o quarto
## aparece cortado pela metade — a borda cortada é o que conta ao dedo que a
## lista continua abaixo.
const ALTURA_CARTAO := 300.0
const RAIO_CARTAO := 28

## Tipografia da lista. O piso de acessibilidade é 14 sp, que no viewport de
## 720 px de largura do projeto valem ~26 px
## (tests/gdscript/integration/test_layout_mobile.gd).
const FONTE_TITULO := 38
const FONTE_TAG := 27
const FONTE_OPCAO := 27
const FONTE_SECAO := 26

## Alvo de toque mínimo: 48 dp ≈ 88 px neste viewport.
const TOQUE_MIN := 88.0

## Onde a escolha do filtro sobrevive à partida. Voltar de um jogo instancia o
## menu de novo; sem isto o filtro se desfaria toda vez que o jogador jogasse,
## que é justamente quando ele acabou de usá-lo.
const CHAVE_MODO := "menu_filtro_modo"
const CHAVE_PROGRESSO := "menu_filtro_progresso"

## Se o jogador já abriu aquele jogo alguma vez. `TODOS` não olha o perfil.
## Guardado como `int` porque vai e volta do disco em JSON, onde tipo de enum
## não sobrevive.
enum Progresso { TODOS, JOGADOS, NUNCA }

## Caminho da própria cena. O GenericGame o lê para montar o botão de voltar.
var menu_scene_path: String = ""

## Bandeira de `GameDefinition.Mode`, ou 0 para "qualquer modo".
var filtro_modo: int = 0
var filtro_progresso: int = Progresso.TODOS

## O painel do filtro só nasce quando alguém toca no botão: enquanto está
## fechado ele não existe, e não há sete botões invisíveis na árvore.
var _overlay_filtro: Control = null

static var _degrade_scrim: GradientTexture2D = null


func _ready() -> void:
	_ler_filtro_salvo()
	var botao := _btn_filtro()
	if botao != null:
		botao.pressed.connect(_on_btn_filtro_pressed)
	_montar_lista()


## Os jogos que esta tela lista. Cada menu responde com a sua categoria.
func list_games() -> Array[GameDefinition]:
	return [] as Array[GameDefinition]


## Gênero e modos de uma entrada, na linha que o cartão mostra por baixo do
## título: "Estratégia • vs IA • 2 Jogadores".
##
## Antes isto era um `match` de dezenove caminhos de cena com o texto fixo em
## português dentro do menu — os nomes mudavam de idioma e a tag não. Agora sai
## do próprio catálogo, que é onde a informação nasce.
static func get_game_subtitle(game: GameDefinition) -> String:
	var partes: PackedStringArray = []
	if game.genre != "":
		partes.append(TranslationServer.translate(game.genre))
	for par in [
		[GameDefinition.Mode.SOLO, "TAG_MODE_SOLO"],
		[GameDefinition.Mode.AI, "TAG_MODE_AI"],
		[GameDefinition.Mode.VERSUS, "TAG_MODE_VERSUS"],
	]:
		if game.has_mode(par[0]):
			partes.append(TranslationServer.translate(par[1]))
	return " • ".join(partes)


static func get_game_intro_path(game: GameDefinition) -> String:
	if game.scene_path.begins_with("res://games/"):
		var parts := game.scene_path.split("/")
		if parts.size() >= 4:
			var folder := parts[3]
			var intro := "res://games/%s/intro.jpg" % folder
			if ResourceLoader.exists(intro):
				return intro
	return ""


# ------------------------------------------------------------------ a lista

func _lista() -> Container:
	return get_node_or_null("VBoxContainer/ScrollContainer/Lista") as Container


func _btn_filtro() -> Button:
	return get_node_or_null("VBoxContainer/TopBar/BtnFiltro") as Button


func _resumo() -> Label:
	return get_node_or_null("VBoxContainer/Resumo") as Label


func _montar_lista() -> void:
	var lista := _lista()
	if lista == null:
		return

	# Tirar da árvore antes de liberar: `queue_free` só acontece no fim do
	# quadro, e sem o `remove_child` os cartões antigos e os novos aparecem
	# empilhados no quadro em que o filtro muda.
	for child in lista.get_children():
		lista.remove_child(child)
		child.queue_free()

	var jogos := _jogos_filtrados()
	for game: GameDefinition in jogos:
		lista.add_child(_create_game_card(game))
	if jogos.is_empty():
		lista.add_child(_cartao_vazio())

	_atualizar_cabecalho(jogos.size())


func _jogos_filtrados() -> Array[GameDefinition]:
	var saida: Array[GameDefinition] = []
	for game: GameDefinition in list_games():
		if filtro_modo != 0 and not game.has_mode(filtro_modo):
			continue
		if not _passa_no_progresso(game):
			continue
		saida.append(game)
	return saida


func _passa_no_progresso(game: GameDefinition) -> bool:
	if filtro_progresso == Progresso.TODOS:
		return true
	var jogou := _ja_jogou(game)
	return jogou if filtro_progresso == Progresso.JOGADOS else not jogou


## Lê `per_game` direto em vez de chamar `PlayerProfile.game_stats()`: aquele
## cria a entrada do jogo quando ela não existe, e o menu passaria por todos os
## dezenove jogos gravando estatística zerada só por ter sido aberto.
func _ja_jogou(game: GameDefinition) -> bool:
	if PlayerProfile == null:
		return false
	var id := GameCatalog.game_id_of(game)
	return int(PlayerProfile.per_game.get(id, {}).get("matches", 0)) > 0


# ------------------------------------------------------------- o cartão

func _create_game_card(game: GameDefinition) -> Button:
	var accent := _game_accent(game)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, ALTURA_CARTAO)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_stylebox_override("normal", _sombra_cartao(accent, false))
	btn.add_theme_stylebox_override("hover", _sombra_cartao(accent, true))
	btn.add_theme_stylebox_override("pressed", _sombra_cartao(accent, false))
	btn.add_theme_stylebox_override("focus", _sombra_cartao(accent, true))

	# A arte sangra até a borda do cartão, e quem arredonda os cantos é o
	# recorte do próprio painel: `clip_contents` do botão recortaria num
	# retângulo, deixando os quatro cantos quadrados por cima da moldura.
	var fundo := Panel.new()
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	fundo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	fundo.add_theme_stylebox_override("panel", _fundo_cartao(accent))
	btn.add_child(fundo)

	var intro_path := get_game_intro_path(game)
	if intro_path != "":
		var arte := TextureRect.new()
		arte.texture = load(intro_path)
		arte.set_anchors_preset(Control.PRESET_FULL_RECT)
		arte.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arte.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		arte.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
		arte.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fundo.add_child(arte)
	else:
		var icone := Label.new()
		icone.text = game.icon
		icone.set_anchors_preset(Control.PRESET_FULL_RECT)
		icone.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		icone.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		icone.add_theme_font_size_override("font_size", 120)
		icone.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fundo.add_child(icone)

	# Véu escuro só na metade de baixo: texto branco sobre arte clara some, e
	# escurecer a arte inteira apagaria justamente o que faz o jogador escolher.
	var scrim := TextureRect.new()
	scrim.texture = _scrim()
	scrim.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	scrim.offset_top = -ALTURA_CARTAO * 0.62
	scrim.offset_bottom = 0.0
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(scrim)

	var textos := VBoxContainer.new()
	textos.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	textos.offset_left = 26.0
	textos.offset_right = -26.0
	textos.offset_top = -110.0
	textos.offset_bottom = -22.0
	textos.alignment = BoxContainer.ALIGNMENT_END
	textos.add_theme_constant_override("separation", 6)
	textos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundo.add_child(textos)

	var titulo := Label.new()
	titulo.text = game.title
	titulo.add_theme_font_size_override("font_size", FONTE_TITULO)
	titulo.add_theme_color_override("font_color", Color(0.99, 0.98, 0.95))
	titulo.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	titulo.add_theme_constant_override("shadow_offset_x", 1)
	titulo.add_theme_constant_override("shadow_offset_y", 3)
	titulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(titulo)

	var tag := Label.new()
	tag.text = get_game_subtitle(game)
	tag.add_theme_font_size_override("font_size", FONTE_TAG)
	tag.add_theme_color_override("font_color", Color(0.94, 0.84, 0.58))
	tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	textos.add_child(tag)

	# A moldura entra por último e por dentro do recorte: desenhada pelo botão
	# ela ficaria atrás da arte, que cobre o cartão inteiro.
	var moldura := Panel.new()
	moldura.set_anchors_preset(Control.PRESET_FULL_RECT)
	moldura.mouse_filter = Control.MOUSE_FILTER_IGNORE
	moldura.add_theme_stylebox_override("panel", _moldura_cartao(accent))
	fundo.add_child(moldura)

	# Num telefone não existe passar o mouse por cima: o único aviso de que o
	# toque pegou é o cartão afundar enquanto o dedo está nele.
	btn.button_down.connect(func() -> void: fundo.modulate = Color(0.78, 0.78, 0.80))
	btn.button_up.connect(func() -> void: fundo.modulate = Color.WHITE)
	btn.pressed.connect(_on_game_pressed.bind(game))
	return btn


static func _scrim() -> GradientTexture2D:
	if _degrade_scrim == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.45, 1.0])
		g.colors = PackedColorArray([
			Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.55), Color(0.02, 0.02, 0.04, 0.94),
		])
		_degrade_scrim = GradientTexture2D.new()
		_degrade_scrim.gradient = g
		_degrade_scrim.width = 8
		_degrade_scrim.height = 128
		_degrade_scrim.fill_from = Vector2(0, 0)
		_degrade_scrim.fill_to = Vector2(0, 1)
	return _degrade_scrim


func _fundo_cartao(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 1.0)
	style.set_corner_radius_all(RAIO_CARTAO)
	return style


func _moldura_cartao(accent: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0, 0, 0, 0)
	style.border_color = Color(accent.lightened(0.35), 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(RAIO_CARTAO)
	return style


## Só a sombra: o miolo do cartão é o painel recortado que vem por cima. O
## `bg_color` acompanha o acento para o antisserrilhado dos cantos não abrir
## uma linha clara entre a sombra e a arte.
func _sombra_cartao(accent: Color, destacado: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(accent, 1.0)
	style.set_corner_radius_all(RAIO_CARTAO)
	style.shadow_color = Color(0, 0, 0, 0.45 if destacado else 0.35)
	style.shadow_size = 16 if destacado else 10
	style.shadow_offset = Vector2(0, 6)
	return style


func _game_accent(game: GameDefinition) -> Color:
	match game.scene_path:
		"res://games/quatro_em_linha/ConnectFourGame.tscn": return Color("#1f66b8")
		"res://games/jogo_da_velha/TicTacToeGame.tscn": return Color("#203b66")
		"res://games/reversi/ReversiGame.tscn": return Color("#25864f")
		"res://games/batalha_naval/BattleshipGame.tscn": return Color("#183149")
		"res://games/damas/CheckersGame.tscn": return Color("#552d32")
		"res://games/mancala/MancalaGame.tscn": return Color("#8d4d22")
		_: return Color("#263b56")


## O que a lista mostra quando o filtro não deixa passar nenhum jogo. Sem isto
## a tela fica vazia e sem explicação, e o jogador não tem por onde desfazer.
func _cartao_vazio() -> Control:
	var cartao := UIKit.cartao()
	cartao.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 18)
	cartao.add_child(caixa)

	var aviso := Label.new()
	aviso.text = tr("FILTER_EMPTY")
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	aviso.add_theme_font_size_override("font_size", FONTE_OPCAO)
	aviso.add_theme_color_override("font_color", UIKit.TEXTO_FRACO)
	caixa.add_child(aviso)

	var limpar := Button.new()
	limpar.text = tr("FILTER_CLEAR")
	limpar.custom_minimum_size = Vector2(0, TOQUE_MIN)
	limpar.add_theme_font_size_override("font_size", FONTE_OPCAO)
	limpar.pressed.connect(_on_limpar_filtros)
	caixa.add_child(limpar)
	return cartao


# ------------------------------------------------------------------ o filtro

func _ler_filtro_salvo() -> void:
	if SaveManager == null:
		return
	filtro_modo = int(SaveManager.get_setting(CHAVE_MODO, 0))
	filtro_progresso = int(SaveManager.get_setting(CHAVE_PROGRESSO, Progresso.TODOS))


func _gravar_filtro() -> void:
	if SaveManager == null:
		return
	SaveManager.set_setting(CHAVE_MODO, filtro_modo)
	SaveManager.set_setting(CHAVE_PROGRESSO, filtro_progresso)


func _filtros_ativos() -> int:
	return int(filtro_modo != 0) + int(filtro_progresso != Progresso.TODOS)


## O botão de filtro e a linha de resumo dizem, juntos, que a lista está
## encurtada e por quê. Um filtro que sobrevive à partida sem aparecer na tela
## vira "sumiram jogos do meu aplicativo".
func _atualizar_cabecalho(quantos: int) -> void:
	var botao := _btn_filtro()
	if botao != null:
		var ativos := _filtros_ativos()
		botao.text = tr("BTN_FILTERS") if ativos == 0 else "%s •" % tr("BTN_FILTERS")
		botao.add_theme_color_override("font_color",
			UIKit.OURO if ativos > 0 else Color(0.96, 0.93, 0.86))

	var resumo := _resumo()
	if resumo == null:
		return
	if _filtros_ativos() == 0:
		resumo.visible = false
		return
	var partes: PackedStringArray = []
	if filtro_modo != 0:
		partes.append(tr(_chave_do_modo(filtro_modo)))
	if filtro_progresso != Progresso.TODOS:
		partes.append(tr("FILTER_PLAYED" if filtro_progresso == Progresso.JOGADOS else "FILTER_UNPLAYED"))
	var contagem := tr("FILTER_COUNT_ONE") if quantos == 1 else tr("FILTER_COUNT") % quantos
	resumo.text = "%s — %s" % [" · ".join(partes), contagem]
	resumo.visible = true


func _chave_do_modo(modo: int) -> String:
	match modo:
		GameDefinition.Mode.SOLO: return "FILTER_SOLO"
		GameDefinition.Mode.AI: return "FILTER_AI"
		GameDefinition.Mode.VERSUS: return "FILTER_VERSUS"
		_: return "FILTER_ALL"


func _on_btn_filtro_pressed() -> void:
	play_click()
	if _overlay_filtro != null and _overlay_filtro.visible:
		_fechar_filtro()
		return
	if _overlay_filtro == null:
		_overlay_filtro = _montar_painel_filtro()
		add_child(_overlay_filtro)
	_posicionar_painel()
	_overlay_filtro.visible = true


func _fechar_filtro() -> void:
	if _overlay_filtro != null:
		_overlay_filtro.visible = false


## O painel nasce colado embaixo do botão que o abriu, medindo o botão em tempo
## de execução — mexer no cabeçalho reposiciona o painel sozinho. Quando não
## couber até a borda de baixo, ele sobe até caber.
func _posicionar_painel() -> void:
	if _overlay_filtro == null:
		return
	var painel := _overlay_filtro.get_node_or_null("Painel") as Control
	var botao := _btn_filtro()
	if painel == null or botao == null:
		return
	var topo := botao.get_global_rect().end.y + 14.0
	var altura := painel.get_combined_minimum_size().y
	topo = clampf(topo, 24.0, maxf(24.0, size.y - 24.0 - altura))
	painel.offset_top = topo
	painel.offset_bottom = topo


func _montar_painel_filtro() -> Control:
	var overlay := Control.new()
	overlay.name = "FiltroOverlay"
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.visible = false

	# O véu escurece a lista e, sobretudo, engole o toque: sem ele o dedo que
	# erra o painel abre o jogo que estiver embaixo.
	var veu := ColorRect.new()
	veu.set_anchors_preset(Control.PRESET_FULL_RECT)
	veu.color = Color(0, 0, 0, 0.55)
	veu.mouse_filter = Control.MOUSE_FILTER_STOP
	veu.gui_input.connect(_on_veu_input)
	overlay.add_child(veu)

	var painel := PanelContainer.new()
	painel.name = "Painel"
	painel.anchor_left = 1.0
	painel.anchor_right = 1.0
	painel.offset_left = -24.0
	painel.offset_right = -24.0
	painel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	painel.grow_vertical = Control.GROW_DIRECTION_END
	overlay.add_child(painel)

	var caixa := VBoxContainer.new()
	caixa.add_theme_constant_override("separation", 14)
	painel.add_child(caixa)

	caixa.add_child(_secao("FILTER_MODE"))
	caixa.add_child(_grade_opcoes([
		["FILTER_ALL", 0], ["FILTER_SOLO", GameDefinition.Mode.SOLO],
		["FILTER_AI", GameDefinition.Mode.AI], ["FILTER_VERSUS", GameDefinition.Mode.VERSUS],
	], filtro_modo, _on_escolher_modo))

	var risca := HSeparator.new()
	caixa.add_child(risca)

	caixa.add_child(_secao("FILTER_PROGRESS"))
	caixa.add_child(_grade_opcoes([
		["FILTER_ALL", Progresso.TODOS], ["FILTER_PLAYED", Progresso.JOGADOS],
		["FILTER_UNPLAYED", Progresso.NUNCA],
	], filtro_progresso, _on_escolher_progresso))

	var pronto := Button.new()
	pronto.text = tr("FILTER_CLOSE")
	pronto.custom_minimum_size = Vector2(0, TOQUE_MIN)
	pronto.add_theme_font_size_override("font_size", FONTE_OPCAO)
	pronto.pressed.connect(func() -> void:
		play_click()
		_fechar_filtro())
	caixa.add_child(pronto)
	return overlay


func _secao(chave: String) -> Label:
	var l := Label.new()
	l.text = tr(chave).to_upper()
	l.add_theme_font_size_override("font_size", FONTE_SECAO)
	l.add_theme_color_override("font_color", UIKit.OURO_FRACO)
	return l


## Duas colunas: em uma só o painel passaria de 700 px de altura e não caberia
## abaixo do cabeçalho num telefone 3:4.
func _grade_opcoes(opcoes: Array, escolhido: int, aoEscolher: Callable) -> GridContainer:
	var grade := GridContainer.new()
	grade.columns = 2
	grade.add_theme_constant_override("h_separation", 12)
	grade.add_theme_constant_override("v_separation", 12)
	var grupo := ButtonGroup.new()
	for opcao: Array in opcoes:
		var valor := int(opcao[1])
		var b := Button.new()
		b.text = tr(opcao[0])
		b.toggle_mode = true
		b.button_group = grupo
		b.button_pressed = valor == escolhido
		b.custom_minimum_size = Vector2(190, TOQUE_MIN)
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", FONTE_OPCAO)
		b.add_theme_stylebox_override("pressed", _estilo_opcao(true))
		b.add_theme_stylebox_override("hover_pressed", _estilo_opcao(true))
		b.add_theme_color_override("font_pressed_color", Color(0.12, 0.09, 0.05))
		b.add_theme_color_override("font_hover_pressed_color", Color(0.12, 0.09, 0.05))
		b.pressed.connect(aoEscolher.bind(valor))
		grade.add_child(b)
	return grade


## A opção escolhida acende em ouro cheio. O estilo "pressed" do tema é escuro
## como o "normal" — serve para o instante do toque, não para dizer qual das
## quatro está valendo.
func _estilo_opcao(ligada: bool) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = UIKit.OURO if ligada else Color(0.20, 0.12, 0.08, 0.92)
	style.border_color = Color(0.98, 0.88, 0.55, 0.95)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style


func _on_veu_input(evento: InputEvent) -> void:
	if evento is InputEventMouseButton and (evento as InputEventMouseButton).pressed:
		_fechar_filtro()
	elif evento is InputEventScreenTouch and (evento as InputEventScreenTouch).pressed:
		_fechar_filtro()


func _on_escolher_modo(valor: int) -> void:
	play_click()
	filtro_modo = valor
	_gravar_filtro()
	_montar_lista()


func _on_escolher_progresso(valor: int) -> void:
	play_click()
	filtro_progresso = valor
	_gravar_filtro()
	_montar_lista()


func _on_limpar_filtros() -> void:
	play_click()
	filtro_modo = 0
	filtro_progresso = Progresso.TODOS
	_gravar_filtro()
	if _overlay_filtro != null:
		_overlay_filtro.queue_free()
		_overlay_filtro = null
	_montar_lista()


# ------------------------------------------------------------------ navegação

func _on_game_pressed(game: GameDefinition) -> void:
	play_click()
	if game.is_implemented and ResourceLoader.exists(game.scene_path):
		SceneManager.goto_scene(game.scene_path)
	else:
		SaveManager.set_setting("generic_game_title", game.title)
		SaveManager.set_setting("generic_game_intro", get_game_intro_path(game))
		SaveManager.set_setting("current_menu", menu_scene_path)
		SceneManager.goto_scene(GENERIC_GAME)


## Ligado no `.tscn` dos dois menus.
func _on_btn_voltar_pressed() -> void:
	play_click()
	SceneManager.goto_scene(MAIN_MENU)


func play_click() -> void:
	if AudioManager:
		AudioManager.play_click()
