# sim-nav-map Stabilization Goal

## Objective

Complete the `sim-nav-map` addon stabilization pass in `D:\GodotProjects\inkmon\inkmon-godot`.

## Deliverables

- Document the `addons/sim-nav-map` public API boundary.
- Clarify responsibility boundaries across the core addon, application adapter, and `examples/rts-pathfinding-lab`.
- Update README, usage docs, mental model, and feature roadmap.
- Replace or archive old RTS private pathfinder fixture wording so it is not treated as the active pathfinding baseline.
- Close the smoke matrix around stable `simnav/smoke` and `rtslab/smoke` regression entries.

## Constraints

- Do not add crowd steering, formation, push/yield, soft-block, or other game-specific movement policy to `sim-nav-map` core.
- Do not lift `examples/rts-pathfinding-lab` application policy into `sim-nav-map` core.
- Do not commit `addons/sim-nav-map/docs/references/0ad-source/`.

## Validation

```powershell
git diff --check
./tools/run_tests.ps1 simnav/smoke rtslab/smoke
```

Final audit must cover public API docs, old path references, docs links, smoke group discovery, and clean root/addons worktrees.
