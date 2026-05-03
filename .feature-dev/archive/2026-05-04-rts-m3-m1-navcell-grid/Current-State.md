# Current State — 2026-05-04 baseline (M3 Epic / M0 done; M1 active)

inkmon-godot baseline 事实快照. M3 Epic / M1 启动用.

> **Active feature**: M3 Epic / M1 (Navcell Grid + 16-bit Passability Class).
>
> **M0 sub-feature**: ✅ 整体完成 + archived (`archive/2026-05-04-rts-m3-m0-footprint-split/`).
>
> **M3 Epic 状态**: codex Round 1-8 APPROVE + M0 done + 14+1 smoke 0 漂移 baseline 就绪.
>
> phase 实现细节 / 决策来源 → 见对应 archive 的 `Summary.md` 或 `task-plan/m3-0ad-pathfinding-migration/`.

---

## 工程结构

- 主仓 `D:\GodotProjects\inkmon\inkmon-godot`,Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`),含 3 个 addon:`logic-game-framework` / `lomolib` / `ultra-grid-map`
- 主仓 entry:`scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- `project.godot` autoload:`Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng`

## 当前 baseline 能力 (M0 末态 = M1 出发点)

M2 末态 RTS 完整可玩 1v1 skirmish + AI vs AI 观战 demo 之上,M0 增量:

- 3 obstruction shape data class:`RtsObstructionShape` 基类 + `Static` 子类(width/height/rotation_rad + get_corners + get_axes)+ `RtsFootprintShape`(CIRCLE/SQUARE + contains + get_world_aabb)
- `RtsBuildingActor` 双路径 `get_footprint_cells`:obstruction_shape != null 走新路径(用 obstruction.center)/ null fallback 旧 footprint_size 路径;`sync_obstruction_shape()` 把 center 设为 `position_2d + obstruction_offset`
- `RtsBuildingConfig.StatBlock` 4 新字段(obstruction_size / obstruction_offset / footprint_shape_type / selection_footprint_size)+ fallback 派生(raw 没显式时从旧 footprint_size 派生)
- `RtsBuildings._create_from_kind` 工厂注入 shape 默认字段;6 个 sync sites(玩家命令 + procedure start + demo 双 ct + demo_pathfinding 4 处 + scenario_harness 2 处)
- `RtsBuildingPlacement.compute_footprint_cells_from_shape` / `compute_footprint_cells_core` public helper(actor + ghost preview + smoke 共用,无双份漂移)
- Frontend visualizer `_footprint_shape` 字段 + `_draw()` 用 `get_world_aabb`(F4-A 决策 = sprite 锚点 = position_2d 不变)
- 期间 hotfix:`get_alive_actor_ids` 过滤 ability_set==null(ResourceNode);scene-driven UI 重构 main_menu / demo_rts_frontend 子树(摆脱代码动态生成);placement event 用 `get_global_mouse_position`(修 Camera zoom=3 偏离);spawn unit rally(玩家手控 demo)

## M3 Epic 已落地的基础设施

- **完整规划文档** (`.feature-dev/task-plan/m3-0ad-pathfinding-migration/`):README + data-structures + interfaces + validation-strategy + risks-and-rollback + 9 milestone (M0-M8 含 sub-phase 拆分) + deferred/0ad-formation-design
- **Trace 基础设施** (M0.1):
  - `addons/.../tools/path_trace_v2.gd` (24 字段 CSV writer)
  - `addons/.../tests/battle/smoke_pathfinding_baseline.{tscn,gd}` (PASS 900 ticks / 6155 rows / 111 events)
  - `addons/.../tests/baselines/0ad-baseline-master.csv` (882 KB,byte-identical 跨 run)
  - `addons/.../tests/baselines/0ad-baseline-master.replay.json` (34 KB)
- **0 A.D. 本地参考副本** (开发期对照): `addons/.../docs/references/0ad-source/` (sparse `source/simulation2/`,9.2 MB,git ignore)
- **M0 acceptance smoke** (M0.7): `tests/battle/smoke_obstruction_footprint_split.{tscn,gd}` (M1 启动前 0 漂移基线 +1 项)

## 测试基线 (M0 末态 = 14+1+1 项 + LGF 73)

| 入口 | 末态 |
|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | **73/73 PASS** |
| `tests/battle/smoke_rts_auto_battle.tscn` | left_win, ticks=347, attacks=74, melee=32, ranged=42, melee_max=24.00 |
| `tests/battle/smoke_castle_war_minimal.tscn` | left_win, ticks=193 |
| `tests/battle/smoke_player_command.tscn` | gold=20 wood=50 |
| `tests/battle/smoke_player_command_production.tscn` | ticks=600 left_spawned=7 |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | ticks=200 alive=5 |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 gold=140 wood=212 |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | ai_units_spawned=4 |
| `tests/battle/smoke_flying_units.tscn` | PASS |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=9 events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 |
| `tests/frontend/smoke_ui_main_menu.tscn` | demo=RtsFrontendDemo |
| `tests/battle/smoke_pathfinding_baseline.tscn` | ticks=900 trace_rows=6155 events=111 |
| `tests/battle/smoke_obstruction_footprint_split.tscn` | (M0.7 新)set_b=4 set_c=10 (B ∩ C)=∅ |

## M3 Epic 关键决策(D 系列,详见 `task-plan/m3-0ad-pathfinding-migration/README.md` §0.3)

- **D1**: 混合避让方案 = 0 A.D. short path + 本项目 sep force 微调(⚠️ 有意偏离 0 A.D.)
- **D2**: 复刻 4 个独立 component (Position / Obstruction / Footprint / Motion);Motion.clearance ≡ Obstruction.radius
- **D6**: LongPath 用朴素 A*(⚠️ 有意简化,不做 JPS)
- **D9**: group_filter 在 M6/M7 已是 API 输入,M8 仅打开 + tune
- **D10**: RegionID 用 packed int64 (24+24+16 bit) — 不能用 RefCounted (Godot 4.6 实测 Dict key 走实例身份)
- **D11**: §12 determinism 总排序 contract 显式定义 — heap 5 元组 + spatial bucket / vertex / obstruction / commands 顺序 / 浮点处理
- **R5 P1-1**: tick 排序 key = `(kind: String, spawn_seq: int)` 数值复合 key(**不**用 actor.get_id() 字典序;IdGenerator 真实输出 `Character_10 < Character_2` 漂移)
- **R5 P1-2**: dirty lifecycle = rasterize / hierarchical update 都只读,RtsWorld.tick step 7 末端统一 `clear_dirty()`

## 关键约束 (跨 phase / sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** — 新代码进 `addons/logic-game-framework/example/rts-auto-battle/`
2. **三层架构**: `core ← logic ← frontend`
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认**

M3 Epic 新增约束:
7. **保持 replay bit-identical** — 每个 milestone 必须 PASS `smoke_replay_bit_identical seed=42 frames=9 events=20 deep-equal`
8. **Determinism §12 contract** — 任何 tie-break 路径必须有显式 deterministic key(详见 `data-structures.md §12`)

## Git 状态

- 主仓 master ahead of origin/master(M3 Epic + M0 实施期间累积 commit 待推)
- submodule `addons/logic-game-framework` HEAD=18ae582(M0 末态 + scene-driven UI hotfix)
- M0 archive sweep 待 commit(本文件 + Progress / Next-Steps / m3 README / M0.md status 修订)

## 决策来源 (历史 sub-feature → archive)

- **M0 Footprint 拆分 + Bug 1** (2026-05-04): `archive/2026-05-04-rts-m3-m0-footprint-split/` ← **最近**
- M2.3 UI/HUD/BuildPanel/关卡 (2026-05-03): `archive/2026-05-03-rts-m2-3-ui-hud/`
- M2.2 AI 对手 (2026-05-02): `archive/2026-05-02-rts-m2-2-ai-opponent/`
- M2.1 经济 (2026-05-02): `archive/2026-05-02-rts-m2-1-economy/`
- M1 RTS 重构 (2026-05-02): `archive/2026-05-02-rts-m1-refactor/`
- 早期 RTS 例子骨架 (2026-04-30): `archive/2026-04-30-rts-auto-battle/`
- M2 整体路线图: `task-plan/m2-roadmap.md`
- **M3 Epic 完整规划**: `task-plan/m3-0ad-pathfinding-migration/`
- **M3 Epic codex 审查记录**: `Handoff-2026-05-03-0ad-migration-planning.md` (R1-R4) + `Handoff-2026-05-03-step-b-codex-review.md` (R5-R8)
