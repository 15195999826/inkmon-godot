# Task Plan — RTS Auto-Battle M2.3 UI / HUD / Build Panel / 关卡

> **Active feature**: RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 (Full scope, 4 phase, **Phase A active**)
>
> **执行模式**: 一次只开发一个 phase。当前 phase 收口后才进下一 phase。

---

## 文档索引

| 文档 | 角色 | 状态 |
|---|---|---|
| [`m2-roadmap.md`](m2-roadmap.md) | M2 整体路线图 (M2.1 / M2.2 / M2.3) | 稳定 spec, 跨 sub-feature 不变 |
| [`m2-1-economy/`](m2-1-economy/) | M2.1 4 phase 详细 (历史快照) | ✅ done + archived (`../archive/2026-05-02-rts-m2-1-economy/`) |
| [`m2-2-ai-opponent/`](m2-2-ai-opponent/) | M2.2 详细 (历史快照) | ✅ done + archived (`../archive/2026-05-02-rts-m2-2-ai-opponent/`) |
| [`m2-3-ui-hud/README.md`](m2-3-ui-hud/README.md) | **M2.3 4 phase 概览 + 用户决策表 + 收口条件** | 🔄 active |
| [`m2-3-ui-hud/phase-a-build-panel.md`](m2-3-ui-hud/phase-a-build-panel.md) | **Phase A 详细 4 子任务 + 7 AC + F1-F4 决策表** | 🔄 active (待启动) |

> M2.1 / M2.2 的 task-plan 子目录是历史 phase 拆分快照, 完整快照已随 archive 拷贝; 主目录保留供查阅, 不再更新。

---

## 当前 Phase 总览 (M2.3 Phase A 🔄 active; B/C/D 🔒 pending)

**Phase A — BuildPanel + Placement Mode + HUD icon (核心 build 闭环)** 🔄 active

详细 plan: [`m2-3-ui-hud/phase-a-build-panel.md`](m2-3-ui-hud/phase-a-build-panel.md) (4 子任务 + 7 AC + F1-F4 决策表)

**预期落地**:
- 新 `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/build_panel.{gd,tscn}` (Button 列 + cost tooltip)
- 改 `frontend/demo_rts_frontend.gd` 接 BuildPanel.building_selected → placement mode (复用 M2.1 ghost)
- 改 demo HUD Label → HBox(ColorRect icon + Label) × 2 (gold + wood)

**Acceptance**: 7 AC (BuildPanel 控件 + Button hover tooltip + 点 button 进 placement + 鼠标点放 enqueue + ESC/右键取消 + HUD 升级 + Validation 全套 0 漂移)

**Phase B/C/D 🔒 pending** — 上一 phase 收口时落 skeleton。

---

## M2.3 Phase 总览 (4 phase)

### Phase A — BuildPanel + Placement Mode + HUD icon 🔄 active (2026-05-03)

详见 [`m2-3-ui-hud/phase-a-build-panel.md`](m2-3-ui-hud/phase-a-build-panel.md)

### Phase B — Minimap (可见 + 双向交互) 🔒 pending

预期 scope: Minimap 控件 (固定屏幕角落) + 实时渲染 unit/building (team color) + camera viewport 画框 + 点 minimap → camera 跳。详细等 Phase A 收口落 `m2-3-ui-hud/phase-b-minimap.md`。

### Phase C — Main menu + ≤3 预设 setup 🔒 pending

预期 scope: main_menu.tscn + PresetMatchSetup Resource (name / description / starting_units / ai) + 3 预设 (经典 1v1 / 资源紧 1v1 / AI vs AI 观战) + 点预设 → 加载 demo + apply。详细等 Phase B 收口落 `m2-3-ui-hud/phase-c-main-menu.md`。

### Phase D — smoke_ui_main_menu + 全套 validation + 收口 + M2 整体 archive 🔒 pending

预期 scope: smoke_ui_main_menu (headless 点预设 → BuildPanel 点 → enqueue) + F6 全链路视觉 + 全套 validation (M2.2 末态 14 项 + 新 smoke 1-2 项, 0 漂移) + archive + m2-roadmap M2.3 / M2 整体标 done。详细等 Phase C 收口落 `m2-3-ui-hud/phase-d-smoke-and-archive.md`。

---

## 全局收口条件

整个 RTS M2.3 完成 = Phase A + B + C + D 全过 + 用户 F6 视觉认可 (main_menu → demo → BuildPanel → 放下 + 取消 + minimap 实时 + camera 跳 + HUD 实时)。

完成时执行:
1. 创建 `archive/<YYYY-MM-DD>-rts-m2-3-ui-hud/` 归档全部 phase 进度 (Summary / Current-State / Next-Steps / Progress / task-plan 全套快照)
2. 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
3. 主 `Current-State.md` 更新为 M2.3 完成后 baseline (BuildPanel / minimap / main_menu 已落地)
4. M2 路线图 (`m2-roadmap.md`) 中 M2.3 status 标 "✅ done", M2 整体加完成节点
5. M2.3 archive 内 Summary.md 同时承担 M2 整体 milestone 收口章节 (M2.1 + M2.2 + M2.3 总结)

---

## Phase 间过渡协议

### Phase A → Phase B
- Phase A acceptance 全过 → **不归档** (同一 feature 早期 phase)
- 更新 `Next-Steps.md` 当前目标 → Phase B
- 更新 `Progress.md` 切到 Phase B 子任务清单
- 创建 `m2-3-ui-hud/phase-b-minimap.md` (Phase A 收口时再写, 不预先写)
- 用户在新会话调 `/autonomous-feature-runner` 即可继续

### Phase B → Phase C, Phase C → Phase D
- 同上, 不归档, 文档增量

### Phase D 完成
- M2.3 整体收口 → archive → 主 docs 切回等待状态
- M2 milestone 整体宣告完成 (无单独 milestone-level archive; M2.3 archive Summary 内承担)

---

## 实现纪律 (跨 phase 不变)

来自 `.feature-dev/Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** (新代码进 `addons/logic-game-framework/example/rts-auto-battle/frontend/` 为主)
2. **测试入口规范**: `.tscn` 入口 + `> /tmp/*.txt 2>&1` redirect, 不用 `--script` 不用 pipe
3. **触发 stop 条件**: 需要修改 `project.godot` autoload / `scripts/SimulationManager.gd` / LGF submodule 时要先确认
4. **每 phase 完成 re-run validation 顺序**: import → LGF 73/73 → 全部 RTS smoke (含 replay bit-identical + frontend) → hex demo (sanity)
5. **决策来自 m2-3-ui-hud/ 文档**: 实现时若发现需要改决策, 先停下来跟用户对齐再改文档
