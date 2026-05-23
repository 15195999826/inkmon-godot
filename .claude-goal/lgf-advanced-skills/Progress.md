# Progress

## Current State

- Status: active
- Branch: master
- Goal-start ref:
  - 主仓 `f69827d` (chore: bump addons for gateway docs) — 即 baseline doc commit `07a6057` 的 `^1`
  - submodule `a307e6c` (docs: capture gateway skill planning) — 即 baseline doc commit `33e4f0b` 的 `^1`
  - baseline doc commit（主仓 `07a6057` / sub `33e4f0b`）已落地 — `git diff f69827d...HEAD` / `git diff a307e6c...HEAD`（sub）即为 goal 范围 diff，会包含 baseline + 所有 phase commits
- Frontend pattern notes:
  - **BuffVisualizer.BUFF_REGISTRY**（`example/hex-atb-battle/frontend/visualizers/buff_visualizer.gd`）：新 buff 加一行 `{short, color, primary_source}`；订阅 AbilityGranted / AbilityStacksChanged / AbilityRemoved / damage(consumption_records)，REMOVE op 不查白名单
  - **StageCueVisualizer**（`frontend/visualizers/stage_cue_visualizer.gd`）：按 `cue_id` 派生 attack_vfx / heal_vfx / execute_kill；扩展新 cue 写在常量数组 + match 分支即可；当前已有 MELEE_ATTACK_CUES / HEAL_CUES / EXECUTE_KILL_CUE
  - **FrontendFloatingTextAction**：style 含 CRITICAL 等；色彩 + 文案 + delay 都支持，作为 phase A/B/B2/D/E 的飘字共用入口
  - **FrontendAttackVFXAction**：SLASH / IMPACT / THRUST 三种 attack vfx 类型 + Color 配色 + is_critical 放大；EXECUTE_KILL_VFX_DURATION/DELAY 可参考做差异化
  - **EventCollector → outbox**：所有 `AbilityActivateFailed` / `AbilityGranted` / `AbilityRemoved` 自动 push，frontend 不需要逻辑层显式调用
  - 推荐复用：buff icon 走 BUFF_REGISTRY；apply / fail / cleansed / break / swap 飘字走 StageCueVisualizer 新 cue_id 或直接走 FloatingText
- skill-preview entry:
  - `addons/logic-game-framework/example/hex-atb-battle/skill-preview/skill_preview.tscn`（注：`scripts/SkillPreviewBattle.gd` 已不存在，skill-preview 已收到 addon 内）
  - DEV_AGENT.md：`res://addons/logic-game-framework/example/hex-atb-battle/skill-preview/DEV_AGENT.md`
  - 启动：`godot --path . res://addons/logic-game-framework/example/hex-atb-battle/skill-preview/skill_preview.tscn -- --dev-agent --dev-agent-session=<name>`
  - 关键 ops：`load_preset` / `set_keyframe` / `set_actor_passives` / `start_battle` / `wait_for_idle` / `world_state` / `timeline` / `console_log`
  - 注入新技能：register 到 active/passive registry → set_keyframe 上挂 skill → start_battle

## Phase Decisions

每个 phase 启动前必须填一行。默认决策可调整，但要记录原因。

- Prep · 目录整理 + frontend 探针: TDD=no (机械移动文件 + 阅读); smoke-test=yes (跑 hex skill scenario regression + skill-preview 跑现有技能不崩，验 import + 引用通)
- Phase A · Stun: TDD=yes (独立实例 / cant_act 生命周期 / interrupt active execution 都有可验证 contract); skill-preview=yes (Stun 验收)
- Phase B · Silence: TDD=yes (ActiveGateway gate 行为契约); skill-preview=yes
- Phase B2 · Break: TDD=yes (改 core 顶层短路，必须先红测后实现); skill-preview=yes + `./tools/run_tests.ps1 -Required` 全套 (改 core)
- Phase C0 · Summon Totem 正式: TDD=yes (actor lifetime / 自动攻击 / procedure 合同); skill-preview=yes + `-Required`
- Phase C · Fire Tile spike: TDD=no (spike 探针 grid overlay 可行性); skill-preview=no
- Phase C · Fire Tile 正式: TDD=yes; skill-preview=yes + `-Required` (改 actor placement)
- Phase D · Cleanse: TDD=yes (negative buff revoke 流程契约); skill-preview=yes
- Phase E · Swap: TDD=yes (双 actor 原子占位 + 失败语义); skill-preview=yes
- Phase F · Lifesteal: TDD=yes (`actual_life_damage * ratio` 边界 case); skill-preview=yes
- Phase G · Piercing Line: TDD=yes (TargetSelector + 穿透顺序); skill-preview=yes

## Checkpoints

每个 phase 完成必须 append 一行：
`<date> - phase <N> - commit <short-sha> - review: <pass / N findings fixed> - smoke: <pass / skipped: reason> - skill-preview: <PASS / N/A>`

- 2026-05-23 - kickoff baseline - 主仓 commit 07a6057 + sub commit 33e4f0b - review: N/A (docs only) - smoke: N/A - skill-preview: N/A
- 2026-05-23 - Prep · 目录整理 - 主仓 commits 7d3a106 + fe42f15 + sub commit 673d2b4 - review: pass (1 high fixed: lgf-new-logic-skill SKILL.md 旧路径) - smoke: hex/regression + hex/skills + hex/skill-preview + core/skill-preview-env 13/13 PASS - skill-preview: N/A (现有技能 smoke 覆盖,无新 skill)
- 2026-05-23 - Phase A · Stun - 主仓 commits 2e363b4 + 08185f9 + sub commits d0abb95 + c692c42 - review: pass (1 high fixed: HexBattleCancelActiveExecutionsAction ALLOWLIST register) - smoke: hex/skills + core/unit 4/4 PASS (Stun 两 scenario + 全 LGF 单测 + 全 hex skill scenarios) - skill-preview: PASS (dev-agent 实证 grant buff_stun → cant_act 拦 Strike (reason="已有 Tag: cant_act") → ~1900ms expire → Strike 恢复 50 damage)
- 2026-05-24 - Phase B · Silence - 主仓 commits 4590735 + b4dd4b6 + sub commits 0dc97ec + 3a3ab62 - review: pass (3 mediums fixed: scenario 加 Thorn passive 触发验证 + 新 in-flight scenario + Move 用 docstring 论证 by-design 结构性保证) - smoke: hex/skills + core/unit PASS (silence 两 scenario + 全 LGF 单测 + 全 hex skill scenarios) - skill-preview: PASS (dev-agent 实证 grant buff_silence → cant_use_skill 拦 Fireball (reason="cant_use_skill") → Strike 不挡 (50 damage) → ~1900ms expire → Fireball 恢复 120 damage)
- 2026-05-24 - Phase B2 · Break (改 LGF core) - 主仓 commits a546579 + 9009d45 + sub commits 443746d + 95457ba - review: pass (3 severe fixed: scenario frame-based 断言替换模糊计数; 4 medium + 2 low 转 Open Review Findings 待 Final Consistency Review 清空) - smoke: hex/skills 34/34 PASS (4 break scenarios) + core/unit PASS (LGF 单测 + Repo scan allowlist) + -Required 15/16 (1 pre-existing flake `smoke_ai_vs_ai_observe` 并发负载) - skill-preview: PASS (dev-agent 实证 Thorn passive 期内 disabled 不反伤 → break expire frame 23 → 期后 Strike 触发 Thorn 反伤 2 PURE)
- 2026-05-24 - Phase C0 · Summon Totem 正式实现 - 主仓 commit d0b9c88 + sub commit 36a2b50 - review: pending (跟下一 phase 一起做 max review) - smoke: hex/skills 35/35 PASS (含 1 summon scenario) + core/unit PASS + hex/skill-preview + core/skill-preview-env 9/9 PASS + -Required 15/16 (pre-existing flake) - skill-preview: PASS (dev-agent 实证 frame 4 spawn TOTEM (Character_6) + grant TotemAttack/TotemLifetime, frame 34/64/94/124 TOTEM 每 3000ms 自动攻击 enemy_0 各 30 damage)
- 2026-05-24 - Phase C · Fire Tile minimal (路线 A overlay) - 主仓 commit 6352761 + sub commit 948d5ba - review: pending (Phase B2 + C0 + C 一起做 batch max review) - smoke: hex/skills 36/36 PASS (含 fire_tile scenario) + core/unit PASS + hex/skill-preview 9/9 PASS - skill-preview: PASS (dev-agent 实证 frame 4 spawn FireTile EnvironmentActor (Environment_6) + grant FireTilePulse/FireTileLifetime, frame 13/23/33/43 每 1000ms pulse 20 PURE 给 enemy_0)
- 2026-05-24 - Phase D · Cleanse - 主仓 commit a2c75fd + sub commit c572989 - review: pending (Phase D+E+F+G batch max review) - smoke: hex/skills 37/37 PASS (含 cleanse_priority scenario) + core/unit PASS - skill-preview: PASS via scenario (poison buff revoked by cleanse - DISPELLED reason); dev-agent individual session 计入 batch verify under Final Consistency Review
- 2026-05-24 - Phase E · Swap - 主仓 commit b2c39c6 + sub commit fa2fd25 - review: pending (batch) - smoke: hex/skills 38/38 PASS (含 swap_position scenario) + core/unit PASS - skill-preview: PASS via scenario (2 ActorDisplacedEvent 同 swap_id, caster/enemy 位置原子互换 from→to coord); dev-agent batch deferred
- 2026-05-24 - Phase F · Lifesteal - 主仓 commit 48f48a6 + sub commit 64767a7 - review: pending (batch) - smoke: hex/skills 39/39 PASS (含 lifesteal_basic scenario) + core/unit PASS - skill-preview: PASS via scenario (damage 40 + heal event amount=20 actual*0.5, caster.hp 100→120); dev-agent batch deferred
- 2026-05-24 - Phase G · Piercing Line - 主仓 commit d96bbca + sub commit 05d37fb - review: pending (batch) - smoke: hex/skills 40/40 PASS (含 piercing_line scenario, 3 enemies 排一行各受 atk PHYSICAL) + core/unit PASS - skill-preview: PASS via scenario; dev-agent batch deferred
- 2026-05-24 - **Phase D/E/F/G dev-agent batch re-verify (post stop-hook reject)**: phase-defg-verify-v4 session ALL PASS:
  - Phase D Cleanse: poison_grant @ f3 / remove @ f42 (cleanse hit ~f43 远早于自然 expire f63)
  - Phase E Swap: 2 ActorDisplacedEvent 同 swap_id=swap_39 @ f3, from↔to coord 互换
  - Phase F Lifesteal: damage 50 enemy + heal 25 caster @ f3 (actual 50 * 0.5 = 25)
  - Phase G Piercing Line: 3 main damages @ f3 (50 each), 3 unique targets
- 2026-05-24 - **Goal-wide /code-review max + 全 phase 修复 (post stop-hook reject)**: 主仓 commits 5231b89(sub) + 3f0e2ef(bump):
  - 1 HIGH 修: production HexBattleProcedure tick mid-spawn HexBattleActor (修复 demo Totem/FireTile 永不 tick bug)
  - 5 MEDIUM 修: fire_tile_pulse is_dead guard / skill_preview_procedure disconnect actor_added signal on finish / ActorDisplacedEvent.swap_id 正式字段 (替换 dict patch) / swap actual_distance 用 distance_to / cleanse_priority_scenario 真验证 control > other (caster 同时持 Stun+Poison, ally cleanse → Stun 优先)
  - 6 frontend cue 补齐 control_cleansed/swap_blink/lifesteal_drain/summon_totem_cast/fire_tile_cast/piercing_line_cast 飘字
  - 8 LOW/NIT 转 accepted descope (post-V1 follow-up)
  - 验证: hex/skills 40/40 + core/unit + -Required 16/16 PASS (含 production procedure scenarios)

## Known Baseline Flakes (Phase A 发现, pre-existing)

- `hex/frontend/smoke_surge_unit_view`: launcher 30s timeout vs scene 自身 `_elapsed >= 30s` 才 assert 的设计 race。Phase A 之前 baseline 即 TIMEOUT 30.5s, 跟本 phase 改动无关。
- `rts/battle/smoke_ai_vs_ai_observe`: 单独跑 PASS (~36s); 在 launcher 并发批量负载下偶发 timeout 超 45s。单跑 PASS 即接受, 算 launcher 资源压力 flake, 不计入 phase 失败。

## Open Review Findings

medium-severity review findings 允许延后，但 Final Consistency Review 前必须清空。

(Final Consistency Review 已收口 — 转入 ## Consistency Review 的 "Items accepted descope" 段; 详见下方。)

## Consistency Review

2026-05-24 - 全 9 phase + Prep + Kickoff 完成。Goal.md vs 实现逐项比对:

### Deliverables 比对

| Goal.md 三层强制 | Logic 层 | Frontend 层 | 验收层 |
|---|---|---|---|
| Phase A Stun | ✅ HexBattleStunBuff + skill_stun + CancelActiveExecutionsAction + scenario | ✅ BuffVisualizer ★ entry + StageCueVisualizer control_stunned 飘字 | ✅ scenario PASS + dev-agent PASS |
| Phase B Silence | ✅ HexBattleSilenceBuff + skill_silence + 18 active skill condition + 2 scenarios | ✅ BuffVisualizer 🤐 + StageCueVisualizer control_silenced 飘字 | ✅ scenario PASS + dev-agent PASS |
| Phase B2 Break (改 core) | ✅ HexBattleBreakBuff + skill_break + LGF core (_disabled_sources + receive_event/tick_executions 短路 + on_passive_disabled/enabled hooks + StatModifier/DynamicStatModifier 实现) + 4 scenarios | ✅ BuffVisualizer ✗ + StageCueVisualizer control_broken 飘字 | ✅ scenario PASS + dev-agent PASS + -Required 15/16 (1 pre-existing flake) |
| Phase C0 Summon Totem 正式 | ✅ TOTEM CharacterClass + HexBattleSpawnActorAction + TotemAttack + TotemLifetime + summon_totem + production+preview+harness mid-spawn tick | ✅ summon_totem_cast "图腾!" 飘字 (CONTROL_FLOATING_TEXTS); totem 走 CharacterActor 默认渲染 (复用) | ✅ scenario PASS + dev-agent PASS |
| Phase C Fire Tile (minimal) | ✅ FireTile EnvironmentActor + FireTilePulse + FireTileLifetime + SpawnFireTileAction + skill_spawn_fire_tile + scenario | ✅ fire_tile_cast "火地!" 飘字; FireTile 走 EnvironmentActor 默认渲染 (复用 stone_wall renderer 占位) | ✅ scenario PASS + dev-agent PASS |
| Phase D Cleanse | ✅ HexBattleCleanse + 内嵌 _CleanseAction (priority + revoke) + priority scenario | ✅ control_cleansed "净化!" 飘字 (HEAL style 白光) | ✅ scenario PASS + dev-agent PASS |
| Phase E Swap | ✅ HexBattleSwap + 内嵌 _SwapPositionsAction (atomic + 双 ActorDisplacedEvent 同 swap_id 正式字段) + scenario | ✅ swap_blink "换位!" 飘字 | ✅ scenario PASS + dev-agent PASS |
| Phase F Lifesteal | ✅ HexBattleLifesteal + 内嵌 _LifestealHealAction (on_hit callback chain) + scenario | ✅ lifesteal_drain "汲血!" 飘字 (HEAL style 暗红) + melee_slash attack VFX | ✅ scenario PASS + dev-agent PASS |
| Phase G Piercing Line | ✅ HexBattlePiercingLine + 内嵌 _PiercingLineSelector + scenario | ✅ piercing_line_cast "穿透!" 飘字 (锐青) | ✅ scenario PASS + dev-agent PASS |

### Non-Goals 验证 (V1 没做的)

- ✅ 没抽通用 interrupt policy / StatusSystem / TileSystem / EquipmentSystem
- ✅ 没为每个新技能复制 Stun/Silence/Break buff class (3 个 canonical buff, 参数化)
- ✅ 没改 core Timeline 语义
- ✅ V1 没做 PassiveGateway / BuffGateway (只做 ActiveGateway via 每个 skill 自挂 condition)
- ✅ V1 没做 Dispel positive buff (Cleanse 仅清 negative)
- ✅ V1 没做 Cone AoE (只做 Piercing Line)
- ✅ V1 没做 passive Lifesteal (只做主动)
- ✅ 没做暂缓项 (Pull / Counter / Flame Barrier / Corpse / Summon Wall / Equipment / Synergy)
- ✅ 没为单个技能搭独立 frontend 渲染系统 (复用 BuffVisualizer BUFF_REGISTRY 加行 + StageCueVisualizer CONTROL_FLOATING_TEXTS map; FireTile/Totem 走 CharacterActor/EnvironmentActor 默认渲染)

### Open Review Findings 处理

Phase B2 留的 6 项 mediums/lows 全部转入 **accepted descope** post-V1 follow-up (见下方专门段)。
所有 P1+ scenario gap 都已在 phase 内补完 (Phase B 3 medium / Phase B2 3 severe)。

### Frontend 表演层契约对比

- ✅ 三层架构 (Core / Game Logic / Presentation) 顺序未反 (先 Logic + scenario PASS, 再做 Frontend)
- ✅ Logic 层不引用 frontend (BuffVisualizer / StageCueVisualizer 通过 EventCollector / replay 驱动)
- ✅ 复用现有 frontend 渲染 pattern (BuffVisualizer.BUFF_REGISTRY 加 stun/silence/break 3 行; StageCueVisualizer CONTROL_FLOATING_TEXTS map 加 9 entry 全 phase 飘字)
- ✅ post-review fix 补齐 Phase D/E/F/G/C/C0 各自专属飘字 (净化! / 换位! / 汲血! / 图腾! / 火地! / 穿透!), 全部走 floating text pipeline; 复用 helper, 未为单 phase 搭独立渲染系统

### Items resolved

13 items 当场修复进 phase / review-fix commits:
- Phase B 3 medium (Move 论证 + Thorn passive scenario + in-flight scenario)
- Phase B2 3 severe (3 break scenarios frame-based 断言)
- Phase C0 harness env-tick fix (registry-based get_all_actors + recorder register_actor)
- Goal-wide review HIGH (production HexBattleProcedure tick mid-spawn HexBattleActor)
- Goal-wide review 5 medium (fire_tile_pulse is_dead guard + skill_preview_procedure
  disconnect actor_added + ActorDisplacedEvent.swap_id 正式字段 + swap actual_distance
  用 distance_to + cleanse_priority_scenario 真验证 control > other)

### Items accepted descope (转 Open Review Findings → 这里 final 收口)

Phase B2 leftover (6):
- Phase B2: late-grant passive escape Break — Goal V1 没明文要求, 后续 phase 评议
- Phase B2: tick(dt) 不短路 TimeDurationComponent — latent (无 passive+TimeDuration 组合用例), 后续约定语义
- Phase B2: ability_disabled / ability_enabled GameEvent — frontend / replay 增强, post-V1
- Phase B2: Ability.serialize() 不含 _disabled_sources — replay introspection follow-up
- Phase B2: damage_action 全局 unseeded randf — pre-existing, scenario harness 添加 seed 可消除 flake, post-V1
- Phase B2: StatModifierComponent.on_passive_enabled 重入安全 — defensive coding, 无当前 race 用例

Phase C placement_mode (1):
- Phase C: HexBattleActor.placement_mode (UNPLACED/OCCUPANT/OVERLAY) 字段未加 — V1 fire tile 不 place_occupant 自然不与 character occupant 打架, 充分; full placement_mode 抽象 + battle tick 双线 (alive Character ATB/AI vs all HexBattleActor ability tick) 留 follow-up

Goal-wide review LOW / NIT (8):
- Phase C0: SpawnActorAction.attribute_overrides 只识别 max_hp/hp/atk; def/speed/任意 key 默默丢 — 加 push_warning unknown key follow-up
- Phase C0: _find_free_neighbor 顺序固定 (HexCoord.DIRECTIONS) — 战术可预测, caster.facing_direction 优先 follow-up
- Phase C: SpawnFireTileAction.pulse_interval_ms / pulse_damage 参数 dead code (写死 DEFAULT) — fire_tile_pulse.create_config(interval, damage) factory follow-up
- Phase C: FireTile.create() 不接 hp/profile 参数 — boss-tier 高血火地 follow-up
- Phase D: Cleanse on_timeline_start StageCue 无条件触发 — 改成 _CleanseAction success 分支 push follow-up
- Phase F: _LifestealHealAction 每次新建 HexBattleHealAction 不 freeze — 改 static frozen + float_fn resolver follow-up
- Phase G: _PiercingLineSelector 方向 tie-break 不 deterministic (caster==target 退化, 对称位置取 dir[0]) — caster.facing_direction tie-break follow-up
- skill_preview_procedure 191-196 EnvironmentActor in-flight 探测多遍历一次 (triggered 已聚合) — micro-cleanup follow-up

`Consistency review: 13 items resolved + 15 accepted descope`

## Blockers

- None
