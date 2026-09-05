# E2E Test Infra: Caminho Numérico Expansion

## Test Philosophy
- Opaque-box, requirement-driven. No dependency on implementation design.
- Methodology: Category-Partition + BVA + Pairwise + Workload Testing (Monte Carlo).
- Test Runner: GUT 9.7.1 on Godot 4.7.2 (`./tests/run_gut.sh -gselect=number_path`).

## Feature Inventory
| # | Feature | Source | Tier 1 | Tier 2 | Tier 3 |
|---|---------|--------|:------:|:------:|:------:|
| 1 | Obstacles | ORIGINAL_REQUEST §R1 | 6 | 2 | 2 |
| 2 | Bridges / Tunnels | ORIGINAL_REQUEST §R1 | 6 | 2 | 2 |
| 3 | Mandatory Stars | ORIGINAL_REQUEST §R1 | 6 | 2 | 2 |
| 4 | Time Limit Mode | ORIGINAL_REQUEST §R1 | 6 | 2 | 2 |
| 5 | Warp Portals (Bonus) | ORIGINAL_REQUEST §R1 | 6 | 2 | 2 |
| 6 | Refactored Generator & Scaling | ORIGINAL_REQUEST §R2 | 6 | 2 | 2 |

## Test Architecture
- Test runner command: `./tests/run_gut.sh -gselect=number_path`
- Script location: `tests/gdscript/unit/test_number_path.gd`
- Pass semantics: 100% tests pass, 0 failures, 0 errors, 0 script ignoring warnings.

## Real-World Application Scenarios (Tier 4)
| # | Scenario | Features Exercised | Complexity |
|---|----------|--------------------|------------|
| 1 | Campaign Playthrough Levels 1-10 | Grid scaling, Clues, Stars, Obstacles, Bridges, Portals | High |
| 2 | Player Recovery with Repeated Backtracking | Backtracking across Bridges, Portals, and Stars | High |
| 3 | Monte Carlo Solvability 100+ Puzzles | Procedural Generator across all difficulty tiers | Very High |

## Coverage Thresholds
- Tier 1: ≥5 tests per feature
- Tier 2: ≥5 boundary & corner tests
- Tier 3: ≥5 pairwise cross-feature combination tests
- Tier 4: ≥3 realistic application scenarios & Monte Carlo solvability stress tests
