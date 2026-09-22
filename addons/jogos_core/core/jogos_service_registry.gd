class_name JogosServiceRegistry
extends RefCounted

## Registro de serviços para quem prefere injeção a autoload.
##
## Extraído de VOLTA `src/core/service_registry.gd` sem alteração de
## comportamento: `resolve()` de um serviço inexistente falha com erro legível
## que lista o que existe, nunca com `null` silencioso. `JogosBootstrap` monta
## o grafo aqui; as telas recebem o registro e pedem o que precisam.

var _services: Dictionary = {}
var _last_error: String = ""


func register(service_name: String, instance: Object) -> bool:
	if _services.has(service_name):
		_last_error = "service_already_registered:%s" % service_name
		push_error("JogosServiceRegistry: '%s' já registrado" % service_name)
		return false
	_services[service_name] = instance
	return true


func resolve(service_name: String) -> Object:
	if not _services.has(service_name):
		_last_error = "service_not_found:%s" % service_name
		push_error("JogosServiceRegistry: serviço '%s' não encontrado. Registrados: %s" % [service_name, _services.keys()])
		return null
	return _services[service_name]


## Como `resolve`, mas sem reclamar: para dependência opcional.
func resolve_or_null(service_name: String) -> Object:
	return _services.get(service_name, null)


func has(service_name: String) -> bool:
	return _services.has(service_name)


func names() -> PackedStringArray:
	var out: PackedStringArray = []
	for key: Variant in _services.keys():
		out.append(str(key))
	return out


func get_last_error() -> String:
	return _last_error
