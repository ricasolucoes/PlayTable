import cv2
import numpy as np
import os
import glob

def make_transparent_and_crop(img, bbox):
    x, y, w, h = bbox
    pad = 4
    x1 = max(0, x - pad)
    y1 = max(0, y - pad)
    x2 = min(img.shape[1], x + w + pad)
    y2 = min(img.shape[0], y + h + pad)
    
    crop = img[y1:y2, x1:x2]
    
    # Generate alpha channel by thresholding near-white
    gray = cv2.cvtColor(crop, cv2.COLOR_BGR2GRAY)
    _, mask = cv2.threshold(gray, 245, 255, cv2.THRESH_BINARY_INV)
    
    # Smooth edges slightly
    kernel = np.ones((2,2), np.uint8)
    mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)
    
    b, g, r = cv2.split(crop)
    rgba = [b, g, r, mask]
    dst = cv2.merge(rgba, 4)
    return dst

def get_sorted_bboxes(image_path, min_size=20):
    img = cv2.imread(image_path)
    if img is None:
        return img, []
        
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 242, 255, cv2.THRESH_BINARY_INV)
    
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
    
    bboxes = []
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        if w >= min_size and h >= min_size:
            bboxes.append((x, y, w, h))
            
    if not bboxes:
        return img, []
        
    avg_h = np.median([b[3] for b in bboxes])
    row_tol = avg_h * 0.5
    
    # Sort primarily by y
    bboxes.sort(key=lambda b: b[1])
    
    rows = []
    current_row = []
    current_y = None
    
    for b in bboxes:
        if current_y is None:
            current_y = b[1]
            current_row.append(b)
        elif abs(b[1] - current_y) < row_tol:
            current_row.append(b)
        else:
            current_row.sort(key=lambda b: b[0])
            rows.append(current_row)
            current_row = [b]
            current_y = b[1]
            
    if current_row:
        current_row.sort(key=lambda b: b[0])
        rows.append(current_row)
        
    sorted_boxes = [box for row in rows for box in row]
    return img, sorted_boxes

def process_all():
    base_assets = "shared/assets"
    
    # 1. UI Buttons
    ui_files = glob.glob(os.path.join(base_assets, "assets_ui_buttons_*.jpg"))
    if ui_files:
        img, boxes = get_sorted_bboxes(ui_files[0], min_size=40)
        out_dir = os.path.join(base_assets, "ui")
        os.makedirs(out_dir, exist_ok=True)
        names = [
            "btn_play_01.png", "btn_play_02.png", "btn_play_03.png", "btn_play_04.png",
            "btn_pause_01.png", "btn_pause_02.png", "btn_pause_03.png", "btn_pause_04.png",
            "btn_settings_01.png", "btn_settings_02.png", "btn_settings_03.png", "btn_settings_04.png",
            "btn_home_01.png", "btn_home_02.png", "btn_home_03.png", "btn_home_04.png",
            "btn_replay_01.png", "btn_replay_02.png", "btn_replay_03.png", "btn_replay_04.png"
        ]
        for i, box in enumerate(boxes):
            if i < len(names):
                name = names[i]
            else:
                name = f"btn_extra_{i:02d}.png"
            dst = make_transparent_and_crop(img, box)
            cv2.imwrite(os.path.join(out_dir, name), dst)
        print(f"Exported {min(len(boxes), len(names))} UI buttons to {out_dir}")

    # 2. Board Pieces
    piece_files = glob.glob(os.path.join(base_assets, "assets_board_pieces_*.jpg"))
    if piece_files:
        img, boxes = get_sorted_bboxes(piece_files[0], min_size=25)
        out_dir = os.path.join(base_assets, "pieces")
        os.makedirs(out_dir, exist_ok=True)
        for i, box in enumerate(boxes):
            dst = make_transparent_and_crop(img, box)
            name = f"board_piece_{i:02d}.png"
            cv2.imwrite(os.path.join(out_dir, name), dst)
        if len(boxes) >= 20:
            cv2.imwrite(os.path.join(out_dir, "checker_red.png"), make_transparent_and_crop(img, boxes[0]))
            cv2.imwrite(os.path.join(out_dir, "checker_black.png"), make_transparent_and_crop(img, boxes[8] if len(boxes)>8 else boxes[1]))
            cv2.imwrite(os.path.join(out_dir, "reversi_black.png"), make_transparent_and_crop(img, boxes[24] if len(boxes)>24 else boxes[2]))
            cv2.imwrite(os.path.join(out_dir, "reversi_white.png"), make_transparent_and_crop(img, boxes[32] if len(boxes)>32 else boxes[3]))
            cv2.imwrite(os.path.join(out_dir, "mancala_stone_blue.png"), make_transparent_and_crop(img, boxes[-10] if len(boxes)>=10 else boxes[0]))
            cv2.imwrite(os.path.join(out_dir, "mancala_stone_green.png"), make_transparent_and_crop(img, boxes[-9] if len(boxes)>=9 else boxes[1]))
            cv2.imwrite(os.path.join(out_dir, "mancala_stone_red.png"), make_transparent_and_crop(img, boxes[-8] if len(boxes)>=8 else boxes[2]))
            cv2.imwrite(os.path.join(out_dir, "mancala_stone_purple.png"), make_transparent_and_crop(img, boxes[-7] if len(boxes)>=7 else boxes[3]))
            cv2.imwrite(os.path.join(out_dir, "mancala_stone_yellow.png"), make_transparent_and_crop(img, boxes[-6] if len(boxes)>=6 else boxes[4]))
        print(f"Exported board pieces to {out_dir}")

    # 3. Dice & Tokens
    dice_files = glob.glob(os.path.join(base_assets, "assets_dice_tokens_*.jpg"))
    if dice_files:
        img, boxes = get_sorted_bboxes(dice_files[0], min_size=25)
        out_dir = os.path.join(base_assets, "tokens")
        os.makedirs(out_dir, exist_ok=True)
        for i, box in enumerate(boxes):
            dst = make_transparent_and_crop(img, box)
            name = f"token_{i:02d}.png"
            cv2.imwrite(os.path.join(out_dir, name), dst)
        if len(boxes) >= 7:
            cv2.imwrite(os.path.join(out_dir, "dice_red.png"), make_transparent_and_crop(img, boxes[0]))
            cv2.imwrite(os.path.join(out_dir, "dice_blue.png"), make_transparent_and_crop(img, boxes[1]))
            cv2.imwrite(os.path.join(out_dir, "dice_green.png"), make_transparent_and_crop(img, boxes[2]))
            cv2.imwrite(os.path.join(out_dir, "pawn_red.png"), make_transparent_and_crop(img, boxes[3] if len(boxes)>3 else boxes[0]))
            cv2.imwrite(os.path.join(out_dir, "pawn_blue.png"), make_transparent_and_crop(img, boxes[4] if len(boxes)>4 else boxes[1]))
            cv2.imwrite(os.path.join(out_dir, "pawn_green.png"), make_transparent_and_crop(img, boxes[5] if len(boxes)>5 else boxes[2]))
            cv2.imwrite(os.path.join(out_dir, "pawn_yellow.png"), make_transparent_and_crop(img, boxes[6] if len(boxes)>6 else boxes[3]))
        print(f"Exported dice & tokens to {out_dir}")

    # 4. Rewards, Coins & Gems
    coin_files = glob.glob(os.path.join(base_assets, "assets_coins_gems_*.jpg"))
    if coin_files:
        img, boxes = get_sorted_bboxes(coin_files[0], min_size=20)
        out_dir = os.path.join(base_assets, "rewards")
        os.makedirs(out_dir, exist_ok=True)
        for i, box in enumerate(boxes):
            dst = make_transparent_and_crop(img, box)
            name = f"reward_{i:02d}.png"
            cv2.imwrite(os.path.join(out_dir, name), dst)
        if len(boxes) >= 12:
            cv2.imwrite(os.path.join(out_dir, "coin_gold.png"), make_transparent_and_crop(img, boxes[0]))
            cv2.imwrite(os.path.join(out_dir, "coin_stack.png"), make_transparent_and_crop(img, boxes[1]))
            cv2.imwrite(os.path.join(out_dir, "gem_ruby.png"), make_transparent_and_crop(img, boxes[8] if len(boxes)>8 else boxes[2]))
            cv2.imwrite(os.path.join(out_dir, "gem_sapphire.png"), make_transparent_and_crop(img, boxes[9] if len(boxes)>9 else boxes[3]))
            cv2.imwrite(os.path.join(out_dir, "gem_emerald.png"), make_transparent_and_crop(img, boxes[10] if len(boxes)>10 else boxes[4]))
            cv2.imwrite(os.path.join(out_dir, "gem_amethyst.png"), make_transparent_and_crop(img, boxes[11] if len(boxes)>11 else boxes[5]))
        print(f"Exported rewards, coins & gems to {out_dir}")

    # 5. Playing Cards
    card_files = glob.glob(os.path.join(base_assets, "assets_playing_cards_*.jpg"))
    if card_files:
        img, boxes = get_sorted_bboxes(card_files[0], min_size=30)
        out_dir = os.path.join(base_assets, "cards")
        os.makedirs(out_dir, exist_ok=True)
        for i, box in enumerate(boxes):
            dst = make_transparent_and_crop(img, box)
            name = f"card_{i:02d}.png"
            cv2.imwrite(os.path.join(out_dir, name), dst)
        if len(boxes) >= 5:
            cv2.imwrite(os.path.join(out_dir, "card_back_red.png"), make_transparent_and_crop(img, boxes[0]))
            cv2.imwrite(os.path.join(out_dir, "card_back_blue.png"), make_transparent_and_crop(img, boxes[1]))
            cv2.imwrite(os.path.join(out_dir, "card_back_green.png"), make_transparent_and_crop(img, boxes[2]))
            cv2.imwrite(os.path.join(out_dir, "card_back_purple.png"), make_transparent_and_crop(img, boxes[3]))
            cv2.imwrite(os.path.join(out_dir, "card_back_black.png"), make_transparent_and_crop(img, boxes[4]))
        print(f"Exported playing cards to {out_dir}")

if __name__ == '__main__':
    process_all()
