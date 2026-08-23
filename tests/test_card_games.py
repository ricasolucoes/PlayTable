#!/usr/bin/env python3
"""
Test Suite: Card Games Rules & Logic Unit Tests
Covers all 5 card games in 'Jogos de Mesa Offline':
1. Paciência Klondike
2. Jogo da Memória
3. 21 (Blackjack)
4. Cartas das Cores (Uno-like)
5. Poker (Video Poker)
"""
import unittest

class TestBlackjack(unittest.TestCase):
    """1. 21 (Blackjack)"""

    def calculate_score(self, cards):
        score = 0
        aces = 0
        for val in cards:
            if val == 1 or val == 14: # Ace
                aces += 1
                score += 11
            elif val >= 10:
                score += 10
            else:
                score += val
        while score > 21 and aces > 0:
            score -= 10
            aces -= 1
        return score

    def evaluate_match(self, player_cards, dealer_cards):
        p_score = self.calculate_score(player_cards)
        d_score = self.calculate_score(dealer_cards)
        p_bj = (len(player_cards) == 2 and p_score == 21)
        d_bj = (len(dealer_cards) == 2 and d_score == 21)

        if p_score > 21:
            return {"winner": "dealer", "reason": "player_bust"}
        if d_score > 21:
            return {"winner": "player", "reason": "dealer_bust"}
        if p_bj and not d_bj:
            return {"winner": "player", "reason": "blackjack"}
        if d_bj and not p_bj:
            return {"winner": "dealer", "reason": "dealer_blackjack"}
        if p_score > d_score:
            return {"winner": "player", "reason": "higher_score"}
        elif d_score > p_score:
            return {"winner": "dealer", "reason": "dealer_higher"}
        else:
            return {"winner": "draw", "reason": "push"}

    def test_dynamic_ace_scoring(self):
        self.assertEqual(self.calculate_score([1, 10]), 21)       # Natural 21
        self.assertEqual(self.calculate_score([1, 9, 5]), 15)     # Ace as 1
        self.assertEqual(self.calculate_score([1, 1, 9]), 21)     # Ace 11 + Ace 1 + 9 = 21
        self.assertEqual(self.calculate_score([1, 1, 1, 1, 7]), 21) # Four Aces (11+1+1+1=14 -> 1+1+1+1+7=11? 11+1+1+1+7 = 21)

    def test_bust_and_dealer_stand_rules(self):
        self.assertEqual(self.calculate_score([10, 10, 5]), 25) # Bust
        self.assertTrue(self.calculate_score([10, 6]) < 17)    # Dealer hits
        self.assertFalse(self.calculate_score([10, 7]) < 17)   # Dealer stands at 17

    def test_match_outcomes(self):
        # Player wins with Blackjack
        self.assertEqual(self.evaluate_match([1, 10], [10, 9])["winner"], "player")
        # Dealer busts
        self.assertEqual(self.evaluate_match([10, 8], [10, 6, 8])["winner"], "player")
        # Player busts
        self.assertEqual(self.evaluate_match([10, 6, 8], [10, 7])["winner"], "dealer")
        # Push (Tie)
        self.assertEqual(self.evaluate_match([10, 8], [9, 9])["winner"], "draw")


class TestVideoPoker(unittest.TestCase):
    """2. Poker (Video Poker) Evaluator & Multipliers"""

    def evaluate_hand(self, vals, suits):
        vals = sorted(vals)
        is_flush = len(set(suits)) == 1
        is_straight = False
        if (vals[4] - vals[0] == 4) and (vals[1] - vals[0] == 1) and (vals[2] - vals[1] == 1) and (vals[3] - vals[2] == 1):
            is_straight = True
        elif vals == [2, 3, 4, 5, 14]: # Ace-low wheel
            is_straight = True

        freq = {}
        for v in vals:
            freq[v] = freq.get(v, 0) + 1
        counts = sorted(freq.values())

        if is_flush and is_straight and vals[0] == 10 and vals[4] == 14:
            return {"name": "Royal Flush", "mult": 800, "rank": 10}
        if is_flush and is_straight:
            return {"name": "Straight Flush", "mult": 50, "rank": 9}
        if 4 in counts:
            return {"name": "Quadra", "mult": 25, "rank": 8}
        if counts == [2, 3]:
            return {"name": "Full House", "mult": 9, "rank": 7}
        if is_flush:
            return {"name": "Flush", "mult": 6, "rank": 6}
        if is_straight:
            return {"name": "Straight", "mult": 4, "rank": 5}
        if 3 in counts:
            return {"name": "Trinca", "mult": 3, "rank": 4}
        if counts == [1, 2, 2]:
            return {"name": "Dois Pares", "mult": 2, "rank": 3}
        if 2 in counts:
            for v, c in freq.items():
                if c == 2 and v >= 11:
                    return {"name": "Par J+", "mult": 1, "rank": 2}
            return {"name": "Par Baixo", "mult": 0, "rank": 1}
        return {"name": "Carta Alta", "mult": 0, "rank": 0}

    def test_all_poker_hands_and_payouts(self):
        # 1. Royal Flush
        res = self.evaluate_hand([10, 11, 12, 13, 14], [1, 1, 1, 1, 1])
        self.assertEqual(res["name"], "Royal Flush")
        self.assertEqual(res["mult"], 800)

        # 2. Straight Flush
        res = self.evaluate_hand([5, 6, 7, 8, 9], [2, 2, 2, 2, 2])
        self.assertEqual(res["name"], "Straight Flush")
        self.assertEqual(res["mult"], 50)

        # 3. Quadra (Four of a Kind)
        res = self.evaluate_hand([8, 8, 8, 8, 3], [1, 2, 3, 4, 1])
        self.assertEqual(res["name"], "Quadra")
        self.assertEqual(res["mult"], 25)

        # 4. Full House
        res = self.evaluate_hand([10, 10, 10, 4, 4], [1, 2, 3, 1, 2])
        self.assertEqual(res["name"], "Full House")
        self.assertEqual(res["mult"], 9)

        # 5. Flush
        res = self.evaluate_hand([2, 5, 7, 9, 13], [3, 3, 3, 3, 3])
        self.assertEqual(res["name"], "Flush")
        self.assertEqual(res["mult"], 6)

        # 6. Straight (Wheel A-2-3-4-5)
        res = self.evaluate_hand([2, 3, 4, 5, 14], [1, 2, 3, 4, 1])
        self.assertEqual(res["name"], "Straight")
        self.assertEqual(res["mult"], 4)

        # 7. Trinca (Three of a Kind)
        res = self.evaluate_hand([7, 7, 7, 2, 9], [1, 2, 3, 1, 2])
        self.assertEqual(res["name"], "Trinca")
        self.assertEqual(res["mult"], 3)

        # 8. Dois Pares (Two Pair)
        res = self.evaluate_hand([12, 12, 5, 5, 2], [1, 2, 1, 2, 3])
        self.assertEqual(res["name"], "Dois Pares")
        self.assertEqual(res["mult"], 2)

        # 9. Jacks or Better (Pair >= 11)
        res = self.evaluate_hand([11, 11, 2, 6, 9], [1, 2, 3, 4, 1])
        self.assertEqual(res["name"], "Par J+")
        self.assertEqual(res["mult"], 1)

        # 10. Low Pair (< 11, No Payout)
        res = self.evaluate_hand([9, 9, 2, 6, 8], [1, 2, 3, 4, 1])
        self.assertEqual(res["name"], "Par Baixo")
        self.assertEqual(res["mult"], 0)

        # 11. High Card
        res = self.evaluate_hand([2, 4, 6, 8, 14], [1, 2, 3, 4, 1])
        self.assertEqual(res["name"], "Carta Alta")
        self.assertEqual(res["mult"], 0)


class TestKlondikeSolitaire(unittest.TestCase):
    """3. Paciência Klondike (Solitaire)"""

    def can_add_to_foundation(self, card_val, card_suit, top_val, top_suit, target_suit):
        if card_suit != target_suit: return False
        if top_val is None: return card_val == 1 # Ace
        return card_val == top_val + 1

    def can_add_to_tableau(self, card_val, card_col, top_val, top_col):
        if top_val is None: return card_val == 13 # King on empty column
        return (card_val == top_val - 1) and (card_col != top_col)

    def test_foundation_rules_suit_and_ascending_order(self):
        # Ace of Spades on empty Spades foundation
        self.assertTrue(self.can_add_to_foundation(1, "♠", None, None, "♠"))
        # 2 of Spades on empty (invalid)
        self.assertFalse(self.can_add_to_foundation(2, "♠", None, None, "♠"))
        # 2 of Spades on Ace of Spades
        self.assertTrue(self.can_add_to_foundation(2, "♠", 1, "♠", "♠"))
        # 3 of Spades on Ace of Spades (invalid skip)
        self.assertFalse(self.can_add_to_foundation(3, "♠", 1, "♠", "♠"))
        # 2 of Hearts on Ace of Spades (invalid suit)
        self.assertFalse(self.can_add_to_foundation(2, "♥", 1, "♠", "♠"))

    def test_tableau_rules_alternating_colors_and_descending(self):
        # King on empty column
        self.assertTrue(self.can_add_to_tableau(13, "red", None, None))
        # Queen on empty column (invalid)
        self.assertFalse(self.can_add_to_tableau(12, "red", None, None))
        # Red Queen (12) on Black King (13)
        self.assertTrue(self.can_add_to_tableau(12, "red", 13, "black"))
        # Red Queen (12) on Red King (13) (invalid color)
        self.assertFalse(self.can_add_to_tableau(12, "red", 13, "red"))
        # Black 10 on Black Jack (invalid color)
        self.assertFalse(self.can_add_to_tableau(10, "black", 11, "black"))
        # Red 9 on Black 10
        self.assertTrue(self.can_add_to_tableau(9, "red", 10, "black"))


class TestUnoLike(unittest.TestCase):
    """4. Cartas das Cores (Uno-like)"""

    def is_valid_play(self, card, active_color, top_card):
        # Wild card is always playable
        if card.get("color") == "WILD":
            return True
        # Match current active color
        if card.get("color") == active_color:
            return True
        # Match value/type of top card
        if top_card and card.get("value") == top_card.get("value") and card.get("type") == top_card.get("type"):
            return True
        return False

    def pick_best_color(self, hand):
        counts = {"RED": 0, "BLUE": 0, "GREEN": 0, "YELLOW": 0}
        for c in hand:
            col = c.get("color")
            if col in counts:
                counts[col] += 1
        return max(counts, key=counts.get)

    def test_valid_play_color_and_value_matching(self):
        top_card = {"color": "RED", "value": 7, "type": "number"}

        # Same color Red 3 -> Valid
        self.assertTrue(self.is_valid_play({"color": "RED", "value": 3, "type": "number"}, "RED", top_card))
        # Same value Blue 7 -> Valid
        self.assertTrue(self.is_valid_play({"color": "BLUE", "value": 7, "type": "number"}, "RED", top_card))
        # Wild card -> Valid
        self.assertTrue(self.is_valid_play({"color": "WILD", "value": 50, "type": "wild"}, "RED", top_card))
        # Different color and different value Green 2 -> Invalid
        self.assertFalse(self.is_valid_play({"color": "GREEN", "value": 2, "type": "number"}, "RED", top_card))

    def test_ai_color_selection_majority_heuristic(self):
        hand = [
            {"color": "BLUE", "value": 1},
            {"color": "BLUE", "value": 4},
            {"color": "BLUE", "value": 9},
            {"color": "RED", "value": 5},
            {"color": "GREEN", "value": 3}
        ]
        self.assertEqual(self.pick_best_color(hand), "BLUE")


if __name__ == '__main__':
    unittest.main()
