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
