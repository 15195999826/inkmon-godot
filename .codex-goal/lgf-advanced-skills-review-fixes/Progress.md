# Progress

Last updated: 2026-05-24 03:12 +08:00

## Current State

- Status: active
- Branch: `master`
- Main repo review base: current workspace after LGF advanced skills Phase 2+ completion.
- Submodule: `addons` has the relevant LGF changes; leave unrelated untracked `sim-nav-map/docs/references/dota2-style-source/` alone.

## Codex Review Findings

- P1: `HexWorldGameplayInstance.remove_actor()` clears `grid.occupant` by coord for every `HexBattleActor`. Fire Tile is an overlay and is never placed as occupant, so lifetime cleanup can clear the character standing on the same hex.
- P1: production `HexBattleProcedure._start_recorder()` only records initial characters. Unlike skill preview and scenario harness, it does not register mid-spawn actors, so production replay can miss totem/fire tile `actorSpawned`, `abilityGranted`, and `executionActivated` events.
- P1: `SpawnActorAction` and `SpawnFireTileAction` call `battle.add_actor()` before team/position/abilities are initialized. Any synchronous `actor_added` consumer or recorder registration can snapshot incomplete actor state.
- P2: `HexBattleCleanse` declares `ally` + `self`, but `HexWorldGameplayInstance.can_use_skill_on()` rejects self targets for all ally skills.
- P2: Break short-circuits `receive_event()` and `tick_executions()`, but not `Ability.tick()`. Passive `TimeDurationConfig` abilities such as `TotemLifetime` / `FireTileLifetime` continue expiring while broken; this needs an explicit semantic decision and matching tests.

## Checkpoints

- 2026-05-24 02:53 +08:00 - Review archived - Findings above copied from Codex review into `.codex-goal/lgf-advanced-skills-review-fixes/`.
- 2026-05-24 02:53 +08:00 - Validation baseline - `./tools/run_tests.ps1 hex/skills` PASS 3/3; `./tools/run_tests.ps1 hex/regression` PASS 2/2; `./tools/run_tests.ps1 hex/frontend` PASS 6/7 with `frontend/smoke_surge_unit_view` timeout after logging expected buff label transitions.
- 2026-05-24 03:12 +08:00 - Fixes landed - Fire Tile overlay cleanup is occupant-safe; production `HexBattleProcedure` registers mid-spawn actors; spawn actions initialize position/team/abilities before `actor_added` observers snapshot; Cleanse self-target is allowed only when `self` tag is present; Break skips `lifetime` passives so Totem/FireTile lifetime still expires.
- 2026-05-24 03:12 +08:00 - Coverage added - Tightened Fire Tile occupant assertion; added Cleanse self scenario, Break lifetime scenario, and `smoke_mid_spawn_production_replay` covering Summon Totem + Fire Tile actorSpawned/abilityGranted/executionActivated/actorDestroyed in production procedure path.
- 2026-05-24 03:12 +08:00 - Validation - `git -C addons diff --check` PASS; `./tools/run_tests.ps1 hex/skills` PASS 4/4; `./tools/run_tests.ps1 hex/regression` PASS 3/3; `./tools/run_tests.ps1 core/unit hex/skills hex/regression` PASS 6/6.

## Blockers

- None.
