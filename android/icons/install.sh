#!/usr/bin/env bash
# Copia os icones de launcher para o modelo de compilacao do Android.
#
# android/build/ e gerado e nao e versionado; reinstalar o modelo apaga o que
# estiver em res/. E os builds deste repositorio nao passam pelo exportador do
# Godot (--export-pack + gradle), entao ninguem mais escreve os icones ali: sem
# esta copia o pacote sai com o robo do godot-lib.aar. Idempotente.
#
# Os PNG saem de tools/make_launcher_icons.py a partir de icon.png.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${1:-$AQUI/../build}"

if [ ! -d "$BUILD/res" ]; then
	echo "android/icons: $BUILD/res nao existe (modelo de compilacao ausente)" >&2
	exit 1
fi

copiados=0
for pasta in "$AQUI"/mipmap*; do
	[ -d "$pasta" ] || continue
	nome="$(basename "$pasta")"
	mkdir -p "$BUILD/res/$nome"
	cp "$pasta"/*.png "$BUILD/res/$nome/"
	copiados=$((copiados + 1))
done

if [ "$copiados" -eq 0 ]; then
	echo "android/icons: nenhuma pasta mipmap* -- rode tools/make_launcher_icons.py" >&2
	exit 1
fi
echo "android/icons: $copiados pastas mipmap copiadas para $BUILD/res"
