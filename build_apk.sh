#!/bin/bash
# Generate Signed APK Script
#
# Required Environment Variables:
#   JAVA_HOME         - Path to JDK 17+ installation
#   KEYSTORE_PASSWORD - Keystore and key password for release signing
#
# Optional:
#   GODOT_BIN         - Path to Godot binary (default: searches PATH, then local Godot.app)

set -euo pipefail

echo "=> Iniciando configuração do Android SDK e Build do Godot..."

# --- Resolve JAVA_HOME ---
if [ -z "${JAVA_HOME:-}" ]; then
    # Try local JDK first, then system
    if [ -d "$(dirname "$0")/jdk-17.0.2.jdk/Contents/Home" ]; then
        export JAVA_HOME="$(dirname "$0")/jdk-17.0.2.jdk/Contents/Home"
    elif command -v java &>/dev/null; then
        export JAVA_HOME="$(/usr/libexec/java_home 2>/dev/null || true)"
    fi
fi

if [ -z "${JAVA_HOME:-}" ]; then
    echo "ERROR: JAVA_HOME is not set and no JDK found. Install JDK 17+ or set JAVA_HOME."
    exit 1
fi
export PATH="$JAVA_HOME/bin:$PATH"
echo "   JAVA_HOME=$JAVA_HOME"

# --- Resolve keystore password ---
if [ -z "${KEYSTORE_PASSWORD:-}" ]; then
    echo "ERROR: KEYSTORE_PASSWORD environment variable is not set."
    echo "Usage: KEYSTORE_PASSWORD=your_password ./build_apk.sh"
    exit 1
fi

# --- Resolve Godot binary ---
GODOT_BIN="${GODOT_BIN:-}"
if [ -z "$GODOT_BIN" ]; then
    if command -v godot &>/dev/null; then
        GODOT_BIN="godot"
    elif [ -x "$(dirname "$0")/Godot.app/Contents/MacOS/Godot" ]; then
        GODOT_BIN="$(dirname "$0")/Godot.app/Contents/MacOS/Godot"
    else
        echo "ERROR: Godot binary not found. Set GODOT_BIN or install Godot in PATH."
        exit 1
    fi
fi

mkdir -p build/android

# --- Generate keystore if missing ---
if [ ! -f "release.keystore" ]; then
    echo "=> Gerando release.keystore..."
    keytool -genkey -v \
        -keystore release.keystore \
        -alias alias_name \
        -keyalg RSA \
        -keysize 2048 \
        -validity 10000 \
        -storepass "$KEYSTORE_PASSWORD" \
        -keypass "$KEYSTORE_PASSWORD" \
        -dname "CN=PlayTable, OU=Games, O=Dev, L=BR, S=BR, C=BR"
fi

# --- Export APK ---
echo "=> Exportando APK pelo Godot (Headless)..."
"$GODOT_BIN" -ApplePersistenceIgnoreState YES --headless --export-release "Android" build/android/JogosDeMesaOffline.apk

echo "=> Build Concluída! APK Assinado salvo em build/android/JogosDeMesaOffline.apk"
