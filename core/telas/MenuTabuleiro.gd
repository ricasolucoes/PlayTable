extends Control

func _play_game(path: String, title: String = ""):
	if AudioManager: AudioManager.play_click()
	if ResourceLoader.exists(path):
		SceneManager.goto_scene(path)
	else:
		SaveManager.set_setting("generic_game_title", title)
		SaveManager.set_setting("current_menu", "res://core/telas/MenuTabuleiro.tscn")
		SceneManager.goto_scene("res://shared/GenericGame.tscn")

func _on_btn_c4_pressed():
	_play_game("res://games/quatro_em_linha/ConnectFourGame.tscn", "Quatro em Linha")

func _on_btn_velha_pressed():
	_play_game("res://games/jogo_da_velha/TicTacToeGame.tscn", "Jogo da Velha")

func _on_btn_damas_pressed():
	_play_game("res://games/damas/CheckersGame.tscn", "Damas")

func _on_btn_batalha_pressed():
	_play_game("res://games/batalha_naval/BattleshipGame.tscn", "Batalha Naval")

func _on_btn_reversi_pressed():
	_play_game("res://games/reversi/ReversiGame.tscn", "Reversi")

func _on_btn_mancala_pressed():
	_play_game("res://games/mancala/MancalaGame.tscn", "Mancala")

func _on_btn_ludo_pressed():
	_play_game("res://games/ludo/LudoGame.tscn", "Ludo")

func _on_btn_senet_pressed():
	_play_game("res://games/senet/SenetGame.tscn", "Senet")

func _on_btn_solitario_pressed():
	_play_game("res://games/solitario/PegSolitaireGame.tscn", "Resta Um")

func _on_btn_campo_pressed():
	_play_game("res://games/campo_minado/MinesweeperGame.tscn", "Campo Minado")

func _on_btn_domino_pressed():
	_play_game("res://games/domino/DominoGame.tscn", "Dominó")

func _on_btn_voltar_pressed():
	if AudioManager: AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
