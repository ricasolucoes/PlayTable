class_name PokerEvaluator
extends RefCounted

const CardScript = preload("res://shared/core_engine/cards/Card.gd")

static func evaluate_hand(cards: Array) -> Dictionary:
	if cards.size() < 5:
		return {"name": "Mão Incompleta", "mult": 0, "rank": 0}
		
	var vals: Array[int] = []
	var suits: Array[int] = []
	
	for c in cards:
		if c is Card:
			vals.append(c.value)
			suits.append(int(c.suit))
		elif c is Dictionary:
			vals.append(int(c.get("value", c.get("val", 0))))
			suits.append(int(c.get("suit", 0)))
			
	vals.sort()
	
	# Checagem de Flush (todas do mesmo naipe)
	var is_flush = (suits[0] == suits[1] and suits[1] == suits[2] and suits[2] == suits[3] and suits[3] == suits[4])
	
	# Checagem de Straight (sequência)
	var is_straight = false
	if (vals[4] - vals[0] == 4) and (vals[1] - vals[0] == 1) and (vals[2] - vals[1] == 1) and (vals[3] - vals[2] == 1):
		is_straight = true
	elif vals == [2, 3, 4, 5, 14]: # Straight com Ás baixo (A-2-3-4-5)
		is_straight = true
		
	# Contagem de frequências
	var freq: Dictionary = {}
	for v in vals:
		freq[v] = freq.get(v, 0) + 1
	var counts = freq.values()
	counts.sort()
	
	# 1. Royal Flush
	if is_flush and is_straight and vals[0] == 10 and vals[4] == 14:
		return {"name": "Royal Flush", "mult": 800, "rank": 10}
		
	# 2. Straight Flush
	if is_flush and is_straight:
		return {"name": "Straight Flush", "mult": 50, "rank": 9}
		
	# 3. Quadra
	if 4 in counts:
		return {"name": "Quadra (4 of a Kind)", "mult": 25, "rank": 8}
		
	# 4. Full House
	if counts == [2, 3]:
		return {"name": "Full House", "mult": 9, "rank": 7}
		
	# 5. Flush
	if is_flush:
		return {"name": "Flush (Cor)", "mult": 6, "rank": 6}
		
	# 6. Sequência (Straight)
	if is_straight:
		return {"name": "Sequência (Straight)", "mult": 4, "rank": 5}
		
	# 7. Trinca
	if 3 in counts:
		return {"name": "Trinca (3 of a Kind)", "mult": 3, "rank": 4}
		
	# 8. Dois Pares
	if counts == [1, 2, 2]:
		return {"name": "Dois Pares", "mult": 2, "rank": 3}
		
	# 9. Par de Valetes ou Maior (Jacks or Better: J=11, Q=12, K=13, A=14)
	if 2 in counts:
		for v in freq:
			if freq[v] == 2 and v >= 11:
				return {"name": "Par de Valetes ou Maior", "mult": 1, "rank": 2}
		return {"name": "Par Baixo (Sem prêmio)", "mult": 0, "rank": 1}
		
	return {"name": "Carta Alta (Sem prêmio)", "mult": 0, "rank": 0}
