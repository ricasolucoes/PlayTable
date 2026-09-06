#!/bin/bash
# Generate and sign release AAB for PlayTable (Google Play Store).
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUT_DIR="$PROJECT_DIR/build/android"
OUT_AAB="$OUT_DIR/PlayTable.aab"

export JAVA_HOME="${JAVA_HOME:-/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home}"
export PATH="$JAVA_HOME/bin:$PATH"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"

KEYSTORE_PATH="${KEYSTORE_PATH:-/Users/sierra/Dev/keystores/playtable-upload.jks}"
KEYSTORE_ALIAS="${KEYSTORE_ALIAS:-playtable}"
KEYSTORE_PW_FILE="${KEYSTORE_PW_FILE:-/Users/sierra/Dev/keystores/playtable-upload.password.txt}"

if [ -z "${KEYSTORE_PASSWORD:-}" ] && [ -f "$KEYSTORE_PW_FILE" ]; then
    KEYSTORE_PASSWORD="$(cat "$KEYSTORE_PW_FILE" | tr -d '\n\r')"
fi

source "$PROJECT_DIR/scripts/android_version.sh"

# Mesma resolucao do build_apk.sh: versao conferida contra .godot-version e
# contra a engine do modelo Android, senao o AAB publicado crasha no boot.
GODOT_BIN="$("$PROJECT_DIR/scripts/godot_bin.sh")"

echo "=> PlayTable :: Exportando PCK do Godot ($VERSION_NAME - code $VERSION_CODE)..."
# Gradle carrega src/main/assets; limpar a exportacao anterior evita empacotar
# arquivos soltos antigos junto com o PCK novo.
rm -rf "$PROJECT_DIR/android/build/src/main/assets"
mkdir -p "$PROJECT_DIR/android/build/src/main/assets"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-pack "Android" "$PROJECT_DIR/android/build/src/main/assets/main.pck"

echo "=> Compilando AAB via Gradle..."
mkdir -p "$PROJECT_DIR/android/build/assetPackInstallTime/src/main/assets"
# --- Integracao Play Games -------------------------------------------------
# android/build/ e gerado e esta no .gitignore: reinstalar o modelo de
# compilacao apaga o plugin, o manifesto e o games_ids.xml. O instalador
# reaplica tudo a partir de android/pgs/, que e versionado. E idempotente.
"$PROJECT_DIR/android/pgs/install.sh"
# Icones de launcher: o exportador do Godot nao roda aqui, e e ele quem os
# escreveria em res/mipmap-*. Sem esta copia o pacote sai com o robo do Godot.
"$PROJECT_DIR/android/icons/install.sh" "$PROJECT_DIR/android/build"
PGS_DEPS="$(tr '\n' '|' < "$PROJECT_DIR/android/pgs/gradle_deps.txt" | sed 's/|$//')"

# As ABIs precisam vir na linha do gradle: estes builds nao passam pelo
# exportador do Godot, entao `architectures/*` do export_presets.cfg nao chega
# aqui e o gradle assume as quatro. O APK saia com x86 e x86_64 -- 153 MB de
# biblioteca nativa que nenhum telefone usa.
ABIS="armeabi-v7a|arm64-v8a"

cd "$PROJECT_DIR/android/build"
./gradlew bundleStandardRelease \
    -Pexport_enabled_abis="$ABIS" \
    -Pplugins_remote_binaries="$PGS_DEPS" \
    -Pexport_package_name="org.playtable.app" \
    -Pexport_version_code="$VERSION_CODE" \
    -Pexport_version_name="$VERSION_NAME" \
    -Pexport_version_target_sdk=36 \
    -Pexport_version_min_sdk=24

mkdir -p "$OUT_DIR"
AAB_SOURCE="$PROJECT_DIR/android/build/build/outputs/bundle/standardRelease/build-standard-release.aab"
if [ -z "$AAB_SOURCE" ] || [ ! -f "$AAB_SOURCE" ]; then
    echo "ERROR: Arquivo .aab não encontrado em android/build/build/outputs/bundle/"
    exit 1
fi
echo "   AAB gerado em: $AAB_SOURCE"
cp "$AAB_SOURCE" "$OUT_AAB"

echo "=> Assinando AAB com jarsigner..."
export KEYSTORE_PASSWORD
jarsigner -sigalg SHA256withRSA -digestalg SHA-256 \
    -keystore "$KEYSTORE_PATH" \
    -storepass:env KEYSTORE_PASSWORD \
    -keypass:env KEYSTORE_PASSWORD \
    "$OUT_AAB" "$KEYSTORE_ALIAS"

echo "=> Verificando assinatura do AAB..."
jarsigner -verify "$OUT_AAB"

echo "=> Build concluída com sucesso! AAB assinado gerado em: $OUT_AAB"
ls -lh "$OUT_AAB"
