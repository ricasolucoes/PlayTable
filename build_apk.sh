#!/bin/bash
# Generate a release APK for PlayTable.
#
# The Godot export preset (export_presets.cfg) is intentionally UNSIGNED
# (package/signed=false) and carries no keystore path or password, so the
# repository stays reproducible and free of secrets (F-Droid requirement).
# Signing happens here, as a separate step, using a keystore kept OUTSIDE
# this repository.
#
# Required environment variables (only for the signing step):
#   KEYSTORE_PASSWORD - keystore and key password
#
# Optional:
#   JAVA_HOME     - path to a JDK 17+ installation
#   GODOT_BIN     - path to the Godot binary (default: PATH, then ./Godot.app)
#   KEYSTORE_PATH - path to the release keystore
#                   (default: $HOME/keys/playtable-release.keystore)
#   KEYSTORE_ALIAS- key alias inside the keystore (default: playtable)
#   SKIP_SIGN=1   - only produce the unsigned APK (what F-Droid builds)

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$PROJECT_DIR/build/android"
UNSIGNED_APK="$OUT_DIR/PlayTable.apk"
SIGNED_APK="$OUT_DIR/PlayTable-signed.apk"

KEYSTORE_PATH="${KEYSTORE_PATH:-$HOME/keys/playtable-release.keystore}"
KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-playtable}"

echo "=> PlayTable :: build Android"

# --- Resolve JAVA_HOME ---
if [ -z "${JAVA_HOME:-}" ]; then
    if [ -d "$PROJECT_DIR/jdk-17.0.2.jdk/Contents/Home" ]; then
        export JAVA_HOME="$PROJECT_DIR/jdk-17.0.2.jdk/Contents/Home"
    elif command -v /usr/libexec/java_home &>/dev/null; then
        export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
    fi
fi
if [ -n "${JAVA_HOME:-}" ]; then
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "   JAVA_HOME=$JAVA_HOME"
fi

# --- Resolve Godot binary ---
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
    if command -v godot &>/dev/null; then
        GODOT_BIN="godot"
    elif [ -x "$PROJECT_DIR/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="$PROJECT_DIR/Godot.app/Contents/MacOS/Godot"
    else
        echo "ERROR: Godot binary not found. Set GODOT_BIN or install Godot in PATH."
        exit 1
    fi
fi

mkdir -p "$OUT_DIR"

# --- Export (unsigned) ---
echo "=> Exportando APK pelo Godot (headless, sem assinatura)..."
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-release "Android" "$UNSIGNED_APK"
echo "   APK nao assinado: $UNSIGNED_APK"

if [ "${SKIP_SIGN:-0}" = "1" ]; then
    echo "=> SKIP_SIGN=1, encerrando sem assinar."
    exit 0
fi

# --- Sign ---
if [ -z "${KEYSTORE_PASSWORD:-}" ]; then
    echo "ERROR: KEYSTORE_PASSWORD environment variable is not set."
    echo "Usage: KEYSTORE_PASSWORD=... ./build_apk.sh   (or SKIP_SIGN=1 to skip signing)"
    exit 1
fi

if [ ! -f "$KEYSTORE_PATH" ]; then
    echo "ERROR: keystore nao encontrada em '$KEYSTORE_PATH'."
    echo "Gere uma FORA do repositorio, por exemplo:"
    echo "  mkdir -p \"\$HOME/keys\""
    echo "  keytool -genkey -v -keystore \"$KEYSTORE_PATH\" -alias \"$KEYSTORE_ALIAS\" \\"
    echo "      -keyalg RSA -keysize 2048 -validity 10000"
    echo "Depois rode novamente, ou use SKIP_SIGN=1 para gerar apenas o APK nao assinado."
    exit 1
fi

APKSIGNER="${APKSIGNER:-$(command -v apksigner || true)}"
if [ -z "$APKSIGNER" ] && [ -n "${ANDROID_HOME:-}" ]; then
    APKSIGNER="$(ls -1 "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "$APKSIGNER" ]; then
    echo "ERROR: apksigner nao encontrado. Instale o Android SDK build-tools ou defina APKSIGNER."
    exit 1
fi

echo "=> Assinando com $APKSIGNER..."
"$APKSIGNER" sign \
    --ks "$KEYSTORE_PATH" \
    --ks-key-alias "$KEYSTORE_ALIAS" \
    --ks-pass "env:KEYSTORE_PASSWORD" \
    --key-pass "env:KEYSTORE_PASSWORD" \
    --out "$SIGNED_APK" \
    "$UNSIGNED_APK"

"$APKSIGNER" verify --verbose "$SIGNED_APK"

echo "=> Build concluida! APK assinado: $SIGNED_APK"
