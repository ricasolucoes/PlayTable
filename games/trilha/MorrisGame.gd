extends BaseGame

## Trilha (Nine Men's Morris) numa mesa 3D: tabuleiro proprio de nogueira com
## as linhas e os 24 pontos em bordo claro, pecas de marfim e obsidiana, e as
## que ainda nao entraram empilhadas em duas bandejas fora do tabuleiro.
##
## Toda jogada -- da pessoa, da maquina ou do outro aparelho -- passa por
## `_aplicar()`, que e o unico lugar que mexe no estado e na mesa. O toque
## entra pelo `DragPicker3D` com os 24 pontos e as duas bandejas como alvos:
## na colocacao toca-se o ponto (ou arrasta-se a peca da bandeja ate ele); no
## movimento toca-se a peca e depois o destino aceso, ou arrasta-se; na
## captura toca-se a peca adversaria acesa em vermelho.

const TOKEN_SCENE := preload("res://shared/3d/Token3D.tscn")

## Arte gerada de cada peca (`tools/art/trilha.json`); sem o arquivo fica o
## procedural.
const ART_PECAS := {"ivory": "trilha/peca_clara", "obsidian": "trilha/peca_escura"}

## Geometria da mesa, em unidades de mundo.
const PASSO := 0.88                  # uma unidade de grade das COORDS
const LADO_TABULEIRO := 6.3
const ESPESSURA_TABULEIRO := 0.16
const TOPO := 0.12                   # altura do tampo
const ALTURA_LINHA := 0.02
const LARGURA_LINHA := 0.07
const RAIO_PONTO := 0.21
const ALTURA_PONTO := 0.03
const RAIO_PECA := 0.30
const RAIO_HALO := 0.40
const BANDEJA_Z := 3.7               # centro de cada bandeja, fora do tabuleiro
const BANDEJA_TAM := Vector2(6.0, 0.9)
const BANDEJA_ESPESSURA := 0.10
const BANDEJA_TOPO := 0.06
const PASSO_BANDEJA := 0.64
## Tabuleiro mais as duas bandejas, para o enquadramento.
const PROFUNDIDADE_MESA := 8.3

## Pausa de encenacao antes da maquina jogar e entre a trilha e a captura dela.
const PAUSA_IA := 0.45
const PAUSA_CAPTURA_IA := 0.6

var estado: Dictionary = {}
var mesa: SeatTable = null
var vs_ai: bool = true
var ai_level: int = DifficultyManager.DEFAULT_LEVEL

var halos: CellHalo3D = null
var picker: DragPicker3D = null

## As 18 pecas: 0..8 brancas (marfim), 9..17 pretas (obsidiana).
var pecas: Array = []
## Ponto -> indice da peca que esta nele, ou -1.
var ponto_peca: PackedInt32Array = PackedInt32Array()
## Por lado, as pecas ainda na bandeja; a ultima e a proxima a entrar.
var mao_pecas: Array = [[], [], []]

## A peca escolhida para mover (ponto), ou -1.
var selecionada: int = -1
## Os pontos do ultimo lance, para o anel azul.
var ultimo_lance: PackedInt32Array = PackedInt32Array()

## Quem fechou quantas trilhas nesta partida e quem fechou duas de uma vez:
## sao os fatos que a gamificacao recebe no fim.
var _moinhos_fechados: PackedInt32Array = PackedInt32Array([0, 0, 0])
var _dupla_fechada: Array = [false, false, false]

## Aviso de uma captura sofrida, mostrado junto com a vez seguinte.
var _aviso: String = ""

## Peca em arrasto e de onde ela saiu (um ponto, ou o id da bandeja).
var _arrasto_peca: int = -1
var _arrasto_origem: Variant = null

## A busca da IA esta no ar. `_geracao` sobe a cada partida nova para o
## resultado de uma busca da partida anterior ser descartado ao chegar.
var _ia_pensando: bool = false
var _geracao: int = 0

## -1 quando este aparelho joga de pretas em rede: a mesa gira meia volta para
## as pecas de quem esta aqui ficarem embaixo, como numa mesa de verdade.
var _sinal: float = 1.0

@onready var board_root: Node3D = $BoardRoot
@onready var pieces_root: Node3D = $PiecesRoot
@onready var shell: GameShell = $GameShell


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(restart_game)
	# Tampo claro de pedra: o tabuleiro de nogueira precisa de contraste com a
	# mesa, e o salao de nogueira o engoliria.
	env_3d.apply_theme(GameTheme3D.stone_gallery())
	ai_level = DifficultyManager.get_level(game_id)

	_montar_tabuleiro()
	_montar_pecas()
	_montar_toque()

	# Antes do fit_table: e HUD ancorada e precisa ser medida.
	if top_bar != null:
		top_bar.oferecer_modo(vs_ai)
		top_bar.mode_pressed.connect(_on_modo_trocado)

	# Tabuleiro quadrado e raso: a camera pode ir quase de cima, e em retrato e
	# isso que faz o tabuleiro ocupar a largura inteira.
	fit_table(Vector2(LADO_TABULEIRO, PROFUNDIDADE_MESA), Vector3.ZERO, 82.0)
	_start_new_game()
	begin_match(_modo())


# =================================================================== mesa 3D

func _montar_tabuleiro() -> void:
	for c in board_root.get_children():
		c.queue_free()

	var tampo := MeshInstance3D.new()
	tampo.mesh = MeshBuilder3D.board_slab(LADO_TABULEIRO, LADO_TABULEIRO, ESPESSURA_TABULEIRO)
	tampo.position = Vector3(0.0, TOPO - ESPESSURA_TABULEIRO * 0.5, 0.0)
	tampo.material_override = MaterialFactory3D.get_wood_walnut()
	board_root.add_child(tampo)

	# Os tres quadrados e as quatro ligacoes, em bordo claro sobre a nogueira.
	var y_linha := TOPO + ALTURA_LINHA * 0.5
	for anel in [3, 2, 1]:
		var meia := float(anel) * PASSO
		var comp := meia * 2.0 + LARGURA_LINHA
		_linha(Vector3(0.0, y_linha, -meia), Vector3(comp, ALTURA_LINHA, LARGURA_LINHA))
		_linha(Vector3(0.0, y_linha, meia), Vector3(comp, ALTURA_LINHA, LARGURA_LINHA))
		_linha(Vector3(-meia, y_linha, 0.0), Vector3(LARGURA_LINHA, ALTURA_LINHA, comp))
		_linha(Vector3(meia, y_linha, 0.0), Vector3(LARGURA_LINHA, ALTURA_LINHA, comp))
	var liga := 2.0 * PASSO
	_linha(Vector3(0.0, y_linha, -liga), Vector3(LARGURA_LINHA, ALTURA_LINHA, liga))
	_linha(Vector3(0.0, y_linha, liga), Vector3(LARGURA_LINHA, ALTURA_LINHA, liga))
	_linha(Vector3(-liga, y_linha, 0.0), Vector3(liga, ALTURA_LINHA, LARGURA_LINHA))
	_linha(Vector3(liga, y_linha, 0.0), Vector3(liga, ALTURA_LINHA, LARGURA_LINHA))

	# Os 24 pontos: discos de bordo onde a peca pousa.
	var disco := MeshBuilder3D.disc_token(RAIO_PONTO, ALTURA_PONTO)
	for p in MorrisRules.PONTOS:
		var no := MeshInstance3D.new()
		no.mesh = disco
		var c: Vector2i = MorrisRules.COORDS[p]
		no.position = Vector3(c.x * PASSO, TOPO + 0.004, c.y * PASSO)
		no.material_override = MaterialFactory3D.get_wood_maple()
		board_root.add_child(no)

	# As bandejas das pecas por entrar, uma de cada lado, fora do tabuleiro.
	for z in [BANDEJA_Z, -BANDEJA_Z]:
		var bandeja := MeshInstance3D.new()
		bandeja.mesh = MeshBuilder3D.board_slab(BANDEJA_TAM.x, BANDEJA_TAM.y, BANDEJA_ESPESSURA)
		bandeja.position = Vector3(0.0, BANDEJA_TOPO - BANDEJA_ESPESSURA * 0.5, z)
		bandeja.material_override = MaterialFactory3D.get_leather()
		board_root.add_child(bandeja)

	halos = CellHalo3D.new()
	board_root.add_child(halos)
	halos.setup(MorrisRules.PONTOS, RAIO_HALO)


func _linha(centro: Vector3, tamanho: Vector3) -> void:
	var no := MeshInstance3D.new()
	var caixa := BoxMesh.new()
	caixa.size = tamanho
	no.mesh = caixa
	no.position = centro
	no.material_override = MaterialFactory3D.get_wood_maple()
	board_root.add_child(no)


func _montar_pecas() -> void:
	for c in pieces_root.get_children():
		c.queue_free()
	pecas.clear()
	for lado in [MorrisRules.BRANCO, MorrisRules.PRETO]:
		for i in MorrisRules.PECAS:
			var t := TOKEN_SCENE.instantiate()
			t.token_type = "cylinder"
			t.token_radius = RAIO_PECA
			t.material_name = "ivory" if lado == MorrisRules.BRANCO else "obsidian"
			t.art_by_material = ART_PECAS
			pieces_root.add_child(t)
			pecas.append(t)


func _montar_toque() -> void:
	picker = DragPicker3D.new()
	add_child(picker)
	picker.attach(env_3d, TOPO + ALTURA_PONTO)
	picker.target_tapped.connect(_on_toque)
	picker.drag_started.connect(_on_arrasto_comecou)
	picker.drag_moved.connect(_on_arrasto_moveu)
	picker.drag_ended.connect(_on_arrasto_terminou)


## Os alvos do toque, projetados da mesa: os 24 pontos e as duas bandejas
## (uma amostra por lugar de peca, para pegar a bandeja de ponta a ponta).
func _refazer_alvos() -> void:
	var alvos: Dictionary = {}
	for p in MorrisRules.PONTOS:
		alvos[p] = _pos_ponto(p, TOPO + ALTURA_PONTO)
	for lado in [MorrisRules.BRANCO, MorrisRules.PRETO]:
		var amostras: Array = []
		for slot in MorrisRules.PECAS:
			amostras.append(_pos_bandeja(lado, slot))
		alvos[_id_bandeja(lado)] = amostras
	picker.set_targets(alvos)
	var aneis: Array = []
	for p in MorrisRules.PONTOS:
		aneis.append(_pos_ponto(p, TOPO + ALTURA_PONTO))
	halos.set_targets(aneis)


static func _lado_da_peca(indice: int) -> int:
	return MorrisRules.BRANCO if indice < MorrisRules.PECAS else MorrisRules.PRETO


static func _id_bandeja(lado: int) -> String:
	return "bandeja_%d" % lado


func _pos_ponto(p: int, altura: float = TOPO + ALTURA_PONTO) -> Vector3:
	var c: Vector2i = MorrisRules.COORDS[p]
	return Vector3(c.x * PASSO * _sinal, altura, c.y * PASSO * _sinal)


## As brancas ficam na bandeja de perto, as pretas na de longe -- invertido
## quando este aparelho joga de pretas.
func _pos_bandeja(lado: int, slot: int) -> Vector3:
	var z := BANDEJA_Z if lado == MorrisRules.BRANCO else -BANDEJA_Z
	return Vector3((float(slot) - 4.0) * PASSO_BANDEJA * _sinal, BANDEJA_TOPO, z * _sinal)


# ================================================================== partida

func _start_new_game() -> void:
	game_over = false
	_geracao += 1
	_ia_pensando = false
	selecionada = -1
	ultimo_lance = PackedInt32Array()
	_arrasto_peca = -1
	_arrasto_origem = null
	_aviso = ""
	_moinhos_fechados = PackedInt32Array([0, 0, 0])
	_dupla_fechada = [false, false, false]
	if picker:
		picker.cancel_drag()

	ai_level = DifficultyManager.get_level(game_id)
	mesa = SeatTable.for_game(self, 2, vs_ai)
	if top_bar != null:
		# Com dois aparelhos na mesa nao ha modo para escolher.
		if not mesa.online():
			top_bar.oferecer_modo(vs_ai)
		else:
			top_bar.esconder_modo()
	_sinal = -1.0 if (mesa.online() and not mesa.is_host()) else 1.0

	estado = MorrisRules.novo_estado()
	btn_restart.hide()
	shell.timer.reset()
	shell.timer.start()

	_refazer_alvos()
	_sincronizar_pecas()
	_atualizar_hud()
	_acender()
	_talvez_jogar_ia()


## Poe cada peca onde o estado diz, sem animacao: no ponto, na bandeja ou
## fora da mesa (capturada). Serve ao inicio da partida e a suite.
func _sincronizar_pecas() -> void:
	var cells: PackedByteArray = estado["cells"]
	var mao: PackedInt32Array = estado["mao"]
	ponto_peca = PackedInt32Array()
	ponto_peca.resize(MorrisRules.PONTOS)
	ponto_peca.fill(-1)
	mao_pecas = [[], [], []]
	for lado in [MorrisRules.BRANCO, MorrisRules.PRETO]:
		var base := 0 if lado == MorrisRules.BRANCO else MorrisRules.PECAS
		var proxima := base
		for p in MorrisRules.PONTOS:
			if cells[p] != lado:
				continue
			ponto_peca[p] = proxima
			_repor(proxima, _pos_ponto(p))
			proxima += 1
		for slot in mao[lado]:
			_repor(proxima, _pos_bandeja(lado, slot))
			(mao_pecas[lado] as Array).append(proxima)
			proxima += 1
		# A proxima a entrar e a ultima da lista: a do fim da fila da bandeja.
		while proxima < base + MorrisRules.PECAS:
			(pecas[proxima] as Token3D).hide()
			proxima += 1


func _repor(indice: int, pos: Vector3) -> void:
	var t: Token3D = pecas[indice]
	t.show()
	t.scale = Vector3.ONE
	t.set_lift(0.0, 0.0)
	t.slide_to(pos, 0.0)


## Carrega uma posicao pronta: 24 bytes em hexadecimal, pecas na mao e a vez.
## E o ponto de entrada da suite e da captura de tela de meio de partida.
func carregar_posicao(cells_hex: String, mao_branca: int, mao_preta: int, vez: int) -> void:
	var novo := MorrisRules.novo_estado()
	var cells := cells_hex.hex_decode()
	if cells.size() == MorrisRules.PONTOS:
		novo["cells"] = cells
	novo["mao"] = PackedInt32Array([0, mao_branca, mao_preta])
	novo["vez"] = vez
	estado = novo
	selecionada = -1
	ultimo_lance = PackedInt32Array()
	_sincronizar_pecas()
	_atualizar_hud()
	_acender()
	_talvez_jogar_ia()


func _on_modo_trocado(novo_vs_ai: bool) -> void:
	vs_ai = novo_vs_ai
	restart_game()


func _modo() -> String:
	if mesa != null and mesa.online():
		return "online"
	return "ai" if vs_ai else "pass_play"


## O lado que este aparelho representa: o assento da sala em rede; as brancas
## contra a maquina e na mesa compartilhada (jogador 1).
func _lado_local() -> int:
	if mesa != null and mesa.online():
		return mesa.local_index() + 1
	return MorrisRules.BRANCO


func _assento_da_vez() -> int:
	return int(estado["vez"]) - 1


## Uma pessoa com o aparelho na mao joga por este assento agora.
func _humano_aqui(assento: int) -> bool:
	return mesa.is_local(assento) or mesa.is_pass(assento)


func _posso_tocar() -> bool:
	return not game_over and not _ia_pensando and _humano_aqui(_assento_da_vez())


# ================================================================== jogadas

## A entrada da pessoa deste aparelho: manda ao outro aparelho e aplica.
func _jogar(acao: Dictionary) -> void:
	if not MorrisRules.valida(estado, acao):
		return
	if mesa.online():
		net_send(acao)
	_aplicar(acao)


## A jogada, seja de quem for. Move o estado, anima a mesa e decide o que vem
## depois. Devolve falso se a acao e ilegal (e entao nada muda).
func _aplicar(acao: Dictionary) -> bool:
	if game_over or not MorrisRules.valida(estado, acao):
		return false
	var lado: int = estado["vez"]
	var tipo := str(acao.get("t", ""))
	var fechados := MorrisRules.aplicar(estado, acao)
	if fechados < 0:
		return false

	match tipo:
		"place":
			var p := int(acao["p"])
			_animar_colocacao(lado, p)
			ultimo_lance = PackedInt32Array([p])
		"move":
			var de := int(acao["from"])
			var para := int(acao["to"])
			_animar_movimento(de, para)
			ultimo_lance = PackedInt32Array([de, para])
		"remove":
			var p := int(acao["p"])
			_animar_captura(p)
			# Quem capturou e `lado`; se nao foi este aparelho, a vez seguinte
			# comeca avisando a perda.
			if lado != _lado_local() and not mesa.pass_and_play():
				_aviso = tr("TRILHA_LOST_PIECE")

	if fechados > 0:
		_moinhos_fechados[lado] += 1
		if fechados >= 2:
			_dupla_fechada[lado] = true
	selecionada = -1

	var fim := MorrisRules.resultado(estado)
	if bool(fim["over"]):
		_encerrar(fim)
		return true
	_atualizar_hud(fechados)
	_acender()
	_talvez_jogar_ia()
	return true


## A jogada do outro aparelho: so na vez dele e so se for legal aqui tambem.
func _on_net_move(payload: Dictionary) -> void:
	if mesa == null or not mesa.online() or game_over:
		return
	if not mesa.expects_from_network(_assento_da_vez()):
		return
	_aplicar(payload)


# ---------------------------------------------------------------- animacao

func _animar_colocacao(lado: int, p: int) -> void:
	var fila: Array = mao_pecas[lado]
	if fila.is_empty():
		return
	var indice := int(fila.pop_back())
	ponto_peca[p] = indice
	var t: Token3D = pecas[indice]
	t.set_lift(0.0)
	t.jump_to(_pos_ponto(p), Tokens3D.ARC_LONG, Tokens3D.DUR_NORMAL)
	if AudioManager:
		AudioManager.play_piece_place()


func _animar_movimento(de: int, para: int) -> void:
	var indice := int(ponto_peca[de])
	if indice < 0:
		return
	ponto_peca[de] = -1
	ponto_peca[para] = indice
	var t: Token3D = pecas[indice]
	t.set_lift(0.0)
	# Vizinho: um passo curto. Voo: um salto alto, para se ver que voou.
	var vizinho: bool = MorrisRules.ADJ[de].has(para)
	if vizinho:
		t.jump_to(_pos_ponto(para), Tokens3D.ARC_SHORT, Tokens3D.DUR_NORMAL)
	else:
		t.jump_to(_pos_ponto(para), Tokens3D.ARC_LONG, Tokens3D.DUR_SLOW)
	if AudioManager:
		AudioManager.play_piece_place()


func _animar_captura(p: int) -> void:
	var indice := int(ponto_peca[p])
	if indice < 0:
		return
	ponto_peca[p] = -1
	var t: Token3D = pecas[indice]
	t.set_lift(0.0)
	t.vanish(false)
	if AudioManager:
		AudioManager.play_capture()


# ------------------------------------------------------------------- toque

func _on_toque(id: Variant) -> void:
	if not _posso_tocar():
		return
	if id is String:
		# A bandeja nao e jogada: tocar nela so relembra onde da para colocar.
		_acender()
		return
	var p := int(id)
	var cells: PackedByteArray = estado["cells"]
	var vez: int = estado["vez"]

	if bool(estado["remover"]):
		if MorrisRules.pode_remover(estado, p):
			_jogar({"t": "remove", "p": p})
		else:
			_recusar(p, cells[p] == MorrisRules.adversario(vez))
		return

	if MorrisRules.fase_de(estado, vez) == MorrisRules.Fase.COLOCACAO:
		if MorrisRules.pode_colocar(estado, p):
			_jogar({"t": "place", "p": p})
		else:
			_recusar(p, false)
		return

	if cells[p] == vez:
		_selecionar(-1 if selecionada == p else p)
		return
	if selecionada >= 0 and MorrisRules.pode_mover(estado, selecionada, p):
		_jogar({"t": "move", "from": selecionada, "to": p})
		return
	_recusar(p, false)


## Escolhe a peca que vai andar: levanta, acende os destinos.
func _selecionar(p: int) -> void:
	if selecionada >= 0 and ponto_peca[selecionada] >= 0:
		(pecas[ponto_peca[selecionada]] as Token3D).set_lift(0.0)
	selecionada = -1
	if p >= 0:
		if MorrisRules.destinos(estado["cells"], estado["mao"], p).is_empty():
			_recusar(p, false)
			return
		selecionada = p
		(pecas[ponto_peca[p]] as Token3D).set_lift(Tokens3D.LIFT_SELECTED)
		play_click()
	_acender()


## Recusar calado e o que faz o jogo parecer quebrado: a mesa treme a peca e
## a linha de status diz o porque.
func _recusar(p: int, peca_em_trilha: bool) -> void:
	var indice := int(ponto_peca[p])
	if indice >= 0:
		(pecas[indice] as Token3D).reject()
	if AudioManager:
		AudioManager.play_error()
	set_status(tr("TRILHA_INVALID_REMOVE") if peca_em_trilha else tr("TRILHA_INVALID"))


func _on_arrasto_comecou(id: Variant) -> void:
	if not _posso_tocar() or bool(estado["remover"]):
		picker.cancel_drag()
		return
	var vez: int = estado["vez"]
	var cells: PackedByteArray = estado["cells"]
	if id is String:
		var fila: Array = mao_pecas[vez]
		if str(id) != _id_bandeja(vez) or fila.is_empty():
			picker.cancel_drag()
			return
		_arrasto_peca = int(fila.back())
		_arrasto_origem = str(id)
	else:
		var p := int(id)
		if cells[p] != vez or MorrisRules.destinos(cells, estado["mao"], p).is_empty():
			picker.cancel_drag()
			return
		_arrasto_peca = int(ponto_peca[p])
		_arrasto_origem = p
		_selecionar(p)
	(pecas[_arrasto_peca] as Token3D).set_lift(Tokens3D.LIFT_DRAG)


func _on_arrasto_moveu(_de: Variant, _sobre: Variant, mundo: Vector3) -> void:
	if _arrasto_peca < 0 or mundo == Vector3.INF:
		return
	var t: Token3D = pecas[_arrasto_peca]
	t.position = Vector3(mundo.x, t.position.y, mundo.z)


func _on_arrasto_terminou(_de: Variant, para: Variant) -> void:
	var indice := _arrasto_peca
	var origem: Variant = _arrasto_origem
	_arrasto_peca = -1
	_arrasto_origem = null
	if indice < 0:
		return
	var t: Token3D = pecas[indice]
	if para is int:
		var p := int(para)
		if origem is String and MorrisRules.pode_colocar(estado, p):
			_jogar({"t": "place", "p": p})
			return
		if origem is int and MorrisRules.pode_mover(estado, int(origem), p):
			_jogar({"t": "move", "from": int(origem), "to": p})
			return
	# Soltou fora de um destino: a peca volta, e a escolha fica de pe para
	# quem prefere tocar no destino.
	if origem is String:
		var lado := _lado_da_peca(indice)
		var fila: Array = mao_pecas[lado]
		t.set_lift(0.0)
		t.jump_to(_pos_bandeja(lado, fila.size() - 1), Tokens3D.ARC_SHORT, Tokens3D.DUR_FAST)
	else:
		t.jump_to(_pos_ponto(int(origem)), Tokens3D.ARC_SHORT, Tokens3D.DUR_FAST)
		t.set_lift(Tokens3D.LIFT_SELECTED)


# ------------------------------------------------------------------- maquina

func _talvez_jogar_ia() -> void:
	# A captura da maquina vem junto com o lance dela, em `_jogar_ia`: com uma
	# captura pendente nao ha lance novo para pensar.
	if game_over or _ia_pensando or bool(estado["remover"]):
		return
	if mesa.ai_runs_here(_assento_da_vez()):
		_jogar_ia()


## Pensa fora da linha principal, durante a pausa de encenacao. A tarefa
## recebe copias planas do estado, nunca a cena, que pode ser fechada com a
## busca ainda rodando.
func _jogar_ia() -> void:
	_ia_pensando = true
	var geracao := _geracao
	var cells := (estado["cells"] as PackedByteArray).duplicate()
	var mao := (estado["mao"] as PackedInt32Array).duplicate()
	var lado: int = estado["vez"]
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(
		MorrisAI.pensar_em_tarefa.bind(cells, mao, lado, ai_level, saida))

	# A arvore fica guardada antes do laco: se o jogador sair da cena com a
	# busca no ar, `get_tree()` passa a devolver null no quadro seguinte.
	var arvore := get_tree()
	var inicio := Time.get_ticks_msec()
	while arvore != null and (not WorkerThreadPool.is_task_completed(tarefa)
			or Time.get_ticks_msec() - inicio < int(PAUSA_IA * 1000.0)):
		await arvore.process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)

	if not is_inside_tree() or geracao != _geracao or game_over:
		return
	_ia_pensando = false
	if saida.is_empty():
		return
	var lance: Vector3i = saida[0]
	if lance.y < 0:
		return
	var acoes := MorrisRules.lance_para_acoes(lance)
	_aplicar(acoes[0])
	if game_over or not bool(estado["remover"]):
		return
	# A captura vem depois de uma pausa, para a trilha ser vista antes.
	var captura := lance.z
	if captura < 0:
		captura = MorrisRules.removiveis(estado["cells"], MorrisRules.adversario(lado))[0]
	_ia_pensando = true
	await arvore.create_timer(PAUSA_CAPTURA_IA).timeout
	if not is_inside_tree() or geracao != _geracao or game_over:
		return
	_ia_pensando = false
	_aplicar({"t": "remove", "p": captura})


# ==================================================================== HUD

## Acende os aneis: o ultimo lance em azul, e para quem joga aqui os pontos
## onde da para colocar, as pecas que podem andar, os destinos da escolhida
## ou as pecas adversarias que podem ser capturadas (vermelho).
func _acender() -> void:
	halos.clear()
	if game_over:
		for p in ultimo_lance:
			halos.light(p, Tokens3D.COLOR_LAST_MOVE)
		return
	for p in ultimo_lance:
		halos.light(p, Tokens3D.COLOR_LAST_MOVE)
	var assento := _assento_da_vez()
	if not _humano_aqui(assento) or _ia_pensando:
		return
	var cells: PackedByteArray = estado["cells"]
	var mao: PackedInt32Array = estado["mao"]
	var vez: int = estado["vez"]
	if bool(estado["remover"]):
		for p in MorrisRules.removiveis(cells, MorrisRules.adversario(vez)):
			halos.light(p, Tokens3D.COLOR_INVALID)
		return
	if MorrisRules.fase(cells, mao, vez) == MorrisRules.Fase.COLOCACAO:
		for p in MorrisRules.vazios(cells):
			halos.light(p, Tokens3D.COLOR_VALID)
		return
	if selecionada >= 0:
		halos.light(selecionada, Tokens3D.COLOR_SELECTED)
		for q in MorrisRules.destinos(cells, mao, selecionada):
			halos.light(q, Tokens3D.COLOR_VALID)
		return
	for p in MorrisRules.pecas_moveis(cells, mao, vez):
		halos.light(p, Tokens3D.COLOR_HINT)


func _atualizar_hud(fechados: int = 0) -> void:
	_pintar_placar()
	_atualizar_status(fechados)


## Pecas em jogo de cada lado na barra de cima, e o degrau no rotulo do shell.
func _pintar_placar() -> void:
	var meu := _lado_local()
	var dele := MorrisRules.adversario(meu)
	var minhas := MorrisRules.total(estado, meu)
	var suas := MorrisRules.total(estado, dele)
	if mesa.online():
		set_duel_score(minhas, suas, "NET_YOU", "NET_OPPONENT")
		shell.set_level(tr("NET_MODE_LABEL") % net_opponent_name())
	elif mesa.pass_and_play():
		set_duel_score(minhas, suas, "SCORE_PLAYER_1", "SCORE_PLAYER_2")
		shell.set_level(tr("MODE_LABEL") % tr("MODE_TWO_PLAYERS"))
	else:
		set_duel_score(minhas, suas)
		shell.set_level(DifficultyManager.label_for(game_id))
	set_active_side(int(estado["vez"]) == meu)


## "De quem e a vez -- o que tocar". A dica so aparece para quem joga aqui.
func _atualizar_status(fechados: int = 0) -> void:
	var vez: int = estado["vez"]
	var assento := vez - 1
	var quem := ""
	if mesa.online():
		quem = tr("NET_YOUR_TURN") if mesa.is_local(assento) else tr("NET_THEIR_TURN") % net_opponent_name()
	elif mesa.is_ai(assento):
		quem = tr("AI_TURN_SHORT")
	elif mesa.pass_and_play():
		quem = tr("TURN_PLAYER") % vez
	else:
		quem = tr("YOUR_TURN")
	if _aviso != "":
		quem = _aviso
		_aviso = ""

	var dica := ""
	if _humano_aqui(assento):
		if bool(estado["remover"]):
			dica = tr("TRILHA_DOUBLE_MILL") if fechados >= 2 else tr("TRILHA_HINT_REMOVE")
		else:
			match MorrisRules.fase_de(estado, vez):
				MorrisRules.Fase.COLOCACAO:
					dica = tr("TRILHA_HINT_PLACE") % int((estado["mao"] as PackedInt32Array)[vez])
				MorrisRules.Fase.VOO:
					dica = tr("TRILHA_HINT_FLY")
				_:
					dica = tr("TRILHA_HINT_MOVE")
	var texto := quem if dica == "" else "%s — %s" % [quem, dica]
	set_status(texto)


# ============================================================ fim de partida

func _encerrar(fim: Dictionary) -> void:
	shell.timer.stop()
	_selecionar(-1)
	var meu := _lado_local()
	var vencedor := int(fim["winner"])
	var empate := bool(fim["draw"])
	var venci := vencedor == meu
	var motivo := str(fim["reason"])

	var fatos: Array[String] = []
	if _dupla_fechada[meu]:
		fatos.append("trilha_moinho_duplo")
	if _moinhos_fechados[meu] >= 3:
		fatos.append("trilha_tres_moinhos")
	if venci:
		if motivo == "bloqueio":
			fatos.append("trilha_bloqueio")
		if MorrisRules.fase_de(estado, meu) == MorrisRules.Fase.VOO:
			fatos.append("trilha_voo")
	var extra := {
		"moves": int(estado["lances"]),
		"time": shell.timer.get_time(),
		"mode": _modo(),
		"perfect": venci and MorrisRules.total(estado, meu) == MorrisRules.PECAS,
		"flags": fatos,
	}
	if empate:
		extra["draw"] = true

	game_over = true
	_acender()
	if empate:
		var msg_empate := tr("TRILHA_DRAW_MOVES") if motivo == "lances" else tr("TRILHA_DRAW_REPEAT")
		finish_game(msg_empate, false, extra)
		return
	if mesa.pass_and_play():
		# Os dois estao na mesma mesa: o cartao anuncia o lado, nao "voce".
		finish_game(tr("PLAYER_WINS") % vencedor, vencedor == MorrisRules.BRANCO, extra)
		return
	if venci:
		finish_game(tr("TRILHA_WIN_BLOCK") if motivo == "bloqueio" else tr("RESULT_YOU_WIN"), true, extra)
		return
	var msg := tr("NET_OPPONENT_WINS") % net_opponent_name() if mesa.online() else tr("RESULT_AI_WINS")
	finish_game(msg, false, extra)
