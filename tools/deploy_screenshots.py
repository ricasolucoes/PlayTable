#!/usr/bin/env python3
import os
import shutil
import subprocess
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RICA_GAMES_PUBLIC = Path("/Users/sierra/Dev/Jogos/RicaGames/public/images/games")
SCREENSHOTS_DIR = REPO_ROOT / "screenshots" / "games"
FASTLANE_DIR = REPO_ROOT / "fastlane" / "metadata" / "android"

# 8 Curated Screenshots for Google Play
PLAY_STORE_SELECTION = [
    ("01", "menu_principal.png"),
    ("02", "damas.png"),
    ("03", "batalha_naval.png"),
    ("04", "campo_minado.png"),
    ("05", "paciencia.png"),
    ("06", "gamao.png"),
    ("07", "domino.png"),
    ("08", "sudoku.png"),
]

def main():
    RICA_GAMES_PUBLIC.mkdir(parents=True, exist_ok=True)
    
    # 1. Prepare JPGs for store
    store_tmp = REPO_ROOT / "screenshots" / "store_tmp"
    store_tmp.mkdir(parents=True, exist_ok=True)
    
    jpg_files = []
    for num, src_name in PLAY_STORE_SELECTION:
        src_path = (SCREENSHOTS_DIR / src_name).resolve()
        dest_jpg = (store_tmp / f"{num}.jpg").resolve()
        subprocess.run(["sips", "-s", "format", "jpeg", str(src_path), "--out", str(dest_jpg)], check=True, capture_output=True)
        jpg_files.append((f"{num}.jpg", dest_jpg))
        print(f"Gerado {num}.jpg a partir de {src_name} ({dest_jpg.stat().st_size // 1024} KB)")

    # 2. Deploy to fastlane locales
    locales = [d for d in FASTLANE_DIR.iterdir() if d.is_dir()]
    print(f"\nAtualizando {len(locales)} locales do Fastlane...")
    for loc in locales:
        img_dir = loc / "images"
        for shot_sub in ["phoneScreenshots", "sevenInchScreenshots", "tenInchScreenshots"]:
            target_sub = img_dir / shot_sub
            target_sub.mkdir(parents=True, exist_ok=True)
            for fname, fpath in jpg_files:
                shutil.copy2(str(fpath), str(target_sub / fname))
                
    print("✓ Imagens da loja atualizadas em todos os 27 idiomas!")

    # 3. Deploy all 25 game screenshots to RicaGames public folder
    print(f"\nCopiando 25 screenshots para o portal RicaGames ({RICA_GAMES_PUBLIC})...")
    for f in SCREENSHOTS_DIR.glob("*.png"):
        dest_name = f"playtable_{f.name}"
        shutil.copy2(str(f), str(RICA_GAMES_PUBLIC / dest_name))
        shutil.copy2(str(f), str(RICA_GAMES_PUBLIC / f.name))
        print(f"  ✓ Copiado: {dest_name} e {f.name}")

    # Clean up store_tmp
    shutil.rmtree(store_tmp)

    print("\n✓ Deploy de imagens concluído com sucesso!")

if __name__ == "__main__":
    main()
