# ROADMAP

## Phase 1: O Início (Jogos de Tabuleiro)

- [ ] **Phase 1.1: Estrutura Core e UI Base**
  - Definição da stack (Godot ou Flutter) no código.
  - Implementação de Menu Principal e navegação entre cenas/telas.
  - Sistema base de persistência (Save local).

- [ ] **Phase 1.2: Quatro em Linha**
  - Implementação do grid vertical 7x6.
  - Física/Animação de queda das peças.
  - Verificação de vitória (4 em linha).
  - Modo PvP local e contra IA básica.

- [ ] **Phase 1.3: Reversi**
  - Implementação de grid 8x8.
  - Regras de captura e limitação de movimentos válidos.
  - IA com níveis (Fácil, Normal, Difícil - Minimax).

- [ ] **Phase 1.4: Batalha Naval**
  - Sistema de dois grids ocultos.
  - Posicionamento manual e automático de frotas.
  - Turnos de ataque e indicação de acerto/água.
  - IA básica de oponente.

## Phase 2: Expansão Contínua

- [ ] **Phase 2.1: Novos Jogos de Tabuleiro**
  - Damas, Mancala, Jogo da Velha.
  
- [ ] **Phase 2.2: Integração de Jogos de Cartas**
  - Solitário (Klondike), Jogo da Memória, 21 (Blackjack simplificado).

- [ ] **Phase 2.3: Engajamento e Desafios**
  - Sistema de desafios diários offline.
  - Tela global de estatísticas e conquistas.

## Phase 3: Spin-Offs e Distribuição Especial

- [ ] **Phase 3.1: Publicação Independente**
  - Lançamentos no F-Droid e GitHub Releases.
  
- [ ] **Phase 3.2: Separação de Módulos Populares**
  - Se um jogo ganhar muita tração (ex: Solitário), dividi-lo em um app dedicado usando a mesma codebase base do `core` e `shared`.
