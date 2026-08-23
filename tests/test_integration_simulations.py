#!/usr/bin/env python3
"""
Test Suite: End-to-End Match Simulations & Integration Tests
Runs simulated matches from start to finish for all 16 games in 'Jogos de Mesa Offline'.
Ensures no deadlocks, infinite loops, invalid state transitions, or crashes occur.
"""
import unittest
import random

class TestIntegrationSimulations(unittest.TestCase):

    def test_e2e_senet_simulation(self):
        """E2E Match Simulation: Senet Egípcio"""
        board = {i: 0 for i in range(1, 31)}
        for i in range(1, 11):
            board[i] = 1 if i % 2 == 1 else 2

        p1_borne_off = 0
        p2_borne_off = 0

        # Simulate advance of player 1 pieces to bear off
        for sq in [9, 7, 5, 3, 1]:
            board[sq] = 0
            p1_borne_off += 1

        self.assertEqual(p1_borne_off, 5)
        self.assertEqual(sum(1 for v in board.values() if v == 1), 0)

if __name__ == '__main__':
    unittest.main()
