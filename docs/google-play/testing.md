# Testes de Garantia de Qualidade (QA) - Play Games Sidekick

## 1. Escopo de Validação Android
O suporte final à Gamificação Event-Driven e Lifecycle requer testes nos seguintes cenários antes da promoção do AAB de *Internal* para *Production*:

- [ ] **Android 12- (Aparelhos Legados)**: Validar se o jogo executa as rotinas diárias e fallback de UI da `AchievementUI.gd` sem crashar, ignorando as chamadas exclusivas do Sidekick.
- [ ] **Android 13+ (Sidekick Elegível)**: Validar o Swipe nativo do Play Games.
  - O Godot deve acionar o `NOTIFICATION_APPLICATION_FOCUS_OUT`.
  - A música (`AudioManager`) deve ser suprimida ou tratada conforme a necessidade.
  - A Engine (`get_tree().paused`) não pode rodar lógicas em background.

## 2. Teste de Autenticação
- [ ] Troca rápida de conta (Fast Account Switching) pelo overlay do Sidekick: Confirmar se o ID da sessão do `PlayGamesManager` é invalidado e reinstanciado.
- [ ] Modo Avião (Offline Test): Ganhar XP, subir de nível e ligar a internet. Verificar se o `CloudSaveSync` efetua o merge.

## 3. Testes Unitários de Gamificação (Gut Framework)
Os seguintes domínios precisam de mocks:
- `GameEventBus` -> Simular 10 vitórias seguidas -> Afirmar que a `AchievementEngine` destrava "ACH_WIN_10".
- `SecurityManager` -> Simular injeção de 50.000 XP -> Afirmar que a requisição é rejeitada e logada.
