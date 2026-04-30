# Next Steps

## 当前目标

**已完成系统功能验收，等待用户确认下一个 feature 开发。**

上一个 feature: RTS 自动战斗最小可玩示例（slug `rts-auto-battle`），归档于 `.feature-dev/archive/2026-04-30-rts-auto-battle/`。

acceptance 结论:
- AC1 (RTS smoke 跑到判胜负): ✓
- AC2 (单位走 navmesh 不穿墙): ✓
- AC3 (兵种行为正确 — melee 距离 ≤ 24×1.05；ranged 至少 1 次 > 24): ✓
- AC4 (LGF 73/73 不退化): ✓
- AC5 (hex demo 不退化): ~ 半通过 — battle 仍能跑到 winner，但 headless 退出时 signal 11 segfault (exit 139)。隔离测试已确认与 RTS 改动无关，归 LGF submodule 既有 leak

详见 `.feature-dev/archive/2026-04-30-rts-auto-battle/Summary.md`。

## 下一步

**等待用户确认下一个 feature 开发。**

候选方向（从 RTS M0 残余风险与 hex 例子状态推断）：

1. **AC5 hex demo shutdown segfault 排根** — 进 LGF submodule 的 core/stdlib 找 ObjectDB ShutdownScene 时的 destructor 顺序问题。需要用户授权解除"不修改 LGF submodule"硬约束
2. **RTS M1** — 在 rts-auto-battle 之上加：8v8 / 骑兵 / 投射物 entity / NavAgent avoidance / 实例化 PreEvent + PostEvent handler（buff / passive 接入）
3. **RTS frontend 美化** — 加攻击特效 / hp 条 / 死亡动画 / 相机 follow（M0 故意未做）
4. **接 SimulationManager / Web 桥接** — RTS 例子目前不进 web 桥接，可加 `godot_run_rts_battle` 让 Web UI 跑 RTS demo
5. **完全无关的新 feature** — 用户提

## 启动新 feature 流程

要开下一个 feature，调 `/next-feature-planner`：
- 它会重写本文件（`## 当前目标` / `## 非目标` / `## 验收准则`）
- 重写 `Current-State.md` 反映本轮归档后的 baseline（必要时）
- 重写 `Progress.md` 与 `task-plan/README.md` 为新 feature 的拆分

完成规划后调 `/autonomous-feature-runner` 自动开发。
