# Task Plan — RTS Auto-Battle M2.1 Economy

> **Active feature**: RTS Auto-Battle M2.1 — Economy (Worker Harvest, gold + wood)
>
> **执行模式**: 一次只开发一个 phase。当前 phase 收口后才进下一 phase。

---

## 文档索引

| 文档 | 角色 | 状态 |
|---|---|---|
| [`m2-roadmap.md`](m2-roadmap.md) | M2 整体路线图 (M2.1 economy / M2.2 AI 对手 / M2.3 UI 关卡) | 稳定 spec, 跨 sub-feature 不变 |
| [`m2-1-economy/README.md`](m2-1-economy/README.md) | M2.1 4 phase 拆分概览 + 收口条件 | 稳定 spec |
| [`m2-1-economy/phase-a-multi-resource.md`](m2-1-economy/phase-a-multi-resource.md) | Phase A 详细子任务 A.1-A.6 | ✅ done (2026-05-02; 7/7 AC PASS) |
| [`m2-1-economy/phase-b-resource-nodes.md`](m2-1-economy/phase-b-resource-nodes.md) | Phase B 详细子任务 B.1-B.6 | 🚧 **active** (2026-05-02) |

> Phase C/D 详细文档待对应 phase 启动时添加。`m2-1-economy/README.md` 已列出每 phase 的 scope / acceptance 主旨。

---

## 当前 Phase 总览 (M2.1 Phase B)

**Phase B — Resource Nodes + Worker Class (新 actor + UnitClass.WORKER + idle 行为)**

Phase A 收口后引入新 actor 类型 (`RtsResourceNode`) + 新单位类 (`UnitClass.WORKER`) + idle 行为 + 新 smoke (`smoke_resource_nodes`)。**不接** harvest / drop-off / 任何经济闭环逻辑 (那些是 Phase C)。

6 个子任务 (B.1-B.6): 新 ResourceNodeConfig + ResourceNode actor + 工厂 + UnitClass.WORKER + worker strategy 路径 + 新 smoke。风险点在 ResourceNode 不被 AutoTargetSystem 误选 + worker 不被默认 strategy 替换。

**Acceptance**: 6 条 (详见 [`m2-1-economy/phase-b-resource-nodes.md`](m2-1-economy/phase-b-resource-nodes.md) §Acceptance)

---

## M2.1 Phase 总览 (4 phase)

### Phase A — Multi-Resource Foundation ✅ done (2026-05-02)

详见 [`m2-1-economy/phase-a-multi-resource.md`](m2-1-economy/phase-a-multi-resource.md)。7/7 AC PASS, bit-identical 0 漂移, 全 smoke 数字与 RTS M1 末态一致。

### Phase B — Resource Nodes + Worker Class (本轮 active)

详见上方 + [`m2-1-economy/phase-b-resource-nodes.md`](m2-1-economy/phase-b-resource-nodes.md)。

新基础设施: `RtsResourceNode` actor (extends RtsBattleActor 或独立类型; 字段 = GOLD/WOOD, amount, position) + `UnitClass.WORKER` (低 hp / 无 attack / has carry_capacity + harvest_speed)。Worker 起手 idle 不动, 不接 harvest 行为 (那是 Phase C)。

- Worker 默认 movement_layer=GROUND, target_layer_mask=NONE (不打人, 不被默认 strategy 选)
- ResourceNode 是否阻挡 footprint? 倾向 不阻挡 (worker 可踩) — Phase B 启动时确认
- Demo / scenario 起手 spawn 几个 ResourceNode + 几个 worker, smoke 验证 spawn 链路

**Acceptance 主旨**: smoke_resource_nodes (5 worker + 1 gold node + 1 wood node, ticks=200 后 worker idle 在 spawn 位置 ± drift, ResourceNode amount 不变)

### Phase C — Harvest Activity + Drop-off Loop

经济闭环核心: `RtsHarvestActivity` (worker → 资源点 → harvest_progress 累积 → carrying = capacity → switch) + `RtsReturnAndDropActivity` (worker → 最近 drop-off → 加 team_resources → switch back) + `RtsHarvestStrategy` (worker autonomous 行为, idle 时找最近 ResourceNode)。

- Drop-off 建筑: 倾向 复用 crystal_tower (双 ct 起手就有, 不新加 town_hall) — Phase C 启动时确认
- Worker 出生方式: 倾向 hardcode demo / scenario 起手 spawn N 个 (不加 SpawnWorkerCommand) — Phase C 启动时确认

**Acceptance 主旨**: smoke_harvest_loop (5 worker + 1 gold node + 1 wood node, 跑 N tick 后 team_resources gold + wood 双增长 ≥ X; cycle 完整: worker → node → drop-off → team_resources)

### Phase D — Cost Rebalance + smoke_economy_demo

经济闭环对外可观: 给 archer_tower / barracks 重定 multi-resource cost (例: barracks={"gold": 80, "wood": 50}, archer_tower={"gold": 60, "wood": 100}; 数值待 Phase D 启动时调) + smoke_economy_demo (full cycle: worker harvest → 资源到达 cost → enqueue PlaceBuildingCommand → 自动放下个建筑) + 编辑器 F6 视觉验证。

**Acceptance 主旨**: 经济闭环 full cycle smoke PASS + F6 demo 视觉链路 OK + RTS M2.1 Economy 整体收口

---

## 全局收口条件

整个 RTS M2.1 Economy 完成 = Phase A + B + C + D 全过 + 用户 F6 视觉认可经济闭环。

完成时执行:
1. 创建 `archive/<YYYY-MM-DD>-rts-m2-1-economy/` 归档全部 phase 进度
2. 主 `Next-Steps.md` 切回"等待用户确认下一个 feature"
3. 主 `Current-State.md` 更新为 RTS M2.1 完成后的 baseline (worker / harvest / 经济闭环 已落地)
4. M2 路线图 (`m2-roadmap.md`) 中 M2.1 status 标 "✅ done"

---

## Phase 间过渡协议

### Phase A → Phase B
- Phase A acceptance 全过 → **不归档** (同一 feature 早期 phase)
- 更新 `Next-Steps.md` 当前目标 → Phase B
- 更新 `Progress.md` 切到 Phase B 子任务清单
- 创建 `m2-1-economy/phase-b-resource-nodes.md` (Phase A 收口时再写, 不预先写)
- 用户在新会话调 `/autonomous-feature-runner` 即可继续

### Phase B → Phase C, Phase C → Phase D
- 同上, 不归档, 文档增量

### Phase D 完成
- M2.1 Economy 整体收口 → archive → 主 docs 切回等待状态
- 用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)

---

## 实现纪律 (跨 phase 不变)

来自 `.feature-dev/Autonomous-Work-Protocol.md`:

1. **不修改 LGF submodule core / stdlib** (新代码进 `addons/logic-game-framework/example/rts-auto-battle/`)
2. **测试入口规范**: `.tscn` 入口 + `> /tmp/*.txt 2>&1` redirect, 不用 `--script` 不用 pipe
3. **触发 stop 条件**: 需要修改 `project.godot` autoload / `scripts/SimulationManager.gd` / LGF submodule 时要先确认
4. **每 phase 完成 re-run validation 顺序**: import → LGF 73/73 → 全部 RTS smoke (含 replay bit-identical + frontend) → hex demo (sanity)
5. **决策来自 m2-1-economy/ 文档**: 实现时若发现需要改决策, 先停下来跟用户对齐再改文档
