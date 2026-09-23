#!/usr/bin/env bash
# Exporta o projeto Xcode iOS do PlayTable usando a versão exata do Godot.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_PATH="${IOS_EXPORT_PATH:-$PROJECT_DIR/build/ios/PlayTable.xcodeproj}"

GODOT_BIN="$($PROJECT_DIR/scripts/godot_bin.sh)"
mkdir -p "$(dirname "$OUTPUT_PATH")"
rm -rf "$OUTPUT_PATH"

echo "=> PlayTable :: exportando projeto Xcode iOS"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "iOS" "$OUTPUT_PATH"

[[ -f "$OUTPUT_PATH/project.pbxproj" ]] || {
  echo "ERRO: o exportador não criou $OUTPUT_PATH/project.pbxproj" >&2
  exit 1
}

APP_ICON_PATH="$(dirname "$OUTPUT_PATH")/PlayTable/Images.xcassets/AppIcon.appiconset/Icon-1024.png"
if [[ -f "$PROJECT_DIR/fastlane/metadata/app_icon_1024.png" ]]; then
  mkdir -p "$(dirname "$APP_ICON_PATH")"
  cp "$PROJECT_DIR/fastlane/metadata/app_icon_1024.png" "$APP_ICON_PATH"
fi
[[ -f "$APP_ICON_PATH" ]] || {
  echo "ERRO: o exportador não incluiu o ícone iOS em $APP_ICON_PATH" >&2
  exit 1
}

# Sincroniza todas as variantes de ícone do AppIcon.appiconset a partir do Icon-1024.png
python3 -c "
import json, os
from PIL import Image

icon_dir = os.path.dirname('$APP_ICON_PATH')
contents_file = os.path.join(icon_dir, 'Contents.json')
if os.path.isfile(contents_file):
    with open(contents_file) as f:
        data = json.load(f)
    master = Image.open('$APP_ICON_PATH')
    for item in data.get('images', []):
        fn = item.get('filename')
        if not fn or fn == 'Icon-1024.png':
            continue
        sz = item['size']
        scale = float(item.get('scale', '1x').replace('x', ''))
        w, h = map(float, sz.split('x'))
        tw, th = int(round(w * scale)), int(round(h * scale))
        target_path = os.path.join(icon_dir, fn)
        resized = master.resize((tw, th), Image.Resampling.LANCZOS)
        resized.save(target_path)
" 2>/dev/null || true

if command -v sips >/dev/null 2>&1; then
  icon_dimensions="$(sips -g pixelWidth -g pixelHeight "$APP_ICON_PATH" | awk '/pixelWidth|pixelHeight/ { print $2 }' | paste -sd'x' -)"
  [[ "$icon_dimensions" == "1024x1024" ]] || {
    echo "ERRO: o ícone iOS deve ter 1024x1024 px, mas tem $icon_dimensions" >&2
    exit 1
  }
fi

INFO_PLIST_PATH="$(dirname "$OUTPUT_PATH")/PlayTable/PlayTable-Info.plist"
[[ -f "$INFO_PLIST_PATH" ]] || {
  echo "ERRO: o exportador não criou $INFO_PLIST_PATH" >&2
  exit 1
}

# Godot's generic iOS template can emit empty permission keys for optional
# camera, microphone, and photo modules. PlayTable does not use those APIs;
# leaving empty declarations in the submitted plist is misleading and can
# trigger unnecessary permission review. Remove only the unused keys.
for unused_key in NSCameraUsageDescription NSMicrophoneUsageDescription NSPhotoLibraryUsageDescription; do
  /usr/libexec/PlistBuddy -c "Delete :$unused_key" "$INFO_PLIST_PATH" 2>/dev/null || true
done

# The generated localized strings file can repeat those empty declarations;
# remove the exact empty entries there as well so the submitted bundle only
# advertises permissions that the app actually uses.
for localized_plist in "$(dirname "$OUTPUT_PATH")"/PlayTable/*.lproj/InfoPlist.strings; do
  [[ -f "$localized_plist" ]] || continue
  sed -i '' \
    -e '/^NSCameraUsageDescription = "";$/d' \
    -e '/^NSMicrophoneUsageDescription = "";$/d' \
    -e '/^NSPhotoLibraryUsageDescription = "";$/d' \
    "$localized_plist"
done

LOCAL_NETWORK_DESCRIPTION="$(/usr/libexec/PlistBuddy -c 'Print :NSLocalNetworkUsageDescription' "$INFO_PLIST_PATH" 2>/dev/null || true)"
[[ -n "$LOCAL_NETWORK_DESCRIPTION" ]] || {
  echo "ERRO: o Info.plist iOS precisa declarar NSLocalNetworkUsageDescription" >&2
  exit 1
}

echo "Projeto Xcode iOS exportado em: $OUTPUT_PATH"
echo "Ícone iOS conferido: $APP_ICON_PATH"
echo "Rede local iOS declarada: $LOCAL_NETWORK_DESCRIPTION"
