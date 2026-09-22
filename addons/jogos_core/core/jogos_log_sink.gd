class_name JogosLogSink
extends RefCounted

## Destino de log (arquivo, overlay, telemetria...).
##
## Extraído de VOLTA `src/core/log/log_sink.gd`. Generalização: a categoria
## virou `String` (era um enum com as áreas do VOLTA), então cada jogo nomeia
## as suas sem tocar na lib. A base falha alto se usada direta, para deixar
## claro que um sink concreto tem de sobrescrever `write`.


func write(_level: int, _category: String, _key: String, _data: Dictionary) -> void:
	push_error("JogosLogSink.write() não implementado em %s" % [get_script()])
