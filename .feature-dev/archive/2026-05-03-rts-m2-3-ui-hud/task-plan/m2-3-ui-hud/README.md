# Task Plan — RTS Auto-Battle M2.3 UI / HUD / Build Panel / 关卡

> **Active feature**: RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 (Full scope, 4 phase)
>
> **执行模式**: 一次只开发一个 phase。当前 phase 收口后才进下一 phase。

---

## 用户决策 (2026-05-03 锁定)

| 决策点 | 选项 | 理由 |
|---|---|---|
| **Scope** | Full (路线图 6 项全做) | 收口后 M2 milestone 完整结束 |
| **BuildPanel 交互** | 复用 M2.1 placement_mode (点 → 光标 → 点放) | 与 demo 现有放 barracks 同链路, 不开新机制 |
| **关卡 selector** | 预设 setup main_menu (≤3 预设) | 经典 1v1 / 资源紧 1v1 / AI vs AI 观战 |
| **Minimap** | 可见 + 双向交互 (无战雾) | 无战雾基础体验, 与 AI vs AI 观战需求同吞吐 |
| **HUD** | icon + 数字 (最小) | 不加增量动画 / 不加红色, scope 6 项下快接下一项 |
| **Phase 拆分** | 4 phase (与 M2.1 节奏一致) | 每 phase 独立可 F6 验收 + commit + 不 archive 中途 |

---

## 文档索引

| 文档 | 角色 | 状态 |
|---|---|---|
| [`README.md`](README.md) | 本文档 — 4 phase 概览 + 收口条件 | 稳定 spec |
| [`phase-a-build-panel.md`](phase-a-build-panel.md) | Phase A 详细 4 子任务 + 7 AC + F1-F4 决策表 | 🔄 active (待启动) |
| `phase-b-minimap.md` | Phase B 详细 (Minimap) | 🔒 pending — Phase A 收口时落 skeleton |
| `phase-c-main-menu.md` | Phase C 详细 (Main menu + ≤3 预设) | 🔒 pending — Phase B 收口时落 skeleton |
| `phase-d-smoke-and-archive.md` | Phase D 详细 (smoke + 收口 + archive) | 🔒 pending — Phase C 收口时落 skeleton |

---

## 4 Phase 拆分

### Phase A — BuildPanel + Placement Mode + HUD icon (核心 build 闭环) 🔄 active

详见 [`phase-a-build-panel.md`](phase-a-build-panel.md)

**Scope**: BuildPanel 控件 (Button + cost tooltip) + 复用 M2.1 placement preview + HUD label → icon + 数字

**Acceptance 主旨**: F6 demo 玩家通过 BuildPanel 放下 barracks 和 archer_tower; HUD 实时反映资源; M2.2 末态 14 项 validation 0 漂移 (纯 frontend 改动)

### Phase B — Minimap (可见 + 双向交互) 🔒 pending

落 skeleton 时 (Phase A 收口) 写 `phase-b-minimap.md`。

**预期 Scope**: Minimap 控件 (固定屏幕角落) + 实时渲染 unit/building (team color) + camera viewport 画框 + minimap 点击 → 主 camera 跳

**预期 Acceptance 主旨**: F6 看 minimap 实时反映 unit/building, 点 minimap 主 camera 跳; AI vs AI 模式可观全局

### Phase C — Main menu + ≤3 预设 setup 🔒 pending

落 skeleton 时 (Phase B 收口) 写 `phase-c-main-menu.md`。

**预期 Scope**: main_menu.tscn + PresetMatchSetup Resource (name / description / starting_units / ai_attached) + 3 预设 (经典 1v1 / 资源紧 1v1 / AI vs AI 观战) + 点预设 → 加载 demo_rts_frontend + apply

**预期 Acceptance 主旨**: 玩家从 main_menu 选预设进 demo, demo 用预设的 setup 起手

### Phase D — smoke_ui_main_menu + 全套 validation + 收口 + M2 整体 archive 🔒 pending

落 skeleton 时 (Phase C 收口) 写 `phase-d-smoke-and-archive.md`。

**预期 Scope**: smoke_ui_main_menu (headless 点预设 → BuildPanel 点 → enqueue 成功) + F6 全链路视觉 + 全套 validation (M2.2 末态 14 项 + 新 smoke 1-2 项, 0 漂移) + archive + m2-roadmap M2.3/M2 整体标 done

**预期 Acceptance 主旨**: M2 milestone 完整收口

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
2. **三层架构**: `core ← logic ← frontend`, M2.3 主战场是 frontend, 不应触碰 core / logic 的接口 (BuildPanel / Minimap / main_menu 都是 frontend)
3. **测试入口规范**: `.tscn` 入口 + `> /tmp/*.txt 2>&1` redirect, 不用 `--script` 不用 pipe
4. **每 phase 完成 re-run validation 顺序**: import → LGF 73/73 → 全部 RTS smoke (含 replay bit-identical + frontend) → hex demo (sanity)
5. **bit-identical replay 0 漂移** (M2.3 几乎纯 frontend, 不影响 logic; 但要验证证明)
6. **不修改 project.godot autoload** (M2.3 不预期加新 autoload)

---

## 决策来源

- 2026-05-03 用户答复 6 轮 AskUserQuestion (/next-feature-planner): scope=Full / build_panel=placement_mode / 关卡=≤3 预设 / minimap=可见+双向 / hud=icon+数字 / phase=4 phase
- M2 整体路线图: `../m2-roadmap.md` §M2.3
- M2.2 末态 baseline: `../../archive/2026-05-02-rts-m2-2-ai-opponent/Summary.md`
- M2.1 末态 baseline: `../../archive/2026-05-02-rts-m2-1-economy/Summary.md`
