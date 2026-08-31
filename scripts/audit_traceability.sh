#!/usr/bin/env bash
# Checagem de rastreabilidade da fase 1 (Discovery e Auditoria).
#
# Esta fase nao escreve GDScript, entao nao ha teste GUT novo. O que ela precisa
# provar e outra coisa: que tudo o que os documentos de auditoria afirmam tem
# endereco (arquivo:linha) ou fonte (https://) por tras, e que nenhum topico
# obrigatorio de descoberta ficou de fora.
#
# Uso:  bash scripts/audit_traceability.sh
# Sai 0 se as 4 checagens passarem; 1 se qualquer uma falhar.

set -uo pipefail
export LC_ALL=C   # comparacao byte a byte: os termos acentuados abaixo sao
                  # casados como bytes UTF-8, sem depender do locale da maquina.

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$RAIZ" || exit 1

AUDIT="docs/google-play/compatibility-audit.md"
REQS="docs/google-play/current-requirements.md"
PROJETO=".planning/PROJECT.md"
ROADMAP=".planning/ROADMAP.md"

# Pisos minimos: documento em prosa, sem tabela, nao pode passar por vacuo.
MIN_LINHAS_AUDIT=45
MIN_LINHAS_REQS=12
MIN_ENDERECOS_AUDIT=30
MIN_URLS_REQS=15

# Evidencia aceita numa linha de tabela: caminho de arquivo (linha opcional),
# URL, ou o marcador SEM-CODIGO, usado quando a linha afirma ausencia
# confirmada por grep e portanto nao tem arquivo para citar.
EVIDENCIA='[A-Za-z0-9_./-]+\.(gd|java|json|cfg|sh|xml|txt|csv|md)(:[0-9]+)?|https://|SEM-CODIGO'

# Lista literal de topicos de descoberta do REQUIREMENTS.md da fase. Cada termo
# comeca no segundo caractere da palavra de proposito: assim casa com maiuscula
# e minuscula sem precisar de -i (que nao e confiavel com acento em LC_ALL=C).
TOPICOS=(
  "ngine" "ramework" "inguagem" "lataforma" "strutura Android" "ódulo Android"
  "istema de build" "ackage" "utenticação" "anco de dados" "ackend" "PI"
  "suários" "ave local" "rogressão" "oedas" "XP" "íveis" "anking" "onquistas"
  "issões" "ventos" "emporadas" "ecompensas" "nalytics" "otificações" "ompras"
  "onetização" "nti-cheat" "incronização" "ffline"
)

FALHAS=0

executar() {  # $1 = rotulo, $2 = funcao
  if "$2"; then
    printf '[OK] %s\n' "$1"
  else
    printf '[FALHA] %s\n' "$1"
    FALHAS=$((FALHAS + 1))
  fi
}

# --- 1: toda linha de tabela dos dois documentos tem evidencia rastreavel -----
check_1() {
  local ruim=0 doc saida total ruins enderecos urls piso
  for doc in "$AUDIT" "$REQS"; do
    if [ ! -f "$doc" ]; then
      printf '    arquivo ausente: %s\n' "$doc"
      ruim=1
      continue
    fi
    saida=$(awk -v pat="$EVIDENCIA" -v arq="$doc" '
      { l[NR] = $0 }
      END {
        for (i = 1; i <= NR; i++) {
          if (l[i] !~ /^\|/) continue
          if (l[i] ~ /^\|[[:space:]]*:?--/) continue    # linha separadora
          if (l[i+1] ~ /^\|[[:space:]]*:?--/) continue  # linha de cabecalho
          total++
          if (l[i] ~ pat) continue
          printf "    %s:%d sem evidencia -> %.90s\n", arq, i, l[i]
          ruins++
        }
        printf "CONTAGEM %d %d\n", total, ruins
      }' "$doc")
    printf '%s\n' "$saida" | grep -v '^CONTAGEM ' || true
    total=$(printf '%s\n' "$saida" | awk '/^CONTAGEM /{print $2}')
    ruins=$(printf '%s\n' "$saida" | awk '/^CONTAGEM /{print $3}')
    if [ "${ruins:-0}" -gt 0 ]; then
      printf '    %s: %s linha(s) de tabela sem arquivo:linha, https:// ou SEM-CODIGO\n' "$doc" "$ruins"
      ruim=1
    fi
    if [ "$doc" = "$AUDIT" ]; then piso="$MIN_LINHAS_AUDIT"; else piso="$MIN_LINHAS_REQS"; fi
    if [ "${total:-0}" -lt "$piso" ]; then
      printf '    %s: so %s linha(s) de tabela, o minimo e %s (documento em prosa nao e auditoria)\n' \
        "$doc" "${total:-0}" "$piso"
      ruim=1
    fi
  done

  if [ -f "$AUDIT" ]; then
    enderecos=$(grep -oE '[A-Za-z0-9_./-]+\.(gd|java|json|cfg|sh|xml|txt|csv|md):[0-9]+' "$AUDIT" | wc -l | tr -d ' ')
    if [ "$enderecos" -lt "$MIN_ENDERECOS_AUDIT" ]; then
      printf '    %s: so %s citacao(oes) arquivo:linha, o minimo e %s\n' "$AUDIT" "$enderecos" "$MIN_ENDERECOS_AUDIT"
      ruim=1
    fi
  fi
  if [ -f "$REQS" ]; then
    urls=$(grep -oE 'https://[^ )|]+' "$REQS" | wc -l | tr -d ' ')
    if [ "$urls" -lt "$MIN_URLS_REQS" ]; then
      printf '    %s: so %s URL(s) oficiais, o minimo e %s\n' "$REQS" "$urls" "$MIN_URLS_REQS"
      ruim=1
    fi
  fi
  [ "$ruim" -eq 0 ]
}

# --- 2: nenhum topico de descoberta do REQUIREMENTS.md ficou de fora ---------
check_2() {
  local t faltando=0
  if [ ! -f "$AUDIT" ]; then
    printf '    arquivo ausente: %s\n' "$AUDIT"
    return 1
  fi
  for t in "${TOPICOS[@]}"; do
    if ! grep -qF -- "$t" "$AUDIT"; then
      printf '    topico de descoberta ausente no audit: %s\n' "$t"
      faltando=$((faltando + 1))
    fi
  done
  [ "$faltando" -eq 0 ]
}

# --- 3: PROJECT.md descreve as tres camadas, nao nega servidor/conta --------
check_3() {
  local ruim=0
  if [ ! -f "$PROJETO" ]; then
    printf '    arquivo ausente: %s\n' "$PROJETO"
    return 1
  fi
  if grep -nE 'sem servidores|sem contas|Sem Sistema de Contas' "$PROJETO" | sed 's/^/    tenet vencido -> /'; then
    ruim=1
  fi
  grep -qF 'playtable.ricasolucoes.com.br' "$PROJETO" || {
    printf '    PROJECT.md nao cita a camada de servidor proprio (playtable.ricasolucoes.com.br)\n'
    ruim=1
  }
  grep -qF 'Play Games' "$PROJETO" || {
    printf '    PROJECT.md nao cita a camada Play Games\n'
    ruim=1
  }
  [ "$ruim" -eq 0 ]
}

# --- 4: ROADMAP tem a fase 7.1 entre a 7 e a 8 ------------------------------
check_4() {
  local c71 n7 n71 n8
  if [ ! -f "$ROADMAP" ]; then
    printf '    arquivo ausente: %s\n' "$ROADMAP"
    return 1
  fi
  c71=$(grep -c '^### Phase 7\.1' "$ROADMAP")
  if [ "$c71" -ne 1 ]; then
    printf '    esperava exatamente 1 linha "### Phase 7.1", achei %s\n' "$c71"
    return 1
  fi
  n7=$(grep -n '^### Phase 7:' "$ROADMAP" | head -1 | cut -d: -f1)
  n71=$(grep -n '^### Phase 7\.1' "$ROADMAP" | head -1 | cut -d: -f1)
  n8=$(grep -n '^### Phase 8:' "$ROADMAP" | head -1 | cut -d: -f1)
  if [ -z "$n7" ] || [ -z "$n8" ]; then
    printf '    nao achei "### Phase 7:" ou "### Phase 8:" no roadmap\n'
    return 1
  fi
  if [ "$n71" -lt "$n7" ] || [ "$n71" -gt "$n8" ]; then
    printf '    Phase 7.1 (linha %s) nao esta entre Phase 7 (linha %s) e Phase 8 (linha %s)\n' "$n71" "$n7" "$n8"
    return 1
  fi
  return 0
}

printf 'Rastreabilidade da fase 1 -- raiz: %s\n\n' "$RAIZ"
executar "1 rastreabilidade"   check_1
executar "2 cobertura-topicos" check_2
executar "3 project-tenets"    check_3
executar "4 roadmap-fase-7.1"  check_4

printf '\nRESULTADO: %d de 4 checagens verdes\n' "$((4 - FALHAS))"
[ "$FALHAS" -eq 0 ] || exit 1
exit 0
