# PlayTable

Bem-vindo ao repositório do **PlayTable** — um aplicativo unificado, gratuito, open source, internacionalizado (i18n) e 100% livre de anúncios que reúne uma coleção de **18 minijogos clássicos de tabuleiro e cartas** em uma experiência polida para dispositivos móveis e desktop (Godot 4.7.2 Engine).

---

## 🛡️ Nossos Princípios Fundamentais

1. **100% Gratuito & Open Source:** Todo o código sob licença MIT. Livre para estudo, modificação e distribuição independente (F-Droid, GitHub Releases).
2. **Offline First:** Nenhuma dependência de servidores de internet para jogar. Toda a jogabilidade acontece localmente no dispositivo.
3. **Internacionalização Nativa (i18n):** Suporte nativo a múltiplos idiomas (Português, Inglês, Espanhol) com troca dinâmica em tempo de execução.
4. **Sem Anúncios (Zero Ads):** Zero propagandas, sem banners, sem intersticiais e sem SDKs de rastreamento.
5. **Sem Sistema de Contas/Login:** Sem telemetria predatória e sem cadastro. Configurações e estatísticas salvas 100% localmente.
6. **Sem Compras no App (Zero IAP):** Todos os 18 jogos liberados nativamente, sem paywalls ou microtransações.

---

## 🎮 Catálogo dos 18 Jogos Implementados

### 🎲 Jogos de Tabuleiro (13 Jogos)
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
| **Torres de Hanói** | Baixa | 3 a 8 discos 3D, física em arco, solver automático, undo e gamificação | [`games/hanoi/`](games/hanoi/) |
| **Jogo de Nim** | Baixa | 3 a 5 pilhas de gemas 3D, IA Teorema de Bouton, Normal e Misère | [`games/nim/`](games/nim/) |

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
├── games/                 # Módulos dos 16 jogos isolados (Regras, IAs, Lógicas únicas)
└── tests/                 # Suíte GUT rodando contra o GDScript de produção
    ├── gdscript/unit/     # Um arquivo por jogo, mais núcleo e i18n
    └── gdscript/integration/  # Catálogo: instancia as 16 cenas de verdade
```

---

## 🧪 Testes

A suíte roda o GDScript real, headless, sem abrir janela:

```bash
tests/run_gut.sh                                   # suíte completa
tests/run_gut.sh -gselect=reversi                  # só um arquivo
GODOT_BIN=/caminho/para/godot tests/run_gut.sh     # apontando a engine
```

O script exige a engine de `.godot-version` (hoje 4.7.2-stable), exata: quem
resolve é `scripts/godot_bin.sh`, o mesmo que os scripts de build usam. Ele
procura no `PATH`, em `~/Dev/godot-<versao>` e em `/Applications`,
instala o [GUT](https://github.com/bitwes/Gut) em `addons/gut` na primeira
execução (o addon não é versionado) e reimporta os recursos quando a engine
ou a versão do GUT mudam. O mesmo comando roda no GitHub Actions a cada push
e pull request — veja `.github/workflows/ci.yml`.

---

## 🛠️ Tecnologias e Compilação

- **Engine Principal:** Godot 4.7.2 (Mobile/Desktop) com suporte a exportação Android (`build_apk.sh`), iOS, Web e Desktop.
- **Configuração de Export:** Versionada em `export_presets.cfg` (preset `Android`, arquiteturas `arm64-v8a` + `armeabi-v7a`).
  O preset é propositalmente **não assinado** (`package/signed=false`) e não contém keystore, alias nem senha —
  isso permite builds reproduzíveis por terceiros (F-Droid). A assinatura é feita à parte pelo `build_apk.sh`,
  usando uma keystore mantida **fora do repositório** (`KEYSTORE_PATH`, padrão `~/keys/playtable-release.keystore`)
  e a senha via variável de ambiente `KEYSTORE_PASSWORD`.

---

Feito com 💙 para jogadores e desenvolvedores de software livre.
