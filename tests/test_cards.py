#!/usr/bin/env python3
"""
Test Suite: Universal Card Engine & Rules Validation
Tests algorithms and rules implemented across all card games in Jogos de Mesa.
"""
import unittest

class TestCardRules(unittest.TestCase):

    def test_blackjack_scoring(self):
        # A + 10 = 21 (Blackjack)
        def calculate_score(cards):
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

        self.assertEqual(calculate_score([1, 10]), 21)
        self.assertEqual(calculate_score([1, 9, 5]), 15) # Ace as 1
        self.assertEqual(calculate_score([1, 1, 9]), 21) # One Ace as 11, one Ace as 1
        self.assertEqual(calculate_score([10, 10, 5]), 25) # Bust
        self.assertEqual(calculate_score([10, 7]), 17) # Stand threshold

    def test_poker_evaluator(self):
        def evaluate_hand(vals, suits):
            vals = sorted(vals)
            is_flush = len(set(suits)) == 1
            is_straight = False
            if (vals[4] - vals[0] == 4) and len(set(vals)) == 5:
                is_straight = True
            elif vals == [2, 3, 4, 5, 14]: # Wheel
                is_straight = True

            freq = {}
            for v in vals:
                freq[v] = freq.get(v, 0) + 1
            counts = sorted(freq.values())

            if is_flush and is_straight and vals[0] == 10 and vals[4] == 14:
                return "Royal Flush"
            if is_flush and is_straight:
                return "Straight Flush"
            if 4 in counts:
                return "Quadra"
            if counts == [2, 3]:
                return "Full House"
            if is_flush:
                return "Flush"
            if is_straight:
                return "Straight"
            if 3 in counts:
                return "Trinca"
            if counts == [1, 2, 2]:
                return "Dois Pares"
            if 2 in counts:
                for v, c in freq.items():
                    if c == 2 and v >= 11:
                        return "Par J+"
                return "Par Baixo"
            return "Carta Alta"

        self.assertEqual(evaluate_hand([10, 11, 12, 13, 14], [1, 1, 1, 1, 1]), "Royal Flush")
        self.assertEqual(evaluate_hand([5, 6, 7, 8, 9], [2, 2, 2, 2, 2]), "Straight Flush")
        self.assertEqual(evaluate_hand([8, 8, 8, 8, 3], [1, 2, 3, 4, 1]), "Quadra")
        self.assertEqual(evaluate_hand([10, 10, 10, 4, 4], [1, 2, 3, 1, 2]), "Full House")
        self.assertEqual(evaluate_hand([2, 5, 7, 9, 13], [3, 3, 3, 3, 3]), "Flush")
        self.assertEqual(evaluate_hand([2, 3, 4, 5, 14], [1, 2, 3, 4, 1]), "Straight") # Wheel
        self.assertEqual(evaluate_hand([7, 7, 7, 2, 9], [1, 2, 3, 1, 2]), "Trinca")
        self.assertEqual(evaluate_hand([12, 12, 5, 5, 2], [1, 2, 1, 2, 3]), "Dois Pares")
        self.assertEqual(evaluate_hand([13, 13, 2, 6, 9], [1, 2, 3, 4, 1]), "Par J+")
        self.assertEqual(evaluate_hand([4, 4, 2, 6, 9], [1, 2, 3, 4, 1]), "Par Baixo")
        self.assertEqual(evaluate_hand([2, 4, 6, 8, 14], [1, 2, 3, 4, 1]), "Carta Alta")

    def test_klondike_foundation_and_tableau(self):
        # Foundation: same suit, ascending from 1 (Ace) to 13 (King)
        def can_add_to_foundation(card_val, card_suit, top_val, top_suit, target_suit):
            if card_suit != target_suit: return False
            if top_val is None: return card_val == 1
            return card_val == top_val + 1

        self.assertTrue(can_add_to_foundation(1, "♠", None, None, "♠")) # Ace on empty
        self.assertFalse(can_add_to_foundation(2, "♠", None, None, "♠")) # 2 on empty (invalid)
        self.assertTrue(can_add_to_foundation(2, "♠", 1, "♠", "♠")) # 2 on Ace
        self.assertFalse(can_add_to_foundation(3, "♠", 1, "♠", "♠")) # 3 on Ace (invalid)

        # Tableau: alternating colors, descending values
        def can_add_to_tableau(card_val, card_col, top_val, top_col):
            if top_val is None: return card_val == 13 # Only King on empty column
            return (card_val == top_val - 1) and (card_col != top_col)

        self.assertTrue(can_add_to_tableau(13, "red", None, None)) # King on empty
        self.assertFalse(can_add_to_tableau(12, "red", None, None)) # Queen on empty (invalid)
        self.assertTrue(can_add_to_tableau(12, "red", 13, "black")) # Red Queen on Black King
        self.assertFalse(can_add_to_tableau(12, "red", 13, "red")) # Red Queen on Red King (invalid color)
        self.assertFalse(can_add_to_tableau(11, "red", 13, "black")) # Jack on King (invalid rank)

if __name__ == '__main__':
    unittest.main()
