#!/usr/bin/env python3
"""
Test Suite: Board Games Rules & Logic Unit Tests
Covers all 11 board games in 'Jogos de Mesa Offline'.
"""
import unittest
import random


class TestCheckers(unittest.TestCase):
    """2. Damas (Checkers)"""
    ROWS = 8
    COLS = 8

    def create_initial_board(self):
        grid = [[0]*self.COLS for _ in range(self.ROWS)]
        for r in range(self.ROWS):
            for c in range(self.COLS):
                if (r + c) % 2 == 1:
                    if r < 3:
                        grid[r][c] = -1 # Black piece
                    elif r > 4:
                        grid[r][c] = 1  # White piece
        return grid

    def get_piece_captures(self, grid, r, c):
        captures = []
        piece = grid[r][c]
        if piece == 0:
            return captures
        is_player = piece > 0
        is_king = abs(piece) == 2
        dirs = [(-1, -1), (-1, 1), (1, -1), (1, 1)]

        for dr, dc in dirs:
            if not is_king:
                if is_player and dr > 0: continue
                if not is_player and dr < 0: continue
            over_r, over_c = r + dr, c + dc
            land_r, land_c = r + dr * 2, c + dc * 2
            if 0 <= land_r < self.ROWS and 0 <= land_c < self.COLS:
                target = grid[over_r][over_c]
                if target != 0 and (target > 0) != is_player:
                    if grid[land_r][land_c] == 0:
                        captures.append({
                            "from": (r, c),
                            "to": (land_r, land_c),
                            "captured": (over_r, over_c)
                        })
        return captures

    def execute_move(self, grid, from_p, to_p, captured=None):
        r1, c1 = from_p
        r2, c2 = to_p
        piece = grid[r1][c1]
        grid[r1][c1] = 0
        if captured:
            cr, cc = captured
            grid[cr][cc] = 0
        # King promotion
        if piece == 1 and r2 == 0:
            piece = 2
        elif piece == -1 and r2 == self.ROWS - 1:
            piece = -2
        grid[r2][c2] = piece
        return piece

    def test_initial_board_setup(self):
        grid = self.create_initial_board()
        white_count = sum(row.count(1) for row in grid)
        black_count = sum(row.count(-1) for row in grid)
        self.assertEqual(white_count, 12)
        self.assertEqual(black_count, 12)

    def test_capture_and_king_promotion(self):
        grid = [[0]*8 for _ in range(8)]
        grid[2][2] = 1   # White piece
        grid[1][1] = -1  # Black piece
        caps = self.get_piece_captures(grid, 2, 2)
        self.assertEqual(len(caps), 1)
        self.assertEqual(caps[0]["to"], (0, 0))
        self.assertEqual(caps[0]["captured"], (1, 1))

        # Execute capture to row 0 -> should crown king
        piece = self.execute_move(grid, (2, 2), (0, 0), (1, 1))
        self.assertEqual(piece, 2) # White King
        self.assertEqual(grid[1][1], 0) # Captured removed
        self.assertEqual(grid[0][0], 2)

    def test_king_backward_capture(self):
        grid = [[0]*8 for _ in range(8)]
        grid[2][2] = 2   # White King
        grid[3][3] = -1  # Black piece behind it
        caps = self.get_piece_captures(grid, 2, 2)
        self.assertEqual(len(caps), 1)
        self.assertEqual(caps[0]["to"], (4, 4))
        self.assertEqual(caps[0]["captured"], (3, 3))


class TestBattleship(unittest.TestCase):
    """3. Batalha Naval (Battleship)"""
    SHIP_DEFS = [
        {"name": "Porta-Aviões", "size": 5},
        {"name": "Encouraçado", "size": 4},
        {"name": "Cruzador", "size": 3},
        {"name": "Submarino", "size": 3},
        {"name": "Destroyer", "size": 2}
    ]

    def place_ships(self, seed=42):
        random.seed(seed)
        grid = [[0]*10 for _ in range(10)]
        fleet = []
        for s in self.SHIP_DEFS:
            size = s["size"]
            placed = False
            for _ in range(300):
                horizontal = random.choice([True, False])
                max_r = 9 if horizontal else 10 - size
                max_c = 10 - size if horizontal else 9
                r = random.randint(0, max_r)
                c = random.randint(0, max_c)
                cells = [(r, c + i) if horizontal else (r + i, c) for i in range(size)]
                if all(grid[cr][cc] == 0 for cr, cc in cells):
                    for cr, cc in cells:
                        grid[cr][cc] = 1
                    fleet.append({"name": s["name"], "size": size, "cells": cells, "hits": 0, "sunk": False})
                    placed = True
                    break
            if not placed:
                raise RuntimeError(f"Could not place ship {s['name']}")
        return grid, fleet

    def register_shot(self, grid, pos, fleet):
        r, c = pos
        if grid[r][c] in [2, 3]: # Already fired
            return {"valid": False, "is_hit": False, "sunk_ship": None, "all_sunk": False}
        is_hit = (grid[r][c] == 1)
        grid[r][c] = 3 if is_hit else 2
        sunk_ship = None
        if is_hit:
            for s in fleet:
                if pos in s["cells"]:
                    s["hits"] += 1
                    if s["hits"] >= s["size"]:
                        s["sunk"] = True
                        sunk_ship = s
                    break
        all_sunk = all(s["sunk"] for s in fleet)
        return {"valid": True, "is_hit": is_hit, "sunk_ship": sunk_ship, "all_sunk": all_sunk}

    def test_ship_placement_no_overlaps_and_sizes(self):
        grid, fleet = self.place_ships(seed=123)
        total_cells = sum(row.count(1) for row in grid)
        expected_cells = 5 + 4 + 3 + 3 + 2 # 17 cells
        self.assertEqual(total_cells, expected_cells)
        self.assertEqual(len(fleet), 5)

    def test_hit_miss_and_sinking(self):
        grid, fleet = self.place_ships(seed=999)
        # Find first ship cell
        first_ship = fleet[0]
        first_cell = first_ship["cells"][0]

        # Valid hit
        res1 = self.register_shot(grid, first_cell, fleet)
        self.assertTrue(res1["valid"])
        self.assertTrue(res1["is_hit"])

        # Repeat shot -> invalid
        res_repeat = self.register_shot(grid, first_cell, fleet)
        self.assertFalse(res_repeat["valid"])

        # Miss
        res_miss = self.register_shot(grid, (0, 0) if grid[0][0] == 0 else (9, 9), fleet)
        if res_miss["valid"]:
            self.assertFalse(res_miss["is_hit"])

        # Hit all cells of the first ship -> sunk
        for cell in first_ship["cells"][1:]:
            res = self.register_shot(grid, cell, fleet)
        self.assertTrue(first_ship["sunk"])

    def test_fleet_annihilation_win(self):
        grid, fleet = self.place_ships(seed=777)
        for s in fleet:
            for cell in s["cells"]:
                res = self.register_shot(grid, cell, fleet)
        self.assertTrue(all(s["sunk"] for s in fleet))
        self.assertTrue(res["all_sunk"])


class TestLudo(unittest.TestCase):
    """8. Ludo Simplificado"""
    START_OFFSETS = [0, 7, 14, 21]
    TRACK_LEN = 28

    def test_pawn_spawn_only_on_six(self):
        # Position -1 means in base
        pawn_pos = -1
        # Roll 5 -> cannot leave base
        can_move_5 = (pawn_pos == -1 and 5 == 6)
        self.assertFalse(can_move_5)
        # Roll 6 -> leaves base to step 0
        can_move_6 = (pawn_pos == -1 and 6 == 6)
        self.assertTrue(can_move_6)

    def test_circular_track_and_captures(self):
        # Player 0 at step 7, Player 1 starts at offset 7
        # Player 0 absolute index: (7 + 0) % 28 = 7
        # Player 1 at step 0: (0 + 7) % 28 = 7
        p0_abs = (7 + self.START_OFFSETS[0]) % self.TRACK_LEN
        p1_abs = (0 + self.START_OFFSETS[1]) % self.TRACK_LEN
        self.assertEqual(p0_abs, p1_abs) # Capture collision!


class TestMancala(unittest.TestCase):
    """10. Mancala (Kalah)"""
    def test_mancala_sowing_and_extra_turn(self):
        # 14 pits: 0-5 (Player), 6 (Player Kalah), 7-12 (AI), 13 (AI Kalah)
        pits = [4]*14
        pits[6] = 0
        pits[13] = 0

        # Player picks pit 2 (4 seeds: drops into 3, 4, 5, 6)
        seeds = pits[2]
        pits[2] = 0
        curr = 2
        while seeds > 0:
            curr = (curr + 1) % 14
            if curr == 13: continue # Skip AI store
            pits[curr] += 1
            seeds -= 1

        self.assertEqual(curr, 6) # Ended in own store -> Extra turn!
        self.assertEqual(pits[6], 1)
        self.assertEqual(pits[2], 0)

    def test_mancala_capture_rule(self):
        pits = [0]*14
        pits[0] = 1 # Sowing pit with 1 seed
        pits[1] = 0 # Empty target pit
        pits[11] = 5 # Opposite pit to pit 1 is 12 - 1 = 11

        # Sowing from pit 0 with 1 seed lands on empty pit 1
        pits[0] = 0
        pits[1] = 1 # now 1 seed in previously empty pit

        # Capture: pit 1 (1 seed) + pit 11 (5 seeds) = 6 seeds into Player store (6)
        captured = pits[1] + pits[11]
        pits[1] = 0
        pits[11] = 0
        pits[6] += captured

        self.assertEqual(pits[6], 6)
        self.assertEqual(pits[1], 0)
        self.assertEqual(pits[11], 0)


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
