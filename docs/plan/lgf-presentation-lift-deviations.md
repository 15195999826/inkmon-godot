# LGF 表演管线上提——偏离记录

> 配套 [`lgf-presentation-lift-plan.md`](lgf-presentation-lift-plan.md) §2 第 2 关。每阶段执行方在此追加；格式 `- PL<n>-<序号> / 做了什么 / 为什么`，每条 ≤ 200 字；「影响」只在会改变后续阶段时写；锚点写符号不写 `file:line`。范围外发现不写这里，记计划 §6「后续观察」。

## PL0 钉子先行

- PL0-1 / golden 用 3 个 seed（651143 + 900127 + 900191）而非只取 `hex/random-frontend` 那一个 / 651143 一局只出 10 种卡片，缺 `bump` 与 `cone_debug_overlay`——恰是 PL1 要改坐标口径的两张。在 `hex/random-golden` 的 10 个覆盖率 seed 上探针：900191 出 bump、900127 出 cone（另有 5 张投射物），三个合起来 12 种全覆盖，一次 4 s。
- PL0-2 / dump 里的生成 id 按 seed 内首现序规范化成「前缀#序号」（`Character#1` / `ability#3`） / 多 seed 同进程连跑时 IdGenerator 计数随顺序漂，指纹须与 RUNS 增删顺序无关。录像 sha（`record_sha256`）不规范化，只用于归因。
- PL0-3 / golden 接 Director 走三处私有字段：`_registry` 换成记录包装（翻译结果原样透传）、`_world.as_context()` 读取整位置、`_scheduler.get_action_count()` 只用于报错 / 「不改 frontend 源码」前提下拿翻译结果只能包注册表。影响：PL2 / PL3 搬家改名时这三处钩子随之改指向，不止「换用映射表」。
- PL0-4 / 主仓 §6 状态行的主仓 SHA 用单独一个 docs 提交回填（沿用 core 计划 P1 / P2 的做法） / 提交无法自引用自己的 SHA；阶段本身仍是两仓各一个提交。
- PL0-5 / leak 基线目录加 `README.md` / 直方图是零泄漏的空文件，没有说明看不出是「零」还是「没烤」；照 core 基线目录惯例，只记场景、命令与「仍为空即合格」的判据。

## PL1 坐标对齐

- PL1-1 / 投射物 duration 口径从「像素距离 / 速度」改为「逻辑平面 axial 距离 / 速度」 / 翻译员没有棋盘几何算不了像素距离；hex 逻辑层 ProjectileSystem 本就在 (q, r, 0) 空间飞、speed 是这个平面的，改后与逻辑飞行时间同口径反而更准。size 1 下 axial 距离恒小于像素距离，golden 6 张 300 ms 下限卡片不漂；数值由 `visualizer_coordinates_test` 钉住。
- PL1-2 / cone overlay 的 angle-cone 引导线不改 axial，作为 `guide_segments` 按逻辑层 2D 平面坐标原样透传（view 端 y→Z） / 逻辑层 `compute_edge_segments` 用棋盘世界坐标算旋转射线，翻译员无棋盘几何反算不了 axial；改逻辑层会动录像（逻辑 golden 禁重烤）。cells / 外沿按计划改 axial，外沿端点用三格中心质心（仿射映射下就是共用顶点），不需要棋盘。
- PL1-3 / bump 的 direction 不归一化：= 停住格→撞向格的 axial 一步，max_offset 改为格距比例 0.30 / axial 平面无度规，归一化会让六个方向投影后长短不一；不归一化 + 比例经线性投影恰等于今日「hex 间距 × 0.30」，视觉零漂移。squish 收成 (水平, 竖直) 二维，3D view 展成 (x, y, x)。
- PL1-4 / 投影收成一个 static 工具 `FrontendHexProjection`（`frontend/scene/hex_projection.gd`），animator / unit_view / cone view 共用 / 计划写「animator / world_view / scene 各新增 `_project`」；同一段双线性抄三份是漂移温床。`world_view.hex_to_world` 本就是 view 层投影、未动；animator 的 `_project` 只是薄包装，棋盘几何由 animator 在 `load` 时从录像 map_config 建。
- PL1-5 / reconciler 改成两层比：账本 hex 直接比逻辑 hex；unit_view 节点位置比逻辑 hex 经 `world_view.hex_to_world` 投影后的世界坐标 / 计划只写「expected_alive_pos 改比较 hex 坐标」；节点 settle 漂移只能在世界坐标里比，保留；账本 hex 直比是零投影的新钉子，投影只剩 view 边界一处。
- PL1-6 / `FrontendVisualizerContext` 新增 `has_actor` / 投射物翻译员要区分「账本没这个 actor」与「站在 (0,0)」；旧码用 `== ZERO` 判空，世界原点上的 actor 会退回读事件字段（把 (q, r, 0) 当世界坐标）的隐性 bug 一并消掉。
- PL1-7 / hex 翻译员坐标口径单测放 `tests/presentation/visualizer_coordinates_test.gd`（挂 `core/unit`） / PL0 §6 记「投射物距离口径要另用单测钉」；沿用 PL0 把 Frontend* 单测放 tests/presentation 的先例。影响：PL2 路径同步多一个文件，且它测的是 hex 翻译员（PL2 后留 hex），归属届时定。
- PL1-8 / hex `frontend/README.md` 流程图三行同步（`projectile_updated(pos)` / `_project(...)`） / 改 API 的同一提交不留过期示意；PL4 精简 README 时照旧处理。

## PL2 搬家 + 改名 + 扩展缝

- PL2-1 / 目录 `frontend/visualizers/` 连同 `default_registry.gd` 一起 git mv 到 `frontend/translators/` / 计划只列 class_name + 文件名；`Visualizer` 一词退役后目录名留着就是死词，README 接入清单的路径随之同步。
- PL2-2 / `ActorVisualState.position`、`VisualMoveAction.from_position / to_position`、`VisualState.set_actor_position` 全改 `Vector2`；`VisualStateQuery` 删 PL1 保留的 `get_actor_hex_position`；move / displacement 翻译员把 `HexCoord.from_dict` 结果转 `Vector2(q, r)` 再装卡 / `presentation/` 不许出现 `HexCoord`（lint 断言）；hex 翻译员没有一个读它，golden / reconciler / facing view 各自 `roundi` 取整即等价，golden 零漂移。
- PL2-3 / 方法改名三处：`as_context → as_query`、`get_world_time → get_time_ms`、`get_actor_axial → get_actor_position`（Director 同名）；`initialize_from_replay` / `reset_to` 不动 / 返回 `VisualStateQuery` 的方法不该叫 context；`world` / `axial` 随 RenderWorld / hex 词退役；replay 不是退役词（D6 自己用 `ReplayDirector`）。
- PL2-4 / 一次性效果簿记合成 `VisualState._effects: kind → {id → Effect}` 一张表 + `spawn / update / remove / expire_effects` 四个原语；飘字 / overlay 到期由账本静默忘记，`effect_removed` 只由 attack_vfx / projectile 的 handler 在 progress 1 显式发 / D4 私有卡片（cone overlay）要能入账，账本就不能按种类各开簿子；§4 不做的是 `EffectState` + dirty flush 那套，这里只是存储容器。计数口径与旧四组信号逐一相同，golden 零漂移，不重烤。
- PL2-5 / `VisualUpdater.tick_time` = 到期清理 + hp 追赶，Director 每 tick 无条件调（旧码 `cleanup` 只在 `has_changes` 时跑） / D7 定义如此；效果到期与卡片完成同 tick 或更晚，完成那帧已把 flash / tint / shake 写成终值，无条件清理只让簿子准时出账，视觉与 golden 无差；cone overlay 的簿子从此到期出账（旧码存到 reset 才清）。
- PL2-6 / `VisualEffectPayload.AttackVfx` 加 `scale_factor / alpha`、`Projectile` 加 `position`，随 `effect_updated` 带出；`Effect` 基类持 id / start_time / duration / D5 把逐种类参数的 `*_updated` 收成 `effect_updated(kind, id, progress, payload)`，逐种类的当前值只能挂在 payload（账本里那条记录本身，不复制）上。
- PL2-7 / `VisualUpdater.apply_actions` 对未登记的 kind `Log.assert_crash` / 旧 `match` 对未知枚举静默跳过；kind 开放后「忘了 register_handler」是最可能的接入错误，静默会让卡片无声消失。
- PL2-8 / 单测同步改名，新增 `presentation_lint_test.gd`（禁词 / 依赖方向 / 无前缀 class_name / .uid），`visualizer_coordinates_test → hex_translator_coordinates_test` 仍挂 `tests/presentation`（测 hex 翻译员，PL1-7 的归属题），`visual_updater_test` 多两条（私有 kind handler、飘字到期静默） / 计划要 lint 断言；hex 翻译员坐标口径没有别的 unit 挂点（hex tests 全是 smoke 场景）。
- PL2-9 / 三个白盒 smoke（buff_pipeline / facing_indicator / regeneration）的 `_run_frame` 改走 `VisualUpdater`，并按 Director 顺序补 `advance_time` + `tick_time`（旧码不推账本时间、cleanup 用 time 0）；buff_ui / shield_ui 直接调 `VisualUpdater.apply_buff_state / apply_shield_state` / 记账规则搬到 Updater 后 `_apply_*` 私有方法不在了；补 advance_time 让 smoke 与 Director 同一条 tick 路径，断言只看 buffs / facing / target_hp 不受影响。
- PL2-10 / hex `frontend/README.md` 与 hex 根 README 术语 / 路径 / 信号面同步，不重排章节 / 完成定义要求 `frontend` 目录零 `Visualizer`；PL4 再精简结构（沿 PL1-8）。
- PL2-11 / 主仓 §6 状态行的主仓 SHA 用单独 docs 提交回填（沿 PL0-4） / 提交无法自引用自己的 SHA。
- PL2-12 / 全量验收在隔离 worktree `../inkmon-godot-pl2`（两仓 HEAD + 只覆盖本阶段路径）跑，两仓提交只走显式路径 / 同一工作区有定向投递第二刀会话在改 core（本阶段中途已提交 addons 2e9a89b），按并行会话纪律把全量组搬去隔离树。

## PL3 Director 骨架 + live 入口

- PL3-1 / 翻译员注册表经构造函数注入（`VisualDirector._init(registry, animation_config = null)`），四件在 `_init` 建 / D6 只说 Director「持 registry」；hex 不再有 Director 子类可覆盖工厂，注入是唯一不靠入树顺序的办法（PL2 后续观察那条一并解决）。golden 的记录包装改走构造注入，不再碰 `_registry` 私有字段。
- PL3-2 / `frame_changed` 在帧时钟循环里按帧发，事件翻译挪到循环之后的 `pump` 里一趟做 / D6 把「事件直改 → 翻译 → 入 stepper」定义在 pump 内；`frame_changed` 监听者只更新 UI 标签、不读步进器，观察面无差，golden 一步一帧零漂移。
- PL3-3 / 不带 `@export initial_speed / auto_play` 与 `fire_tile` 专用 FrameDiag 打印进框架；诊断打印前缀改 `[Presentation:ReplayDirector]` / 前两者无消费方，且 auto_play 分支引用不存在的 `BattleRecord.is_empty()`；fire_tile 是 hex 项目词，animator `spawn_view` 已按 config_id 打印同一事实；前缀全仓无人 grep。
- PL3-4 / `seed_actor` 同 id 忽略返回 null（inkmon 现版静默覆盖），并多发一条 `actor_spawned` / 与 `spawn_actor` 同口径：覆盖会让 view 层懒建对同一 id 双发；inkmon 自己在 view 层 `get_avatar` 判空挡了这条路，框架里收成一条口径。
- PL3-5 / 删 `VisualState.set_actor_hp / set_actor_dead`，`set_actor_position` 保留归入 live 入口 / PL2 后续观察点名定去留：前两者 hex / inkmon 生产码零调用；inkmon live 只用 set_actor_position 做 snap。单测「视图跟账本走」改用 set_actor_position 钉。
- PL3-6 / `ReplayDirector._exit_tree` 清帧表、置空录像再 `super()`；`load_playback` 缺 meta 断言、`tick_interval ≤ 0` 退回 100 / 两问自查①的对称出口；`tick_interval` 为 0 会让帧时钟 while 死循环，旧码写死常量 100 没这个坑。
- PL3-7 / 单测不止计划的两个文件：`action_stepper_test` +2（cancel_for_actor / has_actor_action）、`visual_state_events_test` +1（seed / set_actor_position / despawn） / live 入口是本阶段新进框架的合同，按 PL0 惯例每条合同就近钉。
- PL3-8 / `skill_preview.gd` 无需改；`skill_preview_dev_agent_ops.gd` / `smoke_buff_pipeline.gd` 只同步注释里的 `LOGIC_TICK_MS` / `BattleDirector._tick` 死词 / 计划写「skill_preview.gd 引用同步」，实查它只经 `FrontendBattleAnimator`（API 未动），零 Director 引用。
- PL3-9 / hex `frontend/README.md` 流程图 / 目录树 / 核心类说明 §1 同步到 VisualDirector / ReplayDirector，不重排章节 / 沿 PL1-8 / PL2-10：改 API 的同一提交不留过期示意；PL4 再精简。
- PL3-10 / 主仓 §6 状态行的主仓 SHA 用单独 docs 提交回填 / 沿 PL0-4：提交无法自引用自己的 SHA。

## PL4 文档与规则之家

- PL4-1 / hex `frontend/README.md` 除计划点名的「框架设计 / 四层管线 / 核心类说明」外还删了「流程图」（阶段一是已删 `FrontendBattleReplayScene` 的历史示意、阶段二是 `pump` 体逐步复述）「事件类型」「录像数据格式」（`position: {hex: {q, r}}` 与录像实际 `[q, r, 0]` 不符）「使用方法」；阶段三的 hex 接线图与「添加自定义翻译员」并入新「hex 接线」「扩展」两节，目录结构按真实树重写，wire 节里的 `main.gd` 死指针改成 `demo_frontend.gd` / 过期示意与框架复述留着就是第二份真相；README 只讲 hex 项目件。
- PL4-2 / `enforcing-lgf` SKILL.md「Where to look」加一行 Presentation（源码 + 单测 + golden），Reference 段的 CLAUDE.md 指针加「Presentation layer」 / 计划只要求「若列了 frontend 路径同步」（三个 frontend 路径都还在，无死链）；指针表按 topic 列，表演层已是框架件却没有行，读者找不到入口。
- PL4-3 / 逻辑层注释 `BuffVisualizer` → `BuffTranslator` 七处（`core/events/game_event.gd` / `core/playback/recording_utils.gd` / hex `surge.gd` / `surge_buff.gd` / `surge_tick_action.gd` / `poison_scenario.gd` / `surge_scenario.gd`），`perl -i -pe` 保行尾 / PL2 后续观察点名交 PL4 顺手扫；仅注释，零行为。
- PL4-4 / 提交类型用 `docs(lgf)` / `docs:`，不用协议模板的 `refactor` / 本阶段零行为改动（文档 + 注释）；git log 是变更追溯入口，Conventional Commits 类型要真。
- PL4-5 / 主仓 §6 状态行的主仓 SHA 用单独 docs 提交回填 / 沿 PL0-4：提交无法自引用自己的 SHA。

## PL5 整体审与收口

- PL5-1 / `/code-review` 在本会话内按 skill 的 8 角度（3 正确性 + 3 清理 + 高度 + 规范）high 档跑，报 10 条后修 ≥ medium 与零风险的 low，不 spawn 子 agent、修完不复审 / 计划写「fable 做 `/code-review`」，skill 指令本身要求 finder 在当前 context 跑；审的范围按计划取 `bc385e6..HEAD -- presentation example/hex-atb-battle/frontend tests`，同区间的定向投递刀 `2e9a89b` 触到的 `tests/core` 四个文件不属本计划、不审。
- PL5-2 / `ReplayDirector` 加 `_ended_reported` 标记：`playback_ended` / 停播只报一次，`load_playback` / `reset` 归 false / 判断式（开趟 `was_ended` 与收趟比翻转）做不到零帧录像的首次报告——它从加载起就是 ended、没有翻转可判，标记专门论证后采用。PL3 后续观察那条关闭。
- PL5-3 / `ReplayDirector.play / reset / step` 没有录像时无动作；`load_playback` 改走 `reset_to` / 旧 hex Director 同样会 `reset_to(null)` 空指针（demo 在 Start Battle 前按 Play / Space / Reset），animator 注释早已承诺「未 load 时 no-op」——不是回归，进了框架就该守住；`reset_to` 让换片与 reset 同样归零账本时间。LGF `CLAUDE.md` 词表 ReplayDirector 行补一句。
- PL5-4 / `VisualUpdater.apply_move` 不在账上的 actor 整张忽略（PL3 后续观察关闭）；`_expire` 改成一趟扫寿命簿分组 + 闪白 / 染色真归零才标脏 / 每 tick 每 actor 两个闭包扫描是热路径浪费；归零不标脏会让 live 中途 `cancel_for_actor` 的 actor 视图停在闪白态。正常完成的卡片最后一次 apply 已写零位、到期总不早于完成，golden 三 seed 指纹不变，不重烤。
- PL5-5 / `VisualDirector.pump` 只读视图一趟建一次 / 视图是账本字典的活引用（`visual_state_events_test` 钉「同一个 query 读到直改后的新值」），逐事件重建纯浪费。
- PL5-6 / `smoke_regeneration_visualizer` → `smoke_regeneration_translator`（.gd / .uid / .tscn `git mv`，根节点 `SmokeRegenerationTranslator`，`test_groups.json` 同步）；`smoke_frontend_main` 头注释 `ActionScheduler` → `ActionStepper` / PL4 后续观察交 PL5 顺手；退役词不该留在活场景名里。
- PL5-7 / 两条 low 不修：`seed_actor` 给 hp 不给 max_hp 时 hp > max_hp（照 inkmon 现版口径，2e 接入时定）；`advance_time(int(delta_ms))` 账本时钟按趟截断（60 fps 慢约 4%，效果到期只晚不早、view 自管寿命，无可见差异）/ 计划只要求修 ≥ medium；两条都记 §6 后续观察。
- PL5-8 / 主仓 §6 状态行的主仓 SHA 用单独 docs 提交回填 / 沿 PL0-4：提交无法自引用自己的 SHA。

## 分诊轮（§6 后续观察分诊，2026-09-24，用户拍板 B）

- TR-1 / 三个白盒 smoke 改喂 `pump` 走的是 `ReplayDirector.load_playback`（零帧录像重建台面）+ 直接 `pump(STEP_MS, events)`，不是 `VisualDirector.new` + 私有 `_state.initialize_from_replay` / `VisualDirector` 不暴露台面重建入口，`load_playback` 是唯一公开路径；沿 golden「账本 / 步进器只走 Director 的公开读法」。原 `_run_frame` 逐事件打印翻译出的卡片数随之取消（翻译在 pump 内，观察面只剩账本）。
- TR-2 / 删 `[Presentation:ReplayDirector]` 打印时连 `_analyze_event_coverage()`（加载时事件覆盖分析）与两个 WARN 常量一起删；删 `[Frontend:FrameDiag]` 时连 `SPAWN_VIEW_COST_WARN_MS` / `FLOATING_TEXT_COST_WARN_MS` / `POSITION_GAP_WARN` / `MAX_POSITION_GAP_LOGS` / `_position_gap_log_count` / `_should_log_position_gap` 与只剩赋值没人读的 `_environment_kind` 一起删 / 这些只为打印存在，留着就是死代码；「哪些 kind 没翻译员」要看时现问 `TranslatorRegistry.has_translator_for`（regeneration smoke 就这么用）。
- TR-3 / `EXECUTE_KILL_VFX_DURATION / DELAY` 0.8 / 0.15 → 800.0 / 150.0（毫秒），hex 表演 golden 重烤一次 / 预期漂移 = 仅 seed 651143（三 seed 里只有它出斩杀）：第 18 帧两张卡 `delay / dur` 0.15 / 0.80 → 150 / 800；step 18 的 fx 行少 `+attack_vfx=1 -attack_vfx=1`（不再同步建了又删）与一条 `+floating_text`；step 19 多 `+attack_vfx=1 +floating_text=1`（150 ms 延迟落到下一步）；step 27 多 `-attack_vfx=1`（800 ms 到期出账）；帧数 / 步数 / 卡片数 / 结局与录像 sha 全同，900127 / 900191 dump 逐字节同。指纹 466926191 → 2927815786。hex/random-golden 与 inkmon golden 未动。
- TR-4 / 主仓 SHA 用单独 docs 提交回填 / 沿 PL0-4：提交无法自引用自己的 SHA。
