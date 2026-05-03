# Next Steps — 2026-05-03 (RTS M2.3 — UI / HUD / Build Panel / 关卡 — Phase A active)

## 当前目标

**RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 (Full scope, 4 phase, Phase A active)**

让 demo 从"AI vs AI 自动跑"演进为"玩家可通过 BuildPanel 选建筑 + 关卡 selector + minimap 全局观战"的完整可玩 skirmish, 收口 M2 milestone。

## 下一步

启动 **Phase A — BuildPanel + Placement Mode + HUD icon (核心 build 闭环)**:

1. **A.1** 写 `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/build_panel.{gd,tscn}` (Button 列 building_kind + cost tooltip)
2. **A.2** 接 `BuildPanel.building_selected` → demo_rts_frontend placement mode (复用 M2.1 ghost; ESC/右键取消; 失败 retry)
3. **A.3** demo_rts_frontend HUD label 替换为 icon + 数字 (gold + wood)
4. **A.4** F6 视觉验证 + Validation 全套 14 项 + commit

详细 plan + 7 AC + F1-F4 决策表见 [`task-plan/m2-3-ui-hud/phase-a-build-panel.md`](task-plan/m2-3-ui-hud/phase-a-build-panel.md)

## 验收准则 (Phase A 7 AC)

- AC1 — RtsBuildPanel 控件存在 + 列出可建造 kind (动态扫描 RtsBuildingConfig)
- AC2 — Button hover 显示 cost dict tooltip
- AC3 — 点 Button → 进入 placement mode (光标变预览)
- AC4 — placement mode 鼠标点地图 → enqueue PlaceBuildingCommand + 退出 mode (失败 retry; F1 决策 default A)
- AC5 — ESC / 右键取消 placement mode
- AC6 — HUD label → icon + 数字 (gold + wood, ColorRect 占位)
- AC7 — Validation 全套 0 漂移 (M2.2 末态 14 项, bit-identical, 纯 frontend 改动天然成立)

详细预期数字见 [`task-plan/m2-3-ui-hud/phase-a-build-panel.md`](task-plan/m2-3-ui-hud/phase-a-build-panel.md) §AC7

**Phase A 收口 = M2.3 整体收口的第 1/4 步**; 全 4 phase 收口后整 M2 milestone 完整结束 → archive。

## 非下一步 (M2.3 scope 外)

- AI 难度档位 / 兵种偏好 / 防御阵型 (M2.2 增量, 旁支 sub-feature)
- M3 后续 milestone (待 M2 整体收口后规划)
- 完整 HUD (income rate / cap / 增量动画 / 不足红) — 已 finalize 走最小 icon + 数字
- Minimap 战雾 (已 finalize 无战雾)
- 关卡完整 scenario harness 可玩化 (已 finalize 走 ≤3 预设 setup)
- 修改 LGF submodule core / stdlib (M2.3 主战场 frontend, 不应触碰)
- 修改 project.godot autoload (M2.3 不预期加新 autoload)

## 等待动作

无。`/autonomous-feature-runner` 可立即启动 Phase A.1。

> Phase A 启动时 F1-F4 决策表 default 走 Recommended (无需用户再决策); 若实现中发现 F 决策需要变化, 由 runner 走 Autonomous-Work-Protocol stop 条件回问。
