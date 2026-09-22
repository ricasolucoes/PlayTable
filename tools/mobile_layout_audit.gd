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
	"res://games/sudoku/SudokuGame.tscn",
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

			var screen := Rect2(Vector2.ZERO, Vector2(size))
			var chrome := _find_chrome(instance)
			var chrome_top := chrome.content_top_px if chrome != null else 0.0
			for control in _controls(instance):
				var target := _measurement_target(control)
				var rect := target.get_global_rect()
				if rect.size.x > 0.0 and rect.size.y > 0.0 and not screen.encloses(rect):
					total += 1
					print("OUT_OF_SAFE_AREA | %s | %s | %s | %s | expected=%s" % [
						scene_path.get_file(), label, target.get_path(), rect, _band_for(target)])
				if chrome != null and not chrome.is_ancestor_of(target) \
						and not _tem_overlay(target) \
						and Rect2(0.0, 0.0, float(size.x), chrome_top).intersects(rect):
					total += 1
					print("UNDER_CHROME | %s | %s | %s | %s | %s | expected=%s" % [
						scene_path.get_file(), label, target.get_path(), rect, chrome_top, _band_for(target)])

			for overlap in find_overlaps(instance):
				total += 1
				print("OVERLAP | %s | %s | %s | %s | expected=%s/%s" % [
					scene_path.get_file(), overlap["a"], overlap["b"], overlap["rect"],
					_band_for_path(instance, overlap["a"]), _band_for_path(instance, overlap["b"])])
			instance.queue_free()
			viewport.queue_free()
			await process_frame
	print("TOTAL VIOLATIONS: ", total)
	quit(1 if total > 0 else 0)


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


func _find_chrome(root_node: Node) -> GameTopBar:
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is GameTopBar:
			return node as GameTopBar
		pending.append_array(node.get_children())
	return null


func _band_for(control: Control) -> String:
	var node: Node = control
	while node != null:
		if node.has_meta("mobile_hud_band"):
			return str(node.get_meta("mobile_hud_band"))
		node = node.get_parent()
	return "unregistered"


func _band_for_path(root_node: Node, path: NodePath) -> String:
	var node := root_node.get_node_or_null(path)
	return _band_for(node as Control) if node is Control else "unregistered"


## Retorna cada colisão real entre controles irmãos/independentes. Containers
## ancestrais não contam: o retângulo do pai naturalmente contém os filhos.
## Esta função também é usada pela régua do GUT para que o audit standalone e
## os testes de layout tenham exatamente a mesma definição de sobreposição.
static func find_overlaps(root_node: Node) -> Array[Dictionary]:
	var controls: Array[Control] = []
	var pending: Array[Node] = [root_node]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Control and (node as Control).is_visible_in_tree():
			var control := node as Control
			var viewport_size := control.get_viewport_rect().size
			var is_screen_sized := viewport_size.x > 0.0 and viewport_size.y > 0.0 \
					and control.size.x >= viewport_size.x * 0.98 \
					and control.size.y >= viewport_size.y * 0.98
			if node != root_node and not is_screen_sized and _is_surface(control) \
					and control.size.x > 0.0 and control.size.y > 0.0:
				controls.append(control)
		pending.append_array(node.get_children())

	var overlaps: Array[Dictionary] = []
	for i in controls.size():
		for j in range(i + 1, controls.size()):
			var a := controls[i]
			var b := controls[j]
			if a.is_ancestor_of(b) or b.is_ancestor_of(a) or _pode_sobrepor(a, b):
				continue
			var intersection := a.get_global_rect().intersection(b.get_global_rect())
			if intersection.size.x <= 1.0 or intersection.size.y <= 1.0:
				continue
			overlaps.append({
				"a": a.get_path(),
				"b": b.get_path(),
				"rect": intersection,
			})
	return overlaps


static func _pode_sobrepor(a: Control, b: Control) -> bool:
	return _tem_overlay(a) or _tem_overlay(b) \
			or a.z_index != b.z_index and (a.get_class() == "PopupPanel" or b.get_class() == "PopupPanel")


static func _tem_overlay(control: Control) -> bool:
	var node: Node = control
	while node != null:
		if node.get_meta("allow_overlay", false):
			return true
		node = node.get_parent()
	return false


static func _is_surface(control: Control) -> bool:
	# Containers de composição ocupam a banda inteira, mas não desenham uma
	# superfície própria. Seus filhos continuam na fila e são auditados.
	return not control is Container or control is PanelContainer
