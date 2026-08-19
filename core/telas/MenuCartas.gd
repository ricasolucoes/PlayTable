extends Control

func _on_btn_paciencia_pressed():
	SceneManager.goto_scene("res://games/paciencia/KlondikeGame.tscn")

func _on_btn_memoria_pressed():
	SceneManager.goto_scene("res://games/memoria/MemoryGame.tscn")

func _on_btn_21_pressed():
	SceneManager.goto_scene("res://games/blackjack/BlackjackGame.tscn")

func _on_btn_unolike_pressed():
	SceneManager.goto_scene("res://games/unolike/UnoLikeGame.tscn")

func _on_btn_poker_pressed():
	SceneManager.goto_scene("res://games/poker/PokerGame.tscn")

func _on_btn_voltar_pressed():
	SceneManager.goto_scene("res://core/telas/MainMenu.tscn")
