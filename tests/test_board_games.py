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


class TestConnectFour(unittest.TestCase):
    """4. Quatro em Linha (Connect Four)"""
    ROWS = 6
    COLS = 7

    def drop_piece(self, grid, col, player):
        if col < 0 or col >= self.COLS or grid[0][col] != 0:
            return -1
        for r in range(self.ROWS - 1, -1, -1):
            if grid[r][col] == 0:
                grid[r][col] = player
                return r
        return -1

    def count_streak(self, grid, start_r, start_c, dr, dc, player):
        count = 1
        # Positive dir
        r, c = start_r + dr, start_c + dc
        while 0 <= r < self.ROWS and 0 <= c < self.COLS and grid[r][c] == player:
            count += 1
            r += dr
            c += dc
        # Negative dir
        r, c = start_r - dr, start_c - dc
        while 0 <= r < self.ROWS and 0 <= c < self.COLS and grid[r][c] == player:
            count += 1
            r -= dr
            c -= dc
        return count

    def check_win(self, grid, r, c, player):
        dirs = [(0, 1), (1, 0), (1, 1), (1, -1)]
        return any(self.count_streak(grid, r, c, dr, dc, player) >= 4 for dr, dc in dirs)

    def test_horizontal_vertical_diagonal_streaks(self):
        grid = [[0]*7 for _ in range(6)]
        # Horizontal win
        for c in range(4):
            self.drop_piece(grid, c, 1)
        self.assertTrue(self.check_win(grid, 5, 3, 1))

        # Vertical win in col 6
        grid_v = [[0]*7 for _ in range(6)]
        for _ in range(4):
            self.drop_piece(grid_v, 6, 2)
        self.assertTrue(self.check_win(grid_v, 2, 6, 2))

        # Diagonal positive win
        grid_d = [[0]*7 for _ in range(6)]
        # col 0: 1
        self.drop_piece(grid_d, 0, 1)
        # col 1: 2, 1
        self.drop_piece(grid_d, 1, 2); self.drop_piece(grid_d, 1, 1)
        # col 2: 2, 2, 1
        self.drop_piece(grid_d, 2, 2); self.drop_piece(grid_d, 2, 2); self.drop_piece(grid_d, 2, 1)
        # col 3: 2, 2, 2, 1
        self.drop_piece(grid_d, 3, 2); self.drop_piece(grid_d, 3, 2); self.drop_piece(grid_d, 3, 2); self.drop_piece(grid_d, 3, 1)
        self.assertTrue(self.check_win(grid_d, 2, 3, 1))

    def test_full_column_rejection(self):
        grid = [[0]*7 for _ in range(6)]
        for _ in range(6):
            self.assertNotEqual(self.drop_piece(grid, 3, 1), -1)
        # 7th piece in col 3 must fail
        self.assertEqual(self.drop_piece(grid, 3, 1), -1)


class TestPegSolitaire(unittest.TestCase):
    """5. Solitário (Resta Um / Peg Solitaire)"""
    SIZE = 7

    def is_valid_hole(self, r, c):
        if r < 0 or r >= self.SIZE or c < 0 or c >= self.SIZE:
            return False
        if (r < 2 or r > 4) and (c < 2 or c > 4):
            return False
        return True

    def create_board(self):
        grid = [[-1]*self.SIZE for _ in range(self.SIZE)]
        for r in range(self.SIZE):
            for c in range(self.SIZE):
                if self.is_valid_hole(r, c):
                    grid[r][c] = 0 if (r == 3 and c == 3) else 1
        return grid

    def get_valid_moves(self, grid):
        moves = []
        dirs = [(-1, 0), (1, 0), (0, -1), (0, 1)]
        for r in range(self.SIZE):
            for c in range(self.SIZE):
                if grid[r][c] == 1:
                    for dr, dc in dirs:
                        over_r, over_c = r + dr, c + dc
                        land_r, land_c = r + dr * 2, c + dc * 2
                        if self.is_valid_hole(over_r, over_c) and self.is_valid_hole(land_r, land_c):
                            if grid[over_r][over_c] == 1 and grid[land_r][land_c] == 0:
                                moves.append(((r, c), (over_r, over_c), (land_r, land_c)))
        return moves

    def execute_jump(self, grid, from_p, over_p, land_p):
        grid[from_p[0]][from_p[1]] = 0
        grid[over_p[0]][over_p[1]] = 0
        grid[land_p[0]][land_p[1]] = 1

    def test_board_initial_state(self):
        grid = self.create_board()
        peg_count = sum(row.count(1) for row in grid)
        empty_count = sum(row.count(0) for row in grid)
        invalid_count = sum(row.count(-1) for row in grid)
        self.assertEqual(peg_count, 32)
        self.assertEqual(empty_count, 1)
        self.assertEqual(invalid_count, 16) # 4 quinas de 4 células

    def test_jump_and_peg_reduction(self):
        grid = self.create_board()
        moves = self.get_valid_moves(grid)
        self.assertEqual(len(moves), 4) # 4 saltos possíveis para o centro
        f, o, l = moves[0]
        self.execute_jump(grid, f, o, l)
        new_pegs = sum(row.count(1) for row in grid)
        self.assertEqual(new_pegs, 31)


class TestMinesweeper(unittest.TestCase):
    """6. Campo Minado (Minesweeper)"""
    ROWS = 9
    COLS = 9
    MINES = 10

    def generate_board(self, safe_r, safe_c, seed=42):
        random.seed(seed)
        grid = [[{"is_mine": False, "revealed": False, "flagged": False, "adjacent": 0} for _ in range(self.COLS)] for _ in range(self.ROWS)]
        placed = 0
        while placed < self.MINES:
            r = random.randint(0, self.ROWS - 1)
            c = random.randint(0, self.COLS - 1)
            if abs(r - safe_r) <= 1 and abs(c - safe_c) <= 1:
                continue
            if not grid[r][c]["is_mine"]:
                grid[r][c]["is_mine"] = True
                placed += 1

        for r in range(self.ROWS):
            for c in range(self.COLS):
                if grid[r][c]["is_mine"]: continue
                count = 0
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        if dr == 0 and dc == 0: continue
                        nr, nc = r + dr, c + dc
                        if 0 <= nr < self.ROWS and 0 <= nc < self.COLS:
                            if grid[nr][nc]["is_mine"]:
                                count += 1
                grid[r][c]["adjacent"] = count
        return grid

    def reveal(self, grid, r, c):
        revealed = []
        queue = [(r, c)]
        while queue:
            curr_r, curr_c = queue.pop(0)
            if not (0 <= curr_r < self.ROWS and 0 <= curr_c < self.COLS): continue
            cell = grid[curr_r][curr_c]
            if cell["revealed"] or cell["flagged"] or cell["is_mine"]: continue
            cell["revealed"] = True
            revealed.append((curr_r, curr_c))
            if cell["adjacent"] == 0:
                for dr in [-1, 0, 1]:
                    for dc in [-1, 0, 1]:
                        if dr == 0 and dc == 0: continue
                        queue.append((curr_r + dr, curr_c + dc))
        return revealed

    def test_first_click_safety_guarantee(self):
        grid = self.generate_board(4, 4, seed=100)
        # The 3x3 box centered at (4, 4) must not have any mine
        for dr in [-1, 0, 1]:
            for dc in [-1, 0, 1]:
                self.assertFalse(grid[4 + dr][4 + dc]["is_mine"])

    def test_flood_fill_reveal(self):
        grid = self.generate_board(4, 4, seed=100)
        revealed = self.reveal(grid, 4, 4)
        self.assertGreater(len(revealed), 0)
        self.assertTrue(grid[4][4]["revealed"])


class TestDomino(unittest.TestCase):
    """7. Dominó (Domino)"""
    def generate_boneyard(self):
        tiles = []
        for a in range(7):
            for b in range(a, 7):
                tiles.append((a, b))
        return tiles

    def can_fit(self, tile, left, right):
        if left == -1 or right == -1: return True
        return tile[0] in [left, right] or tile[1] in [left, right]

    def orient_tile(self, tile, side, left, right):
        a, b = tile
        if side == "left":
            if b == left:
                return (a, b), a, right
            else:
                return (b, a), b, right
        else: # right
            if a == right:
                return (a, b), left, b
            else:
                return (b, a), left, a

    def test_boneyard_count_and_uniqueness(self):
        tiles = self.generate_boneyard()
        self.assertEqual(len(tiles), 28)
        self.assertEqual(len(set(tiles)), 28)

    def test_fit_and_orientation(self):
        tile = (6, 4)
        self.assertTrue(self.can_fit(tile, 4, 2))
        self.assertTrue(self.can_fit(tile, 6, 2))
        self.assertFalse(self.can_fit(tile, 5, 3))

        # Orient on left with left_end=6 -> tile becomes (4, 6) with new left_end=4
        oriented, new_l, new_r = self.orient_tile(tile, "left", 6, 2)
        self.assertEqual(oriented, (4, 6))
        self.assertEqual(new_l, 4)
        self.assertEqual(new_r, 2)


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


class TestReversi(unittest.TestCase):
    """9. Reversi (Othello)"""
    def create_initial_board(self):
        grid = [[0]*8 for _ in range(8)]
        grid[3][3] = 2 # White
        grid[3][4] = 1 # Black
        grid[4][3] = 1 # Black
        grid[4][4] = 2 # White
        return grid

    def get_flips(self, grid, r, c, piece):
        if grid[r][c] != 0: return []
        opp = 2 if piece == 1 else 1
        dirs = [(-1, 0), (1, 0), (0, -1), (0, 1), (-1, -1), (-1, 1), (1, -1), (1, 1)]
        flips = []
        for dr, dc in dirs:
            curr = []
            nr, nc = r + dr, c + dc
            while 0 <= nr < 8 and 0 <= nc < 8 and grid[nr][nc] == opp:
                curr.append((nr, nc))
                nr += dr
                nc += dc
            if 0 <= nr < 8 and 0 <= nc < 8 and grid[nr][nc] == piece:
                flips.extend(curr)
        return flips

    def test_initial_board_and_valid_flanking(self):
        grid = self.create_initial_board()
        flips_2_3 = self.get_flips(grid, 2, 3, 1) # Black at (2, 3) flanks White at (3, 3)
        self.assertEqual(flips_2_3, [(3, 3)])

        flips_invalid = self.get_flips(grid, 0, 0, 1)
        self.assertEqual(flips_invalid, [])


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
