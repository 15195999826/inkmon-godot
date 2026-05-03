# Current State — 2026-05-03 baseline (M2 milestone done)

inkmon-godot baseline 事实快照. 开新 sub-feature 前对齐用.

> **Active feature**: 无. 上一个 sub-feature **M2.3 UI/HUD/BuildPanel/关卡** 已 archive (2026-05-03).
>
> **M2 milestone**: ✅ 整体完成 (M2.1 经济 + M2.2 AI 对手 + M2.3 UI/HUD).
>
> phase 实现细节 / 决策来源不在本文件 → 见对应 archive 的 `Summary.md`.

## 工程结构

- 主仓 `D:\GodotProjects\inkmon\inkmon-godot`, Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`), 含 3 个 addon: `logic-game-framework` / `lomolib` / `ultra-grid-map`
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- `project.godot` autoload: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng`

## 当前 baseline 能力 (RTS auto-battle 例子)

末态能力 (M2 done; M3 出发点):

- Actor 三层基类 + 共享攻击协议 + AIR/GROUND layer
- 30Hz fixed-tick + RtsRng 决定性 + bit-identical replay
- Activity 系统 (Idle / MoveTo / Attack / AttackMove / Harvest / ReturnAndDrop)
- 4 层避障 (spatial hash + steering + stuck detection + group formation)
- AutoTargetSystem (priority + stance, 含建筑作目标候选)
- Production System (RtsBuildingActor 工厂)
- Player Command (RtsPlayerCommand + RtsPlayerCommandQueue tick-stamped)
- 胜负判定 (crystal-tower-死亡优先 + fallback team-wipeout)
- Frontend BattleDirector (流式 push, 0 actor 直读, alpha 插值)
- 经济系统 (worker harvest → drop-off + 双资源 dict cost)
- AI 对手 (RtsComputerPlayer team-level + 走 PlayerCommandQueue 同接口)
- BuildPanel + placement mode + ghost preview
- Minimap + Camera2D zoom + WASD pan + 点跳
- Main menu + RtsMatchPreset Resource + 3 预设 (Classic 1v1 / Resource Scarce 1v1 / AI vs AI Observe)

## 测试基线 (M2.3 末态; 15 项全过 0 漂移)

| 入口 | 用途 | 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance | left_win, ticks=347, attacks=74 |
| `tests/battle/smoke_castle_war_minimal.tscn` | 城堡战争端到端 | left_win, ticks=193 |
| `tests/battle/smoke_player_command.tscn` | placement + 资源扣减 | gold=20 wood=50 |
| `tests/battle/smoke_player_command_production.tscn` | 玩家命令 → production | ticks=600 left_spawned=7 |
| `tests/battle/smoke_production.tscn` | 生产周期 | ticks=600 left=7 right=7 |
| `tests/battle/smoke_crystal_tower_win.tscn` | 水晶塔胜负 | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | HarvestStrategy | ticks=200 alive_workers=5 |
| `tests/battle/smoke_harvest_loop.tscn` | worker harvest cycle | ticks=600 gold=140 wood=212 |
| `tests/battle/smoke_economy_demo.tscn` | full 经济闭环 | ticks=900 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | AI 自主 build + attack-move | ai_units_spawned=4 |
| `tests/replay/smoke_replay_bit_identical.tscn` | bit-identical replay | seed=42 frames=9 events=20 |
| `tests/replay/smoke_determinism.tscn` | 同 seed → 同结果 | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟 | visualizers=10 |
| `tests/frontend/smoke_ui_main_menu.tscn` | main_menu → demo apply_preset | demo=RtsFrontendDemo |

具体数字 / fixture 完整内容见各 archive 的 Progress.md.

## 关键约束 (跨 phase / sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** — 新代码进 `addons/logic-game-framework/example/rts-auto-battle/`
2. **三层架构**: `core ← logic ← frontend`
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认**

## Git 状态

主仓 master 与 origin/master 一致 (M1 + M2.1 + M2.2 + M2.3 已 commit; archive 在最后一个 commit).

## 决策来源 (历史 sub-feature → archive)

- M2.3 UI/HUD/BuildPanel/关卡 (2026-05-03): `archive/2026-05-03-rts-m2-3-ui-hud/`
- M2.2 AI 对手 (2026-05-02): `archive/2026-05-02-rts-m2-2-ai-opponent/`
- M2.1 经济 (2026-05-02): `archive/2026-05-02-rts-m2-1-economy/`
- M1 RTS 重构 (2026-05-02): `archive/2026-05-02-rts-m1-refactor/`
- 早期 RTS 例子骨架 (2026-04-30): `archive/2026-04-30-rts-auto-battle/`
- M2 整体路线图: `task-plan/m2-roadmap.md`
