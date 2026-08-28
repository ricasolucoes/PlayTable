extends SceneTree

## Igual ao shot.gd, mas troca o idioma antes de capturar.
##
## Existe porque o idioma vem do perfil salvo, e nao da linha de comando: sem
## isto so da para conferir a tela na lingua em que a maquina esta, e uma
## traducao que estourou o botao so aparece no aparelho de quem fala aquela
## lingua.
##
## A ordem importa. O `LocaleManager` e autoload e escolhe o idioma no proprio
## `_ready`, ou seja, DEPOIS deste `_initialize`: trocar antes nao adianta, ele
## desfaz. Por isso a cena e montada, descartada e montada de novo -- os
## rotulos postos como chave no `.tscn` o Godot retraduz sozinho, mas os que o
## codigo escreve (o nome do jogo no cartao, o genero) sao lidos uma vez na
## montagem e nao voltam atras.
##
## `TranslationServer` direto, sem passar pelo `LocaleManager`, porque este
## grava a escolha: a captura nao pode mexer no idioma de quem joga aqui.
##
## Uso: Godot --path <proj> --script tools/shot_idioma.gd -- <idioma> <cena> <out.png> [frames] [w] [h]

func _initialize() -> void:
	var argv := OS.get_cmdline_user_args()
	if argv.size() < 3:
		push_error("uso: -- <idioma> <cena> <out.png> [frames] [w] [h]")
		quit(1)
		return
	var idioma: String = argv[0]
	var cena: String = argv[1]
	var saida: String = argv[2]
	var frames: int = int(argv[3]) if argv.size() > 3 else 45
	var w: int = int(argv[4]) if argv.size() > 4 else 720
	var h: int = int(argv[5]) if argv.size() > 5 else 1280

	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_EXPAND
	root.content_scale_size = Vector2i(w, h)
	root.size = Vector2i(w, h)

	var ps: PackedScene = load(cena)
	if ps == null:
		push_error("nao carregou %s" % cena)
		quit(2)
		return

	var descartavel := ps.instantiate()
	root.add_child(descartavel)
	for i in range(10):
		await process_frame

	TranslationServer.set_locale(idioma)
	root.remove_child(descartavel)
	descartavel.queue_free()

	root.add_child(ps.instantiate())
	for i in range(frames):
		await process_frame

	root.get_texture().get_image().save_png(saida)
	print("shot: %s (%s)" % [saida, TranslationServer.get_locale()])
	quit(0)
