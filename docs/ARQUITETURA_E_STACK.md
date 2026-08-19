# 🏗️ Arquitetura do Repositório e Guia de Stacks

Este documento apresenta a estrutura modular do projeto **Jogos de Mesa Offline**, a separação de responsabilidades no código e as diretrizes para escolha de tecnologia (Godot vs Flutter).

---

## 🏛️ Estrutura Modular

O projeto foi projetado para permitir que múltiplos jogos convivam de forma harmônica e organizada, sem acoplamento entre regras de negócio:

```text
Jogos/
├── core/                  # Módulos fundamentais do sistema operacional do aplicativo
│   ├── configs/           # Configurações globais (áudio, vibração, tema)
│   ├── estatisticas/      # Persistência de histórico de partidas, vitórias e derrotas
│   ├── navegacao/         # SceneManager: orquestrador de transição de cenas e telas
│   ├── save/              # SaveManager: wrapper de persistência local (ConfigFile / JSON)
│   └── telas/             # Menu Principal e Menus de Categorias (Tabuleiro, Cartas)
│
├── shared/                # Componentes visuais e de UI reaproveitáveis
│   ├── pecas/             # Instâncias genéricas de peças (discos, pinos, fichas)
│   ├── tabuleiro/         # Componentes base de grades e botões de tabuleiro
│   ├── theme/             # Tema visual comum, tipografia, paletas e estilos
│   └── ui/                # Botões de controle (Voltar, Reiniciar), modais e diálogos
│
└── games/                 # Módulos isolados de cada jogo (Regras, IAs, Lógicas únicas)
    ├── batalha_naval/     # BattleshipGame: Grids 10x10, frotas e IA Hunt & Target
    ├── blackjack/         # BlackjackGame: Lógica de 21, baralho e dealer
    ├── damas/             # CheckersGame: Movimentos diagonais, damas e capturas múltiplas
    ├── jogo_da_velha/     # TicTacToeGame: Grade 3x3 rápida e animações
    ├── memoria/           # MemoryGame: Virada de cartas 3D e pares de emojis
    ├── quatro_em_linha/   # ConnectFourGame: Grid 7x6, física de gravidade e IA
    └── reversi/           # ReversiGame: Lógica de virada de peças e IA Minimax
```

---

## ⚖️ Comparação e Recomendação de Stacks

### 1. Godot Engine (Godot 4.x - GDScript / C#)

**Distribuição & Licença:** Licença MIT, compilação nativa para Android, iOS (Xcode), Web, macOS, Linux e Windows.

#### Quando escolher Godot:
- **Animações e Efeitos Visuais:** Jogos com física leve (peças caindo com bounce), efeitos de partículas ou animações complexas entre nós.
- **Interações de Mesa e Tabuleiro Dinâmico:** Manipulação fluida de peças, zoom no tabuleiro, rotação ou perspectivas isométricas/3D.
- **Cartas Arrastáveis e Interativas:** Controle preciso de drag-and-drop com colisores 2D e curvas de animação (*Tweens*).
- **Áudio e Efeitos Sonoros:** Controle avançado de canais de áudio (*buses*), pitch randômico e efeitos espaciais.
- **Jogos Recomendados para Godot:**
  - *Quatro em Linha*
  - *Batalha Naval*
  - *Reversi*
  - *Damas*
  - *Ludo*
  - *Gamão*
  - *Mahjong Solitaire*

---

### 2. Flutter (Dart)

**Distribuição & Licença:** Licença BSD-3-Clause, compilação multiplataforma com rendering nativo Impeller/Skia.

#### Quando escolher Flutter:
- **Interface Predominantemente 2D / Formulários:** Telas com muitos menus, tabelas de estatísticas, listas e configurações textuais.
- **Jogos Baseados em Grids Lógicas:** Jogos onde o estado é essencialmente matemático e pode ser renderizado com `CustomPainter` ou árvore de `Widgets`.
- **Cartas e Menus em Widget Tree:** Manipulação de baralhos utilizando bibliotecas conhecidas da comunidade.
- **Integração com Armazenamento Local:** Fácil persistência com `shared_preferences`, `sqflite` ou `hive`.
- **Jogos Recomendados para Flutter:**
  - *Solitário (Klondike / FreeCell)*
  - *Dominó*
  - *Truco / Buraco / Canastra*
  - *Sudoku*
  - *Caça-Palavras e Jogos de Palavras*

---

## 🌟 Referências Open Source de Alta Qualidade

1. **CardsWithCats ([GitHub](https://github.com/dozingcat/CardsWithCats)):**
   - Implementação em Flutter de jogos de cartas clássicos (Hearts, Spades, etc.) para Android e iOS.
   - Excelente referência para animação de cartas, IAs determinísticas e gerenciamento de estado sem servidores.

2. **The Deck ([GitHub](https://github.com/xajik/thedeck)):**
   - Engine/agregador de jogos de cartas em Flutter, totalmente offline e focado em múltiplas plataformas.
   - Modelo ideal para modularizar regras de baralho e reutilizar o motor de renderização de cartas.

---

## 🔒 Princípio de Isolamento das Regras de Negócio

> [!IMPORTANT]
> **Regra de Ouro:** Componentes visuais (`shared/`) podem e devem ser compartilhados para manter a identidade do app coesa. No entanto, as **regras de negócio de cada jogo** (como a validação de capturas de Damas ou a contagem de pontos do Blackjack) **nunca devem ser forçadas em uma superclasse acoplada**. Cada pasta dentro de `games/` deve ser autocontida e independente.
