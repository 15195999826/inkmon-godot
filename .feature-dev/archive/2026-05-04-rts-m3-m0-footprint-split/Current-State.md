# Current State — 2026-05-03 baseline (M3 Epic 启动前)

inkmon-godot baseline 事实快照. M3 Epic / M0 启动用.

> **Active feature**: M3 Epic / M0 (Footprint 拆分 + Bug 1 修复).
>
> **M2 milestone**: ✅ 整体完成 + archived (M2.1 经济 + M2.2 AI + M2.3 UI/HUD).
>
> **M3 Epic 状态**: codex Round 1-8 APPROVE,Step A + Step B 完成,M0 待 runner 启动.
>
> phase 实现细节 / 决策来源不在本文件 → 见对应 archive 的 `Summary.md` 或 `task-plan/m3-0ad-pathfinding-migration/`.

---

## 工程结构

- 主仓 `D:\GodotProjects\inkmon\inkmon-godot`, Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`), 含 3 个 addon: `logic-game-framework` / `lomolib` / `ultra-grid-map`
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- `project.godot` autoload: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng`

## 当前 baseline 能力 (RTS auto-battle 例子)

末态能力 (M2 done; M3 出发点):

- Actor 三层基类 + 共享攻击协议 + AIR/GROUND layer
- 30Hz fixed-tick + RtsRng 决定性 + bit-identical replay (`smoke_replay_bit_identical seed=42 frames=9 events=20`)
- Activity 系统 (Idle / MoveTo / Attack / AttackMove / Harvest / ReturnAndDrop)
- 4 层避障 (spatial hash + steering + stuck detection + group formation)
- AutoTargetSystem (priority + stance, 含建筑作目标候选)
- Production System (RtsBuildingActor 工厂)
- Player Command (RtsPlayerCommand + RtsPlayerCommandQueue tick-stamped, 真实 API: `apply_due(procedure, world, current_tick)`)
- 胜负判定 (crystal-tower-死亡优先 + fallback team-wipeout)
- Frontend BattleDirector (流式 push, 0 actor 直读, alpha 插值)
- 经济系统 (worker harvest → drop-off + 双资源 dict cost)
- AI 对手 (RtsComputerPlayer team-level + 走 PlayerCommandQueue 同接口)
- BuildPanel + placement mode + ghost preview
- Minimap + Camera2D zoom + WASD pan + 点跳
- Main menu + RtsMatchPreset Resource + 3 预设 (Classic 1v1 / Resource Scarce 1v1 / AI vs AI Observe)

## M3 Epic 已落地的基础设施 (Step A + Step B)

- **完整规划文档** (`.feature-dev/task-plan/m3-0ad-pathfinding-migration/`):README + data-structures + interfaces + validation-strategy + risks-and-rollback + 9 milestone (M0-M8 含 sub-phase 拆分) + deferred/0ad-formation-design
- **Trace 基础设施** (M0.1 已落地):
  - `addons/.../tools/path_trace_v2.gd` (24 字段 CSV writer)
  - `addons/.../tests/battle/smoke_pathfinding_baseline.{tscn,gd}` (PASS 900 ticks / 6155 rows / 111 events)
  - `addons/.../tests/baselines/0ad-baseline-master.csv` (882 KB,byte-identical 跨 run)
  - `addons/.../tests/baselines/0ad-baseline-master.replay.json` (34 KB)
- **0 A.D. 本地参考副本** (开发期对照): `addons/.../docs/references/0ad-source/` (sparse `source/simulation2/`,9.2 MB,git 已 ignore)

## 测试基线 (M2.3 末态; 14 项 smoke + LGF 73 + new baseline)

| 入口 | 用途 | 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance | left_win, ticks=347, attacks=74, melee=32, ranged=42, melee_max=24.00 |
| `tests/battle/smoke_castle_war_minimal.tscn` | 城堡战争端到端 | left_win, ticks=193 |
| `tests/battle/smoke_player_command.tscn` | placement + 资源扣减 | gold=20 wood=50 |
| `tests/battle/smoke_player_command_production.tscn` | 玩家命令 → production | ticks=600 left_spawned=7 |
| `tests/battle/smoke_production.tscn` | 生产周期 | ticks=600 left=7 right=7 |
| `tests/battle/smoke_crystal_tower_win.tscn` | 水晶塔胜负 | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | HarvestStrategy | ticks=200 alive_workers=5 |
| `tests/battle/smoke_harvest_loop.tscn` | worker harvest cycle | ticks=600 gold=140 wood=212 |
| `tests/battle/smoke_economy_demo.tscn` | full 经济闭环 | ticks=900 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | AI 自主 build + attack-move | ai_units_spawned=4 |
| `tests/replay/smoke_replay_bit_identical.tscn` | bit-identical replay | seed=42 frames=9 events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | 同 seed → 同结果 | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟 | visualizers=10 |
| `tests/frontend/smoke_ui_main_menu.tscn` | main_menu → demo apply_preset | demo=RtsFrontendDemo |
| **新加** `tests/battle/smoke_pathfinding_baseline.tscn` | M3 Epic baseline trace + replay | ticks=900 trace_rows=6155 events=111 |

具体数字 / fixture 完整内容见各 archive 的 Progress.md.

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

- 主仓 master ahead of origin/master 8 commits(Step A + Step B 文档变更未推)
- submodule `addons/logic-game-framework` 有 untracked baseline + smoke 文件(未 commit)
- 主仓 untracked: `Handoff-2026-05-03-step-b-codex-review.md` + `task-plan/m3-0ad-pathfinding-migration/`(部分新文件)+ R5-R8 修改

## 决策来源 (历史 sub-feature → archive)

- M2.3 UI/HUD/BuildPanel/关卡 (2026-05-03): `archive/2026-05-03-rts-m2-3-ui-hud/`
- M2.2 AI 对手 (2026-05-02): `archive/2026-05-02-rts-m2-2-ai-opponent/`
- M2.1 经济 (2026-05-02): `archive/2026-05-02-rts-m2-1-economy/`
- M1 RTS 重构 (2026-05-02): `archive/2026-05-02-rts-m1-refactor/`
- 早期 RTS 例子骨架 (2026-04-30): `archive/2026-04-30-rts-auto-battle/`
- M2 整体路线图: `task-plan/m2-roadmap.md`
- **M3 Epic 完整规划**: `task-plan/m3-0ad-pathfinding-migration/`
- **M3 Epic codex 审查记录**: `Handoff-2026-05-03-0ad-migration-planning.md` (R1-R4) + `Handoff-2026-05-03-step-b-codex-review.md` (R5-R8)
