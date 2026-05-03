# RTS Pathfinding M3 Epic / M3 — Clearance + 外扩 (per-class buffer) — Summary (2026-05-04)

> M3 Epic 第四个 milestone(M3/9)。把 M2 落地的 ObstructionManager 真正接入 NavcellGrid:
> rasterize 改两步(原 cell 占用 + clearance 外扩 inflate),procedure 末端 `rasterize_if_dirty`
> 走 manager._shapes 单一数据源增量重写 NavcellGrid(R5 P1-2 dirty lifecycle invariant 一并落地)。
>
> M2 deferred 的 "pathfinder 走 manager 数据 single source of truth 切换" 在此 milestone 完成 —
> dual-write 模式终结,manager._shapes 现在是 BLOCK_PATHFINDING 状态的唯一来源。
>
> **替换 M2 末态 baseline CSV (882882 → 829520 bytes,M3 inflate 让单位绕建筑路径变宽);
> replay seed=42 frames=11 events=20 deep-equal,determinism tick_diff=0;LGF 73/73 + 17 RTS smoke
> 全过(数字漂为预期算法变化范畴)。**

---

## Acceptance 结论 (M3.1 - M3.4 全过 + AC1-AC10)

### M3.1 - M3.4 子任务

| Sub | Scope | 状态 |
|---|---|---|
| **M3.1** | `RtsObstructionManager.rasterize` 改两步: 原 cell 占用 + clearance 外扩 inflate (Euclidean 距离 ≤ buffer_px = ceilf(clearance/cell)*cell, 至少 1 cell);I1 决策 A brute-force / I2 决策 A 圆形 buffer | ✅ done |
| **M3.2** | `RtsPassabilityClassConfig.affects_pathfinding: bool` 字段 (替 spec §M3.1 步骤 1 给的 `class_name_id == "air"` 字符串比较, 改 type-safe flag);registry 加 `get_classes()` + `get_class_by_mask()` (后者 spec §M3.1 步骤 2 要求, M4+ 用) | ✅ done |
| **M3.3** | `procedure.tick_once` step 6.6 调 `rasterize_if_dirty` + step 7.5 `clear_dirty()`(R5 P1-2 dirty lifecycle invariant);装饰 obstacle (frontend `mark_obstacle_cell` 阶段标的 cells) 自动注册到 manager;`NavcellGrid._origin_world` 字段修 RtsBattleGrid HexCoord+half_offset vs ObstructionManager world/cell 索引坐标系错位 | ✅ done |
| **M3.4** | 新 smoke `tests/battle/smoke_clearance_inflate.{tscn,gd}` (AC1+AC2+AC3+AC8) + Validation 全套 + 接受新 baseline | ✅ done |

### AC1-AC10 验收

- ✅ **AC1** — Rasterize inflate 第二遍工作:`_rasterize_class` 内 sorted blocking_shapes 跨两遍迭代(occupy + inflate);smoke 验证 4 OBB cells + 11 inflate cells = 15 default-blocked in 5×5 候选(barracks 64×64 @ (500,500) clearance=14)
- ✅ **AC2** — Per-class clearance 生效:per `pass_class.clearance` 算 `clearance_cells / buffer_px`;`affects_pathfinding=false` 让 air class skip(M3 wiring,M4+ 引入飞行单位时打开)
- ✅ **AC3** — Dirty 增量正确:smoke `_test_dirty_lifecycle` 验证 add → 15 blocked → remove → 0 blocked;`_clear_dirty_with_buffer` per-dirty-cell ±clearance 范围清(maxi/mini 内层 clamp)
- ✅ **AC4** — Procedure 接调度:`procedure.tick_once` step 6.6 调 `rasterize_if_dirty`;`grid.collect_dirty_cells().is_empty() return false` noop;step 7.5 末端 `clear_dirty()`
- ✅ **AC5** — `smoke_clearance_inflate` PASS:4 sub-test 全过(AC1 inflate basic / AC2/AC8 air independent / AC3 dirty lifecycle / rasterize_if_dirty noop+triggered)
- ✅ **AC6** — Validation 全套:LGF 73/73 + 17 RTS smoke 全 PASS + replay seed=42 frames=11 events=20 deep-equal + determinism tick_diff=0 + baseline CSV 跑两次 byte-identical (829520 bytes,接受新 baseline 替换 M2 末态 882882)
- 🟡 **AC7** — Perf 增长 ≤ 50%:未跑 perf_trace.gd 正式数据;实测各 smoke 时间跟 M2 同数量级;simplify pass hoist `dirty_cells / sorted_tags` 跨 class 共享 + `_clear_dirty_with_buffer` 改 dirty-cells iter 不全图扫,实际 perf 比初版好。stop-runner 第 5 条未触发
- ✅ **AC8** — air class 外扩独立:smoke `_test_air_class_independent` 验证 air mask 25 cells 全 passable(default rasterize 后 air rasterize 不重写);`_collect_blocking_shapes(air)` 早返空(`affects_pathfinding=false`)
- 🟡 **AC9** — 体验点改进准备:demo 没用户跑;baseline CSV diff(882882→829520) + smoke_rts_auto_battle ticks(347→264)证 inflate 真在改 path。✋1 真正体验点验收推到 M4
- ✅ **AC10** — 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内(`core/` `logic/grid/` `logic/obstruction/` `tests/`),不动 LGF core / stdlib

---

## 关键 artifact 路径

### 修改文件 (submodule)

```
addons/logic-game-framework/example/rts-auto-battle/
├── core/
│   └── rts_auto_battle_procedure.gd          ← _init 末注册装饰 obstacles + air
│                                                  affects_pathfinding=false; tick_once
│                                                  step 6.6 rasterize_if_dirty + step 7.5
│                                                  clear_dirty; +63 行
├── logic/grid/
│   ├── rts_battle_grid.gd                    ← attach_passability_registry 时
│   │                                            navcell_grid.set_origin_world(...) +5 行
│   ├── rts_navcell_grid.gd                   ← +_origin_world 字段 + helpers
│   │                                            (set_origin_world / origin_world / world_to_navcell_i/j /
│   │                                             has_any_dirty / collect_dirty_cells); navcell_center_world /
│   │                                            nearest_navcell 走 origin; +44 行
│   ├── rts_passability_class_config.gd       ← +affects_pathfinding: bool
│   └── rts_passability_class_registry.gd     ← +get_classes + get_class_by_mask
└── logic/obstruction/
    └── rts_obstruction_manager.gd            ← rasterize 改 wrapper 调 _rasterize_class;
                                                  +rasterize_if_dirty / _rasterize_class /
                                                  _collect_blocking_shapes / _inflate_one_shape /
                                                  _clear_dirty_with_buffer / _shape_world_aabb;
                                                  add/move/remove_shape 仅 BLOCK_PATHFINDING shape
                                                  mark dirty(unit shape 是 BLOCK_MOVEMENT,不写
                                                  NavcellGrid bit, perf-critical 修正)
                                                  +210 -94 行
```

### 新建文件

```
addons/.../tests/battle/
├── smoke_clearance_inflate.tscn / .gd       ← 新 smoke (AC1+AC2+AC3+AC8 + 4 sub-test)
└── smoke_clearance_inflate.gd.uid           ← godot import 生成
```

### 替换文件 (新 baseline)

```
addons/.../tests/baselines/
├── 0ad-baseline-master.csv                  ← 829520 bytes (M2 882882 → M3 -53 KB)
└── 0ad-baseline-master.replay.json          ← 含 frames=11 events=97 trace_rows=5769
```

### 子任务 commit

submodule sha **bbaac16**: `feat(rts-m3): M3 done — Clearance + 外扩 (per-class buffer)`

---

## Spec 偏离 (simplify pass 改进, codex review 后续可审)

1. **`_shape_blocks_class` 字符串比较 → `pass_class.affects_pathfinding` flag**
   spec §M3.1 步骤 1 给的伪代码用 `class_name_id == "air"` 字符串比较;改成
   `RtsPassabilityClassConfig.affects_pathfinding: bool` 字段。procedure._init
   注册 air 时显式 `air_cfg.affects_pathfinding = false`。type-safe + 跨 class 名重命名稳定 +
   不依赖 well-known string ID。

2. **NavcellGrid `_origin_world` 字段(spec 没明文要求)**
   M3.3 启用 `rasterize_if_dirty` 后才暴露 ObstructionManager 用 `world / cell_size` 索引
   NavcellGrid,但 RtsBattleGrid 用 HexCoord + half_offset 平移到 NavcellGrid;两边坐标系
   错位 — M2 阶段 rasterize 没被 caller 调过没暴露,M3 启用就报 baseline regression。
   `_origin_world` 让 NavcellGrid 自洽:`navcell_center_world(i,j) = origin + (i+0.5, j+0.5)*cell`,
   `world_to_navcell_i/j` helper 集中坐标转换;RtsBattleGrid attach 时 set_origin_world
   `(-half_cols, -half_rows) * cell_size`,ObstructionManager 全程不需要知道 RtsBattleGrid 内部约定。

3. **装饰 obstacle 自动注册 manager**
   `procedure._init._register_decorative_obstacles_to_manager` 扫
   `grid.model.is_tile_blocking` cells,sort by (q, r) deterministic,每 cell 注册成
   1 cell × cell OBB shape (BLOCK_PATHFINDING|BLOCK_FOUNDATION,group="decorative")。
   否则 `rasterize_if_dirty` 第一次跑会 `_clear_dirty_with_buffer` 清掉 frontend
   `mark_obstacle_cell` 在 `_ready` 阶段标的 cells(那时 manager 还没出生),触发隐式
   baseline regression(单位走过中央障碍区)— stop-runner 第 6 条 P1 风险。

4. **Hoist 优化(simplify pass §7a)**
   - `rasterize_if_dirty` 一次 `collect_dirty_cells` + 跨 class 共享(原:每 class 独立全图扫)
   - `_collect_blocking_shapes(pass_class)` 一次 sort tag + filter,blocking_shapes 跨两遍
     (occupy + inflate)迭代复用
   - `_clear_dirty_with_buffer` 改 dirty-cells list iter(原:全 W×H 扫描)+ 内层 maxi/mini
     提前 clamp(原:逐 cell 判越界)
   - `_shape_world_aabb` 抽 helper 共享给 `_rasterize_one_shape` + `_inflate_one_shape`
     (原:OBB corners 扫两遍)

5. **Unit shape 不 mark navcell dirty(perf-critical 修正)**
   M2 实现 add_unit_shape / move_shape / remove_shape 总是 `_mark_navcell_dirty`;
   unit shape 是 BLOCK_MOVEMENT(不写 NavcellGrid bit),原本不该让周围 cells dirty 触发
   `rasterize_if_dirty` 全图重 rasterize。M3 改:仅 BLOCK_PATHFINDING shape mark dirty。
   避免 100 unit × 30 Hz 每 tick 触发全图重 rasterize(否则 600K+ ops/s)。

---

## 决策来源 / 引用

- spec: `task-plan/m3-0ad-pathfinding-migration/milestones/M3-clearance.md` §M3.1-§M3.4
- 数据结构: `task-plan/m3-0ad-pathfinding-migration/data-structures.md` §1.1 (clearance) + §2.3 (rasterize)
- 风险: `task-plan/m3-0ad-pathfinding-migration/risks-and-rollback.md` §1.3 (baseline CSV 漂 P1) + §3 stop runner 9 条
- 0 A.D. 对照: `CCmpPathfinder.cpp:RecalculateGridDirty` + `Inflate`(本项目用 brute-force 简化)
- M2 末态 baseline: `archive/2026-05-04-rts-m3-m2-obstruction-manager/Summary.md`

---

## 残余风险 → M4 启动

- **R1 brute-force inflate perf**: M2.3 16 building 场景未见 perf 异常;simplify pass hoist 后实际开销低;M4 hierarchical 引入后再 measure
- **R2 baseline CSV 漂**: ✅ 接受新 baseline (829520 bytes),M4 启动出发点
- **R3 multi-class rasterize**: air `affects_pathfinding=false` 短路,实际只 default class 跑 inflate;M4+ 引入飞行单位时打开 air 实际 inflate
- **AC9 体验点 ✋1**: demo 视觉验收推到 M4(M3 inflate 在 baseline trace 上已生效,但用户没 demo 跑)

---

## 下一个 milestone

**M4 — HierarchicalPathfinder**(详见 `task-plan/m3-0ad-pathfinding-migration/milestones/M4-hierarchical.md`)
- M4 依赖 M3:per-class navcell grid passability(已外扩)+ dirty 机制(M4 增量更新触发)+
  ObstructionManager 注册 / 删除链路稳定
- M4 启动等用户授权(milestone-chain 协议:每 milestone 末等用户审阅)
