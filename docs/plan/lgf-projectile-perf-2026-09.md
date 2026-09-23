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

### 4.1 kards-tavern 复测（2026-09-23，公司电脑；kards-tavern `8a02545`）

探针 `game/tests/logic/perf_battle.tscn`。**规模与 handoff 基线不同**：handoff 的 20.3 / 30.4 量于小型单位容量 30（每方 203 / 270 人），kards-tavern `93e46dd`（09-23）已把 `match_config.json` 容量改成 12 / 4 / 2，同一探针现在是 mid 17 / mixed 82 / infantry 108 人每方。所以在同一台机器、同一数据上做三态 A/B，各跑两遍（两遍差 < 3%）：

| 每 tick（ms） | BEFORE：`0e5de9c` + filter | MID：`d750caf` + filter（只有刀 A/C） | AFTER：`d750caf` + precheck | AFTER ÷ BEFORE |
|---|---|---|---|---|
| mid（17 人/方，450 tick） | 1.26 / 1.26 | 0.92 / 0.93 | 0.82 / 0.85 | 0.66 |
| mixed（82 人/方，427 tick） | 6.00 / 5.90 | 4.45 / 4.57 | 3.49 / 3.47 | 0.58 |
| infantry（108 人/方，450 tick） | 9.10 / 9.04 | 6.70 / 6.69 | 5.24 / 5.18 | 0.57 |
| infantry 分帧 step(60) 最坏（ms/step） | 840 / 812 | 623 / 607 | 440 / 451 | 0.54 |

- 刀 A/C 单独约 26%（infantry 9.1 → 6.7），刀 B 再约 16 个点（→ 5.2），合计每 tick 省 43%；§0「30.4 → 约 20」那档（270 人）数据已不存在，没法再量，方向一致（两刀省的都是每颗弹 / 每次派发的固定开销，规模越大占比越高）。
- 回归：kards-tavern `logic/all` 9 + `static/all` 3 + `net/all` 10 场全 PASS（含 `smoke_projectiles` 213 checks、`smoke_battle_determinism`、lockstep 2 / 4 / 8 人哈希一致），六次探针日志无 `SCRIPT ERROR`；presentation 组要窗口，SSH 会话里没跑。
- 项目侧迁移细节见 handoff 文档末尾 §9（同一 commit）。

## 5. kards-tavern 侧待办（用户 push addons 之后）

> ✅ 2026-09-23 全部落地：kards-tavern `8a02545`（数字见 §4.1，项目侧细节见 handoff §9）。逐条结果：

1. ✅ submodule bump 到 `d750caf`。
2. ✅ `kt_basic_attack.gd`：`TriggerConfig.new(GameEvent.PROJECTILE_HIT_EVENT).precheck(_own_shot_precheck)`，比 `source_actor_id == h.owner_id and ability_config_id == h.config_id`，直接读 dict 不建对象。溅射（source id + source_kind + damage > 0）与碾压（killer id）条件全是事件字段，整段进 precheck、filter 删除；爆头拆两段（precheck 比 id / kind / is_kill，filter 只剩读目标血量）。**lend_lease / upgrade_promote_all 保持 filter**：比的是持有者席位 / piece_instance_id，都要取 actor（HandlerContext 只有三个 id），且是对局侧低频事件。`kt_armor_piercing` 走 `PreEventConfig` 的 pre 阶段 filter，不在 precheck 机制内。
3. ✅ `KtBattleWorld` 未 override `clear_grid_footprint`，handoff 4.6 两个绕法都没用。
4. ✅ 全仓 `place_occupant` 只在 `_place_piece` 对新棋子调一次（hydrate / 空降），没有重复 place；移动走 `move_occupant`。`piece_actor.gd` 头注释去掉已删除的 `IGridOccupant`。
5. ✅ 复测见 §4.1；`smoke_projectiles` 全绿（213 checks）。

## 6. 不做 / 后续

- handoff 4.3 的 (kind, owner) 索引：订阅者成百上千才值。
- handoff §6 C++ / §7 多线程：不做；`IdGenerator` 的线程安全（lomolib）等 kards-tavern 真要按场并行再加。
- handoff §5 `AbilitySet.tick_runtime` 快速路径（540 个单位每 tick 约 2 ms）：已落地，见 §7。
- `actor_position_changed` 由项目层 emit、stdlib 只声明：可考虑 stdlib 提供 `move_actor` 包装统一 emit，非本轮。
- `GridTileData.duplicate()` 拷贝 occupant 但不进索引（只在 `set_tile` 时进）：拿复制品另建模型时走 `set_tile` 即可。

## 7. 刀 D · `AbilitySet.tick` 快速路径（2026-09-23，handoff §5 第二条）

落地 commit：godot-addons `c74d9d2`（基于 `d750caf`）。kards-tavern bump 到它即含刀 A/B/C/D，项目代码零改动。

- 真实路径：一个只有常驻 StatModifier buff 的单位，每 tick 经 `tick_runtime` → `tick` 做约 6 次分配（tag 清理建 3 个容器 + lambda + `expired` 数组 + `duplicate` 快照）和 10–15 次空调用（每个 ability 两次 `is_expired`、每个 component `is_active` + 空 `on_tick`、每个 ability `has_executing_instance`）。
- 改法（用户拍板：组合、判断式）：
  - `AbilityComponent` 删掉按名字调用的 `on_tick` 钩子，新增 `get_tick_callable() -> Callable`；要随时间推进的 component 交出自己的函数（自己判 `is_active`）。交出去的就是函数本身，没有第二个开关。仓内只有 `TimeDurationComponent` 交函数；kards-tavern 没有自定义 `on_tick`（SSH `git grep` 核过），零迁移。
  - `Ability` 构造时收齐 `_tickers`（component 列表构造后不变），`needs_tick()` 据此回答。
  - `AbilitySet.tick` 每帧扫真实 `_abilities` 问 `needs_tick()`，没有就不走 `_process_abilities`——早退不遍历也就不需要快照，与「会回调用户代码的遍历走快照」铁律不冲突；有就原样走（快照照旧）。
  - `tick_executions` 开头「没有 execution 在飞直接返回」（只影响 dota2 / scenario harness 这类直接开门 2 的调用方；`tick_runtime` 本就先扫一遍）；`TagContainer.cleanup_expired_tags` 空列表直接返回。
- 为什么不是 `needs_tick` 声明 + grant/revoke 计数（最初提的 A 案）：声明是与函数分开的开关，忘一个就静默不 tick；计数是要随 `_abilities` 同步的簿记。用户拍板改判断式；不用继承标记类（`TickingComponent`）是因为单继承下能力不能叠加。代价：每帧多 N 次 `needs_tick()`（N = 身上 ability 数，kards 单位 1–3 个）。
- 预估：单位这条约 1.9 ms/tick → 约 0.4–0.6 ms；真实数字等 kards `perf_battle.tscn` 复测。
- 验证：`all-required` 21 场 + `hex/all` `dota2autobattle/smoke` `inkmon/m1` 40 场全 PASS；hex `random-golden`（10 seeds）与 inkmon `smoke_battle_golden` 位一致；`core/unit` 271（新增 `ability_tick_fast_path_test` ×6）。
- 顺带发现（未改，另开卡）：
  - `TagContainer.cleanup_expired_tags` 的 old count 在时钟拨过之后才算（`get_tag_stacks` 只数 `expires_at > now`），计时 tag 到期从不广播 `TagChanged`，旁边算好的 `removed_counts` 没人用——修它会往录像里加事件，要重烤两处 golden，先拍板再修。
  - hex `BattleAbilitySet.get_cooldown_remaining` / `reset_cooldown` 调的 `TagContainer.get_auto_duration_remaining` / `remove_auto_duration_tag` 不存在，两个方法无人调用（死代码，调了就崩）。
  - `tick_runtime` 命名与语义不符：它是「推进两扇门 + 回答『算行动的 execution 是否在飞』」，用户要求新名字不带 `tick_`；`_is_blocking_execution` 就是「哪些 execution 算行动」的项目定义，可一并改名。 ✅ 2026-09-23 已改（用户拍板 A：保留包装、改复合名）：`AbilitySet.tick_runtime` → `advance_and_is_acting`、`_is_blocking_execution` → `_is_acting_execution`（hex `BattleAbilitySet` / inkmon `InkMonBattleAbilitySet` / 测试子类的覆盖同名改；顺序不变量「is_acting 在 tick_executions 之前算」不动），addons `658d813`；`all-required hex/all inkmon/m1` 全 PASS，hex `random-golden` 与 inkmon `smoke_battle_golden` 位一致（在隔离 worktree 验，避开同树 peer 未提交的 TagChanged 改动）。kards-tavern 待 bump 时改：`game/src/logic/battle/kt_battle_procedure.gd` 65 / 75 / 76 行三处 `tick_runtime` → `advance_and_is_acting`，`game/src/logic/actors/kt_ability_set.gd` 7 行覆盖 `_is_blocking_execution` → `_is_acting_execution`。
