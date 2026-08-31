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
**Plans:** 4 plans

Plans:
- [ ] 01-01-PLAN.md — Ferramenta de rastreabilidade (`scripts/audit_traceability.sh`), tenets do PROJECT.md e fase 7.1 no roadmap
- [ ] 01-02-PLAN.md — `docs/google-play/current-requirements.md` reescrito contra o código real
- [ ] 01-03-PLAN.md — `docs/server/api-contract.md` e correção dos documentos desatualizados
- [ ] 01-04-PLAN.md — `docs/google-play/compatibility-audit.md`, o entregável final, e o CHANGELOG

### Phase 2: Fundação Gamification Service

**Goal:** Criar a base arquitetural e Event Bus da gamificação.
**Requirements**: Criar/refatorar módulo Gamification (Progression, Quests, Rewards). Implementar Game Domain Events para desacoplar da gameplay. Preparar base de Analytics, Persistência e Feature Flags. (Ver arquivo `REQUIREMENTS.md` na pasta da fase)
**Depends on:** Phase 1
**Plans:** 0 plans

Plans:
- [ ] TBD (run /gsd-plan-phase 2 to break down)

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

---

## Estrutura Core e Menus
- [x] **Menu Principal**: Navegação para Tabuleiro (14 jogos), Cartas (5 jogos) e Configurações com alternância de tema Claro/Escuro.
- [x] **Menu Tabuleiro**: Grade com navegação direta para os 14 jogos de tabuleiro.
- [x] **Menu Cartas**: Grade com navegação direta para os 5 jogos de cartas.
- [x] **Build & Android**: Export preset configurado e script de build (`build_apk.sh`).
