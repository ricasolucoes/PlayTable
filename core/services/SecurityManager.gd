extends Node

## Gerenciador Simples de Anti-Cheat Local.
##
## Impede abusos rudimentares baseados em modificação de memória (GameGuardian)
## e limites absurdos de injeção de eventos no GameEventBus.

var _last_xp_gain_time: int = 0
var _xp_gain_burst_count: int = 0

const MAX_XP_BURST_PER_SEC = 3
const MAX_XP_PER_TRANSACTION = 5000

func _ready() -> void:
	# Como este Manager fica no nível mais alto, interceptamos eventos perigosos,
	# mas como estamos validando no lado cliente de um jogo offline, 
	# a proteção foca em integridade de design.
	pass

## Chamado pelo GamificationManager ANTES de conceder XP
func validate_xp_gain(amount: int) -> bool:
	if amount > MAX_XP_PER_TRANSACTION:
		push_warning("Security: XP injection attempt blocked (too high).")
		return false
		
	var current_time = Time.get_ticks_msec()
	if current_time - _last_xp_gain_time < 1000: # menos de 1 segundo
		_xp_gain_burst_count += 1
		if _xp_gain_burst_count > MAX_XP_BURST_PER_SEC:
			push_warning("Security: XP rate limit exceeded.")
			return false
	else:
		_xp_gain_burst_count = 1
		
	_last_xp_gain_time = current_time
	return true

## Cria um "hash" simplificado para validar se o arquivo de save foi adulterado maliciosamente.
func generate_save_checksum(data_string: String) -> String:
	# Simula um HMAC simples baseado no SHA256 para dificultar alterações manuais
	# no arquivo cfg local por jogadores mal intencionados antes do CloudSave.
	var ctx = HashingContext.new()
	ctx.start(HashingContext.HASH_SHA256)
	ctx.update(data_string.to_utf8_buffer())
	var res = ctx.finish()
	return res.hex_encode()
