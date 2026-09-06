extends GutTest

## O caminho da arte gerada ate a mesa, com os arquivos AINDA ausentes.
##
## A cota do Gemini decide quando os PNG existem; o codigo que os consome nao
## pode depender disso. Estes testes fixam o contrato: chave sem arquivo cai no
## procedural sem mudar nada, e os dois consumidores novos (a moldura do
## CellHalo3D e o DecalGrid3D) funcionam com textura vinda da memoria.

const TOKEN := preload("res://shared/3d/Token3D.tscn")


# ------------------------------------------------------------ AssetCatalog

func test_arte_inexistente_devolve_null_sem_erro() -> void:
	assert_null(AssetCatalog.get_game_art("damas", "peca_que_nao_existe"))
	assert_null(AssetCatalog.get_game_art_by_key("chave_sem_barra"))
	assert_null(AssetCatalog.get_game_art_by_key("damas/peca_que_nao_existe"))
	assert_false(AssetCatalog.has_game_art("damas", "peca_que_nao_existe"))


func test_o_caminho_da_arte_e_o_que_o_gen_art_grava() -> void:
	assert_eq(AssetCatalog.game_art_path("campo_minado", "numeros"),
		"res://shared/assets/campo_minado/numeros.png")


# ------------------------------------------------------- MaterialFactory3D

func test_sem_arquivo_get_textured_devolve_o_proprio_fallback() -> void:
	var base := MaterialFactory3D.get_ivory()
	assert_same(MaterialFactory3D.get_textured("", base), base, "chave vazia")
	assert_same(MaterialFactory3D.get_textured("damas/nada", base), base, "arquivo ausente")


func test_token_com_chave_de_arte_sem_arquivo_fica_procedural() -> void:
	var peca: Token3D = add_child_autofree(TOKEN.instantiate())
	peca.material_name = "obsidian"
	peca.art_by_material = {"obsidian": "inexistente/disco_preto", "ivory": "inexistente/disco_branco"}
	peca.apply_material("obsidian")
	assert_same(peca.mesh_instance.material_override, MaterialFactory3D.get_obsidian(),
		"o material e o de sempre enquanto a arte nao existe")
	peca.apply_material("ivory")
	assert_same(peca.mesh_instance.material_override, MaterialFactory3D.get_ivory(),
		"a troca de material continua funcionando")


# --------------------------------------------------------------- CellHalo3D

func test_a_moldura_do_nim_e_um_alvo_por_canaleta() -> void:
	var halos: CellHalo3D = add_child_autofree(CellHalo3D.new())
	halos.setup_frames(3, Vector2(0.8, 4.5))
	halos.set_targets([Vector3(-1, 0, 0), Vector3(0, 0, 0), Vector3(1, 0, 0)])
	assert_eq(halos.multimesh.instance_count, 3)
	assert_eq(halos.multimesh.visible_instance_count, 0, "nasce apagada")
	# Quatro faixas de dois triangulos: 24 vertices.
	var arrays: Array = halos.multimesh.mesh.surface_get_arrays(0)
	assert_eq((arrays[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), 24)
	halos.light_only([1], Tokens3D.COLOR_SELECTED)
	assert_eq(halos.multimesh.visible_instance_count, 1, "so a canaleta escolhida acende")
	assert_eq(halos.color_of(1), Tokens3D.COLOR_SELECTED)
	assert_eq(halos.color_of(0), Color.TRANSPARENT)
	assert_eq(halos.position_of(2), Vector3(1, 0, 0))
	halos.clear()
	assert_eq(halos.multimesh.visible_instance_count, 0)


# -------------------------------------------------------------- DecalGrid3D

func _tira(cols: int) -> ImageTexture:
	var img := Image.create_empty(16 * cols, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	return ImageTexture.create_from_image(img)


func test_decalques_saem_de_um_atlas_so() -> void:
	var grade: DecalGrid3D = add_child_autofree(DecalGrid3D.new())
	grade.setup(_tira(8), 8, 1, 0.6, 81)
	assert_eq(grade.multimesh.instance_count, 81)
	assert_eq(grade.count(), 0)

	grade.place(Vector2i(0, 0), Vector3(0, 0, 0), 2)
	grade.place(Vector2i(4, 4), Vector3(1, 0, 1), 7)
	assert_eq(grade.count(), 2)
	assert_eq(grade.multimesh.visible_instance_count, 2)
	# A celula do "3" e a 2; cada decalque ocupa uma instancia, na ordem de entrada.
	assert_eq(grade.cell_of(Vector2i(0, 0)), 2)
	assert_eq(grade.cell_of(Vector2i(4, 4)), 7)
	assert_eq(grade.slot_of(Vector2i(4, 4)), 1)
	assert_eq(grade.position_of(Vector2i(4, 4)), Vector3(1, 0, 1))

	grade.place(Vector2i(0, 0), Vector3(0, 0, 0), 5)
	assert_eq(grade.count(), 2, "trocar a celula nao duplica o decalque")
	assert_eq(grade.cell_of(Vector2i(0, 0)), 5)

	grade.remove(Vector2i(0, 0))
	assert_eq(grade.count(), 1)
	assert_false(grade.has(Vector2i(0, 0)))
	assert_eq(grade.cell_of(Vector2i(0, 0)), -1)
	assert_eq(grade.slot_of(Vector2i(4, 4)), 0, "o que sobrou compacta para o comeco")
	assert_eq(grade.multimesh.visible_instance_count, 1)
	grade.clear()
	assert_eq(grade.multimesh.visible_instance_count, 0)


func test_a_celula_fora_do_atlas_e_presa_a_ultima() -> void:
	var grade: DecalGrid3D = add_child_autofree(DecalGrid3D.new())
	grade.setup(_tira(4), 4, 2, 0.5, 4)
	grade.place("a", Vector3.ZERO, 6)
	assert_eq(grade.cell_of("a"), 6)
	grade.place("b", Vector3.ZERO, 99)
	assert_eq(grade.cell_of("b"), 7, "numa grade 4x2 a ultima celula e a 7")
	grade.place("c", Vector3.ZERO, -3)
	assert_eq(grade.cell_of("c"), 0)


func test_a_capacidade_do_atlas_nao_estoura() -> void:
	var grade: DecalGrid3D = add_child_autofree(DecalGrid3D.new())
	grade.setup(_tira(2), 2, 1, 0.5, 2)
	grade.place("a", Vector3.ZERO, 0)
	grade.place("b", Vector3.ZERO, 1)
	grade.place("c", Vector3.ZERO, 1)
	assert_eq(grade.count(), 2, "o terceiro nao cabe e e recusado, sem estourar o buffer")
	assert_false(grade.has("c"))


func test_o_campo_minado_sem_atlas_continua_nos_labels() -> void:
	var jogo: Node = add_child_autofree((load("res://games/campo_minado/MinesweeperGame.tscn") as PackedScene).instantiate())
	await wait_process_frames(1)
	if jogo.numbers_grid != null:
		assert_not_null(jogo.numbers_grid, "com numeros.png ha grade de decalques")
		jogo._mostrar_numero(2, 2, 3)
		assert_true(jogo.numbers_grid.has(Vector2i(2, 2)), "o algarismo vai para o DecalGrid3D")
	else:
		assert_null(jogo.numbers_grid, "sem numeros.png nao ha grade de decalques")
		jogo._mostrar_numero(2, 2, 3)
		assert_eq(jogo.numbers_3d.size(), 1, "o algarismo vem como Label3D")
		assert_true(jogo.numbers_3d[Vector2i(2, 2)] is Label3D)


func test_atlas_entregue_tem_oito_celulas_quadradas() -> void:
	var atlas := AssetCatalog.get_game_art("campo_minado", "numeros")
	assert_not_null(atlas)
	if atlas == null:
		return
	assert_eq(atlas.get_width(), atlas.get_height() * 2)
	var jogo: Node = add_child_autofree((load("res://games/campo_minado/MinesweeperGame.tscn") as PackedScene).instantiate())
	assert_eq(jogo.numbers_grid._cols, 4)
	assert_eq(jogo.numbers_grid._rows, 2)
	for n in range(1, 9):
		jogo._mostrar_numero(0, n - 1, n)
		assert_eq(jogo.numbers_grid.cell_of(Vector2i(0, n - 1)), n - 1)
