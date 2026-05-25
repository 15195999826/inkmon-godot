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
- `SkillPreviewWorldGI.reset()` clears old actor equipment containers while preserving player bag and items; new scene actors rebuild equipment containers with new runtime actor ids.
- Added `HexPlayerInventory.clear_actor_equipment_keep_player()` for SkillPreview reset semantics.
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
- reset keeps player bag and rebuilds actor equipment.
- start/reset battle keeps inventory state consistent.

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
- Player bag and player-owned item instances survive world reset; actor equipment containers are rebuilt or cleaned up on reset/add/remove.
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

Remaining accepted descope:

- Inventory panel is scoped to the SkillPreview character actor roster; environment actors are not exposed as equipment-bearing UI targets in Phase F.
- The explicit single-scene validation used Windows `godot_console` for reliable redirected console output; the scene is also covered by `hex/regression`.
