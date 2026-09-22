extends BaseGame

## Senha (Mastermind) sobre a mesa 3D.
##
## A grade de ardosia tem 10 linhas (as tentativas, de baixo para cima) e
## N + 1 colunas: as N primeiras recebem os pinos coloridos do palpite e a
## ultima, apagada, e a faixa de resposta onde pousam os pinos pretos e
## brancos. Acima da grade, uma segunda grade de uma linha guarda o codigo
## secreto debaixo de uma tampa de madeira que levanta no fim.
##
## Tres modos, um caminho: SOLO (o codigo sai do sorteio compartilhado),
## DUELO contra a maquina e DUELO em rede. No duelo cada lado monta um codigo
## para o outro e vence quem precisou de menos tentativas para quebrar o que
## recebeu. Toda jogada -- da pessoa daqui, da maquina ou do outro aparelho --
## passa por `_aplicar(seat, acao)`; a rede so carrega o palpite e a resposta
## calculada por quem tem o codigo, e o codigo em si viaja uma vez, no fim da
## rodada, para ser mostrado.

const TOKEN_SCENE := preload("res://shared/3d/Token3D.tscn")

## Lado da casa. Fixo: quem enquadra a grade e a camera (`fit_table`).
const CELL := 0.7
const RAIO_PINO := 0.24
## Base do pino: em cima da placa da casa.
const ALTURA_PECA := Tokens3D.TILE_THICKNESS + 0.005
## Entre a moldura da grade e a faixa do codigo.
const FOLGA_CODIGO := 0.28
const TAMPA_ALTURA := 0.22
## Pino de resposta: pequeno, dois por coluna dentro da casa apagada.
const PINO_RESPOSTA_ALTURA := 0.17
const PINO_RESPOSTA_RAIO := 0.062

## Pausas de encenacao. A suite zera as duas.
const PAUSA_IA := 0.55
const PAUSA_REVELACAO := 1.6

enum Fase {
	ESPERA,     ## Esperando a rede: a semente ou o codigo do outro.
	MONTAR,     ## A pessoa daqui monta o codigo secreto para o outro.
	PALPITE,    ## A pessoa daqui compoe um palpite.
	ASSISTIR,   ## Outro quebra (maquina ou outro aparelho), ou espera resposta.
	FIM,        ## A rodada fechou; falta revelar ou encerrar.
}

@onready var shell: GameShell = $GameShell
@onready var board_3d: Board3D = $Board3D
@onready var code_board: Board3D = $CodeBoard3D
@onready var pieces_root: Node3D = $PiecesRoot
@onready var feedback_root: Node3D = $FeedbackRoot
@onready var code_root: Node3D = $CodeRoot
@onready var lid_root: Node3D = $LidRoot
@onready var palette: GridContainer = $UI/Footer/Palette
@onready var btn_erase: Button = $UI/Footer/Actions/BtnErase
@onready var btn_check: Button = $UI/Footer/Actions/BtnCheck
@onready var btn_mode: Button = $UI/BtnMode

## Degrau de 1 a 10 do DifficultyManager: tamanho do codigo e forca da IA.
var ai_level: int = DifficultyManager.DEFAULT_LEVEL
var posicoes: int = 4
var cores: int = 6
var repete: bool = true

## Falso = solo (o codigo e sorteado); verdadeiro = duelo contra a maquina.
## Em rede e sempre duelo, e o botao de modo some.
var duelo: bool = false

var table: SeatTable = null
var sync: MatchSync = null
var fase: int = Fase.ESPERA
var rodada: int = 1
## Cadeira de quem montou o codigo desta rodada (-1 = a mesa, no solo) e de
## quem esta quebrando.
var maker: int = -1
var breaker: int = 0
var codigo: Array[int] = []
## Cada tentativa: {"pins": Array, "black": int, "white": int}; black -1 = sem resposta ainda.
var tentativas: Array[Dictionary] = []
## A linha em composicao (palpite ou codigo); -1 = casa vazia.
var linha: Array[int] = []
## Casa escolhida para receber a proxima cor; -1 = a primeira vazia.
var _sel: int = -1
var _press_col: int = -1
## Tentativas usadas por cadeira ao fechar a rodada (11 = nao quebrou).
var resultado: Dictionary = {}
var tempos: Dictionary = {}

## Pinos da linha em composicao, por casa.
var _pinos_linha: Array = []
## Pinos ja conferidos: Vector2i(linha, coluna) -> Token3D.
var pins_3d: Dictionary = {}
var lid: MeshInstance3D = null
var _lid_tween: Tween = null

## Estado da maquina quebradora (ver MastermindAI). Plano, para a tarefa.
var estado_ia: Dictionary = {}
var _ia_ultimo: Array = []
var _ia_ultimo_fb: Dictionary = {}
var _ia_pensando: bool = false
var pausa_ia: float = PAUSA_IA
var pausa_revelacao: float = PAUSA_REVELACAO

## Jogadas que chegaram antes da semente (o convidado entra na cena depois do
## anfitriao) e sao aplicadas quando a partida abre.
var _pendentes: Array = []
var _partida_iniciada: bool = false
## Sobe a cada partida nova: corrotina que acorda numa partida antiga desiste.
var _geracao: int = 0
var _montado_para: Vector2i = Vector2i(-1, -1)


func _ready() -> void:
	env_3d = $TabletopEnvironment3D
	status_label = shell.status_label
	btn_restart = shell.btn_restart
	shell.restart_requested.connect(restart_game)
	shell.timer.time_changed.connect(func(_s: int) -> void: _pintar_placar())
	# O toque entra pela propria grade: a casa tocada e a casa desenhada.
	board_3d.cell_clicked.connect(_on_grade_tocada)
	board_3d.cell_released.connect(_on_grade_solta)
	code_board.cell_clicked.connect(_on_codigo_tocado)
	code_board.cell_released.connect(_on_codigo_solto)
	btn_erase.pressed.connect(_on_apagar)
	btn_check.pressed.connect(_on_conferir)
	btn_mode.pressed.connect(_on_modo)
	# Madeira e couro em volta de uma grade de ardosia: e uma caixa de Senha.
	env_3d.apply_theme(GameTheme3D.parlour_walnut())
	_montar_tampa()
	_start_new_game()
	begin_match(_nome_do_modo())


# ------------------------------------------------------------ ciclo da partida

func _start_new_game() -> void:
	_geracao += 1
	game_over = false
	fase = Fase.ESPERA
	_partida_iniciada = false
	_pendentes.clear()
	_ia_pensando = false
	ai_level = DifficultyManager.get_level(game_id)
	var cfg := MastermindRules.config_do_degrau(ai_level)
	_aplicar_config(int(cfg["posicoes"]), int(cfg["cores"]), bool(cfg["repete"]))
	shell.set_level(DifficultyManager.label_for(game_id))
	shell.timer.reset()
	shell.timer.stop()
	btn_mode.visible = not net_active()
	_pintar_modo()
	table = SeatTable.for_game(self, 2 if _em_duelo() else 1, true)
	sync = MatchSync.new(self, table)
	sync.start()
	_limpar_mesa()
	if sync.waiting_for_deal():
		set_status(tr("NET_WAITING_DEAL"))
		_atualizar_botoes()
		return
	_iniciar_partida()


func _iniciar_partida() -> void:
	_partida_iniciada = true
	resultado.clear()
	tempos.clear()
	_iniciar_rodada(1)
	var fila := _pendentes.duplicate()
	_pendentes.clear()
	for msg in fila:
		_aplicar(int(msg["seat"]), msg["a"])


func _iniciar_rodada(r: int) -> void:
	rodada = r
	tentativas.clear()
	codigo = []
	estado_ia = {}
	_ia_ultimo = []
	_ia_ultimo_fb = {}
	_limpar_mesa()
	_fechar_tampa(true)
	shell.timer.reset()
	shell.timer.stop()
	if not _em_duelo():
		maker = -1
		breaker = 0
		codigo = MastermindRules.gerar_codigo(sync.rng, posicoes, cores, repete)
		_codigo_pronto()
		return
	# Rodada 1: quem abriu a sala (cadeira 0) monta, o outro quebra. Rodada 2
	# inverte. Fora da rede a cadeira 1 e a maquina.
	maker = 0 if r == 1 else 1
	breaker = 1 - maker
	if table.is_ai(maker):
		codigo = MastermindRules.gerar_codigo(sync.rng, posicoes, cores, repete)
		_codigo_pronto()
	elif table.is_local(maker):
		_comecar_montagem()
	else:
		fase = Fase.ESPERA
		set_status(tr("SENHA_WAITING_CODE") % table.display_name(maker, self))
		_pintar_estados()
		_atualizar_botoes()
	_pintar_placar()


## A pessoa daqui monta o codigo na faixa de cima, com a tampa aberta.
func _comecar_montagem() -> void:
	fase = Fase.MONTAR
	_nova_linha()
	_abrir_tampa(false)
	set_status(tr("SENHA_MAKE_CODE") % table.display_name(breaker, self))
	_pintar_estados()
	_atualizar_botoes()
	_pintar_placar()


## O codigo desta rodada existe (aqui ou no outro aparelho): a tampa fecha e
## o quebrador comeca.
func _codigo_pronto() -> void:
	_limpar_codigo_3d()
	_fechar_tampa(false)
	if table.is_local(breaker):
		_comecar_palpite()
	elif table.ai_runs_here(breaker):
		fase = Fase.ASSISTIR
		estado_ia = {"posicoes": posicoes, "cores": cores, "repete": repete}
		set_status(tr("SENHA_CODE_LOCKED") % table.display_name(breaker, self))
		_pintar_estados()
		_atualizar_botoes()
		_pintar_placar()
		_turno_ia.call_deferred()
	else:
		fase = Fase.ASSISTIR
		set_status(tr("SENHA_CODE_LOCKED") % table.display_name(breaker, self))
		_pintar_estados()
		_atualizar_botoes()
		_pintar_placar()


## A pessoa daqui compoe o proximo palpite na linha acesa.
func _comecar_palpite() -> void:
	fase = Fase.PALPITE
	_nova_linha()
	if _em_duelo():
		set_status(tr("SENHA_YOUR_TURN_BREAK") % table.display_name(maker, self))
	else:
		set_status(tr("SENHA_START") + difficulty_suffix())
	_pintar_estados()
	_atualizar_botoes()
	_pintar_placar()


func _nova_linha() -> void:
	linha = []
	linha.resize(posicoes)
	linha.fill(-1)
	_pinos_linha = []
	_pinos_linha.resize(posicoes)
	_sel = -1
	_press_col = -1


func _em_duelo() -> bool:
	return duelo or net_active()


func _nome_do_modo() -> String:
	if net_active():
		return "online"
	return "ai" if duelo else "solo"


## Este aparelho sabe o codigo desta rodada? A mesa (solo), a pessoa daqui ou
## a maquina daqui montaram; o do outro aparelho so chega no fim.
func _codigo_conhecido() -> bool:
	return not codigo.is_empty()


# ------------------------------------------------------------------ jogadas

## O unico caminho de toda jogada: pessoa daqui, maquina, outro aparelho.
## Cada acao confere quem pode manda-la e em que fase; o que nao vale e
## ignorado calado, como o Reversi faz com a jogada remota ilegal.
func _aplicar(seat: int, acao: Dictionary) -> void:
	if game_over:
		return
	match str(acao.get("t", "")):
		"code_ready":
			_receber_codigo_pronto(seat, acao)
		"guess":
			_receber_palpite(seat, acao)
		"feedback":
			_receber_resposta(seat, acao)
		"reveal":
			_receber_revelacao(seat, acao)


func _receber_codigo_pronto(seat: int, acao: Dictionary) -> void:
	if not _em_duelo() or seat != maker or _codigo_conhecido() and fase != Fase.MONTAR:
		return
	if fase != Fase.ESPERA and fase != Fase.MONTAR:
		return
	var n := int(acao.get("n", posicoes))
	var c := int(acao.get("c", cores))
	var rep := bool(acao.get("rep", repete))
	if n < 1 or n > MastermindRules.MAX_POSICOES or c < 2 or c > MastermindRules.MAX_CORES:
		return
	# O degrau de quem abriu a sala manda nos dois aparelhos: o convidado
	# remonta a grade no tamanho que chegou. Na rodada 2 a configuracao ja e
	# a mesma e nada muda.
	if table.is_remote(seat) and (n != posicoes or c != cores or rep != repete):
		if rodada != 1:
			return
		_aplicar_config(n, c, rep)
		_limpar_mesa()
	_codigo_pronto()


func _receber_palpite(seat: int, acao: Dictionary) -> void:
	if seat != breaker or (fase != Fase.PALPITE and fase != Fase.ASSISTIR):
		return
	if tentativas.size() >= MastermindRules.MAX_TENTATIVAS or _esperando_resposta():
		return
	var bruto: Variant = acao.get("pins", [])
	if not (bruto is Array):
		return
	var pins: Array[int] = []
	for v in bruto:
		pins.append(int(v))
	if not MastermindRules.palpite_valido(pins, posicoes, cores):
		return
	var row := MastermindRules.MAX_TENTATIVAS - 1 - tentativas.size()
	tentativas.append({"pins": pins, "black": -1, "white": -1})
	for i in posicoes:
		var pino: Node3D = _pinos_linha[i] if i < _pinos_linha.size() else null
		if pino == null:
			pino = _criar_pino(pins[i], board_3d.get_cell_position_3d(row, i, ALTURA_PECA), pieces_root)
		pins_3d[Vector2i(row, i)] = pino
	_nova_linha()
	if AudioManager:
		AudioManager.play_piece_place()
	if fase == Fase.PALPITE:
		# Sai da composicao ate a resposta chegar; local ela chega ja.
		fase = Fase.ASSISTIR
	_pintar_estados()
	_atualizar_botoes()
	_pintar_placar()
	if _codigo_conhecido():
		var fb := MastermindRules.avaliar(codigo, pins)
		var resposta := {"t": "feedback", "black": int(fb["black"]), "white": int(fb["white"])}
		_aplicar(maker, resposta)
		if maker >= 0:
			sync.send(maker, resposta)
	elif table.is_local(breaker):
		set_status(tr("SENHA_WAITING_FEEDBACK") % table.display_name(maker, self))


func _receber_resposta(seat: int, acao: Dictionary) -> void:
	if seat != maker or not _esperando_resposta():
		return
	if not MastermindRules.feedback_valido(acao, posicoes):
		return
	var idx := tentativas.size() - 1
	var t := tentativas[idx]
	t["black"] = int(acao["black"])
	t["white"] = int(acao["white"])
	_mostrar_resposta(idx, int(t["black"]), int(t["white"]))
	if table.ai_runs_here(breaker):
		_ia_ultimo = (t["pins"] as Array).duplicate()
		_ia_ultimo_fb = {"black": int(t["black"]), "white": int(t["white"])}
	if AudioManager:
		AudioManager.play_capture()
	if int(t["black"]) == posicoes:
		_fim_da_rodada(tentativas.size())
		return
	if tentativas.size() >= MastermindRules.MAX_TENTATIVAS:
		_fim_da_rodada(MastermindRules.MAX_TENTATIVAS + 1)
		return
	if table.is_local(breaker):
		_comecar_palpite()
	elif table.ai_runs_here(breaker):
		_pintar_estados()
		_pintar_placar()
		_turno_ia.call_deferred()
	else:
		_pintar_estados()
		_pintar_placar()


## A rodada fechou: guarda quantas tentativas o quebrador usou e revela o
## codigo -- quem o tem manda; quem nao tem espera chegar.
func _fim_da_rodada(usadas: int) -> void:
	fase = Fase.FIM
	shell.timer.stop()
	resultado[breaker] = usadas
	tempos[breaker] = float(shell.timer.get_time())
	var quebrou := usadas <= MastermindRules.MAX_TENTATIVAS
	if table.is_local(breaker):
		set_status(tr("SENHA_WIN") % usadas if quebrou else tr("SENHA_LOSE"))
	else:
		var nome := table.display_name(breaker, self)
		set_status(tr("SENHA_THEY_SOLVED") % [nome, usadas] if quebrou else tr("SENHA_THEY_FAILED") % nome)
	_pintar_estados()
	_atualizar_botoes()
	_pintar_placar()
	if _codigo_conhecido():
		var revelacao := {"t": "reveal", "code": codigo.duplicate()}
		_aplicar(maker, revelacao)
		if maker >= 0:
			sync.send(maker, revelacao)


func _receber_revelacao(seat: int, acao: Dictionary) -> void:
	if seat != maker or fase != Fase.FIM:
		return
	var bruto: Variant = acao.get("code", [])
	if not (bruto is Array):
		return
	var code: Array[int] = []
	for v in bruto:
		code.append(int(v))
	if not MastermindRules.codigo_valido(code, posicoes, cores, repete):
		return
	if codigo.is_empty():
		codigo = code
	_abrir_tampa(false)
	_mostrar_codigo_3d()
	_depois_da_revelacao()


func _depois_da_revelacao() -> void:
	var geracao := _geracao
	if pausa_revelacao > 0.0:
		var arvore := get_tree()
		if arvore == null:
			return
		await arvore.create_timer(pausa_revelacao).timeout
		if not is_inside_tree() or geracao != _geracao or game_over:
			return
	if _em_duelo() and rodada == 1:
		_iniciar_rodada(2)
	else:
		_encerrar()


## Publica o resultado: o solo pontua por tentativas e tempo; o duelo compara
## as tentativas dos dois lados.
func _encerrar() -> void:
	fase = Fase.FIM
	_atualizar_botoes()
	if not _em_duelo():
		var usadas := int(resultado.get(0, MastermindRules.MAX_TENTATIVAS + 1))
		var venceu := usadas <= MastermindRules.MAX_TENTATIVAS
		var tempo := float(tempos.get(0, 0.0))
		var extra := {"mode": "solo", "moves": mini(usadas, MastermindRules.MAX_TENTATIVAS), "time": tempo}
		if venceu:
			extra["score"] = MastermindRules.pontuacao(usadas, tempo)
			extra["perfect"] = usadas <= 2
		extra["flags"] = _flags(usadas, false)
		finish_game(tr("SENHA_WIN") % usadas if venceu else tr("SENHA_LOSE"), venceu, extra)
		return
	var eu := table.local_index()
	var ele := 1 - eu
	var minhas := int(resultado.get(eu, MastermindRules.MAX_TENTATIVAS + 1))
	var dele := int(resultado.get(ele, MastermindRules.MAX_TENTATIVAS + 1))
	var venci := minhas < dele
	var empate := minhas == dele
	var tempo := float(tempos.get(eu, 0.0))
	var extra := {
		"mode": _nome_do_modo(),
		"moves": mini(minhas, MastermindRules.MAX_TENTATIVAS),
		"time": tempo,
		"draw": empate,
	}
	if minhas <= MastermindRules.MAX_TENTATIVAS:
		extra["score"] = MastermindRules.pontuacao(minhas, tempo)
		extra["perfect"] = venci and minhas <= 2
	extra["flags"] = _flags(minhas, venci)
	var msg: String
	if empate:
		msg = tr("DRAW_TITLE") if minhas > MastermindRules.MAX_TENTATIVAS else tr("SENHA_DUEL_DRAW") % _tent_txt(minhas)
	elif venci:
		msg = tr("SENHA_DUEL_WIN") % [_tent_txt(minhas), _tent_txt(dele)]
	else:
		msg = tr("SENHA_DUEL_LOSE") % [table.display_name(ele, self), _tent_txt(dele), _tent_txt(minhas)]
	finish_game(msg, venci, extra)


## Os fatos da partida que as conquistas leem (prefixo `senha_`).
func _flags(usadas: int, venceu_duelo: bool) -> Array[String]:
	var saida: Array[String] = []
	if usadas <= MastermindRules.MAX_TENTATIVAS:
		if usadas == 1:
			saida.append("senha_primeira")
		if usadas <= 3:
			saida.append("senha_tres")
		if posicoes >= 5:
			saida.append("senha_cinco_pos")
	if venceu_duelo:
		saida.append("senha_duelo")
	return saida


func _tent_txt(n: int) -> String:
	return str(n) if n <= MastermindRules.MAX_TENTATIVAS else "—"


func _esperando_resposta() -> bool:
	return not tentativas.is_empty() and int(tentativas[tentativas.size() - 1].get("black", -1)) < 0


## A linha da grade em uso: a que espera resposta, ou a proxima livre.
func _linha_atual_row() -> int:
	var k := tentativas.size()
	if _esperando_resposta():
		k -= 1
	return MastermindRules.MAX_TENTATIVAS - 1 - k


# ---------------------------------------------------------------- a maquina

## A maquina quebra o codigo daqui: pensa numa tarefa fora da linha principal
## e entra pelo mesmo `_aplicar` que a pessoa usa.
func _turno_ia() -> void:
	if game_over or fase != Fase.ASSISTIR or not table.ai_runs_here(breaker) or _ia_pensando:
		return
	if _esperando_resposta() or tentativas.size() >= MastermindRules.MAX_TENTATIVAS:
		return
	_ia_pensando = true
	var geracao := _geracao
	var arvore := get_tree()
	if pausa_ia > 0.0 and arvore != null:
		await arvore.create_timer(pausa_ia).timeout
		if not is_inside_tree() or geracao != _geracao:
			_ia_pensando = false
			return
	var palpite: Array[int] = await _pensar_palpite_ia()
	_ia_pensando = false
	if not is_inside_tree() or geracao != _geracao or game_over or fase != Fase.ASSISTIR:
		return
	var acao := {"t": "guess", "pins": palpite}
	_aplicar(breaker, acao)
	sync.send(breaker, acao)


## A tarefa recebe so dicionarios e arrays, nunca a cena: a cena pode ser
## fechada com a busca no ar. O ultimo feedback e registrado la dentro, junto
## com a enumeracao dos candidatos (ate 32768 codigos no degrau 9).
func _pensar_palpite_ia() -> Array[int]:
	var saida: Array = []
	var tarefa := WorkerThreadPool.add_task(MastermindAI.pensar_em_tarefa.bind(
		estado_ia, _ia_ultimo.duplicate(), _ia_ultimo_fb.duplicate(), ai_level, sync.rng.randi(), saida))
	_ia_ultimo = []
	_ia_ultimo_fb = {}
	# A arvore fica guardada antes do laco: se a pessoa sair da cena com a
	# busca em andamento, `get_tree()` vira `null` no quadro seguinte.
	var arvore := get_tree()
	while not WorkerThreadPool.is_task_completed(tarefa):
		if arvore == null:
			break
		await arvore.process_frame
	WorkerThreadPool.wait_for_task_completion(tarefa)
	if saida.is_empty():
		return MastermindAI.abertura(posicoes, cores, repete)
	var palpite: Array[int] = []
	for v in saida[0]:
		palpite.append(int(v))
	return palpite


# --------------------------------------------------------------------- toque

## Uma cor da paleta: entra na casa escolhida, ou na primeira vazia.
func _tocar_cor(cor: int) -> void:
	if game_over or (fase != Fase.MONTAR and fase != Fase.PALPITE) or cor < 0 or cor >= cores:
		return
	var alvo := _sel if _sel >= 0 else linha.find(-1)
	if alvo < 0:
		# Linha cheia e nada escolhido: a pessoa precisa tocar a casa que quer
		# trocar. Recusar calado pareceria toque perdido.
		if AudioManager:
			AudioManager.play_error()
		set_status(tr("SENHA_ROW_FULL"))
		return
	if fase == Fase.PALPITE and not shell.timer.active:
		shell.timer.start()
	_por_pino(alvo, cor)
	_sel = -1
	_pintar_estados()
	_atualizar_botoes()


func _por_pino(idx: int, cor: int) -> void:
	var antigo: Node3D = _pinos_linha[idx]
	if antigo != null:
		antigo.vanish()
	linha[idx] = cor
	_pinos_linha[idx] = _criar_pino(cor, _pos_da_casa(idx), pieces_root)
	if AudioManager:
		AudioManager.play_piece_place()


## Tocar uma casa da linha em composicao escolhe onde a proxima cor entra;
## soltar o dedo em outra casa da mesma linha troca os dois pinos de lugar
## (a peca que se move aceita arrastar, alem de dois toques).
func _on_grade_tocada(r: int, c: int) -> void:
	if fase != Fase.PALPITE or r != _linha_atual_row():
		return
	_tocar_casa(c)


func _on_grade_solta(r: int, c: int) -> void:
	if fase != Fase.PALPITE or r != _linha_atual_row():
		_press_col = -1
		return
	_soltar_casa(c)


func _on_codigo_tocado(_r: int, c: int) -> void:
	if fase != Fase.MONTAR:
		return
	_tocar_casa(c)


func _on_codigo_solto(_r: int, c: int) -> void:
	if fase != Fase.MONTAR:
		_press_col = -1
		return
	_soltar_casa(c)


func _tocar_casa(c: int) -> void:
	if game_over or c < 0 or c >= posicoes:
		return
	_press_col = c
	_sel = -1 if _sel == c else c
	play_click()
	_pintar_estados()
	_atualizar_botoes()


func _soltar_casa(c: int) -> void:
	var origem := _press_col
	_press_col = -1
	if origem < 0 or c < 0 or c >= posicoes or c == origem:
		return
	_trocar(origem, c)


func _trocar(a: int, b: int) -> void:
	var cor_a := linha[a]
	var cor_b := linha[b]
	if cor_a < 0 and cor_b < 0:
		return
	linha[a] = cor_b
	linha[b] = cor_a
	var pino_a: Node3D = _pinos_linha[a]
	var pino_b: Node3D = _pinos_linha[b]
	_pinos_linha[a] = pino_b
	_pinos_linha[b] = pino_a
	if pino_a != null:
		pino_a.slide_to(_pos_da_casa(b))
	if pino_b != null:
		pino_b.slide_to(_pos_da_casa(a))
	_sel = -1
	if AudioManager:
		AudioManager.play_piece_place()
	_pintar_estados()
	_atualizar_botoes()


func _on_apagar() -> void:
	if game_over or (fase != Fase.MONTAR and fase != Fase.PALPITE):
		return
	var idx := _sel if _sel >= 0 and linha[_sel] >= 0 else linha.rfind(_ultima_cor())
	if idx < 0 or linha[idx] < 0:
		return
	play_click()
	var pino: Node3D = _pinos_linha[idx]
	if pino != null:
		pino.vanish()
	_pinos_linha[idx] = null
	linha[idx] = -1
	_sel = -1
	_pintar_estados()
	_atualizar_botoes()


## A cor da ultima casa preenchida da linha, ou -1.
func _ultima_cor() -> int:
	for i in range(linha.size() - 1, -1, -1):
		if linha[i] >= 0:
			return linha[i]
	return -1


## "Conferir" no palpite, "Guardar codigo" na montagem.
func _on_conferir() -> void:
	if game_over or linha.find(-1) != -1:
		return
	play_click()
	if fase == Fase.MONTAR:
		if not MastermindRules.codigo_valido(linha, posicoes, cores, repete):
			set_status(tr("SENHA_NO_REPEAT"))
			if AudioManager:
				AudioManager.play_error()
			return
		codigo = linha.duplicate()
		var acao := {"t": "code_ready", "n": posicoes, "c": cores, "rep": repete}
		_aplicar(maker, acao)
		sync.send(maker, acao)
	elif fase == Fase.PALPITE:
		var acao := {"t": "guess", "pins": linha.duplicate()}
		_aplicar(breaker, acao)
		sync.send(breaker, acao)


func _on_modo() -> void:
	if net_active():
		return
	duelo = not duelo
	restart_game()


func _pintar_modo() -> void:
	btn_mode.text = tr("MODE_LABEL") % tr("SENHA_MODE_DUEL" if _em_duelo() else "SENHA_MODE_SOLO")


# ------------------------------------------------------------------- rede

func _on_net_move(payload: Dictionary) -> void:
	if sync == null:
		return
	var msg := sync.accept(payload)
	match str(msg.get("t", "")):
		"deal":
			if not _partida_iniciada:
				_iniciar_partida()
		"act":
			if _partida_iniciada:
				_aplicar(int(msg["seat"]), msg["a"])
			else:
				_pendentes.append(msg)


# --------------------------------------------------------------------- mesa

## Monta (ou remonta) as duas grades e a paleta no tamanho da configuracao e
## reenquadra a camera. So reconstrui quando o tamanho muda.
func _aplicar_config(n: int, c: int, rep: bool) -> void:
	posicoes = n
	cores = c
	repete = rep
	var alvo := Vector2i(n, c)
	if _montado_para == alvo:
		return
	_montado_para = alvo
	board_3d.setup_board(MastermindRules.MAX_TENTATIVAS, n + 1, CELL, "slate_grid")
	code_board.show_frame = false
	code_board.setup_board(1, n, CELL, "slate_grid")
	# A faixa do codigo fica acima da grade, alinhada as N colunas de palpite
	# (a grade tem uma coluna a mais, a de resposta, a direita).
	var meio_grade := MastermindRules.MAX_TENTATIVAS * CELL * 0.5
	code_board.position = Vector3(-CELL * 0.5, 0.0,
		-(meio_grade + Tokens3D.BOARD_FRAME_WIDTH + FOLGA_CODIGO + CELL * 0.5))
	_dimensionar_tampa()
	_montar_paleta()
	_enquadrar()


func _enquadrar() -> void:
	var bs := board_3d.content_size()
	var extra := FOLGA_CODIGO + CELL + 0.12
	# A grade e rasa e aceita ser vista quase de cima: teto alto de inclinacao,
	# senao em retrato sobra altura vazia.
	fit_table(Vector2(bs.x, bs.y + extra), Vector3(0.0, 0.0, -extra * 0.5), 82.0)


func _montar_paleta() -> void:
	for filho in palette.get_children():
		palette.remove_child(filho)
		filho.queue_free()
	palette.columns = int(ceil(cores / 2.0))
	for i in cores:
		var b := Button.new()
		b.name = "Cor%d" % i
		b.text = MastermindRules.simbolo(i)
		b.custom_minimum_size = Vector2(UIKit.TOQUE_MIN, UIKit.TOQUE_MIN)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 44)
		var texto := MastermindRules.cor_do_texto(i)
		b.add_theme_color_override("font_color", texto)
		b.add_theme_color_override("font_hover_color", texto)
		b.add_theme_color_override("font_pressed_color", texto)
		b.add_theme_color_override("font_disabled_color", texto.darkened(0.3))
		var cor := MastermindRules.cor(i)
		b.add_theme_stylebox_override("normal", _estilo_da_cor(cor))
		b.add_theme_stylebox_override("hover", _estilo_da_cor(cor.lightened(0.12)))
		b.add_theme_stylebox_override("pressed", _estilo_da_cor(cor.darkened(0.2)))
		b.add_theme_stylebox_override("disabled", _estilo_da_cor(cor.darkened(0.45)))
		b.pressed.connect(_tocar_cor.bind(i))
		palette.add_child(b)


func _estilo_da_cor(cor: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = cor
	sb.set_corner_radius_all(14)
	sb.set_border_width_all(3)
	sb.border_color = cor.darkened(0.45)
	return sb


func _limpar_mesa() -> void:
	for filho in pieces_root.get_children():
		filho.queue_free()
	for filho in feedback_root.get_children():
		filho.queue_free()
	_limpar_codigo_3d()
	pins_3d.clear()
	_pinos_linha = []
	_pinos_linha.resize(posicoes)
	linha = []
	linha.resize(posicoes)
	linha.fill(-1)
	_sel = -1
	_press_col = -1
	board_3d.clear_states()
	code_board.clear_states()


func _limpar_codigo_3d() -> void:
	for filho in code_root.get_children():
		filho.queue_free()


## Posicao no mundo da casa `idx` da linha em composicao.
func _pos_da_casa(idx: int) -> Vector3:
	if fase == Fase.MONTAR:
		return code_board.position + code_board.get_cell_position_3d(0, idx, ALTURA_PECA)
	return board_3d.position + board_3d.get_cell_position_3d(_linha_atual_row(), idx, ALTURA_PECA)


## Um pino: peca de plastico na cor, na forma da cor, com o simbolo da cor
## deitado em cima. Tres pistas para quem nao separa duas das cores.
func _criar_pino(cor: int, alvo: Vector3, pai: Node3D) -> Node3D:
	var tok: Token3D = TOKEN_SCENE.instantiate()
	tok.token_type = MastermindRules.forma(cor)
	tok.token_radius = RAIO_PINO
	tok.position = alvo + Vector3(0.0, 1.1, 0.0)
	pai.add_child(tok)
	tok.mesh_instance.material_override = MaterialFactory3D.get_plastic(MastermindRules.cor(cor))
	var rotulo := Label3D.new()
	rotulo.text = MastermindRules.simbolo(cor)
	rotulo.font_size = 96
	rotulo.pixel_size = 0.0028
	rotulo.outline_size = 14
	rotulo.modulate = MastermindRules.cor_do_texto(cor)
	rotulo.outline_modulate = MastermindRules.cor(cor).darkened(0.55)
	rotulo.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	rotulo.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	rotulo.position = Vector3(0.0, _altura_da_forma(tok.token_type) + 0.015, 0.0)
	tok.add_child(rotulo)
	tok.drop_to(alvo, Tokens3D.DUR_FAST)
	return tok


## Altura do topo de cada forma, a mesma conta do Token3D.
func _altura_da_forma(forma: String) -> float:
	match forma:
		"sphere":
			return RAIO_PINO * 1.72
		"pawn":
			return RAIO_PINO * 2.6
		_:
			return Tokens3D.TOKEN_HEIGHT


## Pinos de resposta da tentativa `idx`, na casa apagada a direita da linha:
## pretos primeiro, depois brancos, em duas colunas.
func _mostrar_resposta(idx: int, pretos: int, brancos: int) -> void:
	var row := MastermindRules.MAX_TENTATIVAS - 1 - idx
	var grupo := Node3D.new()
	grupo.name = "Resposta%d" % idx
	grupo.position = board_3d.position + board_3d.get_cell_position_3d(row, posicoes, Tokens3D.TILE_THICKNESS)
	feedback_root.add_child(grupo)
	var linhas := int(ceil(posicoes / 2.0))
	var passo := minf(0.22, (CELL - 0.12) / float(linhas))
	var mesh := MeshBuilder3D.peg_pin(PINO_RESPOSTA_ALTURA, PINO_RESPOSTA_RAIO)
	var preto := MaterialFactory3D.get_plastic(Color(0.05, 0.05, 0.06))
	var branco := MaterialFactory3D.get_plastic(Color(0.96, 0.95, 0.92))
	var k := 0
	for i in pretos + brancos:
		var pino := MeshInstance3D.new()
		pino.mesh = mesh
		pino.material_override = preto if i < pretos else branco
		var lin := k / 2
		var col := k % 2
		pino.position = Vector3((col - 0.5) * 0.24, 0.0, (lin - (linhas - 1) * 0.5) * passo)
		grupo.add_child(pino)
		k += 1


func _mostrar_codigo_3d() -> void:
	_limpar_codigo_3d()
	for i in codigo.size():
		_criar_pino(codigo[i], code_board.position + code_board.get_cell_position_3d(0, i, ALTURA_PECA), code_root)


## A tampa de madeira sobre a faixa do codigo.
func _montar_tampa() -> void:
	lid = MeshInstance3D.new()
	lid.name = "Tampa"
	lid.material_override = MaterialFactory3D.get_wood_walnut()
	var rotulo := Label3D.new()
	rotulo.text = "?"
	rotulo.font_size = 120
	rotulo.pixel_size = 0.003
	rotulo.outline_size = 12
	rotulo.modulate = UIKit.OURO
	rotulo.outline_modulate = Color(0.12, 0.08, 0.05)
	rotulo.billboard = BaseMaterial3D.BILLBOARD_DISABLED
	rotulo.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	rotulo.position = Vector3(0.0, TAMPA_ALTURA * 0.5 + 0.005, 0.0)
	lid.add_child(rotulo)
	lid_root.add_child(lid)


func _dimensionar_tampa() -> void:
	if lid == null:
		return
	var caixa := BoxMesh.new()
	caixa.size = Vector3(posicoes * CELL + 0.16, TAMPA_ALTURA, CELL + 0.16)
	lid.mesh = caixa
	lid_root.position = code_board.position + Vector3(0.0, Tokens3D.TILE_THICKNESS + TAMPA_ALTURA * 0.5 + 0.01, 0.0)
	lid.position = Vector3.ZERO
	lid.rotation_degrees = Vector3.ZERO


func _abrir_tampa(instantaneo: bool) -> void:
	_mover_tampa(Vector3(0.0, 0.9, -0.95), Vector3(-62.0, 0.0, 0.0), instantaneo)


func _fechar_tampa(instantaneo: bool) -> void:
	_mover_tampa(Vector3.ZERO, Vector3.ZERO, instantaneo)


func _mover_tampa(pos: Vector3, rot: Vector3, instantaneo: bool) -> void:
	if lid == null:
		return
	if _lid_tween != null and _lid_tween.is_valid():
		_lid_tween.kill()
	if instantaneo or not is_inside_tree():
		lid.position = pos
		lid.rotation_degrees = rot
		return
	_lid_tween = create_tween().set_parallel(true)
	_lid_tween.tween_property(lid, "position", pos, Tokens3D.DUR_SLOW) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_lid_tween.tween_property(lid, "rotation_degrees", rot, Tokens3D.DUR_SLOW) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## Estados das casas: a linha em uso acende, a casa escolhida ganha o anel,
## as linhas ainda por vir ficam apagadas (e a coluna de resposta sempre).
func _pintar_estados() -> void:
	var row := _linha_atual_row()
	var compondo := fase == Fase.PALPITE
	var em_uso := fase == Fase.PALPITE or fase == Fase.ASSISTIR
	for r in board_3d.rows:
		for c in board_3d.cols:
			var st := Board3D.CellState.NORMAL
			if c >= posicoes:
				st = Board3D.CellState.DISABLED
			elif em_uso and r == row:
				st = Board3D.CellState.SELECTED if compondo and c == _sel else Board3D.CellState.HIGHLIGHT
			elif r < row:
				st = Board3D.CellState.DISABLED
			board_3d.stage_cell_state(r, c, st)
	board_3d.commit_states()
	for c in code_board.cols:
		var st := Board3D.CellState.NORMAL
		if fase == Fase.MONTAR:
			st = Board3D.CellState.SELECTED if c == _sel else Board3D.CellState.HIGHLIGHT
		code_board.stage_cell_state(0, c, st)
	code_board.commit_states()


func _atualizar_botoes() -> void:
	var compondo := not game_over and (fase == Fase.MONTAR or fase == Fase.PALPITE)
	var cheia := compondo and linha.find(-1) == -1
	btn_check.text = tr("SENHA_BTN_LOCK") if fase == Fase.MONTAR else tr("SENHA_BTN_CHECK")
	btn_check.disabled = not cheia
	btn_erase.disabled = not compondo or _ultima_cor() < 0
	for b in palette.get_children():
		if b is Button:
			(b as Button).disabled = not compondo


## Solo: tentativas e tempo. Duelo: as tentativas de cada lado, e de quem e a
## vez.
func _pintar_placar() -> void:
	if table == null:
		return
	if not _em_duelo():
		set_counters([
			{"value": "%d/%d" % [tentativas.size(), MastermindRules.MAX_TENTATIVAS], "label": "SENHA_TRIES"},
			{"value": "%03d" % shell.timer.get_time(), "label": "SCORE_TIME"},
		])
		return
	var eu := table.local_index()
	var ele := 1 - eu
	set_duel_score(_placar_de(eu), _placar_de(ele), "NET_YOU",
		"NET_OPPONENT" if table.online() else "SCORE_AI")
	set_active_side(fase == Fase.MONTAR or fase == Fase.PALPITE)


func _placar_de(seat: int) -> String:
	if resultado.has(seat):
		return _tent_txt(int(resultado[seat]))
	if seat == breaker and fase != Fase.ESPERA:
		return str(tentativas.size())
	return "–"
