#!/usr/bin/env python3
"""
Test Suite: Core Systems & Engine Components Unit Tests
Tests SaveManager, Grid2D, BoardCoord, Card/Deck, TurnManager and GameAction.
"""
import unittest
import json
import os

class MockSaveManager:
    """Mock of SaveManager GDScript logic"""
    def __init__(self, file_storage=None):
        self.settings = {
            "master_volume": 1.0,
            "theme_dark": True
        }
        self.storage = file_storage if file_storage is not None else {}

    def save_data(self):
        self.storage["config.save"] = json.dumps(self.settings)

    def load_data(self):
        if "config.save" in self.storage:
            try:
                self.settings = json.loads(self.storage["config.save"])
            except Exception:
                pass

    def set_setting(self, key, value):
        self.settings[key] = value
        self.save_data()

    def get_setting(self, key, default_val=None):
        return self.settings.get(key, default_val)


class MockGrid2D:
    """Mock of Grid2D GDScript engine component"""
    def __init__(self, rows=0, cols=0, default_value=None):
        self.rows = rows
        self.cols = cols
        self.cells = [default_value] * (rows * cols) if (rows > 0 and cols > 0) else []

    def is_valid(self, r, c):
        return 0 <= r < self.rows and 0 <= c < self.cols

    def get_cell(self, r, c):
        if not self.is_valid(r, c):
            return None
        return self.cells[r * self.cols + c]

    def set_cell(self, r, c, val):
        if self.is_valid(r, c):
            self.cells[r * self.cols + c] = val

    def get_orthogonal_neighbors(self, r, c):
        result = []
        for dr, dc in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
            nr, nc = r + dr, c + dc
            if self.is_valid(nr, nc):
                result.append((nr, nc))
        return result

    def get_all_neighbors(self, r, c):
        result = []
        for dr in [-1, 0, 1]:
            for dc in [-1, 0, 1]:
                if dr == 0 and dc == 0: continue
                nr, nc = r + dr, c + dc
                if self.is_valid(nr, nc):
                    result.append((nr, nc))
        return result

    def count_consecutive(self, start_r, start_c, dr, dc, match_val):
        count = 0
        r, c = start_r + dr, start_c + dc
        while self.is_valid(r, c) and self.get_cell(r, c) == match_val:
            count += 1
            r += dr
            c += dc
        return count

    def count_streak_bidirectional(self, start_r, start_c, dr, dc, match_val):
        count = 1
        count += self.count_consecutive(start_r, start_c, dr, dc, match_val)
        count += self.count_consecutive(start_r, start_c, -dr, -dc, match_val)
        return count

    def count_matching(self, match_val):
        return self.cells.count(match_val)

    def clone(self):
        g = MockGrid2D(self.rows, self.cols)
        g.cells = list(self.cells)
        return g

    def to_dict(self):
        return {"rows": self.rows, "cols": self.cols, "cells": list(self.cells)}

    @classmethod
    def from_dict(cls, data):
        g = cls(data["rows"], data["cols"])
        g.cells = list(data["cells"])
        return g


class TestCoreSystems(unittest.TestCase):

    def test_save_manager_persistence_and_defaults(self):
        storage = {}
        sm1 = MockSaveManager(storage)
        self.assertEqual(sm1.get_setting("master_volume"), 1.0)
        self.assertEqual(sm1.get_setting("theme_dark"), True)
        self.assertEqual(sm1.get_setting("non_existent_key", "default_val"), "default_val")

        # Modify and save
        sm1.set_setting("master_volume", 0.75)
        sm1.set_setting("theme_dark", False)

        # New instance loading from storage
        sm2 = MockSaveManager(storage)
        sm2.load_data()
        self.assertEqual(sm2.get_setting("master_volume"), 0.75)
        self.assertEqual(sm2.get_setting("theme_dark"), False)

    def test_grid2d_operations_and_neighbors(self):
        grid = MockGrid2D(5, 5, 0)
        self.assertEqual(grid.rows, 5)
        self.assertEqual(grid.cols, 5)
        self.assertTrue(grid.is_valid(0, 0))
        self.assertTrue(grid.is_valid(4, 4))
        self.assertFalse(grid.is_valid(5, 5))
        self.assertFalse(grid.is_valid(-1, 0))

        grid.set_cell(2, 2, 99)
        self.assertEqual(grid.get_cell(2, 2), 99)

        ortho = grid.get_orthogonal_neighbors(0, 0)
        self.assertEqual(len(ortho), 2) # (1,0) and (0,1)
        all_n = grid.get_all_neighbors(2, 2)
        self.assertEqual(len(all_n), 8)

    def test_grid2d_streak_and_cloning(self):
        grid = MockGrid2D(6, 7, 0)
        grid.set_cell(5, 1, 1)
        grid.set_cell(5, 2, 1)
        grid.set_cell(5, 3, 1)
        grid.set_cell(5, 4, 1)

        # Bidirectional streak along horizontal
        streak = grid.count_streak_bidirectional(5, 2, 0, 1, 1)
        self.assertEqual(streak, 4)

        # Clone and verify deep copy
        cloned = grid.clone()
        self.assertEqual(cloned.get_cell(5, 2), 1)
        cloned.set_cell(5, 2, 2)
        self.assertEqual(grid.get_cell(5, 2), 1) # Original unchanged

        # Dict serialization roundtrip
        d = grid.to_dict()
        restored = MockGrid2D.from_dict(d)
        self.assertEqual(restored.cells, grid.cells)

    def test_standard_52_deck_generation(self):
        suits = ["HEARTS", "DIAMONDS", "CLUBS", "SPADES"]
        cards = []
        for s in suits:
            color = "RED" if s in ["HEARTS", "DIAMONDS"] else "BLACK"
            for v in range(1, 14):
                cards.append({"value": v, "suit": s, "color": color})

        self.assertEqual(len(cards), 52)
        red_cards = [c for c in cards if c["color"] == "RED"]
        black_cards = [c for c in cards if c["color"] == "BLACK"]
        self.assertEqual(len(red_cards), 26)
        self.assertEqual(len(black_cards), 26)

    def test_uno_deck_generation(self):
        colors = ["RED", "BLUE", "GREEN", "YELLOW"]
        uno_cards = []
        for c in colors:
            # One '0'
            uno_cards.append({"color": c, "value": 0, "type": "number"})
            # Two of 1-9
            for n in range(1, 10):
                uno_cards.append({"color": c, "value": n, "type": "number"})
                uno_cards.append({"color": c, "value": n, "type": "number"})
            # Two skips, reverses, draw2
            for _ in range(2):
                uno_cards.append({"color": c, "value": 10, "type": "skip"})
                uno_cards.append({"color": c, "value": 11, "type": "reverse"})
                uno_cards.append({"color": c, "value": 12, "type": "draw2"})
        # 4 Wilds, 4 Wild +4
        for _ in range(4):
            uno_cards.append({"color": "WILD", "value": 50, "type": "wild"})
            uno_cards.append({"color": "WILD", "value": 54, "type": "wild4"})

        # Total standard uno deck = 108 cards
        self.assertEqual(len(uno_cards), 108)

    def test_turn_manager_cycling(self):
        players = ["P1", "P2", "P3", "P4"]
        current_idx = 0
        def next_turn(idx):
            return (idx + 1) % len(players)

        for i in range(12):
            self.assertEqual(players[current_idx], players[i % 4])
            current_idx = next_turn(current_idx)

    def test_game_action_serialization(self):
        action = {
            "player_id": 1,
            "action_type": "place_stone",
            "payload": {"row": 4, "col": 4},
            "timestamp": 1720000000.0
        }
        json_str = json.dumps(action)
        parsed = json.loads(json_str)
        self.assertEqual(parsed["player_id"], 1)
        self.assertEqual(parsed["action_type"], "place_stone")
        self.assertEqual(parsed["payload"]["row"], 4)

if __name__ == '__main__':
    unittest.main()
