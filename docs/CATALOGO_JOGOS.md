# 🎮 Catálogo Geral de Jogos e Estágios

Este documento cataloga todos os jogos potenciais do ecossistema **Jogos de Mesa Offline**, incluindo especificações de regras, stack recomendada, complexidade de implementação e o **estágio atual de desenvolvimento** de cada um.

---

## 🏆 1. As Melhores Recomendações (Foco Inicial & Agregador)

| Jogo | Tipo | Complexidade | Stack Recomendada | Estágio Atual | Arquivos / Localização |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Quatro em Linha** | Tabuleiro | Baixa | Godot | ✅ **Implementado** | [`games/quatro_em_linha/`](file:///Users/sierra/Dev/Jogos/games/quatro_em_linha/) |
| **Batalha Naval** | Tabuleiro | Média-Baixa | Godot | ✅ **Implementado** | [`games/batalha_naval/`](file:///Users/sierra/Dev/Jogos/games/batalha_naval/) |
| **Reversi (Othello)** | Tabuleiro | Média | Godot | 🟡 **Em Estruturação** | [`games/reversi/`](file:///Users/sierra/Dev/Jogos/games/reversi/) |
| **Dominó** | Tabuleiro/Mesa | Média | Flutter / Godot | 📋 **Planejado** | `games/domino/` |
| **Solitário (Paciência)** | Cartas | Média | Flutter | 📋 **Planejado** | `games/solitario/` |

### Detalhamento das Recomendações:

#### 1. Quatro em Linha
- **Mecânica:** Grade 7×6, peças caindo verticalmente, verificação de 4 peças alinhadas (horizontal, vertical e diagonais).
- **Recursos:** Modo 2 jogadores local (mesmo aparelho) e IA oponente com seleção de jogadas viáveis.
- **Estágio:** ✅ Totalmente implementado com física visual via Tweens, checagem de vitória e oponente IA.

#### 2. Batalha Naval
- **Mecânica:** Dois tabuleiros 10×10 (Radar de ataque e Frota aliada), 5 navios (Porta-Aviões 5, Encouraçado 4, Cruzador 3, Submarino 3, Destroyer 2).
- **Recursos:** Posicionamento automático/manual, detecção de água, acerto e afundamento. IA com algoritmo *Hunt & Target* (busca em cruz ao acertar).
- **Estágio:** ✅ Totalmente implementado com alternância de abas Radar/Frota, IA inteligente e feedback visual.

#### 3. Reversi (Othello)
- **Mecânica:** Tabuleiro 8×8, peças bicolores (Preto e Branco). Captura obrigatória de linhas inimigas prensadas entre duas peças da cor da vez.
- **Recursos Previstos:**
  - *Fácil:* Jogadas aleatórias válidas.
  - *Normal:* Priorização de cantos e bordas, evitando quadrados adjacentes perigosos (X-squares e C-squares).
  - *Difícil:* Algoritmo Minimax com poda Alfa-Beta (profundidade 4-6).
- **Estágio:** 🟡 Pasta e integração no menu criadas; lógica minimax e UI 8x8 a serem integradas.

#### 4. Dominó
- **Mecânica:** 28 pedras (duplo 6). Variações: Clássico individual, em Duplas (2v2) e 5 Pontos (Ponta).
- **Desafios:** Regras brasileiras de compra, fechamento ("tranca"), contagem de pontos e formação de duplas.
- **Stack Ideal:** Flutter (layout 2D com widgets limpos) ou Godot (para arrasto suave de pedras).
- **Estágio:** 📋 Planejado para a Fase de Jogos de Mesa Multijogador Local.

#### 5. Solitário (Klondike / Multi-modos)
- **Mecânica:** Movimentação em colunas alternando cores e ordem decrescente; 4 fundações por naipe em ordem crescente (Ás ao Rei).
- **Desafios:** Validação precisa de pilhas, desfazer jogada (*undo*), detecção automática de vitória.
- **Referência Open Source:** [CardsWithCats](https://github.com/dozingcat/CardsWithCats) e [The Deck](https://github.com/xajik/thedeck).
- **Estágio:** 📋 Planejado como destaque da categoria de cartas.

---

## 🃏 2. Jogos de Cartas Simples

| Jogo | Mecânica Resumida | Complexidade | Stack Ideal | Estágio Atual | Arquivos / Localização |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **21 / Blackjack Simplificado** | Comprar até se aproximar de 21 sem estourar. Dealer para em 17+. | Muito Baixa | Godot / Flutter | ✅ **Implementado** | [`games/blackjack/`](file:///Users/sierra/Dev/Jogos/games/blackjack/) |
| **Memória com Cartas** | Revelar 2 cartas por vez e encontrar todos os pares. | Muito Baixa | Godot / Flutter | ✅ **Implementado** | [`games/memoria/`](file:///Users/sierra/Dev/Jogos/games/memoria/) |
| **Maior Carta (High Card)** | Cada jogador revela uma carta; o maior valor vence. | Mínima | Flutter / Godot | 💡 **Backlog** | `games/maior_carta/` |
| **Guerra (War Card Game)** | Batalha de cartas com acúmulo em empates. | Baixa | Flutter / Godot | 💡 **Backlog** | `games/guerra/` |
| **Paciência Simples** | Ordenação direta de cartas por sequência. | Baixa | Flutter | 📋 **Planejado** | `games/paciencia_simples/` |
| **Golf Solitaire** | Remover cartas da mesa se forem ±1 da carta de descarte. | Baixa-Média | Flutter | 💡 **Backlog** | `games/golf_solitaire/` |
| **Pirâmide (Pyramid Solitaire)** | Remover pares de cartas cuja soma seja igual a 13 (K=13). | Baixa-Média | Flutter | 💡 **Backlog** | `games/piramide/` |
| **FreeCell Simplificado** | 8 colunas e 4 células livres de apoio temporário. | Média | Flutter | 💡 **Backlog** | `games/freecell/` |

---

## 🇧🇷 3. Jogos de Cartas com Potencial Comercial & Brasileiros

> [!NOTE]
> Para todos os jogos tradicionais (Truco, Buraco, Canastra, etc.), as regras tradicionais pertencem ao domínio público, mas todo o material artístico, sonoro, textos, layout e logotipos são 100% originais e livres de marcas de terceiros.

| Jogo | Descrição / Variações | Complexidade | Stack Ideal | Estágio Atual | Arquivos / Localização |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Solitário Multi-Modos** | Klondike, Spider (1 naipe), FreeCell, Golf e Pirâmide unificados. | Média-Alta | Flutter | 📋 **Planejado** | `games/solitario_hub/` |
| **Truco contra IA** | Regras Paulista e Mineiro, sinais da IA, blefes locais, sem apostas reais. | Média-Alta | Flutter / Godot | 💡 **Backlog Prioritário** | `games/truco/` |
| **Buraco Offline** | Canastras limpas e sujas, morto, batida com descarte. IA para duplas. | Alta | Flutter | 💡 **Backlog** | `games/buraco/` |
| **Canastra Offline** | Similar ao Buraco com contagem e regras tradicionais de pontuação. | Alta | Flutter | 💡 **Backlog** | `games/canastra/` |
| **Sueca** | Jogo de vazas em 4 jogadores (2 duplas), trunfo definido pelo corte. | Média | Flutter | 💡 **Backlog** | `games/sueca/` |
| **Escopa (de 15)** | Captura de cartas da mesa somando 15 pontos com a carta jogada. | Média | Flutter | 💡 **Backlog** | `games/escopa/` |
| **Cacheta (Pife / Pif-Paf)** | Formação de trincas e sequências com 9 ou 10 cartas e coringa. | Média-Alta | Flutter | 💡 **Backlog** | `games/cacheta/` |
| **Paciência com Desafios Diários** | Sementes diárias (*seeds*) geradas deterministicamente offline. | Média | Flutter | 💡 **Backlog** | `games/solitario_daily/` |
| **Jogo de Cartas BR Original** | Mecânica autoral criada especialmente para o projeto. | Média | Flutter / Godot | 💡 **Backlog** | `games/card_original/` |
| **Deck-Building Original** | Construção de baralho procedural solo com inimigos e relíquias. | Alta | Godot | 💡 **Backlog Futuro** | `games/deck_builder/` |

---

## 🎲 4. Jogos de Tabuleiro Clássicos e Lógicos

| Jogo | Especificação | Complexidade | Stack Ideal | Estágio Atual | Arquivos / Localização |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Jogo da Velha (Tic-Tac-Toe)** | Grade 3×3 clássica com efeitos visuais e IA. | Muito Baixa | Godot / Flutter | ✅ **Implementado** | [`games/jogo_da_velha/`](file:///Users/sierra/Dev/Jogos/games/jogo_da_velha/) |
| **Damas (Checkers)** | Tabuleiro 8×8, damas voadoras, capturas múltiplas obrigatórias, IA. | Média | Godot | ✅ **Implementado** | [`games/damas/`](file:///Users/sierra/Dev/Jogos/games/damas/) |
| **Mancala (Kalah)** | Semeadura em 12 cavidades + 2 kalahas com captura de sementes. | Baixa-Média | Godot / Flutter | 📋 **Planejado** | `games/mancala/` |
| **Campo Minado (Minesweeper)** | Grade com contagem de minas adjacentes, bandeiras e primeiro clique seguro. | Baixa-Média | Flutter / Godot | 📋 **Planejado** | `games/campo_minado/` |
| **Sudoku** | Grade 9×9 (subgrades 3×3) com gerador e validador de quebra-cabeças offline. | Baixa-Média | Flutter | 📋 **Planejado** | `games/sudoku/` |
| **Kakuro Simplificado** | Cruzadinha numérica com somas por linha e coluna sem repetir dígitos. | Média | Flutter | 💡 **Backlog** | `games/kakuro/` |
| **Nonogram (Picross)** | Pintura lógica em grade baseada em pistas numéricas nas bordas. | Média | Flutter | 💡 **Backlog** | `games/nonogram/` |
| **Ludo / Pachisi** | 4 peões por jogador, dado virtual, percurso em cruz e captura de peões. | Média | Godot | 💡 **Backlog** | `games/ludo/` |
| **Gamão (Backgammon)** | Movimentação em 24 pontos triangulares, barra de captura e dados. | Alta | Godot | 💡 **Backlog** | `games/gamao/` |
| **Hex** | Tabuleiro hexagonal de conexão entre lados opostos; sem empates. | Média | Godot | 💡 **Backlog** | `games/hex/` |
| **Nim** | Retirada matemática de peças de pilhas; IA perfeita baseada em Nim-sum. | Baixa | Flutter / Godot | 💡 **Backlog** | `games/nim/` |
| **Torres de Hanói** | Quebra-cabeça clássico de transferência de discos entre três pinos. | Muito Baixa | Godot / Flutter | 💡 **Backlog** | `games/hanoi/` |
| **Mahjong Solitaire** | Remoção de pares de peças livres idênticas em pilhas 3D/2D. | Média | Godot | 💡 **Backlog** | `games/mahjong/` |
| **Caça-Palavras** | Grade de letras com gerador de listas temáticas em português. | Baixa | Flutter | 💡 **Backlog** | `games/caca_palavras/` |
| **Jogo de Palavras em Tabuleiro** | Formação de palavras cruzadas em grade (estilo Scrabble offline). | Alta | Flutter | 💡 **Backlog** | `games/palavras_tabuleiro/` |
| **Banco Imobiliário Original** | Tabuleiro de compra e troca de propriedades com tema e artes autorais. | Alta | Godot | 💡 **Backlog Futuro** | `games/propriedades_original/` |

---

## 🚫 5. Jogos Evitados no Início (Descartados ou Adiados)

Estes jogos foram conscientemente deixados de fora do escopo inicial para garantir entregas rápidas, código limpo e foco offline:

1. **Xadrez:** IA avançada exige avaliação posicional complexa (Stockfish/Bitboards), grande árvore de busca e muitas regras especiais (roque, en passant, afogamento, repetição tripla).
2. **Go:** IA competitiva requer redes neurais/MCTS pesados e regras de território complexas.
3. **Jogos de Estratégia com Múltiplas Unidades (RTS/4X):** Alta complexidade gráfica, balanceamento pesado e alta demanda de CPU.
4. **Multiplayer Online:** Exigiria servidores dedicados, sincronização de rede, reconciliação de estado e sistemas de autenticação, violando os princípios *Offline-First* e *Zero Custos Operacionais*.

---

## 📈 Matriz Comparativa Geral

```mermaid
quadrantChart
    title Matriz de Complexidade vs Engajamento
    x-axis Baixa Complexidade --> Alta Complexidade
    y-axis Baixo Engajamento --> Alto Engajamento
    quadrant-1 Projetos Principais (Foco Futuro)
    quadrant-2 Vitórias Rápidas (Implementados / Próximos)
    quadrant-3 Jogos Secundários
    quadrant-4 Alta Complexidade (Adiar)
    "Quatro em Linha": [0.2, 0.75]
    "Batalha Naval": [0.35, 0.85]
    "Damas": [0.45, 0.8]
    "Jogo da Velha": [0.1, 0.5]
    "Memória": [0.15, 0.55]
    "Blackjack (21)": [0.2, 0.65]
    "Reversi": [0.4, 0.78]
    "Dominó": [0.5, 0.9]
    "Solitário": [0.55, 0.95]
    "Truco IA": [0.75, 0.98]
    "Buraco": [0.8, 0.92]
    "Xadrez": [0.95, 0.7]
    "Multiplayer Online": [0.98, 0.6]
```
