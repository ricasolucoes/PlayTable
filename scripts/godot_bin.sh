#!/usr/bin/env bash
# Resolve o binario do Godot na versao que o projeto exige e imprime o caminho.
#
# Existe porque a versao da engine nao e detalhe de ambiente: o
# `libgodot_android.so` que vai dentro do APK vem do modelo de build do
# Android, e um pacote de dados exportado por outra versao faz o aplicativo
# morrer de SIGSEGV na primeira quadro renderizado -- instala, abre e fecha,
# sem uma linha de erro durante a compilacao. Foi o que aconteceu na v0.6.0:
# havia um Godot 4.6 na raiz do repositorio e os scripts o escolhiam primeiro.
#
# A versao exigida mora em `.godot-version`, versionado, e e a mesma que a CI
# baixa. Aqui a conferencia e exata: 4.7.1 nao serve no lugar de 4.7.2.
#
# Uso:
#   GODOT_BIN="$(scripts/godot_bin.sh)"
#   scripts/godot_bin.sh --check      # so confere e explica, nao imprime nada
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
QUERO="$(tr -d '[:space:]' < "$REPO_ROOT/.godot-version")"
QUERO_NUM="${QUERO%%-*}"

versao_de() {
	"$1" --version 2>/dev/null | tail -n 1 | tr -d '\r'
}

serve() {
	[[ -x "$1" ]] || return 1
	[[ "$(versao_de "$1")" == "$QUERO_NUM".* ]]
}

# Um caminho apontado a mao e ordem, nao sugestao: se ele nao serve, isto para
# e explica. Cair calado em outra engine faria o operador achar que testou o
# binario que pediu.
ESCOLHIDO=""
for var in GODOT_BIN GODOT; do
	escolhido_a_mao="${!var:-}"
	[[ -z "$escolhido_a_mao" ]] && continue
	if serve "$escolhido_a_mao"; then
		ESCOLHIDO="$escolhido_a_mao"
		break
	fi
	{
		echo "ERRO: $var aponta para $escolhido_a_mao ($(versao_de "$escolhido_a_mao" || echo 'nao executa'))."
		echo "O projeto exige Godot $QUERO (.godot-version). Corrija $var ou remova a variavel."
	} >&2
	exit 127
done

CANDIDATOS=()
for c in godot godot4; do
	command -v "$c" >/dev/null 2>&1 && CANDIDATOS+=("$(command -v "$c")")
done
# Onde as engines costumam ficar nesta maquina, e dentro de bundles .app.
for app in "$HOME/Dev/godot-$QUERO_NUM"/Godot*.app "$REPO_ROOT"/Godot*.app \
		/Applications/Godot*.app "$HOME/Applications"/Godot*.app; do
	[[ -x "$app/Contents/MacOS/Godot" ]] && CANDIDATOS+=("$app/Contents/MacOS/Godot")
done
for bin in "$HOME/Dev/godot-$QUERO_NUM"/godot "$HOME/.local/share/godot-bin/godot"; do
	[[ -x "$bin" ]] && CANDIDATOS+=("$bin")
done

for c in "${CANDIDATOS[@]:-}"; do
	[[ -n "$ESCOLHIDO" ]] && break
	[[ -z "$c" ]] && continue
	if serve "$c"; then ESCOLHIDO="$c"; break; fi
done

if [[ -z "$ESCOLHIDO" ]]; then
	{
		echo "ERRO: nenhum Godot $QUERO encontrado (.godot-version pede exatamente esta versao)."
		for c in "${CANDIDATOS[@]:-}"; do
			[[ -n "$c" ]] && echo "  descartado: $c ($(versao_de "$c" || echo 'versao desconhecida'))"
		done
		echo "Baixe em https://github.com/godotengine/godot/releases/tag/$QUERO"
		echo "ou aponte com GODOT_BIN=/caminho/para/godot."
	} >&2
	exit 127
fi

# O modelo de build do Android carrega a propria engine: se ele discordar do
# `.godot-version`, o APK sai com uma engine e um pacote de dados de outra.
CARIMBO="$REPO_ROOT/android/build/.build_version"
if [[ -f "$CARIMBO" ]]; then
	TEM="$(tr -d '[:space:]' < "$CARIMBO")"
	if [[ "$TEM" != "$QUERO_NUM".* ]]; then
		{
			echo "ERRO: o modelo de build do Android e $TEM, mas o projeto exige $QUERO."
			echo "Um APK com essa combinacao instala e morre de SIGSEGV no primeiro quadro."
			echo "Reinstale o modelo pelo editor $QUERO (Projeto > Instalar modelo de compilacao),"
			echo "e depois rode android/pgs/install.sh para repor o plugin do Play Games."
		} >&2
		exit 126
	fi
fi

if [[ "${1:-}" == "--check" ]]; then
	echo "Godot $QUERO OK: $ESCOLHIDO" >&2
	[[ -f "$CARIMBO" ]] && echo "Modelo Android OK: $(tr -d '[:space:]' < "$CARIMBO")" >&2
	exit 0
fi

echo "$ESCOLHIDO"
