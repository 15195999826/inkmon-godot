# sim-nav-map Feature 1: Terrain-Derived Passability

## Objective

Complete Feature 1 from `addons/sim-nav-map/docs/feature-roadmap.md`: make
terrain/map data a first-class navigation input by deriving navcell passability
from terrain tile data and passability class terrain masks.

## Delivery Scope

- Implement a stable core contract for terrain tile data -> navcell passability.
- Ensure terrain edits update the derived passability data and mark affected
  navcells dirty for downstream pathfinding/cache users.
- Add or update core smoke coverage and register it in `simnav/smoke`.
- Add `examples/rts-pathfinding-lab` adapter smoke only as needed to prove the
  lab can consume terrain-derived passability without moving lab policy into
  core.
- Update Feature 1 API, smoke, boundary, and next-step docs:
  - `addons/sim-nav-map/docs/public-api.md`
  - `addons/sim-nav-map/docs/usage.md`
  - `addons/sim-nav-map/docs/smoke-matrix.md`
  - `addons/sim-nav-map/docs/feature-roadmap.md`
- Keep this goal's progress in
  `.codex-goal/sim-nav-map-terrain-passability/Progress.md`.

## Explicit Non-Scope

- Feature 2+ work:
  - class-aware clearance rasterization
  - dirty cache lifecycle expansion
  - reachability result DTO
  - long path result contract
  - short path filter
  - line validation
  - request queue expansion
  - scale diagnostics
- Ship gameplay, water/land unit gameplay, formation, push/yield, stuck/deadlock,
  HUD policy, or game-specific movement policy.
- Promoting `rts-pathfinding-lab` movement, selection, command, formation, or
  playable policy into core.
- Copying GPL source implementation. `addons/sim-nav-map/docs/references/0ad-source/`
  must remain untracked.

## Required Verification

```powershell
./tools/run_tests.ps1 simnav/smoke rtslab/smoke
git -C addons diff --check
git -C addons status --short -- sim-nav-map/docs/references/0ad-source
```

If any Godot scene/frontend behavior changes, document the editor-side manual
checks needed before completion.

## Completion Gate

- Core terrain-derived passability smoke passes.
- `rtslab/smoke` remains green as adapter/playable regression.
- Docs clearly state the post-Feature-1 boundary between core addon and
  `examples/rts-pathfinding-lab`.
- Feature 2 entry conditions are explicit.
