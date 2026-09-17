# LGF core 重构计划（2026-09）

> 2026-09-10 锐评定稿。范围：`addons/logic-game-framework/`（core / stdlib / hex / dota2 示例）+ 主仓 `inkmon/`（第三消费者）+ `scripts/SkillValidator.gd` + 相关文档/skill。
> 背景：通读 LGF 后的十刀锐评，用户确认三句话心智模型不变（所有能力基于 ability；action 是原子能力；timeline 是逻辑动画）。刀 9（表演管线上提）另开计划，本轮不做。
> 状态：**P1–P10 全部完成（2026-09-12）**，本轮收口；**2026-09-12 流程修订**（D10 / D11 / §2 / §5 重写，新增 P5.5 文档清场与 P10 整体审）。四条设计题（见 P10 改法 5）2026-09-13 拍板、2026-09-14 落地（§6「P10 拍板落地」行）。每阶段完成后在 §6 填 submodule / 主仓 SHA。
> 执行方式：**每阶段一个 fresh context**——用户逐阶段开新会话，或开一个总控会话按序派子 agent（两者等价，见 §5）；每阶段一个原子提交，失败即停，无人值守时不 push。本文件是仓内唯一真相（规划会话从 `~/.claude/plans/indexed-bubbling-raccoon.md` 复制而来，seed 不再更新）；P1 随主仓 commit 首次提交它。

---

## 0. Context

- 十刀来源：2026-09-10 会话锐评。Explore 实测 call site 规模比口述小：post 广播只有 12 处真实调用且全部传 `get_alive_actor_ids()`；`TimelineRegistry` 唯一承重点是 `ability_execution_instance.gd:51` 一行；`ctx.game_state_provider` 41 处非 core 读取中 37 处立刻强转。
- 目标：core 承认「带 AbilitySet 的 actor」是一等公民；事件层从广播改订阅；去全局态；grid 出 core；属性分资源/数值；事件 key 一种拼写。
- 不做：刀 9 表演管线上提（另开计划）；技能语义重设计；任何向后兼容 shim（call site 锁步改，见记忆 `feedback_no_backward_compat`）。
- 三个消费者：hex 示例（`example/hex-atb-battle`）、dota2 示例（`example/dota2-auto-battle`）、inkmon 主游戏（`inkmon/logic/{world,battle}`）。inkmon 只能依赖 LGF `core/` 与 `stdlib/`，**绝不引用 `example/`**。

## 1. 固定决策（本轮 grill 已拍板，执行时不重开）

| # | 决策 |
|---|---|
| D1 | **Post 事件订阅制**：按 Ability 注册（每个 ability 对每种 trigger kind 一条 `PostHandlerRegistration`），注册在 `Ability.apply_effects`、注销在 `remove_effects`；`process_post_event(event_dict)` 无观众参数；`abilityActivate` / `abilityGranted` 是**定向投递**kind（`DIRECT_DELIVERY_KINDS`），永不注册、传入即 `assert_crash`；派发顺序 = owner 进 registry 顺序 → ability grant 顺序 → component 顺序（复现今日广播顺序）；死者策略走 actor 钩子 `is_event_responsive(event_dict, phase) -> bool`（替代 `is_pre_event_responsive`），core 默认 true，hex 覆盖为「活着 or（post 且事件是自己的 death / 自己作为 target 的 damage）」以保住亡语与致死一击的荆棘。 |
| D2 | **`game_state_provider: Variant` → `instance: GameplayInstance`**，所有 core 签名去掉尾随 provider 参数；instance 由 id 反查（`GameWorld.get_instance_of_actor(actor_id)`，与 `Actor.get_owner_gameplay_instance()` 同一机制），**不**在 AbilitySet 上绑 WeakRef（inkmon `reset_battle_runtime` 每场重建 ability_set，绑引用会漏）。context 对象（ExecutionContext / AbilityLifecycleContext）栈作用域持强引用，永不缓存到 Ability / ExecutionInstance / Action 字段。 |
| D3 | **EventProcessor / EventCollector 归 GameplayInstance**；`GameWorld` 只留 registry、`get_actor`、`get_instance_of_actor`、`tick_all`、单一生命周期动词 `shutdown()`（删 `init` / `destroy`）；`ExecutionContext.event_collector` 变派生只读属性；recorder 走注入拿 collector；`EventProcessorConfig.DEFAULT_TRACE_LEVEL := 0`。 |
| D4 | **core 加 `BattleActor extends Actor`**（`core/entity/battle_actor.gd`）：core 不声明 `ability_set` 字段，走虚函数 `get_ability_set() -> AbilitySet` / `get_attribute_set() -> BaseGeneratedAttributeSet`（默认 null），子类用协变返回覆盖（仓内先例：`HexWorldGameplayInstance.get_actor() -> HexBattleActor`）；inkmon 接法 = **`InkMonWorldActor extends BattleActor`**，`InkMonBattleActor` 缩成薄子类。 |
| D5 | **事件 dict key 全部 snake_case**（GameEvent / ProjectileEvents / PlaybackData / RawAttributeSet 监听 dict）。仓外 JS 解析器本就未同步 v3，恢复 web 发布时一并升级。 |
| D6 | **资源型属性**：attribute config 加 `"kind": "resource"`（hp）；直接存值、clamp 到 `[minValue, maxRef 当前值]`、不进 modifier 管线；生成器出 `set_hp(v)` / `add_hp(delta)`，不再出 `set_hp_base`；`AttributeChanged` 事件契约不变。 |
| D7 | **Action 收成两类**：保留 `Action.BaseAction`（公共原语）+ `Action.SkillLocalAction`（技能私有，owner 断言）；删 `PrimitiveAction` / `FlowActionBase` / validator + allowlist / `TagAction`；`Condition extends RefCounted`；`ActiveUseConfig extends ActivateInstanceConfig`（data + builder 都继承，builder 链式方法用协变返回覆盖）；`AbilityConfig` 两个 component 列表合一。 |
| D8 | **grid 出 core**：新建 `stdlib/grid/grid_world_gameplay_instance.gd`（`GridWorldGameplayInstance`）+ `stdlib/grid/i_grid_occupant.gd`；core `WorldGameplayInstance` 删 `grid` 与三个 hex 化 signal，只留 `_get_map_config() -> Dictionary` 钩子；inkmon 基类 `grid` 固定 = 战斗棋盘，`get_battle_grid()` 是唯一战斗侧读名，`overworld_grid` 不变，**删除翻转**。 |
| D9 | **删 `TimelineRegistry` autoload**：TimelineData 引用经 config → component → `Ability.activate_new_execution_instance(timeline: TimelineData, …)` → `AbilityExecutionInstance` 直传；`tags.make_read_only()` 移到 builder `.timeline(data)`；「同 id 异引用」降级为 hex manifest lint 静态断言。 |
| D10 | **验收 = 两关 + 期末整体审**（2026-09-12 修订，替代原「三关 + 每阶段 `/code-review max`」）：第 1 关 = 钉子先行 + 新行为测试先红后绿 + 全量测试组 + 释放测试（直方图 P9 必做、P6–P8 收尾一次）；第 2 关 = 完成定义逐条核对 + 两问自查 + 精简偏离记录。每阶段**不开 agent 审查**；P10 对 P6–P9 累计 diff 做一次整体审。修订依据：P5 一轮四角度复审约 140 万 token 全为 low，P3 六轮复审后几轮只在挑自己写的注释与锚点；review 抓到的「本阶段引入且测试不覆盖」问题每阶段约 3 条、全在退场路径与遍历中改集合两类，改由钉子与两问自查覆盖。 |
| D11 | **提交 = 两仓各 commit，push 由用户收工后手动**（2026-09-12 修订）：submodule 在 `master` commit，再主仓 commit（指针 bump + inkmon/docs/tests）。无人值守链里**不自动 push**；用户检查后按 addons 先、主仓后的顺序推，顺序不可反（主仓指针不得指向未推送的 submodule commit）。 |
| D12 | **循环引用是每阶段的硬关卡**（用户此前修过多轮）。纪律：GDScript RefCounted 无循环 GC；子对象回指容器只允许 String id 或 WeakRef；context 对象（ExecutionContext / AbilityLifecycleContext / HandlerContext）栈作用域，任何 Component / Ability / Action / ExecutionInstance **不得把 context 或 instance 存进字段**；**要长期存放的 lambda 不得引用 `self` 或任何实例成员**（引用了就是 `GDScriptLambdaSelfCallable`，强持有宿主）——只能引用局部变量、参数、静态函数（`PreEventComponent.on_apply` 是范本）；`Callable(self, "m")` / `self.m` 形式的 Callable 不得跨容器边界存放。检查 = ① `tests/core/world/refcount_release_test.gd`（P1 建，逐阶段扩）② ObjectDB 泄漏直方图对比基线（见 §2）。 |

## 2. 每阶段验收协议（共用；2026-09-12 修订）

> 修订依据（P1–P5 实测）：每阶段 `/code-review max` 首审 + 多轮复审是 token 大头（P5 一轮四角度复审约 140 万、全为 low；P3 六轮复审后几轮只在挑自己写的注释与锚点），而它抓到的「本阶段引入且测试不覆盖」问题每阶段约 3 条、全落在退场路径与遍历中改集合两类。全量测试组、释放测试、一致性核对便宜且承重。于是：审查改为钉子 + 两问自查，agent 审只在 P10 做一次；文档只留规则之家；push 不再无人值守时自动做。

**全量测试组**（用 PowerShell tool 跑，两条命令分开两次调用，各设 timeout 600000，不与其他调用同批）：

```powershell
./tools/run_tests.ps1 -Required
./tools/run_tests.ps1 hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env
```

- `-Required` = `core/unit` + `hex/regression` + `dota2autobattle/regression` + `main/validator`。inkmon 组没有 required 标记，必须显式点名 `inkmon/all`。
- 失败先看 `.claude/tmp/test-runs/<scene>.log` 末尾；超时按失败处理，不抬 timeout。
- 新增 core 单元测试要**手动追加到 `addons/logic-game-framework/tests/run_tests.gd` 的 `TEST_PATHS`**（自动扫描是死代码）；零断言的测试算 FAIL。

**第 1 关：钉子版**（顺序即工序）

1. **钉子先行**：本阶段「钉子」项列出的 characterization 测试，在改任何代码之前写好、在旧代码上跑绿、单独 commit 进 submodule（`test(lgf): P<n> pins`）。钉子只钉今日行为，不钉本阶段的新行为。
2. **新行为测试先红后绿**：本阶段「测试」项的用例先写、先跑一次看它红（红的原因必须是断言而非 parse error；`TestFramework.assert_equal` 只收两参），再改代码让它绿。这一步取代旧流程的「回退修复 → 确认变红」。
3. **全量测试组**全绿。
4. **释放测试** `tests/core/world/refcount_release_test.gd` 随 `core/unit` 跑；只在引入新持引用的阶段扩 weakref（本轮只剩 P9 的 `grid`）。D12 纪律不变。
5. **泄漏直方图**：P9 必做并逐字节 diff 基线；P6–P8 只在全部修完后跑一次；P5.5 不跑。出现新类名或上升即回到步骤 3 之前修；下降了要棘轮写回基线目录。脚本：

```bash
mkdir -p .claude/tmp/leak
for s in core hex dota2 inkmon; do case $s in
  core)   scene=addons/logic-game-framework/tests/run_tests.tscn ;;
  hex)    scene=addons/logic-game-framework/example/hex-atb-battle/tests/battle/smoke_skill_scenarios.tscn ;;
  dota2)  scene=addons/logic-game-framework/example/dota2-auto-battle/tests/battle/smoke_lane_wave_engage.tscn ;;
  inkmon) scene=inkmon/tests/smoke_m1_battle.tscn ;;   # 以 tests/inkmon/test_groups.json 里的实际路径为准
esac; godot --headless --verbose --path . "$scene" > ".claude/tmp/leak/$s.txt" 2>&1
grep -o "Leaked instance: [A-Za-z0-9_]*" ".claude/tmp/leak/$s.txt" | sort | uniq -c | sort -rn > ".claude/tmp/leak/$s.hist.txt"; done
```

   基线四份直方图在 `docs/plan/lgf-core-refactor-2026-09-leak-baseline/<s>.hist.txt`。LGF 类（`GameplayInstance` / `WorldGameplayInstance` 子类 / `BattleActor` 子类 / `AbilitySet` / `Ability` / `*Component` / `AbilityExecutionInstance` / `EventProcessor` / `EventCollector` / `BattleProcedure` / `BattleRecorder` / `RecordingContext` / `*Registration`）计数只许持平或下降。非 LGF 的既有泄漏（Node / 渲染资源）不在本轮修，记 §6「后续观察」。
6. **SCRIPT ERROR**：P5.5 起 `tools/run_tests.ps1` 的 `Finish-Scene` 遇 `SCRIPT ERROR:` 判 FAIL，不再人工扫日志。P5.5 自身仍人工 grep `.claude/tmp/test-runs/*.log`，按修改时间排除 2026-09-10 之前的旧日志。core 单测的刻意报错基线：「EventProcessor not available」警告一条（`instance_context_test`）、「Event recursion depth exceeded」错误一条（`post_event_dispatch_test`），两者都不是 SCRIPT ERROR，多出来的才是问题。

**钉子变红的通则**（各阶段「钉子」项可写得更具体）：钉子红 = 今日行为变了。能证明是计划明写的行为变化 → 偏离记录写一条后重烤；不能证明 → 取「保住今日行为」的改法；两者都做不到 → BLOCKED。**inkmon `smoke_battle_golden` 除 P7 外一律不许重烤。**

**第 2 关：一致性核对**

- 对照本阶段「完成定义」逐条勾选。
- **两问自查**（对本阶段 diff 逐处回答，答案各写进偏离记录一行）：① 本阶段新增的每张表 / 注册 / 缓存，在 revoke、`remove_actor`、reset、`shutdown`、整个换掉 AbilitySet 五个出口是否都对称清掉；② 本阶段新增或改动的每个循环，遍历的是不是快照。
- **偏离记录**写入 `docs/plan/lgf-core-refactor-2026-09-deviations.md`（P5.5 建，存量 ①–㊿ 原样搬入）。格式：`- P<n>-<序号> / 改法 N / 做了什么 / 为什么`，**每条不超过 200 字**；「影响」只在会改变后续阶段时写；锚点写符号不写 `file:line`；测试数量变化只进 §6 状态行。
- 范围外发现写进 §6「后续观察」一行，不顺手修。

**第 3 关：无。** 每阶段不开 agent 审查（D10 修订）。P10 对 P6–P9 累计 diff 做一次整体审。

**规则之家维护**（取代旧「文档与 skill」段）：LGF 规则只有两个家——`addons/logic-game-framework/CLAUDE.md`（架构与铁律）与 `.claude/skills/enforcing-lgf/SKILL.md`（编码规则）。每阶段只改**规则变了的那几行**（各阶段「规则之家」项列出）。无 CHANGELOG、无 reference 增量、无 `.agents` 镜像（P5.5 起）。源码注释只讲现状；历史归 git log，commit 正文列 API 变化与 why。

**提交协议**：
1. 开工：`git -C addons status -sb` 须干净且在 master；`git -C addons pull --ff-only`（失败即 BLOCKED）。
2. submodule：`git -C addons add -A && git -C addons commit -m "refactor(lgf): P<n> <标题>"`（Conventional Commits，正文列 API 变化与 why——这是唯一的历史记录）。**不 push**。
3. 主仓：`git add addons inkmon docs scripts tests tools .claude` 等本阶段相关路径（用路径 add，不用 `-A`）→ `git commit -m "refactor: LGF P<n> <标题> (addons → <short sha>)"`，§6 状态行随这个 commit 一起。**不 push**。主仓 `.mcp.json`、`content/art/units/inkmon-units-infernace/`、`.claude-goal/` 下的既有改动**不属于本计划，不要带进 commit**。
4. 分支一律 master，不开 feature 分支。
5. push 由用户收工检查后手动执行，顺序不可反：`git -C addons push origin master`，再 `git push origin master`。

**无人值守策略**（总控模式下每个阶段 agent 遵守；用户手动开会话时同样适用）：
- 第 1 关红 → 修复最多 2 轮（一轮 = 改 + 重跑相关组）；仍红 → BLOCKED。
- BLOCKED：不 commit 半成品、不 stash、不还原，工作区原样留下；§6 状态行写 `BLOCKED <原因> <建议>`；回报总控。总控停链，不派后续阶段。
- 计划没写到的选择 → 取保住今日行为的那个，偏离记录写一条并标 `[假设]`；**绝不问人**。
- 阶段回报不超过 15 行：DONE / BLOCKED、两仓 SHA、测试数变化、偏离条数、阻塞原因。

**踩坑清单**（来自记忆，执行前读一遍）：
- submodule 存量文件**别用 `sed -i`**（整文件 CRLF↔LF 翻转出假 diff），批量替换用 `perl -i -pe`；改前 `git -C addons diff --stat` 核对行数合理。
- Bash tool 是 git-bash/POSIX；`.ps1` 走 PowerShell tool。别 `godot --script`；别 `godot … | grep`，一律 `> file 2>&1` 再读。Bash 里 `cd` 会持久化到后续调用，一律用绝对路径或用完切回 repo root。
- **并行 tool call 一个 errored 全批取消**：测试 runner、可能 0 命中的 grep、探查性 python 单独发。
- GDScript `static var` 持含 Callable 的 RefCounted → headless 退出段错误（PASS 打印后才崩）；新增静态缓存用 `static func` 线性扫。
- 引用 LGF 字段/方法前先 grep/read 真实定义；改完必跑 `.tscn` smoke。
- `attribute_set.hp = x` 无 setter 静默吞；资源写 `set_hp` / `add_hp`，stat 写 `set_*_base`。
- `Log.assert_crash` 在 debug 下只中止自己那一帧，调用方继续跑；「降级不报错」类合同要挂 `tests/log_counter.gd` 断言零错误。
- 改 `.gd` 时 `enforcing-lgf` / `gdscript-coding` skill 会自动触发，遵守其 14 条规范（类型标注、`_` 前缀未用参数、`Log.assert_crash`）。

## 3. 阶段

依赖关系：P1 独立热身；**P2 → P3 → P4 → P5 是一条链**（BattleActor 给 core 真类型 → 去 provider 参数 → 事件基础设施进 instance → post 订阅依赖 instance 级 processor 与 actor 钩子）；P6 / P7 / P8 / P9 各自独立，按爆炸半径升序排列。**2026-09-12 新增**：P5.5 文档清场排在 P6 前（清文档 + 一次性 chore，不改生产代码），P10 整体审与收口排在 P9 后。

---

### P1 减法热身：删 TimelineRegistry + 死代码 + trace 默认关（刀 10 + 小疣）

**目标**：零新概念，纯删除，建立本轮的验收/提交节奏。

**改法**：
1. 确认本文件 `docs/plan/lgf-core-refactor-2026-09.md` 在工作区（规划会话已放好、未提交，随本阶段主仓 commit 首次提交）。记忆目录已由规划会话更新（`feedback_impl_plan_consistency_check.md` 验收关卡改 `/code-review max`；新增 `project_lgf_core_refactor_2026_09.md`），无需再动；后续阶段只需在该 project 记忆里更新「当前阶段」一行。
2. TimelineData 直传（D9）：
   - `core/abilities/components/activate_instance_config.gd` + `active_use_config.gd`：删 `timeline_id` 字段；构造函数首参改 `timeline: TimelineData`（替代 String），尾参 `timeline_data` 删除；builder `.timeline(data)` 断言非空且 id 非空 → `data.tags.make_read_only()`（幂等）→ 存；`build()` 断言 timeline 非空。`timeline_id` 只作派生（`timeline_data.id`）。
   - `activate_instance_component.gd`：`var _timeline: TimelineData`，`_init` 读 `config.timeline_data` 并 `assert_crash` 非空；`serialize()` 的 `timelineId` 用 `_timeline.id`；`_activate_execution` 传 `_timeline`。`active_use_component.gd` 构父配置时传 `config.timeline_data`。
   - `core/abilities/core/ability.gd`：`activate_new_execution_instance(p_timeline: TimelineData, …)`。
   - `ability_execution_instance.gd`：`_init(p_timeline: TimelineData, …)`，`_timeline = p_timeline; timeline_id = p_timeline.id`（公开 `timeline_id` 保留，录像/事件读它）；删 registry 查找、"Timeline not found" 警告、`_timeline == null → COMPLETED` 分支；`assert_crash(p_timeline != null)`。
3. 删除：`core/timeline/timeline.gd`（+ `.uid`）；`addons/logic-game-framework/plugin.gd` 的 `AUTOLOAD_TIMELINE_REGISTRY*` 常量与对应 `_ensure_autoload` / `_remove_autoload_if_matches` 调用；主仓 `project.godot:21` autoload 行；`HexBattleAllSkills.register_all_timelines`（`example/hex-atb-battle/logic/abilities/shared/all_skills.gd:76-81`）、`InkMonAllSkills.register_all_timelines`（`inkmon/logic/battle/abilities/shared/ink_mon_all_skills.gd:22-25`）、`Dota2BasicAttackAbility.register_timelines`（`:56-58`）及 6 处生产调用（`hex_demo_world_gameplay_instance.gd:75`、`hex_random_demo_world_gameplay_instance.gd:30`、`skill_scenario_harness.gd:605`、`skill_preview.gd:2683`、`dota2_auto_battle_procedure.gd:53`、`ink_mon_world_gi.gd:724`）；`TimelineRegistry.reset()` 全部（`inkmon/host/ink_mon_world_host.gd:48,353,409`、12 个 `inkmon/tests/smoke_*.gd`、5 个 LGF 测试）；14 个 hex 测试文件里 19 处 register 调用；`tests/skill_preview_validation_test.gd` 的 `_ensure_timelines_registered` 及 6 处调用。`AbilityConfig.collect_timelines()` **保留**（lint/validator 输入，改 docstring）。
4. 校验器改读引用：`scripts/SkillValidator.gd:129-141`（`au.timeline_data != null` 则填 `result.timeline = {id, duration, tags}`；`:196` 用 `first_active.timeline_data.id`）；`example/hex-atb-battle/skill-preview/skill_preview_validation.gd:44`（`au.timeline_data.total_duration`）；`example/hex-atb-battle/tests/battle/smoke_manifest_lint.gd:72-82` 断言 ① 改为「timeline 合法且唯一」：每个 `collect_timelines()` 项 `validate()` 为空、`tags.is_read_only()`、跨 manifest 建 `id → 实例` 表，同 id 异实例即 FAIL（「timeline 必须 static 单例声明」）。
5. 小疣：删 `core/types/{activation_context,hook_context,activation_error,direction}.gd`（+ `.uid`，全仓零引用）；`core/events/event_processor_config.gd` `DEFAULT_TRACE_LEVEL := 0`（trace 基础设施保留）；`core/entity/Actor.gd` 删 `_on_spawn_callbacks` / `add_spawn_listener`（`on_spawn()` 保留为空虚钩子），`core/playback/recording_utils.gd:record_actor_lifecycle` 删 spawn 分支（它调用不存在的 `actor.to_dict()`，只因永不触发才没炸；despawn 分支保留）。
6. 陈旧注释清理：`activate_instance_config.gd:38-41,122-124`、`active_use_config.gd:42-45,139-141`、`ability_config.gd:81-83`、`all_skills.gd:1-10`、`std_timelines.gd:9`（改为「冻结在 `.timeline()`，唯一性由 manifest lint 守」）、`skill_preview.gd:2602`、`skill_preview_timeline_panel.gd:11`、`SkillValidator.gd:129-131`、`smoke_manifest_lint.gd:5-6`。
7. **泄漏基线**（在改任何代码之前）：按 §2 脚本烤四份直方图，提交到 `docs/plan/lgf-core-refactor-2026-09-leak-baseline/`；把 LGF 类当前泄漏计数（应为 0，若不为 0 先查明原因记入 §6 后续观察）写进 §6。
8. **释放测试**：新建 `addons/logic-game-framework/tests/core/world/refcount_release_test.gd`（§2 描述的两个用例；本阶段 actor 用 `pre_event_component_test.gd` 里 MockActor 的写法自带 `ability_set` + `attribute_set`，P2 换成 `BattleActor`）并登记 `TEST_PATHS`。本阶段它必须一次通过——若不通过说明现状就有环，先修（记偏离记录）再继续。

**测试**：`tests/core/timeline/timeline_test.gd` 删 `_test_register`，保留 `_test_validate`，加 `get_sorted_tags` 顺序测试；`timeline_loop_test.gd`（5 处）、`tests/core/abilities/ability_execution_instance_test.gd`（7 处）改为 `var tl := TimelineData.new(...)` 直传；`ability_test.gd:90-98` 传 `TimelineData.new("t-ability", 1.0, {})`；`activate_instance_component_test.gd:8-9,44-45` 构造首参改 TimelineData，加一条「`.timeline(data)` 后 `tags.is_read_only()`」builder 测试；`tests/skill_validator/smoke_skill_validator.gd` 可选断言 `result.timeline.id`。跑全量组。

**文档**：CHANGELOG Removed（「`TimelineRegistry` autoload 删除（breaking）… why：`.timeline(data)` 一体化后 registry 只剩空转 + 漏注册静默失效面；删后漏 timeline = build 期 crash」）+ Changed（trace 默认 0）+ Removed（core/types 四死类、spawn 监听）；LGF `docs/README.md:317` 目录树 `timeline/` 条目；LGF `AGENTS.md` / `CLAUDE.md` mermaid 节点 `TimelineRegistry → TimelineData`；主仓 `CLAUDE.md` 与 `AGENTS.md` autoload 列表、`docs/project-overview.md:46` 删 `TimelineRegistry`；`.claude/skills/enforcing-lgf/reference/abilities.md:222-247`（经 `/update-lgf-skill`）。

**行为变化**：null timeline 从「警告 + 立即完成」变 build 期 crash；tags 冻结时机从战斗开始提前到声明时；重复 id 不再运行时 crash，只由 hex lint 守；`SkillValidator.result.timeline` 对有 active_use 的技能恒有值；trace 不再累积。

**完成定义**：`grep -r TimelineRegistry` 全仓零命中（含 project.godot / plugin.gd / 文档）；core/types 目录只剩 `actor_id.gd`；泄漏基线四份已提交；释放测试绿；全量组绿；三关过；两仓已 push；§6 状态行填 SHA。

---

### P2 core 加 BattleActor（刀 3）

**目标**：core 用真类型访问 ability_set / attribute_set，三家 actor 骨架合一。

**改法**（新增均在 `addons/logic-game-framework/core/`）：
1. `core/entity/battle_actor.gd`：`class_name BattleActor extends Actor`。成员：
   - 虚 `get_ability_set() -> AbilitySet` / `get_attribute_set() -> BaseGeneratedAttributeSet`，默认 `return null`（数据型 actor）。
   - `var _is_dead := false`；`const HP_ATTRIBUTE := "hp"`；`get_current_hp() -> float`（经 `get_attribute_set().get_raw()` 的 `has_attribute` / `get_current_value`，唯一的属性名假设，可覆盖）。
   - `check_death() -> bool`（attrs 为 null → false；hp≤0 且未死 → 锁存并返回 true 一次）；`mark_dead() -> bool`（显式锁存，返回是否首次）；`is_dead()`；`is_pre_event_responsive() -> bool: return not _is_dead`（P5 改名）。
   - `_on_id_assigned()` null 安全：`get_ability_set().bind_owner(get_id())`、`get_attribute_set().actor_id = get_id()`。
   - 录像默认：`get_attribute_snapshot()`（`get_attribute_names()` 全量 `{name: current}`）、`get_ability_snapshot()`（`{instance_id, config_id}` 列表）、`get_tag_snapshot()`、`setup_recording(ctx)` = `RecordingUtils.record_attribute_changes` + `record_ability_set_changes` + `record_actor_lifecycle`，各自按 null 守卫；`serialize()` = `serialize_base()` + attribute raw + `is_dead`（位置留项目层）。
   - `static func ability_set_of(actor: Actor) -> AbilitySet`（非 BattleActor 返回 null）：替代 `IAbilitySetOwner.get_ability_set` 的 5 处 core + 4 处 example 调用；删 `core/interfaces/i_ability_set_owner.gd`。
   - 可选吸收 `team_id: int` + `set_team_id/get_team_id/_get_team_int`（hex 覆盖时先 super 再重设朝向）。
2. `core/abilities/core/ability_set.gd`：`bind_owner(actor_id)`（同步 `owner_actor_id` 与 `tag_container.owner_id`）；`tick_runtime(dt, logic_time) -> bool`（先 `tick`，再在 `tick_executions` **之前**算 blocking，最后 `tick_executions`，返回 blocking）；`has_executing_instances()`；虚 `_is_blocking_execution(ability) -> bool` 默认 true。hex `BattleAbilitySet` 与 inkmon `InkMonBattleAbilitySet` 覆盖为 `not ability.has_ability_tag("intrinsic")`。删 `HexBattleProcedure.tick_actor_ability_runtime` / `actor_has_*` 静态三件套与 `InkMonBattleProcedure` 同名副本；`SkillPreviewProcedure`、hex 中途 spawn 循环、dota2 `_has_active_execution` 改调 `ability_set.tick_runtime` / `has_executing_instances`。
3. `core/world/game_world.gd`：加 `get_instance_of_actor(actor_id) -> GameplayInstance`（`ActorId.parse` + registry，P3 用）。
4. core 鸭子摸字段改真类型：`ability.gd:263-272 _build_remove_context`、`pre_event_component.gd:88-109 _rebuild_context` 改 `actor as BattleActor` 取两个 set；`AbilityRef.resolve`、`TagAction`/`LooseTagAction._get_ability_set`、`BattleRecorder._record_existing_actor_abilities` 改 `BattleActor.ability_set_of`。**不**在 core 加 `get_alive_actor_ids` 默认实现（P5 删除该概念）。
5. 消费者：`example/hex-atb-battle/logic/hex_battle_actor.gd` 改 `extends BattleActor`，删 ~55 行重复（保留 KIND 常量、`ability_set: BattleAbilitySet`、`hex_position`、`collision_profile`、协变 `get_ability_set() -> BattleAbilitySet`、抽象 `get_attribute_set() -> HexBattleActorAttributeSet`、`_get_position`、`serialize` 补 hex_position）；`example/dota2-auto-battle/logic/actors/dota2_battle_actor.gd` 同理删 ~30 行；`hex_actor_equipment_container.gd:141` 及其 revoke 对偶改真类型。
6. inkmon（D4）：`inkmon/logic/world/ink_mon_world_actor.gd` 改 `extends BattleActor`；`inkmon/logic/battle/ink_mon_battle_actor.gd` 缩成薄子类（`ability_set: InkMonBattleAbilitySet`、协变 `get_ability_set()`、抽象 `get_attribute_set() -> InkMonUnitAttributeSet`、`serialize` 补 hex_position，约 15 行）；`sync_downed_state()` 移到 `InkMonUnitActor`（唯一调用者 `reset_battle_runtime` / `set_current_hp`，是从 HP 复活的项目规则）。玩家/NPC 仅多一个恒 false 的 `_is_dead` 与返回 null 的 getter；`get_battle_actor()`（`ink_mon_world_gi.gd:774`）、`is InkMonBattleActor`（`:760`）、`clear_actor_footprint`、`can_use_skill_on` 的收窄语义不变。
7. 小疣（可选，时间允许再做）：`Actor.gd:112-137` 的 `id/config_id/display_name/team/position` 兼容属性改为显式方法（`get_position()` 公开），`core/playback/` 10 处改调方法；example/inkmon 表演层的 `actor.position` 读取多为表演层对象，**逐行确认后**再改。

**测试**：新增 `tests/core/entity/battle_actor_test.gd`（登记 `TEST_PATHS`）：check_death 单次锁存、mark_dead、null set 的 actor 各方法不崩、`_on_id_assigned` 同步 owner id、`tick_runtime` blocking 语义（本 tick 完成的 instance 仍算 blocking）；现有 mock actor（`tag_action_test`、`no_instance_component_test`、`pre_event_component_test`、`tag_component_config_test`、`stat_modifier_component_test`、`loose_tag_action_test`）改 `extends BattleActor`。跑全量组。

**文档**：CHANGELOG Added（`BattleActor`、`AbilitySet.tick_runtime` + blocking 钩子、`GameWorld.get_instance_of_actor`）/ Removed（`IAbilitySetOwner`、三份项目 actor 副本、两份静态 tick 三件套）；`docs/README.md` 「Actor 管理架构 / IAbilitySetOwner 协议」节改为 `BattleActor` 协议，设计铁律「Ability lifecycle hook」条补一句「Actor 保持中性，BattleActor 是 opt-in 的死亡锁存」；`docs/main-game-architecture.md` World actor 层级句（`InkMonWorldActor` 现 extends `BattleActor`）；skill `reference/entity.md`、`abilities.md`、`conventions-detail.md §2`。

**行为变化**：dota2 actor 此前 `setup_recording` 返回空，现在录属性/tag/ability 变化进 `Dota2LogicFrame.events`（接受；若 frame 体积成问题再覆盖回空）；玩家/NPC 成为 `BattleActor`（数据型）。

**循环引用要点**：`BattleActor` 不持 instance；`AbilitySet.bind_owner` 只存 String id；`ability_set_of()` 是 static。释放测试的 actor 改为 `BattleActor` 子类，加 `tag_container` 的 weakref。

**完成定义**：`grep -rn '"ability_set" in\|"attribute_set" in' core/ stdlib/` 零命中；`IAbilitySetOwner` 零引用；三家 actor 基类各不再定义 `_is_dead / check_death / is_dead / get_ability_set / _on_id_assigned / setup_recording`；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

### P3 typed instance：`game_state_provider` → `instance`（刀 2）

**目标**：一种「找 instance」的方式；52 个 core 签名去掉 provider 参数。

**改法**：
1. **B1 参数流锁步（大爆炸 commit，约 55 文件）**：
   - `Condition.check(ctx, event)` / `get_fail_reason(ctx, event)`；`Cost.can_pay/pay/get_fail_reason(ctx, event)`（13 处项目覆盖：hex 5 `cooldown_system.gd`、dota2 3 `dota2_attack_cooldown.gd`、inkmon 5 `ink_mon_cooldown_system.gd`，删 `_game_state` 参数）。
   - `AbilityComponent.on_event(event, ctx) -> bool` 及 NoInstance / ActivateInstance / ActiveUse 覆盖与私有 helper。
   - `Ability.receive_event(event, ctx)`、`tick_executions(dt)`、`activate_new_execution_instance(timeline, tag_actions, start_actions, end_actions, trigger_event)`。
   - `AbilityExecutionInstance.tick(dt)`、`fire_sync_actions(actions, tag)`、`_build_execution_context(tag)`。
   - `AbilitySet.receive_event(event)`、`tick_executions(dt)`、`grant_ability(ability)`（**恒自广播 `AbilityGranted`**；今日静默的 ~30 处两参调用去掉参数；若 `hex/skills` scenario 出现差异，退路 `grant_ability(ability, broadcast_granted := true)`）。
   - `EventProcessor.process_pre_event(event) -> MutableEvent`、`process_post_event(event, actor_ids)`（观众参数 P5 再删）；`HandlerContext` 删 `game_state`（三参构造）。
   - `AbilityLifecycleContext._init(owner_actor_id, attribute_set, ability, ability_set, event_processor, instance: GameplayInstance)`（3 处 core + 17 处测试构造）。填充点：`AbilitySet._create_lifecycle_context`（`get_owner_instance()` = `GameWorld.get_instance_of_actor(owner_actor_id)`）、`Ability._build_remove_context` 与 `PreEventComponent._rebuild_context`（`actor.get_owner_gameplay_instance()`）、`AbilityExecutionInstance._build_execution_context`（`_ability_ref.owner_actor_id` 反查）、`NoInstanceComponent`（`context.instance`，含 lifecycle actions，此前 null）。找不到 owner（孤立测试、`AbilityRef.new("a1","c1")`）→ `instance == null`，需要它的 action `Log.assert_crash`。
   - 删 `core/interfaces/i_game_state_provider.gd`；`TagAction._get_logic_time` → `ctx.instance.get_logic_time()`（null 则 0.0；删除挂钟 fallback）。
   - `CharacterActor.equip_abilities()` / `replace_skill_ability(cfg)` / `InkMonUnitActor.equip_abilities()` 删 provider 参数（调用者：hex demo GI、harness、skill_preview、`InkMonWorldGI._prepare_actor_for_battle`）。
2. **B2 改名/定型（约 45 文件）**：`ExecutionContext.game_state_provider: Variant` → `instance: GameplayInstance`；`create(chain, instance, ability_ref=null, execution_info=null, execution_state={})`（collector 参数 P4 再删）；41 处 `ctx.game_state_provider` 机械改 `ctx.instance`（GDScript 4 允许 `var battle: HexWorldGameplayInstance = ctx.instance` 从基类隐式下转，运行时不匹配即硬错；**先编译一处确认**）。新代码约定：每项目一个 `world(ctx) -> <ConcreteGI>` helper（`as` + `Log.assert_crash`）：`HexBattleGameStateUtils.world(ctx)`、dota2 / inkmon 对偶。`target_selector.gd` / `execution_context.gd` 文档注释同步。

**引用图不成环的证明（写进 CHANGELOG why）**：强边只向下：`GameWorld._instances → GameplayInstance → {_actors → BattleActor → {typed ability_set → AbilitySet → {_abilities → Ability → {_components, _execution_instances}, tag_container}, typed attribute_set}, _systems, event_processor, event_collector, _active_battle → BattleProcedure → _recorder}`；回边只有 String id（`Actor._instance_id`、`AbilitySet/Ability.owner_actor_id`）与 WeakRef（`AbilityComponent._ability_ref`、`System._instance_ref`、`BattleProcedure._world`）；context 对象栈作用域。两条纪律写进文档：`execution_state` 不许放 owning Object；`RecordingContext._recorder` 强引用由 `stop_recording` 打断（既有）。

**测试**：更新 8 个构造 `AbilityLifecycleContext` / `ExecutionContext` 的 core 测试；`flow_action_test` 等传 `GameplayInstance.new("t")` 代替 null provider。跑全量组，重点看 `hex/skills`（grant 广播变化）。

**文档**：CHANGELOG Changed（breaking：`ExecutionContext.instance`、52 签名去参、`grant_ability` 恒广播）/ Removed（`IGameStateProvider`、`HandlerContext.game_state`、挂钟 fallback）；`docs/README.md` §4「GameStateProvider 最佳实践」整节改写为「GameplayInstance 上下文」（`ctx.instance` + `world(ctx)` 约定），§5 代码样例，设计铁律「子对象回指 container」条改为「instance 经 id 反查，context 栈作用域永不缓存」；`docs/reference/action-architecture.md` §0.6（lifecycle action 现可读 `ctx.instance`，仍不许 push 事件）、`action-system.md:194`、`target-selector.md:102-164`；skill `SKILL.md §4/§7`、`reference/{abilities,events,conventions-detail,actions,stdlib}.md`。

**行为变化**：`grant_ability` 恒广播（现有静默调用者无 `GRANTED_SELF`，不可观测）；lifecycle actions 拿到真 instance；挂钟 fallback 消失（更确定）。

**循环引用要点**：本阶段最容易出环——`AbilityLifecycleContext.instance` / `ExecutionContext.instance` 是强引用，**只能活在调用栈上**。审查清单：① 任何 `AbilityComponent` 子类（含 stdlib `StatModifierComponent` / `DynamicStatModifierComponent` / `TimeDurationComponent`、hex `HexBattleShieldComponent`）的 `on_apply` / `on_event` 不得把 `context` 或 `context.instance` 存进字段；② `AbilityExecutionInstance` 不得缓存 `_build_execution_context` 的结果；③ Action 字段写入被 `_verify_unchanged` 抓，但 `execution_state` dict 不受检——不许放 instance / actor；④ `HandlerContext` 不携带 instance（只有 id）。释放测试加 weakref：一个由 `NoInstanceComponent` 执行过的 `ExecutionContext`（在 action 内经 weakref 捕出）与一个 `AbilityLifecycleContext`，断言调用返回后均已释放。

**完成定义**：`grep -rn "game_state_provider\|game_state: Variant\|_game_state" addons/logic-game-framework inkmon scripts --include=*.gd` 零命中；释放测试绿（含 context 释放断言）、直方图不增；全量组绿；三关；push；§6。

---

### P4 EventProcessor / EventCollector 归 GameplayInstance（刀 4）

**目标**：去掉 `GameWorld` 上的事件全局态；`GameWorld` 退成电话簿。

**改法**：
1. **C1 所有权迁移（约 50 文件）**：
   - `GameplayInstance._init(id_value := "", processor_config: EventProcessorConfig = null)`；`var event_processor: EventProcessor`、`var event_collector: EventCollector`；`_cleanup_pre_event_handlers` 用自己的 processor。
   - `ExecutionContext.event_collector` 改**派生只读属性**（`get: return instance.event_collector if instance != null else null`，无存储字段），`create()` 删 collector 参数；37 处 `ctx.event_collector` / `ctx.push_event` 零改动。
   - core 切换点：`gameplay_instance.gd:76`（自身字段）；`ability_set.gd:28 get_event_processor`（`get_owner_instance().event_processor`，null 安全；`_create_lifecycle_context` 不调它，改用参数里已反查的 `owner_instance.event_processor`——否则 P3 ⑰ 的「每次投递只反查一次」会退化成逐 ability 反查）；`ability_execution_instance.gd:231`、`no_instance_component.gd:88`（P3 已把两处 ExecutionContext 构造合并进 `_execute_actions`，删 collector 实参即可）；`active_use_component.gd:135`（`ctx.instance.event_collector`，null 守卫）；`pre_event_component.gd:108`（用 `_rebuild_context` 手上已反查的 `owner_instance.event_processor`，不再经 actor 二次反查）；（以上行号按 P3 之后刷新）`BattleProcedure.record_current_frame_events()` 里的 flush（改 `_get_world().event_collector.flush()`）；recorder 改注入：`BattleRecorder._init(config, event_collector)`（`BattleProcedure.start()` 传 `_get_world().event_collector`）、`RecordingContext._init(actor_id, recorder, collector)`（属性变化高频路径不走 registry 查找）。
   - stdlib：`ProjectileSystem` 已是注入式；10 处构造（hex demo GI:59、skill_preview:2681、harness:596、7 个 skill-preview smoke）改传 `world.event_collector`。
   - example / inkmon：`HexWorldGameplayInstance.broadcast_projectile_events`（自身字段）；`HexBattleProcedure._start_actor_action` 与 `SkillPreviewProcedure._fire_due_keyframes` 里的 `face_actor_for_active_event`（`world.event_collector`）；hex damage/heal/poison/regenerate/strike/`hex_battle_damage_utils` 与 inkmon damage/heal/`ink_mon_battle_damage_utils` 的 `GameWorld.event_processor` → `battle.event_processor`；dota2 procedure ×4 / wave spawner / creep controller → `world.event_collector`；dota2 damage action → `world.event_processor`；`ink_mon_world_gi.gd:898`（自身）；harness:217/367；`smoke_summon_spike.gd:169/178`；`smoke_battle_math.gd:116`（`gi.event_processor`）。（本条与上一条的行号、计数按 P3 之后刷新）
   - `pre_event_component_test` 改为 `MockInstance` 传 `EventProcessorConfig.new(10, 2)` 给 `super._init`，调 `env.instance.event_processor.process_pre_event(event)`。
2. **C2 生命周期（约 60 文件，纯机械）**：`GameWorld` 删 `init / destroy / initialize / _ensure_initialized / _ready / _initialized / event_processor / event_collector`，保留 `_instances、create_instance、get_instance_by_id、get_instances_by_type、destroy_instance、destroy_all_instances、tick_all、get_instance_count、has_running_instances、get_debug_info、get_actor、get_instance_of_actor、shutdown()`（幂等：end all + clear）；51 处 `GameWorld.init(...)` 与 43 处 `destroy()` 改 `shutdown()`（测试两端各一次）；inkmon 夹具收敛：`InkMonWorldGI._init` 传 `EventProcessorConfig.new(20, 0)` 给 `super._init`（max_depth 20 是世界属性），`ink_mon_world_host.gd:47` 与 13 个 inkmon smoke 去掉参数。

**测试**：`tests/core/events/event_processor_test.gd`、`pre_event_component_test.gd` 改 instance 级；`tests/core/world/world_test.gd` 覆盖 `shutdown` 幂等与 instance 自持 processor；跑全量组。

**文档**：CHANGELOG Changed（breaking：processor/collector 归 instance、handler 按 instance 隔离、recorder 注入、`GameWorld.init/destroy → shutdown`、trace 默认 0）；`docs/README.md` §5 样例、「World owns Battle (c)」录像句（「统一汇入 world 的 collector」）、设计铁律「录像顺序」条；LGF `AGENTS.md`/`CLAUDE.md` mermaid（Collector/Processor 挂 GameplayInstance）；skill `reference/{entity,events}.md`、`conventions-detail.md §7`。

**行为变化**：pre handler 按 instance 隔离（hex demo 与 skill-preview 共存时不再串表）；owner 未 `add_actor` 就 grant `PreEventConfig` 会打既有「EventProcessor not available」警告而非静默全局注册（生产路径全在注册后 grant）。

**循环引用要点**：新的强边 `GameplayInstance → EventProcessor → PreHandlerRegistration → lambda`、`GameplayInstance → BattleProcedure → BattleRecorder → EventCollector`、`RecordingContext → BattleRecorder`（既有）。必须保证：`EventProcessor` **不**持 instance 强引用（若需要则 `_instance_ref: WeakRef`）；`register_pre_handler` 返回的注销闭包引用 `_pre_handlers` 即捕获 processor 自身——它被 `PreEventComponent._unregister` 强持有，方向 component → processor 与 instance → processor 同向，不成环，但 processor 决不能反向持 Ability / Component；`EventCollector` 只存 dict，不得引用发射者。释放测试第二用例此时必须覆盖 recorder 注入路径（`BattleRecorder` / `RecordingContext` / 每个 actor 的 unsubscribes 闭包）并断言 `shutdown()` 后 instance 级 processor / collector 释放。procedure 侧的回边同样要守（P3 复审查明）：procedure 子类回指 world 只经 `_get_world()`（基类 `_world` 是 WeakRef，子类协变覆盖收窄），不存 world 字段；procedure 持有的对象（基类 `_recorder`、hex `logger`、dota2 `movement_adapter` 与 `_controllers`）不存 world / procedure 引用，要用 world 由 procedure 当调用参数传入（如 `decide_if_needed(world, tick)`），静态 helper（`Dota2WaveSpawner` / `Dota2TargetingSystem`）同样只经参数拿——C1 新增的 `world.event_collector` 读点：procedure 内用 `_get_world()` 取的局部变量，controller / spawner 用已有的 `world` 形参，不为此加字段；释放用例补三种形状：真实 procedure 子类、直接 `finish()`、开着录像的战斗中途 `shutdown()`（须含非参战的被录 actor——registry 常驻者或中途 spawn——weakref 挂在全部被录 actor 上；这一种在「world 拥有战斗终止」落地前是预期泄漏，见 §6 后续观察）。

**完成定义**：`grep -rn "GameWorld.event_\|GameWorld.init(\|GameWorld.destroy(" addons/logic-game-framework inkmon scripts --include=*.gd` 零命中；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

### P5 Post 事件订阅制（刀 1）

**目标**：`process_post_event(event_dict)` 无观众；被动 = 字面意义的订阅；死者策略归项目钩子。

**改法**（按 Plan agent 设计，核心文件 `core/events/event_processor.gd`、`core/abilities/core/ability.gd`、`core/entity/Actor.gd`）：
1. **核心翻转（一步内完成，hex/dota2/inkmon 仍能编译）**：
   - `AbilityComponent.get_post_event_kinds() -> Array[String]` 虚函数默认 `[]`；`NoInstanceComponent` / `ActivateInstanceComponent`（含 ActiveUse）返回 `_triggers` 的去重 `eventKind`。
   - 新建 `core/events/post_handler_registration.gd`（镜像 `PreHandlerRegistration`）：`id`（`"%s_post_%s" % [ability_id, kind]`）、`event_kind`、`owner_id`、`ability_id`、`config_id`、`handler: Callable`（`func(event_dict, ctx: HandlerContext) -> bool`，true = 至少一个 component 触发，仅 trace 用）、`handler_name`，processor 赋 `owner_seq`、`seq`。**无 filter 字段**：`TriggerConfig.filter` 仍在 `AbilityComponent.match_triggers` 内评估。
   - `HandlerContext` 加 `event_processor: EventProcessor`（派发时设置）。
   - `AbilityLifecycleContext.rebuild_for_handler(owner_id, ability_id, event_dict, phase) -> AbilityLifecycleContext` 静态方法：actor 反查 → `actor.is_event_responsive(event_dict, phase)` → `BattleActor.ability_set_of` → `find_ability_by_id` → attribute set；任一失败返回 null。`PreEventComponent._rebuild_context` 删除改调它。
   - `Ability`：`var _post_unregisters: Array[Callable]`；`apply_effects` 在 components `on_apply` 之后：kinds = ∪ `get_post_event_kinds()` − `EventProcessor.DIRECT_DELIVERY_KINDS`；`context.event_processor == null` 则静默跳过（孤立单测）；每 kind 注册一个只捕获 `owner_id: String`、`ability_id: String` 的 lambda：`rebuild_for_handler(...)` → null 返回 false → 否则 `return ability.receive_event(event_dict, lifecycle_ctx)`。`remove_effects` 先逐个注销再清 callback 列表。`receive_event(...) -> bool` 改返回 `not triggered_components.is_empty()`。
   - `EventProcessor`：`const DIRECT_DELIVERY_KINDS: Array[String] = [ABILITY_ACTIVATE_EVENT, ABILITY_GRANTED_EVENT]`；`register_post_handler(reg) -> Callable`（`seq = _next_seq++`，`owner_seq = _owner_seq.get(owner_id, INT64_MAX)`，按 `(owner_seq, seq)` 有序插入 `_post_handlers[kind]`，返回按 id 幂等注销）；`note_actor_added(actor_id)`（`GameplayInstance.add_actor` 调用，分配 `_owner_seq`）；`process_post_event(event_dict)`：传入 DIRECT kind 即 `assert_crash`；深度守卫同今日；遍历 `_post_handlers[kind]` 的**快照**（`duplicate()`），每条建 `HandlerContext` + `event_processor = self` 后 `call_handler`；trace_level ≥ 2 记 `{handlerId, handlerName, triggered, executionTime}`；`remove_handlers_by_ability_id` / `remove_handlers_by_owner_id` 同时清两张表（后者并清 `_owner_seq`）；新 `remove_all_handlers()` 供 `GameplayInstance.end()`（`_cleanup_pre_event_handlers` 改名 `_cleanup_event_handlers`）；`GameplayInstance.remove_actor` 调 `remove_handlers_by_owner_id`。删 `process_post_event_to_related`。旧三参 `process_post_event(event, actor_ids)` 本步保留为**忽略 actor_ids 的 shim**（不能再遍历 actor，否则双投递）。
   - `Actor.is_event_responsive(event_dict: Dictionary, phase: String) -> bool` 默认 true（本步先加，旧 `is_pre_event_responsive` 与项目覆盖暂留一步）。
   - `AbilitySet._process_abilities` 遍历 `_abilities.duplicate()`（中途 revoke 不跳元素）。
   - `AbilitySet.receive_event(event)` 保留为**定向投递**路径（5 处 activation + `grant_ability` 的 GRANTED 广播）。双投递由 DIRECT kind 永不注册结构性保证。
2. **hex**：`HexBattleActor.is_event_responsive`：`not _is_dead`，否则 `phase == PHASE_POST and ((kind == "death" and actor_id == id) or (kind == "damage" and target_actor_id == id))`；护盾破裂改**立即** `ability_set.revoke_ability(shield_ability_id, REVOKE_REASON_EXPIRED, EXPIRE_REASON_BROKEN)`（今日靠广播顺带 sweep，改订阅后失去 sweep）；删 `alive_actor_ids` 参数：`HexBattleDamageUtils.apply_damage(damage_event, ctx, battle)`、`broadcast_post_damage(dict, battle)` 及调用者（`damage_action.gd:139/201/211`、`reflect_damage_action.gd:55`、`poison_tick_action.gd:42`、`push_action.gd:244`、`totem_attack.gd:85-88`、`fire_tile_pulse.gd:63`）、`heal_action.gd:86/122`、`regenerate_action.gd:88-93`、`strike.gd:80-82`（删 36-39 的「两套约定」注释）、`hex_world_gameplay_instance.gd:184-192`（`broadcast_projectile_events` 逐条 `process_post_event(event)`）；删 `get_alive_actor_ids`（`:109`）；`smoke_summon_spike.gd:82` 改查 `get_alive_actors()` 的 id。
3. **dota2**：`Dota2BattleActor.is_event_responsive` = `not _is_dead`；`dota2_damage_action.gd:40/79`；删 `dota2_world_gameplay_instance.gd:46 get_alive_actor_ids`。
4. **inkmon**：`InkMonBattleActor.is_event_responsive` = `not _is_dead`；`InkMonUnitActor.reset_battle_runtime`（`ink_mon_unit_actor.gd:279`）换 ability_set 前先 `event_processor.remove_handlers_by_owner_id(get_id())`（今日 pre handler 已按场累积幽灵注册）；`ink_mon_battle_damage_utils.gd`（`apply_damage(damage_event, ctx, battle)`、`broadcast_post_damage(dict, battle)`）、`ink_mon_damage_action.gd:28/64/66`、`ink_mon_heal_action.gd:19/33`；删 `ink_mon_world_gi.gd:789 get_alive_actor_ids`（保留 `get_alive_actors`）。`smoke_battle_golden` 指纹**必须不变**（inkmon 无广播型监听者）。
5. **核心清理**：删 shim 签名、`is_pre_event_responsive`（Actor + 3 覆盖 + PreEventComponent 引用）；文档。

**测试**：新增 `tests/core/events/post_event_dispatch_test.gd`（登记 `TEST_PATHS`，沿用 `pre_event_component_test` 的自建 instance + mock actor 环境）：同 kind 两 component 只注册一条且 action 跑一次；DIRECT kind 永不注册；`ability_set.receive_event` 激活恰一次；`grant_ability` GRANTED_SELF 恰一次；派发顺序 = registry 顺序再 grant 顺序（A、A、B）；revoke / expire sweep 注销；`remove_actor` / `end()` 清表；`is_event_responsive` false 跳过、own-death 豁免通过；disabled ability 跳过；嵌套派发到 max_depth 停止不挂；`abilityTriggered` 监听者带 component 名触发一次。更新 `event_processor_test.gd`、`no_instance_component_test.gd`（经 processor 派发 `{"kind":"test_kind"}` 跑 action）、`activate_instance_component_test.gd`（`get_post_event_kinds() == ["hit","heal"]`）、`pre_event_component_test.gd`（死 owner 跳过）。跑全量组，额外盯 `hex/skills`、`hex/random-frontend-20`、`inkmon/m1`。

**文档**：`docs/README.md:656` 铁律条改为「钩子 = `is_event_responsive(event_dict, phase)`；观众由注册决定，死活由 actor 决定」并删 `alive_actor_ids` 时序契约措辞，修 `:158/:164/:233/:257/:261` 样例；LGF `CLAUDE.md`/`AGENTS.md` 「Broadcast to all alive Actors」→「Dispatch to registered ability handlers, gated by `Actor.is_event_responsive`」；hex `docs/reference/damage-pipeline.md:51-54`、`hex_battle_damage_utils.gd:6-8`、`view-logic-reconciliation.md:135`；skill `reference/events.md:27-29`（+ `PostHandlerRegistration` / `HandlerContext.event_processor`）、`entity.md:25`、`abilities.md:122`、`example-app-game-logic.md:208`；CHANGELOG Changed（「Post 事件订阅派发…why：12 处调用手搬陈旧观众名单且两套约定并存；expiry sweep 不再搭广播便车」）。

**行为变化（逐条核对）**：① 广播不再兼任过期 sweep → hex 护盾破裂改即时 revoke，`abilityRemoved(shield)` 在同帧提前到 `shield_broken` 之后；② EnvironmentActor 成为合法监听者（无环境 ability 监听广播 kind，不可观测）；③ 派发中新注册的 handler 收不到进行中的事件；④ `remove_actor` 同时清 pre + post handler；⑤ 签名变化与删除项；⑥ inkmon `reset_battle_runtime` 清幽灵注册；⑦ 打尸体的反伤 damage 现在到达尸体自身监听（thorn 拒绝 `is_reflected`，不可观测）。

**循环引用要点（本阶段第一风险）**：post handler 的 lambda 在 `Ability.apply_effects` 里创建——**它不得引用 `self`、`_components`、`id` 等任何成员**，只能捕获局部 `owner_id: String` / `ability_id: String`，通过 `AbilityLifecycleContext.rebuild_for_handler(...)` 拿回 ability 再调 `lifecycle_ctx.ability.receive_event(...)`；否则形成 `Ability → _post_unregisters 闭包 → EventProcessor → registration → lambda → Ability` 的真环。做法：把建 lambda 的代码放进一个 `static func _make_post_handler(owner_id, ability_id) -> Callable`，静态上下文里根本没有 `self` 可捕获（与 `PreEventComponent._rebuild_context` 同思路）。`_post_unregisters` 里的闭包捕获 processor 自身可接受（同 P4 分析）。释放测试加：注册过 post handler 的 ability 在 `revoke_ability` 后 weakref 为 null；`remove_actor` 后其 pre/post registration 与 lambda 均释放（对 registration 取 weakref）；`end()` 后 processor 两张表为空。

**完成定义**：`grep -rn "get_alive_actor_ids\|is_pre_event_responsive\|process_post_event_to_related" --include=*.gd` 全仓零命中；`process_post_event(` 全部单参；hex 70 个 scenario、`smoke_battle_golden` 指纹不变（若变必须先解释再重烤）；释放测试绿（含 registration 释放断言）、直方图不增；全量组绿；三关；push；§6。

---

### P5.5 文档清场（2026-09-12 新增）

**目标**：只保留 AI 会话需要、且从代码 / 测试 / git 推不出来的文档——规则、铁律、决策的 why。API 罗列、用法样例、历史一律删。顺带落地几件一次性 chore，让 P6–P9 零杂活。不改任何 `.gd` 生产代码。

**判据**：谁在读？未来 AI 会话不读的 → 删；读但内容从代码推得出 → 删；规则与 why → 并入规则之家（addon `CLAUDE.md` / `enforcing-lgf/SKILL.md`）。**不在下表的文件一律不动。**

**改法**（处置表，逐行落地）：

| 文件 | 处置 |
|---|---|
| addon `CHANGELOG.md`、hex `CHANGELOG.md` | 删。addon `CLAUDE.md` 「源代码注释边界」两处「历史归 CHANGELOG」改为「历史归 git log；commit 正文列 API 变化与 why」 |
| addon `CLAUDE.md` / `AGENTS.md` | `CLAUDE.md` 为真相；`AGENTS.md` 改成一行指向 `CLAUDE.md`（两份已漂移：AGENTS 缺 BattleActor 与 `can_activate` 段，以 CLAUDE.md 为准） |
| addon `docs/README.md` | 拆：「设计铁律」「已知债务」「明确不做」类段落并入 `CLAUDE.md`（去重、只讲现状、不搬代码样例、已过期的 API 名不搬）；其余段（快速开始、示例、流程图、目录树、序列化约定样例）删；文件整个删除，`CLAUDE.md` 「更多文档」节相应改 |
| addon `docs/reference/` 三篇 | 删。action-architecture 的「目录规则」（公共 action 目录只放通用原语；技能私有一律内嵌 `_XxxAction extends SkillLocalAction`，不得 `class_name`）写进 SKILL.md 一段，措辞按 P6 之后的「两类」合同写，不提 `PrimitiveAction` / `FlowActionBase` / validator |
| addon `docs/proposals/` 两篇 | 删（git 里有） |
| hex `docs/reference/` 三篇、`logic/docs/logic-to-presentation-guide.md` | 删；删前只捞「铁律 / 必须 / 不得 / 禁止」类句子并入 hex `README.md`，不搬样例 |
| hex `README.md`、`frontend/README.md`、`core/README.md`、两份 `DEV_AGENT.md` | 留（`run-dev-scene` 依赖 DEV_AGENT）；删掉其中指向已删文件的链接 |
| `.claude/skills/enforcing-lgf/SKILL.md` | 留为规则之家。顶部加一行「LGF core 重构进行中（P6–P9），API 以 `docs/plan/lgf-core-refactor-2026-09.md` 与代码为准」（P10 删） |
| `.claude/skills/enforcing-lgf/reference/` 12 篇 | 只留 `conventions-detail.md`、`cast-eligibility-vs-condition.md`；其余 10 篇删。SKILL.md 里对应的「按需读」条目改为「看哪个文件」指针表（指向真实 core / stdlib 源文件与对应测试） |
| `.claude/skills/enforcing-lgf/update.json`、`.claude/commands/update-lgf-skill.md` | 删（增量机制随 reference 退役） |
| `.claude/skills/lgf-new-logic-skill/SKILL.md` | 留；内嵌代码样例改为指向一个真实技能文件及其 scenario 测试；删指向已删文件的引用 |
| `.agents/skills/` 全部 11 个 | 删（Codex 不参与逻辑开发；根目录 `AGENTS.md` 若存在保留） |
| 主仓 `CLAUDE.md` | 删 `/update-lgf-skill` 一行；「LGF 原始架构文档」句改为只指 addon `CLAUDE.md`；「测试」节加一句「launcher 遇 SCRIPT ERROR 判 FAIL」 |
| 计划 §6 偏离记录 ①–㊿ | 原样搬到 `docs/plan/lgf-core-refactor-2026-09-deviations.md`（文件头一行说明格式，新条目按 §2 精简格式追加）；后续观察中已标「本条关闭」的条目搬到该文件末尾「已关闭」节；§6 只留状态表与仍开着的后续观察 |

**捞规则的方法**：对每篇待删文件 `grep -n '铁律\|必须\|不得\|禁止\|不要\|不能\|只允许\|唯一'`，逐条判断是否已在规则之家；不在的并入，并在偏离记录列「从 X 捞入 Y」。

**一次性 chore**：
1. `tools/run_tests.ps1` `Finish-Scene`：在 TIMEOUT 与 `SMOKE_TEST_RESULT: FAIL` 判定之后、`exitCode` 判定之前加一支：`$log -match "SCRIPT ERROR:"` → `FAIL`，reason 带首条匹配行。先红后绿：临时在任一 smoke 里注入一行必报 SCRIPT ERROR 的代码，launcher 须判 FAIL，验证后还原。
2. 全量组重跑，86 scene 仍全绿（证明零 SCRIPT ERROR 基线成立）。

**测试**：全量组。释放测试 / 直方图不适用。

**完成定义**：处置表逐行落地；`grep -rn "CHANGELOG\|docs/README.md\|docs/reference\|update-lgf-skill" CLAUDE.md addons/logic-game-framework/CLAUDE.md .claude/skills .claude/commands` 零命中；`.agents/skills` 不存在；SKILL.md 与 lgf-new-logic-skill 里引用的每个路径 `ls` 都存在；launcher 对注入的 SCRIPT ERROR 判 FAIL、还原后 86 scene 全绿；两仓 commit（addons 先）；§6 状态行。

---

### P6 Action / Config 收口（刀 8）

**目标**：Action 只剩两类；Condition 不再白背组件生命周期；ActiveUse 与 ActivateInstance 配置层级镜像组件层级。

**改法**：
1. `core/actions/Action.gd`：删 `PrimitiveAction`、`FlowActionBase`，`FlowAction.IfAction extends BaseAction`；`execute_child` 保留；文件头「四层合同」表改为「两类」。16 处 `extends Action.PrimitiveAction`（inkmon 7、hex 5、core 2 内嵌、测试 2）改 `extends Action.BaseAction`；`SkillLocalAction` 不动。
2. 删 `core/actions/action_architecture_validator.gd` + `tests/core/actions/action_architecture_validator_test.gd` + `run_tests.gd:30` 登记；删 `core/actions/tag_action.gd` + `tests/core/actions/tag_action_test.gd`（生产零调用）。
3. `core/abilities/shared/condition.gd`：`extends RefCounted`（7 个子类均未用组件 API，已核实）；保留 `_freeze/_verify_unchanged`。
4. Config 合并：`ActiveUseConfig extends ActivateInstanceConfig`（删重复字段，只留 `conditions` / `costs`）；`ActiveUseConfigBuilder extends ActivateInstanceConfigBuilder`，`trigger / trigger_mode / timeline / on_tag / on_timeline_start / on_timeline_end` 用协变返回覆盖（`-> ActiveUseConfigBuilder`，调 super）；`build()` 返回 `ActiveUseConfig`。`AbilityConfig`：删 `active_use_components`，`components: Array[AbilityComponentConfig]` 一个列表，`AbilityConfigBuilder.active_use(cfg)` 保留为追加到 `_components` 的别名（37 处调用不动）；加 `get_active_use_configs() -> Array[ActiveUseConfig]`（按类型过滤）供 `scripts/SkillValidator.gd`（5 处）、`skill-preview/hex_battle_skill_index.gd`（3）、`skill_preview_validation.gd`（2）、`skill_preview.gd`、`hex_random_demo_world_gameplay_instance.gd`（2）、`scripts/runtime_script_test.gd`（2）、`smoke_manifest_lint.gd`（3）、`tests/skill_validator/smoke_skill_validator.gd` 改用；`_resolve_components` 与 `collect_timelines` 简化为单列表遍历（`ActiveUseConfig is ActivateInstanceConfig` 自动覆盖）。
5. 文档：`docs/reference/action-architecture.md` 与 skill `reference/actions.md` 已在 P5.5 删除，目录规则已按两类合同写在 SKILL.md；本阶段只核对规则之家（见下）。

**钉子（开工前）**：解析顺序钉——builder 先 `.component_config(x)` 再 `.active_use(y)`，grant 后断言 ability 的 component 解析顺序为今日的「active_use 在前」。变红处理：grep 全仓技能是否存在「先 `component_config` 后 `active_use`」的写法；没有 → 重烤钉子为调用顺序并写偏离一条；有 → 让 `active_use(cfg)` 仍排在普通 component 之前以保住今日派发顺序（D1：component 顺序 = handler 顺序），写偏离一条。inkmon golden 与 hex scenario 必须不变。

**测试**：`tests/core/abilities/` 中构造 `ActiveUseConfig.new(...)` 的测试改新构造顺序；加一条 builder 测试（`ActiveUseConfig.builder().timeline(tl).on_tag(...).condition(c).build()` 类型为 `ActiveUseConfig` 且 `is ActivateInstanceConfig`）。跑全量组 + `main/validator`。

**规则之家**：SKILL.md 与 addon `CLAUDE.md` 里「Action 四层」改为「两类 + 目录规则」各一段（P5.5 已预写目录规则，此处核对措辞与代码一致）。

**行为变化**：无运行时行为变化；失去 validator 门禁（由目录规则 + P10 整体审顶上）。

**完成定义**：`grep -rn "PrimitiveAction\|FlowActionBase\|ActionArchitectureValidator\|TagAction\.\|active_use_components" --include=*.gd` 全仓零命中，且 addon `CLAUDE.md` 与 SKILL.md 零命中（计划文件与偏离记录除外）；钉子绿或按规则重烤；释放测试绿、直方图收尾一次不增；全量组绿；两关；两仓 commit；§6。

---

### P7 事件 dict key 统一 snake_case（刀 7）

**目标**：唯一跨层契约一种拼写；机器守门。

**改法**：
1. `core/events/game_event.gd`（24 个 payload key：`actorId, abilityInstanceId, abilityConfigId, sourceId, triggeredComponents, triggerEventKind, timelineId, targetActorIds, targetActorId, sourceActorId, projectileId, oldValue, oldStacks, oldCount, newValue, newStacks, newCount, logicTime, hitPosition, flyTime, flyDistance, failedComponentType, executionId, cueId`）、`stdlib/projectile/projectile_events.gd`（`projectileId, flyTime, flyDistance, hitPosition, startPosition, targetPosition, finalPosition, piercePosition, pierceCount, projectileType`）、其他发射点（`raw_attribute_set.gd` 的 `attributeName`，`ability.gd:386-390` 的 `abilityTags/maxStacks/overflowPolicy`，`ability_execution_instance.gd:200` 的 `triggeredTags`，`battle_recorder.gd:176` / `recording_utils.gd:93` 的 `instanceId`，`customData / visualType / eventKind / expiresAt / traceId / parentTraceId / handlerId / handlerName / modifierType / sourceName / scalesByStacks / loopsCompleted`）、`core/playback/playback_data.gd`（`battleId, recordedAt, tickInterval, totalFrames, mapConfig, positionFormats, configId, displayName`）全部改 snake_case。**kind 字面量**（`attributeChanged` 等 13 个 + projectile 5 个）也改 snake_case（`attribute_changed`…），与 hex/dota2/inkmon 的 `damage` / `inkmon_damage` 风格对齐。
2. 消费端约 437 处读取（addon core+stdlib 100、example 测试 133、hex frontend 21、addon 测试 12、inkmon 10、skill-preview 6）：`perl -i -pe` 批量 + 逐文件 `git diff` 核对；11 个生成的 attribute set 文件**不手改**，改生成器模板后用 headless `addons/logic-game-framework/scripts/generate_attribute_sets.tscn` 重生成（退出码 0）。
3. `InkMonBattleProcedure._create_action_use_event`（`inkmon/logic/battle/ink_mon_battle_procedure.gd`）手拼的激活 dict 改用 `GameEvent.AbilityActivate.create(...)`。
4. 守门：新增 `tests/core/events/event_key_casing_test.gd`：对 `GameEvent` 每个内嵌类与 `ProjectileEvents` 每个工厂用哑参构造，`to_dict()` 的所有 key（递归一层）匹配 `^[a-z0-9_]+$`；hex `smoke_manifest_lint` 可选加同断言覆盖 `BattleEvents`。
5. `scripts/SimulationManager.gd:62-64` 债务注释更新：JS 解析器需同步 snake_case + v3。

**钉子（开工前）**：inkmon `smoke_battle_golden` 只存 hash 不存 JSON——开工前临时给它加一个落盘分支（或 ad-hoc scene），把 behavior JSON 写到 `.claude/tmp/p7/before.json`；改完再落盘 `after.json`；用 python 对 `before.json` 递归套用本阶段的 key 映射表（含 kind 字面量）后与 `after.json` 比对相等，脚本与两份 JSON 放 `.claude/tmp/p7/`，不入库。相等 → 重烤 golden 常量并写偏离一条；不等 → BLOCKED，不许直接重烤。

**测试**：hex scenario 与其余测试的 key 读取随 perl 批量改；跑全量组 + `inkmon/battle-2d`、`inkmon/mission`。

**规则之家**：SKILL.md 一句「事件 dict key 与 kind 字面量一律 snake_case」；`scripts/CLAUDE.md` 加一句协议说明；`scripts/SimulationManager.gd` 债务注释同改法 5。

**行为变化**：录像 JSON 形状变化（旧文件不可播）；`kind` 字符串变化影响任何按字面量匹配的消费者（已全常量化，lint 兜底）。

**完成定义**：`grep -rnE '"[a-z]+[A-Z][A-Za-z]*":' addons/logic-game-framework/core addons/logic-game-framework/stdlib --include=*.gd` 零命中；casing 测试绿；映射比对相等后 golden 已重烤；释放测试绿、直方图收尾一次不增；全量组绿；两关；两仓 commit；§6。

---

### P8 资源型属性（刀 6）

**目标**：hp 是资源不是派生值；扣血不再全属性重算。

**改法**：
1. 属性 config 语法：`"hp": { "kind": "resource", "baseValue": 100.0, "minValue": 0.0, "maxRef": "max_hp" }`（三份含 hp 的 config：`logic-game-framework-config/attributes/attributes_config.gd` 的 `InkMonUnit`、hex `HexBattleActor`、dota2 `Dota2BattleActor`）。
2. `core/attributes/raw_attribute_set.gd`：`define_resource(name, initial, min_value, max_ref)`，`_resource_values: Dictionary`；`set_resource(name, value)`（clamp `[min, max_ref 当前值]`，变化才 `_dispatch_event`，**不**跑 `_snapshot_all_values` / 动态求解）；`add_resource(name, delta)`；`get_current_value` 对资源返回存值；`add_modifier` / `update_modifier` 指向资源 → `assert_crash`；任何 stat 入口方法结束后对所有资源按 `max_ref` 重 clamp（max_hp 下降拉低 hp，沿用 `register_cross_attr_clamp` 的语义，改为资源专用实现）；`serialize` / `deserialize` 含资源值；`get_breakdown` 对资源返回 `AttributeBreakdown.from_base(value)`。
3. 生成器 `scripts/attribute_set_generator_script.gd`：资源属性生成 `var hp: float`（getter）、`set_hp(v)`、`add_hp(delta)`、`on_hp_changed`、`const hp_attribute`，**不**生成 `_breakdown` / `set_hp_base`；`maxRef` 对资源生成 `define_resource` 而非 `register_cross_attr_clamp`；`_validate_clamp_direction` 逻辑对资源保留。重生成 11 个 set，逐字节核对只有 hp 相关行变化。
4. 17 处生产 `set_hp_base(` → `set_hp(` / `add_hp(`（`hex_battle_damage_utils.gd:87`、`heal_action.gd:108`、`regenerate_action.gd:81`、`spawn_actor_action.gd:74`、`ink_mon_battle_damage_utils.gd:30`、`ink_mon_unit_actor.gd:94,129,334`、`dota2_damage_action.gd:64`、`stone_wall.gd:34`、`fire_tile.gd:35`、`character_actor.gd:58` 等）+ 19 处测试。
5. 规则之家：SKILL.md 与 addon `CLAUDE.md` 各一句「hp 是资源：写走 `set_hp` / `add_hp`，不再有 `set_hp_base`；stat 属性照旧 `set_*_base`」；主仓 `CLAUDE.md` 与 §2 踩坑「`attribute_set.hp = x` 静默吞」保留。`docs/README.md` 与 hex `damage-pipeline.md` 已在 P5.5 删除。

**钉子（开工前）**：不用新加。inkmon golden 含属性快照与 AttributeChanged 事件流（今日 `_notify_changes` 已只在值变时发），hex scenario 含数值断言，两者就是钉子；**任一变红 = BLOCKED，不许重烤**。

**测试**：`tests/core/attributes/attribute_set_test.gd` 的 21 行 hp modifier 用例改成对 stat 属性（如 `atk`）+ 新增资源用例（clamp 到 max_ref、max_hp 下降拉低 hp、加 modifier 到资源 crash、`set_resource` 不触发其他属性通知）；`attribute_set_generator_test.gd:83` clamp 断言改为 `define_resource` 行。跑全量组（`inkmon/m1` 数值 golden 必须不变）。

**行为变化**：数值应完全一致；`AttributeChanged` 事件流应一致（只在 hp 真变时发）；性能：扣血不再全属性重算。

**循环引用要点**：`RawAttributeSet` 仍只存 String（`register_cross_attr_clamp` 的「不存 Callable」纪律延续到资源 clamp）；`on_hp_changed` 返回的注销闭包捕获 raw set 自身，由调用者持有，方向与今日一致。

**完成定义**：`grep -rn "set_hp_base" --include=*.gd` 零命中；生成文件重生成后 `git diff` 只含 hp 行；inkmon golden 与 hex scenario 不变；释放测试绿、直方图收尾一次不增；全量组绿；两关；两仓 commit；§6。

---

### P9 grid 出 core → stdlib，inkmon 双 grid 退役（刀 5）

**目标**：core 不依赖 ultra-grid-map；inkmon 不再翻转基类 grid。**submodule 一次 commit（stdlib 新增 + hex + core 剥离），随后主仓一次 commit（inkmon + 指针）**，中间 inkmon 编译不过是预期的，不要拆开验收。

**改法**：
1. `stdlib/grid/grid_world_gameplay_instance.gd`：`class_name GridWorldGameplayInstance extends WorldGameplayInstance`；从 core 原样搬 `signal actor_position_changed(actor_id, old_coord: HexCoord, new_coord: HexCoord)`、`signal grid_configured(config: GridMapConfig)`、`signal grid_cell_changed(coord: HexCoord, change_type: String)`、`var grid: GridMapModel`；`configure_grid(config)`（建 model + initialize → 委托 `configure_grid_model`）；`configure_grid_model(model)`（从 inkmon 上提：`grid = model; grid_configured.emit(model.get_config())`，唯一 emit 点）；`_get_map_config() -> Dictionary`（`grid.to_config_dict()`，null 则 `{}`）；`clear_grid_footprint(actor)`（`IGridOccupant.get_grid_position(actor)` 有效时 `occ is Object and occ == actor` 才 `remove_occupant`，再扫 `get_all_coords()` 取消该 actor 的 reservation；**不用** `GridMapModel.find_occupant_position`，它对 Variant 无守卫 `==`）；`remove_actor(actor_id)`（`super.get_actor` 取 actor → `clear_grid_footprint` → `super.remove_actor`）。
2. `stdlib/grid/i_grid_occupant.gd`：`class_name IGridOccupant`，`static func get_grid_position(actor: Actor) -> HexCoord`（`"hex_position" in actor` 则取值，否则 `HexCoord.invalid()`）。hex `HexBattleActor.hex_position` 与 inkmon `InkMonWorldActor.hex_position` 天然满足。
3. core `core/entity/world_gameplay_instance.gd`：删 `grid`、`configure_grid`、三个 signal；`capture_world_snapshot()` 改 `snap.map_config = _get_map_config()`，加虚 `_get_map_config() -> Dictionary: return {}`。`actor_position_changed` **整体离开 core**（它携带 HexCoord 就是 grid 概念；core 零发射零消费）。
4. hex：`hex_world_gameplay_instance.gd` 改 `extends GridWorldGameplayInstance`，`configure_grid` 覆盖保留为 UGridMap 桥（`UGridMap.configure(config); configure_grid_model(UGridMap.model)`）；删 `remove_actor` + `_find_reservations_by`；`hex_battle_damage_utils._clear_grid_footprint`（:147-155）改调 `battle.clear_grid_footprint(dead_actor)`；`frontend/world_view.gd:44 bind_world(world: GridWorldGameplayInstance)`；harness `_PreviewInstance.start()` 里的 `UGridMap.configure(grid_config)` / `grid = UGridMap.model` 用 `configure_grid`、录像快照的 `UGridMap.model.to_config_dict()` 用 `_get_map_config()`。dota2 不动（`map_config` 仍 `{}`）。
5. inkmon `inkmon/logic/world/ink_mon_world_gi.gd`：`extends GridWorldGameplayInstance`；头注释 `:6-12` 改「固定分工无翻转」；删 `:63 overworld_grid_model`、`:289-290`（`grid = overworld_grid.model`）、`:743-755` 两个 `configure_grid*` 覆盖（inkmon 从此**不写 UGridMap**，已核实 inkmon/scripts/渲染器无人读 UGridMap）、`:758-762 remove_actor` 覆盖、`:887-890` 翻回；加 `get_battle_grid() -> GridMapModel: return grid`（accessor，不是第二字段）；`:441-443` 注释精简（守卫保留）；不覆盖 `_get_map_config`（快照只在 `start_battle` 内取，此时 grid 即战斗棋盘）。
6. inkmon 19 处战斗侧 `grid` 读取改 `get_battle_grid()`：`ink_mon_battle_setup.gd` `:119(×2),123,129,130(×2),143(×2)`（每函数 hoist 一个 `var board := gi.get_battle_grid()`）；删 `find_reservations_by`（:149-156）与 `clear_actor_footprint`（:162-173），其 3 处调用者改 `gi.clear_grid_footprint(actor)`（`ink_mon_battle_damage_utils.gd:44`、GI `:761`（随覆盖删除）、GI `:901`）；`ink_mon_ai_strategy.gd:73-78` hoist 一次；`ink_mon_apply_move_action.gd:27` / `ink_mon_start_move_action.gd:26`；`inkmon/tests/smoke_wild_battle.gd:71`。`InkMonBattleSetup.configure_battle_grid`（:186-199）主体不变（调用的已是 stdlib 方法），注释 `:184` 更新。

**钉子（开工前）**：grid 占用对称钉（hex 测试，今日行为）：`remove_actor` 后该 actor 在 `grid` 无 occupant 且无 reservation。inkmon 「`_reset_battle_state` 后上一棋盘无残留占用」是新行为（今日对 overworld model 静默 no-op），走先红后绿而非钉子。inkmon golden 与 hex scenario 变红 = BLOCKED。

**测试**：hex 12 处 `configure_grid(` 测试调用与 `tests/smoke_skill_preview_environment.gd` 靠继承零改动；inkmon 只改 `smoke_wild_battle.gd:71`；`smoke_tick_movement.gd` 必须保持绿。跑全量组（含 `inkmon/session`、`inkmon/battle-2d`）。

**规则之家**：addon `CLAUDE.md` mermaid 加 `Grid[GridWorldGameplayInstance]`，加一句「core 无 grid，`_get_map_config()` 是唯一钩子；grid 是 stdlib 电池，dota2 不带」；SKILL.md entity 段一句。主仓 `docs/main-game-architecture.md` 仍改（它是主游戏架构真相，不是 LGF 文档）：`:86`（`overworld_grid` 必留 → 分工固定，`get_battle_grid()` 是唯一战斗侧读名）、`:117` ⚠️ → 已解决、`:263/:265` §9。`docs/README.md` 与 skill `reference/entity.md` 已在 P5.5 删除。

**行为变化**：inkmon 不再配置 UGridMap；`gi.grid` 在战斗外是上一场棋盘或 null（今日零处此类读取）；`_reset_battle_state` 清理现在真的清上一棋盘的占用（此前对 overworld model 静默 no-op）；hex `remove_actor` 清理条件从 `is HexBattleActor` 变「有 hex_position」（同集合）。

**循环引用要点**：`GridWorldGameplayInstance.grid` 是 instance → model 的向下强边；`GridMapModel` 的 occupant 表存的是 actor 引用（instance → grid → actor，与 registry 同向，不成环），但 **actor 死亡/移除必须清 occupant**，否则 grid 持尸体到 instance 结束——`clear_grid_footprint` 在 `remove_actor` 里保证这一点；释放测试第二用例加 `grid` 的 weakref。`BattleProcedure` 对 `world.actor_added` 的 signal 连接是 world → procedure 的强边，与 `_active_battle` 同向，`finish()` 断开（既有）。

**完成定义**：`grep -rn "HexCoord\|GridMapModel\|GridMapConfig\|UGridMap" addons/logic-game-framework/core --include=*.gd` 零命中（注释除外）；`grep -n "overworld_grid_model\|configure_grid_model\|grid = " inkmon/logic/world/ink_mon_world_gi.gd` 只剩预期项；钉子绿；释放测试扩 `grid` weakref 后绿；直方图逐字节与基线一致；全量组绿；两关；两仓 commit；§6。

---

### P10 整体审与收口（2026-09-12 新增）

**目标**：对 P6–P9 累计改动做本轮唯一一次 agent 审并修完；收掉 P5.5 的横幅；四条设计题留给用户。

**改法**：
1. **审查面**：从 P1 基线起算，含 P1–P5——submodule 内 `git diff 8e56bba..HEAD -- core stdlib`；主仓 `git diff bbe5d9a7..HEAD -- inkmon scripts tools`。P1–P5 由 opus 开发并逐阶段 `/code-review max` 审过、P5 第二轮复审被叫停，不单独补审，纳入这一次即可。reviewer / verifier agent 也用 **fable**（用户 2026-09-12 拍板：周限额充裕，全程 fable）。
2. **整体审**：优先 `/code-review max`——用 `mcp__ccd_directory__change_directory` 切到 `addons/logic-game-framework`，以路径目标 `core stdlib` 让它覆盖上述范围（review 靠 git diff 找改动；若它只看工作区或只看最近一次 commit、覆盖不到累计范围，则把两份 diff 落盘到 `.claude/tmp/p10/`，开 3 个 fresh-context reviewer agent 各审一个角度：① 退场对称与循环引用 ② P8 资源属性语义与数值路径 ③ P9 grid 归属与占用清理，每条发现再由一个 verifier agent 核实）。审完切回 repo root。只报 CONFIRMED 且 severity ≥ medium；low 记后续观察不修。**不复审**。
3. **修复**：按 §2 第 1 关（含钉子通则）重跑；修完不再开 review。
4. **收口**：删 SKILL.md 横幅；核对 SKILL.md 与 addon `CLAUDE.md` 指针表指向的文件都存在；释放测试与直方图按 P9 标准再跑一次。
5. **留给用户拍板、本阶段不做**：注册前 grant 的纯 post 被动静默缺订阅；post handler 里过期不当场 revoke；`Ability.owner_actor_id` 与 set owner 双来源；Break 后 pre handler 仍改事件。整体审若再报这四条，标「已知、待拍板」不修。（2026-09-13 拍板、09-14 落地：① `grant_ability` 断言 owner 已登记；② post 派发在 handler 收尾回收自 expire 者，不做配置项；③ grant 时由 set 盖章 owner，「id 由工厂派发」列候选刀不排期；④ 不做，Break 未继续设计。见 §6「P10 拍板落地」行与 deviations P10.5。）

**完成定义**：整体审的 CONFIRMED ≥ medium 全部修完或在偏离记录写明不修理由；全量组绿；直方图与基线一致；横幅已删；指针表无死链；两仓 commit；§6。

---

## 4. 明确不做（本轮认可的既有决策，勿重开）

- 刀 9 表演管线上提（render_world / scheduler / visualizer 注册表 / VisualAction 进 LGF `presentation/`）：另开计划，前提是先对齐 hex 3D 与 inkmon 2D 两份分叉。
- 不做 B 层 deterministic Replay；Playback 不重建逻辑层（铁律不变）。
- 不把 hex 的死亡语义（留尸体）或 dota2 的（tick 末移除）写进 core；core 只给钩子。
- 不引入 handler 优先级；pre/post 派发顺序 = 注册顺序（owner registry 序 → grant 序 → component 序）。
- 不重命名 `BattleRecorder` 家族、`assert_replay` DSL、`playback_*` signal。
- 不做 timeline 数据驱动（技能保持脚本形态，2026-07-02 拍板）。
- 不给 `GameplayInstance` 之外再造"多 instance 并行"设施；P4 只是把状态放对位置。

## 5. 启动指令（2026-09-12 修订）

两种方式等价，都是**每阶段一个 fresh context**：用户逐阶段开新会话粘贴「阶段 prompt」；或开一个总控会话粘贴「总控 prompt」，由它按序派子 agent。总控会话须开 bypass permissions，电脑不能睡眠；无人值守期间**不 push**。

**总控 prompt**：

```
你是 LGF core 重构的总控，只派活不干活。读 docs/plan/lgf-core-refactor-2026-09.md 的 §5 与 §6 状态表，找到第一个状态不是「已完成」的阶段（顺序 P5.5 → P6 → P7 → P8 → P9 → P10）。对该阶段用 Agent 工具派一个子 agent：subagent_type general-purpose，model fable（开发与 P10 审查全程 fable），run_in_background false（若工具不允许长阻塞则改 true，收到完成通知再继续），prompt 用 §5「阶段 prompt」原文填入阶段号。子 agent 返回后：读它的回报；跑 git -C addons log -1 --oneline 与 git log -1 --oneline 核对两仓各有本阶段的 commit；读 §6 状态表确认该行已填「已完成」。三项都对 → 派下一阶段；回报是 BLOCKED、或核对不符 → 停链，把回报原样转给用户，列出已完成与阻塞的阶段。全部阶段完成后同样汇总，并附 push 命令（git -C addons push origin master，再 git push origin master）。你自己不读源码、不跑测试、不改文件、不 push；不要把两个阶段合给一个子 agent；子 agent 的问题你不替它决定，它按 §2 无人值守策略自己定。
```

**阶段 prompt**（总控填 `<n>`；用户手动开会话时粘同一段）：

```
按 docs/plan/lgf-core-refactor-2026-09.md 执行 P<n>。先读 §0–§2、§6 状态表与后续观察中提到 P<n> 的条目、P<n> 全文，再读 addons/logic-game-framework/CLAUDE.md 与 .claude/skills/enforcing-lgf/SKILL.md；改 .gd 前遵守 enforcing-lgf / gdscript-coding skill。开工前 git -C addons status -sb 须干净且在 master。工序：钉子先行 → 新行为测试先红后绿 → 改代码 → 第 1 关 → 第 2 关 → 规则之家 → 两仓 commit（不 push）→ §6 状态行随主仓 commit。无人值守：不问人；计划没写到的选择取保住今日行为的那个并在偏离记录标 [假设]；第 1 关修复最多 2 轮，仍红即 BLOCKED（不 commit、不 stash、工作区原样留下，§6 状态行写 BLOCKED + 原因 + 建议）。只做本阶段范围，范围外发现记 §6 后续观察一行。最后回报不超过 15 行：DONE/BLOCKED、两仓 SHA、测试数变化、偏离条数、阻塞原因。
```

执行会话的纪律：只做本阶段范围；每个阶段的「完成定义」是验收清单；规则之家那几行改动是阶段的一部分，不是可选项；一个阶段两仓各一个 commit（submodule 的钉子 commit 除外）。

## 6. 状态与偏离记录

| 阶段 | 状态 | submodule SHA | 主仓 SHA | 备注 |
|---|---|---|---|---|
| P1 减法热身 | 已完成 2026-09-10 | `f1d132f` | `cdcc871f` | 基线 8e56bba 非 a4730a1，见偏离记录 ①；主仓先单独 `chore` bump 到 8e56bba（`bbe5d9a7`）再 P1。验收：86 scene 全 PASS / 释放测试绿 / 四份泄漏直方图与基线逐字节一致 / `/code-review max` 十角度已修 |
| P2 BattleActor | 已完成 2026-09-10 | `ec72e5a` | `cd0633ec` | 验收：86 scene 全 PASS（core 单测 173→187）/ 释放测试绿 / 直方图 core·hex·inkmon 与基线逐字节一致、dota2 **下降** 590→170 RefCounted（关掉本就播不了的 dota2 录像，基线已棘轮）/ `/code-review max` 十角度 + 修复后二次复审已合入。偏离见 ⑧–⑭ |
| P3 typed instance | 已完成 2026-09-11 | `0e54dfd` | `703b6efc` | 验收：86 scene 全 PASS（core 单测 187→193）/ 释放测试绿（含 context 释放探针）/ 直方图 core·hex·inkmon 与基线逐字节一致、dota2 **清零**（P2 后 170 RefCounted / 61 GDScript / 15 WeakRef / 1 GDScriptNativeClass → 0，根因是 world ↔ procedure 强引用环，基线已棘轮）/ `/code-review max` 十角度首审 + 六轮复审已合入。偏离见 ⑮–㉖ |
| P4 instance 级事件设施 | 已完成 2026-09-11 | `8af9821` | `c78aa66c` | 验收：86 scene 全 PASS（core 单测 193→199）/ 释放测试绿（4 例依次 41 / 74 / 53 / 92 条断言，含 procedure 子类直接 `finish()` 与录像战斗 tick 内结束 world）/ 四份直方图与基线逐字节一致 / `/code-review max` 十角度首审 + 三轮复审已合入（最后一轮只剩文字修正）。偏离见 ㉗–㊳ |
| P5 Post 订阅制 | 已完成 2026-09-12 | `78f8cc5` | `d0cfec19` | 验收：86 scene 全 PASS（core 单测 199→218，hex scenario 68→69）/ 释放测试绿（5 例依次 44 / 80 / 59 / 104 / 34 条断言，含 registration 在 revoke / `remove_actor` / 整个换掉 AbilitySet 三种退场下的释放）/ 四份直方图与基线逐字节一致 / inkmon golden 指纹不变 / `/code-review max` 十角度首审（15 条：13 修、2 记入 ㊿）+ 一轮四角度复审（全为 low：修 9 条，owner 双来源记入 ㊿⑦），复审第 1 轮后未再开下一轮（用户要求本轮后暂停）。偏离见 ㊴–㊿ |
| P5.5 文档清场 | 已完成 2026-09-12 | `dc6da26` | `d8574859` | 验收：86 scene 全 PASS（launcher 已判 SCRIPT ERROR，人工 grep 日志只剩 core 单测两条既知基线）/ 处置表逐行落地 / 释放测试 · 直方图不适用。偏离见 deviations 文件 P5.5-1–8 |
| P6 Action/Config 收口 | 已完成 2026-09-12 | `6daabbc` | `f67c010b` | 验收：86 scene 全 PASS（core 单测 218→209：删 tag_action / validator 两套 11 例，加钉子 1 例 + ActiveUseConfig 层级 1 例；hex scenario 69 不变）/ 释放测试绿 / 四份直方图与基线逐字节一致 / inkmon golden 指纹不变 / 钉子未重烤（hex stance 是先 component_config 后 active_use 的写法，builder `active_use` 恒前置）。钉子 commit `f2c71b9`。偏离见 deviations 文件 P6-1–8 |
| P7 key snake_case | 已完成 2026-09-12 | `a9f4b50` | `abbe892f` | 验收：86 scene 全 PASS（core 单测 209→214：casing 守门 5 例；hex scenario 69 不变）/ 释放测试绿 / 四份直方图与基线逐字节一致 / 完成定义 grep 零命中 / inkmon golden 按「改前 JSON 递归套 key 映射 == 改后 JSON」比对相等后重烤（hash 638978954→3014638374，result / ticks / frames 全等）/ 钉子即这份比对（脚本与两份 JSON 在 `.claude/tmp/p7/` 不入库，无 submodule 钉子 commit）。偏离见 deviations 文件 P7-1–7 |
| P8 资源型属性 | 已完成 2026-09-12 | `1360b9e` | `2f7576c9` | 验收：86 scene 全 PASS（core 单测 214→220：hp modifier 用例改 atk、删 2 例跨属性 clamp、加 7 例资源 + 1 例生成器契约；hex scenario 69 不变）/ 释放测试绿 / 四份直方图与基线逐字节一致（P6–P8 收尾一次）/ inkmon golden 指纹不变（3014638374，钉子未重烤）/ 完成定义 grep 零命中 / 11 份生成 set 重生成，只有含 hp 的 3 份变化且只 hp 行 / 新行为测试先红（既有 API 用例断言红、新 API 用例运行期缺方法红）后绿 / 无 submodule 钉子 commit（计划：不用新加）。偏离见 deviations 文件 P8-1–7 |
| P9 grid 出 core | 已完成 2026-09-12 | `4b7923c` | `7c3ed6e5` | 验收：89 scene 全 PASS（17 required + 72；core 单测 220→224：stdlib GridWorld 合同 4 例；hex/regression 新增钉子 `smoke_grid_footprint`；inkmon/m1 新增 `smoke_battle_board_reset`；hex scenario 69 不变）/ 释放测试绿（用例 2 改 GridWorldGameplayInstance + 站棋盘 + 预订，加 grid weakref，80→84 条断言）/ 四份直方图与基线逐字节一致 / inkmon golden 指纹不变（3014638374）/ 完成定义 grep：core 只剩 `game_event.gd` 一条注释，inkmon GI 只剩 `overworld_grid = ` / 新行为测试先红（inkmon 按断言红「4 unit(s) still occupy the previous board」；stdlib 单测 parse 红）后绿 / 钉子 commit `53aa1d4`。偏离见 deviations 文件 P9-1–6 |
| P10 整体审与收口 | 已完成 2026-09-12 | `658f43e` | `2ca3f617` | 验收：89 scene 全 PASS（17 required + 72；core 单测 224→225：资源 modifier 入口暂降 1 例，P8「回升不恢复」用例重烤为「回升恢复」；inkmon `smoke_actor_serialization` +1 带 max_hp 装备的幂等守卫）/ 释放测试绿 / 四份直方图与基线逐字节一致 / inkmon golden 指纹不变（3014638374）/ 整体审 = 3 reviewer + 1 verifier（fable）：1 medium（P8 资源存值被上限暂降覆写）CONFIRMED 已修（先红后绿）、7 low 记后续观察不修、四条设计题仍待拍板 / 横幅已删、指针表无死链、14 处 `.gd` 注释指针已清 / `-Required` 一次退出期 AV 偶发（单跑 3 次 + 整组重跑 PASS，记后续观察）。偏离见 deviations 文件 P10-1–8 |
| P10 拍板落地 | 已完成 2026-09-14 | `84a4c61` | `50968141` | 四条设计题 2026-09-13 拍板：① `grant_ability` 断言 owner 已登记 ② post 派发在 handler 收尾回收自 expire 者（不做配置项） ③ grant 时由 set 盖章 owner，「id 由工厂派发」列候选刀不排期 ④ 不做。验收：`all` 别名 127 scene 全 PASS（core 单测 225→226：handler 内 expire 当场除名 +1、盖章断言扩入既有用例，先红后绿；`instance_context_test` 两条改为 instance 已销毁形状）/ 零 SCRIPT ERROR、「EventProcessor not available」基线 1→0 / inkmon golden 指纹不变 / 直方图未重烤（改动无新引用，[假设]）。偏离见 deviations 文件 P10.5-1–6 |
| 随机战斗差分 + golden 固化 | 已完成 2026-09-14 | `2f8cf7c` | `42cd3a56` | 与基线 bbe5d9a7 / 8e56bba 逐 seed 差分：demo 20 seed 日志逐字节同、事件流 / 胜负 / 帧数全同；覆盖组 30 seed 的 8 处分叉全部归因 A/B/C/D（RD-2）；拍板 ① 尸体不 tick 落地（在飞执行冻结而非 cancel，[假设]）；新增 `hex/random-golden`（10 seed，53 config 全覆盖，required）；hex 28 scene + 该组全 PASS。记录见 deviations RD-1–6 |
| 后续观察第 3 轮 B-9 | 已完成 2026-09-17 | `7182e8f` | `93caa156` | 删 `.claude/skills/lgf-new-logic-skill/` 与 `.lomo-team/reference/inkmon-skill-design.md`（`mechanics-taxonomy.md` 与三份 `*-raw.md` 研究笔记保留）；SKILL.md §7 表演层接入清单迁 hex `frontend/README.md`「新技能表演层接入清单」节，hex README 指针改指该节；主仓 `CLAUDE.md` / `AGENTS.md` 摘条目。验收：`-Required` 18 scene 全 PASS；无 `.gd` 改动，golden / 直方图不适用。§6「inkmon-skill-design 示例整体失效」条随之关闭 |
| 后续观察第 1 轮 B-core 小修 | 已完成 2026-09-17 | `09ac4ee` | `df17d9a0` | B-1 `revoke_abilities_where(predicate, reason)`（删两个 by_* 特例）/ B-3 删 `destroy_all_instances`（21 处改 `shutdown()`）/ B-4 删 `serialize` 链 + 规则之家「可序列化挂读者不挂类」/ B-6 modifier 三钩子 null 即 `assert_crash` 报明原因；配套 `TestFramework.expect_script_errors(n)` + launcher 按 `EXPECTED_SCRIPT_ERRORS: n` 恰好放行。验收：新行为用例先红后绿（B-1 三例、B-6 两例）/ `all` 127/128，唯一 FAIL 是第 2 轮进行中的 random-golden 漂移，隔离 worktree 复跑 10 seed 不漂 / inkmon 只机械改动、golden 指纹不变。偏离见 deviations 文件 FU1-1–8 |
| 后续观察第 2 轮 B-hex | 已完成 2026-09-17 | `a66d3d9` | `12362171` | B-2 投射物产出即派发 / B-7 hex 退 `UGridMap` autoload / B-5 item_preview 沙盒登记 / B-10 dota2 攻击预检。验收：`-Required` 18 scene 全 PASS（core 单测 +4：`projectile_system_test`，释放测试随组绿）/ `all` 别名 129 scene 全 PASS / 四处新行为测试均先红后绿 / `hex/random-golden` 按解释重烤（10 seed 里 5 个只差 `projectile_despawn` 相对命中反应事件的位置，胜负 / 帧数 / 事件数全同）、B-7 前后 10 seed 事件流逐字节同 / inkmon 冻结未动 / 直方图未重烤。偏离见 deviations 文件 FU2-1–13 |
| 后续观察第 4 轮 A1 | 已完成 2026-09-17 | `df86d90` | `2c8beba9` | A1 十一条全部落地（inkmon 两个半条冻结，条目 9 只核对）。验收：新行为用例先红后绿（条目 1 / 2 / 4 / 6 / 11 单测、条目 5 新 smoke；条目 10 两条钉子；core 单测 +8 → 242，hex/regression +1）/ `all` 130 scene 全 PASS / 释放测试随组绿 / `hex/random-golden` 零漂移（回退本轮 core 改动 A/B 10 seed sha 逐条相同）/ inkmon golden 指纹不变 / 直方图未重烤（无新引用，[假设]）。偏离见 deviations 文件 FU4-1–12 |
| 后续观察第 6 轮 执行中新记回的三条 | 已完成 2026-09-17 | `ebf97c8` | `7a31bdaf` | `AbilitySet.revoke_ability` 按对象除名（含 on_remove 里重入 revoke 自己不二次广播）/ `GameplayInstance.base_tick` 走系统表快照（中途 `add_system` 下一趟起 tick、中途 `remove_system` 本趟不再 tick）/ 用户拍板 A 删 `u_grid_map.gd` 连同 README 的 UGridMap 示例段。验收：四条新用例先红后绿（core 单测 242 → 246）/ 隔离 worktree（主仓 `2c8beba9` + addons `df86d90` + 仅本轮 patch）`all` 130 scene 全 PASS，释放测试随组绿 / `hex/random-golden` 零漂移（改前 A / 改后 B 复跑 10 seed sha 逐条相同）/ inkmon golden 指纹不变 / 直方图未重烤（无新引用，[假设]）。§6 三条关闭。偏离见 deviations 文件 FU6-1–8 |
| 后续观察第 5 轮 A2 | 已完成 2026-09-17 | `d15162f` | `3c6c0b84` | A2 六条全部落地：录像收尾录进末帧 + 开录清 collector + 同帧号并帧 / `register_dynamic_dep` 发通知 + 两条封顶路径单测 / `AbilityGranted` payload 收成 `id` 一个键 / 十个 type id 改 snake / `actor_removed → unregister_actor`（只退订不推事件）/ hex 与 skill-preview 补 tick 循环走快照 + 尸体在飞行动 cancel。验收：新行为用例先红后绿（红因全为断言；core 单测 246 → 255，新 smoke `smoke_tick_loop_removal` 进 hex/regression）/ `all` 131 scene 全 PASS / 释放测试随组绿（用例 2 加中途离场 weakref 断言）/ 两份 golden 逐条差分归因后重烤：末帧 +`tag_changed`（hex 每 seed 6 条、inkmon 8 条）、`ability_granted` 少 `instance_id` 键（hex 37 条、inkmon 5 条）、seed 900083 +3 条 `attribute_changed`、两个 seed 各少 1 条已离场 actor 的 `ability_removed`；type id 与快照遍历零漂移；胜负 / 帧数全同，inkmon 指纹 3014638374 → 3099257976 / inkmon 只重烤 golden 常量 / 直方图未重烤。§6 六条关闭、新增三条。偏离见 deviations 文件 FU5-1–20 |
| 后续观察第 7 轮 A2 新记回的三条 | 已完成 2026-09-17 | `0e5de9c` | `3fa7578e` | 用户逐条拍板 A / A / A：hex 主循环逐个判 `is_dead()`（尸体从死亡那一帧起不 tick / 不充能 / 不起手，skill-preview 同形）/ ATB 阻塞改白名单只认 `active` · `action`（中毒 · 涌动 · 恶魔形态持有者恢复行动；manifest lint 守漏标；skill-preview 判 idle 改问 `has_pending_execution`）/ Stun 取消动作只改注释（不打断在飞 Move）。验收：新行为用例先红后绿（红因全为断言：`smoke_tick_loop_removal` +2 幕、新 smoke `smoke_action_tags` 幕 1；幕 2 · 3 为钉子）/ `all` 132 scene 全 PASS（core 单测 255 不变，hex/regression +1）/ 释放测试随组绿 / `hex/random-golden` 每条改完各 dump 一次逐帧差分、独立归因后重烤：条目 1 五个 seed 少掉尸体当帧的起手与在飞 keyframe（胜负 · 帧数全同），条目 2 五个带中毒 · 涌动 · 恶魔形态的 seed 从持有者首次恢复行动那一帧起分叉（四个胜负翻转），条目 3 零漂移；671159 · 900131 指纹不变 / inkmon 冻结未动、指纹 3099257976 不变 / 直方图未重烤。§6 三条关闭、新增一条（inkmon 同形半条）。偏离见 deviations 文件 FU7-1–20 |

**偏离记录**：全部条目在 [`lgf-core-refactor-2026-09-deviations.md`](lgf-core-refactor-2026-09-deviations.md)（存量 ①–㊿ 原样搬入；P5.5 起新条目按 §2 精简格式追加在那里，§6 只留状态表与仍开着的后续观察）。

**后续观察**（范围外发现，不在本轮修；2026-09-17 已按 task-queue 3c 分诊并分七轮清理，分桶 / 拍板 / 各轮 hash 见 [`lgf-followups-2026-09-triage.md`](lgf-followups-2026-09-triage.md)——下列 14 条是清理后的余量，均无 LGF 侧待办：inkmon 冻结随 task-queue 2e / 基线参考数字 / 信息 · 已定 / 候选刀未排期 / 环境偶发）：

- 既有非 LGF 泄漏（P1 基线，原生类计数）：core `run_tests` 100 ObjectDB / 5 resources；hex `smoke_skill_scenarios` 38 / 6；dota2 `smoke_lane_wave_engage` 672 / 57（590 RefCounted + 66 GDScript + 15 WeakRef）；inkmon `smoke_m1_battle` 0。dota2 的 590 RefCounted 值得单独查（sim-nav / lane 侧）——P3 复审查明是 LGF 自己的 world ↔ procedure 强引用环，已修并清零（见 ㉒）。
- **`Log.assert_crash` 在 debug 构建下不阻断调用方**（本轮实证：独立探针项目里 `assert(false)` 只中止 `assert_crash` 自己那一帧，调用方继续跑完；`logger.gd` 里 `assert()` 之后的 `OS.crash()` 只在 release 走到）。含义：全仓所有 `assert_crash` 都是「响亮报错 + 该帧中止」而非「进程停住」，构造函数里的断言**挡不住**半成品对象继续被使用。计划各阶段（P1 的 timeline 非空、后续的 instance 非空等）凡写「crash」处，实际语义都是这个；需要真正阻断的地方得靠类型系统或提前 return，不能只靠断言。
- `plugin.gd._unregister_autoloads()` 随常量一起删掉了 `TimelineRegistry` 的清理行：曾启用过本 addon 的**其他**消费者项目，其 `project.godot` 里那行指向已删脚本的 autoload 再也无法靠「禁用/重启用插件」自动清除，只能手改（本仓已手改）。没加回清理是因为那要求 addon 长期保留一个指向已删文件的路径常量（违反无兼容 shim 纪律）；CHANGELOG 的迁移说明是目前唯一缓解。（P5.5 删除 CHANGELOG 后连迁移说明也没有了；其他消费者项目只能手改 `project.godot`。）
- dota2 示例没有 manifest（只有单个 `Dota2BasicAttackAbility`），因此未加 lint smoke；若它将来长出第二个 ability，照 `inkmon/tests/smoke_skill_manifest_lint` 复制一个即可（逻辑已在 `AbilityConfig.lint_timelines`）。
- **inkmon 的 `"intrinsic"` 是裸字面量**（P2 发现）：`ink_mon_battle_ability_set.gd` 的 `_is_blocking_execution` 与三个生产端（`ink_mon_damage_math_passive` / `ink_mon_engraving_passive` / `ink_mon_equipment_stat_ability`）各写一遍，而 hex 侧有 `HexBattleSkillTags.TAG_INTRINSIC`。打错一个字母 = 常驻 passive 被当成阻塞执行 = 该单位 ATB 永不充能、战斗静默跑到 timeout。常量归属地现成（`inkmon/logic/battle/config/ink_mon_skill_meta_keys.gd`）。
- **`instance == null` 仍是合法值**（P3 review 发现，按计划保留）：owner 未注册（孤立单测、`AbilityRef.new("a", "c")`、注册前 grant）时 context 的 instance 为 null。P3 已把五处「factory 里 `start()`」改成先注册（三处见 ㉑、dota2 两处见 ㉒），契约写在 `GameWorld.create_instance` 上；但 P4 C1 让 `get_event_processor` / `event_collector` 改从 instance 取之后，任何注册前的 grant / lifecycle 都会**静默**拿不到 processor / collector——P4「行为变化」里「生产路径全在注册后 grant」这一前提要在执行时对同形新站点复查。（P4 复查：新站点是 `PreEventComponent.on_apply` 取 processor、`ActiveUseComponent` 推激活失败事件、Action 经 `ctx.event_collector` 推事件；全量组 86 scene 日志里「EventProcessor not available」零命中（复审第 1 轮加的降级用例会在 core 单测日志里刻意触发一条，此后以「只有这一条」为准），`instance == null` 仍只出现在孤立单测；复审第 1 轮在 `instance_context_test` 补了三条降级路径的用例、第 2 轮给它补了日志断言，见 ㉟ ㊱。）（2026-09-14：注册前 grant 改由 `grant_ability` 断言拒绝，`instance == null` 只剩「instance 已销毁后仍持有 actor」一种来源；`instance_context_test` 两条降级用例改为销毁后的形状。）
- **inkmon overworld smoke 报 `Lambda capture at index 0 was freed`**（P4 扫日志发现，早于 P4）：`smoke_overworld_iso` 的 load 路径两次，`smoke_overworld_3d` 更早的日志里也有两次，都在世界重建（`destroy_all_instances` 前后）时调到了捕获已释放对象的 lambda，测试照样 PASS。未定位是哪条 signal 连接。
- **周期 buff 在被 grant 的那一帧不再 tick**（2026-09-14 随机战斗差分发现，P5 `_process_abilities` 遍历快照的副作用，行为变化未登记）：基线把 grant 帧重复计入，第二次 tick 落在第 19 帧；HEAD 落在精确周期第 20 帧。含周期 buff 的单位 ATB 时机最多偏 1 tick，数值与胜负不变。2026-09-14 查证是实现偷跑而非设计：① 同一个 buff 的两半不同步——时长倒计时在 `tick` 里、周期 timeline 在 `tick_executions` 里，基线顺序先 tick 后 tick_executions，挂上那一帧时长没扣、timeline 却走了 100ms；② 顺序依赖——给自己挂当帧走，给本帧已处理过的队友挂不走；③ `TimelineData.periodic` 定义 = 0ms 首 tick + 每 interval 循环，上游 7 月「loop 余量结转」专修周期精度，surge 注释写「之后每 2s」，基线实际 1.9s 再 2.0s；活数组遍历是 initial commit 的最简写法，无任何注释称当帧 tick 为有意。用户 2026-09-14 拍板保留 HEAD，`smoke_random_battle_golden` 钉住；若要回到基线行为，需让快照遍历补处理本趟新 grant 的 ability，并接受「同帧是否 tick」取决于目标处理顺序。
- **core 单测日志的刻意报错基线**（P5；2026-09-14 修订）：扫日志时「Event recursion depth exceeded」错误一条（`post_event_dispatch_test` 的嵌套派发用例），多出来的才是问题。原先还有「EventProcessor not available」警告一条（`instance_context_test` 未注册 owner 的 grant），注册前 grant 改为断言拒绝后该用例改为销毁后形状，这条警告归零。
- **actor id 改由工厂在构造时派发（候选刀，未排期）**（2026-09-13 讨论）：今天 id = `实例id:本地id`、`add_actor` 才发，`GameWorld` 只有 instance 表、按拆 id 反查 actor 与所属 instance；`IdGenerator` 是全局静态计数器，前缀对唯一性与确定性都无贡献，只服务反查。改成工厂派发会去掉「Do not set ID before add_actor」断言、`_on_id_assigned` / `bind_owner` / `attrs.actor_id` 补绑与构造期空 id（inkmon `InkMonUnitActor` 构造函数里用空串建 attribute_set / ability_set）；代价是 `GameWorld` 加一张 actor → instance 表并在 `remove_actor` / `end` / `destroy` 三个出口同步清（正是「退场对称」一类）、id 不再自描述归属、录像与 inkmon golden 里的 actor id 换格式要重烤。它能防的具体 bug 已由「grant 断言已登记 + grant 时盖章 owner」堵住，顺带收益（actor 跨 instance 迁移 id 不变）今天无人需要。触发条件：需要 actor 跨 instance 迁移；再出一次构造期依赖 id 的 bug；下次本来就要动 `add_actor` / registry。
- **inkmon `smoke_battle_board_reset` 未断言旧 `GridMapModel` 释放**（P10 整体审，low）：测试强持 `first_board` 只查占用清空；换板后旧板无第二持有者（`InkMonMapLoader.build_grid_model` 每次 `GridMapModel.new()`，inkmon 零引用 UGridMap）目前靠读码确认，缺 weakref 断言。
- **inkmon 0 血 carryover 单位整场占格**（P10 整体审范围外，既有）：`sync_downed_state` 保持 downed 的 roster 单位仍被 `place_team_fixed` 放成 occupant，整场不再触发死亡事件、不经 `clear_grid_footprint`，与「死亡不占格」不符。
- **`smoke_skill_validator` 退出期偶发 AV**（P10 发现）：`-Required` 并行跑时一次 exit=-1073741819，`SMOKE_TEST_RESULT: PASS` 已打印、崩在 ObjectDB cleanup 之后；单跑 3 次与整组重跑均 PASS。launcher 按退出码判 FAIL，遇到时先单跑复核；根因未查（与 `pitfall_gdscript_static_var_refcounted_exit_crash` 同形但非确定性）。
- **inkmon 的周期 buff 同样冻结持有者 ATB**（2026-09-17 第 7 轮发现，既有，inkmon 冻结只记）：`InkMonBattleAbilitySet._is_blocking_execution` 仍是「除 `intrinsic` 外全部阻塞」，而 `ink_mon_poison_buff` 正是 GRANTED_SELF 周期 timeline——inkmon 战斗里中毒 = 定身。hex 侧已改白名单（只认 `active` / `action`，见 deviations FU7-6）；inkmon 随重设计（task-queue 2e）处理，届时 golden 会大幅漂移。
