#!/usr/bin/env python3
"""
Test Suite: Repository Filesystem, Casing, Scenes & Catalog Integrity
Verifies that all 16 games, scenes, GDScripts, autoload singletons and menus exist and match configuration.
"""
import unittest
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

EXPECTED_BOARD_GAMES = [
    ("jogo_da_velha", "TicTacToeGame"),
    ("damas", "CheckersGame"),
    ("batalha_naval", "BattleshipGame"),
    ("quatro_em_linha", "ConnectFourGame"),
    ("solitario", "PegSolitaireGame"),
    ("campo_minado", "MinesweeperGame"),
    ("domino", "DominoGame"),
    ("ludo", "LudoGame"),
    ("reversi", "ReversiGame"),
    ("mancala", "MancalaGame"),
    ("senet", "SenetGame")
]

EXPECTED_CARD_GAMES = [
    ("paciencia", "KlondikeGame"),
    ("memoria", "MemoryGame"),
    ("blackjack", "BlackjackGame"),
    ("unolike", "UnoLikeGame"),
    ("poker", "PokerGame")
]

class TestAllGamesCatalog(unittest.TestCase):

    def test_project_godot_exists_and_valid(self):
        project_godot_path = os.path.join(PROJECT_ROOT, "project.godot")
        self.assertTrue(os.path.exists(project_godot_path), "project.godot not found")
        with open(project_godot_path, "r", encoding="utf-8") as f:
            content = f.read()
        self.assertIn("res://core/telas/MainMenu.tscn", content)
        self.assertIn('config/name="PlayTable"', content)
        self.assertIn("SaveManager", content)
        self.assertIn("LocaleManager", content)
        self.assertIn("SceneManager", content)
        self.assertIn("AudioManager", content)
        self.assertTrue("translations." in content or "translations.csv" in content)

    def test_all_11_board_games_exist_with_scenes_and_scripts(self):
        games_dir = os.path.join(PROJECT_ROOT, "games")
        self.assertTrue(os.path.isdir(games_dir), "games/ directory not found")

        for folder_name, base_name in EXPECTED_BOARD_GAMES:
            game_path = os.path.join(games_dir, folder_name)
            self.assertTrue(os.path.isdir(game_path), f"Game directory not found: {folder_name}")

            gd_path = os.path.join(game_path, f"{base_name}.gd")
            tscn_path = os.path.join(game_path, f"{base_name}.tscn")

            self.assertTrue(os.path.isfile(gd_path), f"Script missing: {gd_path}")
            self.assertTrue(os.path.isfile(tscn_path), f"Scene missing: {tscn_path}")

    def test_all_5_card_games_exist_with_scenes_and_scripts(self):
        games_dir = os.path.join(PROJECT_ROOT, "games")

        for folder_name, base_name in EXPECTED_CARD_GAMES:
            game_path = os.path.join(games_dir, folder_name)
            self.assertTrue(os.path.isdir(game_path), f"Game directory not found: {folder_name}")

            gd_path = os.path.join(game_path, f"{base_name}.gd")
            tscn_path = os.path.join(game_path, f"{base_name}.tscn")

            self.assertTrue(os.path.isfile(gd_path), f"Script missing: {gd_path}")
            self.assertTrue(os.path.isfile(tscn_path), f"Scene missing: {tscn_path}")

    def test_core_singletons_and_menus_exist(self):
        core_dir = os.path.join(PROJECT_ROOT, "core")
        self.assertTrue(os.path.isfile(os.path.join(core_dir, "save", "SaveManager.gd")))
        self.assertTrue(os.path.isfile(os.path.join(core_dir, "i18n", "LocaleManager.gd")))
        self.assertTrue(os.path.isfile(os.path.join(core_dir, "i18n", "translations.csv")))
        self.assertTrue(os.path.isfile(os.path.join(core_dir, "navegacao", "SceneManager.gd")))
        self.assertTrue(os.path.isfile(os.path.join(core_dir, "audio", "AudioManager.gd")))

        # Telas
        telas_dir = os.path.join(core_dir, "telas")
        self.assertTrue(os.path.isfile(os.path.join(telas_dir, "MainMenu.tscn")))
        self.assertTrue(os.path.isfile(os.path.join(telas_dir, "MenuTabuleiro.tscn")))
        self.assertTrue(os.path.isfile(os.path.join(telas_dir, "MenuCartas.tscn")))

    def test_shared_3d_and_core_engine_components_exist(self):
        shared_dir = os.path.join(PROJECT_ROOT, "shared")
        # 3D assets
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "3d", "Board3D.tscn")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "3d", "Dice3D.tscn")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "3d", "Token3D.tscn")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "3d", "TabletopEnvironment3D.tscn")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "3d", "MaterialFactory3D.gd")))

        # Core engine
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "core_engine", "board", "Grid2D.gd")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "core_engine", "cards", "Card.gd")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "core_engine", "cards", "Deck.gd")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "core_engine", "network", "GameAction.gd")))
        self.assertTrue(os.path.isfile(os.path.join(shared_dir, "core_engine", "players", "TurnManager.gd")))

if __name__ == '__main__':
    unittest.main()
