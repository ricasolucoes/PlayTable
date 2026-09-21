extends GutTest

const SCENE_MANAGER := preload("res://addons/jogos_core/nav/scene_manager_autoload.gd")
const SCENE_LOADER := preload("res://addons/jogos_core/nav/jogos_scene_loader.gd")


func test_mobile_focus_out_is_not_treated_as_background_pause() -> void:
	assert_false(SCENE_MANAGER.should_pause_on_focus_out("iOS"),
		"o foco do iOS pode oscilar com espelhamento/ponteiro sem mandar a arvore dormir")
	assert_false(SCENE_MANAGER.should_pause_on_focus_out("Android"),
		"o foco do Android nao e o sinal de ciclo de vida")
	assert_true(SCENE_MANAGER.should_pause_on_focus_out("macOS"),
		"no desktop perder foco continua pausando a aplicacao")


func test_mobile_navigation_uses_the_safe_resource_loading_path() -> void:
	var loader: Node = add_child_autofree(SCENE_LOADER.new())
	assert_true(loader.has_method("uses_threaded_loading"),
		"o loader declara a politica de carregamento por plataforma")
	if not loader.has_method("uses_threaded_loading"):
		return
	assert_false(bool(loader.call("uses_threaded_loading", "iOS")),
		"o iOS nao fica preso esperando o worker de recursos")
	assert_false(bool(loader.call("uses_threaded_loading", "Android")),
		"o Android segue o mesmo caminho seguro")
	assert_true(bool(loader.call("uses_threaded_loading", "macOS")),
		"o desktop pode manter o carregamento em thread")
