# LGF 表演管线上提 §6 后续观察 — 分诊与拍板（2026-09-24）

> 来源：[`lgf-presentation-lift-plan.md`](lgf-presentation-lift-plan.md) §6「后续观察」22 条（PL0–PL5 执行期的范围外发现，按计划纪律没顺手修；其中 3 条执行期已由 PL5 关闭并标记）。先例：[`lgf-followups-2026-09-triage.md`](lgf-followups-2026-09-triage.md)。
> 本文是「分诊 → 分桶 → 用户拍板 → 一轮落地」的产出。**执行状态（2026-09-24 收口）：用户拍板 B（A 桶确定性小项 + 斩杀特效毫秒修正），一轮落地——addons `878c5b1` / 主仓 `5eb15969`（主仓 SHA 由随后的 docs 提交回填）；§6 从 22 条收到 7 条登记项（1 条待拍板 + 1 条等 inkmon 2e + 5 条候选 / 不动），LGF 侧无待办。**验收沿计划 §2（`-Required` + 四组全量 + inkmon 守卫 + leak 直方图 + golden），两仓各一个 commit，执行方不 push。

## 0. 本轮约束（用户 2026-09-24 拍板）

- **inkmon/ 一行不改**（冻结，随 2e 重设计）。
- **hex/random-golden 与 inkmon golden 一律不重烤**；hex 表演 golden（`smoke_presentation_golden`）允许在**先解释预期漂移**之后重烤。
- 「hex 逻辑层投射物各向异性」属逻辑层，不动。
- `VisualState.seed_actor` hp > max_hp 等 inkmon 2e 接入时定。
- 「effects map 统一」先核对 PL2 是否已合成 `VisualState._effects` 一张表再决定去留。
- 桌面分诊 = 读代码 + 全仓 grep 核实（消费方 / 残留 / 单位语境），未逐条跑复现；改动项的复现即本轮验收组。

## 1. 分桶总表

| 桶 | 条数 | 条目（§6 标题关键词） |
|---|---|---|
| ✅ 已关闭（执行期已落地，分诊核对后关闭） | 10 | effects map 统一（PL2-4 已合成 `VisualState._effects: kind → {id → Effect}` + 四原语）· `MELEE_STRIKE` 死项（PL2 内置 11 种不含，LGF / hex 零引用）· `projectile_default_speed` / `get_trail_length`（PL2 改名不带，LGF / hex 零引用）· 300 ms 下限钉不住距离公式（PL1-7 `hex_translator_coordinates_test` 单测钉住）· `BuffVisualizer` 注释（PL4-3 七处扫完）· `set_actor_hp / set_actor_dead`（PL3-5 已删、`set_actor_position` 归 live 入口）· Director 组件 `_ready` 才建（PL3-1 `_init` 建 + 注册表构造注入）· `step()` 重发 `playback_ended`（PL5-2）· `apply_move` 幽灵插值（PL5-4）· `smoke_regeneration_visualizer` 改名（PL5-6）|
| 🟢 A 本轮修：确定性小项，零 golden 风险 | 4 | `AnimationConfig.from_dict` 删（全仓零调用）· `[Frontend:FrameDiag]` 3 处 + `[Presentation:ReplayDirector]` 4 处诊断打印删，连带只为它们存在的常量 / 计数器 / `_analyze_event_coverage` / `_environment_kind` · 三个白盒 smoke（buff_pipeline / facing_indicator / regeneration）`_run_frame` 改喂 `pump` · `docs/README.md` 2.2 ADR 索引补 0009–0013 |
| 🟡 B 本轮修：动 hex 表演 golden（先解释再重烤） | 1 | `FrontendStageCueTranslator.EXECUTE_KILL_VFX_DURATION / DELAY` 0.8 / 0.15 → 800 / 150 ms（见 §2 B-1）|
| ⚪ 登记不修 | 7 | hex 逻辑层投射物 axial 欧氏度量各向异性（逻辑层，硬约束）· `FrontendFacingIndicatorView` 自己拿 `GridLayout` 算朝向（view 层候选：改 `FrontendHexProjection.delta_to_world`）· Director 四件 `_exit_tree` 拆后移出树再加回不可用（无消费方；触发 = 第一个这么用的消费方，届时改 `NOTIFICATION_PREDELETE` 或不拆）· hex `frontend/README.md`「项目背景」称「Godot 3D 表演层」并与 `inkmon-web` 1:1 对照（**待拍板**，见 §2）· `seed_actor` hp > max_hp（等 inkmon 2e）· `pump` 的 `advance_time(int(delta_ms))` 逐趟截断（候选：账本时间走 float 或 Director 攒余数；触发 = 出现可见的到期误差）· `FrontendAttackVFXView.update_progress` 不用 payload 的 `scale_factor`（view 层候选）|

## 2. 拍板记录

- **B-1 斩杀特效常量 → 800 / 150 ms（用户 2026-09-24 拍板 B）。**
  why：卡片时间一律毫秒（`VisualAction` 头注释 / `delay` / `duration` 字段注释），同文件普通攻击特效用 `AnimationConfig.attack_vfx_duration = 300` ms；基线 golden 651143 第 18 帧那张斩杀 attack_vfx 同一步内 `+1 / -1`（0.8 ms 内建了又删），「斩杀!」飘字 delay 0.15 ms 等于零延迟——注释写的「更长」「略延迟」两个意图都没兑现。
  改法：两常量 ×1000，注释补「单位毫秒」；不动 view、不动其他翻译员。
  验收：hex 表演 golden 漂移只在 651143（三 seed 里只有它出斩杀）：第 18 帧两张卡 `delay / dur` 0.15 / 0.80 → 150 / 800；step 18 的 fx 行少 `+attack_vfx=1 -attack_vfx=1` 与一条 `+floating_text`；step 19 多 `+attack_vfx=1 +floating_text=1`（150 ms 延迟落到下一步）；step 27 多 `-attack_vfx=1`（800 ms 到期出账）；帧数 / 步数 / 卡片数 / 结局与录像 sha 全同，900127 / 900191 dump 逐字节同。指纹 466926191 → 2927815786，解释后重烤一次（deviations TR-3）。hex/random-golden 与 inkmon golden 未动。
- **待拍板（本轮不动）：hex `frontend/README.md`「项目背景」。** 现文仍称本目录「inkmon 战斗系统的 Godot 3D 表演层」并与 `../inkmon-web/lib/battle-replay/` 对照「1:1 架构」；web 端是否按 adr/0013 词表走未核实、也不在本仓。选项：A 改写成「hex 示例的 3D 表演层 = LGF `presentation/` 的第一消费者」并删 web 对照表 / B 保留，等核实 web 端后再改 / C 删整节（「表演框架在哪」「hex 接线」两节已足够）。

## 3. 规则之家新增

- 无。本轮零 core / presentation 语义变化：删的是无消费方的诊断打印与工厂方法，改的是 hex 项目件常量与 hex 测试；LGF `CLAUDE.md` 词表 `AnimationConfig` 行本就只列 `create_default()`，不需改。

## 4. 本轮新登记（不在本轮执行）

- `smoke_buff_ui` / `smoke_shield_ui` 仍直调 `VisualUpdater.apply_buff_state / apply_shield_state`（PL2-9）——它们测的是单条记账原语，不是管线，核对后不改。
- 诊断打印删掉后 `ReplayDirector._process` 不再报长帧 / 慢 tick；将来要看表演层性能走 profiler 或 golden 的 `steps` 指标，不再加 print。

## 5. 执行顺序与结果（2026-09-24 一轮完成）

1. A 桶四项落地 → `hex/frontend` 10 / 10 PASS，golden 三 seed 指纹不变（证明 A 零漂移）。
2. B-1 落地 → golden 不带 rebake 跑一次拿新 dump 与基线逐行差分（结果同 §2 B-1 验收）→ `-- rebake` → 复跑 PASS。
3. 全量验收：`-Required` 21 / 21 PASS；`hex/all dota2autobattle/smoke inkmon/all core/skill-preview-env` 78 / 78 PASS；`git status --porcelain -- inkmon/` 为空；leak 直方图 `hex-frontend.hist.txt` 仍为空与基线逐字节一致。
4. 提交：addons `878c5b1`（`fix(lgf)`，显式路径：`presentation/core/replay_director.gd` / `animation_config.gd`、hex `frontend/battle_animator.gd` / `scene/unit_view.gd` / `translators/stage_cue_translator.gd`、hex `tests/frontend/` 三个 smoke + `presentation_golden.json`）/ 主仓 `5eb15969`（submodule 指针 + 本文 + 计划 §6 每条处置标记 + deviations TR-1～4 + `docs/README.md` 2.2）；不 push。
