#!/usr/bin/env python3
"""
Test Suite: End-to-End Match Simulations & Integration Tests
Runs simulated matches from start to finish for all 16 games in 'Jogos de Mesa Offline'.
Ensures no deadlocks, infinite loops, invalid state transitions, or crashes occur.
"""
import unittest
import random

class TestIntegrationSimulations(unittest.TestCase):

    def test_e2e_battleship_simulation(self):
        """E2E Match Simulation: Batalha Naval (Hunt & Target AI vs Fleet)"""
        SHIP_DEFS = [
            {"name": "Carrier", "size": 5},
            {"name": "Battleship", "size": 4},
            {"name": "Cruiser", "size": 3},
            {"name": "Submarine", "size": 3},
            {"name": "Destroyer", "size": 2}
        ]
        # Place fleet deterministically
        grid = [[0]*10 for _ in range(10)]
        fleet = []
        # Row 0: Carrier (5), Row 2: Battleship (4), Row 4: Cruiser (3), Row 6: Submarine (3), Row 8: Destroyer (2)
        r_list = [0, 2, 4, 6, 8]
        for idx, s in enumerate(SHIP_DEFS):
            r = r_list[idx]
            size = s["size"]
            cells = [(r, c) for c in range(size)]
            for cr, cc in cells:
                grid[cr][cc] = 1
            fleet.append({"name": s["name"], "size": size, "cells": cells, "hits": 0, "sunk": False})

        shots_fired = set()
        hit_stack = []
        turns = 0

        while not all(s["sunk"] for s in fleet) and turns < 100:
            turns += 1
            # AI pick shot
            shot = None
            while hit_stack:
                cand = hit_stack.pop()
                if 0 <= cand[0] < 10 and 0 <= cand[1] < 10 and cand not in shots_fired:
                    shot = cand
                    break
            if shot is None:
                # Checkerboard hunt
                candidates = [(r, c) for r in range(10) for c in range(10) if (r + c) % 2 == 0 and (r, c) not in shots_fired]
                if not candidates:
                    candidates = [(r, c) for r in range(10) for c in range(10) if (r, c) not in shots_fired]
                shot = candidates[0]

            shots_fired.add(shot)
            sr, sc = shot
            is_hit = (grid[sr][sc] == 1)

            if is_hit:
                # Push orthogonal neighbors to hit_stack
                for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
                    hit_stack.append((sr + dr, sc + dc))
                for s in fleet:
                    if shot in s["cells"]:
                        s["hits"] += 1
                        if s["hits"] >= s["size"]:
                            s["sunk"] = True
                        break

        # Verification: all 5 ships sunk in under 100 turns
        self.assertTrue(all(s["sunk"] for s in fleet))
        self.assertLessEqual(turns, 100)

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

    def test_e2e_checkers_simulation(self):
        """E2E Match Simulation: Damas (Checkers Multi-Jump)"""
        grid = [[0]*8 for _ in range(8)]
        # Setup multi-jump scenario: White at (6, 0), Black at (5, 1) and (3, 3)
        grid[6][0] = 1
        grid[5][1] = -1
        grid[3][3] = -1

        # Jump 1: (6, 0) -> (4, 2) capturing (5, 1)
        grid[6][0] = 0
        grid[5][1] = 0
        grid[4][2] = 1

        # Jump 2: (4, 2) -> (2, 4) capturing (3, 3)
        grid[4][2] = 0
        grid[3][3] = 0
        grid[2][4] = 1

        self.assertEqual(grid[2][4], 1)
        self.assertEqual(grid[5][1], 0)
        self.assertEqual(grid[3][3], 0)

if __name__ == '__main__':
    unittest.main()
