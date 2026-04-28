# Inkmon (Godot)

Godot 4.6 回合制 / ATB 战斗模拟框架。Hex grid + Timeline 技能系统，最终导出为 Web/WASM，在浏览器中通过 JS ↔ Godot 桥接运行；也支持本地 headless 模拟。

## 核心架构

三层设计（顺序 = 依赖方向，上层依赖下层，下层绝不引用上层）：

1. **Core Logic** — 纯模拟，无渲染（`addons/logic-game-framework/core/`）
2. **Game Logic** — 战斗规则/机制（`addons/logic-game-framework/example/hex-atb-battle-core/`）
3. **Presentation** — VFX / 弹道 / 动画（`addons/logic-game-framework/example/hex-atb-battle-frontend/`）

事件驱动：`event_processor.gd` 管 pre/post handlers；技能用 timeline keyframe 驱动 actions。

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

### 三个入口，按用途选

| 入口 | 覆盖 |
|---|---|
| **LGF 单元测试** `addons/logic-game-framework/tests/run_tests.tscn` | core（attributes/events/abilities/actions/resolvers/timeline/world）+ 框架特性 |
| **Skill scenario 契约** `addons/logic-game-framework/tests/example/hex-atb-battle/smoke_skill_scenarios.tscn` | 具体 skill 的数值/tag/effect 断言 |
| **示例前端冒烟** `addons/logic-game-framework/tests/example/hex-atb-battle-frontend/smoke_frontend_main.tscn` | demo_frontend.tscn → core 战斗 → replay → director 播放（~80% 回归面） |

> 其余 smoke 在 `addons/logic-game-framework/tests/**/smoke_*.tscn`，按文件名打开即可（skill-preview / buff / shield / world-view 等）。

### 怎么跑

- **日常**：Godot 编辑器打开 `.tscn`，F6 跑，1 秒出结果。
- **Headless**：`godot --headless --path . <scene.tscn> > /tmp/godot_out.txt 2>&1`，然后读文件。退出码 0 = PASS；smoke 输出 `SMOKE_TEST_RESULT: PASS|FAIL - <reason>`。

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
