# Jogos de Mesa Offline

Bem-vindo ao repositório do **Jogos de Mesa Offline** — um aplicativo unificado, gratuito, open source e 100% livre de anúncios que reúne uma coleção de **16 minijogos clássicos de tabuleiro e cartas** em uma experiência polida para dispositivos móveis e desktop (Godot 4.3 Engine).

---

## 🛡️ Nossos Princípios Fundamentais

1. **100% Gratuito & Open Source:** Todo o código sob licença MIT. Livre para estudo, modificação e distribuição independente (F-Droid, GitHub Releases).
2. **Offline First:** Nenhuma dependência de servidores de internet para jogar. Toda a jogabilidade acontece localmente no dispositivo.
3. **Sem Anúncios (Zero Ads):** Zero propagandas, sem banners, sem intersticiais e sem SDKs de rastreamento.
4. **Sem Sistema de Contas/Login:** Sem telemetria predatória e sem cadastro. Configurações e estatísticas salvas 100% localmente.
5. **Sem Compras no App (Zero IAP):** Todos os 16 jogos liberados nativamente, sem paywalls ou microtransações.

---

## 🎮 Catálogo dos 16 Jogos Implementados

### 🎲 Jogos de Tabuleiro (11 Jogos)
| Jogo | Complexidade | Destaques | Localização |
| :--- | :--- | :--- | :--- |
| **Jogo da Velha** | Muito Baixa | Grade 3x3, IA Minimax, placar e reinício | [`games/jogo_da_velha/`](file:///Users/sierra/Dev/Jogos/games/jogo_da_velha/) |
| **Damas** | Baixa | Tabuleiro 8x8, capturas múltiplas, coroação de damas 👑 e IA | [`games/damas/`](file:///Users/sierra/Dev/Jogos/games/damas/) |
| **Batalha Naval** | Baixa | Grids 10x10 (Radar e Frota), 5 navios, IA Hunt & Target | [`games/batalha_naval/`](file:///Users/sierra/Dev/Jogos/games/batalha_naval/) |
| **Quatro em Linha** | Baixa | Grade 7x6, animação de queda, IA e placar | [`games/quatro_em_linha/`](file:///Users/sierra/Dev/Jogos/games/quatro_em_linha/) |
| **Solitário (Resta Um)** | Baixa/Média | Cruz de 33 furos, 32 pinos, botão Desfazer (Undo) e avaliação | [`games/solitario/`](file:///Users/sierra/Dev/Jogos/games/solitario/) |
| **Campo Minado** | Baixa/Média | 9x9 com 10 minas, 1º clique seguro, flood-fill, modo bandeira e timer | [`games/campo_minado/`](file:///Users/sierra/Dev/Jogos/games/campo_minado/) |
| **Dominó** | Média | 28 pedras (duplo-6), compra do dorme, encaixe de pontas e IA | [`games/domino/`](file:///Users/sierra/Dev/Jogos/games/domino/) |
| **Ludo Simplificado** | Média | 4 jogadores (Humano + 3 IAs), dado 1-6 animado e capturas | [`games/ludo/`](file:///Users/sierra/Dev/Jogos/games/ludo/) |
| **Reversi (Othello)** | Média | Tabuleiro 8x8 verde, viradas em 8 direções e matriz posicional | [`games/reversi/`](file:///Users/sierra/Dev/Jogos/games/reversi/) |
| **Mancala (Kalah)** | Baixa/Média | 12 covas + 2 depósitos, semeadura anti-horária, turnos extras e IA | [`games/mancala/`](file:///Users/sierra/Dev/Jogos/games/mancala/) |
| **Senet Egípcio** | Baixa/Média | Trilha serpenteante 3x10, varetas de lançamento (1-5) e casas sagradas | [`games/senet/`](file:///Users/sierra/Dev/Jogos/games/senet/) |

### 🃏 Jogos de Cartas (5 Jogos)
| Jogo | Complexidade | Destaques | Localização |
| :--- | :--- | :--- | :--- |
| **Paciência Klondike** | Média | 7 colunas no tableau, 4 fundações, monte/descarte e auto-mover | [`games/paciencia/`](file:///Users/sierra/Dev/Jogos/games/paciencia/) |
| **Jogo da Memória** | Baixa | Cartas com emojis, animação 3D de flip e contador de jogadas | [`games/memoria/`](file:///Users/sierra/Dev/Jogos/games/memoria/) |
| **21 (Blackjack)** | Baixa | Dealer com parada no 17, fichas/apostas e botão Dobrar | [`games/blackjack/`](file:///Users/sierra/Dev/Jogos/games/blackjack/) |
| **Cartas das Cores (Uno)** | Média | 4 cores, cartas de ação (Pular, Inverter, +2, +4, Curinga) e IA | [`games/unolike/`](file:///Users/sierra/Dev/Jogos/games/unolike/) |
| **Poker (Video Poker)** | Média | 5 cartas, seleção de MANTER (HOLD), troca e tabela de pagamentos | [`games/poker/`](file:///Users/sierra/Dev/Jogos/games/poker/) |

---

## 🏗️ Arquitetura do Repositório

```text
/
├── core/                  # Sistemas comuns vitais do aplicativo
│   ├── telas/             # MainMenu, MenuTabuleiro (11 jogos) e MenuCartas (5 jogos)
│   ├── navegacao/         # SceneManager: Transições suaves entre telas/cenas
│   ├── configs/           # Temas (Claro/Escuro), volume de sons, etc.
│   └── save/              # SaveManager: Armazenamento e persistência local JSON
├── shared/                # Componentes visuais e lógica reaproveitável
│   ├── pecas/             # Componentes de peões e peças
│   └── theme/             # Tema global (MainTheme.tres)
└── games/                 # Módulos dos 16 jogos isolados (Regras, IAs, Lógicas únicas)
```

---

## 🛠️ Tecnologias e Compilação

- **Engine Principal:** Godot 4.3 (Mobile/Desktop) com suporte a exportação Android (`build_apk.sh`), iOS, Web e Desktop.
- **Configuração de Export:** Parametrizada no `export_presets.cfg` com assinatura habilitada.

---

Feito com 💙 para jogadores e desenvolvedores de software livre.
