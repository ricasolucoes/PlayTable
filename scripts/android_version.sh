#!/usr/bin/env bash
# Fonte unica de versao para APK, AAB e CI.
VERSION_PRESET="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/export_presets.cfg"
VERSION_CODE="${EXPORT_VERSION_CODE:-$(sed -n 's/^version\/code=//p' "$VERSION_PRESET")}"
VERSION_NAME="${EXPORT_VERSION_NAME:-$(sed -n 's/^version\/name="\(.*\)"/\1/p' "$VERSION_PRESET")}"
[[ "$VERSION_CODE" =~ ^[1-9][0-9]*$ && "$VERSION_NAME" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || {
    echo "Versao Android invalida: $VERSION_NAME / $VERSION_CODE" >&2
    exit 1
}
