# sim-nav-map Feature 2: Class-Aware Clearance Rasterization

## Objective

Complete Feature 2 from `addons/sim-nav-map/docs/feature-roadmap.md`: make
`SimNavPassabilityClassConfig.clearance` participate in terrain-derived and
static obstruction rasterization so different passability classes can see
different navcell masks on the same navigation input.

## Delivery Scope

- Implement a stable core contract for class-aware clearance rasterization.
- Define how every passability class `clearance` affects navcell passability.
- Ensure the same terrain or static obstruction can block one class while
  allowing another class.
- Add or update core smoke coverage and register it in `simnav/smoke`.
- Add `examples/rts-pathfinding-lab` adapter smoke only as needed to prove
  small/large class consumption without moving lab policy into core.
- Update Feature 2 API, smoke, boundary, and Feature 3 entry docs:
  - `addons/sim-nav-map/docs/public-api.md`
  - `addons/sim-nav-map/docs/usage.md`
  - `addons/sim-nav-map/docs/smoke-matrix.md`
  - `addons/sim-nav-map/docs/feature-roadmap.md`
- Keep this goal's progress in
  `.codex-goal/sim-nav-map-clearance-rasterization/Progress.md`.

## Explicit Non-Scope

- Feature 3+ work:
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

- Feature 2 core class-aware clearance rasterization smoke passes.
- `rtslab/smoke` remains green as adapter/playable regression.
- Docs clearly state the post-Feature-2 boundary between core addon and
  `examples/rts-pathfinding-lab`.
- Feature 3 dirty edit/cache lifecycle entry conditions are explicit.
