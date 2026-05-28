# Progress

最后更新：2026-05-27

## 当前状态

状态：complete。

代码、文档与验证已完成。本文件之前的“待提交”表述是 stale 状态；当前没有剩余实现或验证工作。

## 已完成

- [x] 创建 goal 目标与文档入口。
- [x] 修复 `HexFacing.direction_between` 6 向计算，并在 facing scenario 覆盖 6 个邻居方向。
- [x] 修复 `StatModifierComponent.on_stacks_changed()` 直接预写 modifier value 的 notification bug，并补 listener old/new/changeType 测试。
- [x] 给 scenario flatten events 保留 `replay_frame` metadata，并把 Chain Lightning 三跳 damage 改成严格跨 frame 递增断言。
- [x] 增加 Chain Lightning caster 被 Thorn post reaction 反死后不继续结算下一跳 damage 的 scenario。
- [x] 扩展 Action validator：repo scan 覆盖 skill/buff 文件里的 `SkillLocalAction` 边界，直接 `execution_state` 访问会被 flag。
- [x] 修正 `smoke_summon_spike.gd`：behavior placeholder 不计入完成，manual remove 与 TimeDuration/on_remove lifecycle 分开验证。
- [x] 修正 `SkillPreviewProcedure` 自写 ability tick 漂移：正式 runtime tick 抽到 `HexBattleProcedure.tick_actor_ability_runtime()` 复用，preview 只调度 keyframe；已死亡 actor 的 pending keyframe / buff tick 不再继续执行。
- [x] 同步 remaining skills docs 的 spike closeout 状态。

## 验证记录

- [x] `./tools/run_tests.ps1 hex/skill-preview` — PASS 8 / FAIL 0。
- [x] `./tools/run_tests.ps1 core/unit hex/skills hex/skill-preview` — PASS 12 / FAIL 0。
- [x] `./tools/run_tests.ps1 core/unit hex/skills` — PASS 4 / FAIL 0。
- [x] `./tools/run_tests.ps1 all-required` — PASS 16 / FAIL 0 / TIMEOUT 0。
- [x] Chain Lightning / damage 类回归重跑 5 次 — `hex/skills` 连续 5 次 PASS。
- [x] `smoke_summon_spike.tscn` 单独重跑 — `SMOKE_SPIKE_RESULT: PASS - 5/5 verified phases passed; 1 placeholders skipped`。
- [x] `run-dev-scene` / `skill_preview.tscn`：`Poison @0ms -> Strike @1000ms -> Strike @3100ms`，timeline 1200ms -50、2200ms poison -3、3300ms -50 + death，结束 4600ms；死亡后无 4200ms poison tick。

## 边界

- 未实现正式 Summon Totem。
- 未触碰 Phase 2+ advanced skills。
- 不纳入本目标前已存在的无关 dirty/untracked 文件。

## 收口说明

- 2026-05-27：修正 stale 文档状态；该 goal 已收口，不再作为当前开发入口。
