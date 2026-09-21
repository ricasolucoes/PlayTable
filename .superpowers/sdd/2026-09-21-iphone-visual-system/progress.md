# SDD ledger — plan: docs/superpowers/plans/2026-09-21-iphone-visual-system.md

Setup: Native execution in the existing dedicated feature branch; no isolated worktree created.

Pre-flight: shared-interface rows checked. Task 2 produces `MobileHudMetrics`,
`BaseGame.register_mobile_band` and chrome badge APIs consumed by Tasks 3, 6 and
7; names and ownership match. Task 5 produces `Token3D.get_visual_material`
consumed by Task 6 tests; Task 4 owns both atlas implementations and their
`ensure_built(owner) -> bool` contract. No unresolved interface conflict found.

Ruling: the packaged execution skill exposes `task-brief` but not the documented
`task-start`/`task-done` scripts. I will use `task-brief` for each task and
record the exact final command/output manually in this ledger; cost if wrong:
the automated ledger append/check is unavailable, so task evidence must be
recorded carefully here.

Task 1: complete (commit 61936ea; RED `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_general.gd` → parser error at `GeneralGame.gd:92`, 16 failures; GREEN same command → 817/817 tests, 24,266 asserts, exit 0). GDScript tabs in the committed diff are existing project indentation, not whitespace errors.

Ruling: the shared `GameShell` restart action moved from `VBoxContainer` to `ActionRail`, so the existing touch integration paths for Damas and Peg Solitaire are part of Task 2 compatibility work even though the plan's file list did not call them out. Cost if wrong: only those two scene lookup paths would need reverting.

Task 2: complete (RED `tests/run_gut.sh -gtest=res://tests/gdscript/unit/test_mobile_hud.gd` → missing `MobileHudMetrics`/type errors and baseline 817 passing; GREEN same command → 821/821 tests, 24,054 asserts, exit 0). Added shared safe-area metrics, top-bar context badges, bottom action rail, and responsive mobile-band layout. Commit pending.

Ruling: the layout audit compares drawable surfaces, not transparent composition containers. Cards, modal layers, reward/rules panels, and board-render/input layers declare `allow_overlay`; their descendants are still traversed, but intentional z-order is not reported as a HUD collision.

Task 3: complete (RED `tests/run_gut.sh -gtest=res://tests/gdscript/integration/test_layout_mobile.gd` → missing audit helper plus M7 violations; GREEN `tests/run_gut.sh -gselect=layout_mobile` → 9/9 tests; visual contract `-gselect=mobile_visuals` → 3/3; standalone audit → `TOTAL VIOLATIONS: 0`). Migrated scene HUDs to shared content/header/bottom bands, stacked multiple bottom rails, moved mode controls into the shared top bar for Tic-Tac-Toe/Connect Four, and made the audit fail nonzero when violations remain. Commit pending.

Task 4: complete (RED `tests/run_gut.sh -gselect=card_rendering` → missing `is_valid_image` and fallback APIs; GREEN same selector → 4/4 tests, 57 asserts, exit 0. Card smoke tests: Blackjack 22/22, Spider 6/6, Poker 17/17, all exit 0). Added validated single-state atlas warm-up for standard and UNO cards, an immediate visible Card3D fallback, and non-blocking menu warm-up. GUT's dummy renderer reports teardown-only material/orphan diagnostics when a card scene is freed before three render frames; assertions and process exits remain green.

Task 5: complete (RED `tests/run_gut.sh -gselect=mobile_visuals`/`reversi` → missing `reversi_piece`; GREEN → mobile visuals 5/5, Reversi 26/26, exit 0). Added explicit side-based Reversi materials with stable fallback luminance, exposed `Token3D.get_visual_material`, preserved visual material through flips, and removed the fixed top HUD offset. Commit pending.

Tasks: Tasks 1–5 complete; Task 6 in progress; Tasks 7–8 pending.
