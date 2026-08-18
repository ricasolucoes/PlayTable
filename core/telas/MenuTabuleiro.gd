extends Control

func _on_btn_c4_pressed():
	SceneManager.goto_scene("res://games/quatro_em_linha/ConnectFourGame.tscn")

func _on_btn_reversi_pressed():
	print("Em desenvolvimento")

func _on_btn_voltar_pressed():
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
