#!/bin/bash
# Generate and sign release APK for PlayTable.
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$PROJECT_DIR/build/android"
OUT_APK="$OUT_DIR/PlayTable-signed.apk"

# --- Java & Android SDK Paths ---
export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
if [ ! -d "$JAVA_HOME" ] && [ -d "$PROJECT_DIR/jdk-17.0.2.jdk/Contents/Home" ]; then
    export JAVA_HOME="$PROJECT_DIR/jdk-17.0.2.jdk/Contents/Home"
fi
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

# --- Keystore Configuration ---
KEYSTORE_PATH="${KEYSTORE_PATH:-/Users/sierra/Dev/keystores/playtable-upload.jks}"
KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-playtable}"
KEYSTORE_PW_FILE="${KEYSTORE_PW_FILE:-/Users/sierra/Dev/keystores/playtable-upload.password.txt}"

if [ -z "${KEYSTORE_PASSWORD:-}" ] && [ -f "$KEYSTORE_PW_FILE" ]; then
    KEYSTORE_PASSWORD="$(cat "$KEYSTORE_PW_FILE" | tr -d '\n\r')"
fi

# --- Godot Binary ---
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
    if [ -x "$PROJECT_DIR/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="$PROJECT_DIR/Godot.app/Contents/MacOS/Godot"
    elif command -v godot &>/dev/null; then
        GODOT_BIN="godot"
    else
        echo "ERROR: Godot binary not found."
        exit 1
    fi
fi

VERSION_CODE="${EXPORT_VERSION_CODE:-10}"
VERSION_NAME="${EXPORT_VERSION_NAME:-0.5.0}"

echo "=> PlayTable :: Exportando assets do Godot ($VERSION_NAME - code $VERSION_CODE)..."
TEMP_ZIP="/tmp/playtable_assets_$$.zip"
rm -f "$TEMP_ZIP"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-pack "Android" "$TEMP_ZIP"

echo "=> Extraindo assets para src/main/assets..."
rm -rf "$PROJECT_DIR/android/build/src/main/assets"
mkdir -p "$PROJECT_DIR/android/build/src/main/assets"
unzip -q "$TEMP_ZIP" -d "$PROJECT_DIR/android/build/src/main/assets"
rm -f "$TEMP_ZIP"

echo "=> Compilando APK via Gradle..."
cd "$PROJECT_DIR/android/build"
./gradlew assembleStandardRelease \
    -Pexport_package_name="org.playtable.app" \
    -Pexport_version_code="$VERSION_CODE" \
    -Pexport_version_name="$VERSION_NAME" \
    -Pexport_version_target_sdk=36 \
    -Pexport_version_min_sdk=24

mkdir -p "$OUT_DIR"
IN_APK="$PROJECT_DIR/android/build/build/outputs/apk/standard/release/android_release.apk"

if [ "${SKIP_SIGN:-0}" = "1" ]; then
    cp "$IN_APK" "$OUT_DIR/PlayTable.apk"
    echo "=> SKIP_SIGN=1, APK gerado em: $OUT_DIR/PlayTable.apk"
    exit 0
fi

# --- Signing ---
APKSIGNER="${APKSIGNER:-$(command -v apksigner || true)}"
if [ -z "$APKSIGNER" ] && [ -n "${ANDROID_HOME:-}" ]; then
    APKSIGNER="$(ls -1 "$ANDROID_HOME"/build-tools/*/apksigner 2>/dev/null | sort -V | tail -1 || true)"
fi
if [ -z "$APKSIGNER" ]; then
    echo "ERROR: apksigner nao encontrado."
    exit 1
fi

echo "=> Assinando APK com $APKSIGNER..."
"$APKSIGNER" sign \
    --ks "$KEYSTORE_PATH" \
    --ks-key-alias "$KEYSTORE_ALIAS" \
    --ks-pass "pass:$KEYSTORE_PASSWORD" \
    --key-pass "pass:$KEYSTORE_PASSWORD" \
    --out "$OUT_APK" \
    "$IN_APK"

echo "=> Verificando assinatura do APK..."
"$APKSIGNER" verify --verbose "$OUT_APK"

echo "=> Build concluida com sucesso! APK assinado: $OUT_APK"
ls -lh "$OUT_APK"
