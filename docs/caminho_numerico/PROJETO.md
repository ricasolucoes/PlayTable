# Project: Caminho Numérico Expansion

## Architecture
- **Design Pattern**: Model-View-Controller (MVC) in Godot 4.7.2 GDScript
- **Model**: `games/caminho_numerico/NumberPathModel.gd` — Pure game state, cell validation, bridges crossing logic, mandatory stars, warp portals, directional constraints, completion checks.
- **View & Input**: `games/caminho_numerico/NumberPathBoard.gd` — 2D canvas drawing (`_draw`), obstacle rendering, multi-layer bridge rendering, star glow animations, portal vortexes, touch/drag input handling.
- **Controller**: `games/caminho_numerico/NumberPathGame.gd` & `NumberPathGame.tscn` — Game lifecycle, countdown timer loop, HUD updates, timeout game over, level advancement.
- **Procedural Generator**: `games/caminho_numerico/NumberPathGenerator.gd` — Warnsdorff DFS Hamiltonian path synthesis, bipartite parity guards, bridge crossing generation, obstacle placement, star checkpoints, warp portals, solver, 1-30+ level progression curve.
- **Scoring**: `games/caminho_numerico/NumberPathScoring.gd` — Gamification, star bonuses, time limit bonus, rank calculation.
- **Tests**: `tests/gdscript/unit/test_number_path.gd` — GUT unit and integration test suite.

## Feature Inventory
| # | Feature | Description | Milestone | Source |
|---|---------|-------------|-----------|--------|
| 1 | Scene Syntax Fix | Fix misplaced `[ext_resource]` tag in `NumberPathGame.tscn` | M1 | Survey |
| 2 | Obstacles (Model & Rules) | Blocked cells that cannot be traversed; walkable count calculation | M1 | ORIGINAL_REQUEST §R1 |
| 3 | Bridges / Tunnels (Model) | Orthogonal self-crossings (horizontal + vertical), straight-through rule, dual visit limit | M1 | ORIGINAL_REQUEST §R1 |
| 4 | Mandatory Stars (Model) | Checkpoint cells without numbers required for completion | M1 | ORIGINAL_REQUEST §R1 |
| 5 | Bonus Mechanic: Warp Portals (Model) | Bidirectional paired teleportation tiles | M1 | ORIGINAL_REQUEST §R1 |
| 6 | Scoring & i18n Expansion | Star bonuses, time bonus, Portuguese translation keys | M1 | Survey |
| 7 | Procedural Generator Core | Parity-balanced Warnsdorff DFS path synthesis with obstacles and bridges | M2 | ORIGINAL_REQUEST §R2 |
| 8 | Generator Feature Infusion | Deterministic placement of clues, stars, portals, and directional tiles along path | M2 | ORIGINAL_REQUEST §R2 |
| 9 | 3-Tier Fail-Safe & Solver | Constrained DFS -> Adaptive Retry -> Serpentine Fallback + `solve_puzzle()` | M2 | ORIGINAL_REQUEST §R2 |
| 10 | Difficulty Progression Matrix | Levels 1 to 30+ scaling grid size (3x3 to 7x7), obstacles, bridges, stars, time limits | M2 | ORIGINAL_REQUEST §R2 |
| 11 | Board Visuals: Obstacles & Bridges | Custom stone obstacle rendering; 2-layer bridge overpass/underpass with rails | M3 | ORIGINAL_REQUEST §R1 |
| 12 | Board Visuals: Stars & Portals | Glowing golden stars, animated swirling warp vortexes, directional arrows | M3 | ORIGINAL_REQUEST §R1 |
| 13 | Time Limit Controller & HUD | Countdown timer loop in `_process()`, HUD display, timeout game over, win stop | M3 | ORIGINAL_REQUEST §R1 |
| 14 | 4-Tier Test Suite | Comprehensive GUT unit & integration tests in `test_number_path.gd` | M4 | ORIGINAL_REQUEST §AC |
| 15 | Adversarial Stress & Forensic Audit | Verification, challenger edge-case tests, forensic integrity certification | M5 | Integrity Policy |

## Milestones
| # | Name | Scope | Dependencies | Status |
|---|------|-------|-------------|--------|
| M1 | Core Logic Model & Scene Fix | `NumberPathGame.tscn`, `NumberPathModel.gd`, `NumberPathScoring.gd`, `translations.csv` | none | DONE |
| M2 | Procedural Generator Engine & Solver | `NumberPathGenerator.gd` (bipartite parity, bridges, obstacles, stars, portals, solver, scaling) | M1 | IN_PROGRESS |
| M3 | Visuals, Rendering & Game Controller | `NumberPathBoard.gd`, `NumberPathGame.gd` (rendering, input, countdown timer, HUD, SFX) | M1, M2 | PLANNED |
| M4 | Comprehensive Test Suite & E2E Verification | `test_number_path.gd` (Tiers 1-4 tests, Monte Carlo solvability) | M1, M2, M3 | PLANNED |
| M5 | Final Verification, Adversarial Hardening & Audit | Reviewers + Challengers + Forensic Auditor | M4 | PLANNED |

## Interface Contracts

### `NumberPathModel` ↔ `NumberPathBoard` / `NumberPathGame`
- `setup_puzzle(puzzle_data: Dictionary) -> void`
  - Consumes: `width`, `height`, `clues` (Dict[Vector2i, int]), `obstacles` (Array[Vector2i]), `bridges` (Array[Vector2i]), `stars` (Array[Vector2i]), `portals` (Dict[Vector2i, Vector2i]), `time_limit` (float).
  - Emits: `path_changed(path)`, `clue_reached(cell, num)`, `star_collected(cell, remaining)`, `portal_used(from_cell, to_cell)`, `completed`, `mistake_occurred(cell, reason)`.
- `can_extend_to(cell: Vector2i) -> bool`
  - Evaluates bounds, obstacle non-membership, single-visit or bridge orthogonal crossing, star collection, portal jump validity, and clue monotonic order.
- `extend_to(cell: Vector2i) -> bool`
  - Adds cell to `player_path`, handles bridge crossing axes, handles portal auto-jump step, triggers star collection, checks completion.
- `truncate_to(cell: Vector2i) -> bool`
  - Backtracks `player_path` to target cell, restoring bridge visit counts, uncollecting stars, and removing paired portal jumps cleanly.

### `NumberPathGenerator` ↔ `NumberPathGame`
- `generate_level(level: int) -> Dictionary`
  - Returns canonical `puzzle_dict` containing all keys: `level`, `width`, `height`, `total_cells`, `walkable_count`, `obstacles`, `bridges`, `stars`, `portals`, `directional`, `path`, `clues`, `start_cell`, `end_cell`, `max_number`, `time_limit`, `par_time`, `difficulty_tier`.
- `solve_puzzle(puzzle: Dictionary, max_solutions: int = 1) -> Array`
  - Returns array of valid path solutions verifying that generated puzzle is mathematically solvable.

## Code Layout
- `games/caminho_numerico/NumberPathModel.gd` — Model logic
- `games/caminho_numerico/NumberPathBoard.gd` — View & Input
- `games/caminho_numerico/NumberPathGame.gd` — Game controller
- `games/caminho_numerico/NumberPathGame.tscn` — Scene tree & UI
- `games/caminho_numerico/NumberPathGenerator.gd` — Procedural generator
- `games/caminho_numerico/NumberPathScoring.gd` — Scoring formulas
- `tests/gdscript/unit/test_number_path.gd` — Test suite
- `core/i18n/translations.csv` — Translations
