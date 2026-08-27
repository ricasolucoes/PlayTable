# Integração Play Games Sidekick

O Play Games Sidekick provê um overlay poderoso para Android 13+. Por causa das ferramentas como captura de tela, PIP de vídeos e dicas com IA, a integração correta do *Lifecycle* é vital.

## Lifecycle Godot vs Android

### O Problema do Immersive Mode
Jogos Godot costumam operar em *Immersive Mode* (escondendo a barra de status). Quando o jogador puxa a aba para abrir o Sidekick, o Android envia um evento de perda de foco e desenha um overlay. Se o jogo não pausar adequadamente, o jogador perderá turnos/gameplay ou terá os controles bloqueados temporariamente.

### A Solução Implementada (`SceneManager.gd`)
A engine foi configurada para escutar `NOTIFICATION_APPLICATION_FOCUS_OUT` e `NOTIFICATION_APPLICATION_FOCUS_IN`. 

1. **FOCUS_OUT (Sidekick Aberto)**: `get_tree().paused = true`. Toda física, AI e timers do jogo são congelados. O renderizador ainda exibe o último frame (o Sidekick tira proveito visual disso).
2. **FOCUS_IN (Sidekick Fechado)**: `get_tree().paused = false`. A partida continua imediatamente, sem glitchs de áudio.

## UX e Input
Nenhum botão de UI no `shared/ui/` (como botões de Voltar ou Pause) ficará coberto pelo Sidekick, pois a Google instrui o overlay a respeitar as bordas limpas laterais em landscape ou o menu inferior em portrait. O jogo, sendo renderizado em "Expand", adapta-se organicamente a margens *safe area*.

## Requisito de aparelho

`PlayGamesManager.is_sidekick_supported()` responde consultando o plugin, que
checa **Android 13 (API 33)** e **memória total do aparelho**. A versão anterior
devolvia `true` para qualquer Android, e a interface prometia um overlay que não
abriria em metade dos aparelhos.

## Feedback quando o Sidekick não está lá

Fora do Android, sem login, ou em aparelho que não suporta o overlay, quem avisa
o jogador é o `RewardToast` (`shared/ui/RewardToast.gd`), pendurado
automaticamente pelo `BaseGame` em toda partida. Ele não depende de Play Games
nenhum: escuta o `GameEventBus` e mostra XP, nível, conquista, missão, maestria,
liga e sequência.

Existia um `AchievementUI.gd` para esse papel, mas ele não tinha cena, nunca era
instanciado por ninguém, e seus `@onready` apontavam para nós que não existiam
em lugar algum. Foi removido.
