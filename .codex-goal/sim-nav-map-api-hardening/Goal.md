# sim-nav-map Public API Hardening Goal

## Objective

Complete the `sim-nav-map` public API hardening pass in
`D:\GodotProjects\inkmon\inkmon-godot`.

## Scope

Allowed write scope:

- `addons/sim-nav-map/**`
- `.codex-goal/sim-nav-map-api-hardening/**`
- root submodule pointer update after committing the `addons` submodule

Do not modify `addons/logic-game-framework/example/rts-auto-battle/**`.

## Deliverables

- Audit `addons/sim-nav-map/docs/public-api.md` against the actual public
  `class_name` and non-underscore function boundary.
- Add or tighten `simnav/smoke` coverage for public entry points:
  constructor/defaults, dirty/cache lifecycle, path request queue cloning, and
  long/short query boundaries.
- Keep `examples/rts-pathfinding-lab` as an adapter consumer and playable
  regression; do not lift lab movement policy into core.
- Update README, usage, mental model, public API, and smoke matrix docs so they
  describe the same boundary.

## Constraints

- No crowd steering, formation, push/yield, soft-block, deadlock policy, or
  other game-specific movement policy in core `sim-nav-map`.
- No public API breaking rename unless compatibility and smoke coverage are
  added in the same pass.
- Do not commit `addons/sim-nav-map/docs/references/0ad-source/`.

## Validation

```powershell
./tools/run_tests.ps1 -List
git diff --check
./tools/run_tests.ps1 simnav/smoke rtslab/smoke
```

## Completion Gate

- Public API docs and actual public class/function boundaries have a final
  audit.
- `simnav/smoke` covers key public API contracts.
- `rtslab/smoke` remains a stable consumer regression.
- Root and `addons` worktrees are clean after local commits.
