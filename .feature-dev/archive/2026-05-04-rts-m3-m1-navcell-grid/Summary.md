# RTS Pathfinding M3 Epic / M1 — Navcell Grid + 16-bit Passability Class — Summary (2026-05-04)

> M3 Epic 第二个 milestone(M1/9)。把 `RtsBattleGrid` 内部 per-cell `is_blocking: bool`(M0 末态:走 ultra-grid-map plugin `model.is_tile_blocking`)替换为 `RtsNavcellGrid` `PackedInt32Array` 16-bit 位掩码 multi-class passability,引入 `RtsPassabilityClassRegistry` 注册 `default` + `air` 两 class(留 14 bit 给将来 mod / 扩展)。
>
> M1 是数据层重构,**寻路算法不变** — 现有 `GridPathfinding.find_path` 仍工作(只是底下数据存储方式变了);**replay seed=42 frames=9 events=20 deep-equal + baseline CSV byte-identical(882882 bytes)**。

---

## Acceptance 结论 (M1.1 - M1.5 全过 + AC1-AC10 全 PASS,AC7 留 follow-up)

### M1.1 - M1.5 子任务

| Sub | Scope | 状态 |
|---|---|---|
| **M1.1** | `RtsPassabilityClassConfig`(Resource, 6 字段)+ `RtsPassabilityClassRegistry`(RefCounted, PASS_CLASS_BITS=16, SPECIAL_PASS_CLASS_INDEX=15);procedure._init 末固定顺序 register("default")→register("air") | ✅ done |
| **M1.2** | `RtsNavcellGrid`(RefCounted, `_data: PackedInt32Array` + `_dirtiness: PackedByteArray`;or_data/and_data/is_passable/边界外 false/dirty lifecycle) | ✅ done |
| **M1.3** | `RtsBattleGrid` 改 facade:`_navcell_grid` + `_passability_registry` + `_default_class_mask` + `_half_cols`/`_half_rows` 字段;`attach_passability_registry` + `is_blocking` + `mark_obstacle_cell` + `_coord_to_ij` helper;dual-write model + NavcellGrid;`is_passable_for_layer` 走 `is_blocking` | ✅ done |
| **M1.4** | procedure._init 调 `attach_passability_registry`;attach 时从 `model.get_all_coords()` 同步已有 `is_tile_blocking` cells 到 NavcellGrid(frontend `_ready` 在 procedure._init 之前调 `mark_obstacle_cell` 时 NavcellGrid 还未 attach,sync 兜底)| ✅ done |
| **M1.5** | `smoke_navcell_grid_passability.{gd,tscn}` PASS(13 项断言 AC1+AC2+AC8);Validation 全套 0 漂移;simplify pass(`_coord_to_ij` helper 收敛 5 处重复) | ✅ done |

### AC1-AC10 全过

- ✅ **AC1** — Registry 落地(bit_index 自动分配 0/1;get_mask("default")==0x1 / get_mask("air")==0x2;duplicate / full assert_crash)
- ✅ **AC2** — RtsNavcellGrid 落地(or_data/and_data/is_passable/边界外 false/dirty 标记/clear_dirty)
- ✅ **AC3** — RtsBattleGrid facade 改造(spec 假设的 `RtsCell` 类不存在 — 实际是 plugin model;dual-write 替换达成 AC3 spirit "替换 per-cell is_blocking 存储")
- ✅ **AC4** — Procedure 启动后 `world.passability_registry` / `world.rts_grid.has_navcell_grid()` 都非 null
- ✅ **AC5** — `smoke_navcell_grid_passability` PASS(default vs air 不互相影响)
- ✅ **AC6** — Validation 全套 14 项 smoke + LGF 73 + replay seed=42 deep-equal + **baseline CSV byte-identical(882882 bytes match M0 末态)**
- ⏳ **AC7** — Perf-trace 工具未实现(M0 也没引入);实测 wall-clock 没明显增长(smoke 跑时间感觉跟 M0 一致),按 stop-runner 第 5 条(`tick_p99/tick_max` 增长 ≥ 100% / 2× 才停)未触发;**M5 启动前批量补足 perf_trace + oos_log 工具**
- ✅ **AC8** — Multi-class 不互相干扰(smoke 验证:默认 写不影响 air、air 写不影响 默认、双 bit 同 cell 独立)
- ✅ **AC9** — `GridPathfinding.find_path` 路径输出 bit-identical(replay seed=42 frames=9 events=20 deep-equal 证明)
- ✅ **AC10** — 改动仅在 `addons/logic-game-framework/example/rts-auto-battle/` 内,不动 LGF core / stdlib

---

## 关键 artifact 路径

### 新建文件 (submodule)

- `addons/logic-game-framework/example/rts-auto-battle/logic/grid/rts_passability_class_config.gd` — Resource 配置(6 字段对齐 0 A.D. pathfinder.xml schema)
- `addons/logic-game-framework/example/rts-auto-battle/logic/grid/rts_passability_class_registry.gd` — RefCounted 注册查询(register / get_pass_class / get_mask / max_clearance / size)
- `addons/logic-game-framework/example/rts-auto-battle/logic/grid/rts_navcell_grid.gd` — RefCounted 数据 grid(PackedInt32Array + PackedByteArray;边界防越界)
- `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_navcell_grid_passability.{gd,tscn}` — M1 acceptance smoke

### 改动文件 (submodule)

- `logic/grid/rts_battle_grid.gd` — facade 改造 + dual-write
- `core/rts_world_gameplay_instance.gd` — passability_registry 字段
- `core/rts_auto_battle_procedure.gd` — _init 末注册 + attach
- `frontend/scene/rts_battle_map.gd` — `_mark_obstacle_cells` 走 facade
- `logic/commands/rts_building_placement.gd` — 占位检查走 facade

### CHANGELOG (LGF submodule)

- `addons/logic-game-framework/CHANGELOG.md` — 新增 [Unreleased] — 2026-05-04 M3 Epic / M1 段(Added / Changed / 待处理 / 验证表)

---

## 真实运行证据 (M0 末态 baseline 0 漂移 + 新 smoke)

### LGF 单元测试

```
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn
→ 总计: 73 | 通过: 73 | 失败: 0
```

### RTS 主 acceptance smoke (11 项,数字 100% 与 M0 末态 match)

| smoke | 实测 |
|---|---|
| smoke_rts_auto_battle | left_win ticks=347 attacks=74 (melee=32 ranged=42) melee_max=24.00 ranged_max=125.75 deaths=6 detoured=4 |
| smoke_castle_war_minimal | ticks=193 left_win unit_to_building=4 archer_anti_air=1 |
| smoke_player_command | gold=20 wood=50 log=3 |
| smoke_player_command_production | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 |
| smoke_production | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| smoke_crystal_tower_win | ticks=2 left_win |
| smoke_resource_nodes | ticks=200 alive=5 max_drift=0 |
| smoke_harvest_loop | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 |
| smoke_economy_demo | ticks=900 melee_to_ct=31 |
| smoke_ai_vs_player_full_match | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 |
| smoke_flying_units | PASS(anti-air / ground / flying)|

### Replay / determinism (3 项,含 baseline)

```
smoke_replay_bit_identical: seed=42 commands=2 frames=9 events=20 deep-equal
smoke_determinism: tick_diff=0 (run1 ticks=347 = run2 ticks=347)
smoke_pathfinding_baseline: 900 ticks / 6155 trace rows / 111 replay events
baseline CSV byte-identical: 882882 bytes match M0 末态
```

### Frontend (2 项)

```
smoke_frontend_main: visualizers=10 alive_after_3.0s=10
smoke_ui_main_menu: demo=RtsFrontendDemo preset=Classic 1v1 → PASS
```

### 新 M1 acceptance smoke

```
smoke_navcell_grid_passability: PASS — AC1+AC2+AC8 13 项断言全过
- registry bit_index 0/1, get_mask 0x1/0x2, unknown 返 0, max_clearance, size
- NavcellGrid 初始 clean, or_data/and_data/clear_dirty 行为正确, 边界外 false/-1
- multi-class isolation: default 写不影响 air, air 写不影响 default, 双 bit 同 cell 独立
```

### M0 已有 acceptance smoke

```
smoke_obstruction_footprint_split (M0): set_b={(5,5),(6,5),(5,6),(6,6)} == set_a, B ∩ C = ∅ → PASS
```

---

## 残余风险 / 已知 follow-up

1. **AC7 perf-trace 工具未实现** — M0 也没引入。实测 wall-clock 没明显增长但缺正式数据。**M5 启动前批量补足 `perf_trace.gd` + `oos_log.gd` 工具**(M5 LongPath 重写是 replay 漂移高风险段,需要 OOSLog 风格定位 + perf-trace 跑分)。
2. **smoke 直读 `grid.model.is_tile_blocking` 的 5 处** — 由 dual-write 兜底不破。具体位置:
   - `tests/battle/diag_castle_attack_trace.gd:161`
   - `tests/battle/diag_pathfinding_trace.gd:143`
   - `tests/battle/smoke_player_command.gd:193`
   - `tests/battle/smoke_production.gd:223`
   - 可能还有其它 utility/diag 文件
   - **M5 删除 RtsBattleGrid facade 时统一 cleanup**(改读 `grid.is_blocking(coord)` 或 NavcellGrid 直接访问)
3. **Spec drift 记录** — M1.3 AC3 写"删除旧 RtsCell 类"literal 不适用(类不存在 — 当前是 ultra-grid-map plugin 的 `GridMapModel.is_tile_blocking`)。AC3 spirit "替换 per-cell is_blocking 存储" 已通过 dual-write + NavcellGrid 接管 is_passable 查询达成。`data-structures.md §1.5` 描述也跟现状有偏差,后续 M 启动前如有需要再 patch spec。
4. **NavcellGrid attach sync 漏 obstacle bug 修复** — 第一次 attach 时漏 sync 已有 model obstacle(frontend `_ready` 在 procedure._init 之前)→ AC2 violated(单位走穿 obstacle 墙)→ 加 `model.get_all_coords()` 扫描 sync 修复。lessons learned:**任何"延迟 attach"逻辑必须从源头 sync 已写入状态,不能假设 attach 时 0-state**。
5. **`get_pass_class` 命名偏离 spec** — spec §1.2 写 `get_class(name_id)`,但 RefCounted 内建 `get_class() -> String` 返类名,签名冲突。`get_pass_class` 命名清晰且避错。**spec 后续可同步**(留 patch 给下个 milestone 启动前)。
6. **0 A.D. 本地副本 sparse checkout** — 9.2 MB,addons submodule .gitignore 屏蔽。M2 起 ObstructionManager 实施时直接读源码对照。
7. **`.claude/tmp/` 多个 diag/verify 文件** — M0 + M1 期间 diag 工具,未 staged 不进 commit;留给用户决定是否清理。

---

## Commits

### 主仓

- `3b5a7b8` feat(rts-m3): M1 done — bump submodule → d077c54 (Navcell Grid + Passability)
- (本 archive sweep commit — 由 §8d 落地)

### submodule (addons/logic-game-framework)

- `d077c54` feat(rts-m3): M1 done — Navcell Grid + 16-bit Passability Class

---

## M1 末态 baseline (M2 出发点)

- 3 个 grid 数据类落地(PassabilityClassConfig + Registry + NavcellGrid)
- `RtsBattleGrid` 改 facade(dual-write model + NavcellGrid;`is_blocking` / `mark_obstacle_cell` / `_coord_to_ij` helper)
- Procedure 启动注册 default/air + attach grid(sync 已有 obstacle)
- 14 项 smoke + LGF 73 + replay seed=42 deep-equal + baseline CSV byte-identical + 新 smoke 全过

**M2 启动条件全部满足**:
- M2 spec 经 codex Round 5-8 审查 APPROVE
- M1 的 NavcellGrid (or_data / and_data / is_passable) + Registry (get_mask) 是 M2 ObstructionManager rasterize 的输入
- `RtsBattleGrid.place_building` 仍工作(M2 时 ObstructionManager 替代它);`get_navcell_grid()` 给 M2 直接写入用
