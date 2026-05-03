# Current State — 2026-05-03 (RTS M2.3 done; M2 milestone 整体完成)

inkmon-godot baseline 事实快照. 开新 sub-feature 前对齐用.

> **Active feature**: 无. 上一个 sub-feature **RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡** 已完成系统功能验收并归档 (2026-05-03; archive `archive/2026-05-03-rts-m2-3-ui-hud/`)
>
> **M2 milestone**: ✅ 整体完成 (M2.1 + M2.2 + M2.3 三 sub-feature 全部 done + archived)

## M2.3 末态 (M3 出发点 / 现行 baseline)

4 phase 全过 (2026-05-03), 24 AC PASS, 15/15 validation 全套 0 漂移, bit-identical replay 0 漂移:

### Phase A — BuildPanel + Placement Mode + HUD icon
- `frontend/ui/build_panel.{gd,tscn}` — RtsBuildPanel (Control 屏幕底部居中 + Button × N + ColorRect icon + cost tooltip + emit signal `building_selected(kind: String)`)
- demo placement mode 状态机 — `_placement_kind: String` + `_placement_ghost: ColorRect` + `_placement_stats` 缓存; `_enter_/_exit_/_update_placement_ghost` + `_try_place_at` + `_validate_player_placement` helper; ghost 跟鼠标 + grid snap + RtsBuildingPlacement.validate 同步预检 → tint 绿/红
- 玩家输入 — `_unhandled_input` 走 placement mode (左键 enqueue / ESC / 右键取消); 不在 mode 时左键不入命令 (M2.2 demo 直放 barracks 行为废弃)
- HUD 升级 — `_setup_hud` VBox + 2 HBox(ColorRect icon + Label) (gold/wood) + hint Label + hp Label

### Phase B — Minimap + Camera2D + WASD pan
- `frontend/ui/minimap.{gd,tscn}` — RtsMinimap (Control 屏幕右下角 150×150); _draw 批量画 BG + 边框 + actor 点 (team color: 0=蓝/1=红/-1=黄, building max_hp ≥ 400 用 4×4 / unit 2×2) + camera viewport 框 (camera.global_position ± viewport.size/2/zoom); _gui_input 左键 → emit `world_position_clicked(world_pos)`
- demo Camera2D — BattleMap 子节点, position=(250, 250), zoom=3, limit_*=0..500, make_current; WASD 移 camera (200 px/s) — `_register_camera_keys` 注册 WASD 到 ui_left/right/up/down; placement mode 期间禁 WASD 避免冲突
- director — `_render_states["team_id"]` 加字段 (frontend/core 内接口扩展, 不破 visualizer 协议)

### Phase C — Main menu + 3 预设
- `frontend/preset/rts_match_preset.gd` — RtsMatchPreset extends Resource (字段 starting_resources_left/right / num_workers_per_team / attach_left/right_ai / show_build_panel); 3 静态工厂 create_classic_1v1 / create_resource_scarce_1v1 / create_ai_vs_ai_observe; `all_presets()` 列表
- `frontend/main_menu.{gd,tscn}` — RtsMainMenu (Control + VBox 居中 + 标题 Label + N Button); 点 Button → 实例化 demo + apply_preset + parent.add_child + queue_free(self)
- demo._preset 字段 + apply_preset 接口 + _ready 头部 read effective values (eff_*) 替换 hardcode (preset = null 时走 fallback hardcode 保 frontend smoke 路径不破); show_build_panel = false 时 _setup_build_panel + _setup_placement_ghost 跳过

### Phase D — smoke_ui_main_menu + 收口 + archive
- `tests/frontend/smoke_ui_main_menu.{gd,tscn}` — headless 验 main_menu → demo apply_preset 链路 (instantiate menu + 模拟点 Button → 验 demo 加 child + demo._preset 不空); SMOKE_TEST_RESULT: PASS
- 全套 15 项 validation 0 漂移
- archive `archive/2026-05-03-rts-m2-3-ui-hud/` (Summary + 全 phase 文档快照)

## M2.2 末态 (M2.3 之前 baseline; 仍是)

详见 archive `archive/2026-05-02-rts-m2-2-ai-opponent/`.

要点: AI 对手 (RtsComputerPlayer / 30 tick 决策 / barracks 1 cap / ≥3 unit 后 attack-move once); demo 双方都 attach AI (F6 默认 AI vs AI 自跑); bit-identical replay 不破.

## M2.1 末态

详见 archive `archive/2026-05-02-rts-m2-1-economy/`.

要点: 双资源 (gold + wood) cost 全链路 dict; RtsResourceNode + UnitClass.WORKER + StatBlock carry_capacity / harvest_speed; RtsHarvestActivity / RtsReturnAndDropActivity; crystal_tower 兼 drop-off; barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100}.

## 工程结构

- 主仓 `D:\GodotProjects\inkmon\inkmon-godot`, Godot 4.6 项目
- `addons/` 是单一 git submodule (→ `godot-addons.git`), 含三个 addon: `logic-game-framework` / `lomolib` / `ultra-grid-map`
- 主仓 entry: `scenes/Simulation.tscn` + `scripts/SimulationManager.gd` (Web/headless 桥接)
- **`project.godot` autoload 列表**: `Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` / `RtsRng` (M2.3 不动 autoload)

## RTS 示例当前状态

### RTS M1 / M2.1 / M2.2 / M2.3 全部已归档
- 2026-05-02 归档 M1 / M2.1 / M2.2
- 2026-05-03 归档 M2.3

末态能力 (M3 出发点):
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
- BuildPanel + placement mode + ghost preview (M2.3 Phase A)
- Minimap + Camera2D zoom + WASD pan + 点跳 (M2.3 Phase B)
- Main menu + RtsMatchPreset Resource + 3 预设 (M2.3 Phase C)

## 测试基线 (M2.3 末态; 15 项全过 0 漂移)

| 入口 | 用途 | M2.3 末态 |
|---|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | LGF 核心单元测试 | **73/73 PASS** |
| `tests/battle/smoke_rts_auto_battle.tscn` | 4v4 主 acceptance | left_win, ticks=347, attacks=74 (melee=32 ranged=42), melee_max=24.00 |
| `tests/battle/smoke_castle_war_minimal.tscn` | 城堡战争端到端 | left_win, ticks=193, unit_to_building=4, archer_anti_air=1 |
| `tests/battle/smoke_player_command.tscn` | placement + 资源扣减 | gold_remaining=20 wood_remaining=50 log_entries=3 |
| `tests/battle/smoke_player_command_production.tscn` | 玩家命令 → production | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 |
| `tests/battle/smoke_production.tscn` | 生产周期 | ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | 水晶塔胜负 | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | HarvestStrategy fallback to Idle | ticks=200 alive_workers=5 max_drift=0.00 |
| `tests/battle/smoke_harvest_loop.tscn` | worker harvest cycle | ticks=600 alive_workers=5 team_gold=140 team_wood=212 cycle_workers=5 |
| `tests/battle/smoke_economy_demo.tscn` | full 经济闭环 | ticks=900 alive_workers=5 cycle_workers=5 melee_to_ct_attacks=31 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | AI 自主 build + attack-move | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 |
| `tests/replay/smoke_replay_bit_identical.tscn` | bit-identical replay | seed=42 commands=2 frames=9 events=20 (deep-equal) |
| `tests/replay/smoke_determinism.tscn` | 同 seed → 同结果 | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | 前端 visualizer 冒烟 | visualizers=10 alive_after_3.0s=10 |
| `tests/frontend/smoke_ui_main_menu.tscn` (新增 M2.3) | main_menu → demo apply_preset 链路 | demo=RtsFrontendDemo preset=Classic 1v1 |

## Git 状态 (M2.3 收口阶段)

主仓 master 与 origin/master 一致 (M1 + M2.1 + M2.2 + M2.3 已 commit; archive 在最后一个 commit).

## 关键约束 (跨 phase / sub-feature 不变)

来自 `Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** (新代码进 `addons/logic-game-framework/example/rts-auto-battle/`)
2. **三层架构**: `core ← logic ← frontend`
3. **Headless 测试入口规范**: `SMOKE_TEST_RESULT: PASS|FAIL - <reason>` + 退出码 0
4. **跑 headless 不要 pipe**: redirect 到 `/tmp/*.txt` 再读
5. **不要 `godot --script`**: 永远用 `.tscn` 入口
6. **修改 `project.godot` autoload 需用户确认**

## 决策来源

- M2.3 4 phase 拆分 + 用户决策表: `archive/2026-05-03-rts-m2-3-ui-hud/task-plan/m2-3-ui-hud/README.md`
- M2 整体路线图 (M2.1 + M2.2 + M2.3 全过): `task-plan/m2-roadmap.md`
- M2.3 Phase A/B/C/D 完整决策 + 实施: `archive/2026-05-03-rts-m2-3-ui-hud/Summary.md`
- M2.2 完整 archive: `archive/2026-05-02-rts-m2-2-ai-opponent/`
- M2.1 完整 archive: `archive/2026-05-02-rts-m2-1-economy/`
- RTS M1 完整决策: `archive/2026-05-02-rts-m1-refactor/task-plan/architecture-baseline.md`
