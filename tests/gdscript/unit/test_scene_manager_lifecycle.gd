extends GutTest

const SCENE_MANAGER := preload("res://addons/jogos_core/nav/scene_manager_autoload.gd")


func test_mobile_focus_out_is_not_treated_as_background_pause() -> void:
	assert_false(SCENE_MANAGER.should_pause_on_focus_out("iOS"),
		"o foco do iOS pode oscilar com espelhamento/ponteiro sem mandar a arvore dormir")
	assert_false(SCENE_MANAGER.should_pause_on_focus_out("Android"),
		"o foco do Android nao e o sinal de ciclo de vida")
	assert_true(SCENE_MANAGER.should_pause_on_focus_out("macOS"),
		"no desktop perder foco continua pausando a aplicacao")
