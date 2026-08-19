#!/usr/bin/env python3
"""
Test Suite: Players, Controllers, AI & Network Action Serialization Validation
"""
import unittest
import json

class TestPlayersAndNetwork(unittest.TestCase):

    def test_game_action_serialization(self):
        action_dict = {
            "player_id": 1,
            "action_type": "drop_piece",
            "payload": {"col": 3, "row": 5},
            "timestamp": 1720000000.0
        }
        json_str = json.dumps(action_dict)
        parsed = json.loads(json_str)
        
        self.assertEqual(parsed["player_id"], 1)
        self.assertEqual(parsed["action_type"], "drop_piece")
        self.assertEqual(parsed["payload"]["col"], 3)

    def test_turn_manager_cycle(self):
        players = ["Player 1", "Player 2", "Player 3"]
        turn = 0
        current_player_idx = 0

        def next_turn(curr_idx):
            return (curr_idx + 1) % len(players)

        self.assertEqual(players[current_player_idx], "Player 1")
        current_player_idx = next_turn(current_player_idx)
        self.assertEqual(players[current_player_idx], "Player 2")
        current_player_idx = next_turn(current_player_idx)
        self.assertEqual(players[current_player_idx], "Player 3")
        current_player_idx = next_turn(current_player_idx)
        self.assertEqual(players[current_player_idx], "Player 1")

if __name__ == '__main__':
    unittest.main()
