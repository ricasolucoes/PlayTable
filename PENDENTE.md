# PENDENTE — o que ficou de fora

> **Arquivo temporário.** Não foi commitado. Apague depois de esvaziar.
> Reescrito em 2026-09-06 às 4h40, ao fim do lote "retrato": Gamão e Mancala
> de pé, arrasto do Ludo, toque do Mancala pela mesa, frota da Batalha Naval,
> cor do anel, manifesto do Memória, captura em 720x1280, suíte 673+ testes.
> Tudo o que dependia só de código está feito e commitado em `master`.
> Ficaram **três** itens, todos bloqueados por algo fora do repositório.

Cole este arquivo inteiro como prompt numa sessão nova.

---

## 1. Conferir no Galaxy S23 (bloqueado: o aparelho caiu do USB)

O S23 (`RQCX8033PJJ`) sumiu do `adb devices` por volta de 0h15 e não voltou nem
com `adb kill-server`; a sessão do VOLTA viu o mesmo padrão (enumera como
"Billboard Device", só volta **mexendo no cabo**). O APK deste lote está pronto
e íntegro (export sem `SCRIPT ERROR`, 75,5 MB):

```bash
~/Library/Android/sdk/platform-tools/adb devices          # tem de listar o S23
~/Library/Android/sdk/platform-tools/adb install -r build/android/PlayTable-retrato-2026-09-06.apk
```

Ele leva também a árvore **não commitada** da sessão `playtable-2c` (música de
fundo, cartão de resultado) — o botão "Música liga" no menu é dela.

O que olhar, a meio metro do rosto:

- **Mancala**: tabuleiro de pé, contagem ao lado das covas legível, tocar a
  cova semeia (não há mais botões embaixo). Visto no aparelho antes da queda do
  USB: layout ok, faltava só o shader da cor.
- **Gamão**: de pé; peça sobe pela coluna da direita, cruza, desce pela
  esquerda; arrastar; as três cores das molduras (ouro, verde, azul-claro) —
  o shader converte sRGB agora, e na captura de desktop as cores batem.
- **Ludo**: rolar com dois peões na pista, ver o anel na casa de destino,
  arrastar o peão até lá; soltar fora devolve.
- **Batalha Naval**: o pino da IA na frota se lê?
- **Damas / Resta Um** (arrastar), **Hanói** (Desfazer responde; anel do pino
  ouro, não creme), **Nim** (moldura amarela), capas do menu recomprimidas.

## 2. Arte do Gemini (bloqueado: cota 429, reconferido 2026-09-06 0h)

```bash
set -a; source /Users/sierra/Dev/Jogos/.env; set +a      # linha 5 já corrigida
venv/bin/python tools/gen_art.py --list                  # 20 assets, 7 manifestos
venv/bin/python tools/gen_art.py --dry-run --all
venv/bin/python tools/gen_art.py --all
```

Depois: abrir cada PNG; capturar Campo Minado, Batalha Naval, Damas, Reversi,
Mancala, Uno e Memória; conferir que o Godot não reescreveu os `.import` de
decalque para VRAM; tirar os três do Memória de `LEGADO` em
`test_art_provenance.gd`; medir o APK (era 75,5 MB). Só então o Veo.

## 3. Os 70 ids do Play Console

`core/configs/play_games_ids.json` — só o Play Console resolve.

---

**Armadilhas novas deste lote** (também na memória da sessão):

- `-gtest=` do GUT 9.7 não filtra nada; um arquivo só é `tests/run_gut.sh -gselect=test_ludo`.
- Teste de cena que espera 1–2 quadros e libera a cena acorda o
  `_schedule_refit()` do `BaseGame` num nó liberado; esperar
  `wait_process_frames(3)` e `not jogo._refit_pending` (a `playtable-2c` ia
  trocar por `call_deferred`).
- A suíte cruzando meia-noite paga a recompensa do dia novo no meio de um teste
  de XP (`test_difficulty`): reexecutar.
- Um **terceiro editor** (não é nenhuma das duas sessões do Claude; talvez o
  Antigravity) gravou 28 mp3 em `core/audio/` e reescreveu `AudioManager.gd`
  durante a noite, e a árvore parou de bootar headless por minutos. Antes de
  concluir que um erro é seu, `git status` e `git diff` do arquivo.
- A outra sessão do Claude (`playtable-2c`) responde por SendMessage; avisar
  antes de gravar o CHANGELOG, de rodar `build_apk.sh` e de editar arquivo dela.

---

## Adendo de playtable-2c (2026-09-07, fim do lote da v0.9.0)

Fechado nesta rodada, tudo commitado e na tag `v0.9.0` (local, **sem push**):

1. **Campo Minado** — casa aberta distinta da fechada (placa de arenito no
   `Board3D`, estado `REVEALED`) e progressão de verdade: o degrau monta o
   campo, de 8x8/6 minas a 16x10/36.
2. **Som e música** — efeitos em 16 bits, seis sons novos, e música de fundo
   gerada (`core/audio/MusicSynth.gd`) a -21 dB com chave própria no menu. Os
   14 mp3 que apareceram em `core/audio/` entram por `load()` quando existem;
   proveniência em `core/audio/AUDIO_LICENSES.md` — **confirmar a licença dos
   dez que chegaram sem registro antes de publicar na loja**.
3. **Torres de Hanói** — um disco por degrau (3 a 8) e cartão de fim de
   partida com "Próximo nível" (`shared/ui/ResultPanel.gd`), comum a todos os
   jogos.
4. **Cartas** — índice de canto de 11% para 30% da altura, atlas 180x252.
5. **Jogos em rede** — `core/net/NetworkManager.gd` + `LobbyScreen`: Jogo da
   Velha, Quatro em Linha e Reversi entre dois aparelhos na mesma Wi-Fi.
6. **Design** — cartão "Em rede" no menu, filtro por modo, rodapé que não
   promete mais "100% Offline".
7. **Ícone** — `tools/make_launcher_icons.py` + `android/icons/install.sh`;
   conferido byte a byte dentro do APK assinado.

### O que ficou aberto

- **Nunca testei em rede com dois aparelhos de verdade.** A suíte cobre o
  protocolo e o lado do jogo com um peer falso (`_test_activate`); dois
  telefones na mesma Wi-Fi é conferência que só a mão faz. É o risco número um
  desta versão.
- **Relay da internet não existe** — o cliente está pronto e o contrato está
  em `docs/server/api-contract.md` §7.1; sem servidor a tela diz que o online
  está fora, e é isso que acontece hoje.
- **Conferência no aparelho ficou pela metade**: menu, versão 0.9.0 e ícone
  conferidos; lobby, Campo Minado, Hanói e cartas só por captura no desktop,
  porque o telefone passou a ser usado pela pessoa no meio da rodada.
- **`v0.9.0` não foi enviada ao `origin`** — nem a tag nem os commits.
