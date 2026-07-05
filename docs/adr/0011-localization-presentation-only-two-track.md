# 本地化 = 表现层独占 + 双轨资产(框架文案 CSV / 内容文案 lab canon)

UI 现状全英文硬编码,要换中文;借这次全量替换把本地化框架立好,替换动作直接完成 key 化(一步到位,不留双轨期)。翻译工作由 AI 执行 ⇒ 资产选型按 AI-native 准绳(格式对 AI 友好 / 中英同处对照 / diff 干净 / 模型先验强),而非人类翻译工具链生态。

## 决定(铁律)

1. **逻辑层禁产玩家可见文案** —— logic 只产语义数据(type/id/count/reason 码),`tr()` 与拼参全在 presentation。红利:headless smoke / replay / 确定性模拟的断言永不被 locale 污染。`Log`/`print` 调试输出豁免,不算文案。
2. **用 Godot 内置 i18n,不自研** —— `TranslationServer` + `tr()`;表现层唯一出口 **`InkMonText`**(static 纯函数类,`inkmon/presentation/text/`):`quest_title()` / `site_name()` / `reject_reason()` 等组装函数全住这里,底下 `tr().format()`。**逻辑层出现 `tr(` 或 `InkMonText` 引用 = review 一眼见的违例**。
3. **资产双轨**:
   - **框架文案**(UI chrome / HUD / reason 码 / 地标名等 godot 域) → `inkmon/presentation/text/translations.csv`(key,en,zh 三列,单文件起步,多了按域拆)
   - **内容文案**(species/item 名,将来技能名/描述) → **lab canon**(adr/0003:内容单一事实源=lab):schema 加 zh 字段、契约投影双语、godot catalog 按 locale 取名(无 zh fallback en)。改 spec 走 lab+godot 双仓同步惯例。
4. **key 规范**:全大写下划线+域前缀(`UI_` `QUEST_` `SITE_` `NPC_` `REASON_`…);占位符**具名** `{n}` `{site}`(`String.format`),**禁 `%s` 位置风格**(中英语序不同必须可重排);复数优先中立文案,躲不开拆 `_ONE`/`_MANY`。
5. **场景静态文案 = .tscn text 直接写 key, 走内置 auto_translate 原生查表**(实施修订: 摸排发现 .tscn 静态文案量可观——modal 标题/按钮/说明——逐个 _ready 赋值是纯噪音)。auto_translate 保持默认开; 动态赋值串被再查一次 miss 原样返回, 无害(key 全大写, 动态串不会撞)。动态文案唯一组装入口仍是 InkMonText; smoke 强制 .tscn text 值 ∈ CSV key ∪ 无字母符号。
6. **默认 locale = zh**,v1 不做游戏内切语言,留 `TranslationServer.set_locale()` 口子(切语言 = 重建场景,不做运行时刷新)。
7. **存档/跨层 dict 只流转 id,不流转显示名** —— 现状 `world_gi` / `i_world_query` / 捕捉快照流转英文 `display_name`,切中文后存档躺英文名;改为流转 `species_id`,表现层查名(不向后兼容,直接删字段)。
8. **纪律机器可验**:测试断言禁断显示文案(断数据/reason 码/key);加**漏 key smoke**——CSV 双列非空 + 代码字面 key 必在 CSV + 内容 id(sites/species/items)派生名必齐全。
9. **字体自带** —— 项目零字体资产,现有中文靠系统 fallback;**Web 导出无系统字体,中文必豆腐块**。自带 Noto Sans SC,按 translations.csv 实际用字生成子集(构建脚本抽字表,全量 10MB+ → 子集 1-3MB)。

## 考虑过的另一派(rejected)

- **gettext PO**:核心优势(Poedit/Weblate 人类工具链、翻译记忆、POT 抽取)对 AI 翻译零价值;每语言一文件 = AI 翻译时中英不同处、漏翻难扫;"抽 POT→msgmerge→填"三步对"加 key 当场填双语"的工作流纯累赘。复数支持是唯一损失,中英双语下用中立文案/拆 key 兜底;将来真上复杂复数语言再迁,key 已在,机械活。
- **自研字典查表**:热更/服务器拉取/复杂语法等自研理由在本项目全不成立;自研 = 重写加载/fallback/切换通知还失去编辑器工具链。
- **逻辑层直接 tr()**(改动最小):逻辑层输出随 locale 变,smoke 断言被语言设置污染,违三层铁律。
- **逻辑层产 {key,params} 折中**:两层都碰文案概念,key 散逻辑层;表现层独占更干净且 InkMonText 重建 match 分支成本可忽略。
- **内容名抽进 godot CSV**:lab 加怪要跨仓补 CSV,违 adr/0003 canon 纪律。
- **english-as-key(text-based)**:改英文文案 = 断所有语言链,快速迭代期致命;走稳定 key。

## 落地状态

**已落地 (2026-07-05, 一步到位)**:

- 资产: `inkmon/presentation/text/translations.csv`(~95 key, en+zh 双列全填) + `InkMonText`(同目录) + project.godot 注册 translations / fallback=en / `gui/theme/custom_font`
- 字体: `tools/build_font_subset.py`(字表 = CSV 用字 + content.json 字符串值用字 + ASCII + CJK 标点; lab 中文名落地后重跑) → `noto_sans_sc_subset.otf` 145KB/326 字; 全量源字体不入库
- 逻辑层违例清零: quest_def 三个展示函数删除(投影改传 `quest: def.to_dict()`); npc handler `_action` 改语义签名(id/kind/enabled/extras: variant/quest/item_config_id/price/display_name 透传); world_gi 捕捉池与 attempt 返回、i_world_query roster 投影不再流转 display_name; `"Player"`/NPC registry display_name 留作 debug(不再喂 UI)
- 表现层: presentation/ui 全量 key 化(代码走 InkMonText, .tscn 静态文案写 key 走 auto_translate); overworld NPC 地图标签走 `npc_name`; roster chip `short_name` 加 CJK 分支; battle_2d 全部标记/浮字/提示 key 化; 主菜单 + `set_locale("zh")` 在 InkMonMain._ready
- 测试: `smoke_localization`(inkmon/localization 组) 五项纪律机器可验; `smoke_mission_departure` 断言改断数字不断文案; `acceptance_full_loop` 修 harness 盲区(timeout 野群战清锁后回放仍须看完离场, 判据从 pending 扩到 _replaying)
- 顺带修复的两个**既有缺陷**(被验收随机 seed 揪出, 与本地化正交但被放大):
  - mission HUD 面板 `mouse_filter=STOP` 遮挡地图深层节点点击 —— 面板本被内容撑大越界(中文行高放大了撞击面), 深层节点屏幕位置(左上走向)落进面板即卡死出征; 修: MissionPanel/MissionBox `mouse_filter=IGNORE`(AbandonButton 独立命中不受影响)
  - acceptance harness 只认 pending 判"有仗要看", timeout 野群战(GI 设计内即刻清锁)的回放没人点离开 → `_replaying` 挡死地图; 修: 判据扩到 `_replaying`(对齐真实玩家看完点离开)
  - 另加 departure modal close() 的 overlay 残留自愈防御(幂等无害)
  - 修后 acceptance 8 连跑全 PASS(修前失败率 ~1/4)
- 遗留:
  - lab 侧 zh 名字段 + 契约投影(另仓); 到位后 species_name/item_display 单点接入即生效
  - battle result 值域 key 仅列 left_win/right_win/timeout, 新结局值上屏显英文原值(自曝式降级)
