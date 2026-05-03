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

**详细规划**: [`m2-1-economy/README.md`](m2-1-economy/README.md)

**已交付** (4 phase 全过, 25/25 AC PASS):
- `RtsResourceNode` actor + `UnitClass.WORKER` + `RtsHarvestActivity` / `RtsReturnAndDropActivity` / `RtsHarvestStrategy`
- 双资源 (gold + wood) cost 全链路 dict 化 (`RtsBuildingConfig.cost: Dictionary[String, int]`)
- crystal_tower 兼 drop-off (`RtsBuildingConfig.StatBlock.is_drop_off`; 与 is_crystal_tower 同模式)
- 闭环 PASS: worker harvest → 资源到达 cost (80g+50w barracks / 60g+100w archer_tower) → 玩家 enqueue PlaceBuildingCommand → barracks spawn melee → melee 攻 ct (smoke_economy_demo 验证 melee_to_ct_attacks=31)

**Status**: ✅ done + archive 完成 2026-05-02 (archive `archive/2026-05-02-rts-m2-1-economy/`)

---

### M2.2 — AI 对手 (Computer Player) ✅ done (2026-05-02; Minimal AI)

**详细规划**: [`m2-2-ai-opponent/README.md`](m2-2-ai-opponent/README.md) (含 E1-E10 决策表 + 6 AC + 子任务拆分 E.1-E.4)

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

### M2.3 — UI / HUD / Build Panel / 关卡 🔄 active (2026-05-03; Phase A 待启动)

**详细规划**: [`m2-3-ui-hud/README.md`](m2-3-ui-hud/README.md) (含 用户决策表 + 4 phase 概览 + 收口条件)
**Phase A 详细**: [`m2-3-ui-hud/phase-a-build-panel.md`](m2-3-ui-hud/phase-a-build-panel.md) (7 AC + 4 子任务 + F1-F4 决策表)

**目标**: 玩家不再"只能放 barracks", build panel 让玩家选 building_kind; 资源 HUD 升级 icon + 数字; minimap; 关卡 selector 让玩家选预设 setup。

**Full scope 落地** (用户 2026-05-03 锁定; 4 phase 串行):
- **Phase A** — `Frontend BuildPanel` (Button 列 building_kind + hover cost dict) + 鼠标点 BuildPanel → 复用 M2.1 placement mode → 点地图放下 + ESC/右键取消 + HUD label → icon + 数字 (gold + wood)
- **Phase B** — Minimap (固定屏幕角落, 可见 + 双向交互, 无战雾, 点 minimap → 主 camera 跳)
- **Phase C** — Main menu + ≤3 预设 setup (PresetMatchSetup Resource: 经典 1v1 / 资源紧 1v1 / AI vs AI 观战)
- **Phase D** — smoke_ui_main_menu (headless: 点预设 → BuildPanel 点 → enqueue 成功) + F6 全链路视觉 + 全套 validation (M2.2 末态 14 项 + 新 smoke 1-2 项, 0 漂移) + archive

**用户决策** (2026-05-03 锁定):
- BuildPanel 交互 = 复用 placement_mode (与 demo 现有放 barracks 同链路)
- 关卡 = ≤3 预设 setup (不做完整 scenario harness 可玩化)
- Minimap = 可见 + 双向 (无战雾)
- HUD = icon + 数字 (最小; 不加增量动画 / 不加红色)

**为何 deferred 至今**: M2.3 是"可玩感受"层, M2.1 经济 + M2.2 AI 都做完后, 玩家才有"该建什么 / 该选什么 scenario"的决策空间; 前两步没做, 单纯加 UI 是空壳。M2.1 / M2.2 都已 done + archived → 现在启动 M2.3 完成 M2 milestone 整体收口。

---

## M2 收口条件

整个 M2 完成 = M2.1 + M2.2 + M2.3 全做完 + 用户在编辑器 F6 跑 demo 能完整打完一局 (玩家 vs AI, 经济采集, build panel 选建筑, ct 死定胜负)。

或: 用户决定不做完所有 sub-feature, 在某点收尾归档 + 切下一个 milestone (M3)。

---

## 决策来源

- 2026-05-02 用户授权 M2 主方向 (经济 / AI / UI 三选, 先做经济)
- RTS M1 末态 baseline: archive `.feature-dev/archive/2026-05-02-rts-m1-refactor/Summary.md`
- M2 整体 scope 的"双轨 AC" + "三 sub-feature 串行" 决策: 本文档 (即将沉淀进 reference 若长期稳定)
