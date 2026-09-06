#!/usr/bin/env bash
# Copia os icones de launcher e as imagens do splash para o modelo de
# compilacao do Android.
#
# android/build/ e gerado e nao e versionado; reinstalar o modelo apaga o que
# estiver em res/. E os builds deste repositorio nao passam pelo exportador do
# Godot (--export-pack + gradle), entao ninguem mais escreve os icones ali: sem
# esta copia o pacote sai com o robo do godot-lib.aar -- no launcher e, no
# Android 12+, na tela de abertura (res/drawable/splash_icon.webp). Idempotente.
#
# Os PNG saem de tools/make_launcher_icons.py a partir de icon.png; os WEBP do
# drawable/ saem de tools/make_splash.py.
set -euo pipefail

AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD="${1:-$AQUI/../build}"

if [ ! -d "$BUILD/res" ]; then
	echo "android/icons: $BUILD/res nao existe (modelo de compilacao ausente)" >&2
	exit 1
fi
if [ ! -f "$AQUI/drawable/splash_icon.webp" ]; then
	echo "android/icons: falta drawable/splash_icon.webp -- rode tools/make_splash.py" >&2
	exit 1
fi

copiados=0
for pasta in "$AQUI"/mipmap* "$AQUI"/drawable*; do
	[ -d "$pasta" ] || continue
	nome="$(basename "$pasta")"
	mkdir -p "$BUILD/res/$nome"
	for arquivo in "$pasta"/*.png "$pasta"/*.webp; do
		[ -f "$arquivo" ] || continue
		cp "$arquivo" "$BUILD/res/$nome/"
	done
	copiados=$((copiados + 1))
done

if [ "$copiados" -eq 0 ]; then
	echo "android/icons: nenhuma pasta mipmap* -- rode tools/make_launcher_icons.py" >&2
	exit 1
fi
echo "android/icons: $copiados pastas (mipmap* e drawable*) copiadas para $BUILD/res"
