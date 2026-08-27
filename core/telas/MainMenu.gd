extends Control

## Menu principal: navegação para as duas categorias, som, idioma e perfil.
##
## O cartão de progresso no topo dos botões é montado em código porque ele
## muda de conteúdo a cada abertura — nível, XP, sequência e o próximo marco.
## Era a peça que faltava: o jogador voltava ao menu depois de subir de nível e
## a tela não dizia nada, então a progressão só existia nos 1,7 s do aviso de
## recompensa dentro da partida.

var _cartao_perfil: PanelContainer


func _ready() -> void:
	if LocaleManager and LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	_montar_cartao_perfil()
	_update_ui_texts()


func _on_locale_changed(_new_locale: String) -> void:
	_atualizar_cartao_perfil()
	_update_ui_texts()


# ------------------------------------------------------------ cartão de perfil

func _montar_cartao_perfil() -> void:
	var botoes: VBoxContainer = $VBoxContainer/VBoxButtons
	if botoes == null or EngagementManager == null:
		return

	_cartao_perfil = UIKit.cartao()
	_cartao_perfil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	botoes.add_child(_cartao_perfil)
	botoes.move_child(_cartao_perfil, 0)

	var abrir := UIKit.botao("👤 " + tr("MENU_PROFILE"), 26)
	abrir.pressed.connect(_on_btn_perfil_pressed)
	botoes.add_child(abrir)
	botoes.move_child(abrir, 1)

	_atualizar_cartao_perfil()


func _atualizar_cartao_perfil() -> void:
	if _cartao_perfil == null:
		return
	for filho in _cartao_perfil.get_children():
		filho.queue_free()

	var r: Dictionary = EngagementManager.resumo()
	var coluna := UIKit.vbox(6)
	coluna.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var topo := UIKit.hbox(10)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_child(UIKit.expandir(UIKit.rotulo(
		tr("PROFILE_LEVEL") % r["level"], UIKit.FONTE_CORPO, UIKit.OURO)))
	if int(r["streak"]) > 0:
		topo.add_child(UIKit.rotulo("🔥 %d" % r["streak"], UIKit.FONTE_MIUDA, UIKit.TEXTO))
	coluna.add_child(topo)

	coluna.add_child(UIKit.barra(int(r["xp"]), int(r["xp_next"]), UIKit.OURO, 16.0))

	# Uma linha só, e sempre a mais próxima de fechar: o menu não é lugar de
	# listar tudo, é lugar de dar um motivo para tocar em jogar.
	var marco: Dictionary = EngagementManager.proximo_marco()
	if not marco.is_empty():
		coluna.add_child(UIKit.paragrafo(
			"🎯 " + (tr(str(marco["texto_key"])) % marco["args"])))
	elif int(r["quests_pending"]) > 0:
		coluna.add_child(UIKit.rotulo(
			"🎯 %s: %d" % [tr("PROFILE_DAILY"), r["quests_pending"]],
			UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO))

	_cartao_perfil.add_child(coluna)


func _on_btn_perfil_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/PerfilScreen.tscn")

func _update_ui_texts() -> void:
	var title: Label = $VBoxContainer/HeaderCard/VBox/Title
	if title:
		title.text = tr("APP_TITLE")
	
	var subtitle: Label = $VBoxContainer/HeaderCard/VBox/Subtitle
	if subtitle:
		subtitle.text = tr("APP_SUBTITLE")
	
	var btn_tab: Button = $VBoxContainer/VBoxButtons/BtnTabuleiro
	if btn_tab:
		btn_tab.text = tr("MENU_BOARD_GAMES")
	
	var btn_cart: Button = $VBoxContainer/VBoxButtons/BtnCartas
	if btn_cart:
		btn_cart.text = tr("MENU_CARD_GAMES")
	
	var footer: Label = $VBoxContainer/Footer
	if footer:
		footer.text = tr("FOOTER_OFFLINE_PROMISE")
	
	_update_sound_button_label()
	_update_language_button_label()

func _update_sound_button_label() -> void:
	var btn: Button = $VBoxContainer/VBoxButtons/BtnSound
	if btn and AudioManager:
		btn.text = tr("SOUND_ON") if AudioManager.sound_enabled else tr("SOUND_OFF")

func _update_language_button_label() -> void:
	var btn: Button = $VBoxContainer/VBoxButtons/BtnLanguage
	if btn:
		btn.text = tr("BTN_LANGUAGE")

func _on_btn_tabuleiro_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")

func _on_btn_cartas_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")

func _on_btn_sound_toggle_pressed() -> void:
	if AudioManager:
		AudioManager.sound_enabled = not AudioManager.sound_enabled
		if AudioManager.sound_enabled:
			AudioManager.play_click()
		_update_sound_button_label()

func _on_btn_language_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	if LocaleManager:
		LocaleManager.cycle_locale()
