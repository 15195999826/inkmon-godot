# 装备数值靠 grant ability 生效(进加成层,不焊进 base)

装备 item 的数值效果 = 穿戴时给 actor **grant 一个 ability**,ability 携 `StatModifierComponent` → `AttributeModifier` → `RawAttributeSet.add_modifier`(进**加成层**,非 base);脱下时按 ability instance id **精确 revoke**。v1 只做纯数值,用**单一通用 ability**,穿戴瞬间拿 item 自己的 `stat_mods` **现场拼** `StatModifierConfig`(数字来自 lab 的 item 数据,不写死 godot 配置)。

地基 = hex-atb-battle 已落地的机制:`HexActorEquipmentContainer`(Phase G 的 grant/revoke 生命周期)+ LGF `StatModifierComponent`/`AttributeModifier`/`AttributeBreakdown` 四层属性公式。数字来源见 [adr/0003](0003-item-config-lab-canon-static-import.md);数据模型见 [adr/0001](0001-unified-live-actor-model.md)。

> **本 ADR 反转一条既有决定**:[main-game-architecture.md §8c](../main-game-architecture.md) 原写「装备走 base 折叠、hex Phase-G = Non-Goal、**不引入主游戏**」。本 ADR 推翻之 —— **代价** = 把 hex 的装备 grant 机器搬进主游戏;**换取** = 数字归 lab(adr/0003)+ 来源可 introspect + 富效果可扩展。§8c 已据此更新。这不是"换掉烂代码",是有取舍的架构反转。

## 决定(铁律)

1. **装备数值进"加成层"、不进 base** —— 角色属性 = base + 各 modifier 层(`AttributeBreakdown` 四层公式)。装备只塞 modifier,**算得出每条 +X 来自哪件 item**,可被 introspect。取代 inkmon 现 `InkMonUnitActor._equipment_mods()` + `apply_derived_stats` 把 stat_mods **焊进 base** 的土办法。
2. **穿/脱 = grant/revoke 对称,revoke 按 instance id 精确** —— item 进装备格 → grant ability 并记录 instance id;离格 → 按记录的 instance id 精确 revoke,**不按 config_id 粗暴 revoke**(防误删 actor 自带 / 其它装备 grant 的同 config_id 被动)。对齐 `HexActorEquipmentContainer._granted_abilities` 做法。
3. **单一通用 ability,数字现场来自 item(甲案)** —— 不为每种数值组合各写一个 named ability config。穿戴时读 `itemconfig.stat_mods`,用 `StatModifierConfig.builder().modifier(attr, ADD_BASE, value)` **现场构造**,塞进通用 ability shell 再 grant。⇒ **数字归 item 数据(lab),通用 ability 是 godot 纯机制、与具体数值无关** → 不进契约、不 godot→server 上行。
4. **预校验,callback 不背回滚** —— 能否装备(含数值合法性)在 `can_add_item`/`can_move_item` 阶段判完;进 container callback 后假定 prevalidated(对齐 hex Phase G "callback 不能承担失败回滚")。
5. **两条独立通道,并存不二选一** —— 装备对 actor 有两种作用,各走各的:**①基础属性**(+5 攻击这类纯数字)= 本 ADR 的通用 ability 现场读 `stat_mods`(甲);**②装备送技能**(武器给一个主动技能/富效果)= itemconfig 的 `granted_abilities` 指向 godot 预制 ability 配置,经 `HexEquipmentAbilityResolver` 解析后 grant。lab item canon 已建 ②(`granted_abilities` 字段),**缺 ①的 `stat_mods` 字段、待补**(见 adr/0003)。两者共用同一套 grant/revoke 生命周期。

## 考虑过的另一派(rejected)

- **直接 fold 进 base(inkmon 现状)**:无法 introspect 来源、与 buff/ability 管线异构、富效果(吸血/触发)将来无法平滑长出。被加成层方案取代。
- **用 `granted_abilities`(named ability config)承载基础属性数值**(每种 +X 各写一个预制被动如 `passive_ad_5`):那把**基础属性数字写死在 godot 配置**里,与 [adr/0003](0003-item-config-lab-canon-static-import.md)"基础属性数字归 lab"矛盾、且数值组合爆炸 ⇒ **基础属性不用此法,改通用 ability 现场读 stat_mods**。⚠️ 注意:`granted_abilities` 本身**不被否决**——它是**装备送技能**的独立通道(决定 #5 ②),保留;此处否决的只是"拿它来塞基础属性数字"。
- **乙案:改 `StatModifierComponent` 让它从 ability metadata 读数字**:更深的框架改动;好处是数字随存档走,但 item 数字本就在 item 数据(lab)、装备实例只存 `config_id`,无随档需求 ⇒ 否决,选甲(零引擎改动 + 数字来源摆明面)。

## 落地状态

**待落地(重构)**。当前 `InkMonUnitActor` 走 `equipment_container_id` + `_equipment_mods()` 焊 base。改造点:
1. 主游戏建 item 装备容器(参考 `HexActorEquipmentContainer` 的 grant/revoke + 精确 revoke + metadata attribution)。
2. 加通用 item ability shell;穿戴时从 `itemconfig.stat_mods` 现场构造 `StatModifierConfig` → grant。
3. 删 `_equipment_mods()` / `apply_derived_stats` 的装备 fold 分支(派生六维只剩 species_base × 等级缩放;装备改走加成层)。
4. smoke:装备 → 攻击经**加成层**抬升且 breakdown 可溯源 → 脱下复原;round-trip(存档只存 `config_id`,读档重穿重 grant)。

> 衔接 [adr/0003](0003-item-config-lab-canon-static-import.md)(item 数字归属)。本 ADR 只管"数字怎么作用到 actor",不管"数字从哪来"。
