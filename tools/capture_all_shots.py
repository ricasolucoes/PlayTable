#!/usr/bin/env python3
import os
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GODOT_BIN_SCRIPT = REPO_ROOT / "scripts" / "godot_bin.sh"
SHOT_GD = REPO_ROOT / "tools" / "shot.gd"

SCENES = {
    "menu_principal": "res://core/telas/MainMenu.tscn",
    "menu_tabuleiro": "res://core/telas/MenuTabuleiro.tscn",
    "menu_cartas": "res://core/telas/MenuCartas.tscn",
    "damas": "res://games/damas/CheckersGame.tscn",
    "batalha_naval": "res://games/batalha_naval/BattleshipGame.tscn",
    "campo_minado": "res://games/campo_minado/MinesweeperGame.tscn",
    "paciencia": "res://games/paciencia/KlondikeGame.tscn",
    "paciencia_spider": "res://games/paciencia_spider/SpiderGame.tscn",
    "sudoku": "res://games/sudoku/SudokuGame.tscn",
    "domino": "res://games/domino/DominoGame.tscn",
    "gamao": "res://games/gamao/BackgammonGame.tscn",
    "reversi": "res://games/reversi/ReversiGame.tscn",
    "ludo": "res://games/ludo/LudoGame.tscn",
    "quatro_em_linha": "res://games/quatro_em_linha/ConnectFourGame.tscn",
    "jogo_da_velha": "res://games/jogo_da_velha/TicTacToeGame.tscn",
    "mancala": "res://games/mancala/MancalaGame.tscn",
    "senet": "res://games/senet/SenetGame.tscn",
    "solitario": "res://games/solitario/PegSolitaireGame.tscn",
    "hanoi": "res://games/hanoi/HanoiGame.tscn",
    "nim": "res://games/nim/NimGame.tscn",
    "caminho_numerico": "res://games/caminho_numerico/NumberPathGame.tscn",
    "blackjack": "res://games/blackjack/BlackjackGame.tscn",
    "poker": "res://games/poker/PokerGame.tscn",
    "memoria": "res://games/memoria/MemoryGame.tscn",
    "unolike": "res://games/unolike/UnoLikeGame.tscn",
}

def get_godot_bin():
    result = subprocess.run([str(GODOT_BIN_SCRIPT)], capture_output=True, text=True, check=True)
    return result.stdout.strip()

def main():
    godot_bin = get_godot_bin()
    out_dir = REPO_ROOT / "screenshots" / "games"
    out_dir.mkdir(parents=True, exist_ok=True)
    
    print(f"Usando Godot: {godot_bin}")
    print(f"Diretório de saída: {out_dir}")
    
    success = 0
    for name, scene in SCENES.items():
        out_file = out_dir / f"{name}.png"
        print(f"Capturando [{name}] -> {scene}...")
        cmd = [
            godot_bin,
            "--path", str(REPO_ROOT),
            "--script", str(SHOT_GD),
            "--",
            scene,
            str(out_file),
            "60",
            "720",
            "1280"
        ]
        try:
            out_file.unlink(missing_ok=True)
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=60)
            if res.returncode == 0 and "SHOT_OK" in res.stdout and "SCRIPT ERROR" not in res.stderr and out_file.exists() and out_file.stat().st_size > 5000:
                print(f"  ✓ OK: {out_file.name} ({out_file.stat().st_size // 1024} KB)")
                success += 1
            else:
                print(f"  ✗ Falha ao capturar {name}: {res.stderr}")
        except Exception as e:
            print(f"  ✗ Erro/Timeout em {name}: {e}")
            
    print(f"\nFinalizado: {success}/{len(SCENES)} capturas concluídas com sucesso!")
    return 0 if success == len(SCENES) else 1

if __name__ == "__main__":
    sys.exit(main())
