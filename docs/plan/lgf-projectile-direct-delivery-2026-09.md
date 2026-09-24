# LGF 投射物结局定向投递（2026-09-24）

> 起因：kards-tavern「特效 / 普攻表演接入框架化」grill 会话要让**单位**持有进攻技能，照现在的四件套 `projectile_hit` 的订阅者会从每棋子一条涨到每单位一条，09-23 用 precheck 压下去的命中扇出会以十几倍规模回来。交接文档在公司电脑
> `C:\GodotProjects\kards-tavern\game\docs\handoff\2026-09-24-lgf-projectile-direct-delivery.md`（接 09-23 那份扇出交接）。本文是插件侧的决策与落地记录。
> 上一刀的记录：[lgf-projectile-perf-2026-09.md](lgf-projectile-perf-2026-09.md)。

## 0. 结论

投射物不持有技能集，只带一张**回执**（发射它的 ability 实例）；结局（命中 / 未命中 / 穿透）由投射物系统**只投给那个实例**，不再按 kind 广播；投递通道由订阅方在 trigger 上声明（`.direct()`）。订阅者数量从此不随单位数涨，命中直达 O(1)。

handoff 两个开放问题的拍板（2026-09-24，用户）：

| 问题 | 拍板 | 理由 |
|---|---|---|
| §3.3 命中的公开广播由谁发、何时发 | **③ 不再广播原始命中**。系统只定向投递；公开事实由发射技能的命中链产出（kards 的 `attack_missed` / `damage_applied`，hex 的 damage 事件），旁观者听结算事件 | 三个使用方（hex / inkmon / dota2）没有任何旁观者订阅原始命中；原始命中不是可靠的游戏事实——发射定结果的游戏（kards）对没掷中的弹也发 `projectile_hit`，命中时判定的游戏（hex）才在那一刻现判；结算时机归技能的 timeline，系统找不到「结算之后」这个广播点；若既定向又广播，同一技能对同 kind 同时有 direct 与广播 trigger 时会触发两次 |
| §3.4 收件人已死 | **由技能决定，定向投递不问 `is_event_responsive`**。`.direct()` 默认收件人死了也送达，要「人死弹灭」的技能自己加 trigger filter | 用户原话「这个行为我希望是放在技能上，而非 actor 上的」。与激活请求 / grant 自投递今天的做法一致（三种定向投递统一不问门）；不同游戏答案不同（kards 要生效、hex 现状不生效），都由各自技能表达 |
| §3.4 收件人不在了 | 静默丢弃，trace 记一笔，不断言 | 与广播今天一致（owner 出 registry 注册即清、旁观者静默收不到）；hex 图腾 / 火焰地块寿命到期走 `remove_actor`，中途消失的发射者是合法游戏状态 |
| §3.4 投递粒度 | **技能实例**（回执 = owner actor id + ability 实例 id，即 `AbilityRef` 的两个字段） | 同一 actor 挂两个同 config 实例时按 config 比对会互相接到对方的弹（kards `_own_shot_precheck` 的形状；hex 链锁闪电为此手写了 `custom_data.ability_instance_id` 路由），按实例投递把两处都收掉 |
| §3.4 同 tick 顺序 | 不变，由产出方决定；收件技能内多个 direct 组件按 config 声明顺序 | — |
| precheck 去留 | 保留，定位改成「广播订阅者的廉价拒绝」 | 「是不是我的弹」这一族全改 `.direct()`；kards 溅射 / 爆头 / 碾压这类只比 id 的旁观者仍靠它；hex 示例里迁完后没有使用方，只剩单测钉着 |
| `DIRECT_DELIVERY_KINDS` 退役（handoff §3.2 第 4 条） | **本刀不做**，拆开单独讨论；**同日第二刀用户拍板 B 并入**（§4） | 本刀理由：激活请求是命令、grant 自投递是生命周期通知、投射物结局是回复；三者只是都「寄给某个实例」，合并进同一条路要动的是 `AbilitySet.receive_event` 这条入口与既有测试，与本刀的收益无关。第二刀理由见 §4 |

## 1. 框架模型

### 1.1 回执在载体上，不在事件里

- `ProjectileActor.launch(params)` 多收一项 `source_ability_id`（发射它的 `Ability.id`），`get_source_ability_id()` 读出。`LaunchProjectileAction` 从 `ctx.ability_ref` 自动填；项目自己调 `launch` 的（kards `_launch`）照填。
- `source_actor_id` 改取 `ctx.ability_ref.owner_actor_id`（发射者 = 持有该 ability 的 actor，回执的 owner 半边）。此前取的是 ability 的 `source_actor_id`（buff 的施加者）；hex 三个发射技能都是自持主动技能，两者相同，录像不变。
- **与 handoff §3.1 的偏差**：回执不写进 hit / miss / pierce 事件 payload，而是投射物系统从载体读出后作为投递参数交给 processor。录像事件形状不变（hex random-golden / inkmon golden 位一致就是「语义没变」的证明），事件字典也不必为「收件人」定一套通用键名。
- 没回执的弹 = 编程错误（载体铁律：行为全挂施法者 ability 上）：`LaunchProjectileAction` 断言 `ctx.ability_ref` 非空；`ProjectileSystem` 产出结局时没回执只录不投并 `assert_crash`。

### 1.2 `TriggerConfig.direct()`：订阅方声明只收寄给自己的

- copy-with（与 `precheck()` 同款，共享 static 配置不原地改）。`.direct()` 的 trigger：
  1. **不进广播注册表**——`AbilityComponent.trigger_event_kinds` / `trigger_prechecks_by_kind` 跳过它，`Ability._register_post_handlers` 于是不为该 kind 注册（该 kind 若还有普通 trigger，照常注册）。
  2. **只在定向投递通道匹配**——`match_single_trigger` 比较 `trigger.direct` 与 `context.is_direct_delivery`，direct trigger 只认寄给我的，普通 trigger 只认广播来的；同一技能对同 kind 两种 trigger 并存也不会一事二触。
  3. 「收件人是不是我」不必再手写 precheck：processor 按回执只重建收件实例的 context，寄错人的根本到不了。
- precheck / filter 在 direct trigger 上照旧可用（filter 是「人死弹灭」这类死活策略的落点）。

### 1.3 `EventProcessor.deliver_to_ability(event_dict, owner_id, ability_id)`

- 不查注册表：`AbilityLifecycleContext.rebuild_for_recipient(owner_id, ability_id)` 按回执重建 context（与 `rebuild_for_handler` 同一条找法，**不问 `is_event_responsive`**，`is_direct_delivery = true`），null 即收件人不在了（owner 出 registry / 不是 BattleActor / ability 已 revoke 或过期）→ 静默丢弃，trace ≥ 1 记 `recipient_missing`。
- 收件 ability 在 handler 里 expire 了自己 → 同一趟 `revoke_ability`（与 `_make_post_handler` 收尾对称）。
- 深度保护、trace 与 post 派发同款；trace 相位标 `EventPhase.PHASE_DIRECT`（只用于 trace 标注，不传给任何死活钩子）。
- 与 09-23 handoff §4.5「不推荐加定向派发 API」不冲突：这里的地址是载体自带的事实（谁发的这颗弹），不是调用方临时挑的观众；能不能收到仍由订阅方 `.direct()` 声明，没声明的收不到。

### 1.4 `ProjectileSystem`

hit / miss / pierce 三处：`event_collector.push(event)`（录像照旧、一次）→ `deliver_to_ability(event, source_actor_id, source_ability_id)`（原来是 `process_post_event(event)`）。despawn 仍只录。旁观者要「弹到了」这个事实，由项目在自己的命中链里推自己的业务事件。

## 2. 落地（godot-addons 本 commit）

| 层 | 文件 | 改动 |
|---|---|---|
| core | `core/abilities/shared/trigger_config.gd` | `direct()` / `is_direct()`，`precheck()` copy-with 保留 direct 位 |
| core | `core/abilities/core/ability_component.gd` | `convert_triggers` 带 `direct`；`match_single_trigger` 分通道；`trigger_event_kinds` / `trigger_prechecks_by_kind` 跳过 direct |
| core | `core/abilities/core/ability_lifecycle_context.gd` | `is_direct_delivery`；`rebuild_for_recipient`；两条重建共用 `_rebuild_by_ids` |
| core | `core/events/event_processor.gd` | `deliver_to_ability` |
| core | `core/events/event_phase.gd` | `PHASE_DIRECT`（trace 标注） |
| stdlib | `stdlib/projectile/projectile_actor.gd` | `get_source_ability_id()` |
| stdlib | `stdlib/actions/launch_projectile_action.gd` | 回执；`source_actor_id` 取 owner；断言 `ability_ref` |
| stdlib | `stdlib/projectile/projectile_system.gd` | 三处结局改定向投递；没回执断言 |
| hex | `abilities/shared/skill_helpers.gd` | `projectile_hit_precheck` → `owner_alive_filter`（人死弹灭 = hex 现状，原来由 `HexBattleActor.is_event_responsive` 保证） |
| hex | `fireball.gd` / `precise_shot.gd` / `chain_lightning.gd` | 命中 trigger 改 `TriggerConfig.new(PROJECTILE_HIT_EVENT, owner_alive_filter).direct()`；链锁闪电删手写 precheck / guard（`custom_data.ability_instance_id` 仍随弹记录，`_next_chain_data` 与 scenario 读它） |
| tests | `tests/core/events/post_event_dispatch_test.gd` | 定向投递合同 ×N（见 §3） |
| tests | `tests/stdlib/projectile/projectile_system_test.gd` | 订阅改 `.direct()` + 回执；加「广播订阅者听不到」 |
| 文档 | `CLAUDE.md` | 铁律两句：定向投递由技能定死活；载体事件只投发射者不广播 |

本刀不动：`DIRECT_DELIVERY_KINDS` / `AbilitySet.receive_event`（激活请求、grant 自投递照旧；同日第二刀退役，见 §4）、inkmon（无投射物）、dota2（无投射物）、`ProjectileEvents` 工厂（payload 不变）。

## 3. 验收（2026-09-24，本机）

| 组 | 结果 |
|---|---|
| `core/unit`（LGF 单测） | **285 / 285 ✅**，含新增 `DeliverToAbility` ×6（direct trigger 不进广播注册表、只在定向通道触发、同 kind 广播 trigger 只在广播通道触发；死掉的 owner 照收且 `is_event_responsive` 一次都没被问、filter 能拒；收件人不在了（错 id / 已 revoke / owner 已 remove）返回 false 不报错、深度归零；投递内 expire 当场 revoke 且 `abilityRevoked` 恰一次；嵌套投递到 max_depth 停）+ projectile system「旁观广播订阅者零触发」×1，原有 hit / miss / pierce 三条改走回执后照过 |
| `all-required hex/all inkmon/m1`（48 场） | **全 PASS**；hex `smoke_random_battle_golden`「unchanged over 10 seeds」、inkmon `smoke_battle_golden`「fingerprint matches」——录像形状与触发都没变，即语义不变的证明（人死弹灭在 hex 由 `owner_alive_filter` 接住、原来由 `is_event_responsive` 接住，两条路结果一致） |

### 3.1 kards-tavern 第一步（2026-09-24，公司电脑；kards-tavern `23eac79`，addons `c16dab3` → `bd20c8d`）

✅ 已落地（addons 未 push，走 git bundle 送到公司电脑再 fetch）。项目侧改动：`kt_basic_attack.gd` 命中 trigger 改 `TriggerConfig.new(PROJECTILE_HIT_EVENT).direct()`、删 `_own_shot_precheck`、`_launch` 多传 ability 实例 id 并在 launch 参数填 `source_ability_id`（人死弹照落不挂 filter）；`piece_actor.gd` `is_event_responsive` 死者放行列表删 `PROJECTILE_HIT_EVENT`（命中不再经这道门，`pre_damage` / `damage_applied` 保留）；`kt_projectile_system.gd` 头注释同步。kards 全仓没有裸发的弹（`ProjectileActor.launch` 只在 `_launch` 一处，表演层的 `launch` 是另一个类）。

| 组 | 结果 |
|---|---|
| `logic/all` 9 + `static/all` 3 + `net/all` 10 | **22 场全 PASS**（含 `smoke_projectiles`、`smoke_battle_determinism`、lockstep 2 / 4 / 8）；工作区里同时有 kards 侧另一会话未提交的改动（数据表 / 碾压 / 几个 smoke），测试是连着它们一起跑的 |

探针 `perf_battle.tscn` 同机（OLD = addons `c16dab3` + `275aa86` 版三文件；NEW 先跑两遍、切 OLD 跑两遍、切回 NEW 再跑一遍；每次切版本都 `--import`）：

| 每 tick（ms） | OLD | NEW | NEW ÷ OLD |
|---|---|---|---|
| mid（17 人/方，450 tick） | 0.75 / 0.75 | 0.73 / 0.74 / 0.74 | 0.98 |
| mixed（82 人/方，414.8 tick） | 3.23 / 3.23 | 3.13 / 3.13 / 3.16 | 0.97 |
| infantry（108 人/方，450 tick） | 5.50 / 5.21 | 5.00 / 5.04 / 5.02 | 0.94（按 OLD 较低的 5.21 算 0.96） |
| infantry 分帧 step(60) 最坏（ms/step） | 458 / 461 | 439.5 / 439.6 / 439.8 | 0.96 |

- 第一步只是把 18 条 `projectile_hit` 注册上的 precheck 换成一次直达，省 3–4%，符合预期（09-23 handoff 估的扇出大头本来就已被 precheck 压掉）。真正的收益在第二步：单位持有进攻技能后订阅者约 216 条，按旧路每 tick 约 5000 次 precheck（handoff §1 估 4–6 ms/tick），按新路仍是每次命中一次直达，不随单位数涨。
- ticks/battle 三档新旧全等（450 / 414.8 / 450）：战斗走向没变，与 `smoke_battle_determinism` / lockstep 哈希一致互证。
- 三次探针日志无 `SCRIPT ERROR`。presentation 组要窗口，SSH 会话里没跑。
- kards-tavern 仓纯本地不 push（2026-09-23 拍板）。第二步（单位持有进攻技能、修订 ADR-0010 第 3 条）单独立项，不在本刀范围。

## 4. 第二刀：`DIRECT_DELIVERY_KINDS` 退役，激活请求 / grant 通知并入定向投递（2026-09-24）

> 由 §0 表里挂起的那一行起头，同日下午拍板。用户先把四件事问清——名单是 P5（09-12 `a1e8182`）加的护栏、不是本刀加的；两种事件各用在哪（激活请求 = 所有主动技能的起手，grant 通知 = 挂上即跑的 buff / 被动的启动信号）；`AbilitySet.receive_event` 在广播时代是「所有事件进 ability 的唯一入口」（旧 `_process_post_event_impl` 逐 actor 调它），P5 把 post 派发改成 processor 直调 `Ability.receive_event` 后它函数体一字未改、地位却缩成只走两种事件的窄路（命名债）；收件人字段（`AbilityActivate.ability_instance_id` / `source_id`、`AbilityGranted.actor_id` / `ability.id`）从初始提交 `615da58` 起就在事件里——然后拍板 **B：并入，删 `AbilitySet.receive_event`**。

### 4.1 拍板与理由

| 问题 | 拍板 | 理由 |
|---|---|---|
| 并不并 | **并**：激活请求、grant 通知、投射物结局全部经 `EventProcessor.deliver_to_ability(event, owner_id, ability_id)` | 用户的设计口味「不留多余入口」。事件进 ability 只剩两条路——广播按订阅（`process_post_event`）/ 定向按地址（`deliver_to_ability`）——都汇到 `Ability.receive_event`；`AbilitySet` 退回纯容器（grant / revoke / tick / 查询），不再有任何收事件的方法 |
| `AbilitySet.receive_event` 去留 | **删**，不留薄封装 | 留着就是第三条入口。hex / inkmon / dota2 三个 procedure、skill-preview、scenario harness 改调 `_get_world().event_processor.deliver_to_ability(event, actor_id, ability_instance_id)` |
| 地址走参数还是自己读事件 | **参数**（与投射物一致） | `AbilityActivate` 与 `AbilityGranted` 的收件人键名各异、投射物结局根本不带收件人；要统一就得改字段名或加重复键、两处 golden 重烤、推翻本刀「回执在载体不进事件」。事件里那份是游戏数据（失败事件 / 录像 / AI 决策在读），参数那份是地址，同值不同职 |
| grant 通知的收件范围 | 从「投给整个 set」**收窄到「只寄给刚 grant 的实例」** | 仓内没有任何监听「兄弟被 grant」的 trigger（`ABILITY_GRANTED_EVENT` 的全部 trigger 用法都是 `GRANTED_SELF`，其余是录像 / 前端读事件流）；今后要听得走业务 post 事件 |
| 「是不是叫我」的 precheck | 删：内置 `ABILITY_ACTIVATE` / `GRANTED_SELF` 变裸 `.direct()`，hex `move.gd` 手写的 `ability_activate_precheck` 同删 | 收件人由地址保证，寄错人的到不了；direct trigger 上的 precheck / filter 机制照旧可用（单测钉着） |

### 4.2 语义上真正变的三处

1. **grant 通知只寄给新实例**（上表）。
2. **instance 销毁后 actor 不能再激活技能**：以前 `receive_event` 不经 processor，instance 没了还能降级跑（context 拿不到 instance、失败事件无处可推就跳过）；现在没有 processor 可寄。生产里激活只发生在活着的 procedure tick 内。`instance_context_test` 两个测试的合同随之改成「set 上没有 processor 可寄，grant 时起飞的 execution 照常 tick、context 无 instance」与「无 collector 时 cue action 照常成功」；「激活失败事件无处可推」那条降级不再有入口。
3. **一道护栏换成文档**：以前对 `ABILITY_GRANTED_EVENT` / `ABILITY_ACTIVATE_EVENT` 写不带 `.direct()` 的 trigger，注册时 assert 当场炸；现在会静默注册、永远收不到（没人广播这两个 kind）。写进 LGF `CLAUDE.md` 铁律（内置两个 trigger 就是裸 `.direct()`）。

录像形状与事件序不变：以前非收件的 ability 只是白跑一遍匹配、没有副作用；两处 golden 位一致是验收项（§4.4）。

### 4.3 落地（godot-addons `2e9a89b` / 主仓 `<MAIN_HASH>`）

| 层 | 文件 | 改动 |
|---|---|---|
| core | `core/abilities/shared/trigger_config.gd` | `ABILITY_ACTIVATE` / `GRANTED_SELF` 改 `TriggerConfig.new(kind).direct()`，两段 id precheck 删；头注释三通道 |
| core | `core/abilities/core/ability_set.gd` | 删 `receive_event`；`grant_ability` 尾部 `owner_instance.event_processor.deliver_to_ability(granted, owner_actor_id, ability.id)`；`can_activate` 注释 |
| core | `core/events/event_processor.gd` | 删 `DIRECT_DELIVERY_KINDS` 与 `register_post_handler` / `process_post_event` / `deliver_to_ability` 三处 assert；头注释与 `deliver_to_ability` 文档改成三种寄件人 |
| core | `core/abilities/core/ability.gd` | `_register_post_handlers` 删 kind 名单跳过（direct trigger 本就不进 `trigger_event_kinds`）；三处注释 |
| core | `core/abilities/core/{ability_component, ability_lifecycle_context}.gd`、`core/abilities/components/active_use_config.gd`、`core/events/game_event.gd`、`core/entity/Actor.gd` | 注释：定向投递的入口与三种寄件人 |
| hex | `logic/abilities/active/move.gd` | 手写激活 trigger 换 `TriggerConfig.ABILITY_ACTIVATE` |
| hex | `logic/abilities/shared/skill_helpers.gd` | 删 `ability_activate_precheck`；头注释 |
| hex | `logic/hex_battle_procedure.gd`、`skill-preview/skill_preview_procedure.gd`、`logic/scenario/skill_scenario_harness.gd` | 激活请求改 `world.event_processor.deliver_to_ability(event, actor_id, ability_id)` |
| hex | `logic/actions/apply_buff_action.gd`、`tests/battle/skill_scenarios/surge_scenario.gd` | 注释 |
| hex tests | `tests/battle/{smoke_action_tags, smoke_tick_loop_removal, smoke_mid_spawn_production_replay, smoke_knockback_punch}.gd` | call site 机械改（lambda 里按 actor id 反查 instance 取 processor，不捕获 world） |
| dota2 | `core/dota2_auto_battle_procedure.gd` | `_request_basic_attack` 改 `_get_world().event_processor.deliver_to_ability(event, unit_id, ability.id)`；`logic/ability/dota2_basic_attack_ability.gd`、`logic/ai/dota2_target_selectors.gd` 注释 |
| tests | `tests/core/events/post_event_dispatch_test.gd` | 「内置两 trigger 不注册、grant 恰激活一次、激活请求按地址恰激活一次、寄错地址返回 false」；「direct trigger 的 precheck 在 match 里照样求值」改用自定义 direct trigger + `_deliver_with` 夹具 |
| tests | `tests/core/abilities/instance_context_test.gd` | 定向投递部分改 `deliver_to_ability`（双 component 分别钉定向 / 广播两通道拿到 owner instance）；两个 instance-销毁测试按 §4.2 第 2 条改合同 |
| tests | `tests/core/abilities/active_use_query_test.gd`、`tests/core/world/refcount_release_test.gd` | call site / 注释 |
| 文档 | `CLAUDE.md` | 铁律第一条：三种寄件人、`AbilitySet` 没有收事件的方法、内置两 trigger 裸 `.direct()`；第三条：定向投递在 `deliver_to_ability` 收尾 |
| 主仓 | `inkmon/logic/battle/ink_mon_battle_procedure.gd` | 一行机械改（inkmon 冻结期允许的机械改动） |
| 主仓 | `.claude/skills/enforcing-lgf/SKILL.md` | §4 三条 + 检查单一条改成 `deliver_to_ability` |

**不动**：`AbilityActivate` / `AbilityGranted` 事件字段与录像形状、`Ability.receive_event` 签名、precheck / filter 机制、投射物侧（本刀 §1–§2）。

### 4.4 验收（2026-09-24，本机，隔离 worktree：peer 刀 9 的表演上提在共享树里有未提交改动，按并行纪律搬出去跑）

| 组 | 结果 |
|---|---|
| `core/unit`（LGF 单测） | **316 / 316 ✅**（含 peer 刀 9 PL0 / PL1 已提交的 presentation pins）；重写的两例 `PostDispatch: built-in activate / granted triggers never register, each delivered once by address`（9 断言）/ `direct delivery evaluates the precheck inside the trigger match`（3 断言）与 `instance_context_test` 两条新合同全过 |
| `all-required hex/all inkmon/m1 dota2autobattle/smoke`（49 场） | **全 PASS**；hex `smoke_random_battle_golden`「unchanged over 10 seeds, every manifest config exercised」、inkmon `smoke_battle_golden`「fingerprint matches the golden replay」——录像形状与事件序不变 |

同一套改动在共享树上先跑过一次 `core/unit`：285 条全过、0 失败；launcher 报 exit=5 是 peer 未提交的 `tests/presentation/*` 五个套件重命名后 `run_tests.gd` 旧路径加载失败，与本刀无关。

### 4.5 kards-tavern 侧待办

kards `game/src/logic/battle/kt_battle_procedure.gd` 的 `_activate_basic_attack` 今天调 `AbilitySet.receive_event`（handoff §1）。bump addons 到 `2e9a89b` 时要改成 `instance.event_processor.deliver_to_ability(event, piece_id, ability.id)`，一处机械改动；kards 自己若有手写「是不是叫我」的激活 precheck 一并删（内置 `ABILITY_ACTIVATE` 已是 direct）。其余（`projectile_hit` 的 `.direct()`、回执）第一步已落地（§3.1），不受本刀影响。
