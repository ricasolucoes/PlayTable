# ROADMAP

## Coleção Completa de Jogos Offline (19 Jogos)

### 🎲 Jogos de Tabuleiro (14 Jogos)
- [x] **1. Jogo da Velha (Tic-Tac-Toe)**: Grade 3x3, IA tática, placar de vitórias/empates e reinício rápido (`games/jogo_da_velha/`).
- [x] **2. Damas (Checkers)**: Tabuleiro 8x8, movimentos simples, damas coroadas 👑, capturas múltiplas e IA (`games/damas/`).
- [x] **3. Batalha Naval (Battleship)**: Grids 10x10 (Radar e Frota), 5 navios, IA Hunt & Target com busca em cruz (`games/batalha_naval/`).
- [x] **4. Quatro em Linha (Connect Four)**: Grade 7x6, física de queda, IA e placar de vitórias (`games/quatro_em_linha/`).
- [x] **5. Solitário / Resta Um (Peg Solitaire)**: Cruz de 33 posições, saltos válidos, botão Desfazer (Undo) e vitória com 1 pino no centro (`games/solitario/`).
- [x] **6. Campo Minado (Minesweeper)**: Grade 9x9 com 10 minas, primeiro clique seguro, flood-fill de zeros, alternador de bandeiras e timer (`games/campo_minado/`).
- [x] **7. Dominó (Dominoes)**: Conjunto de 28 pedras (duplo-6), compra do dorme, jogadas nas pontas abertas e desempate por contagem de pontos (`games/domino/`).
- [x] **8. Ludo Simplificado**: 4 jogadores (Jogador + 3 IAs), dado 1-6 animado, saída de base com 6, capturas na pista e corrida ao centro (`games/ludo/`).
- [x] **9. Reversi / Othello**: Tabuleiro 8x8 verde, virada de discos em 8 direções, matriz de peso posicional e contagem de peças (`games/reversi/`).
- [x] **10. Mancala (Kalah)**: 12 covas e 2 depósitos, semeadura anti-horária, turnos extras, capturas opostas e IA inteligente (`games/mancala/`).
- [x] **11. Senet (Jogo Egípcio Antigo)**: Trilha serpenteante 3x10 (30 casas), 5 peças cada, varetas de lançamento (1-5), casas sagradas e remoção de peças (`games/senet/`).
- [x] **12. Torres de Hanói (Tower of Hanoi)**: 3 a 8 discos 3D, movimentação parabólica em arco por tweens, solver automático demonstrativo, histórico de desfazer e gamificação (`games/hanoi/`).
- [x] **13. Jogo de Nim (Nim Game 3D)**: 3 a 5 pilhas de gemas 3D em nogueira e ouro, IA com Teorema de Bouton (Nim-Sum), modos Normal e Misère (Marienbad), descarte em arco e gamificação (`games/nim/`).
- [x] **14. Gamão 3D (Backgammon)**: 24 pontas triangulares entalhadas, 30 peças em marfim/obsidiana, dados 3D rolantes, barra de captura, bear-off, Pip Count, IA tática e gamificação (`games/gamao/`).

---

### 🃏 Jogos de Cartas (5 Jogos)
- [x] **15. Paciência Klondike (Klondike Solitaire)**: 7 colunas no tableau, 4 fundações por naipe (A a K), monte de compras e descarte, auto-completar e pontuação (`games/paciencia/`).
- [x] **16. Jogo da Memória**: Cartas com emojis, animação de flip, contador de jogadas e pares (`games/memoria/`).
- [x] **17. 21 / Blackjack**: Baralho 52 cartas, dealer para no 17, sistema de fichas/apostas e botão Dobrar (Double Down) (`games/blackjack/`).
- [x] **18. Uno-like (Cartas das Cores)**: Baralho com 4 cores + cartas de ação (Pular, Inverter, +2, Curinga, +4), seletor de cor e IA oponente (`games/unolike/`).
- [x] **19. Poker Simplificado (Video Poker / 5-Card Draw)**: Avaliador de mãos de poker oficiais, seleção de cartas para MANTER (HOLD), troca de cartas e tabela de pagamentos (`games/poker/`).

---

## Estrutura Core e Menus
- [x] **Menu Principal**: Navegação para Tabuleiro (14 jogos), Cartas (5 jogos) e Configurações com alternância de tema Claro/Escuro.
- [x] **Menu Tabuleiro**: Grade com navegação direta para os 14 jogos de tabuleiro.
- [x] **Menu Cartas**: Grade com navegação direta para os 5 jogos de cartas.
- [x] **Build & Android**: Export preset configurado e script de build (`build_apk.sh`).
