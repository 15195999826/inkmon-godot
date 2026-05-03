# Phase B — Minimap (可见 + 双向交互)

> 父 plan: [`README.md`](README.md)
>
> Status: 🔄 active (Phase A 收口后落; 等待 /autonomous-feature-runner 推进)

---

## Scope

落地 Minimap 控件 + 主 camera 双向交互. 玩家在屏幕角落看到全图 + 当前 camera viewport 框, 点 minimap 主 camera 跳. 也加 WASD 移动主 camera, 让 viewport 框真的有意义.

**纯 frontend 改动 — 不动 core / logic / commands; replay bit-identical 0 漂移天然成立.**

---

## 子任务 (B.1 → B.2 → B.3 → B.4)

### B.1 — Minimap 控件 + Camera2D

- 新文件 `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/minimap.{gd,tscn}`
  - `class_name RtsMinimap extends Control`
  - 屏幕右下角 (anchor preset BOTTOM_RIGHT), 150×150
  - `_draw` 自定义渲染 — 画 BattleMap 边界 + unit / building 点 (team color)
  - `bind(world_view_size: Vector2, director: RtsBattleDirector)` 让外部传入 BattleMap 尺寸
- demo_rts_frontend.gd 加 Camera2D 子节点 (BattleMap 下)
  - position = BattleMap 中心 (250, 250)
  - zoom = (3, 3) — 主视野显示约 1920/3 ≈ 640px 宽 × 1080/3 ≈ 360px 高
  - make_current = true
  - limit_left=0, limit_right=500, limit_top=0, limit_bottom=500 (Camera2D 内置 clamp)

### B.2 — Minimap 实时画 unit/building (team color)

- minimap._draw() 内:
  - 边框 (Rect2 outline, 灰色) — minimap 全大小
  - 遍历 director.get_render_state(actor_id) 拿 pos / team_id (走现有 director 协议, 不读 actor)
  - team 0 = 蓝, team 1 = 红, team -1 (中立 ResourceNode) = 黄
  - 每个 actor 画 2×2 px 方块 (unit) 或 4×4 (building)
- demo._process 末尾 minimap.queue_redraw() 让 _draw 每帧重跑

### B.3 — Camera viewport 画框 + WASD 主 camera 移动

- minimap._draw 末尾画白色矩形 = camera.get_viewport_rect 投到 minimap 坐标
  - bbox = camera.global_position ± (viewport_size / 2 / camera.zoom)
  - bbox → minimap 坐标 = bbox / world_size * minimap_size
- demo._process 内读 Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
  - camera.position += dir * speed * delta (speed = 200 px/s)
  - Camera2D limit_* 自动 clamp 边界

### B.4 — Minimap 点跳 + Validation 全套 + commit

- minimap._gui_input 内 InputEventMouseButton 左键 pressed:
  - mouse_pos (minimap 坐标) → world_pos = mouse_pos / minimap_size * world_size
  - emit `signal world_position_clicked(world_pos: Vector2)`
- demo._on_minimap_clicked: camera.position = world_pos (Camera2D limit 自动 clamp)
- F6 视觉验证 + Validation 全套 14 项 + commit

---

## 验收准则 (5 AC)

### AC1 — RtsMinimap 控件存在 + 实时画 unit/building 🔒 pending
- `frontend/ui/minimap.{gd,tscn}` 存在
- `class_name RtsMinimap extends Control`
- _draw 渲染 BattleMap 边框 + 各 actor 点 (team color: 0=蓝 / 1=红 / -1=黄)

### AC2 — Camera viewport 画框 🔒 pending
- minimap._draw 末尾画白色 outline 矩形 = main camera 当前 visible_rect 投到 minimap
- WASD 移 camera → minimap 框同步移动

### AC3 — Minimap 点击 → 主 camera 跳 🔒 pending
- minimap._gui_input 左键 → emit world_position_clicked
- demo 接收 → camera.position = world_pos (自动 clamp)
- F6 视觉验证 minimap 点 → 主视图跳

### AC4 — WASD 主 camera 移动 (双向交互前提) 🔒 pending
- demo._process 读 Input.get_vector("ui_left/right/up/down") → camera.position += dir × 200 × delta
- 边界由 Camera2D limit_* 自动 clamp

### AC5 — Validation 全套 0 漂移 (M2.2 末态 14 项) 🔒 pending

(预期数字与 Phase A AC7 表完全一致 — 纯 frontend 改动天然成立)

| smoke / 测试 | 预期 |
|---|---|
| LGF unit 73/73 | 73/73 PASS |
| smoke_rts_auto_battle | left_win ticks=347 attacks=74 |
| smoke_castle_war_minimal | ticks=193 left_win |
| smoke_player_command | log=3 gold=20 |
| smoke_player_command_production | ticks=600 left_spawned=7 |
| smoke_production | ticks=600 left=7 right=7 |
| smoke_crystal_tower_win | ticks=2 left_win |
| smoke_resource_nodes | ticks=200 alive=5 |
| smoke_harvest_loop | ticks=600 cycle=5 |
| smoke_economy_demo | ticks=900 melee_to_ct=31 |
| smoke_ai_vs_player_full_match | ai_barracks=1 |
| smoke_replay_bit_identical | frames=9 events=20 deep-equal |
| smoke_determinism | tick_diff=0 |
| smoke_frontend_main | visualizers=10 alive=10 |

---

## 决策表 (G 系列, default Recommended)

### G1 — Camera2D zoom

- **A. 3.0 (主视野约 50% BattleMap)** (Recommended; 平衡可见与精细)
- B. 2.0 (主视野约 75%, 接近全图但仍有"跳"意义)
- C. 4.0+ (zoom 高, minimap 点跳更有视觉感)

> default A.

### G2 — Minimap 大小

- **A. 150×150 屏幕右下角** (Recommended; 经典 RTS)
- B. 200×200 大一些, 看清更多细节
- C. 100×100 小, 不挡视野

> default A.

### G3 — 主 camera 输入

- **A. WASD (按住即移, speed 200 px/s)** (Recommended; 简洁)
- B. + 鼠标边缘 (鼠标到屏幕边缘自动滚)
- C. + 中键拖动

> default A. 视后续 phase 用户反馈再扩.

### G4 — Minimap 渲染方式

- **A. _draw 自定义批量画 (Rect2 / outline / dot)** (Recommended; 性能优于 N 个子 Node)
- B. ColorRect 子节点 + 一对多 update

> default A.

---

## 子任务进度 (B.1-B.4)

- [ ] **B.1 — Minimap 控件 + Camera2D** 🔒 pending
- [ ] **B.2 — _draw 画 actor + edge** 🔒 pending
- [ ] **B.3 — Camera viewport 框 + WASD 移动** 🔒 pending
- [ ] **B.4 — 点跳 + Validation 全套 + commit** 🔒 pending

---

## 残余风险

1. **Camera2D zoom=3 改变主视图行为** — 现 demo 是 1920×1080 viewport 显示 500×500 BattleMap (BattleMap 居左上 + 周围空白); zoom=3 后只显示 ~640×360 区域居中. F6 视觉变化, 但不影响 headless smoke (smoke 不渲染).
2. **WASD 与 placement mode 冲突** — placement mode 也接 InputEvent. 需要 demo._process 在 placement mode 内禁用 WASD (避免边输入边按 ESC 误触). default 走"placement mode 期间禁 WASD".
3. **director.get_render_state 当前签名** — 取单 actor by id; minimap 需遍历所有 alive actor. 需先 grep director, 看是否有 list_alive 接口或需要扩 — 若需扩 director 接口算 logic 改动, 停下来确认.
4. **Minimap _draw 性能** — 30 actor × _draw call_count ~3 (outline + dot) → 90 draw call/frame, 60 fps 共 5400/s. Godot Control._draw 优化好, 可以接受.
