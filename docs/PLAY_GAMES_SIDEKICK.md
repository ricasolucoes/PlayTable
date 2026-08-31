# 🎮 Google Play Games & Play Games Sidekick: Guia de Integração

Este documento explica detalhadamente a plataforma **Google Play Games**, o recurso **Play Games Sidekick**, seus requisitos de sistema, benefícios de engajamento e a implementação técnica realizada no **PlayTable**.

---

## 🌟 1. O que é o Google Play Games (PGS v2)?

O **Google Play Games Services (PGS)** é o ecossistema e conjunto de serviços da Google que conecta jogos Android e PC (Google Play Games no Windows) a uma identidade única de jogador:

- **Autenticação Automática (Zero-Click Sign-in):** Com o PGS v2, o login ocorre silenciosamente em segundo plano, sem interrupções de telas pop-up excessivas.
- **Conquistas (Achievements):** Sistema unificado de troféus, notificações visuais do sistema operacional e recompensas de XP para a conta Google do jogador.
- **Placares de Líderes (Leaderboards):** Tabelas de classificação públicas e entre amigos para pontuações, menores tempos e taxas de vitórias.
- **Sincronização em Nuvem (Cloud Save / Saved Games):** Continuidade entre múltiplos dispositivos (celulares, tablets e PC).
- **Google Play Games no PC:** Experiência otimizada com suporte a tela cheia, teclado e mouse com emulação nativa no Windows.
- **Programa Level Up:** Selo de qualidade da Google que premia jogos com boa integração de PGS com maior alcance orgânico e promoções na loja.

---

## 🤖 2. O que é o Play Games Sidekick?

O **Play Games Sidekick** é o **overlay (painel flutuante de sobreposição) inteligente e assistente em tempo real** da Google integrado diretamente à experiência dos jogos Android.

### 💡 Principais Funcionalidades para os Jogadores

1. **Assistente de Jogo com IA (Gemini Live):**
   - Oferece dicas estratégicas, respostas a dúvidas em tempo real e guias sem precisar sair do jogo ou alternar de aplicativo.
2. **Utilitários Rápidos de Jogador:**
   - Gravação de tela (Screen Recorder) em alta resolução.
   - Captura instantânea de screenshots.
   - Transmissão ao vivo (Live Stream) direta para o YouTube.
   - Modo "Não Perturbe" / Game Focus para bloquear notificações durante partidas competitivas.
3. **Perfil, Conquistas & Streaks:**
   - Acesso imediato ao status de conquistas, dias seguidos jogando (streaks) e nível do Gamer Profile.
4. **Recompensas & Monetização Amigável:**
   - Consulta e resgate de pontos **Play Points**, cupons do **Google Play Pass** e missões ativas da Google Play.
5. **Vídeos e Dicas da Comunidade:**
   - Janela flutuante Picture-in-Picture (PiP) com tutoriais oficiais e vídeos de criadores de conteúdo.

---

## 📋 3. Requisitos de Sistema para o Sidekick

| Requisito | Especificação |
| :--- | :--- |
| **Sistema Operacional** | Android 13 (API Level 33) ou superior |
| **Memória RAM** | Mínimo de 3 GB de RAM no dispositivo |
| **Distribuição** | Instalado via Google Play Store com Play Games Services ativo |
| **Formato de Publicação** | Android App Bundle (`.aab`) assinado |

---

## 🛠️ 4. Integração Técnica no PlayTable

No PlayTable, a integração com o Play Games e o Sidekick foi estruturada em três camadas com **total isolamento e segurança** para preservar o funcionamento offline e as compilações independentes (F-Droid):

### A. Dependências Gradle (`android/pgs/gradle_deps.txt`)
O arquivo real de dependências é `android/pgs/gradle_deps.txt`, com só estas duas linhas — nada de `build.gradle` editado à mão:
```text
com.google.android.gms:play-services-games-v2:20.1.2
com.google.android.gms:play-services-auth:21.2.0
```
O SDK entra pela propriedade oficial `-Pplugins_remote_binaries` do exportador Gradle do Godot (usada em `build_apk.sh` e `build_aab.sh`), que lê justamente esse arquivo.

A dependência `com.google.android.play:sidekick` **não** está na lista, e não precisa estar: pela documentação oficial atual (<https://developer.android.com/games/pgs/play-games-sidekick-sdk>), em **AAB** o Sidekick é adicionado automaticamente ao marcar "Add Play Games Sidekick to app bundles" no Play Console — é esse o caminho escolhido aqui, publicado por `build_aab.sh`. Ela só seria necessária no caminho de publicação por APK, que também exige o formulário de registro do Google (1 a 2 semanas de aprovação).

### B. Metadados do Manifesto (`android/build/src/main/AndroidManifest.xml`)
Adicionada a referência ao ID de projeto do Play Games:
```xml
<application ...>
    <!-- Google Play Games Services App ID -->
    <meta-data
        android:name="com.google.android.gms.games.APP_ID"
        android:value="@string/game_services_project_id" />
</application>
```
O valor padrão configurável fica centralizado em `android/build/res/values/games_ids.xml`.

### C. Autoload no Godot (`core/services/PlayGamesManager.gd`)
Um singleton global (`PlayGamesManager`) que:
- Detecta a plataforma em tempo de execução (`is_android()`).
- Provê fallback silencioso em builds Desktop / Web / F-Droid.
- Mapeia conquistas para os 16 jogos de mesa (Xadrez, Damas, Batalha Naval, Quatro em Linha, Resta Um, Campo Minado, Dominó, Ludo, Reversi, Mancala, Senet, Paciência, Memória, 21 Blackjack, Uno, Poker).
- Suporta envio de pontuações para Leaderboards e notificações de conquistas.

---

## 🚀 5. Como Ativar o Sidekick no Google Play Console

Após compilar o arquivo `.aab` usando o script `./build_aab.sh`:

1. Acesse o **Google Play Console** ([play.google.com/console](https://play.google.com/console)).
2. Selecione o aplicativo **PlayTable**.
3. Navegue até **Crescimento > Google Play Games Services > Configuração**.
4. Configure as credenciais de autenticação (OAuth 2.0 / SHA-1 da keystore de release).
5. Vá em **Versão > Testes > Configurações avançadas** (ou seção de recursos de jogos).
6. Ative a opção: **"Adicionar Play Games Sidekick aos pacotes de apps enviados"** (*Add Play Games Sidekick to app bundles*).
7. Publique a versão na trilha de **Teste Interno** ou **Teste Fechado** para testar em um dispositivo Android 13+ com o aplicativo Google Play Games atualizado.
