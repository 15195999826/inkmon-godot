# L2 v1 占位项 — 刻印 / X→X2（待 lab 内容落地时补全）

> 本文记录 L2 主游戏重构 v1 里**有意留作占位**的两个机制：刻印 per-skill scoping、技能进化 X→X2。
> 目的是把「当前是什么 / 设计本意是什么 / 为何延后 / 将来怎么补」一次说清，避免又被当成「已完成」。
> 关联：`.codex-goal/l2-architecture-refactor/Progress.md` 的 Known Divergences (F1) + `docs/L2-ARCHITECTURE.md` §8c。

---

## 1. 刻印 per-skill scoping（= Progress F1，**该做未做**的真缺口）

### 当前实现（占位）
- `scenes/inkmon-battle/logic/abilities/passives/ink_mon_engraving_passive.gd`
  - hook `PRE_DAMAGE`，条件只判 `source_actor_id == owner`（`:32-33`），命中就把**所有** outgoing damage ×1.25（`:36-42`）。
  - 结果：普攻 + 任意技能都吃加成，**不区分 target_slot 指向的技能**。
- `scenes/inkmon-battle/logic/ink_mon_unit_actor.gd:119-122` 每条 engraving grant 一个**同款** passive，`target_slot` 没传进 ability。
- `target_slot` 数据全程存在（entry→snapshot→actor 都带），只是被 passive 忽略。

### 设计本意（Goal.md:16 / docs/L2-ARCHITECTURE.md:160）
- 「v1 **只强化指定 `skill_slot` 的技能**」；`target_slot` 对应 `skill_slots[].slot_index`。
- 即「给火球开小灶」应只让火球更疼，普攻和其它技能不变。

### 为何与 F3/X→X2 不同 —— 这是真亏欠
- Goal 字面要求 v1 就做到 per-slot，**没做到** → 属真 divergence（用户已拍板 v1 接受占位，但记录在案）。

### 将来怎么补（grill 已估，成本中等）
1. **给伤害事件加技能身份**：`ink_mon_battle_pre_events.gd` 的 `PreDamageEvent` 增字段 `source_ability_config_id`；在 `ink_mon_damage_action.gd:24/38` 用 `ctx.ability_ref` 的 config_id 填入（开火 ability 身份当场可拿）。
2. **passive 改无状态过滤**：engraving passive 改为**每 actor grant 一次**（不再每条 engraving 一个）；handler 内读 `owner.engravings → target_slot → owner.skill_slots[target_slot].skill_id`，与事件的 `source_ability_config_id` 比对，命中才 ×BONUS（多条命中同 slot → 叠乘/叠加）。保持 stateless 共享 config（守 enforcing-lgf）。
3. **测**：`smoke_progression` 或战斗 smoke 加断言「火球 slot + 刻印 → 火球伤害↑、普攻伤害不变」。

### 已知边界（即便补 per-slot 仍存在）
- PreEvent 系统**只有 `PRE_DAMAGE`，无 `PRE_HEAL`**。挂在治疗/纯辅助技能 slot 上的刻印**拦不到**，v1 即便做 per-slot 也只覆盖伤害类技能。要覆盖治疗需先加 `PRE_HEAL` 钩子（更大工程，归 lab）。

---

## 2. 技能进化 X→X2（= 设计点名要的占位，**按规格已做**，非缺口）

### 当前实现
- `scenes/inkmon-main/logic/content/ink_mon_species_catalog.gd`
  - `SKILL_EVOLUTIONS`（`:17-20`）：目前**只配一条** `inkmon_fireball → inkmon_chain_lightning`。
  - `evolve_entry`（`:104-108`）：进化时遍历旧 slot，凡 skill_id 命中 SKILL_EVOLUTIONS 就改写为进化后 skill_id。
- 机制通、确定性、有测：`smoke_progression.gd:137-138` 断言「cinder_kit lv5 进化 → slot0 火球升级成 chain_lightning」。

### 设计本意（docs/L2-ARCHITECTURE.md §8c / species_catalog 头注 :8-9）
- 「v1 X2 目标**复用现有真实技能（占位）**；真正独立的 X2 ability 随 lab 内容落地。」
- 即：现在的「进化后技能」是**借现成技能冒充**，不是真·进化技能；映射也只有一条。

### 为何不是缺口
- 设计**明写** v1 就用现成技能占位 → 占位**正是规格** → 属「按规格做了」，与刻印（该做未做）性质不同。

### 将来怎么补
1. lab 内容提供**真正独立的 X2 ability**（如「炽炎火球」而非借 chain_lightning）。
2. 扩 `SKILL_EVOLUTIONS` 覆盖更多 X→X2 对（目前仅 fireball）。
3. 评估「多段进化二次套用」是否要收敛（见下）。

### 已知 quirk（已记 Progress，可接受 / 语义可辩）
- 多段链 `cinder_kit → cinder_fox → cinder_drake`：fox 阶段 slot1 若 roll 到火球，会在 drake 进化时**再被** SKILL_EVOLUTIONS 升级一次（后期才长出的技能也吃升级）。
- 非崩溃、结果在合法池内、语义可辩（进一步进化继续强化）；仅 cinder 这一条两段链触发。
- 将来定 X→X2 是否**只作用于「出生原始携带槽」**时再收敛。
