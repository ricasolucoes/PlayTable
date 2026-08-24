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

# Sempre delega ao install_gut.sh: ele compara o carimbo .gut_version com a
# versao fixada e so baixa quando diferem. Conferir apenas se gut_cmdln.gd
# existe deixaria passar uma instalacao velha — foi o que aconteceu com o
# 9.3.0 (Godot 4.3) sobrevivendo a migracao para a 4.6, onde ele nem carrega:
# o 9.3.0 declara `class_name Logger`, que na 4.6 e uma classe nativa.
"$REPO_ROOT/tests/install_gut.sh"

# O GUT registra class_names proprios; sem importar, o gut_cmdln.gd aborta.
# Trocar de versao da engine tambem invalida o cache, por isso o carimbo.
#
# O carimbo tambem cobre a lista de class_name do projeto: uma classe nova so
# entra em global_script_class_cache.cfg depois de um --import, e ate la quem
# herda dela morre em "Could not find base class". Conferir so engine e GUT
# deixava passar exatamente esse caso.
STAMP="$REPO_ROOT/.godot/.gut_import_stamp"
CLASSES="$(grep -rhE '^class_name ' "$REPO_ROOT/core" "$REPO_ROOT/games" "$REPO_ROOT/shared" \
	--include='*.gd' 2>/dev/null | sort | shasum | cut -d' ' -f1)"
WANT="$(godot_version "$GODOT_BIN")|$(cat "$REPO_ROOT/addons/gut/.gut_version" 2>/dev/null || echo none)|$CLASSES"
if [[ ! -f "$STAMP" || "$(cat "$STAMP")" != "$WANT" ]]; then
	echo "Importando recursos (engine ou GUT mudaram)..."
	"$GODOT_BIN" --headless --path "$REPO_ROOT" --import >/dev/null 2>&1 || true
	mkdir -p "$(dirname "$STAMP")"
	echo "$WANT" > "$STAMP"
fi

# Um arquivo de teste que nao compila nao reprova nada: o GUT o descarta com
# "Ignoring script ... because it does not extend GutTest", um aviso no meio da
# saida, e segue com os outros. O arquivo some da suite sem ninguem notar --
# aconteceu com test_table_item_3d.gd, que sumiu por um `:=` que nao inferia.
SAIDA="$(mktemp)"
trap 'rm -f "$SAIDA"' EXIT

set +e
"$GODOT_BIN" --headless --path "$REPO_ROOT" -s addons/gut/gut_cmdln.gd "$@" 2>&1 | tee "$SAIDA"
STATUS=${PIPESTATUS[0]}
set -e

if grep -q "Ignoring script" "$SAIDA"; then
	echo "" >&2
	echo "ERRO: o GUT descartou arquivo(s) de teste -- provavelmente erro de parse:" >&2
	grep "Ignoring script" "$SAIDA" >&2
	STATUS=1
fi

exit "$STATUS"
