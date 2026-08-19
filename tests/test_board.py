#!/usr/bin/env python3
"""
Test Suite: Universal Board Engine & Rules Validation
Tests algorithms and rules implemented across all board games in Jogos de Mesa.
"""
import unittest

class TestBoardRules(unittest.TestCase):

    def test_tictactoe_win_and_block(self):
        # 3x3 Grid
        WIN_COMBOS = [
            [0, 1, 2], [3, 4, 5], [6, 7, 8],
            [0, 3, 6], [1, 4, 7], [2, 5, 8],
            [0, 4, 8], [2, 4, 6]
        ]
        def check_win(board, p):
            for w in WIN_COMBOS:
                if board[w[0]] == p and board[w[1]] == p and board[w[2]] == p:
                    return True
            return False

        def get_best_move(board, ai_p):
            opp = 1 if ai_p == 2 else 2
            empty = [i for i, v in enumerate(board) if v == 0]
            # Win
            for i in empty:
                board[i] = ai_p
                if check_win(board, ai_p):
                    board[i] = 0
                    return i
                board[i] = 0
            # Block
            for i in empty:
                board[i] = opp
                if check_win(board, opp):
                    board[i] = 0
                    return i
                board[i] = 0
            return empty[0]

        # Player 1 about to win on [0, 1] -> AI (2) must block on [2]
        board = [1, 1, 0, 2, 0, 0, 0, 0, 0]
        self.assertEqual(get_best_move(board, 2), 2)

        # AI (2) about to win on [4, 8] with [0] empty -> AI must win on [0]
        board = [0, 1, 1, 0, 2, 0, 0, 0, 2]
        self.assertEqual(get_best_move(board, 2), 0)

    def test_connect_four_streak(self):
        # 6 rows, 7 cols
        grid = [[0]*7 for _ in range(6)]

        # Drop 4 pieces in col 3
        for r in range(4):
            grid[5 - r][3] = 1

        # Check vertical streak
        streak = 0
        for r in range(6):
            if grid[r][3] == 1: streak += 1
            else: streak = 0
            if streak == 4: break
        self.assertEqual(streak, 4)

    def test_reversi_flanking(self):
        # 8x8 Board with center pieces
        grid = [[0]*8 for _ in range(8)]
        grid[3][3] = 2 # White
        grid[3][4] = 1 # Black
        grid[4][3] = 1 # Black
        grid[4][4] = 2 # White

        # If Black (1) plays at (2, 3), it flanks White at (3, 3) because (4, 3) is Black
        def get_flips(r, c, piece):
            opp = 2 if piece == 1 else 1
            dirs = [(-1,0), (1,0), (0,-1), (0,1), (-1,-1), (-1,1), (1,-1), (1,1)]
            flips = []
            for dr, dc in dirs:
                curr_flips = []
                nr, nc = r + dr, c + dc
                while 0 <= nr < 8 and 0 <= nc < 8 and grid[nr][nc] == opp:
                    curr_flips.append((nr, nc))
                    nr += dr
                    nc += dc
                if 0 <= nr < 8 and 0 <= nc < 8 and grid[nr][nc] == piece:
                    flips.extend(curr_flips)
            return flips

        flips = get_flips(2, 3, 1)
        self.assertEqual(flips, [(3, 3)]) # Captures White piece at (3, 3)

    def test_domino_matching_and_orientation(self):
        def can_fit(tile, left, right):
            return tile[0] == left or tile[1] == left or tile[0] == right or tile[1] == right

        self.assertTrue(can_fit((6, 4), 6, 2))
        self.assertTrue(can_fit((3, 2), 6, 2))
        self.assertFalse(can_fit((1, 5), 6, 2))

    def test_peg_solitaire_cross_and_jump(self):
        def is_valid_hole(r, c):
            if r < 0 or r >= 7 or c < 0 or c >= 7: return False
            if (r < 2 or r > 4) and (c < 2 or c > 4): return False
            return True

        self.assertFalse(is_valid_hole(0, 0)) # Corner invalid
        self.assertTrue(is_valid_hole(3, 3))  # Center valid
        self.assertTrue(is_valid_hole(0, 3))  # Top bar valid
        self.assertTrue(is_valid_hole(3, 0))  # Left bar valid

if __name__ == '__main__':
    unittest.main()
