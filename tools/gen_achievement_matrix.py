#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Gera docs/google-play/achievement-matrix.md a partir do catálogo.

A matriz é a lista que se usa para criar as conquistas no Play Console, e é
por isso que ela não pode ser escrita à mão: a versão anterior derivou do
código e prometia uma conquista de Xadrez, jogo que o PlayTable não tem.

Uso: python3 tools/gen_achievement_matrix.py
"""
import csv
import json
import os

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CATALOGO = os.path.join(RAIZ, 'core/configs/achievements.json')
IDS = os.path.join(RAIZ, 'core/configs/play_games_ids.json')
TRADUCOES = os.path.join(RAIZ, 'core/i18n/translations.csv')
SAIDA = os.path.join(RAIZ, 'docs/google-play/achievement-matrix.md')

CAT_PT = {
    "progressao": "Progressão", "habilidade": "Habilidade",
    "exploracao": "Exploração", "persistencia": "Persistência",
    "tabuleiro": "Tabuleiro", "cartas": "Cartas",
    "colecao": "Coleção", "segredos": "Segredos", "social": "Social",
}


def traducoes():
    tr = {}
    with open(TRADUCOES, encoding='utf-8') as f:
        for row in csv.reader(f):
            if row and len(row) >= 2:
                tr[row[0]] = row[1]
    return tr


def tipo_play(a):
    r = a['rule']
    if r['type'] in ('stat', 'level', 'streak', 'distinct_games', 'mastery') \
            and int(r.get('target', 1)) > 1:
        return 'Incremental'
    return 'Oculta' if a.get('hidden') else 'Padrão'


def condicao(a):
    r = a['rule']
    t = r['type']
    return {
        'stat': lambda: "`%s` >= %d" % (r['key'], r['target']),
        'level': lambda: "nível do perfil >= %d" % r['target'],
        'streak': lambda: "sequência diária >= %d" % r['target'],
        'distinct_games': lambda: "%d jogos diferentes" % r['target'],
        'game_win': lambda: "1 vitória em `%s`" % r['game'],
        'flag': lambda: "evento `%s`" % r['key'],
        'mastery': lambda: "maestria >= %d em qualquer jogo" % r['target'],
        'all': lambda: "todas as outras conquistas",
    }.get(t, lambda: t)()


def main():
    tr = traducoes()
    cat = json.load(open(CATALOGO, encoding='utf-8'))['achievements']
    ids = json.load(open(IDS, encoding='utf-8'))

    linhas = []
    for a in cat:
        linhas.append("| `%s` | %s | %s | %s | %s | %s | %d | %s |" % (
            a['id'],
            tr.get(a['id'] + '_NAME', a['id']),
            CAT_PT.get(a['cat'], a['cat']),
            tr.get(a['id'] + '_DESC', ''),
            condicao(a),
            tipo_play(a),
            a['xp'],
            "sim" if ids['achievements'].get(a['id']) else "**pendente**",
        ))

    pendentes = sum(1 for a in cat if not ids['achievements'].get(a['id']))
    doc = CABECALHO % (len(cat), pendentes, len(cat), "\n".join(linhas))
    open(SAIDA, 'w', encoding='utf-8').write(doc)
    print("matriz gerada: %d conquistas, %d pendentes de mapeamento" % (len(cat), pendentes))


CABECALHO = """# Matriz de Conquistas (PlayTable)

> **Gerado por `tools/gen_achievement_matrix.py` a partir de
> `core/configs/achievements.json` e das traduções. Não editar à mão** — a
> versão anterior deste arquivo foi escrita à mão e derivou: prometia uma
> conquista de Xadrez, jogo que não existe no PlayTable, e não tinha nada de
> Gamão, Torre de Hanói, Nim nem Resta Um.

São **%d conquistas** cobrindo os 19 jogos, progressão, persistência, coleção e
segredos. O motor (`core/services/AchievementEngine.gd`) não conhece nenhuma
delas pelo nome: lê a regra, calcula o valor atual, compara com o alvo.

A coluna **Mapeada** diz se o id do Play Console já foi preenchido em
`core/configs/play_games_ids.json`. Enquanto estiver pendente, o
`PlayGamesManager` **não envia** aquela conquista — de propósito: um id
inventado é recusado em silêncio pelo servidor e a integração pareceria
funcionar sem entregar nada. Hoje: **%d pendentes de %d**.

O **Tipo Google Play** é o que criar no Console: `Incremental` para as que têm
alvo maior que 1 (o jogo envia o número absoluto de passos, não incrementos, para
a fila offline poder colapsar repetição sem perder contagem), `Oculta` para as
secretas e `Padrão` para o resto.

| ID | Nome | Categoria | Objetivo | Condição no motor | Tipo Google Play | XP | Mapeada |
| -- | ---- | --------- | -------- | ----------------- | ---------------- | -- | ------- |
%s
"""

if __name__ == '__main__':
    main()
