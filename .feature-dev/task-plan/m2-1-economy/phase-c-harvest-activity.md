# M2.1 — Phase C — Harvest Activity + Drop-off Loop

> Phase C 是 RTS M2.1 Economy 的第三个 phase, **经济闭环核心**。**Scope 限定**: 引入 worker harvest cycle (Activity → Strategy → procedure 加 resources) + 一个新 smoke (`smoke_harvest_loop`); **不接** Phase D 的 cost 重平衡 / starting_resources 调值 / smoke_economy_demo 全闭环。
>
> Phase B 已收口 (RtsResourceNode + UnitClass.WORKER + idle 行为 + smoke_resource_nodes 通过)。Phase C 在此基础上接 harvest 行为 (worker → node → ct drop-off → team_resources 增长 → 回 node), 让 Phase D 的 cost 重平衡有"花的资源是从哪来的"的闭环。

---

## Acceptance (本轮 7 条)

- [ ] **AC1** `RtsAutoBattleProcedure.add_team_resources(team_id: int, delta: Dictionary)` (新)
  - 对称 `spend_team_resources`; 逐 key 加; key 不在 bucket 内 → 视作当前 0 起加; value=0 跳过
  - Activity 通过 `world.procedure.add_team_resources(...)` 调 (见 §设计决策 D9)
- [ ] **AC2** 新 `RtsHarvestActivity` (extends `RtsActivity`)
  - 字段: `target_node_id: String`, `harvest_progress: float`, `_nav_agent: RtsNavAgent`
  - on_first_run: nav_agent.set_target(node.position_2d)
  - tick:
    - target_node 不存在 / `is_depleted()` → return false (DONE; strategy 下 tick 找新 node)
    - 距离 ≤ HARVEST_RADIUS² → harvesting (累积 `harvest_progress += unit.harvest_speed * dt`; 累计 ≥ 1 单位 → `node.amount -= delta`, `worker.carrying[node.field_kind_key] += delta`); carrying 总和 ≥ carry_capacity → return false (worker 满载)
    - 距离过远 → 接近 (set_target 限频, 与 RtsAttackActivity NAV_REFRESH_INTERVAL 一致)
  - on_last_run: nav_agent.clear_target
  - is_equivalent_to: 同 target_node_id 视为等价 (避免 strategy 提议每 tick 重建 nav)
  - get_intent_label: "harvest" (in-range 时) / "approach" (接近时)
- [ ] **AC3** 新 `RtsReturnAndDropActivity` (extends `RtsActivity`)
  - 字段: `drop_off_id: String` (空表示 on_first_run 找最近), `_nav_agent: RtsNavAgent`
  - on_first_run: 找己方最近 RtsBuildingActor with `is_drop_off()` (Phase C 默认 ct 是 drop-off; 见 §设计决策 D6) → set_target(building.position_2d)
  - tick:
    - drop_off 不存在 / dead → on_first_run 重找; 仍找不到 → return false (DONE; strategy 下 tick 接管)
    - 距离 ≤ DROP_OFF_RADIUS² → 调 `world.procedure.add_team_resources(team_id, worker.carrying)` → `worker.carrying.clear()` → return false (DONE)
    - 距离过远 → 接近 (set_target 限频)
  - on_last_run: nav_agent.clear_target
  - is_equivalent_to: 同 drop_off_id 视为等价
  - get_intent_label: "drop_off" (抵达瞬间) / "return" (回程时)
- [ ] **AC4** 新 `RtsHarvestStrategy` (extends `RtsAIStrategy`)
  - decide(actor, world):
    - actor null / dead / world null → IdleActivity
    - worker.carrying 总和 ≥ 1 (上次 harvest 没 drop 完, 无论 carry_capacity 是否满) → ReturnAndDropActivity (`drop_off_id` 空让 Activity 自找)
    - 否则: 找最近未耗尽 ResourceNode (D7 round-robin nearest) → HarvestActivity(node.id); 找不到 → IdleActivity
  - **不读** `_cached_target_id` (worker mask=NONE → AutoTargetSystem skip 不写 cache); 自己扫 world.get_alive_actors() 过滤 RtsResourceNode + not is_depleted
  - HOLD_FIRE / DEFENSIVE / AGGRESSIVE stance 都 harvest (worker 不参战, stance 不影响; 见 §设计决策 D14)
- [ ] **AC5** `RtsAIStrategyFactory.get_strategy(WORKER)` 从 `_basic_attack` 切到 `_harvest_strategy`
  - 共享实例: `static var _harvest_strategy: RtsAIStrategy = RtsHarvestStrategy.new()`
  - WORKER 分支返 `_harvest_strategy`; MELEE/RANGED 仍返 `_basic_attack` (不动)
- [ ] **AC6** 新 `smoke_harvest_loop.{gd,tscn}` PASS
  - 起手 spawn (左 team 0): 5 worker @ ~ (100, 200) 簇; 双方 ct (不死, hp=2000) 防战斗终结
  - 中立 (team_id=-1): 1 gold node @ (250, 200); 1 wood node @ (250, 300)
  - 跑 N tick (default 600 tick @ 33.33ms ≈ 20 秒; 见 §设计决策 D13)
  - 验证:
    - gold_amount 增长 ≥ 100; wood_amount 增长 ≥ 100 (5 worker × 至少 1 cycle each × 10 capacity = 50 lower bound; 阈值 100 留余 5 worker 平均 2 cycle)
    - 至少 1 个 worker 经历过 cycle (HarvestActivity → ReturnAndDropActivity → HarvestActivity)
    - 资源节点 amount 减少 (gold_node.amount + wood_node.amount < 2 × max_amount)
    - 5 worker 全 alive, 无 SCRIPT ERROR
    - SMOKE_TEST_RESULT: PASS
- [ ] **AC7** Validation 全套不退化 (13 项, 与 Phase B 末态一致 + 新 smoke_harvest_loop)
  - LGF 73/73 PASS
  - 既有 6 RTS smoke (player_command / player_command_production / castle_war_minimal / production / crystal_tower_win / rts_auto_battle 4v4 main) PASS, 数字与 Phase B 末态完全一致 (4v4 不含 worker → 应 0 漂移)
  - smoke_resource_nodes (Phase B) PASS, 数字与 Phase B 末态一致 (worker idle → harvest strategy 切换不影响 200 tick 内没 ResourceNode 找的 idle smoke; 但 Phase C HarvestStrategy 找 node 时 spawn pos = node pos worker 会动 → 此 smoke 可能被 break, 见 §风险表)
  - 2 replay smoke (replay_bit_identical + determinism) PASS, 数字与 Phase B 末态完全一致 (4v4 main path 不含 worker)
  - frontend smoke (smoke_frontend_main) PASS

---

## 设计决策 (Phase C 启动时确认)

### D6 — Drop-off 建筑选择

**选**: 复用 `crystal_tower` (用户 2026-05-02 确认)

**Why**: 双方起手就有 ct (不需要新加 actor 类型 / building_kind / cfg); Phase C scope 最小; ct 兼任 drop-off 与 hex example "town hall" 模式异曲同工。

**Implementation**: `RtsBuildingActor` 加 `is_drop_off: bool` 字段 (默认 false; ct 起手设 true; Phase D 启动时若加 town_hall 也设 true)。`RtsReturnAndDropActivity` 通过 `world.get_alive_actors()` 过滤 `is RtsBuildingActor and is_drop_off and team_id == worker.team_id` 找最近。

**Alt**: 任意己方建筑都 drop-off (用户拒绝, barracks 被毁会让 worker 行为乱)。

### D7 — Worker AI 默认行为

**选**: 找最近未耗尽 `ResourceNode` (用户 2026-05-02 确认)

**Why**: round-robin 找最近, 简单决定性, bit-identical replay 友好; 5 worker 全部去同一 node 也 OK (D11 多 worker 同 node 无锁)。

**Implementation**: `RtsHarvestStrategy.decide` 用 `world.get_alive_actors()` 线性 scan, distance_squared_to 比较, 同距离取 actor_id 字典序最小 (决定性 tiebreak)。O(N) per worker per tick, 5 worker × 30 Hz = 150 ops/sec, 可接受。

**Alt**: GOLD/WOOD 比例平衡 / 玩家手动指派 (用户拒绝, scope 翻倍)。

### D8 — Worker 出生方式

**选**: hardcode smoke/demo 起手 spawn (用户 2026-05-02 确认)

**Why**: 与 Phase B smoke_resource_nodes 同模式; Phase C scope 最小; 不加 SpawnWorkerCommand。

**Implementation**: smoke_harvest_loop 起手 add_actor 5 个 RtsUnitActor with `unit_class=WORKER`; demo_rts_frontend Phase D 启动时再决定是否 spawn worker (Phase C 不动 demo)。

### D9 — Activity ↔ procedure 通信

**选**: `RtsWorldGameplayInstance` 加 `procedure: RtsAutoBattleProcedure` 引用字段 + `bind_procedure(p)` 方法; procedure._init 末尾 `world.bind_procedure(self)`; Activity 通过 `world.procedure.add_team_resources(...)` 调

**Why**:
- Activity 现有 sig (actor, world, dt) 没 procedure 引用 — 加 procedure 引用到 world 最低侵入
- 不改 Activity / RtsAIStrategy / bind_runtime sig — 改 sig 影响 4 个既有 Activity 子类 + factory + controller
- 与既有 `world.rts_grid` 模式一致 (Activity 通过 world 拿 grid 走 nav, 也通过 world 拿 procedure 走 resources)
- Example 层改, 无 LGF core / stdlib 风险

**Alt 否决**:
- 把 _team_resources 移到 world (cross-cutting refactor, 影响 spend_team_resources / get_team_resources / _install_team_configs / _team_resources 字段 5+ 处)
- Activity bind_runtime 加第二参数 procedure (改 4 个既有 Activity sig)
- Event-driven (push HarvestDroppedEvent, procedure tick 末消费 — 引入新 event 类型 + procedure 多一段消费循环, 复杂度高)

### D10 — HarvestActivity 实现模式

**选**: 单一 Activity 自管 nav (类似 `RtsAttackActivity` in-range/out-of-range 切换), 不用 child MoveTo 嵌套

**Why**: AttackActivity 已有"接近 + in-range 触发动作"模式, HarvestActivity 同构 (接近 + in-range 累积 progress); child 嵌套增加复杂度且 advance 顺序父先子后会让 reconcile 难调。

**Implementation**: 一个 Activity, tick 内根据距离判断 harvest (累 progress) 或 接近 (set_target 限频); 满 carry_capacity → return false → strategy 下 tick 提议 ReturnAndDropActivity。

### D11 — 多 worker 同 node 并发

**选**: 无锁, 多 worker 都能 harvest 同一 node, `node.amount` 共享递减

**Why**: 简单决定性 (无 lock = 无序无关); 5 worker 全部去同一 node 也 OK, amount 减得快但同时多 worker carrying 满载, drop-off 后再来一波。

**Risk**: 若 5 worker 站同一 node 互相 push_out 距离判定可能抖动 — Phase B 已验证 worker collision_radius=12, 簇站 spawn pos 互避微移; Phase C 启动 smoke 验证。

### D12 — 抵达判定半径

**选**: HARVEST_RADIUS = 32 px (worker collision 12 + node margin 20); DROP_OFF_RADIUS = 32 px (worker collision 12 + ct footprint margin 20)

**Why**: 类似 RtsAttackActivity ARRIVAL_THRESHOLD=4 但 worker harvest 不需要"贴脸" — node footprint 1×1 cell = 32 px, worker 走到 cell 内即可 harvest; ct footprint 通常 2×2 = 64 px, drop-off radius=32 让 worker 走到 ct 边即可 drop。

**Tunable**: Phase C 启动时若 smoke 数据卡边界 (worker 在边缘抖动不进入 radius), 改成 48 px。

### D13 — smoke_harvest_loop 跑多少 tick + 阈值

**选**: 600 tick @ 33.33ms = ~20 秒真实; 阈值 gold + wood 双 ≥ 100

**Why**:
- 一次完整 cycle ≈ MoveTo 1.5s (~120 px / 80 move_speed) + harvest ~2s (carry_capacity 10 / harvest_speed 5 per sec) + Return ~1.5s + drop instant ≈ 5 秒
- 600 tick (20 秒) ≈ 4 cycle/worker × 5 worker × 10 capacity = 200 (gold + wood 各 ~100)
- 阈值 100 留 50% 余 (worker 互相 push_out 抖动 / 寻路绕路损耗)

**Tunable**: Phase C 启动 implement 后跑一次实测 cycle 长度, 必要时调 N=900 tick 或调阈值。

### D14 — Stance 影响

**选**: Stance 不影响 worker (worker mask=NONE 不参战, AGGRESSIVE/HOLD_FIRE/DEFENSIVE 都 harvest)

**Why**: 与 Phase B 一致, worker 没 attack 行为, stance 是 attack 行为参数; HarvestStrategy 也不读 stance — 始终 propose harvest 链。

### D15 — `RtsUnitActor.carrying` 字段

**选**: 加 `carrying: Dictionary[String, int]` 字段 ({"gold": 10} / {"wood": 10}); HarvestActivity 累计加, ReturnAndDropActivity 抵达时 transfer 给 procedure 后 clear

**Why**:
- carrying 是 worker per-actor 状态, Activity 之间持续 — 必须挂 actor (不能挂 Activity, 因 Activity 切换会 GC)
- Dictionary[String, int] 与 cost / team_resources 同 schema, transfer 时直接 add_team_resources(team_id, carrying)
- 默认 {} 让既有兵种不受影响 (4v4 main 不读不写 carrying)

**Implementation**: `RtsUnitActor` 加 `carrying: Dictionary[String, int] = {}`; HarvestActivity tick 内 `actor.carrying[node.field_kind_key] = actor.carrying.get(node.field_kind_key, 0) + delta`; carry_total = `actor.carrying.values().reduce(...)` 算总量; ReturnAndDropActivity 抵达时 `world.procedure.add_team_resources(team_id, actor.carrying)` + `actor.carrying.clear()`。

### D16 — harvest_progress 累积 vs 立即扣 amount

**选**: per-tick 累积 progress (float), `floor(progress)` 单位时刻 mutate `node.amount` + `worker.carrying`

**Why**: 30 Hz tick, harvest_speed=5.0/sec → 每 tick 累积 0.166 progress; floor(progress) 走 0/1 单位 transfer (~6 tick 累积 1 单位); 离散单位让 node.amount / carrying 始终 int (与 cost dict 同 schema)。

**Implementation**: HarvestActivity tick:
```gdscript
harvest_progress += unit.harvest_speed * dt  # ~0.166 per tick
var transferable: int = floor(harvest_progress)
if transferable > 0:
    var actual: int = min(transferable, node.amount, capacity_remaining)
    node.amount -= actual
    actor.carrying[key] = actor.carrying.get(key, 0) + actual
    harvest_progress -= actual
```

**Alt 否决**: instant pickup (抵达 → 等 N tick → 一次性 carrying=10) — 不 RTS 体感, 但 Phase C 启动若发现累积模型跑出 bit-identical replay 漂移可降级 instant 模式。

---

## 子任务 7 步 (推荐顺序)

### C.1 — `RtsWorldGameplayInstance` + `RtsAutoBattleProcedure` 通信打通

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/core/rts_world_gameplay_instance.gd` (改)
- `addons/logic-game-framework/example/rts-auto-battle/core/rts_auto_battle_procedure.gd` (改)

**改动**:
- World 加字段 `procedure: RtsAutoBattleProcedure = null` + 方法 `bind_procedure(p: RtsAutoBattleProcedure) -> void`
- Procedure._init 末尾 `world.bind_procedure(self)`
- Procedure 加 `add_team_resources(team_id: int, delta: Dictionary) -> void` (对称 spend_team_resources; 逐 key 加; value=0 跳过; key 不在 bucket → bucket[key] = delta)

**完成判定**: import 0 错误; Phase B `smoke_resource_nodes` 跑通 (procedure._init 走通); 既有 4v4 main smoke 数字与 Phase B 末态完全一致

---

### C.2 — `RtsUnitActor.carrying` 字段

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/rts_unit_actor.gd` (改)

**改动**: 加字段 `carrying: Dictionary[String, int] = {}`; 既有兵种不读不写, 默认 {}

**完成判定**: import 0 错误; LGF 73/73 不退化; 既有 6 RTS smoke 数字与 Phase B 末态完全一致

---

### C.3 — `RtsBuildingActor.is_drop_off` 字段 + ct 起手设 true

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/logic/rts_building_actor.gd` (改)
- `addons/logic-game-framework/example/rts-auto-battle/logic/buildings/rts_buildings.gd` (改 — ct 工厂设 is_drop_off=true)

**改动**: RtsBuildingActor 加 `is_drop_off: bool = false`; `RtsBuildings.create_crystal_tower(...)` 末尾 `b.is_drop_off = true`

**完成判定**: import 0 错误; 既有 smoke 不退化 (字段默认 false, 不影响 placement / production / 攻击)

---

### C.4 — `RtsHarvestActivity` 新文件

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/activity/harvest_activity.gd` (新)

**改动**: §AC2 + §设计决策 D10 + D12 + D16 落地

**完成判定**: import 0 错误; smoke_harvest_loop 跑通 (worker 抵达 node + harvest_progress 累积 + 满载切换)

---

### C.5 — `RtsReturnAndDropActivity` 新文件

**文件**: `addons/logic-game-framework/example/rts-auto-battle/logic/activity/return_and_drop_activity.gd` (新)

**改动**: §AC3 落地; on_first_run 找己方最近 is_drop_off 建筑; tick 抵达调 procedure.add_team_resources

**完成判定**: import 0 错误; smoke_harvest_loop 跑通 (worker drop 后 team_resources 增长)

---

### C.6 — `RtsHarvestStrategy` 新文件 + factory 切换

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_harvest_strategy.gd` (新)
- `addons/logic-game-framework/example/rts-auto-battle/logic/ai/rts_ai_strategy_factory.gd` (改)

**改动**:
- HarvestStrategy: §AC4 落地 (carrying > 0 → ReturnAndDrop; 否则找最近 ResourceNode → Harvest; 找不到 → Idle)
- factory: 加 `static var _harvest_strategy: RtsAIStrategy = RtsHarvestStrategy.new()`; WORKER 分支从 `_basic_attack` 切到 `_harvest_strategy`

**完成判定**: import 0 错误; Phase B smoke_resource_nodes 行为变化 (worker 不再 idle, 开始去 node — 此 smoke 的 max_drift assertion 会破, 见 §风险表第 1 行)

---

### C.7 — `smoke_harvest_loop.{gd,tscn}` 新文件

**文件**:
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_harvest_loop.gd` (新)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_harvest_loop.tscn` (新)

**改动**: §AC6 落地

**完成判定**: `godot --headless ... smoke_harvest_loop.tscn > /tmp/m21_c_hl.txt 2>&1` 退出码 0 + tail 含 SMOKE_TEST_RESULT: PASS

---

## Validation 顺序 (C.1-C.7 全做完后)

按 `.feature-dev/Autonomous-Work-Protocol.md` §Validation 顺序:

```bash
# 1) Type check
godot --headless --path . --import > /tmp/m21_c_import.txt 2>&1

# 2) LGF unit tests (regression gate, baseline 73/73)
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/m21_c_lgf_unit.txt 2>&1

# 3) RTS 既有 6 smoke (4v4 main + production + 命令链路 + ct 胜负 + castle_war)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command.tscn > /tmp/m21_c_pc.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_player_command_production.tscn > /tmp/m21_c_pcp.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_castle_war_minimal.tscn > /tmp/m21_c_cw.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_production.tscn > /tmp/m21_c_prod.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_crystal_tower_win.tscn > /tmp/m21_c_ct.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/m21_c_main.txt 2>&1

# 4) Phase B smoke_resource_nodes (HarvestStrategy 切换可能 break, 见 §风险表第 1 行)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_resource_nodes.tscn > /tmp/m21_c_rn.txt 2>&1

# 5) 新 smoke_harvest_loop (Phase C 主 gate)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_harvest_loop.tscn > /tmp/m21_c_hl.txt 2>&1

# 6) Replay smoke (4v4 不含 worker → 应 0 漂移)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_replay_bit_identical.tscn > /tmp/m21_c_replay.txt 2>&1
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/replay/smoke_determinism.tscn > /tmp/m21_c_det.txt 2>&1

# 7) Frontend smoke (sanity)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn > /tmp/m21_c_fe.txt 2>&1
```

退出码 0 + 每个文件末尾 100 行检查 `SMOKE_TEST_RESULT: PASS`; 按 Bash 并行约定: 1+2 串行 → 3 (6 smoke 分 2 批并行 3 个/批) → 4+5 并行 → 6 (replay 2 个并行) → 7 单跑。

---

## 风险与对策

| 风险 | 触发条件 | 对策 |
|---|---|---|
| Phase B `smoke_resource_nodes` 被 break | C.6 切 factory 后 worker 不再 idle, 会去 node — Phase B smoke 期望 worker 距 spawn ≤ 50 px | **方案 A** (推荐): 把 Phase B smoke 改成"worker 找不到 ResourceNode → IdleActivity" 的 setup (smoke 起手不放 node, 验 idle); **方案 B**: smoke 删除 (Phase C smoke_harvest_loop 已覆盖 worker spawn + harvest cycle); Phase C 启动 implement 时定 |
| Activity ↔ procedure 通信循环 | World ↔ Procedure 互相 hold ref → leak | bind_procedure 在 procedure._init 末尾调; procedure.finish() 不需要 unbind (战斗结束 procedure GC, world 仍 hold null reference 也无害); 若 ObjectDB leak 增加, 加 weakref pattern |
| Bit-identical replay 漂移 (新 strategy + Activity) | 4v4 main path 不含 worker, 但 RtsAIStrategyFactory 加 _harvest_strategy 静态实例 init 顺序 / RNG state 影响 RtsRng | factory 静态 var 初始化在 LGF/example 加载时一次, 不受 RtsRng.set_seed 影响; replay smoke 应 0 漂移 — 若发现漂移, 排查 HarvestStrategy 内是否调 RtsRng (不应调; 找最近 node 用确定性 actor_id 字典序 tiebreak) |
| Multiple worker 同 node 抢 amount → 决定性破 | 5 worker 同 tick 调 `node.amount -= delta` — Godot Dictionary / actor 字段 mutate 顺序 | controller.tick 顺序 = `world.get_alive_actors()` 顺序 (按 actor 加入 world 顺序), 决定性; 同 tick 内多 worker mutate 顺序固定 → bit-identical |
| Drop-off 找不到 ct (ct 死亡) | castle_war 模式 ct 死亡 → drop_off 找不到目标 → return false → strategy 下 tick 找新 node 但 carrying 仍满载 → 死循环找 node 立刻满载 → 立刻找 drop-off → 找不到 → ... | smoke_harvest_loop 起手双方 ct hp=2000 不死 (与 Phase B 同模式); 真 castle_war 模式下 ct 死亡 = 战斗结束 (胜负判定 priority 高于 worker 行为), 死循环不会发生; Phase D smoke_economy_demo 加显式 carrying-locked-no-drop fallback 测 |
| HarvestActivity tick 内 nav 接敌频繁 set_target 抖动 | worker 接近 node 时距离 ~ HARVEST_RADIUS 边界, 可能 in/out 反复 | 与 RtsAttackActivity 同模式: NAV_REFRESH_INTERVAL=0.2s 限频 + 距离 > 2px 强制刷新; 不应抖动 |
| ResourceNode 同时被多 worker harvest, amount 减到负 | C.4 tick 内 `node.amount -= actual`; 5 worker 同 tick 都 transfer → 总和可能 > node.amount | C.4 tick 内 actual = `min(transferable, node.amount, capacity_remaining)`; node.amount 限上界后即使多 worker 同 tick 减也是先到先得 → 后到 worker actual=0 → harvest_progress 累但不 transfer → tick 末 strategy.decide 检测 node.is_depleted → 切其它 node |

---

## Commit 策略 (沿用 `Autonomous-Work-Protocol.md`)

Phase C 收口时: 7 个子任务 (C.1-C.7) 全部 acceptance 子项 PASS + smoke 不退化 + 文档同步更新 → submodule commit (`feat(rts-m21): Phase C done — harvest activity + drop-off loop + smoke_harvest_loop`) → 主仓 bump pointer commit (`feat(rts-m21): bump addons + 同步 .feature-dev`)。

中间子任务 (C.1-C.7 任意一个) 若全 acceptance 子项 PASS + 无回归, 也可 commit (与 Autonomous-Work-Protocol §Commit 策略 一致, 倾向"小 commit 比大 commit 易回滚")。

---

## Phase C 完成后

切到 Phase D (Cost Rebalance + smoke_economy_demo):
- 不归档 (同一 feature 早期 phase)
- 写 `phase-d-cost-rebalance.md` (Phase C 收口时新写)
- 更新 Next-Steps.md 当前目标 → Phase D; Progress.md 切到 Phase D 子任务清单
- m2-1-economy/README.md 把 Phase C 标 done, Phase D active
