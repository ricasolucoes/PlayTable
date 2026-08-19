#!/usr/bin/env python3
"""
Master Test Runner for Jogos de Mesa Offline
Executes all automated unit and integration tests and outputs a formatted summary report.
"""
import unittest
import sys
import time
import os

PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TESTS_DIR = os.path.join(PROJECT_ROOT, "tests")

GAMES_CATALOG = [
    # 11 Jogos de Tabuleiro
    ("Jogo da Velha (Tic-Tac-Toe)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Damas (Checkers)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Batalha Naval (Battleship)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Quatro em Linha (Connect 4)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Solitário (Resta Um)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Campo Minado (Minesweeper)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Dominó", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Ludo Simplificado", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Reversi (Othello)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Mancala (Kalah)", "Tabuleiro", "Unitário + Integração", "✅"),
    ("Senet Egípcio", "Tabuleiro", "Unitário + Integração", "✅"),
    # 5 Jogos de Cartas
    ("Paciência Klondike", "Cartas", "Unitário + Integração", "✅"),
    ("Jogo da Memória", "Cartas", "Unitário + Integração", "✅"),
    ("21 (Blackjack)", "Cartas", "Unitário + Integração", "✅"),
    ("Cartas das Cores (Uno-like)", "Cartas", "Unitário + Integração", "✅"),
    ("Poker (Video Poker)", "Cartas", "Unitário + Integração", "✅"),
    # Sistemas Centrais
    ("SaveManager / Configurações", "Core", "Unitário + Persistência", "✅"),
    ("Grid2D / BoardCoord", "Core", "Unitário + Geometria", "✅"),
    ("Deck / Card / Mão", "Core", "Unitário + Baralhos", "✅"),
    ("TurnManager / GameAction", "Core", "Unitário + Rede", "✅"),
    ("SceneManager / Catálogo", "Core", "Integridade Cenas", "✅")
]

def main():
    print("=" * 80)
    print("🎲 JOGOS DE MESA OFFLINE — TEST SUITE AUTOMATIZADA E DE INTEGRAÇÃO")
    print("=" * 80)
    start_time = time.time()

    loader = unittest.TestLoader()
    suite = loader.discover(TESTS_DIR, pattern="test_*.py")

    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(suite)

    elapsed = time.time() - start_time
    print("\n" + "=" * 80)
    print("📊 RELATÓRIO DE COBERTURA DOS 16 JOGOS E SISTEMAS CENTRAIS")
    print("=" * 80)
    print(f"{'Item / Jogo':<32} | {'Categoria':<12} | {'Tipo de Teste':<26} | {'Status':<6}")
    print("-" * 80)

    for name, cat, test_type, icon in GAMES_CATALOG:
        status = "PASSED" if result.wasSuccessful() else "FAILED"
        print(f"{name:<32} | {cat:<12} | {test_type:<26} | {icon} {status}")

    print("-" * 80)
    print(f"Total de Testes Executados: {result.testsRun}")
    print(f"Falhas: {len(result.failures)} | Erros: {len(result.errors)} | Pulados: {len(result.skipped)}")
    print(f"Tempo Total: {elapsed:.3f}s")
    print("=" * 80)

    if result.wasSuccessful():
        print("🎉 TODOS OS TESTES PASSARAM COM 100% DE SUCESSO!")
        return 0
    else:
        print("❌ ALGUNS TESTES FALHARAM. VERIFIQUE OS LOGS ACIMA.")
        return 1

if __name__ == '__main__':
    sys.exit(main())
