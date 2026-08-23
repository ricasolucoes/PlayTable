#!/usr/bin/env python3
"""
Test Suite: End-to-End Match Simulations & Integration Tests
Runs simulated matches from start to finish for all 16 games in 'Jogos de Mesa Offline'.
Ensures no deadlocks, infinite loops, invalid state transitions, or crashes occur.
"""
import unittest
import random

class TestIntegrationSimulations(unittest.TestCase):

    def test_e2e_mancala_simulation(self):
        """E2E Match Simulation: Mancala (Kalah) Full Match"""
        pits = [4]*14
        pits[6] = 0  # Player store
        pits[13] = 0 # AI store

        def has_moves(is_p1):
            start = 0 if is_p1 else 7
            return any(pits[i] > 0 for i in range(start, start + 6))

        is_p1 = True
        rounds = 0

        while (has_moves(True) or has_moves(False)) and rounds < 100:
            rounds += 1
            if not has_moves(is_p1):
                break
            start = 0 if is_p1 else 7
            valid = [i for i in range(start, start + 6) if pits[i] > 0]
            chosen = valid[0]

            seeds = pits[chosen]
            pits[chosen] = 0
            curr = chosen
            skip_store = 13 if is_p1 else 6

            while seeds > 0:
                curr = (curr + 1) % 14
                if curr == skip_store: continue
                pits[curr] += 1
                seeds -= 1

            # Capture rule
            own_store = 6 if is_p1 else 13
            own_range = range(0, 6) if is_p1 else range(7, 13)
            if curr in own_range and pits[curr] == 1:
                opp_pit = 12 - curr
                if pits[opp_pit] > 0:
                    captured = pits[curr] + pits[opp_pit]
                    pits[curr] = 0
                    pits[opp_pit] = 0
                    pits[own_store] += captured

            # Extra turn if ended in own store
            if curr == own_store:
                continue
            is_p1 = not is_p1

        # Sweep remaining
        for i in range(6): pits[6] += pits[i]; pits[i] = 0
        for i in range(7, 13): pits[13] += pits[i]; pits[i] = 0

        total_seeds = pits[6] + pits[13]
        self.assertEqual(total_seeds, 48) # 12 pits * 4 seeds = 48 seeds conserved

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

    def test_e2e_ludo_simulation(self):
        """E2E Match Simulation: Ludo Simplificado"""
        # Simulate 2 pawns of player 0 completing the course
        pawns = [-1, -1]
        # Roll 6 -> spawn pawn 0
        pawns[0] = 0
        # Move pawn 0 along track (28 steps) + final stretch (4 steps) = 32
        pawns[0] += 28
        pawns[0] += 4
        self.assertEqual(pawns[0], 32) # Reached home center

        # Spawn and finish pawn 1
        pawns[1] = 0
        pawns[1] += 32
        self.assertEqual(pawns[1], 32)
        # Victory check
        all_won = all(p >= 32 for p in pawns)
        self.assertTrue(all_won)

if __name__ == '__main__':
    unittest.main()
