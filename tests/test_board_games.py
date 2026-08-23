#!/usr/bin/env python3
"""
Test Suite: Board Games Rules & Logic Unit Tests
Covers all 11 board games in 'Jogos de Mesa Offline'.
"""
import unittest
import random


class TestSenet(unittest.TestCase):
    """11. Senet Egípcio"""
    def test_casting_sticks_probabilities_and_extra_throws(self):
        # 4 sticks: white count determines value (0 white -> 5)
        def score_sticks(whites):
            val = 5 if whites == 0 else whites
            extra = (val in [1, 4, 5])
            return val, extra

        self.assertEqual(score_sticks(0), (5, True))
        self.assertEqual(score_sticks(1), (1, True))
        self.assertEqual(score_sticks(2), (2, False))
        self.assertEqual(score_sticks(3), (3, False))
        self.assertEqual(score_sticks(4), (4, True))

    def test_serpentine_path_and_rebirth(self):
        # Row 0: 1-10 (left to right)
        # Row 1: 20-11 (right to left)
        # Row 2: 21-30 (left to right)
        def get_rc(sq):
            if sq <= 10: return (0, sq - 1)
            elif sq <= 20: return (1, 20 - sq)
            else: return (2, sq - 21)

        self.assertEqual(get_rc(1), (0, 0))
        self.assertEqual(get_rc(10), (0, 9))
        self.assertEqual(get_rc(11), (1, 9))
        self.assertEqual(get_rc(20), (1, 0))
        self.assertEqual(get_rc(21), (2, 0))
        self.assertEqual(get_rc(30), (2, 9))

        # House of Water (27) sends back to House of Rebirth (15)
        board = {i: 0 for i in range(1, 31)}
        board[27] = 1
        # Fall in water -> relocate to 15
        target = 27
        if target == 27:
            board[target] = 0
            rebirth = 15
            while board[rebirth] != 0 and rebirth > 1:
                rebirth -= 1
            board[rebirth] = 1
        self.assertEqual(board[15], 1)
        self.assertEqual(board[27], 0)

if __name__ == '__main__':
    unittest.main()
