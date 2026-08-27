# Matriz de Qualidade & Performance (Google Play Level Up)

Para o **PlayTable** manter os benefícios algorítmicos do Level Up, os seguintes KPIs de performance (Android Vitals) devem ser monitorados vigorosamente nas builds exportadas:

## 1. Frame Pacing e Estabilidade
- O Gamification Engine e o `LeaderboardSync` operam de forma totalmente assíncrona baseada em eventos.
- Não existem `_process(delta)` pesados iterando sobre chaves de conquistas.
- **Meta**: 60 FPS consistentes em dispositivos Mid-range, sem engasgos (jank) quando o jogador recebe uma notificação de Quest Concluída.

## 2. Inicialização (Cold Start)
- O carregamento da configuração via `LiveOpsManager` em `_ready()` lê arquivos JSON locais, durando < 2ms.
- A requisição silenciosa de login do `PlayGamesManager` não trava a Main Thread do Godot.
- **Meta**: App acessível na Scene Principal em < 1.5s.

## 3. Crash e ANR
- Como lidamos com JNI/Android SDKs através de plugins Godot, a chance primária de ANR (Application Not Responding) está no bloqueio de Threads C++ esperando resposta de Java (Play Services).
- A refatoração atual usou exclusivamente Signals (Callbacks Assíncronos). Se o Google Play cair, o app Godot sobrevive ileso.
- **Alvo**: Crash rate inferior a 0.20% (Padrão de excelência da Play Store).
