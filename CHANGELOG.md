# Release Notes

---

## [Unreleased](https://github.com/ricardosierra/PlayTable/compare/v0.3.0...develop)

### ✨ Novidades

- [x] **Suíte de testes que roda o GDScript de verdade** — 350 testes GUT em 20 arquivos, executados headless contra os `.gd` e os `.tscn` de produção. Um arquivo por jogo (`tests/gdscript/unit/`), mais núcleo, i18n e um teste de integração que instancia as 16 cenas de verdade
- [x] **CI no GitHub Actions** — `.github/workflows/ci.yml` roda a suíte em todo push e pull request, com Godot 4.6.3 e o addon GUT em cache, e publica o relatório JUnit como artefato
- [x] **`tests/run_gut.sh`** — runner local que acha um Godot 4.4+ no `PATH`, no repositório ou em `/Applications`, instala o GUT sob demanda e reimporta os recursos quando a engine ou o addon mudam

### 🐛 Correções

- [x] **Tweens soltos disparando sobre nós já liberados** — dez chamadas usavam `get_tree().create_tween()`, que cria o tween na SceneTree em vez de amarrá-lo ao nó animado. Ao trocar de cena, reiniciar a partida ou dar `queue_free` nas cartas do Jogo da Memória, o tween seguia rodando e chamava o callback sobre uma instância morta (*Trying to call a lambda with an invalid instance*). Trocadas por `Node.create_tween()`, que é o que o resto do projeto já usava
- [x] **Resta Um estava intransitável** — `PegSolitaireGame._execute_jump` lia `target_dict["jumped"]`, chave que `PegSolitaireRules.get_valid_moves_for_peg` nunca devolveu (as chaves são `from`, `over` e `land`). O acesso derrubava a função com *Invalid access to property or key* antes de qualquer `set_cell`: selecionar uma esfera funcionava, tocar no furo de destino não fazia absolutamente nada. Nenhuma partida podia ser jogada até o fim

### 🔧 Técnico

- [x] **Ciclo de vida dos 16 jogos concentrado em `shared/`** — o botão voltar tinha 14 cópias, o reiniciar 11 (mais 3 sob outro nome), o fim de partida 8 e a grade de toque 6. Nasceram `shared/BaseGame.gd` (navegação de volta, reinício, `game_over`, `finish_game()`, `set_status()`, `reveal_result_modal()`) e `shared/GridGame.gd` (`build_touch_grid()`, herdada pelos 6 jogos cujo tabuleiro é uma grade). Os 16 jogos e a tela de *placeholder* migraram **um por commit**, com a suíte verde em cada um: `_on_btn_back_pressed` foi de 14 para 1, `_on_btn_restart_pressed` de 11 para 1 e `_setup_touch_grid` de 6 para 0. `games/` perdeu 207 linhas e `shared/` ganhou 152, das quais 146 são as duas classes novas
- [x] **Nenhuma abstração forçada nos jogos de cartas** — o corte não é *tabuleiro × cartas* e sim *quem tem grade de células*: Mancala, Ludo e Dominó são de tabuleiro e herdam direto de `BaseGame`; Blackjack, Uno-like e Paciência são de cartas e compartilham voltar, reiniciar e fim de partida. O Poker é o caso-limite — video poker não tem fim de partida nem botão reiniciar, a rodada anda por um `game_phase` de três estados — e por isso herda **só a navegação**, deixando `finish_game()`, `btn_restart` e `_start_new_game()` intocados. Nenhuma bandeira ou condicional foi acrescentada a `BaseGame` para acomodar exceção
- [x] **A IA dos 4 jogos continua separada** — `get_best_move` aparece 4 vezes, mas são 4 algoritmos que só coincidem no nome: heurística fixa devolvendo `int` no Jogo da Velha, minimax com poda alfa-beta devolvendo `Vector2i` no Reversi, primeira jogada válida devolvendo `Dictionary` nas Damas e vencer/bloquear/aleatório sobre um `ConnectFourBoard` no Quatro em Linha. Uma assinatura comum exigiria um tipo de estado comum e um conceito de jogada comum, para quatro implementações que não se substituem. **Fica como está**
- [x] **Bandeiras de fim de partida unificadas** — `game_won` da Paciência era o `game_over` do jogo com outro nome (guardava os quatro tratadores de toque e nada mais) e virou a bandeira herdada: uma a menos, não uma a mais. No Blackjack, `_start_game()` passou a se chamar `_start_new_game()` — era a única das 11 cópias do botão reiniciar que chamava outro nome. E o botão voltar da tela de *placeholder*, 14ª cópia, virou o `menu_scene_path` que ela preenche a partir da chave `current_menu`
- [x] **18 testes novos para a camada compartilhada** — `tests/gdscript/unit/test_shared_lifecycle.gd` bate direto em `BaseGame` e `GridGame` (os dois nomes de cada botão caindo no mesmo método, `finish_game()` com e sem os nós opcionais, a mesa 3D comemorando só na vitória, e o tamanho, o callback, as casas desligadas e a remontagem da grade). Em `test_catalog.gd`, dois guardas pelo lado de fora: as 16 cenas instanciam como `BaseGame` apontando para o menu da própria categoria, e nenhum `.gd` de `games/` volta a declarar sua cópia do voltar, do reiniciar ou do `game_over`
- [x] **`docs/CICLO_DE_VIDA_DOS_JOGOS.md`** — o levantamento função a função contra o que `shared/` já oferecia, com a contagem antes e depois e o registro de que `GenericGame` nunca foi classe-base, apesar do nome: é a tela de "em breve" mostrada quando um `GameDefinition` tem `is_implemented = false`
- [x] **GUT 9.7.1 como framework** — roda por `-s addons/gut/gut_cmdln.gd`, sem janela e sem habilitar plugin, e sai com código 1 quando há falha. O addon não é versionado (11 MB de código de terceiros, 8,8 MB deles num único `.tscn` do painel do editor): `tests/install_gut.sh` busca a versão fixada sob demanda. A versão está amarrada à engine — o 9.7.x exige Godot 4.4+ e o 9.3.x é o último que roda na 4.3
- [x] **Os 7 arquivos Python de teste foram removidos** — `test_board_games.py`, `test_card_games.py`, `test_integration_simulations.py`, `test_core_systems.py`, `test_i18n.py`, `test_all_games_catalog.py` e `run_tests.py`. Eles reimplementavam as regras de cada jogo em Python e testavam a reimplementação; os 70 arquivos `.gd` que rodam no aplicativo não eram exercitados por nada. Os casos foram aproveitados como especificação, um jogo por vez, e cada migração apagou o equivalente Python
- [x] **`export_presets.cfg`** — passa a excluir `tests/*`, `addons/*` e `.gutconfig.json`, para o APK não carregar código de teste

**Achados registrados, ainda sem decisão:**

- [ ] **Regras duplicadas e código morto** — `TicTacToeRules.gd`, `ConnectFourRules.gd` e `MemoryRules.gd` não são referenciados por ninguém: as cenas têm a própria cópia das regras. `DominoGame` repete a orientação da pedra inline em dois lugares em vez de chamar `DominoRules.orient_tile_for_side`. Enquanto as duas versões existirem, os testes cobrem as duas — no Jogo da Velha, um teste compara as 6.561 posições possíveis para travar a divergência
- [ ] **IA do Uno joga com a cor fixa** — `UnoRules.pick_best_color_for_hand` implementa a heurística de maioria que o teste Python cobria, mas `UnoLikeGame` não a chama: ao jogar um curinga, a IA fixa `active_color` em azul (ou vermelho, no caminho de comprar-e-jogar)
- [ ] **`ConnectFourAI` promete minimax e não entrega** — o cabeçalho diz *"minimax with alpha-beta pruning"*; o código é vencer/bloquear/aleatório, sem poda e sem a preferência pela coluna central que o `ConnectFourRules` tem
- [ ] **Tabuleiro do Quatro em Linha desenhado de cabeça para baixo** — `ConnectFourGame._make_move` calcula `visual_row = (ROWS - 1) - row` apoiado num comentário que diz *"logic row 0 is bottom"*, mas `drop_piece` preenche do índice 5 para o 0, então a linha 0 é o topo. A primeira ficha de cada coluna é desenhada em cima e a pilha cresce para baixo
- [ ] **Nomes dos jogos nunca são traduzidos** — o `GameCatalog` aponta para chaves `GAME_DESC_*` que não existem no `translations.csv`, enquanto o CSV traz 16 chaves `GAME_*` com o nome de cada jogo que ninguém consome: `MenuTabuleiro` e `MenuCartas` montam o botão com `game.title`, texto fixo em português
- [ ] **`KlondikeRules.can_place_on_foundation` não confere o naipe na fundação vazia** — aceita qualquer ás em qualquer uma das quatro. Só não vira bug porque `KlondikeGame` confere `card.suit == req_suit` antes de chamar

## [v0.3.0 (2026-08-23)](https://github.com/ricardosierra/PlayTable/compare/v0.2.1...v0.3.0)

### 🎨 Melhorias

- [x] **APK 11 MB menor** — as 16 capturas de tela em `screenshots/` eram importadas pelo Godot e viajavam dentro do aplicativo, porque o preset usa `export_filter="all_resources"`; um `.gdignore` no diretório tira as imagens do pacote sem removê-las do repositório. De 63,5 MB para 52,4 MB

### 🔧 Técnico

- [x] **Migração para Godot 4.6** — a 4.3 não tem como ser compilada no buildserver do F-Droid: o Debian trixie de lá só oferece JDK 21 e 25, o Godot exige exatamente o 17 em todas as versões, e o Gradle 8.2 que a 4.3 carrega sequer roda em Java 21 (suporte veio no 8.5). A 4.6 traz Gradle 8.11.1 e AGP 8.6.1, que rodam em 21. Os 70 scripts e 27 cenas importaram e exportaram sem uma única alteração em `project.godot` ou `export_presets.cfg`
- [x] **Arquivos `.uid` versionados** — o Godot 4.4+ passou a identificar cada script por UID em vez de caminho; os 70 arquivos entram no versionamento, como a documentação do Godot exige, para que mover um script não quebre as referências


## [v0.2.1 (2026-08-22)](https://github.com/ricardosierra/PlayTable/compare/v0.2.0...v0.2.1)

### 🐛 Correções

- [x] **Autoloads ocultados por `class_name`** — `SceneManager`, `SaveManager`, `AudioManager` e `LocaleManager` declaravam uma classe global com o mesmo nome do singleton; no Godot 4.3 isso gerava `Class "X" hides an autoload singleton` e fazia 26 scripts (todos os menus e os 16 jogos) falharem ao carregar. Removida a linha `class_name` dos quatro autoloads
- [x] **Links quebrados na documentação** — os 16 links do catálogo no `README.md` apontavam para `file:///Users/...`; agora são relativos. Links do `CHANGELOG.md` migrados do GitLab privado para o GitHub
- [x] **`LICENSE`** — placeholder `[Developer Name]` substituído por `Ricardo Sierra`

### 🔧 Técnico

- [x] **`export_presets.cfg` completo e sem chaves** — o preset era um stub de ~17 chaves que o Godot 4.3 rejeitava (keystore parcialmente preenchida e `architecture/*` no singular, ignorado em favor de `architectures/*`). Regenerado com as 202 chaves de um preset real, sem nenhuma chave `keystore/*`, `package/signed=false`, `arm64-v8a` + `armeabi-v7a`, `package/name="PlayTable"`
- [x] **Preparação para F-Droid** — `export_presets.cfg` versionado (removido do `.gitignore`), cache do editor `.godot/` removido do índice (o `uid_cache.bin` reprovava no scanner e o `project_metadata.cfg` vazava caminhos absolutos). Scanner do F-Droid passa de 1 problema para 0
- [x] **Keystore de release removida do histórico** — a chave privada de assinatura estava versionada e publicamente acessível no GitHub e no GitLab, com a senha em claro no `build_apk.sh`. Histórico reescrito com `git filter-repo`, senha redigida e chave marcada como comprometida. Os SHAs de todos os commits mudaram e as tags foram recriadas
- [x] **`build_apk.sh`** — export sempre sem assinatura; assinatura virou passo separado com `apksigner`, usando `KEYSTORE_PATH` (fora do repositório) e `KEYSTORE_PASSWORD` via ambiente

## [v0.2.0 (2026-08-19)](https://github.com/ricardosierra/PlayTable/compare/v0.1.0...v0.2.0)

### ✨ Novidades

- [x] **Suíte de Testes Automatizados e de Integração:** 64 testes unitários e de integração E2E criados e 100% aprovados, cobrindo todos os 16 minijogos de tabuleiro e cartas, persistência, regras de IA, internacionalização e simulações completas de partidas sem deadlocks
- [x] **Runner de Testes Mestre (`tests/run_tests.py`):** Script executável via terminal com relatório visual consolidado de cobertura por jogo e métricas de execução
- [x] **Catálogo Completo dos 11 Jogos de Tabuleiro Validados:** Regras e testes implementados para Jogo da Velha, Damas, Batalha Naval, Quatro em Linha, Resta Um (Solitário), Campo Minado, Dominó, Ludo, Reversi, Mancala e Senet Egípcio
- [x] **Catálogo Completo dos 5 Jogos de Cartas Validados:** Regras e testes implementados para Paciência Klondike, Jogo da Memória, 21 (Blackjack), Cartas das Cores (Uno-like) e Poker (Video Poker)
- [x] **Internacionalização (i18n):** Suporte multilíngue completo com `LocaleManager.gd` e catálogos traduzidos em Português (`pt_BR`), Inglês (`en`) e Espanhol (`es`)
- [x] **Sistema de Áudio Centralizado:** Implementação de `AudioManager.gd` para efeitos sonoros e controle de volume persistente

### 🎨 Melhorias

- [x] **Ícone Vetorial Autoral (`icon.svg`):** Arte vetorial minimalista com dados e cartas estilizados em gradiente dourado e tema escuro
- [x] **Aprimoramento Visual 3D:** Peças esculpidas, tabuleiros texturizados e integração com `TabletopBackground.gd` e `TabletopEnvironment3D`
- [x] **Tema Escuro Moderno:** `MainTheme.tres` otimizado com botões arredondados, contrastes legíveis e estilo tabletop sofisticado

### 🐛 Correções

- [x] **Compatibilidade Godot 4 GDScript:** Corrigidas chamadas de construtor `super()` em `AIPlayerController.gd` e alinhadas assinaturas de métodos em todas as regras dos jogos (`BattleshipRules`, `CheckersRules`, `DominoRules`, `KlondikeRules`, `MinesweeperRules`, `PokerEvaluator`, `ReversiRules`, `PegSolitaireRules` e `UnoRules`)
- [x] **Paridade de Enums em Cartas:** Adicionados `SpecialType` e `ColorType` para descarte correto no Uno-like e tratamento de Ás dinâmico no Blackjack
- [x] **Resolução de Modal no macOS:** Tratado travamento de diálogo modal de persistência do AppKit via `-ApplePersistenceIgnoreState YES` na execução headless

### 🔧 Técnico

- [x] **Pipeline de Build Android (`build_apk.sh`):** Exportação headless automatizada gerando APK assinado (`JogosDeMesaOffline.apk`) via `apksigner` com `release.keystore`
- [x] **Arquitetura Modular:** Separação estrita em `core/` (save, áudio, i18n, navegação), `shared/` (motores de peças, tabuleiros, baralhos) e `games/` (módulos isolados por jogo)
- [x] **Zero Ads, Zero Tracking & 100% Offline:** Sem SDKs invasivos, sem internet necessária e dados salvos exclusivamente no dispositivo local

---

## [v0.1.0 (2026-08-18)](https://github.com/ricardosierra/PlayTable/releases/tag/v0.1.0)

### ✨ Novidades

- [x] **Estrutura Base do Projeto:** Inicialização do repositório Godot 4.3 Engine para 16 minijogos de tabuleiro e cartas
- [x] **Navegação & Telas:** Menus de seleção divididos em Menu Principal, Menu de Tabuleiros e Menu de Cartas
- [x] **Persistência de Dados (`SaveManager.gd`):** Gerenciamento de configurações locais em JSON (`user://config.save`)
- [x] **Documentação Arquitetural:** Criação dos guias técnicos em `docs/` e `README.md`
