extends Control

func _play_game(path: String, title: String = ""):
	if AudioManager: AudioManager.play_click()
	if ResourceLoader.exists(path):
		SceneManager.goto_scene(path)
	else:
		SaveManager.set_setting("generic_game_title", title)
		SaveManager.set_setting("current_menu", "res://core/telas/MenuCartas.tscn")
		SceneManager.goto_scene("res://shared/GenericGame.tscn")

func _on_btn_paciencia_pressed():
	_play_game("res://games/paciencia/KlondikeGame.tscn", "Paciência (Klondike)")

func _on_btn_memoria_pressed():
	_play_game("res://games/memoria/MemoryGame.tscn", "Jogo da Memória")

func _on_btn_21_pressed():
	_play_game("res://games/blackjack/BlackjackGame.tscn", "21 (Blackjack)")

func _on_btn_unolike_pressed():
	_play_game("res://games/unolike/UnoLikeGame.tscn", "Jogo de Cores & Cartas")

func _on_btn_poker_pressed():
	_play_game("res://games/poker/PokerGame.tscn", "Poker Dice / Cartas")

func _on_btn_voltar_pressed():
	if AudioManager: AudioManager.play_click()
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
