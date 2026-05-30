# InkMon L2 Main Game Vertical Slice

## Objective

Build InkMon L2 as the main game project in this repository: a playable single-player vertical slice with a working battle core, overworld entry flow, core NPC systems, player progression state, and enough content plumbing to consume lab-generated data later.

## Source Context

- Read `L2-M1-BRIEF.md` first for the immediate M1 battle slice.
- Read the lab design truth before implementation:
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\CONTEXT.md`
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\BUILD-PLAN.md`
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0001-inkmon-battle-is-atb-auto-battler.md`
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0002-v1-is-standalone-playable-vertical-slice.md`
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0003-dual-channel-stats.md`
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0004-skill-fixed-kit-rolled-from-pools.md`
  - `D:\GodotProjects\inkmon-lab\docs\plan\current\L2\adr\0005-l2-is-main-game-in-inkmon-godot.md`
- Read `CLAUDE.md`, `addons/logic-game-framework/CLAUDE.md`, `.claude/skills/lgf-new-logic-skill/`, and the reference implementation under `addons/logic-game-framework/example/hex-atb-battle/`.

## Durable Boundaries

- L2 is project-level game code under this repository, not a new addon example and not a new repo.
- `addons/logic-game-framework/example/hex-atb-battle/` is a reference implementation only. Do not modify or inherit from it as project gameplay code.
- L2 M1 may read `hex-atb-battle` actions, utils, AI, skills, world, and procedure files as reference only. New L2 battle code must not directly call or type against example classes such as `HexBattle*`, `CharacterActor`, `HexDemoWorldGameplayInstance`, `HexWorldGameplayInstance`, or `HexBattleProcedure`.
- Allowed dependencies for L2 implementation are LGF core/stdlib, project-level code, and generic addons such as `UGridMap` / `ItemSystem`. If an example helper is needed, fork it into `scenes/inkmon-battle/` with `InkMon*` naming and project-owned semantics.
- Prefer existing mechanisms before creating new systems: `GameWorld`, `GameplayInstance`, `EventProcessor`, `EventCollector`, `AbilitySet`, `AttributeSet`, `UGridMap`, `ItemSystem`, Godot `Node` / `Signal`, and project autoloads.
- Keep simulation state separate from presentation. Save serializable game state, not renderer nodes.
- Any `addons/` change is submodule work and must be committed in the submodule before bumping the parent pointer.

## Phase Plan

### Phase 0 - Goal And Architecture Planning

- Keep this `.codex-goal` documentation as the durable handoff.
- Before any non-trivial new framework, query the architecture KB and use `.agents/skills/game-architecture-patterns/`.
- For overworld / NPC / economy / PlayerState design, run `claude -p` multi-round consultation until consensus is reached or unresolved disagreements are recorded.
- For player-facing UI design, run `claude -p` consultation before implementation, then generate a visual mockup with `imagegen` and implement against the selected design.

### M1 - Headless Battle Core

- Project-level `InkMonUnitAttributeSet` with `hp`, `max_hp`, `ad`, `ap`, `armor`, `mr`, and `speed`; `hp` must cross-clamp to `max_hp`.
- New L2 battle code under `scenes/inkmon-battle/`, mirroring the hex ATB three-layer structure as project code.
- `InkMonUnitActor` as a full class fork of demo `CharacterActor`, using `role`, `species`, `stage`, `element_primary`, and `element_secondary` instead of demo `character_class`.
- 4v4 hand-written InkMon stub roster: tank, mage-DPS, healer, and flex on each side.
- M1 kit rule: each unit has one active skill plus a generic basic attack.
- Dual-channel damage formula: basic attacks use AD vs Armor; skills use AP vs MR; both then apply five-element damage multiplier.
- Role AI for tank, DPS, and healer.
- Headless M1 smoke test wired into the test launcher.

M1 implementation order:

1. Pass the Day-1 attribute-set gate before writing battle code.
2. Fork `CharacterActor` into `InkMonUnitActor`.
3. Add damage formula and five-element multiplier through the existing pre-damage pipeline pattern.
4. Reuse and adapt demo skills: `strike`, `fireball`, `chain_lightning`, `poison`, `holy_heal`, and `stun`.
5. Implement role AI.
6. Implement `InkMonBattleWorldGI` and battle procedure.
7. Add the M1 smoke.

M1 validation:

- `./tools/run_tests.ps1 inkmon/m1`
- Smoke ends with `SMOKE_TEST_RESULT: PASS`.
- Battle does not time out.
- Result is `left_win` or `right_win`.
- Losing side has zero alive units.
- Logs show final damage differing from base damage in at least one relevant case, proving resistance and/or element multiplier is active.

### M2 - Unit And Progression Systems

- Add project-level unit ownership data and PlayerState boundary.
- Add Equipment integration through the existing `ItemSystem`; do not create a parallel item system.
- Add engraving and per-InkMon progression hooks.
- Add birth roll / skill variance / evolution only after the fixed-kit data model is explicit.
- Add medal/player-level enhancement only after a framework design decision for player/team-level ability ownership; this is a known framework gap.
- Add focused tests or smoke scenes for each system before wiring into full gameplay.

### M3 - Overworld And Battle Entry

- Build the hex overworld as project gameplay code, not as battle-procedure code.
- Add player movement, camera/input boundary, and system NPC interaction flow.
- Add Training NPC as the battle entry path.
- Preserve a clear boundary between overworld simulation state, battle simulation state, and presentation.
- Validate with a smoke that moves/interacts through the real input path and enters/exits battle.

### M4 - Meta Systems And Economy

- Add Gold as the v1 currency.
- Add the six system NPC flows at minimal playable depth:
  - Shop: spend Gold on Equipment.
  - Training: enter battle and earn Gold.
  - Cultivation: spend Gold to level InkMon and trigger progression hooks.
  - Guild: minimal quest/task entry.
  - Trainer Advancement: spend Gold on player-level upgrades after the medal ownership model is designed.
  - Release/Adopt: debug-oriented InkMon acquisition.
- Add save/load for PlayerState, roster, inventory, progression, and world position.
- Validate an end-to-end loop: obtain/prepare InkMon, enter battle, receive reward, spend reward, persist state, reload.

### M-lab - Content Pipeline Alignment

- Coordinate with `inkmon-lab` for canon schema redesign: five elements, dual-channel stats, role, skill pools, validators, fixtures, and export format.
- Keep M1 hand-written stub data until the lab export contract is ready.
- Add import validation before replacing stubs with lab data.

## Non-Goals

- Do not expand M1 into overworld or economy work before the post-M1 design gate.
- Do not modify `addons/logic-game-framework/example/hex-atb-battle/` as the L2 implementation.
- Do not directly depend on `hex-atb-battle` example classes from L2 code; example code is reference-only, including lower-level actions and utils.
- Do not introduce multi-skill-slot AI in M1.
- Do not bypass failing tests, lint, or typecheck with no-verify style switches.

## Post-M1 World Design Gate

The overworld / NPC / economy / PlayerState part of L2 requires a separate framework-design discussion before implementation.

Required discussion workflow:

- Use `claude -p` for multi-round consultation with Claude until the design either reaches consensus or the unresolved disagreements are explicitly recorded.
- Use `.agents/skills/game-architecture-patterns/` during the discussion. Before recommending patterns, inspect existing project mechanisms and prefer reuse over new systems.
- Use `game-studio` / `web-game-foundations` as a boundary checklist only: simulation vs rendering, input model, asset ownership, save/debug/perf boundaries. Do not apply browser-stack assumptions to this Godot project.
- Produce a design handoff before coding, including chosen architecture, rejected alternatives, ownership boundaries, state serialization boundary, validation plan, and the first implementation slice.

## UI / UX Design Gate

Player-facing UI must be designed before implementation, not invented directly in code.

Required workflow for each major UI surface:

- Discuss with Claude through `claude -p` until the UI direction is agreed or disagreements are recorded.
- Cover at least: battle HUD, overworld HUD, NPC dialog, Shop, Training, Cultivation, Guild, Trainer Advancement, Release/Adopt, roster/equipment, save/load, and reward/progression feedback.
- Use `game-studio` UI guidance only as a checklist for playfield protection, HUD density, interaction clarity, and responsive constraints; adapt the result to Godot UI instead of browser assumptions.
- After discussion, use `imagegen` in `ui-mockup` mode to produce at least one visual design for the surface before implementation.
- Save selected project-bound mockups inside the workspace, preferably under `.codex-goal/l2-main-game-vertical-slice/ui-mockups/` until a permanent design-doc path is chosen. Do not leave project-referenced mockups only under `$CODEX_HOME`.
- Implement Godot scenes/styles according to the selected mockup. Any intentional deviation must be recorded in `Progress.md`.
- Validate implemented player-facing UI through DevAgent scene runs when a scene exists, in addition to any launcher smoke tests.

## Commit Policy

- Do not create WIP commits while tests or required validation are failing.
- Commit at meaningful phase checkpoints, preferably after each accepted implementation slice: M1 battle core, post-M1 design handoff, M2 progression slice, M3 overworld/battle-entry slice, M4 meta/save/load slice, and final closeout.
- Before every commit, inspect `git status --short`, stage only files owned by the current slice, and avoid staging unrelated user changes or generated noise.
- Before every commit, run `git diff --check` and the relevant validation command(s) recorded in `Progress.md`.
- If `addons/` is changed, commit inside the submodule first, then commit the parent repository submodule pointer update. Record both scopes in `Progress.md`.
- Commit messages should name the milestone/slice and the behavior delivered, for example `Add InkMon M1 battle smoke`.
- If validation cannot be run, do not commit unless the user explicitly accepts the risk; record the reason in `Progress.md`.

## Validation

- Phase-level validation commands must be recorded in `Progress.md` as each phase starts.
- M1 starts with `./tools/run_tests.ps1 inkmon/m1`.
- Runtime-facing gameplay validation must not rely only on headless assertions. Scene, UI, overworld, NPC, and player-flow work must be tested through real Godot scene execution.
- When a matching DevAgent-enabled scene exists, use `.agents/skills/run-dev-scene/` to drive the scene and verify behavior through actual runtime operations.
- When a new L2 gameplay scene needs runtime validation and has no DevAgent adapter, use `.agents/skills/dev-agent-scene-debug-mode/` first to add the minimal development-only adapter and document supported ops in `DEV_AGENT.md`.
- DevAgent verification is for development scene debugging and runtime confidence; launcher smoke/regression tests remain required for deterministic coverage.
- Later phases must add launcher groups or smoke scenes that prove their gameplay loop through real Godot scene/runtime paths, plus DevAgent runs for player-facing flows.
- Final vertical slice validation must prove: overworld movement, NPC interaction, battle entry, battle completion, reward, spend/progression, save, reload, and no M1 regressions.

## Completion Gate

- M1 through M4 are implemented and locally validated.
- The lab content boundary is either integrated or explicitly stubbed with a documented import contract and validation path.
- The player can complete the v1 loop in one local run: move in overworld, interact with NPCs, enter battle, win/lose a battle, receive/update resources, apply at least one progression/equipment action, save, and reload.
- Current tests/smokes for battle, overworld, systems, and save/load pass.
- No required full-scope L2 feature remains only as a stub or TODO without a documented deferral.
