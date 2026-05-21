# remaining-skills-review-closeout

## 目标

完成 remaining skills review closeout，把 review 中 P1/P2 findings 用代码或测试闭环。

## 范围

- 修复 `HexFacing.direction_between` 的 6 向方向计算，并补 6 个方向覆盖。
- 修复 `StatModifierComponent.on_stacks_changed()`，modifier value 更新只走 `RawAttributeSet.update_modifier()`，补 attribute listener/change event 测试。
- 修正 `smoke_summon_spike.gd` 假 PASS：Phase 5 behavior placeholder 不计入完成；manual remove 与 `TimeDurationConfig/on_remove` lifecycle 分开给结论。
- 加强 Action validator / `execution_state` guardrail：覆盖 skill 文件里的 `SkillLocalAction` 边界，禁止直接读写 `execution_state` 绕过 namespaced helper。
- 修正 Chain Lightning scenario 跨 frame 逐跳断言，让 replay frame metadata 可被断言；补 caster 被 post reaction 反死后不继续结算下一跳 damage 的回归。

## 禁止

- 不实现 Phase 2+ advanced skills。
- 不把正式 Summon Totem 技能塞进本目标；本目标只收口 spike 证据。
- 不改无关 UI / frontend polish。
- 不纳入无关 dirty/untracked 文件。

## 验证

- `./tools/run_tests.ps1 core/unit hex/skills`
- `./tools/run_tests.ps1 all-required`
- Chain Lightning / damage 类回归重跑 5 次，确认无随机绿灯。
- 如果 `all-required` 因既有 Godot resource leak exit=-1 失败，记录日志证据并区分 scene 自报 PASS 与真实行为失败。
