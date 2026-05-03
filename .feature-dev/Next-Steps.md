# Next Steps — 2026-05-03 (RTS M2.3 — Phase A + B done; Phase C next)

## 当前目标

**RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 (Full scope, 4 phase, Phase A+B done)**

让 demo 从"AI vs AI 自动跑"演进为"玩家可通过 BuildPanel 选建筑 + 关卡 selector + minimap 全局观战"的完整可玩 skirmish, 收口 M2 milestone。

## 下一步

启动 **Phase C — Main menu + ≤3 预设 setup**:

1. **C.1** 写 `frontend/ui/main_menu.{gd,tscn}` (Control + 3 Button 列预设, 屏幕居中)
2. **C.2** 写 `frontend/preset/match_preset.gd` (Resource 子类: name/description/starting_resources/starting_units/ai_attached/build_zone)
3. **C.3** 写 3 预设: 经典 1v1 (M2.2 当前 demo) / 资源紧 1v1 (起手少资源 + 多中立 node) / AI vs AI 观战 (双 AI no human input)
4. **C.4** main_menu 点预设 → instantiate demo_rts_frontend.tscn + apply preset (将原 demo._ready 内 hardcode 改为 apply_preset(preset)) + Validation 全套 + commit

详细 plan + AC + 决策表见 `task-plan/m2-3-ui-hud/phase-c-main-menu.md` (Phase B 收口时落)

## 验收准则 (Phase C 预期 AC)

- AC1 — RtsMainMenu 控件存在 + 列出 3 预设 Button
- AC2 — RtsMatchPreset Resource (name/description/starting_resources/starting_units/ai_attached/build_zone)
- AC3 — 3 预设分别配置不同起手 (经典 1v1 / 资源紧 1v1 / AI vs AI 观战)
- AC4 — 点预设 → 加载 demo_rts_frontend + apply 起手 (worker 数 / 资源 / AI 是否 attach)
- AC5 — Main menu 作为 demo 入口 (F6 打开 `frontend/main_menu.tscn` 而非 demo_rts_frontend.tscn; 不动主仓 scenes/Simulation.tscn)
- AC6 — Validation 全套 0 漂移 (14 项 + 纯 frontend 改动)

**Phase A + B 验收已过**; Phase C 收口 = M2.3 整体收口的第 3/4 步。

## 非下一步 (M2.3 scope 外)

- AI 难度档位 / 兵种偏好 / 防御阵型 (M2.2 增量, 旁支 sub-feature)
- M3 后续 milestone (待 M2 整体收口后规划)
- 完整 HUD (income rate / cap / 增量动画 / 不足红) — 已 finalize 走最小 icon + 数字
- Minimap 战雾 (已 finalize 无战雾)
- 关卡完整 scenario harness 可玩化 (已 finalize 走 ≤3 预设 setup)
- 修改 LGF submodule core / stdlib (M2.3 主战场 frontend, 不应触碰)
- 修改 project.godot autoload (M2.3 不预期加新 autoload)

## 等待动作

无。`/autonomous-feature-runner` 可立即启动 Phase B.1。

> Phase A 已 done (commit submodule `d98e884` + 主仓 bump). Phase B/C 决策表 default 走 Recommended (无需用户再决策); 若实现中发现决策需要变化, 由 runner 走 Autonomous-Work-Protocol stop 条件回问。
