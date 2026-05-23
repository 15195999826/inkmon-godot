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

## Known Baseline Flakes (Phase A 发现, pre-existing)

- `hex/frontend/smoke_surge_unit_view`: launcher 30s timeout vs scene 自身 `_elapsed >= 30s` 才 assert 的设计 race。Phase A 之前 baseline 即 TIMEOUT 30.5s, 跟本 phase 改动无关。
- `rts/battle/smoke_ai_vs_ai_observe`: 单独跑 PASS (~36s); 在 launcher 并发批量负载下偶发 timeout 超 45s。单跑 PASS 即接受, 算 launcher 资源压力 flake, 不计入 phase 失败。

## Open Review Findings

medium-severity review findings 允许延后，但 Final Consistency Review 前必须清空。

- None

## Consistency Review

(所有 phase 完成后填入。)

- <date> - Goal.md vs 实现: <no divergence | resolved items list>
- `Consistency review: no divergence`（或 `N items resolved`）

## Blockers

- None
