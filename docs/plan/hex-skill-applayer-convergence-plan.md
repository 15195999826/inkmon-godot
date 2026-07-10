# Hex 技能系统应用层收敛计划

> 2026-07-10 grill 定稿。范围：`addons/logic-game-framework/example/hex-atb-battle/` 技能应用层 + 少量 LGF core 增量 API。
> 背景：20+ 技能落地后 review 发现的摩擦收敛为 9 点决策，逐点 grill 拍板。
> 状态：**P1 已实现**（submodule `ec4d592` / 主仓 `43d56dd`），P2-P9 待 GO 后实施。

## 决策清单

### P1 ✅ "buff" tag 两轴收口（已落地）

- **问题**：`"buff"` 一词两义（状态实例 vs 增益形容词），demon_form / vigor / vitality 三个被动误带 `"buff"`，被 SkillPreview 选单的 `has("buff")` 过滤误伤。
- **拍板**：两轴模型——**载体轴**（`skill` / `passive` / `buff` / `intrinsic` / `status`，互斥必带一）×**极性轴**（`positive` / `negative`，正交可选，buff 实例必带其一）。"是否增益"一律查极性 tag。三被动摘 `buff` 补 `positive`；`skill_preview.gd` 手抄过滤改调 `HexBattleSkillIndex`；`buff_tags.gd` 头注释写死两轴模型。

### P2 manifest lint smoke（4 条断言全做）

- **问题**：四类静默失效面全靠人肉 checklist——timeline 手抄注册、cue_id 未登记静默跳过、新 buff 忘接 BUFF_REGISTRY、tag typo。
- **拍板**：新建 `tests/battle/smoke_manifest_lint.gd`，挂 `hex/regression` 必跑组。断言：① 每个 config 的 timeline 可在 registry 解析；② 带 `buff` tag 的 config_id ∈ BUFF_REGISTRY（留显式豁免名单）；③ StageCueAction 固定 cue ⊆ frontend 注册表（core 给 StageCueAction 加只读 `get_fixed_cue()` 探查口）；④ tag ∈ 已知词表 + active 技能 RANGE / TARGETING meta 必填。

### P3 词表常量化（消费驱动）

- **拍板**：tag 用「消费方常量」——新建 `HexBattleSkillTags`（ENEMY/ALLY/SELF、载体轴、HEAL 等**有代码读的**），`can_use_skill_on` / AI / index 等消费处改引用 const；纯描述 tag（melee/ranged/aoe/line/projectile/flavor）保持字面量，由 lint 词表兜 typo。`HexBattleBuffTags` 保持不动。
- cue 用「常量菜单」——新建 `HexBattleCues`（logic 侧，frontend 引用合法），**声明方和注册表都引用 const**；想编新 cue 必须先进菜单文件，动静自然暴露（对抗"编造新 cue id"惯性）。

### P4 标准 timeline 库

- **问题**：`500ms/HIT@300/END@500` 逐字重复 ~14 个文件；"节奏对齐 Strike"只活在注释里。
- **拍板**：`HexBattleStdTimelines` 三条共享实例：`MELEE_500`（HIT@300/END@500）、`CAST_LAUNCH_600`（CAST@200/LAUNCH@400/END@600）、`HIT_RESPONSE_100`（END@100）。标准节奏技能删自有声明改引用；真有节奏个性的保留（crushing_blow / swift_strike / move / shadow_step / 召唤类 / buff tick）。
- **已核实安全**：timeline_id 仅两类读者——执行器查 keyframe（共享无碍）、录像元数据（frontend 零处读）。代价仅 replay 里 timeline_id 显示 std 名而非技能名。

### P5 buff_applier preset

- **问题**：stun/silence/break/poison/expose/ward/双盾/surge 共 9 文件同骨架，每文件 ~50 行仅 ~8 行是信息。按项目自己的尺子（fireball.gd："3 技能/12 参数/有结构差异→不抽"）反推：9 技能/6 参数/零结构差异→该抽。
- **拍板**：`HexBattleSkillPresets.buff_applier(...)` 收 **8 个**；**poison 保留全显式**当家族教学范本（DOT 契约示范地位不动）。

### P6 timeline 声明-注册一体化（全线切换）

- **问题**：timeline 信息要写三遍（声明 / `.timeline_id()` / manifest 手抄列）；registry 对同 id 冲突静默 last-write-wins（`timeline.gd:8`）。
- **拍板**：builder 加 `.timeline(data: TimelineData)`（设 id + 携带 data），**`.timeline_id(String)` 删除、全线切换**（44 处/41 文件，含 dota2 示例 1 处；约半数被 P4/P5 顺路吞掉）。`register_all_timelines()` 改从 config 树收集；manifest `_Entry` 退化单列。
- **引用共享安全结论**（grill 中核实）：TimelineData 是纯数据资产（全库写点仅构造期两处）；执行游标全在 `AbilityExecutionInstance`（`_elapsed`/`_triggered_tags`/…），每次施法新实例；**今天并发即共享同一引用**，id 从未提供拷贝隔离，真实收益是序列化键（保留不变）。
- **加固**：registry 三态注册（新→存 / 同引用→幂等 / 同 id 异引用→`assert_crash`，顺带焊死"timeline 必须 static 声明、禁工厂内联 new"）；注册时 `tags.make_read_only()`。

### P7 TARGETING 元数据 + 几何层命名约定

- **问题**：actor/coord 双施法协议隐式，AI 靠嗅 `"cone"` tag 决定附不附 `target_coord`（`random_loadout_strategy.gd:156`）；coord 技能无入口校验。
- **拍板**：meta key `TARGETING` ∈ `ACTOR`/`COORD`/`SELF`；AI 判据切到它，cone/aoe/line 降回纯描述；新增 `can_use_skill_at(actor, skill, coord)` 管 COORD 合法性；lint 断言 TARGETING 必填。
- **UE"公用 TargetSelector"问题的结论**：目标选择拆三层——①合法性（declarative metadata，AI 要批量枚举）②形状几何（**该公用的层**：static 纯函数如 `compute_checked_coords`，selector 与预览 overlay 共用，代码已自发形成）③执行期命中（TargetSelector 专属，ATB 出手延迟 300ms 决定必须执行期重解析）。公用几何纯函数层、selector 不动；②升级为明文约定写入 README。

### P8 chain_lightning 派生数据重写（行为一致性硬约束）

- **问题**：`_next_chain_data`（O(全场) 扫描）被 predicate/selector/4 resolver **各自重算 6 遍**，正确性靠"6 次调用间世界不变"的隐式不变量。
- **拍板**：on_hit 链头插私有 compute action 算一次写 `execution_state["chain_lightning.next"]`，下游全部只读（shadow_step 已有同款 pattern）；写成明文 pattern 文档。顺手：`HexBattleSkillHelpers.caster(ctx)` 收掉五行式 owner 解析样板（不判死活，留给调用方）。
- **验证协议（用户硬性要求：改后行为必须与现在游戏内一致）**：① 重写**前**先补"标准三跳"基线 scenario（断言伤害序列 60/48/38.4、跳跃顺序、不重复命中、MAX_HITS 停链）；② 重写后全部 chain scenario 绿 + **重跑 5 次稳定**；③ 基线断言永久保留。

### P9 工作流文档刷新（等 P1-P8 落地后一次做）

- **问题**：`lgf-new-logic-skill` SKILL.md 目录图/scenario 路径过时，Step 0 指向已不存在的 progress 文档。
- **拍板**：P1-P8 完成后一次重写（目录图、路径、新增 preset/`.timeline()`/TARGETING/execution_state pattern/lint 说明）；progress 文档不复活——"已落地清单"职责交给 manifest+lint（机器不烂），"pattern 速查表"并入 SKILL.md。
- **待确认小项**：该 skill 被 skillOverrides 禁用模型调用，是否有意？

## 实施顺序（波次间跑 `hex/all` + submodule 阶段性 commit）

| 波次 | 内容 | 性质 |
|---|---|---|
| W1 | P3 两个常量类；P4 `HexBattleStdTimelines`；P6-core（`.timeline()` API + registry 三态 + `make_read_only` + StageCueAction `get_fixed_cue()`） | 纯新增，零行为变化 |
| W2 | P6 全线迁移 44 处（吸收 P4 共享引用）；P5 preset 收 8 文件；P7 TARGETING + `can_use_skill_at` + AI 判据切换 | 机械迁移 + 声明补齐 |
| W3 | P2 lint smoke 落地（此时词表/必填键齐备，四断言全开）+ 挂 `hex/regression` | 守门 |
| W4 | P8 基线 scenario → 重写 → 5 次稳定 | 唯一行为敏感点，单独波次 |
| W5 | P9 文档重写 + LGF CHANGELOG 补记 | 文档 |
| W6 | 验收①：实现与本计划逐 P 一致性 review（机器可查判据） | 验收 |
| W7 | 验收②：codex CLI（xhigh）审查全量 diff + 修复循环 | 验收 |

## 验收

**W6 一致性判据**（逐 P，grep/测试级）：P2 lint 在 `hex/regression` 且注入坏样本红过一次；P3 消费方无裸 tag、技能声明处 cue 裸字符串=0；P4 `TimelineData.new` 在 active/ 仅存于个性名单；P5 8 文件走 preset、poison 保持显式；P6 全库 `.timeline_id(` grep=0、registry 三态+make_read_only；P7 lint TARGETING 必填绿、AI 无 `has_ability_tag("cone")`、`can_use_skill_at` 存在、README 有几何约定；P8 基线 scenario 在库且绿、`_next_chain_data` 调用点=1；P9 SKILL.md 路径抽查一致、无 progress 引用。

**W7 codex 审查**：范围 = submodule 基线 `ec4d592`→HEAD 全 diff + 主仓侧改动；`codex exec` headless / read-only / xhigh；findings triage→确认项修复→重跑受影响组→commit；退出判据 = 无未处置确认级 finding；设计分歧类 finding 呈报用户裁决不擅自改。

## 偏离记录

W6 验收（2026-07-10）逐 P 判据核对结果——全部达标，偏离与处置如下：

| # | 偏离/事件 | 处置与理由 |
|---|---|---|
| 1 | precise_shot 的 cast timeline **保留自定义**（未并入 `CAST_LAUNCH_600`） | 计划括号内可选项。并入会把 LAUNCH 300ms→400ms（出手时机变化）——与 P8「游戏内行为不变」硬约束冲突，选择不并。快弓节奏已在文件头注释说明 |
| 2 | `timeline_id()` 兼容入口在 W1 短暂保留、W2 迁移完成后删除（计划写在 W1 删） | 波次内部次序调整：保证 W1 波次末测试全绿（44 处调用点未迁时删除会全线爆炸）。最终态与计划一致（全库归零） |
| 3 | lint 首跑抓获存量违规：`buff_physical_shield` / `buff_magical_shield` 从未接 BUFF_REGISTRY | 按计划预案「修」处置——补 PS（钢灰）/ MS（蓝紫）两 entry，双盾头顶图标自此显示 |
| 4 | `demon_form_pulse` 列入 lint 的 `CUE_NO_VISUAL_YET` 豁免名单 | 存量事实（该 cue 一直无 frontend 消费），非本轮引入；已在 HexBattleCues 菜单标注 |
| 5 | SKILL.md 保留一句「原 progress 文档已废除」墓碑说明（判据字面要求"无引用"） | 有意保留：帮携带旧工作流记忆的读者理解 Step 0 变更；无任何流程依赖 |
| 6 | **W6 验收自身抓获 W2 遗漏**：`hex_battle_procedure.gd` / `skill_scenario_harness.gd` 两处 `"intrinsic"` 裸字符串消费方 | 已修（切 `HexBattleSkillTags.TAG_INTRINSIC`）——P3「消费方无裸 tag」判据在修复后达标 |

其余判据一次通过：`.timeline_id(` 全库=0；`_next_chain_data` 调用点=1；技能声明处 cue 裸字符串=0；preset 收编 8 文件 + poison 显式；16 处 TimelineData 声明全部在个性名单（9 个节奏个性主动技 + 6 个 buff/被动 tick + std 库自身）；registry 三态+make_read_only 在位；`can_use_skill_at` 在位；AI 无 `has_ability_tag("cone")`；README 三层分工铁律在位；lint 在 `hex/regression` 且经真实违规（#3）+ 注入假 tag 双重自证会红。

## 明确不做（本轮 review 认可的既有决策，勿重开）

- buff 多实例并存 / Expose 指数叠加（已 grill 确认）
- 投射物四件套不抽 factory（3 技能/12 参数/有结构差异，注释已锚定重估条件）
- AOE 几何逐技能各写（第 4 个 AOE 时重估；P7 只把已有的几何共用升为明文）
- `all_skills.gd` 每调用重建 manifest（Godot 4.6 崩溃绕行，成本可忽略）
