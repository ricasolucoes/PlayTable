#!/usr/bin/env bash
# Baixa o GUT (Godot Unit Test) numa versao fixa para addons/gut.
#
# O addon nao e versionado neste repositorio (ver .gitignore): sao ~11 MB de
# codigo de terceiros, dos quais 8,8 MB vem de um unico .tscn do painel do
# editor. Buscar sob demanda mantem a arvore limpa e o pacote do F-Droid
# livre de codigo que nao roda no aplicativo.
#
# A versao esta amarrada a engine: o GUT 9.7.x exige Godot 4.4+ e o 9.3.x so
# roda ate a 4.3. O projeto migrou para a 4.6 na v0.3.0, entao 9.7.1.
# Trocar a engine de volta para a 4.3 exige GUT_VERSION=v9.3.0.
set -euo pipefail

GUT_VERSION="${GUT_VERSION:-v9.7.1}"
GUT_REPO="${GUT_REPO:-https://github.com/bitwes/Gut.git}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TARGET="$REPO_ROOT/addons/gut"
STAMP="$TARGET/.gut_version"

if [[ -f "$STAMP" && "$(cat "$STAMP")" == "$GUT_VERSION" ]]; then
	echo "GUT $GUT_VERSION ja instalado em $TARGET"
	exit 0
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "Baixando GUT $GUT_VERSION de $GUT_REPO ..."
git -c advice.detachedHead=false clone --quiet --depth 1 --branch "$GUT_VERSION" "$GUT_REPO" "$TMP_DIR/gut"

rm -rf "$TARGET"
mkdir -p "$REPO_ROOT/addons"
cp -R "$TMP_DIR/gut/addons/gut" "$TARGET"
cp "$TMP_DIR/gut/LICENSE" "$TARGET/LICENSE" 2>/dev/null || true
echo "$GUT_VERSION" > "$STAMP"

echo "GUT $GUT_VERSION instalado em $TARGET"
