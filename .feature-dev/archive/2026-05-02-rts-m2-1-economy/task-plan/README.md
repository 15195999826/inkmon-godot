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
| [`m2-1-economy/phase-b-resource-nodes.md`](m2-1-economy/phase-b-resource-nodes.md) | Phase B 详细子任务 B.1-B.6 | ✅ done (2026-05-02; 6/6 AC PASS) |
| [`m2-1-economy/phase-c-harvest-activity.md`](m2-1-economy/phase-c-harvest-activity.md) | Phase C 详细子任务 C.1-C.7 + D6-D16 决策表 + Simplify Pass 段 | ✅ done (2026-05-02; 7/7 AC PASS) |
| [`m2-1-economy/phase-d-cost-rebalance.md`](m2-1-economy/phase-d-cost-rebalance.md) | Phase D 详细子任务 D.1-D.4 + D17/D18/D19 决策表 (skeleton) | 🔒 pending (Phase C 收口时落 skeleton, 等待用户启动) |

---

## 当前 Phase 总览 (M2.1 Phase C ✅ 收口; Phase D 等待用户启动)

**Phase A + B + C ✅ 收口 (2026-05-02)** — Multi-Resource Foundation + Resource Nodes + Worker Class + Harvest Activity + Drop-off Loop

20/20 AC (Phase A 7 + Phase B 6 + Phase C 7) 全过, Phase C 13/13 validation 全套 PASS 0 行为漂移 + simplify pass clean。

**Phase D 🔒 pending (2026-05-02)** — Cost Rebalance + smoke_economy_demo

经济闭环对外可观。详细 plan skeleton: [`m2-1-economy/phase-d-cost-rebalance.md`](m2-1-economy/phase-d-cost-rebalance.md) (5 AC + 4 子任务 + D17/D18/D19 决策表 skeleton)。等待用户在 phase-d-cost-rebalance.md 内 finalize D17/D18/D19 (cost 数值具体配方 / smoke_economy_demo 时长阈值 / demo_rts_frontend 起手 spawn 列表) 后启动。

---

## M2.1 Phase 总览 (4 phase)

### Phase A — Multi-Resource Foundation ✅ done (2026-05-02)

详见 [`m2-1-economy/phase-a-multi-resource.md`](m2-1-economy/phase-a-multi-resource.md)。7/7 AC PASS, bit-identical 0 漂移, 全 smoke 数字与 RTS M1 末态一致。

### Phase B — Resource Nodes + Worker Class ✅ done (2026-05-02)

详见 [`m2-1-economy/phase-b-resource-nodes.md`](m2-1-economy/phase-b-resource-nodes.md) (AC 全部 [x] 收口) + `Progress.md` §Phase B。

落地内容 (D1-D5 决策全沿用):
- 新 `RtsResourceNode` actor (extends RtsBattleActor 平级独立子类; 字段 field_kind / max_amount / amount / field_kind_key; team_id 默认 -1 中立; D2 不阻挡 footprint)
- 新 `RtsResourceNodeConfig` (FieldKind enum GOLD=0/WOOD=1 + StatBlock + raw const + get_stats + field_kind_to_resource_key)
- 新 `RtsResourceNodes` 工厂 (create_gold_node / create_wood_node)
- `UnitClass.WORKER` (=3 by 顺序声明位置) + StatBlock 加 carry_capacity / harvest_speed (worker 10/5.0, 其它兵种默认 0)
- `RtsAIStrategyFactory.get_strategy(WORKER)` 复用 _basic_attack (D4 决策 — worker mask=NONE 自然 idle)
- 新 `smoke_resource_nodes.tscn` PASS (ticks=200 alive_workers=5 gold/wood amount=1500 max_drift=0.00)

回归验证: LGF 73/73 + 既有 6 smoke + 2 replay smoke + frontend smoke 0 行为漂移 (与 Phase A 末态完全一致)。

### Phase C — Harvest Activity + Drop-off Loop ✅ done (2026-05-02)

详见 [`m2-1-economy/phase-c-harvest-activity.md`](m2-1-economy/phase-c-harvest-activity.md) (AC 全部 [x] 收口 + Simplify Pass 段) + `Progress.md` §Phase C。

落地内容 (D6-D16 决策全沿用 + simplify pass 抽象到位):
- 新 RtsHarvestActivity / RtsReturnAndDropActivity (Activity 基类抽 nav refresh helper, 三 Activity 共用)
- 新 RtsHarvestStrategy + factory WORKER 切换
- RtsBuildingActor.is_drop_off + RtsBuildingConfig.StatBlock.is_drop_off (与 is_crystal_tower 同模式 工厂统一注入)
- RtsUnitActor.carrying + get_carry_total() helper
- RtsAutoBattleProcedure.add_team_resources 对称 spend_team_resources
- RtsWorldGameplayInstance.bind_procedure 让 Activity 通过 world.procedure 改资源
- 新 smoke_harvest_loop (5 worker + 1 gold + 1 wood + 双方 ct, 跑 600 tick → team_gold=140 team_wood=212 cycle_workers=5)
- Phase B smoke_resource_nodes 重定位 (HarvestStrategy fallback to IdleActivity 找不到 node — 方案 A)

回归验证: 13 项 validation 全套 0 行为漂移 (4v4 ticks=347 attacks=74 melee_max_dist=24.00 bit-identical; replay frames=9 events=20 deep-equal; det tick_diff=0)。

### Phase D — Cost Rebalance + smoke_economy_demo 🔒 pending (2026-05-02)

详见 [`m2-1-economy/phase-d-cost-rebalance.md`](m2-1-economy/phase-d-cost-rebalance.md) (Phase C 收口时落 skeleton; AC1-AC5 + D17/D18/D19 决策表 + 4 子任务)。

经济闭环对外可观: 给 archer_tower / barracks 重定 multi-resource cost (例草案: barracks={"gold": 80, "wood": 50}, archer_tower={"gold": 60, "wood": 100}; 数值 D17 待用户启动 Phase D 时 finalize) + smoke_economy_demo (full cycle: worker harvest → 资源到达 cost → enqueue PlaceBuildingCommand → 自动放下个建筑) + 编辑器 F6 视觉验证 demo_rts_frontend 经济闭环。

**Acceptance 主旨**: 经济闭环 full cycle smoke PASS + F6 demo 视觉链路 OK + RTS M2.1 Economy 整体收口 → archive

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
