# Inkmon (Godot)

Godot 4.6 回合制 / ATB 战斗模拟框架。Hex grid + Timeline 技能系统，最终导出为 Web/WASM，在浏览器中通过 JS ↔ Godot 桥接运行；也支持本地 headless 模拟。

## 核心架构

三层设计（顺序 = 依赖方向，上层依赖下层，下层绝不引用上层）：

1. **Core Logic** — 纯模拟，无渲染（`addons/logic-game-framework/core/`）
2. **Game Logic** — 战斗规则/机制（`addons/logic-game-framework/example/<example>/core/` + `logic/`）
3. **Presentation** — VFX / 弹道 / 动画（`addons/logic-game-framework/example/<example>/frontend/`）

事件驱动：`event_processor.gd` 管 pre/post handlers；技能用 timeline keyframe 驱动 actions（hex 例子）；RTS 例子用实时 `attack_cooldown` 替代 timeline 调度。

目前有两个示例：[hex-atb-battle](addons/logic-game-framework/example/hex-atb-battle/) (回合制 + hex grid) 与 [rts-auto-battle](addons/logic-game-framework/example/rts-auto-battle/) (实时连续坐标 + navmesh)。

## 目录速查

| 路径 | 职责 |
|---|---|
| `scenes/Simulation.tscn` | 主场景（`project.godot` 配置） |
| `scripts/SimulationManager.gd` | 主入口，Web 下注册 `window.godot_*` 回调 |
| `scripts/SkillValidator.gd` | AI 生成技能四阶段验证（Compile → Interface → Runtime → Structure） |
| `scripts/SkillPreviewBattle.gd` | 技能预览沙盒战斗 |
| `addons/` | 单一 git submodule → `godot-addons.git`，内含 `logic-game-framework` / `lomolib` / `ultra-grid-map` |
| `logic-game-framework-config/` | 项目级 attribute set 配置（hero / tower） |

修改 `addons/` 下任何文件 = 改上游 submodule，需要在 submodule 内单独 commit。

## Autoload 单例

见 `project.godot` 的 `[autoload]`：
`Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap`

全局名可直接调用（如 `Log.info(...)`、`GameWorld.get_actor(id)`）。

## 测试

### 几个入口，按用途选

| 入口 | 覆盖 |
|---|---|
| **LGF 单元测试** `addons/logic-game-framework/tests/run_tests.tscn` | core（attributes/events/abilities/actions/resolvers/timeline/world）+ 框架特性 |
| **Hex Skill scenario 契约** `addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn` | 具体 skill 的数值/tag/effect 断言 |
| **Hex 示例前端冒烟** `addons/logic-game-framework/example/hex-atb-battle/tests/frontend/smoke_frontend_main.tscn` | demo_frontend.tscn → core 战斗 → replay → director 播放（~80% 回归面） |
| **RTS 自动战斗冒烟** `addons/logic-game-framework/example/rts-auto-battle/tests/battle/smoke_rts_auto_battle.tscn` | 4v4 连续坐标 + navmesh + 实时 attack_cooldown，断言兵种行为（melee 距离 ≤24 / ranged ≥1 次远距）|
| **RTS 前端冒烟** `addons/logic-game-framework/example/rts-auto-battle/tests/frontend/smoke_frontend_main.tscn` | demo_rts_frontend.tscn → 8 个圆圈 visualizer 不崩（编辑器 F6 看可视化）|

> 其余 smoke 在 `addons/logic-game-framework/tests/**/smoke_*.tscn` 与各 example 子目录下，按文件名打开即可（skill-preview / buff / shield / world-view / nav / ai / attack 等）。

### 怎么跑

- **日常**：Godot 编辑器打开 `.tscn`，F6 跑，1 秒出结果。
- **Headless**：`godot --headless --path . <scene.tscn> > /tmp/godot_out.txt 2>&1`，然后读文件。退出码 0 = PASS；smoke 输出 `SMOKE_TEST_RESULT: PASS|FAIL - <reason>`。

### Headless smoke 耗时 & Bash timeout 约定

Headless 单 smoke 包含 Godot 启动 + scene 加载 + sim 跑完 + ObjectDB cleanup，**实测 5-30s 一个**，远高于"编辑器 F6 1 秒出结果"。Claude Code 的 Bash tool 默认 timeout = 120000ms (2 min)，跑长 smoke 或串行批量时必须显式抬 timeout 否则会"假卡死"。

**核心心法**：**Godot 单 smoke 30s 还没返回，基本就是 smoke 自己有问题（死循环 / await 永远不触发 / scene 加载失败 hang）**，直接 kill 看 stderr 排错，不要傻等。timeout 上限不是"等更久能过"，是"过了这个时间就该假定坏掉"的上限。

| smoke 类型 | 典型耗时 | 推荐 Bash timeout (ms) |
|---|---|---|
| 简单单元 smoke (skeleton / nav / ai / attack / activity_chain / steering / stuck / auto_target / grid_pathfinding / push_out) | 5-8s | 30000 |
| 战斗 smoke (rts_auto_battle / hex demo_headless 跑数百 tick) | 10-15s | 30000 |
| 长跑 smoke (production / player_command_production 600 tick @ 50ms; determinism 60s × 2; replay_bit_identical 100 tick × 2) | 15-30s | 45000 |
| frontend smoke (含 `await create_timer 3-4s` real time) | 10-15s | 30000 |
| LGF 单元测试 `run_tests.tscn` (73 tests) | 15-25s | 45000 |
| 主仓 `--import` | 首次 10-30s, 后续 < 5s | 首次 60000，后续 30000 |

**批量跑 smoke 的正确做法**（避免 Bash 工具层假卡死）:
- ❌ 不要把 5+ smoke 串成一条 `for s in ...; do godot ... done` Bash 调用——单次 Bash 的输出延迟会让交互层无反馈，即使 `timeout` 设得再高也劝退
- ✅ 单 smoke 一条 Bash 调用，timeout 按上表设
- ✅ 多个**独立** smoke 用**同一消息里多条 Bash tool call 并行**（3-5 条/批）让 Godot 进程同时跑
- ✅ 按依赖分批：`--import` → LGF unit → 单元 smoke → 战斗 smoke → frontend / replay smoke
- ✅ 超时立刻当 fail 处理 — 看 `/tmp/<smoke>.txt` 末 100 行找 SCRIPT ERROR / await 链断点，不是抬 timeout 重跑

### 既知坑（踩过别再踩）

- **别用** `godot --headless --script <file>.gd`：`--script` 模式不触发 autoload，`Log`/`GameWorld` 全报错。始终用 `.tscn` 入口。
- **别用** `godot ... | grep`：Windows Git Bash pipe buffering + Godot ObjectDB cleanup 会让命令"假卡住" 2-3 分钟。永远 `> file 2>&1` redirect 再读。
- 退出时 `ObjectDB instances leaked` / `resources still in use` 是既有 leak，**不影响退出码**，修要去 LGF addon 内部排。

> 写新 smoke / 选 smoke 入口的约定见 `addons/logic-game-framework/tests/` 下现成模板与 README。

## Web / JS 桥接

`SimulationManager._setup_js_bridge()` 注册的 window 回调：
- `godot_greet` — 连通性测试
- `godot_run_battle` — 跑一场战斗
- `godot_test_runtime_script` — 动态加载脚本
- `godot_validate_skill` — 校验 AI 生成技能
- `godot_preview_skill` — 预览技能

只在 `OS.has_feature("web")` 下注册；本地跑会进 headless 测试分支。

## 规范与踩坑

项目自带三个 Claude Skill（`.claude/skills/`，按需加载，不常驻 context）：

- **`gdscript-coding`** — 通用 GDScript 编码规范（类型、shadowing、I* pattern、`Log.assert_crash` 等 14 条）；踩坑见同目录 `reference/troubleshooting.md`
- **`enforcing-lgf`** — Logic Game Framework 约定（Actor 生命周期、共享对象无状态、Intent 返回、Resolver 等）；详细 API 在 `reference/*.md`
- **`lgf-new-logic-skill`** — 实现新 skill / ability / buff / passive 时的 "去哪写、怎么 wire 进 submodule、怎么测" 指南（搭配上面两个使用）

配套 slash command（`.claude/commands/`）：

- `/review-gdscript <path>` — 按 14 条规范批量审 `.gd` 文件
- `/update-lgf-skill` — 根据 LGF addon 新提交增量更新 `enforcing-lgf` 文档

LGF 原始架构文档：`addons/logic-game-framework/CLAUDE.md` 和同级 `docs/`。

修改 `.gd` 文件 / 接触 LGF 类时 skill 会自动触发，不要在此文件复述规范内容。

## 本地约定

- 改代码前先确认 scope（改 `scripts/` 还是 `addons/`），不擅自扩大范围
- UI/场景改动需在编辑器中验证，不能仅靠 headless
