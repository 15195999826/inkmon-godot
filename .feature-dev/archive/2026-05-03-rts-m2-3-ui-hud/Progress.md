## Progress — RTS Auto-Battle M2.3 UI / HUD / Build Panel / 关卡

**Status**: 🔄 **Phase A + B + C done; Phase D 待启动 (smoke + 收口 + archive)** (2026-05-03)

- 上一个 sub-feature: M2.2 AI 对手 ✅ done + archived (2026-05-02; archive `archive/2026-05-02-rts-m2-2-ai-opponent/`)
- 本 sub-feature 模式: **4 phase 串行** (Phase A 核心 build 闭环 ✅ → Phase B Minimap ✅ → Phase C Main menu ✅ → Phase D smoke + 收口 + archive 🔄)
- 详细 plan: [`task-plan/m2-3-ui-hud/README.md`](task-plan/m2-3-ui-hud/README.md)
- Phase A: [`phase-a-build-panel.md`](task-plan/m2-3-ui-hud/phase-a-build-panel.md) ✅ done
- Phase B: [`phase-b-minimap.md`](task-plan/m2-3-ui-hud/phase-b-minimap.md) ✅ done
- Phase C: [`phase-c-main-menu.md`](task-plan/m2-3-ui-hud/phase-c-main-menu.md) ✅ done

---

## Phase A 验收准则 checklist (7 AC ✅ 全过)

### AC1 — RtsBuildPanel 控件存在 + 列出可建造 kind ✅ done

- [x] **新文件** `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/build_panel.gd`
  - `class_name RtsBuildPanel extends Control`
  - emit `signal building_selected(kind: String)` (kind = RtsBuildingConfig.KIND_*)
  - hardcode `_ALL_KINDS` (含 barracks / archer_tower / crystal_tower) + filter cost.is_empty() 自动排 crystal_tower
- [x] **新文件** `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/build_panel.tscn`
- [x] Evidence: 编译通过 (`/tmp/m23_simplify_import.txt`); frontend smoke `/tmp/m23_a4_fe.txt` PASS — demo_rts_frontend.tscn 加载 BuildPanel + visualizers=10 alive=10 不崩

### AC2 — Button hover 显示 cost dict tooltip ✅ done

- [x] Button.tooltip_text = "Cost: %s" % _format_cost(stats.cost) (e.g. "Cost: gold 80, wood 50")
- [x] 字典 → 字符串 helper (build_panel.gd `_format_cost` static, 内联未抽出)
- [x] Evidence: build_panel.gd:67-72 + tooltip_text 由 Godot Button 原生托管 (hover 自动显示); F6 视觉验证留给用户

### AC3 — 点 Button → 进入 placement mode (光标变预览) ✅ done

- [x] BuildPanel emit `signal building_selected(kind: String)` → demo `_on_building_selected` → `_enter_placement_mode`
- [x] demo_rts_frontend `_setup_placement_ghost` 创建半透明 ColorRect (M2.1 demo 无现成 ghost, A.2 从零实现)
- [x] grid snap = `grid.coord_to_world(grid.world_to_coord(mouse_world))`; ghost size = footprint × cell_size; bbox 偏置由 `_bbox_center_offset` 静态算 (与 RtsBuildingPlacement 同算法, 进 mode 时缓存)
- [x] Evidence: demo_rts_frontend.gd:404-418 + frontend smoke `/tmp/m23_a4_fe.txt` PASS

### AC4 — placement mode 鼠标点地图 → enqueue + 退出 mode ✅ done

- [x] 鼠标左键 → `_try_place_at` → `_validate_player_placement` 同步预检 → 通过则 `procedure.enqueue_player_command(RtsPlaceBuildingCommand.new(tick, 0, kind, world_pos))` → `_exit_placement_mode("placed")` (ghost 消失)
- [x] F1 default A: validate 失败时 print 后 return, 不调 _exit_placement_mode → 留 mode 让玩家重选
- [x] ghost tint 同帧由 `_update_placement_ghost` 用 `_validate_player_placement` 预检, 绿=可放 / 红=不可放
- [x] Evidence: demo_rts_frontend.gd:236-262 + smoke_player_command.tscn `/tmp/m23_a4_pc.txt` 验证 enqueue + validate 链路 PASS (gold_remaining=20 wood_remaining=50)

### AC5 — ESC / 右键取消 placement mode ✅ done

- [x] _unhandled_input MOUSE_BUTTON_RIGHT → _exit_placement_mode("right_click") (不 enqueue, ghost.visible = false)
- [x] _unhandled_input KEY_ESCAPE → _exit_placement_mode("escape") (同上)
- [x] Evidence: demo_rts_frontend.gd:218-231 (`match` 分支拍平; 既 mouse 也 key)

### AC6 — HUD label → icon + 数字 (gold + wood) ✅ done

- [x] _setup_hud 创建 VBoxContainer + 2 行 (HBox(ColorRect icon + Label name + Label value)) + hint Label + hp Label
- [x] _process 实时刷新 _gold_label.text / _wood_label.text 从 procedure.get_team_resources(0)
- [x] icon = ColorRect 占位 (黄=gold #FFDA33, 棕=wood #80522F); 后续可替换 sprite
- [x] Evidence: demo_rts_frontend.gd:319-377 + frontend smoke 跑 demo 3 秒 visualizers=10 alive=10 不崩

### AC7 — Validation 全套 0 漂移 (M2.2 末态 14 项) ✅ done

simplify 前 + simplify 后 各跑一轮 14 项, 全过且数字 100% 一致 (0 漂移). 详细数字与 `task-plan/m2-3-ui-hud/phase-a-build-panel.md` §AC7 表完全 match.

- [x] LGF 73/73 PASS — `/tmp/m23_a4_lgf.txt` (总计: 73 | 通过: 73 | 失败: 0)
- [x] `tests/battle/smoke_rts_auto_battle.tscn` left_win ticks=347 attacks=74 melee=32 ranged=42 melee_max=24.00 — `/tmp/m23_a4_main.txt`
- [x] `tests/battle/smoke_castle_war_minimal.tscn` ticks=193 left_win unit_to_building=4 archer_anti_air=1 — `/tmp/m23_a4_cw.txt`
- [x] `tests/battle/smoke_player_command.tscn` log_entries=3 gold_remaining=20 wood_remaining=50 — `/tmp/m23_a4_pc.txt`
- [x] `tests/battle/smoke_player_command_production.tscn` ticks=600 left_spawned=7 max_eastward=254.74 gold_remaining=20 — `/tmp/m23_a4_pcp.txt`
- [x] `tests/battle/smoke_production.tscn` ticks=600 left_spawned=7 right_spawned=7 max_left_eastward=118.51 — `/tmp/m23_a4_prod.txt`
- [x] `tests/battle/smoke_crystal_tower_win.tscn` ticks=2 left_win — `/tmp/m23_a4_ct.txt`
- [x] `tests/battle/smoke_resource_nodes.tscn` ticks=200 alive_workers=5 max_drift=0.00 — `/tmp/m23_a4_rn.txt`
- [x] `tests/battle/smoke_harvest_loop.tscn` ticks=600 alive_workers=5 team_gold=140 team_wood=212 cycle_workers=5 — `/tmp/m23_a4_hl.txt`
- [x] `tests/battle/smoke_economy_demo.tscn` ticks=900 melee_to_ct_attacks=31 — `/tmp/m23_a4_econ.txt`
- [x] `tests/battle/smoke_ai_vs_player_full_match.tscn` ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 — `/tmp/m23_a4_ai_match.txt`
- [x] `tests/replay/smoke_replay_bit_identical.tscn` seed=42 commands=2 frames=9 events=20 deep-equal — `/tmp/m23_a4_replay.txt`
- [x] `tests/replay/smoke_determinism.tscn` tick_diff=0 — `/tmp/m23_a4_det.txt`
- [x] `tests/frontend/smoke_frontend_main.tscn` visualizers=10 alive_after_3.0s=10 — `/tmp/m23_a4_fe.txt`

---

## 子任务进度 (Phase A: A.1-A.4)

- [x] **A.1 — BuildPanel 控件 + cost tooltip** ✅ done (build_panel.gd / build_panel.tscn 新建)
- [x] **A.2 — Placement mode (从零实现 ghost; M2.1 没有现成)** ✅ done (demo `_setup_placement_ghost` / `_enter_/_exit_/_update_placement_ghost` / `_try_place_at` / `_validate_player_placement`)
- [x] **A.3 — HUD label → icon + 数字** ✅ done (demo `_setup_hud` 改 VBox + 2 HBox + hint + hp)
- [x] **A.4 — Validation 全套 + commit** ✅ done — 14/14 0 漂移 (simplify 前/后各一轮); F6 视觉验证留给用户

---

## 残余风险 (Phase A 启动前预判)

1. **demo_rts_frontend 现有 placement ghost 实现可能不存在 / 残缺** — Phase A 启动 A.2 时先 grep 现有 demo placement 链路, 若没有现成 ghost 则 A.2 先实现 ghost 再接 BuildPanel
2. **Button tooltip 显示 cost dict 时格式化** — Godot Button.tooltip_text 是纯字符串; 字典 → 字符串需要 helper, Phase A 内联
3. **HUD 升级时 ColorRect icon 视觉占位简陋** — Phase A 接受 ColorRect 占位 (后续可替换 sprite); 不阻塞收口
4. **F1 placement 失败 callback 缺失** — PlaceBuildingCommand.apply 失败仅进 _failed_commands_log, frontend 不直接知道; 实现时可能需要轮询 _failed_commands_log 或加 signal (若加 signal 算 logic 改动需停下来确认)

---

## Phase B 验收准则 checklist (5 AC ✅ 全过)

### AC1 — RtsMinimap 控件存在 + 实时画 unit/building ✅ done
- [x] `frontend/ui/minimap.{gd,tscn}` 新建; `class_name RtsMinimap extends Control`
- [x] `_draw` 渲染 BattleMap 边框 + 各 alive actor 点 (team color: 0=蓝 / 1=红 / -1=黄, _UNKNOWN=灰); building (max_hp ≥ 400) 4×4 / unit 2×2
- [x] team_id 走 `director._render_states["team_id"]` (新加字段, _seed_render_state 写入)

### AC2 — Camera viewport 画框 ✅ done
- [x] minimap._draw 末尾画白色矩形 = camera.global_position ± (viewport.size / 2 / camera.zoom) 投到 minimap 坐标
- [x] WASD 移 camera → minimap 框跟随 (demo._process queue_redraw)

### AC3 — Minimap 点击 → 主 camera 跳 ✅ done
- [x] minimap._gui_input 左键 → emit world_position_clicked(world_pos)
- [x] demo._on_minimap_clicked → _camera.position = world_pos (Camera2D limit_* 自动 clamp)

### AC4 — WASD 主 camera 移动 ✅ done
- [x] demo._process 内 (非 placement mode) `Input.get_vector("ui_left/right/up/down")` × 200 px/s
- [x] `_register_camera_keys` 注册 WASD 到 ui_* action (默认只绑 arrow keys)
- [x] Camera2D limit_* (0..500) 自动 clamp 边界

### AC5 — Validation 全套 0 漂移 (M2.2 末态 14 项) ✅ done
- [x] LGF 73/73 PASS — `/tmp/m23_b4_lgf.txt`
- [x] 11 RTS smoke 数字逐项 match Phase A baseline (0 漂移)
- [x] frontend smoke visualizers=10 alive=10 — `/tmp/m23_b4_fe.txt`

---

## Phase B 子任务进度 (B.1-B.4 ✅ 全过)

- [x] **B.1 — Minimap 控件 + Camera2D** ✅ done (minimap.gd / minimap.tscn 新; demo Camera2D zoom=3 居中 + limit_*)
- [x] **B.2 — Minimap 实时画 actor** ✅ done (_draw 走 director.get_actor_ids → render_state, team color)
- [x] **B.3 — Camera viewport 框 + WASD** ✅ done (_draw_viewport_frame + _update_camera_from_input + _register_camera_keys)
- [x] **B.4 — 点跳 + Validation + commit** ✅ done — 14/14 0 漂移; F6 视觉验证留给用户

---

## Phase C 验收准则 checklist (6 AC ✅ 全过)

### AC1 — RtsMainMenu 控件存在 ✅ done
- [x] `frontend/main_menu.{gd,tscn}` 新建; `class_name RtsMainMenu extends Control` (anchor preset 15 全屏)
- [x] VBox 居中, 标题 Label "Inkmon RTS — Skirmish Setup" + N Button (RtsMatchPreset.all_presets() = 3 项)

### AC2 — RtsMatchPreset Resource ✅ done
- [x] `frontend/preset/rts_match_preset.gd` 新建; `class_name RtsMatchPreset extends Resource`
- [x] 字段: name / description / starting_resources_left / starting_resources_right / num_workers_per_team / attach_left_ai / attach_right_ai / show_build_panel
- [x] 静态工厂 `create_classic_1v1` / `create_resource_scarce_1v1` / `create_ai_vs_ai_observe` + `all_presets()` 列表

### AC3 — demo_rts_frontend 接 preset ✅ done
- [x] demo._preset 字段 + apply_preset(p) helper (main_menu 在 instantiate + add_child 之间调用)
- [x] demo._ready 头部 read preset 字段 (eff_resources_left / eff_num_workers / eff_attach_*_ai / eff_show_build_panel) → 替换原 hardcode
- [x] _preset = null 时 fallback 走原 hardcode (frontend smoke headless 路径不破)
- [x] show_build_panel = false 时 _setup_build_panel + _setup_placement_ghost 跳过 (AI vs AI observe mode)

### AC4 — main_menu 点 Button → 进 demo ✅ done
- [x] main_menu._make_preset_button 每 preset 1 个 Button + connect pressed
- [x] _start_match: 实例化 demo + apply_preset + parent.add_child(demo) + queue_free(self) (demo 替换 main_menu)

### AC5 — main_menu.tscn 作为新 demo 入口 ✅ done
- [x] `frontend/main_menu.tscn` 存在, F6 打开看到菜单 (用户编辑器视觉验证)
- [x] `frontend/demo_rts_frontend.tscn` 仍能 F6 直接跑 (走 fallback hardcode, frontend smoke 入口)

### AC6 — Validation 全套 0 漂移 (M2.2 末态 14 项) ✅ done
- [x] LGF 73/73 + 11 RTS smoke + replay/determinism + frontend = 14/14 PASS, 数字逐项 match Phase A/B baseline (0 漂移)

---

## Phase C 子任务进度 (C.1-C.4 ✅ 全过)

- [x] **C.1+C.2 — RtsMatchPreset Resource + 3 预设静态工厂** ✅ done
- [x] **C.3 — demo apply_preset (eff_* fallback)** ✅ done (Dictionary[String, int] typed fix)
- [x] **C.4 — main_menu + Validation + commit** ✅ done — 14/14 0 漂移

---

## 后续 phase

- **Phase B — Minimap (可见 + 双向交互)** ✅ done — `task-plan/m2-3-ui-hud/phase-b-minimap.md`
- **Phase C — Main menu + ≤3 预设 setup** ✅ done — `task-plan/m2-3-ui-hud/phase-c-main-menu.md`
- **Phase D — smoke_ui_main_menu + 全套 validation + 收口 + archive** 🔄 active — Phase C 收口时落 `task-plan/m2-3-ui-hud/phase-d-smoke-and-archive.md`

---

## 决策来源

- 2026-05-03 用户答复 6 轮 AskUserQuestion (/next-feature-planner): scope=Full / build_panel=placement_mode / 关卡=≤3 预设 / minimap=可见+双向 / hud=icon+数字 / phase=4 phase
- M2.3 路线图: `task-plan/m2-roadmap.md` §M2.3
- M2.2 末态 baseline: `archive/2026-05-02-rts-m2-2-ai-opponent/Summary.md`
- M2.1 末态 baseline: `archive/2026-05-02-rts-m2-1-economy/Summary.md`
