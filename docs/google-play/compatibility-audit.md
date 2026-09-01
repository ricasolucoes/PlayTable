# Auditoria de Compatibilidade — Google Play Games, Level Up e Sidekick

**Auditado em:** 2026-08-31
**Entregável:** este documento é a "Fase 0" do prompt original e a entrada de planejamento das fases 2 a 13.
**Método:** cada linha foi lida no arquivo, não no documento anterior. Onde a coluna de evidência traz `arquivo:linha`, a afirmação foi conferida ali. Onde traz `SEM-CODIGO`, a ausência foi confirmada por varredura em todo o repositório, fora de `android/build/`, que é gerado e descartável (`.gitignore:27`).
**Substitui:** a versão de 2026-08-24. Aquele documento afirmava "Arquitetura Event-Driven Ausente" e "Gamificação Existente: Extremamente básica e acoplada". As duas afirmações eram falsas: `core/services/GameEventBus.gd` tem 25 sinais e 20 autoloads reagem a ele. Planejar em cima daquele texto faria a fase 2 reconstruir o que já existe.
**Requisitos oficiais:** a lista de requisitos do Google, com fonte e status, está em `docs/google-play/current-requirements.md`. Este documento cruza aquela lista com o roadmap.
**Achado central:** a ponte com o Play Games Services já existe, completa, em `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` (seção 3). O que trava as fases 3, 4 e 9 não é código — são os 69 ids vazios do Play Console.

## 1. Identificação do projeto e build

| Tópico | Valor | Evidência | Observação |
|---|---|---|---|
| Engine | Godot 4.7.2-stable | `.godot-version` | versão pinada; `scripts/godot_bin.sh` resolve o binário sozinho, e é o mesmo resolvedor que os scripts de build e a suíte GUT usam — testar numa engine e publicar em outra seria não testar |
| Framework e Linguagem | GDScript puro no cliente; Java só na ponte Android | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` | não há framework externo; a "framework" é a própria árvore de autoloads do Godot |
| Plataforma | Android, preset único "Android" | `export_presets.cfg:1-6` | não existe preset de iOS nem de desktop no repositório |
| Package / application ID | `org.playtable.app` | `export_presets.cfg:36`, `android/pgs/README.md:29` | o mesmo id vinculado no projeto do Play Games |
| Versão publicada | code 12, name 0.7.0 | `export_presets.cfg:34-35`, `build_aab.sh:21-22` | o script aceita sobrescrita por variável de ambiente |
| Estrutura Android e Módulo Android | `android/build/` gerado e descartável, `android/pgs/` fonte versionada | `.gitignore:27`, `android/pgs/install.sh` | o instalador é idempotente e reaplica `android/pgs/` sobre `android/build/` a cada build, porque o template do Godot apaga a integração ao ser reinstalado |
| Sistema de build | Gradle direto, sem passar pelo exportador gráfico | `build_apk.sh`, `build_aab.sh`, `android/pgs/install.sh` | ABIs fixadas em `armeabi-v7a` e `arm64-v8a` nos dois scripts, o que evita carregar libs x86 inúteis |
| Target e min SDK reais | target 36, min 24 | `build_aab.sh:54`, `build_aab.sh:55`, `build_apk.sh:68` | conforme com o prazo de 2026-08-31 do Google. O preset do editor declarava 35 em `export_presets.cfg:29` e foi corrigido nesta fase |

## 2. Inventário do repositório por tópico de descoberta

Esta seção percorre, um a um, os tópicos que o `REQUIREMENTS.md` da fase exige descobrir e documentar. Nenhum foi omitido; onde não há nada, a linha diz `SEM-CODIGO` em vez de calar.

| Tópico | Existe? | Evidência | Completude | Observação |
|---|---|---|---|---|
| Engine | Sim | `.godot-version`, `scripts/godot_bin.sh` | Completo | ver seção 1 |
| Framework | Sim | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` | Completo | ver seção 1 — GDScript é a única "framework" do cliente |
| Linguagem | Sim | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` | Completo | ver seção 1 — GDScript no cliente, Java só na ponte |
| Plataforma | Sim | `export_presets.cfg:1-6` | Completo | ver seção 1 — só Android |
| Estrutura Android | Sim | `.gitignore:27`, `android/pgs/install.sh` | Completo | ver seção 1 |
| Módulo Android | Sim | `android/pgs/install.sh` | Completo | ver seção 1 — `android/pgs/` reaplicado a cada build |
| Sistema de build | Sim | `build_apk.sh`, `build_aab.sh` | Completo | ver seção 1 — Gradle direto |
| Package / application ID | Sim | `export_presets.cfg:36` | Completo | ver seção 1 — `org.playtable.app` |
| Autenticação | Sim, opcional | `core/services/PlayGamesManager.gd:45-61`, `android/pgs/java/org/playtable/pgs/PlayTablePGS.java:120-180` | Completo | Silent sign-in no boot mais botão manual; nunca bloqueia o app. |
| Banco de dados | Não existe | `SEM-CODIGO` | — | Sem SQLite nem equivalente: tudo é `ConfigFile` e JSON em `user://`. |
| Backend próprio | Não existe, por decisão | `docs/server/api-contract.md` | — | O domínio `playtable.ricasolucoes.com.br` existe; o servidor não. O contrato-base foi escrito nesta fase. |
| APIs externas | Sim, uma só | `android/pgs/gradle_deps.txt`, `android/pgs/README.md:18` | Completo | o SDK do Play Games v2 entra pela propriedade oficial `-Pplugins_remote_binaries` (`build_aab.sh:50`, `build_apk.sh:64`), sem `build.gradle` editado à mão. |
| Sistema de usuários | Não existe, por decisão (guest-only) | `SEM-CODIGO` | — | Não há conta local; o perfil é por instalação (`core/services/PlayerProfile.gd`). |
| Save local | Sim, em dois arquivos distintos | `core/save/SaveManager.gd`, `core/services/PlayerProfile.gd:373-390` | Completo | `SaveManager` (40 linhas) só guarda `master_volume` e `theme_dark`. **Armadilha:** o progresso do jogador não está no `SaveManager`. Quem procurar save por ali erra o alvo. |
| Progressão | Sim | `core/services/PlayerProfile.gd:41-125` | Completo | `lifetime_xp` monotônico, nível derivado, migração de perfil v1→v2 já implementada em `core/services/PlayerProfile.gd:424-448`. |
| Moedas | Não existe | `SEM-CODIGO` | — | Não há currency separada do XP, e nenhuma fase do roadmap pede uma. |
| XP | Sim, funil único | `core/services/RewardSystem.gd`, `shared/BaseGame.gd:272` | Completo | Todo XP passa pelo `RewardSystem`: partida, missão, conquista, maestria, liga e bônus diário. |
| Níveis | Sim, derivado do XP | `core/services/PlayerProfile.gd:41-125` | Completo | Nível é função do `lifetime_xp`, não um contador próprio — não dá para dessincronizar. |
| Ranking | Sim, local completo; pendente de id | `core/services/LeaderboardSync.gd`, `core/configs/play_games_ids.json` | Parcial | 9 placares; 4 são "menor é melhor" e já saem formatados certo. |
| Conquistas | Sim | `core/services/AchievementEngine.gd`, `core/configs/achievements.json` | Completo | 55 no catálogo, orientado a dados: o motor lê a regra, calcula o valor atual e compara com o alvo; adicionar conquista é editar JSON. |
| Missões | Sim | `core/services/QuestEngine.gd`, `core/configs/quests.json` | Completo | 11 diárias e 6 semanais no pool; sorteio determinístico por semente de data. |
| Eventos | Parcial: existe a Events API clássica do PGS, não a Game Stats | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java:267-275` | Parcial | 5 eventos catalogados, ids vazios. |
| Temporadas | Parcial, estático | `core/configs/liveops_config.json`, `core/services/LiveOpsManager.gd` | Parcial | `LiveOpsManager` (38 linhas) só lê o JSON local; não há como mudar a season sem novo build, e o próprio comentário do arquivo admite isso. |
| Recompensas | Sim, como funil de XP; não como "oferta" no sentido do Google | `core/services/RewardSystem.gd` | Parcial | Não existe conceito de oferta resgatável ligada ao Play Console. |
| Analytics | Não existe | `SEM-CODIGO` | — | Nenhum SDK de terceiro, nenhum Firebase. |
| Notificações | Não existe | `SEM-CODIGO` | — | Nenhuma ocorrência de FCM nem de notificação local. |
| Compras | Não existe | `SEM-CODIGO` | — | Nenhuma ocorrência de `BillingClient`. O tenet "Sem Compras" de `.planning/PROJECT.md` continua verdadeiro. |
| Monetização | Não existe, por decisão | `SEM-CODIGO` | — | Sem anúncio e sem compra; as únicas menções a AdMob no repositório são documentos explicando que não há. |
| Anti-cheat | Parcial e deliberadamente fino | `core/services/SecurityManager.gd` | Parcial | Limita XP por transação e por janela deslizante local; não há verificação server-side porque não há servidor. Correto para offline puro, insuficiente quando o servidor entrar (fase 10). |
| Sincronização | Sim para o PGS | `core/services/PlayGamesManager.gd:220-277`, `core/save/CloudSaveSync.gd` | Parcial | Fila persistida em `user://pgs_queue.json` com colapso de repetição; Cloud Save com merge campo a campo. Nada equivalente existe ainda para o servidor próprio — a fase 7.1 e a 8 herdam esta forma, por `docs/server/api-contract.md`. |
| Offline | Sim, é o modo base | `core/services/PlayGamesManager.gd:21-24` | Completo | Sem o singleton do plugin, `is_available()` devolve `false` e a gamificação inteira continua 100% local. É a "degradação sem mentir" que o próprio código documenta. |

## 3. O veredito da ponte PGS

Esta é a seção que muda o plano das fases seguintes, por isso vai em prosa, não em linha de tabela.

**O Godot não tem suporte nativo a Play Games Services. Então como este repositório fala com o SDK Java?**

1. **É um plugin Android nativo do Godot 4, compilado de fonte própria, versionado no repositório.** Não é simulação, não é `.aar` de terceiro, não é placeholder. `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` tem 446 linhas, estende `GodotPlugin` (formato de plugin v2 do Godot 4) e implementa: sign-in silencioso e interativo (`:120-180`), conquistas (`unlock`, `increment`, `setSteps`, `show`), placares (`submitScore`, `showLeaderboard`, `showAllLeaderboards`), eventos da API clássica (`:267-275`), Cloud Save por Snapshots (`:277-376`) e a checagem de suporte a Sidekick (`:397-413`).
2. **Usa as classes atuais do SDK, não as depreciadas.** Só `PlayGames.get*Client(activity)`; nenhuma chamada ao `Games` legado. O prazo de depreciação do Google não afeta este repositório. Evidência: `android/pgs/java/org/playtable/pgs/PlayTablePGS.java`.
3. **O registro usa o mecanismo oficial.** Meta-data `org.godotengine.plugin.v2.PlayTablePGS` em `android/pgs/AndroidManifest.inject.xml:15`; o SDK entra pela propriedade `-Pplugins_remote_binaries` do exportador Gradle do Godot (`android/pgs/README.md:18`, `build_aab.sh:50`, `build_apk.sh:64`). Não há `build.gradle` editado à mão.
4. **A degradação é honesta.** O GDScript só fala com o plugin por `Engine.get_singleton("PlayTablePGS")`; sem o singleton — fora do Android, sem login, ou em build F-Droid — `is_available()` devolve `false` e a gamificação inteira segue local (`core/services/PlayGamesManager.gd:21-24`). E `android/pgs/install.sh` reaplica a fonte versionada sobre `android/build/` a cada build, resolvendo o problema real de o template do Godot apagar a integração.
5. **O que falta não é código: são os identificadores do Play Console.** `core/configs/play_games_ids.json` tem `app_id` vazio e as 55 conquistas, 9 placares e 5 eventos com valor `""`. Enquanto estiverem vazios, `_map()` recusa enviar de propósito (`core/services/PlayGamesManager.gd:118-123`) — id inventado seria aceito em silêncio pelo servidor e daria a impressão de que a integração funciona. O passo a passo manual já está em `android/pgs/README.md:20-47` e `docs/google-play/play-console-checklist.md`.

**Isto reclassifica as fases 3, 4 e boa parte da 9 de engenharia para configuração no Play Console.** O que falta de código, de verdade, são só três coisas — Recall API (`SEM-CODIGO`), Game Stats API nova (`SEM-CODIGO`; o que existe é a Events API clássica, que é outro produto, não substitui o `GameStatsClient`) e Play Integrity (`SEM-CODIGO`, e depende de backend).

## 4. Matriz de reaproveitamento por fase do roadmap

Uma linha por fase do `.planning/ROADMAP.md`, as 13 originais mais a 7.1 inserida no plano 01-01. O veredito usa só três palavras — `Substancialmente entregue`, `Parcial`, `Do zero` — para que quem planejar a fase seguinte saiba, antes de ler qualquer código, se está fechando lacuna ou construindo do zero.

| Fase | O que a fase pedia | O que já existe (evidência) | O que falta de verdade | Veredito |
|---|---|---|---|---|
| Fase 1 — Discovery e Auditoria | Mapear o repositório e produzir os dois documentos de entrada de planejamento | `docs/google-play/compatibility-audit.md`, `docs/google-play/current-requirements.md` | nada — é esta fase | Substancialmente entregue |
| Fase 2 — Fundação Gamification | Event bus e engines de gamificação desacoplados do gameplay | `core/services/GameEventBus.gd` (25 sinais) e 20 autoloads reagindo em ordem declarada (`project.godot:27-31`) | feature flag remota; o restante já roda | Substancialmente entregue |
| Fase 3 — Play Games Services v2 | Login, fallback offline, idempotência, reconexão, Recall API | sign-in, fila e idempotência (`core/services/PlayGamesManager.gd:220-277`) | Recall API (`SEM-CODIGO`) e a configuração do Console | Parcial |
| Fase 4 — Achievements | Catálogo de 40-60 conquistas e matriz de documentação | 55 em `core/configs/achievements.json`, motor em `core/services/AchievementEngine.gd`, matriz em `docs/google-play/achievement-matrix.md` | criar as 55 no Console | Substancialmente entregue |
| Fase 5 — Game Stats | Enviar stats via `GameStatsClient` e gerar CSVs para o Console | CSVs com nome certo em `docs/google-play/game-stats/` | o `GameStatsClient` em si — a Events API clássica (`android/pgs/java/org/playtable/pgs/PlayTablePGS.java:267-275`) **não** o substitui; colunas dos CSVs a reconferir | Do zero |
| Fase 6 — XP, Quests, Streaks | XP global, níveis, missões, streaks, coleções | `core/services/PlayerProfile.gd:41-125`, `core/services/QuestEngine.gd`, streak em `core/services/PlayerProfile.gd:238-267`, coleção em `core/services/CollectionSystem.gd` | ajustes finos, se algum surgir no uso | Substancialmente entregue |
| Fase 7 — Social e Leaderboards | Rankings e recursos sociais | placares e sync (`core/services/LeaderboardSync.gd`) | "amigos" e desafio social | Parcial |
| Fase 7.1 — Multiplayer Online | Salas, convite, partida online contra o servidor próprio | regras de base em `docs/server/api-contract.md` | tudo — depende do servidor, que fica fora deste repositório | Do zero |
| Fase 8 — LiveOps | Seasons, flags remotas, configuração dinâmica sem novo build | flags locais em `core/services/LiveOpsManager.gd` | o fetch remoto — é stub confesso no próprio comentário do arquivo (38 linhas) | Parcial |
| Fase 9 — Sidekick | Overlay testado extensivamente, publicação, design de Game Tips | detecção de suporte pronta e correta (`android/pgs/java/org/playtable/pgs/PlayTablePGS.java:397-413`) | o QA real (immersive mode, troca de conta, lifecycle) não foi rodado; checklist em `docs/google-play/testing.md` | Parcial |
| Fase 10 — Segurança e Anti-cheat | Validação server-side, Play Integrity, resolução de conflito de Cloud Save | validação local de XP (`core/services/SecurityManager.gd`); resolução manual de conflito já em `core/save/CloudSaveSync.gd` | tudo server-side; Play Integrity exige backend (`SEM-CODIGO`) | Parcial |
| Fase 11 — QA e Sincronização | Testes de autenticação, offline-first, fila local, matriz de dispositivos | 32 arquivos de teste GUT em `tests/gdscript/`, com `tests/run_gut.sh` | a matriz de aparelhos com e sem Sidekick | Parcial |
| Fase 12 — Performance | FPS, memória, battery, startup, ANRs | base de suíte automatizada em `tests/run_gut.sh` | nenhuma medição de performance registrada | Do zero |
| Fase 13 — Release e Rollout | Faixas de lançamento, observabilidade, checklist do Console | `docs/google-play/play-console-checklist.md` e `docs/google-play/rollout.md` já existem e estão atualizados | executar o rollout de verdade | Parcial |

## 5. Débito técnico e conflitos

Onze itens vieram da pesquisa desta fase (seção 4 de `01-RESEARCH.md`); o décimo segundo foi encontrado durante a escrita deste documento e o décimo terceiro durante o portão final de testes. Nove dos treze já foram corrigidos pelos planos 01-01 a 01-03; três ficam abertos para uma fase futura específica.

| # | Conflito ou débito | Evidência (arquivo:linha) | Risco | Situação |
|---|---|---|---|---|
| 1 | `docs/google-play/current-requirements.md` dava o Cloud Save como só local, ignorando `core/save/CloudSaveSync.gd` | `docs/google-play/current-requirements.md`, `core/save/CloudSaveSync.gd` | Alto | Corrigido nesta fase (reescrito no plano 01-02) |
| 2 | `docs/google-play/compatibility-audit.md` afirmava "Gamificação Existente: Extremamente básica e acoplada" e "Arquitetura Event-Driven Ausente" contra `core/services/GameEventBus.gd` (25 sinais, 20 autoloads reagindo) | `core/services/GameEventBus.gd` | Alto | Corrigido nesta fase (este documento) |
| 3 | `docs/PLAY_GAMES_SIDEKICK.md:62` afirmava a dependência Gradle `com.google.android.play:sidekick:1.0.16`, ausente de `android/pgs/gradle_deps.txt` | `docs/PLAY_GAMES_SIDEKICK.md:62`, `android/pgs/gradle_deps.txt` | Médio | Corrigido nesta fase (plano 01-03). A dependência não é necessária: a publicação é por AAB |
| 4 | `docs/google-play/testing.md:6` mandava validar fallback pelo `AchievementUI.gd`, removido; quem faz o papel é `shared/ui/RewardToast.gd` | `docs/google-play/testing.md:6` | Médio | Corrigido nesta fase (plano 01-03) |
| 5 | `docs/google-play/quests.md` documentava 5 missões com ids inventados, contra 17 reais em `core/configs/quests.json` | `docs/google-play/quests.md`, `core/configs/quests.json` | Baixo/Médio | Corrigido nesta fase (plano 01-03) |
| 6 | Docstring de `core/services/AchievementEngine.gd:5` dizia "50 conquistas" contra 55 em `core/configs/achievements.json` | `core/services/AchievementEngine.gd:5`, `core/configs/achievements.json` | Baixo | Corrigido nesta fase (plano 01-03) |
| 7 | `export_presets.cfg:29` declarava `target_sdk="35"` contra `build_aab.sh:54` (`36`) e o prazo de 2026-08-31 | `export_presets.cfg:29`, `build_aab.sh:54` | Médio | Corrigido nesta fase (plano 01-03) |
| 8 | `.planning/PROJECT.md` afirmava "sem servidores, sem dependências proprietárias", contra a decisão travada das três camadas | `.planning/PROJECT.md` | Alto | Corrigido nesta fase (plano 01-01) |
| 9 | `core/estatisticas/` é diretório vazio; `docs/ARQUITETURA_E_STACK.md:15` o descrevia como persistência de histórico. A estatística real mora em `core/services/PlayerProfile.gd` (`per_game`) | `docs/ARQUITETURA_E_STACK.md:15`, `core/services/PlayerProfile.gd` | Baixo | Corrigido nesta fase na documentação; o diretório em si não é rastreado pelo git e não gera commit |
| 10 | `docs/google-play/game-stats/` versiona `.csv.import` e `.translation` binários, gerados pelo importador do Godot porque todo `.csv` na árvore do projeto vira recurso de Tradução por padrão | `docs/google-play/game-stats/PlayerGameEvent.csv.import` | Baixo | Aberto — fase 5 (revisar a configuração de importação antes de gerar os CSVs definitivos) |
| 11 | Nenhuma fase do `ROADMAP.md` cobria Multiplayer Online | `.planning/ROADMAP.md` | Alto | Corrigido nesta fase (`.planning/ROADMAP.md`, fase 7.1 inserida no plano 01-01) |
| 12 | `.planning/ROADMAP.md:3` ainda lê "Coleção Completa de Jogos Offline (19 Jogos)" e a lista de tabuleiro para em 14 itens, sem a Spider — mas `games/` tem 20 diretórios, incluindo `paciencia_spider` (adicionado no commit `bfff3bb`) | `.planning/ROADMAP.md:3`, `games/paciencia_spider/` | Baixo | Aberto — quem next tocar o roadmap corrige a contagem e a lista |
| 13 | A suíte GUT não é determinística: duas execuções do mesmo commit deram 562/562 e 560/562. Falharam `test_turno_da_ia.gd:47` (`a vez voltou para o jogador`, do reversi — dependente de tempo) e `test_difficulty.gd:197-198` (`[3] expected to equal [2]: dois pagamentos`, `[300] expected to equal [200]` — um pagamento de XP a mais, o que indica estado vazando entre testes) | `tests/gdscript/integration/test_turno_da_ia.gd:47`, `tests/gdscript/unit/test_difficulty.gd:197` | Alto | Aberto — fase 11 (QA). Uma suíte que muda de resultado sem mudar código não serve de portão de regressão: reprovação vira ruído e ninguém investiga |

## 6. Conclusão e recomendação de sequenciamento

1. **O gargalo das fases 3, 4 e 9 não é engenharia: é configuração no Play Console**, e está fora do controle deste repositório. `core/configs/play_games_ids.json` tem `app_id` vazio e 69 ids vazios (55 conquistas, 9 placares, 5 eventos). Enquanto isso não for preenchido, nenhuma quantidade de código faz uma conquista aparecer para o jogador.
2. **O prazo do Level Up para Sidekick e Achievements venceu em 2026-07-31** — hoje é 2026-08-31. Isto não é trabalho futuro: é achado com data. O de Cloud Save vence em **2026-11-30**, e o código de Cloud Save já está pronto (`core/save/CloudSaveSync.gd`), o que torna esse prazo alcançável se a configuração do Console andar. Fonte: `https://android-developers.googleblog.com/2026/03/level-up-your-game.html`.
3. **Sequência recomendada:** primeiro a configuração do Console (destrava 3, 4, 7 e 9 de uma vez, seguindo `docs/google-play/play-console-checklist.md`); depois a fase 5 (Game Stats), que é o único bloco genuinamente do zero dentro do PGS; depois 8 e 10, que dependem do servidor; a 7.1 por último dentro do bloco online, porque depende do servidor mais do que qualquer outra.
4. **Nenhuma fase seguinte deve criar sistema paralelo.** Onde já há autoload cobrindo o assunto, estenda-o. As três formas a reaproveitar, e não recriar, são: o `core/services/GameEventBus.gd` para qualquer sinal novo, a fila de `core/services/PlayGamesManager.gd:220-277` para qualquer transporte que possa falhar, e o `shared/BaseGame.gd:272` como funil único de fim de partida.
5. **O que ainda não é certeza.** Remeta à seção 5 de `docs/google-play/current-requirements.md`, que lista os cinco itens de confiança MÉDIA ou BAIXA e a fase que reconfere cada um. A auditoria não transforma incerteza em fato.
6. **Um débito fora do escopo do Google, mas que quem planejar a próxima fase precisa ver.** O item 12 da seção 5 não é sobre PGS nem Level Up: o `.planning/ROADMAP.md` conta 19 jogos e lista 14 de tabuleiro, mas `games/` já tem 20 diretórios, com `paciencia_spider` fora da lista. Corrigir a contagem não é tarefa desta fase — nenhum arquivo além de `docs/google-play/compatibility-audit.md` e `CHANGELOG.md` foi tocado aqui — mas fica registrado para quem mexer no roadmap em seguida.
