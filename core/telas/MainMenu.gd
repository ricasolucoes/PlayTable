extends Control

## Menu principal: navegação para as duas categorias, som, idioma e perfil.
##
## O cartão de progresso no topo dos botões é montado em código porque ele
## muda de conteúdo a cada abertura — nível, XP, sequência e o próximo marco.
## Era a peça que faltava: o jogador voltava ao menu depois de subir de nível e
## a tela não dizia nada, então a progressão só existia nos 1,7 s do aviso de
## recompensa dentro da partida.

var _cartao_perfil: Button
var _conteudo_perfil: VBoxContainer


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

	# O cartão *é* o botão, em vez de um cartão com um botão embaixo. Não é
	# economia de código: em 3:4 (720x960) os dois somavam ~220 px e empurravam
	# o rodapé para fora da tela — a régua de layout pegou. Como cartão-botão,
	# tocar no progresso leva ao progresso, que é para onde o dedo ia mesmo.
	_cartao_perfil = Button.new()
	_cartao_perfil.custom_minimum_size = Vector2(0, UIKit.TOQUE_MIN + 24)
	_cartao_perfil.pressed.connect(_on_btn_perfil_pressed)
	botoes.add_child(_cartao_perfil)
	botoes.move_child(_cartao_perfil, 0)

	_conteudo_perfil = UIKit.vbox(4)
	_conteudo_perfil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_conteudo_perfil.add_theme_constant_override("margin_left", 16)
	# Os filhos não podem interceptar o toque, senão o cartão deixa de ser botão.
	_conteudo_perfil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var margem := MarginContainer.new()
	margem.set_anchors_preset(Control.PRESET_FULL_RECT)
	margem.add_theme_constant_override("margin_left", 18)
	margem.add_theme_constant_override("margin_right", 18)
	margem.add_theme_constant_override("margin_top", 10)
	margem.add_theme_constant_override("margin_bottom", 10)
	margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
	margem.add_child(_conteudo_perfil)
	_cartao_perfil.add_child(margem)

	_atualizar_cartao_perfil()


func _atualizar_cartao_perfil() -> void:
	if _conteudo_perfil == null:
		return
	for filho in _conteudo_perfil.get_children():
		filho.queue_free()

	var r: Dictionary = EngagementManager.resumo()

	var topo := UIKit.hbox(10)
	topo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	topo.add_child(UIKit.expandir(UIKit.rotulo(
		"👤 " + tr("PROFILE_LEVEL") % r["level"], UIKit.FONTE_CORPO, UIKit.OURO)))
	if int(r["streak"]) > 0:
		topo.add_child(UIKit.rotulo("🔥 %d" % r["streak"], UIKit.FONTE_MIUDA, UIKit.TEXTO))
	_conteudo_perfil.add_child(topo)

	_conteudo_perfil.add_child(UIKit.barra(int(r["xp"]), int(r["xp_next"]), UIKit.OURO, 12.0))

	# Uma linha só, e sempre a mais próxima de fechar: o menu não é lugar de
	# listar tudo, é lugar de dar um motivo para tocar em jogar.
	var marco: Dictionary = EngagementManager.proximo_marco()
	var recado := ""
	if not marco.is_empty():
		recado = "🎯 " + (tr(str(marco["texto_key"])) % marco["args"])
	elif int(r["quests_pending"]) > 0:
		recado = "🎯 %s: %d" % [tr("PROFILE_DAILY"), r["quests_pending"]]
	if recado != "":
		var linha := UIKit.rotulo(recado, UIKit.FONTE_MIUDA, UIKit.TEXTO_FRACO)
		linha.clip_text = true
		linha.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_conteudo_perfil.add_child(linha)


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
