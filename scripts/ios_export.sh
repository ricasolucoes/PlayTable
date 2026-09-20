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
[[ -f "$APP_ICON_PATH" ]] || {
  echo "ERRO: o exportador não incluiu o ícone iOS em $APP_ICON_PATH" >&2
  exit 1
}

if command -v sips >/dev/null 2>&1; then
  icon_dimensions="$(sips -g pixelWidth -g pixelHeight "$APP_ICON_PATH" | awk '/pixelWidth|pixelHeight/ { print $2 }' | paste -sd'x' -)"
  [[ "$icon_dimensions" == "1024x1024" ]] || {
    echo "ERRO: o ícone iOS deve ter 1024x1024 px, mas tem $icon_dimensions" >&2
    exit 1
  }
fi

echo "Projeto Xcode iOS exportado em: $OUTPUT_PATH"
echo "Ícone iOS conferido: $APP_ICON_PATH"
