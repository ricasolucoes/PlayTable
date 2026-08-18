extends Control

func _on_btn_c4_pressed():
	SceneManager.goto_scene("res://games/quatro_em_linha/ConnectFourGame.tscn")

func _launch_generic(title: String):
	SaveManager.set_setting("current_generic_game", title)
	SaveManager.set_setting("current_menu", "res://core/telas/MenuTabuleiro.tscn")
	SceneManager.goto_scene("res://shared/GenericGame.tscn")

func _on_btn_reversi_pressed(): _launch_generic("Reversi")
func _on_btn_batalha_pressed(): _launch_generic("Batalha Naval")
func _on_btn_damas_pressed(): _launch_generic("Damas")
func _on_btn_mancala_pressed(): _launch_generic("Mancala")

func _on_btn_velha_pressed():
	SceneManager.goto_scene("res://games/jogo_da_velha/TicTacToeGame.tscn")

func _on_btn_voltar_pressed():
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
