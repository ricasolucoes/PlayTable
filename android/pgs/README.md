# Integração Play Games (Android)

Tudo que faz o Play Games funcionar no APK mora aqui. `android/build/` é gerado
pelo Godot e está no `.gitignore` — reinstalar o modelo de compilação apaga o
que estiver lá dentro. `install.sh` reaplica esta pasta em cima dele, e é
idempotente.

```
android/pgs/
├── java/org/playtable/pgs/PlayTablePGS.java   plugin Godot ↔ PGS v2
├── AndroidManifest.inject.xml                 meta-data que o template não tem
├── gradle_deps.txt                            dependências do SDK
└── install.sh                                 instala / `--check` verifica
```

Os `build_apk.sh` e `build_aab.sh` chamam `install.sh` sozinhos e passam as
dependências pela propriedade oficial de plugin do Godot
(`-Pplugins_remote_binaries`), então não há build.gradle editado à mão.

## O que falta para ligar de verdade

O código está completo e vai no APK; o que ainda não existe são os
identificadores, que só o Play Console gera. Enquanto eles estiverem vazios em
`core/configs/play_games_ids.json`, o `PlayGamesManager` **não envia nada** — de
propósito. Um id inventado é recusado em silêncio pelo servidor, e a integração
pareceria funcionar enquanto nenhuma conquista chegasse ao jogador.

1. **Play Console → Play Games Services → Configuração e gerenciamento →
   Configuração.** Crie o projeto do PGS e vincule ao app `org.playtable.app`.
2. Copie o **ID do projeto** (só números) para `app_id` no
   `core/configs/play_games_ids.json`.
3. **Credenciais:** crie os OAuth 2.0 Client IDs de *debug* e de *release*, com
   a impressão digital SHA-1 de cada keystore. Sem o de release, o app assinado
   nunca autentica — é o erro mais comum e não dá mensagem clara.
4. **Conquistas:** crie as 55 do catálogo
   (`core/configs/achievements.json`). Cada uma devolve um id no formato
   `CgkI...EAQ`; cole no mapa `achievements` do `play_games_ids.json`, na
   mesma chave.
5. **Placares:** crie os nove de `leaderboards`. Atenção à ordenação — quatro
   deles são "menor é melhor" (tempo do Campo Minado, jogadas da Memória e da
   Torre, peças do Resta Um). O `LeaderboardSync` já manda o valor no formato
   certo, mas o placar precisa estar configurado como *Menor é melhor* no
   Console.
6. **Eventos:** crie os cinco de `events` e publique.
7. **Testadores:** adicione as contas Google na aba de testes do PGS. Antes de
   publicar, só elas autenticam.

Conferir a instalação a qualquer momento:

```sh
android/pgs/install.sh --check
```

E o estado em tempo de execução, de dentro do jogo, com
`PlayGamesManager.diagnostics()` — diz quantos ids estão mapeados, se há login,
e quantos envios estão na fila offline.

## Por que Java em vez de um plugin pronto

Os plugins de PGS publicados hoje são `.aar` binários com API própria, e a
versão anterior deste código tentava falar com três deles ao mesmo tempo por
`has_method()`. Compilar a partir da fonte, junto com o app, dá uma superfície
só, atualizável com o SDK, e sem binário de terceiro no repositório.
