#!/usr/bin/env bash
# Fonte unica da versão iOS para o preset, o Xcode e o App Store Connect.
set -euo pipefail

VERSION_PRESET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/export_presets.cfg"
VERSION_NAME="${EXPORT_VERSION_NAME:-$(sed -n 's/^application\/short_version="\(.*\)"/\1/p' "$VERSION_PRESET" | tail -n 1)}"
BUILD_NUMBER="${EXPORT_BUILD_NUMBER:-$(sed -n 's/^application\/version="\(.*\)"/\1/p' "$VERSION_PRESET" | tail -n 1)}"

[[ "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+([.][0-9]+)?$ && "$BUILD_NUMBER" =~ ^[1-9][0-9]*$ ]] || {
  echo "Versão iOS inválida: $VERSION_NAME / $BUILD_NUMBER" >&2
  exit 1
}

printf 'VERSION_NAME=%s\n' "$VERSION_NAME"
printf 'BUILD_NUMBER=%s\n' "$BUILD_NUMBER"
