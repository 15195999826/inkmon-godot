# RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 — Summary (2026-05-03)

> M2 milestone 整体收口章节. M2.1 (Economy) + M2.2 (AI 对手) + M2.3 (UI / HUD / 关卡) 三个 sub-feature 全部 done + archived, 整个 M2 milestone "可玩单人 RTS skirmish 模式" 整体完成.

---

## Acceptance 结论 (Phase A 7 AC + Phase B 5 AC + Phase C 6 AC + Phase D 5 AC = 23 AC PASS)

### Phase A — BuildPanel + Placement Mode + HUD icon (7/7 ✅)

- [x] AC1 — `frontend/ui/build_panel.{gd,tscn}` 存在; class_name RtsBuildPanel; emit `building_selected(kind: String)`; 动态过滤 cost != {} 列出 barracks + archer_tower
- [x] AC2 — Button hover 显示 cost dict tooltip ("Cost: gold 80, wood 50")
- [x] AC3 — 点 Button → 进入 placement mode + ghost 预览 + grid snap
- [x] AC4 — 鼠标左键 → enqueue PlaceBuildingCommand + 退出 mode (失败留 mode)
- [x] AC5 — ESC / 右键取消 placement mode
- [x] AC6 — HUD 升级 icon + 数字 (gold + wood, ColorRect 占位)
- [x] AC7 — Validation 全套 14 项 0 漂移 (M2.2 末态完全 match)

### Phase B — Minimap + Camera2D + WASD pan (5/5 ✅)

- [x] AC1 — RtsMinimap 控件存在 + 实时画 unit/building (team color)
- [x] AC2 — Camera viewport 画框
- [x] AC3 — Minimap 点击 → 主 camera 跳
- [x] AC4 — WASD / arrow keys 主 camera 移动 (200 px/s)
- [x] AC5 — Validation 全套 14 项 0 漂移

### Phase C — Main menu + 3 预设 setup (6/6 ✅)

- [x] AC1 — RtsMainMenu 控件存在 + 列出 N Button (RtsMatchPreset.all_presets() = 3)
- [x] AC2 — RtsMatchPreset Resource (字段 + 3 静态工厂)
- [x] AC3 — demo_rts_frontend 接 preset (apply_preset + eff_* fallback)
- [x] AC4 — main_menu 点 Button → 进 demo (instantiate + apply_preset + queue_free self)
- [x] AC5 — main_menu.tscn 作为新 demo 入口 (demo_rts_frontend.tscn 仍作 fallback 入口)
- [x] AC6 — Validation 全套 14 项 0 漂移

### Phase D — smoke_ui_main_menu + 收口 + archive (5/5 ✅)

- [x] AC1 — smoke_ui_main_menu PASS (main_menu → demo apply_preset 链路 headless 验证)
- [x] AC2 — Validation 全套 15 项 (14 baseline + 1 新 smoke) 0 漂移
- [x] AC3 — archive entry `archive/2026-05-03-rts-m2-3-ui-hud/` (本 dir)
- [x] AC4 — m2-roadmap M2.3 / M2 整体标 ✅ done
- [x] AC5 — Next-Steps + task-plan/README 切回 waiting/index 状态

---

## 关键 artifact 路径

- 主入口: `addons/logic-game-framework/example/rts-auto-battle/frontend/main_menu.tscn` (F6 打开看到 3 预设)
- demo (preset 注入入口): `frontend/demo_rts_frontend.tscn` (作为 fallback 直接 F6 走 hardcode)
- BuildPanel: `frontend/ui/build_panel.{gd,tscn}` (RtsBuildPanel)
- Minimap: `frontend/ui/minimap.{gd,tscn}` (RtsMinimap)
- Match preset: `frontend/preset/rts_match_preset.gd` (RtsMatchPreset Resource + 3 静态工厂)
- 新 smoke: `tests/frontend/smoke_ui_main_menu.{gd,tscn}` (M2.3 Phase D 落地, 验证 menu → demo 链路)
- 修改的现有文件:
  - `frontend/demo_rts_frontend.gd` (Phase A 改 placement / HUD; Phase B 加 Camera2D + minimap; Phase C 加 _preset + apply_preset + eff_* fallback)
  - `frontend/core/rts_battle_director.gd` (Phase B 加 _render_states["team_id"] 字段)

---

## 真实运行证据 (M2.3 全套 15 项 validation 0 漂移)

### LGF 单元测试

```
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn
→ 总计: 73 | 通过: 73 | 失败: 0
```

### RTS 主 acceptance smoke (11 项, 数字 100% 与 M2.2 末态 match)

| smoke | 实测 |
|---|---|
| smoke_rts_auto_battle | left_win ticks=347 attacks=74 (melee=32 ranged=42) melee_max=24.00 |
| smoke_castle_war_minimal | ticks=193 left_win unit_to_building=4 archer_anti_air=1 |
| smoke_player_command | log_entries=3 gold_remaining=20 wood_remaining=50 |
| smoke_player_command_production | ticks=600 left_spawned=7 max_eastward=254.74 gold=20 |
| smoke_production | ticks=600 left=7 right=7 max_left_eastward=118.51 |
| smoke_crystal_tower_win | ticks=2 left_win |
| smoke_resource_nodes | ticks=200 alive_workers=5 max_drift=0.00 |
| smoke_harvest_loop | ticks=600 alive=5 team_gold=140 team_wood=212 cycle=5 |
| smoke_economy_demo | ticks=900 melee_to_ct_attacks=31 |
| smoke_ai_vs_player_full_match | ai_barracks=1 ai_units_spawned=4 ai_unit_to_ct_attacks=9 |

### Replay / determinism (2 项)

```
smoke_replay_bit_identical: seed=42 commands=2 frames=9 events=20 (deep-equal)
smoke_determinism: tick_diff=0 (run1 ticks=347 = run2 ticks=347)
```

### Frontend (2 项)

```
smoke_frontend_main: visualizers=10 alive_after_3.0s=10
smoke_ui_main_menu (新 M2.3): demo=RtsFrontendDemo preset=Classic 1v1 → PASS
```

### F6 视觉验证 (留给用户实际游玩)

- F6 main_menu.tscn → 看到 3 Button (Classic 1v1 / Resource Scarcity / AI vs AI Observation)
- 点 Classic 1v1 → 进 demo: 屏幕底部 BuildPanel 2 Button (Barracks / Archer Tower) + 屏幕顶部 HUD (gold + wood icon + 数字 + hint + ct hp) + 屏幕右下角 minimap (双方 ct + worker 点 + camera 框)
- WASD/arrow keys 平移主 camera (limit 0..500), 点 minimap 任意位置 → camera 跳 (clamp 边界)
- BuildPanel 点 Barracks → ghost 跟鼠标 (绿=在 build_zone + 资源够 + cells 空 / 红=外 / 资源不足 / occupied) → 左键放下 (clamped 到 grid snap, 走 RtsPlaceBuildingCommand) → ghost 消失退 mode; ESC / 右键也能取消

---

## 残余风险 / 已知 follow-up

1. **Camera2D zoom=3 + 1920×1080 viewport 显示约 50% BattleMap** — 边界外的 minimap 框可能被 limit_* 限制后看起来比 viewport 实际可见区域略小, 视觉细节 (Phase D 不阻塞)
2. **WASD 与 placement mode 冲突** — placement mode 期间 demo._update_camera_from_input 已禁 WASD, 但鼠标拖 Camera2D 拖动暂未实现 (后续 phase 视用户反馈再加)
3. **HUD ColorRect icon 占位** — 后续 phase 可替换 sprite (Phase A 文档接受占位; 不阻塞 M2 收口)
4. **bbox 中心算法重复 3 处** (RtsBuildingPlacement._compute_footprint_cells / RtsBuildingActor.get_footprint_cells / demo._bbox_center_offset) — 已知小 DRY 红线, simplify 时跳过 (改 logic 层会破 "不动 logic" 约束); 未来 M3 重构时考虑抽到 logic 静态 helper
5. **`docs/` 与 `tests/battle/diag_*` 多个 untracked 文件** 在 LGF submodule 内 — 不属于 M2.3 改动; 留给后续 sub-feature 处理

---

## M2 milestone 整体收口 (M2.1 + M2.2 + M2.3 总结)

### M2.1 — Economy (2026-05-02 done + archived)
- 双资源 (gold + wood) cost 全链路 dict 化
- RtsResourceNode + UnitClass.WORKER + StatBlock carry_capacity / harvest_speed
- RtsHarvestActivity / RtsReturnAndDropActivity / RtsHarvestStrategy
- crystal_tower 兼 drop-off (is_drop_off)
- barracks {gold:80, wood:50}, archer_tower {gold:60, wood:100}

### M2.2 — AI 对手 (2026-05-02 done + archived)
- RtsComputerPlayer (logic/ai/, RefCounted, team-level)
- procedure tick step 6.5 驱动 (每 30 tick 决策)
- _try_build_barracks: cap=1, cost 足时 enqueue PlaceBuildingCommand
- _try_attack: alive non-worker ≥3 触发 once, enqueue MoveUnitsCommand 攻敌 ct
- procedure._computer_players + attach_computer_player(team_id) 显式 attach
- AI 走 RtsPlayerCommandQueue 与玩家同接口 — bit-identical replay 不破

### M2.3 — UI / HUD / 关卡 (2026-05-03 done + 本 archive)
- BuildPanel + Placement mode + ghost (Phase A)
- Minimap + Camera2D + WASD pan + 点跳 (Phase B)
- Main menu + RtsMatchPreset Resource + 3 预设 (Phase C)
- smoke_ui_main_menu + 全套 15 项 0 漂移 (Phase D)

### M2 末态能力 (M3 出发点 baseline)

玩家 F6 打开 main_menu.tscn → 选 Classic 1v1 / Resource Scarcity / AI vs AI Observation → 进 demo → BuildPanel 选建筑放下 / 主 camera WASD 移动 + minimap 全图观战 + 点 minimap 跳 → 经济闭环 (worker harvest → drop ct) → AI 对手自跑 → ct 死分胜负. **完整可玩 1v1 RTS skirmish + AI vs AI 观战 demo**.

---

## Commits

- 主仓:
  - `5b105ba` feat(rts-m23): Phase A done — BuildPanel + Placement Mode + HUD icon
  - `55e8061` feat(rts-m23): Phase B done — Minimap + Camera2D + WASD pan
  - `34db779` feat(rts-m23): Phase C done — Main menu + RtsMatchPreset (3 setup)
  - (final commit including this archive — 由 D.5 final commit 落)
- submodule (addons/logic-game-framework):
  - `d98e884` feat(rts-m23): Phase A — BuildPanel + Placement Mode + HUD icon
  - `b1ef3b5` feat(rts-m23): Phase B — Minimap + Camera2D + WASD pan
  - `669cdf1` feat(rts-m23): Phase C — Main menu + RtsMatchPreset (3 setup)
  - (Phase D smoke + 由 D.5 一并 commit)
