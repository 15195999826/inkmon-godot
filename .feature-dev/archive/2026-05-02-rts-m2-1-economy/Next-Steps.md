# Next Steps — 2026-05-02 (已完成系统功能验收, 等待用户确认下一个 feature)

## 当前状态

**RTS Auto-Battle M2.1 — Economy ✅ 完整收口** (4 phase 全过 + archive 完成 2026-05-02)

- ✅ Phase A 收口 (Multi-Resource Foundation, 7/7 AC) — cost / starting_resources 全链路 dict 化
- ✅ Phase B 收口 (Resource Nodes + Worker Class, 6/6 AC) — RtsResourceNode + UnitClass.WORKER + idle 行为
- ✅ Phase C 收口 (Harvest Activity + Drop-off Loop, 7/7 AC) — HarvestActivity + ReturnAndDropActivity + HarvestStrategy + crystal_tower 兼 drop-off
- ✅ Phase D 收口 (Cost Rebalance + smoke_economy_demo, 5/5 AC) — barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100} / starting {gold:100, wood:100} + smoke_economy_demo full cycle PASS + demo_rts_frontend 经济闭环重写

**总计 25/25 AC PASS, 18/18 validation 全套 PASS, 0 行为漂移 (除 4 fixture cost/starting 数字漂)。**

> M2.1 完整 archive: [`archive/2026-05-02-rts-m2-1-economy/`](archive/2026-05-02-rts-m2-1-economy/)
> Phase D 文档: [`task-plan/m2-1-economy/phase-d-cost-rebalance.md`](task-plan/m2-1-economy/phase-d-cost-rebalance.md)
> M2.1 整体规划: [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md)
> M2 整体路线图: [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md)

## 下一步

**等待用户确认下一个 feature 开发**

可选方向:
- **M2.2 — AI 对手 (Computer Player)**: 右侧不再依赖 player_command, AI 走 strategy 自动放 barracks + 出兵 + 进攻 (M2.1 经济做完, AI 现在有"该花什么"决策空间)
- **M2.3 — UI / HUD / Build Panel / 关卡**: build panel 让玩家选 building_kind, HUD icon 化, minimap, 关卡 selector
- **新方向**: 用户也可以决定不继续 M2 路线, 切其它 milestone

详见 [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md) §M2 sub-feature 介绍。

要在 M2 之外开新的 sub-feature, 调 `/next-feature-planner`。
