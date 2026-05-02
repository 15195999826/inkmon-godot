# M2.1 — Economy (Worker Harvest, gold + wood) ✅ done (2026-05-02)

> **Sub-feature of**: RTS M2 (见 [`../m2-roadmap.md`](../m2-roadmap.md))
>
> **目标**: 把 RTS demo 现有的"starting_resources 一次性 100 gold"演进为"worker harvest 资源闭环 + 双资源 cost"。
>
> **收口结论**: 4 phase 全过 (A 7/7 + B 6/6 + C 7/7 + D 5/5 = 25/25 AC PASS); Phase D 收口时 18/18 validation 全套 PASS, 0 行为漂移; M2.1 整体待 archive。

---

## 4 Phase 拆分

| Phase | 内容 | Status |
|---|---|---|
| **A** | Multi-Resource Foundation (config 迁移 + 既有 smoke 适配) | ✅ done (2026-05-02; 7/7 AC PASS, bit-identical replay 0 漂移) |
| **B** | Resource Nodes + Worker Class (新 actor + UnitClass.WORKER + idle 行为) | ✅ done (2026-05-02; 6/6 AC PASS, 11/11 validation 全过 0 漂移) |
| **C** | Harvest Activity + Drop-off Loop (HarvestActivity + ReturnAndDropActivity + crystal_tower 兼 drop-off) | ✅ done (2026-05-02; 7/7 AC PASS, 13/13 validation 全过 0 漂移, simplify clean) |
| **D** | Cost Rebalance + smoke_economy_demo (经济闭环 full cycle + F6 视觉) | ✅ done (2026-05-02; 5/5 AC PASS, 18/18 validation 全套 PASS, simplify clean) |

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

## Phase C — Harvest Activity + Drop-off Loop ✅ done (2026-05-02)

**详细 plan**: [`phase-c-harvest-activity.md`](phase-c-harvest-activity.md) (AC 全部 [x] 收口 + simplify pass 段)

**收口结论**: 7/7 AC PASS, 13/13 validation 全套 PASS, 0 行为漂移; simplify pass 抽 nav refresh 到基类 + get_carry_total + is_drop_off StatBlock + stats cache + dead write 删除, 跑完 simplify 13/13 仍 PASS (bit-identical 4v4 ticks=347/replay frames=9 events=20)。

落地内容 (D6-D16 决策全沿用):
- 新 `RtsHarvestActivity` (extends RtsActivity; 单 Activity 自管 nav 类似 AttackActivity, in-range 累 progress + transfer; on_first_run cache stats)
- 新 `RtsReturnAndDropActivity` (extends RtsActivity; on_first_run 找己方最近 is_drop_off 建筑; 抵达调 procedure.add_team_resources + carrying.clear)
- 新 `RtsHarvestStrategy` (extends RtsAIStrategy; carry > 0 → ReturnAndDrop; 否则找最近 ResourceNode → Harvest; 找不到 → Idle)
- `RtsAIStrategyFactory.WORKER` 切到 `_harvest_strategy` (melee/ranged 不动)
- `RtsBuildingActor.is_drop_off: bool` 字段 + `RtsBuildingConfig.StatBlock.is_drop_off` (crystal_tower 起手 true; 工厂统一注入)
- `RtsUnitActor.carrying: Dictionary[String, int] = {}` + `get_carry_total()` helper
- `RtsAutoBattleProcedure.add_team_resources(team_id, delta)` 对称 spend
- `RtsWorldGameplayInstance.bind_procedure(p)` 让 Activity 通过 world.procedure 改资源
- 基类 `RtsActivity` 抽 nav refresh helper (NAV_REFRESH_INTERVAL / _time_since_nav_refresh / _last_set_target / _should_refresh_nav / _refresh_nav_target) — attack/harvest/return 三 Activity 共用
- 新 `smoke_harvest_loop.{gd,tscn}` PASS (ticks=600 alive_workers=5 team_gold=140 team_wood=212 gold_node=1360/1500 wood_node=1288/1500 cycle_workers=5)
- Phase B `smoke_resource_nodes` 重定位 (HarvestStrategy fallback to IdleActivity 找不到 node — 方案 A): ticks=200 alive=5 max_drift=0.00

回归验证: LGF 73/73 + 既有 6 RTS smoke + 2 replay smoke + frontend smoke + smoke_harvest_loop + smoke_resource_nodes (重定位) 全过 0 行为漂移 (4v4 main 数字与 Phase B 末态完全一致 ticks=347 attacks=74 melee_max_dist=24.00; bit-identical replay frames=9 events=20 deep-equal; det tick_diff=0)。

---

## Phase D — Cost Rebalance + smoke_economy_demo ✅ done (2026-05-02)

**详细 plan**: [`phase-d-cost-rebalance.md`](phase-d-cost-rebalance.md) (AC 全部 [x] 收口 + Simplify Pass 段 + Validation 全套 18/18 表) + [`../../Progress.md`](../../Progress.md) §Phase D。

**收口结论**: 5/5 AC PASS, 18/18 validation 全套 PASS, 0 行为漂移 (除 fixture cost/starting 数字漂); simplify pass 删 smoke_economy_demo 冗余 _max_total tracking; AC-doc consistency review 修 AC3 setup 描述 (2+2 → 1+1) / starting (100/100 → 0/0 smoke-only) / 删 "drop-off 计数对" 验证段。

落地内容 (D17-D19 决策全沿用):
- Building cost 重平衡 (`rts_building_config.gd`): barracks {"gold":80, "wood":50} (gold-rich 偏 melee 推 ct); archer_tower {"gold":60, "wood":100} (wood-rich 偏防空); crystal_tower {} (不可建造)
- starting_resources (D17 finalized {gold:100, wood:100}): rts_team_config.gd 默认 `{}` 不动; 4 个 smoke fixture + demo_rts_frontend.gd 直接传; smoke_economy_demo 用 {0,0} 强制 harvest
- 新 `smoke_economy_demo.{gd,tscn}` PASS (full cycle: 5 worker + 1 gold + 1 wood + 双方 ct, 跑 900 tick @ 30Hz, harvest → enqueue barracks → spawn melee → ≥1 melee 攻 ct)
- demo_rts_frontend.gd 完全重写 (5 worker + 1 ct + 4 中立 node / 方; 删 archer / 4 ground / flying_scout); HUD 文字更新 cost (gold 80 + wood 50)
- 4 个 smoke fixture 数字漂适配: smoke_player_command (gold/wood 100/0 → 20/50), smoke_player_command_production (gold 100 → 20), smoke_castle_war_minimal (加 wood 100 行为 0 漂移), smoke_replay_bit_identical (wood 0 → 500 双方加, bit-identical 0 漂移)

回归验证: 18/18 validation 全套 PASS — LGF 73/73 + 12 既有 RTS smoke + smoke_harvest_loop + smoke_economy_demo + 2 replay + frontend; 0 行为漂移 (4v4 main bit-identical ticks=347 attacks=74 melee_max_dist=24.00; replay frames=9 events=20 deep-equal; det tick_diff=0)。

---

## 关键 design 已确认

| 决策 | 选定 / 倾向 | 何时定 / 已定 |
|---|---|---|
| ResourceNode 是否阻挡 footprint | ✅ 不阻挡 (worker 可踩) — D2 | Phase B 启动 (2026-05-02) |
| Worker default strategy | ✅ 复用 RtsBasicAttackStrategy — D4 | Phase B 启动 (2026-05-02) |
| RtsResourceNode 与 RtsBuildingActor 关系 | ✅ 平级独立子类 (都继承 RtsBattleActor) — D5 | Phase B 启动 (2026-05-02) |
| Drop-off 建筑 | ✅ 复用 crystal_tower (RtsBuildingConfig.StatBlock.is_drop_off) — D11 | Phase C 启动 (2026-05-02) |
| Worker 出生方式 | ✅ hardcode smoke / demo spawn N 个 — D8 | Phase C 启动 (2026-05-02) |
| Worker AI: GOLD/WOOD 平衡 vs round-robin vs 玩家手动指派 | ✅ autonomous (HarvestStrategy 找最近未耗尽 node) — D10 | Phase C 启动 (2026-05-02) |
| Building cost 配方 | ✅ barracks {gold:80, wood:50} / archer_tower {gold:60, wood:100} / crystal_tower {} — D17 | Phase D 启动 (2026-05-02) |
| starting_resources 调值 | ✅ {gold:100, wood:100} (D17; smoke setup 走) | Phase D 启动 (2026-05-02) |
| smoke_economy_demo 时长 | ✅ 900 tick @ 30Hz (Bash timeout 45000ms) — D18 | Phase D 启动 (2026-05-02) |
| demo_rts_frontend Phase D 起手 spawn | ✅ 5 worker + 1 ct + 2 gold + 2 wood / 方 — D19 | Phase D 启动 (2026-05-02) |

---

## 跨 Phase 不变的设计要点 (用户已确认 2026-05-02)

- **D1 — 资源累积模式**: Worker harvest (SC 经典)
- **D2 — 资源类型**: 2 种 (gold + wood)
- **D3 — Frontend HUD**: logic + minimal HUD (不做 icon bar, 仅 Label "Gold: X | Wood: Y")
- **D4 — Cost 字段**: 硬迁 multi-resource (一次性, 不留 cost: int 兼容字段)
