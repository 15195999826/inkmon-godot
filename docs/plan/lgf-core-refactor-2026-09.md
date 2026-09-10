# LGF core 重构计划（2026-09）

> 2026-09-10 锐评定稿。范围：`addons/logic-game-framework/`（core / stdlib / hex / dota2 示例）+ 主仓 `inkmon/`（第三消费者）+ `scripts/SkillValidator.gd` + 相关文档/skill。
> 背景：通读 LGF 后的十刀锐评，用户确认三句话心智模型不变（所有能力基于 ability；action 是原子能力；timeline 是逻辑动画）。刀 9（表演管线上提）另开计划，本轮不做。
> 状态：**P2 已完成（2026-09-10）**，下一阶段 P3。每阶段完成后在 §6 填 submodule / 主仓 SHA。
> 执行方式：**每阶段开新会话（clear context）**。本文件是仓内唯一真相（规划会话从 `~/.claude/plans/indexed-bubbling-raccoon.md` 复制而来，seed 不再更新）；P1 随主仓 commit 首次提交它。

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
| D10 | **验收 = 三关**：全量测试组 → 计划↔实现逐条核对（写偏离记录）→ `/code-review max`（修完再跑测试）。`/code-review max` 替代记忆里的 `/codex` 审查。 |
| D11 | **提交 = 两仓各 commit 并 push**：submodule 在 `master` 分支 commit 后 `push origin master`，再主仓 commit（指针 bump + inkmon/docs）并 push。顺序不可反（主仓指针不得指向未推送的 submodule commit）。 |
| D12 | **循环引用是每阶段的硬关卡**（用户此前修过多轮）。纪律：GDScript RefCounted 无循环 GC；子对象回指容器只允许 String id 或 WeakRef；context 对象（ExecutionContext / AbilityLifecycleContext / HandlerContext）栈作用域，任何 Component / Ability / Action / ExecutionInstance **不得把 context 或 instance 存进字段**；**要长期存放的 lambda 不得引用 `self` 或任何实例成员**（引用了就是 `GDScriptLambdaSelfCallable`，强持有宿主）——只能引用局部变量、参数、静态函数（`PreEventComponent.on_apply` 是范本）；`Callable(self, "m")` / `self.m` 形式的 Callable 不得跨容器边界存放。检查 = ① `tests/core/world/refcount_release_test.gd`（P1 建，逐阶段扩）② ObjectDB 泄漏直方图对比基线（见 §2）。 |

## 2. 每阶段验收协议（共用）

**全量测试组**（用 PowerShell tool 跑，单独一条调用，不与其他调用同批）：

```powershell
./tools/run_tests.ps1 -Required
./tools/run_tests.ps1 hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env
```

- `-Required` = `core/unit` + `hex/regression` + `dota2autobattle/regression` + `main/validator`。inkmon 组没有 required 标记，必须显式点名 `inkmon/all`。
- 失败先看 `.claude/tmp/test-runs/<scene>.log` 末尾；超时按失败处理，不抬 timeout。
- 新增 core 单元测试要**手动追加到 `addons/logic-game-framework/tests/run_tests.gd` 的 `TEST_PATHS`**（自动扫描是死代码）；零断言的测试算 FAIL。

**循环引用检查**（D12，属于第 1 关的一部分，每阶段必做）：
- **释放测试** `addons/logic-game-framework/tests/core/world/refcount_release_test.gd`（P1 新建并登记 `TEST_PATHS`）：建 instance → 加 actor（带 ability_set + attribute_set；P2 起用 `BattleActor`）→ grant 一个同时挂 `PreEventConfig` + `NoInstanceConfig(trigger)` + `StatModifierConfig` + `ActivateInstanceConfig(GRANTED_SELF, periodic timeline)` 的 ability → tick 几帧让 `AbilityExecutionInstance` 存在并 fire 过 action → 对 instance / actor / ability_set / tag_container / ability / 每个 component / execution instance / event_processor / event_collector 各取 `weakref` → `destroy_instance`（P4 后 `shutdown`）→ **把测试自己的所有局部强引用置 null** → 断言每个 `weakref.get_ref() == null`（RefCounted 计数归零即时释放，无需等 GC）。第二个用例走 `start_battle` + 录像开启，覆盖 `BattleProcedure` / `BattleRecorder` / `RecordingContext` / 订阅闭包，`battle_finished` 后同样断言全部释放。后续阶段每引入新的持引用对象（P3 context 携带 instance、P4 recorder 注入、P5 `PostHandlerRegistration` 与 `_post_unregisters` 闭包）就往两个用例里加 weakref。任何一个断言失败 = 本阶段不通过，先修再走后面关卡。
- **泄漏直方图**：P1 开工前先烤基线——对 4 个代表场景用 `--verbose` 跑一遍，按类统计 `Leaked instance:` 行：

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

  基线四份直方图提交到 `docs/plan/lgf-core-refactor-2026-09-leak-baseline/<s>.hist.txt`（P1 随主仓 commit）。每阶段验收时重跑同一脚本，`diff` 基线：LGF 类（`GameplayInstance` / `WorldGameplayInstance` 子类 / `BattleActor` 子类 / `AbilitySet` / `Ability` / `*Component` / `AbilityExecutionInstance` / `EventProcessor` / `EventCollector` / `BattleProcedure` / `BattleRecorder` / `RecordingContext` / `*Registration`）计数**只许持平或下降**，出现新类名或上升即为回归，用释放测试定位后再过关。非 LGF 的既有泄漏（Node / 渲染资源）不在本轮修，但记进 §6「后续观察」。

**三关顺序**：
1. 全量测试组全绿 **且** 释放测试绿 **且** 泄漏直方图不增。
2. **一致性核对**：对照本阶段「完成定义」逐条勾选；任何偏离写进 §6「偏离记录」（做了什么 / 为什么 / 影响）。
3. **`/code-review max`**（Skill `code-review`，args `max`）。注意 code-review 靠 git diff 找改动，submodule 内容在主仓只显示为指针：先在 submodule 内 commit（不 push），主仓工作区不提交，跑 `/code-review max addons/logic-game-framework`（路径目标）+ `/code-review max`（主仓工作区）；若 review 输出的文件清单没有 addon `.gd`，用 `mcp__ccd_directory__change_directory` 切到 `addons` 目录重跑（submodule 自身是 git 仓，`HEAD~1..HEAD` 即本阶段 diff），完事切回。找到的问题修完 → 重跑第 1 关 → 再 review 直到无新发现；有意不修的写进偏离记录。

**文档与 skill**（每阶段，随 submodule commit 一起）：
- `addons/logic-game-framework/CHANGELOG.md` `[Unreleased]` 段按 Added / Changed / Fixed / Removed 分类，每条写 **API 变化 + why**（格式见文件头）。
- 各阶段列出的 `docs/README.md` / `docs/reference/*` / hex README 段落。
- submodule commit 后执行 `/update-lgf-skill`（读取 `.claude/skills/enforcing-lgf/update.json` 的 `last_commit` 增量更新 reference 文档，并写回 `update.json`）；若存在 `.agents/skills/enforcing-lgf` 镜像目录则同步复制。skill 改动随主仓 commit。
- 源码注释只讲现状不讲历史（LGF `CLAUDE.md` 规则），历史归 CHANGELOG。

**提交协议**：
1. 首次（P1）：`git -C addons fetch origin`；确认 `git -C addons rev-parse origin/master` == 当前 HEAD（a4730a1），是则 `git -C addons checkout -B master origin/master`；不是则停下问用户。之后各阶段开工先 `git -C addons status -sb`（须干净、在 master）+ `git -C addons pull --ff-only`。
2. submodule：`git -C addons add -A && git -C addons commit -m "refactor(lgf): P<n> <标题>"`（Conventional Commits，正文列 API 变化）→ `git -C addons push origin master`。
3. 主仓：`git add addons inkmon docs scripts .claude tests` 等相关路径 → `git commit -m "refactor: LGF P<n> <标题> (addons → <short sha>)"` → `git push origin master`。主仓 `.mcp.json` 的既有改动与 `content/art/units/inkmon-units-infernace/` 未跟踪目录**不属于本计划，不要带进 commit**。
4. 分支：一律 master，不开 feature 分支。
5. 更新仓内计划 §6 状态行（两仓 SHA）并随主仓 commit 一起提交。

**踩坑清单**（来自记忆，执行前读一遍）：
- submodule 存量文件**别用 `sed -i`**（整文件 CRLF↔LF 翻转出假 diff），批量替换用 `perl -i -pe`；改前 `git -C addons diff --stat` 核对行数合理。
- Bash tool 是 git-bash/POSIX；`.ps1` 走 PowerShell tool。别 `godot --script`；别 `godot … | grep`，一律 `> file 2>&1` 再读。
- **并行 tool call 一个 errored 全批取消**：测试 runner、可能 0 命中的 grep、探查性 python 单独发。
- GDScript `static var` 持含 Callable 的 RefCounted → headless 退出段错误（PASS 打印后才崩）；新增静态缓存用 `static func` 线性扫。
- 引用 LGF 字段/方法前先 grep/read 真实定义；改完必跑 `.tscn` smoke。
- `attribute_set.hp = x` 无 setter 静默吞（P8 之前仍如此）；写属性走 `set_*_base`。
- 改 `.gd` 时 `enforcing-lgf` / `gdscript-coding` skill 会自动触发，遵守其 14 条规范（类型标注、`_` 前缀未用参数、`Log.assert_crash`）。

## 3. 阶段

依赖关系：P1 独立热身；**P2 → P3 → P4 → P5 是一条链**（BattleActor 给 core 真类型 → 去 provider 参数 → 事件基础设施进 instance → post 订阅依赖 instance 级 processor 与 actor 钩子）；P6 / P7 / P8 / P9 各自独立，按爆炸半径升序排列。

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
   - core 切换点：`gameplay_instance.gd:75`（自身字段）；`ability_set.gd:22 get_event_processor`（`get_owner_instance().event_processor`，null 安全）；`ability_execution_instance.gd:187`、`no_instance_component.gd:92,117`（instance.event_collector）；`active_use_component.gd:97`（`ctx.instance.event_collector`，null 守卫）；`pre_event_component.gd:109`（经 `actor.get_owner_gameplay_instance()`）；`battle_procedure.gd:129`（`_get_world().event_collector.flush()`）；recorder 改注入：`BattleRecorder._init(config, event_collector)`（`BattleProcedure.start()` 传 `_get_world().event_collector`）、`RecordingContext._init(actor_id, recorder, collector)`（属性变化高频路径不走 registry 查找）。
   - stdlib：`ProjectileSystem` 已是注入式；11 处构造（hex demo GI:59、skill_preview:2682、harness:600、8 个 skill-preview smoke）改传 `world.event_collector`。
   - example / inkmon：`HexWorldGameplayInstance.broadcast_projectile_events`（自身字段）；`hex_battle_procedure.gd:245` / `skill_preview_procedure.gd:228`（`world.event_collector`）；hex damage/heal/poison/regenerate/strike/`hex_battle_damage_utils` 与 inkmon damage/heal/`ink_mon_battle_damage_utils` 的 `GameWorld.event_processor` → `battle.event_processor`；dota2 procedure ×4 / wave spawner / creep controller → `world.event_collector`；dota2 damage action → `world.event_processor`；`ink_mon_world_gi.gd:898`（自身）；harness:221/371；`smoke_summon_spike.gd:172/181`；`smoke_battle_math.gd:117`（`gi.event_processor`）。
   - `pre_event_component_test` 改为 `MockInstance` 传 `EventProcessorConfig.new(10, 2)` 给 `super._init`，调 `env.instance.event_processor.process_pre_event(event)`。
2. **C2 生命周期（约 60 文件，纯机械）**：`GameWorld` 删 `init / destroy / initialize / _ensure_initialized / _ready / _initialized / event_processor / event_collector`，保留 `_instances、create_instance、get_instance_by_id、get_instances_by_type、destroy_instance、destroy_all_instances、tick_all、get_instance_count、has_running_instances、get_debug_info、get_actor、get_instance_of_actor、shutdown()`（幂等：end all + clear）；51 处 `GameWorld.init(...)` 与 43 处 `destroy()` 改 `shutdown()`（测试两端各一次）；inkmon 夹具收敛：`InkMonWorldGI._init` 传 `EventProcessorConfig.new(20, 0)` 给 `super._init`（max_depth 20 是世界属性），`ink_mon_world_host.gd:47` 与 13 个 inkmon smoke 去掉参数。

**测试**：`tests/core/events/event_processor_test.gd`、`pre_event_component_test.gd` 改 instance 级；`tests/core/world/world_test.gd` 覆盖 `shutdown` 幂等与 instance 自持 processor；跑全量组。

**文档**：CHANGELOG Changed（breaking：processor/collector 归 instance、handler 按 instance 隔离、recorder 注入、`GameWorld.init/destroy → shutdown`、trace 默认 0）；`docs/README.md` §5 样例、「World owns Battle (c)」录像句（「统一汇入 world 的 collector」）、设计铁律「录像顺序」条；LGF `AGENTS.md`/`CLAUDE.md` mermaid（Collector/Processor 挂 GameplayInstance）；skill `reference/{entity,events}.md`、`conventions-detail.md §7`。

**行为变化**：pre handler 按 instance 隔离（hex demo 与 skill-preview 共存时不再串表）；owner 未 `add_actor` 就 grant `PreEventConfig` 会打既有「EventProcessor not available」警告而非静默全局注册（生产路径全在注册后 grant）。

**循环引用要点**：新的强边 `GameplayInstance → EventProcessor → PreHandlerRegistration → lambda`、`GameplayInstance → BattleProcedure → BattleRecorder → EventCollector`、`RecordingContext → BattleRecorder`（既有）。必须保证：`EventProcessor` **不**持 instance 强引用（若需要则 `_instance_ref: WeakRef`）；`register_pre_handler` 返回的注销闭包引用 `_pre_handlers` 即捕获 processor 自身——它被 `PreEventComponent._unregister` 强持有，方向 component → processor 与 instance → processor 同向，不成环，但 processor 决不能反向持 Ability / Component；`EventCollector` 只存 dict，不得引用发射者。释放测试第二用例此时必须覆盖 recorder 注入路径（`BattleRecorder` / `RecordingContext` / 每个 actor 的 unsubscribes 闭包）并断言 `shutdown()` 后 instance 级 processor / collector 释放。

**完成定义**：`grep -rn "GameWorld.event_\|GameWorld.init(\|GameWorld.destroy(" addons/logic-game-framework inkmon scripts --include=*.gd` 零命中；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

### P5 Post 事件订阅制（刀 1）

**目标**：`process_post_event(event_dict)` 无观众；被动 = 字面意义的订阅；死者策略归项目钩子。

**改法**（按 Plan agent 设计，核心文件 `core/events/event_processor.gd`、`core/abilities/core/ability.gd`、`core/entity/Actor.gd`）：
1. **核心翻转（一步内完成，hex/dota2/inkmon 仍能编译）**：
   - `AbilityComponent.get_post_event_kinds() -> Array[String]` 虚函数默认 `[]`；`NoInstanceComponent` / `ActivateInstanceComponent`（含 ActiveUse）返回 `_triggers` 的去重 `eventKind`。
   - 新建 `core/events/post_handler_registration.gd`（镜像 `PreHandlerRegistration`）：`id`（`"%s_post_%s" % [ability_id, kind]`）、`event_kind`、`owner_id`、`ability_id`、`config_id`、`handler: Callable`（`func(event_dict, ctx: HandlerContext) -> bool`，true = 至少一个 component 触发，仅 trace 用）、`handler_name`，processor 赋 `owner_seq`、`seq`。**无 filter 字段**：`TriggerConfig.filter` 仍在 `AbilityComponent.match_triggers` 内评估。
   - `HandlerContext` 加 `event_processor: EventProcessor`（派发时设置）。
   - `AbilityLifecycleContext.rebuild_for_handler(owner_id, ability_id, event_dict, phase, event_processor) -> AbilityLifecycleContext` 静态方法：actor 反查 → `actor.is_event_responsive(event_dict, phase)` → `BattleActor.ability_set_of` → `find_ability_by_id` → attribute set；任一失败返回 null。`PreEventComponent._rebuild_context` 删除改调它。
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

### P6 Action / Config 收口（刀 8）

**目标**：Action 只剩两类；Condition 不再白背组件生命周期；ActiveUse 与 ActivateInstance 配置层级镜像组件层级。

**改法**：
1. `core/actions/Action.gd`：删 `PrimitiveAction`、`FlowActionBase`，`FlowAction.IfAction extends BaseAction`；`execute_child` 保留；文件头「四层合同」表改为「两类」。16 处 `extends Action.PrimitiveAction`（inkmon 7、hex 5、core 2 内嵌、测试 2）改 `extends Action.BaseAction`；`SkillLocalAction` 不动。
2. 删 `core/actions/action_architecture_validator.gd` + `tests/core/actions/action_architecture_validator_test.gd` + `run_tests.gd:30` 登记；删 `core/actions/tag_action.gd` + `tests/core/actions/tag_action_test.gd`（生产零调用）。
3. `core/abilities/shared/condition.gd`：`extends RefCounted`（7 个子类均未用组件 API，已核实）；保留 `_freeze/_verify_unchanged`。
4. Config 合并：`ActiveUseConfig extends ActivateInstanceConfig`（删重复字段，只留 `conditions` / `costs`）；`ActiveUseConfigBuilder extends ActivateInstanceConfigBuilder`，`trigger / trigger_mode / timeline / on_tag / on_timeline_start / on_timeline_end` 用协变返回覆盖（`-> ActiveUseConfigBuilder`，调 super）；`build()` 返回 `ActiveUseConfig`。`AbilityConfig`：删 `active_use_components`，`components: Array[AbilityComponentConfig]` 一个列表，`AbilityConfigBuilder.active_use(cfg)` 保留为追加到 `_components` 的别名（37 处调用不动）；加 `get_active_use_configs() -> Array[ActiveUseConfig]`（按类型过滤）供 `scripts/SkillValidator.gd`（5 处）、`skill-preview/hex_battle_skill_index.gd`（3）、`skill_preview_validation.gd`（2）、`skill_preview.gd`、`hex_random_demo_world_gameplay_instance.gd`（2）、`scripts/runtime_script_test.gd`（2）、`smoke_manifest_lint.gd`（3）、`tests/skill_validator/smoke_skill_validator.gd` 改用；`_resolve_components` 与 `collect_timelines` 简化为单列表遍历（`ActiveUseConfig is ActivateInstanceConfig` 自动覆盖）。
5. `docs/reference/action-architecture.md` 「四层分层合同」与 validator 段重写为两类 + 目录规则（公共 action 目录只放通用原语；技能私有一律内嵌 `_XxxAction extends SkillLocalAction`，不得 `class_name`）；`enforcing-lgf/reference/actions.md:18`。

**测试**：`tests/core/abilities/` 中构造 `ActiveUseConfig.new(...)` 的测试改新构造顺序；加一条 builder 测试（`ActiveUseConfig.builder().timeline(tl).on_tag(...).condition(c).build()` 类型为 `ActiveUseConfig` 且 `is ActivateInstanceConfig`）。跑全量组 + `main/validator`。

**文档**：CHANGELOG Removed / Changed；`docs/README.md` 「Action 四层」引用处；hex README 「Action 分层」段；skill `reference/actions.md`、`abilities.md`。

**行为变化**：无运行时行为变化；失去 validator 门禁（由目录规则 + review 顶上）。

**完成定义**：`grep -rn "PrimitiveAction\|FlowActionBase\|ActionArchitectureValidator\|TagAction\.\|active_use_components" --include=*.gd --include=*.md` 全仓零命中（CHANGELOG 除外）；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

### P7 事件 dict key 统一 snake_case（刀 7）

**目标**：唯一跨层契约一种拼写；机器守门。

**改法**：
1. `core/events/game_event.gd`（24 个 payload key：`actorId, abilityInstanceId, abilityConfigId, sourceId, triggeredComponents, triggerEventKind, timelineId, targetActorIds, targetActorId, sourceActorId, projectileId, oldValue, oldStacks, oldCount, newValue, newStacks, newCount, logicTime, hitPosition, flyTime, flyDistance, failedComponentType, executionId, cueId`）、`stdlib/projectile/projectile_events.gd`（`projectileId, flyTime, flyDistance, hitPosition, startPosition, targetPosition, finalPosition, piercePosition, pierceCount, projectileType`）、其他发射点（`raw_attribute_set.gd` 的 `attributeName`，`ability.gd:386-390` 的 `abilityTags/maxStacks/overflowPolicy`，`ability_execution_instance.gd:200` 的 `triggeredTags`，`battle_recorder.gd:176` / `recording_utils.gd:93` 的 `instanceId`，`customData / visualType / eventKind / expiresAt / traceId / parentTraceId / handlerId / handlerName / modifierType / sourceName / scalesByStacks / loopsCompleted`）、`core/playback/playback_data.gd`（`battleId, recordedAt, tickInterval, totalFrames, mapConfig, positionFormats, configId, displayName`）全部改 snake_case。**kind 字面量**（`attributeChanged` 等 13 个 + projectile 5 个）也改 snake_case（`attribute_changed`…），与 hex/dota2/inkmon 的 `damage` / `inkmon_damage` 风格对齐。
2. 消费端约 437 处读取（addon core+stdlib 100、example 测试 133、hex frontend 21、addon 测试 12、inkmon 10、skill-preview 6）：`perl -i -pe` 批量 + 逐文件 `git diff` 核对；11 个生成的 attribute set 文件**不手改**，改生成器模板后用 headless `addons/logic-game-framework/scripts/generate_attribute_sets.tscn` 重生成（退出码 0）。
3. `inkmon/logic/battle/ink_mon_battle_procedure.gd:148-165` 手拼的激活 dict 改用 `GameEvent.AbilityActivate.create(...)`。
4. 守门：新增 `tests/core/events/event_key_casing_test.gd`：对 `GameEvent` 每个内嵌类与 `ProjectileEvents` 每个工厂用哑参构造，`to_dict()` 的所有 key（递归一层）匹配 `^[a-z0-9_]+$`；hex `smoke_manifest_lint` 可选加同断言覆盖 `BattleEvents`。
5. `scripts/SimulationManager.gd:62-64` 债务注释更新：JS 解析器需同步 snake_case + v3。

**测试**：hex 70 scenario 与 `smoke_battle_golden` 指纹会变：先用 `git diff` 证明变化仅为 key 改名，再重烤 golden；跑全量组 + `inkmon/battle-2d`、`inkmon/mission`。

**文档**：CHANGELOG Changed（breaking：录像/事件 key snake_case；旧录像文件不兼容，录像是短命数据）；`docs/README.md` 「序列化约定」节改为 snake_case；skill `reference/events.md` 全部样例；hex `logic/docs/logic-to-presentation-guide.md` 样例；`scripts/CLAUDE.md` 加一句协议说明。

**行为变化**：录像 JSON 形状变化（旧文件不可播）；`kind` 字符串变化影响任何按字面量匹配的消费者（已全常量化，lint 兜底）。

**完成定义**：`grep -rnE '"[a-z]+[A-Z][A-Za-z]*":' addons/logic-game-framework/core addons/logic-game-framework/stdlib --include=*.gd` 零命中；casing 测试绿；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

### P8 资源型属性（刀 6）

**目标**：hp 是资源不是派生值；扣血不再全属性重算。

**改法**：
1. 属性 config 语法：`"hp": { "kind": "resource", "baseValue": 100.0, "minValue": 0.0, "maxRef": "max_hp" }`（三份含 hp 的 config：`logic-game-framework-config/attributes/attributes_config.gd` 的 `InkMonUnit`、hex `HexBattleActor`、dota2 `Dota2BattleActor`）。
2. `core/attributes/raw_attribute_set.gd`：`define_resource(name, initial, min_value, max_ref)`，`_resource_values: Dictionary`；`set_resource(name, value)`（clamp `[min, max_ref 当前值]`，变化才 `_dispatch_event`，**不**跑 `_snapshot_all_values` / 动态求解）；`add_resource(name, delta)`；`get_current_value` 对资源返回存值；`add_modifier` / `update_modifier` 指向资源 → `assert_crash`；任何 stat 入口方法结束后对所有资源按 `max_ref` 重 clamp（max_hp 下降拉低 hp，沿用 `register_cross_attr_clamp` 的语义，改为资源专用实现）；`serialize` / `deserialize` 含资源值；`get_breakdown` 对资源返回 `AttributeBreakdown.from_base(value)`。
3. 生成器 `scripts/attribute_set_generator_script.gd`：资源属性生成 `var hp: float`（getter）、`set_hp(v)`、`add_hp(delta)`、`on_hp_changed`、`const hp_attribute`，**不**生成 `_breakdown` / `set_hp_base`；`maxRef` 对资源生成 `define_resource` 而非 `register_cross_attr_clamp`；`_validate_clamp_direction` 逻辑对资源保留。重生成 11 个 set，逐字节核对只有 hp 相关行变化。
4. 17 处生产 `set_hp_base(` → `set_hp(` / `add_hp(`（`hex_battle_damage_utils.gd:87`、`heal_action.gd:108`、`regenerate_action.gd:81`、`spawn_actor_action.gd:74`、`ink_mon_battle_damage_utils.gd:30`、`ink_mon_unit_actor.gd:94,129,334`、`dota2_damage_action.gd:64`、`stone_wall.gd:34`、`fire_tile.gd:35`、`character_actor.gd:58` 等）+ 19 处测试。
5. 文档化「资源 vs 数值」：`docs/README.md` 属性节加一段；hex `docs/reference/damage-pipeline.md` ⑥ 步改 `set_hp`。

**测试**：`tests/core/attributes/attribute_set_test.gd` 的 21 行 hp modifier 用例改成对 stat 属性（如 `atk`）+ 新增资源用例（clamp 到 max_ref、max_hp 下降拉低 hp、加 modifier 到资源 crash、`set_resource` 不触发其他属性通知）；`attribute_set_generator_test.gd:83` clamp 断言改为 `define_resource` 行。跑全量组（`inkmon/m1` 数值 golden 必须不变）。

**行为变化**：数值应完全一致；`AttributeChanged` 事件流应一致（只在 hp 真变时发）；性能：扣血不再全属性重算。

**循环引用要点**：`RawAttributeSet` 仍只存 String（`register_cross_attr_clamp` 的「不存 Callable」纪律延续到资源 clamp）；`on_hp_changed` 返回的注销闭包捕获 raw set 自身，由调用者持有，方向与今日一致。

**完成定义**：`grep -rn "set_hp_base" --include=*.gd` 零命中；生成文件重生成后 `git diff` 只含 hp 行；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

### P9 grid 出 core → stdlib，inkmon 双 grid 退役（刀 5）

**目标**：core 不依赖 ultra-grid-map；inkmon 不再翻转基类 grid。**submodule 一次 commit（stdlib 新增 + hex + core 剥离），随后主仓一次 commit（inkmon + 指针）**，中间 inkmon 编译不过是预期的，不要拆开验收。

**改法**：
1. `stdlib/grid/grid_world_gameplay_instance.gd`：`class_name GridWorldGameplayInstance extends WorldGameplayInstance`；从 core 原样搬 `signal actor_position_changed(actor_id, old_coord: HexCoord, new_coord: HexCoord)`、`signal grid_configured(config: GridMapConfig)`、`signal grid_cell_changed(coord: HexCoord, change_type: String)`、`var grid: GridMapModel`；`configure_grid(config)`（建 model + initialize → 委托 `configure_grid_model`）；`configure_grid_model(model)`（从 inkmon 上提：`grid = model; grid_configured.emit(model.get_config())`，唯一 emit 点）；`_get_map_config() -> Dictionary`（`grid.to_config_dict()`，null 则 `{}`）；`clear_grid_footprint(actor)`（`IGridOccupant.get_grid_position(actor)` 有效时 `occ is Object and occ == actor` 才 `remove_occupant`，再扫 `get_all_coords()` 取消该 actor 的 reservation；**不用** `GridMapModel.find_occupant_position`，它对 Variant 无守卫 `==`）；`remove_actor(actor_id)`（`super.get_actor` 取 actor → `clear_grid_footprint` → `super.remove_actor`）。
2. `stdlib/grid/i_grid_occupant.gd`：`class_name IGridOccupant`，`static func get_grid_position(actor: Actor) -> HexCoord`（`"hex_position" in actor` 则取值，否则 `HexCoord.invalid()`）。hex `HexBattleActor.hex_position` 与 inkmon `InkMonWorldActor.hex_position` 天然满足。
3. core `core/entity/world_gameplay_instance.gd`：删 `grid`、`configure_grid`、三个 signal；`capture_world_snapshot()` 改 `snap.map_config = _get_map_config()`，加虚 `_get_map_config() -> Dictionary: return {}`。`actor_position_changed` **整体离开 core**（它携带 HexCoord 就是 grid 概念；core 零发射零消费）。
4. hex：`hex_world_gameplay_instance.gd` 改 `extends GridWorldGameplayInstance`，`configure_grid` 覆盖保留为 UGridMap 桥（`UGridMap.configure(config); configure_grid_model(UGridMap.model)`）；删 `remove_actor` + `_find_reservations_by`；`hex_battle_damage_utils._clear_grid_footprint`（:147-155）改调 `battle.clear_grid_footprint(dead_actor)`；`frontend/world_view.gd:44 bind_world(world: GridWorldGameplayInstance)`；harness `:593-595` 用 `configure_grid`、`:646-647` 用 `_get_map_config()`。dota2 不动（`map_config` 仍 `{}`）。
5. inkmon `inkmon/logic/world/ink_mon_world_gi.gd`：`extends GridWorldGameplayInstance`；头注释 `:6-12` 改「固定分工无翻转」；删 `:63 overworld_grid_model`、`:289-290`（`grid = overworld_grid.model`）、`:743-755` 两个 `configure_grid*` 覆盖（inkmon 从此**不写 UGridMap**，已核实 inkmon/scripts/渲染器无人读 UGridMap）、`:758-762 remove_actor` 覆盖、`:887-890` 翻回；加 `get_battle_grid() -> GridMapModel: return grid`（accessor，不是第二字段）；`:441-443` 注释精简（守卫保留）；不覆盖 `_get_map_config`（快照只在 `start_battle` 内取，此时 grid 即战斗棋盘）。
6. inkmon 19 处战斗侧 `grid` 读取改 `get_battle_grid()`：`ink_mon_battle_setup.gd` `:119(×2),123,129,130(×2),143(×2)`（每函数 hoist 一个 `var board := gi.get_battle_grid()`）；删 `find_reservations_by`（:149-156）与 `clear_actor_footprint`（:162-173），其 3 处调用者改 `gi.clear_grid_footprint(actor)`（`ink_mon_battle_damage_utils.gd:44`、GI `:761`（随覆盖删除）、GI `:901`）；`ink_mon_ai_strategy.gd:73-78` hoist 一次；`ink_mon_apply_move_action.gd:27` / `ink_mon_start_move_action.gd:26`；`inkmon/tests/smoke_wild_battle.gd:71`。`InkMonBattleSetup.configure_battle_grid`（:186-199）主体不变（调用的已是 stdlib 方法），注释 `:184` 更新。

**测试**：hex 12 处 `configure_grid(` 测试调用与 `tests/smoke_skill_preview_environment.gd` 靠继承零改动；inkmon 只改 `smoke_wild_battle.gd:71`；`smoke_tick_movement.gd` 必须保持绿。跑全量组（含 `inkmon/session`、`inkmon/battle-2d`）。

**文档**：CHANGELOG Changed（grid 成 stdlib 电池、core 只留 `_get_map_config()`、dota2 不再白带）；`docs/README.md:789` 未来规划条 → 已知债务 ✅，`:317` 目录树加 `stdlib/grid/`；LGF `AGENTS.md`/`CLAUDE.md` mermaid 加 `Grid[GridWorldGameplayInstance]`；`docs/main-game-architecture.md` `:86`（`overworld_grid` 必留 → 分工固定，`get_battle_grid()` 是唯一战斗侧读名）、`:117` ⚠️ → 已解决、`:263/:265` §9；skill `reference/entity.md`（WorldGameplayInstance 去 grid，新增 GridWorldGameplayInstance 节）。

**行为变化**：inkmon 不再配置 UGridMap；`gi.grid` 在战斗外是上一场棋盘或 null（今日零处此类读取）；`_reset_battle_state` 清理现在真的清上一棋盘的占用（此前对 overworld model 静默 no-op）；hex `remove_actor` 清理条件从 `is HexBattleActor` 变「有 hex_position」（同集合）。

**循环引用要点**：`GridWorldGameplayInstance.grid` 是 instance → model 的向下强边；`GridMapModel` 的 occupant 表存的是 actor 引用（instance → grid → actor，与 registry 同向，不成环），但 **actor 死亡/移除必须清 occupant**，否则 grid 持尸体到 instance 结束——`clear_grid_footprint` 在 `remove_actor` 里保证这一点；释放测试第二用例加 `grid` 的 weakref。`BattleProcedure` 对 `world.actor_added` 的 signal 连接是 world → procedure 的强边，与 `_active_battle` 同向，`finish()` 断开（既有）。

**完成定义**：`grep -rn "HexCoord\|GridMapModel\|GridMapConfig\|UGridMap" addons/logic-game-framework/core --include=*.gd` 零命中（注释除外）；`grep -n "overworld_grid_model\|configure_grid_model\|grid = " inkmon/logic/world/ink_mon_world_gi.gd` 只剩预期项；释放测试绿、直方图不增；全量组绿；三关；push；§6。

---

## 4. 明确不做（本轮认可的既有决策，勿重开）

- 刀 9 表演管线上提（render_world / scheduler / visualizer 注册表 / VisualAction 进 LGF `presentation/`）：另开计划，前提是先对齐 hex 3D 与 inkmon 2D 两份分叉。
- 不做 B 层 deterministic Replay；Playback 不重建逻辑层（铁律不变）。
- 不把 hex 的死亡语义（留尸体）或 dota2 的（tick 末移除）写进 core；core 只给钩子。
- 不引入 handler 优先级；pre/post 派发顺序 = 注册顺序（owner registry 序 → grant 序 → component 序）。
- 不重命名 `BattleRecorder` 家族、`assert_replay` DSL、`playback_*` signal。
- 不做 timeline 数据驱动（技能保持脚本形态，2026-07-02 拍板）。
- 不给 `GameplayInstance` 之外再造"多 instance 并行"设施；P4 只是把状态放对位置。

## 5. 启动指令（每阶段粘贴给新会话）

P1（首阶段）：

```
按 docs/plan/lgf-core-refactor-2026-09.md 执行 P1。先读 §0–§2 与 P1 全文，再读 addons/logic-game-framework/CLAUDE.md 与 docs/README.md 相关节；改 .gd 前遵守 enforcing-lgf / gdscript-coding skill。P1 的前两步是泄漏基线与释放测试，先做再删代码。验收按 §2 三关，通过后按 §2 提交协议两仓 commit + push（计划文件本身随主仓首次提交），最后更新 §6 状态行并提交。
```

P2 及之后：

```
按 docs/plan/lgf-core-refactor-2026-09.md 执行 P<n>。先读 §0–§2、§6 与 P<n> 全文，再读 addons/logic-game-framework/CLAUDE.md 与 docs/README.md 相关节；开工前 git -C addons status -sb 须干净且在 master。验收按 §2 三关，通过后两仓 commit + push，更新 §6 状态行并提交。
```

执行会话的纪律：只做本阶段范围，发现范围外问题记进 §6「后续观察」不顺手修；每个阶段的「完成定义」是验收清单；文档与 skill 更新是阶段的一部分，不是可选项。

## 6. 状态与偏离记录

| 阶段 | 状态 | submodule SHA | 主仓 SHA | 备注 |
|---|---|---|---|---|
| P1 减法热身 | 已完成 2026-09-10 | `f1d132f` | `cdcc871f` | 基线 8e56bba 非 a4730a1，见偏离记录 ①；主仓先单独 `chore` bump 到 8e56bba（`bbe5d9a7`）再 P1。验收：86 scene 全 PASS / 释放测试绿 / 四份泄漏直方图与基线逐字节一致 / `/code-review max` 十角度已修 |
| P2 BattleActor | 已完成 2026-09-10 | `ec72e5a` | `cd0633ec` | 验收：86 scene 全 PASS（core 单测 173→187）/ 释放测试绿 / 直方图 core·hex·inkmon 与基线逐字节一致、dota2 **下降** 590→170 RefCounted（关掉本就播不了的 dota2 录像，基线已棘轮）/ `/code-review max` 十角度 + 修复后二次复审已合入。偏离见 ⑧–⑭ |
| P3 typed instance | 未开始 | | | |
| P4 instance 级事件设施 | 未开始 | | | |
| P5 Post 订阅制 | 未开始 | | | |
| P6 Action/Config 收口 | 未开始 | | | |
| P7 key snake_case | 未开始 | | | |
| P8 资源型属性 | 未开始 | | | |
| P9 grid 出 core | 未开始 | | | |

**偏离记录**（阶段 / 条目 / 做了什么 / 为什么 / 影响）：

- ① P1 / 提交协议 1 / `origin/master` 已是 `8e56bba`（用户 09-07 的 merge，带入 7 月上游 LGF 提交：`can_activate` 纯查询、`DecisionOutcome`、`add_system` (priority, 注册序) 双键、execution 取消清理 + `on_cancel`、loop 余量结转、同刻 tag 定义序、`EventCollector.push` 深拷贝），不是计划写的 `a4730a1`。做法：本地 `master` 建在 `8e56bba`，改任何代码前先跑 §2 全量组（88 scene）全绿，主仓指针分两步——先单独 `chore: bump addons to 8e56bba`（`bbe5d9a7`），再 P1 commit；push 按协议「不是则停下问用户」留给用户确认后执行（顺序 addons 先、主仓后）。/ 为什么：`origin/master` 是唯一可 push 的基线，在 `a4730a1` 上做完再合并会在 P1 同一批文件（execution instance / component / 测试）上冲突。/ 影响：inkmon 首次钉住 7 月上游改动；`smoke_battle_golden` 指纹不变；后续阶段的行号引用以 `8e56bba` 之后为准。
- ② P1 / 改法 2 / 上游在 `8e56bba` 新增的 registry 依赖一并删除：`ActivateInstanceComponent` / `ActiveUseComponent` 的 `_is_timeline_available()`、`Ability.activate_new_execution_instance` 的 `TimelineRegistry.has` 守卫（原返回 null）、`AbilityActivationQuery.FAILED_TIMELINE` 与 `active_use_query_test._test_missing_timeline`（概念随 registry 消失，删用例）；config 的 `timeline_id` 字段整个删除、不留派生属性，3 处读者改读 `timeline_data.id` / `timeline_data.total_duration`（`SkillValidator` ×2、`skill_preview_validation`）。/ 为什么：计划按 `a4730a1` 写，看不到上游新增点；「一种拼写」优于再造一个只读投影。/ 影响：无运行时差异（timeline 缺失路径已由 build 期 crash 覆盖）。
- ③ P1 / 改法 7 / 泄漏直方图只能按原生类计数：Godot 4.6 `--verbose` 的 `Leaked instance:` 行只带 `RefCounted` / `Node` / `GDScript` / `WeakRef` 等原生类名，不带脚本类名，LGF 类逐类计数不可得；四份基线 + `README.md` 已提交，验收判据改为「原生类计数不增（P1 后四份与基线逐字节一致）+ 释放测试 weakref 断言」。/ 为什么：引擎输出格式限制。/ 影响：后续阶段沿用同一判据；LGF 对象释放的精确仪器只有 `refcount_release_test.gd`。
- ④ P1 / 测试 / 上游新增的 3 个 loop 测试、2 个 execution 测试与 `active_use_query_test` 夹具一并迁直传（计划列 5 / 7 处，实际 8 / 9 处 + 1 个新文件）；`timeline_test.gd` 除计划要求的定义序测试（上游已有 `_test_sorted_tags_tie_break`）外补一条纯时间序测试，顶替原 `_test_register` 顺带覆盖的 `get_sorted_tags` 基本路径；`tests/skill_validator/smoke_skill_validator.gd` 加了可选的 `result.timeline` 恒有值断言。/ 为什么：覆盖不缩水。/ 影响：无。
- ⑥ P1 / 验收第 3 关 / `/code-review max` 十角度跑完后合入 20 处修复，其中两处**超出计划的 hex-only 范围**：把 timeline 静态检查收成 core 的 `AbilityConfig.lint_timelines(configs)`，并新增 `inkmon/tests/smoke_skill_manifest_lint`（注册为 `inkmon/skills` 组）。/ 为什么：D9 原文只说「降级为 hex manifest lint」，但五个角度独立指出——registry 一删，主游戏与 dota2 的 timeline id 唯一性、`validate()`、tags 冻结三项检查全部落空（`collect_timelines()` 在主仓零调用点），复制技能文件忘改 `TIMELINE_ID` 会让两个技能在录像里共用一个 `timelineId` 且全程零报错。守卫只长在 hex 一家，等于主游戏裸奔。/ 影响：core 新增一个 static 查询 API（不进存档、不参与执行期）；inkmon 测试组多一个 ~1s 的 smoke，自带「注入同 id 异实例必须报红」的自证；dota2 只有单个 ability、无 manifest，仍未覆盖（见后续观察）。
- ⑦ P1 / 验收第 3 关 / review 抓到两处**由前一轮 review 修复自己引入的回归**，已在同一轮内改掉：① efficiency 角度建议把 lint 的 `validate()` / 冻结检查挪进「首次见到该 id」分支省重复，但这样一来同 id 的**第二个**实例（正是最该查的那个）永远不被校验，且覆盖面变成依赖 manifest 的 append 顺序——改为按**实例**去重（`get_instance_id()`），共享节奏仍只查一次，异实例一个不漏；② conventions 角度要求 `var frames: Array` 补元素类型，但 `battle_finished` 未发时 `Dictionary.get` 返回的是无类型空 `Array`，直接赋给 `Array[Dictionary]` 会抛类型转换错、把干净的断言失败换成引擎报错——改用 `frames.assign(...)`。/ 为什么：记录下来是因为这类「按单一角度的局部建议改，破坏另一维度」的模式会在后续阶段重演。/ 影响：无。
- ⑤ P1 / 文档与 skill / `/update-lgf-skill` 命令本机不可用（`grep -P` 在当前 locale 不支持；其 diff 路径 `addons/logic-game-framework/` 对主仓只是 gitlink；`update.json.last_commit` 记的主仓 SHA 对应的 addons 指针 `13615b2` 已随 Tiny Swords 历史清理消失），改为手动等价执行：以日期等价基线 `e583e80..60d2318` 的 addons diff 增量更新 `enforcing-lgf/reference/*.md` 并镜像到 `.agents/`，`update.json.last_commit` 记 P1 主仓 commit。/ 为什么：命令坏了，不在本阶段顺手修。/ 影响：记入后续观察待修。

- ⑧ P2 / 改法 1「可选吸收 team_id」/ 吸收了 `team_id` + `set_team_id` / `get_team_id` + `_get_team_int`，并给 hex `EnvironmentActor` 补了一句显式 `_get_team_int() -> 0`。/ 为什么：三家子类的 `_get_team_int()` 逐字相同（都返回 team_id / 未入队 -1），不吸收就是三份副本；但 `Actor` 的默认实现是解析字符串 `_team`，从不 `set_team_id` 的 hex 环境物靠它录成 `0`，基类直接返回 `team_id` 会把它们悄悄变成 `-1`（表演层按 team 上色）。1 处显式特例换掉 3 份复制。/ 影响：全仓唯一真的变了 recorded team 的是 inkmon 玩家 / NPC（`InkMonWorldActor` 现在是 `BattleActor`，0 → -1）——它们被 `should_record_actor` 挡在录像外，当前不可观测，已在 `ink_mon_world_actor.gd` 类注释里记下。
- ⑨ P2 / 行为变化「dota2 录像接受」/ 计划写「若 frame 体积成问题再覆盖回空 `setup_recording`」，实际改为 `Dota2AutoBattleProcedure._recording_enabled = false`（整个不建 recorder）。/ 为什么：三个 review 角度独立指出这不只是体积——① `attributeChanged` / `tagChanged` 与业务事件共用同一个 `event_collector`，会把 lane 场景那 14 行 debug 面板（M1 垂直切片的肉眼验收通道）里的 `damage` / `DIED` 挤出去；② 死兵走 `remove_actor` 而 recorder 没有对应的 `unregister_actor`，订阅会留到战斗结束；③ dota2 的录像本就播不了（开战快照在 spawn 之前拍恒空、无 `map_config`、无 `positionFormats`，`finish()` 返回值四个调用点全丢弃）。覆盖回空 `setup_recording` 只治 ①，治不了 ③ 的「录了也没用」。/ 影响：dota2 泄漏直方图 590 → 170 RefCounted、66 → 61 GDScript，基线文件已按「下降要棘轮」更新（见 leak-baseline `README.md`）；`Dota2LogicFrame.events` 回到 P2 之前的内容。
- ⑩ P2 / 完成定义「三家 actor 基类各不再定义 `get_ability_set`」/ 三家仍各自定义 `get_ability_set()`（以及 `get_attribute_set()` / `get_attribute_snapshot()`）。/ 为什么：这三个正是 D4 指定的协变收窄出口——`HexBattleActor.get_ability_set() -> BattleAbilitySet` 让 hex 代码不必到处强转；`get_attribute_snapshot()` 各家录的字段本就不同（hex 只 hp/max_hp，inkmon 六维 + 身份），用 core 的全属性默认会改录像内容。真正下沉的是 `_is_dead` / `check_death` / `is_dead` / `mark_dead` / `is_pre_event_responsive` / `_on_id_assigned` / `setup_recording` / `get_ability_snapshot` / `get_tag_snapshot` / `serialize` / team 四件套。/ 影响：完成定义这条按「骨架成员」而非「所有同名方法」判定，CHANGELOG 已写明例外。
- ⑪ P2 / 改法清单外的 core 新增 / 加了三个计划没列的 core API：`BattleActor._hp_source()`（血条来源钩子，`has_hp` / `get_current_hp` 共用）、`BattleActor.set_death_latch(value)`（唯一解闩入口）、`Ability.has_executing_instance()`（不分配版本），并把 `RawAttributeSet._snapshot_all_values()` 提为 public `snapshot_current_values()`。/ 为什么：`_hp_source` 让「没血条」与「血条为 0」在一处分开（纯数据 actor 不被判成尸体）；`set_death_latch` 是因为 inkmon `sync_downed_state()` 要把闩拨回 false，没有这个入口它只能跨 submodule 直写基类私有字段 `_is_dead`；`has_executing_instance()` 是因为 `get_executing_instances()` 每次 `filter` 出一个新数组，而主循环每 actor 每 tick 只想知道有没有；`snapshot_current_values` 是因为 `BattleActor.get_attribute_snapshot()` 与 raw 内部的 before/after 对比需要同一份快照定义。/ 影响：core 多四个小 API，全部有测试覆盖。
- ⑫ P2 / 验收第 3 关 / `/code-review max` 十角度合入 20 处修复，其中三处**超出计划改法清单**：① `EventProcessor.process_post_event` 的 `assert_crash` 之后补 `continue`（assert 在 debug 下不接管控制流，不 continue 会紧接着对 null 调 `receive_event`，把清楚的报错埋进无关的引擎报错）；② hex `hex_battle_shield_resolver` ×2 与 `hex_battle_damage_utils` ×1 的 `"ability_set" in actor` 一并改真类型（完成定义只 grep `core/ stdlib/`，这三处本会逃掉，而它们「探不到就当没盾」是静默失效）；③ `GameWorld.get_actor()` 改走新的 `get_instance_of_actor()`，`{instance_id}:{local_id}` 的解析收成一处。/ 为什么：都是本轮「真类型化」自己该有的收尾，留着就是同一份改动里两套口径。/ 影响：无行为变化，测试全绿。
- ⑬ P2 / 验收第 3 关 / 修复轮自身引入并当场改掉的两处（延续 ⑦ 那个模式）：① 为省一次虚函数调用，`check_death()` 一度直接读 `_hp_source()` 而不走 `has_hp()` / `get_current_hp()`——这让「换属性名覆盖这两个虚函数」的合同当场失效（覆盖了也不生效），改回经两个虚函数取值，注释按真实合同重写；② 新加的 `_test_setup_recording_full` 为算期望条数多注册了三组 `RecordingUtils` 订阅却不退订，它们捕获的 `ctx → BattleRecorder` 活到进程结束，core 泄漏直方图当场 +5 RefCounted / +8 GDScript——加 `_drain()` 注册后立即退订，直方图恢复与基线一致。/ 为什么：这两条都是「按单一维度优化，破坏另一维度」，与 ⑦ 同型，值得继续记。/ 影响：无。
- ⑭ P2 / 文档与 skill / `/update-lgf-skill` 仍不可用（见 ⑤），继续手动等价执行：按 P2 实际改动的 API 面增量更新 `enforcing-lgf/reference/{entity,abilities,attributes,stdlib,conventions-detail,example-app-game-logic}.md` 与 `gdscript-coding/SKILL.md`，镜像到 `.agents/`（`diff -r` 逐字节一致）。`gdscript-coding` 的 `I*` 范例原本用 `IAbilitySetOwner`（本阶段删除），换成真实的 `IGameStateProvider`——首版是凭印象手写的，与真实实现有两处出入（丢了 `provider is Object` 守卫、兜底从 `Time.get_ticks_msec()` 变成 `0.0`），已按源码逐字符改正。`update.json.last_commit` 改记 addons SHA（按 §6 后续观察里对该命令的修复方向）。/ 为什么：命令坏了，不在本阶段顺手修。/ 影响：同 ⑤。

**后续观察**（范围外发现，不在本轮修）：

- 既有非 LGF 泄漏（P1 基线，原生类计数）：core `run_tests` 100 ObjectDB / 5 resources；hex `smoke_skill_scenarios` 38 / 6；dota2 `smoke_lane_wave_engage` 672 / 57（590 RefCounted + 66 GDScript + 15 WeakRef）；inkmon `smoke_m1_battle` 0。dota2 的 590 RefCounted 值得单独查（sim-nav / lane 侧）。
- `DEFAULT_TRACE_LEVEL` 改 0 后，唯一真正的「常驻世界」反而仍显式传 1：`inkmon/host/ink_mon_world_host.gd:47` 与 13 个 inkmon smoke 都写死 `EventProcessorConfig.new(20, 1)`，改默认值没覆盖到它们。P4「inkmon 夹具收敛」已计划把这些调用点去参（`InkMonWorldGI._init` 传 `(20, 0)`），届时才真正闭环。
- **`Log.assert_crash` 在 debug 构建下不阻断调用方**（本轮实证：独立探针项目里 `assert(false)` 只中止 `assert_crash` 自己那一帧，调用方继续跑完；`logger.gd` 里 `assert()` 之后的 `OS.crash()` 只在 release 走到）。含义：全仓所有 `assert_crash` 都是「响亮报错 + 该帧中止」而非「进程停住」，构造函数里的断言**挡不住**半成品对象继续被使用。计划各阶段（P1 的 timeline 非空、后续的 instance 非空等）凡写「crash」处，实际语义都是这个；需要真正阻断的地方得靠类型系统或提前 return，不能只靠断言。
- `plugin.gd._unregister_autoloads()` 随常量一起删掉了 `TimelineRegistry` 的清理行：曾启用过本 addon 的**其他**消费者项目，其 `project.godot` 里那行指向已删脚本的 autoload 再也无法靠「禁用/重启用插件」自动清除，只能手改（本仓已手改）。没加回清理是因为那要求 addon 长期保留一个指向已删文件的路径常量（违反无兼容 shim 纪律）；CHANGELOG 的迁移说明是目前唯一缓解。
- `TimelineData._init` 把传入的 `tags` **按引用**存下（`timeline_data.gd:20`），而 builder `.timeline(data)` 现在会 `make_read_only()` 它——若某处用 `TimelineData.from_dict(payload)` 建 timeline，`payload["tags"]` 会被就地冻结，调用方后续改它会报 read-only。仓内所有 timeline 都用内联字面量声明，属潜在而非现症；根治是 `_init` 里 `tags = p_tags.duplicate()`（或按 altitude 角度建议把冻结整个下沉进 `_init`，让「不可变」成为类型固有属性而非 builder 副作用）。
- `AbilityConfig.collect_timelines()` 只认 `components` 里的 `ActivateInstanceConfig`，而 `ActiveUseConfig extends AbilityComponentConfig`（**不**继承前者）——技能若写成 `.component_config(ActiveUseConfig.builder()…build())` 而非 `.active_use(…)`，其 timeline 对 lint 完全隐形。仓内当前无此写法；P6「`ActiveUseConfig extends ActivateInstanceConfig`」落地后自动消解。
- dota2 示例没有 manifest（只有单个 `Dota2BasicAttackAbility`），因此未加 lint smoke；若它将来长出第二个 ability，照 `inkmon/tests/smoke_skill_manifest_lint` 复制一个即可（逻辑已在 `AbilityConfig.lint_timelines`）。
- **`.lomo-team/reference/inkmon-skill-design.md` 的技能作者示例整体失效**（P2 发现）：`:196` / `:199` / `:772` 仍用已删除的 `IAbilitySetOwner`，但把它换成 `BattleActor.ability_set_of` 并不能救——同几段还在用同样不存在的 `IAbilitySetOwner.remove_ability` / `ability_set.remove_ability_by_id` / `ability_set.add_ability` / `EventPhase.push_damage` / `tag_container.apply_tag`。只改一个符号会给假信心，需要单独一轮按现行 API 重写整份示例。
- **`BattleRecorder.unregister_actor()` 全仓零调用点**（P2 发现）：`WorldGameplayInstance` 有 `actor_removed` signal，`BattleProcedure` 只接了 `actor_added` 补录那一半。hex 死者留 world 不 `remove_actor`、dota2 已关录像，所以当前无现症；但只要有一家开着录像又移除 actor，订阅就会留到 `stop_recording`。接线时注意 `record_actor_lifecycle` 的 despawn listener 也会推 `ActorDestroyed`，别和 unregister 各推一条。
- **`refcount_release_test` 的「干净起点」依赖运行顺序**（P2 发现）：`GameWorld.init()` 只在 `_initialized` 为 true 时才 `shutdown()`，而同套件更早的 `world_test.gd` 调过 `GameWorld.destroy()` 把它置回 false——于是释放测试开头那次 `init()` 实际没清 `_instances`，只换了 processor/collector。当前无害（各测试自己 `destroy_instance`），但硬关卡的前提是靠运气成立的。P4 把 `GameWorld` 生命周期动词收成单一 `shutdown()` 时一并处理。
- **`StatModifierComponent.on_remove` / `DynamicStatModifierComponent` 直接解引用 `context.attribute_set`**（P2 发现）：同文件的 `on_passive_disabled` / `on_passive_enabled` 都有 `if context.attribute_set == null: return` 守卫，`on_remove` 没有。鸭子探测改真类型后，「子类忘了覆盖 `get_attribute_set()`」从「有字段就命中」变成「静默 null」，这里会在 buff 被 revoke 那一刻才炸。没顺手加守卫是因为加了会把崩溃换成「modifier 没被移除」的静默泄漏，取舍要单独想清楚。
- **inkmon 的 `"intrinsic"` 是裸字面量**（P2 发现）：`ink_mon_battle_ability_set.gd` 的 `_is_blocking_execution` 与三个生产端（`ink_mon_damage_math_passive` / `ink_mon_engraving_passive` / `ink_mon_equipment_stat_ability`）各写一遍，而 hex 侧有 `HexBattleSkillTags.TAG_INTRINSIC`。打错一个字母 = 常驻 passive 被当成阻塞执行 = 该单位 ATB 永不充能、战斗静默跑到 timeout。常量归属地现成（`inkmon/logic/battle/config/ink_mon_skill_meta_keys.gd`）。
- **`Actor.serialize()` 全仓零生产消费者**（P2 发现）：录像走 `PlaybackData.ActorInitData.create`，inkmon 存档走 `to_dict()`。P2 把三份子类实现收敛进 `BattleActor.serialize()` 并加了 `is_dead` 键，等于给一条无人调用的路径加维护面；dota2 还因此白得一个不含 `position_2d` 的 `serialize()`。要么找到真实用途（debug dump / inspector），要么整条删掉。
- `/update-lgf-skill` 命令（`.claude/commands/update-lgf-skill.md`）需修三处：`grep -oP` 换可移植提取（如 `sed -n 's/.*"last_commit"[^"]*"\([^"]*\)".*/\1/p'`）；diff 改在 submodule 内跑（`git -C addons diff <addons-sha>..HEAD -- logic-game-framework/`）；`update.json.last_commit` 改记 addons SHA（主仓 SHA → gitlink 经历史清理后会失联）。
