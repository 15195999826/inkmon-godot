# Handoff — 0 A.D. 寻路全面迁移 Epic 规划文档 Step A 完成 (2026-05-03)

> **目标读者**: codex (架构审查) + 用户 (review 决策)
> **本文档不是给 autonomous runner 的**, runner 入口在 `Next-Steps.md`

---

## 0. TL;DR

我用 max effort 写完了 0 A.D. 寻路迁移 Epic 的 **Step A 三份核心规划文档**:

1. `task-plan/m3-0ad-pathfinding-migration/README.md` (Epic 总览,~9 KB,9 节)
2. `task-plan/m3-0ad-pathfinding-migration/data-structures.md` (所有新数据结构 + 0 A.D. 字段对照,~15 KB,11 节)
3. `task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md` (M0 完整范本,作为 M1-M8 模板,~12 KB,8 节)

**期望 codex 做架构审查**,重点见本文档 §5。审查通过 / 修改建议吸收后,我进 Step B (批量产出 M1-M8 + interfaces + validation-strategy + risks-and-rollback + Formation handoff)。

---

## 1. 背景 (这次为什么会做这个 Epic)

### 1.1 起点

2026-05-03 用户在排查 `demo_rts_frontend` 单位"在建筑前徘徊 / 编队穿建筑 / 编队移动异常"症状。原本以为是 bug 修复,过程中:

- 让 Claude 写了 0 A.D. 寻路架构参考文档 (`docs/references/0ad-pathfinding.md` + `0ad-vs-inkmon-rts.md`)
- 跑诊断 smoke 实际定位:**3 个 bug** — Bug 1 (footprint 偏移 12-42 px) / Bug 2 (idle 单位被 sep 推飘) / Bug 3 (AutoTargetSystem 选中立 ResourceNode → 单位永久冻结)
- 用户看 0 A.D. 视频后判断:**"它的寻路、地图、建筑、编队、资源采集等等方案,完美符合我的预期"** → 决定全面对标重构,而不只是修当前 bug

### 1.2 决策路径 (8+ 轮讨论收敛)

讨论内容已落到 `docs/references/0ad-learnings.md` Q1-Q6,关键收敛点:

- **范围**: 寻路 / Obstruction / Motion / Footprint / 单兵避让 全栈替换为 0 A.D. 风格;Formation 推到下个 Epic
- **策略**: **原样复刻** — 不提前简化合并 (默认易拆难合)
- **避让方案**: 0 A.D. short path 重算 + 保留简化 sep force 微调 (混合方案)
- **里程碑**: 9 个 M (M0-M8),每 M 必须 standalone 跑通 + replay bit-identical + 加新 smoke
- **用户体验里程碑**: 5 个停下来给用户玩 demo_rts_frontend 的点 (✋1 = M0 / ✋2 = M4 / ✋3 = M6 / ✋4 = M7 / ✋5 = M8)

### 1.3 用户的明确要求

1. **冒烟测试需要记录寻路路径** → trace utility 标准化 schema (落 §M0.1)
2. **"在哪一个阶段我可以实际操作单位"** → 5 个体验点位置定好了
3. **Formation 文档先行,但实现推到下个 Epic**
4. **"从数据结构开始设计"** → M0 数据拆分 + data-structures.md 是 Step A 的 1/3 内容
5. **"你自己写,然后给我 handoff,然后我去让 codex 审查"** → 本文档

---

## 2. 产出清单 (Step A,本批)

### 2.1 文件树

```
.feature-dev/
├── Handoff-2026-05-03-0ad-migration-planning.md   ← 本文档
└── task-plan/
    └── m3-0ad-pathfinding-migration/
        ├── README.md                               ← Epic 总览
        ├── data-structures.md                      ← 所有新数据结构
        └── milestones/
            └── M0-footprint-split.md               ← M0 完整范本
```

### 2.2 文档间引用关系

```
README.md (Epic 总览)
    ├── 引用 docs/references/* (5 份已存在的参考文档)
    ├── 引用 data-structures.md (新数据结构定义)
    ├── 引用 milestones/M0-* (具体落地)
    └── 引用 archive/Handoff-2026-05-03-pathfinding-diag.md (上轮 bug 诊断)

data-structures.md (字段定义 + 0 A.D. 对照)
    ├── 引用 0 A.D. 源码具体行号
    └── 被所有 milestone 文档引用

M0-footprint-split.md (具体落地)
    ├── 引用 data-structures.md §2 §3
    ├── 引用 既有 RtsBuildingActor / RtsBuildings / RtsBuildingPlacement 行号
    └── 引用 M2.3 末态 baseline (smoke 数字)
```

### 2.3 还没写的 (Step B/C/D)

- `interfaces.md` (所有 component 公开 API,Step B)
- `validation-strategy.md` (trace schema 完整版 + 体验点流程,Step B)
- `risks-and-rollback.md` (每 M 回退点,Step B)
- `milestones/M1-navcell-grid.md` ... `M8-group-push.md` (Step B)
- `deferred/0ad-formation-design.md` (Step B,Formation handoff for 下个 Epic)
- `Next-Steps.md` + `Acceptance.md` + `Progress.md` (Step C,/next-feature-planner 接入)

---

## 3. 关键架构决策 (codex 审查时要看的)

### 3.1 范围决策 (D1-D8)

记录在 `README.md §0.3`:

| # | 决策 | 我的理由 |
|---|---|---|
| **D1** | 混合避让方案 (0 A.D. short path + sep force 微调) | 我们密度不高 (≤100 单位) / 不需跨平台,可同时享受两层好处 |
| **D2** | 复刻 4 个独立 component (Position / Obstruction / Footprint / Motion),不简化合并 | 默认易拆难合;成熟设计中我看不出价值的拆分,假设它有理由 |
| **D3** | 保留 LGF 框架 (Actor / AbilitySet / EventProcessor / Replay) | 跟寻路解耦,不动 |
| **D4** | 不修改 LGF submodule core/ stdlib/ | 项目硬约束 |
| **D5** | 保持 replay bit-identical | 每 milestone 必须 PASS smoke_replay_bit_identical |
| **D6** | LongPath 用 GDScript 朴素 A*,不做 JPS | 规模小 (≤100 单位 / 1024×1024 grid),JPS 工程量大收益小 |
| **D7** | Vertex pathfinder 复刻 0 A.D. 完整 visibility graph | 任意角度路径关键,简化版做不出来 |
| **D8** | Unit shape 是圆,Building shape 是 OBB | 完全照搬 0 A.D. |

### 3.2 数据结构选型 (data-structures.md §11 待确认 10 个 Q)

**这是 codex 审查最关键的部分**,我对这 10 个选择不完全自信,挑出来给 codex 拍板:

| # | 问题 | 我的当前选择 | 为什么不自信 |
|---|---|---|---|
| Q1 | clearance 单位用 px 还是 navcell? | px | 跟 0 A.D. 不同,文档对照时要换算 |
| Q2 | navcell size 用 32 px 还是 16 px? | 32 (跟现有 cell_size 一致) | 0 A.D. 是 1 m navcell 4 个一个 tile,我们没 tile 概念,32 是不是太粗? |
| Q3 | OBB 用半宽半高还是全宽全高? | 全宽全高 (跟现有 `footprint_size: Vector2i` 风格一致) | 跟 0 A.D. 不同,需在算法里处处 ÷2,易遗漏 |
| Q4 | ~~RegionID 用 RefCounted 还是 packed int?~~ **R1 已拍板** | **packed int64 (24+24+16 bit)** — 见 data-structures §4.1 | ✅ R1 P1 #1 修订;Godot 4.6 实测 RefCounted 当 Dict key 走实例身份,用 packed int64 |
| Q5 | 异步寻路要不要做? | 暂时全同步 | 100 单位规模同步够;>200 单位寻路 spike 怎么办? |
| Q6 | RtsBattleGrid facade 保留多久? | M1-M4 保留,M5 移除 | 双 grid 维护代价 |
| Q7 | trace utility 落到哪? | `addons/.../tools/path_trace_v2.gd` | 跟 logic 混在一起 vs 单独 tools 目录 |
| Q8 | spatial index 用 uniform grid 还是 quadtree? | uniform grid (256 px 桶) | quadtree 标准 RTS 方案,但 uniform 简单;100 单位 uniform 够吗? |
| Q9 | LongPath PriorityQueue 怎么实现? | **A* heap key = 5 元组 `(f, h, i, j, insertion_seq)` 整数比较** — 见 data-structures §6.4 / §12.1 | ✅ R1 P1 #4 修订;不用 RefCounted heap,直接 SortedArray + 整数 5 元组 deterministic 比较 |
| Q10 | ~~replay determinism: A* tie-break 用 entity_id parity?~~ **R1 已拍板** | **完整总排序 contract — 见 data-structures §12** (heap 5 元组 / spatial / vertex / obstruction / commands / 浮点),**不**单靠 entity_id parity | ✅ R1 P1 #4 修订;现有 bit-identical 是多重约束共同保证,新算法所有 tie-break 路径都必须有显式 deterministic key |

### 3.3 M0 设计选型 (F1-F5)

记录在 `M0-footprint-split.md §4`:

| # | 决策 | 我的选择 | 反对意见预测 |
|---|---|---|---|
| F1 | obstruction_offset 默认值 | ZERO (0 漂移最容易满足 AC6) | "为什么不用真实几何中心,展示拆分价值"? — 反驳: Bug 1 修复来自 cells 计算精度,不需要 offset 非零 |
| F2 | RtsObstructionFlags 完整枚举是否在 M0 引入? | 否 (M2 引入) | "M0 引入完整枚举更彻底" — 反驳: M0 只用 BLOCK_PATHFINDING 一个 flag,其他 flag 在 M2 才真正按 flag 区分行为时才有意义 |
| F3 | RtsBattleGrid.place_building API 是否在 M0 改? | 否 (保持 footprint_cells: Array,M1 一起改) | "API 拆分越早越好" — 反驳: M0 不改 grid,只改 actor.get_footprint_cells 实现 |
| F4 | Frontend sprite 锚点策略 | sprite 锚点 = position_2d (跟现有一致),选择圈用 footprint_shape | "sprite 应该跟 obstruction 走" — 反驳: 玩家不感知差异;Bug 1 修复来自 cells 精度不来自 sprite 移位 |
| F5 | footprint_shape.center_offset 语义 | 相对 owner.position (跟 sprite 走) | "应该相对 obstruction 中心" — 反驳: 默认让 footprint 跟 sprite 锚点重合 (玩家点 sprite 中心能选中) |

---

## 4. 我的疑虑 (希望 codex 重点看)

### 4.1 我自己拿不准的设计

**M0 的"价值演示"困境** (R7):

我选了 F1 = ZERO offset (跟现有完全 bit-identical),意味着 M0 完成时**视觉上看不出差异**。Bug 1 的实际体感修复要等到玩家放下 obstruction_offset 非零的建筑才显现。

我加了缓解 (M0.7 步骤 5: "故意临时把 barracks 配 obstruction_offset=(16,16) 做对比演示"),但这个方案有点尴尬 — **真正的 Bug 1 体感修复在 M0 完成时是不存在的,得等 M6 vertex pathfinder 才能完整解决**。

**给 codex 的问题**: 是不是应该:
- (A) 接受 M0 看不出明显差异 (我的当前方案)
- (B) M0 直接改 sprite 锚点策略 (F4 改 B,sprite 跟 obstruction 走) → 视觉差异明显但风险大
- (C) M0 顺手做一点 placement ghost 精度优化 (亚 cell 渲染) → M6 之前先有视觉小改善

**Q4 RegionID 数据类型选择** — ✅ **R1 已闭环 (packed int64)**:

R1 codex 本地验证 GDScript 4.6 Dictionary 用 RefCounted 当 key 走实例身份(不走 `_eq` / `_hash`),所以 RegionID **必须**用值类型当 key。最终选 packed int64 而非 String,理由:int 比较远快于 String,且 packing 后字段易解构。

最终 bit layout (data-structures §4.1):
- bits 63..40 (24 bit): ci — 最大 2^24 = 16M chunks 一边(远超 0 A.D. u8 = 256 的限制)
- bits 39..16 (24 bit): cj
- bits 15..0  (16 bit): r — chunk 内 local region(96² ≤ 65535,16 bit 够用)
- 0 永远表示 "无效 / 不可通行"(`is_invalid` 只看 r)

**剩余风险只在实现层**(M4 实施时验证):
- pack/unpack helper 的 shift / mask 边界 case 单元测试
- RegionID = 0 sentinel 跟合法 (ci=0, cj=0, r=N) 区分(已通过 `is_invalid` 只检 r 解决)
- 多 pass class 时 chunks_w / chunks_h 一致性

**M5 replay bit-identical 漂移源** (codex P1 #4 已纠正):

⚠️ **我之前的判断"现有实现 tie-break 都按 entity_id 字典序"是过度简化的**。

**codex 反馈**: 现有 bit-identical 不是全靠 entity_id 字典序,而是以下多重约束共同保证的:
- IdGenerator reset (seed=42 时 ID 序列固定)
- Fixed seed (`RtsRng` autoload 走 BattleProcedure 的 seeded RNG,真实 API: `RtsRng.randf / randi / randf_range / randi_range`,见 `addons/.../logic/rts_rng.gd`;不用全局 `randf`)
- 固定 tick 顺序
- 显式 sort (例如 actor 列表迭代顺序固定)
- Actor array order (insertion order 在 GameWorld registry 中保留)
- Strict score 比较 (没有"两值相等时随便选"的代码路径)

**重要**: **当前 GridPathfinding A* 自身没有 entity_id tie-break** —— 它走的是"先到先得 + insertion order"。新 LongPath / ShortPath / ObstructionManager 必须明确写**总排序 contract**,否则会引入新漂移源。

完整 contract 落到 [`data-structures.md` §12](../task-plan/m3-0ad-pathfinding-migration/data-structures.md) (新增节,本次 codex 反馈后补)。

**仍需 codex 后续确认的问题**: data-structures §12 contract 是否覆盖完整? 有没有漏的 deterministic 要求点 (heap / spatial bucket / vertex candidates / obstruction query / 同 tick commands order)?

### 4.2 我没足够时间深入的部分

**Vertex pathfinder (M6) 几何边界 case**:

我没读完 0 A.D. `VertexPathfinder.cpp` 全部 1500 行,只读了 header 和注释。具体几何 bug 我不知道:
- 起点在 obstruction 圆内时怎么处理?
- 两个 obstruction 完全重叠时怎么外扩?
- 单位即将进入 obstruction 时,是先绕开还是先 stop?

**M6 我标了"最难一层"+ "前置 prototype"**,但 Step B 写 M6 milestone 文档时我可能仍漏掉关键 case。需要 codex 在审查 data-structures §7 (ShortPath) 时帮我提示遗漏。

**Hierarchical edge map 的增量更新** (M4):

ObstructionManager 删除某 building → 几个 navcell 变可通行 → 影响 chunk 内 region 数 → 可能合并两个 region → 边界 edge 变化 → 可能影响 GlobalRegionID。

0 A.D. 的 `HierarchicalPathfinder::Update(grid, dirtinessGrid)` 处理这个逻辑很复杂,我读了 header 但没读 cpp 实现。Step B 写 M4 milestone 时我可能描述不准。

**给 codex 的问题**: M4 需要花多少时间真正理解 0 A.D. HierarchicalPathfinder 的增量更新?是不是应该把 M4 拆成 M4a (静态全图重算,够 Epic 当前需求) + M4b (增量更新优化,后续) 两个 phase? 当前文档把 M4 写成一个 milestone 1.5-2 周,可能严重低估。

---

## 5. 给 codex 的审查 checklist

请按以下 checklist 审查这 3 份文档:

### 5.1 README.md (Epic 总览)

- [ ] §0 范围决策 D1-D8 是否合理? (尤其 D1 混合方案 / D6 不做 JPS)
- [ ] §1 里程碑切分顺序 M0→M8 是否有遗漏依赖? 是不是某个 M 应该提前 / 推后 / 拆分?
- [ ] §2 用户体验里程碑 5 个位置是否合理? (M0 / M4 / M6 / M7 / M8)
- [ ] §3 Acceptance 9 项是否有遗漏? (尤其 AC-EPIC-7 性能 ≤ 2× 这个数字)
- [ ] §4 trace 验证基础设施清单是否够用?
- [ ] §7 估算 17-19 周全职 / 50-60 周用户节奏是否合理?
- [ ] §8 风险 R1-R8 是否有重大遗漏?

### 5.2 data-structures.md (字段定义)

- [ ] §1 Navcell + Passability — 字段命名 / 类型选择 (PackedInt32Array vs Dictionary) 是否合理?
- [ ] §2 Obstruction shape — Type 枚举 (UNIT / STATIC) 是否够? 是否需要 Sphere / Polygon (将来)?
- [ ] §3 Footprint shape — center_offset 语义 (相对 owner.position) 是否最佳?
- [ ] §4 Hierarchical — RegionID / Chunk 数据结构是否照搬到位? CHUNK_SIZE = 96 是否需要为我们规模调整?
- [ ] §5 PathGoal — 5 种 Type 是否够? maxdist 字段我们用得上吗?
- [ ] §6 LongPath — PathCost 整数公式 (`hv * 65536 + diag * 92682`) 跟浮点直接比较利弊?
- [ ] §7 ShortPath — 还有什么 0 A.D. VertexPathfinder 字段我漏了?
- [ ] §8 Motion — MoveRequest 4 类型 + Ticket + 双 path 是否完整?
- [ ] §9 PathfinderFacade — API 是否照搬 ICmpPathfinder.h?
- [ ] §10 字段对照表 — 是否有遗漏 / 错误对照?
- [ ] §11 待确认 10 个 Q (我的核心疑虑)

### 5.3 M0-footprint-split.md (具体落地范本)

- [ ] §1 Scope 范围划分是否合理? (M0 不引入 ObstructionManager 是否对?)
- [ ] §2 子任务 M0.1-M0.7 顺序 / 内容是否合理?
- [ ] §2 M0.4 `get_footprint_cells` 算法变更 — 偶数尺寸偏置方向选 "上半左半" 是否跟现有 `RtsBuildingPlacement` 完全一致 (避免 AC6 漂移)?
- [ ] §3 AC1-AC10 是否覆盖完整? AC8 体验点 1 验收主观性强,如何客观化?
- [ ] §4 F1-F5 决策默认值 (尤其 F1 ZERO offset 选择)
- [ ] §6 R1-R7 是否合理? R7 "M0 看不出明显差异" 这个困境怎么解?
- [ ] M0 整体能否成为 M1-M8 的格式范本? (Step B 批量产出时直接套这个模板)

### 5.4 总体审查角度

- [ ] **是否有"我以为 0 A.D. 是这样,实际不是"的误解**? (我读的源码量有限,可能有误读)
- [ ] **是否漏了关键 0 A.D. 概念** (e.g. UnitMotionManager 的 push pass 时机 / m_BlockMovement 的特殊语义)?
- [ ] **GDScript / Godot 4 实现选型是否合理** (PackedInt32Array vs Dictionary / RefCounted 当 key)?
- [ ] **里程碑工程量是否严重低估**? (尤其 M4 / M6 / M7)
- [ ] **是否有不该原样复刻的部分** (e.g. 某些 0 A.D. 设计是给 C++ + 物理引擎服务,GDScript 不需要)?
- [ ] **测试基础设施是否够** (trace utility / baseline replay / 体验点)?

### 5.5 codex 反馈格式希望

- 按 5.1 / 5.2 / 5.3 各 section 给 ✅ / ⚠️ / ❌ + 具体说明
- 5.4 总体角度问题逐条回答
- **特别希望**: 如果发现我"原样复刻"理解错了 0 A.D. 某个细节,引用 0 A.D. 源码具体行号告诉我正确实现
- **特别希望**: 如果某 milestone 被严重低估或拆分错误,告诉我应该怎么拆 (M4 / M6 / M7 是高风险点)
- 总体结论: APPROVE / REQUEST CHANGES / REJECT,带 1-3 个 must-fix 项 (如果有)

---

## 6. 用户决策点 (codex 审查后用户拍板)

### 6.1 在 codex 审查后,用户需要拍板的事

1. **codex 的 must-fix 项是否吸收**? (我会逐项分析后再决定;复杂的我会回过来跟用户讨论)
2. **是否进 Step B** (批量产出 M1-M8)? 还是先 prototype M0 看看再决定?
3. **是否要先做 baseline replay 准备** (M0 启动前置)?这是个独立小任务,可以并行 Step B 时做。

### 6.2 我的建议路径

**A 路径 (推荐)**: codex 审查 → 我吸收 must-fix → Step B 批量 → /next-feature-planner → /autonomous-feature-runner 跑 M0
**B 路径**: codex 审查 → 我吸收 must-fix → 直接 prototype M0 (绕过 Step B/C) → 跑通后再写 M1-M8 文档
**C 路径**: codex 审查 → 用户先放着,我先去做别的 (M0 不急) → 后续回来再续

我建议 **A 路径** — Step A 三份文档已是一致的设计,Step B 是批量复制结构,工程量小风险低。但**如果 codex 提出根本性架构问题** (例如 D1 混合方案有大问题),那 B 路径反而合适 (先 prototype 验证可行性)。

---

## 7. 关键文件直链 (给 codex 阅读)

### 7.1 本批 Step A 产出 (主审查对象)

- `.feature-dev/task-plan/m3-0ad-pathfinding-migration/README.md`
- `.feature-dev/task-plan/m3-0ad-pathfinding-migration/data-structures.md`
- `.feature-dev/task-plan/m3-0ad-pathfinding-migration/milestones/M0-footprint-split.md`

### 7.2 上下文文档 (审查时参考)

- `.feature-dev/Handoff-2026-05-03-pathfinding-diag.md` (上轮 bug 诊断,真实 bug 数据)
- `addons/logic-game-framework/example/rts-auto-battle/docs/references/0ad-architecture-overview.md`
- `addons/logic-game-framework/example/rts-auto-battle/docs/references/0ad-pathfinding.md`
- `addons/logic-game-framework/example/rts-auto-battle/docs/references/0ad-data-flow.md`
- `addons/logic-game-framework/example/rts-auto-battle/docs/references/0ad-learnings.md` (Q1-Q6 自答含决策固化)
- `addons/logic-game-framework/example/rts-auto-battle/docs/references/0ad-vs-inkmon-rts.md` (差距对比)

### 7.3 现有代码 (对照点)

- `addons/logic-game-framework/example/rts-auto-battle/logic/rts_building_actor.gd:127-147` (Bug 1 算法)
- `addons/logic-game-framework/example/rts-auto-battle/logic/commands/rts_building_placement.gd:101-115` (placement 算法)
- `addons/logic-game-framework/example/rts-auto-battle/logic/grid/rts_battle_grid.gd` (现有 grid)
- `addons/logic-game-framework/example/rts-auto-battle/logic/movement/rts_nav_agent.gd` (现有 agent,M7 重写)
- `addons/logic-game-framework/example/rts-auto-battle/logic/movement/rts_unit_steering.gd` (现有 steering,M7 重写)
- `CLAUDE.md` (项目级硬约束 — submodule / smoke 入口规范 / NavigationServer 初始化等)

### 7.4 0 A.D. 源码 (核心引用)

- https://github.com/0ad/0ad/blob/master/source/simulation2/helpers/Pathfinding.h
- https://github.com/0ad/0ad/blob/master/source/simulation2/helpers/Grid.h
- https://github.com/0ad/0ad/blob/master/source/simulation2/helpers/HierarchicalPathfinder.h
- https://github.com/0ad/0ad/blob/master/source/simulation2/helpers/PathGoal.h
- https://github.com/0ad/0ad/blob/master/source/simulation2/components/ICmpPathfinder.h
- https://github.com/0ad/0ad/blob/master/source/simulation2/components/ICmpObstructionManager.h
- https://github.com/0ad/0ad/blob/master/source/simulation2/components/CCmpObstruction.cpp (m_Clearance 同步)
- https://github.com/0ad/0ad/blob/master/source/simulation2/components/CCmpUnitMotion.h

---

## 8. 备注 (一些边角)

- **本 handoff 文档不是 autonomous runner 的入口**。runner 入口在 `.feature-dev/Next-Steps.md`,Step C 时写。
- **本 handoff 不会触发 commit**。Step A 文档全部新建,等用户决策后一起 commit (跟 M0 启动时合在一起)。
- **不要让 codex 直接修改我的文档**。codex 反馈 → 我读 → 我决定哪些吸收 → 我自己改文档。codex 是审查不是协作者。
- **审查时间预算**: Step A 三份文档约 36 KB markdown,codex 仔细审应该 30-60 分钟。如果 codex 给过快回复 (< 10 分钟) 表明审得不够仔细,要求重审。

---

## 9. 时间线

- 2026-05-03 上午: 用户报告 Bug,Claude 写参考文档
- 2026-05-03 下午: 8+ 轮架构讨论收敛 + 4 份 docs/references/* 完成
- 2026-05-03 晚 (本批): Step A 三份规划文档完成 + 本 handoff
- **下一步**: 用户提交给 codex 审查 → 等待

---

## 10. 历史警示 (本次 handoff 是第二次写)

第一次写完后被另一个 AI 工具误清理了 (整个 `task-plan/m3-0ad-pathfinding-migration/` 目录 + Handoff 文档全部消失)。本次重写已恢复全部 4 份文档。如果再发现文件消失,先停下问用户,**不要默默重写第三次** — 可能是 git / 工具配置层面的问题需要排查。

---

## 11. Codex Round 1 反馈吸收记录 (2026-05-03)

### 11.1 总体结论 (codex)

**REQUEST CHANGES**, 4 个 P1 + 7 项审查意见。方向 (M0-M8 对标 0 A.D. Hierarchical + LongPath + Vertex + ObstructionManager + UnitMotion) 通过。Step B 启动前必须先修 4 个 P1。

### 11.2 P1 must-fix 吸收 (全部已改)

| P1 # | 问题 | 我的修改 | 落点 |
|---|---|---|---|
| **#1** | RegionID 不能用 RefCounted 当 Dict key (Godot 4.6 实测验证 — 走实例身份, _eq/_hash 也不顶用) | 改 packed int64 (24+24+16 bit), `RtsRegionIdHelper.pack/unpack`, ci/cj 比 0 A.D. 宽 (避免 chunks > 256) | data-structures §4.1 / §4.4 / §10 / §11 Q4 |
| **#2** | M0 factory 初始化 obstruction.center 不可落地 (factory 时不知 position_2d) | factory 只填 size/type/offset 默认字段, 新增 `RtsBuildingActor.sync_obstruction_shape()` 由 procedure/command 写完 position 后调 | M0 §1.3 / §M0.4 step 4 / §M0.5 (重写) |
| **#3** | M0 文档自相矛盾 (sprite 锚点 / footprint_size 命名) | 字段改名 `selection_footprint_size` (避免跟旧 `footprint_size: Vector2i` 冲突), F4 决策 A 全文统一 (sprite 锚点 = position_2d 不变), 删除"不再左上偏置/真正居中"误导句, AC8 客观化 (smoke 验 ghost cells == placed cells == path cells 三者一致) | M0 §1.1 / §M0.3 / §M0.4 / §M0.6 / §AC8 |
| **#4** | Q10 determinism 判断过度简化 (现有 bit-identical 不仅靠 entity_id 字典序) | 新增 data-structures §12 总排序 contract: heap (5 元组) / spatial bucket / vertex candidates / obstruction query / 同 tick commands / 浮点处理 / acceptance | data-structures §12 (新增) / §11 Q10 / Handoff §4.1 |

### 11.3 其他审查反馈吸收 (全部已改)

| 项 | codex 意见 | 我的修改 |
|---|---|---|
| D1 标记 | 混合方案是有意偏离 0 A.D., 不是原样复刻 | README §0.3 D1 加 "⚠️ 有意偏离" 标记 |
| D6 标记 | 0 A.D. LongPath 实际是 JPS+JumpPointCache, 我们简化 | README §0.3 D6 加 "⚠️ 有意简化" 标记 |
| 体验点 1 过度承诺 | M0 自身 32px grid 不能完整消 Bug 1 | README §2 ✋1 改成"ghost / placed / path 三者 cells 一致", 注明完整体感等 M6 |
| M4/M6/M7 估算偏乐观 | 拆 sub-phase | M4 拆 M4a/b/c, M6 拆 M6a/b/c, M7 拆 M7a/b/c/d. README §7 估算从 17-19 周 → 22-26 周 |
| Group filter 不是 M8 polish | 是 M6/M7 输入 | 新增 D9, README 里程碑图 / data-structures §2 / §7 注明 control_group 在 M6/M7 已是 API 输入, M8 仅打开 + tune |
| `make_goal_reachable` 语义错 | 即使 true 也 canonicalize | data-structures §4.4 改正语义 |
| `PathCost` 自相矛盾 | 默认整数, 不等漂移 | data-structures §6.4 改成整数 5 元组 (跟 §12.1 一致) |
| VertexPathfinder 漏 7 个细节 | search bounds shift / range boundary / virtual goal / terrain edges / lazy visibility / best-so-far / moving unit square proxy | data-structures §7.2 全部补全 |

### 11.4 仍待 codex Round 2 看的点

| # | 问题 | 我的修改是否到位? |
|---|---|---|
| 1 | data-structures §12 determinism contract 7 个子节是否覆盖完整? | 自评: heap / spatial / vertex / obstruction / commands / 浮点 / acceptance 都列了, 但可能漏"Hierarchical edge map insertion order" 等 |
| 2 | data-structures §7.2 VertexPathfinder 7+2 细节是否还漏? | 自评: 已包含 codex 列的 7 项 + group filter + tie-break, 但 0 A.D. 源码我没读完 1500 行,可能仍漏几何边界 case |
| 3 | M4/M6/M7 拆分是否合理? | 自评: 按 codex 建议拆 (M4 a/b/c, M6 static→virtual+terrain→dynamic, M7 storage→lifecycle→sync→activity), 但每个 sub-phase 周数仍是粗估 |
| 4 | M0 sync_obstruction_shape 改造影响面是否完整? | 自评: 列了 PlaceBuildingCommand + setup 入口 + 新 smoke 抓漏 sync, 但实际 grep 调用方可能还有别的 |

### 11.5 Round 2 期望(已收到反馈,见 §11.6)

- codex 看新增 §12 + §7.2 修正 + M0 §M0.5 改造 + README 里程碑拆分,**确认 P1 都修到位**
- 如果 §12 / §7.2 仍有遗漏, 列具体项
- 如果 M0 sync 改造影响面有漏, 提示我在 Step B 写 M0 implementation runbook 时一定要 grep 哪些调用方
- 如果 Round 2 通过 → 我进 Step B (M1-M8 批量 + interfaces + validation-strategy + risks-and-rollback + Formation handoff)

---

## 11.6 Codex Round 2 反馈吸收记录 (2026-05-03)

### 11.6.1 总体结论 (codex Round 2)

**REQUEST CHANGES (P2 only)** — Round 1 的 4 个 P1 全部修到位 (§12 / §7.2 / M0.5 / RegionID packed int64),无新 P1。但提出 **4 个 P2** 关于真实 API 名校对 + R2 显式定义 deterministic 排序的事项,要求修后再 review。

### 11.6.2 R2 P2 反馈吸收 (全部已改)

| R2 # | 问题 | 我的修改 | 落点 |
|---|---|---|---|
| **P2-1** | 文档多处用 `RtsRandomSeq` (该类不存在),真实 API 是 `RtsRng` autoload | 全文搜替换为 `RtsRng`,标注真实 API: `randf / randi / randf_range / randi_range`,见 `addons/.../logic/rts_rng.gd` | data-structures §12 背景 / §12.0 / §12.5; Handoff §4.1 |
| **P2-2** | 文档用 `RtsRtsMatchPreset` 双前缀,真实类名是 `RtsMatchPreset` (单前缀) | M0.5 call sites 表(原 6 行)第 6 行注释明确"类名 `RtsMatchPreset`,不是 `RtsRtsMatchPreset`" | M0 §M0.5 步骤 2 表格 |
| **P2-3** | `RtsPlayerCommandQueue` 真实路径 `logic/commands/rts_player_command_queue.gd`,不是文档中假设的位置 | data-structures §12.6 用真实路径引用 | data-structures §12.6 |
| **P2-4** | UnitMotion 同 tick 多 unit 排序顺序未显式定义,跨平台 GDScript Dictionary 迭代序不稳 | §12.5 显式定义 `actor.get_id()` 字典序排序;补 actor_id 格式说明 (`<world>:<kind>_<seq>` e.g. `rts_world_0:Character_3`);要求 M7 加专项 unit test | data-structures §12.5 |

### 11.6.3 R2 补充审查反馈吸收

| 项 | codex R2 意见 | 我的修改 |
|---|---|---|
| M0.5 sync call sites 表 | 上一版只列 PlaceBuildingCommand + setup 入口,实际代码 grep 还有 demo / scenario / preset 多处 | M0.5 步骤 2 表格扩到 6 行(`rts_place_building_command.gd:81-90` / `rts_auto_battle_procedure.gd:188` / `demo_rts_frontend.gd:164,170` / `demo_rts_pathfinding.gd:115,121,269,274` / `rts_scenario_harness.gd:92,282-289,301` / `rts_match_preset.gd`) |
| sync 兜底 assert | 漏 sync 的入口寻路会以为建筑在 (0,0) | M0.5 步骤 2 末尾加 `Log.assert_crash(actor.obstruction_shape.center != Vector2.ZERO or stats.obstruction_offset == Vector2.ZERO)` 在 `place_building` 入口兜底 |

### 11.6.4 R2 仍待后续 Round 关注的点

- [x] data-structures §12 真实 API 名 (P2-1) — R3 重审
- [x] M0.5 sync call sites 完整 (R2 补充) — R3 重审
- [ ] **Step B 实施时**: M0 实现前必须 grep `tests/**/*.gd`,因 diagnostics/smoke 里还有 `create_*` 后 `get_footprint_cells()` 直接路径 (R2 提示,M0 implementation runbook 时落实)

---

## 11.7 Codex Round 3 反馈吸收记录 (2026-05-03)

### 11.7.1 总体结论 (codex Round 3)

**REQUEST CHANGES (文档同步问题, 1 P1 + 3 P2)** — §3.2 已把 Q4 改成 packed int64 但 §4.1 仍以"待 codex 判断"风格留着,导致下一轮从 Handoff 入口读的人会重审已闭环事项;真实 API 残留(`RtsRandomSeq` / `RtsRng.next_*` 不存在的方法名);Round 2 闭环没记录到 §11 段。

### 11.7.2 R3 反馈吸收 (全部已改)

| R3 # | 问题 | 我的修改 | 落点 |
|---|---|---|---|
| **P1** | Handoff §4.1 Q4 段仍用"待 codex 判断"风格,跟 §3.2 闭环结论不一致 | §4.1 Q4 段改写为 "✅ R1 已闭环 (packed int64)",列出 bit layout 决策 + 剩余实现层风险 | Handoff §4.1 |
| **P2-1** | Handoff §4.1 + data-structures §12 背景仍写 `RtsRandomSeq`(该类不存在) | 全文替换为 `RtsRng` autoload,加真实 API 说明 | Handoff §4.1 / data-structures §12 背景 |
| **P2-2** | data-structures §12.0 / §12.5 写 `RtsRng.next_float / next_int`(也不存在) | 改为真实 API: `RtsRng.randf / randi / randf_range / randi_range`;加重要提示"`RtsRng` 是 autoload Node,方法名跟全局同名但作用域不同 — 必须显式 `RtsRng.randf()` 调用,不写前缀走全局未 seed 的 RNG" | data-structures §12.0 / §12.5 |
| **P2-3** | Handoff §11 缺 Round 2 闭环记录,文档非 self-contained | 新增 §11.6 Round 2 反馈吸收记录(本轮再加 §11.7 = 本节) | Handoff §11.6 / §11.7 |

### 11.7.3 R3 codex 补充核对结论 (无新 blocker)

- ✅ M0 sprite 锚点保持 `actor.position_2d` 已修正(F4-A 全文统一)
- ✅ `selection_footprint_size` 字段命名已修正(避开旧 `footprint_size` 冲突)
- ✅ `sync_obstruction_shape()` production call sites 表完整(6 行)
- ⚠️ **Step B 待办**: M0 实施时仍需额外 grep `tests/**/*.gd`,因 diagnostics/smoke 里还有 `create_*` 后 `get_footprint_cells()` 直接路径(已并入 §11.6.4 待办)
- ✅ §7.2 / M4-M7 拆分本轮无新 blocker

### 11.7.4 R3 后状态

- 本轮 codex 给出"修完 1 P1 + 3 P2 后 APPROVE for Step B"承诺
- 4 项已全部修到位 → **Handoff 转 codex Round 4 (期望 APPROVE)**
- 若 R4 APPROVE → 进 Step B (M1-M8 批量 + interfaces + validation-strategy + risks-and-rollback + Formation handoff)
- 若 R4 仍 REQUEST CHANGES → 按 P1 全闭环 / P2 看心情 优先级处理
