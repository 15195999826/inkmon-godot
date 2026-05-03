# Next Steps — 2026-05-03 (RTS M2.3 — Phase A + B + C done; Phase D 收口 next)

## 当前目标

**RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 (Full scope, 4 phase, A+B+C done)**

最后一步: 写 smoke_ui_main_menu 验 main_menu → demo headless 链, 跑全套 14+1 项 validation, 整体 archive M2.3 + M2 milestone 收口。

## 下一步

启动 **Phase D — smoke_ui_main_menu + 全套 validation + archive**:

1. **D.1** 写 `tests/frontend/smoke_ui_main_menu.{gd,tscn}` (headless 实例化 main_menu + 模拟点 Button → 验 demo 子节点存在 + apply_preset 字段被读)
2. **D.2** 跑 全套 14 + 1 = 15 项 validation 0 漂移 (新 smoke 加入)
3. **D.3** 主仓 + .feature-dev 文档收口 — Current-State.md 更新 baseline / m2-roadmap.md M2.3 标 done / README/AGENTS/CLAUDE/docs 入口文档同步
4. **D.4** archive `archive/2026-05-03-rts-m2-3-ui-hud/` (Summary/Current-State/Next-Steps/Progress/task-plan 全套快照) + Next-Steps 切回 "等待用户确认下一个 feature"
5. **D.5** Phase D 不单独 commit — 与 archive 一起 final commit

详细 plan 见 `task-plan/m2-3-ui-hud/phase-d-smoke-and-archive.md` (Phase C 收口时落)

## 验收准则 (Phase D 预期 AC)

- AC1 — smoke_ui_main_menu.tscn headless PASS (main_menu 加载 → 模拟点 → demo apply_preset 路径)
- AC2 — Validation 全套 14 + 1 = 15 项 PASS (0 漂移)
- AC3 — archive entry `archive/2026-05-03-rts-m2-3-ui-hud/` 存在 + Summary.md 概括 M2.3 + M2 milestone
- AC4 — m2-roadmap M2.3 / M2 整体标 ✅ done; Current-State 更新到 M2.3 末态 baseline
- AC5 — Next-Steps 切回 "等待用户确认下一个 feature" + task-plan/README.md 切回 waiting/index 状态

**Phase A + B + C 验收已过**; Phase D 完成 = M2.3 + M2 milestone 整体结束。

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
