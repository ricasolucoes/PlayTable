# ROADMAP

## Coleção Completa de Jogos Offline (19 Jogos)

### 🎲 Jogos de Tabuleiro (14 Jogos)
- [x] **1. Jogo da Velha (Tic-Tac-Toe)**: Grade 3x3, IA tática, placar de vitórias/empates e reinício rápido (`games/jogo_da_velha/`).
- [x] **2. Damas (Checkers)**: Tabuleiro 8x8, movimentos simples, damas coroadas 👑, capturas múltiplas e IA (`games/damas/`).
- [x] **3. Batalha Naval (Battleship)**: Grids 10x10 (Radar e Frota), 5 navios, IA Hunt & Target com busca em cruz (`games/batalha_naval/`).
- [x] **4. Quatro em Linha (Connect Four)**: Grade 7x6, física de queda, IA e placar de vitórias (`games/quatro_em_linha/`).
- [x] **5. Solitário / Resta Um (Peg Solitaire)**: Cruz de 33 posições, saltos válidos, botão Desfazer (Undo) e vitória com 1 pino no centro (`games/solitario/`).
- [x] **6. Campo Minado (Minesweeper)**: Grade 9x9 com 10 minas, primeiro clique seguro, flood-fill de zeros, alternador de bandeiras e timer (`games/campo_minado/`).
- [x] **7. Dominó (Dominoes)**: Conjunto de 28 pedras (duplo-6), compra do dorme, jogadas nas pontas abertas e desempate por contagem de pontos (`games/domino/`).
- [x] **8. Ludo Simplificado**: 4 jogadores (Jogador + 3 IAs), dado 1-6 animado, saída de base com 6, capturas na pista e corrida ao centro (`games/ludo/`).
- [x] **9. Reversi / Othello**: Tabuleiro 8x8 verde, virada de discos em 8 direções, matriz de peso posicional e contagem de peças (`games/reversi/`).
- [x] **10. Mancala (Kalah)**: 12 covas e 2 depósitos, semeadura anti-horária, turnos extras, capturas opostas e IA inteligente (`games/mancala/`).
- [x] **11. Senet (Jogo Egípcio Antigo)**: Trilha serpenteante 3x10 (30 casas), 5 peças cada, varetas de lançamento (1-5), casas sagradas e remoção de peças (`games/senet/`).
- [x] **12. Torres de Hanói (Tower of Hanoi)**: 3 a 8 discos 3D, movimentação parabólica em arco por tweens, solver automático demonstrativo, histórico de desfazer e gamificação (`games/hanoi/`).
- [x] **13. Jogo de Nim (Nim Game 3D)**: 3 a 5 pilhas de gemas 3D em nogueira e ouro, IA com Teorema de Bouton (Nim-Sum), modos Normal e Misère (Marienbad), descarte em arco e gamificação (`games/nim/`).
- [x] **14. Gamão 3D (Backgammon)**: 24 pontas triangulares entalhadas, 30 peças em marfim/obsidiana, dados 3D rolantes, barra de captura, bear-off, Pip Count, IA tática e gamificação (`games/gamao/`).

---

### 🃏 Jogos de Cartas (5 Jogos)
- [x] **15. Paciência Klondike (Klondike Solitaire)**: 7 colunas no tableau, 4 fundações por naipe (A a K), monte de compras e descarte, auto-completar e pontuação (`games/paciencia/`).
- [x] **16. Jogo da Memória**: Cartas com emojis, animação de flip, contador de jogadas e pares (`games/memoria/`).
- [x] **17. 21 / Blackjack**: Baralho 52 cartas, dealer para no 17, sistema de fichas/apostas e botão Dobrar (Double Down) (`games/blackjack/`).
- [x] **18. Uno-like (Cartas das Cores)**: Baralho com 4 cores + cartas de ação (Pular, Inverter, +2, Curinga, +4), seletor de cor e IA oponente (`games/unolike/`).
- [x] **19. Poker Simplificado (Video Poker / 5-Card Draw)**: Avaliador de mãos de poker oficiais, seleção de cartas para MANTER (HOLD), troca de cartas e tabela de pagamentos (`games/poker/`).

### Phase 1: Discovery e Auditoria

**Goal:** Realizar o mapeamento completo do projeto e preparar terreno.
**Requirements**: Ler repositório, documentar infra atual (Godot, Android, build, APIs), não criar sistemas paralelos desnecessários, registrar compatibilidade em /docs/google-play/current-requirements.md e gerar entregável Fase 0. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 0
**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Ferramenta de rastreabilidade (`scripts/audit_traceability.sh`), tenets do PROJECT.md e fase 7.1 no roadmap
- [x] 01-02-PLAN.md — `docs/google-play/current-requirements.md` reescrito contra o código real
- [x] 01-03-PLAN.md — `docs/server/api-contract.md` e correção dos documentos desatualizados
- [x] 01-04-PLAN.md — `docs/google-play/compatibility-audit.md`, o entregável final, e o CHANGELOG

### Phase 2: Fundação Gamification Service

**Goal:** Criar a base arquitetural e Event Bus da gamificação.
**Requirements**: Criar/refatorar módulo Gamification (Progression, Quests, Rewards). Implementar Game Domain Events para desacoplar da gameplay. Preparar base de Analytics, Persistência e Feature Flags. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 1
**Plans:** 5 plans

Plans:
- [ ] 02-01-PLAN.md — `OfflineQueue` extraída do Play Games, `PlayerProfile.export_snapshot()` e o arquivo GUT da fase (REQ-2-MODULO)
- [ ] 02-02-PLAN.md — `domain_event`, sessão, `flags_changed` e o contrato de `match_completed` validado (REQ-2-EVENTOS)
- [ ] 02-03-PLAN.md — feature flags em três camadas, `share_stats` e `docs/gamification/feature-flags.md` (REQ-2-BASE)
- [ ] 02-04-PLAN.md — `AnalyticsManager` local: allowlist, JSONL diário, rotação e `register_sink()` (REQ-2-BASE)
- [ ] 02-05-PLAN.md — `docs/gamification/` (README + domain-events), CHANGELOG e portão final da suíte (REQ-2-MODULO, REQ-2-EVENTOS)

### Phase 3: Play Games Services v2

**Goal:** Implementar Google Play Games Services v2.
**Requirements**: Login automático, tratamento assíncrono, fallback offline, idempotência, reconexão, gerenciamento de contas (Recall API, sync device-to-device). (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 2
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 3 to break down)

### Phase 4: Achievements

**Goal:** Criar sistema de Achievements.
**Requirements**: Catálogo de 40 a 60 conquistas (Progressão, Habilidade, Segredos, etc), focar em 4 conquistas alcançáveis na 1ª hora, criar /docs/google-play/achievement-matrix.md e feedback visual elegante. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 3
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 4 to break down)

### Phase 5: Game Stats

**Goal:** Implementar API moderna de Game Stats.
**Requirements**: Enviar stats de progressão e eventos relevantes, gerar CSVs para o Play Console (ProgressionStatConfig, etc), evitar lixo analítico e criar /docs/google-play/game-stats-schema.md. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 4
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 5 to break down)

### Phase 6: Gamificação avançada (XP, Quests, Streaks)

**Goal:** Implementar XP, Levels, Quests, Streaks.
**Requirements**: Sistema Global de XP, Leveling progressivo, Cadeias de Missões baseadas em eventos, Streak System inteligente, Loop Diário/Semanal, Coleções e Sistema de Retorno (Comeback). (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 5
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 6 to break down)

### Phase 7: Social (Leaderboards, Friends)

**Goal:** Integrar Leaderboards e recursos Sociais.
**Requirements**: Criar rankings globais/locais, loop de engajamento social, desafios comunitários, e ligas competitivas, preparando-se para recursos do Gamer Profile e Social Challenges. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 6
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 7 to break down)

### Phase 7.1: Multiplayer Online

**Goal:** Jogar com amigos pela internet contra o servidor próprio, sem que nada disso vire requisito para quem joga offline.
**Requirements**: Consumir o contrato definido em `docs/server/api-contract.md` (grupos `/v1/rooms/*` e `/v1/matches/*`); cliente HTTP resiliente que trate servidor inacessível como estado normal, com fila local persistida em `user://` e retry, reaproveitando a forma que `core/services/PlayGamesManager.gd:220-277` já usa para o PGS — sem detector de conectividade paralelo; telas de sala, convite e partida; turno autoritativo do servidor para os jogos que já têm modo de 2 jogadores no mesmo aparelho; reconexão e abandono. O servidor `playtable.ricasolucoes.com.br` é mantido fora deste repositório. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 7
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 7.1 to break down)

### Phase 8: LiveOps e Configurações Dinâmicas

**Goal:** Criar sistemas Server-Driven e LiveOps.
**Requirements**: Suporte a Seasons, daily/weekly quests, Multipliers, feature flags e configurações dinâmicas sem atualização do App, permitindo dificuldade dinâmica e recomendações. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 7
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 8 to break down)

### Phase 9: Sidekick Integration

**Goal:** Preparar Play Games Sidekick Integration.
**Requirements**: AAB obrigatório, testar Overlay Sidekick extensivamente (fullscreen, gestos, etc) sem quebrar controles, preparar design para Gemini/Game Tips, Play Pass e Play Points. Documentar integração. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 8
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 9 to break down)

### Phase 10: Segurança e Anti-cheat

**Goal:** Implementar Segurança e Anti-cheat.
**Requirements**: Não confiar cegamente no cliente, implementar validações (idempotência, rate limiting, anti-cheat, validações backend, Play Integrity). Resolver confiltos de Cloud Save corretamente. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 9
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 10 to break down)

### Phase 11: QA e Testes de Sincronização

**Goal:** QA, Sincronização e Offline.
**Requirements**: Criar testes de Autenticação, Offline-first, Achievements e Rewards, reinstalação, dupla validação, filas locais com sync posterior, testando na matriz mínima de dispositivos (com e sem Sidekick). (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 10
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 11 to break down)

### Phase 12: Performance e Otimização

**Goal:** Auditar Performance e Android Quality.
**Requirements**: Garantir FPS, memory, battery, startup. Evitar chamadas pesadas por frame (batch, event-driven), corrigir ANRs e verificar documentação atual do Level Up Quality. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 11
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 12 to break down)

### Phase 13: Release e Rollout

**Goal:** Release, Rollout e Console Checklist.
**Requirements**: Lançamento em faixas (Internal -> Closed -> Production), definir métricas de observabilidade, criar /docs/google-play/play-console-checklist.md e preencher Matriz de Compatibilidade Final 100%. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 12
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 13 to break down)

### Phase 14: Jogo de Tabuleiro - Xadrez (Chess)

**Goal:** Implementar o jogo de Xadrez com motor de regras, gamificação e suporte multiplayer.
**Requirements**: Criar módulo `games/xadrez/`. Implementar regras (xeque, xeque-mate, roque, en passant, promoção). IA local offline. Disparar eventos de progresso via `GameEventBus`. Integrar backend RicaGames (Fase 7.1) para multiplayer (matchmaking e salas privadas). (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 7.1
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 14 to break down)

### Phase 15: Jogo de Tabuleiro - Trilha (Nine Men's Morris)

**Goal:** Implementar o jogo de Trilha, mecânicas de posicionamento e moinhos.
**Requirements**: Criar módulo `games/trilha/`. Implementar as 3 fases (colocação, movimentação, voo) e captura por moinho. IA offline tática. Abstrair conquistas via `PlayerProfile` e Event Bus. Multiplayer RicaGames. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 14
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 15 to break down)

### Phase 16: Jogo de Cartas - Truco

**Goal:** Implementar o jogo de Truco (Paulista/Mineiro), com blefes e sistema de apostas.
**Requirements**: Criar módulo `games/truco/`. Sistema de rodadas, sinais e manilhas. Gamificação com eventos de bluff_successful. Suporte essencial a pareamento 1v1 ou 2v2 online via RicaGames. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 15
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 16 to break down)

### Phase 17: Jogo de Cartas - Buraco (Canasta)

**Goal:** Implementar o jogo de Buraco, com compra, lixo, canastras e batida.
**Requirements**: Criar módulo `games/buraco/`. Lógica de baixar jogos, canastras limpas/sujas, morto. Progressão baseada em pontos e eventos. Multiplayer RicaGames para partidas 1v1 ou 2v2 longas, com persistência local para reconexão. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 16
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 17 to break down)

### Phase 18: Jogo de Tabuleiro - Guerra (War)

**Goal:** Implementar o jogo de estratégia Guerra, com mapa e dominação de territórios.
**Requirements**: Criar módulo `games/guerra/`. Mapas, distribuição de exércitos, ataques e objetivos secretos. Progressão baseada em dominação e vitórias (streaks). Multiplayer RicaGames até 6 jogadores simultâneos/assíncronos. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 17
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 18 to break down)

### Phase 19: Jogo de Dados - General (Yahtzee)

**Goal:** Implementar o clássico jogo de dados General.
**Requirements**: Criar módulo `games/general/`. Lógica de rolagem de 5 dados (com retenção de dados entre rolagens) e tabela de pontuação (Trinca, Sequência, Full House, General). Sistema de Leaderboards para maior pontuação. Multiplayer online (Fase 7.1). (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 18
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 19 to break down)

### Phase 20: Jogo de Cartas - Paciência Spider

**Goal:** Implementar Paciência Spider, aproveitando a base de arrastar e soltar cartas.
**Requirements**: Criar módulo `games/spider/`. Aproveitar código de física/drag-drop da Paciência Klondike. Níveis de dificuldade: 1, 2 e 4 naipes. Conquistas para vitórias nas dificuldades maiores. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 19
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 20 to break down)

### Phase 21: Jogo de Cartas - Copas (Hearts)

**Goal:** Implementar o clássico Copas.
**Requirements**: Criar módulo `games/copas/`. Jogo de vazas de 4 jogadores. Regras para evitar copas e Dama de Espadas, e mecânica de "Acertar a Lua". IA avançada para evitar receber pontos. Multiplayer online 4-players (Fase 7.1). (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 20
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 21 to break down)

### Phase 22: Jogo Social - Bingo (Multijogador)

**Goal:** Implementar Bingo focado na experiência multijogador e social.
**Requirements**: Criar módulo `games/bingo/`. Gerador de cartelas 5x5, roleta/sorteio de bolas. Foco absoluto em salas da RicaGames (Fase 7.1) suportando múltiplos jogadores. Conquistas para preenchimento de padrões rápidos. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 21
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 22 to break down)

### Phase 23: Jogo de Lógica - Mastermind (Senha)

**Goal:** Implementar Jogo da Senha/Mastermind.
**Requirements**: Criar módulo `games/senha/`. Tabuleiro de pinos coloridos. Validação de posição e cor (pinos brancos/pretos). Modo offline de resolver códigos e sistema de tempo/tentativas para Leaderboards. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 22
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 23 to break down)

### Phase 24: Jogo Social - Stop (Adedanha)

**Goal:** Implementar Stop/Adedanha com mecânica social de validação de palavras.
**Requirements**: Criar módulo `games/stop/`. Sistema de salas (RicaGames) onde os jogadores digitam palavras por categoria. Sincronização em tempo real e fase de votação onde os próprios jogadores validam a resposta dos oponentes, eliminando a necessidade de um dicionário offline gigante. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 23
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 24 to break down)

---

## Estrutura Core e Menus
- [x] **Menu Principal**: Navegação para Tabuleiro (14 jogos), Cartas (5 jogos) e Configurações com alternância de tema Claro/Escuro.
- [x] **Menu Tabuleiro**: Grade com navegação direta para os 14 jogos de tabuleiro.
- [x] **Menu Cartas**: Grade com navegação direta para os 5 jogos de cartas.
- [x] **Build & Android**: Export preset configurado e script de build (`build_apk.sh`).
