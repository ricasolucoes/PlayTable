extends Node

## Guarda de integridade do progresso local.
##
## O PlayTable e offline e single-player: nao ha o que roubar de outro jogador.
## O que se protege e o placar global do Play Games, que aceita o que o
## aparelho mandar -- um save adulterado viraria recorde mundial.
##
## O limitador e por *orcamento numa janela deslizante*, nao por numero de
## chamadas. A versao anterior barrava a partir da quarta concessao dentro de
## um segundo, e uma vitoria legitima concede facil cinco vezes no mesmo quadro
## (partida + missao diaria + tres conquistas em cascata): o jogador perdia o
## XP que tinha acabado de merecer. Contar XP em vez de chamadas separa a
## cascata legitima da injecao.

## Nenhuma concessao isolada passa disto. A maior do jogo e a Platina (20000).
const MAX_XP_PER_TRANSACTION := 25000

## Teto de XP numa janela. Uma sessao intensa honesta rende alguns milhares.
const MAX_XP_PER_WINDOW := 60000
const WINDOW_MS := 60000

var _window_start_ms: int = 0
var _window_total: int = 0
var _blocked_count: int = 0


func _ready() -> void:
	_window_start_ms = Time.get_ticks_msec()


## Chamado pelo RewardSystem antes de qualquer concessao de XP.
func validate_xp_gain(amount: int, source: String = "") -> bool:
	if amount <= 0:
		return false

	if amount > MAX_XP_PER_TRANSACTION:
		_reject("concessao unica acima do teto (%d, fonte %s)" % [amount, source])
		return false

	var agora := Time.get_ticks_msec()
	if agora - _window_start_ms >= WINDOW_MS:
		_window_start_ms = agora
		_window_total = 0

	if _window_total + amount > MAX_XP_PER_WINDOW:
		_reject("orcamento da janela estourado (%d + %d, fonte %s)" % [_window_total, amount, source])
		return false

	_window_total += amount
	return true


func _reject(motivo: String) -> void:
	_blocked_count += 1
	push_warning("SecurityManager: XP recusado -- %s" % motivo)


func blocked_count() -> int:
	return _blocked_count


## Assinatura do save local. Usada pelo CloudSaveSync para detectar que o
## arquivo foi trocado por fora entre duas sincronizacoes.
func generate_save_checksum(data_string: String) -> String:
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data_string.to_utf8_buffer())
	return ctx.finish().hex_encode()
