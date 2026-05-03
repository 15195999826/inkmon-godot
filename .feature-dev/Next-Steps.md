# Next Steps — 2026-05-03 (RTS M2.3 — UI / HUD / Build Panel / 关卡 — Phase A done; Phase B next)

## 当前目标

**RTS Auto-Battle M2.3 — UI / HUD / Build Panel / 关卡 (Full scope, 4 phase, Phase A done)**

让 demo 从"AI vs AI 自动跑"演进为"玩家可通过 BuildPanel 选建筑 + 关卡 selector + minimap 全局观战"的完整可玩 skirmish, 收口 M2 milestone。

## 下一步

启动 **Phase B — Minimap (可见 + 双向交互)**:

1. **B.1** 写 `addons/logic-game-framework/example/rts-auto-battle/frontend/ui/minimap.{gd,tscn}` (Control 固定屏幕角落 + 实时画 unit / building 点)
2. **B.2** Minimap 实时刷新 — _process 内 director.get_render_state 拉所有 actor pos / team_id, 画到 minimap 内坐标 (world_to_minimap)
3. **B.3** Camera viewport 画框 — minimap 上叠白色矩形显示主 camera 当前可见区域
4. **B.4** 点 minimap → 主 camera 跳 (minimap_pos_to_world → camera.position); F6 视觉验证 + Validation 全套 14 项 + commit

详细 plan + AC 表 + 决策表见 [`task-plan/m2-3-ui-hud/phase-b-minimap.md`](task-plan/m2-3-ui-hud/phase-b-minimap.md) (Phase A 收口时落 skeleton)

## 验收准则 (Phase B 预期 AC)

- AC1 — RtsMinimap 控件存在 + 实时画 unit/building (按 team color)
- AC2 — Camera viewport 画框 (主 camera 缩放 / 平移时 minimap 框同步)
- AC3 — 点 minimap → 主 camera 中心跳到对应 world_pos
- AC4 — Minimap 不动逻辑 + 不破 replay (走 director.get_render_state, 不读 actor)
- AC5 — Validation 全套 0 漂移 (14 项 + 纯 frontend 改动)

**Phase A 验收已过** (7 AC 全 ✅); Phase B 收口 = M2.3 整体收口的第 2/4 步。

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
