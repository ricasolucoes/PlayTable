extends SceneTree

## Diagnostico de layout para as telas executadas no viewport logico de celular.
##
## Mantem a listagem completa fora do GUT, que resume as violacoes apos as seis
## primeiras. Execute com:
##   "$(scripts/godot_bin.sh)" --headless --path . -s tools/mobile_layout_audit.gd

const SCENES := [
	"res://core/telas/MainMenu.tscn",
	"res://core/telas/MenuTabuleiro.tscn",
	"res://core/telas/MenuCartas.tscn",
	"res://core/telas/PerfilScreen.tscn",
	"res://games/batalha_naval/BattleshipGame.tscn",
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/campo_minado/MinesweeperGame.tscn",
	"res://games/damas/CheckersGame.tscn",
	"res://games/domino/DominoGame.tscn",
	"res://games/gamao/BackgammonGame.tscn",
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
	"res://games/unolike/UnoLikeGame.tscn",
]

const VIEWPORTS := {
	"9:16": Vector2i(720, 1280),
	"20:9": Vector2i(720, 1600),
	"3:4": Vector2i(720, 960),
}


func _initialize() -> void:
	_audit()


func _audit() -> void:
	var total := 0
	for scene_path in SCENES:
		for label in VIEWPORTS:
			var size: Vector2i = VIEWPORTS[label]
			var viewport := SubViewport.new()
			viewport.size = size
			viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
			root.add_child(viewport)
			var scene := load(scene_path) as PackedScene
			if scene == null:
				print("LOAD ERROR: ", scene_path)
				viewport.queue_free()
				continue
			var instance := scene.instantiate()
			viewport.add_child(instance)
			for _frame in 3:
				await process_frame

			var seen := {}
			var screen := Rect2(Vector2.ZERO, Vector2(size))
			for control in _controls(instance):
				var target := _measurement_target(control)
				var key := target.get_path()
				if seen.has(key):
					continue
				seen[key] = true
				var rect := target.get_global_rect()
				if rect.size.x > 0.0 and rect.size.y > 0.0 and not screen.encloses(rect):
					total += 1
					print("%s | %s | %s | %s" % [
						scene_path.get_file(), label, target.get_path(), rect])
			instance.queue_free()
			viewport.queue_free()
			await process_frame
	print("TOTAL VIOLATIONS: ", total)
	quit(0)


func _controls(root_node: Node) -> Array[Control]:
	var found: Array[Control] = []
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Control and (node.is_class("Label") or node.is_class("BaseButton")) \
				and (node as Control).is_visible_in_tree():
			found.append(node)
		pending.append_array(node.get_children())
	return found


func _measurement_target(control: Control) -> Control:
	var node: Node = control.get_parent()
	while node != null:
		if node is ScrollContainer:
			return node
		node = node.get_parent()
	return control
