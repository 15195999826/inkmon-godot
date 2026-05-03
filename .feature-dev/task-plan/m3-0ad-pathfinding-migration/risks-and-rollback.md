# M3 Risks & Rollback

> 父文档: [`README.md`](README.md)
>
> 每个 milestone 的回退点 + 已知风险跨 milestone 视图。runner 在某 milestone 末验收挂时按本文档定位 + 回退。

---

## 0. 总体风险地图

| 风险等级 | 范围 | M0-M8 中最危险点 |
|---|---|---|
| **🔴 P0 (stop runner 立即定位)** | replay bit-identical 漂 / 14 项 smoke 数字漂 | M5 (LongPath 重写) / M7 (UnitMotion 重写) |
| **🟡 P1 (审阅但可继续)** | perf ≥ 50% 慢 / baseline CSV 预期外字段变化 | M3 (clearance inflate) / M6 (vertex 复杂) |
| **🟢 P2 (已知,接受)** | trace 新字段从占位变实填 / 体验点视觉差异 | 每 milestone |

---

## 1. 跨 milestone 风险类别

### 1.1 Replay bit-identical 漂(P0)

**症状**: `smoke_replay_bit_identical seed=42 frames=9 events=20 deep-equal` FAIL

**首要怀疑点**(按概率):
- M2: ObstructionManager `_shapes` 迭代序错误(走了 Dictionary 内部序而不是 sort by tag)
- M4: HierarchicalPathfinder edges Dictionary 迭代序错误 / GlobalRegion BFS 起点顺序错误
- M5: LongPath A* heap 5 元组比较 bug(未严格按 lex 顺序)
- M6: VertexPath candidates 生成顺序错(漏了 obstruction.tag, corner_index 字典序)
- M7: Motion tick 顺序非按 `(kind, spawn_seq)` 数值复合 key(R5 P1 #1 修订;不再走 `actor.get_id()` 字典序)

**定位流程**:
1. 跑 `tools/oos_log.gd`(M5 启动前置):master vs current branch 各跑一遍 → 第一个 hash 不同的 (tick, entity) 即漂移源
2. 从 [data-structures §12](data-structures.md#12-determinism-总排序-contract-codex-p1-4) 7 个子节逐条核对哪条违反
3. 修后 stop runner 让 codex review 修订

**回退**: revert 当前 milestone commit + submodule pointer(主仓 + submodule),回到上 milestone stable。

### 1.2 Perf 退化超 50%(P1)

**症状**: `tools/perf_trace.gd` 报告本 milestone vs 上 milestone wall_clock 增长 > 50%

**首要怀疑点**:
- M3: clearance inflate brute-force 跟 building 数量平方增长
- M4: hierarchical recompute 全图重算太慢 → 应触发 M4c update 增量
- M5: A* SortedArray O(N²) heap → 换 binary heap
- M6: VertexPath O(V²) lazy visibility 大 search box 时炸
- M7: motion tick 6 步重序内层 sort 重复

**响应**:
- ≤ 50%:接受(GDScript vs C++ 差距,记录,不阻塞)
- 50-100%:flag 用户,可视情接受 / 优化
- ≥ 100%(2× 慢):stop runner,做针对性优化(e.g. 换 SortedArray → binary heap;brute-force inflate → EDT)
- ≥ 300%(3× 慢):重新审视设计,可能要重拆 milestone

**回退**: 不回退,但启动 perf 优化轮(独立小 task)。

### 1.3 Baseline CSV 漂(P1 / P2 取决于字段)

**症状**: 跑 `smoke_pathfinding_baseline` 两次 byte diff 出现差异

**先区分类型**:

| 字段类型 | 漂移含义 | 处理 |
|---|---|---|
| 已实填字段(M0-M3 的 tick / unit_id / px / py / activity 等) byte 差 | replay 漂(同 1.1) | 🔴 P0 |
| 新字段从占位 -1 / "" 变实填(预期变化) | 该 milestone 引入新功能,字段开始有值 | 🟢 P2,接受新 baseline |
| 已实填字段值整体偏移(unit 路径变化但行为正确) | 算法升级(M5 LongPath / M6 VertexPath / M3 inflate)预期改变 | 🟡 P1,跑 demo 视觉确认 OK 后接受新 baseline |

**接受新 baseline 流程**:
1. 跑 smoke 双次确认 byte-identical(本 run / next run 一致)
2. copy CSV 到 submodule `tests/baselines/0ad-baseline-master.csv`(覆盖)
3. submodule commit(commit message 含 milestone + 字段变化原因)
4. 主仓 bump pointer

### 1.4 LGF submodule 边界违规(P0,unrecoverable)

**症状**: 改了 `addons/logic-game-framework/core/` 或 `stdlib/` 内文件

**响应**: stop runner,问用户。原则上 M3 Epic 不动这两层。

---

## 2. Per-milestone 回退点

### M0

**Rollback ID**: M0-stable (LGF submodule sha + 主仓 bump pointer)

**条件**: M0.1-M0.7 全 done + 14 项 smoke + LGF + replay 0 漂移 + 体验点 ✋1 通过

**Rollback 操作**:
```bash
# Submodule
cd addons/logic-game-framework
git reset --hard <M0-stable-sha>
cd ../..
# 主仓 bump pointer
git add addons/logic-game-framework
git commit -m "rollback to M0-stable"
```

### M1

**Rollback ID**: M1-stable

**条件**: M1.1-M1.5 全 done + RtsCell 类删除 + Validation

**特殊回退**: M1 删除 RtsCell 类是 destructive,回退后注意:
- M1.3 删除的 RtsCell 类要从 git 历史 restore
- 凡是 grep 不到的 deep callers(M1 没列全)需要重新整理

### M2

**Rollback ID**: M2-stable

**条件**: ObstructionManager 落地 + spatial index + placement / spawn / move 链路全迁

**特殊回退**: M2 RtsBattleGrid `_placement_map` 已删,回退要恢复;同时 M2 引入的 6 个 EFlag 同步。

### M3

**Rollback ID**: M3-stable(✋ 体验点 1 完整修复 准备)

**条件**: clearance 外扩工作 + per-class buffer 独立

**baseline 接受**: M3 trace 路径变化预期(单位绕建筑路径变宽 1 navcell)。回退要恢复 M2 baseline。

### M4 (✋2 体验点)

**Rollback ID**: M4a / M4b / M4c 各 sub-phase 独立

**条件**: hierarchical recompute + canonicalize + 体验点 ✋2 通过

**回退到 sub-phase**: M4c 失败 → 回 M4b stable;M4b 失败 → 回 M4a stable;M4a 失败 → 回 M3 stable

### M5

**Rollback ID**: M5-stable

**条件**: LongPath A* + RtsBattleGrid facade 删除 + Validation

**特殊回退**: M5 删除 RtsBattleGrid + GridPathfinding 是 destructive。回退需要 git restore + 重新 wire。

**replay 漂移高风险**: A* tie-break 5 元组未严格遵守时漂。M5 之前先准备 OOSLog (`tools/oos_log.gd`)。

### M6 (✋3 体验点)

**Rollback ID**: M6a / M6b / M6c 各独立

**条件**: 7+2 细节全实现 + 体验点 ✋3(贴墙绕角)通过

**回退到 sub-phase**: M6c 失败 → 回 M6b stable(短路径无 dynamic units / group filter);M6b 失败 → 回 M6a stable(短路径无 virtual goal / terrain edges,只 static OBB)

**最难一层**: M6 启动前 prototype scene 验算法,production VertexPathfinder 末端再替换。

### M7 (✋4 体验点)

**Rollback ID**: M7a / M7b / M7c / M7d 各独立

**条件**: UnitMotion 完整 + Activity 全迁 + 体验点 ✋4 通过

**回退到 sub-phase**:
- M7d 失败 → 回 M7c(motion 工作但 activity 仍用旧 nav_agent 调用 / 部分迁完)
- M7c 失败 → 回 M7b(motion path storage + lifecycle OK 但 obstruction sync 缺)
- M7b 失败 → 回 M7a(motion 字段落地但状态机不工作)
- M7a 失败 → 回 M6 stable(整 motion 重写 abort)

**特殊回退**: M7c 删除 RtsNavAgent / RtsUnitSteering 是 destructive。

### M8 (✋5 体验点)

**Rollback ID**: M8-stable

**条件**: push pass + control_group 启用 + 体验点 ✋5 通过

**回退**: 关 push pass 走 M7 stable。

---

## 3. Stop Runner 触发条件

任一条件触发,autonomous-feature-runner 立即停下问用户:

1. **🔴 replay seed=42 deep-equal FAIL**(任意 milestone)
2. **🔴 14 项 smoke 任一项数字漂**(已实填字段 byte diff)
3. **🔴 LGF 73 unit test 任一 FAIL**(M3 Epic 不该影响 LGF core)
4. **🔴 LGF submodule core/ 或 stdlib/ 内文件被改**(违反 D4)
5. **🟡 perf `tick_p99` / `tick_max` 增长 ≥ 100% (2×)**(超 AC-EPIC-7 上限,以新主指标为准 — R5 反馈,不再用 `wall_clock_ms`)
6. **🟡 baseline CSV diff 包含 已实填字段值变化** 但**不在预期算法变化范围**(M3 inflate / M5 LongPath 算法变化是预期;M2 / M4 / M7 / M8 不应改路径)
7. **🟡 体验点 ✋N 用户跑 demo 反馈不通过** (功能性问题,非视觉小毛病)
8. **🔴 R5 P1 #2 dirty lifecycle invariant 违反**(任一路径在 RtsWorld.tick step 5-6 中间清 dirty,导致 hierarchical update 拿不到完整 dirty 集合)— M3.4 + M4 smoke 必须验证此 invariant
9. **🔴 R5 P1 #1 actor sort 用了字符串字典序而非 `(kind, spawn_seq)` 数值复合 key**(M7 引入 sort 时漂)— `smoke_motion_tick_order_with_10plus_units` 必跑且 ≥ 10 unit 排序正确

Stop 后流程:
1. runner 写 stop reason 到 `.feature-dev/Progress.md`
2. 用户审阅,决定继续 / 回退 / 重设计
3. 修复 → 重跑当前 milestone 末验收 → 通过后继续下一 milestone

---

## 4. 已知遗留风险(Epic 启动前预判)

| # | 风险 | 缓解 |
|---|---|---|
| R-EPIC-1 | M5/M6/M7 时 replay bit-identical 漂移,定位耗时 | M0 启动前先生成 baseline replay (`smoke_pathfinding_baseline.tscn` Agent 已落地);漂移立刻 stop runner,人工 OOSLog 风格定位 |
| R-EPIC-2 | M6 visibility graph 几何写错难调试 | M6a 启动前先 prototype 一个独立 scene 跑通,再正式整合 |
| R-EPIC-3 | M7 时 RtsActivity (attack / gather / build) 受 motion 重写影响 | M7d 把所有现有 activity 当 acceptance 子项,逐个 verify |
| R-EPIC-4 | 我们对 0 A.D. 内部细节理解不全 | 每个 milestone 启动时再过一遍对应 0 A.D. 源码(`addons/.../docs/references/0ad-source/` 已有本地副本);未知细节先用复刻值,事后调优 |
| R-EPIC-5 | 性能回归(GDScript 实现位掩码 / 空间查询比 C++ 慢 50-100×) | AC-EPIC-7 接受最多 100% 慢(2× C++ baseline),超出再针对性优化;不预先 GDExtension 化 |
| R-EPIC-6 | UI 方面(frontend) 跟 logic 重构同时改 → 互相干扰 | M0 是 frontend 唯一改动,后续 M 全部 logic-only,frontend 不动 |
| R-EPIC-7 | LGF submodule 边界违规 | 任何代码进 `example/rts-auto-battle/`;若发现需要改 core 立刻停下问用户 |
| R-EPIC-8 | 用户中途想加范围(Formation / Vision / Stance)| 默认拒绝,记入 deferred,这次 Epic 不开 |
| R-EPIC-9 | M0.5 sync_obstruction_shape() call sites 漏(diagnostics/smoke 路径)| Step B 实施 M0 前 grep `tests/**/*.gd` 找 `create_*` 后直调 `get_footprint_cells()` 路径,补充 sync;§11.6.4 / §11.7.3 已记录 |

---

## 5. 应急 Rollback 速查

| 当前在 | 怀疑挂在 | 回退到 |
|---|---|---|
| M5 | A* tie-break 漂 | M4 stable |
| M5 | RtsBattleGrid facade 删除引发 deep call 错 | M5 启动前(undo facade 删除)|
| M6c | dynamic unit proxy 几何错 | M6b stable |
| M7c | tick 顺序错 | M7b stable |
| M8 | push pass 力度过大引入抖动 | M7 stable + 关 push |
| 任意 | LGF submodule 内文件被改 | git submodule reset + ask user |

---

## 6. 决策来源

- 风险 R1-R8 列表: README §8(Epic 启动前预判)
- 跨 milestone 触发条件: validation-strategy §6 checklist
- 0 A.D. OOSLog 概念: 0 A.D. simulation 内部 OOS 探测协议
