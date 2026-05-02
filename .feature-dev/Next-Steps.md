# Next Steps — 2026-05-02 (RTS M2.1 Economy — Phase A ✅ 收口; Phase B 启动 — Resource Nodes + Worker Class)

## 当前目标

**RTS Auto-Battle M2.1 — Economy (Worker Harvest, gold + wood) — Phase B: Resource Nodes + Worker Class**

Phase A 已收口 (multi-resource cost 字段全链路 dict 化, 7/7 AC PASS, bit-identical replay 0 漂移). Phase B 在此基础上引入新 actor 类型 (`RtsResourceNode`) + 新单位类 (`UnitClass.WORKER`) + idle 行为 + 新 smoke (`smoke_resource_nodes`); **不接** harvest / drop-off / 任何经济闭环逻辑 (那些是 Phase C)。

> M2.1 完整规划: [`task-plan/m2-1-economy/README.md`](task-plan/m2-1-economy/README.md)
> Phase B 详细子任务: [`task-plan/m2-1-economy/phase-b-resource-nodes.md`](task-plan/m2-1-economy/phase-b-resource-nodes.md)
> Phase A 已归档于 `task-plan/m2-1-economy/phase-a-multi-resource.md` + `Progress.md` §Phase A
> M2 整体路线图: [`task-plan/m2-roadmap.md`](task-plan/m2-roadmap.md)

## 设计要点 (Phase B 启动时确认)

详见 `phase-b-resource-nodes.md` §设计决策:
- **D1 — field_kind 类型**: int 枚举 `RtsResourceNodeConfig.FieldKind { GOLD=0, WOOD=1 }` (与 RTS 既有枚举风格一致); cost dict key 用 String, 通过 `field_kind_to_resource_key(kind: int) -> String` 映射
- **D2 — ResourceNode 不阻挡 footprint** (worker 可踩, 简化 Phase C harvest nav)
- **D3 — Worker 出生方式**: hardcode smoke 起手 spawn (Phase B 阶段); `SpawnWorkerCommand` 不加 (Phase C 视情况)
- **D4 — Worker default strategy**: 复用 `RtsBasicAttackStrategy` (worker target_layer_mask=NONE 让其找不到敌 → 自然 IdleActivity); 若 side effect 出问题再启用 `RtsWorkerIdleStrategy`
- **D5 — RtsResourceNode 与 RtsBuildingActor 关系**: 平级独立子类 (都继承 RtsBattleActor), 不复用 RtsBuildingActor

## Phase B 验收准则 (本轮 6 条)

- [ ] **AC1** 新 `RtsResourceNodeConfig` (field_kind / max_amount / harvest_per_tick (Phase C 用占位) / footprint_size / actor_tags + StatBlock + get_stats + field_kind_to_resource_key)
- [ ] **AC2** 新 `RtsResourceNode` actor (extends RtsBattleActor; field_kind / amount / is_depleted; override is_dead; 不参战 — atk=0 / target_layer_mask=NONE)
- [ ] **AC3** 新 `RtsResourceNodes` 工厂 (`create_gold_node()` / `create_wood_node()`)
- [ ] **AC4** `RtsUnitClassConfig.UnitClass.WORKER` (max_hp=50, move_speed=80, atk=0, attack_range=0, movement_layer=GROUND, target_layer_mask=NONE, unit_tags=["worker"], + 新字段 carry_capacity=10 / harvest_speed=5.0 占位 Phase C)
- [ ] **AC5** Worker idle 行为不被 default strategy 干扰 (`RtsAIStrategyFactory.get_strategy(WORKER)` 返 RtsBasicAttackStrategy 复用; worker 因 mask=NONE 自然 idle)
- [ ] **AC6** 新 `smoke_resource_nodes.tscn` PASS:
  - 起手: 5 worker (左 team 0) + 1 gold node + 1 wood node + 右方 1 ct (永远不死) 让战斗持续
  - 跑 200 tick 后: worker 5 alive + 距 spawn ≤ 50 px + gold/wood node amount = max_amount + 无 SCRIPT ERROR
  - 既有 6 smoke + replay smoke 双 + frontend 不退化 (regression gate)
  - LGF 73/73 仍 PASS

## 下一步

按 `task-plan/m2-1-economy/phase-b-resource-nodes.md` 实施步骤逐步推进。最小可行第一步:

**Step 1** — 新 `RtsResourceNodeConfig` (AC1; B.1 子任务)
- 文件: `addons/logic-game-framework/example/rts-auto-battle/logic/config/rts_resource_node_config.gd` (新)
- 改动: class_name + 内嵌 StatBlock + enum FieldKind { GOLD=0, WOOD=1 } + raw const _GOLD_NODE_STATS / _WOOD_NODE_STATS + static get_stats / field_kind_to_resource_key
- import 0 错误后做 B.2 (新 RtsResourceNode actor)

(Step 2-N 见 phase-b 文档 §子任务 6 步)

## 非目标 (本轮 Phase B 不做)

- ❌ HarvestActivity / ReturnAndDropActivity (Phase C)
- ❌ HarvestStrategy 自动找最近资源点 (Phase C)
- ❌ Drop-off 建筑设计 (Phase C — 倾向复用 crystal_tower)
- ❌ Worker 加入 team 列表参与 _check_battle_end (Phase B worker 仅占位 spawn, idle)
- ❌ ResourceNode amount 减少逻辑 (Phase C harvest 时才减)
- ❌ smoke_harvest_loop / smoke_economy_demo (Phase C/D 各自加)
- ❌ Building cost 重平衡 (Phase D)
- ❌ HUD 显示 worker carrying / harvest 状态 (Phase D 可选)
- ❌ AI 对手 (computer player) 启动 (M2.2 sub-feature, deferred)
- ❌ Build Panel UI / 多 building_kind 选择 (M2.3 sub-feature, deferred)

## F6 视觉验证 (Phase B 不要求, Phase C/D 才有意义)

Phase B 仅 logic 层 + headless smoke 验证; demo 不动 (worker 不出现在 demo_rts_frontend 起手 spawn 列表)。

## 启动后续 Phase / 新 sub-feature

本轮 Phase B 完成后:

- 下一轮: 启动 **Phase C** (Harvest Activity + Drop-off Loop) — 在 Next-Steps.md 切到 active, 写 `phase-c-harvest-activity.md`
- Phase C/D 完成后: M2.1 Economy 整体收口 → 归档至 `.feature-dev/archive/<YYYY-MM-DD>-rts-m2-1-economy/`
- 整个 RTS M2.1 完成后用户决定是否启动 M2.2 (AI 对手) 或 M2.3 (UI HUD)

要在 RTS M2.1 完成后开新的非延续 feature, 调 `/next-feature-planner`。
