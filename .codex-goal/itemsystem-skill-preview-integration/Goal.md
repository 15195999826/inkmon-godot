# ItemSystem SkillPreview Phase F Integration

## Objective

完成 `addons/logic-game-framework/docs/skills/skill-preview-item-system-plan.md` 的 Phase F: 把已在 `item-preview` 验证过的 `ItemSystem`、`HexItemDomain`、`HexItemCatalog`、`HexPlayerInventory` 接入真实 `skill_preview.tscn` / `SkillPreviewWorldGI` lifecycle。

## Deliverables

- `skill_preview.tscn` 启动时配置 Hex item domain/catalog, 并初始化 preview-local `HexPlayerInventory`。
- `SkillPreviewWorldGI` 持有并访问同一套 `HexPlayerInventory`。
- SkillPreview scene actor equipment containers 使用真实 runtime actor id, 不硬编码 actor id。
- actor add/remove/reset/start-reset lifecycle 同步创建、卸回、清理或重建 equipment containers。
- player bag 和 player-owned items 在 reset 中保留。
- `skill_preview` UI 增加 Inventory tab, 展示 player bag 和当前/选中 actor 的 6 个 equipment slots。
- bag/equipment drag/drop 复用 `item-preview` 控件规则, 业务 mutation 只走 `ItemSystem.move_item()`。
- DevAgent scene ops 支持 `inventory_state`、`inventory_layout_state`、`selected_actor_equipment_state`, 并能通过 `drag_at` 真实输入验证 inventory UI 操作。
- smoke tests 覆盖 SkillPreview lifecycle、scene boot、inventory UI contract。

## Non-Goals

- 不重写 `item-preview` 已验证的数据规则。
- 不直接调用或绕过 `register_item_instance()` 做 Hex UI / DevAgent / test 业务创建。
- 不实现装备属性、法球、affix、durability、cooldown、grant/revoke LGF Ability、equipment attack effect。
- 不做 stack split。
- 不做 equipment swap; occupied equipment slot 直接拒绝。
- 不把 DevAgent 接口塞进 production 路径; bridge 默认 disabled。

## Verification Gate

- `./tools/run_tests.ps1 -Required -MaxParallel 2`
- `./tools/run_tests.ps1 hex/skill-preview -MaxParallel 2`
- `./tools/run_tests.ps1 hex/regression -MaxParallel 2`
- `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_hex_item_domain.tscn`
- 新增 SkillPreview inventory/lifecycle smoke scene headless PASS。
- `run-dev-scene` / DevAgent JSONL 验收 inventory flow PASS, transcript 路径记录到 `Progress.md`。
