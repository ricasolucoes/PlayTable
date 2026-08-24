class_name Tokens3D
extends RefCounted

## Tokens3D: Design tokens do sistema 3D do PlayTable.
##
## Fonte unica de verdade para alturas, tempos, escalas e curvas de animacao.
## Nenhum jogo deve inventar numeros magicos: se um valor visual se repete,
## ele mora aqui. Ver docs/design-3d.md.

# ---------------------------------------------------------------------------
# Tempos (segundos). Toda animacao do app escolhe um destes tres ritmos.
# ---------------------------------------------------------------------------
const DUR_INSTANT := 0.09  ## Feedback tatil: hover, press, toggle.
const DUR_FAST := 0.18     ## Selecao, destaque, snap.
const DUR_NORMAL := 0.32   ## Movimento de peca, virada de carta.
const DUR_SLOW := 0.55     ## Distribuicao, entrada de cena, captura.
const DUR_CELEBRATE := 1.4 ## Vitoria / derrota.

# ---------------------------------------------------------------------------
# Alturas relativas (em unidades de mundo). Mantem o "peso" coerente.
# ---------------------------------------------------------------------------
const LIFT_HOVER := 0.055      ## Elevacao ao passar o dedo/mouse.
const LIFT_SELECTED := 0.11    ## Peca escolhida, aguardando destino.
const LIFT_DRAG := 0.22        ## Peca sendo carregada pela mao.
const ARC_SHORT := 0.18        ## Arco de um passo curto.
const ARC_LONG := 0.42         ## Arco de captura / salto longo.

# ---------------------------------------------------------------------------
# Espessuras fisicas. Um objeto de mesa nunca e um plano.
# ---------------------------------------------------------------------------
const CARD_THICKNESS := 0.012
const CARD_WIDTH := 0.70
const CARD_LENGTH := 1.00
const TOKEN_HEIGHT := 0.13
const TILE_THICKNESS := 0.045
const BOARD_SLAB_THICKNESS := 0.16
const BOARD_FRAME_WIDTH := 0.30

# ---------------------------------------------------------------------------
# Camera. Angulos escolhidos para leitura de tabuleiro, nao para cinema.
# ---------------------------------------------------------------------------
const CAM_TILT_BOARD := 52.0   ## Tabuleiros quadrados: le linhas e colunas.
const CAM_TILT_CARDS := 44.0   ## Cartas: mostra a face sem achatar.
const CAM_TILT_TRACK := 58.0   ## Trilhas/percursos: mais de cima.
const CAM_FOV := 42.0          ## FOV contido: evita perspectiva exagerada.
const CAM_MARGIN := 1.12       ## Folga ao redor do conteudo enquadrado.

# ---------------------------------------------------------------------------
# Sombras e contato.
# ---------------------------------------------------------------------------
const CONTACT_SHADOW_OPACITY := 0.34
const CONTACT_SHADOW_GROW := 1.35

# ---------------------------------------------------------------------------
# Cores de estado. Nunca sao o UNICO sinal: sempre acompanham forma/altura.
# ---------------------------------------------------------------------------
const COLOR_VALID := Color(0.24, 0.78, 0.46)
const COLOR_SELECTED := Color(0.98, 0.78, 0.26)
const COLOR_INVALID := Color(0.88, 0.28, 0.24)
const COLOR_LAST_MOVE := Color(0.42, 0.66, 0.98)
const COLOR_HINT := Color(0.62, 0.72, 0.88)

## Curva padrao de "assentar": rapido no inicio, freia no fim.
static func ease_settle(tw: Tween) -> Tween:
	return tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## Curva padrao de "pegar": acelera saindo do lugar.
static func ease_lift(tw: Tween) -> Tween:
	return tw.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

## Curva de deslocamento completo entre dois pontos.
static func ease_travel(tw: Tween) -> Tween:
	return tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
