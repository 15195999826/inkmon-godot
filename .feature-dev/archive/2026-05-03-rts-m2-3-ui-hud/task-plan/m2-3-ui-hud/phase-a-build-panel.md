# Phase A — BuildPanel + Placement Mode + HUD icon

> 父 plan: [`README.md`](README.md)
>
> Status: 🔄 active (等待 /autonomous-feature-runner 启动)

---

## Scope

落地 M2.3 核心 build 闭环 (玩家可在 demo 里通过 BuildPanel 选择建筑并放下), 同步 HUD 升级到 icon + 数字。

**纯 frontend 改动 — 不动 core / logic / commands; replay bit-identical 0 漂移自然成立。**

---

## 子任务 (A.1 → A.2 → A.3 → A.4)

### A.1 — BuildPanel 控件 + cost tooltip

- 新文件 `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/build_panel.gd`
  - `class_name RtsBuildPanel extends Control`
  - VBox / HBox 列 Button (动态扫描 RtsBuildingConfig 所有 buildable kind, F3 决策)
  - Button 上显示 building_kind icon (ColorRect 占位; 后续可替换成 sprite)
  - Button hover → tooltip 显示 cost dict (e.g. "Cost: gold 80, wood 50")
  - emit `signal building_selected(kind: String)` 给 controller (kind 走 RtsBuildingConfig.KIND_* 字符串常量)
- 新文件 `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/build_panel.tscn`
- 数据来源 = `RtsBuildingConfig.get_stats(kind).cost` (动态读)

### A.2 — Placement mode (复用 M2.1 placement preview)

- 修改 `addons/logic-game-framework/example/rts-auto-battle/frontend/demo_rts_frontend.gd`
  - 接 `BuildPanel.building_selected(kind)` → 设 `_placement_kind = kind` 进入 mode
  - 鼠标移动 → ghost 预览 (复用 M2.1 demo 已有的 placement ghost 逻辑; grid snap 沿用)
  - 鼠标左键点地图 → `procedure.enqueue_player_command(RtsPlaceBuildingCommand.new(...))` → 退出 placement mode
  - ESC / 右键 → 取消 placement mode (不 enqueue)
  - placement 失败 (资源不足 / 位置不合法 — F1 决策): default 留在 mode 让用户重选 (Recommended)
- 注意: 启动 A.2 前先 grep 现有 demo_rts_frontend.gd 看 placement ghost 实现是否完整 (可能只是骨架, 需要 A.2 一并完成)

### A.3 — HUD label → icon + 数字

- 修改 demo_rts_frontend.gd 的 HUD Label 替换为 HBox(icon + Label) × 2 (gold + wood)
- icon 用 ColorRect 占位 (黄色 = gold, 棕色 = wood; 后续可替换 sprite)
- 实时绑定 `procedure.get_team_resources(player_team_id)` (与现有 HUD 更新同链路)

### A.4 — F6 视觉验证 + Validation 全套 + commit

- F6 demo 玩家可放下 barracks + archer_tower (各 ≥1 次)
- F6 placement mode 取消 (ESC + 右键各 ≥1 次)
- F6 HUD 数字实时反映资源 (放建筑后看到扣减)
- Validation 全套: M2.2 末态 14 项 全过, 0 漂移 (M2.3 Phase A 是纯 frontend, logic / replay 不变)
- Phase A 不新加 headless smoke (纯 frontend; 新 smoke 落 Phase D 的 smoke_ui_main_menu)
- commit (submodule 内单独 commit + 主仓 bump pointer, 标 "M2.3 Phase A done")

---

## 验收准则 (7 AC)

### AC1 — RtsBuildPanel 控件存在 + 列出可建造 kind 🔒 pending
- `frontend/ui/build_panel.gd` + `build_panel.tscn` 存在
- `class_name RtsBuildPanel extends Control` + emit `signal building_selected(kind: String)` (kind = RtsBuildingConfig.KIND_*)
- 动态扫描 RtsBuildingConfig, 列出所有 cost != {} 的 kind (默认 barracks + archer_tower; crystal_tower 不可建造排除)
- 每个 Button 显示 building_kind 名称 + ColorRect icon

### AC2 — Button hover 显示 cost dict tooltip 🔒 pending
- 鼠标 hover Button → tooltip 显示该 kind 的 cost dict (e.g. "Cost: gold 80, wood 50")
- 字典 → 字符串 helper (Phase A 内联不抽出, 后续 phase 视情况抽到 RtsBuildingConfig 静态方法)
- F6 视觉验证 hover

### AC3 — 点 Button → 进入 placement mode (光标变预览) 🔒 pending
- BuildPanel emit `building_selected(kind)` → demo_rts_frontend 接收 → ghost 预览出现
- ghost 跟鼠标 + grid snap (复用 M2.1 现有 placement preview 逻辑; 若不存在则 A.2 一并实现)
- F6 视觉验证

### AC4 — placement mode 鼠标点地图 → enqueue + 退出 mode 🔒 pending
- 鼠标左键点地图某处 → 走现有 PlaceBuildingCommand 链路 enqueue (`procedure.enqueue_player_command(...)`)
- enqueue 后 ghost 消失, 退出 placement mode
- F1 决策: 资源不足 / 位置不合法时, 命令进 _failed_commands_log, ghost 留 + 玩家可重选位置 (Recommended; default 不弹错误提示)
- F6 验证: 资源足时建筑出现; 资源不足时玩家被允许重试

### AC5 — ESC / 右键取消 placement mode 🔒 pending
- placement mode 下 ESC 键 → ghost 消失, 不 enqueue, 退出 mode
- placement mode 下鼠标右键 → 同上
- F6 视觉验证

### AC6 — HUD label → icon + 数字 (gold + wood) 🔒 pending
- 现有 plain Label 替换为 HBox(ColorRect icon + Label 数字) × 2 (gold / wood)
- 实时反映 `procedure.get_team_resources(player_team_id)` (放建筑后扣减立即可见)
- F6 视觉验证

### AC7 — Validation 全套 0 漂移 (M2.2 末态 14 项) 🔒 pending

| smoke / 测试 | 预期 (与 M2.2 末态 bit-identical) |
|---|---|
| `addons/logic-game-framework/tests/run_tests.tscn` | 73/73 PASS |
| `tests/battle/smoke_rts_auto_battle.tscn` | ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 |
| `tests/battle/smoke_castle_war_minimal.tscn` | ticks=193 left_win unit_to_building=4 archer_anti_air=1 |
| `tests/battle/smoke_player_command.tscn` | gold_remaining=20 wood_remaining=50 log=3 |
| `tests/battle/smoke_player_command_production.tscn` | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 |
| `tests/battle/smoke_production.tscn` | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| `tests/battle/smoke_crystal_tower_win.tscn` | ticks=2 left_win |
| `tests/battle/smoke_resource_nodes.tscn` | ticks=200 alive=5 max_drift=0 |
| `tests/battle/smoke_harvest_loop.tscn` | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 |
| `tests/battle/smoke_economy_demo.tscn` | ticks=900 melee_to_ct=31 |
| `tests/battle/smoke_ai_vs_player_full_match.tscn` | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 |
| `tests/replay/smoke_replay_bit_identical.tscn` | seed=42 frames=9 events=20 deep-equal |
| `tests/replay/smoke_determinism.tscn` | tick_diff=0 |
| `tests/frontend/smoke_frontend_main.tscn` | visualizers=10 alive_after_3.0s=10 |

**0 漂移因为**: M2.3 Phase A 是纯 frontend 改动 (BuildPanel 控件 + demo_rts_frontend / HUD), 不动 core / logic / commands / activity / replay; 既有 smoke 路径不变。

---

## 决策表 (F 系列, Phase A 实现时由 runner default 走 Recommended)

### F1 — placement 失败行为 (资源不足 / 位置不合法)

- **A. 留在 placement mode 让用户重选位置** (Recommended; RTS 经典)
- B. 退出 placement mode 让用户重新点 Button
- C. 弹错误提示 (UX 重)

> default A; 实现时若发现 PlaceBuildingCommand 失败缺少 callback → ghost stay 难以实现, runner 可降级到 B 并通知用户。

### F2 — BuildPanel 屏幕位置

- **A. 屏幕底部中央** (Recommended; Warcraft / StarCraft 经典)
- B. 屏幕底部右侧 (角落; 不挡视野)
- C. 屏幕左侧

> default A; 视实际 demo HUD 已占空间调整 (若底部已被 HUD 占满, 优先退到 B 不阻塞)。

### F3 — buildable building_kind 列表

- **A. 动态扫描 RtsBuildingConfig, 排除 crystal_tower** (Recommended; 自动跟新增建筑)
- B. 手动列举 (barracks + archer_tower hardcoded)

> default A; "排除 crystal_tower" 用 cost == {} 判定 (与 M2.1 cost 重平衡决策一致)。

### F4 — placement ghost 视觉风格

- **A. 半透明 building sprite + tint (绿色 = 可放, 红色 = 不可放)** (Recommended; 经典 RTS)
- B. 仅 outline (无填充)
- C. 沿用 M2.1 现有 ghost 风格 (不动)

> default 视 M2.1 现状决定; 若 M2.1 已有 ghost 走 C 不重写; 若没有走 A。

---

## 子任务进度 (A.1-A.4)

- [ ] **A.1 — BuildPanel 控件 + cost tooltip** 🔒 pending
- [ ] **A.2 — Placement mode (复用 M2.1)** 🔒 pending
- [ ] **A.3 — HUD label → icon + 数字** 🔒 pending
- [ ] **A.4 — F6 视觉 + Validation 全套 + commit** 🔒 pending

---

## 残余风险 (Phase A 启动前预判)

1. **demo_rts_frontend 现有 placement ghost 实现可能不存在 / 残缺** — Phase A 启动 A.2 时先 grep 现有 demo placement 链路, 若没有现成 ghost 则 A.2 先实现 ghost 再接 BuildPanel
2. **Button tooltip 显示 cost dict 时格式化** — Godot Button.tooltip_text 是纯字符串; 字典 → 字符串需要 helper, Phase A 内联不抽出
3. **HUD 升级时 ColorRect icon 视觉占位简陋** — Phase A 接受 ColorRect 占位 (后续可替换 sprite); 不阻塞收口
4. **F1 placement 失败 callback 缺失** — PlaceBuildingCommand.apply 失败仅进 _failed_commands_log, frontend 不直接知道; 实现时可能需要轮询 _failed_commands_log 或加 signal (若加 signal 算 logic 改动需停下来确认)

---

## 决策来源

- 2026-05-03 用户答复 6 轮 AskUserQuestion (/next-feature-planner): scope=Full / build_panel=placement_mode 复用 / 关卡=≤3 预设 / minimap=可见+双向 / hud=icon+数字 / phase=4 phase
- M2.3 路线图: `../m2-roadmap.md` §M2.3
- M2.2 末态 baseline: `../../archive/2026-05-02-rts-m2-2-ai-opponent/Summary.md`
- F1-F4 决策默认值: 本文档 §决策表
