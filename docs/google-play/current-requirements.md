# Requisitos Atuais do Google Play Games, Level Up e Sidekick

**Levantado em:** 2026-08-31
**Método:** cada requisito foi buscado na documentação oficial do Google nesta data e confrontado com o código deste repositório, lido arquivo por arquivo. Onde a coluna "Implementação" traz `arquivo:linha`, a afirmação foi verificada ali. Onde traz `SEM-CODIGO`, a ausência foi confirmada por varredura (`grep`) em todo o repositório, fora de `android/build/` (que é gerado e descartável).
**Substitui:** a versão de 2026-08-24, que dava o Cloud Save como "apenas local" e o catálogo de conquistas como "~16". As duas afirmações eram falsas na data em que foram escritas.

## Legenda de status

| Símbolo | Significado |
|---|---|
| ✅ Conforme | O requisito está atendido pelo código deste repositório — [ver evidência na coluna Implementação](#1-play-games-services-v2-no-cliente) |
| 🟡 Parcial | Parte existe, parte falta; a coluna "Situação atual" diz qual é qual — https://developer.android.com/games/guidelines |
| 🔴 Ausente | Nada no código atende a isto — `SEM-CODIGO` |
| 🟦 Só Console | O código está pronto; o que falta é configuração no Play Console, fora deste repositório — `core/configs/play_games_ids.json` |
| ⛔ Prazo vencido | Prazo oficial já passou — https://android-developers.googleblog.com/2026/03/level-up-your-game.html |
| ⚪ Decisão de produto | Não é trabalho de engenharia; é aceite de termos ou escolha comercial — `SEM-CODIGO` |

A coluna **Confiança** vale para a leitura da fonte oficial, não para a leitura do código (essa é sempre ALTA, porque foi lida direto do arquivo): ALTA = múltiplas fontes oficiais concordantes; MÉDIA = resumo de uma página, não citação literal; BAIXA = não foi encontrada página oficial.

## 1. Play Games Services v2 no cliente

Contexto que muda o peso desta seção inteira: **o Godot não tem suporte nativo a Play Games Services**, e este repositório resolveu isso com um plugin Android próprio, versionado, de 446 linhas — `android/pgs/java/org/playtable/pgs/PlayTablePGS.java`. Não é simulação, não é `.aar` de terceiro, não é placeholder. As linhas abaixo apontam para dentro dele.

| Requisito | Fonte oficial | Impacto | Situação atual (verificada no código) | Implementação (arquivo:linha) | Status | Confiança |
|---|---|---|---|---|---|---|
| **Sign-in v2 silencioso no boot** | `https://developer.android.com/games/pgs/android/android-signin`, `https://developers.google.com/games/services/android/migrate-to-v2` | bloqueia Level Up se o app abrir com tela de login obrigatória | silent sign-in no boot mais `sign_in_interactive()` para o botão manual; nunca bloqueia o app | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java:120-180`, `core/services/PlayGamesManager.gd:45-61` | ✅ Conforme | ALTA |
| **Não usar as APIs depreciadas do SDK** (some do SDK a partir de maio/2026; para de funcionar em julho/2028) | `https://developers.google.com/games/services/android/signin` | prazo de migração para quem ainda chama `Games.get*Client()` | a ponte usa só `PlayGames.get*Client(activity)`; nenhuma chamada ao `Games` legado foi encontrada | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` | ✅ Conforme | ALTA |
| **Achievements API v2** (`unlock`/`increment` com cache local; variantes `*Immediate` devolvem `Task` com sucesso ou falha explícita) | `https://developer.android.com/games/pgs/android/achievements` | a escolha entre cacheado e imediato decide quem controla a fila offline | a ponte usa as variantes **Immediate** de propósito, porque a fila offline fica do lado GDScript e colapsa repetição antes de enviar; escolha deliberada e comentada no código | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java:46-53`, `core/services/PlayGamesManager.gd:243-265`, `core/services/AchievementEngine.gd` | ✅ Conforme | ALTA |
| **Leaderboards** (`submitScore`, `showLeaderboard`) | `https://developer.android.com/games/guidelines` | base do pilar social do Level Up | 9 placares catalogados, 4 deles "menor é melhor" (tempo e jogadas) já formatados antes do envio; falta só o id do Console | `core/services/LeaderboardSync.gd`, `core/configs/play_games_ids.json`, `android/pgs/java/org/playtable/pgs/PlayTablePGS.java` | 🟦 Só Console | ALTA |
| **Cloud Save / Saved Games** (`SnapshotsClient`, `open(name, autoCreate, resolutionPolicy)`, `commitAndClose()`; a API **não** está deprecada — doc atualizada em 2026-06-16) | `https://developer.android.com/games/pgs/android/saved-games` | prazo de 2026-11-30 do Level Up depende disto | implementado com `RESOLUTION_POLICY_MANUAL` e merge campo a campo (contador fica com o maior valor, conjunto vira união, data fica com a mais recente) — mais robusto que o "pega o mais recente" do exemplo da doc | `core/save/CloudSaveSync.gd`, `android/pgs/java/org/playtable/pgs/PlayTablePGS.java:277-376` | ✅ Conforme | ALTA |
| **Events API clássica** (`EventsClient.increment`) | `https://developer.android.com/games/pgs/gamestats` | **não** conta para o requisito de Game Stats do Level Up — são produtos diferentes | implementada; 5 eventos catalogados, ids vazios. Não confundir com a Game Stats API (linha 9 deste documento) | `android/pgs/java/org/playtable/pgs/PlayTablePGS.java:267-275`, `core/configs/play_games_ids.json` | ✅ Conforme (mas não substitui Game Stats) | ALTA |
| **Degradar sem mentir quando o PGS não existe** (fora do Android, sem login, ou build F-Droid sem o plugin) | `https://developer.android.com/games/guidelines` | é o que sustenta a decisão travada de offline-first | o GDScript só fala com o plugin por `Engine.get_singleton("PlayTablePGS")`; sem o singleton, `is_available()` devolve `false` e a gamificação inteira segue 100% local. Fila persistida em `user://pgs_queue.json`, com colapso de repetição por tipo de operação | `core/services/PlayGamesManager.gd:21-24`, `core/services/PlayGamesManager.gd:220-277` | ✅ Conforme | ALTA |
| **Identificadores do Play Console** (`app_id` e um id opaco `CgkI...EAQ` por conquista, placar e evento) | `https://developer.android.com/games/pgs/android/android-signin` | **é o gargalo real de todo o bloco acima.** Sem ids, nada aparece para o jogador, por mais completo que o código esteja | `app_id` vazio; 55 conquistas, 9 placares e 5 eventos, todos com valor `""`. O `_map()` recusa enviar id vazio de propósito — id inventado seria aceito em silêncio pelo servidor e daria a impressão de que a integração funciona. O passo a passo manual já está documentado | `core/configs/play_games_ids.json`, `core/services/PlayGamesManager.gd:118-123`, `android/pgs/README.md:20-47`, `docs/google-play/play-console-checklist.md` | 🟦 Só Console | ALTA |

Regras que valem para toda linha, aqui e na seção seguinte:
- Nunca escreva "implementado" sozinho. Ou vem `arquivo:linha`, ou vem `SEM-CODIGO`.
- Não invente número de linha. Se não souber a linha exata, cite só o caminho do arquivo.
- Barras verticais dentro de uma célula precisam de escape (`\|`), senão quebram a coluna.
