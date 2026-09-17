# LGF core 重构 §6 后续观察 — 分诊与拍板（2026-09-17）

> 来源：[`lgf-core-refactor-2026-09.md`](lgf-core-refactor-2026-09.md) §6「后续观察」38 条；队列条目 [`task-queue.md` 3c](../future/task-queue.md)。
> 本文是 3c 要求的「分诊 → 分桶 → 用户拍板」产出。**执行状态（2026-09-17 收口）：七轮全部落地——按落地顺序第 3 / 1 / 2 / 4 / 6 / 5 / 7 轮（hash 见 §5，第 6 轮见 §4；每轮两仓各一个 commit，执行方不 push、由用户手动 push）；§6 从 38 条收到 14 条，余下均为 inkmon 冻结 / 基线参考 / 信息 / 候选刀 / 环境偶发，LGF 侧无待办，task-queue 3c 关闭。**执行沿用 3c 的验收机械（钉子先行 → 新行为测试先红后绿 → 全量组 + 释放测试 → 两关自查 → 规则之家 → 不 push），一桶一轮、一轮两仓各一个 commit；范围外新发现照旧记回 §6。

## 0. 本轮约束（用户 2026-09-17 拍板）

- **inkmon 冻结**：主游戏 `inkmon/` 将整体重新设计，本轮**不做任何 inkmon 设计或行为改动**。允许的只有「机械改动」：core API 改名/删除连带的调用点改名、已死的 `super` 覆盖删除、golden 指纹重烤。§6 里纯 inkmon 的条目一律不动（见 C 桶「冻结」行）。
- **本轮核心 = LGF 框架 + 其 example（hex / dota2）设计好**。
- 桌面分诊只读代码，未逐条跑复现；每桶开工第一步仍是复核复现。

## 1. 分桶总表

| 桶 | 条数 | 条目（§6 标题关键词） |
|---|---|---|
| 🟢 A1 纯 chore，零 golden 风险 | 11 | `TimelineData._init` tags 按引用（改 `duplicate()`）· `AbilitySet.can_activate` 断言后补 return · `smoke_world_view.gd` 过期文案 · `create_instance` 撞 id 改 `assert_crash`（同对象幂等）· 战斗 tick 内结束 world 时 `tick_once` 每 actor 前判 `_finished`（hex + skill-preview；inkmon 半条冻结）· 同 kind `PreEventComponent` 注册 id 相撞（id 加序号）· 处置表外死链文档（根 `AGENTS.md` / dota2 README·CHANGELOG / `task-queue.md` / adr-0005 / lomolib spec）· `maxHp` 兜底（hex render_world / harness / smoke 夹具改 `max_hp`；inkmon render_world 半条冻结）· `smoke_summon_spike` 登记进组并改走 `configure_grid`（B-7 落地后即 `world.grid`）· stdlib grid 单测补两条 D8 合同 · `EventProcessor._create_trace` trace_level 0 时不分配 |
| 🟡 A2 chore，会动录像 / golden（先解释再重烤） | 6 | `finish()` 清 in_combat 的 `TagChanged` 漏进下一场首帧（core：`finish()` 在 `stop_recording` 前把 collector 余量录进末帧、`_start_recorder` 开录前丢弃旧事件）· `register_dynamic_dep` 不发 `_notify_changes` + 上限封顶路径缺单测 · `AbilityGranted` payload `id` / `instance_id` 双写收一个键 · action/condition/cost `TYPE` id 拼写统一 snake · `BattleProcedure` 接 `actor_removed → recorder.unregister_actor`（注意 despawn listener 已推 `ActorDestroyed`，别双推）· hex 补 tick 循环遍历中 `remove_actor` 跳 tick 一条（死者 Move execution 未 cancel 一并看） |
| 🔴 B 要拍板 | 10 | 见 §2，已全部拍板（B-8 作废） |
| ⚪ C 信息 / 已定 / 未触发 / 冻结 | 11 | 基线泄漏数字 · `Log.assert_crash` 不阻断（已是 pitfall 记忆）· `plugin.gd` 不再清 `TimelineRegistry` autoload（其他消费者手改）· dota2 无 manifest lint（长第二个 ability 再加）· `instance == null` 只剩销毁后持有一种来源 · 周期 buff grant 帧不 tick（2026-09-14 拍板保留）· core 单测刻意报错基线 · actor id 工厂派发候选刀（未排期）· **冻结**：inkmon `"intrinsic"` 裸字面量 · inkmon `smoke_battle_board_reset` 缺 weakref 断言 · inkmon 0 血 carryover 占格（原 B-8） |
| 🔍 D 偶发待定位 | 2 | `smoke_skill_validator` 退出期偶发 AV（主仓 `scripts/`，非确定性）· inkmon overworld smoke `Lambda capture freed`（**冻结**，只记） |

dota2 冷却空发那条拆成两半：预检进 B-10，trace 分配进 A1。

## 2. B 桶拍板记录

每条：**决定** / why 一句 / 改法要点 / 验收要点。

- **B-1 `AbilitySet` 批量 revoke 出口 → 加 predicate 版，删两个特例；inkmon 采纳推迟。**
  why：core 该给「按条件批量下岗、每个走正规退场」的机制，条件由游戏层写；`revoke_all` 把 inkmon 一家的策略刻进 core 动词名。
  改法：`revoke_abilities_where(predicate: Callable, reason: String = REVOKE_REASON_MANUAL) -> int`，先快照命中再逐个 `revoke_ability`（与现有 by_* 同一安全模式）；删 `revoke_abilities_by_config_id`（1 个测试调用点改 predicate 写法）与 `revoke_abilities_by_ability_tag`（零调用）。core 只留 `revoke_ability(id)` + `revoke_abilities_where`。
  推迟：inkmon `reset_battle_runtime` 换集前调它、删「按 owner 清 handler」「按 source 清装备 modifier」两处手写补救 → 归 inkmon 重设计。定位：集子清空不分来源（自己装的与别人施加的一视同仁）；「只清别人施加的」是驱散，另立动词。
- **B-2 投射物 HIT/MISS/PIERCE 派发 → stdlib `ProjectileSystem` 产出即派发。**
  why：全仓事件都是产出点「推录像通道 + 当场 `process_post_event`」，投射物是唯一由 example 层回扫 collector 的，原因是初始 API 的观众参数（P5 已删）；回扫还依赖别人每 tick flush。
  改法：`_emit_hit/miss/pierce` 推 collector 后立即 `instance.event_processor.process_post_event(event)`；删 `HexWorldGameplayInstance.broadcast_projectile_events` 与 hex procedure / skill-preview procedure / harness 三个调用点。投射物**维持 core `Actor` 载体**（不升 `BattleActor`）。
  验收：hex random-golden 预期漂移，解释 = 「命中改为命中当刻结算，与伤害同语义」（同 tick 多发弹体逐发结算；命中弹体在 handler 期间仍在注册表、处理完才删）；解释后重烤。
  规则之家新增判据：见 §3。
- **B-3 `destroy_all_instances` vs `shutdown` → 留 `shutdown`，删前者。**
  why：函数体逐字相同；`shutdown` 已带合同（幂等、拿干净注册表）；P4 后 `GameWorld` 只剩实例表，无第二语义可分。
  改法：合同放宽为「任何要干净注册表的时刻」；改 21 处调用（inkmon host 2 + inkmon smoke 18 + core world_test 1，属机械改名）。
- **B-4 `Actor.serialize()` 链 → 整条删。**
  why：TS 原版移植残留（`displayName` camelCase DTO），生产零读者；录像走 `ActorInitData` 快照、存档走项目层 `to_dict()`；通用 dump 存的正是不该进存档的 transient。
  改法：删 `Actor.serialize_base` / `BattleActor.serialize` / hex 三子类 + inkmon 两子类覆盖（机械删除）/ `ProjectileActor.serialize` / `GameplayInstance.serialize_base` + `battle_actor_test` 两用例。
  规则之家新增：「可序列化挂读者不挂类」（录像口径 / 存档口径 / 观测口径各自定义形状，没有读者的通用形状不存在）。
- **B-5 item_preview 沙盒 → 走 `GameWorld.create_instance` / `destroy_instance`。**
  why：沙盒未登记，装备 grant 按 owner 反查恒 null 静默跳过；默认种子不带 `granted_abilities` 故无现症，改种子即踩。改法：`_setup_session` 用 `create_instance`，`_clear_sandbox_world` 与退出 `destroy_instance`；不加种子。
- **B-6 `on_remove` 守卫 → `assert_crash` 报明原因 + 尽力清理，四钩子一政策。**
  why：同文件 `on_passive_disabled/enabled` 静默返回、`on_remove` 裸解引用；null 只在「actor 出注册表 / instance 已销毁后仍 revoke」出现，属合同违反，该响亮不该静默泄漏。改法：`StatModifierComponent` / `DynamicStatModifierComponent` 四个钩子统一「属性集为 null → `Log.assert_crash`（说明 owner 已不在 instance，modifier 无法清理）→ 仍清内部记录 → return」；两个静默守卫改成同样断言。debug 响亮不阻断、release 停机，与 grant 断言同口径。
- **B-7 hex 退 `UGridMap` autoload → 一条棋盘真相。**
  why：`UGridMap` 只是一个全局槽位 + 九个一行转发，无 `GridMapModel` 没有的能力；P9 已定棋盘归 world；inkmon 零引用；全局槽位让预览重置后旧板被钉住、让 `AIStrategy._is_tile_available` 绕过「world 由参数递入」纪律。
  改法：`ai_strategy` 用 `battle.grid`（`_is_tile_available` 补 `battle` 参数）；`angle_cone` static 几何函数加 `grid: GridMapModel` 参数、调用方传 `world(ctx).grid`；`facing_indicator_view` 从其渲染的 world 取；`skill_preview` 用 `_world.grid`；harness 经 world 放人；删 hex `configure_grid` 覆盖（走 stdlib 默认建板）；`ultra-grid-map` 插件去掉 autoload 自动注册、`project.godot` 删该 autoload；两个 smoke（`smoke_grid_footprint` / `smoke_summon_spike`）改走 `world.grid`。同一块板，行为不变，golden 不应漂。
- **B-8 inkmon 0 血 carryover 占格 → 作废（inkmon 冻结）。** 讨论结论留档：现状违反 glossary 6.1「死者只清格子占用」；最小修法是布阵跳过倒地单位（开局即尸体形状）；「倒地能否上场 / 有无替补」是产品题，归重设计。
- **B-9 `lgf-new-logic-skill` → 删 skill 与其设计文档。**
  why：该 skill 是扩展 hex 机制示例的开发期工具，hex 已丰富稳定，用户不再用；`.lomo-team/reference/inkmon-skill-design.md` 唯一读者是它，16 张卡对应技能 hex 已全部实现，15 段样例全部教已删 API。
  改法：删 `.claude/skills/lgf-new-logic-skill/`（无 `.agents` 镜像）与 `inkmon-skill-design.md`；SKILL.md §7.1–7.3「表演层接入清单」迁 hex `frontend/README.md`；摘引用：主仓 `CLAUDE.md` / `AGENTS.md` 三 skill 列表、`.claude/settings.local.json` 权限行、hex `README.md:18` 改指 frontend README；plan 文档里的历史提及不动。**保留** `.lomo-team/reference/` 的 `mechanics-taxonomy.md` 与三份 `*-raw.md` 研究笔记。
- **B-10 dota2 冷却期空发激活 → 请求前 `ability_set.can_activate` 预检。** 5d 不通过即 `continue`；攻击时机不变，失败事件与日志消失；controller 仍不知「冷却」。dota2 两 smoke 不受影响。

## 3. 规则之家新增（执行 B-2 / B-4 时落到 LGF `CLAUDE.md` 设计铁律）

- **实体 vs 载体**：别人能把它当「一个东西」交互（被选中、占格、有属性、挂 buff、寿命独立于那次施法）→ **实体**，spawn 成 actor 自带 ability，伤害来源是它自己（火焰地板、图腾）；只是把效果送到某处、路上不能被任何人当目标 → **载体**，留在 core `Actor`，行为全挂施法者原 ability 上，系统产出的事件是载体与 ability 之间唯一接口（投射物）。需求要求弹体自己可被交互时，换边 spawn 实体，不给载体长腿。
- **可序列化挂读者不挂类**：录像 / 存档 / 观测各自定义自己要的形状；没有读者的通用 dump 不存在。

## 4. 本轮新登记（不在本轮执行）

- **inkmon 主游戏整体重新设计**（用户 2026-09-17）：登记为 task-queue 新条目，本轮不展开、不预设。
- **投射物候选刀撤回**：原「投射物升 `BattleActor`」候选撤回；「有行为的投射物」= 系统扩展事件词汇（`projectile_miss` 已带 `reason=timeout` + 最终位置，可做到期爆炸）+ 施法者 ability 加组件。触发 = 第一个有行为投射物需求。
- B-1 的 inkmon 采纳、B-8、A1/A2 里的 inkmon 半条 → 随 inkmon 重设计。
- **执行中新记回 §6 的三条（2026-09-17，第 1 / 2 轮范围外发现；记回时未修、不并入 A2，后立第 6 轮同日全部落地，见各条 ✅）**：
  - `AbilitySet.revoke_ability` 先定下标、再 `expire()`、最后 `remove_at(index)`——on_remove 里 revoke 排在自己前面的兄弟会删错人或越界（第 1 轮发现；今日无此生产路径，`ability_set_revoke_test` 的级联用例特意让目标排在后面）。建议 A1 型 chore：expire 后按对象 `erase`，补「级联目标在前」用例，零 golden 风险。 **✅ 2026-09-17 第 6 轮已修**：`expire()` 之后按对象现找再除名，on_remove 里重入 revoke 自己不二次广播；`ability_set_revoke_test` +2 先红后绿；addons `ebf97c8` / 主仓 `7a31bdaf`，deviations FU6-1～2。
  - `u_grid_map.gd` 成了无人注册的可选脚本，仓内零引用，只剩 ultra-grid-map README 示例仍按 `UGridMap` 写（第 2 轮发现，B-7 按拍板只去掉自动注册未删）。要拍板：A 删脚本连同 README 段 / B 留作可选脚本、README 注明手动注册。 **✅ 用户 2026-09-17 拍板 A 删**：脚本连同 `.uid` 删除，README 按 `UGridMap` / 全局 `GridMap` 写的三段示例改为调用方自持 `GridMapModel`、删「可选 autoload」节；addons `ebf97c8` / 主仓 `7a31bdaf`，deviations FU6-3。
  - post 派发会在 `base_tick` 遍历 `_systems` 中途跑 handler，handler 里 `add_system`（就地 sort）会让本趟漏 / 重 tick 某个 system（第 2 轮发现；今日无此 handler）。建议 A1 型 chore：`base_tick` 遍历快照或 `add_system` 延迟到 tick 外，零 golden 风险。 **✅ 2026-09-17 第 6 轮已修**：`base_tick` 遍历系统表快照并逐个查在表（中途加入的下一趟起 tick、中途移除的本趟不再 tick），`world_test` +2 先红后绿，规则之家加「会回调用户代码的遍历走快照」；addons `ebf97c8` / 主仓 `7a31bdaf`，deviations FU6-4～6。验收：隔离 worktree（HEAD + 仅本轮 patch）`all` 130/130、core 单测 246、`hex/random-golden` A/B 10 seed 零漂移。

## 5. 执行顺序与各轮结果（2026-09-17 全部完成）

1. **B-core 小修**（一轮）：B-3、B-4、B-6、B-1（core 收口）——都是 core/stdlib 删改 + 机械改名，无 golden 风险。 ✅ 2026-09-17 完成：addons `09ac4ee` / 主仓 `df17d9a0`（B-1 `revoke_abilities_where` + 3 例、B-3 删 `destroy_all_instances` 21 处改名、B-4 删 serialize 链 + 规则之家「可序列化挂读者不挂类」、B-6 三钩子断言 + 2 例；配套 `TestFramework.expect_script_errors` + launcher 按 `EXPECTED_SCRIPT_ERRORS: n` 恰好放行；`all` 127/128，唯一 FAIL 是第 2 轮 B-2 进行中改动引起的 random-golden 漂移，隔离 worktree 复跑证明本轮不漂；记录见 deviations FU1-1～FU1-8）。
2. **B-hex**（一轮）：B-2 + B-7 + B-5 + B-10——B-2 重烤 random-golden 一次，B-7 同板不漂。 ✅ 2026-09-17 完成：addons `a66d3d9` / 主仓 `12362171`（B-2 `ProjectileSystem` 产出即派发 + stdlib 单测 4 例 + 删三个回扫调用点，random-golden 按解释重烤——10 seed 里 5 个只差 `projectile_despawn` 相对命中反应事件的位置；B-7 hex 退 `UGridMap` autoload（AI / 锥形 / 前端朝向箭头 / 预览 / harness 全部改走 world 的 grid，插件不再注册 autoload，`project.godot` 删行），B-7 前后 10 seed 事件流逐字节同；B-5 沙盒经 `create_instance` / `destroy_instance`；B-10 `_request_basic_attack` 前 `can_activate` 预检，dota2 一场「条件不满足」1220→0；规则之家加「实体 vs 载体」+「一条棋盘真相」；`-Required` 18/18、`all` 129/129 全绿；记录见 deviations FU2-1～FU2-13）。
3. **B-9 删 skill**（一轮，主仓为主）。✅ 2026-09-17 完成：addons `7182e8f`（表演层接入清单迁 hex `frontend/README.md`「新技能表演层接入清单」节 + hex README 指针）/ 主仓 `93caa156`（删 skill 与设计文档、`CLAUDE.md` / `AGENTS.md` 摘条目、pointer bump）；`-Required` 全绿。§6「`inkmon-skill-design.md` 技能作者示例整体失效」条随之关闭，已于收口时搬入 deviations「已关闭的后续观察」。
4. **A1**（一轮）。 ✅ 2026-09-17 完成：addons `df86d90` / 主仓 `2c8beba9`（十一条全部落地，两仓各一个 commit：条目 1 / 2 / 4 / 6 / 11 单测先红后绿、条目 5 新 smoke `smoke_world_end_mid_tick` 两幕先红后绿、条目 10 两条 D8 钉子、条目 3 / 7 / 8 文案与死链、条目 9 只核对；inkmon 两个半条冻结归 2e；`all` 130/130；`hex/random-golden` 零漂移（回退本轮 core 改动 A/B 复跑 10 seed sha 逐条相同）；记录见 deviations FU4-1～FU4-12）。
5. **A2**（一轮，逐条解释 golden 漂移再重烤）。 ✅ 2026-09-17 完成：addons `d15162f` / 主仓 `3c6c0b84`（六条全部落地，两仓各一个 commit：`finish()` 收尾事件录进末帧 + 开录前清 collector + `record_frame` 同帧号并帧 / `register_dynamic_dep` 发通知 + 两条封顶路径单测 / `AbilityGranted` payload 收成 `id` 一个键 / 十个 type id 改 snake / `actor_removed → unregister_actor`（只退订不推事件，释放测试加中途离场 weakref 断言）/ hex 与 skill-preview 补 tick 循环走快照 + 尸体在飞的 move / skill execution 当帧 cancel；新行为用例先红后绿，新 smoke `smoke_tick_loop_removal` 进 hex/regression；`all` 131/131，core 单测 255；两份 golden 每条改完各 dump 一次逐帧差分、独立归因后重烤——末帧 +`tag_changed(in_combat 1→0)`（hex 每 seed 6 条 / inkmon 8 条）、`ability_granted` 少 `instance_id` 键（hex 37 条 / inkmon 5 条）、seed 900083 第 57 帧 +3 条 `attribute_changed`（Break 到期重注册 Vitality / Vigor）、seed 571031 / 900211 各少 1 条已离场火焰地块的 `ability_removed`；type id 与快照遍历零漂移；胜负 / 帧数全同，inkmon 指纹 3014638374 → 3099257976；§6 六条关闭、新记三条（hex 主循环存活名单含本帧已死者 / 周期 buff 的 loop execution 冻结持有者 ATB / Stun 取消动作注释与行为不符），待拍板；记录见 deviations FU5-1～20）。
5b. **A2 新记回的三条**（第 7 轮，用户 2026-09-17 逐条拍板 A / A / A）。 ✅ 2026-09-17 完成：addons `0e5de9c` / 主仓 `3fa7578e`（① hex 主循环逐个判 `is_dead()`——尸体从死亡那一帧起不 tick / 不充能 / 不起手，skill-preview 参战者循环同形；② ATB 阻塞改白名单、只认 `active` / `action` tag——中毒 / 涌动 / 恶魔形态持有者恢复行动（拍板前实测：恶魔形态持有者整场零行动），manifest lint 守「主动技能必带 active、Move 必带 action」，skill-preview 判 idle 改问 `has_pending_execution`；③ `HexBattleCancelActiveExecutionsAction` 只改注释——眩晕不打断在飞 Move，钉子测试钉住；新行为用例先红后绿（`smoke_tick_loop_removal` +2 幕、新 smoke `smoke_action_tags` 进 hex/regression）；`all` 132/132，core 单测 255；`hex/random-golden` 每条改完各 dump 一次逐帧差分、独立归因后重烤——① 五个 seed 少掉尸体当帧的起手与在飞 keyframe（胜负 / 帧数全同），② 五个带中毒 / 涌动 / 恶魔形态的 seed 从持有者首次恢复行动那一帧起分叉（四个胜负翻转），③ 零漂移；inkmon 冻结未动、指纹 3099257976 不变；§6 三条关闭、新记一条（inkmon `_is_blocking_execution` 同形 + `ink_mon_poison_buff` 周期 timeline，随 inkmon 重设计）；记录见 deviations FU7-1～20）。
6. D 桶 AV 偶发：遇到时单跑复核，不单独排期。
