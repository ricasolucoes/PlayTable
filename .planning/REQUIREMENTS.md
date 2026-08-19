# REQUIREMENTS

## Phase 1 (Jogos de Tabuleiro Core)

### Phase 1.1: Estrutura Core e UI Base
- **Requirement 1**: O projeto deve compilar nativamente como App usando a engine escolhida (Godot 4.3).
- **Requirement 2**: O Menu Principal deve listar categorias (Tabuleiro, Cartas, Configurações).
- **Requirement 3**: Implementar um wrapper de dados locais (`SaveManager`) para persistência de configs e estatísticas.

### Phase 1.2: Quatro em Linha
- **Requirement 1**: Tabuleiro de 7 colunas por 6 linhas.
- **Requirement 2**: Física/Animação de queda suave via Tweens.
- **Requirement 3**: Verificação vetorial de vitória nas 4 direções.
- **Requirement 4**: Oponente IA com jogadas válidas.

### Phase 1.3: Batalha Naval
- **Requirement 1**: Grids duplos 10x10 (Ataque e Defesa).
- **Requirement 2**: Frota de 5 navios (tamanhos 5, 4, 3, 3, 2).
- **Requirement 3**: IA oponente com lógica de caça em cruz (*Hunt & Target*).

### Phase 1.4: Damas (Checkers)
- **Requirement 1**: Tabuleiro 8x8 com casas escuras jogáveis.
- **Requirement 2**: Promoção a Dama na última linha e capturas múltiplas em cadeia.
- **Requirement 3**: IA oponente capaz de priorizar saltos de captura.

### Phase 1.5: Jogo da Velha (Tic-Tac-Toe)
- **Requirement 1**: Grade 3x3 com feedback tátil/visual instantâneo e IA básica.

### Phase 1.6: Reversi (Othello)
- **Requirement 1**: Tabuleiro 8x8 verde. Peças pretas e brancas reversíveis.
- **Requirement 2**: Regra restrita: só pode jogar se capturar pelo menos uma peça adversária.
- **Requirement 3**: IA com 3 níveis (Fácil: aleatório, Normal: cantos/bordas, Difícil: minimax com poda alfa-beta).

---

## Phase 2 (Jogos de Cartas e Lógica Casual)

### Phase 2.1: Blackjack (21 Simplificado)
- **Requirement 1**: Baralho de 52 cartas, valores numéricos e figuras (10), Ás flexível (1 ou 11).
- **Requirement 2**: Dealer com regra automática de parar em 17+.

### Phase 2.2: Jogo da Memória
- **Requirement 1**: 16 cartas (8 pares de emojis aleatórios).
- **Requirement 2**: Efeito visual de giro 3D e travamento durante animação de erro/acerto.

### Phase 2.3: Solitário (Klondike)
- **Requirement 1**: 7 colunas com cartas viradas/abertas, 4 fundações ordenadas por naipe e pilha de compra (1 ou 3 cartas).
- **Requirement 2**: Sistema de Desfazer (*Undo*) ilimitado local.

### Phase 2.4: Dominó
- **Requirement 1**: 28 pedras do duplo 6, lógica de ponta aberta para encaixes válidos e regras brasileiras de compra e tranca.
