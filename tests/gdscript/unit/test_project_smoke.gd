extends GutTest

## Fumaca: garante que o projeto real carrega headless.
##
## Se este arquivo falhar, nenhum outro teste da suite significa nada — quer
## dizer que o Godot nao conseguiu abrir o projeto de producao.

func test_autoloads_estao_registrados() -> void:
	var root := get_tree().root
	for nome in ["SaveManager", "LocaleManager", "SceneManager", "AudioManager"]:
		assert_not_null(root.get_node_or_null(NodePath(nome)), "autoload %s ausente" % nome)


func test_cena_principal_existe() -> void:
	var main: String = ProjectSettings.get_setting("application/run/main_scene", "")
	assert_ne(main, "", "application/run/main_scene nao configurada")
	assert_true(ResourceLoader.exists(main), "cena principal ausente: %s" % main)


func test_todas_as_cenas_de_jogo_carregam() -> void:
	var faltando: Array[String] = []
	for def in GameCatalog.get_all_games():
		if not ResourceLoader.exists(def.scene_path):
			faltando.append(def.scene_path)
	assert_eq(faltando, [] as Array[String], "cenas do catalogo que nao carregam")
