# Release Notes

---

## [Unreleased](https://github.com/ricasolucoes/PlayTable/compare/v0.6.0...develop)

### 🎨 Melhorias

- [x] **Cartão de perfil do menu virou cartão-botão** — como cartão mais botão separados, em 3:4 (720x960) os dois somavam ~220 px e empurravam o rodapé para fora da tela. Tocar no progresso leva ao progresso, que é para onde o dedo ia mesmo
- [x] **Matriz de conquistas gerada do catálogo** (`tools/gen_achievement_matrix.py`) — a versão escrita à mão tinha derivado do código: prometia uma conquista de Xadrez, jogo que o PlayTable não tem, e não trazia nada de Gamão, Torre de Hanói, Nim nem Resta Um. A coluna "Mapeada" mostra quantos ids do Play Console ainda faltam
- [x] **Checklist do Play Console reescrito** — separa o que já está no repositório do que só a conta do Google resolve, e diz a ordem que funciona: sem `app_id` o SDK nem inicializa, e sem login nada é enviado (fica na fila e sobe depois)

### 🐛 Correções

- [x] **Data malformada no perfil derrubava a conta da sequência** — a data vem de um arquivo em `user://`, que é editável; data inválida fazia o `Time` reclamar no console a cada abertura e a conta saía assim mesmo. O calendário agora valida e conhece ano bissexto

### 🔧 Técnico

- [x] **Oito testes na sequência diária** — é o motor de retorno do jogo e não tinha um teste sequer. Cobrem as cinco transições que importam: dia seguinte soma; várias partidas no mesmo dia contam como um; um dia perdido sem congelamento zera; com congelamento a sequência sobrevive e o congelamento é consumido; dois dias perdidos não são cobertos por um só; e voltar depois de duas semanas marca o retorno mas recomeça a contagem
- [x] **Suíte em 479 testes**, 474 passando e 5 pendentes (o livro-razão de layout M1/M3/M4/M6)


---

## [v0.6.0 (2026-08-27)](https://github.com/ricasolucoes/PlayTable/compare/v0.5.0...v0.6.0)

### ✨ Novidades

- [x] **Motor de gamificação completo** — 55 conquistas em JSON cobrindo os 19 jogos reais, missões diárias e semanais que trocam de lote quando a janela vira (antes eram sorteadas uma vez e ficavam `completed` para sempre), ligas com ELO, maestria por jogo e coleção. `PlayerProfile` v2 guarda `lifetime_xp` monotônico com o nível derivado, e migra o perfil v1 sem ninguém perder progresso
- [x] **Os 19 jogos publicam a partida** — `BaseGame.finish_game()` anuncia o resultado no `GameEventBus` e nenhum jogo precisa conhecer conquista, missão ou XP
- [x] **Tela de perfil com cinco abas** — Resumo, Missões, Conquistas (as 55 agrupadas por categoria, com progresso: "37/50 vitórias" motiva, cadeado fechado não), Maestria e Coleção. No menu principal, um cartão com nível, barra de XP, sequência e *uma* linha de "falta pouco". O motor calculava tudo isso e gravava em disco sem que uma linha de interface lesse qualquer número
- [x] **Escada de dificuldade de 1 a 10, uma por jogo (`DifficultyManager`)** — venceu sobe um degrau, perdeu desce um, empatou fica. O degrau serve à IA (quanto pensar) e à gamificação (`xp_scale`: vencer no degrau 10 paga o dobro, no degrau 1 paga 60%), senão o caminho mais rápido para o XP era ficar de propósito no fácil
- [x] **Damas com IA que anda na escada** — a busca passou a ser cortada por orçamento de nós, não por profundidade, e o degrau 10 cabe num telefone. A IA devolve o turno inteiro com a cadeia de capturas já escolhida, em vez de a cena continuar a cadeia sozinha pegando a primeira da lista
- [x] **Jogo da Velha com dez degraus e minimax que varia** — do degrau 8 em diante a IA abre a partida, e entre jogadas de mesma nota o minimax sorteia. Antes o jogador abria sempre e, contra minimax perfeito, não podia perder: a escada travava no topo para sempre e a partida ficava decorada depois de vista uma vez
- [x] **Integração real com o Google Play Games** — plugin Android próprio escrito contra o PGS v2 (login automático, conquistas, placares, eventos e Saved Games com conflito manual), `APP_ID` no manifesto e permissão de internet no export. Antes era uma fachada de 240 linhas em volta de um plugin que não existia no repositório, e todo método saía na primeira linha em silêncio
- [x] **Fila offline do Play Games** — conquista fechada no avião chega quando a rede volta. Persistida em disco e colapsando repetição: dez partidas offline viram um placar com o melhor valor e um evento com a soma, não vinte envios
- [x] **Save na nuvem com merge de verdade** — no conflito entre dois aparelhos, contador fica com o maior e conquista com a união. Resolver pelo mais recente descartaria o progresso do outro aparelho; ninguém perde conquista por ter jogado no tablet
- [x] **Bônus de login diário e congelamento de sequência** — o bônus escala com a sequência e é pago na *abertura*, não no fim da partida: recompensa que só chega depois de jogar não ajuda quem abriu o app sem saber o que fazer. A cada 5 dias de sequência vem um congelamento, e um dia perdido deixa de apagar semanas
- [x] **Batalha Naval com os dois mapas na mesa** — batalha naval é um jogo de comparar dois mapas, e um deles vivia escondido atrás de um botão. O navio afundado sobe do fundo no lugar exato das casas e estoura a partir do contorno do casco
- [x] **Biblioteca de sprites nomeados e `AssetCatalog`** — recorte dos spritesheets em arquivos com nome semântico (`card_back_blue`, `checker_red`, `dice_blue`, `coin_gold`), substituindo o acesso por índice das fatias cruas
- [x] **Cartões do menu com a arte de introdução de cada jogo**

### 🎨 Melhorias

- [x] **O tabuleiro passa a ocupar a tela** — o enquadramento é medido na borda de perto do conteúdo, não no plano do foco (em perspectiva a borda próxima projeta mais larga, e a folga de 12% existia só para esconder isso: caiu para 4%). Quando a largura manda, a câmera inclina mais até o teto do tema — 74° no tabuleiro, 56° na mesa de carteado, para a face da carta não achatar
- [x] **Os 19 jogos enquadram a mesa pela HUD real** — `BaseGame.fit_table()` mede as faixas de HUD que a cena tem em tempo de execução; mexer no cabeçalho reenquadra sozinho. Antes cada jogo escrevia a área útil à mão, em pixels
- [x] **Captura obrigatória também para o jogador, nas Damas** — a regra sempre valeu em `get_all_valid_moves`, mas a tela não cobrava: dava para passear com outra peça enquanto a IA era obrigada a comer
- [x] **Blackjack, Poker e Paciência com a mesa perto e as cartas legíveis**
- [x] **Mão do Uno deixa de ser uma fileira de botões apagados**
- [x] **Verso das cartas do Jogo da Memória usando o sprite do catálogo**

### 🐛 Correções

- [x] **Dado saía como um cubo branco** — e, depois de os pontos irem para o lugar certo, ainda ficavam invisíveis
- [x] **As pedras do Dominó não apareciam**, nem na mesa nem na mão
- [x] **Baralho saía todo preto no Blackjack e na Paciência**
- [x] **A camada de toque do Gamão ficava embaixo das pontas**
- [x] **Resta Um** — a esfera pega no furo mais próximo, e passou a aceitar arrastar
- [x] **Carta colorida do Uno** — se é UNO, a carta tem de ser de UNO
- [x] **Memória, Poker e 4 em Linha não reportavam partida** — herdavam `BaseGame` mas terminavam direto no próprio modal. Quem só jogava esses três não ganhava XP, não mantinha sequência e não desbloqueava nada
- [x] **Nim e Torre de Hanói emitiam seis conquistas que não existiam** — ids soltos que iam parar no perfil como texto e, com o Play Games ligado, seriam recusados pelo servidor. Agora os jogos publicam fatos e o catálogo decide o que vira conquista
- [x] **"20 / 19 jogos experimentados"** — a contagem lia as chaves gravadas em vez do catálogo, e o id de fallback `playtable` (que a suíte de testes produz) virava um vigésimo jogo, fechando sozinha a conquista de jogar todos

### 🔧 Técnico

- [x] **Testes** — 470 no total: os 31 do motor de gamificação (incluindo a nuvem e a política de ids do Play Games), os 9 da escada de dificuldade, os do toque nos dois mapas da Batalha Naval e a comparação casa a casa entre as duas gerações de captura das Damas (a busca repete a regra direto no vetor de casas porque o Dicionário de `CheckersRules` é lixo puro num nó de busca)
- [x] **Ferramentas de bancada das Damas** — `tools/_bench_damas.gd` mede o custo por jogada em cada degrau (212 ms de média e 441 ms no pior nó, num Mac) e `tools/_forca_damas.gd` joga um degrau contra o outro. Foi ele que mostrou o degrau 7 perdendo do 5
- [x] **Captura de tela** — sai na resolução lógica do aparelho e chama métodos na cena antes do disparo
- [x] **`android/pgs/` versionado, `android/build/` descartável** — a integração Android inteira (fonte do plugin, meta-data do manifesto, dependências do SDK) mora em `android/pgs/` e é reaplicada por `install.sh`, que é idempotente e tem `--check`. `android/build/` é gerado pelo Godot e está no `.gitignore`: reinstalar o modelo de compilação apagaria tudo. Os build scripts chamam o instalador sozinhos e passam a dependência pela propriedade oficial `-Pplugins_remote_binaries`, sem `build.gradle` editado à mão
- [x] **220 chaves de tradução novas** em pt-BR, inglês e espanhol — conquistas, missões, ligas, itens de coleção e a tela de perfil. A suíte cobra: conquista sem tradução aparece na tela como id cru
- [x] **`android/build/` fora do import do Godot**, e binários de tradução reimportados com o Godot 4.7.2

---

## [v0.5.0 (2026-08-26)](https://github.com/ricasolucoes/PlayTable/compare/v0.4.0...v0.5.0)

### ✨ Novidades

- [x] **Gamão 3D / Backgammon (`games/gamao/`)** — Implementação completa do clássico jogo de tabuleiro e estratégia de Gamão em 3D imersivo. Tabuleiro clássico entalhado em nogueira e mogno nobre com feltro verde aveludado, 24 pontas triangulares em bordo e mogno, 30 peças chanfradas em marfim e obsidiana, barra central e bandejas laterais de bear-off, física e rolagem de dados 3D, e movimentação fluida em arco parabólico via Tweens.
- [x] **Regras Oficiais e IA Tática de Gamão** — Regras completas de captura de blots para a barra, reentrada obrigatória, bloqueio de pontos (2+ peças), recolhimento final (Bear-off), cálculo de Pip Count em tempo real e IA com 3 níveis de dificuldade (Fácil, Médio, Mestre) e modos vs IA / 2 Jogadores Local.
- [x] **Gamificação e Conexão de Eventos** — Integração com `GameEventBus` (`match_completed`, `xp_gained`), `PlayerProfile` (vitórias, partidas, streak diário), recompensas multiplicadas por Gammon (2x) e Backgammon (3x), modal de resultado e suporte a Desfazer (Undo) no turno.
- [x] **Jogo de Nim 3D (`games/nim/`)** — Implementação do lendário jogo de estratégia matemática e raciocínio combinatório em 3D. Tabuleiro em nogueira e mogno nobre com canaletas aveludadas, moedas/gemas chanfradas em PBR com física e animação em arco até a cesta de descarte.
- [x] **IA Inteligente com Teorema de Bouton (Nim-Sum)** — Algoritmo de Nim-Sum com 3 níveis de dificuldade (Fácil, Médio, Mestre) com suporte a estratégias perfeitas nos modos Normal Play e Misère (Marienbad).
- [x] **Modo 2 Jogadores Local e Presets Clássicos** — Suporte a partidas de Pass-and-Play local, alternância de regras Normal e Misère, e presets `[1, 2, 3]`, `[3, 4, 5]`, `[1, 3, 5, 7]` (Marienbad) e `[1, 2, 3, 4, 5]`.
- [x] **Gamificação e Conquistas de Nim** — Concessão de XP, integração com `PlayerProfile` e conquistas (`ACH_NIM_FIRST_WIN`, `ACH_NIM_MISERE_MASTER`, `ACH_NIM_PYRAMID_SOLVER`).
- [x] **Torres de Hanói 3D (`games/hanoi/`)** — Implementação completa do clássico jogo de lógica e estratégia matemática em 3D imersivo. Apresenta base e pinos nobres em mogno, nogueira e ouro polido, discos com pedras preciosas (Rubi, Âmbar, Ouro, Esmeralda, Turquesa, Safira, Ametista, Obsidiana), movimentação parabólica suave em arco por Tweens, amortecimento elástico e som de encaixe sem bugs.
- [x] **Seletor de Dificuldade de 3 a 8 Discos** — Configuração instantânea da quantidade de discos com cálculo automático do número mínimo ótimo de movimentos (\(2^n - 1\)).
- [x] **Recursos de Acessibilidade e Apoio** — Sistema ilimitado de Desfazer (Undo), Dicas (Hints) e Solver Automático demonstrativo com animação passo a passo da solução ótima recursiva.
- [x] **Integração com Gamificação & Maestria** — Avaliação por estrelas (1 a 3 estrelas), disparo de eventos `GameEventBus`, concessão de XP e conquistas (`ACH_HANOI_3_PERFECT`, `ACH_HANOI_5_SOLVED`, `ACH_HANOI_MASTER`) e integração com `PlayerProfile` e `MasteryEngine`.

### 🐛 Correções

- [x] **Damas não aceitavam clique** — o raiz de cada jogo é uma `Control` de tela inteira e, no filtro de mouse padrão, retém o toque antes de ele chegar ao `Picker` do `Board3D`. As Damas são o único jogo que entra por *picking* 3D — o merge da `safety-p07` apagou a grade 2D delas — e ficaram injogáveis: sem clique não há seleção, sem seleção não há salto. `BaseGame._init()` põe o raiz em `MOUSE_FILTER_IGNORE` para os 16 jogos; os botões da HUD seguem recebendo o toque
- [x] **Um toque disparava `cell_clicked` duas vezes** — com `emulate_mouse_from_touch` ligado (o padrão do projeto) cada toque chega como `InputEventScreenTouch` e de novo como `InputEventMouseButton` emulado, e o `Picker` tratava os dois. Com a emulação ligada só o mouse conta
- [x] **A frota da Batalha Naval nunca foi desenhada** — `_render_ship_3d` lia `ship["is_vertical"]`, `start_row` e `start_col`, chaves que `BattleshipRules` nunca gravou (o navio é `{name, size, cells, hits, sunk}`). A aba *Frota* morria no primeiro navio com *Invalid access*. Os cascos agora saem das `cells` — e ganharam cor clara, porque o casco antigo tinha a mesma luminância das casas do oceano
- [x] **Batalha Naval entra pelo próprio tabuleiro** — o toque vinha de uma grade 2D de botões de 32 px (17 dp num telefone comum) alinhada à mão sobre uma câmera fixa que não coincidia com ela. Passa a usar o `cell_clicked` do `Board3D`, com a câmera enquadrando o tabuleiro como nas Damas. Pinos caem e assentam, o de acerto pulsa, os navios emergem um a um ao abrir a aba da frota, e tocar na aba errada ou numa coordenada já atacada responde no status em vez de calar
- [x] **`tests/gdscript/integration/test_touch_input.gd`** — nenhum teste simulava um toque, e a aba *Frota* só renderiza ao trocar de aba; foi por isso que tudo acima passou. Os seis testes novos empurram um clique de verdade pelo viewport raiz (um `SubViewport` solto não processa *picking* para eventos empurrados) e conferem seleção nas Damas, tiro na Batalha Naval, a frota desenhada com contraste, o raiz dos 16 jogos e o disparo único por toque
- [x] **Quatro em Linha desenhado de cabeça para baixo** — `_make_move` calculava `visual_row = (ROWS - 1) - row` apoiado num comentário que dizia *"logic row 0 is bottom"*, mas `drop_piece` preenche do índice `ROWS-1` para o 0: a linha `ROWS-1` é o fundo. Como no desenho o y cresce para baixo, linha lógica e linha visual já coincidiam — a inversão punha a primeira ficha de cada coluna no topo, com a pilha crescendo para baixo. A conta virou `cell_center_y()`, um método nomeado que os testes conseguem interrogar
- [x] **Fundação vazia da Paciência aceitava qualquer ás** — `can_place_on_foundation` ganhou o parâmetro `required_suit`; com `-1` o contrato antigo segue valendo. As duas chamadas de `KlondikeGame` passavam `req_suit` e conferiam `card.suit` por fora, cada uma com sua cópia da condição
- [x] **IA do Uno jogava com a cor fixa** — `UnoRules.pick_best_color_for_hand` existia e implementava a heurística de maioria, mas `UnoLikeGame` não a chamava: ao jogar um curinga a IA fixava azul, ou vermelho no caminho de comprar-e-jogar
- [x] **Trocar a qualidade não descartava o que já tinha sido gerado** — `MeshBuilder3D` guarda malhas construídas com `Quality3D.radial_segments()` e `TextureFactory3D` guarda texturas, e nenhuma das chaves de cache inclui o *tier*. As três `clear_cache()` existiam exatamente para isso e ninguém as chamava: depois de `set_tier()` as peças continuavam com a geometria do nível anterior pelo resto da sessão
- [x] **Arquivo de teste descartado pelo GUT não reprovava nada** — um `.gd` que não compila era descartado com *"Ignoring script … because it does not extend GutTest"*, um aviso no meio da saída, e a suíte seguia verde com menos testes. Aconteceu com `test_table_item_3d.gd`, que sumiu inteiro por um `:=` sobre `add_child_autofree()`. O runner agora sai com 1. No mesmo arquivo, o carimbo de reimportação passou a cobrir a lista de `class_name`: uma classe nova só entra no `global_script_class_cache.cfg` depois de um `--import`, e até lá quem herda dela morre em *"Could not find base class"*

### 🔧 Técnico

- [x] **As outras duas cópias de regras foram fechadas** — o Jogo da Velha tinha `_check_win`, `_is_draw` e `_get_ai_move` inline sobre um `Array` plano enquanto `TicTacToeRules` fazia o mesmo sobre `Grid2D` sem ninguém chamar; havia até um teste varrendo as 6.561 posições possíveis só para travar a divergência entre as duas. Ele provou a equivalência, o que tornou a troca segura, e agora confere o que sobrou. `MemoryRules` era um caso diferente: recebia `Card` e lia `custom_data["pair_id"]`, um modelo que `MemoryGame` nunca usou — não era lógica duplicada, era regra escrita para outro jogo. Passou a falar em símbolos, que é o que a cena tem. `Deck.create_memory_deck()`, que só alimentava o modelo abandonado, saiu junto
- [x] **Tipo de retorno em todas as funções** — eram 41 sem declarar, agora zero. Declarar o retorno destravou a inferência rio abaixo: `shared/` foi de 66% para 95% tipado sem escrever um tipo à mão
- [x] **Os 70 `@onready` ganharam tipo** — `:=` não serve neles: inferiria `Node` e quebraria o acesso aos membros da subclasse. O tipo real saiu da própria cena, lendo os `.tscn`. Os casos que sobravam vinham de `Grid2D.get_cell()`, que devolve `Variant`, e foram anotados com o tipo que o código já assumia. O parser reprovou 16 dessas anotações de primeira, todas em `MinesweeperRules`, onde eu tinha escrito `int` sobre um `Dictionary` — exatamente o erro que a tipagem existe para expor
- [x] **39 constantes `preload` mortas** em 20 arquivos, todas duplicando classes que já têm `class_name` e nenhuma usada uma única vez
- [x] **Os links do CHANGELOG estavam quebrados** — apontavam para `github.com/ricardosierra/PlayTable`, que responde *Repository not found*. O repositório é `ricasolucoes/PlayTable`, e os seis links de comparação de versão não abriam

- [x] **Framework de jogadores e rede removido** — `IPlayerController`, `HumanPlayerController`, `AIPlayerController`, `RemotePlayerController`, `TurnManager`, `Player` e `GameAction` somavam 235 linhas e nenhum dos 16 jogos instanciava qualquer uma delas; os dois únicos usos do identificador `Player` fora do `core_engine` eram comentários. Pior que o peso morto: `test_core_systems.gd` cobria `TurnManager` e `GameAction` com dez testes, então parte da suíte verde falava de código que o aplicativo não executa. Saiu junto, com `ConnectFourBoardVisual.gd`, que ninguém referenciava
- [x] **O Quatro em Linha tinha duas implementações completas das mesmas regras** — a cena usava `ConnectFourBoard` e `ConnectFourAI`; a suíte exercitava `ConnectFourRules`, que ninguém chamava. Ficou o `ConnectFourRules`, melhor nos dois pontos onde diferiam: clona o grid para simular em vez de escrever em `board.grid` e desfazer depois — o próprio `ConnectFourAI` trazia um *"WARNING: Simulates moves by directly mutating board.grid"* no cabeçalho — e tem a preferência pela coluna central que faltava. `ROWS` e `COLS` eram declarados em cinco arquivos e `CELL_SIZE` em três, com o raio do furo sob dois nomes para o mesmo `34.0`
- [x] **`TableItem3D`, base de `Card3D` e `Token3D`** — os dois faziam `extends Node3D` e tinham convergido sozinhos: `_kill`, `hover` e `select` idênticos, `reject` batendo em 7 das 10 linhas, `vanish` em 9 das 14, e a sombra de contato o mesmo bloco com outro tamanho de quad. A única diferença real do `reject()` era a amplitude do tremor, agora `reject_shake`/`reject_settle` escritos uma vez. Card3D 214 → 172 linhas, Token3D 269 → 242
- [x] **`CardCollection`, base de `CardPile`, `CardHand` e `Deck`** — as três repetiam `size()`, `is_empty()`, `clear()` e `to_dict()` com corpos idênticos, e `count()` era alias de `size()` dentro do próprio arquivo, a mesma função escrita duas vezes em três arquivos. Nenhuma chamada a `count()` existia em `games/` nem em `tests/`: saiu em vez de subir
- [x] **`GameMenu`, base de `MenuTabuleiro` e `MenuCartas`** — os dois eram idênticos em 29 das 31 linhas, divergindo na consulta ao catálogo e no caminho gravado em `current_menu`. Cada um caiu para 12 linhas
- [x] **O status da partida passa pelo `set_status()` do `BaseGame`** — a API nasceu na deduplicação da v0.4.0 e ninguém adotou: os 16 jogos escreviam em `status_label.text` direto, 96 vezes, por fora da guarda de nulo que o próprio `BaseGame` documenta
- [x] **Tipagem estática em `games/` e `core/`** — 421 declarações locais passaram a usar `:=`. As 136 restantes foram revertidas uma a uma porque o Godot recusou: ou o valor vem de `Dictionary`/`Array`, que devolvem `Variant`, ou a função chamada não declara retorno. `games` foi de 0% para 69% tipado, `core` de 3% para 100%
- [x] **`shared/pecas/Piece.gd` virou `shared/ui/Piece2D.gd`** — o nome colidia com o `class_name Piece` de `shared/core_engine/board/Piece.gd`, que é outra coisa, e `shared/pecas` era o único diretório em português dentro de `shared/`

- [x] **Engine migrada para o Godot 4.7.2** — `config/features` saiu de `4.3`, que ja nao correspondia ao editor em uso (o `Godot.app` da raiz e 4.6 e a CI fixava `4.6.3-stable`), e passou a declarar `4.7`. O pin da CI foi para `4.7.2-stable` e o template de build Android foi reinstalado a partir da `android_source.zip` da versao nova, que sobe `compileSdk` e `targetSdk` para 36 e exige JDK 17. A suite inteira roda na engine nova sem uma linha alterada: 404 testes, 398 passando, 6 pending de layout que ja existiam


## [v0.4.0 (2026-08-24)](https://github.com/ricasolucoes/PlayTable/compare/v0.3.0...v0.4.0)

### ✨ Novidades

- [x] **Suíte de testes que roda o GDScript de verdade** — 350 testes GUT em 20 arquivos, executados headless contra os `.gd` e os `.tscn` de produção. Um arquivo por jogo (`tests/gdscript/unit/`), mais núcleo, i18n e um teste de integração que instancia as 16 cenas de verdade
- [x] **CI no GitHub Actions** — `.github/workflows/ci.yml` roda a suíte em todo push e pull request, com Godot 4.6.3 e o addon GUT em cache, e publica o relatório JUnit como artefato
- [x] **`tests/run_gut.sh`** — runner local que acha um Godot 4.4+ no `PATH`, no repositório ou em `/Applications`, instala o GUT sob demanda e reimporta os recursos quando a engine ou o addon mudam
- [x] **Mesa 3D reconstruída** — o trabalho que estava parado num branch de segurança desde antes da v0.3.0 entrou: `CameraRig3D` (enquadramento calculado a partir do próprio tabuleiro, sem distância escrita à mão), `GameTheme3D` (paletas nomeadas por ambientação), `TextureFactory3D` e `CardArt2D` (texturas e faces de carta geradas em tempo de execução), `CardAtlas3D`, `Quality3D` (níveis de qualidade) e `Tokens3D` (constantes de arco, duração e espessura que os jogos repetiam). Mais cinco ferramentas de bancada em `tools/` para prévia de atlas, *benchmark* de textura e conferência de malha e referências
- [x] **Google Play Games** — `core/services/PlayGamesManager.gd` entra como autoload, com o roteiro de integração em `docs/PLAY_GAMES_SIDEKICK.md`
- [x] **Ficha de loja em 27 idiomas** — título, descrição curta, descrição completa, *feature graphic* e capturas para `ar`, `de-DE`, `en-AU/CA/GB/US`, `es-419/ES/US`, `fr-CA/FR`, `hi-IN`, `id`, `it-IT`, `ja-JP`, `ko-KR`, `nl-NL`, `pl-PL`, `pt-BR/PT`, `ru-RU`, `sv-SE`, `th`, `tr-TR`, `vi`, `zh-CN/TW`
- [x] **Política de privacidade** — `PRIVACY_POLICY.md` e `docs/privacy.html`, exigidas pela ficha da Play Store
- [x] **`build_aab.sh`** — gera e assina o *bundle* de release. A senha do *keystore* é lida de um arquivo fora do repositório; nada de credencial versionada

### 🐛 Correções

- [x] **Tweens soltos disparando sobre nós já liberados** — dez chamadas usavam `get_tree().create_tween()`, que cria o tween na SceneTree em vez de amarrá-lo ao nó animado. Ao trocar de cena, reiniciar a partida ou dar `queue_free` nas cartas do Jogo da Memória, o tween seguia rodando e chamava o callback sobre uma instância morta (*Trying to call a lambda with an invalid instance*). Trocadas por `Node.create_tween()`, que é o que o resto do projeto já usava
- [x] **Resta Um estava intransitável** — `PegSolitaireGame._execute_jump` lia `target_dict["jumped"]`, chave que `PegSolitaireRules.get_valid_moves_for_peg` nunca devolveu (as chaves são `from`, `over` e `land`). O acesso derrubava a função com *Invalid access to property or key* antes de qualquer `set_cell`: selecionar uma esfera funcionava, tocar no furo de destino não fazia absolutamente nada. Nenhuma partida podia ser jogada até o fim
- [x] **A suíte de testes não rodava desde a migração para a Godot 4.6** — `tests/run_gut.sh` só chamava o `install_gut.sh` quando `addons/gut/gut_cmdln.gd` estava ausente, então a versão fixada nunca era conferida e o GUT 9.3.0 da época da 4.3 sobreviveu à migração feita na v0.3.0. Na 4.6 esse addon nem carrega: o 9.3.0 declara `class_name Logger` e a 4.6 passou a ter uma classe nativa com esse nome, então o `gut.gd` morre em *Parse Error: The member "Logger" shadows a native class*. Pior, o `gut_cmdln.gd` ainda saía com código 0 — a CI e o runner local davam verde sem ter executado um único teste. O runner agora sempre delega ao `install_gut.sh`, que já compara o carimbo `.gut_version` com a versão fixada

### 🔧 Técnico

- [x] **Ciclo de vida dos 16 jogos concentrado em `shared/`** — o botão voltar tinha 14 cópias, o reiniciar 11 (mais 3 sob outro nome), o fim de partida 8 e a grade de toque 6. Nasceram `shared/BaseGame.gd` (navegação de volta, reinício, `game_over`, `finish_game()`, `set_status()`, `reveal_result_modal()`) e `shared/GridGame.gd` (`build_touch_grid()`, herdada pelos 6 jogos cujo tabuleiro é uma grade). Os 16 jogos e a tela de *placeholder* migraram **um por commit**, com a suíte verde em cada um: `_on_btn_back_pressed` foi de 14 para 1, `_on_btn_restart_pressed` de 11 para 1 e `_setup_touch_grid` de 6 para 0. `games/` perdeu 207 linhas e `shared/` ganhou 152, das quais 146 são as duas classes novas
- [x] **Nenhuma abstração forçada nos jogos de cartas** — o corte não é *tabuleiro × cartas* e sim *quem tem grade de células*: Mancala, Ludo e Dominó são de tabuleiro e herdam direto de `BaseGame`; Blackjack, Uno-like e Paciência são de cartas e compartilham voltar, reiniciar e fim de partida. O Poker é o caso-limite — video poker não tem fim de partida nem botão reiniciar, a rodada anda por um `game_phase` de três estados — e por isso herda **só a navegação**, deixando `finish_game()`, `btn_restart` e `_start_new_game()` intocados. Nenhuma bandeira ou condicional foi acrescentada a `BaseGame` para acomodar exceção
- [x] **A IA dos 4 jogos continua separada** — `get_best_move` aparece 4 vezes, mas são 4 algoritmos que só coincidem no nome: heurística fixa devolvendo `int` no Jogo da Velha, minimax com poda alfa-beta devolvendo `Vector2i` no Reversi, primeira jogada válida devolvendo `Dictionary` nas Damas e vencer/bloquear/aleatório sobre um `ConnectFourBoard` no Quatro em Linha. Uma assinatura comum exigiria um tipo de estado comum e um conceito de jogada comum, para quatro implementações que não se substituem. **Fica como está**
- [x] **Bandeiras de fim de partida unificadas** — `game_won` da Paciência era o `game_over` do jogo com outro nome (guardava os quatro tratadores de toque e nada mais) e virou a bandeira herdada: uma a menos, não uma a mais. No Blackjack, `_start_game()` passou a se chamar `_start_new_game()` — era a única das 11 cópias do botão reiniciar que chamava outro nome. E o botão voltar da tela de *placeholder*, 14ª cópia, virou o `menu_scene_path` que ela preenche a partir da chave `current_menu`
- [x] **14 testes novos para a camada compartilhada** (mais 4 que vieram junto das migrações, somando 18 no total) — `tests/gdscript/unit/test_shared_lifecycle.gd` bate direto em `BaseGame` e `GridGame` (os dois nomes de cada botão caindo no mesmo método, `finish_game()` com e sem os nós opcionais, a mesa 3D comemorando só na vitória, e o tamanho, o callback, as casas desligadas e a remontagem da grade). Em `test_catalog.gd`, dois guardas pelo lado de fora: as 16 cenas instanciam como `BaseGame` apontando para o menu da própria categoria, e nenhum `.gd` de `games/` volta a declarar sua cópia do voltar, do reiniciar ou do `game_over`
- [x] **`core/estatisticas/` é um diretório vazio** — o plano de unificação previa ligar o ciclo compartilhado a `core/estatisticas`, `core/save`, `core/i18n` e `core/audio`. Só o áudio entrou (`play_click()`, que os botões voltar e reiniciar agora tocam nos 16 jogos, antes só em 3). Estatísticas não existem: o diretório está vazio e o git não rastreia nada dentro dele. `SaveManager` só tem `set_setting`/`get_setting` e nenhum jogo persiste partida ou placar — integrar exigiria inventar o contrato. E os status dos jogos são português fixo, sem chave no `translations.csv`: traduzir é projeto próprio. Os três cortes seguem a regra do próprio plano, de não acrescentar bandeira nem condicional a `BaseGame` para acomodar exceção
- [x] **`docs/CICLO_DE_VIDA_DOS_JOGOS.md`** — o levantamento função a função contra o que `shared/` já oferecia, com a contagem antes e depois e o registro de que `GenericGame` nunca foi classe-base, apesar do nome: é a tela de "em breve" mostrada quando um `GameDefinition` tem `is_implemented = false`
- [x] **GUT 9.7.1 como framework** — roda por `-s addons/gut/gut_cmdln.gd`, sem janela e sem habilitar plugin, e sai com código 1 quando há falha. O addon não é versionado (11 MB de código de terceiros, 8,8 MB deles num único `.tscn` do painel do editor): `tests/install_gut.sh` busca a versão fixada sob demanda. A versão está amarrada à engine — o 9.7.x exige Godot 4.4+ e o 9.3.x é o último que roda na 4.3
- [x] **Os 7 arquivos Python de teste foram removidos** — `test_board_games.py`, `test_card_games.py`, `test_integration_simulations.py`, `test_core_systems.py`, `test_i18n.py`, `test_all_games_catalog.py` e `run_tests.py`. Eles reimplementavam as regras de cada jogo em Python e testavam a reimplementação; os 70 arquivos `.gd` que rodam no aplicativo não eram exercitados por nada. Os casos foram aproveitados como especificação, um jogo por vez, e cada migração apagou o equivalente Python
- [x] **`export_presets.cfg`** — passa a excluir `tests/*`, `addons/*` e `.gutconfig.json`, para o APK não carregar código de teste
- [x] **Todos os branches de trabalho convergiram** — `claude/p07-gut-testes-reais`, `claude/p15-deduplicacao-jogos`, `claude/p04-varredura-segredos` e `claude/safety-p07` entraram na `develop` e daí na `master`; só `master` e `develop` seguem existindo. O único conflito real foi em `games/damas/CheckersGame.gd`, onde os dois lados mexeram no `_ready()`: ficou a herança de `GridGame` e o preenchimento dos nós de `BaseGame` da p15, mais o `apply_theme()`, o `set_safe_area()` e o `frame_content()` da safety-p07
- [x] **Campo Minado passou a falar com o tabuleiro pela API de estado** — `_sync_revealed_3d` e `_trigger_game_over` mexiam direto em `board_3d.cell_meshes[r][c]`, montando `StandardMaterial3D` na mão para cada casa; agora usam `board_3d.set_cell_state()` com `HIGHLIGHT`, `LAST_MOVE` e `INVALID`
- [x] **Empacotamento em AAB** — `export_presets.cfg` passa a `gradle_build/export_format=1`, com `min_sdk=24` e `target_sdk=35`, e o caminho de saída vira `build/android/PlayTable.aab`

**Achados registrados, ainda sem decisão:**

- [ ] **Regras duplicadas e código morto** — `TicTacToeRules.gd`, `ConnectFourRules.gd` e `MemoryRules.gd` não são referenciados por ninguém: as cenas têm a própria cópia das regras. `DominoGame` repete a orientação da pedra inline em dois lugares em vez de chamar `DominoRules.orient_tile_for_side`. Enquanto as duas versões existirem, os testes cobrem as duas — no Jogo da Velha, um teste compara as 6.561 posições possíveis para travar a divergência
- [ ] **IA do Uno joga com a cor fixa** — `UnoRules.pick_best_color_for_hand` implementa a heurística de maioria que o teste Python cobria, mas `UnoLikeGame` não a chama: ao jogar um curinga, a IA fixa `active_color` em azul (ou vermelho, no caminho de comprar-e-jogar)
- [ ] **`ConnectFourAI` promete minimax e não entrega** — o cabeçalho diz *"minimax with alpha-beta pruning"*; o código é vencer/bloquear/aleatório, sem poda e sem a preferência pela coluna central que o `ConnectFourRules` tem
- [ ] **Tabuleiro do Quatro em Linha desenhado de cabeça para baixo** — `ConnectFourGame._make_move` calcula `visual_row = (ROWS - 1) - row` apoiado num comentário que diz *"logic row 0 is bottom"*, mas `drop_piece` preenche do índice 5 para o 0, então a linha 0 é o topo. A primeira ficha de cada coluna é desenhada em cima e a pilha cresce para baixo
- [ ] **Nomes dos jogos nunca são traduzidos** — o `GameCatalog` aponta para chaves `GAME_DESC_*` que não existem no `translations.csv`, enquanto o CSV traz 16 chaves `GAME_*` com o nome de cada jogo que ninguém consome: `MenuTabuleiro` e `MenuCartas` montam o botão com `game.title`, texto fixo em português
- [ ] **`KlondikeRules.can_place_on_foundation` não confere o naipe na fundação vazia** — aceita qualquer ás em qualquer uma das quatro. Só não vira bug porque `KlondikeGame` confere `card.suit == req_suit` antes de chamar

## [v0.3.0 (2026-08-23)](https://github.com/ricasolucoes/PlayTable/compare/v0.2.1...v0.3.0)

### 🎨 Melhorias

- [x] **APK 11 MB menor** — as 16 capturas de tela em `screenshots/` eram importadas pelo Godot e viajavam dentro do aplicativo, porque o preset usa `export_filter="all_resources"`; um `.gdignore` no diretório tira as imagens do pacote sem removê-las do repositório. De 63,5 MB para 52,4 MB

### 🔧 Técnico

- [x] **Migração para Godot 4.6** — a 4.3 não tem como ser compilada no buildserver do F-Droid: o Debian trixie de lá só oferece JDK 21 e 25, o Godot exige exatamente o 17 em todas as versões, e o Gradle 8.2 que a 4.3 carrega sequer roda em Java 21 (suporte veio no 8.5). A 4.6 traz Gradle 8.11.1 e AGP 8.6.1, que rodam em 21. Os 70 scripts e 27 cenas importaram e exportaram sem uma única alteração em `project.godot` ou `export_presets.cfg`
- [x] **Arquivos `.uid` versionados** — o Godot 4.4+ passou a identificar cada script por UID em vez de caminho; os 70 arquivos entram no versionamento, como a documentação do Godot exige, para que mover um script não quebre as referências

## [v0.2.1 (2026-08-22)](https://github.com/ricasolucoes/PlayTable/compare/v0.2.0...v0.2.1)

### 🐛 Correções

- [x] **Autoloads ocultados por `class_name`** — `SceneManager`, `SaveManager`, `AudioManager` e `LocaleManager` declaravam uma classe global com o mesmo nome do singleton; no Godot 4.3 isso gerava `Class "X" hides an autoload singleton` e fazia 26 scripts (todos os menus e os 16 jogos) falharem ao carregar. Removida a linha `class_name` dos quatro autoloads
- [x] **Links quebrados na documentação** — os 16 links do catálogo no `README.md` apontavam para `file:///Users/...`; agora são relativos. Links do `CHANGELOG.md` migrados do GitLab privado para o GitHub
- [x] **`LICENSE`** — placeholder `[Developer Name]` substituído por `Ricardo Sierra`

### 🔧 Técnico

- [x] **`export_presets.cfg` completo e sem chaves** — o preset era um stub de ~17 chaves que o Godot 4.3 rejeitava (keystore parcialmente preenchida e `architecture/*` no singular, ignorado em favor de `architectures/*`). Regenerado com as 202 chaves de um preset real, sem nenhuma chave `keystore/*`, `package/signed=false`, `arm64-v8a` + `armeabi-v7a`, `package/name="PlayTable"`
- [x] **Preparação para F-Droid** — `export_presets.cfg` versionado (removido do `.gitignore`), cache do editor `.godot/` removido do índice (o `uid_cache.bin` reprovava no scanner e o `project_metadata.cfg` vazava caminhos absolutos). Scanner do F-Droid passa de 1 problema para 0
- [x] **Keystore de release removida do histórico** — a chave privada de assinatura estava versionada e publicamente acessível no GitHub e no GitLab, com a senha em claro no `build_apk.sh`. Histórico reescrito com `git filter-repo`, senha redigida e chave marcada como comprometida. Os SHAs de todos os commits mudaram e as tags foram recriadas
- [x] **`build_apk.sh`** — export sempre sem assinatura; assinatura virou passo separado com `apksigner`, usando `KEYSTORE_PATH` (fora do repositório) e `KEYSTORE_PASSWORD` via ambiente

## [v0.2.0 (2026-08-19)](https://github.com/ricasolucoes/PlayTable/compare/v0.1.0...v0.2.0)

### ✨ Novidades

- [x] **Suíte de Testes Automatizados e de Integração:** 64 testes unitários e de integração E2E criados e 100% aprovados, cobrindo todos os 16 minijogos de tabuleiro e cartas, persistência, regras de IA, internacionalização e simulações completas de partidas sem deadlocks
- [x] **Runner de Testes Mestre (`tests/run_tests.py`):** Script executável via terminal com relatório visual consolidado de cobertura por jogo e métricas de execução
- [x] **Catálogo Completo dos 11 Jogos de Tabuleiro Validados:** Regras e testes implementados para Jogo da Velha, Damas, Batalha Naval, Quatro em Linha, Resta Um (Solitário), Campo Minado, Dominó, Ludo, Reversi, Mancala e Senet Egípcio
- [x] **Catálogo Completo dos 5 Jogos de Cartas Validados:** Regras e testes implementados para Paciência Klondike, Jogo da Memória, 21 (Blackjack), Cartas das Cores (Uno-like) e Poker (Video Poker)
- [x] **Internacionalização (i18n):** Suporte multilíngue completo com `LocaleManager.gd` e catálogos traduzidos em Português (`pt_BR`), Inglês (`en`) e Espanhol (`es`)
- [x] **Sistema de Áudio Centralizado:** Implementação de `AudioManager.gd` para efeitos sonoros e controle de volume persistente

### 🎨 Melhorias

- [x] **Ícone Vetorial Autoral (`icon.svg`):** Arte vetorial minimalista com dados e cartas estilizados em gradiente dourado e tema escuro
- [x] **Aprimoramento Visual 3D:** Peças esculpidas, tabuleiros texturizados e integração com `TabletopBackground.gd` e `TabletopEnvironment3D`
- [x] **Tema Escuro Moderno:** `MainTheme.tres` otimizado com botões arredondados, contrastes legíveis e estilo tabletop sofisticado

### 🐛 Correções

- [x] **Compatibilidade Godot 4 GDScript:** Corrigidas chamadas de construtor `super()` em `AIPlayerController.gd` e alinhadas assinaturas de métodos em todas as regras dos jogos (`BattleshipRules`, `CheckersRules`, `DominoRules`, `KlondikeRules`, `MinesweeperRules`, `PokerEvaluator`, `ReversiRules`, `PegSolitaireRules` e `UnoRules`)
- [x] **Paridade de Enums em Cartas:** Adicionados `SpecialType` e `ColorType` para descarte correto no Uno-like e tratamento de Ás dinâmico no Blackjack
- [x] **Resolução de Modal no macOS:** Tratado travamento de diálogo modal de persistência do AppKit via `-ApplePersistenceIgnoreState YES` na execução headless

### 🔧 Técnico

- [x] **Pipeline de Build Android (`build_apk.sh`):** Exportação headless automatizada gerando APK assinado (`JogosDeMesaOffline.apk`) via `apksigner` com `release.keystore`
- [x] **Arquitetura Modular:** Separação estrita em `core/` (save, áudio, i18n, navegação), `shared/` (motores de peças, tabuleiros, baralhos) e `games/` (módulos isolados por jogo)
- [x] **Zero Ads, Zero Tracking & 100% Offline:** Sem SDKs invasivos, sem internet necessária e dados salvos exclusivamente no dispositivo local

---

## [v0.1.0 (2026-08-18)](https://github.com/ricasolucoes/PlayTable/releases/tag/v0.1.0)

### ✨ Novidades

- [x] **Estrutura Base do Projeto:** Inicialização do repositório Godot 4.3 Engine para 16 minijogos de tabuleiro e cartas
- [x] **Navegação & Telas:** Menus de seleção divididos em Menu Principal, Menu de Tabuleiros e Menu de Cartas
- [x] **Persistência de Dados (`SaveManager.gd`):** Gerenciamento de configurações locais em JSON (`user://config.save`)
- [x] **Documentação Arquitetural:** Criação dos guias técnicos em `docs/` e `README.md`
