---
name: sim-nav-map
description: `addons/sim-nav-map` 插件背景速记：0 A.D.-inspired RTS pathfinding addon，仍在开发阶段，唯一示例 `0ad-rts-pathfinding-lab`，要求先读 `docs/references/0ad-source/` 本地源码再写新功能。Use when working anywhere under `addons/sim-nav-map/`.
---

# Sim Nav Map — 背景速记

## 1. 设计参照 = 0 A.D.

`addons/sim-nav-map/` 是独立 Godot pathfinding addon，分层和 contract 借鉴 0 A.D. 的 `CCmpPathfinder` / `HierarchicalPathfinder` / `LongPathfinder` / `VertexPathfinder` / `ICmpObstructionManager`。

**不是 0 A.D. clone，禁止复制 GPL 源码实现。**

## 2. 唯一示例

- **`examples/0ad-rts-pathfinding-lab/`** = 现役示例项目，所有新功能 / smoke / perf 实验都走这里。
- 旧 `examples/rts-pathfinding-lab/` 已删除（2026-05-10）。

## 3. Issues 现状

`docs/issues/` 当前**已清空待重启**。不要从被删除的内容里推断当前状态。

## 4. 开发阶段

addon 仍在开发中。public API 部分稳定，但 contract / smoke matrix / issue tracker 都还在迭代——**不要假设任何 contract 已完全冻结**。

## 5. 0 A.D. 本地源码优先（CRITICAL）

> **写新功能、改 contract、修和 0 A.D. 行为相关的 bug 之前 → 先去 `addons/sim-nav-map/docs/references/0ad-source/` 读对应源码。**

- `0ad-source/` 是 git-ignored 的本地 sparse checkout（拉取见 `docs/references/0ad-source-setup.md`）
- 源码索引见 `docs/references/0ad-source-map.md`（按主题分组的入口文件）
- **抓 contract / 数据流 / API 边界 / test idea，禁止复制 GPL 实现**

之所以要严格：早期 AI summary 二手总结**已被删除**（产生于源码下载之前，不准确）。对话上下文里出现"0 A.D. 是这样做的……"如果不是刚刚读过源码，就当作未验证假设。
