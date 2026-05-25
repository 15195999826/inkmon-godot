# Progress

## Current State

- Status: complete
- Branch: master
- Workspace: `C:\GodotPorjects\inkmon-godot`
- Goal created: 2026-05-25 11:00 +08:00

## Checkpoints

- 2026-05-25 11:00 +08:00 - kickoff - starting from clean main repo and clean `addons` submodule; prior review found `./tools/run_tests.ps1 -Required -MaxParallel 2` currently fails with Godot class/cache/path resolution errors, `item-preview` uses fixed sandbox actor ids instead of real `HexBattleActor`, and `HexPlayerInventory` can still unregister an equipment container after unload failure.
- 2026-05-25 11:12 +08:00 - P0 cache/test launcher - reproduced that direct PowerShell `godot --import --quit` can refresh `.godot/global_script_class_cache.cfg` and then terminate the launcher before scene scheduling. Fixed `tools/run_tests.ps1` to run import refresh through the same `.bat` wrapper pattern as scene runs; `-List` now skips refresh. This makes stale class_name/path cache repair happen before tests without swallowing the rest of the script.
- 2026-05-25 11:13 +08:00 - P1 real sandbox actors - `item_preview.gd` now builds a preview-local `GameplayInstance`, creates three real `CharacterActor`/`HexBattleActor` instances, and registers equipment containers by each actor runtime id. `smoke_item_preview_boot.gd` asserts 3 actors, 6 slots each, non-`preview-actor-*` ids, and `ActorId.is_valid(actor_id)`.
- 2026-05-25 11:13 +08:00 - P2 unload failure semantics - `HexPlayerInventory.unregister_actor()` and `reset_actor_equipment_keep_player()` now return `false` and preserve equipment container, actor mapping, domain registration, and item existence when unload-to-bag fails. `smoke_hex_item_domain.gd` adds Phase 14/15 bag-full regressions proving the equipped item stays in its equipment container.
- 2026-05-25 11:16 +08:00 - P3 DevAgent real-input acceptance - launched `item_preview.tscn` with DevAgent session `itemsystem-closeout-20260525-111430`; final acceptance round `accept2-01..accept2-17` PASS. Covered supported_ops, seed/reset, inspect_controls/layout, real drag equip success, occupied reject, non-equipable reject, actor switch isolation, equipment -> bag, reset cleanup, and session info. The first failed attempt was a PowerShell helper bug (`$args` auto-variable swallowed `{idx:1}`), not scene logic; rerun passed after fixing the helper.
- 2026-05-25 11:23 +08:00 - final validation rerun - after tightening Phase 6 to assert `unregister_actor()` success, reran all required validation commands below; results remain PASS.

## Validation Transcript

- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 -Required -MaxParallel 2` - PASS 19 / FAIL 0 / TIMEOUT 0.
- `powershell -NoProfile -ExecutionPolicy Bypass -File tools/run_tests.ps1 hex/regression -MaxParallel 2` - PASS 5 / FAIL 0 / TIMEOUT 0.
- `cmd /c "godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_hex_item_domain.tscn > .claude\tmp\test-runs\direct_goal_smoke_hex_item_domain.log 2>&1"` - EXIT 0; `SMOKE_TEST_RESULT: PASS - all HexItemDomain data-layer checks passed`; includes Phase 14/15 expected unload failure errors with item preserved.
- `cmd /c "godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_item_preview_boot.tscn > .claude\tmp\test-runs\direct_goal_smoke_item_preview_boot.log 2>&1"` - EXIT 0; `SMOKE_TEST_RESULT: PASS - item_preview.tscn boot OK (80 bag cells / 6 eq slots / 5 seed items)`.
- DevAgent transcript:
  - Session dir: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\itemsystem-closeout-20260525-111430`
  - Outbox: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\itemsystem-closeout-20260525-111430\outbox.jsonl`
  - Stdout: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\itemsystem-closeout-20260525-111430\godot.stdout.log`
  - Inspect artifact: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\itemsystem-closeout-20260525-111430\node-dumps\accept2-03-inspect-inspect-controls.json`
  - Final actor ids after reset: `item_preview_sandbox_12:Character_13`, `item_preview_sandbox_12:Character_14`, `item_preview_sandbox_12:Character_15`.
  - Godot process stopped after acceptance.

## Closeout Review

- Deliverables: satisfied. InventoryKit/Hex item model/item-preview load under refreshed import cache; item_preview shows 80-cell player bag, 3 runtime actors, and 6 numbered slots per actor; real UI drag/drop paths passed through `drag_at`; data-layer and boot smoke cover the new contracts.
- Non-goals: preserved. No `skill_preview.gd/.tscn` integration; no equipment stats/orb/affix/durability/cooldown/grant-revoke ability work; no stack split or equipment swap; occupied slot still rejects.
- API boundary: satisfied. `rg "register_item_instance\(" addons/logic-game-framework/example/hex-atb-battle/item-preview addons/logic-game-framework/example/hex-atb-battle/logic/item addons/logic-game-framework/example/hex-atb-battle/tests` found no Hex UI/DevAgent/test direct calls.
- Accepted descope: direct PowerShell invocation of `godot --headless --path . <scene>` is still avoided for transcript commands because this Windows shell can swallow continuation/output; validation uses `cmd /c` redirection per project testing guidance. Existing Godot exit leak warnings remain pre-existing non-blocking warnings.

## Blockers

- None
