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
| [`m2-1-economy/phase-c-harvest-activity.md`](m2-1-economy/phase-c-harvest-activity.md) | Phase C 详细子任务 C.1-C.7 + D6-D16 决策表 | 🚧 active (2026-05-02 启动; 0/7 AC) |

> Phase D 详细文档待 Phase C 收口后添加。`m2-1-economy/README.md` 已列出每 phase 的 scope / acceptance 主旨。

---

## 当前 Phase 总览 (M2.1 Phase C 启动 active)

**Phase A + B ✅ 收口 (2026-05-02)** — Multi-Resource Foundation + Resource Nodes + Worker Class

13/13 AC (Phase A 7 + Phase B 6) 全过, 11/11 validation 全套 PASS, 0 行为漂移。

**Phase C 🚧 active (2026-05-02 启动)** — Harvest Activity + Drop-off Loop

经济闭环核心。详细 plan: [`m2-1-economy/phase-c-harvest-activity.md`](m2-1-economy/phase-c-harvest-activity.md) (7 AC + 7 子任务 + D6-D16 决策表 + 风险表)。用户已确认 D6/D7/D8 (Drop-off=ct / 找最近未耗尽 / hardcode spawn);D9-D16 实现细节决策由执行者按文档落地。下一步 = Step 1 (C.1 World ↔ Procedure 通信打通)。

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

### Phase C — Harvest Activity + Drop-off Loop 🚧 active (2026-05-02)

详见 [`m2-1-economy/phase-c-harvest-activity.md`](m2-1-economy/phase-c-harvest-activity.md) — 7 AC + 7 子任务 (C.1-C.7) + D6-D16 决策表 + 风险表 + Validation 顺序。

**用户已确认决策** (2026-05-02):
- **D6** Drop-off = 复用 crystal_tower (RtsBuildingActor 加 is_drop_off 字段, ct 起手设 true)
- **D7** Worker AI = 找最近未耗尽 ResourceNode (round-robin tiebreak by actor_id)
- **D8** Worker 出生 = hardcode smoke/demo (不加 SpawnWorkerCommand)

**Acceptance 主旨**: smoke_harvest_loop (5 worker + 1 gold + 1 wood + 双方 ct 不死, 跑 600 tick → gold + wood 双增长 ≥ 100 + 至少 1 worker 完整 cycle) + 既有 6 RTS smoke + 2 replay smoke + frontend smoke 0 漂移 + LGF 73/73 不退化 (Phase B smoke_resource_nodes 因 strategy 切换可能需要调整, 见 phase-c §风险表)

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
