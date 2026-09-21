# PlayTable — sistema visual e layout mobile para iPhone

## Resumo

O PlayTable precisa tratar o iPhone como uma plataforma de primeira classe, e
não como uma janela menor das cenas desktop. A reforma proposta cria um
contrato visual compartilhado para todas as telas de jogo, torna a composição
de HUD dependente da área segura real do aparelho e dá caminhos de fallback
determinísticos para recursos 3D assíncronos.

O resultado esperado é uma experiência coerente em que a faixa superior, os
indicadores, os botões de ação, as cartas e as peças usam a mesma linguagem
visual; nenhum elemento é escondido pela faixa ou por outro controle; e os
jogos continuam legíveis no iPhone 11 conectado, em portrait, sem depender de
um atlas que ainda não terminou de renderizar.

## Evidências do diagnóstico

O diagnóstico foi feito no checkout atual, na branch
`refactor/modularizacao-jogos-core`, com o iPhone 11 físico
`00008030-001028D614DA802E` conectado, pareado e em iOS 26.5.

### Faixa superior e sobreposições

- `shared/ui/GameTopBar.gd` monta o véu visual até aproximadamente 168 px e
  posiciona a linha da barra usando a área segura. A barra já tem voltar,
  título, score, modo e ajuda, mas os conteúdos legados não conhecem um
  contrato de `content_top`.
- `shared/ui/GameShell.tscn` começa a coluna de status em `offset_top=134`.
  `games/reversi/ReversiGame.tscn` repete esse início fixo. Esses elementos
  podem cair sob o véu da barra no iPhone.
- Outras cenas ainda usam posições fixas como 180, 220 e 246 px
  (`KlondikeGame.tscn`, `PokerGame.tscn` e `SudokuGame.tscn`, entre outras),
  portanto um ajuste isolado na barra não corrige o sistema.
- `shared/BaseGame.gd` chama `measure_hud_bands`, mas a varredura ignora parte
  da hierarquia quando há `Container` intermediário. A câmera pode receber uma
  medida diferente da composição visual real.
- `tests/gdscript/integration/test_layout_mobile.gd` e
  `tools/mobile_layout_audit.gd` verificam limites da tela, fontes e tamanho
  mínimo de toque, mas não verificam colisão entre retângulos, conteúdo sob o
  véu ou ordem visual.

### Cartas invisíveis

- `shared/3d/Card3D.gd` só cria a malha e o material em `_update_visuals` após
  `CardAtlas3D.ensure_built` terminar.
- `shared/3d/CardAtlas3D.gd` cria um `SubViewport`, espera inserção na árvore e
  dois `frame_post_draw`; depois lê a textura. Se o viewport não produzir uma
  imagem válida no momento esperado do iPhone, o card permanece sem malha
  visível.
- Blackjack, Klondike, Spider, Poker e UnoLike distribuem cartas antes de
  existir uma garantia de pixels válidos. Um erro no atlas, uma corrida de
  lifecycle ou uma imagem vazia não pode deixar o espaço da carta totalmente
  transparente.

### Reversi

- `games/reversi/ReversiRules.gd` mantém valores distintos para as duas cores,
  e `games/reversi/ReversiGame.gd` seleciona `obsidian` para um lado e `ivory`
  para o outro.
- Os assets `shared/assets/reversi/disco_preto.png` e
  `shared/assets/reversi/disco_branco.png` são diferentes e válidos. O risco
  está no caminho genérico de material/textura em
  `shared/3d/MaterialFactory3D.gd`, que não fornece uma garantia específica de
  contraste e legibilidade para renderização móvel.
- Portanto a correção deve preservar a regra e tornar a aparência verificável:
  lados distintos devem ter assinaturas de material, cores-base e valores de
  luminância claramente diferentes mesmo quando uma textura não carregar.

### Ludo e linguagem visual

- `games/ludo/LudoGame.gd` monta uma base de madeira, quatro quadrantes,
  discos circulares e um centro dourado. A pista é funcional, porém plana e
  sem hierarquia suficiente para distinguir base, casas, chegada e área de
  ação.
- O projeto já possui peões em
  `shared/assets/ludo/peao_vermelho.png`, `peao_azul.png`, `peao_verde.png` e
  `peao_amarelo.png`, mas os peões atuais são somente formas procedurais e não
  vinculam esses assets.
- `shared/theme/MainTheme.tres` ainda usa fontes grandes e caixas marrom/dourado
  com aparência legada, enquanto `shared/ui/UIKit.gd` e os presets em
  `shared/3d/GameTheme3D.gd` possuem vocabulários parcialmente diferentes.

### Linha de base de qualidade

A suíte existente tem 816 testes, dos quais 801 passam e 15 falham no estado
atual. As falhas são anteriores à reforma visual e começam em
`games/general/GeneralGame.gd:92`, onde o parser não consegue inferir o tipo de
`vp`; depois aparecem erros de lifecycle porque a cena cai para `Control` sem o
script esperado. A verificação final só será confiável quando essa linha de
base for saneada ou quando os testes forem isolados de maneira explícita e a
falha residual for explicada.

## Objetivos

1. Definir uma barra superior consistente em todas as telas, com área segura,
   título, voltar, indicadores pequenos nos lados e uma zona de status que não
   fique sob o véu.
2. Fazer a posição do conteúdo, da câmera e do trilho inferior depender de
   métricas compartilhadas, sem coordenadas mágicas específicas de uma altura
   de tela.
3. Garantir que cada carta tenha uma representação visível imediata e que o
   atlas só substitua o fallback depois de produzir pixels válidos.
4. Garantir contraste e diferenciação visual das peças do Reversi em mobile.
5. Dar ao Ludo uma composição moderna, legível e integrada ao mesmo sistema de
   tokens e ações dos demais jogos, reaproveitando os peões existentes.
6. Substituir os estilos legados de botões, cartões, estados e fundos por um
   conjunto de tokens moderno, consistente e acessível ao toque.
7. Cobrir cada regressão com testes estruturais e validar o resultado no iPhone
   físico, em portrait, incluindo captura visual antes do encerramento.

## Fora do escopo

- Reescrever as regras ou a inteligência dos jogos.
- Alterar o protocolo multiplayer, o relay ou os serviços de rede.
- Criar um novo pacote de ilustrações quando os assets existentes são
  suficientes. Assets novos só serão considerados se a implementação provar
  que os atuais não atendem a uma necessidade visual concreta; nesse caso,
  deverão seguir a proveniência centralizada em `/Users/sierra/Dev/Jogos/Assets`.
- Prometer suporte a tamanhos ou orientações que não forem exercitados pelo
  contrato mobile. O contrato deve ser extensível, mas a aceitação inicial é o
  iPhone conectado em portrait.

## Decisões de arquitetura

### 1. Contrato `MobileGameChrome`

Criar um componente compartilhado, preferencialmente em
`shared/ui/MobileGameChrome.gd` e sua cena correspondente, ou evoluir
`GameTopBar` sem duplicar lógica. O contrato expõe:

- `safe_top_px`, `bar_rect` e `content_top_px` calculados por
  `JogosSafeArea`/`BaseGame`, nunca constantes de cena;
- slot esquerdo para voltar e um ícone contextual opcional;
- título truncável com largura reservada;
- slot direito composto por chips compactos de score/turno/vidas e ícones de
  modo, ajuda ou conexão, com largura máxima e prioridade definida;
- `status_rect` abaixo da barra, usado por nível, mensagens e placares
  legados;
- `bottom_action_rect` para o trilho inferior, incluindo safe area e teclado
  quando aplicável;
- sinais ou callbacks para que o jogo atualize score, turno, modo e estado sem
  reconstruir a cena;
- z-order documentado: chrome acima do conteúdo 3D, status dentro da área de
  conteúdo e modal/resultados acima de ambos.

Os slots devem esconder ou condensar indicadores de baixa prioridade quando o
espaço ficar estreito. O título nunca pode empurrar um botão para fora da
janela. Ícones precisam de rótulo acessível/tooltip quando houver suporte,
mas a leitura principal deve acontecer por cor, texto curto e forma — não só
por cor.

### 2. Métricas únicas de composição

`BaseGame` continuará sendo o dono da integração com câmera, mas passará a
publicar um objeto ou estrutura de métricas com:

```text
top_safe_px
chrome_bottom_px
content_top_px
content_bottom_px
bottom_safe_px
available_content_rect
```

O cálculo deve acontecer depois de a árvore de HUD estar pronta e sempre que
viewport, safe area, teclado ou orientação mudar. A medição deve atravessar
`Container` e `Control` ancorados; não pode depender apenas dos filhos diretos.

As cenas que hoje iniciam em 134/180/220/246 px serão migradas para âncoras ou
helpers relativos a `content_top_px`. O mesmo contrato será usado para o
trilho de ações, evitando que botões fixos ocupem a mesma faixa que o tabuleiro
ou que outro botão.

Para telas com mais ações do que cabem, a regra é:

1. agrupar ações primárias em uma linha de altura mínima de toque;
2. mover ações secundárias para menu/folha contextual;
3. permitir wrap controlado ou rolagem horizontal apenas dentro do trilho;
4. nunca deixar dois controles com retângulos sobrepostos sem uma relação
   explícita de modal/overlay.

### 3. Tokens visuais

Centralizar em `UIKit`/`MainTheme` os tokens de:

- fundo profundo azul-grafite e superfícies elevadas;
- texto primário, texto secundário e texto desabilitado;
- acento ciano/azul para interação e dourado somente para destaque;
- estados de sucesso, alerta e erro com contraste suficiente;
- raio, borda, sombra e elevação dos cartões;
- altura mínima de toque e espaçamento de 8 px como unidade;
- estilos de botão primário, secundário, destrutivo e ícone.

Os jogos 3D continuam podendo ter materiais próprios para a mesa, mas os
elementos de interface, status e ação devem usar os mesmos tokens. O tema não
deve depender de caixas marrom/douradas legadas de
`shared/theme/MainTheme.tres`.

### 4. Cartas fail-safe

`Card3D` terá uma sequência explícita:

1. criar mesh, dimensões, colisão e um material procedural de fallback no
   primeiro `_ready`/`setup`, sem `await` obrigatório;
2. exibir frente/verso identificável, incluindo o valor da carta se possível,
   usando cor sólida e texto ou uma textura já disponível;
3. iniciar ou reutilizar o warm-up do atlas;
4. aceitar o atlas somente se `is_ready` e sua imagem tiver dimensão esperada,
   canais válidos e pixels não uniformemente transparentes/pretos;
5. aplicar a textura em todos os cards interessados e manter o fallback se
   houver falha, timeout ou viewport liberado cedo demais.

`CardAtlas3D` deve expor estado de construção e erro recuperável, evitar
   múltiplos builders concorrentes e liberar o `SubViewport` somente depois de
   copiar uma imagem válida. O aquecimento será iniciado em um ponto previsível
   — menu ou entrada do jogo — e também continuará seguro quando uma cena for
   aberta diretamente.

O mesmo contrato será aplicado ao atlas de Uno, sem introduzir um segundo
   comportamento assíncrono especial.

### 5. Reversi contrastante

O Reversi receberá materiais móveis explícitos para as duas faces. Cada lado
   deverá ter:

- cor-base e roughness distintas;
- fallback sem textura com contraste suficiente;
- textura de arte opcional aplicada apenas quando válida;
- marcador visual de seleção/última jogada que não dependa de trocar o disco
   branco para preto;
- assinatura verificável nos testes (por exemplo, cor-base/material distinto e
   nome de arte distinto).

A regra do jogo continua sendo a fonte de verdade para o valor 1/2. A camada
   visual não poderá inferir a cor a partir da posição ou de um estado global.

### 6. Ludo moderno

O tabuleiro será reorganizado em camadas visuais claras:

- mesa/superfície moderna com contraste suficiente;
- quatro áreas de base com cantos arredondados ou molduras consistentes;
- pista com casas espaçadas e estados de início destacados;
- linhas de chegada coloridas apontando para o centro;
- centro com objetivo visual único, sem competir com os peões;
- peões usando os assets de `shared/assets/ludo` quando o caminho de textura for
  válido, com forma procedural como fallback;
- feedback de seleção/movimento e jogador atual usando o mesmo componente de
  estado dos demais jogos.

O tabuleiro será dimensionado por `fit_table` a partir de
`available_content_rect`, preservando margem para a barra e o trilho de dado.
O dado e a ação principal usarão o trilho inferior compartilhado, não uma
posição absoluta que possa cobrir o tabuleiro.

### 7. Migração incremental das cenas

O chrome será instalado pelo `BaseGame`/`GameShell` para que as 27 cenas que
herdam de `BaseGame` recebam o contrato sem cópia de código. Depois as cenas
com HUD mais complexo serão migradas em grupos:

1. jogos de cartas e Reversi, por serem diretamente afetados pelos bugs
   reportados;
2. Ludo e jogos com trilho inferior de ações;
3. jogos com status superior fixo, como Sudoku;
4. revisão dos demais jogos e remoção de coordenadas mágicas restantes.

Durante a migração, uma camada de compatibilidade poderá mapear labels legados
para `status_rect`, mas não deve manter duas barras ou desenhar o mesmo score
em posições concorrentes.

## Estratégia de testes

A implementação seguirá TDD: cada correção começa com um teste que falha,
depois recebe a menor implementação que atende o contrato e, por fim, roda a
suíte relevante e a suíte completa.

### Testes unitários/estruturais

- `MobileGameChrome` expõe retângulos sem interseção para barra, status e
  trilho inferior em viewports do iPhone 11, iPhone SE e viewport de referência.
- Chips e ícones são reduzidos/ocultados conforme prioridade, sem empurrar o
  botão voltar ou o título para fora da tela.
- O scanner de HUD atravessa containers e detecta retângulos escondidos pelo
  chrome, além de detectar sobreposição não modal.
- `GameShell` usa `content_top_px` e não inicia sob a barra.
- O auditador reporta o nome dos nós, retângulos e tipo de violação para
  facilitar diagnóstico.

### Cartas

- `Card3D` possui mesh/material visível antes do atlas terminar.
- Atlas pronto com pixels válidos substitui o fallback.
- Atlas vazio, preto uniforme, transparente ou com erro mantém o fallback e
  registra estado recuperável.
- Um baralho completo consegue criar e mostrar todas as cartas após warm-up sem
  condição de corrida.

### Reversi

- A sincronização cria lados 1 e 2 com materiais visualmente distintos.
- O fallback sem textura mantém luminâncias diferentes.
- A conversão de regra para material permanece correta depois de flip e reset.

### Ludo

- O tabuleiro contém quatro bases, pista, linhas de chegada, centro e 16
  peões com cores distintas.
- Cada peão tenta o asset correto e cai para material procedural sem ficar
  invisível.
- O dado e o botão de ação ficam dentro de `bottom_action_rect` e não cobrem o
  tabuleiro.

### Verificação visual e no dispositivo

- Rodar `tests/run_gut.sh` completo, tratando falhas de parse/lifecycle de
  `GeneralGame` como bloqueadoras da linha de base.
- Rodar `tools/mobile_layout_audit.gd` com detecção de sobreposição e conteúdo
  sob o véu.
- Exportar o projeto iOS com `scripts/ios_export.sh`.
- Compilar/instalar a build no iPhone 11 identificado acima.
- Capturar a tela real, não uma imagem simulada, em MainMenu, um jogo de cartas,
  Ludo e Reversi; repetir após entrar em uma partida e executar uma ação.
- Conferir visualmente: score acima da faixa/na zona correta, ícones nos slots,
  cartas legíveis, duas cores de Reversi, Ludo hierárquico, botões separados e
  identidade compartilhada.
- Repetir a navegação em pelo menos três jogos adicionais para garantir que o
  contrato não ficou específico às quatro telas principais.

## Plano de rollout e rollback

Cada etapa deve ser um commit pequeno e reversível, nesta ordem:

1. corrigir a linha de base de carregamento de `GeneralGame` e adicionar os
   testes de métricas/overlap;
2. introduzir tokens e `MobileGameChrome` com compatibilidade;
3. migrar `GameShell` e HUDs fixos para as métricas;
4. implementar fallback/validação de atlas e aquecimento de cartas;
5. corrigir materiais do Reversi;
6. redesenhar Ludo e vinculá-lo aos assets existentes;
7. migrar as telas restantes, remover constantes antigas e atualizar o audit;
8. exportar, instalar e executar a verificação física final.

Se uma etapa causar regressão, o commit da etapa pode ser revertido sem perder
as correções independentes anteriores. Não serão feitos resets destrutivos do
checkout; mudanças preexistentes devem permanecer preservadas.

## Critérios de aceitação

O objetivo só será considerado concluído quando todas as condições abaixo
forem demonstradas no estado atual:

1. nenhum score/status fica sob a faixa preta no iPhone;
2. todas as telas usam o chrome compartilhado, com slots laterais funcionais
   ou explicitamente vazios por prioridade;
3. cartas aparecem mesmo com falha/atraso do atlas e recebem arte quando o
   atlas é válido;
4. Reversi mostra peças pretas e brancas distinguíveis em cada estado;
5. Ludo mostra tabuleiro, peões, pista e ações com hierarquia moderna;
6. botões, placares e tabuleiros não se sobrepõem em nenhuma tela auditada;
7. os tokens visuais compartilhados substituem os estilos legados relevantes;
8. a suíte e os audits passam, ou qualquer exceção é corrigida e comprovada
   como fora do escopo;
9. a build instalada no iPhone conectado foi exercitada e as capturas reais
   confirmam os quatro fluxos principais.
