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
# Resolvido e conferido por scripts/godot_bin.sh: a versao tem de bater com
# .godot-version E com a engine do modelo de build do Android. Exportar o
# pacote de dados com outra versao gera um APK que instala e morre de SIGSEGV
# no primeiro quadro, sem erro nenhum durante a compilacao.
GODOT_BIN="$("$PROJECT_DIR/scripts/godot_bin.sh")"

source "$PROJECT_DIR/scripts/android_version.sh"

echo "=> PlayTable :: Exportando assets do Godot ($VERSION_NAME - code $VERSION_CODE)..."
TEMP_ZIP="/tmp/playtable_assets_$$.zip"
rm -f "$TEMP_ZIP"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-pack "Android" "$TEMP_ZIP"

echo "=> Extraindo assets para src/main/assets..."
rm -rf "$PROJECT_DIR/android/build/src/main/assets"
mkdir -p "$PROJECT_DIR/android/build/src/main/assets"
# `-o` e obrigatorio, nao preferencia: sem ele, um arquivo que ja exista na
# pasta -- outra sessao escrevendo ali ao mesmo tempo, um build anterior
# interrompido -- faz o unzip PERGUNTAR se sobrescreve. Sem terminal a
# pergunta le EOF, ele responde "nenhum", e o APK sai com o pacote pela
# metade sem nenhum erro visivel.
unzip -qo "$TEMP_ZIP" -d "$PROJECT_DIR/android/build/src/main/assets"
rm -f "$TEMP_ZIP"

echo "=> Compilando APK via Gradle..."
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
./gradlew assembleStandardRelease \
    -Pexport_enabled_abis="$ABIS" \
    -Pplugins_remote_binaries="$PGS_DEPS" \
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

# Mesma conferencia do build_aab.sh. No Android a engine procura
# `project.binary` na raiz de assets pelo AssetManager: um pacote sem esse
# arquivo instala, abre e aborta em "Unable to set up the Godot Engine!".
# A listagem sai inteira para uma variavel antes do filtro porque `| grep -q`
# mata o unzip com SIGPIPE e o `pipefail` leria isso como "faltando".
echo "=> Conferindo que o pacote de dados esta dentro do APK..."
ENTRADAS_APK="$(unzip -Z1 "$OUT_APK")"
if ! printf '%s\n' "$ENTRADAS_APK" | grep -qx "assets/project.binary"; then
    echo "ERRO: o APK nao tem assets/project.binary." >&2
    exit 1
fi
echo "   OK: $(printf '%s\n' "$ENTRADAS_APK" | grep -c '^assets/') arquivos em assets/"

echo "=> Build concluida com sucesso! APK assinado: $OUT_APK"
ls -lh "$OUT_APK"
