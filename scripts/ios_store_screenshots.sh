#!/usr/bin/env bash
# Prepara screenshots do app no tamanho iPhone 6,5" aceito pelo App Store Connect.
# As imagens de origem sao capturas reais do PlayTable; a conversao apenas preserva
# cada captura em uma tela 1242x2688, sem criar UI ficticia.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SOURCE_DIR="$PROJECT_ROOT/screenshots"
OUTPUT_ROOT="$PROJECT_ROOT/fastlane/screenshots"
LOCALES=(pt-BR en-US es-ES)

command -v magick >/dev/null 2>&1 || {
  printf '%s\n' "ERRO: ImageMagick (magick) e necessario para preparar screenshots iOS." >&2
  exit 1
}

for locale in "${LOCALES[@]}"; do
  output_dir="$OUTPUT_ROOT/$locale"
  mkdir -p "$output_dir"
  for index in 01 02 03; do
    source="$SOURCE_DIR/$index.jpg"
    output="$output_dir/iPhone 6.5-$((10#$index)).png"
    test -f "$source"
    magick "$source" \
      -background '#0f172a' \
      -gravity center \
      -resize '1242x2688' \
      -extent 1242x2688 \
      -strip \
      "$output"
  done
done

for locale in "${LOCALES[@]}"; do
  for output in "$OUTPUT_ROOT/$locale"/*.png; do
    identify -format "$locale/%f %wx%h\\n" "$output"
  done
done
