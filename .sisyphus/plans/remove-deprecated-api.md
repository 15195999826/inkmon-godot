# 移除向后兼容 API

## TL;DR

> **Quick Summary**: 移除 GameEvent 中所有 @deprecated 的旧工厂函数，迁移剩余使用旧 API 的代码
> 
> **Deliverables**:
> - 迁移 `stage_cue_action.gd` 到新 API
> - 迁移 `recording_utils.gd` 到新 API
> - 删除 GameEvent 中 22 个 @deprecated 函数
> 
> **Estimated Effort**: Medium
> **Parallel Execution**: NO - 必须先迁移再删除

---

## Context

### Original Request
用户要求移除所有向后兼容代码（@deprecated 函数）

### Current Situation
- GameEvent 有 22 个 @deprecated 函数（11 个工厂函数 + 11 个类型守卫）
- 2 个文件仍在使用旧 API：
  - `addons/logic-game-framework/stdlib/actions/stage_cue_action.gd`
  - `addons/logic-game-framework/stdlib/replay/recording_utils.gd`

---

## Work Objectives

### Core Objective
完全移除向后兼容代码，强制使用强类型 API

### Concrete Deliverables
- 迁移 `stage_cue_action.gd` 使用 `GameEvent.StageCue.create()`
- 迁移 `recording_utils.gd` 使用强类型事件类
- 删除 `game_event.gd` 中第 388-544 行（157 行 @deprecated 代码）

### Definition of Done
- [x] stage_cue_action.gd 使用新 API
- [x] recording_utils.gd 使用新 API
- [x] game_event.gd 无 @deprecated 函数
- [x] 编译通过，无错误

---

## TODOs

- [x] 1. 迁移 stage_cue_action.gd

  **What to do**:
  - 修改 `addons/logic-game-framework/stdlib/actions/stage_cue_action.gd`
  - 将 `GameEvent.create_stage_cue_event()` 改为 `GameEvent.StageCue.create().to_dict()`

  **代码位置**:
  ```gdscript
  # 第 23 行附近
  var event = GameEvent.create_stage_cue_event(
      source_actor_id,
      target_actor_ids,
      _cue_id,
      _params
  )
  ```

  **修改为**:
  ```gdscript
  var event := GameEvent.StageCue.create(
      source_actor_id,
      target_actor_ids,
      _cue_id,
      _params
  )
  ctx.event_collector.push(event.to_dict())
  ```

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 2)
  - **Blocks**: Task 3
  - **Blocked By**: None

  **Acceptance Criteria**:
  - [ ] 使用 `GameEvent.StageCue.create()`
  - [ ] 调用 `.to_dict()` 转换为 Dictionary
  - [ ] 编译通过

  **Commit**: YES
  - Message: `refactor(stdlib): migrate stage_cue_action to strongly-typed API`
  - Files: `addons/logic-game-framework/stdlib/actions/stage_cue_action.gd`

---

- [x] 2. 迁移 recording_utils.gd

  **What to do**:
  - 修改 `addons/logic-game-framework/stdlib/replay/recording_utils.gd`
  - 迁移 8 个旧函数调用到新 API

  **需要迁移的函数**:
  1. `create_attribute_changed_event()` → `AttributeChanged.create().to_dict()`
  2. `create_ability_triggered_event()` → `AbilityTriggered.create().to_dict()`
  3. `create_execution_activated_event()` → `ExecutionActivated.create().to_dict()`
  4. `create_ability_granted_event()` → `AbilityGranted.create().to_dict()`
  5. `create_ability_removed_event()` → `AbilityRemoved.create().to_dict()`
  6. `create_tag_changed_event()` → `TagChanged.create().to_dict()`
  7. `create_actor_spawned_event()` → `ActorSpawned.create().to_dict()`
  8. `create_actor_destroyed_event()` → `ActorDestroyed.create().to_dict()`

  **Recommended Agent Profile**:
  - **Category**: `unspecified-high`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: YES (with Task 1)
  - **Blocks**: Task 3
  - **Blocked By**: None

  **References**:
  - `addons/logic-game-framework/stdlib/replay/recording_utils.gd` - 目标文件
  - `addons/logic-game-framework/core/events/game_event.gd` - 新 API 定义

  **Acceptance Criteria**:
  - [ ] 所有 8 个旧函数调用已迁移
  - [ ] 使用 `.to_dict()` 转换为 Dictionary
  - [ ] 编译通过

  **Commit**: YES
  - Message: `refactor(stdlib): migrate recording_utils to strongly-typed API`
  - Files: `addons/logic-game-framework/stdlib/replay/recording_utils.gd`

---

- [x] 3. 删除 game_event.gd 中的 @deprecated 函数

  **What to do**:
  - 修改 `addons/logic-game-framework/core/events/game_event.gd`
  - 删除第 388-544 行（157 行 @deprecated 代码）

  **删除内容**:
  - 11 个 `create_xxx_event()` 工厂函数
  - 11 个 `is_xxx_event()` 类型守卫函数
  - 注释 `# ========== 旧工厂函数（标记 deprecated，保持兼容） ==========`

  **Must NOT do**:
  - 不删除事件常量（ABILITY_ACTIVATE_EVENT 等）
  - 不删除强类型事件类（ActorSpawned, AttributeChanged 等）

  **Recommended Agent Profile**:
  - **Category**: `quick`
  - **Skills**: []

  **Parallelization**:
  - **Can Run In Parallel**: NO
  - **Blocks**: None
  - **Blocked By**: Tasks 1, 2

  **References**:
  - `addons/logic-game-framework/core/events/game_event.gd` - 目标文件

  **Acceptance Criteria**:
  - [ ] 第 388-544 行已删除
  - [ ] 文件从 545 行减少到约 388 行
  - [ ] 编译通过，无错误
  - [ ] grep "@deprecated" 返回 0 结果

  **Commit**: YES
  - Message: `refactor(core): remove all deprecated event factory functions`
  - Files: `addons/logic-game-framework/core/events/game_event.gd`

---

## Commit Strategy

| After Task | Message | Files |
|------------|---------|-------|
| 1 | `refactor(stdlib): migrate stage_cue_action to strongly-typed API` | `stage_cue_action.gd` |
| 2 | `refactor(stdlib): migrate recording_utils to strongly-typed API` | `recording_utils.gd` |
| 3 | `refactor(core): remove all deprecated event factory functions` | `game_event.gd` |

---

## Verification Strategy

### Compilation Check
```bash
godot --headless --quit
# Assert: 退出码 0，无 SCRIPT ERROR
```

### Grep Check
```bash
grep "@deprecated" addons/logic-game-framework/core/events/game_event.gd
# Assert: 无结果
```

### Usage Check
```bash
grep -r "create_.*_event" addons/logic-game-framework/ --include="*.gd" | grep -v "game_event.gd" | grep -v "projectile_events.gd"
# Assert: 仅剩 ProjectileEvents 和自定义函数
```
