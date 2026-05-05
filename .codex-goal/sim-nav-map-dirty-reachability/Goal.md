# sim-nav-map Feature 3+4: Dirty Lifecycle And Reachability Queries

## Objective

Complete `sim-nav-map` Feature 3 and Feature 4 from
`addons/sim-nav-map/docs/feature-roadmap.md` for the current target scope:

- Feature 3: terrain/static obstruction edit dirty recompute, hierarchical dirty
  recompute, and long-path cache invalidation lifecycle.
- Feature 4: explicit reachability query, nearest reachable goal
  canonicalization, canonical goal metadata, failure reason, and passability
  class/mask contract.

## Delivery Scope

- Add a stable dirty lifecycle integration entry so adapters do not hand-write
  terrain/static obstruction rasterization, hierarchical recompute, long-path
  cache invalidation, and dirty cleanup order.
- Add explicit reachability/canonical goal result metadata.
- Cover `POINT`, `CIRCLE`, `SQUARE`, inverted goal, passability masks, and dirty
  after region/canonical target changes.
- Update or add core smoke and register it in `simnav/smoke`.
- Keep `rts-pathfinding-lab` as adapter/playable regression only; update it only
  where needed to consume core reachability metadata.
- Update:
  - `addons/sim-nav-map/docs/public-api.md`
  - `addons/sim-nav-map/docs/usage.md`
  - `addons/sim-nav-map/docs/smoke-matrix.md`
  - `addons/sim-nav-map/docs/feature-roadmap.md`
  - `.codex-goal/sim-nav-map-dirty-reachability/Progress.md`

## Explicit Non-Scope

- Feature 5+ long path result contract, path post-processing, excluded regions,
  short path filter, line validation, request queue expansion, or scale
  diagnostics.
- Ship gameplay, water/land unit gameplay, formation, push/yield,
  stuck/deadlock, HUD policy, or game-specific movement policy.
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

- Feature 3 dirty edit/cache lifecycle core smoke passes.
- Feature 4 reachability/canonicalization core smoke passes.
- `rtslab/smoke` remains green as adapter/playable regression.
- Docs clearly state the post-Feature-4 boundary between core addon and
  `examples/rts-pathfinding-lab`.
- Feature 5 long-path query/result contract entry conditions are explicit.
