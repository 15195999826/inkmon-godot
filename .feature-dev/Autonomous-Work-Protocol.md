# Autonomous Work Protocol — inkmon-godot 项目补丁

`/autonomous-feature-runner` 在本项目执行时的额外协议（叠加在 skill 通用 Execution Loop 之上）。

## 项目特定的硬约束

1. **不修改 LGF submodule**
   - 所有新代码进 `addons/logic-game-framework/example/<slug>/`
   - 若实现中需要修改 `addons/logic-game-framework/core/` 或 `addons/logic-game-framework/stdlib/` 才能推进 → **停下来跟用户确认**，不要擅自改 submodule
   - submodule 内即使是 example 目录，commit 也要先在 submodule 内做（否则主仓 pointer 漂移）

2. **测试入口规范**
   - 永远用 `.tscn` 入口跑 headless，**绝不用** `--script <file>.gd`（autoload 不触发）
   - 永远 redirect 输出到文件：`> /tmp/<name>.txt 2>&1`，**绝不用** pipe（`| grep` 会因 ObjectDB cleanup 假卡死 2-3 分钟）
   - smoke 输出格式：`SMOKE_TEST_RESULT: PASS|FAIL - <reason>`；非 PASS 一律 exit code != 0
   - 退出时 `ObjectDB instances leaked` warning 是既有 leak，不影响退出码 0，**不要被它误导成 RTS 引入的回归**

3. **Headless 下 NavigationServer 的初始化**
   - Godot 4 NavigationServer2D 在 headless 下需要 `await get_tree().physics_frame` 至少一次才会 sync map
   - smoke 入口 `_ready()` 末尾必须 `await` 一帧再开始 procedure tick
   - 否则 `NavigationAgent2D.get_next_path_position()` 返回起点本身，单位原地不动

4. **I 接口 / Log.assert_crash 规范**
   - 写新 .gd 时遵循 `.claude/skills/gdscript-coding/SKILL.md`（自动触发）和 `.claude/skills/enforcing-lgf/SKILL.md`
   - 不要在循环中拼字符串当 fail message；assert_crash 用 lazy lambda
   - 类型签名严格：`Array[Actor]` 不是 `Array`

5. **三层依赖方向**
   - `core/` ← `logic/` ← `frontend/`，frontend 不能被 core/logic 引用
   - tests 可以引任意层

## Validation 顺序（每 phase 完成后）

跑下面的命令，按出现错误的层级停下：

```bash
# 1) Type check (Godot import)
godot --headless --path . --import > /tmp/import.txt 2>&1

# 2) LGF unit tests (regression gate, baseline 73/73)
godot --headless --path . addons/logic-game-framework/tests/run_tests.tscn > /tmp/lgf_unit.txt 2>&1

# 3) RTS smoke (从 M0.7 起才有意义)
godot --headless --path . addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn > /tmp/rts_smoke.txt 2>&1

# 4) Hex demo regression (每 3 个 phase 一次)
godot --headless --path . addons/logic-game-framework/example/hex-atb-battle/logic/demo_headless.tscn > /tmp/hex_demo.txt 2>&1
```

每个文件读末尾 100 行检查 `SMOKE_TEST_RESULT` / 错误关键字（`SCRIPT ERROR`、`ERROR:`、`Failed`）。

## 何时停下来问用户

skill 通用 stop 条件之外，本项目额外停下的情况：

- 需要修改 LGF submodule 才能推进
- 需要修改主仓 `scripts/SimulationManager.gd` 或 `scenes/Simulation.tscn`（M0 范围外）
- 需要修改 `project.godot` 的 autoload 列表
- LGF 73/73 中任何一条变红（即使只是顺序变化也要先弄清楚根因）
- M0.7 smoke 连续 3 次同一原因 FAIL 且原因不在已知坑列表里
- 用户最初约定的 4v4 / 2 兵种 / 不写新技能 这些 scope 边界需要扩

## Commit 策略

- **每阶段性任务完成主动 commit**，不再等用户明确要求
  - 何时算"阶段性完成"：
    - 子任务 (P2.x / P3.x) 全部 acceptance 子项 PASS + smoke 不退化 + 文档同步更新到 Progress.md / Next-Steps.md / Current-State.md
    - phase 整体 acceptance 收口（Phase 1/2/3 切换时）
    - 独立 bug fix / 重构 + 验证通过
  - **不**算阶段性完成（此时不 commit，继续往下做）：
    - 单纯写完代码但 smoke 没跑过
    - 写到一半遇到中间错误状态
    - 仅文档改动（跟着代码改动一起 commit，别单独提）
- commit 操作规范：
  - submodule (addons/logic-game-framework/) 改动**单独 commit 在 submodule 内**，主仓 commit 同时 bump submodule pointer（两条 commit，顺序 submodule → 主仓）
  - commit message 中文 / 英文皆可，遵循 `commit-commands:commit` 风格；阶段性 commit 在 message 里点明 "P2.x done" / 关键 acceptance 结论
  - 不 `--no-verify`、不 `--amend`、不 force push（与用户全局规则一致）
  - **push / 开 PR 仍需用户明确要求** — commit 是本地节点保护，push 是公开发布，边界不同
- 如果不确定一个工作单元算不算"阶段性完成"，**倾向于 commit 而不是攒在一起** — 多个小 commit 比一个大 commit 容易回滚

## 文档维护

每次 phase 完成更新：

- `.feature-dev/Progress.md`：勾掉 phase checkbox，写 evidence 路径（`/tmp/*.txt`）
- `.feature-dev/Next-Steps.md` 的 `## 下一步`：指向下一个 phase 的具体动作

acceptance 全过后再做 archive（参见 skill Execution Loop step 7）。
