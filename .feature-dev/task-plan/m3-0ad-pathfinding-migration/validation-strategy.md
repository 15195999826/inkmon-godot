# M3 Validation Strategy

> 父文档: [`README.md`](README.md)
> 数据结构: [`data-structures.md`](data-structures.md)
> 公开 API: [`interfaces.md`](interfaces.md)
>
> 本文档定义 M0-M8 整个 Epic 的验证基础设施(trace schema / replay baseline / 体验点流程 / perf baseline)。
> 每个 milestone 验收时必须满足这里定义的 contract。

---

## 0. 验证哲学

本 Epic 是核心系统重写,bit-identical 漂移是 P0 风险。验证策略三层:

1. **客观自动化**: smoke + replay bit-identical(每 milestone 末必跑)
2. **半自动 trace 对比**: path_trace_v2 CSV byte-equal(M0.1 baseline 起每 milestone 维护)
3. **人工体验点**: 5 个停下来给用户玩 demo 的位置(✋1-✋5)

每个 milestone 三层都过 = APPROVE 进下个 M。任何一层挂 = stop runner,定位漂移源。

---

## 1. Trace Schema (path_trace_v2)

### 1.1 完整字段定义

`tools/path_trace_v2.gd` 输出 CSV(per row = 一个 unit 一个 tick):

| # | 字段 | 类型 | 数据来源 | 占位值 | M0 可填? |
|---|---|---|---|---|---|
| 1 | `tick` | int | 当前 sim tick (从 0 起) | n/a | ✅ |
| 2 | `unit_id` | string | `actor.get_id()` (e.g. `rts_world_0:Character_3`) | n/a | ✅ |
| 3 | `team` | int | `actor.team_id` | -1 | ✅ |
| 4 | `kind` | string | `actor.unit_kind` / `actor.building_kind` | "" | ✅ |
| 5 | `px` | float | `actor.position_2d.x` | n/a | ✅ |
| 6 | `py` | float | `actor.position_2d.y` | n/a | ✅ |
| 7 | `vx` | float | `actor.velocity_2d.x`(若有 nav agent) | 0.0 | ✅ |
| 8 | `vy` | float | `actor.velocity_2d.y` | 0.0 | ✅ |
| 9 | `vmag` | float | `velocity_2d.length()` | 0.0 | ✅ |
| 10 | `long_path_size` | int | `motion._long_path.size()` (M7) | -1 | ❌ M7+ |
| 11 | `long_path_wp_json` | string | JSON encode of waypoints `[[x,y],...]` (M7) | "" | ❌ M7+ |
| 12 | `short_path_size` | int | `motion._short_path.size()` (M7) | -1 | ❌ M7+ |
| 13 | `short_path_wp_json` | string | JSON encode (M7) | "" | ❌ M7+ |
| 14 | `has_target` | bool | `nav_agent.has_target()` (M0-M6) / `motion.has_target()` (M7+) | false | ✅ |
| 15 | `final_tx` | float | `nav_agent.final_target.x` (M0-M6) | -1.0 | ✅ |
| 16 | `final_ty` | float | 同上 | -1.0 | ✅ |
| 17 | `dist_final` | float | `(actor.position_2d - final_target).length()` | -1.0 | ✅ |
| 18 | `obstruction_radius` | float | `actor.collision_radius` (M0-M1) / `obstruction_shape.clearance` (M2+) | -1.0 | ✅ (= collision_radius) |
| 19 | `clearance` | float | 单位 motion clearance (M7) | -1.0 | ❌ M7+ |
| 20 | `region_id` | int | `hierarchical.get_region(navcell, mask)` (M4) | -1 | ❌ M4+ |
| 21 | `global_region_id` | int | `hierarchical.get_global_region` (M4) | -1 | ❌ M4+ |
| 22 | `failed_movements` | int | `motion._failed_movements` (M7) | -1 | ❌ M7+ |
| 23 | `ticket_state` | string | `motion._expected_path_ticket` 状态(`SHORT_PATH/LONG_PATH/none`) | "" | ❌ M7+ |
| 24 | `activity` | string | `actor.get_current_activity_name()` (RtsActivity) | "idle" | ✅ |

### 1.2 占位策略

每个 milestone 引入新字段时,**之前 milestone 的 baseline CSV 不必重生** — 新字段在旧 baseline 里仍是占位值。但 milestone 末的对比规则是:

- M0-M3 baseline: 字段 1-9, 14-18, 24 实填,其他占位
- M4 baseline: 加 `region_id` / `global_region_id` 实填 → 跟 M3 baseline 比较时,这两字段从 -1 变非 -1(预期变化,不算漂移)
- M5 baseline: LongPath waypoints 实填(字段 10-11)→ 跟 M4 对比新字段非 -1(预期)
- M7 baseline: motion 字段全填(12, 13, 19, 22, 23)→ 跟 M6 对比这几个字段从占位变实填(预期)

**判定规则**: 新字段从占位变实填 = 预期变化 / 已实填字段值变化 = 漂移(stop runner)。

### 1.3 CSV 写入约定

- 字段顺序固定 (本节表格顺序),**不准重排**
- 浮点用 `%.6f` 格式化(避免跨平台 6+ 位小数序列化差异)
- string 字段用 CSV 标准引号转义(逗号 / 引号)
- 一个 unit 一个 tick 一行;tick 内 unit 顺序:
  - **M0-M6 阶段**: 按 actor registry insertion 序(GameWorld 内现有 deterministic 顺序)
  - **M7+ 阶段**: 按 **`(kind: String, spawn_seq: int)` 数值复合 key** ⚠️ R5 P1 #1 修订(不再用 `actor.get_id()` 字典序,因 IdGenerator 真实输出 `Character_10 < Character_2` 漂移)
  - 详见 [data-structures §12.5](data-structures.md#125-unitmotion-m7--r5-p1-1-修订)
- 文件第一行 = header(字段名,Tab/逗号都接受,本 Epic 用逗号)

### 1.4 不写入 trace 的情形

- 单位 alive 但无 motion(如纯静态资源点 / 水晶塔)— 不写
- 已 dead 但 actor 仍 in registry(M2.3 之后死者留 world)— 不写(根据 `actor.is_dead()`)
- 处于 placement preview / ghost 状态的 actor — 不写

---

## 2. Replay Bit-Identical 协议

### 2.1 现有保证(M2.3 末态 baseline)

`smoke_replay_bit_identical seed=42 frames=9 events=20`:
- IdGenerator reset (seed=42 时 ID 序列固定)
- Fixed seed (`RtsRng` autoload seeded RNG)
- 固定 tick 顺序
- Actor array order (GameWorld registry insertion order)
- 显式 sort (actor 列表迭代顺序固定)
- Strict score 比较(无"两值相等随便选"路径)

### 2.2 本 Epic 新增约束

Pathfinder/Obstruction/Motion 引入大量新决策点,所有"两候选打平"必须显式 deterministic key — 详见 [data-structures §12](data-structures.md#12-determinism-总排序-contract-codex-p1-4)。

每 milestone 验收时:

```bash
godot --headless --path . addons/.../tests/replay/smoke_replay_bit_identical.tscn > /tmp/replay.txt 2>&1
```

PASS 条件:
- exit code 0
- 输出含 `seed=42 frames=9 events=20 deep-equal`

任何字段变化 → stop runner,从 §12.1-12.6 contract 检查项逐条核对哪条违反了。

### 2.3 跨 milestone 跑两次

每 milestone 新增的算法可能引入"first run vs second run 不同"的漂移(随机内存指针 / Dictionary 迭代序漂移)。验收时**跑两次同 smoke**,对比 CSV byte-identical:

```bash
godot --headless --path . tests/battle/smoke_pathfinding_baseline.tscn > /tmp/run1.txt 2>&1
mv ~/.local/share/godot/app_userdata/Inkmon/0ad-baseline-master.csv /tmp/run1.csv
godot --headless --path . tests/battle/smoke_pathfinding_baseline.tscn > /tmp/run2.txt 2>&1
mv ~/.local/share/godot/app_userdata/Inkmon/0ad-baseline-master.csv /tmp/run2.csv
diff /tmp/run1.csv /tmp/run2.csv  # must be empty
```

---

## 3. Performance Baseline (perf-trace.csv)

### 3.1 字段 (R5 反馈修订)

`tools/perf_trace.gd` 每 milestone 末自动产出:

| 字段 | 含义 | 主辅 |
|---|---|---|
| `milestone` | M0/M1/M2/.../M8 | meta |
| `smoke_name` | smoke 文件名 | meta |
| **`tick_avg_ms`** | 平均每 tick 耗时 (主指标) | ✅ 主 |
| **`tick_p50_ms`** | 中位 tick 耗时 | ✅ 主 |
| **`tick_p99_ms`** | 99 分位 tick 耗时 (尾延迟,30Hz 下不掉帧需 ≤ 30 ms) | ✅ 主 |
| **`tick_max_ms`** | 单 tick 最大耗时 | ✅ 主 |
| `pathfinder_total_ms` | 寻路耗时累计(从 M5 开始有意义) | ✅ 主 |
| `obstruction_total_ms` | obstruction 查询累计(从 M2 开始) | ✅ 主 |
| `memory_peak_mb` | 进程峰值内存 | ✅ 主 |
| `tick_count` | 跑了多少 sim tick | meta |
| `wall_clock_ms` | godot 进程总壁钟 — ⚠️ 跨 run 受系统负载 / background 影响,**仅作辅助参考** | 🟡 辅 |

⚠️ **R5 反馈**: 原版只列 `wall_clock_ms` 不稳定,加了 `tick_avg / p50 / p99 / max` 4 个统计作为**主指标**,`wall_clock` 降级为辅助。判定 perf 退化看 `tick_p99 / tick_max`(尾延迟)+ `pathfinder_total / obstruction_total`(总寻路开销),不依赖 `wall_clock`。

### 3.2 验收规则 (AC-EPIC-7) — R6 P2 修订

每 milestone 跑这 14 项 smoke + 新加的本 milestone smoke,对比上一 milestone。**主验收指标 = `tick_p99_ms` / `tick_max_ms` / `pathfinder_total_ms` / `obstruction_total_ms`**,`wall_clock_ms` 仅作辅助参考(跨 run 受系统负载影响,不稳定)。

**主验收**(必过):
- ✅ `tick_p99_ms` ≤ 30 ms(30 Hz 下不掉帧硬约束,绝对值非相对)
- ✅ `tick_max_ms` ≤ 60 ms(单 tick 尾延迟不刺破 2 帧)
- ✅ `pathfinder_total_ms`(per-smoke 累计)增长 ≤ 50%(M5+ 起)
- ✅ `obstruction_total_ms`(per-smoke 累计)增长 ≤ 50%(M2+ 起)

**辅助参考**(不阻塞,只供调试):
- 🟡 `wall_clock_ms` — 跨 run 受系统负载 / background process / cache 状态影响,看趋势不看绝对值
- 🟡 `tick_avg_ms` / `tick_p50_ms` — 看分布形态参考

**触发 stop runner**(主指标任一):
- 🟡 `pathfinder_total_ms` 或 `obstruction_total_ms` 增长 ≥ 100% (2×) → stop runner 调优
- 🟡 `tick_p99_ms > 30 ms` 或 `tick_max_ms > 60 ms` → stop runner 调优

不预先 GDExtension 化(D8 推论)。

---

## 4. 5 个用户体验点 详细流程

### 4.1 ✋1 — M0 完成 (Footprint / Obstruction 拆分)

**给用户**: F6 跑 `frontend/demo_rts_frontend.tscn`

**用户操作**:
1. 进 build mode (按数字键 / UI 按钮)
2. 鼠标 hover 在地图各位置 → 看 ghost 高亮
3. 放下 1 个 barracks + 1 个 archer_tower
4. spawn 4-6 个单位绕走

**用户应该感觉**:
- ghost 高亮的 cells = 放下后单位实际不能踩的 cells = obstruction 占的 cells(三者一致)
- sprite 视觉位置不变(与 M2.3 完全一致 — F4 决策 A,sprite 锚点保持 position_2d)

**客观断言** (smoke 自动验,不依赖人眼):
- `smoke_obstruction_footprint_split` 内验:`A == B` 且 `B ∩ C = ∅`(A=ghost cells / B=placed cells / C=unit path cells)

**失败回退**: M0 是独立收益,即便后续放弃也保留。回退方案 = revert M0 commit(submodule + 主仓 bump)。

**录屏**: `0ad-migration-M0-after.mp4`(本地留底,不进 git)。

**user 完整"贴墙绕角不穿 sprite"**: 不在 M0 范围,等 ✋3 (M6)。

---

### 4.2 ✋2 — M4 完成 (HierarchicalPathfinder / 可达性)

**给用户**: F6 跑 `frontend/demo_rts_frontend.tscn`

**用户操作**:
1. 选 1 个 unit
2. 右键点 barracks **内部**(建筑占地内)
3. 右键点地图边缘**完全不可达点**(被多重障碍围)
4. 右键点 enemy 后方(需绕路)

**用户应该感觉**:
- 单位走到最近**可达点**(barracks 内部 → 走到建筑外缘最近 navcell)
- 不再"傻站着 / 在建筑前徘徊"
- 不可达点 → 走到全图最近 reachable navcell(可能是几格之外),停下后 abort
- 绕路点 → 走完整 long path(M5 之前 long path 仍是旧 GridPathfinding,M5 后才换)

**客观断言**:
- `smoke_hierarchical_unreachable.tscn` 跑 PASS(M4 时新加)
- `make_goal_reachable` canonicalize 行为符合 [interfaces §1.3](interfaces.md#13-make_goal_reachable-语义-codex-r1-p1-修正)

**失败回退**: 回到 M3 stable,Hierarchical 关掉走 fallback(直接全图 BFS / 或 LongPath 自己处理 unreachable)。

---

### 4.3 ✋3 — M6 完成 (VertexPathfinder / 真正贴边绕角)

**给用户**: F6 跑 demo

**用户操作**:
1. 选 1 个 unit
2. 让它绕单一矩形 barracks 走(从 barracks 一侧到对侧)

**用户应该感觉**:
- **路径转角自然贴边,不再 zig-zag**(这是真正的"Bug 1 完整修复"体感点)
- 单位 sprite 不穿建筑 sprite
- 任意角度路径,不再受 32 px grid 粒度限制

**客观断言**:
- `smoke_vertex_corner_walking.tscn` 跑 PASS(M6 时新加)
- 路径 waypoint 数量 ≤ M5 LongPath 同输入下的 waypoint 数(VertexPath 应该更平滑)

**失败回退**: 回到 M5 stable,short pathfinder 用退化版(cell 中心连线)— 失体感但能用。

---

### 4.4 ✋4 — M7 完成 (UnitMotion 整合)

**给用户**: F6 跑完整 demo,跑一局正常游戏

**用户操作**:
1. 完整 demo_rts_frontend 一局(~3-5 分钟)
2. 涉及所有 RtsActivity:attack / gather / build / ai 行为
3. 观察整体寻路"换装"后的视觉/行为差异

**用户应该感觉**:
- 整体寻路"换了一套"后,**没有视觉退化**
- 攻击行为正常(M7c attack activity 集成)
- 工人采集正常(M7c gather activity 集成)
- 建筑生产 spawn 单位正常
- AI 行为正常(M7d activity 全集成)

**客观断言**:
- 14 项 smoke + LGF 73 unit + replay bit-identical 全 PASS
- 所有 RtsActivity smoke 单测 0 漂移

**失败回退**: 回到 M6 stable,UnitMotion 仍用旧 RtsNavAgent(短期能 verify long+short pathfinder 工作但不是终态)。

---

### 4.5 ✋5 — M8 完成 (group push / 多单位行为)

**给用户**: F6 跑 demo

**用户操作**:
1. 选 ≥10 个单位
2. 右键远程一点 → 整体移动
3. 观察队列形态

**用户应该感觉**:
- 同队不互相绕(group filter 生效)
- 多单位移动整齐(不散队 / 不堵塞)
- 拥挤时 push pass 让出空间

**客观断言**:
- `smoke_group_movement.tscn` 跑 PASS(M8 新加)

**失败回退**: 回到 M7 stable,group filter 关掉,sep force 兜底(M2.3 既有方案)。

---

## 5. Trace 数据 + Replay 文件管理

### 5.1 文件位置

| 文件 | 位置 | 进 git? |
|---|---|---|
| `path_trace_v2.gd` (utility) | `addons/.../tools/` | ✅ submodule |
| `smoke_pathfinding_baseline.tscn` + `.gd` | `addons/.../tests/battle/` | ✅ submodule |
| `0ad-baseline-master.csv` (M0 准备阶段产出) | `addons/.../tests/baselines/` | ✅ submodule(每 milestone 末刷新) |
| 每 milestone trace 输出 (运行时) | `user://0ad-baseline-master.csv` (Godot user data dir) | ❌(开发机本地) |
| 每 milestone replay JSON | `user://0ad-baseline-master.replay.json` | ❌(开发机本地) |
| 录屏 (M0 / M5 / M7 / M8) | 本地 / 开发机文档目录 | ❌ |
| Performance baseline `perf-trace.csv` | `addons/.../tests/baselines/` | ✅(每 milestone 加一行) |

### 5.2 baseline CSV 刷新协议

每 milestone 末:

1. 跑 `smoke_pathfinding_baseline` 两次,验证 byte-identical
2. 把 `user://0ad-baseline-master.csv` copy 到 `addons/.../tests/baselines/0ad-baseline-master.csv`(覆盖)
3. **diff 上一 milestone baseline**:
   - 仅"新字段从占位变实填"的差异 → ✅ 预期变化,接受新 baseline
   - 已实填字段任何 diff → ⚠️ stop runner,定位漂移源
4. submodule 内 commit `tests/baselines/0ad-baseline-master.csv` 更新(commit message 注明 milestone)

### 5.3 baseline CSV 大小预估

`smoke_pathfinding_baseline` 跑 ~30s(900 ticks @ 30Hz)× ~10-20 motion-bearing units ≈ 9000-18000 行。

每行 ~200 字节 → 单 baseline ~1.8-3.6 MB。可接受 git track。

如未来 ≥10 MB,考虑 git-lfs 或不进 git(本地 only)。

---

## 6. 每 milestone 验收 checklist 模板

每 milestone 末必须全过(按顺序):

```
[Milestone Mx]
  ├── 1. AC1-AC10 (本 milestone 自己的 acceptance,各 milestone 文档定义)
  │     全部 ✅ 才进下一步
  │
  ├── 2. M2.3 末态 baseline 14 项 smoke 0 漂移
  │     ├── smoke_rts_auto_battle ticks=347 attacks=74 melee=32 ranged=42
  │     ├── smoke_castle_war_minimal ticks=193 left_win unit_to_building=4
  │     ├── smoke_player_command gold_remaining=20 wood_remaining=50
  │     ├── smoke_player_command_production ticks=600 left_spawned=7
  │     ├── smoke_production ticks=600 left=7 right=7
  │     ├── smoke_crystal_tower_win ticks=2 left_win
  │     ├── smoke_resource_nodes ticks=200 alive=5
  │     ├── smoke_harvest_loop ticks=600 alive=5 team_gold=140 team_wood=212
  │     ├── smoke_economy_demo ticks=900 melee_to_ct=31
  │     ├── smoke_ai_vs_player_full_match ai_barracks=1
  │     ├── smoke_replay_bit_identical seed=42 frames=9 events=20 deep-equal
  │     ├── smoke_determinism tick_diff=0
  │     ├── smoke_frontend_main visualizers=10 alive_after_3.0s=10
  │     └── (本 milestone 新加 smoke 也 PASS)
  │
  ├── 3. LGF 73/73 unit test PASS
  │
  ├── 4. baseline CSV diff (vs 上 milestone)
  │     仅"新字段占位→实填" / 其他字段 byte-identical
  │
  ├── 5. perf-trace.csv 增长 ≤ 50% (vs 上 milestone)
  │
  └── 6. 体验点(如有 ✋N) 用户跑 demo + 反馈通过
```

任一项挂 = stop runner,定位 + 修复 + 重跑全 checklist。

---

## 7. 调试基础设施

### 7.1 Path overlay (Godot 编辑器内可视化)

`tools/path_overlay.gd`:
- 编辑器 F6 跑某 frontend smoke
- 实时画 long_path / short_path 在地图上(不同颜色)
- 画 obstruction shape 边界(OBB / 圆)
- 画 hierarchical region 颜色(M4+)
- 画 navcell passable / impassable 网格(可选 toggle)

**使用场景**: M5 LongPath 出错时编辑器看路径走向 / M6 VertexPath 几何 bug 时看 visibility graph 错误顶点 / M4 region 错误时看 chunk 边界。

不进 production / smoke,只供开发调试。

### 7.2 OOSLog (Out-Of-Sync Log)

借鉴 0 A.D.,replay 漂移定位用:
- 跑 master 一份 → 写入每 tick 各 motion-bearing entity 的 `(tick, id, hash(state))`
- 跑当前 branch 一份 → 同样写入
- diff 两文件,第一个 hash 不同的 tick = 漂移源 entity + tick

`tools/oos_log.gd` (M5 启动前置 落地)。

---

## 8. 决策来源

- Trace schema 24 字段: M0.md §M0.1 (codex R1 提示需要标准化)
- 体验点 5 个: README §2(用户讨论 + codex R1 提示完整 Bug 1 修复在 M6)
- baseline CSV 协议: M0.md §M0.7 + codex R1 反馈"原 footprint baseline 主观,需客观化"
- Replay bit-identical: 现有 `smoke_replay_bit_identical` 协议(M2.3 之前已稳定),本 Epic 不动
- Perf ≤ 50%: README §3 AC-EPIC-7(codex R1 没反对 50% 数字)
- Determinism contract: data-structures §12(codex P1 #4 拍板)

---

## 9. 引用

- 父文档: [README.md](README.md)
- 字段: [data-structures.md](data-structures.md)
- API: [interfaces.md](interfaces.md)
- M0 范本: [milestones/M0-footprint-split.md](milestones/M0-footprint-split.md)
