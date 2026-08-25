# Google Play Game Stats Schema

Para satisfazer os requisitos do programa **Level Up** e permitir que a arquitetura analise a retenção de jogadores de forma saudável, o jogo enviará dados fundamentais via a API de *Game Stats*.

## 1. Progression Stat (Estatística de Progressão Principal)
A métrica principal de progressão de um jogador no PlayTable é o seu **Nível de Perfil**, que sobe ao acumular XP nas partidas diárias.
- **Nome no Console**: Nível do Jogador
- **ID da Configuração**: `progression_level`
- **Tipo de Agregação**: Substituir (Sempre o maior nível local)

## 2. Repetitive Game Events (Estatísticas Recorrentes)
Identificamos métricas saudáveis que não comprometem a privacidade do jogador, agregadas pelo Play Games de forma idempotente:

| Evento | Propriedade | Tipo | Agregação | Descrição |
| --- | --- | --- | --- | --- |
| `match_completed` | `game_id` | String | COUNT | Número de partidas jogadas. |
| `match_won` | `game_id` | String | COUNT | Número de vitórias do jogador. |
| `item_collected` | `item_id` | String | SUM | Fichas e peças raras colecionadas. |
| `quest_finished` | `type` (daily/weekly) | String | COUNT | Número de quests concluídas. |

---
*Estes dados alimentarão internamente (via API do Sidekick) recomendações de "Dicas do Gemini" e poderão ser comparados anonimamente com outros jogadores.*
