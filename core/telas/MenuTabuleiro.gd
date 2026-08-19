extends Control

func _on_btn_c4_pressed():
	SceneManager.goto_scene("res://games/quatro_em_linha/ConnectFourGame.tscn")

func _on_btn_velha_pressed():
	SceneManager.goto_scene("res://games/jogo_da_velha/TicTacToeGame.tscn")

func _on_btn_damas_pressed():
	SceneManager.goto_scene("res://games/damas/CheckersGame.tscn")

func _on_btn_batalha_pressed():
	SceneManager.goto_scene("res://games/batalha_naval/BattleshipGame.tscn")

func _on_btn_reversi_pressed():
	SceneManager.goto_scene("res://games/reversi/ReversiGame.tscn")

func _on_btn_mancala_pressed():
	SceneManager.goto_scene("res://games/mancala/MancalaGame.tscn")

func _on_btn_ludo_pressed():
	SceneManager.goto_scene("res://games/ludo/LudoGame.tscn")

func _on_btn_senet_pressed():
	SceneManager.goto_scene("res://games/senet/SenetGame.tscn")

func _on_btn_solitario_pressed():
	SceneManager.goto_scene("res://games/solitario/PegSolitaireGame.tscn")

func _on_btn_campo_pressed():
	SceneManager.goto_scene("res://games/campo_minado/MinesweeperGame.tscn")

func _on_btn_domino_pressed():
	SceneManager.goto_scene("res://games/domino/DominoGame.tscn")

func _on_btn_voltar_pressed():
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
