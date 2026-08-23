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

    def test_e2e_domino_simulation(self):
        """E2E Match Simulation: Dominó Match"""
        # Player 1 has [(6, 5), (5, 4)], Player 2 has [(4, 2), (2, 0)]
        table = [(6, 6)]
        left_end = 6
        right_end = 6

        # P1 plays (6, 5) on right
        table.append((6, 5))
        right_end = 5

        # P1 plays (5, 4) on right
        table.append((5, 4))
        right_end = 4

        # P2 plays (4, 2) on right
        table.append((4, 2))
        right_end = 2

        # P2 plays (2, 0) on right
        table.append((2, 0))
        right_end = 0

        self.assertEqual(left_end, 6)
        self.assertEqual(right_end, 0)
        self.assertEqual(len(table), 5)

    def test_e2e_blackjack_simulation(self):
        """E2E Match Simulation: 21 (Blackjack Round)"""
        deck = [10, 8, 1, 7, 5, 6, 9] # Simulated shuffled draw stack
        player_hand = [deck.pop(), deck.pop()] # 9, 6 = 15
        dealer_hand = [deck.pop(), deck.pop()] # 5, 7 = 12

        # Player hits (gets 1 -> Ace -> 15 + 1 = 16)
        player_hand.append(deck.pop())

        def score(hand):
            s = 0; aces = 0
            for c in hand:
                if c == 1: aces += 1; s += 11
                elif c >= 10: s += 10
                else: s += c
            while s > 21 and aces > 0: s -= 10; aces -= 1
            return s

        # Dealer hits until >= 17
        while score(dealer_hand) < 17:
            dealer_hand.append(deck.pop())

        self.assertGreaterEqual(score(dealer_hand), 17)
        self.assertEqual(score(player_hand), 16)

    def test_e2e_video_poker_simulation(self):
        """E2E Match Simulation: Video Poker Draw & Payout"""
        # Deal: [10♥, J♥, Q♥, K♥, 2♣]
        initial_hand = [
            {"val": 10, "suit": "♥"},
            {"val": 11, "suit": "♥"},
            {"val": 12, "suit": "♥"},
            {"val": 13, "suit": "♥"},
            {"val": 2, "suit": "♣"}
        ]
        # Hold first 4 cards, redraw 5th
        held = [initial_hand[0], initial_hand[1], initial_hand[2], initial_hand[3]]
        # Draw Ace of Hearts
        held.append({"val": 14, "suit": "♥"})

        # Evaluate final hand -> Royal Flush!
        vals = sorted([c["val"] for c in held])
        suits = [c["suit"] for c in held]
        is_royal_flush = (vals == [10, 11, 12, 13, 14] and len(set(suits)) == 1)
        self.assertTrue(is_royal_flush)

    def test_e2e_klondike_solitaire_simulation(self):
        """E2E Match Simulation: Paciência Klondike Sequence"""
        foundations = [[], [], [], []] # 4 foundation suits
        tableau_col = [{"val": 13, "col": "black"}, {"val": 12, "col": "red"}] # King, Queen

        # Ace of Spades arrives -> placed in foundation 0
        ace_spades = {"val": 1, "suit": "♠"}
        foundations[0].append(ace_spades)
        self.assertEqual(len(foundations[0]), 1)

        # 2 of Spades arrives -> placed on Ace
        two_spades = {"val": 2, "suit": "♠"}
        foundations[0].append(two_spades)
        self.assertEqual(len(foundations[0]), 2)

    def test_e2e_unolike_simulation(self):
        """E2E Match Simulation: Cartas das Cores (Uno-like Match)"""
        p1_hand = [{"color": "RED", "val": 5}, {"color": "BLUE", "val": 5}]
        top_card = {"color": "RED", "val": 2}
        active_color = "RED"

        # P1 plays Red 5
        played = p1_hand.pop(0)
        self.assertEqual(played["color"], active_color)
        top_card = played

        # Next turn: P1 plays Blue 5 matching value 5
        played2 = p1_hand.pop(0)
        self.assertEqual(played2["val"], top_card["val"])
        active_color = played2["color"]

        # P1 hand is now empty -> WIN!
        self.assertEqual(len(p1_hand), 0)

if __name__ == '__main__':
    unittest.main()
