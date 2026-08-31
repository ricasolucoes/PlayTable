# Missões Diárias e Semanais (Quests)

O PlayTable possui um sistema rotativo de Quests focado na geração de loop diário e variação de exploração. O catálogo vive em `core/configs/quests.json` e é interpretado por `core/services/QuestEngine.gd`.

## Categorias de Missões

Cada entrada do catálogo tem `id`, `type`, `target` e `xp`; três entradas (`d_board_2`, `d_cards_2`, `w_win_all_cat`) têm também `category`. A coluna "Regra (type)" traz o valor de `type` do JSON, mais uma frase curta explicando o que ele conta.

### Diárias (11)

| ID | Regra (type) | Alvo (target) | XP | Ciclo | Categoria |
| --- | --- | --- | --- | --- | --- |
| `d_play_3` | `play` — jogar partidas, qualquer jogo | 3 | 300 | Diária | — |
| `d_play_5` | `play` — jogar partidas, qualquer jogo | 5 | 450 | Diária | — |
| `d_win_1` | `win` — vencer partidas | 1 | 400 | Diária | — |
| `d_win_3` | `win` — vencer partidas | 3 | 700 | Diária | — |
| `d_distinct_2` | `distinct_games` — jogar jogos diferentes | 2 | 350 | Diária | — |
| `d_distinct_3` | `distinct_games` — jogar jogos diferentes | 3 | 550 | Diária | — |
| `d_board_2` | `win_category` — vencer partidas de uma categoria | 2 | 500 | Diária | board |
| `d_cards_2` | `win_category` — vencer partidas de uma categoria | 2 | 500 | Diária | cards |
| `d_fast_1` | `fast_win` — vencer em partida rápida | 1 | 600 | Diária | — |
| `d_perfect_1` | `perfect` — vencer sem erro/derrota parcial | 1 | 800 | Diária | — |
| `d_mastery_100` | `mastery_xp` — ganhar XP de maestria num jogo | 1 | 400 | Diária | — |

### Semanais (6)

| ID | Regra (type) | Alvo (target) | XP | Ciclo | Categoria |
| --- | --- | --- | --- | --- | --- |
| `w_play_20` | `play` — jogar partidas, qualquer jogo | 20 | 2000 | Semanal | — |
| `w_win_10` | `win` — vencer partidas | 10 | 2500 | Semanal | — |
| `w_distinct_6` | `distinct_games` — jogar jogos diferentes | 6 | 2200 | Semanal | — |
| `w_win_all_cat` | `win_category` — vencer partidas de uma categoria | 5 | 2400 | Semanal | board |
| `w_mastery_800` | `mastery_xp` — ganhar XP de maestria num jogo | 2 | 2600 | Semanal | — |
| `w_perfect_3` | `perfect` — vencer sem erro/derrota parcial | 3 | 3000 | Semanal | — |

## Rotação e Ciclo de Vida

- **Missões Diárias**: o pool tem 11 candidatas; o `QuestEngine.gd` sorteia `daily_count` (3, no catálogo atual) por dia, substituídas todos os dias à meia-noite (local).
- **Missões Semanais**: o pool tem 6 candidatas; o `QuestEngine.gd` sorteia `weekly_count` (2, no catálogo atual) por semana ISO, de segunda a domingo.
- O sorteio é **determinístico por semente de data**: reabrir o app no mesmo dia (ou na mesma semana ISO, para as semanais) devolve exatamente as mesmas missões em vez de resortear — isso é de propósito, não bug.

*(As missões concluídas emitem um evento global ao `GameEventBus` que se propaga para as estatísticas repetitivas da Play Store via `Game Stats API`)*.
