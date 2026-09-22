extends Node

## Percorre as telas e os jogos no aparelho e grava uma captura de cada um em
## `user://device_shots/`. Existe porque o iPhone desenha diferente do desktop
## (Metal, renderer mobile, recorte do notch) e `tools/shot.gd` so enxerga o
## desktop. Liga com o argumento `--device-shots` ou com o arquivo
## `user://device_shots.flag`; sem nenhum dos dois o no nem nasce.

const FLAG := "user://device_shots.flag"
const OUT_DIR := "user://device_shots"
const FRAMES_POR_TELA := 150

const TELAS := [
	"res://core/telas/MainMenu.tscn",
	"res://core/telas/MenuTabuleiro.tscn",
	"res://core/telas/MenuCartas.tscn",
	"res://core/telas/PerfilScreen.tscn",
	"res://core/telas/LobbyScreen.tscn",
	"res://games/batalha_naval/BattleshipGame.tscn",
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/caminho_numerico/NumberPathGame.tscn",
	"res://games/campo_minado/MinesweeperGame.tscn",
	"res://games/copas/HeartsGame.tscn",
	"res://games/damas/CheckersGame.tscn",
	"res://games/domino/DominoGame.tscn",
	"res://games/gamao/BackgammonGame.tscn",
	"res://games/general/GeneralGame.tscn",
	"res://games/hanoi/HanoiGame.tscn",
	"res://games/jogo_da_velha/TicTacToeGame.tscn",
	"res://games/ludo/LudoGame.tscn",
	"res://games/mancala/MancalaGame.tscn",
	"res://games/memoria/MemoryGame.tscn",
	"res://games/nim/NimGame.tscn",
	"res://games/paciencia/KlondikeGame.tscn",
	"res://games/paciencia_spider/SpiderGame.tscn",
	"res://games/poker/PokerGame.tscn",
	"res://games/quatro_em_linha/ConnectFourGame.tscn",
	"res://games/reversi/ReversiGame.tscn",
	"res://games/senet/SenetGame.tscn",
	"res://games/solitario/PegSolitaireGame.tscn",
	"res://games/sudoku/SudokuGame.tscn",
	"res://games/trilha/MorrisGame.tscn",
	"res://games/unolike/UnoLikeGame.tscn",
	"res://games/xadrez/ChessGame.tscn",
]


static func pedido() -> bool:
	return OS.get_cmdline_user_args().has("--device-shots") \
		or OS.get_cmdline_args().has("--device-shots") \
		or FileAccess.file_exists(FLAG)


func _ready() -> void:
	_percorrer.call_deferred()


func _percorrer() -> void:
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	for velho in DirAccess.get_files_at(OUT_DIR):
		DirAccess.remove_absolute("%s/%s" % [OUT_DIR, velho])
	var so_uma := _filtro()
	if so_uma == "probe":
		await _sondar_materiais()
		return
	for caminho: String in TELAS:
		if so_uma != "" and not caminho.contains(so_uma):
			continue
		var nome := caminho.get_file().get_basename()
		print("DEVICE_SHOT_BEGIN ", nome)
		# Troca direta, sem o fade do SceneManager: a cena ja carregada volta
		# sincrona e o `scene_changed` sairia antes de alguem esperar por ele.
		var erro_troca := get_tree().change_scene_to_file(caminho)
		if erro_troca != OK:
			print("DEVICE_SHOT_FAIL %s err=%d" % [nome, erro_troca])
			continue
		for i in FRAMES_POR_TELA / 2:
			await get_tree().process_frame
		# As regras abrem sozinhas na primeira partida e cobririam a mesa.
		for painel in get_tree().root.find_children("*", "RulesPanel", true, false):
			if painel.is_open():
				painel.close()
		for i in FRAMES_POR_TELA / 2:
			await get_tree().process_frame
		print("DEVICE_SHOT_FRAMES ", nome, " paused=", get_tree().paused)
		await RenderingServer.frame_post_draw
		var imagem := get_viewport().get_texture().get_image()
		var destino := "%s/%s.png" % [OUT_DIR, nome]
		var erro := imagem.save_png(destino)
		print("DEVICE_SHOT %s %dx%d err=%d" % [nome, imagem.get_width(), imagem.get_height(), erro])
		_diagnostico(nome)
	print("DEVICE_SHOTS_DONE")
	DirAccess.remove_absolute(FLAG)
	get_tree().quit()


func _sondar_materiais() -> void:
	var sonda = load("res://core/debug/MaterialProbe.gd").new()
	get_tree().root.add_child(sonda)
	if get_tree().current_scene != null:
		get_tree().current_scene.visible = false
	for caso in sonda.casos():
		print("PROBE ", caso[0])
		sonda.mostrar(caso[1])
		for i in 20:
			await get_tree().process_frame
	print("PROBE_DONE")
	DirAccess.remove_absolute(FLAG)
	get_tree().quit()


## Estado dos atlas de carta depois de cada cena: o baralho e pintado num
## SubViewport em tempo de execucao, e e a parte que mais muda entre GPUs.
func _diagnostico(nome: String) -> void:
	var linhas: PackedStringArray = []
	for par in [["standard", CardAtlas3D], ["uno", UnoCardAtlas3D]]:
		var atlas = par[1]
		linhas.append("%s %s ready=%s err=%s" % [nome, par[0], atlas.is_ready(), atlas.last_error()])
		var arquivo := "%s/atlas_%s.png" % [OUT_DIR, par[0]]
		if atlas.is_ready() and not FileAccess.file_exists(arquivo):
			var tex: Texture2D = atlas._atlas
			if tex != null:
				tex.get_image().save_png(arquivo)
	var f := FileAccess.open("%s/diag.txt" % OUT_DIR, FileAccess.READ_WRITE if FileAccess.file_exists("%s/diag.txt" % OUT_DIR) else FileAccess.WRITE)
	if f != null:
		f.seek_end()
		f.store_string("\n".join(linhas) + "\n")


## O conteudo do arquivo de gatilho, se houver, restringe a volta a uma cena.
func _filtro() -> String:
	if not FileAccess.file_exists(FLAG):
		return ""
	return FileAccess.get_file_as_string(FLAG).strip_edges()
