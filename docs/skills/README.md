# Skills & Systems — 设计与规划文档

inkmon 项目层的**技能/战斗系统**设计与持续演进路线图。

## 这里放什么

- 系统/机制级的设计方案（护盾、状态、AI 行为树等）
- 已实现/未实现 feature 状态
- V2/V3 路线图与优先级
- 设计决策记录（为什么这样选、为什么不那样）
- 已知限制与待拍板的边界 case

## 这里**不**放什么

- LGF 框架层的架构推理 → 去 [`addons/logic-game-framework/docs/design-notes/`](../../addons/logic-game-framework/docs/design-notes/)
- 单技能的数值/行为细节 → 写在技能 `.gd` 文件头部注释
- 已修复 bug 的 post-mortem → 走 LGF 的 `design-notes/` 或 commit message

## 文档约定

- 一系统一文件，命名 `<system-name>.md`（kebab-case）
- 每篇文档包含：状态、V1 定稿、V2+ 路线图、设计决策、已知限制
- 状态用 emoji 标识：🟢 已设计 · 🟡 实现中 · 🔵 已落地 · 🟠 V2 规划中 · ⚫ 已废弃

## 当前清单

| 系统 | 状态 | 文档 |
|---|---|---|
| 护盾系统（Shield） | 🔵 V1 已落地 | [shield-system.md](shield-system.md) |
