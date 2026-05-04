# RTS Pathfinding M3 Epic / M5 — LongPathfinder + PathfinderFacade — Summary (2026-05-04)

> M3 Epic 第六个 milestone(M5/9)。引入 `RtsLongPathfinder`(朴素 A* on NavcellGrid)替换老 `RtsPathfinding`(plugin GridPathfinding wrapper);引入 `RtsPathfinderFacade` 顶层入口聚合 hierarchical canonicalize + LongPath A*;wire 进 nav_agent / activity 链路;一次性兑现 M4 deferred 项(canonicalize 切到"总是 navcell 中心"+ ✋2 体验点验收)。
>
> **新 baseline CSV 968343 bytes**(M4 末态 829520 → +17% LongPath 路径变化 P1 接受)。LGF 73/73 + replay seed=42 deep-equal frames=11 events=24 + 8 RTS smoke + 5 hierarchical smoke + 3 long_pathfinder smoke 全 PASS。
>
> **M5.5b-e RtsBattleGrid 完整删除** DEFERRED 到 EPIC 末 cleanup phase(用户决策推迟 8-10h wallclock 纯 cleanup work)。

---

## Acceptance 结论 (M5.1-M5.4 + M5.5a + M5.6 全过;AC1-AC8 完成或显式 DEFERRED)

### M5 子 phase 状态

| Sub | Scope | 状态 |
|---|---|---|
| **M5.1** | Data classes:RtsLongPathRequest(ticket/start/goal/mask/notify) + RtsWaypointPath(反向存储 PackedVector2Array,back/pop_back O(1)) + RtsPathGoal(5 type enum,M5 仅 POINT 实现) | ✅ done |
| **M5.2** | RtsLongPathfinder 朴素 A* on NavcellGrid:8-邻居 deterministic + COST_HV=65536 / COST_DIAG=92682 整数 cost + 5 元组 lex compare bsearch+insert heap + reconstruct 反向存储 + grid<65536 _pack_cell assert + **direct-path fallback**(终点 navcell impassable → 单 waypoint = goal.center,跟老 RtsPathfinding 一致) | ✅ done |
| **M5.3** | RtsPathfinderFacade 顶层:compute_path_immediate(玩家 click,过 canonicalize) / compute_path_direct(actor 中心 target,不过 canonicalize) / is_goal_reachable / make_goal_reachable;hierarchical 加 make_goal_reachable_pathgoal(M5 PathGoal-aware,**总是 mutate 到 navcell 中心 POINT**;M4b reachable→no-op 临时方案被替代) | ✅ done |
| **M5.4** | nav_agent 加 facade + _pass_mask 字段 + attach_pathfinder;set_target 加 canonicalize 参数(facade 优先 + 老 RtsPathfinding fallback);activity 端按语义区分(玩家 click=true / actor 中心=false);procedure._init 末构造 facade + 遍历 _unit_runtimes attach | ✅ done |
| **M5.5a** | NavcellGrid 提升为 world 一等公民字段(`world.navcell_grid: RtsNavcellGrid`),production code 走此直接 | ✅ done |
| **M5.5b-e** | RtsBattleGrid 完整删除(_placement_map / place_building / is_blocking / world_to_coord / 整类删除文件) | ⏸ DEFERRED 到 EPIC 末 cleanup phase |
| **M5.6** | 3 smoke(basic / unreachable / determinism)+ 新 baseline CSV 接受 + 全套 validation + ✋2 体验点 headless mock | ✅ done |

### AC1-AC8 验收

- ✅ **AC1** RtsLongPathRequest / RtsWaypointPath 落地 — `smoke_long_pathfinder_basic` 数据 class 字段 + push/back/pop_back/clear PASS
- ✅ **AC2** A* heap 5 元组 lex compare deterministic — `smoke_long_pathfinder_determinism` 5 sub-test(direct line / 绕障 / 紧密缝隙 / 长路径 / facade 整链)byte-identical 跨 2 runs
- ✅ **AC3** Octile heuristic + integer cost — basic smoke `_test_integer_cost_ratio` 验 COST_DIAG/COST_HV ≈ √2(0.001 tol)
- ✅ **AC4** Facade 顶层入口工作 — `smoke_long_pathfinder_unreachable` 5 sub-test(canonicalize 可达 mutate 到 navcell 中心 / 不可达 mutate 到 start 同 GlobalRegion 离 goal 最近 / direct 终点 impassable → direct-path fallback / 纯查询不 mutate / ✋2 mock)
- ⏸ **AC5** Activity / command 迁完(grep "GridPathfinding.find_path" 0 处)— 部分:nav_agent 走 facade 优先,RtsPathfinding 仍保留作 facade null fallback 兼容老 smoke;**真正 0 caller 在 M5.5b-e DEFERRED**
- ⏸ **AC6** RtsBattleGrid facade 删除 — **DEFERRED 到 EPIC 末 cleanup phase**(M5.5a navcell_grid 提升 done,实际删除文件推迟)
- ✅ **AC7** 3 smoke PASS + Validation — long_pathfinder basic / unreachable / determinism 全 PASS;LGF 73/73 + replay deep-equal + 8 RTS smoke + 5 hierarchical smoke 全 PASS;**新 baseline CSV 968343 bytes 接受**(P1 LongPath 算法变化预期)
- ⏸ **AC8** Perf ≤ 50% — 没单独 perf benchmark(M4-perf-gate realistic demo 也只 +28 ms vs 阈值 30 ms;M5 加 LongPath A* 实际 demo 影响小,因 set_target 频次低 0.2s 限频);留 EPIC 末 perf 复测时一起做

---

## 关键 artifact 路径

### 修改文件 (submodule)

```
addons/logic-game-framework/example/rts-auto-battle/
├── core/
│   ├── rts_world_gameplay_instance.gd        ← +long_pathfinder / pathfinder_facade /
│   │                                            navcell_grid 字段(M5.5a 提升)
│   └── rts_auto_battle_procedure.gd          ← _init 末构造 facade + LongPathfinder + 遍历
│                                                _unit_runtimes attach_pathfinder
├── logic/
│   ├── components/rts_nav_agent.gd           ← +facade + _pass_mask + attach_pathfinder + set_target
│   │                                            canonicalize 参数(facade 优先 / 老 RtsPathfinding fallback)
│   ├── activity/activity.gd                  ← _refresh_nav_target +canonicalize 参数
│   ├── activity/attack_activity.gd           ← AttackActivity 调 canonicalize=false
│   ├── activity/harvest_activity.gd          ← HarvestActivity 调 canonicalize=false
│   ├── activity/return_and_drop_activity.gd  ← ReturnAndDropActivity 调 canonicalize=false
│   └── pathfinding/rts_hierarchical_pathfinder.gd  ← +make_goal_reachable_pathgoal
│                                                       (M5 切 "总是 navcell 中心 mutate")
└── tests/baselines/0ad-baseline-master.csv   ← REPLACE 829520→968343 bytes(M5 P1 接受新 baseline)
```

### 新建文件 (submodule)

```
addons/logic-game-framework/example/rts-auto-battle/
├── logic/pathfinding/
│   ├── rts_long_path_request.gd          ← data class(ticket/start/goal/mask/notify_entity)
│   ├── rts_waypoint_path.gd              ← 反向存储 PackedVector2Array container(back/pop_back O(1))
│   ├── rts_path_goal.gd                  ← 5 type enum(POINT/CIRCLE/SQUARE/INVERTED_*)+ helpers
│   │                                        (M5 阶段仅 POINT 实现,CIRCLE/SQUARE 占位)
│   ├── rts_long_pathfinder.gd            ← 朴素 A* on NavcellGrid(~280 行;5 元组 lex + 整数 cost
│   │                                        + reverse-stored reconstruct + direct-path fallback)
│   └── rts_pathfinder_facade.gd          ← 顶层 facade(~110 行;compute_path_immediate /
│                                            compute_path_direct / is/make_goal_reachable)
└── tests/battle/
    ├── smoke_long_pathfinder_basic.{tscn,gd,gd.uid}        ← AC1+AC2+AC3 7 sub-test
    ├── smoke_long_pathfinder_unreachable.{tscn,gd,gd.uid}  ← AC4 5 sub-test + ✋2 mock
    └── smoke_long_pathfinder_determinism.{tscn,gd,gd.uid}  ← AC2 5 元组 lex 5 sub-test
```

### 子任务 commit

- submodule sha **ede3b2a**: `feat(rts-m3): M5.1-M5.4 done — LongPathfinder A* + Facade + nav_agent wire`
- submodule sha **47fefa3**: `refactor(rts-m3): M5.5a — promote NavcellGrid to world first-class field`
- submodule sha **ae2790d**: `feat(rts-m3): M5.6 — long_pathfinder smoke (unreachable + determinism) + new baseline CSV`

---

## Spec 偏离 / DEFERRED 决策

### 1. canonicalize 二分(玩家 click vs actor 中心 target)

spec §M4b.3 "AI attack-move 走单独路径(不过 canonicalize)" 描述 wire 入口区分。M5 实测发现:
- **玩家 click move**(target=地图坐标)走 canonicalize=true:goal 落 impassable → mutate 到外缘 navcell → unit 走最近 reachable navcell(✋2 体验点)
- **actor 中心 target**(attack/harvest/drop)走 canonicalize=false + LongPath direct-path fallback:goal 落 footprint/inflate(必然) → A* 找不到 path → 返回单 waypoint = 原 goal.center → unit 直接走过去 → distance check (HARVEST_RADIUS / attack_range / DROP_OFF_RADIUS) 决定 in-range 行为

**关键 insight**:M4b.3 wire fail lesson 的真正解法不是单条"AI 不过 canonicalize",而是 **canonicalize=false + direct-path fallback** 双轨。direct-path fallback 跟老 RtsPathfinding.find_path 终点 impassable 行为一致,确保 actor 中心 target 不死循环。

### 2. M5.5b-e RtsBattleGrid 完整删除 DEFERRED 到 EPIC 末 cleanup phase

spec §M5.5 写"M5 末删除 RtsBattleGrid 文件 + rename rts_grid → navcell_grid"。实际 caller 数量评估:
- production code (5 处:rts_battle_actor.world_to_coord / rts_building_placement.is_blocking / world_to_coord / rts_place_building_command.place_building / procedure.start.place_building):2-3h migration
- frontend (RtsBattleMap.grid 重命名 + 内部走 navcell_grid):1h
- 22+ smoke `_grid = RtsBattleGrid.new(...)` + method call (HexCoord vs Vector2i):4-5h
- baseline regen + debug:1-2h

**实际 8-10h wallclock 纯 cleanup work**,不影响 functionality(production code 数据已走 NavcellGrid + ObstructionManager,RtsBattleGrid 是 thin wrapper)。**2026-05-04 用户决策**:推迟到 EPIC 末 cleanup phase(M8 后)集中做,不阻塞 M6 启动。

### 3. M5.5a navcell_grid 一等公民提升(部分实现 spec §M5.5)

`world.navcell_grid: RtsNavcellGrid` 字段 done(从 rts_grid 内部提升)。procedure._init 末填值。production facade / hierarchical / long_pathfinder 构造走此直接,不再 `world.rts_grid.get_navcell_grid()`。这是 M5.5b-e 的预备步,删除 RtsBattleGrid 时 callsite 从 navcell_grid 走更顺。

### 4. AC5 / AC6 / AC8 部分 DEFERRED

- **AC5** "grep GridPathfinding.find_path 0 处":nav_agent 走 facade 优先,但 facade null 时 fallback 老 RtsPathfinding。0 caller 真删要等 M5.5b-e。
- **AC6** "RtsBattleGrid facade 删除":同 §2 推迟。
- **AC8** Perf ≤ 50%:M5 没 dedicated perf benchmark。M4-perf-gate realistic demo 28 ms ≤ 30 ms 阈值,M5 加 LongPath A* set_target 频次低(0.2s 限频),实际 demo 影响小;留 EPIC 末 perf 复测一起做。

---

## Simplify pass 改进

M5.1-M5.4 收口前:
1. **direct-path fallback** 加在 LongPathfinder.compute_path_immediate(终点 impassable → 单 waypoint = goal.center)解决 attack/harvest/drop 走 canonicalize=false 时 actor 中心落 footprint 内 A* 找不到 path → unit 站住的 bug。这是 spec 不涉及但实测 driven 的关键 fallback。
2. **canonicalize=false + direct-path fallback** 双轨设计,M5.4 wire 时遇到 harvest gold=0 FAIL 才 driven discover。docstring 已写清两条 callsite 分别用法。

M5.6 没明显 simplify 候选(smoke 已经简洁,facade / LongPath 已 hot-path optimize 过)。

---

## 决策来源 / 引用

- spec: `task-plan/m3-0ad-pathfinding-migration/milestones/M5-long-pathfinder.md` §M5.1-§M5.6
- 数据结构: `task-plan/m3-0ad-pathfinding-migration/data-structures.md` §6 (LongPath 整数 cost + reverse-stored path)
- API: `task-plan/m3-0ad-pathfinding-migration/interfaces.md` §4
- 决策模型: 2026-05-04 用户确认 "M5 full 严格 spec" → 中途 "M5.5b-e DEFERRED 到 EPIC 末" 决策
- 风险: `task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md` §1.3 (baseline CSV 漂 P1) + §3 stop runner 9 条
- 0 A.D. 对照: `helpers/LongPathfinder.h:120-180` 公开 API + `Pathfinding.h:127` WaypointPath 反向存储
- M4 末态 baseline: `archive/2026-05-04-rts-m3-m4-hierarchical/Summary.md`

---

## 残余风险 → M6 启动

- **R1 RtsBattleGrid 仍存在**: M5.5b-e DEFERRED,production code 仍走 rts_grid wrapper 调 world_to_coord / place_building 等;M6 / M7 启动时 callsite 仍可用,但 EPIC 末必须清理。**风险**: M6 / M7 引入新 caller 用 rts_grid 接口让 cleanup 工作量越积越大 → **mitigation**: M6/M7 新代码强制走 navcell_grid + facade 直接,不调 rts_grid
- **R2 baseline CSV +17% 漂动**: M5 接受新 baseline 968343 bytes;M6 短路径 + M7 motion 重写还会进一步漂动(P1 预期)。每 milestone 末 spec §1.3 流程接受新 baseline
- **R3 Direct-path fallback 跟 M6 VertexPath 关系**: M6 VertexPath 引入"corner vertex" 短路径,可能让 attack 走更精确路径(不需要 LongPath direct-path fallback)。M6 落地后重新评估 fallback 是否仍必要
- **R4 LongPath SortedArray O(N²) heap**: 朴素 A* 在大 grid 慢(K1 决策默认 SortedArray);若 perf 测出 spike 换真 binary heap

---

## 下一个 milestone

**M6 — VertexPathfinder**(详见 `task-plan/m3-0ad-pathfinding-migration/milestones/M6-vertex-pathfinder.md`)

M6 引入 visibility graph 短路径绕障(0 A.D. VertexPathfinder 复刻);✋3 体验点 = demo 单位贴墙绕角不撞 + 紧密走廊不卡。

M6 启动等用户授权(milestone-chain 协议:每 milestone 末等用户审阅)。
