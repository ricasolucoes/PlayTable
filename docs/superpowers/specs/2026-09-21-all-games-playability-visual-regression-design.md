# PlayTable — jogabilidade e regressão visual de todos os jogos

## Objetivo

Garantir que todos os jogos registrados no `GameCatalog`, e as cenas de jogos
que ainda estão fora dele, possam ser abertos e jogados no iPhone em portrait
sem peças, cartas ou desenhos invisíveis, sem erros de parser e sem controles
se sobrepondo. A experiência deve parecer um único produto: chrome superior,
indicadores laterais, status, ações e estados visuais compartilham a mesma
linguagem.

Esta especificação complementa
`docs/superpowers/specs/2026-09-21-iphone-visual-system-design.md`. A primeira
especificação trata o contrato geral de safe area e chrome; esta fecha as
regressões encontradas ao exercitar partidas e importar o catálogo completo.

## Evidências e sintomas aceitos como bugs

- Damas passa pelo material triplanar genérico de `Token3D`, enquanto Reversi
  aplica textura e cor-base diretamente. No renderizador local as duas cores
  ainda aparecem, mas o caminho não garante contraste no iPhone; os dois lados
  precisam continuar distinguíveis após criação, movimento, captura e promoção.
- Campo Minado depende de `DecalGrid3D` para números e de `Sprite3D` para mina e
  bandeira. O tabuleiro local aparece quando o painel de regras é fechado, mas
  não existe um teste que prove pixels úteis depois de uma jogada em mobile.
  O fallback precisa funcionar se shader, atlas ou textura falhar.
- Os jogos de cartas criam `Card3D` antes de o atlas assíncrono terminar. O
  fallback de mesh atual é coberto apenas por uma checagem estrutural; não há
  garantia de que frente, verso e cartas de Memória permaneçam identificáveis
  após uma partida. Poker começa sem cartas até a ação de distribuição, que
  deve ser exercitada no teste em vez de ser confundida com invisibilidade.
- A importação completa do projeto expõe erros em Xadrez e Trilha que a suíte
  parcial não alcança: constantes `Packed*Array` usadas como `const` não são
  aceitas nesta versão do Godot e `ModeSwitch` não está resolvido em todas as
  cenas.
- Capturas existentes mostram estilos antigos e inconsistentes, texto de
  status misturado com controles e cartas do UNO pressionadas por uma faixa
  horizontal. A migração deve eliminar colisões, não apenas mudar cores.

## Critérios de sucesso

1. Cada entrada de `GameCatalog.get_all_games()` carrega sua `PackedScene`,
   instancia como `BaseGame` e executa pelo menos uma ação representativa sem
   erro de parser, erro de runtime ou elemento visual essencial ausente.
2. Cada cena adicional em `games/*/*Game.tscn` é classificada explicitamente:
   entra no catálogo ou fica documentada como não disponível. Nenhuma cena
   existente pode permanecer silenciosamente quebrada.
3. Damas exibe luminâncias e texturas distintas para os lados claro e escuro,
   inclusive depois de captura e promoção; Reversi preserva o comportamento
   atual.
4. Campo Minado exibe célula fechada, célula aberta com número, bandeira e
   mina revelada em mobile. Cada elemento tem fallback visível e não depende
   de um atlas assíncrono único.
5. Cada jogo de cartas que começa com cartas mostra verso ou frente
   identificável antes do atlas; depois de uma ação mostra a frente correta.
   Memória mostra o desenho do verso e o símbolo ao virar; Poker distribui
   cartas antes de validar a mesa; UNO não corta a mão nem esconde cartas sob
   scrollbar ou controles.
6. Em viewports portrait de referência, nenhum retângulo de chrome, status,
   tabuleiro, carta ou ação primária fica sob a faixa superior, dentro da safe
   area inferior ou sobre outro controle não-modal.
7. O estilo visual usa os tokens compartilhados já existentes: superfícies
   modernas, contraste acessível, estados claros e tamanho mínimo de toque.
   Não haverá uma segunda barra ou uma posição fixa específica de cada jogo.

## Abordagem de arquitetura

### 1. Contrato de validação jogável

Criar uma camada de testes de integração que enumere o catálogo real e as
cenas extras. Cada adaptador de jogo terá uma sequência curta e determinística:
instanciar, aguardar a montagem, localizar a ação pública ou simular o toque
em uma jogada legal, e validar invariantes de estado e visibilidade. Os
adaptadores não reimplementarão regras; usarão os métodos de produção e
posições legais fornecidas pelas regras.

O resultado de uma cena será descrito por uma pequena evidência verificável:
lista de nós esperados, materiais/cores ou texturas válidas, retângulos de
layout e, quando necessário, amostras de pixels da captura mobile. Falha de
parse ou ausência de ação é erro bloqueador, não um screenshot “vazio” aceito.

### 2. Peças de tabuleiro

Adicionar ao `MaterialFactory3D` uma construção explícita de peça de tabuleiro
com lado, cor-base, textura opcional e fallback procedural. `CheckersGame`
deixará de depender do material triplanar para a identidade primária da peça;
`Token3D` continuará responsável pela forma, colisão e posição. A textura é
uma melhoria, nunca a única origem do contraste. O material deve ser criado
antes de qualquer warm-up e reaplicado quando uma peça for reconstruída.

### 3. Campo Minado

Manter os assets existentes, mas separar a garantia de legibilidade do caminho
de shader. `MinesweeperGame` tentará o atlas e `Sprite3D` quando válidos; caso
contrário usará uma representação procedural/`Label3D` de alto contraste para
número, mina e bandeira. O estado do jogo continua sendo a fonte de verdade,
e o desenho será sincronizado por célula após abrir, marcar, desmarcar e perder.
O painel de regras pode continuar disponível, mas não pode ocultar
silenciosamente a mesa durante a entrada de jogo ou os testes de partida.

### 4. Cartas

`Card3D` continuará exibindo um fallback imediato. A validação do atlas será
fortalecida para rejeitar imagem vazia, transparente ou uniforme sem remover o
fallback. A frente procedural precisa exibir uma assinatura da carta (valor,
cor ou símbolo); o atlas só substitui essa superfície depois de pixels válidos.
O mesmo contrato será usado pelo atlas padrão e pelo atlas UNO. `MemoryCard`
manterá seu desenho 2D, mas será testado no estado fechado, aberto e pareado.

### 5. Chrome e layout

Usar as métricas compartilhadas de `BaseGame`/`GameTopBar` e os tokens já
introduzidos. Cada cena registra suas bandas de conteúdo e ação; coordenadas
absolutas restantes serão substituídas por anchors, containers ou helpers
relativos a `content_rect` e `bottom_action_rect`. Indicadores pequenos ficam
nos slots laterais da faixa e cedem por prioridade em telas estreitas.

Quando houver mais ações que cabem, ações secundárias serão agrupadas em menu
ou folha contextual. Rolagem fica restrita ao conteúdo que precisa dela; a
mão do UNO, por exemplo, não pode compartilhar a área útil com o scrollbar de
forma que cartas sejam cortadas.

### 6. Importação e cenas fora do catálogo

Corrigir primeiro os erros de importação de Xadrez e Trilha. Em seguida,
estender o teste de catálogo para enumerar as cenas e verificar que cada
script possui dependências resolvidas. A correção será mínima: trocar apenas
declarações incompatíveis com o parser atual por valores tipados em runtime e
substituir `ModeSwitch` pela interface compartilhada já usada pelas demais
cenas, sem alterar regras ou IA.

## Arquivos e fronteiras prováveis

- Testes: `tests/gdscript/integration/test_catalog.gd`,
  `tests/gdscript/integration/test_touch_input.gd`,
  `tests/gdscript/integration/test_layout_mobile.gd`,
  `tests/gdscript/unit/test_card_rendering.gd`,
  `tests/gdscript/unit/test_checkers.gd`,
  `tests/gdscript/unit/test_minesweeper.gd` e novos helpers de smoke visual.
- Peças e materiais: `shared/3d/Token3D.gd`,
  `shared/3d/MaterialFactory3D.gd`, `games/damas/CheckersGame.gd` e
  `games/reversi/ReversiGame.gd`.
- Campo Minado: `games/campo_minado/MinesweeperGame.gd`,
  `shared/3d/DecalGrid3D.gd` e seus recursos de arte.
- Cartas: `shared/3d/Card3D.gd`, `shared/3d/CardAtlas3D.gd`,
  `shared/3d/UnoCardAtlas3D.gd`, `games/memoria/MemoryCard.gd` e os fluxos
  de distribuição dos jogos de cartas.
- Layout: `shared/BaseGame.gd`, `shared/ui/GameTopBar.gd`,
  `shared/ui/GameShell.gd`, `shared/ui/UIKit.gd` e as cenas que ainda usam
  offsets fixos.
- Catálogo/importação: `core/configs/GameCatalog.gd`,
  `games/xadrez/*.gd` e `games/trilha/MorrisGame.gd`.

## Estratégia de testes e verificação

Cada frente seguirá red/green: primeiro adicionar um teste mínimo que reproduz
o sintoma e observar sua falha; depois implementar a correção mínima; por fim
rodar o teste focado, a auditoria mobile e a suíte completa.

As verificações obrigatórias são:

- teste de importação/instanciação do catálogo e das cenas adicionais;
- testes de materiais dos dois lados de Damas e Reversi;
- smoke test com jogada real em Campo Minado, Memória, Poker e cada família de
  cartas;
- auditoria de overlap e safe bands em todos os jogos;
- capturas headless com o renderizador `mobile` para inspeção visual;
- `tests/run_gut.sh` completo;
- exportação, instalação e lançamento no iPhone conectado, com captura real
  e leitura de logs quando o aparelho estiver desbloqueado.

Se o dispositivo permanecer bloqueado e impedir captura, isso será reportado
como limitação física da verificação, nunca convertido em aprovação visual.

## Fora do escopo

- Reescrever regras, IA, multiplayer ou persistência.
- Criar novos bitmaps enquanto os assets atuais e os fallbacks procedurais
  forem suficientes.
- Remover o painel de regras; apenas reposicioná-lo ou impedir que ele masque
  a validação da mesa.
- Considerar um teste de instanciação isolado como prova de que o jogo foi
  jogado.
