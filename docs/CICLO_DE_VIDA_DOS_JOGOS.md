# 🔁 Ciclo de vida compartilhado dos jogos

Levantamento da duplicação entre os 16 jogos de `games/` e o desenho da camada
que passa a concentrá-la em `shared/`.

---

## 1. O que `shared/GenericGame.gd` cobre hoje

**Nada do ciclo de vida dos jogos.** Apesar do nome, `GenericGame` não é uma
classe-base: é a tela de *placeholder* — 14 linhas, sem `class_name` — exibida
quando um `GameDefinition` está marcado com `is_implemented = false`.
`MenuTabuleiro` e `MenuCartas` navegam para `res://shared/GenericGame.tscn`
nesse caso, e nenhum dos 16 jogos herda dela.

O único trecho reaproveitável que ela contém é o botão voltar, que resolve o
menu de origem por `SaveManager.get_setting("current_menu")` — chave que os dois
menus gravam **apenas** ao abrir o *placeholder*, e não ao abrir um jogo de
verdade. Os 16 jogos, por isso, não têm como ler essa chave e escrevem o caminho
do menu à mão. Ao final, `GenericGame` também passou a herdar de `BaseGame`: o
botão voltar dela é a 14ª cópia, e o que era leitura da chave virou o
`menu_scene_path` que ela mesma preenche.

## 2. Função duplicada × o que já existia

Contagem obtida com `grep -rhoE '^func [a-zA-Z0-9_]+' games/ --include='*.gd'`.

| Função | Cópias | `GenericGame` cobre? | Decisão |
| :-- | --: | :-- | :-- |
| `_ready` | 17 | Não (o dele monta o placeholder) | **Fica em cada jogo.** É a montagem da cena: tabuleiro 3D, feltro, baralho. Não há corpo comum além de ligar os nós. |
| `_on_btn_back_pressed` | 13 | **Parcialmente** — mesma navegação, resolvendo o menu por `SaveManager` | **Nasce em `BaseGame`.** Uma implementação, com `menu_scene_path` explícito por jogo. |
| `_on_back_pressed` | 3 | Idem (nome diferente ligado no `.tscn`) | **Alias em `BaseGame`**, para não reescrever 3 cenas. |
| `_start_new_game` | 12 | Não | **Fica em cada jogo**, mas vira o ponto de extensão que `BaseGame._start_new_game()` declara: é o que o botão reiniciar chama. |
| `_on_btn_restart_pressed` | 11 | Não | **Nasce em `BaseGame`.** 10 das 11 cópias eram só `_start_new_game()`; a 11ª (Blackjack) chamava `_start_game()`, renomeado. |
| `_on_restart_pressed` | 3 | Não | **Alias em `BaseGame`.** As 3 cópias somavam `AudioManager.play_click()` — que agora todas ganham. |
| `_end_game` | 8 | Não | **Meio-termo.** As 8 têm assinaturas diferentes (`()`, `(winner: int)`, `(is_player_win: bool)`, `(msg, is_player_win)`), mas o mesmo final: travar a partida, escrever no rótulo, mostrar o reiniciar e comemorar. Esse final vira `BaseGame.finish_game(mensagem, venceu)`; a assinatura de cada jogo continua sendo dele. |
| `_setup_touch_grid` | 6 | Não | **Nasce em `GridGame.build_touch_grid()`.** As 6 cópias só trocavam o tamanho da célula e o alcance do laço. |
| `_update_ui` | 6 | Não | **Fica em cada jogo.** Um mostra gemas na cova, outro pontas do dominó, outro fichas de cassino: mesmo nome, nada em comum. |
| `_play_ai_turn` | 6 | Não | **Fica em cada jogo.** É a regra do jogo, não ciclo de vida. |
| `_on_cell_clicked` | 5 | Não | **Fica em cada jogo.** Só a assinatura `(r, c)` é comum, e ela vira o contrato do `build_touch_grid`. |
| `check_win` / `_check_win` | 4 | Não | **Fica em cada jogo** (e nos respectivos `*Rules.gd`). |
| `get_best_move` | 4 | Não | **Não unificar** — ver seção 4. |
| modal de fim de partida | 3 | Não | **Nasce em `BaseGame.reveal_result_modal()`.** Os três jogos 2D repetiam o mesmo `await` + fade. |

## 3. As duas bases

A separação não é *tabuleiro × cartas*: é *quem tem grade de células* × *quem
não tem*. Mancala, Ludo e Dominó são jogos de tabuleiro sem grade; Blackjack e
Poker são de cartas e mesmo assim compartilham botão voltar e reiniciar.

- **`shared/BaseGame.gd`** (`class_name BaseGame extends Control`) — herdada
  pelos 16 jogos e pelo *placeholder*. Só ciclo de vida: navegação de volta,
  reinício, `game_over`, `finish_game()`, `set_status()` e
  `reveal_result_modal()`. Nenhum estado de partida, nenhuma bandeira de
  exceção.
- **`shared/GridGame.gd`** (`class_name GridGame extends BaseGame`) — herdada
  pelos 6 jogos cujo tabuleiro é uma grade de células tocáveis (Reversi, Damas,
  Batalha Naval, Campo Minado, Resta Um, Senet). Acrescenta apenas
  `build_touch_grid()`.

Os jogos de cartas **não** ganham `build_touch_grid`, e nada em `BaseGame`
precisa saber se quem herda tem tabuleiro, IA, dado ou baralho.

O **Poker** é o caso-limite: video poker não tem fim de partida nem botão
reiniciar — a rodada anda por um `game_phase` de três estados. Ele herda
`BaseGame` **só pela navegação** e deixa `finish_game()`, `btn_restart` e
`_start_new_game()` intocados. Nenhuma bandeira foi acrescentada a `BaseGame`
para acomodá-lo: os três nós opcionais já eram nulos por padrão. Se algum dia
for preciso um `if` em `BaseGame` para caber um jogo, é sinal de separar as
bases — não foi preciso.

## 4. Por que a IA continua separada

`get_best_move` aparece 4 vezes, em 4 algoritmos diferentes:

| Origem | O que faz |
| :-- | :-- |
| `TicTacToeRules.get_best_move` | Heurística fixa: fecha, bloqueia, centro, canto, lado. Devolve `int`. |
| `ReversiRules.get_best_move` | Minimax de verdade, profundidade 3, com poda alfa-beta sobre um `Grid2D` clonado. Devolve `Vector2i`. |
| `CheckersRules.get_best_ai_move` | Devolve a primeira jogada válida da lista. Devolve `Dictionary {from, to, captured}`. |
| `ConnectFourAI.get_best_move` | Vencer/bloquear/aleatório sobre um `ConnectFourBoard` mutado no lugar (o cabeçalho promete minimax que não existe — ver CHANGELOG). Devolve `int`. |

Só o nome coincide. Uma assinatura comum precisaria de um tipo de estado comum
(`Grid2D` em três casos, `ConnectFourBoard` no quarto) e de um conceito de
"jogada" comum (índice, `Vector2i`, dicionário `{from, to, captured}`). O
resultado seria uma interface com quatro implementações que não se substituem —
custo de abstração sem ganho de reuso. **Fica como está.**

## 5. Comportamento que mudou na unificação

- O botão **voltar** passa a tocar o clique nos 16 jogos (antes: só nos 3 jogos 2D).
- O botão **reiniciar** passa a tocar o clique nos 16 jogos (antes: só nos 3 jogos 2D).
- O modal de **empate** do Jogo da Velha passa a entrar com o mesmo *fade* do
  modal de vitória (antes aparecia seco).
- No Campo Minado, a vitória passa a marcar também `game_over` (antes só
  `game_won`); as duas bandeiras já bloqueavam a mesma coisa.
- Na Paciência, `game_won` **era** o `game_over` do jogo com outro nome —
  guardava os quatro tratadores de toque e nada mais. Virou a bandeira herdada,
  uma a menos e não uma a mais.
- No Blackjack, `_start_game()` passou a se chamar `_start_new_game()`: era a
  única das 11 cópias do botão reiniciar que chamava outro nome.

## 6. O que `BaseGame` deliberadamente **não** integrou

O plano original pedia que a classe compartilhada também integrasse
`core/estatisticas`, `core/save`, `core/i18n` e `core/audio`. Só o último
entrou — `play_click()`, que os botões voltar e reiniciar agora tocam nos 16
jogos. Os outros três ficaram de fora, e por motivos diferentes:

| Sistema | Estado | Por quê |
| :-- | :-- | :-- |
| `core/audio` | **Integrado** | `AudioManager.play_click()` em `play_click()`. |
| `core/estatisticas` | **Não existe** | O diretório está vazio e o git não rastreia nada dentro dele. Não há API para integrar; integrar significaria *escrever* um sistema de estatísticas, que é outra tarefa. |
| `core/save` | Fora | `SaveManager` tem só `set_setting`/`get_setting`. Nenhum jogo persiste partida ou placar hoje — o Jogo da Velha e o Quatro em Linha guardam o placar em memória, e há teste que tranca esse comportamento. Persistir exigiria inventar um contrato (o que é uma partida? o que é um placar?) que nenhum jogo pede. |
| `core/i18n` | Fora | Os 16 jogos escrevem o status em português fixo, e o `translations.csv` não tem chave para nenhuma dessas frases. Traduzir é um projeto próprio, com chave nova para cada mensagem; enfiar `tr()` em `set_status()` só faria a frase passar por uma tabela onde ela não está. |

A regra que guiou os três cortes é a do próprio enunciado: se acomodar o
sistema exigisse bandeira ou condicional em `BaseGame`, a abstração estaria
errada. Nenhum dos três cabia sem inventar contrato novo.

## 7. Resultado

Contagem depois da migração dos 16 jogos, pelo mesmo `grep` da seção 2, agora
sobre `games/` **e** `shared/`:

| Função | Antes | Depois | Onde ficou |
| :-- | --: | --: | :-- |
| `_on_btn_back_pressed` | 14 | **1** | `BaseGame` |
| `_on_back_pressed` | 3 | **1** | `BaseGame` (alias) |
| `_on_btn_restart_pressed` | 11 | **1** | `BaseGame` |
| `_on_restart_pressed` | 3 | **1** | `BaseGame` (alias) |
| `_setup_touch_grid` | 6 | **0** | virou `GridGame.build_touch_grid()` |
| `_end_game` | 8 | 8 | de cada jogo, todas terminando em `finish_game()` |
| `_start_new_game` | 12 | 16 | de cada jogo — agora é o ponto de extensão declarado |
| `_ready` | 24 | 24 | de cada jogo, como previsto |

`games/` perdeu 207 linhas; `shared/` ganhou 152, das quais 146 são as duas
classes novas. Um commit por jogo, com a suíte GUT verde em cada um.

**Testes que trancam o resultado:** `tests/gdscript/unit/test_shared_lifecycle.gd`
bate direto em `BaseGame` e `GridGame`; em `tests/gdscript/integration/test_catalog.gd`,
`test_cada_jogo_volta_para_o_menu_da_sua_categoria` instancia as 16 cenas e confere
o `menu_scene_path`, e `test_nenhum_jogo_reescreve_o_ciclo_de_vida` lê os `.gd` de
`games/` e reprova qualquer cópia nova do botão voltar, do reiniciar ou do
`game_over`.
