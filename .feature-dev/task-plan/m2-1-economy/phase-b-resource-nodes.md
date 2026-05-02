# M2.1 — Phase B — Resource Nodes + Worker Class

> Phase B 是 RTS M2.1 Economy 的第二个 phase。**Scope 限定**: 引入 `RtsResourceNode` actor + `UnitClass.WORKER` + idle 行为 + 一个新 smoke (`smoke_resource_nodes`); **不接** harvest / drop-off / 任何经济闭环逻辑 (那些是 Phase C)。
>
> Phase A 已收口 (multi-resource cost 字段全链路 dict 化 + 既有 smoke 不退化)。Phase B 在此基础上扩 actor 类型 + 新 unit class, 不动 cost / placement / 已存在 smoke。

---

## Acceptance (本轮 6 条)

- [x] **AC1** 新 `RtsResourceNodeConfig`:
  - 字段: `field_kind: int` (枚举 `GOLD=0 / WOOD=1` 或 String — 见 §设计决策 D1); `max_amount: int = 1500`; `harvest_per_tick: int = 0` (Phase B 不用, 占位 Phase C); `footprint_size: Vector2i = Vector2i(1, 1)`; `actor_tags: Array[String]` 含 `"resource_node"` + 具体 kind 串 (gold node `["resource_node", "gold"]` / wood node `["resource_node", "wood"]`, 与 RTS 既有 unit_tags 双 tag pattern 一致 — `melee→["melee","ground"]`, `flying→["flying","air"]`)
  - 工厂 `static get_stats(field_kind) -> StatBlock` 与 `RtsBuildingConfig.get_stats` 同结构
- [x] **AC2** 新 `RtsResourceNode` actor 类:
  - 继承 `RtsBattleActor` (与 `RtsBuildingActor` 平级, 都不是 `RtsUnitActor`); 不参战 — `target_layer_mask = MASK_NONE`, atk=0, attack_range=0
  - 字段: `field_kind`, `amount: int` (起手 = config.max_amount, Phase C harvest 时减), `is_depleted() -> bool` 当 amount<=0; 缓存 `field_kind_key: String` (Phase C drop-off 时直接读)
  - 不阻挡 footprint (worker 可踩, 简化 path; 与 §设计决策 D2 一致); 不调 `grid.place_building` 注册 footprint
  - override `is_dead()` 返 `_is_dead or is_depleted()`; override `check_death()` 永远返 false (耗尽走 is_depleted, 不走 hp <= 0); override `can_attack()` 永远返 false
- [x] **AC3** 新 `RtsResourceNodes` 工厂 (类似 `RtsBuildings`):
  - `static create_gold_node() -> RtsResourceNode` / `static create_wood_node() -> RtsResourceNode`; 各方便 demo / smoke 调用
- [x] **AC4** `RtsUnitClassConfig` 新 `UnitClass.WORKER` (枚举值 = 3 by 顺序声明位置, 与既有 MELEE=0/RANGED=1/FLYING_SCOUT=2 不冲突):
  - 字段: `max_hp: 50.0`, `move_speed: 80.0` (与 melee 同; 慢一点也行 — Phase C 启动时调), `atk: 0.0`, `attack_range: 0.0`, `attack_speed: 0.0`, `collision_radius: 12.0`, `movement_layer: GROUND`, `target_layer_mask: MASK_NONE` (不打人, 不被 default strategy 选作目标), `unit_tags: ["worker"]`
  - 新字段 (Phase B 仅声明, Phase C 用): `carry_capacity: int = 10` (worker 最多背 10 单位资源), `harvest_speed: float = 5.0` (每 tick harvest_progress)
- [x] **AC5** Worker idle 行为不被 default `RtsBasicAttackStrategy` 干扰:
  - `RtsAIStrategyFactory.get_strategy(WORKER)` 复用 `_basic_attack` 实例 (与 §设计决策 D4 一致 — placeholder strategy 不新建); worker `target_layer_mask=MASK_NONE` 让 AutoTargetSystem 在 mover 阶段 skip → `_cached_target_id` 永远空 → `RtsBasicAttackStrategy.decide` 返 `RtsIdleActivity`. Phase C 用 `RtsHarvestStrategy` 替代此分支.
  - Worker spawn 后 stance=AGGRESSIVE 也不会主动找敌 (因 target_layer_mask=NONE → AutoTargetSystem 不写 cached_target); 走 idle
- [x] **AC6** 新 `smoke_resource_nodes.tscn`:
  - 起手 spawn: 5 worker (左方 team 0) + 1 gold node + 1 wood node (中立 team_id=-1) + 右方 1 ct (hp=2000 永远不死, 让 _check_battle_end ct 模式右方不败 + 左方 fallback 全灭模式 worker alive 不败 → 战斗持续 200 tick; 与 §风险表第 4 行方案一致)
  - Procedure 跑 200 tick (50ms tick = 10 真实秒); 期间 worker idle 在 spawn 位置 ± 小 drift (允许 group_formation 互避微移); 验证:
    - Worker 5 个全 alive
    - Worker 位置距离 spawn ≤ 50 px (idle, 不主动远离)
    - Worker `_cached_target_id` 始终空 (mask=NONE → AutoTargetSystem skip mover)
    - Gold node `amount` 不变 (= max_amount; Phase C 才会减)
    - Wood node `amount` 不变
    - 无 SCRIPT ERROR
    - SMOKE_TEST_RESULT: PASS
  - 既有 16 smoke + replay 双 smoke 不退化 (regression gate; Phase B 加新 actor type 应不影响)

---

## 设计决策 (Phase B 启动时确认)

### D1 — field_kind 类型: int 枚举 vs String

**选**: int 枚举 (与 `RtsUnitClassConfig.UnitClass` 一致风格), `RtsResourceNodeConfig.FieldKind { GOLD=0, WOOD=1 }`

**Why**: 与 RTS 既有枚举风格一致 (movement_layer / unit_class 都是 int); typed array iteration 时无 string compare 开销; smoke fixture 引用 `RtsResourceNodeConfig.FieldKind.GOLD` 比 `"gold"` 更安全 (typo 编译期挂)

**Note**: `cost: Dictionary[String, int]` 用 String key 是因为 Dictionary key 用 enum 不能 type 化; runtime field_kind ↔ `team_resources` key 映射用 helper `field_kind_to_resource_key(kind: int) -> String` 转 ("gold"/"wood")

### D2 — ResourceNode 是否阻挡 footprint

**选**: 不阻挡 (worker 可踩)

**Why**: 简化 Phase C HarvestActivity nav (worker 可走到 ResourceNode 中心, 不需要"附近 cell"复杂逻辑); ResourceNode amount 耗尽后 actor.is_dead → AutoTarget / activity 自然清理

**Implementation**: ResourceNode `add_actor` 后 **不调** `grid.place_building` 注册 footprint cells; 仅靠 actor.position_2d 让 AutoTargetSystem / Activity 找到

### D3 — Worker spawn 方式 (Phase B 阶段)

**选**: hardcode smoke 起手 spawn 5 个 (与 melee/ranged smoke 同样方式)

**Why**: Phase B 仅验证 spawn + idle 行为; Phase C 启动后视情况引入 `SpawnWorkerCommand` (但用户决策倾向继续 hardcode demo 起手, 不加新命令类型)

### D4 — Worker default strategy (Phase B 阶段)

**选**: 复用 `RtsBasicAttackStrategy` (worker target_layer_mask=NONE 让其 decide 时找不到敌 → 自然返 IdleActivity), 不新建 `RtsWorkerIdleStrategy`

**Why**: `RtsBasicAttackStrategy` 已正确处理 "无敌 → idle" 路径 (用 cached_target_id 空判断); 新加 strategy 仅为占位浪费; Phase C 启动 HarvestStrategy 时再新加

**Note**: 若发现 `RtsBasicAttackStrategy` 对 worker 行为有副作用 (如尝试 attack_move 默认前进), Phase B 收口前停下来跟用户对齐, 再决定是否新加 `RtsWorkerIdleStrategy`

### D5 — `RtsResourceNode` 与 `RtsBuildingActor` 关系

**选**: 平级独立子类 (都继承 `RtsBattleActor`); 不复用 `RtsBuildingActor`

**Why**:
- ResourceNode 不参战 / 无 production / 无 cost / 无 spawn_unit_kind, 大部分 RtsBuildingActor 字段不适用
- ResourceNode 不阻挡 (vs Building 阻挡 footprint), 行为路径不同
- `_check_battle_end` / `AutoTargetSystem` 通过 `is RtsBuildingActor` 判定建筑特性 — ResourceNode 不应误入此路径
- 平级让 `_world.get_alive_resource_nodes()` 类似过滤干净

---

## 子任务 6 步 (推荐顺序)

### B.1 — 新 `RtsResourceNodeConfig`

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_resource_node_config.gd` (新)

**改动**:
- `class_name RtsResourceNodeConfig extends RefCounted`
- 内嵌 `class StatBlock extends RefCounted` (字段同 §AC1)
- 内嵌 enum `FieldKind { GOLD = 0, WOOD = 1 }`
- 常量 `_GOLD_NODE_STATS` / `_WOOD_NODE_STATS` (raw const dict)
- `static get_stats(field_kind: int) -> StatBlock` (与 `RtsBuildingConfig.get_stats` 同模式; 未知 kind → Log.assert_crash)
- `static field_kind_to_resource_key(field_kind: int) -> String` (`GOLD → "gold"`, `WOOD → "wood"`)

**完成判定**: 文件存在 + class_name 注册 + import 0 错误

---

### B.2 — 新 `RtsResourceNode` actor

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/rts_resource_node.gd` (新)

**改动**:
- `class_name RtsResourceNode extends RtsBattleActor`
- 字段: `field_kind: int`, `max_amount: int`, `amount: int`, `field_kind_key: String` (cache field_kind_to_resource_key)
- ctor `_init(p_field_kind: int)`: 从 config 拿 stats 填字段; team_id=-1 (中立) 起手, 不属任一阵营
- `is_depleted() -> bool` 返 amount <= 0
- override `is_dead() -> bool` 返 `is_depleted()` (耗尽 = 死亡, 让 AutoTarget / Activity 自然清理)
- override `get_attack_range() -> float` 返 0.0; `get_atk() -> float` 返 0.0; `can_attack() -> bool` 返 false (不参战)

**完成判定**: 文件存在 + class_name 注册 + import 0 错误

---

### B.3 — 新 `RtsResourceNodes` 工厂

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/buildings/rts_resource_nodes.gd` (新; 放 buildings 目录是因为 RtsBuildings 工厂在那, 类似归类)

**改动**:
- `class_name RtsResourceNodes extends RefCounted`
- `static create_gold_node() -> RtsResourceNode` 返 `RtsResourceNode.new(FieldKind.GOLD)`
- `static create_wood_node() -> RtsResourceNode` 同上 WOOD

**完成判定**: 文件存在 + import 0 错误; smoke 调用工厂能生成 actor

---

### B.4 — `RtsUnitClassConfig.UnitClass.WORKER`

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_unit_class_config.gd`

**改动**:
- enum `UnitClass` 加 `WORKER = 3`
- 新常量 `_WORKER_STATS` (字段同 §AC4 + 新字段 `carry_capacity` / `harvest_speed`)
- `get_stats(unit_class)` match 加 `WORKER` 分支
- `StatBlock` 类加新字段 `carry_capacity: int = 0` (默认 0 让既有 MELEE/RANGED/FLYING_SCOUT 拿到值是 0); `harvest_speed: float = 0.0`

**完成判定**: import 0 错误; 既有 smoke (4v4 main / production / castle_war_minimal) 不退化 (因新加字段 default 0)

---

### B.5 — `RtsAIStrategyFactory` worker 路径 (D4 选 reuse RtsBasicAttackStrategy)

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_ai_strategy_factory.gd`

**改动**:
- `get_strategy(unit_class)` match 加 `WORKER` 分支返回 `_basic_attack_strategy` (复用既有 instance — strategy 是共享无状态)
- 若 D4 改决策为 "新 RtsWorkerIdleStrategy", 再新加 `logic/ai/rts_worker_idle_strategy.gd`

**完成判定**: smoke spawn worker 后无 SCRIPT ERROR; worker idle 行为符合 §AC5

---

### B.6 — `smoke_resource_nodes.tscn` + `.gd`

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_resource_nodes.gd` (新)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_resource_nodes.tscn` (新, 套节点指 .gd)

**改动**:
- 起手 spawn 5 worker (左方 team 0) + 1 gold node + 1 wood node (中立 team -1; 暂不加入 team 列表)
- 给左方 sentinel 让 fallback team-wipeout 不立刻判 right 胜 (1 个 melee HOLD_FIRE 占位; 与 smoke_player_command 同模式)
- procedure 跑 200 tick @ 50ms; 期间不下任何命令
- assert: 5 worker alive + 距 spawn ≤ 50 px + gold/wood node amount = max_amount + SMOKE_TEST_RESULT: PASS

**完成判定**: `godot --headless ... smoke_resource_nodes.tscn > /tmp/m21_b_rn.txt 2>&1` 退出码 0 + tail 含 SMOKE_TEST_RESULT: PASS

---

## Validation 顺序 (B.1-B.6 全做完后)

按 `.feature-dev/Autonomous-Work-Protocol.md` §Validation 顺序:

```bash
# 1) Type check (新加 5 个 .gd 文件 + UnitClass enum 扩, 走 import 确认编译)
godot --headless --path . --import > /tmp/m21_b_import.txt 2>&1

# 2) LGF unit tests (regression gate, baseline 73/73)
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/m21_b_lgf_unit.txt 2>&1

# 3) RTS 既有 6 smoke (Phase A AC5; 加新 actor 不应破)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.tscn > /tmp/m21_b_pc.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command_production.tscn > /tmp/m21_b_pcp.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_castle_war_minimal.tscn > /tmp/m21_b_cw.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_production.tscn > /tmp/m21_b_prod.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_crystal_tower_win.tscn > /tmp/m21_b_ct.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/m21_b_main.txt 2>&1

# 4) 新 smoke_resource_nodes (Phase B AC6 主 gate)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_resource_nodes.tscn > /tmp/m21_b_rn.txt 2>&1

# 5) Replay determinism (Phase B 改了 UnitClass enum, 应不影响 4v4 main; 但跑一遍 sanity)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_replay_bit_identical.tscn > /tmp/m21_b_replay.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn > /tmp/m21_b_det.txt 2>&1

# 6) Frontend smoke (sanity, 加新 unit class 不影响既有 visualizer)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn > /tmp/m21_b_fe.txt 2>&1
```

退出码 0 + 每个文件末尾 100 行检查 `SMOKE_TEST_RESULT: PASS`; 失败时不抬 timeout 重跑, 直接看 `SCRIPT ERROR`。

按 `Autonomous-Work-Protocol.md` 的 Bash 并行约定: 1+2 串行 → 3 (6 smoke 分 2 批并行 3 个/批) → 4 (单跑 5-15s) → 5 (replay 2 个并行) → 6 (单跑)。

---

## 风险与对策

| 风险 | 触发条件 | 对策 |
|---|---|---|
| RtsResourceNode 被 AutoTargetSystem 误选为 attack target | AutoTargetSystem 用 `is RtsBattleActor` 过滤; ResourceNode 是 RtsBattleActor | ResourceNode `target_layer_mask=MASK_NONE` (作为 mover) + 默认所有 attacker `target_layer_mask` 不含 ResourceNode 的 movement_layer (ResourceNode 应 movement_layer=NONE 或独立的 RESOURCE layer); 若发现攻击者尝试打 ResourceNode, 在 AutoTargetSystem 加 `is RtsResourceNode` 跳过 |
| Worker 不应被默认 strategy 替换 IdleActivity 后开始随机走 | RtsBasicAttackStrategy.decide 在无敌时仍返回 IdleActivity (验证过) | smoke 跑 200 tick 后 assert worker 距 spawn ≤ 50 px; 若漂移过大说明 strategy 行为有副作用, 启用 RtsWorkerIdleStrategy |
| 加 UnitClass.WORKER 破 既有 4v4 smoke | unit_class enum 值变化 / get_stats match 漏 default | enum 加在末尾 (=3 不挤掉既有 0/1/2); get_stats match 加 WORKER 分支不动既有; 既有 smoke 不传 WORKER 入参完全不走新分支 |
| smoke_resource_nodes 被 fallback team-wipeout 立刻判败 | 左方仅 worker (target_layer_mask=NONE), 右方空 → fallback 判左胜或战斗立刻结束 | 给左方加 1 个 melee sentinel (HOLD_FIRE); 不加右方 actor 让左方"赢"; 但 procedure 起手 _check_battle_end 立刻返 left_win 才不阻塞 worker idle 验证 — 实际上 fallback 模式下 right 全灭立刻判 left_win; 改方案: 给右方放 1 个 ct (hp=2000 永远不死) 让战斗持续 |

---

## Commit 策略 (沿用 Autonomous-Work-Protocol.md)

Phase B 收口时: 6 个子任务 (B.1-B.6) 全部 acceptance 子项 PASS + smoke 不退化 + 文档同步更新 → submodule commit (`feat(rts-m21): Phase B done — resource node + worker class + idle smoke`) → 主仓 bump pointer commit (`feat(rts-m21): bump addons + 同步 .feature-dev`)。

Phase A 收口已 commit (本轮 Phase B 启动前提交), 不与 Phase B commit 混。

---

## Phase B 完成后

切到 Phase C (Harvest Activity + Drop-off Loop):
- 不归档 (同一 feature 早期 phase)
- 写 `phase-c-harvest-activity.md` (Phase B 收口时新写)
- 更新 Next-Steps.md 当前目标 → Phase C; Progress.md 切到 Phase C 子任务清单
- m2-1-economy/README.md 把 Phase B 标 done, Phase C active
