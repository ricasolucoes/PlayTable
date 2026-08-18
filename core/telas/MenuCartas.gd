extends Control

func _launch_generic(title: String):
	SaveManager.set_setting("current_generic_game", title)
	SaveManager.set_setting("current_menu", "res://core/telas/MenuCartas.tscn")
	SceneManager.goto_scene("res://shared/GenericGame.tscn")

func _on_btn_solitario_pressed(): _launch_generic("Solitário")

func _on_btn_memoria_pressed():
	SceneManager.goto_scene("res://games/memoria/MemoryGame.tscn")

func _on_btn_21_pressed(): _launch_generic("21 (Blackjack)")

func _on_btn_voltar_pressed():
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
