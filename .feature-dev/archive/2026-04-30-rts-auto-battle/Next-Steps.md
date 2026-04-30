# Next Steps

## 当前目标

**RTS 自动战斗最小可玩示例**（slug: `rts-auto-battle`）。

在 `addons/logic-game-framework/example/rts-auto-battle/{core,logic,frontend,tests}/` 下落地一个新的 LGF 示例，对标既有 `hex-atb-battle` 的三层结构（core / logic / frontend / tests），但把以下两件事换掉：

1. **坐标系**：hex 离散 → 连续 `Vector2`（500×500 像素 2D 地图）
2. **节奏机制**：ATB 行动条 → 每 actor 持续 tick 的 `attack_cooldown`（实时连续时间）

继续复用：LGF 的 Actor / AbilitySet / Action / EventProcessor / Buff / Replay / WorldGameplayInstance / BattleProcedure 基类。

寻路用 Godot 原生 `NavigationServer2D` + `NavigationAgent2D`（A* + navmesh，单位规模 < 50 够用，未选 flow field）。

### 闭环

两军各 4 个单位（M0 起步规模，跑稳后可扩到 8v8），含 2 个兵种：**melee（近战）+ ranged（远程）**。
单位行为循环：`find_nearest_enemy` → `set_navigation_target` → `pathfind` → 进入 `attack_range` → cooldown 到时触发 basic attack → 死亡后 retarget。
500×500 地图带几块石头障碍物（NavigationRegion2D 挖洞）。
一方全灭判胜负，headless 输出 `SMOKE_TEST_RESULT: PASS - <winner>`。

## 下一步

**M0.9 — 文档同步**：
- `addons/logic-game-framework/example/README.md`（如不存在则按需创建）：增补 RTS 例子条目，列出 smoke 入口和子目录结构
- 主仓 `CLAUDE.md` 的"测试 / 三个入口"表 → 增补 RTS smoke 入口（`smoke_rts_auto_battle.tscn` 作为 RTS 主 smoke），保留 hex 三个入口
- `addons/logic-game-framework/CHANGELOG.md` `[Unreleased]` 段：`Added` 条目记录 RTS 自动战斗示例新增（不修改 LGF core/stdlib，只添加 example/rts-auto-battle）
- 不修改 LGF submodule 的 core/ stdlib/ —— 仅 example/ 下文件
- 完成后跑收口：AC1-AC5 全部 re-run，全过则进入 archive 阶段

M0.8 已完成。

## 非目标（M0 不做）

- 玩家操控单位（纯观战）
- 建造 / 资源 / 采集
- 弹道动画（ranged 直接造成伤害，不出 projectile entity）
- 骑兵兵种（推迟到 M1，M0 只 melee + ranged）
- 新的技能 / buff 实例（保留 LGF 的 AbilitySet/Buff 接口，但单位只挂 basic attack；不新写 skill）
- ATB / TimelineRegistry keyframe 调度（用 attack_cooldown 替代）
- 表演层美化（visualizer 仅出最简识别 stub：圆形 + 队伍色，不要动画 / 特效）
- Web 桥接 / `SimulationManager` 接入（M0 只做 LGF 内部 example，主仓 `scripts/` 不动）
- 修改 LGF submodule 本体（除非 M0 实现暴露 LGF 缺失能力，触发时停下来跟用户确认）

## 验收准则

按以下 5 条全部满足判定 **系统功能验收**：

1. **Headless smoke 跑通到判胜负**
   - 入口：`addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn`
   - 命令：`godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/rts_smoke.txt 2>&1`
   - 期望输出含 `SMOKE_TEST_RESULT: PASS - <left_win|right_win>`，退出码 0
   - MAX_TICKS 安全上限触发判 FAIL（不允许平局/死循环）

2. **单位走 navmesh 不穿墙**
   - 主断言（必过）：地图布局让两军初始位置之间存在障碍物，单位必须绕路才能接敌；战斗能完整打完到判胜负即间接证明 navmesh 工作（穿墙会直冲，绕路会被 navmesh 推到障碍物外缘）
   - 辅助断言（可选，能写进 logger 就加）：随机抽 2 个单位的实际行走路径长度 > 起止两点直线距离 × 1.05（绕路比例）
   - 不要求几何级 trajectory vs polygon 相交断言（M0 太重）

3. **兵种行为正确**
   - 用 logger event 流断言：melee 单位的所有 attack 事件中 `attacker_pos→target_pos` 距离 ≤ `melee_attack_range`；ranged 单位至少有 1 次 attack 事件距离 > `melee_attack_range`（即真的拉开了距离打）
   - 至少各方各有 1 melee + 1 ranged 单位参战

4. **LGF 单元测试不退化**
   - `godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/lgf_unit.txt 2>&1`
   - 期望 73/73 PASS（与 baseline 一致；退出码 0）

5. **Hex 例子不退化**
   - `godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/hex_demo.txt 2>&1`
   - 期望跑到 `left_win` 或 `right_win`，退出码 0

### 收口动作（acceptance 全过后）

- 把 RTS 示例条目补进 `addons/logic-game-framework/example/hex-atb-battle/../README.md`（如有 example index）以及主仓 `CLAUDE.md` 的"测试 / 三个入口"表
- 创建 `.feature-dev/archive/2026-04-30-rts-auto-battle/`，复制最终 `Current-State.md` / `Next-Steps.md` / `Progress.md` / `task-plan/`，写 `Summary.md`
- 把本文件的 `## 当前目标` 与 `## 下一步` 重写为「已完成系统功能验收，等待用户确认下一个 feature 开发」
