# Requisitos Atuais: Google Play Games & Gamificação

Este documento rastreia os requisitos oficiais atuais para o uso dos recursos do Google Play Games Services, Level Up e Sidekick.
*(Baseado nas diretrizes atuais do Google Play Console).*

## 1. Google Play Games Services v2
- **Requisito**: Implementação do SDK v2 (`play-services-games-v2`). O login deve ser preferencialmente silencioso e acionado no início do app.
- **Fonte Oficial**: Documentação do Play Games Services.
- **Impacto**: Bloqueia certificação Level Up se houver pop-ups excessivos ou fluxo de login desatualizado.
- **Situação Atual**: Implementado parcialmente (`PlayGamesManager.gd`).
- **Status**: ⚠️ **Requer Revisão** (Tratamento de lifecycle e falhas).

## 2. Play Games Sidekick
- **Requisito**: Android App Bundle (AAB), Android 13+ (API 33+), mínimo 3GB de RAM. Inclusão da biblioteca `com.google.android.play:sidekick`.
- **Fonte Oficial**: Documentação do Sidekick.
- **Impacto**: Essencial para a exibição do overlay, dicas da IA (Gemini) e captura de tela/vídeo nativa.
- **Situação Atual**: Listado no `PLAY_GAMES_SIDEKICK.md` como incluído no gradle, mas sem testes de UI/UX sistêmicos.
- **Status**: ⚠️ **Requer Testes Reais**.

## 3. Achievements (Conquistas) e Level Up
- **Requisito**: Ter um sistema profundo (o programa Level Up exige número significativo de conquistas bem distribuídas, idealmente 40+ para reter engajamento, com feedback visual nativo). Pelo menos 4 conquistas devem ser desbloqueáveis na primeira hora.
- **Fonte Oficial**: Requisitos do Level Up.
- **Impacto**: Sem isso, o jogo perde prioridade algorítmica na loja.
- **Situação Atual**: Mapeadas ~16 conquistas básicas no `PlayGamesManager.gd`. Insuficiente para as diretrizes avançadas.
- **Status**: 🔴 **Requer Implementação (Fase 3)**.

## 4. Game Stats & Progression Stat
- **Requisito**: Integrar o `Game Stats API` para reportar estatísticas globais (ex: Partidas Jogadas, Inimigos Derrotados, Tempo Jogado) e definir um `Progression Stat` (ex: Nível do Jogador ou XP).
- **Fonte Oficial**: Documentação Game Stats.
- **Impacto**: Alimenta os Streaks, Quests e o Perfil do Jogador no ecossistema Google Play.
- **Situação Atual**: Não implementado.
- **Status**: 🔴 **Requer Implementação (Fase 4)**.

## 5. Cloud Save (Saved Games)
- **Requisito**: Integrar a API de Saved Games para persistir o progresso do usuário e recuperá-lo em outros dispositivos (ou reinstalações).
- **Fonte Oficial**: Documentação Cloud Save.
- **Impacto**: Fundamental para retenção de longo prazo. O Sidekick exibe status de sincronização.
- **Situação Atual**: O `SaveManager.gd` atua apenas localmente.
- **Status**: 🔴 **Requer Implementação**.

## 6. Recall API
- **Requisito**: Associar contas in-game locais (caso existam) aos perfis PGS usando a Recall API (PGRR).
- **Fonte Oficial**: Documentação Recall API.
- **Impacto**: Evita perda de contas e facilita transição multi-dispositivo sem amarrar IDs PII.
- **Situação Atual**: Sem sistema de contas locais online, o jogo é guest offline. 
- **Status**: ⚪ **Avaliar Necessidade** (Como é offline, Cloud Save puro pode bastar).

## 7. Play Points & Play Pass
- **Requisito**: Não obrigatório, mas recompensas devem estar prontas para integração de marketing com o Google.
- **Impacto**: Boost de monetização / downloads orgânicos.
- **Situação Atual**: Ausente.
- **Status**: ⚪ **Avaliar Necessidade**.
