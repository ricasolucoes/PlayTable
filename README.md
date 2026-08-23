# PlayTable

Bem-vindo ao repositório do **PlayTable** — um aplicativo unificado, gratuito, open source, internacionalizado (i18n) e 100% livre de anúncios que reúne uma coleção de **16 minijogos clássicos de tabuleiro e cartas** em uma experiência polida para dispositivos móveis e desktop (Godot 4.3 Engine).

---

## 🛡️ Nossos Princípios Fundamentais

1. **100% Gratuito & Open Source:** Todo o código sob licença MIT. Livre para estudo, modificação e distribuição independente (F-Droid, GitHub Releases).
2. **Offline First:** Nenhuma dependência de servidores de internet para jogar. Toda a jogabilidade acontece localmente no dispositivo.
3. **Internacionalização Nativa (i18n):** Suporte nativo a múltiplos idiomas (Português, Inglês, Espanhol) com troca dinâmica em tempo de execução.
4. **Sem Anúncios (Zero Ads):** Zero propagandas, sem banners, sem intersticiais e sem SDKs de rastreamento.
5. **Sem Sistema de Contas/Login:** Sem telemetria predatória e sem cadastro. Configurações e estatísticas salvas 100% localmente.
6. **Sem Compras no App (Zero IAP):** Todos os 16 jogos liberados nativamente, sem paywalls ou microtransações.

---

## 🎮 Catálogo dos 16 Jogos Implementados

### 🎲 Jogos de Tabuleiro (11 Jogos)
| Jogo | Complexidade | Destaques | Localização |
| :--- | :--- | :--- | :--- |
| **Jogo da Velha** | Muito Baixa | Grade 3x3, IA Minimax, placar e reinício | [`games/jogo_da_velha/`](games/jogo_da_velha/) |
| **Damas** | Baixa | Tabuleiro 8x8, capturas múltiplas, coroação de damas 👑 e IA | [`games/damas/`](games/damas/) |
| **Batalha Naval** | Baixa | Grids 10x10 (Radar e Frota), 5 navios, IA Hunt & Target | [`games/batalha_naval/`](games/batalha_naval/) |
| **Quatro em Linha** | Baixa | Grade 7x6, animação de queda, IA e placar | [`games/quatro_em_linha/`](games/quatro_em_linha/) |
| **Solitário (Resta Um)** | Baixa/Média | Cruz de 33 furos, 32 pinos, botão Desfazer (Undo) e avaliação | [`games/solitario/`](games/solitario/) |
| **Campo Minado** | Baixa/Média | 9x9 com 10 minas, 1º clique seguro, flood-fill, modo bandeira e timer | [`games/campo_minado/`](games/campo_minado/) |
| **Dominó** | Média | 28 pedras (duplo-6), compra do dorme, encaixe de pontas e IA | [`games/domino/`](games/domino/) |
| **Ludo Simplificado** | Média | 4 jogadores (Humano + 3 IAs), dado 1-6 animado e capturas | [`games/ludo/`](games/ludo/) |
| **Reversi (Othello)** | Média | Tabuleiro 8x8 verde, viradas em 8 direções e matriz posicional | [`games/reversi/`](games/reversi/) |
| **Mancala (Kalah)** | Baixa/Média | 12 covas + 2 depósitos, semeadura anti-horária, turnos extras e IA | [`games/mancala/`](games/mancala/) |
| **Senet Egípcio** | Baixa/Média | Trilha serpenteante 3x10, varetas de lançamento (1-5) e casas sagradas | [`games/senet/`](games/senet/) |

### 🃏 Jogos de Cartas (5 Jogos)
| Jogo | Complexidade | Destaques | Localização |
| :--- | :--- | :--- | :--- |
| **Paciência Klondike** | Média | 7 colunas no tableau, 4 fundações, monte/descarte e auto-mover | [`games/paciencia/`](games/paciencia/) |
| **Jogo da Memória** | Baixa | Cartas com emojis, animação 3D de flip e contador de jogadas | [`games/memoria/`](games/memoria/) |
| **21 (Blackjack)** | Baixa | Dealer com parada no 17, fichas/apostas e botão Dobrar | [`games/blackjack/`](games/blackjack/) |
| **Cartas das Cores (Uno)** | Média | 4 cores, cartas de ação (Pular, Inverter, +2, +4, Curinga) e IA | [`games/unolike/`](games/unolike/) |
| **Poker (Video Poker)** | Média | 5 cartas, seleção de MANTER (HOLD), troca e tabela de pagamentos | [`games/poker/`](games/poker/) |

---

## 🏗️ Arquitetura do Repositório

```text
/
├── core/                  # Sistemas comuns vitais do aplicativo
│   ├── i18n/              # LocaleManager e catálogo de traduções (translations.csv)
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
- **Configuração de Export:** Versionada em `export_presets.cfg` (preset `Android`, arquiteturas `arm64-v8a` + `armeabi-v7a`).
  O preset é propositalmente **não assinado** (`package/signed=false`) e não contém keystore, alias nem senha —
  isso permite builds reproduzíveis por terceiros (F-Droid). A assinatura é feita à parte pelo `build_apk.sh`,
  usando uma keystore mantida **fora do repositório** (`KEYSTORE_PATH`, padrão `~/keys/playtable-release.keystore`)
  e a senha via variável de ambiente `KEYSTORE_PASSWORD`.

---

Feito com 💙 para jogadores e desenvolvedores de software livre.
