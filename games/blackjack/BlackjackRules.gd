class_name BlackjackRules
extends RefCounted

## Rules and logic for Blackjack.

enum Winner {
	PLAYER,
	DEALER,
	PUSH
}

static func calculate_hand_value(cards: Array) -> int:
	return calculate_score(cards)

static func is_busted(cards: Array) -> bool:
	return is_bust(cards)

static func should_dealer_hit(cards: Array) -> bool:
	return dealer_should_hit(cards)

static func determine_winner(player_cards: Array, dealer_cards: Array) -> Winner:
	var res := evaluate_match(player_cards, dealer_cards)
	if res["winner"] == "player": return Winner.PLAYER
	elif res["winner"] == "dealer": return Winner.DEALER
	else: return Winner.PUSH

static func calculate_score(cards: Array) -> int:
	var score: int = 0
	var aces: int = 0
	for item in cards:
		var val = item.value if (item is Card) else int(item.get("value", item.get("val", 0)))
		if val == 1 or val == 14: # Ás
			aces += 1
			score += 11
		elif val >= 10: # 10, J, Q, K
			score += 10
		else:
			score += val
			
	while score > 21 and aces > 0:
		score -= 10
		aces -= 1
		
	return score

static func is_bust(cards: Array) -> bool:
	return calculate_score(cards) > 21

static func is_blackjack(cards: Array) -> bool:
	return cards.size() == 2 and calculate_score(cards) == 21

static func dealer_should_hit(cards: Array) -> bool:
	return calculate_score(cards) < 17

static func evaluate_match(player_cards: Array, dealer_cards: Array) -> Dictionary:
	var p_score := calculate_score(player_cards)
	var d_score := calculate_score(dealer_cards)
	
	if p_score > 21:
		return {"winner": "dealer", "reason": "player_bust", "message": "Estourou! Você Perdeu."}
	if d_score > 21:
		return {"winner": "player", "reason": "dealer_bust", "message": "Dealer Estourou! Você Venceu."}
	if is_blackjack(player_cards) and not is_blackjack(dealer_cards):
		return {"winner": "player", "reason": "blackjack", "message": "Blackjack! Você Venceu!"}
	if is_blackjack(dealer_cards) and not is_blackjack(player_cards):
		return {"winner": "dealer", "reason": "dealer_blackjack", "message": "Dealer fez Blackjack!"}
		
	if p_score > d_score:
		return {"winner": "player", "reason": "higher_score", "message": "Você Venceu!"}
	elif d_score > p_score:
		return {"winner": "dealer", "reason": "dealer_higher", "message": "Dealer Venceu!"}
	else:
		return {"winner": "draw", "reason": "push", "message": "Empate!"}
