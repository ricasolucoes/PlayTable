# REQUIREMENTS

## Milestone v1.0 — Play Games, Gamificação e Servidor Próprio

Requisitos rastreáveis das fases 1 a 13 (mais a 7.1). Derivados do bloco
`**Requirements**:` de cada fase do `ROADMAP.md`. A tabela de rastreabilidade
no fim desta seção é o que as ferramentas do GSD leem para marcar progresso.

### Decisão de arquitetura que atravessa todas as fases

Três camadas, duas opcionais (ver `.planning/PROJECT.md`):

1. **Local** — sempre completa. Nenhuma feature pode exigir login ou rede.
2. **Play Games Services v2** — opcional. Só existe se o jogador entrar.
3. **Servidor próprio** (`playtable.ricasolucoes.com.br`) — opcional, mantido
   fora deste repositório. Servidor fora do ar é estado normal, não erro.

---

### Phase 1: Discovery e Auditoria

- [x] **REQ-1-LER-REPO**: Ler o repositório inteiro e estabelecer sua arquitetura real, no código e não na documentação.
- [x] **REQ-1-DOC-INFRA**: Documentar os ~31 tópicos de descoberta (engine, build, package id, auth, save, progressão, XP, ranking, conquistas, missões, eventos, temporadas, recompensas, analytics, notificações, compras, monetização, anti-cheat, sincronização, offline, entre outros), cada um com `arquivo:linha`.
- [x] **REQ-1-NAO-DUPLICAR**: Identificar o que já existe e é reaproveitável; não criar sistema paralelo ao que já roda.
- [x] **REQ-1-CURRENT-REQUIREMENTS**: Reescrever `docs/google-play/current-requirements.md` contra a documentação oficial vigente do Google, com fonte, impacto, situação verificada, arquivo, status e confiança.
- [x] **REQ-1-COMPATIBILITY-AUDIT**: Entregar `docs/google-play/compatibility-audit.md` — o entregável final ("Fase 0").

### Phase 2: Fundação Gamification Service

- [ ] **REQ-2-MODULO**: Módulo de gamificação coeso (Progression, Quests, Rewards), estendendo o que já existe em `core/services/`.
- [ ] **REQ-2-EVENTOS**: Game Domain Events desacoplando gamificação da gameplay, sobre o `GameEventBus` existente.
- [ ] **REQ-2-BASE**: Base de analytics, persistência e feature flags preparada.

### Phase 3: Play Games Services v2

- [ ] **REQ-3-LOGIN**: Login silencioso no boot, assíncrono, que nunca bloqueia o app.
- [ ] **REQ-3-FALLBACK**: Fallback offline e reconexão — sem PGS, tudo continua local.
- [ ] **REQ-3-IDEMPOTENCIA**: Idempotência nos envios; fila persistida sem duplicar.
- [ ] **REQ-3-RECALL**: Recall API e sincronização entre aparelhos (hoje ausente do código).
- [ ] **REQ-3-IDS**: Preencher os identificadores do Play Console em `core/configs/play_games_ids.json`.

### Phase 4: Achievements

- [ ] **REQ-4-CATALOGO**: Catálogo de 40 a 60 conquistas distribuídas por progressão, habilidade e segredos.
- [ ] **REQ-4-PRIMEIRA-HORA**: Ao menos 4 conquistas alcançáveis na primeira hora de jogo.
- [ ] **REQ-4-MATRIZ**: `docs/google-play/achievement-matrix.md` conferido contra o catálogo real.
- [ ] **REQ-4-FEEDBACK**: Feedback visual de desbloqueio, sem depender de estar logado.

### Phase 5: Game Stats

- [ ] **REQ-5-API**: Integrar a Game Stats API atual (`GameStatsClient`/`PlayerGameEvent`) — a Events API clássica não substitui.
- [ ] **REQ-5-PROGRESSION**: Definir e enviar o Progression Stat.
- [ ] **REQ-5-CSV**: Gerar os CSVs do Play Console conferidos contra o template vigente.
- [ ] **REQ-5-SCHEMA**: `docs/google-play/game-stats-schema.md` atualizado, sem lixo analítico.

### Phase 6: Gamificação avançada (XP, Quests, Streaks)

- [ ] **REQ-6-XP**: Sistema global de XP com leveling progressivo.
- [ ] **REQ-6-QUESTS**: Cadeias de missões dirigidas por evento.
- [ ] **REQ-6-STREAK**: Streak com tolerância, e loop diário/semanal.
- [ ] **REQ-6-COMEBACK**: Coleções e sistema de retorno para quem ficou fora.

### Phase 7: Social (Leaderboards, Friends)

- [ ] **REQ-7-RANKING**: Rankings globais e locais.
- [ ] **REQ-7-AMIGOS**: Recursos sociais e desafios comunitários.
- [ ] **REQ-7-LIGAS**: Ligas competitivas sobre o `LeagueSystem` existente.

### Phase 7.1: Multiplayer Online

- [ ] **REQ-71-CONTRATO**: Consumir `docs/server/api-contract.md` (`/v1/rooms/*`, `/v1/matches/*`).
- [ ] **REQ-71-RESILIENTE**: Cliente HTTP que trata servidor inacessível como normal, com fila persistida em `user://`, reaproveitando a forma de `core/services/PlayGamesManager.gd` — sem detector de conectividade paralelo.
- [ ] **REQ-71-TELAS**: Telas de sala, convite e partida.
- [ ] **REQ-71-TURNO**: Turno autoritativo do servidor para os jogos que já têm modo de 2 jogadores no mesmo aparelho.
- [ ] **REQ-71-RECONEXAO**: Reconexão e abandono tratados.

### Phase 8: LiveOps e Configurações Dinâmicas

- [ ] **REQ-8-REMOTO**: Configuração remota real — hoje `LiveOpsManager` só lê JSON local e admite isso no próprio comentário.
- [ ] **REQ-8-SEASONS**: Seasons, missões diárias/semanais e multiplicadores mudáveis sem novo build.
- [ ] **REQ-8-FLAGS**: Feature flags com default local seguro quando não há servidor.

### Phase 9: Sidekick Integration

- [ ] **REQ-9-AAB**: Publicação por AAB.
- [ ] **REQ-9-OVERLAY**: Overlay do Sidekick testado de verdade (fullscreen, gestos, troca de conta) sem quebrar controle.
- [ ] **REQ-9-DESIGN**: Preparo para Gemini/Game Tips, Play Pass e Play Points.
- [ ] **REQ-9-DOC**: `docs/google-play/sidekick-integration.md` conferido contra o que existe.

### Phase 10: Segurança e Anti-cheat

- [ ] **REQ-10-CLIENTE**: Não confiar cegamente no cliente; validações de XP e progressão.
- [ ] **REQ-10-IDEMPOTENCIA**: Idempotência e rate limiting nas mutações.
- [ ] **REQ-10-INTEGRITY**: Play Integrity, na medida em que o servidor próprio existir.
- [ ] **REQ-10-CONFLITO**: Resolução correta de conflito de Cloud Save.

### Phase 11: QA e Testes de Sincronização

- [ ] **REQ-11-AUTH**: Testes de autenticação e de reinstalação.
- [ ] **REQ-11-OFFLINE**: Testes offline-first, fila local e sync posterior.
- [ ] **REQ-11-RECOMPENSA**: Testes de conquista e recompensa, com dupla validação.
- [ ] **REQ-11-MATRIZ**: Rodar na matriz mínima de aparelhos, com e sem Sidekick.

### Phase 12: Performance e Otimização

- [ ] **REQ-12-FPS**: FPS, memória, bateria e tempo de partida.
- [ ] **REQ-12-FRAME**: Nada pesado por frame — em lote e dirigido a evento.
- [ ] **REQ-12-ANR**: ANRs corrigidos.
- [ ] **REQ-12-QUALITY**: Conferir a documentação vigente do Level Up Quality.

### Phase 13: Release e Rollout

- [ ] **REQ-13-FAIXAS**: Lançamento em faixas: interno → fechado → produção.
- [ ] **REQ-13-METRICAS**: Métricas de observabilidade definidas.
- [ ] **REQ-13-CHECKLIST**: `docs/google-play/play-console-checklist.md` completo.
- [ ] **REQ-13-COMPAT**: Matriz de compatibilidade final em 100%.

---

## Rastreabilidade — Milestone v1.0

| REQ-ID | Fase | Status |
|--------|------|--------|
| REQ-1-LER-REPO | Phase 1 | Complete |
| REQ-1-DOC-INFRA | Phase 1 | Complete |
| REQ-1-NAO-DUPLICAR | Phase 1 | Complete |
| REQ-1-CURRENT-REQUIREMENTS | Phase 1 | Complete |
| REQ-1-COMPATIBILITY-AUDIT | Phase 1 | Complete |
| REQ-2-MODULO | Phase 2 | Pending |
| REQ-2-EVENTOS | Phase 2 | Pending |
| REQ-2-BASE | Phase 2 | Pending |
| REQ-3-LOGIN | Phase 3 | Pending |
| REQ-3-FALLBACK | Phase 3 | Pending |
| REQ-3-IDEMPOTENCIA | Phase 3 | Pending |
| REQ-3-RECALL | Phase 3 | Pending |
| REQ-3-IDS | Phase 3 | Pending |
| REQ-4-CATALOGO | Phase 4 | Pending |
| REQ-4-PRIMEIRA-HORA | Phase 4 | Pending |
| REQ-4-MATRIZ | Phase 4 | Pending |
| REQ-4-FEEDBACK | Phase 4 | Pending |
| REQ-5-API | Phase 5 | Pending |
| REQ-5-PROGRESSION | Phase 5 | Pending |
| REQ-5-CSV | Phase 5 | Pending |
| REQ-5-SCHEMA | Phase 5 | Pending |
| REQ-6-XP | Phase 6 | Pending |
| REQ-6-QUESTS | Phase 6 | Pending |
| REQ-6-STREAK | Phase 6 | Pending |
| REQ-6-COMEBACK | Phase 6 | Pending |
| REQ-7-RANKING | Phase 7 | Pending |
| REQ-7-AMIGOS | Phase 7 | Pending |
| REQ-7-LIGAS | Phase 7 | Pending |
| REQ-71-CONTRATO | Phase 7.1 | Pending |
| REQ-71-RESILIENTE | Phase 7.1 | Pending |
| REQ-71-TELAS | Phase 7.1 | Pending |
| REQ-71-TURNO | Phase 7.1 | Pending |
| REQ-71-RECONEXAO | Phase 7.1 | Pending |
| REQ-8-REMOTO | Phase 8 | Pending |
| REQ-8-SEASONS | Phase 8 | Pending |
| REQ-8-FLAGS | Phase 8 | Pending |
| REQ-9-AAB | Phase 9 | Pending |
| REQ-9-OVERLAY | Phase 9 | Pending |
| REQ-9-DESIGN | Phase 9 | Pending |
| REQ-9-DOC | Phase 9 | Pending |
| REQ-10-CLIENTE | Phase 10 | Pending |
| REQ-10-IDEMPOTENCIA | Phase 10 | Pending |
| REQ-10-INTEGRITY | Phase 10 | Pending |
| REQ-10-CONFLITO | Phase 10 | Pending |
| REQ-11-AUTH | Phase 11 | Pending |
| REQ-11-OFFLINE | Phase 11 | Pending |
| REQ-11-RECOMPENSA | Phase 11 | Pending |
| REQ-11-MATRIZ | Phase 11 | Pending |
| REQ-12-FPS | Phase 12 | Pending |
| REQ-12-FRAME | Phase 12 | Pending |
| REQ-12-ANR | Phase 12 | Pending |
| REQ-12-QUALITY | Phase 12 | Pending |
| REQ-13-FAIXAS | Phase 13 | Pending |
| REQ-13-METRICAS | Phase 13 | Pending |
| REQ-13-CHECKLIST | Phase 13 | Pending |
| REQ-13-COMPAT | Phase 13 | Pending |

---

## Milestone anterior — Coleção de Jogos Offline (arquivado)

Mantido para histórico. Estes requisitos foram entregues: os 20 jogos estão
em `games/`, com 32 arquivos de teste GUT em `tests/gdscript/`.

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
