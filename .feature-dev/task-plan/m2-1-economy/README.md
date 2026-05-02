# M2.1 — Economy (Worker Harvest, gold + wood)

> **Sub-feature of**: RTS M2 (见 [`../m2-roadmap.md`](../m2-roadmap.md))
>
> **目标**: 把 RTS demo 现有的"starting_resources 一次性 100 gold"演进为"worker harvest 资源闭环 + 双资源 cost"。

---

## 4 Phase 拆分

| Phase | 内容 | Status |
|---|---|---|
| **A** | Multi-Resource Foundation (config 迁移 + 既有 smoke 适配) | ✅ done (2026-05-02; 7/7 AC PASS, bit-identical replay 0 漂移) |
| **B** | Resource Nodes + Worker Class (新 actor + UnitClass.WORKER + idle 行为) | ✅ done (2026-05-02; 6/6 AC PASS, 11/11 validation 全过 0 漂移) |
| **C** | Harvest Activity + Drop-off Loop (HarvestActivity + ReturnAndDropActivity + crystal_tower 兼 drop-off) | 🔒 pending — 等待用户确认启动 |
| **D** | Cost Rebalance + smoke_economy_demo (经济闭环 full cycle + F6 视觉) | 🔒 pending |

---

## Phase A — Multi-Resource Foundation ✅ done (2026-05-02)

详见 [`phase-a-multi-resource.md`](phase-a-multi-resource.md) + [`../../Progress.md`](../../Progress.md) §Phase A 验收准则。

**收口结论**: 7/7 AC PASS, bit-identical replay 0 漂移 (frames=9 events=20, tick_diff=0), 6 个 smoke + 1 个 replay smoke 全部硬迁 + 数字与 RTS M1 末态完全一致 (smoke_rts_auto_battle ticks=347, melee_max=24.00; smoke_castle_war_minimal ticks=193)。

---

## Phase B — Resource Nodes + Worker Class ✅ done (2026-05-02)

**详细 plan**: [`phase-b-resource-nodes.md`](phase-b-resource-nodes.md) (AC 全部 [x] 收口) + [`../../Progress.md`](../../Progress.md) §Phase B。

**收口结论**: 6/6 AC PASS, 11/11 validation 全套 PASS, 0 行为漂移。

落地内容 (D1-D5 决策全沿用):
- 新 `RtsResourceNode` actor (extends RtsBattleActor 平级独立子类, D5; 字段 field_kind / max_amount / amount / field_kind_key; team_id 默认 -1 中立; D2 不阻挡 footprint)
- 新 `RtsResourceNodeConfig` (FieldKind enum GOLD=0/WOOD=1 — D1 决策 int enum + StatBlock + raw const + get_stats + field_kind_to_resource_key)
- 新 `RtsResourceNodes` 工厂 (create_gold_node / create_wood_node)
- `UnitClass.WORKER` (=3 by 顺序声明位置) + StatBlock 加 carry_capacity / harvest_speed (worker 10/5.0, 其它兵种默认 0)
- `RtsAIStrategyFactory.get_strategy(WORKER)` 复用 `_basic_attack` (D4 决策 — worker mask=NONE 自然 idle)
- 新 `smoke_resource_nodes.tscn` PASS (ticks=200 alive_workers=5 gold_amount=1500 wood_amount=1500 max_drift=0.00 cached_target_id 始终空)
- 回归: LGF 73/73 + 既有 6 smoke + 2 replay smoke + frontend smoke 0 行为漂移 (与 Phase A 末态完全一致)

---

## Phase C — Harvest Activity + Drop-off Loop 🔒 pending

**详细 plan**: 待 Phase B 收口后写 `phase-c-harvest-activity.md`。

**Scope 概要**:
- 新 `RtsHarvestActivity` (extends RtsActivity)
  - 阶段 1: worker 走 MoveTo 到 ResourceNode 旁
  - 阶段 2: harvest_progress 每 tick += harvest_speed
  - 阶段 3: progress 达到 carry_capacity → carrying = capacity, switch to ReturnAndDrop
  - cancel: 走通用 RtsActivity cancel propagation (清 nav_agent target)
- 新 `RtsReturnAndDropActivity`
  - 阶段 1: worker 走 MoveTo 到最近 drop-off (crystal_tower)
  - 阶段 2: 抵达后 carrying → procedure.add_team_resources(team_id, {kind: amount}); carrying = 0
  - 阶段 3: switch back to Harvest (找新的 ResourceNode)
- 新 `RtsHarvestStrategy` (worker 默认 strategy)
  - decide(...) 返回 RtsHarvestActivity 包裹最近 ResourceNode (跨 GOLD/WOOD 平衡? 或 round-robin? Phase C 启动时定)
  - idle 时 trigger; HOLD_FIRE stance 不 trigger
- Drop-off 设计: **复用 crystal_tower** (双 ct 起手就有, 不新加 town_hall)
- Worker 出生方式: **hardcode demo / scenario 起手 spawn N 个** (不加 SpawnWorkerCommand; 留给 M2.2 AI 时若需要再加)

**Acceptance 主旨**:
- smoke_harvest_loop (5 worker + 1 gold node @ pos_a + 1 wood node @ pos_b, 跑 N tick 后 team_resources gold/wood 双增长 ≥ X; cycle 完整: worker → node → drop-off → team_resources)

---

## Phase D — Cost Rebalance + smoke_economy_demo 🔒 pending

**详细 plan**: 待 Phase C 收口后写 `phase-d-cost-rebalance.md`。

**Scope 概要**:
- Building cost 重平衡 (Phase A 仅迁字段, cost 数值都是 {"gold": 100} placeholder; Phase D 调到 multi-resource 有差异)
  - 例: barracks={"gold": 80, "wood": 50}; archer_tower={"gold": 60, "wood": 100}; crystal_tower={"gold": 0, "wood": 0} (起手就有, 不能造)
  - 数值待 Phase D 启动时调 + smoke 验证 trade-off (gold-rich 偏 barracks; wood-rich 偏 archer_tower)
- starting_resources 起手值调整 (Phase A 是 {"gold": 200, "wood": 0} placeholder; Phase D 调到 {"gold": 100, "wood": 100} 或类似)
- 新 smoke_economy_demo (full cycle):
  - Setup: 双方各 5 worker + 2 gold node + 2 wood node + ct + 起手 starting (不够直接造 barracks)
  - Tick N: worker harvest → 资源到达 cost → 玩家 enqueue PlaceBuildingCommand barracks
  - Tick M: barracks spawn melee → melee 攻 ct
  - 验证: cycle 完整, worker 不卡, drop-off 计数对, building 放置成功
- 编辑器 F6 视觉验证: demo_rts_frontend.tscn 起手 spawn worker + node, 玩家可见 worker harvest + 资源 bar 增长 + 攒到 cost 后能放兵营

**Acceptance 主旨**:
- smoke_economy_demo PASS
- F6 demo 视觉链路 OK
- M2.1 Economy 整体收口 → archive

---

## 关键 design 待 phase 启动时确认

| 决策 | 选定 / 倾向 | 何时定 / 已定 |
|---|---|---|
| ResourceNode 是否阻挡 footprint | ✅ 不阻挡 (worker 可踩) — D2 | Phase B 启动 (2026-05-02) |
| Worker default strategy | ✅ 复用 RtsBasicAttackStrategy — D4 | Phase B 启动 (2026-05-02) |
| RtsResourceNode 与 RtsBuildingActor 关系 | ✅ 平级独立子类 (都继承 RtsBattleActor) — D5 | Phase B 启动 (2026-05-02) |
| Drop-off 建筑 | 复用 crystal_tower | Phase C |
| Worker 出生方式 | hardcode demo / scenario spawn N 个 | Phase C |
| Worker AI: GOLD/WOOD 平衡 vs round-robin vs 玩家手动指派 | autonomous round-robin (找最近) | Phase C |
| Building cost 配方 | 见 Phase D §scope 草案 | Phase D |
| starting_resources 调值 | 见 Phase D §scope 草案 | Phase D |

---

## 跨 Phase 不变的设计要点 (用户已确认 2026-05-02)

- **D1 — 资源累积模式**: Worker harvest (SC 经典)
- **D2 — 资源类型**: 2 种 (gold + wood)
- **D3 — Frontend HUD**: logic + minimal HUD (不做 icon bar, 仅 Label "Gold: X | Wood: Y")
- **D4 — Cost 字段**: 硬迁 multi-resource (一次性, 不留 cost: int 兼容字段)
