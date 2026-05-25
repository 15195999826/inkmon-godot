# ItemSystem Sandbox Closeout

## Objective

Close out the standalone Hex `item-preview` sandbox according to `addons/logic-game-framework/docs/skills/skill-preview-item-system-plan.md`: make the current checkout testable from a clean Godot state, use real sandbox `HexBattleActor` runtime ids for equipment containers, prevent unload failures from silently destroying equipped items, and finish with repeatable headless plus DevAgent real-input acceptance evidence.

## Deliverables

- `InventoryKit`, Hex item model, and `item-preview` scene load and test reliably from this workspace.
- `item_preview.tscn` shows player bag, 3 real sandbox actors, and 6 numbered equipment slots per actor.
- Real UI drag/drop covers equip success, occupied-slot reject, non-equipable reject, actor switch isolation, equipment-to-bag, and reset cleanup.
- Tests cover real actor ids, unload failure no item loss, scene boot, and data-layer contracts.
- `Progress.md` records phase checkpoints, root-cause notes, and final validation evidence.

## Non-Goals

- Do not integrate with `skill_preview.gd` or `skill_preview.tscn`, except for clearly necessary docs or test isolation notes.
- Do not implement equipment stats, orb effects, affixes, durability, cooldowns, or LGF ability grant/revoke behavior.
- Do not implement stack split or equipment swap; occupied equipment slots still reject moves.
- Do not replace DevAgent real-input acceptance with manual visual inspection.

## Validation

- `./tools/run_tests.ps1 -Required -MaxParallel 2`
- `./tools/run_tests.ps1 hex/regression -MaxParallel 2`
- `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_hex_item_domain.tscn`
- `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_item_preview_boot.tscn`
- DevAgent JSONL real-input acceptance for `item_preview.tscn`, following the plan's DevAgent Acceptance Flow, with transcript paths recorded in `Progress.md`.

## Completion Gate

- `./tools/run_tests.ps1 -Required -MaxParallel 2` passes on this machine.
- `item-preview` no longer uses fixed fake actor ids as sandbox actor substitutes; acceptance assertions use `selected_actor_idx` or display names rather than hard-coded runtime actor ids.
- Unload failure cannot destroy equipped items, with regression coverage.
- Final `Progress.md` closeout compares deliverables, non-goals, validation results, and remaining accepted descope.
