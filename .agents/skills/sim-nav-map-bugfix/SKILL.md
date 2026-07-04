---
name: sim-nav-map-bugfix
description: "`addons/sim-nav-map` 寻路/运动细节 bug 修复流程（现役 example = `dota2-rts-pathfinding-lab`）：probe_log.py 切片导出日志 → 拷 smoke 骨架做最小复现 → 按层修（core/寻路层以 0 A.D. 源码为准，motion/手感层以 fable-motion-design.md 设计意图为准）→ 写带注释的回归测试锁定。Use when 用户提供 `DOTA2_RTS_LAB_EXPORT_LOG: …` 路径并描述视觉异常，或明确说要修 sim-nav-map / dota2 lab 寻路 bug。"
---

# Sim Nav Map — 细节 Bug 修复流程

适用场景：用户描述 dota2-rts-pathfinding-lab 视觉异常（卡死 / 穿模重叠 / 绕远 / 推挤异常 / 指令没反应等），并附上 `DOTA2_RTS_LAB_EXPORT_LOG` 的 JSON 路径（lab 内按 E 或点「导出日志」产出）。

**核心心法（双轨）**：先判 bug 属于哪一层，再选基准——

- **core / 寻路层**（`SimNav*` 类家族：long path / vertex / LOS / clearance / hierarchical）→ 每个 bug 都是偏离 0 A.D. 的具体一处，修复 = 让那一处回到 0 A.D.，不是发明新策略。
- **motion / 手感层**（lab 的 `Dota2LabMotionEngine`：分离求解 / 接触转向 / watchdog / 到达语义）→ 自研设计，基准是 `examples/dota2-rts-pathfinding-lab/docs/design-notes/fable-motion-design.md` 的设计意图。**先确认现象不是设计语义**：`arrived_partial`（目标不可达，停最近可达点）、`arrived_crowded`（目标被人群占住，近旁 settle）、一次 replan 后 `stalled` 判死（`MAX_REPATHS = 1`）都是拍板行为，不是 bug。

## 三步流程

### Step 1. 先复现

不到能确定性复现，**不进 Step 2**。

#### 1a. 切片 log 找最小复现单位

直接用 skill 自带的 helper（替代手写 `python -c json.load`）：

```bash
python .Codex/skills/sim-nav-map-bugfix/probe_log.py <log.json>
# 聚焦某 unit / 事件类型 / tick 段
python .Codex/skills/sim-nav-map-bugfix/probe_log.py <log.json> --unit fast_0
python .Codex/skills/sim-nav-map-bugfix/probe_log.py <log.json> --kind order_failed --tick-range 200:600
```

输出 = meta + units 表（state / stall / repath / last_order，硬失败带 `FAILED_HARD` 标记）+ order 事件 (kind, reason) 计数与 tail + slow frames + UI 事件流 + metrics 概要。

关键信号：

| 信号 | 含义 |
|---|---|
| `last_order` = `failed:stalled` | watchdog 判死（约 1.5s 无净位移 + 唯一一次 replan 用尽） |
| `last_order` = `failed:no_path` | 规划失败（连最近可达点都给不出） |
| `stall_seconds` 增长且 state=MOVING | 正在走向 stalled 的路上 |
| `repath_count` 已到 1 之后再 stall | 重规划救不回来，路径本身判死 |
| `last_step_stats.max_residual_overlap` 高 | 分离求解没收敛（穿模 / 重叠类） |
| `last_step_stats.plans_waiting` 持续 > 0 | 规划队列堵（时间切片 1 query/tick） |
| `slow_frames` 有条目 | 单步尖刺（≥ 3ms，常见 = plan burst） |

`completed:arrived_partial` / `completed:arrived_crowded` 出现在这里**不是异常信号**，见上方设计语义。

schema 防腐：schema id 与主干字段由 addon 侧 `tests/smoke/smoke_dota2_lab_ui_ops.gd::_assert_export_shape` 锁定，但细字段不在断言面内——导出侧改动后若切片输出成片 None，先对照 `_build_export_snapshot()` 再下结论；probe_log.py 自带 schema guard，不认识的 log 直接拒读。

#### 1b. 最小复现 probe：拷 smoke 骨架

dota2 lab 没有独立 probe 模板，**也不需要**：管线是 `Dota2LabWorld.step()` = 逐 motion layer 各调一次 `motion.step(units, pathfinder, delta, tick)`——无 flyer 时就一次；有 flyer 时先 air 后 ground 两次，层间无交互力（`dota2_lab_world.gd` 的 `step()`）。commit-then-resolve 三相，engine 无状态、单位状态全在 `Dota2LabUnit`、数组序迭代确定，没有可绕过的记账，最小复现 = 直接构造 world 跑 step 循环。

拷 `examples/dota2-rts-pathfinding-lab/tests/smoke/smoke_dota2_lab_move_basics.gd` 的骨架改：

```gdscript
# 骨架：_open_world(units, obstacles) → world.issue_move(id, goal) → _run_until_idle(...)
var unit := Dota2LabUnit.new("solo", "blue", Vector2(150, 450), 11.0, 110.0, true)
var world := _open_world([unit], [Dota2LabObstacle.new("block", Vector2(650, 450), Vector2(120, 120))])
world.issue_move("solo", Vector2(650, 450))
# step 循环后断言：unit.state / unit.last_order 的 status:reason / unit.position
```

- 用导出 log 里 units / obstacles 的坐标回填 fixture；`Dota2LabWorld.new()` 默认场景 = 手动 lab 同款地面阵容（三速度档 8 mobile + red_blocker + 走廊三障碍），可直接用
- 临时 probe 放 `.Codex/tmp/`（临时目录），`.tscn` 三行指向脚本，`godot --headless --path . .Codex/tmp/<probe>.tscn`
- 复现是确定性的：同 fixture 同指令序列 → 逐位一致，跑一次就能断言

不到能 probe 复现，**不进 Step 2**。

### Step 2. 按层修

#### core / 寻路层：以 0 A.D. 为准

**禁止**：引入 0 A.D. 没有的 magic number / cooldown / 节流 / 阈值。已踩过的反例：
- `SHORT_REPATH_COOLDOWN_SEC = 0.22`（自创节流）
- `waypoint_spacing = cell_size * 4`（应跟 0 A.D. `SHORT_PATH_MIN_SEARCH_RANGE - 1`）
- LOS directional 分支额外的"切线 = block"检查（0 A.D. 是 binary）
- vertex graph 不过滤被覆盖角（0 A.D. `VertexPathfinder.cpp:727-734` 过滤）

**强制**：
1. 改之前 → 读 `addons/sim-nav-map/docs/references/0ad-source/` 对应文件，**不是** audit 文档、**不是**记忆
2. 命中具体函数 + 行号（例：`CCmpUnitMotion::PostMove` 在 `CCmpUnitMotion.h:1131-1160`）
3. 修复说明里引用源码出处
4. core 行为改动必须同步 native 孪生——GDScript 是参考实现，C++ 侧不同步会挂 `simnav/native`、`dota2lab/native` 的 A/B weld smoke

常用源码入口（去 `docs/references/0ad-source-map.md` 查全表）：

| 主题 | 入口 |
|---|---|
| Long-path waypoint 间距 | `CCmpUnitMotion.h:RequestLongPath`（`improvedGoal.maxdist`）|
| Short-path 触发时机 | `CCmpUnitMotion.h:PostMove` + `HandleObstructedMove` |
| Vertex graph 过滤 | `VertexPathfinder.cpp:727-734` |
| Directional LOS | `Geometry.cpp:TestRaySquare` / `TestRayAASquare` |
| Clearance buffer | `Pathfinding.h:CLEARANCE_EXTENSION_RADIUS` |

#### motion / 手感层：以 fable-motion-design.md 为准

1. 改之前 → 读 `examples/dota2-rts-pathfinding-lab/docs/design-notes/fable-motion-design.md` 对应小节，确认现象不是拍板语义
2. 修复不得破三条设计不变量：**位移永远沿 facing**（推挤只动身体不动意图，v1/v2 的 ice-drift / 横移观感就是破了这条）、**每条 order 有界终止**（无 holding / retry 态）、**engine 无状态**（状态全在 unit，engine 可驱动任意 unit 列表）
3. 调参（pushability / steer 权重 / watchdog 阈值）前先答"是常量错了还是机制错了"——常量改动要能引用设计文档对应段落说理

### Step 3. 锁定回归测试

位置分两类：
- **core 层** → `addons/sim-nav-map/tests/repro/repro_core_NNN_<short_name>.{gd,tscn}`，追加进 `addons/sim-nav-map/tests/test_groups.json` 的 `smoke` 组；NNN 取 `tests/repro/` 与 `docs/issues/` 两处已用 CORE 编号的最大值 +1（当前下一个 = 022）
- **motion / lab 层** → lab `tests/smoke/smoke_dota2_lab_<name>.{gd,tscn}`，追加进 lab `tests/test_groups.json` 的 `smoke` 组（跟随 stall_watchdog / separation_hash 的既有写法）

**强制注释三段**（顶部）：

```gdscript
# CORE-NNN（或 smoke 名）: <一句标题>
#
# Bug reproduced here:
#   - 现象：单位 X 在场景 Y 出现 Z（数值 + 关键 (start, target, blockers)）
#   - 根因：<文件:行> <偏离基准的具体点>
#
# Expected（core 层：0 A.D. <file:line>；motion 层：fable-motion-design.md <小节>）:
#   <基准做法的简短描述>
#
# Before fix: <断言失败的具体输出>. FAIL.
# After fix: <断言通过的具体输出>. PASS.
#
# Run: godot --headless --path . <scene 路径>.tscn
```

测试结构：构造最小 fixture（core 层 = `SimNavMap` + obstacles + 一次目标 API 调用；motion 层 = `Dota2LabWorld` + issue_move + step 循环），断言关键不变量（path 不空 / 不后退 / state 与 last_order reason / 位置界限）。

跑 `./tools/run_tests.ps1 simnav/all dota2lab/all`（~1 分钟 53 scenes，含 native A/B weld），确保全过。

如果旧 smoke 是 lock-in negative test（expect bug exist），**翻转**断言并加注释说明何时翻转、为何翻转。

## 反模式（别做）

- 复现没成功就"先试着改"
- 改完只跑 `dota2lab/*`，没跑 `simnav/*`（反之亦然）；core 行为改动漏跑 native A/B
- 修了 bug 没写 repro，下次回归发现不了
- repro 文件没写"Bug reproduced here / Expected"注释，半年后忘了为啥这么测
- 加魔术常量"压低出现概率"代替治根因
- 只看单 tick 不跑 multi-tick——累积漂移 / 推挤震荡类问题单步看不出来，复现循环至少跑到 order 终止
- **把设计语义当 bug 修**（`arrived_partial` / `arrived_crowded` / 单 replan 判死）——先对 `fable-motion-design.md`，要改语义先跟用户确认是改设计不是修 bug

## 已存案例（参考写法）

core 层（0 A.D. 对齐，`addons/sim-nav-map/tests/repro/`）：
- `repro_core_001_vertex_obb_outset.gd` — OBB 顶点 outset 方向错
- `repro_core_005_clearance_extension.gd` — clearance 扩展余量
- `repro_core_008_covered_vertex_first_waypoint_regression.gd` — 被覆盖的 vertex 导致 short path 首段后退（mirrors `VertexPathfinder.cpp:727-734`）
- `repro_core_009_directional_must_not_pierce_other_unit.gd` — directional 不能让 segment 穿其他 obstacle 中心
- `repro_core_010_boundary_tangent_no_detour.gd` — boundary band 切线噪声不该 reject 整段
- `repro_core_011_short_path_best_vertex_fallback.gd` — A* 失败时返回 closest-to-goal vertex（mirrors `VertexPathfinder.cpp:868-900` `idBest`）
- `repro_core_012_boundary_motion_step_not_stay.gd` — boundary stay-rule 仅适用真 overlap
- `repro_core_013_boundary_step_b_inside_no_early_block.gd` — boundary band 不该有 b-inside 早返
- `repro_core_014_overlap_escape_must_be_strict_binary.gd` — 真 overlap 严格 binary（mirrors `Geometry.cpp:280-281`）

known limitations（lock-in，不是 bug）：
- `repro_core_017_dense_cluster_perimeter_detour_known_limit.gd` — 密集 unit cluster 的 perimeter detour 是 visibility-graph inherent 行为

motion / lab 层（写法参考，lab `tests/smoke/`）：
- `smoke_dota2_lab_move_basics.gd` — 到达 / 绕障 / canonicalized goal / cancel 契约 + no-sideways 管线守卫（v1/v2 ice-drift 回归）
- `smoke_dota2_lab_stall_watchdog.gd` — watchdog 判死语义
- `smoke_dota2_lab_separation_hash.gd` — 分离求解网格化与暴力路径逐位一致焊死
