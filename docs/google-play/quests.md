# Missões Diárias e Semanais (Quests)

O PlayTable possui um sistema rotativo de Quests focado na geração de loop diário e variação de exploração.

## Categorias de Missões

| ID | Nome / Descrição | Requisito (Target) | XP Recompensa | Tipo |
| --- | --- | --- | --- | --- |
| `quest_play_3` | Jogue 3 partidas de qualquer jogo | 3 partidas | 300 XP | Diária |
| `quest_win_1` | Vença 1 partida | 1 vitória | 500 XP | Diária |
| `quest_collect_10`| Colete 10 fichas/peças durante os jogos | 10 itens | 200 XP | Diária |
| `quest_play_all` | Jogue todos os jogos da sua biblioteca | 16 partidas | 2000 XP | Semanal |
| `quest_win_5_hard`| Vença 5 jogos contra a IA no nível difícil | 5 vitórias | 3000 XP | Semanal |

## Rotação e Ciclo de Vida
- **Missões Diárias**: Substituídas todos os dias à meia-noite (local). O jogador sempre recebe um conjunto focado em retorno imediato.
- **Missões Semanais**: Opcionais e mais profundas. Servem como um guia de progresso contínuo de segunda a domingo.

*(As missões concluídas emitem um evento global ao `GameEventBus` que se propaga para as estatísticas repetitivas da Play Store via `Game Stats API`)*.
