extends SceneTree

## Quem, dentro de uma area de rolagem, para o toque antes de ele chegar la.

const CENAS := [
	"res://core/telas/MainMenu.tscn",
	"res://core/telas/MenuTabuleiro.tscn",
	"res://core/telas/MenuCartas.tscn",
	"res://core/telas/PerfilScreen.tscn",
	"res://games/nim/NimGame.tscn",
	"res://games/hanoi/HanoiGame.tscn",
	"res://games/unolike/UnoLikeGame.tscn",
]

func _initialize() -> void:
	_rodar()

func _rolos(n: Node, saida: Array[ScrollContainer]) -> void:
	if n is ScrollContainer:
		saida.append(n)
	for f in n.get_children():
		_rolos(f, saida)

func _bloqueios(n: Node, saida: Array[String], raiz: Node) -> void:
	for f in n.get_children():
		if f is ScrollBar:
			continue
		if f is Control and (f as Control).mouse_filter == Control.MOUSE_FILTER_STOP:
			saida.append("%s (%s)" % [raiz.get_path_to(f), f.get_class()])
		_bloqueios(f, saida, raiz)

func _rodar() -> void:
	for caminho in CENAS:
		var vp := SubViewport.new()
		vp.size = Vector2i(720, 1280)
		vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
		root.add_child(vp)
		var ps: PackedScene = load(caminho)
		var no: Node = ps.instantiate()
		vp.add_child(no)
		for i in range(5):
			await process_frame
		var rolos: Array[ScrollContainer] = []
		_rolos(no, rolos)
		print("--- %s (%d area(s) de rolagem)" % [caminho.get_file(), rolos.size()])
		for sc in rolos:
			var b: Array[String] = []
			_bloqueios(sc, b, sc)
			if b.is_empty():
				print("    %s: livre" % sc.name)
			else:
				var conta := {}
				for x in b:
					var k: String = x.split("(")[-1]
					conta[k] = int(conta.get(k, 0)) + 1
				print("    %s: %d bloqueio(s) %s" % [sc.name, b.size(), conta])
				for x in b.slice(0, 4):
					print("        ", x)
		vp.queue_free()
		await process_frame
	quit(0)
