# 文档索引

> 本目录 = inkmon-godot 的项目文档。文件名即语义,按下面编号顺序读起。
> (给 agent 的操作指令——跑测试 / 编码规范 / 踩坑——在根级 `CLAUDE.md`(Claude)与 `AGENTS.md`(codex),**不在本目录**。)

## 1. 从这里开始

- **1.1 [项目总览](project-overview.md)** — 框架 / 示例 / 主游戏怎么拼起来,仓库布局,入口,autoload。**第一份要读的。**
- **1.2 [术语表](glossary.md)** — 关键概念速查:双通道 stats / ability(技能)/ World Actor 层级 / 主世界 Command·Query / RosterEntry 原则 等。

## 2. 架构

- **2.1 [主游戏架构](main-game-architecture.md)** — 主世界 / 战斗 / 存档三块 + 同步 tick 运行模型 + 三层 + Host + 所有权边界。**主游戏代码的唯一架构真相。**
- **2.2 [架构决策记录 ADR](adr/)** — 主游戏架构决策正本(0001 统一 live-actor / 0002 GI 组织规则 / 0003-0004 item·装备 / 0005-0007 2D 表演管线)。

## 3. 设计 / 未来

- **3.1 [游戏愿景](game-vision.md)** — 游戏概念与循环正本(2026-06 grill 成稿:乐趣核心 / 据点+远征 / 战后捕捉 / 战斗想象兑现)。
- **3.2 [玩法系统路线图](gameplay-systems-roadmap.md)** — 从愿景循环推导的系统分解 + 难度 + 前置决策 + 建议实施顺序。
- **3.3 [待实现 / 占位功能](future/deferred-features.md)** — 刻印 per-skill scoping / 技能进化 X→X2 / lab 内容导入契约:当前是什么、为何延后、将来怎么补。

## 4. 框架与示例文档(在 submodule,不在本目录)

- **4.1 LGF 框架内部** — `addons/logic-game-framework/docs/`(`reference/` + `skills/` + `design-notes/`)。
- **4.2 LGF 框架的决策记录** — `addons/logic-game-framework/docs/design-notes/YYYY-MM-DD-<topic>.md`(框架/示例层的决策住 submodule;**主游戏**的 ADR 在本目录 `adr/`,见 2.2)。
- **4.3 DevAgent 场景调试** — 各场景旁的 `DEV_AGENT.md`(主游戏:`inkmon/host/DEV_AGENT.md`;示例:`addons/.../<example>/.../DEV_AGENT.md`)。

---

> **历史开发计划**(已完成 goal 的过程跟踪文档)已删除,轨迹归 git 历史:`git log -- .codex-goal .claude-goal`。
