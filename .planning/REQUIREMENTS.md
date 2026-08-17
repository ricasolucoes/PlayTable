# REQUIREMENTS

## Phase 1 (Tabuleiro Core)

### Phase 1.1: Estrutura Core e UI Base
- **Requirement 1**: O projeto deve compilar nativamente como App usando a engine escolhida.
- **Requirement 2**: O Menu Principal deve listar 3 categorias (Tabuleiro, Cartas, Configurações).
- **Requirement 3**: Implementar um wrapper de dados locais (SharedPreferences/LocalStorage) para configs.

### Phase 1.2: Quatro em Linha
- **Requirement 1**: Tabuleiro de 7 colunas por 6 linhas.
- **Requirement 2**: Física/Animação simplificada de queda (do topo para a posição mais baixa livre).
- **Requirement 3**: Verificação recursiva nas 4 direções após cada jogada.
- **Requirement 4**: Um oponente IA que jogue em colunas aleatórias não-cheias.

### Phase 1.3: Reversi
- **Requirement 1**: Tabuleiro 8x8 verde. Peças pretas e brancas reversíveis.
- **Requirement 2**: Regra restrita: só pode jogar se capturar pelo menos uma peça adversária.
- **Requirement 3**: IA com algoritmo minimax simples para modos "Normal" e "Difícil".

### Phase 1.4: Batalha Naval
- **Requirement 1**: 2 Tabuleiros 10x10.
- **Requirement 2**: Frotas de tamanhos (5, 4, 3, 3, 2).
- **Requirement 3**: IA oponente capaz de focar nos alvos após primeiro "hit".
