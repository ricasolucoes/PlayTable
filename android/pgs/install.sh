#!/bin/bash
# Instala a integracao Play Games no build customizado do Android.
#
# `android/build/` e gerado pelo Godot e esta no .gitignore: reinstalar o
# template de build apaga tudo que estiver la dentro. Por isso a fonte de
# verdade da integracao mora aqui, em android/pgs/ (versionado), e este script
# a reaplica. Rodar duas vezes nao duplica nada.
#
# Uso:
#   android/pgs/install.sh            instala
#   android/pgs/install.sh --check    so verifica e devolve 1 se faltar algo
set -euo pipefail

RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
PGS="$RAIZ/android/pgs"
BUILD="$RAIZ/android/build"
MANIFESTO="$BUILD/src/main/AndroidManifest.xml"
IDS_JSON="$RAIZ/core/configs/play_games_ids.json"
MODO="${1:-install}"

falhou=0
aviso() { echo "   ! $*"; falhou=1; }
ok()    { echo "   . $*"; }

if [ ! -d "$BUILD" ]; then
    echo "ERRO: $BUILD nao existe. No editor do Godot: Projeto > Instalar modelo de compilacao Android."
    exit 1
fi

# ---------------------------------------------------------------- app id
APP_ID="$(python3 -c "
import json,sys
try:
    print(json.load(open('$IDS_JSON')).get('app_id','').strip())
except Exception:
    print('')
")"

if [ -z "$APP_ID" ]; then
    aviso "app_id vazio em core/configs/play_games_ids.json."
    aviso "  Pegue em Play Console > Play Games Services > Configuracao > 'ID do projeto'."
    aviso "  Sem ele o SDK do PGS nao inicializa e o jogo roda sem Play Games (o resto funciona)."
else
    ok "app_id: $APP_ID"
fi

if [ "$MODO" = "--check" ]; then
    grep -q "org.godotengine.plugin.v2.PlayTablePGS" "$MANIFESTO" 2>/dev/null \
        && ok "plugin registrado no manifesto" || aviso "plugin NAO registrado no manifesto"
    grep -q "android.permission.INTERNET" "$MANIFESTO" 2>/dev/null \
        && ok "permissao INTERNET presente" || aviso "permissao INTERNET AUSENTE"
    [ -f "$BUILD/src/main/java/org/playtable/pgs/PlayTablePGS.java" ] \
        && ok "fonte do plugin em src/main/java" || aviso "fonte do plugin ausente"
    [ -f "$BUILD/res/values/games_ids.xml" ] \
        && ok "games_ids.xml presente" || aviso "games_ids.xml ausente"
    exit $falhou
fi

# ------------------------------------------------------------- fontes java
mkdir -p "$BUILD/src/main/java/org/playtable/pgs"
cp "$PGS/java/org/playtable/pgs/"*.java "$BUILD/src/main/java/org/playtable/pgs/"
ok "fontes Java copiadas"

# ------------------------------------------------------------- recurso de id
mkdir -p "$BUILD/res/values"
cat > "$BUILD/res/values/games_ids.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<!-- GERADO por android/pgs/install.sh a partir de core/configs/play_games_ids.json.
     Nao editar aqui: android/build/ e recriado pelo Godot e a edicao se perde. -->
<resources>
    <string name="game_services_project_id" translatable="false">${APP_ID}</string>
</resources>
XML
ok "res/values/games_ids.xml gerado"

# ---------------------------------------------------------------- manifesto
python3 - "$MANIFESTO" "$PGS/AndroidManifest.inject.xml" <<'PY'
import re, sys

caminho, trecho_path = sys.argv[1], sys.argv[2]
s = open(caminho, encoding='utf-8').read()

# Permissoes. O Godot so injeta INTERNET automaticamente em export de debug, e
# estes builds vao direto pelo gradle sem passar pelo exportador -- o AAB de
# release saia sem permissao de rede nenhuma.
PERMISSOES = ["android.permission.INTERNET", "android.permission.ACCESS_NETWORK_STATE"]
faltando = [p for p in PERMISSOES if p not in s]
if faltando:
    bloco = "\n".join('    <uses-permission android:name="%s" />' % p for p in faltando)
    s = re.sub(r'(<manifest\b[^>]*>)', r'\1\n' + bloco, s, count=1)

# Meta-data do PGS e registro do plugin, antes de </application>.
if "org.godotengine.plugin.v2.PlayTablePGS" not in s:
    trecho = open(trecho_path, encoding='utf-8').read()
    corpo = "\n".join("        " + l for l in trecho.strip().splitlines())
    s = s.replace("    </application>", corpo + "\n\n    </application>", 1)

open(caminho, 'w', encoding='utf-8').write(s)
print("   . manifesto atualizado (permissoes + meta-data do PGS)")
PY

echo
echo "Instalado. O gradle recebe a dependencia do SDK pela propriedade oficial de plugin:"
echo "  -Pplugins_remote_binaries=\"$(cat "$PGS/gradle_deps.txt" | tr '\n' '|' | sed 's/|$//')\""
echo "Os build_apk.sh / build_aab.sh ja fazem isso."
