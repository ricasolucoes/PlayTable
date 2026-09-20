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

echo "Projeto Xcode iOS exportado em: $OUTPUT_PATH"
