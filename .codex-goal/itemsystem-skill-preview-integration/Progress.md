# ItemSystem SkillPreview Phase F Progress

## 2026-05-25 Checkpoint

### Implemented

- Added SkillPreview inventory session boot:
  - `ItemSystem.reset_session()`
  - `ItemSystem.configure_domain(HexItemDomain, HexItemCatalog)`
  - preview-local `HexPlayerInventory.init_inventory()`
  - seed items in player bag.
- `SkillPreviewWorldGI` now holds the same `HexPlayerInventory`.
- `SkillPreviewWorldGI.add_actor()` registers equipment containers for scene `CharacterActor` runtime ids.
- `SkillPreviewWorldGI.remove_actor()` unloads equipment to player bag before removing an actor.
- SkillPreview reset now restores the initial demo inventory state: old item session is torn down, seed bag is recreated, and new scene actors rebuild equipment containers with new runtime actor ids.
- Added `HexPlayerInventory.clear_actor_equipment_keep_player()` for keep-player reset semantics; SkillPreview product reset later moved to full demo session rebuild.
- Added SkillPreview `Inventory` workspace tab:
  - player bag grid.
  - selected/current actor equipment slots `1..6`.
  - bag <-> equipment drag/drop through `ItemSystem.move_item()`.
- Reused `item-preview` `BagCell` / `EquipmentSlot` controls.
- Fixed reused item controls so child labels use `MOUSE_FILTER_IGNORE`; real drag input now hits the slot controls.
- Added SkillPreview DevAgent ops:
  - `show_inventory`
  - `inventory_state`
  - `inventory_layout_state`
  - `selected_actor_equipment_state`
  - `select_actor`
- Added smoke scene:
  - `addons/logic-game-framework/example/hex-atb-battle/tests/skill-preview/smoke_skill_preview_inventory.tscn`
  - registered in `hex/skill-preview`.

### Root Causes / Fixes

- Existing `SkillPreviewWorldGI.reset()` cleared `_actors` directly and emitted `actor_removed`, bypassing item equipment lifecycle.
  - Fix: reset now clears actor equipment containers before clearing world actors.
- `HexPlayerInventory.reset_actor_equipment_keep_player()` rebuilt containers for the same actor ids, which is wrong for SkillPreview reset because runtime actor ids are regenerated.
  - Fix: added `clear_actor_equipment_keep_player()` to unload + unregister without rebuilding stale ids.
- First DevAgent real-input drag dispatched successfully but did not move items.
  - Cause: display labels inside reused bag/equipment controls could intercept mouse input.
  - Fix: label `mouse_filter = Control.MOUSE_FILTER_IGNORE`.

### DevAgent Transcript

- PASS transcript:
  - Outbox: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\skill-preview-inventory-phase-f\outbox.jsonl`
  - Godot log: `C:\Users\Administrator\AppData\Roaming\Godot\app_userdata\Inkmon\dev-agent\sessions\skill-preview-inventory-phase-f\godot.log`
  - Ops: 26

Covered:

- initial inventory state.
- actor selection sync.
- bag -> equipment success.
- occupied slot reject.
- non-equipable reject.
- equipment -> bag.
- add actor creates equipment container.
- remove actor unloads/cleans container.
- reset restores initial demo inventory and rebuilds actor equipment.
- start/reset battle returns inventory to initial demo state.

### Final Validation

- PASS: `./tools/run_tests.ps1 hex/skill-preview -MaxParallel 2 -SkipImportRefresh`
- PASS: `./tools/run_tests.ps1 hex/skill-preview -MaxParallel 2` - 9/9.
- PASS: `./tools/run_tests.ps1 hex/regression -MaxParallel 2` - 5/5.
- PASS: `./tools/run_tests.ps1 -Required -MaxParallel 2` - 19/19.
- PASS: `godot_console --headless --path . addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_hex_item_domain.tscn` - direct single-scene run; output includes `SMOKE_TEST_RESULT: PASS - all HexItemDomain data-layer checks passed`.
- PASS: DevAgent JSONL real-input acceptance for `skill_preview.tscn`.

### Final Closeout

Phase F deliverables:

- SkillPreview boots a real preview-local `ItemSystem` session with `HexItemDomain`, `HexItemCatalog`, and `HexPlayerInventory`.
- `SkillPreviewWorldGI` owns/accesses the same player inventory and synchronizes actor equipment containers against runtime actor ids.
- Reset restores the initial demo player bag/items; actor equipment containers are rebuilt or cleaned up on reset/add/remove.
- Actor removal refuses to destroy an equipped item if unload-to-bag fails.
- Inventory workspace tab shows player bag and selected actor equipment slots `1..6`.
- Bag/equipment drag/drop uses `ItemSystem.move_item()` and keeps `HexPlayerInventory` / `ItemSystem` as the single authoritative state.
- Actor selection updates the equipment panel.
- DevAgent can observe `inventory_state`, `inventory_layout_state`, and selected actor equipment state, and can verify drag/drop through real input.
- SkillPreview lifecycle and inventory UI contract are covered by `smoke_skill_preview_inventory.tscn`.

Non-goals held:

- No equipment stats/effects, affixes, durability, cooldown, grant/revoke Ability, or attack effect implementation.
- No stack split and no equipment swap; occupied equipment slot still rejects the move.
- No direct business creation through `register_item_instance()` in SkillPreview UI/DevAgent/test flows.
- DevAgent remains scene-gated and disabled by default.
- `item-preview` remains the data-rule authority; SkillPreview only reuses its controls and routes through the same item domain/service APIs.

Follow-up notes:

- Inventory panel is scoped to the SkillPreview character actor roster; environment actors are not exposed as equipment-bearing UI targets in Phase F.
- The explicit `smoke_hex_item_domain.tscn` single-scene validation used Windows `godot_console` for reliable redirected console output; that data-layer scene is also covered by `hex/regression`.
- `smoke_skill_preview_inventory.tscn` is registered under `hex/skill-preview`, not `hex/regression`; future inventory acceptance must keep the DevAgent JSONL real-input drag/drop run in the gate when validating the UI loop.

### Review Follow-up Checkpoint

- Converted SkillPreview world reset equipment-unload failure from crash-only assert flow to recoverable `false` with `Log.error`, so UI/DevAgent reset calls can report `ok=false`.
- Registered actor equipment containers inside the `after_id_assigned` callback before `actor_added` is emitted.
- Tightened remove lifecycle: `remove_actor()` confirms the world actor exists before unregistering inventory, and environment removal now checks the world remove result.
- Stabilized `smoke_skill_preview_inventory.gd` seed item lookup by `config_id + slot_index`, avoiding reliance on container insertion order.
- PASS after follow-up: `./tools/run_tests.ps1 hex/skill-preview -MaxParallel 2` - 9/9.
- PASS after follow-up: `./tools/run_tests.ps1 hex/regression -MaxParallel 2` - 5/5.
- PASS after follow-up: `./tools/run_tests.ps1 -Required -MaxParallel 2` - 19/19.

### Product Semantics Update

- User decision: SkillPreview reset should restore the initial demo state, not preserve player bag state.
- Updated reset path to rebuild the preview-local `ItemSystem` session, recreate the seeded player bag, and rebuild actor equipment containers from fresh runtime actor ids.
- Updated `smoke_skill_preview_inventory.gd` to assert old equipped item instances are destroyed, seed items reappear in initial bag slots, and rebuilt actor equipment slots are empty after reset.
- Updated DevAgent docs so `reset_world_to_model` / `reset_battle` acceptance expects initial demo inventory state.
- PASS after semantics update: `./tools/run_tests.ps1 hex/skill-preview -MaxParallel 2` - 9/9.
- PASS after semantics update: `./tools/run_tests.ps1 hex/regression -MaxParallel 2` - 5/5.
- PASS after semantics update: `./tools/run_tests.ps1 -Required -MaxParallel 2` - 19/19.
- Note: an attempted parallel launcher run hit Godot import-refresh file locking; the same gates were rerun serially and passed.
