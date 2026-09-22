# All-games Playability and Visual Regression Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fazer todos os jogos do PlayTable carregarem, serem jogáveis e permanecerem visualmente legíveis no iPhone, corrigindo peças, cartas, desenhos e sobreposições.

**Architecture:** O catálogo e o teste de smoke serão a fonte única do conjunto
de cenas exercitadas. Materiais de peças, atlas de cartas, glifos do Campo
Minado e bandas de HUD terão fallbacks determinísticos; as regras existentes
continuarão sendo a fonte de verdade dos movimentos. A migração de layout
usará as métricas já presentes em `BaseGame`/`GameTopBar` e o auditador único
de retângulos.

**Tech Stack:** Godot 4.7.2, GDScript, GUT, `StandardMaterial3D`,
`Label3D`/`Sprite3D`, `SubViewport`, renderizador `mobile`, scripts de captura
headless e exportação Xcode para iOS.

**Spec:** `docs/superpowers/specs/2026-09-21-all-games-playability-visual-regression-design.md`

## Global Constraints

- A aceitação inicial é portrait no iPhone 11 `00008030-001028D614DA802E`, iOS 26.5, sem remover suporte às proporções já auditadas.
- Usar a engine definida em `.godot-version`, resolvida por `scripts/godot_bin.sh`.
- Manter regras, IA, multiplayer, persistência e serviços de rede inalterados.
- Reutilizar os assets existentes em `shared/assets`; não criar bitmap novo.
- Para cada bug, observar o teste falhar antes da implementação correspondente.
- Preservar mudanças existentes; não usar `git reset --hard`, `git checkout --` ou limpeza destrutiva.
- Nenhuma carta, peça, número, mina ou bandeira pode ficar invisível por falha de textura, atlas ou shader.
- Rodar GUT, audit de layout, capturas mobile, exportação/instalação iOS e captura física quando o aparelho estiver desbloqueado.

## Review Focus

- **Cenas fora do catálogo:** `General`, `Copas`, `Trilha` e `Xadrez` precisam carregar, ter tradução e entrar na enumeração; coberto pelos testes de descoberta em Task 1.
- **Material sem textura no iPhone:** os lados claro/escuro de Damas e os ícones de Campo Minado precisam continuar distintos; coberto pelos testes de material e fallback nas Tasks 2 e 3.
- **Warm-up incompleto:** frente, verso e assinatura da carta precisam existir antes do atlas; coberto por `test_fallback_has_card_identity_before_atlas` na Task 4.
- **Ação real:** abrir/revelar, marcar, virar, distribuir, comprar e jogar devem atualizar estado e desenho; coberto pelo smoke de jogabilidade na Task 6.
- **Tela estreita/alta:** nenhum controle fica sob chrome, fora da safe area ou sobre outra superfície; coberto por `test_all_catalog_scenes_have_no_unregistered_overlap` na Task 5.

## File Map

Arquivos novos:

- `tests/gdscript/integration/test_gameplay_smoke.gd` — sequências jogáveis determinísticas para cada família de jogo.
- `tests/gdscript/unit/test_board_piece_materials.gd` — contrato dos materiais móveis de peças.
- `shared/3d/BoardGlyph3D.gd` — glifo procedural pequeno para mina/bandeira quando a textura não é utilizável.

Arquivos de catálogo/importação:

- `core/configs/GameCatalog.gd` — registrar as quatro cenas adicionais e atualizar as categorias.
- `core/i18n/translations.csv` e traduções importadas — adicionar as chaves de Xadrez que o catálogo utilizar.
- `tests/gdscript/integration/test_catalog.gd` — enumerar todas as cenas `*Game.tscn` e deixar de fixar o conjunto em listas incompletas.
- `games/xadrez/ChessRules.gd`, `ChessAI.gd`, `ChessPieces3D.gd` — tornar os arrays de dados válidos no parser do Godot 4.7.
- `games/xadrez/ChessGame.gd`, `games/trilha/MorrisGame.gd` — usar o `GameTopBar` compartilhado em vez de `ModeSwitch` inexistente.

Arquivos de peças e Campo Minado:

- `shared/3d/MaterialFactory3D.gd` — construir material direto com cor-base, textura opcional e fallback.
- `games/damas/CheckersGame.gd`, `games/reversi/ReversiGame.gd` — aplicar a fábrica compartilhada sem mudar as regras.
- `shared/3d/BoardGlyph3D.gd`, `games/campo_minado/MinesweeperGame.gd`,
  `tests/gdscript/unit/test_minesweeper.gd` — fallback de número, bandeira e mina.

Arquivos de cartas e layout:

- `shared/3d/Card3D.gd`, `CardAtlas3D.gd`, `UnoCardAtlas3D.gd` — identidade visual imediata e validação de pixels.
- `games/memoria/MemoryCard.gd`, `MemoryGame.gd`, `PokerGame.gd`,
  `UnoLikeGame.gd`, `KlondikeGame.gd`, `SpiderGame.gd`, `HeartsGame.gd` — ações e composição de cartas.
- `shared/BaseGame.gd`, `shared/ui/GameTopBar.gd`, `shared/ui/GameShell.gd`,
  `shared/ui/UIKit.gd` e cenas com offsets legados — bandas e espaçamento comuns.
- `tests/gdscript/unit/test_card_rendering.gd`,
  `tests/gdscript/integration/test_layout_mobile.gd`, `tools/mobile_layout_audit.gd` — provas de fallback e overlap.

---

### Task 1: Tornar o catálogo completo importável e jogável

**Files:**
- Modify: `tests/gdscript/integration/test_catalog.gd`
- Create: `tests/gdscript/integration/test_gameplay_smoke.gd`
- Modify: `core/configs/GameCatalog.gd`
- Modify: `core/i18n/translations.csv`
- Modify: `games/xadrez/ChessRules.gd`, `games/xadrez/ChessAI.gd`, `games/xadrez/ChessPieces3D.gd`
- Modify: `games/xadrez/ChessGame.gd`, `games/trilha/MorrisGame.gd`

**Interfaces:**
- Consumes: `GameCatalog.get_all_games()`, `BaseGame`, `GameTopBar.oferecer_modo()` e `GameTopBar.mode_pressed`.
- Produces: catálogo com 19 jogos de tabuleiro e 7 jogos de cartas; todas as cenas `games/*/*Game.tscn` carregáveis; smoke helper que as Tasks 3–6 ampliarão.

- [ ] **Step 1: Write the failing tests**

Adicionar em `test_catalog.gd` um enumerador que percorra cada subdiretório de
`res://games`, selecione arquivos terminados em `Game.tscn`, faça `load()` e
afirme `PackedScene != null`. Adicionar também:

```gdscript
func test_catalogo_cobre_todas_as_cenas_de_jogo() -> void:
    var cenas_catalogo: Array[String] = []
    for definicao in GameCatalog.get_all_games():
        cenas_catalogo.append(definicao.scene_path)
    for caminho in _todas_as_cenas_de_jogo():
        assert_true(caminho in cenas_catalogo, "%s precisa estar no catalogo" % caminho)
    assert_eq(GameCatalog.get_board_games().size(), 19)
    assert_eq(GameCatalog.get_card_games().size(), 7)
```

Criar `test_gameplay_smoke.gd` com o primeiro caso, que carrega todos os
definidos pelo catálogo e afirma que cada instância é `BaseGame` e possui
`top_bar`, `status_label` e `go_back_to_menu`.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_catalog.gd -gtest=res://tests/gdscript/integration/test_gameplay_smoke.gd`

Expected: falha de parser em `ChessRules.gd`/`ChessAI.gd`/`ChessPieces3D.gd`,
`ModeSwitch` ausente em Xadrez/Trilha e falha porque as quatro cenas extras
ainda não estão no catálogo.

- [ ] **Step 3: Fix the import graph and register the four scenes**

Em Xadrez, trocar somente a declaração `const` dos arrays de dados pelos
mesmos valores como `static var` tipados: `KNIGHT_DR`, `KNIGHT_DC`, `KING_DR`,
`KING_DC`, `RAY_DR`, `RAY_DC`, `PROMOS`, `VALOR` em `ChessRules`; `VALOR`,
`PST_PAWN`, `PST_KNIGHT`, `PST_BISHOP`, `PST_ROOK`, `PST_QUEEN`,
`PST_KING_MID`, `PST_KING_END` em `ChessAI`; `RAIO` e `ALTURA` em
`ChessPieces3D`. Nenhum conteúdo numérico muda.

Em Xadrez e Trilha, remover o tipo e a construção de `ModeSwitch` e ligar o
modo à barra existente:

```gdscript
if top_bar != null:
    top_bar.oferecer_modo(vs_ai)
    top_bar.mode_pressed.connect(_on_modo_trocado)
```

Adicionar a `GameCatalog` as entradas `GAME_GENERAL`, `GAME_TRILHA`,
`GAME_XADREZ` (tabuleiro) e `GAME_COPAS` (cartas), usando os paths existentes,
os modos já suportados pelos scripts e ícones curtos. Adicionar
`GAME_XADREZ`/`GAME_DESC_XADREZ` em `translations.csv`; importar os recursos
para regenerar as três traduções binárias.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_catalog.gd -gtest=res://tests/gdscript/integration/test_gameplay_smoke.gd`

Expected: todas as cenas do diretório importam, 26 entradas instanciam como
`BaseGame`, e não há `Ignoring script` nem `SCRIPT ERROR`.

- [ ] **Step 5: Commit**

```bash
git add tests/gdscript/integration/test_catalog.gd tests/gdscript/integration/test_gameplay_smoke.gd core/configs/GameCatalog.gd core/i18n/translations.csv core/i18n/translations.*.translation games/xadrez games/trilha/MorrisGame.gd
git commit -m "fix: load every PlayTable game scene"
```

### Task 2: Dar a Damas materiais móveis contrastantes

**Files:**
- Modify: `tests/gdscript/unit/test_checkers.gd`
- Create: `tests/gdscript/unit/test_board_piece_materials.gd`
- Modify: `shared/3d/MaterialFactory3D.gd`
- Modify: `games/damas/CheckersGame.gd`, `games/reversi/ReversiGame.gd`

**Interfaces:**
- Consumes: `Token3D.apply_visual_material()`, `AssetCatalog.get_game_art_by_key()` e o valor `grid_data` de Damas/Reversi.
- Produces: `MaterialFactory3D.board_piece(side: int, art_key: String) -> StandardMaterial3D`; peças com cor direta antes de entrar na árvore.

- [ ] **Step 1: Write the failing test**

Adicionar estes helpers/caso em `test_board_piece_materials.gd`:

```gdscript
func test_board_piece_tem_luminancias_distintas_mesmo_sem_textura() -> void:
    var claro := MaterialFactory3D.board_piece(1, "damas/arquivo_ausente")
    var escuro := MaterialFactory3D.board_piece(-1, "damas/arquivo_ausente")
    assert_true(claro.albedo_color.get_luminance() > 0.55)
    assert_true(escuro.albedo_color.get_luminance() < 0.25)
    assert_gt(absf(claro.albedo_color.get_luminance() - escuro.albedo_color.get_luminance()), 0.35)
```

Em `test_checkers.gd`, instanciar `CheckersGame`, aguardar dois frames,
percorrer `grid_data` até encontrar um valor positivo e um negativo e afirmar
que os dois `Token3D` têm `StandardMaterial3D` diferentes e não nulos.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_board_piece_materials.gd -gtest=res://tests/gdscript/unit/test_checkers.gd`

Expected: falha porque `board_piece` não existe e Damas ainda deixa o
`Token3D` escolher `get_textured()` pelo caminho triplanar.

- [ ] **Step 3: Implement the direct material path**

Implementar `board_piece` criando `StandardMaterial3D` com `albedo_color`,
`roughness=0.38`, `metallic=0.0`, `clearcoat_enabled=true` e textura direta
quando `AssetCatalog.get_game_art_by_key(art_key)` devolver uma textura válida.
Não ativar `uv1_triplanar` nesse material.

Em `_sync_pieces_3d()` de Damas, escolher a chave de arte pelo sinal do valor,
atribuir `piece.visual_material = MaterialFactory3D.board_piece(...)` antes de
`pieces_root.add_child(piece)` e manter `material_name` apenas como metadado.
Fazer `MaterialFactory3D.reversi_piece()` delegar ao mesmo construtor,
preservando as chaves de arte e o lado 1/2 que Reversi já usa.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_board_piece_materials.gd -gtest=res://tests/gdscript/unit/test_checkers.gd -gtest=res://tests/gdscript/unit/test_reversi.gd`

Expected: materiais claro/escuro passam sem textura e continuam corretos
depois de um movimento/flip de Reversi.

- [ ] **Step 5: Commit**

```bash
git add tests/gdscript/unit/test_board_piece_materials.gd tests/gdscript/unit/test_checkers.gd shared/3d/MaterialFactory3D.gd games/damas/CheckersGame.gd games/reversi/ReversiGame.gd
git commit -m "fix: render board pieces with mobile-safe contrast"
```

### Task 3: Tornar Campo Minado legível sem atlas ou Sprite3D

**Files:**
- Create: `shared/3d/BoardGlyph3D.gd`
- Modify: `games/campo_minado/MinesweeperGame.gd`
- Modify: `tests/gdscript/unit/test_minesweeper.gd`, `tests/gdscript/unit/test_arte_gerada.gd`

**Interfaces:**
- Consumes: `Board3D.CellState`, `Grid2D`, `MinesweeperRules`, `AssetCatalog` e `DecalGrid3D`.
- Produces: `BoardGlyph3D.make(kind: String, color: Color, radius: float) -> Node3D` e três estados visíveis de Campo Minado: número, bandeira e mina.

- [ ] **Step 1: Write the failing tests**

Adicionar em `test_minesweeper.gd` um caso que força uma partida, abre
`(4, 4)`, marca `(0, 0)` e então encontra a primeira célula `is_mine` gerada.
Antes da explosão, procurar uma célula revelada com
`adjacent_mines > 0`; se a abertura segura não produzir uma, definir
`adjacent_mines = 1` em `(0, 1)`, marcar essa célula como revelada e chamar
`_sync_revealed_3d()`. Depois da explosão, afirmar:

```gdscript
assert_gt(jogo.board_3d.revealed_count(), 0)
assert_true(jogo.flags_3d.has(Vector2i(0, 0)))
assert_gt(jogo.mines_root.get_child_count(), 0)
var numero_count := jogo.numbers_3d.size()
if jogo.numbers_grid != null:
    numero_count += jogo.numbers_grid.count()
assert_gt(numero_count, 0)
```

Adicionar um segundo caso que limpa `jogo._mine_tex`, `jogo._flag_tex` e
`jogo.numbers_grid` antes da jogada e exige o mesmo resultado por fallback.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_minesweeper.gd`

Expected: o caminho com textura não cria a mina quando o recurso é nulo e o
caminho de número depende de `numbers_grid` ou de um `Label3D` sem contrato de
visibilidade; os asserts novos falham.

- [ ] **Step 3: Implement `BoardGlyph3D` and sync all cells**

Criar `BoardGlyph3D` como `Node3D` com uma malha procedural simples: `sphere`
obsidiana para `mine`, `pawn` rubi para `flag` e `Label3D` de alto contraste
para `number`. O método `make` deve definir material, escala, rotação deitado
e posição somente depois que o chamador a fornecer.

Em `MinesweeperGame`, usar o glyph quando a textura não existir ou quando
`Texture2D.get_image()` não tiver pelo menos um pixel opaco com luminância
útil. `numbers_grid` só será usado quando a validação passar. `_mostrar_numero`
deve apagar o glyph/label de uma célula que virou zero; `_update_flag_3d` deve
apagar e recriar exatamente um flag por posição; `_trigger_game_over` deve
desenhar um glyph para cada mina mesmo sem `mina.png`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_minesweeper.gd -gtest=res://tests/gdscript/unit/test_arte_gerada.gd`

Expected: a jogada revela casa/número, marcar/desmarcar cria um único flag e
perder mostra pelo menos uma mina tanto com os assets quanto sem eles.

- [ ] **Step 5: Commit**

```bash
git add shared/3d/BoardGlyph3D.gd games/campo_minado/MinesweeperGame.gd tests/gdscript/unit/test_minesweeper.gd tests/gdscript/unit/test_arte_gerada.gd
git commit -m "fix: keep minesweeper glyphs visible on mobile"
```

### Task 4: Garantir identidade imediata das cartas

**Files:**
- Modify: `shared/3d/Card3D.gd`
- Modify: `shared/3d/CardAtlas3D.gd`, `shared/3d/UnoCardAtlas3D.gd`
- Modify: `tests/gdscript/unit/test_card_rendering.gd`

**Interfaces:**
- Consumes: `Card3D.setup()`, `CardAtlas3D.ensure_built()`, `UnoCardAtlas3D.ensure_built()` e `MeshBuilder3D.card_mesh()`.
- Produces: `Card3D.fallback_face: Label3D`, `Card3D.has_visible_visual() -> bool` que também exige identidade, e validação equivalente nos dois atlas.

- [ ] **Step 1: Write the failing tests**

Adicionar:

```gdscript
func test_fallback_has_card_identity_before_atlas() -> void:
    var card: Card3D = CARD_SCENE.instantiate()
    add_child_autofree(card)
    card.setup("A", ART.SUIT_SPADE, true)
    await wait_process_frames(1)
    assert_true(card.has_visible_visual())
    assert_not_null(card.fallback_face)
    assert_true(card.fallback_face.text.contains("A"))

func test_uniform_or_transparent_atlas_keeps_identity_fallback() -> void:
    var card: Card3D = CARD_SCENE.instantiate()
    add_child_autofree(card)
    card.setup("10", ART.SUIT_HEART, true)
    card.apply_fallback_visuals()
    assert_true(card.has_visible_visual())
    assert_true(card.fallback_face.text.contains("10"))
```

Adicionar o mesmo teste de imagem uniforme para `UnoCardAtlas3D` e um teste
que espera que um atlas pronto substitua o material fallback sem remover a
assinatura enquanto a textura é aplicada.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_card_rendering.gd`

Expected: `fallback_face` não existe e `has_visible_visual()` considera apenas
mesh/material, sem provar que a carta é identificável.

- [ ] **Step 3: Implement the immediate fallback**

Adicionar em `Card3D` o `Label3D` criado por `_ensure_fallback_face()`, com
texto rank/naipe, `no_depth_test=false`, outline escuro, billboard desativado,
rotação horizontal da face e escala proporcional a
`Tokens3D.CARD_WIDTH/CARD_LENGTH`. `apply_fallback_visuals()` deve criar a
malha, material de frente/verso e label no mesmo frame; `_update_visuals()` deve
ocultar o label apenas depois de `atlas.is_ready()` e `face_material` devolver
material com textura válida.

Fortalecer `is_valid_image()` nos dois atlas para amostrar centro, bordas e
uma célula intermediária, rejeitando imagem vazia, totalmente transparente,
preta uniforme ou menor que o tamanho de uma célula. A falha permanece
recuperável e não remove o fallback.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_card_rendering.gd`

Expected: todas as cartas têm mesh e identidade antes do warm-up; atlas válido
substitui a frente; atlas inválido mantém rank/naipe e material visível.

- [ ] **Step 5: Commit**

```bash
git add shared/3d/Card3D.gd shared/3d/CardAtlas3D.gd shared/3d/UnoCardAtlas3D.gd tests/gdscript/unit/test_card_rendering.gd
git commit -m "fix: make card faces visible before atlas warmup"
```

### Task 5: Remover sobreposição e normalizar telas de cartas

**Files:**
- Modify: `tests/gdscript/integration/test_layout_mobile.gd`, `tools/mobile_layout_audit.gd`
- Modify: `shared/BaseGame.gd`, `shared/ui/GameTopBar.gd`, `shared/ui/GameShell.gd`, `shared/ui/UIKit.gd`
- Modify: `games/memoria/MemoryGame.tscn`, `games/memoria/MemoryCard.gd`
- Modify: `games/poker/PokerGame.tscn`, `games/unolike/UnoLikeGame.tscn`
- Modify: `games/paciencia/KlondikeGame.tscn`, `games/paciencia_spider/SpiderGame.tscn`, `games/copas/HeartsGame.tscn`
- Modify: `games/campo_minado/MinesweeperGame.tscn`, `games/batalha_naval/BattleshipGame.tscn`, `games/gamao/BackgammonGame.tscn`

**Interfaces:**
- Consumes: `MobileHudMetrics`, `BaseGame.register_mobile_band()`, `GameTopBar.content_top_px`, `LayoutAudit.find_overlaps()`.
- Produces: todas as superfícies de ação com `mobile_hud_band` explícita; hand/controls de cartas confinados ao `content_rect`/`bottom_action_rect`.

- [ ] **Step 1: Write the failing layout test**

Substituir a lista fixa de jogos do audit por
`GameCatalog.get_all_games().map(scene_path)` mais as cenas extras que não
forem catalogadas. Adicionar:

```gdscript
func test_all_catalog_scenes_have_no_unregistered_overlap() -> void:
    for definicao in GameCatalog.get_all_games():
        var jogo := await _montar(definicao.scene_path, PROPORCOES["9:16"])
        assert_not_null(jogo)
        if jogo != null:
            var overlaps := LayoutAudit.find_overlaps(jogo)
            assert_true(overlaps.is_empty(), "%s: %s" % [definicao.scene_path, overlaps])
```

Também exigir que cada `Label`/`BaseButton` visível encontrado fora do chrome
tenha meta `mobile_hud_band` ou seja descendente de um controle registrado.

- [ ] **Step 2: Run the layout test to verify it fails**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_layout_mobile.gd`

Expected: falhas nas cenas de cartas por status/ações em offsets fixos e na
mão do UNO/Spider; o audit deve imprimir o par de nós e o retângulo da colisão.

- [ ] **Step 3: Move every affected band to shared metrics**

Em `BaseGame` e `GameShell`, fazer `status_label`, restart e controles
inferiores registrarem `status`, `content` ou `bottom_action` e recalcularem em
`layout_changed`. Em `GameTopBar`, manter título/voltar/placar dentro da faixa
superior e reduzir badges de baixa prioridade antes de reduzir o título.

Migrar cenas sem mudar regras:

- Memória: grade em `content_rect`, cartas com largura calculada pelo número de
  colunas e sem crescer contra o `BtnBack`/título.
- Poker: `UI/Actions` no trilho inferior e cinco cartas dentro do tabuleiro,
  sem ocupar status.
- Klondike/Spider: estoque, fundações e tableau em `content_rect`; ações
  secundárias ficam no trilho ou em scroll interno com altura limitada.
- UNO/Copas: mão horizontal usa apenas o próprio container de cartas, com
  largura/scroll sem cobrir cartas ou botões.
- Campo Minado/Batalha Naval/Gamão: controles e mensagens deixam de usar
  offsets absolutos que invadem a faixa superior.

Aplicar `UIKit.TOQUE_MIN`, espaçamento de 8 px e os tokens de superfície nos
controles migrados; não reintroduzir caixas marrom/douradas isoladas.

- [ ] **Step 4: Run focused layout verification**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_layout_mobile.gd && "$(scripts/godot_bin.sh)" --headless --path . -s tools/mobile_layout_audit.gd`

Expected: GUT e audit terminam com `TOTAL VIOLATIONS: 0` nas proporções
9:16, 20:9 e 3:4, sem controles fora da tela, sob o chrome ou sobrepostos.

- [ ] **Step 5: Commit**

```bash
git add tests/gdscript/integration/test_layout_mobile.gd tools/mobile_layout_audit.gd shared/BaseGame.gd shared/ui/GameTopBar.gd shared/ui/GameShell.gd shared/ui/UIKit.gd games/memoria games/poker/PokerGame.tscn games/unolike/UnoLikeGame.tscn games/paciencia/KlondikeGame.tscn games/paciencia_spider/SpiderGame.tscn games/copas/HeartsGame.tscn games/campo_minado/MinesweeperGame.tscn games/batalha_naval/BattleshipGame.tscn games/gamao/BackgammonGame.tscn
git commit -m "fix: keep mobile game controls inside safe bands"
```

### Task 6: Jogar cada família e validar desenhos após a ação

**Files:**
- Modify: `tests/gdscript/integration/test_gameplay_smoke.gd`
- Modify: `tests/gdscript/integration/test_touch_input.gd`
- Modify: `games/memoria/MemoryCard.gd`, `games/memoria/MemoryGame.gd`
- Modify: `games/poker/PokerGame.gd`, `games/unolike/UnoLikeGame.gd`
- Modify: `games/paciencia/KlondikeGame.gd`, `games/paciencia_spider/SpiderGame.gd`, `games/copas/HeartsGame.gd`
- Modify: `tools/capture_all_shots.py`, `tools/shot_call.gd`

**Interfaces:**
- Consumes: métodos públicos de jogada de cada cena e os materiais/fallbacks das Tasks 2–5.
- Produces: smoke determinístico para 26 cenas e capturas nomeadas antes/depois da primeira ação.

- [ ] **Step 1: Write the failing gameplay tests**

Adicionar casos explícitos, sem depender de toque visual:

```gdscript
func test_memoria_vira_carta_e_desenha_simbolo() -> void:
    var jogo := await _montar("res://games/memoria/MemoryGame.tscn")
    var cartas: Array[Control] = jogo.cards
    assert_gt(cartas.size(), 1)
    var carta = cartas[0]
    jogo._on_card_clicked(carta)
    await wait_seconds(0.4)
    assert_true(carta.is_face_up)
    assert_ne(carta.symbol_type, -1)

func test_poker_distribui_cinco_cartas_e_mostra_faces() -> void:
    var jogo := await _montar("res://games/poker/PokerGame.tscn")
    jogo._on_btn_action_pressed()
    await wait_process_frames(4)
    assert_eq(jogo.player_hand.cards.size(), 5)
    assert_eq(jogo.cards_3d.size(), 5)
    for card in jogo.cards_3d:
        assert_true(card.has_visible_visual())
```

Adicionar no mesmo arquivo os casos de Blackjack (`_on_btn_hit_pressed`),
Klondike (`_on_stock_pressed`), Spider (`_on_stock_pressed`), UNO
(`_on_btn_draw_pressed`), Copas (`_on_passar_pressed` ou a primeira carta
legal), Campo Minado (abrir/marcar), Damas/Reversi (primeiro lance), Xadrez
(`_on_cell_clicked` origem/destino legal), Trilha (`_on_toque` em ponto vazio),
General (`_on_rolar`) e as jogadas já cobertas de tabuleiro em
`test_touch_input.gd`. Cada caso deve afirmar mudança de estado e ao menos um
node/material visível, não apenas ausência de exceção.

- [ ] **Step 2: Run tests to verify they fail**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_gameplay_smoke.gd -gtest=res://tests/gdscript/integration/test_touch_input.gd`

Expected: Memória/Poker revelam as lacunas atuais de desenho/fluxo; qualquer
falha precisa apontar o jogo e a ação, não ser absorvida por um teste genérico.

- [ ] **Step 3: Fix only the failing game flows**

Em `MemoryCard`, garantir `queue_redraw()` após mudança de tamanho, flip,
match e mismatch; em `MemoryGame`, manter o símbolo e o estado da carta
durante a animação e expor a lista já existente `cards` para o smoke test. Em Poker, chamar
`apply_fallback_visuals()` imediatamente ao criar cada `Card3D` e aguardar o
atlas somente para substituir o material. Em UNO, Klondike, Spider e Copas,
usar a mesma garantia ao criar cartas e limitar o leque à banda registrada.

Atualizar `capture_all_shots.py` com as 26 cenas e criar chamadas
`shot_call.gd` para `hide_rules`, distribuir/revelar e fazer um primeiro
movimento. Os scripts devem falhar se o PNG não existir ou se o processo
retornar `SCRIPT ERROR`.

- [ ] **Step 4: Run gameplay tests and capture representative states**

Run: `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_gameplay_smoke.gd -gtest=res://tests/gdscript/integration/test_touch_input.gd && python3 tools/capture_all_shots.py`

Expected: todos os smoke tests passam; são produzidas capturas de menu, cada
jogo e estados acionados de cartas/Campo Minado sem tela vazia ou overlay
inesperado cobrindo a mesa.

- [ ] **Step 5: Commit**

```bash
git add tests/gdscript/integration/test_gameplay_smoke.gd tests/gdscript/integration/test_touch_input.gd games/memoria games/poker/PokerGame.gd games/unolike/UnoLikeGame.gd games/paciencia/KlondikeGame.gd games/paciencia_spider/SpiderGame.gd games/copas/HeartsGame.gd tools/capture_all_shots.py tools/shot_call.gd
git commit -m "test: play every game through its first action"
```

### Task 7: Verificação final no renderizador mobile e no iPhone

**Files:**
- Create: `docs/superpowers/qa/2026-09-21-all-games-iphone-qa.md`

**Interfaces:**
- Consumes: commits das Tasks 1–6, `scripts/godot_bin.sh`, export preset iOS e dispositivo `00008030-001028D614DA802E`.
- Produces: registro reproduzível de suíte, audit, capturas, build, instalação, lançamento e limite físico de captura.

- [ ] **Step 1: Run the full fresh test suite**

Run: `tests/run_gut.sh`

Expected: saída sem `Ignoring script`, sem erro de parser, 0 falhas e todos
os testes contabilizados. Guardar a saída completa fora do repositório e
registrar contagem no QA.

- [ ] **Step 2: Run layout and visual checks**

Run: `"$(scripts/godot_bin.sh)" --headless --path . -s tools/mobile_layout_audit.gd` e revisar visualmente as capturas de `screenshots/games/` com `view_image`.

Expected: `TOTAL VIOLATIONS: 0`; nenhuma captura mostra texto sob a faixa,
cartas brancas sem identidade, Damas monocromática, Campo Minado sem desenho,
ou controles empilhados.

- [ ] **Step 3: Export, install and launch iOS**

Run:

```bash
xcodebuild -project build/ios/PlayTable.xcodeproj -scheme PlayTable -configuration Debug -destination 'generic/platform=iOS' -derivedDataPath build/ios/DerivedData -allowProvisioningUpdates CODE_SIGN_STYLE=Automatic DEVELOPMENT_TEAM=28X7P94SF5 CODE_SIGN_IDENTITY="Apple Development" build
xcrun devicectl device install app --device 00008030-001028D614DA802E build/ios/DerivedData/Build/Products/Debug-iphoneos/PlayTable.app
xcrun devicectl device process launch --device 00008030-001028D614DA802E org.playtable.app
```

Expected: build, instalação e lançamento retornam código 0; não há crash,
shader error ou recurso ausente nos logs durante a navegação pelos jogos.

- [ ] **Step 4: Capture physical-device evidence**

Desbloquear o iPhone, abrir o app e percorrer menu, Damas, Campo Minado,
Memória, Poker, UNO, Reversi e pelo menos um jogo de cada grupo restante.
Salvar capturas reais e registrar no QA quais estados foram exercitados. Se o
aparelho continuar bloqueado, registrar explicitamente que captura física não
foi possível e não marcar a inspeção como aprovada.

- [ ] **Step 5: Commit the QA record**

```bash
git add docs/superpowers/qa/2026-09-21-all-games-iphone-qa.md
git commit -m "docs: record all-games iPhone QA"
```
