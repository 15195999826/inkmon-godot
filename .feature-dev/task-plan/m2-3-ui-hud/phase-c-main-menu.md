# Phase C — Main menu + ≤3 预设 setup

> 父 plan: [`README.md`](README.md)
>
> Status: 🔄 active (Phase B 收口后落; 等待 /autonomous-feature-runner 推进)

---

## Scope

落地 main_menu 控件 + 3 预设 setup. 玩家 F6 打开 main_menu.tscn (新 demo 入口) → 点预设 Button → main_menu queue_free + 加载 demo_rts_frontend → demo 用预设的 starting_resources / unit count / AI attach 起手.

**纯 frontend 改动 — 不动 core / logic / commands / 主仓 scenes/Simulation.tscn (M0 范围外).**

---

## 子任务 (C.1 → C.2 → C.3 → C.4)

### C.1 — RtsMatchPreset Resource

- 新文件 `addons/logic-game-framework/example/rts-auto-battle/frontend/preset/rts_match_preset.gd`
  - `class_name RtsMatchPreset extends Resource`
  - 字段: name / description / starting_resources_left / starting_resources_right / num_workers_per_team / attach_left_ai / attach_right_ai / show_build_panel / show_minimap

### C.2 — RtsMatchPreset.create_*() 静态工厂 (3 预设)

- `create_classic_1v1()` — 与 M2.2 当前 demo 一致 (起手 100 gold + 100 wood, 5 worker, 双 AI vs 玩家可用 BuildPanel)
- `create_resource_scarce_1v1()` — 起手 50 gold + 50 wood (不够 1 barracks), 必须先 harvest. 3 worker 起手 (少劳力).
- `create_ai_vs_ai_observe()` — 双 AI, 玩家不能 build (BuildPanel 隐藏). 5 worker / 100 资源 标准

### C.3 — demo_rts_frontend 接 preset

- 加 `var _preset: RtsMatchPreset = null` (默认 null = back-compat hardcode)
- 加 `func apply_preset(p: RtsMatchPreset) -> void: _preset = p`
- demo._ready 头部 read preset 字段替换 hardcode const (starting_resources / num_workers / attach_*_ai / show_build_panel)
- main_menu 调 `var d := demo_scene.instantiate(); d.apply_preset(preset); add_child(d)` (preset 在 _ready 前 set)

### C.4 — main_menu.{gd,tscn} + Validation 全套 + commit

- 新文件 `addons/logic-game-framework/example/rts-auto-battle/frontend/main_menu.{gd,tscn}` (与 demo 同级目录, Phase D 改 frontend smoke 入口先指 main_menu 还是 demo 视后续决策)
- main_menu.tscn 主入口 — Control + 3 Button 列 + 标题 Label
- main_menu.gd: 点 Button → load demo_rts_frontend.tscn + instantiate + apply_preset + add_child to parent + queue_free self
- F6 视觉验证: F6 打开 main_menu.tscn → 看到 3 Button → 点经典 1v1 → 进 demo (与现 demo 行为一致)
- Validation 全套 0 漂移 (14 项, demo headless 走 fallback 路径不引 preset, 不破 baseline)

---

## 验收准则 (6 AC)

### AC1 — RtsMainMenu 控件存在 🔒 pending
- `frontend/main_menu.{gd,tscn}` 存在; `class_name RtsMainMenu extends Control`
- 屏幕居中 VBox + 3 Button (按 preset 顺序: 经典 1v1 / 资源紧 1v1 / AI vs AI 观战)
- 标题 Label 顶部 ("Inkmon RTS — Skirmish Setup")

### AC2 — RtsMatchPreset Resource 🔒 pending
- `frontend/preset/rts_match_preset.gd` 存在; `class_name RtsMatchPreset extends Resource`
- 字段: name / description / starting_resources_left / num_workers_per_team / attach_left_ai / attach_right_ai / show_build_panel
- 静态工厂 create_classic_1v1 / create_resource_scarce_1v1 / create_ai_vs_ai_observe

### AC3 — demo_rts_frontend 接 preset 🔒 pending
- demo._preset + apply_preset(p) helper
- demo._ready 字段读 _preset (优先) / fallback hardcode (back-compat headless smoke 不破)
- show_build_panel = false 时 _setup_build_panel 跳过

### AC4 — main_menu 点 Button → 进 demo 🔒 pending
- main_menu.gd 各 Button.pressed → 实例化 demo + apply_preset + add_child to parent (main_menu 父节点) + queue_free(self)

### AC5 — main_menu.tscn 作为新 demo 入口 🔒 pending
- F6 默认打开 main_menu.tscn 看到 menu (用户编辑器视觉验证)
- demo_rts_frontend.tscn 仍可 F6 直接跑 (作为 smoke + back-compat 入口)

### AC6 — Validation 全套 0 漂移 (M2.2 末态 14 项) 🔒 pending
- frontend smoke 走 demo_rts_frontend.tscn (不经 main_menu) → 走 fallback hardcode → baseline 数字 0 漂移
- 其他 13 项 smoke 不接触 demo / main_menu, 自然 0 漂移

---

## 决策表 (H 系列, default Recommended)

### H1 — 预设个数

- **A. 3 (经典 / 资源紧 / AI vs AI 观战)** (Recommended; 用户 finalize)
- B. 5 (加 turtle / rush 变体)
- C. 1 (只 classic, 简单)

> default A.

### H2 — main_menu 后退按钮

- **A. 无 (从 demo 回 menu 走 ESC + battle ended; Phase D 视情况加)** (Recommended; 简洁)
- B. 加 ESC 全局退到 menu

> default A.

### H3 — 预设资源差异

- **A. classic 100/100 5 worker, scarce 50/50 3 worker, observe 100/100 5 worker** (Recommended)
- B. 让用户自己调资源 (slider) — scope 大

> default A.

---

## 子任务进度 (C.1-C.4)

- [ ] **C.1 — RtsMatchPreset Resource** 🔒 pending
- [ ] **C.2 — 3 预设静态工厂** 🔒 pending
- [ ] **C.3 — demo apply_preset** 🔒 pending
- [ ] **C.4 — main_menu + Validation + commit** 🔒 pending

---

## 残余风险

1. **demo._preset = null 时 fallback** — _preset 为 null 时全字段走原 hardcode const, 保 frontend smoke 路径不破; 这是 phase A/B 测试基线维持的关键
2. **show_build_panel = false 时 buildpanel 跳过** — 影响 AI vs AI observe 模式 + headless smoke (smoke 不读 _preset → BuildPanel 仍创建); OK
3. **main_menu queue_free 时机** — Button.pressed → instantiate demo + add_child + queue_free(self) 同步, 应该 OK; 但若 demo._ready 读 main_menu 状态会破; 实际上 demo._ready 不读 main_menu, 所以 OK
