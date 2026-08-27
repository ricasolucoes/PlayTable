# Matriz de Conquistas (PlayTable)

> **Gerado por `tools/gen_achievement_matrix.py` a partir de
> `core/configs/achievements.json` e das traduções. Não editar à mão** — a
> versão anterior deste arquivo foi escrita à mão e derivou: prometia uma
> conquista de Xadrez, jogo que não existe no PlayTable, e não tinha nada de
> Gamão, Torre de Hanói, Nim nem Resta Um.

São **55 conquistas** cobrindo os 19 jogos, progressão, persistência, coleção e
segredos. O motor (`core/services/AchievementEngine.gd`) não conhece nenhuma
delas pelo nome: lê a regra, calcula o valor atual, compara com o alvo.

A coluna **Mapeada** diz se o id do Play Console já foi preenchido em
`core/configs/play_games_ids.json`. Enquanto estiver pendente, o
`PlayGamesManager` **não envia** aquela conquista — de propósito: um id
inventado é recusado em silêncio pelo servidor e a integração pareceria
funcionar sem entregar nada. Hoje: **55 pendentes de 55**.

O **Tipo Google Play** é o que criar no Console: `Incremental` para as que têm
alvo maior que 1 (o jogo envia o número absoluto de passos, não incrementos, para
a fila offline poder colapsar repetição sem perder contagem), `Oculta` para as
secretas e `Padrão` para o resto.

| ID | Nome | Categoria | Objetivo | Condição no motor | Tipo Google Play | XP | Mapeada |
| -- | ---- | --------- | -------- | ----------------- | ---------------- | -- | ------- |
| `ACH_FIRST_BLOOD` | Primeira vitória | Progressão | Vença sua primeira partida | `total_wins` >= 1 | Padrão | 100 | **pendente** |
| `ACH_WIN_10` | Aspirante | Habilidade | Vença 10 partidas | `total_wins` >= 10 | Incremental | 500 | **pendente** |
| `ACH_WIN_50` | Veterano | Habilidade | Vença 50 partidas | `total_wins` >= 50 | Incremental | 1500 | **pendente** |
| `ACH_WIN_100` | Lenda da Mesa | Habilidade | Vença 100 partidas | `total_wins` >= 100 | Incremental | 5000 | **pendente** |
| `ACH_VETERAN` | Veterano — 10 partidas | Habilidade | Jogue 25 partidas | `total_matches` >= 25 | Incremental | 400 | **pendente** |
| `ACH_LEVEL_5` | Aprendiz Dedicado | Progressão | Chegue ao nível 5 | nível do perfil >= 5 | Incremental | 300 | **pendente** |
| `ACH_LEVEL_10` | Nível 10 | Progressão | Chegue ao nível 10 | nível do perfil >= 10 | Incremental | 1000 | **pendente** |
| `ACH_LEVEL_25` | Grão-Mestre | Progressão | Chegue ao nível 25 | nível do perfil >= 25 | Incremental | 2500 | **pendente** |
| `ACH_EXPLORER_1` | Curioso | Exploração | Jogue 3 jogos diferentes | 3 jogos diferentes | Incremental | 250 | **pendente** |
| `ACH_EXPLORER_5` | Andarilho | Exploração | Jogue 8 jogos diferentes | 8 jogos diferentes | Incremental | 500 | **pendente** |
| `ACH_EXPLORER_ALL` | Mestre da Mesa | Exploração | Jogue todos os 19 jogos | 19 jogos diferentes | Incremental | 1000 | **pendente** |
| `ACH_STREAK_3` | Fim de Semana | Persistência | Jogue 3 dias seguidos | sequência diária >= 3 | Incremental | 500 | **pendente** |
| `ACH_STREAK_7` | Semana Inteira | Persistência | Jogue 7 dias seguidos | sequência diária >= 7 | Incremental | 1500 | **pendente** |
| `ACH_STREAK_30` | Hábito Formado | Persistência | Jogue 30 dias seguidos | sequência diária >= 30 | Incremental | 5000 | **pendente** |
| `ACH_COMEBACK` | De volta ao jogo | Persistência | Volte depois de 14 dias longe | evento `comeback` | Padrão | 1000 | **pendente** |
| `ACH_QUESTS_10` | Cumpridor | Persistência | Conclua 10 missões | `quests_completed` >= 10 | Incremental | 800 | **pendente** |
| `ACH_MARATHON` | Maratona | Persistência | Jogue 10 partidas em um só dia | `matches_today` >= 10 | Incremental | 700 | **pendente** |
| `ACH_PERFECT_WIN` | Vitória Impecável | Segredos | Vença uma partida sem errar | evento `perfect` | Oculta | 2000 | **pendente** |
| `ACH_FAST_WIN` | Relâmpago | Habilidade | Vença em menos de 2 minutos | evento `fast_win` | Padrão | 1000 | **pendente** |
| `ACH_TIE_BREAKER` | Por um Triz | Segredos | Vença uma partida decidida na última jogada | evento `close_call` | Oculta | 800 | **pendente** |
| `ACH_LOSER_5` | Persistente | Segredos | Perca 5 partidas seguidas e continue | `loss_streak` >= 5 | Incremental | 100 | **pendente** |
| `ACH_NIGHT_OWL` | Coruja | Segredos | Vença depois da meia-noite | evento `night_owl` | Oculta | 300 | **pendente** |
| `ACH_EARLY_BIRD` | Madrugador | Segredos | Vença antes das 6 da manhã | evento `early_bird` | Oculta | 300 | **pendente** |
| `ACH_MULTIPLAYER_1` | Modo Sofá | Social | Jogue uma partida com outra pessoa no mesmo aparelho | evento `pass_play` | Padrão | 200 | **pendente** |
| `ACH_TICTACTOE_WIN` | Três em Linha | Tabuleiro | Vença no Jogo da Velha | 1 vitória em `jogo_da_velha` | Padrão | 200 | **pendente** |
| `ACH_CHECKERS_WIN` | Coroação | Tabuleiro | Vença nas Damas | 1 vitória em `damas` | Padrão | 300 | **pendente** |
| `ACH_CONNECT4_WIN` | Conectado | Tabuleiro | Vença no Quatro em Linha | 1 vitória em `quatro_em_linha` | Padrão | 300 | **pendente** |
| `ACH_DOMINO_WIN` | Batida Perfeita | Tabuleiro | Vença no Dominó | 1 vitória em `domino` | Padrão | 300 | **pendente** |
| `ACH_HANOI_WIN` | Torre Erguida | Tabuleiro | Complete uma Torre de Hanói | 1 vitória em `hanoi` | Padrão | 300 | **pendente** |
| `ACH_BATTLESHIP_WIN` | Almirante | Tabuleiro | Vença na Batalha Naval | 1 vitória em `batalha_naval` | Padrão | 400 | **pendente** |
| `ACH_LUDO_WIN` | Chegada Triunfal | Tabuleiro | Vença no Ludo | 1 vitória em `ludo` | Padrão | 400 | **pendente** |
| `ACH_MANCALA_WIN` | Semeador | Tabuleiro | Vença no Mancala | 1 vitória em `mancala` | Padrão | 400 | **pendente** |
| `ACH_NIM_WIN` | Contador de Palitos | Tabuleiro | Vença no Nim | 1 vitória em `nim` | Padrão | 400 | **pendente** |
| `ACH_PEG_WIN` | Resta Um | Tabuleiro | Termine o Resta Um com uma só esfera | 1 vitória em `solitario` | Padrão | 400 | **pendente** |
| `ACH_REVERSI_WIN` | Estrategista | Tabuleiro | Vença no Reversi | 1 vitória em `reversi` | Padrão | 500 | **pendente** |
| `ACH_MINESWEEPER_WIN` | Campo Limpo | Tabuleiro | Desarme um Campo Minado | 1 vitória em `campo_minado` | Padrão | 500 | **pendente** |
| `ACH_SENET_WIN` | Faraó | Tabuleiro | Vença no Senet | 1 vitória em `senet` | Padrão | 500 | **pendente** |
| `ACH_BACKGAMMON_WIN` | Duplo Seis | Tabuleiro | Vença no Gamão | 1 vitória em `gamao` | Padrão | 500 | **pendente** |
| `ACH_MEMORY_WIN` | Memória Fotográfica | Cartas | Complete o Jogo da Memória | 1 vitória em `memoria` | Padrão | 200 | **pendente** |
| `ACH_SOLITAIRE_WIN` | Paciência Recompensada | Cartas | Vença uma Paciência | 1 vitória em `paciencia` | Padrão | 300 | **pendente** |
| `ACH_UNO_WIN` | Última Carta | Cartas | Vença no jogo de cores e cartas | 1 vitória em `unolike` | Padrão | 300 | **pendente** |
| `ACH_BLACKJACK_WIN` | Vinte e Um | Cartas | Vença uma mão de Blackjack | 1 vitória em `blackjack` | Padrão | 400 | **pendente** |
| `ACH_POKER_WIN` | High Roller | Cartas | Vença uma mão premiada no Poker | 1 vitória em `poker` | Padrão | 500 | **pendente** |
| `ACH_POKER_ROYAL` | Royal Flush | Segredos | Feche um Royal Flush | evento `royal_flush` | Oculta | 10000 | **pendente** |
| `ACH_ITEMS_100` | Colecionador Amador | Coleção | Colete 100 peças | `total_items_collected` >= 100 | Incremental | 300 | **pendente** |
| `ACH_ITEMS_1000` | Colecionador Obcecado | Coleção | Colete 1000 peças | `total_items_collected` >= 1000 | Incremental | 2000 | **pendente** |
| `ACH_COLLECTOR_10` | Vitrine Cheia | Coleção | Desbloqueie 10 itens da coleção | `collection_items` >= 10 | Incremental | 600 | **pendente** |
| `ACH_CUSTOM_BOARD` | Tabuleiro Seu | Coleção | Troque o acabamento da mesa | evento `custom_board` | Padrão | 100 | **pendente** |
| `ACH_MASTERY_5` | Especialista | Habilidade | Chegue à maestria 5 em qualquer jogo | maestria >= 5 em qualquer jogo | Incremental | 1200 | **pendente** |
| `ACH_HANOI_PERFECT_3` | Mínimo Exato | Tabuleiro | Resolva a Torre de 3 discos no número ótimo de jogadas | evento `hanoi_perfect_3` | Padrão | 400 | **pendente** |
| `ACH_HANOI_5` | Cinco Andares | Tabuleiro | Resolva a Torre com 5 discos | evento `hanoi_5` | Padrão | 700 | **pendente** |
| `ACH_HANOI_MASTER` | Arquiteto de Brahma | Tabuleiro | Resolva a Torre com 7 discos | evento `hanoi_7` | Padrão | 1500 | **pendente** |
| `ACH_NIM_MISERE` | Misère | Tabuleiro | Vença um Nim misère no difícil | evento `nim_misere` | Padrão | 600 | **pendente** |
| `ACH_NIM_PYRAMID` | Pirâmide Desfeita | Tabuleiro | Vença o Nim no formato pirâmide | evento `nim_pyramid` | Padrão | 600 | **pendente** |
| `ACH_100_PERCENT` | Platina | Progressão | Desbloqueie todas as outras conquistas | todas as outras conquistas | Oculta | 20000 | **pendente** |
