# Release Notes

---

## [Unreleased](https://github.com/ricardosierra/jogos-de-mesa-offline/compare/v0.2.1...develop)

## [v0.2.1 (2026-08-22)](https://github.com/ricardosierra/jogos-de-mesa-offline/compare/v0.2.0...v0.2.1)

### 🐛 Correções

- [x] **Autoloads ocultados por `class_name`** — `SceneManager`, `SaveManager`, `AudioManager` e `LocaleManager` declaravam uma classe global com o mesmo nome do singleton; no Godot 4.3 isso gerava `Class "X" hides an autoload singleton` e fazia 26 scripts (todos os menus e os 16 jogos) falharem ao carregar. Removida a linha `class_name` dos quatro autoloads
- [x] **Links quebrados na documentação** — os 16 links do catálogo no `README.md` apontavam para `file:///Users/...`; agora são relativos. Links do `CHANGELOG.md` migrados do GitLab privado para o GitHub
- [x] **`LICENSE`** — placeholder `[Developer Name]` substituído por `Ricardo Sierra`

### 🔧 Técnico

- [x] **`export_presets.cfg` completo e sem chaves** — o preset era um stub de ~17 chaves que o Godot 4.3 rejeitava (keystore parcialmente preenchida e `architecture/*` no singular, ignorado em favor de `architectures/*`). Regenerado com as 202 chaves de um preset real, sem nenhuma chave `keystore/*`, `package/signed=false`, `arm64-v8a` + `armeabi-v7a`, `package/name="PlayTable"`
- [x] **Preparação para F-Droid** — `export_presets.cfg` versionado (removido do `.gitignore`), cache do editor `.godot/` removido do índice (o `uid_cache.bin` reprovava no scanner e o `project_metadata.cfg` vazava caminhos absolutos). Scanner do F-Droid passa de 1 problema para 0
- [x] **Keystore de release removida do histórico** — a chave privada de assinatura estava versionada e publicamente acessível no GitHub e no GitLab, com a senha em claro no `build_apk.sh`. Histórico reescrito com `git filter-repo`, senha redigida e chave marcada como comprometida. Os SHAs de todos os commits mudaram e as tags foram recriadas
- [x] **`build_apk.sh`** — export sempre sem assinatura; assinatura virou passo separado com `apksigner`, usando `KEYSTORE_PATH` (fora do repositório) e `KEYSTORE_PASSWORD` via ambiente

## [v0.2.0 (2026-08-19)](https://github.com/ricardosierra/jogos-de-mesa-offline/compare/v0.1.0...v0.2.0)

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

## [v0.1.0 (2026-08-18)](https://github.com/ricardosierra/jogos-de-mesa-offline/releases/tag/v0.1.0)

### ✨ Novidades

- [x] **Estrutura Base do Projeto:** Inicialização do repositório Godot 4.3 Engine para 16 minijogos de tabuleiro e cartas
- [x] **Navegação & Telas:** Menus de seleção divididos em Menu Principal, Menu de Tabuleiros e Menu de Cartas
- [x] **Persistência de Dados (`SaveManager.gd`):** Gerenciamento de configurações locais em JSON (`user://config.save`)
- [x] **Documentação Arquitetural:** Criação dos guias técnicos em `docs/` e `README.md`
