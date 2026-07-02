# 待启动任务队列（跨主项目 + 框架，启动时才 review/给建议）

> 本文**登记**一批已决定要做、但**尚未启动**的大任务，横跨主项目 `inkmon/` 与框架 submodule（`addons/logic-game-framework/`、`addons/sim-nav-map/`）。
> **操作规则（钉死）**：这里只登记「目标 / 现状 / 启动时做什么 / 约束」。**具体 review、方案、建议一律等对应任务真正启动时才产出，不是现在。** 启动时统一由 **fable** 产出（部分 fable 独立跑、部分**用户 + fable 讨论**）；Claude/Opus 只做登记与编排，不替 fable 下结论。
> **模型备注**：用户点名用 **fable** 跑 fable 标注的项。fable 5 access 已于 2026-07-02 恢复，本队列由 fable 接手推进。
> 关联：本队列是对 [现有 future 文档全景](#关联现有-future-文档) 的收口；不重复其内容，只登记「下一步谁去动、怎么动」。

---

## 线 1 — sim-nav-map（导航/寻路 addon）+ dota2-auto-battle（LGF 示例）

### 1a. sim-nav-map **core** — 对照 0ad 源码 review（fable）【✅ 完成 2026-07-02】
- **产出**：`addons/sim-nav-map/docs/reviews/2026-07-02-core-vs-0ad-review.md`（6 模块并行对照 + 主会话抽查复核）。结论：架构站得住、满意部分经得起对照；5 确认缺陷（重点 C1 clearance extension 缺失 / C2 impassable 逃逸缺失——均与「单位卡住」手感直接相关且有 repro 实证）、22 疑似、差异裁决与 P0-P2 行动清单见报告。
- **现状**：地图数据结构方案 + 基础寻路方案是**用户唯一相对满意**的部分，要保住。
- **启动时 fable 做什么**：根据参考项目 **0ad 源码**做一次 review —— 有无缺陷、架构是否合理。
- **约束**：**只 review 验证，不重写**（这是满意的部分）。
- **0ad 源码位置**（已找到）：`addons/sim-nav-map/docs/references/0ad-source/` —— 真实 git 稀疏/浅 clone，寻路源码已 checkout。重点：`source/simulation2/helpers/`（`HierarchicalPathfinder`/`LongPathfinder`/`VertexPathfinder`/`Pathfinding`/`PathGoal`/`Grid.h`/`Spatial.h`/`Rasterize`/`PriorityQueue`）+ `source/simulation2/components/`（`CCmpPathfinder*`/`CCmpObstructionManager`/`CCmpUnitMotion*`）。
- **相关**：`addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/docs/steady-state-frame-performance-plan.md`

### 1b. sim-nav-map **examples** — 删了重做 or 重构【🚧 已拍板执行中 2026-07-02】
- **提案与拍板**：[`simnav-examples-disposition-proposal.md`](simnav-examples-disposition-proposal.md) —— 用户拍板：sc2 删（✅ 已删）；0ad lab 保留+定向修；dota2 lab 保骨架重做手感契约；1c 继续接 sim-nav lab 栈（**1b 成 1c 前置**）。
- **进度**：core P0（C1 clearance extension + C2 impassable 逃逸）✅ 已修；~~手感契约 v2/v2.1~~ 用户实测判死（重叠 + 永卡两 bug，v2 不如 v1）→ **用户拍板放弃修补，fable 从零重做 ✅ 已落地（2026-07-02）**：接触式分离求解（单位不进 nav map）+ 两态 FSM + 同步规划 + 有界终止语义，`Dota2LabMotionEngine` 替代旧 controller，新 smoke 7/7 + dota2autobattle 2/2 + 全量绿，**待用户 F6 验手感**（设计见 lab `docs/design-notes/fable-motion-design.md`）。**寻路性能已根治 ✅（2026-07-02）**：归因=架构问题×语言单价（旧 per-(start,dir) 射线缓存真实命中率≈0，每查全额逐格扫）；JPS+ 射线表预计算 + LOS refine 走 baked 网格后跨图单查 5-6ms → **~0.8ms**，A/B 探针（1.1 万射线穷举 + 44 全查询 + 500 segment）零结果/零诊断变化，51 smoke 全绿。**剩余**：0ad lab 5Hz 节拍分离 + cell 8 重锚（1b 收尾项）。
- **现状**：用户对**各 example 的手感都不满意**；测试中遇到不少 bug，**改了很多次改不好**。
- **启动时 fable 做什么**：了解后**自行决定** —— 删除示例源码、按各 example 目标从头重做，**还是**在当前 example 上重构。
- **约束**：删除/重写是破坏性操作，**方向自决、动手前仍给用户过目**。手感是体验性的，fable 判断不了的部分需向用户要**具体手感问题**，不臆造结论。
- **相关**：各 example 的 `docs/development-plan.md`、`docs/design-notes/layer-2-ai-control-plan.md`（含 example 目标）。约束记忆：lab 只做移动+编队、不抽 UnitAI 中间层；测试分 smoke/repro/stress 三类。

### 1c. dota2-auto-battle 示例 — 从头重做（fable）【🗳️ 方案待批准 2026-07-02】
- **方案**：[`dota2-auto-battle-rebuild-plan.md`](dota2-auto-battle-rebuild-plan.md) —— 诊断（sim-nav 栈选型错误/无胜负目标/debug-only 前端）+ 保形清单 + M1'-M5' + 3 决策点（移动底座 steering vs sim-nav / 胜负条件进 M1' / 旧代码定义类复用）。批准后动代码。
- **现状**：用户评价"更垃圾"。定位（主仓 CLAUDE.md）：实时固定 tick 30Hz / ARAM 单中路自动战斗 / controller-intent 模型 / sim-nav movement adapter / 当前 M1 垂直切片。
- **启动时 fable 做什么**：**基于项目目标从头重新做**（已定调重做，非修补）。
- **约束**：先出**重建方案**给用户过目，再落实现代码（别抢跑写一堆代码）。守 enforcing-lgf / GDScript 规范，不过度设计。
- **相关**：`addons/logic-game-framework/example/dota2-auto-battle/README.md`（M1 目标 + M2–M5 里程碑 + Open Design Questions）

### 1d. sim-nav 能力信封 + 底座硬化清单【🚧 信封已拍板 2026-07-02】
**契约文件：[`addons/sim-nav-map/docs/capability-envelope.md`](../../addons/sim-nav-map/docs/capability-envelope.md)**（9 条能力拍板 + 性能承诺）。模式 = 用户拍板："先冻结底座支持什么 → 设计在信封内 → 真撞墙才谈改底座"；1c 降级为探索件不再当基建验收方。**执行状态以本条为准**（envelope 内清单只留粗状态，完成一把刀两处各改一行）。每把刀 = 独立会话可启动，开新会话直接说"做 1d-X"。

**已完成（2026-07-02，全部已 commit + codex review）**
- ✅ JPS+ 射线表：跨图规划 5-6ms → 0.8ms，A/B 零结果变化（submodule 6038975）
- ✅ 建表预热进 rebuild：首查 12ms → 0.9ms（f99951f）
- ✅ 刀①路牌表增量修复：沟壑级 ~0.7ms（原全量 ~9ms），"增量==全量"逐字节焊死 `smoke_sim_nav_jump_table_repair`；facade flush + 查询侧双路（564bc52 + codex 修正 4d37dcc）

**顺序推进模式（用户 2026-07-02 拍板：⓪→②→③→④ 挨个做完，⑤ 留专门会话）**
- ✅ **⓪ hierarchical 窗口化 chunk 重算**（2026-07-02）：29ms 真凶 = 单 chunk（96²=9216 格）洪泛逐格跨对象调用，非全局步骤；windowed snapshot + 本地整型 BFS（顺序逐位一致）+ 边界 packed 直读。地形变更 flush 30 → **3.5ms**、全量 rebuild 138 → 72ms；`smoke_sim_nav_hierarchical_incremental` 焊死（增量==全量，含双 mask、两条全量回退分支、区域分裂/重连/跨 chunk 边界/图边）。codex review：High 0 / Medium 0，两条 Low 已修（mask 0 入口拒绝 + smoke 补覆盖）。
- **② `is_line_walkable` 查表化**｜触发 = 单位规模 30+｜⚠️ 语义雷区已勘探：`_validate_line` = 栅格走线（0 A.D. 逃逸规则：可从不可通行格走出）+ 精确几何形状段，不是机械换 `segment_clear`；需带逃逸规则的 baked 孪生 + 保留形状段 + 独立 A/B｜验收 = 结果零变化 + 8 移动单位稳态 tick 0.78 → ~0.4ms
- **③ 分离求解空间哈希**｜触发 = 单位规模 50+｜O(N²)→近线性（9 单位 36 对无感；外推 100 单位 ~12-25ms/tick 不可接受）｜入口 `Dota2LabMotionEngine._resolve_overlaps`；验收 = 100 单位移动 tick < 5ms + 手感 smoke 全绿
- **④ budget smoke 套件**｜触发 = ②③ 完成后｜把 envelope 性能承诺焊进测试（参照 0ad lab `smoke_zero_ad_rts_lab_0ad_budget` 模式），跌破即红
- **⑤ GDExtension 铸模**｜触发 = 信封冻结 + ⓪-④ 完成｜范围含 long-path core + 分离求解；Web/WASM 需另编 wasm（构建链成本）；解锁真后台线程规划（GDScript 线程两次验尸判死）。用户战略原话见 envelope 条目

---

## 线 2 — inkmon 主项目

### 2a.（第一要务，✅ 已完成 2026-07-02）review `architecture-optimization-plan` —— 用户 + fable 讨论
- **做什么**：review [`docs/future/architecture-optimization-plan.md`](architecture-optimization-plan.md)，用 `/grill-with-docs` **跟用户讨论**有无建设性意见，**讨论并落地**。
- **谁做**：**用户 + fable 讨论**（grill）；Claude/Opus 不代跑。
- **相关**：`docs/future/architecture-optimization-plan.md`（P0/P1/P2 backlog，仅记录暂不执行 2026-06-13）。
- **进度（2026-07-02）**：① fable 复核 plan 有效性（2 处修订回写）；② R3 独立验证（fable 逐条读码 + 2 agent 核查，覆盖 44/47）：1 条证伪、数条修正与净增发现，回写 plan 头部 🗳️ 记录；③ 用户拍板：进化 stat gate = 纯成长不含装备；执行策略 = 三波全推；④ **三波已落地**（`inkmon/all` 21 smoke 全绿，明细见 plan 头部 ✅ 记录）；⑤ modal + drawer 下放亦完成（子场景控制器 ×2，root 972→776 行，开窗截图 harness 自验）——**2a 关闭**。核心文档（main-game-architecture / glossary）已同步 snapshot facade 措辞。注：`/grill-with-docs` 已不存在，讨论在会话内按 grill 纪律进行。

### 2b.（其次）大地图 vs 战斗地图的生成策略
- **大地图**：判断是**自己拼**、还是**做地图生成算法**（保证每局不同体验）。
- **战斗地图**：进战斗后**一定是生成的**；看是**基于模板**还是别的做法；**战场不会大**。
- **谁做**：**用户 + fable 讨论**；设计决策，排在 2a 之后。
- **相关**：[`docs/game-vision.md`](../game-vision.md)（游戏循环）、[`docs/gameplay-systems-roadmap.md`](../gameplay-systems-roadmap.md)。

### 2c.（再其次，低优先级）剩余问题
- 用户原话："那些问题没有 fable 我也能搞定，优先级不高"。**暂不展开。**

### 2d. AI Runtime Control Service —— 外部 AI 像玩家一样操作主游戏（fable）
- **现状**：设计边界已锁，完整设计见 [`ai-runtime-control-service.md`](ai-runtime-control-service.md)（`PlayerActionPort` 三分 WorldAction/ViewAction/HostAction + `InkMonAiObservationProjector` 出 state+ASCII screen+available_actions + WebSocket/JSON + 薄 MCP adapter；含 §7 五步实现顺序 + §8 open questions）。
- **启动前置（硬门）**：**inkmon 基础游戏循环做完 / 可玩之后**才启动（用户明确要求排在基础循环之后）。
- **启动时 fable 做什么**：先解 §8 open questions，再按 §7 五步落地（PlayerActionPort → ObservationProjector → RuntimeServer(WebSocket+FIFO) → 薄 MCP server → runtime smoke: observe→move→interact→observe）。
- **谁做**：fable（先出实现切分再动手）。
- **约束**：不复用 DevAgentBridge、不模拟鼠标点击、不在 MCP/TS/Python 层重写规则、不进 Web bridge `Simulation.tscn`；守现有 CQRS 写侧 / Host 控制面 / UI 本地态边界。

---

## 线 3 — LGF 框架（`addons/logic-game-framework/`）

### 3. 修遗留问题 + 优化 hex-atb-battle 架构（fable）
- **意图**：**所有遗留问题都要改**。硬约束：**尽量少改 core 层**；**首要目标 = 优化 hex-atb-battle 架构**。
- **启动时 fable 做什么**：除已知遗留问题外，**了解当前情况、提建设性意见**。
- **已知遗留问题**（`addons/logic-game-framework/docs/README.md` 已知债务）：core→stdlib 反向依赖 / ProjectileActor 位置 / 强类型事件最后落回 Dictionary / Replay·Playback 命名混用 / ~28 个 hex 技能门控待迁移到 helper / WorldGameplayInstance 是否需抽象 hex 概念。
- **约束**：少动 core；改动前出**提案**过目；守 enforcing-lgf。
- **相关**：`addons/logic-game-framework/docs/README.md`、`addons/logic-game-framework/example/hex-atb-battle/README.md`（装备 V1 + 未来规划）。

---

## 关联：现有 future 文档

本队列**触发**这些已有 future 文档的落地；启动某项时先读对应文档：

| 队列项 | 关联 future 文档 |
|---|---|
| 2a | [`future/architecture-optimization-plan.md`](architecture-optimization-plan.md) |
| 2b | [`game-vision.md`](../game-vision.md) · [`gameplay-systems-roadmap.md`](../gameplay-systems-roadmap.md) |
| 2d | [`future/ai-runtime-control-service.md`](ai-runtime-control-service.md)（AI 像玩家操作主游戏,基础循环之后）|
| （主项目占位） | [`future/deferred-features.md`](deferred-features.md)（刻印 per-slot / X→X2 / lab 导入契约） |
| （美术管线） | [`plan/tile-texture-auto-fit-tool-plan.md`](../plan/tile-texture-auto-fit-tool-plan.md) |
| 1a/1b | `addons/sim-nav-map/examples/**/docs/*-plan.md` |
| 1c | `addons/logic-game-framework/example/dota2-auto-battle/README.md` |
| 3 | `addons/logic-game-framework/docs/README.md`（已知债务）· `.../example/hex-atb-battle/README.md` |

---

> **状态**：**2a 已完成**（2026-07-02 fable），其余未启动。启动某项时，把该项从"登记"推进为"进行中"，产出物（review / 方案 / 提案）另起文档或落到对应区域，本文件只维护队列态。
