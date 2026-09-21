extends GutTest

const ReversiScene = preload("res://games/reversi/ReversiGame.tscn")
const LudoScene = preload("res://games/ludo/LudoGame.tscn")

const BAND_SCENES := [
	"res://games/blackjack/BlackjackGame.tscn",
	"res://games/paciencia/KlondikeGame.tscn",
	"res://games/poker/PokerGame.tscn",
	"res://games/sudoku/SudokuGame.tscn",
	"res://games/memoria/MemoryGame.tscn",
	"res://games/nim/NimGame.tscn",
	"res://games/hanoi/HanoiGame.tscn",
	"res://games/ludo/LudoGame.tscn",
]

const VALID_BANDS := [&"content", &"content_header", &"bottom"]


func _controls(root: Node) -> Array[Control]:
	var found: Array[Control] = []
	var pending: Array[Node] = [root]
	while not pending.is_empty():
		var node: Node = pending.pop_back()
		if node is Control:
			found.append(node as Control)
		pending.append_array(node.get_children())
	return found


func test_cenas_de_hud_proprio_declaram_banda_mobile() -> void:
	for path in BAND_SCENES:
		var scene := load(path) as PackedScene
		assert_not_null(scene, "%s carrega" % path)
		if scene == null:
			continue
		var instance := scene.instantiate()
		add_child_autofree(instance)
		var declarados := 0
		for control in _controls(instance):
			if control.has_meta("mobile_hud_band"):
				declarados += 1
		assert_gt(declarados, 0, "%s deve declarar pelo menos uma banda" % path)


func test_bandas_declaradas_usam_apenas_o_vocabulario_compartilhado() -> void:
	for path in BAND_SCENES:
		var scene := load(path) as PackedScene
		if scene == null:
			continue
		var instance := scene.instantiate()
		add_child_autofree(instance)
		for control in _controls(instance):
			if not control.has_meta("mobile_hud_band"):
				continue
			assert_true(StringName(str(control.get_meta("mobile_hud_band"))) in VALID_BANDS,
				"banda inválida em %s/%s" % [path, control.name])


func test_blackjack_monta_chrome_com_metricas_de_conteudo() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(720, 1280)
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child_autofree(viewport)
	var scene := load("res://games/blackjack/BlackjackGame.tscn") as PackedScene
	var game := scene.instantiate()
	viewport.add_child(game)
	await wait_process_frames(3)
	var chrome := game.get_node_or_null("TopBar") as GameTopBar
	assert_not_null(chrome)
	if chrome != null:
		assert_gt(chrome.content_top_px, 0.0)
		assert_not_null(chrome.mobile_metrics)
		assert_gte(chrome.content_bottom_px, chrome.content_top_px)


func test_reversi_fallback_materials_have_distinct_luminance() -> void:
	var preto := MaterialFactory3D.reversi_piece(1, "")
	var branco := MaterialFactory3D.reversi_piece(2, "")
	assert_ne(preto.albedo_color, branco.albedo_color)
	assert_lt(preto.albedo_color.get_luminance(), 0.25)
	assert_gt(branco.albedo_color.get_luminance(), 0.65)


func test_reversi_scene_creates_both_piece_signatures() -> void:
	var jogo = add_child_autofree(ReversiScene.instantiate())
	await wait_process_frames(3)
	jogo._sync_pieces_3d()
	var assinaturas: Array[String] = []
	for p in jogo.pieces_root.get_children():
		var material: StandardMaterial3D = p.call("get_visual_material") as StandardMaterial3D
		assert_not_null(material)
		if material != null:
			assinaturas.append(str(material.albedo_color))
	assert_true(assinaturas.size() >= 4)
	var tem_diferenca := false
	for assinatura in assinaturas.slice(1):
		if assinatura != assinaturas[0]:
			tem_diferenca = true
			break
	assert_true(tem_diferenca, "as duas faces tem assinaturas diferentes")


func test_ludo_pawns_have_procedural_fallback() -> void:
	var jogo = add_child_autofree(LudoScene.instantiate())
	await wait_process_frames(3)
	assert_eq(jogo.pawns_3d[0].size(), 4)
	for pawn in jogo.pawns_3d[0]:
		assert_eq(pawn.art_by_material["plastic_red"], "ludo/peao_vermelho")
		assert_not_null(pawn.get_visual_material())


func test_ludo_has_four_bases_track_finish_and_center() -> void:
	var jogo = add_child_autofree(LudoScene.instantiate())
	await wait_process_frames(3)
	assert_eq(jogo.visual_layer(&"HomeZones").get_child_count(), 4)
	assert_gte(jogo.visual_layer(&"Track").get_child_count(), 28)
	assert_gte(jogo.visual_layer(&"FinishLanes").get_child_count(), 16)
	assert_gt(jogo.visual_layer(&"Goal").get_child_count(), 0)
	assert_true(jogo.get_mobile_hud_metrics().bottom_rect.has_point(
		jogo.btn_dice.get_global_rect().get_center()))
