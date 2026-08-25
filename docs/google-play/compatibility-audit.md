# Auditoria de Compatibilidade: Google Play Games & Gamificação Avançada

## 1. Identificação do Projeto
- **Engine**: Godot Engine 4.3
- **Framework/Linguagem**: GDScript
- **Plataforma Principal**: Android
- **Estrutura Android**: Exportação padrão do Godot (template customizado em `android/build/`).
- **Sistema de Build**: Scripts de exportação shell (`build_aab.sh`, `build_apk.sh`) integrados com Gradle.
- **Package/Application ID**: Configurável via export presets ou no manifesto Android.
- **Autenticação Atual**: O arquivo `PlayGamesManager.gd` possui integração inicial com PGS v2 (Silent Sign-In via plugin GodotPlayGamesServices).

## 2. Arquitetura e Mapeamento
- **Gameplay**: 16 jogos independentes dentro da pasta `games/`. Componentes visuais em `shared/`.
- **Camada Central (Core)**: Módulos de sistema como `SaveManager.gd`, `SceneManager.gd`, `LocaleManager.gd`, `AudioManager.gd` e `PlayGamesManager.gd`.
- **Backend / Online**: Atualmente offline-first. Não há backend próprio (Client-authoritative).
- **Sistema de Save Atual**: Persistência local (`core/save/SaveManager.gd` e histórico em `core/estatisticas/`).
- **Gamificação Existente**: Extremamente básica e acoplada. Apenas um mapeamento fixo de constantes para IDs do Play Console em `PlayGamesManager.gd`.
- **Moedas, XP, Níveis**: Inexistentes.
- **Missões, Eventos, Temporadas, Recompensas**: Inexistentes.
- **Anti-cheat**: Nenhum. Como é offline e client-authoritative, requer implementações básicas de idempotência e validações lógicas mínimas para integridade local.

## 3. Avaliação de Risco e Débito Técnico
- **Arquitetura Event-Driven Ausente**: O jogo não possui um barramento de eventos (Event Bus) focado no gameplay. As conquistas atuais dependem de chamadas imperativas diretas.
- **Hardcoding**: IDs de conquistas e placares em `PlayGamesManager.gd` não são orientados a configuração externa ou catálogo escalável.
- **Cloud Save / Recall**: Não integrados atualmente. O progresso fica preso ao dispositivo (perigoso para retenção D30+).
- **Sidekick e UI/UX**: Embora a dependência do Sidekick conste na documentação (`PLAY_GAMES_SIDEKICK.md`), não há garantias de que o overlay, ao abrir, pause adequadamente o Godot e não quebre o lifecycle.
- **Falta de Loops de Engajamento**: Não existem motivos de curto/médio prazo (diários ou semanais) para o jogador retornar além da pura vontade de jogar offline.

## 4. Requisitos Google Play (Status Atual)
- **Play Games Services v2**: Implementado parcialmente (login e APIs de unlock). Falta tratamento robusto de falhas e fallback inteligente.
- **Sidekick**: Integrado no Gradle, necessita validação rigorosa de Game Tips e lifecycle.
- **Achievements / Leaderboards**: Integrados, mas insuficientes para "Level Up" avançado (necessitamos de 40+).
- **Game Stats, Cloud Save, Recall, Quests, Rewards, Streaks**: Não implementados.

## 5. Conclusão da Fase 0
O projeto é limpo e modular do ponto de vista do gameplay (uma pasta para cada jogo), o que facilita a criação de uma camada global (Gamification Engine) que observará todos os jogos de forma uniforme através de um `GameEventBus`. A ausência de backend significa que a camada de gamificação precisará ser muito resiliente localmente e usar o PGS como "backend de fato" para conquistas, stats e backup.
