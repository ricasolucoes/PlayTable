#!/usr/bin/env bash
# Roda a suite GUT contra o GDScript de producao, headless.
#
# Uso:
#   tests/run_gut.sh
#   tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_tic_tac_toe.gd
#   GODOT=/caminho/para/godot tests/run_gut.sh
#
# O projeto usa Godot 4.6 desde a v0.3.0 e o GUT 9.7.x exige 4.4 ou mais novo.
# O Godot.app que fica na raiz do repositorio (ignorado pelo git) pode ser uma
# copia antiga: por isso a versao e conferida antes de rodar.
set -euo pipefail

MIN_MAJOR=4
MIN_MINOR=4

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

godot_version() {
	"$1" --version 2>/dev/null | tail -n 1 | tr -d '\r'
}

version_ok() {
	local v major minor
	v="$(godot_version "$1")"
	major="${v%%.*}"
	minor="${v#*.}"; minor="${minor%%.*}"
	[[ "$major" =~ ^[0-9]+$ && "$minor" =~ ^[0-9]+$ ]] || return 1
	(( major > MIN_MAJOR )) && return 0
	(( major == MIN_MAJOR && minor >= MIN_MINOR ))
}

CANDIDATES=()
[[ -n "${GODOT:-}" ]] && CANDIDATES+=("$GODOT")
for c in godot godot4 Godot; do
	if command -v "$c" >/dev/null 2>&1; then CANDIDATES+=("$(command -v "$c")"); fi
done
# macOS: o binario de linha de comando fica dentro do bundle .app.
for app in "$REPO_ROOT"/Godot*.app /Applications/Godot*.app "$HOME"/Applications/Godot*.app; do
	[[ -x "$app/Contents/MacOS/Godot" ]] && CANDIDATES+=("$app/Contents/MacOS/Godot")
done

GODOT_BIN=""
for c in "${CANDIDATES[@]:-}"; do
	[[ -z "$c" ]] && continue
	if version_ok "$c"; then GODOT_BIN="$c"; break; fi
done

if [[ -z "$GODOT_BIN" ]]; then
	echo "ERRO: nenhum Godot >= ${MIN_MAJOR}.${MIN_MINOR} encontrado." >&2
	for c in "${CANDIDATES[@]:-}"; do
		[[ -n "$c" ]] && echo "  descartado: $c ($(godot_version "$c" || echo 'versao desconhecida'))" >&2
	done
	echo "Defina GODOT=/caminho/para/godot-4.6 ou instale o GUT 9.3.0 (GUT_VERSION=v9.3.0) para usar a 4.3." >&2
	exit 127
fi

echo "Godot: $GODOT_BIN ($(godot_version "$GODOT_BIN"))"

if [[ ! -f "$REPO_ROOT/addons/gut/gut_cmdln.gd" ]]; then
	echo "GUT ausente; instalando..."
	"$REPO_ROOT/tests/install_gut.sh"
fi

# O GUT registra class_names proprios; sem importar, o gut_cmdln.gd aborta.
# Trocar de versao da engine tambem invalida o cache, por isso o carimbo.
STAMP="$REPO_ROOT/.godot/.gut_import_stamp"
WANT="$(godot_version "$GODOT_BIN")|$(cat "$REPO_ROOT/addons/gut/.gut_version" 2>/dev/null || echo none)"
if [[ ! -f "$STAMP" || "$(cat "$STAMP")" != "$WANT" ]]; then
	echo "Importando recursos (engine ou GUT mudaram)..."
	"$GODOT_BIN" --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
	mkdir -p "$(dirname "$STAMP")"
	echo "$WANT" > "$STAMP"
fi

set +e
"$GODOT_BIN" --headless --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd "$@"
STATUS=$?
set -e

exit "$STATUS"
