# RTS M2 路线图

> RTS M1 (架构重构) 已收口归档 (2026-05-02). M2 是从 "tech demo" 演进为 "可玩单人 RTS skirmish 模式" 的 milestone, 拆成 3 个 sub-feature 串行。

---

## M2 整体目标

让 RTS 例子从 RTS M1 末态的"双方各 4 unit + 玩家放兵营 + crystal-tower 胜负"扩展为"玩家 vs AI + 资源经济 + 多建筑选择 + 关卡选单"的可玩 skirmish demo, 不再仅是 tech demo。

### M2 设计原则 (跨 sub-feature 锁定)

- **遵守 RTS M1 架构**: 13 条决策 (见 archive `task-plan/architecture-baseline.md`) 不动; 三层依赖 + Activity 系统 + AutoTargetSystem + RtsRng 决定性 + bit-identical replay 全部跨 sub-feature 不变
- **不修改 LGF submodule core / stdlib**: 全部新代码进 `addons/logic-game-framework/example/rts-auto-battle/`
- **每 sub-feature 收口 = headless smoke + 编辑器 F6 视觉双轨验证**: 单纯 logic 测过不算完
- **每 sub-feature 独立可启动**: M2.1/M2.2/M2.3 不强依赖, 用户可调顺序; 但下面默认顺序按"经济先于 AI 先于 UI"经验排列

---

## 3 个 sub-feature

### M2.1 — Economy (Worker Harvest, gold + wood) ✅ done (2026-05-02)

**目标**: 把"starting_resources 一次性 100 gold"演进为"worker harvest 资源闭环 + 多资源 cost"。

**详细规划**: [`../archive/2026-05-02-rts-m2-1-economy/task-plan/m2-1-economy/README.md`](../archive/2026-05-02-rts-m2-1-economy/task-plan/m2-1-economy/README.md)

**已交付** (4 phase 全过, 25/25 AC PASS):
- `RtsResourceNode` actor + `UnitClass.WORKER` + `RtsHarvestActivity` / `RtsReturnAndDropActivity` / `RtsHarvestStrategy`
- 双资源 (gold + wood) cost 全链路 dict 化 (`RtsBuildingConfig.cost: Dictionary[String, int]`)
- crystal_tower 兼 drop-off (`RtsBuildingConfig.StatBlock.is_drop_off`; 与 is_crystal_tower 同模式)
- 闭环 PASS: worker harvest → 资源到达 cost (80g+50w barracks / 60g+100w archer_tower) → 玩家 enqueue PlaceBuildingCommand → barracks spawn melee → melee 攻 ct (smoke_economy_demo 验证 melee_to_ct_attacks=31)

**Status**: ✅ done + archive 完成 2026-05-02 (archive `archive/2026-05-02-rts-m2-1-economy/`)

---

### M2.2 — AI 对手 (Computer Player) ✅ done (2026-05-02; Minimal AI)

**详细规划**: [`../archive/2026-05-02-rts-m2-2-ai-opponent/task-plan/m2-2-ai-opponent/README.md`](../archive/2026-05-02-rts-m2-2-ai-opponent/task-plan/m2-2-ai-opponent/README.md) (含 E1-E10 决策表 + 6 AC + 子任务拆分 E.1-E.4)

**目标**: 右侧不再依赖 player_command, AI 走 RtsComputerPlayer 自动放 barracks + 出兵 + 进攻; 单机 1v1 玩家 vs CPU 可在 demo 里打完一局。

**Minimal AI scope 落地** (后续轮可加难度 / 兵种偏好 / 防御阵型):
- 1 档难度,无难度档位选项
- 单跳 build order:只放 barracks (1 个 cap; 不管 archer_tower / 防空 / 兵种偏好)
- AI 出 unit 走默认 melee (barracks 默认 spawn melee)
- worker harvest 沿用 M2.1 的 RtsHarvestStrategy(AI 不 override worker)
- 不引入侦探 / 防御阵型

**已交付** (单 phase 4 子任务全过, 6/6 AC PASS, 14/14 validation 全套 0 漂移):
- `RtsComputerPlayer` (logic/ai/, team-level, RefCounted, procedure tick step 6.5 驱动 — 每 30 tick 决策)
- AI 走 RtsPlayerCommandQueue 链路 (与玩家走同一接口, 保 bit-identical replay)
- procedure._computer_players + attach_computer_player(team_id) (默认不 attach, smoke / demo 显式启用 — E10 决策保旧 12 项 smoke 不破)
- smoke_ai_vs_player_full_match (600 tick @ 30Hz, 实测 ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9, ≥ 阈值 {1,3,1} 全过)
- demo_rts_frontend 双方都启 AI (F6 可看 AI vs AI 自跑 经济 → 出兵 → 攻 ct 完整链路)

**Status**: ✅ done + archive 完成 2026-05-02 (archive `archive/2026-05-02-rts-m2-2-ai-opponent/`)

---

### M2.3 — UI / HUD / Build Panel / 关卡 ✅ done (2026-05-03; Full scope, 4 phase)

**详细规划**: [`../archive/2026-05-03-rts-m2-3-ui-hud/task-plan/m2-3-ui-hud/README.md`](../archive/2026-05-03-rts-m2-3-ui-hud/task-plan/m2-3-ui-hud/README.md) (含 用户决策表 + 4 phase 概览 + 收口条件)

**已交付** (4 phase 全过, 24 AC PASS, 15/15 validation 全套 0 漂移):
- **Phase A** — `RtsBuildPanel` (frontend/ui/build_panel.{gd,tscn}); BuildPanel.signal `building_selected(kind: String)` → demo 进 placement mode → 半透 ColorRect ghost 跟鼠标 + grid snap (绿=可放 / 红=不可放, RtsBuildingPlacement.validate 同步预检) → 左键放下 / ESC / 右键取消; HUD 升级为 VBox(icon + 数字) × 2 (gold + wood)
- **Phase B** — `RtsMinimap` (frontend/ui/minimap.{gd,tscn}, 屏幕右下角 150×150); _draw 批量画 actor 点 (team color) + camera viewport 框; 点 minimap → 主 camera 跳; 加 Camera2D zoom=3 居中 + WASD/arrow keys 平移 (limit_* 自动 clamp); director._render_states 加 team_id 字段
- **Phase C** — `RtsMainMenu` (frontend/main_menu.{gd,tscn}) + `RtsMatchPreset` Resource (frontend/preset/rts_match_preset.gd; 字段 starting_resources_left/right / num_workers_per_team / attach_*_ai / show_build_panel); 3 静态工厂 create_classic_1v1 / create_resource_scarce_1v1 / create_ai_vs_ai_observe; main_menu 点 Button → 实例化 demo + apply_preset → 替换 main_menu
- **Phase D** — `tests/frontend/smoke_ui_main_menu.{gd,tscn}` headless 验 main_menu → demo apply_preset 链路 PASS; 全套 14 + 1 = 15 项 validation 0 漂移; archive 完成

**用户决策** (2026-05-03 锁定):
- BuildPanel 交互 = 复用 placement_mode
- 关卡 = ≤3 预设 setup (不做完整 scenario harness 可玩化)
- Minimap = 可见 + 双向 (无战雾)
- HUD = icon + 数字 (最小; 不加增量动画 / 不加红色)

**Status**: ✅ done + archive 完成 2026-05-03 (archive `archive/2026-05-03-rts-m2-3-ui-hud/`)

---

## M2 整体 milestone ✅ done (2026-05-03)

3 sub-feature 全部收口:
- M2.1 Economy ✅ done (2026-05-02)
- M2.2 AI 对手 ✅ done (2026-05-02)
- M2.3 UI / HUD / Build Panel / 关卡 ✅ done (2026-05-03)

**M2 末态能力**: 玩家 F6 打开 main_menu.tscn → 选预设 → 进 demo → BuildPanel 选建筑放下 → 主 camera WASD 移动 + minimap 全图观战 + 点 minimap 跳 → 经济闭环 (worker harvest gold + wood 给 ct 兼 drop-off) → AI 对手自跑 → ct 死分胜负. 玩家可在编辑器 F6 完整打完一局 1v1 / AI vs AI 观战.

**M2 收口条件 (已满足)**: M2.1 + M2.2 + M2.3 全做完, headless 全套 15 项 validation 0 漂移 + 视觉验证留 F6 (用户实际游玩验收).

---

## 决策来源

- 2026-05-02 用户授权 M2 主方向 (经济 / AI / UI 三选, 先做经济)
- RTS M1 末态 baseline: archive `.feature-dev/archive/2026-05-02-rts-m1-refactor/Summary.md`
- M2 整体 scope 的"双轨 AC" + "三 sub-feature 串行" 决策: 本文档 (即将沉淀进 reference 若长期稳定)
