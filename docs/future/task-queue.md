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
- **相关**：`addons/sim-nav-map/examples/0ad-rts-pathfinding-lab/docs/steady-state-frame-performance-plan.md`（该 lab 已随 1b 删除，文档见 git 历史）

### 1b. sim-nav-map **examples** — 删了重做 or 重构【✅ 完成 2026-07-04】
- **提案与拍板**：[`simnav-examples-disposition-proposal.md`](simnav-examples-disposition-proposal.md) —— 用户拍板：sc2 删（✅ 已删）；0ad lab 保留+定向修；dota2 lab 保骨架重做手感契约；1c 继续接 sim-nav lab 栈（**1b 成 1c 前置**）。
- **进度**：core P0（C1 clearance extension + C2 impassable 逃逸）✅ 已修；~~手感契约 v2/v2.1~~ 用户实测判死（重叠 + 永卡两 bug，v2 不如 v1）→ **用户拍板放弃修补，fable 从零重做 ✅ 已落地（2026-07-02）**：接触式分离求解（单位不进 nav map）+ 两态 FSM + 同步规划 + 有界终止语义，`Dota2LabMotionEngine` 替代旧 controller，新 smoke 7/7 + dota2autobattle 2/2 + 全量绿，**✅ 用户已 F6 验收（2026-07-03：手感完美）**（设计见 lab `docs/design-notes/fable-motion-design.md`）。**寻路性能已根治 ✅（2026-07-02）**：归因=架构问题×语言单价（旧 per-(start,dir) 射线缓存真实命中率≈0，每查全额逐格扫）；JPS+ 射线表预计算 + LOS refine 走 baked 网格后跨图单查 5-6ms → **~0.8ms**，A/B 探针（1.1 万射线穷举 + 44 全查询 + 500 segment）零结果/零诊断变化，51 smoke 全绿。
- **2026-07-03 用户追加拍板（推翻原「0ad lab 保留+定向修」）**：examples **只保留 dota2 lab 一个**——手感已验收「完美」，未来可扩展性也评估足够；**0ad-rts-pathfinding-lab 不再保留**。原「0ad lab 5Hz 节拍分离 + cell 8 重锚」尾项作废，1b 剩余工作改为**删除 0ad-rts-pathfinding-lab example**。
  - ⚠️ 执行前已勘查（供启动时参考）：0ad lab 承载 6 组 lab-only smoke（motion/scene_load/ui_ops/0ad_budget/failed_panel/edge_cases）+ stress harness + core-020 known-limit repro（`repro_core_020_motion_brushes_clearance_under_push_known_limit`，2026-05-11 起本就被排除出主 smoke 组）会随之移除；**不影响** `addons/sim-nav-map/tests/` 下的 core 回归套件（repro_core_001-018 + `smoke_sim_nav_*`，物理独立于 example，unaffected；执行时修正：015/016 实为 lab 耦合测试、随 lab 连带删除，其余不受影响）——1a「地图数据结构+基础寻路方案要保住」的回归资产安全。
  - 交叉引用清单（~15 处，submodule 内，已随执行清完）：`README.md`、`docs/public-api.md`、`docs/smoke-matrix.md`、`docs/mental-model.md`、`docs/references/0ad-source-map.md`、`docs/issues/core-019/020/021-*.md`、`docs/_workflows/ralph-fix-issue-batch.md`、`.claude|.agents/skills/sim-nav-map*/`；主仓侧 `AGENTS.md` 一处 skill 摘要提及。
  - ✅ **已执行（2026-07-04，Sonnet）**：submodule 4be5da5（63 文件 -8786 行，含 repro_core_015/016 连带删除——测试体直调 lab 类，测的是 lab own 的 arrival/motion-validation 策略）+ 主仓 c0cff5e7 pointer bump；上述交叉引用同轮清理（issue 文档留档式状态说明，非删历史）。fable review 复核：删除面干净，simnav/all + dota2lab/all 53/53 复跑全绿。
  - ✅ **收尾（2026-07-04，fable）**：`sim-nav-map-bugfix` skill 重工完成——probe_los/probe_motion 模板删除（所测机制随 0ad 管线消亡，最小复现改拷 dota2 smoke 骨架）、probe_log.py 重写对齐 dota2 导出 schema v1（含 schema guard）、SKILL.md 心法改双轨（core 对 0 A.D. / motion 对 fable-motion-design.md）；.claude 与 .agents 双镜像同步。
- **现状**：用户对**各 example 的手感都不满意**；测试中遇到不少 bug，**改了很多次改不好**（历史记录；dota2 lab 已 2026-07-03 验收翻篇，0ad lab 因上述拍板不再需要修）。
- **启动时 fable 做什么**：了解后**自行决定** —— 删除示例源码、按各 example 目标从头重做，**还是**在当前 example 上重构。
- **约束**：删除/重写是破坏性操作，**方向自决、动手前仍给用户过目**。手感是体验性的，fable 判断不了的部分需向用户要**具体手感问题**，不臆造结论。
- **相关**：各 example 的 `docs/development-plan.md`、`docs/design-notes/layer-2-ai-control-plan.md`（含 example 目标）。约束记忆：lab 只做移动+编队、不抽 UnitAI 中间层；测试分 smoke/repro/stress 三类。

### 1c. dota2-auto-battle 示例 — 从头重做（fable）【⏸️ 短期搁置 2026-07-03】
- **搁置记录（2026-07-03 用户拍板）**：短期内不做——核心寻路已在 lab 侧示例项目验证，游戏逻辑不再是卡点、随时能做。重建方案保留待用，重启时直接批准/修订即可。
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
- ✅ **② `is_line_walkable` 查表化**（2026-07-02）：`movement_line_clear` 布尔快路径（baked 逃逸规则孪生 + 保留精确形状段，无 DTO/clone），wrapper 切换；8 单位移动稳态 tick 0.78 → **0.17ms**。等价性常驻焊死 `smoke_sim_nav_movement_line_fast_path`（468 段：OOB/逃逸/格线 tie/mask 0/三种 filter/修复后/无 long 回退）。codex review：Medium（A/B 落库）+ Low（脏版本号防重复 repair，`dirty_navcell_revision`）已修。0ad lab 用自家带 unit 复合签名接口、消费完整 result，不在本刀范围。
- **② `is_line_walkable` 查表化**｜触发 = 单位规模 30+｜⚠️ 语义雷区已勘探：`_validate_line` = 栅格走线（0 A.D. 逃逸规则：可从不可通行格走出）+ 精确几何形状段，不是机械换 `segment_clear`；需带逃逸规则的 baked 孪生 + 保留形状段 + 独立 A/B｜验收 = 结果零变化 + 8 移动单位稳态 tick 0.78 → ~0.4ms
- ✅ **③ 移动管线 O(N²) 网格化**（2026-07-02）：实际挖出**三处** O(N²)——分离配对循环、接触转向逐单位全体扫描（Phase A 隐藏项）、`max_overlap_depth` 诊断统计（每 tick 全对）；全部换扁平网格链表（PackedInt32Array heads/next，倒序插入保升序 → 与暴力逐位同序），另加静态投影 AABB 预筛 + clamp 内联 + 平方距离预拒。100 单位：分散行军 **3.8ms**、死球最坏 **5.2ms**（原 ~20ms，3.9×）；9 单位默认走原暴力路径（173µs，手感零风险）。`smoke_dota2_lab_separation_hash` 焊死：41 单位现实群 240 tick 逐位一致（含中途换令）+ 致密堆硬不变量与复跑确定性。
- ✅ **④ budget smoke 套件**（2026-07-02）：`smoke_dota2_lab_perf_budget` 四条绊线（跨图规划 3ms / 预热后首查 3ms / 地形 flush 10ms / 100 单位分散行军 tick 10ms，阈值=实测 2-3 倍专抓渐进级回归）+ 结构断言（flush 必须走增量修复而非全量回退）。
- ✅ **⑤ GDExtension 铸模**（2026-07-03，专门会话 M0-M5 全落地）：方案+四项拍板+工具链 pin 见 [`gdextension-port-plan.md`](../../addons/sim-nav-map/docs/gdextension-port-plan.md)；`SimNavNative*` 类家族（map/jump 表/长径全链/hierarchical/facade/motion 求解器/后台队列），GDScript 永久默认 + C++ 可切换（lab `use_native`/`use_native_solver`）。A/B 焊死：M2 表逐字节（~25k 探针）、M3 查询逐字段（13 类矩阵+connectivity+flush 重放）、M4 600 tick 轨迹逐位（sinf/cosf CRT 1 ULP 漂移用 double-then-narrow 精确修复，零 ε）、M5 真后台规划（100 批 worker ~1.2ms 主线程 0 等待；固定延迟 T+1 收割防 core-019 类非确定性；飞行中冻结守卫防共享表突变竞态）。实测：规划 ~0.07-0.11ms（批内纯算 ~0.012ms）/ flush 0.44ms / 线检查 0.9µs / 100 单位全 native tick ~0.6ms。Windows dll + Web wasm（emcc 4.0.20 对齐官方模板，CDP 浏览器实证）双平台入库。每里程碑 codex review 全修（M2 2H/4M、M3 1P2/2P3、M4 2M/1L、M5 1H/2M/2L）。native smoke 组：simnav/native ×4 + dota2lab/native ×2，全量 62/62。

---

## 线 2 — inkmon 主项目

### 2a.（第一要务，✅ 已完成 2026-07-02）review `architecture-optimization-plan` —— 用户 + fable 讨论
- **做什么**：review [`docs/future/architecture-optimization-plan.md`](architecture-optimization-plan.md)，用 `/grill-with-docs` **跟用户讨论**有无建设性意见，**讨论并落地**。
- **谁做**：**用户 + fable 讨论**（grill）；Claude/Opus 不代跑。
- **相关**：`docs/future/architecture-optimization-plan.md`（P0/P1/P2 backlog，仅记录暂不执行 2026-06-13）。
- **进度（2026-07-02）**：① fable 复核 plan 有效性（2 处修订回写）；② R3 独立验证（fable 逐条读码 + 2 agent 核查，覆盖 44/47）：1 条证伪、数条修正与净增发现，回写 plan 头部 🗳️ 记录；③ 用户拍板：进化 stat gate = 纯成长不含装备；执行策略 = 三波全推；④ **三波已落地**（`inkmon/all` 21 smoke 全绿，明细见 plan 头部 ✅ 记录）；⑤ modal + drawer 下放亦完成（子场景控制器 ×2，root 972→776 行，开窗截图 harness 自验）——**2a 关闭**。核心文档（main-game-architecture / glossary）已同步 snapshot facade 措辞。注：`/grill-with-docs` 已不存在，讨论在会话内按 grill 纪律进行。

### 2b.（其次）大地图 vs 战斗地图的生成策略【◐ 大地图半边已定 2026-07-04；剩战斗地图】
- **大地图**：~~判断是自己拼、还是做地图生成算法~~ **✅ 已定（2026-07-04，P1/P2 grill 搭车拍板，用户 + fable）**：两层拆分——世界地理 = 开档 `new_game` 一次生成、永久固定、进据点档（每个存档一个独特世界）；趟内选路节点图（DAG）= 接委托后在固定地理上蔓延生成（"每局不同体验"的载体），住 `InkMonMissionState`（transient）。v1 减负：数据形状按"生成结果入档"定死，世界生成器 v1 极简/预制占位，DAG 生成器 v1 实做（固定 seed 即手摆兜底）。详见 game-vision §1 末 + glossary §4.8/4.9 + roadmap 判断#1（原"手摆 3-5 张"已作废）。
- **战斗地图**：进战斗后**一定是生成的**；看是**基于模板**还是别的做法；**战场不会大**。**仍开放**——不阻塞 Phase 1 出征骨架，**Phase 2 野群战斗接入时定**（与 P3 捕捉形态同窗 grill）。
- **谁做**：**用户 + fable 讨论**（剩余战斗地图半边同）。
- **相关**：[`docs/game-vision.md`](../game-vision.md)（游戏循环）、[`docs/gameplay-systems-roadmap.md`](../gameplay-systems-roadmap.md)。

### 2c.（再其次，低优先级）剩余问题
- 用户原话："那些问题没有 fable 我也能搞定，优先级不高"。**暂不展开。**

### 2e. inkmon 主游戏整体重新设计（用户 + fable）【📋 登记于 2026-09-17，未启动】
- **来源**：用户 2026-09-17 在 LGF 后续观察分诊中拍板：「inkmon 相关的代码我们不做任何处理，这个项目我需要重新设计」。
- **现状**：`inkmon/` 自 2026-09-17 起**冻结**——不做设计与行为改动；只允许 core API 改名/删除连带的机械改动（调用点改名、已死 `super` 覆盖删除、golden 重烤）。原挂在 inkmon 上的后续观察（`"intrinsic"` 常量化、board_reset weakref、0 血 carryover 占格、`Lambda capture freed`、B-1 的换集前 `revoke_abilities_where`、第 7 轮新记的周期 buff 冻结持有者 ATB——中毒 = 定身）全部并入本条，见 [`lgf-followups-2026-09-triage.md`](../plan/lgf-followups-2026-09-triage.md) §0 / §4 / §5 的 5b。
- **启动时做什么**：用户 + fable grill，先定范围与目标，再出方案；本条只登记，不预设方向。
- **约束**：启动前 LGF 侧先按 3c 收口（✅ 2026-09-17 已收口），重设计从干净的 core 起步；守 adr/0001 / 0002 除非重设计明确推翻。

### 2d. AI Runtime Control Service —— 外部 AI 像玩家一样操作主游戏（fable）
- **现状**：设计边界已锁，完整设计见 [`ai-runtime-control-service.md`](ai-runtime-control-service.md)（`PlayerActionPort` 三分 WorldAction/ViewAction/HostAction + `InkMonAiObservationProjector` 出 state+ASCII screen+available_actions + WebSocket/JSON + 薄 MCP adapter；含 §7 五步实现顺序 + §8 open questions）。
- **启动前置（硬门）**：**inkmon 基础游戏循环做完 / 可玩之后**才启动（用户明确要求排在基础循环之后）。
- **启动时 fable 做什么**：先解 §8 open questions，再按 §7 五步落地（PlayerActionPort → ObservationProjector → RuntimeServer(WebSocket+FIFO) → 薄 MCP server → runtime smoke: observe→move→interact→observe）。
- **谁做**：fable（先出实现切分再动手）。
- **约束**：不复用 DevAgentBridge、不模拟鼠标点击、不在 MCP/TS/Python 层重写规则、不进 Web bridge `Simulation.tscn`；守现有 CQRS 写侧 / Host 控制面 / UI 本地态边界。

---

## 线 3 — LGF 框架（`addons/logic-game-framework/`）

### 3. 修遗留问题 + 优化 hex-atb-battle 架构（fable）【✅ 完成 2026-07-03】
- **提案与执行记录**：[`addons/logic-game-framework/docs/proposals/2026-07-03-known-debt-and-hex-architecture-proposal.md`](../../addons/logic-game-framework/docs/proposals/2026-07-03-known-debt-and-hex-architecture-proposal.md)（头部含 6 轮 commit 锚点与偏差记录；该提案文档已随 2026-09 LGF 文档清场删除，历史归 git log）。
- **结果**：6 条债务全部了断（D1 recorder 家族迁 core/playback + REFRESH 组件钩子；D2 投射物迁 stdlib/projectile——原「反向依赖 ProjectileSystem」描述经查证不实；D3 裁决落地 = dict 总线转正 + 端点强类型化（AbilityActivate 补齐消灭全仓 6 处手写、删死类、visualizer 常量化/from_dict）；D4 最小 rename ReplayData→PlaybackData/load_replay→load_playback（web 桥协议零波及）；D5 门控 29 技能迁 bundle helper + SkillValidator 豁免字符串潜伏 bug 修正；D6 维持不修——触发条款未满足）。hex 架构优化：H1 hex core/ 双向依赖归位（core/ 只剩共享事件）；H2 skill_preview 6607→5083 行（Inventory/Timeline 双子控制器最小档，完整档与 item_preview 合并留观察）；H3 一致性清理（actor-kind/kind 常量化、双日志合一、亡灵注释）。
- **过程纪律**：每轮 = 实现 → 全量测试 → V1 一致性 review（agent 对照计划核对 diff）→ codex review（修 findings）→ commit；六轮累计 codex 2 findings / V1 3 处遗漏全部修复归零。
- **仍挂账（观察项，另立轮次）**：timeline 骨架 helper、BaseAction→PrimitiveAction 归类批量迁移、logic/ai + battle_logger 测试空白、dota2 事件模式统一（原留 1c；1c 已搁置，继续挂账）。录像 v3 已升级为正式条目 3b（见下）；skill 文档结构性同步 ✅ 已完成（2026-07-03，enforcing-lgf 12 文档全量校准 +807/-328，update.json 基线重锚——旧基线因 addons 仓合并断链）。

### 3b. 录像格式 v3 — split world_snapshot + event_timeline（fable）【✅ 完成 2026-07-03】
- **提案与执行记录**：[`2026-07-03-playback-v3-format.md`](../../addons/logic-game-framework/docs/proposals/2026-07-03-playback-v3-format.md)（头部含执行偏差 ①-⑨；该提案文档已随 2026-09 LGF 文档清场删除，历史归 git log）—— 7 项拍板全部落地：录像 = `{meta, world_snapshot{actors,mapConfig,positionFormats}, timeline}`、无 version、快照由 `WorldGameplayInstance.capture_world_snapshot()` 产出（`should_record_actor()` 范围钩子——codex 抓到常驻世界会把 overworld 玩家/NPC 拍进战斗回放，已修）、旧双路径删除、三 procedure override 全删、actor 订阅保留（attributeChanged 是 inkmon render2d 消费的真管道——events-only 注释系误导）。全量 65/65 绿，golden 重烤（逻辑零漂移）；V1 + codex 双 review 归零。**JS 端解析器欠账**（web 发布启用时同步，SimulationManager 注释在案）；大小优化三方案继续挂账。
- **动机**：「世界 owns 战斗」的录像侧收尾——世界常驻持有 actor 后，战斗录像原则上只该记事件流；v2 的 initialActors/mapConfig 快照与 WorldGI 职责重叠。可搭车裁决录像大小优化 3 方案（`battle_recorder.gd` 头注释：事件白名单过滤 / 高频事件节流 / 二进制格式）。
- **现状（2026-07-03 核实）**：core 钩子已铺——`BattleRecorder.start_recording_events_only()` 已实现且是 `BattleProcedure._start_recorder()` 的默认；但**零生产使用者**，三个 procedure 全 override 回旧版全快照路径：hex（`hex_battle_procedure.gd:69`，注释明言等 v3 落地再切）、skill-preview（`skill_preview_procedure.gd:65`）、**inkmon 主游戏（`ink_mon_battle_procedure.gd:34`，adr/0005 显式决策：全量录像让 2D 回放 animator 能从录像独立重建开战阵容）**。`PROTOCOL_VERSION` 停 "2.0"，web/JS 桥消费 v2 顶层 key。
- **启动时 fable 做什么**：先出格式提案过目——① world_snapshot 的定义与归属（录像同文件字段 / 分离产物 / 播放时复用现有 world）；② 播放侧改造：A 层 Playback 与 inkmon 2D animator 的 initialActors 依赖怎么迁，**须与 adr/0005「从录像独立重建阵容」的意志对表**（v3 对 inkmon 的正确答案可能是 world_snapshot 承载阵容，而非放弃快照）；③ web/JS 桥协议兼容（PROTOCOL_VERSION 升 "3.0" 或双格式并存）；④ 大小优化 3 方案是否搭车。批准后再切三个 procedure。
- **约束**：「录像顺序 = 调用栈真实顺序」「Playback 不重建逻辑层」两条铁律不动；web 桥外部消费方（JS/cloud）兼容优先；先提案后代码。
- **相关**：`addons/logic-game-framework/core/playback/battle_recorder.gd`（头注释 + events_only 实现）、LGF `CLAUDE.md`「World owns Battle」节（原 `docs/README.md` §World owns Battle (c)，该文档已随 2026-09 文档清场删除）、主仓 `docs/adr/0005-presentation-true-2d-isometric-hex.md`。

### 3c. 清 LGF core 重构的 §6 后续观察（fable）【✅ 完成 2026-09-17】
- **来源**：[`docs/plan/lgf-core-refactor-2026-09.md`](../plan/lgf-core-refactor-2026-09.md) §6「后续观察」。本轮重构（P1–P10 + 四题拍板 + 随机战斗差分，2026-09-14 收口，两仓已 push）执行纪律是「范围外发现记一行、不顺手修」，十个阶段加一次整体审累积出这张表。
- **现状（登记时 2026-09-14）**：38 条，构成 = 早于本轮的既有问题 23 条 / 本轮衍生或明确保留的设计选择 11 条 / 基线参考数字 2 条（不是待办）/ 环境偶发 2 条。每条是「一行发现 + 一句修向提示」，**不是 spec**：条目大小从「删一个兜底」到「actor id 改由工厂派发」跨度极大，风险与验收面也不同。已关闭的条目在 [`lgf-core-refactor-2026-09-deviations.md`](../plan/lgf-core-refactor-2026-09-deviations.md) 的「已关闭的后续观察」节。
- **启动时 fable 做什么**：**先分诊，不要开工**。① 逐条复核是否仍复现——本轮改动已顺带消掉一部分，表上未必都更新了；② 按「能一批修完的 chore / 要单独设计并拍板的 / 只是信息不动」分桶，每桶给出条目清单与一句代价估计；③ 把分桶结果交用户拍板，由用户决定这次动哪一桶。批准后才进执行。
- **约束**：不整轮吞下 38 条；一桶一轮、一轮两仓各一个 commit；执行沿用本轮已验证的验收机械（钉子先行 → 新行为测试先红后绿 → 全量组 + 释放测试 → 两关自查 → 规则之家 → 不 push）；`hex/random-golden` 与 inkmon golden 指纹漂移一律先解释再重烤；范围外的新发现照旧记回 §6，不顺手修。
- **进度（2026-09-17，用户 + fable）**：分诊 + B 桶 10 条逐条拍板完成，记录在 [`docs/plan/lgf-followups-2026-09-triage.md`](../plan/lgf-followups-2026-09-triage.md)（分桶总表 / B 桶拍板 / 规则之家新增两条判据 / 执行顺序与各轮 hash）。本轮新约束：**inkmon 冻结**（见 2e），只允许机械改动；核心 = LGF + example 设计好。B-8 作废、B-9 改为删 `lgf-new-logic-skill`。执行按桶分轮，同日七轮全部落地（按落地顺序列出；每轮两仓各一 commit，执行方不 push、由用户手动 push）：
  - 第 3 轮 B-9 删 skill：addons `7182e8f` / 主仓 `93caa156`（表演层接入清单迁 hex frontend README）。
  - 第 1 轮 B-core（B-1 / B-3 / B-4 / B-6）：addons `09ac4ee` / 主仓 `df17d9a0`，deviations FU1-1～8；配套 launcher 按 `EXPECTED_SCRIPT_ERRORS: n` 恰好放行。
  - 第 2 轮 B-hex（B-2 / B-7 / B-5 / B-10）：addons `a66d3d9` / 主仓 `12362171`，deviations FU2-1～13；`hex/random-golden` 按解释重烤（B-2 预期漂移：5 seed 只差 `projectile_despawn` 位置）。
  - 第 4 轮 A1 十一条：addons `df86d90` / 主仓 `2c8beba9`，deviations FU4-1～12；`all` 130/130，golden 零漂移。
  - 第 6 轮 执行中新记回的三条（`revoke_ability` 按对象除名 / `base_tick` 走系统表快照 / 用户拍板 A 删 `u_grid_map.gd`）：addons `ebf97c8` / 主仓 `7a31bdaf`，deviations FU6-1～8；隔离 worktree `all` 130/130（core 单测 246），golden 零漂移；§6 这三条关闭（22 → 19）。
  - 第 5 轮 A2 六条：addons `d15162f` / 主仓 `3c6c0b84`，deviations FU5-1～20；`all` 131/131（core 单测 255，hex/regression +1 `smoke_tick_loop_removal`）；`hex/random-golden` 与 inkmon golden 逐条差分归因后重烤（末帧 +in_combat 清除的 `tag_changed` / `ability_granted` 少 `instance_id` 键 / seed 900083 +3 条 `attribute_changed` / 两个 seed 各少 1 条已离场 actor 的 `ability_removed`；type id 与快照遍历零漂移，胜负 / 帧数全同，inkmon 指纹 3014638374 → 3099257976）；§6 六条关闭、新记三条待拍板（hex 主循环存活名单含本帧已死者 / 周期 buff 冻结 ATB / Stun 取消动作注释不符）（19 → 16）。
  - 第 7 轮 A2 新记回的三条（用户逐条拍板 A / A / A：hex 主循环逐个判 `is_dead()` / ATB 阻塞改白名单只认 `active` · `action` / Stun 取消动作只改注释）：addons `0e5de9c` / 主仓 `3fa7578e`，deviations FU7-1～20；`all` 132/132（core 单测 255，hex/regression +1 `smoke_action_tags`）；`hex/random-golden` 逐条差分归因后重烤（① 五个 seed 少掉尸体当帧的起手与在飞 keyframe、胜负 / 帧数全同；② 五个带中毒 / 涌动 / 恶魔形态的 seed 从持有者首次恢复行动起分叉、四个胜负翻转；③ 零漂移），inkmon 指纹不变；§6 三条关闭、新记一条 inkmon 同形半条（16 → 14，余下均为 inkmon 冻结 / 基线参考 / 信息 / 候选刀 / 环境偶发，LGF 侧无待办）。
  - **收口（2026-09-17）**：§6 从 38 条收到 14 条——前四轮关闭 19、新记 3（`revoke_ability` 下标左移 / `u_grid_map.gd` 孤儿脚本 / `base_tick` 遍历中 `add_system`，见 triage §4）→ 22；第 6 轮关闭这 3 条 → 19；第 5 轮关闭 6、新记 3 → 16；第 7 轮关闭这 3 条、新记 1 → 14（累计 38 + 7 新记 − 31 关闭，与 deviations「已关闭的后续观察」节 2026-09-17 关闭的 31 条对得上）。余 14 条 = triage C 桶 11 + D 桶 2 + 第 7 轮新记的 inkmon 同形半条 1，按性质 = inkmon 冻结 5（含 D 桶的 `Lambda capture freed`，随 2e）/ 基线参考数字 2 / 信息 · 已定 5 / 候选刀 1（actor id 工厂派发，未排期）/ 环境偶发 1（`smoke_skill_validator` 退出期 AV，遇到时单跑复核）；**LGF 侧无待办，3c 关闭**。inkmon 半条与 B-1 采纳随 2e。

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
| 3 | LGF `CLAUDE.md`「已知债务」节（原 `docs/README.md`，已随 2026-09 文档清场删除）· `.../example/hex-atb-battle/README.md` |

---

> **状态**（2026-09-17 刷新）：✅ 完成 = 1a · 1b · 1d · 2a · 线 3 · 3b · 3c；⏸️ 搁置 = 1c；◐ 半定 = 2b（大地图半边已定，剩战斗地图 Phase 2 定）；📋 待启动 = 2c · 2d · 2e（inkmon 重设计，2c/2d 随之重估）。启动某项时，把该项从"登记"推进为"进行中"，产出物（review / 方案 / 提案）另起文档或落到对应区域，本文件只维护队列态。
