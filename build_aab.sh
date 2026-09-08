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

echo "=> PlayTable :: Exportando assets do Godot ($VERSION_NAME - code $VERSION_CODE)..."
# O pacote vai SOLTO em src/main/assets, arquivo por arquivo -- nao como um
# main.pck. No Android a engine le `res://` pelo AssetManager: `Main::setup`
# procura `project.binary` na raiz de assets e nada mais. Ela nao conhece o
# nome "main.pck"; so carregaria um pacote com `--main-pack` na linha de
# comando, e a linha de comando do aplicativo sai de `assets/_cl_`, que este
# build nao escreve. Um AAB com `assets/main.pck` e mais nada instala, abre e
# morre em "Unable to set up the Godot Engine! Aborting" em qualquer aparelho
# -- foi o que subiu para a loja da v0.8.0 (code 14) a v0.9.0 (code 16).
# Mesmo tratamento do build_apk.sh, de proposito: os dois pacotes tem de
# carregar exatamente o mesmo conteudo.
TEMP_ZIP="/tmp/playtable_aab_assets_$$.zip"
rm -f "$TEMP_ZIP"
"$GODOT_BIN" --headless --path "$PROJECT_DIR" --export-pack "Android" "$TEMP_ZIP"

echo "=> Extraindo assets para src/main/assets..."
rm -rf "$PROJECT_DIR/android/build/src/main/assets"
mkdir -p "$PROJECT_DIR/android/build/src/main/assets"
# `-o` e obrigatorio: sem ele o unzip PERGUNTA se sobrescreve, le EOF, responde
# "nenhum", e o pacote sai pela metade sem erro nenhum.
unzip -qo "$TEMP_ZIP" -d "$PROJECT_DIR/android/build/src/main/assets"
rm -f "$TEMP_ZIP"

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

# A conferencia que faltava. Um AAB sem `base/assets/project.binary` compila,
# assina e sobe para a loja sem uma linha de erro -- e morre no boot de todo
# mundo. Custa um `unzip -l`; pagar isso e barato perto de uma versao morta na
# producao.
echo "=> Conferindo que o pacote de dados esta dentro do AAB..."
# A listagem sai inteira para uma variavel antes de ser filtrada, de proposito:
# `unzip -Z1 ... | grep -q` faz o grep fechar o cano na primeira linha que
# casa, o unzip morre de SIGPIPE, e com `pipefail` o pipeline inteiro devolve
# 141 -- o teste acusaria "faltando" justamente quando o arquivo esta la.
ENTRADAS_AAB="$(unzip -Z1 "$OUT_AAB")"
if ! printf '%s\n' "$ENTRADAS_AAB" | grep -qx "base/assets/project.binary"; then
    echo "ERRO: o AAB nao tem base/assets/project.binary." >&2
    echo "A engine procura esse arquivo no AssetManager; sem ele o aplicativo" >&2
    echo "aborta em \"Unable to set up the Godot Engine!\" em qualquer aparelho." >&2
    exit 1
fi
echo "   OK: $(printf '%s\n' "$ENTRADAS_AAB" | grep -c '^base/assets/') arquivos em base/assets/"

echo "=> Build concluída com sucesso! AAB assinado gerado em: $OUT_AAB"
ls -lh "$OUT_AAB"
