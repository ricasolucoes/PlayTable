extends Node

## Manages scene transitions with a fade-to-black overlay.

var overlay: ColorRect

## Verdadeiro entre o início do escurecimento e a troca da cena. Sem isto, dois
## Voltar seguidos durante a transição empilham duas navegações.
var _navegando := false

func _ready() -> void:
	var canvas := CanvasLayer.new()
	canvas.layer = 100
	add_child(canvas)
	
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(overlay)
	
	# Garante que o Godot vai escutar o lifecycle do OS para não perder estado quando o Sidekick abrir
	get_tree().set_auto_accept_quit(false)
	# O Voltar do Android fechava o aplicativo INTEIRO, de qualquer tela.
	# `application/config/quit_on_go_back` nasce ligado, e nenhuma tela tratava
	# NOTIFICATION_WM_GO_BACK_REQUEST: quem apertava Voltar no meio de uma
	# partida -- o gesto mais natural do aparelho para sair de uma tela --
	# perdia o aplicativo, e não a tela. Desligado aqui, e não no
	# `project.godot`, porque este é o autoload que manda na navegação e o
	# ajuste passa a valer mesmo se alguém reescrever o arquivo de projeto.
	get_tree().set_quit_on_go_back(false)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_voltar_uma_tela()
		return
	if what != NOTIFICATION_APPLICATION_FOCUS_OUT and what != NOTIFICATION_APPLICATION_FOCUS_IN:
		return
	# O OS pode notificar foco antes de este autoload entrar na SceneTree.
	# Nessa janela nao ha arvore para pausar ainda. A pergunta e
	# `is_inside_tree()` e nao `get_tree() == null` porque o proprio `get_tree()`
	# imprime "Parameter data.tree is null" antes de devolver null: com a
	# segunda forma o travamento some, mas o erro continua na saida de toda
	# abertura.
	if not is_inside_tree():
		return
	get_tree().paused = what == NOTIFICATION_APPLICATION_FOCUS_OUT

## O Voltar do aparelho: uma tela para tras, e nao o aplicativo fora.
##
## Quem sabe para onde se volta e a propria tela -- o jogo volta ao menu da
## categoria, o menu da categoria ao menu principal --, entao a decisao e dela:
## quem implementa `voltar_do_aparelho()` e devolve `true` tratou o gesto. So
## quando ninguem trata -- o menu principal e o topo da pilha -- o aplicativo
## sai, que e o que o Android espera ali.
func _voltar_uma_tela() -> void:
	if _navegando:
		return
	var tela: Node = get_tree().current_scene
	if tela != null and tela.has_method("voltar_do_aparelho"):
		if bool(tela.call("voltar_do_aparelho")):
			return
	get_tree().quit()


func goto_scene(path: String) -> void:
	_navegando = true
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(overlay, "color:a", 1.0, 0.2)
	tween.tween_callback(_deferred_goto_scene.bind(path))
	tween.tween_property(overlay, "color:a", 0.0, 0.2)
	tween.tween_callback(func() -> void:
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_navegando = false)

func _deferred_goto_scene(path: String) -> void:
	var current_scene: Node = get_tree().current_scene
	if current_scene:
		current_scene.free()
	
	var next_scene: Resource = ResourceLoader.load(path)
	if next_scene:
		var instance: Node = next_scene.instantiate()
		get_tree().root.add_child(instance)
		get_tree().current_scene = instance
		# A musica de fundo acompanha a tela: menu fora dos jogos, e nos jogos
		# o clima que o catalogo da ao jogo.
		if AudioManager != null:
			AudioManager.play_music_for_scene(instance)
	else:
		push_error("SceneManager: Failed to load scene: %s" % path)
