# LGF 投射物性能刀（2026-09-23）

> 起因：kards-tavern「棋子技能与普攻实现」会话把普攻改成每发一颗 LGF 投射物后做性能实测，交接文档在公司电脑
> `C:\GodotProjects\kards-tavern\game\docs\handoff\2026-09-23-lgf-post-dispatch-fanout.md`。本文是插件侧的决策与落地记录。
> 落地 commit：godot-addons `d750caf`（基于 `0e5de9c`，即 kards-tavern 当时挂的版本）。

## 0. 结论

满编局（每方 9 棋 / 270 人，每 tick 落地约 29 颗弹）两处框架开销，都是「大量短命载体 actor」放大的：

| 开销 | 实测 | 根因 | 处置 |
|---|---|---|---|
| 移除一颗弹 210 µs，其中 190 µs 在 `clear_grid_footprint` | 5.6 ms/tick | 预订没有反向记录，按 id 翻整张图 | 刀 A/C：棋盘两本反向簿子 |
| `projectile_hit` 扇出，每个订阅者重建 context 后才在 filter 里拒 | 约 4 ms/tick | 订阅粒度只到 kind，「是不是我的弹」要 ctx 才能判 | 刀 B：trigger 两段式 precheck |
| `remove_handlers_by_owner_id` 把两张表过一遍 | 约 0.6 ms/tick | 同类：按 id 扫表 | 顺手：登记过 handler 的 owner 集合 |

预期：满编 infantry 30.4 → 约 20 ms/tick；中期规模（每方 6 棋 39 人）新模型降到与旧模型（当场命中）相当。真实收益只有 kards-tavern 的探针能量（§5）。

## 1. 刀 A/C · 棋盘：actor 站在哪由棋盘记，不由 actor 记

- `GridMapModel`（ultra-grid-map，同仓插件）加两本反向簿子：占用 `occupant → tile key`、预订 `reserver_id → {tile key}`；预订本体也搬出 `tile.metadata`，存模型自己的 `tile key → reserver_id`。新 API `remove_occupant_of(occupant)` / `cancel_reservations_by(reserver_id) -> int` / `get_reserved_coords(reserver_id)`；`find_occupant_position` 改走索引（Object 按引用、String 按值，不再跨类型 `==`）。
- 一个占用者同时只站一格：已在棋盘上的再 `place_occupant` 报错并返回 false（先 remove / move）。`set_tile` 整块替换作废旧占用与预订、新数据自带的 occupant 进索引；`initialize` / `initialize_from_tiles` 三表一起归零；空 reserver id 拒绝；`serialize()` 仍导出 reservation（顶层键）。
- stdlib `GridWorldGameplayInstance.clear_grid_footprint` 变成两句：`grid.remove_occupant_of(actor)` + `grid.cancel_reservations_by(actor.get_id())`。不读 actor 身上任何坐标字段；`IGridOccupant` 删除（除它自己没人用，且把 `hex_position` 这个名字写死在 stdlib 里，四边形格子支持时本来就得动）。
- **为什么簿子进插件不进 stdlib**：预订是项目 action 直接对 model 调的（hex `start_move_action` / inkmon `ink_mon_start_move_action`），stdlib 世界类看不见 reserve / cancel 那一刻；簿子必须和数据同处才不走样。ultra-grid-map 与 LGF、lomolib 同仓同 commit，不是外部依赖。
- **为什么不做「只对上过板的 actor 才清」**：D8 合同要求坐标无效也按 id 清预订；给 actor 别「我上过板」的徽章会和簿子对不上。反向簿子让没足迹的 actor 两次查找落空即返回——效果等于「只对上过板的做」，但由棋盘说了算。
- **stdlib 该不该有 `GridWorldGameplayInstance`**：该。它是「世界持一张棋盘」的绑定（持板 / 出 registry 必出棋盘且在 `actor_removed` 之前 / 录像地图钩子 / 三个观察 signal），被 hex / inkmon / kards 三个项目共用，前端 `world_view.bind_world` 靠它的类型和 signal，防泄漏合同靠它的 override 顺序。P9/D8（2026-09-12）把它从 hex 项目层搬进 stdlib，本轮不动结构。
- 纠错：讨论中说过「预订会随 `to_config_dict()` 进录像快照」——看错了。含预订的是 `serialize()`（完整状态导出），`to_config_dict()` 只有 config，录像快照从未含预订。搬出 metadata 的理由只剩「运行时态不混进瓦片数据、一处真相」。

## 2. 刀 B · `TriggerConfig.new(kind, filter).precheck(fn)`

- trigger 条件分两段，按顺序求值：① `precheck(event_dict, h: HandlerContext) -> bool` 只看事件 + 本 ability 的三个 id（owner / ability / config），不需要 actor；② `filter(event_dict, ctx: AbilityLifecycleContext) -> bool` 要完整 ctx。`match_single_trigger` 顺序 kind → precheck → filter；定向投递（ABILITY_ACTIVATE / GRANTED）只有这一处求值。
- 登记：`Ability._register_post_handlers` 按 kind 取全部 component 的 precheck **并集**进 `PostHandlerRegistration.prechecks`；该 kind 任一 trigger 没带 precheck → 空列表 → 全派（预过滤只许跳过「没有任何 trigger 可能匹配」的事件）。`EventProcessor.process_post_event` 在 `call_handler` 前用登记里现成的 `HandlerContext` 跑一遍，任一通过才叫人；trace ≥ 2 记 `skipped_by_precheck`。
- **为什么是 precheck 不是 owner_key 数据键**：用户拍板，语义更清晰——它表达的是「不需要 actor 就能判的条件」这一整族（是不是我射的 / 打中我 / 我杀的 / 我的 config），不限于 owner 相等。代价：放弃 handoff 4.3 的 (kind, owner) 索引，18 个订阅者用不上。
- **为什么 fluent 而不是位置参数**：两个 Callable 签名不同塞位置里分不清；`.precheck()` 自描述、无 `Callable()` 占位；现有 `TriggerConfig.new(kind, filter)` 写法全部照旧合法（本仓 22 处、kards-tavern 13 处零改动）。`precheck()` 是 copy-with：TriggerConfig 是共享 static 配置，原地改会污染全场。
- 迁移：内置 `ABILITY_ACTIVATE` / `GRANTED_SELF` 改成 precheck；hex 火球 / 精准射击 / move 改用 `HexBattleSkillHelpers.projectile_hit_precheck` / `ability_activate_precheck`（旧 `*_filter` 删除）；链锁闪电拆成 id precheck + 死活 guard filter；thorn / deathrattle / general_passive 未动（仍是 filter，语义需要 ctx 或未审）；inkmon 零改动（冻结）。
- 语义不变的证明：`hex/random-golden` 与 inkmon `smoke_battle_golden` 位一致。

## 3. 合同（已写进 LGF `CLAUDE.md`）

| 层 | 责任 |
|---|---|
| stdlib `GridWorldGameplayInstance` | 持板（`grid` / `configure_grid` / `configure_grid_model`）；出 registry 必出棋盘（`remove_actor` 先 `clear_grid_footprint` 再出 registry）；录像地图钩子 `_get_map_config()`；三个观察 signal。不读 actor 坐标字段。 |
| 项目层 | 开局 `place_occupant`；移动三件套 `reserve_tile` / `move_occupant` / `cancel_reservation` 并 emit `actor_position_changed`；死亡留尸体只调 `clear_grid_footprint`，真移除 `remove_actor`；AI / action 读 `world.grid`；载体（投射物）从不碰棋盘。 |
| 项目层 actor | stdlib 对它零要求。`hex_position` 之类是项目自己的位置缓存，真相在棋盘，同步是项目责任；死活 / 响应 / tag 与棋盘无关。 |

新铁律：**离场广播、子系统自查、自查必须 O(1)**——`remove_actor` 对每个 actor 都通知持 per-actor 状态的子系统（`note_actor_removed` / `clear_grid_footprint`），world 不猜谁在乎谁；子系统靠自己的索引一次查找判「没我的事」。

## 4. 验证（2026-09-23，本机）

| 组 | 结果 |
|---|---|
| `core/unit`（LGF 单测） | 265 ✅，含新增 post_dispatch ×5、GridWorld 合同改写 +1、GridModelIndex ×4 |
| `-Required`（21 场） | 全 PASS，含 `smoke_random_battle_golden` 位一致 |
| `hex/all` + `inkmon/all`（74 场） | 全 PASS，含 inkmon `smoke_battle_golden` / `smoke_battle_board_reset` |
| `dota2autobattle/smoke` + `dota2lab/smoke` + `core/skill-preview-env`（13 场） | 全 PASS |
| ultra-grid-map `tests/test_grid_map.gd`（`--script` 模式） | 6/6 PASS，含新加反向索引段 |

## 5. kards-tavern 侧待办（用户 push addons 之后）

1. `C:\GodotProjects\kards-tavern` 把 submodule bump 到 `d750caf`（或更新）。
2. 普攻命中组件 `kt_basic_attack.gd:42`：`TriggerConfig.new(GameEvent.PROJECTILE_HIT_EVENT, _own_shot())` → `TriggerConfig.new(GameEvent.PROJECTILE_HIT_EVENT).precheck(_own_shot_precheck)`，precheck 比 `source_actor_id == h.owner_id and ability_config_id == h.config_id`。溅射 / 爆头 / 碾压 / lend_lease / upgrade_promote 的 `_own_*` 同理：只比 id 的进 precheck，要读目标血量之类的留 filter（或拆两段）。
3. `KtBattleWorld` **不需要** override `clear_grid_footprint`；handoff 4.6 的两个项目层绕法都不用。
4. `place_occupant` 现在拒绝已在棋盘上的占用者：若有「同一棋子 place 两次」的写法会报错并返回 false，改成 `move_occupant`。
5. 复测 `godot_console --headless --path game tests/logic/perf_battle.tscn`，看 `PERF full[mixed]` / `PERF full[infantry]`（基线 20.3 / 30.4 ms/tick，预期 infantry 约 20）；`game/tests/logic/smoke_projectiles.tscn` 应全绿。

## 6. 不做 / 后续

- handoff 4.3 的 (kind, owner) 索引：订阅者成百上千才值。
- handoff §6 C++ / §7 多线程：不做；`IdGenerator` 的线程安全（lomolib）等 kards-tavern 真要按场并行再加。
- handoff §5 `AbilitySet.tick_runtime` 快速路径（540 个单位每 tick 约 2 ms）：另开一刀，先看 `Ability.tick` 每 tick 到底干了什么再设计早退条件。
- `actor_position_changed` 由项目层 emit、stdlib 只声明：可考虑 stdlib 提供 `move_actor` 包装统一 emit，非本轮。
- `GridTileData.duplicate()` 拷贝 occupant 但不进索引（只在 `set_tile` 时进）：拿复制品另建模型时走 `set_tile` 即可。
