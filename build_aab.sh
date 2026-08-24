#!/bin/bash
# Generate and sign release AAB for PlayTable (Google Play Store).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$PROJECT_DIR/build/android"
OUT_AAB="$OUT_DIR/PlayTable.aab"

export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="/Users/sierra/Library/Android/sdk"

KEYSTORE_PATH="${KEYSTORE_PATH:-/Users/sierra/Dev/keystores/playtable-upload.jks}"
KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-playtable}"
KEYSTORE_PW_FILE="/Users/sierra/Dev/keystores/playtable-upload.password.txt"

if [ -f "$KEYSTORE_PW_FILE" ]; then
    KEYSTORE_PASSWORD="$(cat "$KEYSTORE_PW_FILE" | tr -d '\n\r')"
fi

VERSION_CODE="${EXPORT_VERSION_CODE:-8}"
VERSION_NAME="${EXPORT_VERSION_NAME:-0.4.0}"

echo "=> PlayTable :: Exportando PCK do Godot ($VERSION_NAME - code $VERSION_CODE)..."
mkdir -p "$PROJECT_DIR/android/build/assets"
"$PROJECT_DIR/Godot.app/Contents/MacOS/Godot" --headless --path "$PROJECT_DIR" --export-pack "Android" "$PROJECT_DIR/android/build/assets/main.pck"

echo "=> Compilando AAB via Gradle..."
mkdir -p "$PROJECT_DIR/android/build/assetPackInstallTime/src/main/assets"
cd "$PROJECT_DIR/android/build"
./gradlew bundleStandardRelease \
    -Pexport_package_name="org.playtable.app" \
    -Pexport_version_code="$VERSION_CODE" \
    -Pexport_version_name="$VERSION_NAME" \
    -Pexport_version_target_sdk=35 \
    -Pexport_version_min_sdk=24

mkdir -p "$OUT_DIR"
AAB_SOURCE="$(find "$PROJECT_DIR/android/build/build/outputs/bundle" -name "*.aab" | head -n 1)"
if [ -z "$AAB_SOURCE" ] || [ ! -f "$AAB_SOURCE" ]; then
    echo "ERROR: Arquivo .aab não encontrado em android/build/build/outputs/bundle/"
    exit 1
fi
echo "   AAB gerado em: $AAB_SOURCE"
cp "$AAB_SOURCE" "$OUT_AAB"

echo "=> Assinando AAB com jarsigner..."
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
    -keystore "$KEYSTORE_PATH" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEYSTORE_PASSWORD" \
    "$OUT_AAB" "$KEYSTORE_ALIAS"

echo "=> Verificando assinatura do AAB..."
jarsigner -verify "$OUT_AAB"

echo "=> Build concluída com sucesso! AAB assinado gerado em: $OUT_AAB"
ls -lh "$OUT_AAB"
