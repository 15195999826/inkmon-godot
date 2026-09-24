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
| `DIRECT_DELIVERY_KINDS` 退役（handoff §3.2 第 4 条） | **本刀不做**，拆开单独讨论 | 激活请求是命令、grant 自投递是生命周期通知、投射物结局是回复；三者只是都「寄给某个实例」，合并进同一条路要动的是 `AbilitySet.receive_event` 这条入口与既有测试，与本刀的收益无关 |

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

不动：`DIRECT_DELIVERY_KINDS` / `AbilitySet.receive_event`（激活请求、grant 自投递照旧）、inkmon（无投射物）、dota2（无投射物）、`ProjectileEvents` 工厂（payload 不变）。

## 3. 验收（2026-09-24，本机）

| 组 | 结果 |
|---|---|
| `core/unit`（LGF 单测） | **285 / 285 ✅**，含新增 `DeliverToAbility` ×6（direct trigger 不进广播注册表、只在定向通道触发、同 kind 广播 trigger 只在广播通道触发；死掉的 owner 照收且 `is_event_responsive` 一次都没被问、filter 能拒；收件人不在了（错 id / 已 revoke / owner 已 remove）返回 false 不报错、深度归零；投递内 expire 当场 revoke 且 `abilityRevoked` 恰一次；嵌套投递到 max_depth 停）+ projectile system「旁观广播订阅者零触发」×1，原有 hit / miss / pierce 三条改走回执后照过 |
| `all-required hex/all inkmon/m1`（48 场） | **全 PASS**；hex `smoke_random_battle_golden`「unchanged over 10 seeds」、inkmon `smoke_battle_golden`「fingerprint matches」——录像形状与触发都没变，即语义不变的证明（人死弹灭在 hex 由 `owner_alive_filter` 接住、原来由 `is_event_responsive` 接住，两条路结果一致） |

- kards-tavern 第一步（公司电脑，单独 commit）：bump；`kt_basic_attack.gd` 命中 trigger `.direct()`、删 `_own_shot_precheck`、`_launch` 填 `source_ability_id`；`PieceActor.is_event_responsive` 里 `projectile_hit` 那一项已无人问（定向投递不问门），删掉；`logic/all static/all net/all` 全绿、`smoke_projectiles`（开火方全灭后弹照样落地）不变；探针 A/B 同机交替各两遍。（数字落地后回填。）
