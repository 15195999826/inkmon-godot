---
name: sim-nav-map-bugfix
description: `addons/sim-nav-map` 寻路细节 bug 修复流程：先用 0ad-rts-pathfinding-lab 的 export log 复现 → 以 0 A.D. 源码为准修复（不引入 lab 自创 magic number）→ 写带注释的回归测试锁定。Use when 用户提供 `ZERO_AD_RTS_LAB_EXPORT_LOG: …` 路径并描述视觉异常，或者明确说要修 sim-nav-map / 0ad lab 寻路 bug。
---

# Sim Nav Map — 细节 Bug 修复流程

适用场景：用户描述 0ad-rts-pathfinding-lab 视觉异常（卡墙角 / 撞静止 unit / 寻路绕远 / first wp 后退 / 卡死等），并附上 `ZERO_AD_RTS_LAB_EXPORT_LOG` 的 JSON 路径。

**核心心法**：每个 bug 都是 lab 偏离 0 A.D. 的具体一处。修复 = 让那一处回到 0 A.D.，不是发明新策略。

## 三步流程

### Step 1. 先复现

不到能确定性复现，**不进 Step 2**。

#### 1a. 切片 log 找最小复现单位

直接用 skill 自带的 helper（替代手写 `python -c json.load`）：

```bash
python .claude/skills/sim-nav-map-bugfix/probe_log.py <log.json>
# 聚焦某 unit / tick 段 / 某事件
python .claude/skills/sim-nav-map-bugfix/probe_log.py <log.json> --unit blue_2 --tick-range 9700:9900
python .claude/skills/sim-nav-map-bugfix/probe_log.py <log.json> --kind movement_line_blocked
```

输出 = units 状态 + path_decisions kind counts + 严重 overlap 列表 + filtered decisions tail + motion_updates tail。

关键计数对比信号：

| 计数模式 | 含义 |
|---|---|
| `long_segment_unit_line_blocked` 多但 `short_path_suppressed` 也多 | pre-check 触发但被节流 |
| `movement_line_blocked` 多 | 真撞墙的 reactive recovery |
| `move_failed (max_failed_movements)` | 单位卡死，short path 反复 `no_route` |
| `first_short_waypoint_farther_from_final_goal: true` | 短路径首段后退 |
| `recent_pair_contacts` 末段 final_distance < 14 | 单位严重重叠（穿过静止 unit）|

#### 1b. 用 probe 验证假设（headless，秒级）

提取出最小条件后，**先用 probe 模板验证假设**，比改代码再跑 demo 快得多：

| 模板 | 用途 |
|---|---|
| `probe_los.gd/.tscn` | 单段 LOS 测试：直接 `SimNavLineOfSight.shape_blocks_segment` + facade.validate_movement_line + lab pathfinder 三层。验证"这条 segment 应该 block 吗" |
| `probe_motion.gd/.tscn` | 多 tick motion 模拟（默认 120 tick = 2 秒）：跑 motion controller 的 step_unit + apply_push_adjust 多帧，看 unit 是否前进 / fm 累 / drift 进 obstacle 中心。**比单步 LOS 准——揭露累积漂移问题** |

使用：
```bash
# 1. cp 模板到 .claude/tmp/
cp .claude/skills/sim-nav-map-bugfix/probe_los.{gd,tscn} .claude/tmp/
# 2. Edit start/target/blockers 为最小复现条件
# 3. 跑（30s 内出结果）
godot --headless --path . .claude/tmp/probe_los.tscn 2>&1 | grep "LOS\|FACADE\|LAB_PF"
```

不到能 probe 复现，**不进 Step 2**。

### Step 2. 以 0 A.D. 为准修

**禁止**：在 lab 引入 0 A.D. 没有的 magic number / cooldown / 节流 / 阈值。已踩过的反例：
- `SHORT_REPATH_COOLDOWN_SEC = 0.22`（lab 自创节流）
- `waypoint_spacing = cell_size * 4`（应跟 0 A.D. `SHORT_PATH_MIN_SEARCH_RANGE - 1`）
- LOS directional 分支额外的"切线 = block"检查（0 A.D. 是 binary）
- vertex graph 不过滤被覆盖角（0 A.D. `VertexPathfinder.cpp:727-734` 过滤）

**强制**：
1. 改之前 → 读 `addons/sim-nav-map/docs/references/0ad-source/` 对应文件，**不是** audit 文档、**不是**记忆
2. 命中具体函数 + 行号（例：`CCmpUnitMotion::PostMove` 在 `CCmpUnitMotion.h:1131-1160`）
3. 修复说明里引用源码出处
4. 修复 lab 文件，不轻动 core；除非 0 A.D. 在 core 等价层做了 lab 没做的事

常用源码入口（去 `docs/references/0ad-source-map.md` 查全表）：

| 主题 | 入口 |
|---|---|
| Long-path waypoint 间距 | `CCmpUnitMotion.h:RequestLongPath`（`improvedGoal.maxdist`）|
| Short-path 触发时机 | `CCmpUnitMotion.h:PostMove` + `HandleObstructedMove` |
| Vertex graph 过滤 | `VertexPathfinder.cpp:727-734` |
| Directional LOS | `Geometry.cpp:TestRaySquare` / `TestRayAASquare` |
| Clearance buffer | `Pathfinding.h:CLEARANCE_EXTENSION_RADIUS` |

### Step 3. 锁定回归测试

位置：`addons/sim-nav-map/tests/repro/repro_core_NNN_<short_name>.{gd,tscn}`。

**强制注释三段**（顶部）：

```gdscript
# CORE-NNN: <一句标题>
#
# Bug reproduced here:
#   - 现象：单位 X 在场景 Y 出现 Z（数值 + 关键 (start, target, blockers)）
#   - 根因：lab <文件:行> <偏离 0 A.D. 的具体点>
#
# 0 A.D. expected (<file:line>):
#   <对应源码做法的简短描述>
#
# Before fix: <断言失败的具体输出>. FAIL.
# After fix: <断言通过的具体输出>. PASS.
#
# Run: godot --headless --path . addons/sim-nav-map/tests/repro/repro_core_NNN_<short_name>.tscn
```

测试结构：构造最小 `SimNavMap` + obstacles + dynamic units + `SimNavShortPathRequest`/`SimNavLongPathQuery`，调一次目标 API，断言关键不变量（path 不空、first wp 不后退、不含 covered vertex 等）。

**追加**到 `addons/sim-nav-map/tests/test_groups.json` 的 `simnav/smoke` 列表。

跑 `./tools/run_tests.ps1 simnav/smoke zeroadlab/smoke`，确保全过。

如果旧 smoke 是 lock-in negative test（expect bug exist），**翻转**断言并加注释说明何时翻转、为何翻转。

## 反模式（别做）

- 复现没成功就"先试着改"
- 改完只跑了 zeroadlab/smoke，没跑 simnav/smoke
- 修了 bug 没写 repro，下次回归发现不了
- repro 文件没写"Bug reproduced here / 0 A.D. expected"注释，半年后忘了为啥这么测
- 改 core 时没看 0 A.D. 等价层（容易引入 lab-only 自创策略）
- 在 lab 加魔术常量"压低出现概率"代替治根因
- **改 LOS 后只单步 probe，不跑 multi-tick** — 累积漂移类 bug（单步 0.5 px tolerance 几十帧穿过 obstacle）单步看不出来，必须 `probe_motion` 验证
- **加 lab 自创"看似合理"的保护**（如 stay-or-deeper guard、cooldown） — 0 A.D. 没就不要加；真有 race-condition / drift 顾虑，看 0 A.D. 怎么靠 push system / blocked recovery 多帧处理，而不是 LOS 单帧硬拒

## 已存案例（参考写法）

LOS / vertex graph：
- `repro_core_001_vertex_obb_outset.gd` — OBB 顶点 outset 方向错
- `repro_core_005_clearance_extension.gd` — clearance 扩展余量
- `repro_core_008_covered_vertex_first_waypoint_regression.gd` — 被覆盖的 vertex 导致 short path 首段后退（mirrors `VertexPathfinder.cpp:727-734`）
- `repro_core_009_directional_must_not_pierce_other_unit.gd` — directional 不能让 segment 穿其他 obstacle 中心
- `repro_core_010_boundary_tangent_no_detour.gd` — boundary band 切线噪声不该 reject 整段
- `repro_core_011_short_path_best_vertex_fallback.gd` — A* 失败时返回 closest-to-goal vertex（mirrors `VertexPathfinder.cpp:868-900` `idBest`）
- `repro_core_013_boundary_step_b_inside_no_early_block.gd` — boundary band 不该有 b-inside 早返
- `repro_core_014_overlap_escape_must_be_strict_binary.gd` — 真 overlap 严格 binary（mirrors `Geometry.cpp:280-281`）

motion 层：
- `repro_core_012_boundary_motion_step_not_stay.gd` — boundary stay-rule 仅适用真 overlap
- `repro_core_015_motion_validates_full_segment_to_waypoint.gd` — motion LOS 用 waypoint 不是 candidate（mirrors `CCmpUnitMotion.h:1334`）
- `repro_core_016_arrive_when_blocked_close_to_target.gd` — blocked 但近 target 即 arrived（mirrors `PossiblyAtDestination`）

known limitations（lock-in，不是 bug）：
- `repro_core_017_dense_cluster_perimeter_detour_known_limit.gd` — 密集 unit cluster 的 perimeter detour 是 visibility-graph inherent 行为
