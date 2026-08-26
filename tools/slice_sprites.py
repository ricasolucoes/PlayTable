import cv2
import numpy as np
import os
import sys

def slice_spritesheet(image_path, output_dir):
    # Load image
    img = cv2.imread(image_path)
    if img is None:
        print(f"Error loading {image_path}")
        return

    # Convert to grayscale and threshold to find objects (assuming white background)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    _, thresh = cv2.threshold(gray, 240, 255, cv2.THRESH_BINARY_INV)

    # Find contours
    contours, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    basename = os.path.splitext(os.path.basename(image_path))[0]
    os.makedirs(output_dir, exist_ok=True)

    count = 0
    for cnt in contours:
        x, y, w, h = cv2.boundingRect(cnt)
        
        # Filter out very small noise
        if w < 15 or h < 15:
            continue
            
        # Add a little padding
        pad = 2
        x1 = max(0, x - pad)
        y1 = max(0, y - pad)
        x2 = min(img.shape[1], x + w + pad)
        y2 = min(img.shape[0], y + h + pad)

        # Crop the sprite
        sprite = img[y1:y2, x1:x2]
        
        # Create an alpha channel based on the white background to make it transparent
        tmp = cv2.cvtColor(sprite, cv2.COLOR_BGR2GRAY)
        _, alpha = cv2.threshold(tmp, 240, 255, cv2.THRESH_BINARY_INV)
        
        b, g, r = cv2.split(sprite)
        rgba = [b, g, r, alpha]
        dst = cv2.merge(rgba, 4)

        out_path = os.path.join(output_dir, f"{basename}_{count:03d}.png")
        cv2.imwrite(out_path, dst)
        count += 1

    print(f"Sliced {count} sprites from {basename}")

if __name__ == '__main__':
    if len(sys.argv) < 3:
        print("Usage: python slice_sprites.py <input_dir> <output_dir>")
        sys.exit(1)
        
    input_dir = sys.argv[1]
    output_dir = sys.argv[2]
    
    for filename in os.listdir(input_dir):
        if filename.endswith(".jpg") or filename.endswith(".png"):
            slice_spritesheet(os.path.join(input_dir, filename), output_dir)
