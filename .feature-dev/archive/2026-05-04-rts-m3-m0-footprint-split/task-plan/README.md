# M3 — RTS Pathfinding 全面迁移到 0 A.D. 方案

> Status: 🟡 **planning** — 完整规划文档撰写中,等待 codex 审查 + 用户拍板后进 `/autonomous-feature-runner`
> Sub-feature: 第三个 RTS 大版本 milestone (前两个: M1 重构, M2 单人可玩 demo)
> Scope: 寻路 / 障碍 / 移动 / 单兵避让 全栈替换为 0 A.D. 风格 (long+short pathfinder + ObstructionManager + Hierarchical 可达性 + Clearance 外扩 + Footprint/Obstruction 拆分)
> 不含: Formation 实现 (有独立 design 文档作为 handoff,留给 M4 Epic)

---

## 0. 背景与目的

### 0.1 决策来源

2026-05-03 用户在排查 `demo_rts_frontend` 单位"在建筑前徘徊 / 编队穿建筑 / 编队移动异常"症状时,看了 0 A.D. 视频,认为其寻路 / 地图 / 建筑 / 编队 / 资源采集等基础设施"完美符合预期",决定 **将我们 RTS 项目的寻路基础设施全面对标 0 A.D.**。

期间产出 5 份参考文档,落在 `addons/logic-game-framework/example/rts-auto-battle/docs/references/`:
- `0ad-architecture-overview.md` — 整体引擎架构 (ECS + lockstep + JS/C++ 双层)
- `0ad-pathfinding.md` — 寻路三层综述
- `0ad-data-flow.md` — 地图数据结构 + agent 状态 + 完整数据流
- `0ad-learnings.md` — Q1-Q6 阅读笔记 (含核心决策固化)
- `0ad-vs-inkmon-rts.md` — 与 inkmon RTS 当前实现的差距对比

### 0.2 范围决策

经多轮 (8+) 讨论收敛到 **"原样复刻"策略**:

> 0 A.D. 是 23 年沉淀的开源工业 RTS,我们对它的理解只覆盖了几页源码;凡是当前看不出价值但成熟设计中存在的拆分,**默认假设它有理由我没看到**,先复刻,迁移到 Godot 跑起来再决定是否合并简化。
>
> 工程铁律: 简化 (合并组件) 是单向操作,**拆分** (合了再拆) 是地狱。默认选 "易拆难合" 的方向 = 先复刻。

具体范围 (按用户意图固化):

| 0 A.D. 子系统 | 本 Epic 范围 | 备注 |
|---|---|---|
| Pathfinder 三层 (Hierarchical + Long-range A* + Short-range Vertex) | ✅ 全做 | 核心 |
| ObstructionManager (静态/动态 shape 数据库) | ✅ 全做 | 核心 |
| Clearance + 外扩 (per-class passability grid) | ✅ 做 | M3 |
| Multi-class Passability (16-bit 位掩码) | ✅ 做 | M1,但本 Epic 只用 GROUND / AIR 两 class,留接口 |
| Footprint vs Obstruction 拆分 (建筑) | ✅ 做 | M0,顺手修 Bug 1 |
| UnitMotion 重写 (long+short 双轨 + MoveRequest + ticket) | ✅ 做 | M7 |
| Group filter + push pass (单兵避让) | ✅ 做 | M8 |
| **Formation controller (虚拟 entity + slot)** | ❌ **不做** | 写 design handoff,M4 Epic 实现 |
| Stance 完整版 (UnitAI 7 种 stance) | ❌ 不做 | 当前 RtsActivity + 默认行为够用 |
| Vision / LOS / Fogging | ❌ 不做 | 游戏机制不需要 |
| Territory / Trader / Tech tree | ❌ 不做 | 游戏机制不需要 |
| Fixed-point 数值 | ❌ 不做 | Godot WASM 浮点已实测 deterministic |
| C++/JS 双层 | ❌ 不做 | GDScript 单层够用 |

### 0.3 关键技术决策

| # | 决策 | 类型 | 来源 |
|---|---|---|---|
| D1 | **混合避让方案**: 0 A.D. short path 重算 + 保留**本项目** sep force 微调 | ⚠️ **有意偏离 0 A.D.** (不是原样复刻) | 我们密度低 (≤100 单位) / 不需跨平台;codex 讨论 |
| D2 | **复刻 4 个独立 component** (Position / Obstruction / Footprint / Motion) | ✅ 原样复刻 | 默认易拆难合;Motion.clearance ≡ Obstruction.radius (仿 CCmpObstruction.cpp:228) |
| D3 | **保留 LGF 框架** (Actor / AbilitySet / AttributeSet / Ability / Action / Resolver / EventProcessor / Replay) | ➕ 项目特定 (LGF 跟寻路正交) | 这一层跟寻路解耦,不动 |
| D4 | **不修改 LGF submodule core/ stdlib/** | ➕ 项目硬约束 | 所有新代码在 `example/rts-auto-battle/` 内 |
| D5 | **保持 replay bit-identical** | ✅ 与 0 A.D. lockstep 一致 | 每个 milestone 必须 PASS `smoke_replay_bit_identical` |
| D6 | **LongPath 用 GDScript 朴素 A*,不做 JPS + JumpPointCache** | ⚠️ **有意简化 0 A.D.** (0 A.D. LongPathfinder 实际是 JPS+JumpPointCache) | 我们规模小 (≤100 单位 / 1024×1024 grid),JPS 工程量大收益小;codex 标记为有意简化 |
| D7 | **Vertex pathfinder 复刻 0 A.D. 完整 visibility graph** | ✅ 原样复刻 | 这是任意角度路径的关键,简化版做不出来 |
| D8 | **Unit shape 是圆,Building shape 是 OBB** | ✅ 原样复刻 | 完全照搬 0 A.D. |
| D9 | **`group_filter` 在 M6/M7 已是 API 输入,M8 只是行为 polish** | ✅ 原样复刻 (codex 提示) | group filter 是 ShortPath / Motion obstruction filter 的输入,M8 仅打开 + 调多单位行为 |
| D10 | **RegionID 用 packed int64 (24+24+16 bit),不能用 RefCounted** | ➕ Godot 4 适配 (codex P1 #1) | GDScript Dictionary 用 RefCounted 当 key 走实例身份 — codex 本地验证 |
| D11 | **Determinism 总排序 contract 显式定义** (见 data-structures §12) | ➕ 比 0 A.D. 更严格 (codex P1 #4) | 现有 bit-identical 不是单靠 entity_id parity,新算法所有 tie-break 路径必须有显式 deterministic key |

---

## 1. 里程碑地图 (M0 → M8)

```
M0  Footprint 拆分 + 修 Bug 1                      ← 独立收益,后面失败也保留
    ↓                                              [✋ 体验点 1: 单位绕建筑视觉对齐]
M1  Navcell Grid + 16-bit Passability Class        ← 数据层重构,寻路算法不变
    ↓
M2  ObstructionManager (shape 数据库)              ← 中间层,Rasterize 替换直接刷 grid
    ↓
M3  Clearance + 外扩                                ← 第一个解锁能力
    ↓
M4  HierarchicalPathfinder (可达性)                ← 解决"建筑前徘徊"症状
    ↓                                              [✋ 体验点 2: 玩家点不可达点单位智能寻路]
M5  LongPathfinder 重写 (在新 grid 上跑 A*)        ← 替换核心算法,危险时刻
    ↓
M6  VertexPathfinder (short-range visibility)      ← 最难一层,任意角度路径
    │   group_filter API 此 M 已是输入 (D9)        ← 不是 M8 才引入
    ↓                                              [✋ 体验点 3: 转角自然贴边,不再 zig-zag]
M7  UnitMotion 重写 (long+short 双轨整合)          ← agent 数据结构对齐 0 A.D.
    │   group_filter 也是此 M obstruction flag sync 输入
    ↓                                              [✋ 体验点 4: 整体寻路换装]
M8  push pass + 多单位行为 polish                  ← 不引入 group_filter API (那在 M6/M7), 仅打开 + tune
                                                   [✋ 体验点 5: 同队不互相绕,移动整齐]

[deferred → M4 Epic]
M9  Formation controller (虚拟 entity + slot)      ← 仅写 design handoff,不实现
```

---

## 2. 5 个用户体验里程碑 (停下来给你玩 demo_rts_frontend)

每个体验点都**暂停 autonomous runner**,等你跑 demo 反馈 → 调优 → 才进下一个 M。

| # | 完成 M | 你玩什么 | 你应该感觉 | 失败回退 |
|---|---|---|---|---|
| ✋1 | M0 | 玩 placement mode + 看 ghost / 看放下后 cells | **ghost 占地高亮 = 放下后 obstruction cells = 单位绕走 cells** 三者精确一致 (客观可测;sprite 锚点不变,**完整"贴墙绕角不穿 sprite"等 M6**) | M0 是独立收益,即便后续放弃也保留这个修复 |
| ✋2 | M4 | 故意点击建筑内部 / 不可达点 | 单位走到最近可达点,不再傻站着 / 在建筑前徘徊 | 回到 M3 stable,Hierarchical 关掉走 fallback |
| ✋3 | M6 | 单位绕单一矩形建筑 | 路径转角自然贴边,不再 zig-zag (这是真正的"Bug 1 完整修复"体感点) | 回到 M5 stable,short pathfinder 用退化版 (cell 中心连线) |
| ✋4 | M7 | 完整 demo_rts_frontend 一局 | 整体寻路"换了一套",注意视觉/行为回归 | 回到 M6 stable,UnitMotion 仍用旧 RtsNavAgent,但能 verify long+short pathfinder 工作 |
| ✋5 | M8 | 多单位同时选中移动 | 同队不互相绕,移动整齐 | 回到 M7 stable,group filter 关掉,sep force 兜底 |

> **codex 反馈** (2026-05-03): 体验点 1 之前的描述"Bug 1 消失"过度承诺。M0 自身 (`F4` sprite 锚点保留 = `position_2d`,32 px grid 粒度) 不能完整消除"贴墙绕角穿 sprite"。M0 真正交付的是"ghost / placed / path 三者 cells 精确一致"的客观可测改进,完整视觉对齐留 M6。

---

## 3. 整体 Acceptance (Epic 完成的硬条件)

| AC | 验收 | 验证方式 |
|---|---|---|
| **AC-EPIC-1** | 所有现有 smoke 全 PASS (M2.3 末态 baseline) | M0-M8 每 milestone 末跑一次 |
| **AC-EPIC-2** | replay bit-identical (seed=42 frames=9 events=20 deep-equal) | M0-M8 每 milestone 末跑 |
| **AC-EPIC-3** | demo_rts_frontend 视觉无 Bug 1 (单位绕建筑视觉对齐) | M0 完成时人工 + diff 录屏 |
| **AC-EPIC-4** | 玩家点不可达点 → 单位走到最近可达 navcell (不再死循环) | M4 新 smoke + 体验点 2 |
| **AC-EPIC-5** | 单位绕单一矩形建筑路径任意角度 (不 zig-zag) | M6 新 smoke + 体验点 3 |
| **AC-EPIC-6** | 多单位同时选中移动,同队不互相绕 (queue 不散) | M8 新 smoke + 体验点 5 |
| **AC-EPIC-7** | 性能 baseline 对比: 主要 smoke 寻路开销不增超 50% (允许慢一倍内) | 每 milestone 末 perf trace |
| **AC-EPIC-8** | 5 份参考文档 + Formation handoff 文档 全部 commit | M8 commit 时 |
| **AC-EPIC-9** | M0-M8 所有 milestone 文档 + Progress + Next-Steps 完整 | runner 自动维护 |

---

## 4. Trace / 验证基础设施 (在 M0 之前先准备)

| 工具 | 干什么 | 用在哪 |
|---|---|---|
| **`tools/path_trace_v2.gd`** | 标准化 trace utility,所有 M 共用同一格式输出 CSV (schema 见 `validation-strategy.md`) | 每 milestone 验收 |
| **`smoke_pathfinding_baseline.tscn`** | 跑当前 master 一局,生成 baseline replay + path CSV,后续 M 用它做 bit-identical 对比 | M0 启动前**必须**先跑生成基线 |
| **`smoke_visual_regression.tscn`** | 简化版 demo_rts_frontend,固定 30s 场景,dump 单位最终位置 + path 长度 | 每 milestone 验收 |
| **`/tmp/0ad-migration-perf-baseline.csv`** | 现有 master 在所有 smoke 的 wall-clock + tick-count + memory | 每 milestone 验收 |
| **录屏 demo_rts_frontend 30s** | 视觉基线 (M0 / M5 / M7 / M8 各对比一次) | 体验点 |
| **`tools/path_overlay.gd`** | Godot 编辑器里 F6 跑能直接看到 long/short path 画在地图上 | 关键 frontend smoke |

详细 trace schema + 验证流程见 [`validation-strategy.md`](validation-strategy.md) (Step B 产出)。

---

## 5. 文档结构

```
.feature-dev/task-plan/m3-0ad-pathfinding-migration/
├── README.md                      ← 本文档 (Epic 总览)
├── data-structures.md             ← 所有新数据结构 + 字段 + 0 A.D. 对照
├── interfaces.md                  ← 所有 component 公开 API (Step B)
├── milestones/
│   ├── M0-footprint-split.md      ← 完整范本 (Step A 已完成)
│   ├── M1-navcell-grid.md         ← Step B 批量产出
│   ├── M2-obstruction-manager.md
│   ├── M3-clearance.md
│   ├── M4-hierarchical.md
│   ├── M5-long-pathfinder.md
│   ├── M6-vertex-pathfinder.md
│   ├── M7-unit-motion.md
│   └── M8-group-push.md
├── validation-strategy.md         ← trace schema + 体验点 + replay 基线 (Step B)
├── risks-and-rollback.md          ← 每 M 的回退点 + 已知风险 (Step B)
└── deferred/
    └── 0ad-formation-design.md    ← 下个 Epic (M4 Epic) 的 handoff (Step B)

addons/logic-game-framework/example/rts-auto-battle/docs/references/
├── 0ad-architecture-overview.md   ← 已有
├── 0ad-pathfinding.md             ← 已有
├── 0ad-data-flow.md               ← 已有
├── 0ad-learnings.md               ← 已有
└── 0ad-vs-inkmon-rts.md           ← 已有
```

---

## 6. 进度追踪

详细 phase 进度见 [`Progress.md`](../../Progress.md)。

### 6.1 当前状态 (2026-05-03)

- [x] 5 份参考文档完成
- [x] Bug 1 / Bug 2 / Bug 3 诊断完成 (见 `Handoff-2026-05-03-pathfinding-diag.md`)
- [x] 范围与策略决策完成 (D1-D8)
- [x] **Step A**: README + data-structures + M0 范本 (本文档所在)
- [ ] **Step B**: M1-M8 + interfaces + validation-strategy + risks-and-rollback + Formation handoff (本 Epic 计划文档剩余部分)
- [ ] **Step C**: `/next-feature-planner` 接入 + Next-Steps + Acceptance 落地
- [ ] **Step D**: `/autonomous-feature-runner` 跑 M0
- [ ] **... M0-M8 实施**

### 6.2 下一步动作

**用户拿这 3 份 Step A 文档 + Handoff 文档去给 codex 做架构审查**。
codex 审查通过 / 修改建议吸收后,我进 Step B,批量产出 M1-M8 + 配套文档。

---

## 7. 估算 (晚上 + 周末节奏)

**重要更新** (codex 反馈): 原估算 M4/M6/M7 偏乐观。codex 建议拆分以降低单 milestone 风险:

- **M4** 拆 3 个 sub-phase: M4a (full recompute) → M4b (`MakeGoalReachable` canonicalization) → M4c (dirty 增量更新)
- **M6** 拆 3 个 sub-phase: M6a (static OBB prototype) → M6b (virtual goal + domain + terrain edges) → M6c (dynamic unit + group filter)
- **M7** 拆 4 个 sub-phase: M7a (path storage) → M7b (lifecycle: ticket / FailedMovements 反馈) → M7c (movement + obstruction flag sync) → M7d (activity 集成)

每个 sub-phase 是独立 standalone smoke checkpoint,失败只回退到 sub-phase。

| Phase | 单位时间 | 备注 |
|---|---|---|
| Step A (本批文档) | 已完成 | 在用 max effort 一次到位 |
| Step B (M1-M8 批量文档) | ~5-7 天 | 批量产出 (M4/M6/M7 各拆 3-4 sub-phase, 工程量增加) |
| Step C (next-feature-planner 落地) | 0.5 天 | 走形式 |
| **M0** | 1 周 | 最简单 milestone |
| **M1** | 1.5 周 | 数据层重构,off-by-one 风险 |
| **M2** | 1.5 周 | shape 数据库,重构面广 |
| **M3** | 1 周 | 算法清晰 |
| **M4** | **3 周** (M4a 1w + M4b 1w + M4c 1w) | flood-fill / region 边界 / canonicalize / dirty update,每 sub-phase 1 周 |
| **M5** | 2-3 周 | 算法换装,replay 漂移要彻查 |
| **M6** | **4-5 周** (M6a 1.5w + M6b 1.5w + M6c 1.5w) | 最难一层,几何 + dynamic + group filter (group filter 是 M6 输入, D9) |
| **M7** | **4-5 周** (M7a 1w + M7b 1w + M7c 1.5w + M7d 1.5w) | agent 重写,影响所有 activity (group filter 也是 M7 输入) |
| **M8** | 1.5 周 | polish (group 行为优化, 不引入 group filter API) |
| **总计** | **~22-26 周全职等价 / 65-78 周用户节奏** (含 buffer; codex 反馈后从 17-19 周上调) |

---

## 8. 已知风险 / 残余风险 (Epic 启动前预判)

| # | 风险 | 缓解 |
|---|---|---|
| R1 | M5/M6/M7 时 replay bit-identical 漂移,定位耗时 | M0 启动前先生成 baseline replay;漂移立刻 stop runner,人工 OOSLog 风格定位 |
| R2 | M6 visibility graph 几何写错难调试 | M6 启动前先 prototype 一个独立 scene 跑通,再正式整合 |
| R3 | M7 时 RtsActivity (attack / gather / build) 受 motion 重写影响 | M7 把所有现有 activity 当作 acceptance 子项,逐个 verify |
| R4 | 我们对 0 A.D. 内部细节理解不全 (e.g. push pass 顺序 / m_FailedMovements 阈值原因) | 每个 milestone 启动时再过一遍对应 0 A.D. 源码;未知细节先用复刻值,事后调优 |
| R5 | 性能回归 (GDScript 实现位掩码 / 空间查询会比 C++ 慢 50-100×) | AC-EPIC-7 接受最多 2× 慢,超出再针对性优化;不预先 GDExtension 化 |
| R6 | UI 方面 (frontend) 跟 logic 重构同时改 → 互相干扰 | M0 是 frontend 唯一真正改动;后续 M 全部 logic-only,frontend 不动 |
| R7 | LGF submodule 边界违规 | 任何代码进 `example/rts-auto-battle/`;若发现需要改 core 立刻停下问用户 |
| R8 | 用户中途想加范围 (Formation / Vision / Stance) | 默认拒绝,记入 deferred,这次 Epic 不开 |

---

## 9. 决策日志

| 日期 | 决策 | 来源 |
|---|---|---|
| 2026-05-03 | 看 0 A.D. 视频后决定全面迁移寻路 | 用户主动提议 |
| 2026-05-03 | "原样复刻"策略,不提前简化 | Q5/Q6 讨论收敛 |
| 2026-05-03 | M9 Formation 推到下一个 Epic | 用户授权,文档先行 |
| 2026-05-03 | M0 优先级抬到第一 | 用户偏好"从数据结构开始" |
| 2026-05-03 | trace utility 标准化 + path 数据落 CSV | 用户要求"冒烟测试需要记录寻路路径" |
| 2026-05-03 | D1 混合避让方案 (0 A.D. short path + sep force 微调) | codex 讨论 + 用户授权 |

---

## 10. 引用

- 参考文档 (5 份): `addons/logic-game-framework/example/rts-auto-battle/docs/references/`
- 上一轮 handoff: `.feature-dev/Handoff-2026-05-03-pathfinding-diag.md`
- 0 A.D. 源码: https://github.com/0ad/0ad (master,已 archive,新仓 https://gitea.wildfiregames.com/0ad/0ad)
- 关键源码引用 (Step A 内出现的):
  - `source/simulation2/helpers/Pathfinding.h` (NavcellData / NAVCELL_SIZE)
  - `source/simulation2/helpers/Grid.h` (Grid<T>)
  - `source/simulation2/helpers/HierarchicalPathfinder.h` (RegionID / GlobalRegionID / Chunk)
  - `source/simulation2/helpers/PathGoal.h` (PathGoal 5 种 type)
  - `source/simulation2/components/ICmpPathfinder.h` (LongPathRequest / ShortPathRequest)
  - `source/simulation2/components/ICmpObstructionManager.h` (ObstructionSquare / EFlags)
  - `source/simulation2/components/CCmpObstruction.cpp` (m_Clearance 同步)
  - `source/simulation2/components/CCmpUnitMotion.h` (MoveRequest / Ticket / m_LongPath / m_ShortPath / m_FailedMovements)
