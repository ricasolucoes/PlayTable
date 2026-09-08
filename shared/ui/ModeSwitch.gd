class_name ModeSwitch
extends Button

## O botão que troca entre jogar contra a máquina e dois no mesmo aparelho.
##
## Existe como controle próprio, e não como um botão desenhado em cada cena, por
## dois motivos. O jogador aprende **um** lugar: em todo jogo que aceita dois, o
## botão está no mesmo canto, com o mesmo texto. E, ancorado no topo, ele entra
## na medição de `BaseGame._scan_hud`, então o tabuleiro se reenquadra sozinho em
## vez de ficar por baixo dele — o que importa nos jogos de mesa 3D, onde a
## câmera é calculada a partir da faixa de HUD medida em tempo de execução.
##
## O texto diz o modo em que a partida **está**, não o que o toque vai fazer:
## "Modo: vs IA" enquanto se joga contra a máquina. É a convenção que o Gamão já
## usava, e as chaves são as mesmas (`MODE_LABEL`, `MODE_VS_AI`,
## `MODE_TWO_PLAYERS`) — nenhum jogo precisa de chave própria para isto.
##
## Uso, no `_ready()` do jogo:
##
##     mode_switch = ModeSwitch.montar(self, vs_ai)
##     mode_switch.trocou.connect(_on_modo_trocado)
##
## e, quando a partida entra em rede, `mode_switch.hide()`: com dois aparelhos
## na mesa não há modo para escolher.

## O jogador trocou de modo. `vs_ai` já vem com o valor novo.
signal trocou(vs_ai: bool)

## Largura fixa: o texto muda de tamanho entre "Modo: vs IA" e
## "Modo: 2 Jogadores", e um botão que encolhe e cresce sob o dedo erra o alvo.
const LARGURA := 230.0

## Logo abaixo da barra de cima (`GameTopBar.BANDA` mais um respiro), no canto
## direito, que é onde o Jogo da Velha já o punha.
const TOPO := 134.0
const MARGEM := 24.0

var vs_ai := true


## Monta o botão dentro de `jogo` e devolve o controle. O jogo guarda a
## referência para poder escondê-lo em partida de rede.
static func montar(jogo: Control, comeca_vs_ai := true) -> ModeSwitch:
	var b := ModeSwitch.new()
	b.name = "ModeSwitch"
	b.vs_ai = comeca_vs_ai
	jogo.add_child(b)
	return b


func _ready() -> void:
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 0.0
	grow_horizontal = Control.GROW_DIRECTION_BEGIN
	offset_left = -(LARGURA + MARGEM)
	offset_right = -MARGEM
	offset_top = TOPO
	offset_bottom = TOPO + UIKit.TOQUE_MIN
	custom_minimum_size = Vector2(LARGURA, UIKit.TOQUE_MIN)
	add_theme_font_size_override("font_size", UIKit.FONTE_CORPO)
	focus_mode = Control.FOCUS_NONE
	pressed.connect(_on_pressed)
	_pintar()


func _on_pressed() -> void:
	if AudioManager:
		AudioManager.play_click()
	vs_ai = not vs_ai
	_pintar()
	trocou.emit(vs_ai)


## Troca o modo sem passar pelo toque -- para quem precisa forçar um modo (a
## partida em rede não é nem um nem outro) e para a suíte.
func definir(novo_vs_ai: bool) -> void:
	if vs_ai == novo_vs_ai:
		return
	vs_ai = novo_vs_ai
	_pintar()
	trocou.emit(vs_ai)


func _pintar() -> void:
	text = tr("MODE_LABEL") % tr("MODE_VS_AI" if vs_ai else "MODE_TWO_PLAYERS")
