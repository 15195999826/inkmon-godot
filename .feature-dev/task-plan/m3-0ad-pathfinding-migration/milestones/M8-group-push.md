# M8 — push pass + 多单位行为 polish

> 父 plan: [`../README.md`](../README.md)
> 数据结构: [`../data-structures.md`](../data-structures.md) §8 (UnitMotion)
> API: [`../interfaces.md`](../interfaces.md) §6
>
> Status: ⏳ active(2026-05-05 planner 启动;scope = M8 only;cleanup phase 留 M8 完成后下一 feature)
> 依赖: M7 (UnitMotion 完整,M7d 末态 baseline rts/all 53/53 PASS)
> ✋ 用户体验点 5: M8 完成时(多单位移动整齐,同队不互相绕);AC8 user demo 硬性验收(8 unit 凹陷中心)

---

## 0. 目标

启用 0 A.D. UnitMotionManager 风格的 **push pass** — 同 sim tick 内所有 motion-bearing units 移动后,有一个额外 pass 让 overlapping 单位互相轻轻 push 开,避免堆叠。

**重要(D9 决策)**:`group_filter` API 在 M6/M7 已是输入(VertexPathfinder + RtsShortPathRequest.control_group + UnitMotion 同步 obstruction.control_group),M8 **不引入新 API**,只:
1. 打开 control_group 真实赋值(RtsMotionComponent 启动时 `obstruction.control_group = str(team_id)` 或 `formation_id`)
2. push pass 算法
3. 多单位行为 tune(队列散开 / 集合行为)

**M8 是相对短的 milestone(1.5 周)** — 之前所有基础设施都搭好了,M8 是 polish。

---

## 1. Scope

### 1.1 必做

- 启动时 RtsMotionComponent 把 owner.team_id 赋值给 obstruction.control_group
- 实现 `_push_pass(world)`(每 sim tick 末额外 pass)— 见 [data-structures §8](../data-structures.md#8-motion-层--agent-m7) + 0 A.D. CCmpUnitMotionManager.cpp:Push
- push 力度公式 = `(overlap_distance / 2) * push_factor`(默认 push_factor=0.5)
- push 不修改 _move_request 不影响 path,只调整 actor.position_2d
- push 完成后再 sync obstr_mgr.move_shape
- 多单位 group 行为 tune:玩家选 ≥10 unit 同时 right-click → 队伍行为不散
- 加新 smoke `smoke_group_push_pass.tscn` + `smoke_group_movement_unity.tscn`

### 1.2 不做

| 不做 | 原因 |
|---|---|
| Formation slot(virtual entity 跟随)| 下个 Epic |
| Group goto 路径合并 | 同上 |
| 单位 priority(谁让位)| 当前所有 push 力等大,简化 |

### 1.3 文件清单

#### 修改

```
addons/.../logic/movement/
├── rts_unit_motion.gd                        ← 加 _push_pass / _push_force
└── rts_motion_component.gd                   ← _init 时设 control_group

addons/.../core/rts_auto_battle_procedure.gd  ← tick 顺序加 push pass step
```

#### 新建 smokes

```
addons/.../tests/battle/
├── smoke_group_push_pass.tscn                 ← push 力度 / 触发条件
└── smoke_group_movement_unity.tscn            ← ≥10 unit move together
```

---

## 2. 子任务

### M8.1 — control_group 赋值打开

```gdscript
# RtsMotionComponent._init 内末尾(在 obstr_mgr.add_unit_shape 之后)
obstr_mgr.set_unit_control_group(owner.obstruction_tag, str(owner.team_id))
```

**完成标志**: 单位 spawn 后 `obstr_mgr.get_shape(tag).control_group == str(team_id)`,VertexPathfinder 同 group 不算障碍生效。

### M8.2 — Push pass 实现

```gdscript
# RtsUnitMotion 加新方法
func push_pass(world: RtsWorld) -> void:
    if not _block_movement:
        return
    var obstr_mgr: RtsObstructionManager = world.obstruction_manager
    var nearby: Array = obstr_mgr.get_obstructions_in_range(_actor.position_2d, _clearance * 4.0)
    var push_total: Vector2 = Vector2.ZERO
    for s in nearby:
        if not (s is RtsObstructionShapeUnit):
            continue   # 只 push unit 互相, 不 push 建筑
        if s.entity_id == _actor.get_id():
            continue
        if s.control_group == str(_actor.team_id):
            # 同队互相 push 也允许(防止堆叠), 0 A.D. 也是这样
            pass
        var dx: Vector2 = _actor.position_2d - s.center
        var d: float = dx.length()
        var sum_clearance: float = _clearance + s.clearance
        if d < sum_clearance and d > 0.001:
            var overlap: float = sum_clearance - d
            push_total += dx.normalized() * (overlap / 2.0) * 0.5    # push_factor = 0.5
    
    if push_total.length() > 0.001:
        _actor.position_2d += push_total
        obstr_mgr.move_shape(_actor.obstruction_tag, _actor.position_2d)
```

**RtsWorld.tick 内**(M7c.2 已定义,M8 加 push pass step 3,共 7 步;M7 R5 P1 #1 + P2 修订后真实顺序):

```
1. RtsPlayerCommandQueue.apply_due(procedure, world, current_tick)    ← 真实 API (不是 flush)
2. for actor in sort_by_(kind, spawn_seq)(motion-bearing):           ← (kind, spawn_seq) 数值复合 key, 不字典序 (R5 P1 #1)
     actor.motion.tick(delta, world, facade)
3. for actor in sort_by_(kind, spawn_seq)(motion-bearing):           ← M8 加: push pass, 排序同 step 2
     actor.motion.push_pass(world)
4. RtsActivity.tick(delta)
5. ObstructionManager.rasterize_if_dirty(grid, registry)             ← 不 clear_dirty 在 rasterize 内(M3 R5 P1 #2)
6. RtsHierarchicalPathfinder.update(grid, dirty_snapshot)            ← 拿 step 5 的 dirty snapshot
7. grid.clear_dirty() + GameWorld.event_collector.flush()            ← 末端统一清 dirty + 落事件
```

**完成标志**: 两单位强行 spawn 在同一坐标 → push pass 后被推开;FLAG_BLOCK_MOVEMENT off 的单位不参与 push。

### M8.3 — 多单位 group 行为 tune

- 玩家选 10 unit + right-click 同一目标 → 内部生成 N 个 MoveRequest,每 unit 独立寻路 + push pass
- M8 阶段不引入 formation slot,但确认:
  - 同队互相不绕(group_filter 在 ShortPath 已生效)
  - push pass 让位避免堆叠
  - 整体到达后停下来,不会因 push pass 持续抖动

调优:
- push_factor 默认 0.5,允许从 RtsMatchPreset 配置
- push 阈值(最小 push 力度)= 0.1 px,< 阈值时不动 → 防止微抖

### M8.4 — Smokes

`smoke_group_push_pass`:
- spawn 5 unit 在同一 (500, 500) 强行重叠
- 1 tick push pass → 5 unit 散开,互相距离 ≥ 2 * clearance

`smoke_group_movement_unity`:
- spawn 10 unit team A in (100, 100) 区域
- 玩家 move 到 (700, 700)
- 5 秒后:
  - 全部 10 unit 已到达目标范围内 (≤ 100 px from goal)
  - 同队互相不绕(short path 路径长度 < 1.2 × LongPath 直接距离)
  - 队形不散开过远(标准差 ≤ 50 px)

---

## 3. 验收准则

### AC1 — control_group 真实赋值打开 🔒
### AC2 — push_pass 算法落地 🔒
- 重叠 → push 散开
- 不影响 motion._move_request / path
### AC3 — RtsWorld.tick 7 步顺序正确 🔒
- 顺序按 §interfaces §10.3 + push pass step 3
### AC4 — Validation + 体验点 ✋5 🔒
- 14 项 + LGF + replay seed=42 deep-equal
- baseline CSV byte-identical (M8 不改 trace 字段; push pass 影响 path 但 trace 走 actor.position_2d 仍变化 — 接受新 baseline)
- 体验点 ✋5: demo F6 验证 ≥10 unit 同时移动整齐

### AC5 — 2 smokes PASS 🔒

### AC6 — Perf ≤ 50% (vs M7) 🔒
- push pass 是 O(units × nearby_units) ≈ O(N × 10),GDScript 撑得住

### AC7 — Group filter 生效验证 🔒
- 同 control_group 单位 short path 不绕(M6 wired,M8 真实场景验证)

### AC8 — User demo ✋4 8 unit 凹陷中心硬性验收 🔒(2026-05-05 planner 追加)
**触发动机**:M7d 教训 — smoke 全过 ≠ user demo 真实多 unit 拥挤体验(4 unit pairwise 27 PASS,8 unit 用户实测仍重叠)。AC8 把 user demo 显式签字纳入 ✋5 体验点必要条件,防止 smoke 全过但 demo 仍差直接 archive。

- 跑 `demo_rts_pathfinding.tscn`,user F6 同时控制 8 unit 移动到 3 barracks 凹陷中心(座标 ~350, 230)
- **接受标准**:user 显式签字"目视无重叠 / 无穿越 / 远好于 M7d.5b 末态"才算 ✋5 通过,否则不算 M8 done
- 量化对比(配套数据 dump,非 PASS/FAIL smoke):跑 `tests/diagnostics/trace_pathfinding_8units.tscn`,与 §7b 表中 M5 baseline 对比:
  - 中途 events ≤ 100(M5 baseline 266,~60% 降幅)
  - max_overlap ≤ 4 px(~16% diameter 以下,视觉无穿模感)
  - 终点 events 仍 0(M5 已达,不退化)
- 量化指标 + user 签字两者**都过**才算 AC8 PASS

---

## 4. 关键决策

### N1 — push_factor 数值 ✅ locked A(2026-05-05 planner)

- **A. 0.5** (0 A.D. 同值) — ✅ **locked**
- B. 0.3 / 1.0(更弱 / 更强)

> 复刻 0 A.D.,体感最自然。runner 直接按 0.5 实现;demo F6 ✋5 不达再 tune。

### N2 — push 是否考虑 group(同队 push 力度减小?) ✅ locked A(2026-05-05 planner)

- **A. 不考虑,所有 unit pair 同力度 push**(简化) — ✅ **locked**
- B. 同 control_group push 力度 × 0.5(让队友更紧凑)

> 0 A.D. 不区分;A 选项语义清晰。runner 直接按 A 实现;demo 不达再考虑 B。

---

## 5. 子任务进度

- [ ] M8.1 — control_group 赋值
- [ ] M8.2 — push_pass 算法
- [ ] M8.3 — group 行为 tune
- [ ] M8.4 — Smokes

---

## 6. 残余风险

| # | 风险 | 缓解 |
|---|---|---|
| R1 | push pass 引入 replay 漂(同 tick 处理顺序) | 严格按 `(kind, spawn_seq)` 数值复合 key push(同 §12.5,R5 P1 #1 修订);smoke 跑双倍验证 |
| R2 | push 力度过大 → 单位被弹离 path | push_factor = 0.5 + 阈值 0.1 阻 微抖;若仍弹太远,M8 末调小 push_factor |
| R3 | M8 跟 M7 边界:push_pass 在哪一 step | 严格 step 3(motion.tick step 2 后,activity step 4 前);保证 activity 看到 push 后位置 |

---

## 7. 决策来源

- 数据结构: data-structures §8(M7 已含 _block_movement / _pushing 字段)
- 0 A.D. 对照: CCmpUnitMotionManager.cpp Push
- M7 末态 baseline

---

## 7b. 启动前已知观察(用户 2026-05-04 跑 demo 反馈)

用户跑 `demo_rts_pathfinding.tscn` 测 8 unit 走到 3 barracks 中央凹槽 (350, 230),报告**中途擦肩穿模视觉异常**(终点稳定 OK)。

**复测入口**(数据 dump 工具,不是 PASS/FAIL smoke):
`tests/diagnostics/trace_pathfinding_8units.tscn`

**M5 末态 baseline 量化结果**:

| 阶段 | tick | overlap events | max_overlap |
|---|---|---|---|
| 起手离开 | 0-39 | 83 | 8.73 px |
| **中途绕行** | 40-119 | **266** | **9.45 px** ← 用户反馈 |
| 接近聚拢 | 120-199 | 40 | 7.94 px |
| 终点稳定 | 200+ | 0 | 0 |

(collision_diameter = 24 px → max overlap 9.45 px = ~39% 重叠;视觉上明显穿模)

**根因分层**(见会话讨论):
1. 几何 hard constraint — barracks_1 ↔ barracks_2 间垂直空隙仅 16 px < 24 px diameter,8 unit 物理上塞不进
2. `RtsGroupFormation.assign_offsets` 不知 obstacle,offset 落点经 canonicalize 多个挤同格(0 A.D. 用 footprint-aware formation 解,在 formation deferred plan)
3. `MAX_SEP_FRACTION = 0.7` 留 30% velocity 朝目标推 → 互挤
4. `RtsMinimalPushOut` 0.5×overlap 修正不彻底 → 稳态轻度重叠

**M6/M7/M8 各能解多少**:
- **M6 vertex pathfinder**:中途单位走斜线绕对方 vertex,266 中途 events 应显著降
- **M7 UnitMotion 整合 long+short**:cluster 抵达后 motion 状态机能识别"在拥挤区"主动减速,可消接近聚拢的 40 events
- **M8 push pass + control_group**:同 group 单位互不阻挡,终点 formation 稳定不抖动 — ✋5 体验点的核心

**M8 验收追加**:M8 末跑一次 `trace_pathfinding_8units.tscn`,对比上面 baseline。M8 后预期:
- 中途 events ≤ 100(~60% 降幅)
- max_overlap ≤ 4 px(~16% diameter 以下,视觉无穿模感)
- 终点 events 仍 0(M5 已达,不退化)

---

## 8. Epic 完成

M8 完成 = 整个 M3 Epic 完成 — 9 个 milestone (M0-M8) + Formation handoff(deferred)= 0 A.D. 寻路全面迁移落地。

下一步:
- 用户跑 demo 体验点 ✋1-✋5 全 PASS
- AC-EPIC-1 ~ AC-EPIC-9 (README §3) 全部签字
- Epic archive(`.feature-dev/archive/2026-XX-XX-rts-m3-0ad-pathfinding-migration/`)
- 启动 Formation Epic(下个 Epic,设计文档见 [`../deferred/0ad-formation-design.md`](../deferred/0ad-formation-design.md))
