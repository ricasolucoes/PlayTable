# iPhone Visual System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Corrigir o chrome, layout, cartas, Reversi e Ludo e entregar uma experiência visual consistente, legível e sem sobreposições no iPhone físico conectado.

**Architecture:** `BaseGame` será a fonte única das métricas de área segura e
`GameTopBar` será a implementação do chrome mobile compartilhado, preservando
os métodos públicos que as cenas atuais já usam. Os jogos registrarão suas
áreas de conteúdo e ação contra essas métricas; cartas e peças terão fallback
procedural determinístico para não depender de renderização assíncrona.

**Tech Stack:** Godot 4.7.2, GDScript, GUT, `SubViewport`/`StandardMaterial3D`,
exportação Xcode para iOS e validação no iPhone 11 físico em iOS 26.5.

**Spec:** `docs/superpowers/specs/2026-09-21-iphone-visual-system-design.md`

## Global Constraints

- Usar Godot `4.7.2.stable.official.ed1daf0bf`, resolvido por `scripts/godot_bin.sh`.
- A aceitação inicial é portrait no iPhone 11 `00008030-001028D614DA802E`, iOS 26.5, sem remover suporte às proporções já auditadas.
- Manter regras, IA, multiplayer e serviços de rede inalterados; esta mudança é de composição e renderização.
- Reutilizar os assets existentes em `shared/assets`; nenhum bitmap novo será criado sem necessidade visual comprovada e proveniência registrada.
- Para cada bug, escrever e executar o teste que falha antes da implementação correspondente.
- Preservar mudanças existentes e não usar `git reset --hard`, `git checkout --` ou qualquer operação destrutiva.
- Manter a altura mínima de toque de `UIKit.TOQUE_MIN` e o padrão de safe area em todas as telas.
- Nenhuma carta ou peça pode ficar invisível apenas porque um atlas, textura ou viewport assíncrono falhou.
- A verificação final deve incluir a suíte GUT, o audit de layout, exportação/instalação iOS e capturas reais do dispositivo.

## Review Focus

- **Inset superior variável:** um iPhone com notch, um viewport sem safe area e um redimensionamento durante a partida devem manter conteúdo abaixo do chrome; coberto por `test_metrics_recompute_after_viewport_change` em Task 2.
- **Largura estreita:** título longo, dois scores, modo, badges e ajuda devem ceder por prioridade sem empurrar o voltar para fora; coberto por `test_chrome_collapses_low_priority_badges` em Task 2.
- **Árvore de containers:** HUD dentro de `VBoxContainer`/`HBoxContainer` deve ser medido e auditado, não ignorado por uma varredura rasa; coberto por `test_audit_finds_nested_overlap` em Task 3.
- **Falha de atlas:** imagem vazia, preta uniforme, transparente ou builder interrompido deve deixar uma carta visível; coberto por `test_invalid_atlas_keeps_card_fallback` em Task 4.
- **Renderizador móvel sem textura:** peças do Reversi e peões do Ludo devem continuar distintos quando o asset não estiver disponível; coberto por `test_reversi_fallback_materials_have_distinct_luminance` e `test_ludo_pawns_have_procedural_fallback` nas Tasks 5 e 6.

## File Map

Arquivos novos e responsabilidades:

- Create: `shared/ui/MobileHudMetrics.gd` — cálculo puro de retângulos de
  safe area, chrome, conteúdo e trilho inferior.
- Create: `tests/gdscript/unit/test_mobile_hud.gd` — testes unitários do
  contrato de métricas e prioridade do chrome.
- Create: `tests/gdscript/unit/test_card_rendering.gd` — testes de fallback,
  validação do atlas e baralho completo.
- Create: `tests/gdscript/unit/test_mobile_visuals.gd` — testes estruturais do
  Reversi, Ludo e tokens visuais compartilhados.

Arquivos compartilhados modificados:

- Modify: `shared/ui/GameTopBar.gd` — slots laterais, badges, chips e métricas;
  manter `set_duel_score`, `set_counters`, `oferecer_modo`, `esconder_modo` e
  os sinais existentes.
- Modify: `shared/BaseGame.gd` — expor métricas, registrar bandas, refazer
  medição profunda e reposicionar bindings quando a viewport mudar.
- Modify: `shared/ui/GameShell.gd` e `shared/ui/GameShell.tscn` — status e
  restart abaixo do chrome e no trilho seguro.
- Modify: `shared/ui/UIKit.gd` e `shared/theme/MainTheme.tres` — tokens e
  estilos modernos de interface.
- Modify: `shared/3d/Card3D.gd`, `shared/3d/CardAtlas3D.gd` e
  `shared/3d/UnoCardAtlas3D.gd` — fallback imediato, estado de erro e
  validação de pixels.
- Modify: `shared/3d/Token3D.gd` e `shared/3d/MaterialFactory3D.gd` — assinatura
  de material, materiais móveis do Reversi e arte opcional de peões.

Arquivos de jogos modificados:

- Modify: `games/general/GeneralGame.gd` — corrigir o tipo do viewport que
  atualmente impede o script de carregar.
- Modify: `games/reversi/ReversiGame.gd` e `games/reversi/ReversiGame.tscn` —
  materiais explícitos e HUD baseada em conteúdo.
- Modify: `games/ludo/LudoGame.gd` e `games/ludo/LudoGame.tscn` — composição
  visual moderna, peões com assets/fallback e trilho do dado.
- Modify: `games/blackjack/BlackjackGame.tscn`,
  `games/paciencia/KlondikeGame.tscn`,
  `games/paciencia_spider/SpiderGame.tscn`, `games/poker/PokerGame.tscn` e
  `games/unolike/UnoLikeGame.tscn` — bindings de conteúdo/ação e remoção de
  offsets fixos das telas de cartas.
- Modify: `games/sudoku/SudokuGame.tscn`,
  `games/batalha_naval/BattleshipGame.tscn`,
  `games/campo_minado/MinesweeperGame.tscn`,
  `games/damas/CheckersGame.tscn`, `games/domino/DominoGame.tscn`,
  `games/gamao/BackgammonGame.tscn`, `games/mancala/MancalaGame.tscn`,
  `games/senet/SenetGame.tscn`, `games/jogo_da_velha/TicTacToeGame.tscn`,
  `games/quatro_em_linha/ConnectFourGame.tscn`,
  `games/solitario/PegSolitaireGame.tscn`,
  `games/memoria/MemoryGame.tscn`, `games/hanoi/HanoiGame.tscn`,
  `games/nim/NimGame.tscn`, `games/xadrez/ChessGame.tscn`,
  `games/trilha/MorrisGame.tscn`, `games/senha/MastermindGame.tscn` — substituir bandas superiores e
  inferiores absolutas pelos bindings do `BaseGame` onde existirem.

Auditoria e build modificadas:

- Modify: `tests/gdscript/integration/test_layout_mobile.gd` — verificar
  overlap, chrome e trilho em todas as proporções.
- Modify: `tools/mobile_layout_audit.gd` — emitir nó, retângulo e causa para
  cada violação, incluindo conteúdo sob o véu.
- Modify: `core/telas/MainMenu.gd` — solicitar warm-up dos dois atlas sem
  bloquear a abertura do menu.

## Task 1: Restaurar a linha de base do General

**Files:**
- Modify: `games/general/GeneralGame.gd:89-95`
- Test: `tests/gdscript/unit/test_general.gd`

**Interfaces:**
- Consumes: `SceneTree.root` e `JogosSafeArea.top(viewport)`.
- Produces: `GeneralGame.gd` carregável como classe `BaseGame` e
  `ModoGeneral._topo_botao() -> float` determinístico.

- [ ] **Step 1: Write the failing test**

Adicionar ao bloco de cena de `tests/gdscript/unit/test_general.gd`:

```gdscript
func test_a_cena_do_general_carrega_o_script_de_jogo() -> void:
    var cena := load("res://games/general/GeneralGame.tscn") as PackedScene
    assert_not_null(cena, "General carrega sem erro de parser")
    var jogo := add_child_autofree(cena.instantiate())
    assert_true(jogo is BaseGame, "General continua sendo um BaseGame")
    assert_true(jogo is GeneralGame, "o script especializado nao foi descartado")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_general.gd`

Expected: FAIL/erro de carregamento em `GeneralGame.gd:92` com a mensagem de
que o tipo de `vp` não pode ser inferido; os erros de atributos em cascata
confirmam que a cena caiu para `Control`.

- [ ] **Step 3: Write minimal implementation**

Em `ModoGeneral._topo_botao`, substituir as duas inferências ambíguas por
variáveis anotadas:

```gdscript
static func _topo_botao() -> float:
    var vp: Viewport = null
    var loop := Engine.get_main_loop()
    if loop is SceneTree:
        vp = (loop as SceneTree).root
    var inset: float = JogosSafeArea.top(vp) if vp != null else 0.0
    return 8.0 + 88.0 + inset + 8.0
```

- [ ] **Step 4: Run test to verify it passes**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_general.gd`

Expected: o teste novo e os testes de regra/cena do General passam; qualquer
falha restante será registrada pelo nome do teste e tratada antes da Task 2.

- [ ] **Step 5: Commit**

```bash
git add games/general/GeneralGame.gd tests/gdscript/unit/test_general.gd
git commit -m "fix: restore General scene loading"
```

## Task 2: Criar métricas e chrome mobile compartilhados

**Files:**
- Create: `shared/ui/MobileHudMetrics.gd`
- Create: `tests/gdscript/unit/test_mobile_hud.gd`
- Modify: `shared/ui/GameTopBar.gd:26-340`
- Modify: `shared/BaseGame.gd:1-410`
- Modify: `shared/ui/GameShell.gd`
- Modify: `shared/ui/GameShell.tscn:19-55`

**Interfaces:**
- Consumes: `JogosSafeArea.insets`, `Viewport.size_changed` e os métodos
  públicos existentes de `GameTopBar`.
- Produces: `MobileHudMetrics.calculate(...)`,
  `BaseGame.get_mobile_hud_metrics()`,
  `BaseGame.register_mobile_band(control, band, margin)`,
  `GameTopBar.set_context_badges(badges)` e a signal
  `GameTopBar.layout_changed(metrics)`.

- [ ] **Step 1: Write the failing tests**

Criar `tests/gdscript/unit/test_mobile_hud.gd` com estes testes e helpers:

```gdscript
extends GutTest

const Metrics = preload("res://shared/ui/MobileHudMetrics.gd")

func test_content_begins_after_chrome_and_ends_before_bottom_safe_area() -> void:
    var m: MobileHudMetrics = Metrics.calculate(
        Vector2(828.0, 1792.0), Vector4(0.0, 96.0, 0.0, 34.0), 88.0, 132.0)
    assert_eq(m.chrome_rect.position.y, 96.0)
    assert_gte(m.content_rect.position.y, m.chrome_rect.end.y)
    assert_lte(m.content_rect.end.y, 1792.0 - 34.0 - 132.0)
    assert_true(m.bottom_rect.position.y >= m.content_rect.end.y)

func test_metrics_recompute_after_viewport_change() -> void:
    var m: MobileHudMetrics = Metrics.calculate(
        Vector2(720.0, 1280.0), Vector4(0.0, 0.0, 0.0, 0.0), 88.0, 88.0)
    var resized: MobileHudMetrics = m.resized(
        Vector2(720.0, 1600.0), Vector4(0.0, 44.0, 0.0, 22.0))
    assert_eq(resized.chrome_rect.position.y, 44.0)
    assert_gt(resized.content_rect.size.y, m.content_rect.size.y)

func test_chrome_collapses_low_priority_badges() -> void:
    var top := GameTopBar.new()
    add_child_autofree(top)
    top.size = Vector2(828.0, 1792.0)
    top.game_title = "Jogo de Cores e Cartas"
    top.set_context_badges([
        {"id": "turn", "icon": "↻", "priority": 100, "tooltip": "Turno"},
        {"id": "moves", "icon": "✦", "priority": 20, "tooltip": "Jogadas"},
        {"id": "network", "icon": "⌁", "priority": 10, "tooltip": "Conexao"},
    ])
    await wait_process_frames(2)
    assert_true(top.has_badge("turn"))
    assert_lte(top.visible_badge_count(), 2)
    assert_true(top.get_node("Linha/BtnBack").get_global_rect().end.x <= 828.0)

func test_chrome_exposes_content_top_after_safe_area() -> void:
    var top := GameTopBar.new()
    add_child_autofree(top)
    top.size = Vector2(828.0, 1792.0)
    await wait_process_frames(2)
    assert_gte(top.content_top_px, top.BANDA)
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_hud.gd`

Expected: FAIL porque `MobileHudMetrics`, `set_context_badges`,
`has_badge`, `visible_badge_count` e `content_top_px` ainda não existem.

- [ ] **Step 3: Implement the metrics object**

Criar `shared/ui/MobileHudMetrics.gd` com esta interface concreta:

```gdscript
class_name MobileHudMetrics
extends RefCounted

var viewport_size: Vector2
var safe_insets: Vector4
var chrome_rect: Rect2
var content_rect: Rect2
var bottom_rect: Rect2

static func calculate(size: Vector2, insets: Vector4, chrome_height: float, bottom_height: float) -> MobileHudMetrics:
    var result := MobileHudMetrics.new()
    result.viewport_size = size
    result.safe_insets = insets
    var usable_left := maxf(0.0, insets.x)
    var usable_right := maxf(0.0, size.x - insets.z)
    var chrome_bottom := minf(size.y, insets.y + chrome_height)
    var bottom_top := maxf(chrome_bottom, size.y - insets.w - bottom_height)
    result.chrome_rect = Rect2(usable_left, insets.y, usable_right - usable_left, chrome_height)
    result.content_rect = Rect2(usable_left, chrome_bottom,
        usable_right - usable_left, maxf(0.0, bottom_top - chrome_bottom))
    result.bottom_rect = Rect2(usable_left, bottom_top,
        usable_right - usable_left, maxf(0.0, size.y - insets.w - bottom_top))
    return result

func resized(size: Vector2, insets: Vector4) -> MobileHudMetrics:
    return calculate(size, insets, chrome_rect.size.y, bottom_rect.size.y)

func rect_is_inside_viewport(rect: Rect2) -> bool:
    return rect.position.x >= safe_insets.x and rect.position.y >= safe_insets.y \
        and rect.end.x <= viewport_size.x - safe_insets.z \
        and rect.end.y <= viewport_size.y - safe_insets.w
```

- [ ] **Step 4: Refactor `GameTopBar` to own the chrome contract**

Adicionar no topo da classe:

```gdscript
signal layout_changed(metrics: MobileHudMetrics)
var mobile_metrics: MobileHudMetrics
var content_top_px: float = 0.0
var content_bottom_px: float = 0.0
var _badges: Dictionary = {}
```

No `_atualizar_safe_area`, calcular os insets, preencher
`mobile_metrics`, atualizar `BANDA`, `content_top_px` e `content_bottom_px`,
reaplicar offsets da linha e emitir `layout_changed`. Em `_montar_linha`,
criar `Badges` antes de `Placar`, preservando espaço para `BtnMode` e
`BtnRules`. Implementar:

```gdscript
func set_context_badges(badges: Array[Dictionary]) -> void
func has_badge(id: String) -> bool
func visible_badge_count() -> int
func get_badge(id: String) -> Control
```

Cada badge será um `Button` de `UIKit.TOQUE_MIN`, com prioridade numérica; em
`NOTIFICATION_RESIZED`, esconder primeiro o menor `priority` até o título e
os controles obrigatórios caberem. O score continuará acima do véu e não será
movido para coordenada fixa de cena.

- [ ] **Step 5: Integrate `BaseGame` and `GameShell`**

Em `BaseGame`, adicionar:

```gdscript
var mobile_hud_metrics: MobileHudMetrics
var _mobile_bands: Array[Dictionary] = []

func get_mobile_hud_metrics() -> MobileHudMetrics:
    return mobile_hud_metrics

func register_mobile_band(control: Control, band: StringName, margin: float = 16.0) -> void
func _layout_mobile_bands() -> void
```

`register_mobile_band` aceitará apenas `&"content"` ou `&"bottom"`, salvará o
controle e fará `_layout_mobile_bands`. `_layout_mobile_bands` usará
`mobile_hud_metrics.content_rect`/`bottom_rect`, respeitando o tamanho mínimo
do controle e emitindo um erro estruturado se a banda não comportar o
controle. `measure_hud_bands()` continuará retornando `Vector2` para
compatibilidade, mas passará a usar a mesma medição profunda.

`GameShell.gd` localizará o `BaseGame` ancestral, registrará sua coluna como
`&"content"` e o botão restart como `&"bottom"`; `GameShell.tscn` deixará
`offset_top=0`/`offset_bottom=0` para que a posição real venha do contrato.

- [ ] **Step 6: Run tests to verify they pass**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_hud.gd`

Expected: 4 testes passam; depois rodar
`tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_layout_mobile.gd`
e registrar as violações que ainda pertencem à Task 3.

- [ ] **Step 7: Commit**

```bash
git add shared/ui/MobileHudMetrics.gd shared/ui/GameTopBar.gd shared/BaseGame.gd shared/ui/GameShell.gd shared/ui/GameShell.tscn tests/gdscript/unit/test_mobile_hud.gd
git commit -m "feat: add shared mobile game chrome"
```

## Task 3: Migrar HUDs e tornar o audit de layout rigoroso

**Files:**
- Modify: `games/reversi/ReversiGame.tscn`,
  `games/blackjack/BlackjackGame.tscn`,
  `games/paciencia/KlondikeGame.tscn`,
  `games/paciencia_spider/SpiderGame.tscn`, `games/poker/PokerGame.tscn`,
  `games/unolike/UnoLikeGame.tscn`, `games/sudoku/SudokuGame.tscn`
- Modify: `games/batalha_naval/BattleshipGame.tscn`,
  `games/campo_minado/MinesweeperGame.tscn`,
  `games/damas/CheckersGame.tscn`, `games/domino/DominoGame.tscn`,
  `games/gamao/BackgammonGame.tscn`, `games/mancala/MancalaGame.tscn`,
  `games/senet/SenetGame.tscn`, `games/jogo_da_velha/TicTacToeGame.tscn`,
  `games/quatro_em_linha/ConnectFourGame.tscn`,
  `games/solitario/PegSolitaireGame.tscn`,
  `games/memoria/MemoryGame.tscn`, `games/hanoi/HanoiGame.tscn`,
  `games/nim/NimGame.tscn`, `games/xadrez/ChessGame.tscn`,
  `games/trilha/MorrisGame.tscn`, `games/senha/MastermindGame.tscn`
- Modify: `tests/gdscript/integration/test_layout_mobile.gd`
- Modify: `tools/mobile_layout_audit.gd`
- Create: `tests/gdscript/unit/test_mobile_visuals.gd`

**Interfaces:**
- Consumes: `BaseGame.register_mobile_band`, `MobileHudMetrics.content_rect`,
  `GameTopBar.set_context_badges`.
- Produces: todas as cenas de jogo com `metadata/mobile_hud_band` ou registro
  explícito, nenhum offset superior fixo abaixo de `content_top_px` e um audit
  que rejeita sobreposição não modal.

- [ ] **Step 1: Write the failing overlap tests**

Adicionar em `test_layout_mobile.gd` um helper que percorre a árvore inteira,
converte cada `Control` visível para `get_global_rect()` e compara pares que
não são ancestrais/descendentes. Adicionar também:

```gdscript
func test_nenhum_hud_fica_sob_a_faixa_ou_sobre_outro_controle() -> void:
    for caminho in JOGOS + MENUS:
        for rotulo in PROPORCOES:
            var raiz := await _montar(caminho, PROPORCOES[rotulo])
            if raiz == null:
                continue
            var chrome := raiz.get_node_or_null("GameTopBar") as GameTopBar
            if chrome == null:
                continue
            var proibida := Rect2(0.0, 0.0, float(PROPORCOES[rotulo].x), chrome.content_top_px)
            for controle in _controles(raiz, "Control"):
                if controle == chrome or chrome.is_ancestor_of(controle) \
                    or controle.get_meta("allow_overlay", false):
                    continue
                assert_false(proibida.intersects(controle.get_global_rect()),
                    "%s/%s: %s sob chrome" % [caminho, rotulo, controle.name])
```

Adicionar `test_audit_finds_nested_overlap` criando um `VBoxContainer` com duas
`Button`s que se intersectam por offsets artificiais e verificar que a função
de auditoria retorna os dois nomes.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_layout_mobile.gd`

Expected: FAIL em cenas com `offset_top` 134/180/220/246 e em pelo menos uma
HUD aninhada; a saída deve nomear cena, nó e retângulo.

- [ ] **Step 3: Migrate the common shell and the four affected families**

Em cada cena, remover o `offset_top` absoluto da área que é status/conteúdo e
registrar o nó no `_ready` da classe do jogo:

```gdscript
register_mobile_band($UI, &"content", 16.0)
register_mobile_band($UI/ActionRail, &"bottom", 16.0)
```

Aplicar explicitamente:

- Reversi: `UI` como content e score/status para `GameShell.status_label`.
- Klondike/Spider/Poker/Blackjack/UnoLike: tabela/área de cartas como content;
  ações como bottom, mantendo cada Container interno intacto.
- Sudoku: grade e status abaixo do chrome, com teclado/controles no bottom.
- Batalha Naval/Campo Minado/Damas/Domino/Gamão/Mancala/Senet: tabuleiro
  content e ações bottom, sem alterar regras ou picker.
- Jogo da Velha/Quatro em Linha/Resta Um/Memória/Hanoi/Nim/Xadrez/Trilha/
  Senha: trocar apenas posições HUD fixas por registro na banda correta.

Para uma tela sem trilho inferior, não criar uma barra vazia: registrar apenas
o content e deixar `bottom_rect` livre para a câmera.

- [ ] **Step 4: Make the audit traverse containers and z-order**

Em `tools/mobile_layout_audit.gd`, substituir a coleta de filhos diretos por
uma fila completa. Ignorar somente:

```gdscript
func _pode_sobrepor(a: Control, b: Control) -> bool:
    return a.get_meta("allow_overlay", false) or b.get_meta("allow_overlay", false) \
        or a.z_index != b.z_index and (a is PopupPanel or b is PopupPanel)
```

Emitir três códigos distintos: `UNDER_CHROME`, `OVERLAP` e `OUT_OF_SAFE_AREA`.
Cada linha deve conter o caminho dos nós, `Rect2` de ambos e a banda esperada.

- [ ] **Step 5: Run targeted tests and audit**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_layout_mobile.gd`

Expected: todas as proporções `9:16`, `20:9` e `3:4` passam sem violações.

Run: `scripts/godot_bin.sh --headless --path . --script tools/mobile_layout_audit.gd`

Expected: `TOTAL VIOLATIONS: 0`, sem `UNDER_CHROME` ou `OVERLAP`.

- [ ] **Step 6: Commit**

```bash
git add games tests/gdscript/integration/test_layout_mobile.gd tools/mobile_layout_audit.gd
git commit -m "fix: migrate game HUDs to mobile safe bands"
```

## Task 4: Tornar cartas visíveis sem depender do atlas

**Files:**
- Create: `tests/gdscript/unit/test_card_rendering.gd`
- Modify: `shared/3d/Card3D.gd:35-75`
- Modify: `shared/3d/CardAtlas3D.gd:20-120`
- Modify: `shared/3d/UnoCardAtlas3D.gd` na interface equivalente
- Modify: `core/telas/MainMenu.gd` no warm-up de materiais

**Interfaces:**
- Consumes: `MeshBuilder3D.card_mesh`, `CardArt2D`, `Image` e o atlas de Uno.
- Produces: `CardAtlas3D.is_valid_image(image) -> bool`,
  `CardAtlas3D.request_warmup() -> void`,
  `Card3D.apply_fallback_visuals() -> void`,
  `Card3D.has_visible_visual() -> bool` e `ensure_built(owner) -> bool` nos
  dois atlas.

- [ ] **Step 1: Write the failing tests**

Criar `tests/gdscript/unit/test_card_rendering.gd`:

```gdscript
extends GutTest

const CardScene = preload("res://shared/3d/Card3D.tscn")
const Atlas = preload("res://shared/3d/CardAtlas3D.gd")
const Art = preload("res://shared/3d/CardArt2D.gd")

func test_atlas_rejeita_imagem_transparente_ou_preta_uniforme() -> void:
    var transparente := Image.create(180, 252, false, Image.FORMAT_RGBA8)
    assert_false(Atlas.is_valid_image(transparente))
    var preta := Image.create(180, 252, false, Image.FORMAT_RGBA8)
    preta.fill(Color.BLACK)
    assert_false(Atlas.is_valid_image(preta))

func test_atlas_aceita_imagem_com_pixels_de_arte() -> void:
    var imagem := Image.create(180, 252, false, Image.FORMAT_RGBA8)
    imagem.fill(Color.WHITE)
    assert_true(Atlas.is_valid_image(imagem))

func test_invalid_atlas_keeps_card_fallback() -> void:
    var card := add_child_autofree(CardScene.instantiate())
    card.setup("A", Art.SUIT_SPADE, false)
    await wait_process_frames(1)
    card.apply_fallback_visuals()
    assert_true(card.has_visible_visual(), "carta visivel antes do atlas")
    assert_not_null(card.mesh_instance.mesh)
```

Adicionar um teste que instancia 52 `Card3D`, chama `setup`, espera 3 frames e
confirma `has_visible_visual()` em todos, sem exigir que o atlas esteja pronto.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_card_rendering.gd`

Expected: FAIL porque `is_valid_image`, `apply_fallback_visuals` e
`has_visible_visual` não existem e o `Card3D` atual só atribui mesh depois do
`await ensure_built`.

- [ ] **Step 3: Add atlas validation and a single warm-up state**

Em `CardAtlas3D` e `UnoCardAtlas3D`:

```gdscript
static var _state: String = "cold"
static var _last_error: String = ""

static func is_valid_image(image: Image) -> bool:
    var minimum := _cell_size()
    if image == null or image.is_empty() \
        or image.get_width() < minimum.x or image.get_height() < minimum.y:
        return false
    var center := image.get_pixel(image.get_width() / 2, image.get_height() / 2)
    var corner := image.get_pixel(0, 0)
    var edge := image.get_pixel(image.get_width() - 1, image.get_height() - 1)
    var has_alpha := center.a > 0.05 or corner.a > 0.05 or edge.a > 0.05
    var has_ink := center.get_luminance() > 0.02 \
        or corner.get_luminance() > 0.02 \
        or edge.get_luminance() > 0.02 \
        or center.distance_to(corner) > 0.01
    return has_alpha and has_ink

static func request_warmup() -> void:
    if _state == "building" or is_ready():
        return
    _state = "building"
    var tree := Engine.get_main_loop() as SceneTree
    if tree == null:
        _state = "failed"
        _last_error = "no SceneTree"
        return
    var owner := Node.new()
    tree.root.add_child.call_deferred(owner)
    _warmup_and_release(owner)

static func _warmup_and_release(owner: Node) -> void:
    await ensure_built(owner)
    if is_instance_valid(owner):
        owner.queue_free()

static func last_error() -> String:
    return _last_error
```

A implementação real deve preencher `_state="ready"` somente após validar a
imagem copiada do `SubViewport`, usar `_state="failed"` em qualquer erro e
manter o cache concorrente único. `ensure_built(owner)` retornará `true` só
quando a textura tiver passado por `is_valid_image`.

- [ ] **Step 4: Add the immediate Card3D fallback**

Em `_ready`, executar `apply_fallback_visuals()` antes do `await`:

```gdscript
func apply_fallback_visuals() -> void:
    if mesh_instance == null:
        return
    mesh_instance.mesh = MeshBuilder3D.card_mesh(
        Tokens3D.CARD_WIDTH, Tokens3D.CARD_LENGTH, Tokens3D.CARD_THICKNESS,
        Rect2(0.0, 0.0, 1.0, 1.0), Rect2(0.25, 0.25, 0.5, 0.5))
    var fallback := StandardMaterial3D.new()
    fallback.albedo_color = Color(0.08, 0.18, 0.32) if not is_face_up else Color(0.96, 0.97, 0.99)
    fallback.roughness = 0.52
    mesh_instance.set_surface_override_material(0, fallback)
    mesh_instance.set_surface_override_material(1, MaterialFactory3D.get_ivory())
    rotation_degrees.z = 0.0 if is_face_up else 180.0

func has_visible_visual() -> bool:
    return mesh_instance != null and mesh_instance.mesh != null \
        and mesh_instance.get_surface_override_material(0) != null
```

Depois do `await`, aplicar arte do atlas somente quando o booleano retornado
for verdadeiro; em erro, manter o material fallback e registrar um warning
único por atlas. Atualizar a interface do Uno para o mesmo contrato.

- [ ] **Step 5: Warm the atlases without blocking navigation**

Em `core/telas/MainMenu.gd`, chamar `CardAtlas3D.request_warmup()` e
`UnoCardAtlas3D.request_warmup()` depois do warm-up síncrono de materiais, sem
`await` na transição do menu. A abertura direta de qualquer jogo continua
funcionando pelo fallback.

- [ ] **Step 6: Run tests and card-game smoke tests**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_card_rendering.gd`

Expected: todos os cards têm mesh/material no primeiro frame útil; atlas válido
é aplicado após o warm-up; atlas inválido não apaga a carta.

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_blackjack.gd`

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_paciencia.gd`

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_poker.gd`

Expected: distribuição e regras permanecem verdes, sem card transparente.

- [ ] **Step 7: Commit**

```bash
git add shared/3d/Card3D.gd shared/3d/CardAtlas3D.gd shared/3d/UnoCardAtlas3D.gd core/telas/MainMenu.gd tests/gdscript/unit/test_card_rendering.gd
git commit -m "fix: keep cards visible before atlas warmup"
```

## Task 5: Corrigir contraste e material do Reversi

**Files:**
- Modify: `shared/3d/MaterialFactory3D.gd` na família de materiais de peças
- Modify: `shared/3d/Token3D.gd`
- Modify: `games/reversi/ReversiGame.gd:99-121`
- Modify: `games/reversi/ReversiGame.tscn` na HUD
- Modify: `tests/gdscript/unit/test_reversi.gd`
- Modify: `tests/gdscript/unit/test_mobile_visuals.gd`

**Interfaces:**
- Consumes: valor 1/2 de `ReversiRules`, `AssetCatalog` e os PNGs
  `reversi/disco_preto`/`reversi/disco_branco`.
- Produces: `MaterialFactory3D.reversi_piece(side, art_key)`,
  `Token3D.get_visual_material()` e peças com assinatura de cor estável,
  inclusive sem textura.

- [ ] **Step 1: Write the failing visual tests**

Adicionar a `test_mobile_visuals.gd`:

```gdscript
extends GutTest

const ReversiScene = preload("res://games/reversi/ReversiGame.tscn")

func test_reversi_fallback_materials_have_distinct_luminance() -> void:
    var preto := MaterialFactory3D.reversi_piece(1, "")
    var branco := MaterialFactory3D.reversi_piece(2, "")
    assert_ne(preto.albedo_color, branco.albedo_color)
    assert_lt(preto.albedo_color.get_luminance(), 0.25)
    assert_gt(branco.albedo_color.get_luminance(), 0.65)

func test_reversi_scene_creates_both_piece_signatures() -> void:
    var jogo := add_child_autofree(ReversiScene.instantiate())
    await wait_process_frames(3)
    jogo._sync_pieces_3d()
    var assinaturas: Array[String] = []
    for p in jogo.pieces_root.get_children():
        assinaturas.append(str(p.get_visual_material().albedo_color))
    assert_true(assinaturas.size() >= 4)
    var tem_diferenca := false
    for assinatura in assinaturas.slice(1):
        if assinatura != assinaturas[0]:
            tem_diferenca = true
            break
    assert_true(tem_diferenca, "as duas faces tem assinaturas diferentes")
```

Adicionar em `test_reversi.gd` um teste de flip que confirma que o lado 1 usa
material preto e o lado 2 usa material branco depois de `_sync_pieces_3d`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_visuals.gd`

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_reversi.gd`

Expected: FAIL porque o factory não tem `reversi_piece`, o Token3D não expõe
material e a cena atual usa caminhos genéricos que podem convergir para preto.

- [ ] **Step 3: Implement explicit mobile materials**

Adicionar em `MaterialFactory3D.gd`:

```gdscript
static func reversi_piece(side: int, art_key: String) -> StandardMaterial3D:
    var key := "reversi_%d_%s" % [side, art_key]
    if _cache.has(key):
        return _cache[key]
    var mat := StandardMaterial3D.new()
    mat.albedo_color = Color(0.055, 0.075, 0.12) if side == 1 else Color(0.94, 0.96, 1.0)
    mat.roughness = 0.24 if side == 1 else 0.38
    mat.metallic = 0.0
    mat.rim_enabled = true
    mat.rim = 0.38 if side == 1 else 0.12
    var texture := AssetCatalog.get_game_art_by_key(art_key)
    if texture != null:
        mat.albedo_texture = texture
    _cache[key] = mat
    return mat
```

A assinatura deverá preservar `albedo_color` mesmo quando a textura existe.
Adicionar `Token3D.get_visual_material() -> Material` retornando o material
da superfície principal.

- [ ] **Step 4: Use side as the source of truth in Reversi**

Em `_sync_pieces_3d`, mapear `1 -> reversi_piece(1,
"reversi/disco_preto")` e `2 -> reversi_piece(2, "reversi/disco_branco")`;
não usar `by_name("obsidian")`/`by_name("ivory")` para esses discos. Em
`ReversiGame.tscn`, registrar UI/status na banda content e remover
`offset_top=134`.

- [ ] **Step 5: Run tests to verify they pass**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_visuals.gd`

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_reversi.gd`

Expected: peças 1/2 têm luminâncias diferentes, a regra e os flips continuam
passando e nenhuma peça depende de uma textura para se distinguir.

- [ ] **Step 6: Commit**

```bash
git add shared/3d/MaterialFactory3D.gd shared/3d/Token3D.gd games/reversi/ReversiGame.gd games/reversi/ReversiGame.tscn tests/gdscript/unit/test_reversi.gd tests/gdscript/unit/test_mobile_visuals.gd
git commit -m "fix: give Reversi pieces explicit mobile contrast"
```

## Task 6: Redesenhar o Ludo com os assets existentes

**Files:**
- Modify: `games/ludo/LudoGame.gd:104-185` e `_setup_3d_pawns`
- Modify: `games/ludo/LudoGame.tscn`
- Modify: `shared/3d/MaterialFactory3D.gd` somente se faltar fallback de peão
- Modify: `tests/gdscript/unit/test_ludo.gd`
- Modify: `tests/gdscript/unit/test_mobile_visuals.gd`

**Interfaces:**
- Consumes: `QUAD_COLORS`, `START_OFFSETS`, `Token3D.art_by_material`,
  `MobileHudMetrics.bottom_rect` e assets `shared/assets/ludo`.
- Produces: bases, pista, chegadas e centro com hierarquia clara; 16 peões
  com arte opcional e fallback; dado dentro da banda bottom.

- [ ] **Step 1: Write the failing visual tests**

Adicionar a `test_mobile_visuals.gd`:

```gdscript
const LudoScene = preload("res://games/ludo/LudoGame.tscn")

func test_ludo_pawns_have_procedural_fallback() -> void:
    var jogo := add_child_autofree(LudoScene.instantiate())
    await wait_process_frames(3)
    assert_eq(jogo.pawns_3d[0].size(), 4)
    for pawn in jogo.pawns_3d[0]:
        assert_eq(pawn.art_by_material["plastic_red"], "ludo/peao_vermelho")
        assert_not_null(pawn.get_visual_material())

func test_ludo_has_four_bases_track_finish_and_center() -> void:
    var jogo := add_child_autofree(LudoScene.instantiate())
    await wait_process_frames(3)
    assert_eq(jogo.visual_layer(&"HomeZones").get_child_count(), 4)
    assert_gte(jogo.visual_layer(&"Track").get_child_count(), 28)
    assert_gte(jogo.visual_layer(&"FinishLanes").get_child_count(), 16)
    assert_gt(jogo.visual_layer(&"Goal").get_child_count(), 0)
    assert_true(jogo.get_mobile_hud_metrics().bottom_rect.has_point(
        jogo.btn_dice.get_global_rect().get_center()))
```

Adicionar a `test_ludo.gd` uma asserção de que `btn_dice` não intersecta a
projeção/rect do conteúdo após três frames.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_visuals.gd`

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_ludo.gd`

Expected: FAIL porque os peões não configuram `art_by_material`, o botão ainda
usa posição absoluta e a composição atual não expõe zonas nomeadas.

- [ ] **Step 3: Refactor the board into named visual layers**

Em `_setup_3d_ludo_board`, criar nós nomeados `BoardSurface`, `HomeZones`,
`Track`, `FinishLanes` e `Goal`. Manter a lógica de coordenadas do jogo, mas:

- trocar a base marrom por uma superfície azul-grafite com borda dourada fina;
- usar quatro superfícies de base com `QUAD_COLORS` em alpha visualmente suave e
  uma moldura clara;
- criar casas da pista com marfim alternado e largadas saturadas;
- criar linhas finais com cinco casas, separador e direção visual para o centro;
- criar o centro como peça elevada com aro, não como disco dourado solto;
- adicionar `z_index`/altura de cada camada para não haver z-fighting.

O tamanho lógico continuará `Vector2(6.7, 6.7)`, para preservar a câmera e a
interação já testadas, mas a superfície terá margens internas e os objetos
serão instanciados nos nós nomeados.

Expor no jogo o helper usado pelos testes e pela inspeção visual:

```gdscript
func visual_layer(name: StringName) -> Node:
    return board_root.get_node_or_null(NodePath(name))
```

- [ ] **Step 4: Use the existing pawn art with fallback**

Antes de `pawns_root.add_child(pawn)`, atribuir:

```gdscript
pawn.art_by_material = {
    "plastic_red": "ludo/peao_vermelho",
    "plastic_blue": "ludo/peao_azul",
    "plastic_green": "ludo/peao_verde",
    "plastic_yellow": "ludo/peao_amarelo",
}
```

`Token3D` continuará chamando `MaterialFactory3D.get_textured`; quando o
asset não carregar, `get_textured` deve retornar o material plástico colorido
sem textura, nunca `null`.

- [ ] **Step 5: Move dice to the shared bottom rail**

Remover offsets negativos fixos de `LudoGame.tscn`, registrar
`$UI/DiceArea` como `&"bottom"` e colocar o botão em uma `HBoxContainer` com
altura `UIKit.TOQUE_MIN`. O tabuleiro deve usar `fit_table` depois de a banda
estar registrada, para que a câmera receba a área útil correta.

- [ ] **Step 6: Run tests and commit**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_visuals.gd`

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_ludo.gd`

Expected: 16 peões têm material, as zonas visuais existem, o dado fica no
trilho inferior e as regras de Ludo continuam verdes.

```bash
git add games/ludo/LudoGame.gd games/ludo/LudoGame.tscn tests/gdscript/unit/test_ludo.gd tests/gdscript/unit/test_mobile_visuals.gd shared/3d/Token3D.gd
git commit -m "feat: modernize Ludo mobile board"
```

## Task 7: Unificar tokens e remover o estilo legado

**Files:**
- Modify: `shared/ui/UIKit.gd`
- Modify: `shared/theme/MainTheme.tres`
- Modify: `shared/ui/GameTopBar.gd` para usar tokens
- Modify: `core/telas/MainMenu.gd` somente onde estilos duplicados divergirem
- Modify: `tests/gdscript/unit/test_mobile_visuals.gd`

**Interfaces:**
- Consumes: estilos atuais de `UIKit`, `GameTopBar` e `MainTheme`.
- Produces: constantes `UIKit.COLOR_SURFACE`, `COLOR_SURFACE_RAISED`,
  `COLOR_ACCENT`, `COLOR_TEXT`, `COLOR_MUTED`, `RADIUS_CARD`,
  `SPACE_UNIT` e factories de botão/chip/ícone com o mesmo visual.

- [ ] **Step 1: Write the failing token tests**

Adicionar:

```gdscript
func test_tokens_de_interface_sao_consistentes_e_nao_herdam_marrom_legado() -> void:
    assert_ne(UIKit.COLOR_SURFACE, Color(0.27, 0.16, 0.10))
    assert_gte(UIKit.TOQUE_MIN, 88.0)
    var botao := UIKit.botao("Teste")
    add_child_autofree(botao)
    assert_gte(botao.custom_minimum_size.x, UIKit.TOQUE_MIN)
    assert_gte(botao.custom_minimum_size.y, UIKit.TOQUE_MIN)
    assert_true(UIKit.RADIUS_CARD >= 12.0)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_visuals.gd`

Expected: FAIL pela ausência dos tokens novos ou pelos valores legados.

- [ ] **Step 3: Implement the token set**

Em `UIKit.gd`, declarar os tokens e fazer `botao`, `rotulo`, `hbox`,
`cartao` e chips consultarem essas constantes. Em `MainTheme.tres`, trocar
fontes/StyleBoxFlat marrom-dourados por superfícies azul-grafite, borda
transparente clara, raio mínimo 12 e estados pressed/focus explícitos.

Os textos traduzidos continuarão vindo de `tr()`; não hardcodar rótulos nos
novos badges.

- [ ] **Step 4: Run visual token tests and layout audit**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_visuals.gd`

Expected: os tokens passam e nenhum botão perde o alvo mínimo.

Run: `scripts/godot_bin.sh --headless --path . --script tools/mobile_layout_audit.gd`

Expected: `TOTAL VIOLATIONS: 0`.

- [ ] **Step 5: Commit**

```bash
git add shared/ui/UIKit.gd shared/theme/MainTheme.tres shared/ui/GameTopBar.gd core/telas/MainMenu.gd tests/gdscript/unit/test_mobile_visuals.gd
git commit -m "style: unify modern mobile interface tokens"
```

## Task 8: Verificação completa, exportação e iPhone físico

**Files:**
- Modify only files required by fresh verification failures.
- Evidence: `build/ios/PlayTable.xcodeproj`, screenshots/captures from the
  connected iPhone and command logs kept outside the repository as QA output.

**Interfaces:**
- Consumes: todos os contratos das Tasks 1–7, `scripts/ios_export.sh`,
  `xcodebuild` e `xcrun devicectl`.
- Produces: suíte verde, audit sem violações, build instalada no bundle
  `org.playtable.app` e evidência visual dos quatro fluxos principais.

- [ ] **Step 1: Run the full automated suite**

Run: `tests/run_gut.sh`

Expected: 0 failures, 0 ignored test scripts and no parse errors. Se `General`
ou outro script falhar, corrigir a causa antes de prosseguir; não mascarar
falhas com `pending`.

- [ ] **Step 2: Run the mobile audit fresh**

Run: `scripts/godot_bin.sh --headless --path . --script tools/mobile_layout_audit.gd`

Expected: `TOTAL VIOLATIONS: 0`, com zero `UNDER_CHROME`, `OVERLAP` e
`OUT_OF_SAFE_AREA` em todas as telas listadas.

- [ ] **Step 3: Export the iOS project**

Run: `scripts/ios_export.sh`

Expected: regenerar `build/ios/PlayTable.xcodeproj` com bundle
`org.playtable.app`, deployment target existente e os recursos compartilhados
presentes.

- [ ] **Step 4: Build and install on the connected iPhone**

Run:

```bash
xcodebuild -project build/ios/PlayTable.xcodeproj -scheme PlayTable -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios/DerivedData build
xcrun devicectl device install app --device 00008030-001028D614DA802E build/ios/DerivedData/Build/Products/Debug-iphoneos/PlayTable.app
xcrun devicectl device process launch --device 00008030-001028D614DA802E org.playtable.app
```

Expected: build e instalação sem erro, aplicação abre no aparelho físico e
continua interativa em portrait.

- [ ] **Step 5: Capture and inspect the required flows**

No iPhone, capturar a tela real em:

1. MainMenu;
2. Klondike ou Blackjack com cartas distribuídas;
3. Ludo antes e depois de rolar o dado;
4. Reversi no início e após uma virada;
5. três jogos adicionais escolhidos entre Sudoku, Damas, Batalha Naval,
   UnoLike e Poker.

Para cada captura conferir explicitamente: score/status abaixo da faixa, ícones
nos slots laterais, ausência de interseção entre botão e tabuleiro, cartas
visíveis, preto/branco do Reversi e identidade visual compartilhada. Registrar
qualquer falha com o nome da tela e voltar à Task correspondente.

- [ ] **Step 6: Run the final regression suite after device fixes**

Run: `tests/run_gut.sh && scripts/godot_bin.sh --headless --path . --script tools/mobile_layout_audit.gd`

Expected: ambos os comandos retornam código 0 imediatamente antes do handoff.

- [ ] **Step 7: Commit the verified release changes**

```bash
git status --short
git diff --check
git add shared games tests tools core
git commit -m "fix: finish iPhone visual system"
```

Só criar o commit final se os dois comandos de verificação e a inspeção física
estiverem documentados; não declarar o objetivo concluído com base apenas em
testes headless.
