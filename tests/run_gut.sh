#!/usr/bin/env bash
# Roda a suite GUT contra o GDScript de producao, headless.
#
# Uso:
#   tests/run_gut.sh
#   tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_tic_tac_toe.gd
#   GODOT_BIN=/caminho/para/godot tests/run_gut.sh
#
# A engine e a de `.godot-version`, exata -- a mesma que a CI baixa e a mesma
# que vai dentro do APK.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A versao exigida mora em .godot-version e quem resolve e scripts/godot_bin.sh,
# o mesmo que os scripts de build usam. Antes aqui bastava "4.4 ou mais novo", e
# por isso a suite passou a rodar num Godot 4.6 enquanto o APK saia com a 4.7.2:
# testar numa engine e publicar em outra e como nao testar.
GODOT_BIN="$("$REPO_ROOT/scripts/godot_bin.sh")"

godot_version() {
	"$1" --version 2>/dev/null | tail -n 1 | tr -d '\r'
}

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
# A suite roda contra o mesmo `user://` do jogo instalado nesta maquina: quem
# joga aqui tem perfil, XP, fila do Play Games e degrau de dificuldade
# gravados nele. Varios testes terminam partida de verdade -- e fim de partida
# grava. Guardar o arquivo antes e devolver depois e o que impede a suite de
# mexer no progresso de quem esta jogando.
#
# Fica no shell, e nao em `before_each`, porque assim vale para os 30 arquivos
# de teste de uma vez, inclusive os que ainda nao existem.
USER_DIR="$HOME/Library/Application Support/user_data"
if [[ "$(uname)" != "Darwin" ]]; then
	USER_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/user_data"
fi
SAVE_BAK="$(mktemp)"
SAVE_TINHA=0
if [[ -f "$USER_DIR/config.save" ]]; then
	cp "$USER_DIR/config.save" "$SAVE_BAK"
	SAVE_TINHA=1
fi

restaurar_save() {
	if (( SAVE_TINHA )); then
		cp "$SAVE_BAK" "$USER_DIR/config.save"
	else
		rm -f "$USER_DIR/config.save"
	fi
	rm -f "$SAVE_BAK"
}

SAIDA="$(mktemp)"
trap 'rm -f "$SAIDA"; restaurar_save' EXIT

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
