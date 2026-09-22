#!/usr/bin/env bash
# Captura fontes reais e localizadas para os screenshots da App Store.
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$($PROJECT_ROOT/scripts/godot_bin.sh)}"
SOURCE_ROOT="$PROJECT_ROOT/screenshots/store"
LOCALES=(pt-BR en-US es-ES)

scene_for_index() {
  case "$1" in
    01) printf '%s\n' 'res://core/telas/MainMenu.tscn' ;;
    02) printf '%s\n' 'res://games/damas/CheckersGame.tscn' ;;
    03) printf '%s\n' 'res://games/batalha_naval/BattleshipGame.tscn' ;;
    *) echo "Índice de screenshot inválido: $1" >&2; return 1 ;;
  esac
}

godot_locale_for_store_locale() {
  case "$1" in
    pt-BR) printf '%s\n' pt_BR ;;
    en-US) printf '%s\n' en ;;
    es-ES) printf '%s\n' es ;;
    *) echo "Locale de loja inválido: $1" >&2; return 1 ;;
  esac
}

for locale in "${LOCALES[@]}"; do
  godot_locale="$(godot_locale_for_store_locale "$locale")"
  mkdir -p "$SOURCE_ROOT/$locale"
  for index in 01 02 03; do
    output="$SOURCE_ROOT/$locale/$index.png"
    scene="$(scene_for_index "$index")"
    echo "Capturando $locale/$index: $scene"
    "$GODOT_BIN" \
      --path "$PROJECT_ROOT" \
      --script "$PROJECT_ROOT/tools/shot_idioma.gd" \
      -- "$godot_locale" "$scene" "$output" 60 720 1280
    test -s "$output"
    dimensions="$(identify -format '%wx%h' "$output")"
    [[ "$dimensions" == "720x1280" ]] || {
      echo "ERRO: $output tem dimensão $dimensions; esperado 720x1280" >&2
      exit 1
    }
  done
done

echo "Fontes localizadas prontas em $SOURCE_ROOT"
