# Handoff — M3 Step B 完成 (codex Round 5 审查)

> **目标读者**: codex (架构审查) + 用户 (review 决策)
> **本文档不是给 autonomous runner 的**, runner 入口在 `Next-Steps.md` (Step C 时写)
>
> **依赖前序 handoff**:
> - [`Handoff-2026-05-03-0ad-migration-planning.md`](Handoff-2026-05-03-0ad-migration-planning.md) — Step A handoff + Round 1/2/3/4 反馈记录
> - Round 4 codex 已 APPROVE for Step B,本轮是 Step B 完成后送审

---

## 0. TL;DR

Step A (3 份核心文档) 在 codex Round 1-4 期间已修订到 APPROVE。本轮 (Step B) **一次性产出 12 份新文档 + 1 套 baseline 基础设施** (~6500 行 markdown),**等 codex Round 5 拍板**。

期望:
- 走全文档审查 (跟 Step A 类似 checklist 风格)
- 重点看 4 个最难 milestone (M4/M5/M6/M7) 的 sub-phase 拆分 + Determinism 严格性
- 重点看 interfaces.md / validation-strategy.md / risks-and-rollback.md 是否覆盖完整

如 R5 通过 → 用户进 Step C (`/next-feature-planner` 落地 Next-Steps + Acceptance + Progress + 启动 autonomous-feature-runner 跑 M0)。
如有 P1 → 我吸收修订,等 R6。

---

## 1. 本轮新增产出 (Step B)

### 1.1 文件树

```
.feature-dev/
├── Handoff-2026-05-03-0ad-migration-planning.md   ← Step A handoff (R1-R4 反馈记录已闭环)
├── Handoff-2026-05-03-step-b-codex-review.md      ← 本文档
└── task-plan/m3-0ad-pathfinding-migration/
    ├── README.md                          (Step A, R1-R4 修订完毕)
    ├── data-structures.md                 (Step A, R1-R3 修订完毕)
    ├── interfaces.md                      ← Step B 新 (~790 行)
    ├── validation-strategy.md             ← Step B 新 (~535 行)
    ├── risks-and-rollback.md              ← Step B 新 (~330 行)
    ├── milestones/
    │   ├── M0-footprint-split.md          (Step A, R1-R3 修订完毕)
    │   ├── M1-navcell-grid.md             ← Step B 新 (~590 行)
    │   ├── M2-obstruction-manager.md      ← Step B 新 (~1060 行)
    │   ├── M3-clearance.md                ← Step B 新 (~590 行)
    │   ├── M4-hierarchical.md             ← Step B 新 (~690 行, 拆 M4a/b/c)
    │   ├── M5-long-pathfinder.md          ← Step B 新 (~560 行)
    │   ├── M6-vertex-pathfinder.md        ← Step B 新 (~735 行, 拆 M6a/b/c, 7+2 细节全实现)
    │   ├── M7-unit-motion.md              ← Step B 新 (~500 行, 拆 M7a/b/c/d)
    │   └── M8-group-push.md               ← Step B 新 (~270 行)
    └── deferred/
        └── 0ad-formation-design.md        ← Step B 新 (~270 行, 下个 Epic handoff)
```

### 1.2 Baseline 基础设施 (Agent 后台并行落地)

```
addons/logic-game-framework/example/rts-auto-battle/
├── tools/
│   └── path_trace_v2.gd                          ← 24 字段 CSV writer
├── tests/battle/
│   ├── smoke_pathfinding_baseline.tscn
│   └── smoke_pathfinding_baseline.gd
└── tests/baselines/
    ├── 0ad-baseline-master.csv                   ← 882 KB / 6155 rows, byte-identical 跨 run
    ├── 0ad-baseline-master.replay.json           ← 34 KB (注: meta.battleId / meta.recordedAt 不 deterministic, diff 用 jq 'del(.meta)' 剥)
    └── README.md
```

**Agent 验证结果**:
- `smoke_pathfinding_baseline` PASS (900 ticks, 6155 trace rows, 111 replay events, exit code 0)
- `smoke_rts_auto_battle` 0 漂移 (ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00,完全对齐 CLAUDE.md 列的 baseline)
- baseline CSV 跑两次 byte-identical

### 1.3 0 A.D. 源码本地副本 (本轮顺手落地)

```
addons/logic-game-framework/example/rts-auto-battle/docs/references/
├── 0ad-source/                       ← sparse checkout source/simulation2/, 9.2 MB 工作树
│   ├── source/simulation2/helpers/   ← Pathfinding / HierarchicalPathfinder / LongPathfinder / VertexPathfinder / PathGoal / Grid (.h + .cpp)
│   └── source/simulation2/components/ ← CCmp* / ICmp* Footprint/Obstruction/Position/UnitMotion/Pathfinder
└── 0ad-source-setup.md               ← 拉取 / 升级 / 删除 指引
```

注: `addons/logic-game-framework/.gitignore` 屏蔽 `0ad-source/`(submodule 内不 commit, GPL 隔离 + 体积控制)。

### 1.4 发现的小问题 (codex 不必 review,记录给用户)

`tests/baselines/` 里 Godot 编辑器自动把 CSV 识别为 i18n translation 资源,产生 ~20 个 `*.translation` + `*.csv.import` 文件。下次 submodule commit 前需:
- 加 `*.translation` + `*.csv.import` 到 submodule `.gitignore`,或
- 把 CSV 改后缀(e.g. `.tsv` 用 tab 分隔,Godot 不会 auto-import)

不阻塞本轮审查。

---

## 2. 关键设计点 (codex 审查时需重点看)

### 2.1 interfaces.md

**新引入概念**:
- **Component 依赖图** (§0):分 4 层(顶层 facade / 中层三 pathfinder / 底层 grid+obstr_mgr / 数据 actor),严禁跨层引用
- **`RtsPathfinderFacade`** 是顶层入口 (§1):UnitMotion / Activity / Command 只调它,不直接打 hierarchical/long/vertex
- **`make_goal_reachable` 总 mutate goal** (§1.3):即使 true 也 canonicalize(R1 已闭环;此处再次 enforced 在 facade API contract)
- **同 tick 内可见性 contract** (§10.2):unit_A 先 tick 后 unit_B 看到的是 unit_A 移动**之后**的位置(synchronous + ordered)
- **RtsBattleGrid facade 退役计划** (§11):M0-M4 保留 / M5 移除
- **API 调用约定**(每个 component 都有 "不暴露" 列表 + "必须避免" 列表)

**疑虑给 codex 看** (R5 后状态):
- §1.3 facade.make_goal_reachable 中 *副作用 mutate 入参* 是否应该改成返回新 goal 不 mutate?(GDScript 风格 + 调用方可选保留原 goal) — 现在跟 0 A.D. 一致 mutate,但 GDScript RefCounted 引用语义可能引入 confusing(R5 没明确反对,本疑虑保留至 R6/R7)
- ~~§10.3 RtsWorld.tick 6 步顺序 + M8 加 push pass step 3 → 7 步,最后 EventProcessor.flush 是 step 7~~ — ✅ **R5 P2-1 已闭环** (见 §10.2):EventProcessor **没有** flush;真实 API 是 `GameWorld.event_collector.flush()`,顺序已修订成 7 步含 dirty 末端清

### 2.2 validation-strategy.md

**24 字段 trace schema** (§1.1):
- M0 阶段实填 14 字段 / 占位 10 字段(M4-M7 引入)
- 每 milestone 末新字段从占位变实填 = **预期变化**(不算漂移);已实填字段 byte diff = 漂移(stop runner)

**Replay bit-identical 协议** (§2):
- 现有 M2.3 末态保证 + 本 Epic 新增约束(详 data-structures §12)
- 跨 milestone 跑两次 byte-identical (`/tmp/run1.csv` vs `/tmp/run2.csv`)

**Performance baseline** (§3):
- ≤ 50% 增长接受 / 50-100% flag / ≥ 100%(2×) stop runner / ≥ 300% 重新审视设计

**5 个体验点** (§4) 各自独立详细操作 + 客观断言 + 失败回退

**疑虑给 codex 看**:
- §1.4 "不写入 trace 的情形":pure static actor (水晶塔) 不写 trace,这会让 baseline CSV 行数随 actor 类型分布变化 → 改 actor 配置 (e.g. ct 加 motion) 时 baseline 大变
- §3 perf baseline `wall_clock_ms` / `tick_p99_ms`:`wall_clock` 受 background process / 系统负载影响,跨 run 不稳定。是否应 dump 更多统计 (mean / p50 / p99 / max) 而非单 wall_clock?

### 2.3 risks-and-rollback.md

**3 类风险等级**:
- 🔴 P0:replay 漂 / 14 项 smoke 数字漂(M5/M7 最危险)
- 🟡 P1:perf ≥ 50% / baseline CSV 预期外字段变化
- 🟢 P2:trace 新字段从占位变实填 / 体验点视觉差异

**7 条 stop runner 触发条件** (§3) — 触发即停下问用户,不 autonomous 继续

**Per-milestone rollback ID** (§2):每 milestone 末记录 LGF submodule sha + 主仓 bump pointer 作为回退点

**疑虑给 codex 看**:
- §2 "M5 Rollback 特殊回退" 提到 RtsBattleGrid + GridPathfinding 删除是 destructive,回退要 git restore + 重新 wire — 这套 destructive milestone 跨 ≥3 个 (M1/M5/M7),回退操作复杂。是否应该:
  - (A) 这些 destructive milestone 多分一层"软删"(标 deprecated 不删,M9+ 才真删)
  - (B) 保持当前(每 milestone 末干净删除,接受回退复杂)— 我的当前选择

### 2.4 Milestone 拆分 (M1-M8)

各 milestone 套 M0 模板结构 (8 节: 目标 / Scope / 子任务 / AC / 决策 / 进度 / 风险 / 来源)。重点变化:

| Milestone | 拆分 | 总周数 (codex R1 拍板) | 关键风险 |
|---|---|---|---|
| M0 | 单段 | 1 周 | F1 ZERO offset 看不出视觉差异(M0 已修订,接受 + smoke 客观验) |
| M1 | 单段 | 1.5 周 | 删 RtsCell 类导致 deep callers 漏改 |
| M2 | 单段 | 1.5 周 | OBB-vs-OBB SAT 实现 bug |
| M3 | 单段 | 1 周 | brute-force inflate 多 building 时 perf 炸 |
| **M4** | **a/b/c** | **3 周** | 增量 update 合并/分裂 region 错算 |
| M5 | 单段 | 2-3 周 | A* tie-break 5 元组未严格遵守 → replay 漂 |
| **M6** | **a/b/c** | **4-5 周 (最难)** | 7+2 细节漏一个就炸;M6a 必须先做 prototype |
| **M7** | **a/b/c/d** | **4-5 周** | Tick 顺序错 → 同 tick unit_B 看错 unit_A 位置 |
| M8 | 单段 | 1.5 周 | push pass 力度过大 → 单位被弹离 path |

**疑虑给 codex 看**:
- M4 拆 a/b/c 是否合理?M4c (dirty 增量) 是否真的需要做 — 100 unit / 16 buildings 规模 full recompute (M4a) 应该 ≤ 30ms,M4c 可能 over-engineering?
- M6 拆 a/b/c 是否合理?M6a 用独立 prototype scene 验算法,**真的能减少 production VertexPathfinder 集成时风险**吗?或者反而引入"prototype vs production 漂移"新风险(R6 有提)?
- M7 拆 a/b/c/d:M7a (path storage) + M7b (lifecycle) 跨度大,是否应该合 M7ab?

---

## 3. Determinism Contract Coverage (codex Round 1 P1 #4 后续)

每个 milestone 文档都引用 [data-structures §12](task-plan/m3-0ad-pathfinding-migration/data-structures.md) 7 子节。**Step B 新文档遵守程度自评**:

| 子节 | 应用 milestone | 落实位置 |
|---|---|---|
| §12.1 LongPath A* | M5 | M5.2 `_astar` 5 元组 heap key |
| §12.2 Hierarchical | M4 | M4a.3 `_build_chunk` BFS 起点 (lj, li) 字典序 / `_compute_global_regions` 起点字典序 |
| §12.3 ShortPath VertexPath | M6 | M6a.3 vertex 候选生成 (按 obstruction.tag, corner_index) / A* 5 元组 (含 vertex_x_int = `int(round(x*10))`) |
| §12.4 ObstructionManager | M2 | M2.2 `query_circle` 末尾 `result.sort()` (按 tag 升序) |
| §12.5 UnitMotion tick 顺序 | M7 | M7c.2 `RtsWorld.tick` step 2 按 **`(kind, spawn_seq)` 数值复合 key**(R5 P1 #1 修订后,不再走 `actor.get_id()` 字典序)|
| §12.6 同 tick command | 全 Epic | 现有 RtsPlayerCommandQueue insertion order 保留 (M0-M8 不动) |
| §12.7 浮点数值处理 | M5/M6/M7 | A* PathCost 整数化 / vertex_x_int 整数化 / position 比较 epsilon=0.001 |

**疑虑给 codex 看** (R5 后状态):
- ~~§12.5 actor.get_id() 字典序 vs `IdGenerator` 单调递增~~ — ✅ **R5 P1-1 已闭环** (见 §10.2):codex R5 验证此问题在 ≥ 10 unit (不是 ≥ 100) 就漂(`Character_10 < Character_2`,因为 `'1' < '2'`);已采用 **`(kind, spawn_seq)` 数值复合 key** 解法,每 actor 加 `spawn_seq: int` 字段,5 文件同步
  - 或者:ID 序列内 spawn 100+ unit 是否实际发生?100 unit cap 下不会,但若 stretch 到 ≥ 100 unit / `Worker_*` 等 spawn 多次... → **应在 M7 实施前先验证现有 actor.get_id 排序在 ≥ 100 unit 时不漂**

### Step B 引入的新 Determinism 关注点 (R5 看一下)

- M2 spatial_index `query_circle` `result.sort()` 是稳定 sort(int)?GDScript Array.sort() 是 quick sort,稳定性?— 应该不重要因为 sort key 是 int 唯一(tag),没有 tie,所以 quick sort 稳定也不稳定结果一样
- M4a.4 `_add_undirected_edge` 双向加 edge 后排序 (`lo_arr.sort()` / `hi_arr.sort()`) — 同上
- M5 `_pack_cell` 用 `x * 65536 + y`(16-bit each)— 1024×1024 grid 范围内 OK,但 grid > 65536 时会 collision。本 Epic 只 1024² 不会;但若未来扩 16K² grid → bug。是否应该用更宽 packing?

---

## 4. 给 codex 的审查 checklist

请按以下 checklist 审查 Step B 12 个新文档:

### 4.1 interfaces.md

- [ ] §0 Component 依赖图 4 层划分是否合理? 严禁跨层引用是否实际可执行?
- [ ] §1.3 `make_goal_reachable` mutate 入参语义是否最佳? 还是改返回新 goal 更 GDScript-friendly?
- [ ] §10.2 同 tick 内可见性 contract 是否完整? unit_A 后 unit_B 看到 unit_A 新位置 — 跟 RtsActivity / EventProcessor 集成有冲突吗?
- [ ] §10.3 RtsWorld.tick 6+1 步顺序合理? push pass 在 step 3 (motion 后, activity 前) 是否对?
- [ ] §11 RtsBattleGrid facade 退役 在 M5 是否过早? 还是应该 M7+ 才删?
- [ ] §12 字段对照索引完整?

### 4.2 validation-strategy.md

- [ ] §1.1 24 字段 trace schema 是否够用? 还有 0 A.D. 关键状态没列?
- [ ] §1.2 占位策略是否合理? 新字段从占位变实填的接受规则清晰?
- [ ] §2 Replay bit-identical 跨 milestone 跑两次的协议是否够 robust?
- [ ] §3 Perf baseline 50% / 100% / 300% 阈值是否合理? wall_clock 跨 run 稳定性?
- [ ] §4 5 个体验点的客观断言是否够? 主观判断回退到自证?
- [ ] §6 每 milestone checklist 模板是否覆盖完整?
- [ ] §7 调试基础设施 (path_overlay / OOSLog) 是否够?

### 4.3 risks-and-rollback.md

- [ ] §1 跨 milestone 风险类别 (P0/P1/P2) 划分是否合理?
- [ ] §2 Per-milestone rollback ID 协议 (LGF submodule sha + 主仓 bump pointer) 是否实际可执行?
- [ ] §3 Stop Runner 7 条触发条件是否够? 是否漏什么?
- [ ] §4 R-EPIC-1 ~ R-EPIC-9 跟 Step A README §8 是否一致?
- [ ] §5 应急 Rollback 速查表 是否覆盖常见失败场景?

### 4.4 Milestone 文档 M1-M8

每个 milestone 都套 M0 模板,审查重点:

- [ ] **M1**: RtsCell 删除 vs deprecate stub (G1) 是否对? RtsBattleGrid facade 改造是否正确?
- [ ] **M2**: ObstructionManager API 是否完整? OBB-vs-OBB SAT 算法 (M2.3 _obb_obb_overlap_sat) 实现概要够 detailed 吗?
- [ ] **M3**: brute-force inflate 算法 (I1) 是否合理? per-class 独立 rasterize 协议?
- [ ] **M4 (拆 a/b/c)**: M4a 全图 recompute / M4b canonicalize / M4c dirty 增量 — 拆分是否合理? 每 sub-phase 1 周是否真够?
  - 特别看 M4c 是否 over-engineering (100 unit / 16 building 规模)
- [ ] **M5**: A* heap 用 SortedArray (K1) 是否会 perf 不够? `_pack_cell` 16-bit (K2) 是否 limit?
- [ ] **M6 (拆 a/b/c, 最难)**: 7+2 细节是否全实现? 是否漏几何边界 case?
  - M6a prototype scene 是否真减少风险?
- [ ] **M7 (拆 a/b/c/d)**: a/b 是否应合并? Activity 集成 (M7d) 涵盖 attack/gather/build/spawn/die 是否完整?
- [ ] **M8**: push_factor = 0.5 (N1) 是否合理? 多单位行为 tune 是否够 polish?

### 4.5 deferred/0ad-formation-design.md

- [ ] handoff 是否够 self-contained, 让下个 Epic 工程师能 cold-start?
- [ ] M3 Epic 给 Formation 留的接口 (MoveRequest.OFFSET / control_group) 是否真够用?

### 4.6 总体审查角度

- [ ] 12 个 Step B 文档之间的引用是否一致 (没有 dangling link / 字段名漂移)?
- [ ] data-structures §12 Determinism contract 在每个 milestone 的应用是否到位?
- [ ] **跨 milestone 字段命名**:`obstruction_tag` / `obstruction_shape` / `motion._move_request` 等命名是否在 Step A 文档 + Step B 文档之间一致?
- [ ] **跨 milestone 时序假设**:M4c dirty 触发 → M3 inflate / M5 LongPath / M6 VertexPath 都接 facade.tick 内 update — 是否有竞争?
- [ ] **GDScript 实现选型**:有没有"我以为 GDScript 这样行,实际不行"的隐藏 bug? (e.g. PackedInt32Array 序列化 / Dictionary 迭代序 / RefCounted instance compare)
- [ ] **最难 milestone (M6) 是否仍偏乐观**? M6 拆 4-5 周 (codex R1 已上调),是否仍可能 explosively 慢?
- [ ] **Determinism contract 是否漏了**? §3 提到的"actor.get_id 字典序在 ≥ 100 unit 时漂"是个具体 case

### 4.7 codex 反馈格式希望

跟 R1-R3 一致:
- 每 section ✅ / ⚠️ / ❌ + 具体说明
- 总体角度问题逐条回答
- 总体结论: APPROVE / REQUEST CHANGES / REJECT,带 1-3 个 must-fix(如有)

如发现真实 0 A.D. 实现跟我们文档描述不符,引用 0 A.D. 源码具体行号(本地副本在 `addons/.../docs/references/0ad-source/`)。

---

## 5. R5 期望

| R5 结论 | 后续动作 |
|---|---|
| **APPROVE** | 用户进 Step C(`/next-feature-planner` 接入,落地 Next-Steps + Acceptance + Progress)→ Step D(`/autonomous-feature-runner` 跑 M0)|
| **REQUEST CHANGES (P1)** | 我吸收 P1 修订,等 R6 |
| **REQUEST CHANGES (P2 only)** | 我看反馈决定吸收哪些(P1 全闭环, P2 看心情),然后进 Step C |
| **REJECT** | 跟 R1-R4 完全 APPROVE 风格不一致,出现这种情况说明 Step B 有根本性架构问题(预计概率低)→ 跟用户讨论是否重设计 Step B |

---

## 6. 关键文件直链

### 6.1 本批 Step B 主审查对象

```
.feature-dev/task-plan/m3-0ad-pathfinding-migration/
├── interfaces.md
├── validation-strategy.md
├── risks-and-rollback.md
├── milestones/M1-navcell-grid.md
├── milestones/M2-obstruction-manager.md
├── milestones/M3-clearance.md
├── milestones/M4-hierarchical.md
├── milestones/M5-long-pathfinder.md
├── milestones/M6-vertex-pathfinder.md
├── milestones/M7-unit-motion.md
├── milestones/M8-group-push.md
└── deferred/0ad-formation-design.md
```

### 6.2 上下文 / 已闭环文档 (审查时参考)

- [`.feature-dev/Handoff-2026-05-03-0ad-migration-planning.md`](Handoff-2026-05-03-0ad-migration-planning.md) (Step A handoff + R1-R4 闭环记录)
- `.feature-dev/task-plan/m3-0ad-pathfinding-migration/README.md` (Step A 总览)
- `.feature-dev/task-plan/m3-0ad-pathfinding-migration/data-structures.md` (Step A 数据结构 + R1-R3 修订)
- `.feature-dev/task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md` (Step A 范本)

### 6.3 0 A.D. 本地参考副本

```
addons/logic-game-framework/example/rts-auto-battle/docs/references/
├── 0ad-source/                        ← sparse checkout, 9.2 MB
└── 0ad-source-setup.md                ← 拉取指引
```

不进 git (.gitignore 屏蔽);供 codex 审查时引用 0 A.D. 源码具体行号用。

### 6.4 Baseline 基础设施 (Agent 已落地,smoke PASS)

```
addons/logic-game-framework/example/rts-auto-battle/
├── tools/path_trace_v2.gd
├── tests/battle/smoke_pathfinding_baseline.{tscn,gd}
└── tests/baselines/
    ├── 0ad-baseline-master.csv  (882 KB / 6155 rows)
    ├── 0ad-baseline-master.replay.json  (34 KB)
    └── README.md
```

---

## 7. 备注

- 本 handoff 不会触发 commit。Step B 全部新建,等 R5 拍板后一起 commit
- 不要让 codex 直接修改文档。codex 反馈 → 我读 → 我决定吸收哪些 → 我自己改
- **审查时间预算**: Step B 12 份文档约 245 KB markdown + Step A 联动审查,codex 仔细审应该 60-90 分钟。如果 codex 给过快回复 (< 20 分钟) 表明审得不够仔细,要求重审

---

## 8. 时间线 (Step A → Step B)

- 2026-05-03 上午: 用户报告 Bug,Claude 写参考文档
- 2026-05-03 下午: 8+ 轮架构讨论 + 4 份 docs/references/* 完成
- 2026-05-03 晚 (Step A): README + data-structures + M0 范本 + Handoff
- 2026-05-03 - 之后: codex Round 1-4 审查 + 修订 (4 P1 + 多项 P2 全闭环)
- 2026-05-03 - 当晚 (Step B): 12 份新文档 + baseline 基础设施 (Agent) + 0 A.D. 源码本地副本 一次性产出
- **下一步**: 用户提交本 handoff 给 codex Round 5 审查 → 等待

---

## 9. 跟前序 Handoff 的关系

| 文档 | 角色 | 状态 |
|---|---|---|
| `Handoff-2026-05-03-0ad-migration-planning.md` | Step A handoff + R1-R4 反馈记录 | 历史记录,继续保留 |
| **本文档** (`Handoff-2026-05-03-step-b-codex-review.md`) | **Step B handoff,送 R5 审查** | **当前 active** |
| (R5+ 后) | R5 反馈吸收记录 + Step C handoff | 待写 |

R5 之后若有反馈,在本文档加 §10 (R5 反馈吸收) — 跟前序 handoff §11.6 / §11.7 同风格,保持 self-contained。

---

## 10. Codex Round 5 反馈吸收记录 (2026-05-03)

### 10.1 总体结论 (codex Round 5)

**REQUEST CHANGES (3 P1 + 1 P2)** — Step B 文档整体完整,但 3 个 P1 直接影响后续实现正确性,必须修完才能进 Step C。修完送 R6,期望 APPROVE。

### 10.2 R5 P1 + P2 反馈吸收 (全部已改)

| R5 # | 问题 | 我的修改 | 落点 |
|---|---|---|---|
| **P1-1** | `actor.get_id()` 字典序在 ≥ 10 unit 时漂(`Character_10 < Character_2`,因 IdGenerator 真实输出 `"%s_%d"` 无 zero-pad)| 排序 key 改为 **`(kind: String, spawn_seq: int)` 数值复合 key**;每 actor 加 `spawn_seq: int` 字段(创建时从 `IdGenerator._counter` 取并冻结)| data-structures §12.5 重写 / interfaces.md §10.3 / M7.md M7c.2 + AC9 / M8.md tick 顺序 / validation-strategy.md §1.3 |
| **P1-2** | M3 rasterize 内 `clear_dirty()` 在 hierarchical update 前清 → M4c update 拿到空 dirty 集合 | `rasterize` 不再内部清 dirty;改为 caller 协议: rasterize 只读 / hierarchical update 只读 / **RtsWorld.tick step 7 末端统一 `grid.clear_dirty()`** | M3.md M3.1 + M3.3 / M4.md M4c.2 / interfaces.md §10.3 |
| **P1-3** | M4 `_compute_global_regions` 只从 `edges.keys()` 取起点 → 无跨 chunk edge 的 isolated passable region 不进 global 表 → `is_goal_reachable` 把合法 isolated region 误判不可达 | 起点改为**枚举 `chunks.regions_id` 全量 packed RegionID**(包括无 edge 的 isolated region),再用 edges 做连通扩展 | M4.md M4a.5 重写 + 新加 `smoke_hierarchical_isolated_region` |
| **P2-1** | `interfaces/M7/M8` 写 `RtsPlayerCommandQueue.flush()` / `EventProcessor.flush()`,真实 API 是 `apply_due(procedure, world, current_tick)` / `GameWorld.event_collector.flush()`(EventProcessor 没有 flush) | 全部替换为真实 API + 在 §10.3 加注释说明 | interfaces.md §10.3 / M7.md M7c.2 / M8.md tick 顺序 |

### 10.3 R5 sub-section 反馈吸收

| 项 | codex R5 意见 | 我的修改 |
|---|---|---|
| M4c over-engineering 降级 | M4a + M4b 默认必做,M4c 改 perf 触发项 | M4.md §1 加"R5 反馈降级"段;M4c 标注"可选 sub-phase, 仅 M4a perf > 30 ms / tick 触发" |
| M5 `_pack_cell` 16-bit 限制 | 加 `Log.assert_crash(width < 65536 && height < 65536)` 即可,不阻塞 | M5.md M5.2 `_init` 加 assert |
| M6 prototype 退役 | M6c 末必须显式删除 prototype-only 简化实现,避免双实现漂移 | M6.md M6c 段标题加"+ Prototype 退役";R6 风险加强调"M6c 末删除 `proto_vertex_obb.tscn` + grep 整 RtsVertexPathfinder 无 prototype-only 路径" |
| validation perf 字段 | 保留 `tick_avg/p50/p99/max` 主指标;`wall_clock_ms` 降辅助 | validation-strategy.md §3.1 重排表格,主辅分级 |
| risks-and-rollback 新 stop-runner 条件 | 加"M4 dirty lifecycle 违反" + "actor sort 用字典序" 两条 | risks.md §3 加条件 8 + 9 |
| trace 排序跟新 numeric tick key 同步 | M0-M6 走 actor registry insertion 序 / M7+ 走 (kind, spawn_seq) | validation-strategy.md §1.3 显式分阶段说明 |
| M7a/b 拆分 | 可保留(R5 没强制合并)| 保留 M7a/b/c/d 不改 |

### 10.4 R5 仍待 R6 看的点

- [x] data-structures §12.5 numeric tick key 协议是否覆盖完整(spawn_seq 字段时机 / kind 名固化 / 跨 milestone 兼容)
- [x] M3 / M4 dirty snapshot 协议:rasterize / update / clear 三段 invariant 是否清晰
- [x] M4 isolated region BFS 起点全量枚举,是否还漏其他 case(e.g. impassable navcell 的 GlobalRegionID = 0 是否正确)
- [x] M6 prototype 退役检查是否够(grep + smoke 双重确认)
- [ ] **Step B 实施时**: M0 implementation runbook 必须 grep `tests/**/*.gd` 找 diagnostics/smoke 里 `create_*` 后直调 `get_footprint_cells()` 路径(前 handoff §11.6.4 已记录,本轮再次提醒)

### 10.5 R6 期望

- codex 看 §10.2 4 项 + §10.3 7 项修订到位
- 如 R6 APPROVE → 进 Step C(`/next-feature-planner` 接入)
- 如 R6 仍 P1 → 继续修;P2 only 视情况吸收

---

## 11. Codex Round 6 反馈吸收记录 (2026-05-03)

### 11.1 总体结论 (codex Round 6)

**REQUEST CHANGES (1 P1 + 2 P2)** — R5 三项主体方案修对了,但有 1 个**活跃 contract 残留**(interfaces.md §6.3 RtsUnitMotion 调用约定段没同步改),以及 2 个**陈述跟新协议不一致**的 P2(Handoff 旧疑虑 + validation 验收规则首句)。会误导 Step C/M7 实施者按旧 contract 实现重新引入 R5 P1-1。

修完后 **APPROVE for Step C**。

### 11.2 R6 反馈吸收 (全部已改)

| R6 # | 问题 | 我的修改 | 落点 |
|---|---|---|---|
| **P1** | `interfaces.md §6.3 RtsUnitMotion 调用约定` 仍写 "顺序按 actor.get_id() 字典序" — 这是活跃 contract,不是历史引用,M7 实施者会按这里写旧排序 | 改为 "顺序按 **`(kind: String, spawn_seq: int)` 数值复合 key**(R5 P1 #1 修订)";加 IdGenerator 真实输出反例说明 | interfaces.md §6.3 第 291 行 |
| **P2-1** | Handoff §2.1 仍把 `EventProcessor.flush` 当待审疑虑 / §3 仍把 `actor.get_id 字典序` 当待审疑虑 — 误导 R6+ 入口读者 | 两处疑虑加 `~~strikethrough~~ + ✅ R5 已闭环 (见 §10.2)` 标记 | Handoff §2.1 / §3 疑虑列表 |
| **P2-2** | `validation-strategy.md §3.2 验收规则` 首句仍以 `wall_clock_ms ≤ 50%` 为主,跟 §3.1 把 wall_clock 降辅助矛盾 | 主验收改为 `tick_p99/tick_max/pathfinder_total/obstruction_total`,wall_clock 显式标"仅作辅助参考";绝对阈值 (`p99 ≤ 30 ms` / `max ≤ 60 ms`)与相对阈值 (`总开销 ≤ +50%`)分开列;stop runner 触发条件按主指标 | validation-strategy.md §3.2 重写 |

### 11.3 R6 codex 已通过的部分(明确确认)

- ✅ data-structures §12.5 / M7 / M8 numeric sort 主方案闭环
- ✅ M3/M4 dirty lifecycle:rasterize 不内部 clear,末端统一清,主体闭环
- ✅ M4 isolated region 全量 `regions_id` 枚举,方向通过
- ✅ `apply_due(...)` / `GameWorld.event_collector.flush()` 在主要 tick 顺序文档已替换

### 11.4 R7 期望

- codex 看 §11.2 三项修订到位 → APPROVE for Step C
- 若 R7 仍 P1 → 继续修;P2 only 视情况吸收
- APPROVE 后:用户进 Step C(`/next-feature-planner` 接入,落地 Next-Steps + Acceptance + Progress + 启动 autonomous-feature-runner 跑 M0)

---

## 12. Codex Round 7 反馈吸收记录 (2026-05-03)

### 12.1 总体结论 (codex Round 7)

**REQUEST CHANGES,只剩 1 P1 残留** — `interfaces.md §10.2` "同 tick 内可见性" 段最后一行 "解法: §12.5 显式按 `actor.get_id()` 字典序排序" 仍是活跃 contract 总览的 contract,Step C/M7 实施者从 §10.2 读到旧解法会回到字典序。

修完 → APPROVE for Step C。

### 12.2 R7 反馈吸收 (已改)

| R7 # | 问题 | 我的修改 | 落点 |
|---|---|---|---|
| **P1** | `interfaces.md §10.2` 最后一行 "解法: §12.5 显式按 `actor.get_id()` 字典序排序" 是活跃 contract 总览,不是历史引用 | 改为 "解法: §12.5 显式按 **`(kind: String, spawn_seq: int)` 数值复合 key** 排序(R5 P1 #1 修订;不用 `actor.get_id()` 字典序,因 IdGenerator 真实输出 `Character_10 < Character_2` 漂移)" | interfaces.md §10.2 第 392 行 |

### 12.3 R7 已通过部分(明确确认)

- ✅ `interfaces.md §6.3` (RtsUnitMotion 调用约定) 已改 `(kind, spawn_seq)`
- ✅ `validation-strategy.md §3.2` 已主验收改 `tick_p99/tick_max/pathfinder_total/obstruction_total`,`wall_clock` 降辅助
- ✅ `EventProcessor.flush` / `RtsPlayerCommandQueue.flush` 在活跃 tick 顺序文档已替换为真实 API
- ✅ Handoff 旧疑虑标 R5/R6 闭环

### 12.4 R8 期望(若需)

- codex 看 §12.2 P1 修订到位 → **APPROVE for Step C**
- APPROVE 后用户进 Step C:
  1. `/next-feature-planner` 接入
  2. 落地 `.feature-dev/Next-Steps.md` + `Acceptance.md` + `Progress.md`
  3. 启动 `/autonomous-feature-runner` 跑 M0
  4. 期间停在 5 个 ✋N 体验点等用户反馈
