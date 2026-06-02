# 项目总览

> 一页看懂 inkmon-godot 怎么拼起来。深入:主游戏架构 → [`main-game-architecture.md`](main-game-architecture.md);概念定义 → [`glossary.md`](glossary.md);框架内部 → `addons/logic-game-framework/docs/`。

## 1. 这是什么

Godot 4.6 回合制 / ATB 战斗模拟框架 + 在其上自建的养成主游戏。最终导出 Web/WASM(浏览器内 JS ↔ Godot 桥接运行),也支持本地 headless 模拟。

## 2. 分层(自底向上,依赖单向:上层依赖下层,下层绝不引用上层)

**2.1 框架层 LGF**(`addons/logic-game-framework/`)— 纯模拟战斗框架,三子层:
- **Core Logic** — 纯模拟无渲染(`core/`)
- **Game Logic** — 战斗规则 / 机制(`example/<example>/core/` + `logic/`)
- **Presentation** — VFX / 弹道 / 动画(`example/<example>/frontend/`)

事件驱动:`event_processor.gd` 管 pre/post handler;hex 例子技能用 timeline keyframe 驱动 action,实时例子(dota2)用固定 tick + `attack_cooldown` 替代 timeline 调度。

**2.2 示例层**(LGF 自带,两个独立 example,共享 core):
- **hex-atb-battle** — 技能系统展示 + AI 技能沙盒(见 `glossary.md` 1.2)。
- **dota2-auto-battle** — 实时固定 tick 30Hz / ARAM 单中路自动战斗(垂直切片)。

**2.3 主游戏层**(本仓 `scenes/`)— 在 LGF 之上自建:hex 行走世界 + 战斗(复用 LGF 战斗数学)+ 持久存档。架构 → `main-game-architecture.md`。

## 3. 仓库布局

| 路径 | 职责 |
|---|---|
| `addons/` | 单一 git submodule(`godot-addons.git`),含 `logic-game-framework` / `lomolib` / `sim-nav-map` / `ultra-grid-map` |
| `scenes/inkmon-main/` | 主游戏外壳:Host / 场景路由 / overworld 3D view / UI / core(session + 存档 IO) |
| `scenes/inkmon-battle/` | 主游戏战斗:`InkMonWorldGI` / battle actor / 技能内容 |
| `scripts/` | web 桥(`SimulationManager.gd`)+ `SkillValidator.gd` + 运行时脚本测试 |
| `logic-game-framework-config/` | 项目级 attribute set 配置 |
| `docs/` | 本文档目录(见 [`README.md`](README.md)) |

> **改 `addons/` 下任何文件 = 改上游 submodule**,需在 submodule 内单独 commit,主仓再 bump pointer。

## 4. 入口

- `project.godot` `run/main_scene` = 主游戏入口 `InkMonMain.tscn`(标题 → 菜单 → 进游戏;v1 直进,结构留好)。
- `Simulation.tscn` + `scripts/SimulationManager.gd` = 纯 web 桥,只在 `OS.has_feature("web")` 下注册 `window.godot_*` 回调(`godot_greet` / `godot_run_battle` / `godot_validate_skill` / `godot_preview_skill` 等);本地跑进 headless 测试分支。

## 5. Autoload 单例(见 `project.godot` `[autoload]`)

`Log` / `IdGenerator` / `GameWorld` / `TimelineRegistry` / `WaitGroupManager` / `ItemSystem` / `UGridMap` — 全局名直接调用(如 `Log.info(...)`、`GameWorld.get_actor(id)`)。

## 6. 文档与规范的家(本 docs/ 之外)

- **架构决策记录(ADR 等价物)** = LGF 既有的 `addons/logic-game-framework/docs/design-notes/YYYY-MM-DD-<topic>.md`,**不另起 `docs/adr/`**。
- **框架 / 技能内部知识** = `addons/logic-game-framework/docs/`(`reference/` + `skills/` + `design-notes/`)。
- **跑测试 / 编码规范 / 踩坑 / 工具用法** = agent onboarding 文件 `CLAUDE.md`(Claude)与 `AGENTS.md`(codex),**不在本 docs/ 重复**。
