# item config = lab canon 静态数据(数字发号 item_NNNN,editor-tool 导入,运行时只读本地)

itemconfig(一种 item 的共享定义:id / display_name / price / item_tags / stat_mods / equipable / max_stack / icon_key)是**纯数据、无 godot 逻辑**,与 unit base 同性质 ⇒ **归 lab/server canon**,身份键用 **server 发号的数字 `item_NNNN`**(对称 species `mon_NNNN`),数据流走 **静态导入**:editor tool 开发期拉一次→校验→写本地 JSON,**运行时只读本地、绝不联网**。

承接 [adr/0001 统一 live-actor](0001-unified-live-actor-model.md)(itemconfig 不进存档,只有 item 实例随活 actor 序列化)与 content 契约 [content-contract-v2-spec](../reference/content-contract-v2-spec.md)(本 ADR 把其中 out-of-scope 的 `items[]` 升为正式承载段)。装备数值**怎么生效**是另一问题,见 [adr/0004](0004-equipment-stat-via-granted-ability.md)。

## 决定(铁律)

1. **itemconfig 归 lab canon,不留 godot 硬编码** —— item 是策划填的死数字、零 godot 逻辑,和怪物基础六维是同一种东西;同一种东西同一个家 = lab/server。godot 只**接收 + 校验**。
2. **身份键 = `^item_\d+$`(如 `item_0001`),server MAX+1 发号** —— 与 species `^mon_\d+$` 对称、强唯一、防撞号/重命名漂移。**弃用英文 slug**(`training_sword` 那种)。
3. **静态数据流,运行时零联网** —— 复用 creature 那条线:`InkMonContentImportTool`(editor tool,开发期 fetch server `items[]` → `InkMonContentImporter` 校验 → 写 `res://data/inkmon_content.json`)+ 运行时 catalog **只读该本地文件**。拉到的数据被打进导出包,玩家端离线静态。**绝不存在运行时动态拉取**。(import tool 头注已为此预留:"item/skill server-sync tools can reuse the same mechanism"。)
4. **契约 `items[]` 升为承载段** —— v2 spec 现把 `items` 标 out-of-scope/留空;本 ADR 改为:lab 投影 itemconfig 进 `items[]`,godot 加防御性 item 校验(id 形状 + 必填字段)。改 spec 须 lab+godot 双仓同步(spec 权威源在 lab)。

## 推论:解锁 item-gated 进化

v2 spec §2.1 把进化条件 `type:"item"`(如"持火石→进化")标 **BLOCKED**,理由正是"item 域未迁 server"。本 ADR 迁了 ⇒ 该条件可解锁:进化条件里的 `item_id` 就是某个 `item_NNNN` itemconfig 的 id,godot 评估"活 actor(出战的 `InkMonUnitActor`)是否持有该 config_id 的 item 实例"即可(术语随 adr/0001 统一为活 actor,无 entry)。**数字发号(决定 2)正是为让进化条件能稳定引用 item 身份**。

## 考虑过的另一派(rejected)

- **itemconfig 留 godot 硬编码 stub**:被"纯数据 = 与 unit 同性质 = 归 lab"否决(用户决定:现在就迁,不是只占坑)。godot stub 仅作 lab item domain 落地前的**临时 fallback**,非终态。
- **英文 slug 身份键**(`training_sword` / `firestone`):人可读,但与 species 数字制不对称、撞号与重命名风险高、canon 难做权威发号;统一走数字。
- **运行时联网拉 item**:被"静态数据、离线导出、玩家端不联网"硬否决——与 creature 同纪律。
- **沿用 v1 契约"items 必填非空"**(见 deferred-features 旧文):那是 stub 自描述期的形状假设,与 v2 + 本 ADR 冲突,作废。

## 落地状态

**待落地(已定:现在就迁,非只占坑 —— 对比 §rejected『itemconfig 留 godot 硬编码 stub』那条被否决的临时方案)**。godot 现 stub catalog(`InkMonItemCatalog`:`training_sword`/`minor_rune`,英文 slug,`stat_mods` 内联)= 迁移前的临时态。

**lab 侧已落地(2026-06-05,乙-完整 = item 服务器同步)**:`inkmon-lab` 已把 item 改成与 creature 同构的 server 权威数据 —— 新建 driver-free `item-table.ts`(schema 加 `stat_mods`/`price`、id=`item_NNNN`、发号原语)、server `writeItem.ts`+`POST /item`+`/contract` 投 items、Electron promote 走服务器 + 读走同步镜像、清旧 slug。全套验证绿(vitest 298 / bun 52 / typecheck / biome)。

接入步骤(对称 creature 已有路径):
1. ✅ **lab 改造(done)**:item id → `item_NNNN`(server 发号);ItemSchema 加 `stat_mods`(载体机制 = [adr/0004](0004-equipment-stat-via-granted-ability.md) 的『穿戴瞬间现场读 stat_mods』方案)+ `price`;`godot-contract.ts` 真实投影 items(剔 description/image_prompt);测试 + 清库。
2. ✅ **lab spec 正本 + godot 抄本同步(done)**:`content-contract-v2-spec.md` 双仓已填 items 承载段(§1b)+ 解锁进化 `item` 条件(§2.1)。
3. ⏳ **godot(待落地)**:`InkMonContentImporter`/`validate_creature_base` 扩 item 校验;catalog 从硬编码 `_configs()` 切到读 `res://data/inkmon_content.json` 的 `items[]`;stub 退化为"无文件时 fallback"。
4. ⏳ 解锁进化 `item` 条件(godot 评估端,随 #3)。

> 取代 [deferred-features §3](../future/deferred-features.md) 中关于 item 的旧描述(schema v1 / items 必填非空 / canon Equipment 映射待定)。
