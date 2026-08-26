class_name HanoiRules
extends RefCounted

## HanoiRules: Motor de regras puras e algoritmos do jogo Torres de Hanói.
##
## Implementa as regras matemáticas clássicas de Édouard Lucas (1883),
## validação de movimentos, gerador da sequência de solução ótima recursiva
## (2^n - 1 jogadas), pilha de desfazer/refazer e cálculo de estrelas.

const MIN_DISKS: int = 3
const MAX_DISKS: int = 8
const PEG_COUNT: int = 3

const PEG_ORIGEM: int = 0
const PEG_AUXILIAR: int = 1
const PEG_DESTINO: int = 2


## Cria a estrutura de pinos inicial com N discos no pino de origem (0).
## Discos são representados por inteiros de 1 (menor) a N (maior).
## A base da pilha fica no índice 0 e o topo no último índice.
static func create_initial_pegs(disk_count: int) -> Array[Array]:
	var clamped_count := clampi(disk_count, MIN_DISKS, MAX_DISKS)
	var pegs: Array[Array] = [[], [], []]
	for d in range(clamped_count, 0, -1):
		pegs[PEG_ORIGEM].append(d)
	return pegs


## Retorna o disco do topo de um pino (0 se o pino estiver vazio).
static func get_top_disk(peg: Array) -> int:
	if peg.is_empty():
		return 0
	return int(peg[peg.size() - 1])


## Valida se o disco do topo de `from_peg` pode ser transferido para `to_peg`.
## Regra: Nenhum disco maior pode ser pousado sobre um menor.
static func can_move_disk(pegs: Array[Array], from_peg: int, to_peg: int) -> bool:
	if from_peg < 0 or from_peg >= PEG_COUNT or to_peg < 0 or to_peg >= PEG_COUNT:
		return false
	if from_peg == to_peg:
		return false
	if pegs[from_peg].is_empty():
		return false
		
	var moving_disk := get_top_disk(pegs[from_peg])
	if pegs[to_peg].is_empty():
		return true
		
	var target_top := get_top_disk(pegs[to_peg])
	return moving_disk < target_top


## Executa o movimento de um disco entre pinos se for válido.
static func execute_move(pegs: Array[Array], from_peg: int, to_peg: int) -> Dictionary:
	if not can_move_disk(pegs, from_peg, to_peg):
		return {"success": false, "disk": 0, "from": from_peg, "to": to_peg}
		
	var disk: int = pegs[from_peg].pop_back()
	pegs[to_peg].append(disk)
	return {"success": true, "disk": disk, "from": from_peg, "to": to_peg}


## Desfaz um movimento registrado no histórico.
static func undo_move(pegs: Array[Array], move: Dictionary) -> bool:
	if not move.has("from") or not move.has("to") or not move.has("disk"):
		return false
	var from_peg: int = move["from"]
	var to_peg: int = move["to"]
	var disk: int = move["disk"]
	
	if pegs[to_peg].is_empty() or get_top_disk(pegs[to_peg]) != disk:
		return false
		
	pegs[to_peg].pop_back()
	pegs[from_peg].append(disk)
	return true


## Verifica se o jogador venceu o jogo (todos os discos transferidos para o pino de destino).
static func is_won(pegs: Array[Array], disk_count: int, target_peg: int = PEG_DESTINO) -> bool:
	if target_peg < 0 or target_peg >= PEG_COUNT:
		return false
	var peg: Array = pegs[target_peg]
	if peg.size() != disk_count:
		return false
		
	for i in range(disk_count):
		var expected := disk_count - i
		if peg[i] != expected:
			return false
	return true


## Retorna o número mínimo teórico de movimentos para resolver a torre com N discos (2^n - 1).
static func get_optimal_moves(disk_count: int) -> int:
	return int(pow(2, clampi(disk_count, MIN_DISKS, MAX_DISKS))) - 1


## Calcula a pontuação em estrelas (1 a 3 estrelas) baseado na eficiência de movimentos.
static func calculate_stars(moves: int, disk_count: int) -> int:
	var optimal := get_optimal_moves(disk_count)
	if moves <= optimal:
		return 3
	elif moves <= int(float(optimal) * 1.5) + 2:
		return 2
	return 1


## Gera a lista sequencial de passos para a solução ótima recursiva.
static func generate_optimal_solution(disk_count: int, from_peg: int = PEG_ORIGEM,
		to_peg: int = PEG_DESTINO, aux_peg: int = PEG_AUXILIAR) -> Array[Dictionary]:
	var solution: Array[Dictionary] = []
	_solve_recursive(disk_count, from_peg, to_peg, aux_peg, solution)
	return solution


static func _solve_recursive(n: int, source: int, target: int, auxiliary: int, solution: Array[Dictionary]) -> void:
	if n <= 0:
		return
	if n == 1:
		solution.append({"from": source, "to": target})
		return
	_solve_recursive(n - 1, source, auxiliary, target, solution)
	solution.append({"from": source, "to": target})
	_solve_recursive(n - 1, auxiliary, target, source, solution)


## Clona a estrutura de pinos para simulações ou histórico.
static func clone_pegs(pegs: Array[Array]) -> Array[Array]:
	var copy: Array[Array] = []
	for peg in pegs:
		copy.append(peg.duplicate())
	return copy


## Encontra a melhor próxima jogada (dica) para o estado atual em direção à solução do pino alvo.
## Usa busca em largura (BFS) pelo grafo de estados da Torre de Hanói.
static func get_next_hint(current_pegs: Array[Array], disk_count: int, target_peg: int = PEG_DESTINO) -> Dictionary:
	if is_won(current_pegs, disk_count, target_peg):
		return {}

	# BFS para encontrar o menor caminho até a vitória
	var queue: Array = []
	var visited: Dictionary = {}
	
	var initial_state := _encode_state(current_pegs)
	visited[initial_state] = true
	
	# Cada nó na fila guarda [pegs_state, first_move]
	for f in range(PEG_COUNT):
		for t in range(PEG_COUNT):
			if can_move_disk(current_pegs, f, t):
				var next_pegs := clone_pegs(current_pegs)
				execute_move(next_pegs, f, t)
				var state_key := _encode_state(next_pegs)
				var first_move := {"from": f, "to": t}
				if is_won(next_pegs, disk_count, target_peg):
					return first_move
				visited[state_key] = true
				queue.append({"pegs": next_pegs, "first_move": first_move})
				
	while not queue.is_empty():
		var node: Dictionary = queue.pop_front()
		var p: Array[Array] = node["pegs"]
		var first_mv: Dictionary = node["first_move"]
		
		for f in range(PEG_COUNT):
			for t in range(PEG_COUNT):
				if can_move_disk(p, f, t):
					var next_p := clone_pegs(p)
					execute_move(next_p, f, t)
					if is_won(next_p, disk_count, target_peg):
						return first_mv
					var k := _encode_state(next_p)
					if not visited.has(k):
						visited[k] = true
						# Limite de busca para evitar explosão de memória
						if queue.size() < 1200:
							queue.append({"pegs": next_p, "first_move": first_mv})
							
	# Fallback para qualquer movimento válido que avance
	for f in range(PEG_COUNT):
		for t in range(PEG_COUNT):
			if can_move_disk(current_pegs, f, t):
				return {"from": f, "to": t}
	return {}


static func _encode_state(pegs: Array[Array]) -> String:
	return "%s|%s|%s" % [str(pegs[0]), str(pegs[1]), str(pegs[2])]
