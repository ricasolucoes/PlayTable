extends Control

## Tela de perfil: onde o progresso finalmente aparece.
##
## Antes desta tela o PlayTable calculava XP, nivel, sequencia diaria, maestria
## por jogo, ELO, liga e colecao -- e gravava tudo em disco -- sem que uma
## unica linha da interface lesse qualquer um desses numeros. O jogador podia
## ter 167 partidas e liga Prata e nao ver nada em lugar nenhum.
##
## Cinco abas, cada uma com um motivo de existir:
##
##   Resumo      o retrato do jogador e o proximo marco alcancavel
##   Missoes     o que da para fechar hoje e nesta semana
##   Conquistas  as 55, com barra de progresso -- "37/50 vitorias" motiva, um
##               cadeado fechado nao
##   Maestria    a trilha de cada jogo ja tocado, com recorde pessoal
##   Colecao     o que o progresso desbloqueia, e o que ainda falta para o resto
##
## A tela e montada em codigo em vez de `.tscn` porque e quase toda repeticao
## de cartao com barra: em cena seriam centenas de nos escritos a mao que
## precisariam ser refeitos a cada conquista nova.

const ABAS := ["overview", "quests", "achievements", "mastery", "collection"]
const ABA_KEYS := {
	"overview": "PROFILE_TAB_OVERVIEW",
	"quests": "PROFILE_TAB_QUESTS",
	"achievements": "PROFILE_TAB_ACHIEVEMENTS",
	"mastery": "PROFILE_TAB_MASTERY",
	"collection": "PROFILE_TAB_COLLECTION",
}

var _aba: String = "overview"
var _conteudo: VBoxContainer
var _cabecalho: VBoxContainer
var _botoes_aba: Dictionary = {}
var _tira_abas: ScrollContainer


func _ready() -> void:
	_montar()
	_atualizar_cabecalho()
	_trocar_aba("overview")
	if GameEventBus:
		GameEventBus.quest_progressed.connect(_on_mudou_quest)
		GameEventBus.achievement_unlocked.connect(_on_mudou_str)
		GameEventBus.xp_gained.connect(_on_mudou_xp)


func _on_mudou_quest(_a: String, _b: int, _c: int) -> void: _atualizar_cabecalho()
func _on_mudou_str(_a: String) -> void: _atualizar_cabecalho()
func _on_mudou_xp(_a: int, _b: String) -> void: _atualizar_cabecalho()


# ------------------------------------------------------------------ estrutura

func _montar() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)

	var fundo := preload("res://shared/ui/TabletopBackground.tscn").instantiate()
	add_child(fundo)

	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 24)
	margem.add_theme_constant_override("margin_right", 24)
	margem.add_theme_constant_override("margin_top", 40)
	margem.add_theme_constant_override("margin_bottom", 28)
	add_child(margem)

	var coluna := UIKit.vbox(16)
	margem.add_child(coluna)

	coluna.add_child(_barra_superior())

	var cartao_topo := UIKit.cartao()
	_cabecalho = UIKit.vbox(10)
	cartao_topo.add_child(_cabecalho)
	coluna.add_child(cartao_topo)

	coluna.add_child(_barra_de_abas())

	# O conteudo rola; o cabecalho e as abas ficam parados. Numa lista de 55
	# conquistas o jogador perde a referencia de onde esta sem isso.
	var rolagem := ScrollContainer.new()
	rolagem.size_flags_vertical = Control.SIZE_EXPAND_FILL
	rolagem.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	coluna.add_child(rolagem)

	_conteudo = UIKit.vbox(12)
	_conteudo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rolagem.add_child(_conteudo)


func _barra_superior() -> HBoxContainer:
	var barra := UIKit.hbox(12)
	var voltar := UIKit.botao(tr("BTN_BACK"), UIKit.FONTE_MIUDA)
	voltar.custom_minimum_size = Vector2(150, UIKit.TOQUE_MIN)
	voltar.pressed.connect(_voltar)
	barra.add_child(voltar)

	var titulo := UIKit.rotulo(tr("PROFILE_TITLE"), UIKit.FONTE_TITULO, UIKit.OURO)
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	barra.add_child(UIKit.expandir(titulo))

	# Espaco espelhando o botao voltar, para o titulo ficar mesmo no centro.
	var vazio := Control.new()
	vazio.custom_minimum_size = Vector2(150, 0)
	barra.add_child(vazio)
	return barra


func _barra_de_abas() -> ScrollContainer:
	var rolagem := ScrollContainer.new()
	rolagem.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	rolagem.custom_minimum_size = Vector2(0, UIKit.TOQUE_MIN + 8)

	_tira_abas = rolagem
	var linha := UIKit.hbox(8)
	rolagem.add_child(linha)

	for aba in ABAS:
		var b := UIKit.botao(tr(ABA_KEYS[aba]), UIKit.FONTE_MIUDA)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(120, UIKit.TOQUE_MIN)
		b.pressed.connect(_trocar_aba.bind(aba))
		linha.add_child(b)
		_botoes_aba[aba] = b
	return rolagem


func _voltar() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")


func _trocar_aba(aba: String) -> void:
	_aba = aba
	for id in _botoes_aba:
		_botoes_aba[id].button_pressed = (id == aba)
	# As cinco abas nao cabem na largura do telefone; a tira rola. Sem trazer a
	# selecionada para dentro do quadro, tocar na ultima visivel deixava a aba
	# ativa fora da tela.
	if _tira_abas != null and _botoes_aba.has(aba):
		_tira_abas.ensure_control_visible(_botoes_aba[aba])
	if AudioManager and _conteudo.get_child_count() > 0:
		AudioManager.play_click()

	for filho in _conteudo.get_children():
		filho.queue_free()

	match aba:
		"overview": _aba_resumo()
		"quests": _aba_missoes()
		"achievements": _aba_conquistas()
		"mastery": _aba_maestria()
		"collection": _aba_colecao()


# ------------------------------------------------------------------ cabecalho

func _atualizar_cabecalho() -> void:
	if _cabecalho == null:
		return
	for filho in _cabecalho.get_children():
		filho.queue_free()

	var r: Dictionary = EngagementManager.resumo()

	var topo := UIKit.hbox(14)
	topo.add_child(UIKit.rotulo("⭐", 40))
	var col := UIKit.vbox(4)
	col.add_child(UIKit.rotulo(tr("PROFILE_LEVEL") % r["level"], UIKit.FONTE_SECAO, UIKit.OURO))
	col.add_child(UIKit.rotulo(tr("PROFILE_XP") % [r["xp"], r["xp_next"]], UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	topo.add_child(UIKit.expandir(col))

	var liga := UIKit.vbox(4)
	liga.custom_minimum_size = Vector2(200, 0)
	var nome_liga := UIKit.rotulo(tr("LEAGUE_" + str(r["league"]).to_upper()), UIKit.FONTE_CORPO, UIKit.OURO)
	nome_liga.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	liga.add_child(nome_liga)
	var pontos := UIKit.rotulo(tr("PROFILE_ELO") % r["elo"], UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO)
	pontos.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	liga.add_child(pontos)
	topo.add_child(liga)
	_cabecalho.add_child(topo)

	_cabecalho.add_child(UIKit.barra(r["xp"], r["xp_next"]))

	var rodape := UIKit.hbox(10)
	var streak_txt := tr("PROFILE_STREAK") % r["streak"] if int(r["streak"]) > 0 else tr("PROFILE_STREAK_NONE")
	rodape.add_child(UIKit.expandir(UIKit.rotulo("🔥 " + streak_txt, UIKit.FONTE_MIUDA, UIKit.TEXTO)))
	if int(r["freezes"]) > 0:
		rodape.add_child(UIKit.rotulo("❄ %d" % r["freezes"], UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	_cabecalho.add_child(rodape)


# --------------------------------------------------------------------- resumo

func _aba_resumo() -> void:
	var r: Dictionary = EngagementManager.resumo()

	var marco: Dictionary = EngagementManager.proximo_marco()
	if not marco.is_empty():
		var c := UIKit.cartao()
		var v := UIKit.vbox(8)
		v.add_child(UIKit.paragrafo("🎯 " + (tr(str(marco["texto_key"])) % marco["args"]), UIKit.FONTE_CORPO, UIKit.OURO))
		v.add_child(UIKit.barra(int(round(float(marco["frac"]) * 100.0)), 100))
		c.add_child(v)
		_conteudo.add_child(c)

	var stats := UIKit.cartao()
	var lista := UIKit.vbox(10)
	var partidas := int(r["matches"])
	var vitorias := int(r["wins"])
	lista.add_child(UIKit.linha_valor(tr("PROFILE_MATCHES"), str(partidas)))
	lista.add_child(UIKit.linha_valor(tr("PROFILE_WINS"), str(vitorias)))
	lista.add_child(UIKit.linha_valor(tr("PROFILE_WINRATE"),
		"%d%%" % int(round(100.0 * vitorias / float(maxi(1, partidas)))) if partidas > 0 else "—"))
	lista.add_child(UIKit.linha_valor(tr("PROFILE_GAMES_TRIED"), "%d / %d" % [r["games_played"], r["games_total"]]))
	lista.add_child(UIKit.linha_valor(tr("PROFILE_LONGEST_STREAK"), str(r["longest_streak"])))
	lista.add_child(UIKit.linha_valor(tr("PROFILE_TAB_ACHIEVEMENTS"),
		"%d / %d" % [r["achievements"], r["achievements_total"]]))
	lista.add_child(UIKit.linha_valor(tr("PROFILE_TAB_COLLECTION"), "%d%%" % int(r["collection"])))
	stats.add_child(lista)
	_conteudo.add_child(stats)

	_conteudo.add_child(_cartao_liga())
	_conteudo.add_child(_cartao_play_games())


func _cartao_liga() -> PanelContainer:
	var c := UIKit.cartao()
	var v := UIKit.vbox(8)
	v.add_child(UIKit.rotulo(tr("PROFILE_LEAGUE"), UIKit.FONTE_SECAO, UIKit.OURO))

	var atual: Dictionary = LeagueSystem.get_current_league()
	var proxima: Dictionary = LeagueSystem.next_league()
	var prog: Vector2i = LeagueSystem.league_progress()

	v.add_child(UIKit.rotulo(tr("LEAGUE_" + str(atual["id"]).to_upper()), UIKit.FONTE_CORPO))
	v.add_child(UIKit.barra(prog.x, prog.y))
	if proxima.is_empty():
		v.add_child(UIKit.rotulo(tr("PROFILE_TOP_LEAGUE"), UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	else:
		v.add_child(UIKit.rotulo(tr("PROFILE_NEXT_LEAGUE") % [
			maxi(0, prog.y - prog.x), tr("LEAGUE_" + str(proxima["id"]).to_upper())],
			UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	c.add_child(v)
	return c


## Estado do Play Games. Fora do Android nao ha nada que ligar, e a tela diz
## isso em vez de mostrar um botao que nao faria nada.
func _cartao_play_games() -> PanelContainer:
	var c := UIKit.cartao()
	var v := UIKit.vbox(10)

	if PlayGamesManager.is_logged_in():
		v.add_child(UIKit.rotulo("🎮 " + tr("PGS_SIGNED_IN") % PlayGamesManager.player_name(),
			UIKit.FONTE_CORPO, UIKit.VERDE))
		var b := UIKit.botao("🏆 " + tr("PGS_ACHIEVEMENTS"))
		b.pressed.connect(PlayGamesManager.show_achievements)
		v.add_child(b)
		var l := UIKit.botao("📊 " + tr("PGS_LEADERBOARDS"))
		l.pressed.connect(PlayGamesManager.show_all_leaderboards)
		v.add_child(l)
	else:
		v.add_child(UIKit.rotulo("💾 " + tr("PGS_OFFLINE"), UIKit.FONTE_CORPO, UIKit.TEXTO_FRACO))
		if PlayGamesManager.is_available():
			var b := UIKit.botao(tr("PGS_SIGNED_IN") % "Play Games")
			b.pressed.connect(PlayGamesManager.sign_in_interactive)
			v.add_child(b)

	var fila := PlayGamesManager.queued_count()
	if fila > 0:
		v.add_child(UIKit.rotulo(tr("PGS_SYNC_PENDING") % fila, UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))

	c.add_child(v)
	return c


# -------------------------------------------------------------------- missoes

func _aba_missoes() -> void:
	for escopo in ["daily", "weekly"]:
		var missoes: Array = QuestEngine.quests_for_ui(escopo)
		if missoes.is_empty():
			continue
		_conteudo.add_child(UIKit.rotulo(
			tr("PROFILE_DAILY") if escopo == "daily" else tr("PROFILE_WEEKLY"),
			UIKit.FONTE_SECAO, UIKit.OURO))
		for q in missoes:
			_conteudo.add_child(_cartao_missao(q))

	if _conteudo.get_child_count() == 0:
		_conteudo.add_child(UIKit.rotulo(tr("PROFILE_NO_QUESTS"), UIKit.FONTE_CORPO, UIKit.TEXTO_FRACO))


func _cartao_missao(q: Dictionary) -> PanelContainer:
	var feito: bool = q["completed"]
	var c := UIKit.cartao(not feito)
	var v := UIKit.vbox(8)

	var topo := UIKit.hbox(10)
	topo.add_child(UIKit.expandir(UIKit.rotulo(
		("✅ " if feito else "") + tr(str(q["name_key"])),
		UIKit.FONTE_CORPO, UIKit.TEXTO_FRACO if feito else UIKit.TEXTO)))
	var xp := UIKit.rotulo("+%d XP" % q["xp"], UIKit.FONTE_MIUDA, UIKit.VERDE if feito else UIKit.OURO)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topo.add_child(xp)
	v.add_child(topo)

	v.add_child(UIKit.barra(int(q["progress"]), int(q["target"]),
		UIKit.VERDE if feito else UIKit.OURO))
	v.add_child(UIKit.rotulo(
		tr("PROFILE_QUEST_DONE") if feito else "%d / %d" % [q["progress"], q["target"]],
		UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))
	c.add_child(v)
	return c


# ----------------------------------------------------------------- conquistas

func _aba_conquistas() -> void:
	var catalogo: Array = AchievementEngine.catalog_for_ui()
	_conteudo.add_child(UIKit.rotulo(
		tr("PROFILE_ACH_COUNT") % [AchievementEngine.unlocked_count(), AchievementEngine.total_count()],
		UIKit.FONTE_SECAO, UIKit.OURO))

	var categoria_atual := ""
	for a in catalogo:
		if str(a["cat"]) != categoria_atual and not a["hidden"]:
			categoria_atual = str(a["cat"])
			_conteudo.add_child(UIKit.rotulo(
				tr("CAT_" + categoria_atual.to_upper()), UIKit.FONTE_CORPO, UIKit.OURO_FRACO))
		_conteudo.add_child(_cartao_conquista(a))


func _cartao_conquista(a: Dictionary) -> PanelContainer:
	var aberta: bool = a["unlocked"]
	var oculta: bool = a["hidden"]
	var c := UIKit.cartao(aberta)
	var v := UIKit.vbox(6)

	var topo := UIKit.hbox(12)
	topo.add_child(UIKit.rotulo("🏆" if aberta else ("❓" if oculta else "🔒"), 32))

	var col := UIKit.vbox(2)
	var nome := tr("PROFILE_ACH_HIDDEN") if oculta else tr(str(a["name_key"]))
	var desc := tr("PROFILE_ACH_HIDDEN_DESC") if oculta else tr(str(a["desc_key"]))
	col.add_child(UIKit.rotulo(nome, UIKit.FONTE_CORPO, UIKit.OURO if aberta else UIKit.TEXTO))
	col.add_child(UIKit.paragrafo(desc))
	topo.add_child(UIKit.expandir(col))

	var xp := UIKit.rotulo("+%d" % a["xp"], UIKit.FONTE_MIUDA, UIKit.VERDE if aberta else UIKit.TEXTO_FRACO)
	xp.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	topo.add_child(xp)
	v.add_child(topo)

	# Barra so onde ela informa: conquista de alvo 1 e sim ou nao, e a barra da
	# oculta entregaria o que falta para achar o segredo.
	if not aberta and not oculta and int(a["target"]) > 1:
		v.add_child(UIKit.barra(int(a["progress"]), int(a["target"]), UIKit.OURO_FRACO, 10.0))
		v.add_child(UIKit.rotulo("%d / %d" % [a["progress"], a["target"]],
			UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))

	c.add_child(v)
	return c


# ------------------------------------------------------------------- maestria

func _aba_maestria() -> void:
	var trilhas: Array = MasteryEngine.mastery_for_ui()
	if trilhas.is_empty():
		_conteudo.add_child(UIKit.rotulo(tr("PROFILE_NO_MASTERY"), UIKit.FONTE_CORPO, UIKit.TEXTO_FRACO))
		return

	for m in trilhas:
		var c := UIKit.cartao()
		var v := UIKit.vbox(8)

		var topo := UIKit.hbox(12)
		topo.add_child(UIKit.rotulo(str(m["icon"]), 34))
		var col := UIKit.vbox(2)
		col.add_child(UIKit.rotulo(str(m["title"]), UIKit.FONTE_CORPO))
		col.add_child(UIKit.rotulo(tr("PROFILE_MASTERY_LEVEL") % m["level"], UIKit.FONTE_MIUDA, UIKit.OURO))
		topo.add_child(UIKit.expandir(col))

		var placar := UIKit.rotulo("🏆 %d/%d" % [m["wins"], m["matches"]], UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO)
		placar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		topo.add_child(placar)
		v.add_child(topo)

		v.add_child(UIKit.barra(int(m["xp"]), int(m["xp_next"])))

		var recorde: String = LeaderboardSync.personal_best(str(m["id"]))
		if recorde != "":
			v.add_child(UIKit.rotulo(tr("PROFILE_BEST_TIME") % recorde, UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))

		c.add_child(v)
		_conteudo.add_child(c)


# -------------------------------------------------------------------- colecao

func _aba_colecao() -> void:
	_conteudo.add_child(UIKit.rotulo(tr("PROFILE_COLLECTION_COUNT") % [
		CollectionSystem.unlocked_items.size(), CollectionSystem.total_count()],
		UIKit.FONTE_SECAO, UIKit.OURO))

	for tipo in ["table", "card", "avatar"]:
		var itens: Array = CollectionSystem.collection_for_ui(tipo)
		if itens.is_empty():
			continue
		for item in itens:
			_conteudo.add_child(_cartao_item(item))


func _cartao_item(item: Dictionary) -> PanelContainer:
	var aberto: bool = item["unlocked"]
	var c := UIKit.cartao(aberto)
	var linha := UIKit.hbox(12)

	linha.add_child(UIKit.rotulo("🎨" if aberto else "🔒", 30))
	var col := UIKit.vbox(2)
	col.add_child(UIKit.rotulo(tr(str(item["name_key"])), UIKit.FONTE_CORPO,
		UIKit.TEXTO if aberto else UIKit.TEXTO_FRACO))
	col.add_child(UIKit.paragrafo(_condicao(item["rule"])))
	linha.add_child(UIKit.expandir(col))

	if aberto:
		if item["equipped"]:
			linha.add_child(UIKit.rotulo("✓ " + tr("PROFILE_EQUIPPED"), UIKit.FONTE_MIUDA, UIKit.VERDE))
		else:
			var b := UIKit.botao(tr("PROFILE_EQUIP"), UIKit.FONTE_MIUDA)
			b.custom_minimum_size = Vector2(150, UIKit.TOQUE_MIN)
			b.pressed.connect(_equipar.bind(str(item["id"])))
			linha.add_child(b)
	else:
		linha.add_child(UIKit.rotulo(tr("PROFILE_LOCKED"), UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))

	c.add_child(linha)
	return c


## Traduz a regra de desbloqueio para uma frase. O item bloqueado mostra o que
## falta: esconder a condicao transforma a colecao em loteria.
func _condicao(rule: Dictionary) -> String:
	match str(rule.get("type", "")):
		"level": return tr("UNLOCK_LEVEL") % int(rule.get("value", 1))
		"streak": return tr("UNLOCK_STREAK") % int(rule.get("value", 1))
		"mastery": return tr("UNLOCK_MASTERY") % int(rule.get("value", 1))
		"league": return tr("UNLOCK_LEAGUE") % tr("LEAGUE_" + str(rule.get("value", "")).to_upper())
		"achievement": return tr("UNLOCK_ACHIEVEMENT") % tr(str(rule.get("value", "")) + "_NAME")
		_: return tr("UNLOCK_DEFAULT")


func _equipar(item_id: String) -> void:
	if CollectionSystem.equip(item_id):
		if AudioManager:
			AudioManager.play_click()
		_trocar_aba("collection")
