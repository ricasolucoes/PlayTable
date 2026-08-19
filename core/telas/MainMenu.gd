extends Control

func _on_btn_tabuleiro_pressed():
	if AudioManager: AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MenuTabuleiro.tscn")

func _on_btn_cartas_pressed():
	if AudioManager: AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MenuCartas.tscn")

func _on_btn_sound_toggle_pressed():
	if AudioManager:
		AudioManager.sound_enabled = not AudioManager.sound_enabled
		if AudioManager.sound_enabled:
			AudioManager.play_click()
		_update_sound_button_label()

func _ready():
	_update_sound_button_label()

func _update_sound_button_label():
	var btn = $VBoxContainer/VBoxButtons/BtnSound
	if btn and AudioManager:
		btn.text = "🔊 Efeitos Sonoros: Ligados" if AudioManager.sound_enabled else "🔇 Efeitos Sonoros: Desligados"
