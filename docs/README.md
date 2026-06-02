# 文档索引

> 本目录 = inkmon-godot 的项目文档。文件名即语义,按下面编号顺序读起。
> (给 agent 的操作指令——跑测试 / 编码规范 / 踩坑——在根级 `CLAUDE.md`(Claude)与 `AGENTS.md`(codex),**不在本目录**。)

## 1. 从这里开始

- **1.1 [项目总览](project-overview.md)** — 框架 / 示例 / 主游戏怎么拼起来,仓库布局,入口,autoload。**第一份要读的。**
- **1.2 [术语表](glossary.md)** — 关键概念速查:双通道 stats / ability(技能)/ World Actor 层级 / 主世界 Command·Query / RosterEntry 原则 等。

## 2. 架构

- **2.1 [主游戏架构](main-game-architecture.md)** — 主世界 / 战斗 / 存档三块 + 同步 tick 运行模型 + 三层 + Host + 所有权边界。**主游戏代码的唯一架构真相。**

## 3. 设计 / 未来

- **3.1 [游戏愿景](game-vision.md)** — 对游戏整体的构思(设计输入,部分待填)。
- **3.2 [待实现 / 占位功能](future/deferred-features.md)** — 刻印 per-skill scoping / 技能进化 X→X2 / lab 内容导入契约:当前是什么、为何延后、将来怎么补。

## 4. 框架与示例文档(在 submodule,不在本目录)

- **4.1 LGF 框架内部** — `addons/logic-game-framework/docs/`(`reference/` + `skills/` + `design-notes/`)。
- **4.2 架构决策记录(ADR 等价物)** — `addons/logic-game-framework/docs/design-notes/YYYY-MM-DD-<topic>.md`(本仓约定:不另起 `docs/adr/`)。
- **4.3 DevAgent 场景调试** — 各场景旁的 `DEV_AGENT.md`(主游戏:`scenes/inkmon-main/DEV_AGENT.md`;示例:`addons/.../<example>/.../DEV_AGENT.md`)。

---

> **历史开发计划**(已完成 goal 的过程跟踪文档)已删除,轨迹归 git 历史:`git log -- .codex-goal .claude-goal`。
