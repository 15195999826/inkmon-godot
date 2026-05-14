# Dota2 Lab Phase B Behavior Baseline

## Objective

Complete the Dota2 RTS Pathfinding Lab Phase B behavior baseline in the current
`C:\GodotPorjects\inkmon-godot` workspace.

The goal is to separate accepted hard-block terminal behavior from defects
without changing movement feel policy.

## Scope

- Update
  `addons/sim-nav-map/examples/dota2-rts-pathfinding-lab/docs/development-plan.md`
  with Phase A DevAgent verification and Phase B baseline evidence.
- Add smoke coverage for:
  - default group move baseline;
  - narrow-gap bounded terminal behavior;
  - mixed static + dynamic obstacle behavior.
- Make every smoke `FAILED` explainable as either accepted hard-block terminal
  behavior or a defect.
- Run `./tools/run_tests.ps1 dota2lab/smoke`.
- Run at least one DevAgent/free-play verification session and record the
  artifact path or key metrics.

## Non-Goals

- No UI work.
- No Layer 2 AI.
- No `MAX_RETRY`, speed, or radius tuning to hide failures.
- No push, yield, formation, or destination packing.
- No `sim-nav-map` core policy surface expansion.
- No Phase C playable-feel policy in this goal.

## Acceptance Criteria

- `dota2lab/smoke` passes.
- Phase B has smoke or directly reviewable evidence for all three behavior
  classes.
- `development-plan.md` clearly distinguishes accepted baseline failure, real
  defect, and Phase C policy decisions.
- The `addons` submodule is committed before the parent repo pointer update.
- The unrelated `.agents/skills/game-architecture-patterns/` directory remains
  untracked and uncommitted.
