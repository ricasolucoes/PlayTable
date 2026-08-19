extends Control

## Main menu screen with navigation to board and card game categories,
## sound toggle, and language switching.

func _ready() -> void:
	if LocaleManager and LocaleManager.has_signal("locale_changed"):
		LocaleManager.locale_changed.connect(_on_locale_changed)
	_update_ui_texts()

func _on_locale_changed(_new_locale: String) -> void:
	_update_ui_texts()

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
