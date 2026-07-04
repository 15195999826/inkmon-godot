# MVP 阶段实施规划（Phase 1-4）

> 定位：[`gameplay-systems-roadmap.md`](../gameplay-systems-roadmap.md) 管"要去哪"，本文管"怎么去"。
> 输入 = Phase 0 拍板产物（P1 存档语义 / P2 三地图语境 / 术语 mission·quest，见 game-vision §1 末 + glossary §4.8/4.9）。
> 状态：2026-07-04 初稿（fable，用户外出期间产出），**待用户验收**。设计拍板权在用户：§1 是既定决策的工程展开（可直接批准动工）；§2-§4 各带"动工前待拍板问题"（Q 编号，附推荐答案，**未拍板**）。

---

## 0. 输入与代码锚点（已核实）

**已定决策**（不再复述，出处见 glossary §4.8/4.9 + game-vision §1 末）：出征态 transient 不序列化 / 出征中禁手动存档 / 出发自动写据点档 / 两出口（主委托完成 · 丢这趟）/ mission=出征 · quest=委托（1 主 + N 副）/ 世界地理开档一次生成固定入档 / 趟内 DAG 蔓延生成 / 迷雾两层 / 大地图不进 GI grid 机器。

**代码对称模板**（出征 flow 照 battle flow 的挂法抄，已 grep 核实）：

| battle 现役 | mission 对称物 |
|---|---|
| trainer handler 返回 `intent {kind:"start_battle"}` | guild handler 返回 `intent {kind:"start_mission"}` |
| Presentation `flow_intent_raised` 上抛 → Host `_on_flow_intent_raised` | 同一条 signal，加分支 |
| Host `_begin_training_battle_flow(generation)` | Host `_begin_mission_flow(generation)` |
| Host `_replay_active` 冻结世界泵 | 出征**不冻结**泵（选路走 command 通道，需要 tick drain） |
| Presentation `set_battle_active` / `app_state` 派生 | `set_mission_active` / `app_state` 加 `MISSION` |
| Host `save_to_slot` / `load_from_slot`（3 槽机器现成） | 出发档 = 独立预留槽（不占 3 手动槽） |
| `InkMonBattleSetup`（static 杂活） | `InkMonMissionSetup`（static 杂活） |

**routing 纪律**（adr/0002 三叉）：MissionState/世界地图运行态 → GI 持有；选路/用药等世界 mutation → command 通道（方案 A：mutation 只在 tick drain 一处发生）；出发/回城 → Host 控制面 flow（经 intent）。

---

## 1. Phase 1 出征骨架 —— 工程切分（无待拍板项，可直接批准动工）

> 目标：走通「出发 → 选路走格 → 抵达目标（占位主委托完成）→ 回城结算」+「粮尽 → 全灭 → 丢这趟」。
> 下述"默认已选"的工程细节，验收时可改：出发档独立槽位 / 点击节点走一跳的交互 / 粮尽掉血可致全灭 / 出征中 save·load 菜单置灰。

### M1.1 世界地图 data shape（logic）

- 新 `inkmon/logic/world/map/ink_mon_world_map_data.gd`（RefCounted 纯数据类）：`region`（v1 仅一个）、hex 地形 cells、地标、目标格候选、`revealed_cells`（持久点亮）；`static generate(seed)`（v1 极简：固定模板 + 随机扰动，或直接预制 JSON 当生成结果）；`to_dict / from_dict`。
- `InkMonWorldGI` 接线：`new_game()` 生成并持有；`to_dict/from_dict` 挂字段；`SAVE_VERSION` 2→3（旧档直接丢弃重开，§5.2 无迁移）。
- 测试：`smoke_world_map_data` —— 同 seed 生成确定性 / 序列化 roundtrip / 点亮集合持久。

### M1.2 MissionState + 出征 flow（logic + host）

- 新 `inkmon/logic/world/mission/ink_mon_mission_state.gd`（transient RefCounted，**无 to_dict**——P1 铁律）：携带委托（v1 占位主委托：目标格）、本趟节点图、当前节点、剩余补给、途中捕获列表、趟内视野。
- 新 `InkMonMissionSetup`（static service）：建占位主委托 / 校验出发条件 / 结算出口。
- GI：`start_mission(config)` / `end_mission(outcome)` / `has_active_mission()`；guild handler 加 "出征" action，返回 `intent {kind:"start_mission"}`（trainer 同款 command-as-data）。
- Host `_begin_mission_flow` **顺序钉死**（防呆）：① 出发确认（选带粮数，从据点 bag 扣除）→ ② **写出发档**（独立槽 `user://inkmon_l2_mission_departure.json`）→ ③ `gi.start_mission`。⚠️ 扣粮必须在写档**之前**——否则丢趟回档粮白回，出征零成本。
- 两出口落地：完成 → `end_mission("complete")` 结算（途中捕获 adopt 入 roster、奖励入 player_actor）→ 回据点视图；丢这趟（全灭 / 玩家从菜单放弃并退出）→ `load_from_slot(出发档)`——**与 load 现役路径同一条代码**。
- Presentation：出征中 save/load 菜单置灰（禁手动存档）。
- 测试：`smoke_mission_flow` —— 出发自动写档断言 / 完成结算落 actor / 丢趟后 gold·roster·bag 精确回到出发时刻。

### M1.3 趟内 DAG 生成 + 大地图 view（logic + presentation）

- 新 `ink_mon_mission_map_gen.gd`（static）：layered DAG（可调参数：层数 / 每层宽 / 出边度 2-3 / 起点—目标收束；v1 节点类型只有 `{empty, battle占位}`）+ 皮肤最简摆（节点按层直排锚 hex 坐标，走廊 = 直线 hex path）。seed 存 MissionState（复跑确定性）。
- 新 `inkmon/presentation/mission/ink_mon_mission_map_view.gd`：复用 render2d 的 iso 投影/hex 底图画法，画地形 tile + 节点 marker + 走廊 + 玩家棋子；出征中 overworld view 隐藏、mission view 显示（battle_2d_view 同款挂法）。
- 选路交互：点击**可达下一节点** → `submit(InkMonMissionMoveCommand)` → tick drain 前进 + 扣粮 + mutation signal → view 棋子沿走廊补间。
- 测试：`smoke_mission_map_gen`（DAG 硬不变量：无环 / 起点全可达 / 目标必可达 / 出边度在域内）+ UI 交互 smoke（真鼠标点节点走一步，`(real mouse input)` 约定）。

### M1.4 补给钟（logic + HUD）

- `MissionState.supplies`：每步（节点跳）扣 1（占位数值，正式数值归 lab 侧）；**粮尽后每步全队掉 HP**（扣活 roster actor 真 HP，carryover 现成）；全队 HP 归零 = 全灭 → 丢这趟出口。掉血可致全灭是设计推论（game-vision 前进压力三重的自然闭环），不留保底。
- 出征 HUD 一行：剩余粮 / 队伍 HP 概览。
- 测试：并入 `smoke_mission_flow`（粮尽 → 掉血 → 全灭 → 回出发档全链路）。

### M1.5 Phase 1 验收口径

- headless：新 test group `main/mission`（`tests/mission/test_groups.json`，launcher 自动发现）。
- 手感：编辑器跑 `InkMonMain.tscn`，实际走一趟「公会接出征 → 选路 → 抵达 → 回城」+ 一趟「粮尽全灭」。
- 完工一致性检查：对照本节逐条核（含 P1/P2 拍板无偏移）。

---

## 2. Phase 2 遭遇与捕捉 —— 纲要 + 动工前待拍板

纲要：野群生成（区域野群表 roll 个体）→ 踩野群节点开战（4v4，battle flow 复用，敌方 = 临时野生 actor，训练假人同款生命周期）→ 战后对 downed 野生个体捕捉 → 捕获暂存 MissionState → 回城结算 adopt 入库（"落袋为安"闭环）。

| # | 待拍板 | 推荐（未拍板） |
|---|---|---|
| Q2.1 | **P3 捕捉形态**（纯结算 / 气绝制 / 满注制） | **气绝制起步**：战后对 HP=0 野生个体逐只掷球看结果（有仪式感 UI），概率公式 v1 极简（基础率 × 物种稀有度）；满注制（击倒方式影响捕获率）留后，录像读参数的底座天然在 |
| Q2.2 | **战斗地图生成**（task-queue 2b 剩余半边：模板 or 其他） | **v1 模板制**：固定小棋盘尺寸 + 按区域换地形皮肤 + 随机摆 0-3 个障碍；纯生成留后 |
| Q2.3 | 遭遇触发语义 | **节点即内容**：踩野群节点必战，绕行 = 选路决策的一部分；不做暗雷 |
| Q2.4 | 野群构成 | 区域野群权重表（species × 等级带 × 只数 1-4），v1 一张 JSON |
| Q2.5 | 药的使用时机 | 战斗零干涉 ⇒ **药只在大地图节点间用**（出征菜单用药回 HP），战斗内无道具 |
| Q2.6 | 回城 HP 语义 | **回据点自动回满**（v1 最简；压力全在出征内，据点不再加惩罚） |
| Q2.7 | 全灭温和化 | **维持丢整趟**，Phase 2 试玩后再评（P1 已定，此处只是复核窗口） |

### user answer
解决你这几个问题我认为需要先明确出征玩法
> 节点地图的各个节点对应一个事件， 这个事件可能是战斗、资源、事件等。玩家在出征过程中会遇到这些节点，并根据节点类型进行相应的操作。
> 我们现在统一进入节点后的规格为： 进入一张地图， 战斗地图的随机是基于该地点环境的， 敌方队伍也是基于该区域生态的（这个可能有点复杂， 第一版可以做成就从全部可用单位中随机）。其它事件暂时未定， 其它事件的地图我的想法是， 暂时做成固定地图。

然后会带你的问题
Q2.1 捕捉形态：气绝制 即可（但如果我没有记错， 我原本的规划好像是， 战斗后留在战斗场景， 气绝的怪物在战斗场景中， 玩家扔球捕捉一次。）
Q2.2 战斗地图生成：v1 模板制：固定小棋盘尺寸 + 按区域换地形皮肤 + 随机摆 0-3 个障碍 接受， 棋盘尺寸你定
Q2.3 遭遇触发语义：上面的玩法应该回答了你了
Q2.4 野群构成：上面的玩法应该回答了你了
Q2.5 药的使用时机：战斗零干涉 ⇒ **药只在大地图节点间用**（出征菜单用药回 HP），战斗内无道具；我们原本设计也是如此， 战斗开始后， 就是纯自动玩家不可干涉的
Q2.6 回城 HP 语义：回据点自动回满（v1 最简；压力全在出征内，据点不再加惩罚） 接受
Q2.7 全灭温和化：维持丢整趟，Phase 2 试玩后再评（P1 已定，此处只是复核窗口） 接受

### Phase 2 工程切分（M2.x，2026-07-05 拍板齐备后落档，用户授权推进完整循环）

- ~~**M2.1 野群节点（logic）**~~ ✅ **已完成（2026-07-05）**：`NODE_BATTLE` 激活（中间层 0.4 概率 roll，起点/目标层恒非战）；battle 节点携 `wild` payload `[{species_id, roll_seed}...]`（1-4 只，v1 池 = 领养池 baby 物种，seed 确定；roll_seed 留给捕获 adopt 复用；等级开战时按队伍均值算不进 payload）；大地图 battle 节点红色标识（visited 退灰）；gen smoke 契约焊死（battle 仅中间层 / payload 域 / 物种在 catalog / 非战节点无 payload）。
- ~~**M2.2 踩节点开战（logic+host）**~~ ✅ **已完成（2026-07-05）**：踩 battle 节点 → `pending_battle_node_id` 必战锁（锁定期选路拒）+ `mission_battle_triggered` 上行 → Host deferred wild battle flow（对称训练战，冻结/回放观看语义同链）。战斗地图模板生成落地（Q2.2 模板制：radius-4 盘 61 格，尺寸 fable 定；皮肤按节点世界格地形 plain→grass / forest→dirt / hill→stone；0-3 个 water 障碍限 |q|≤1 中带不压布阵点；map doc 一份两端消费——逻辑 GridMapModel + 回放 baked hex map 按 map_id 换图）。敌方 = payload 建临时野生 actor（`build_wild_pack`：等级 = 出战队均值，技能 = `roll_birth_skill_slots(species, roll_seed)` 与捕获 adopt 同源）。胜 → 清锁回大地图（回放收尾按语境恢复 mission view，顺带修了误显 overworld 的既有 bug）；败（right_win）→ 看完回放确认离开 → 既有丢趟出口（`is_wild_battle` 门死训练战误触）。smoke：`smoke_wild_battle`（生成契约+锁语义+队伍契约+胜负出口）+ departure 串行追加野群战败全链。
- ~~**M2.3 战后捕捉（logic+presentation）**~~ ✅ **已完成（2026-07-05）**：胜利后留在战斗场景（必战锁延续到离场，`resolve_wild_battle_encounter` 收尾清锁+作废未掷机会；`is_wild_battle` 门死训练战误清）；`InkMonCaptureRules` 概率 = 基础率 0.5 × 稀有度（占位 1.0，lab 数据后换读数），掷点按 (mission_seed, node, slot) 确定（单次尝试下与现掷不可分辨，换可断言）；捕获暂存 `captured_pending` → 回城 `settle_complete` adopt 落袋（roll_seed 复用 ⇒ 场上个体↔入库个体技能同源，smoke 闭环焊死）。UI：回放播完 → 气绝个体拉回半透明可见 + "◎ throw" 待掷标 → 点掷 → 浮字/落标（捕获收走淡出、逃走留场躺尸）→ Leave 离场。**路由决策**：回放观看期世界泵冻结（command 不 drain），捕捉走 Host 控制面直调（对称 save/load 槽位）。附带根治出发档并行 race 残余：`smoke_mission_map_ui` 改纯函数探 seed + GI 直起 mission，出发档写手收敛到 departure smoke 独占。smoke：wild_battle 捕捉段（混合成败/去重/闭环）+ `smoke_wild_capture_ui`（真鼠标掷球，death 淡出复现）。
- ~~**M2.4 带粮选择 + 出征 HUD（host+presentation；并尾项②④⑤）**~~ ✅ **已完成（2026-07-05）**：**粮源拍板（2026-07-05 用户）= B gold 直接换粮**——理由：item 域已迁 lab canon（粮 item 需跨仓发号，A 阻塞在内容流程）且粮在设计上是出征消耗计数器非背包物品；粮 item 化留待 lab item 内容成熟后再评，不烧桥。落地：出发确认 modal（`InkMonDepartureModal`，guild 的 start_mission intent 先落 modal、Confirm 才带粮数上抛；+/- 步进 0..99、总价/余额显示、gold 不足置灰）；Host 顺序契约=①`try_pay_departure` 扣款（占位 2g/粮）→②写出发档（丢趟粮款沉没；写档失败退款——出征没开始不算沉没）→③`start_mission({supplies})`；出征 HUD（`InkMonMissionHud`：剩余粮+队伍 HP 条+放弃按钮两击确认 3 秒回弹，战斗离场/每步/掉血都刷新）。smoke：`smoke_departure_modal_ui`（真鼠标步进/gate/confirm/cancel）+ departure 串行改造（modal Confirm 真实链路、粮款沉没断言、HUD 可见与两击放弃全链）。
- ~~**M2.5 Phase 2 验收**~~ ✅ **已完成（2026-07-05，用户休息期间 fable 自主验收）**：`acceptance_full_loop.tscn` 验收 harness（**不进 launcher 组**——走 guild 写出发档，只单跑）全真实链路自动驾驶两轮通过：接出征（modal 真按钮扣粮款）→ 选路 → 踩野群真实 4v4 自动战（不作弊，败了丢趟重试）→ 回放 Skip → 留场逐只掷球（真实点击链）→ 回城 adopt 入库（一轮 roster 4→6 捕 2、一轮 4→8 捕 4）→ 再出征闭环。`inkmon/all` 31 smoke 全绿。**一致性检查抓漏并补**：Q2.6"回据点自动回满"原漏实现——已补进 `settle_complete`（回城全队 `set_current_hp(-1)`），smoke 焊死；丢趟回档不回满（回档语义=精确回到出发时刻）。**Q2.5 药的节点间使用**：依赖药 item 内容（lab canon 无药 item），登记为 Phase 3 前小项，不挡循环。


## 3. Phase 3 委托系统 —— 纲要 + 动工前待拍板

纲要：`QuestDef` 数据形状（id / type / target / reward）→ 公会委托板 UI（guild handler 扩展，占位主委托转正为数据驱动）→ 主委托目标在世界地图上揭示 → 完成判定 → 副委托槽（纯 bonus）。

| # | 待拍板 | 推荐（未拍板） |
|---|---|---|
| Q3.1 | v1 委托类型集 | 2 型起步：**抵达型**（占位转正）+ **讨伐型**（清掉目标节点野群）；捕捉型/采集型后补 |
| Q3.2 | 副委托数量上限 | 主 1 + 副 2 |
| Q3.3 | 委托板刷新 | 回城刷新 3-5 张，按进度/段位过滤 |
| Q3.4 | 奖励结构 | 金币 + 物品；勋章/段位挂晋升 NPC（Phase 5 gate 再展开） |
| Q3.5 | QuestDef 归属 | v1 godot 本地 JSON；类型稳定后进 lab canon（对称 item/species 路线） |

### user answer
Q3.1 接受
Q3.2 接受
Q3.3 接受
Q3.4 接受
Q3.5 目前只考虑 godot, 暂时我还没想到为什么让它进lab

### Phase 3 工程切分（M3.x，2026-07-05 fable 落档，对称 §2；用户授权全自主推进）

工程展开细节（拍板内推导，验收时可改）：副委托 v1 类型 = 趟内事件计数型（`hunt_count` 本趟打赢 ≥N 场野群战 / `capture_count` 本趟捕获 ≥N 只）——趟内 DAG 单目标蔓延，reach 型副委托无"顺路第二地标"可判，计数型零新机制且真 bonus；奖励物品 roll 自 item catalog（price>0 池，当前仅 item_0001，池随 lab 内容自动扩）；委托板进据点档（回城刷新、看好的单存档后不消失），`SAVE_VERSION` 3→4 旧档丢弃重开（§5.2 无迁移）。

- **M3.1 QuestDef 数据形状 + 委托板生成（logic）**：`InkMonQuestDef`（RefCounted 纯数据：quest_id / type(reach|hunt) / target_site_id / reward_gold / reward_item_id("" = 无) / 副委托 goal_count；to_dict/from_dict）+ `InkMonQuestGen`（static：回城刷新 roll 3-5 张主委托候选 + 副委托池，参数代码常量——Q3.5 不进 lab，v1 连 JSON 文件都不设，类型稳定后再议数据外置）；GI 持 `quest_board`（进档）+ 回城结算/放弃回城后刷新；世界地标 = 委托目标寻址域。
- **M3.2 出征接委托 + 完成判定（logic+host）**：`MissionState.quests`（1 主 + ≤2 副，transient）；guild handler 委托板 action（`quest:<id>` 选主委托出征，副委托自动附带 ≤2）；`start_mission(config.quest_id)` → 主委托定 target_site；**hunt 型主委托 = 趟内图目标节点生成为 battle 节点**（`InkMonMissionMapGen.generate` 加 target_is_battle 参数；抵达必战、胜即完成结算、负 = 既有丢趟）；副委托计数挂趟内事件（野群战胜 +1 / 捕获成功 +1）；`settle_complete` 逐副委托判定发奖（gold + item 入 bag）。
- **M3.3 委托板 UI + 出征 HUD 委托行（presentation）**：guild drawer 委托板卡列表（标题/类型/目标/奖励，点选即以该委托走出发确认 modal 链）；出征 HUD 加委托行（主委托标题 + 副委托进度 n/N）；hunt 型目标节点沿用 battle 红标 + 地标旗高亮现成。
- **M3.4 Phase 3 验收**：smoke（quest roll 域与确定性 / 板子进档 roundtrip / 接单出征携带 / reach·hunt 完成判定 / 副委托计数与发奖 / 板子回城刷新）+ `acceptance_full_loop` 扩接单跑单全链 + codex review + `inkmon/all` 全绿 + 一致性检查。

**M3.1-M3.4 ✅ 全部完成（2026-07-05，fable 自主推进）**：落地与切分一致；codex 两项修复（hunt 超时误完成——resolve 完成判定加 left_win 门，站把守 target 无出边只剩放弃出口属诚实败局；存档委托奖励物品 id 漂移——quest_board 纳入读档物品预检丢弃重开）；副委托双张同型去重（观感）；`SAVE_VERSION` 3→4。验收 = `acceptance_full_loop` 接单（注入 hunt 单保覆盖 + 板 roll 随机单）跑通「接单 → 出征 → 中层野群战 → 把守 target 清剿 → 捕捉 → 回城结算发奖 adopt → 再接单」多轮，`inkmon/all` 32 smoke 全绿。**偏差登记**：① Q3.3"按进度/段位过滤"——v1 委托无段位标、无段位差异内容可滤，挂 Phase 5 晋升 gate 一起展开；② Q2.5 药品节点间使用——依赖 lab canon 药 item（本地 stub 违反 adr/0003 单一来源），待 lab 侧发号后接（出征菜单用药回 HP 的 UI 位与 command 通道现成）。

## 4. Phase 4 选路体验 —— 纲要 + 待拍板（窗口远，仅登记）

纲要：节点类型扩展（事件 / 资源 / 精英 / 营地…）+ 明牌/迷雾信息设计 + 侦察手段（含个体侦察特性钩子——个体独一无二接入探索）。

- Q4.1 节点类型集与各类型内容形态（事件池怎么组织）
- Q4.2 明牌距离（几跳内节点类型可见）
- Q4.3 侦察手段集（消耗品 / 个体特性 / 高地节点？）

### user answer
基于你的问题， 这里我得先说我的想法， 然后你给建议。
首先大地图，我在思考是用俯视角hex地图更好， 还是俯视角类似文明那种地图更好；另外我想要的体验是这样的，玩家有一个视野范围的字段， 这个字段是玩家的视野范围， 玩家只能看到这个范围内的节点， 这个范围内的节点是明牌， 超出这个范围的节点是迷雾， 地图探索的感受是跟war3类似的， 它实际上已探索/未探索的战争迷雾是有去别的， 然后当前视野范围则是全部可见的。我预期这个范围是个圆形范围， 假设下一组可选节点， 有某个点不在视野范围， 那么它就是"？"， 即便是"？", 也不影响玩家选择， 玩家只是不知道它是什么事件。

这样的话， 你还有其它什么问题

### 2026-07-05 迷雾拍板落档（对话轮）

- **Q4.2 视野形态（取代原"几跳明牌"）**：war3 三态迷雾——未探索黑 / 已探索灰 / 当前视野亮；当前视野 = 以棋子为圆心的 hex 半径圆（半径 = 玩家字段 + 未来队伍个体特性加成，Q4.3 侦察入口）；圆外下一跳可选节点显示 "?"，可点不可知。与既有"迷雾两层"拍板咬合：黑 = 世界从未点亮，灰 = 持久 `revealed_cells`（地理）+ 趟内 seen（节点），亮 = 视野圆。
- **Q4.4 黑区不露 DAG 骨架 = A（war3 纯血）**：从未见过的区域节点/走廊全不显示，仅下一跳 "?" 浮出；**目标地标旗始终显示**（委托自带情报，也是带粮距离目测的锚）。
- **Q4.5 灰态记最后所见 = A**：视野扫过的节点离开视野后保留最后所见类型（war3 灰态快照）；`MissionState` 加 `seen` 集合（transient，零存档影响）。

### Phase 4 已拍板部分工程切分（M4.x，2026-07-05 fable 落档；Q4.1 节点类型集 / Q4.3 侦察手段**未拍板不动**）

- **M4.1 视野与足迹（logic）**：`InkMonPlayerActor.sight_range`（拍板"玩家视野范围字段"，v1 默认 3，进 player 持久切片，未来队伍个体特性加成的挂点）；出发/每步 reveal **视野圆内**全部世界格（取代单格点亮；hex 半径圆 = axial 距离 ≤ sight）；`MissionState.seen`（node_id → kind 快照，transient，Q4.5）出发/每步把圆内节点记快照。mission snapshot 每节点带 `visibility`（lit / seen / hidden，逻辑真相在 GI）+ `seen_kind`。
- **M4.2 大地图三态渲染（presentation）**：迷雾遮罩烘低分辨率纹理叠地形图上（对齐地形烘焙手法，每步重烘毫秒级；lit 全透 / 灰 revealed 半透黑 / 黑近全遮）；节点 lit 正常、seen 灰快照色、hidden 不画；下一跳 hidden 节点画 "?"（可点不可知，Q4.2）；走廊两端皆可见才画（黑区不露骨架，Q4.4）；目标地标旗永显、其余旗随格子可见性。
- **M4.3 验收**：smoke（圆 reveal 持久点亮 / seen 快照留存离场不丢 / snapshot 三态域正确 / "?" 节点可点走一步）+ shot 三态截图自验 + codex review + `inkmon/all` 全绿。

**M4.1-M4.3 ✅ 已完成（2026-07-05，fable 自主推进）**：落地与切分一致（`sight_range` 进玩家持久切片 / `seen_node_kinds` transient / 雾罩低分辨率烘焙叠地形 / 节点三态 + "?" + 走廊两端可见裁剪 / 目标旗黑区永显）。shot 自验：黑区纯黑无骨架、视野圆亮区、灰迹、金旗光晕正确。`inkmon/all` 33 smoke 全绿，codex 无发现。**Q4.1 节点类型集 / Q4.3 侦察手段仍未拍板，未动**——迷雾的侦察加成入口（sight_range 字段 + 未来队伍特性加成）已留好。
- **大地图观感方向（用户纠正）**：要"**完整地形图**"概念——地形是连续地貌、hex 只是叠加的网格边界（文明 6 式），**不是六边形色块拼凑**。**已落地（2026-07-05 用户拍板"现在做"）**：①生成层 per-cell 独立 roll → 双 FBM 噪声（elevation→丘陵带 / vegetation→林区，按未压扁平面坐标采样防剪切，同 seed 确定性，数据形状不变，地形入档故跨平台浮点无碍）②渲染层烘低分辨率地形图 + LINEAR 插值放大铺成完整矩形"地图纸"（超界像素 clamp 界内色，边界由格线终止表达）+ hex 细格线 + 描边框。"地貌成片"契约断言进 `smoke_world_map_data`（森林邻聚率 ≥40%，胡椒面必挂）。迷雾三态渲染本身仍归 Phase 4。

## 5. 验收导读

1. ~~§1 可直接批~~ **Phase 1 已实现（2026-07-04，用户授权开工）**：M1.1-M1.5 全部落地，`inkmon/all` 27 smoke 全绿（新增 mission 组 5 个）。验收入口 = 编辑器 F6 `InkMonMain.tscn` → 走到公会 NPC → "Set Out on Mission"。
2. **Q2.1-Q2.7 是下一批要拍的**（Phase 2 动工前）：可以一次拍完，也可以先验收 Phase 1 再拍。
3. Q3.x / Q4.x 窗口更远，本文只登记防丢。

### Phase 1 执行偏差与尾项（2026-07-04 一致性检查登记）

- **偏差① 选路 command 提前**：`InkMonMissionMoveCommand` 因依赖顺序从 M1.3 提前到 M1.2 实现（start_mission 就要走图）。无语义偏移。
- **尾项② 带粮选择 UI 未做**：v1 supplies = `InkMonMissionSetup.DEFAULT_SUPPLIES`(10) 占位，未做"出发确认选带粮数 + 从据点 bag 扣除"。⚠ "带多少粮 = 出发前构筑决策"是 game-vision 核心决策点，**Phase 2 前补**；接 bag 时严守 Host 顺序契约（扣 bag → 写出发档 → start，注释已钉在 `_begin_mission_flow`）。
- ~~**尾项③ 崩溃恢复 UI 入口**~~ **已完成（2026-07-05 验收轮）**：InkMonMain 主菜单落地（New Game / Continue 读最近档 / 出发档存在时 "Return to Departure"），配套出发档生命周期收口（Host 两出口收尾删档 ⇒ 档存在 ⇔ 上次出征未正常收尾）；`--dev-agent` 跳菜单直进保 DEV_AGENT 树路径契约；recover 在菜单层触发（未塞 Host `_ready`，smoke race 红线守住）。smoke：`smoke_main_menu`（真鼠标两段：New Game 主链 + 恢复全链），`smoke_main_router` 同步新契约。
- **尾项④ 放弃出征无 UI 按钮**：`Host.abandon_mission()` 已实现并被 smoke 焊死，大地图上的"放弃"按钮（UI 壳）未做。
- **尾项⑤ 出征 HUD 极简**：补给显示走 message 位一行；正式出征 HUD（粮/队伍 HP 条）留 Phase 2 与野群战斗一起做。
- **实现中抓出的真 bug**：`attribute_set.hp = x` 是只读投影 property，赋值被 GDScript 静默丢弃——已改走 `set_current_hp()`，坑已记 memory + 本文备案。

### Phase 1 验收反馈修正（2026-07-05）

- **世界地图"像一个世界"**（用户验收反馈：原从左到右像关卡链）：出生点改**中心 ±2 随机**、3 个目标地标按 **120° 方向扇区散布四方**（扇区内枚举合法格随机挑，margin 15° 保证两两方位角差 ≥30°，smoke 多 seed 焊死）、世界 24×16 → **28×22 且边界语义改 odd-r offset 矩形**（屏幕真矩形，不再是 axial 斜移平行四边形）、趟内 DAG 层内展开改**垂直于行进方向**（平面空间计算，南北向出征不再挤成线）、`MIN_TARGET_DISTANCE` 12→9（与新尺寸联动）。几何 helpers（`axial_to_plane` / `offset_to_axial`）挂 `InkMonWorldMapData` static。mission view 皮肤提档（深色底板 / 地形明度微扰+描边 / **全地标旗**+本趟目标高亮 / 双层走廊线）。
- **主菜单**：见上尾项③销项。
